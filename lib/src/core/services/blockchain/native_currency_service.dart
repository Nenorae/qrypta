// lib/src/core/services/blockchain/native_currency_service.dart

import 'dart:developer' as developer;
import 'package:qrypta/src/core/config/blockchain_config.dart'; // Sesuaikan path
import 'package:web3dart/web3dart.dart';

/// Mengelola interaksi dengan mata uang native blockchain (mis. ETH).
class NativeCurrencyService {
  final Web3Client _client;
  final String _serviceName = 'NativeCurrencyService';

  NativeCurrencyService(this._client);

  Future<EtherAmount> getBalance(EthereumAddress address) async {
    developer.log(
      '[INFO] Fetching balance for: ${address.hex}',
      name: _serviceName,
    );
    try {
      return await _client.getBalance(address);
    } catch (e, s) {
      developer.log(
        '[ERROR] Error fetching balance',
        name: _serviceName,
        error: e,
        stackTrace: s,
      );
      rethrow;
    }
  }

  Future<String> sendTransaction(
    String privateKey,
    EthereumAddress receiver,
    EtherAmount amount,
  ) async {
    developer.log(
      '[INFO] Sending ${amount.getInEther} to ${receiver.hex}',
      name: _serviceName,
    );
    try {
      final credentials = EthPrivateKey.fromHex(privateKey);
      final txHash = await _client.sendTransaction(
        credentials,
        Transaction(to: receiver, value: amount),
        chainId: BlockchainConfig.chainId,
      );
      return txHash;
    } catch (e, s) {
      developer.log(
        '[ERROR] Error sending transaction',
        name: _serviceName,
        error: e,
        stackTrace: s,
      );
      rethrow;
    }
  }
}
