// lib/src/features/transaction/logic/payment_controller.dart

import 'dart:developer' as developer;
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qrypta/src/core/config/app_config.dart';
import 'package:qrypta/src/core/config/blockchain_config.dart';
import 'package:qrypta/src/core/error/app_failure.dart';
import 'package:qrypta/src/core/error/network_exception_adapter.dart';
import 'package:qrypta/src/core/providers/foundation_providers.dart';
import 'package:qrypta/src/core/services/authentication_service.dart';
import 'package:qrypta/src/core/services/blockchain/blockchain_service.dart';
import 'package:qrypta/src/core/transaction/state_machine/tx_state.dart';
import 'package:qrypta/src/core/transaction/state_machine/tx_state_machine.dart';
import 'package:qrypta/src/core/utils/formatters.dart';
import 'package:qrypta/src/features/authentication/presentation/providers/auth_providers.dart';
import 'package:qrypta/src/features/authentication/presentation/providers/btid_provider.dart';
import 'package:qrypta/src/features/tokens/presentation/providers/token_provider.dart';
import 'package:qrypta/src/features/verification/logic/verification_controller.dart';

/// Model Kuitansi Resmi Tourist Levy Bali
class LevyReceiptData {
  final String receiptRef;
  final String touristName;
  final String btidNumber;
  final String passportMasked;
  final String amount;
  final int amountRaw;
  final String paymentMethod;
  final String txHash;
  final DateTime timestamp;
  final String bapendaAddress;
  final String mrzLine1;
  final String mrzLine2;

  const LevyReceiptData({
    required this.receiptRef,
    required this.touristName,
    required this.btidNumber,
    required this.passportMasked,
    required this.amount,
    required this.amountRaw,
    required this.paymentMethod,
    required this.txHash,
    required this.timestamp,
    required this.bapendaAddress,
    required this.mrzLine1,
    required this.mrzLine2,
  });

  static String generateMrzLine1(String levyRef, int amount) {
    final cleanRef = levyRef.replaceAll('-', '<');
    final raw = 'LEVY<<$cleanRef<<IDR$amount';
    return raw.length > 44 ? raw.substring(0, 44) : raw.padRight(44, '<');
  }

  static String generateMrzLine2(String btidNumber) {
    final cleanBtid = btidNumber.replaceAll('-', '<');
    final raw = 'BTID<<$cleanBtid<<PAID';
    return raw.length > 44 ? raw.substring(0, 44) : raw.padRight(44, '<');
  }
}

/// Model Kuitansi Resmi Pembayaran QRIS Merchant
class QrisReceiptData {
  final String payRef;
  final String merchantName;
  final String merchantId;
  final String merchantAddress;
  final String amount;
  final int amountRaw;
  final String paymentMethod;
  final String txHash;
  final DateTime timestamp;
  final String itemDescription;
  final String privacyNotice;

  const QrisReceiptData({
    required this.payRef,
    required this.merchantName,
    required this.merchantId,
    required this.merchantAddress,
    required this.amount,
    required this.amountRaw,
    required this.paymentMethod,
    required this.txHash,
    required this.timestamp,
    required this.itemDescription,
    this.privacyNotice =
        'Zero passport, identity, or personal data revealed to merchant.',
  });
}

/// State Operasi Pembayaran
class PaymentState {
  final bool isLoading;
  final bool isTransferring;
  final String? errorMessage;
  final LevyReceiptData? lastLevyReceipt;
  final QrisReceiptData? lastQrisReceipt;

  const PaymentState({
    this.isLoading = false,
    this.isTransferring = false,
    this.errorMessage,
    this.lastLevyReceipt,
    this.lastQrisReceipt,
  });

  PaymentState copyWith({
    bool? isLoading,
    bool? isTransferring,
    String? errorMessage,
    LevyReceiptData? lastLevyReceipt,
    QrisReceiptData? lastQrisReceipt,
  }) {
    return PaymentState(
      isLoading: isLoading ?? this.isLoading,
      isTransferring: isTransferring ?? this.isTransferring,
      errorMessage: errorMessage,
      lastLevyReceipt: lastLevyReceipt ?? this.lastLevyReceipt,
      lastQrisReceipt: lastQrisReceipt ?? this.lastQrisReceipt,
    );
  }
}

final paymentControllerProvider =
    StateNotifierProvider<PaymentNotifier, PaymentState>((ref) {
  return PaymentNotifier(ref);
});

class PaymentNotifier extends StateNotifier<PaymentState> {
  final Ref ref;

  PaymentNotifier(this.ref) : super(const PaymentState());

  /// Eksekusi Pembayaran Tourist Levy (ScrLevyPay) on-chain tanpa fallback palsu
  Future<LevyReceiptData> payTouristLevy({
    required String paymentMethod,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    // 1. Otorisasi Biometrik / PIN
    final authOk = await AuthenticationService.authenticate(
      'Authorize Bali Tourist Levy payment (IDR 150,000)',
    );

    if (!authOk) {
      const failure = ValidationFailure('Otorisasi biometrik/PIN dibatalkan atau gagal.');
      state = state.copyWith(isLoading: false, errorMessage: failure.message);
      throw failure;
    }

    // 2. Validasi kredensial BTID
    final btidCred = ref.read(btidCredentialProvider);
    if (btidCred == null || btidCred.walletAddress.isEmpty) {
      const failure = ValidationFailure('Kredensial BTID belum aktif atau dompet belum siap.');
      state = state.copyWith(isLoading: false, errorMessage: failure.message);
      throw failure;
    }

    if (btidCred.isLevyPaid) {
      const failure = ValidationFailure('Tourist Levy sudah berstatus lunas (Paid).');
      state = state.copyWith(isLoading: false, errorMessage: failure.message);
      throw failure;
    }

    // 3. Validasi metode pembayaran (F-03b: non-wallet ditolak transparan)
    if (paymentMethod != 'wallet') {
      final failure = ValidationFailure(
        'Metode pembayaran $paymentMethod belum tersedia untuk penyelesaian on-chain resmi.',
      );
      state = state.copyWith(isLoading: false, errorMessage: failure.message);
      throw failure;
    }

    final userWallet = btidCred.walletAddress;
    final btid = btidCred.btidNumber;
    final touristName = btidCred.fullName;
    final passportMasked = btidCred.passportMasked;
    final bapendaTreasury = BlockchainConfig.bapendaTreasuryAddress;

    final rand = Random();
    final levyRef = 'LVY-${100000 + rand.nextInt(900000)}';

    final blockchainService = ref.read(blockchainServiceProvider);
    final getPrivateKey = ref.read(getPrivateKeyUseCaseProvider);
    final privateKey = await getPrivateKey();

    if (privateKey == null || privateKey.isEmpty) {
      const failure = ValidationFailure('Private key tidak tersedia di secure storage.');
      state = state.copyWith(isLoading: false, isTransferring: false, errorMessage: failure.message);
      throw failure;
    }

    final idrtAddress = AppConfig.idrtContractAddress;
    final decimals = AppConfig.idrtDecimals;
    final amountBigInt = parseAmountToBigInt('150000', decimals);

    // 4. Inisialisasi State Machine transaksi
    final txRepo = ref.read(txIntentRepositoryProvider);
    final txRecovery = ref.read(txRecoveryServiceProvider);
    final stateMachine = TxStateMachine(repository: txRepo);

    await stateMachine.startIntent(
      kind: 'levy',
      ref: levyRef,
      from: userWallet,
      to: bapendaTreasury,
      amount: amountBigInt.toString(),
    );

    state = state.copyWith(isTransferring: true);

    String txHash;
    try {
      try {
        final currentBalance = await blockchainService.erc20.getErc20Balance(
          idrtAddress,
          userWallet,
        );
        if (currentBalance < amountBigInt) {
          throw const InsufficientBalance(
            'Saldo IDRT tidak mencukupi untuk pembayaran retribusi (butuh Rp 150.000).',
          );
        }
      } on AppFailure {
        rethrow;
      } on Object catch (e) {
        developer.log('Pengecekan saldo awal lewati ke broadcast: $e', name: 'PaymentController');
        state = state.copyWith(errorMessage: null);
      }

      await stateMachine.transitionTo(TxState.signing);
      await stateMachine.transitionTo(TxState.broadcasting);

      txHash = await blockchainService.erc20.sendErc20Token(
        privateKey: privateKey,
        contractHex: idrtAddress,
        recipientHex: bapendaTreasury,
        amount: amountBigInt,
      );

      await stateMachine.transitionTo(TxState.pending, txHash: txHash);

      final receipt = await txRecovery.pollReceiptUntilMined(txHash);

      await stateMachine.transitionTo(
        TxState.confirmed,
        blockNumber: BigInt.from(receipt.blockNumber.blockNum),
      );
    } on Object catch (e) {
      final failure = NetworkExceptionAdapter.fromException(e);
      await stateMachine.transitionTo(
        TxState.failed,
        failureReason: failure.message,
      );
      state = state.copyWith(
        isLoading: false,
        isTransferring: false,
        errorMessage: failure.message,
      );
      throw failure;
    }

    // 5. Catat audit finansial & update status lokal
    final verificationService = ref.read(blockchainServiceProvider).verification;
    try {
      await verificationService.recordLevyPaymentAudit(
        levyRef: levyRef,
        txHash: txHash,
        btid: btid,
        amountFormatted: 'IDR 150,000',
        walletAddress: userWallet,
      );
    } on Object catch (e) {
      developer.log('Pencatatan audit levy server tertunda: $e', name: 'PaymentController');
      state = state.copyWith(errorMessage: null);
    }

    await ref
        .read(btidCredentialProvider.notifier)
        .updateLevyStatus('paid', receiptRef: levyRef, txHash: txHash);

    try {
      await ref.read(tokenNotifierProvider.notifier).fetchUserTokens();
      await ref.read(verificationControllerProvider.notifier).loadAuditHistory();
    } on Object catch (e) {
      developer.log('Penyegaran state pasca-transaksi: $e', name: 'PaymentController');
      state = state.copyWith(errorMessage: null);
    }

    final receipt = LevyReceiptData(
      receiptRef: levyRef,
      touristName: touristName,
      btidNumber: btid,
      passportMasked: passportMasked,
      amount: 'IDR 150,000',
      amountRaw: 150000,
      paymentMethod: 'Qrypta IDRT Wallet Balance',
      txHash: txHash,
      timestamp: DateTime.now(),
      bapendaAddress: bapendaTreasury,
      mrzLine1: LevyReceiptData.generateMrzLine1(levyRef, 150000),
      mrzLine2: LevyReceiptData.generateMrzLine2(btid),
    );

    state = state.copyWith(
      isLoading: false,
      isTransferring: false,
      lastLevyReceipt: receipt,
    );

    return receipt;
  }

  /// Eksekusi Pembayaran Merchant QRIS on-chain tanpa fallback palsu
  Future<QrisReceiptData> payQrisMerchant({
    required String merchantName,
    required String merchantId,
    required String merchantAddress,
    required int amountIdr,
    String? itemDescription,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final formattedAmount = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'IDR ',
      decimalDigits: 0,
    ).format(amountIdr);

    // 1. Otorisasi PIN / Biometrik
    final authOk = await AuthenticationService.authenticate(
      'Authorize payment of $formattedAmount to $merchantName',
    );

    if (!authOk) {
      const failure = ValidationFailure('Otorisasi biometrik/PIN dibatalkan atau gagal.');
      state = state.copyWith(isLoading: false, errorMessage: failure.message);
      throw failure;
    }

    final btidCred = ref.read(btidCredentialProvider);
    if (btidCred == null || btidCred.walletAddress.isEmpty) {
      const failure = ValidationFailure('Kredensial BTID belum aktif atau dompet belum siap.');
      state = state.copyWith(isLoading: false, errorMessage: failure.message);
      throw failure;
    }

    final userWallet = btidCred.walletAddress;
    final rand = Random();
    final payRef = 'PAY-${100000 + rand.nextInt(900000)}';

    final blockchainService = ref.read(blockchainServiceProvider);
    final getPrivateKey = ref.read(getPrivateKeyUseCaseProvider);
    final privateKey = await getPrivateKey();

    if (privateKey == null || privateKey.isEmpty) {
      const failure = ValidationFailure('Private key tidak tersedia di secure storage.');
      state = state.copyWith(isLoading: false, isTransferring: false, errorMessage: failure.message);
      throw failure;
    }

    final idrtAddress = AppConfig.idrtContractAddress;
    final decimals = AppConfig.idrtDecimals;
    final amountBigInt = parseAmountToBigInt(amountIdr.toString(), decimals);

    // 2. Inisialisasi State Machine transaksi
    final txRepo = ref.read(txIntentRepositoryProvider);
    final txRecovery = ref.read(txRecoveryServiceProvider);
    final stateMachine = TxStateMachine(repository: txRepo);

    await stateMachine.startIntent(
      kind: 'qris',
      ref: payRef,
      from: userWallet,
      to: merchantAddress,
      amount: amountBigInt.toString(),
    );

    state = state.copyWith(isTransferring: true);

    String txHash;
    try {
      try {
        final currentBalance = await blockchainService.erc20.getErc20Balance(
          idrtAddress,
          userWallet,
        );
        if (currentBalance < amountBigInt) {
          throw InsufficientBalance(
            'Saldo IDRT tidak mencukupi untuk pembayaran QRIS ($formattedAmount).',
          );
        }
      } on AppFailure {
        rethrow;
      } on Object catch (e) {
        developer.log('Pengecekan saldo QRIS lewati ke broadcast: $e', name: 'PaymentController');
        state = state.copyWith(errorMessage: null);
      }

      await stateMachine.transitionTo(TxState.signing);
      await stateMachine.transitionTo(TxState.broadcasting);

      txHash = await blockchainService.erc20.sendErc20Token(
        privateKey: privateKey,
        contractHex: idrtAddress,
        recipientHex: merchantAddress,
        amount: amountBigInt,
      );

      await stateMachine.transitionTo(TxState.pending, txHash: txHash);

      final receipt = await txRecovery.pollReceiptUntilMined(txHash);

      await stateMachine.transitionTo(
        TxState.confirmed,
        blockNumber: BigInt.from(receipt.blockNumber.blockNum),
      );
    } on Object catch (e) {
      final failure = NetworkExceptionAdapter.fromException(e);
      await stateMachine.transitionTo(
        TxState.failed,
        failureReason: failure.message,
      );
      state = state.copyWith(
        isLoading: false,
        isTransferring: false,
        errorMessage: failure.message,
      );
      throw failure;
    }

    // 3. Catat audit finansial QRIS
    final verificationService = ref.read(blockchainServiceProvider).verification;
    try {
      await verificationService.recordQrisPaymentAudit(
        payRef: payRef,
        txHash: txHash,
        merchantName: merchantName,
        merchantId: merchantId,
        amountFormatted: formattedAmount,
        walletAddress: userWallet,
        itemDescription: itemDescription,
      );
    } on Object catch (e) {
      developer.log('Pencatatan audit QRIS server tertunda: $e', name: 'PaymentController');
      state = state.copyWith(errorMessage: null);
    }

    try {
      await ref.read(tokenNotifierProvider.notifier).fetchUserTokens();
      await ref.read(verificationControllerProvider.notifier).loadAuditHistory();
    } on Object catch (e) {
      developer.log('Penyegaran state pasca-transaksi: $e', name: 'PaymentController');
      state = state.copyWith(errorMessage: null);
    }

    final receipt = QrisReceiptData(
      payRef: payRef,
      merchantName: merchantName,
      merchantId: merchantId,
      merchantAddress: merchantAddress,
      amount: formattedAmount,
      amountRaw: amountIdr,
      paymentMethod: 'Qrypta IDRT Wallet Balance',
      txHash: txHash,
      timestamp: DateTime.now(),
      itemDescription: itemDescription ?? 'Merchant settlement',
    );

    state = state.copyWith(
      isLoading: false,
      isTransferring: false,
      lastQrisReceipt: receipt,
    );

    return receipt;
  }
}
