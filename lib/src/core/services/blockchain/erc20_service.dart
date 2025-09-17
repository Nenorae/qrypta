// lib/src/core/services/blockchain/erc20_service.dart

import 'dart:convert';
import 'dart:developer' as developer;
import 'package:qrypta/src/core/config/blockchain_config.dart'; // Sesuaikan path
import 'package:web3dart/web3dart.dart';

/// Mengelola interaksi dengan kontrak token standar ERC-20.
class Erc20Service {
  final Web3Client _client;
  final String _serviceName = 'Erc20Service';

  Erc20Service(this._client);

  DeployedContract _getErc20Contract(String contractHex) {
    final contractAddress = EthereumAddress.fromHex(contractHex);
    final abi = [
      'function balanceOf(address owner) view returns (uint256)',
      'function transfer(address to, uint256 value) returns (bool)',
    ];
    return DeployedContract(
      ContractAbi.fromJson(jsonEncode(abi), 'ERC20'),
      contractAddress,
    );
  }

  Future<BigInt> getErc20Balance(String contractHex, String ownerHex) async {
    developer.log(
      'Fetching ERC20 balance for $ownerHex on $contractHex',
      name: _serviceName,
    );
    try {
      final contract = _getErc20Contract(contractHex);
      final balanceFunction = contract.function('balanceOf');
      final ownerAddress = EthereumAddress.fromHex(ownerHex);
      final result = await _client.call(
        contract: contract,
        function: balanceFunction,
        params: [ownerAddress],
      );
      return result.first as BigInt;
    } catch (e, s) {
      developer.log(
        'Error fetching ERC20 balance',
        name: _serviceName,
        error: e,
        stackTrace: s,
      );
      rethrow;
    }
  }

  Future<String> sendErc20Token({
    required String privateKey,
    required String contractHex,
    required String recipientHex,
    required BigInt amount,
  }) async {
    developer.log('Sending $amount ERC20 to $recipientHex', name: _serviceName);
    try {
      final credentials = EthPrivateKey.fromHex(privateKey);
      final contract = _getErc20Contract(contractHex);
      final transferFunction = contract.function('transfer');
      final recipientAddress = EthereumAddress.fromHex(recipientHex);
      final transaction = Transaction.callContract(
        contract: contract,
        function: transferFunction,
        parameters: [recipientAddress, amount],
      );
      return await _client.sendTransaction(
        credentials,
        transaction,
        chainId: BlockchainConfig.chainId,
      );
    } catch (e, s) {
      developer.log(
        'Error sending ERC20 token',
        name: _serviceName,
        error: e,
        stackTrace: s,
      );
      rethrow;
    }
  }
}
