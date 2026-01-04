import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web3dart/web3dart.dart'; // Import web3dart for transaction signing
import 'package:qrypta/src/core/services/blockchain/blockchain_service.dart';
import 'package:qrypta/src/features/authentication/presentation/providers/auth_providers.dart';
import 'package:qrypta/src/core/config/blockchain_config.dart';

// Enum untuk merepresentasikan level biaya transaksi
enum FeeLevel { low, medium, high }

// Define the state for SendMoneyController
class SendMoneyState {
  final FeeLevel selectedFee;
  final bool isSending;
  final String? errorMessage;
  final String? transactionHash; // New field for transaction hash

  SendMoneyState({
    this.selectedFee = FeeLevel.medium,
    this.isSending = false,
    this.errorMessage,
    this.transactionHash,
  });

  SendMoneyState copyWith({
    FeeLevel? selectedFee,
    bool? isSending,
    String? errorMessage,
    String? transactionHash,
  }) {
    return SendMoneyState(
      selectedFee: selectedFee ?? this.selectedFee,
      isSending: isSending ?? this.isSending,
      errorMessage: errorMessage, // Nullable field, so don't use ??
      transactionHash: transactionHash, // Nullable field
    );
  }
}

// Notifier for SendMoneyController
class SendMoneyController extends Notifier<SendMoneyState> {
  final TextEditingController addressController = TextEditingController();
  final TextEditingController amountController = TextEditingController();

  @override
  SendMoneyState build() {
    ref.onDispose(() {
      addressController.dispose();
      amountController.dispose();
    });
    return SendMoneyState();
  }

  // Mengubah level biaya yang dipilih
  void setFeeLevel(FeeLevel fee) {
    developer.log('Setting fee level to: $fee', name: 'SendMoneyController');
    state = state.copyWith(selectedFee: fee);
  }

  // Fungsi untuk memvalidasi input
  bool _validateInput() {
    developer.log('Validating input', name: 'SendMoneyController');
    if (addressController.text.isEmpty) {
      state = state.copyWith(errorMessage: "Recipient address cannot be empty.");
      developer.log('Validation failed: Recipient address is empty', name: 'SendMoneyController');
      return false;
    }
    if (amountController.text.isEmpty || double.tryParse(amountController.text) == null || double.parse(amountController.text) <= 0) {
      state = state.copyWith(errorMessage: "Please enter a valid amount.");
      developer.log('Validation failed: Invalid amount', name: 'SendMoneyController');
      return false;
    }
    state = state.copyWith(errorMessage: null);
    developer.log('Validation successful', name: 'SendMoneyController');
    return true;
  }

  // Fungsi utama untuk mengirim transaksi
  Future<void> sendTransaction() async {
    developer.log('Attempting to send transaction', name: 'SendMoneyController');
    if (!_validateInput()) {
      return;
    }

    state = state.copyWith(isSending: true, errorMessage: null, transactionHash: null);

    final blockchainService = ref.read(blockchainServiceProvider);
    final getPrivateKey = ref.read(getPrivateKeyUseCaseProvider);

    try {
      final privateKey = await getPrivateKey();
      if (privateKey == null) {
        state = state.copyWith(isSending: false, errorMessage: "Private key not found.");
        return;
      }

      final credentials = EthPrivateKey.fromHex(privateKey);
      final recipient = EthereumAddress.fromHex(addressController.text);
      final amountInEther = double.parse(amountController.text);
      final value = EtherAmount.fromUnitAndValue(EtherUnit.ether, amountInEther);
      
      final currentNonce = await blockchainService.transaction.getNonce(credentials.address.hex);
      final gasPrice = await blockchainService.client.getGasPrice();
      final estimatedGas = 21000; // Standard gas limit for simple transfers

      final transaction = Transaction(
        to: recipient,
        value: value,
        gasPrice: gasPrice,
        maxGas: estimatedGas,
        nonce: currentNonce,
      );

      final signedTransaction = await blockchainService.client.signTransaction(
        credentials,
        transaction,
        chainId: BlockchainConfig.chainId,
      );

      // Convert Uint8List to hex string
      final signedTransactionHex = '0x${bytesToHex(signedTransaction)}';

      final txHash = await blockchainService.transaction.sendSignedTransaction(signedTransactionHex);

      state = state.copyWith(isSending: false, transactionHash: txHash, errorMessage: null);
      developer.log('Transaction successful, hash: $txHash', name: 'SendMoneyController');

    } catch (e, s) {
      state = state.copyWith(isSending: false, errorMessage: "Failed to send transaction: ${e.toString()}");
      developer.log('Failed to send transaction', name: 'SendMoneyController', error: e, stackTrace: s);
    }
  }

  // Helper to convert Uint8List to hex string (web3dart's bytesToHex is internal)
  String bytesToHex(List<int> bytes) {
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }
}

// Provider definition
final sendMoneyControllerProvider = NotifierProvider<SendMoneyController, SendMoneyState>(
  () => SendMoneyController(),
);
