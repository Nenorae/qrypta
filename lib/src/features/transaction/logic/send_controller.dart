import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web3dart/web3dart.dart';
import 'package:qrypta/src/core/services/blockchain/blockchain_service.dart';
import 'package:qrypta/src/features/authentication/presentation/providers/auth_providers.dart';
import 'package:qrypta/src/core/data/models/token_model.dart';

class SendState {
  final bool isSending;
  final String? errorMessage;
  final String? transactionHash;

  SendState({
    this.isSending = false,
    this.errorMessage,
    this.transactionHash,
  });

  SendState copyWith({
    bool? isSending,
    String? errorMessage,
    String? transactionHash,
  }) {
    return SendState(
      isSending: isSending ?? this.isSending,
      errorMessage: errorMessage,
      transactionHash: transactionHash,
    );
  }
}

class SendController extends Notifier<SendState> {
  final TextEditingController addressController = TextEditingController();
  final TextEditingController amountController = TextEditingController();

  @override
  SendState build() {
    ref.onDispose(() {
      addressController.dispose();
      amountController.dispose();
    });
    return SendState();
  }

  bool _validateInput() {
    if (addressController.text.isEmpty) {
      state = state.copyWith(errorMessage: "Recipient address cannot be empty.");
      return false;
    }
    if (amountController.text.isEmpty || double.tryParse(amountController.text) == null || double.parse(amountController.text) <= 0) {
      state = state.copyWith(errorMessage: "Please enter a valid amount.");
      return false;
    }
    state = state.copyWith(errorMessage: null);
    return true;
  }

  Future<void> send({TokenModel? token}) async {
    developer.log('Attempting to send ${token?.symbol ?? 'ETH'}', name: 'SendController');
    if (!_validateInput()) return;

    state = state.copyWith(isSending: true, errorMessage: null, transactionHash: null);

    final blockchainService = ref.read(blockchainServiceProvider);
    final getPrivateKey = ref.read(getPrivateKeyUseCaseProvider);

    try {
      final privateKey = await getPrivateKey();
      if (privateKey == null) {
        state = state.copyWith(isSending: false, errorMessage: "Private key not found.");
        return;
      }

      final recipient = addressController.text;
      final amountDouble = double.parse(amountController.text);
      String txHash;

      if (token == null) {
        // SEND NATIVE ETH
        final amountInWei = EtherAmount.fromUnitAndValue(EtherUnit.ether, amountDouble);
        txHash = await blockchainService.nativeCurrency.sendTransaction(privateKey, EthereumAddress.fromHex(recipient), amountInWei);
      } else {
        // SEND ERC20 TOKEN (IDRT)
        final amountBigInt = BigInt.from(amountDouble * (BigInt.from(10).pow(token.decimals).toDouble()).toInt());
        txHash = await blockchainService.erc20.sendErc20Token(
          privateKey: privateKey,
          contractHex: token.contractAddress,
          recipientHex: recipient,
          amount: amountBigInt,
        );
      }

      state = state.copyWith(isSending: false, transactionHash: txHash, errorMessage: null);
      developer.log('Transaction successful, hash: $txHash', name: 'SendController');

    } catch (e, s) {
      state = state.copyWith(isSending: false, errorMessage: "Transaction failed: ${e.toString()}");
      developer.log('Transaction failed', name: 'SendController', error: e, stackTrace: s);
    }
  }
}

final sendControllerProvider = NotifierProvider<SendController, SendState>(
  () => SendController(),
);
