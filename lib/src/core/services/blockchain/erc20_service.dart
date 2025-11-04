import 'dart:convert';
import 'dart:developer' as developer;
import 'package:qrypta/src/core/config/blockchain_config.dart';
import 'package:web3dart/web3dart.dart';

/// Layanan untuk mengelola interaksi dengan kontrak token standar ERC-20.
class Erc20Service {
  final Web3Client _client;
  final String _serviceName = 'Erc20Service';

  Erc20Service(this._client);

  /// Mengembalikan instance kontrak ERC-20 berdasarkan alamat kontrak.
  DeployedContract _getErc20Contract(String contractHex) {
    final contractAddress = EthereumAddress.fromHex(contractHex);
    final abi = [
      'function balanceOf(address owner) view returns (uint256)',
      'function transfer(address to, uint256 value) returns (bool)',
      'function name() view returns (string)',
      'function symbol() view returns (string)',
      'function decimals() view returns (uint8)',
    ];
    return DeployedContract(
      ContractAbi.fromJson(jsonEncode(abi), 'ERC20'),
      contractAddress,
    );
  }

  /// Mengambil saldo token ERC-20 dari alamat pengguna tertentu.
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

  /// Mengirim token ERC-20 dari akun pengirim ke penerima.
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

  /// Mengambil detail dasar token seperti nama, simbol, dan desimal.
  Future<Map<String, dynamic>> getTokenDetails(String contractHex) async {
    developer.log(
      'Fetching token details for $contractHex',
      name: _serviceName,
    );
    try {
      final contract = _getErc20Contract(contractHex);
      final nameFunction = contract.function('name');
      final symbolFunction = contract.function('symbol');
      final decimalsFunction = contract.function('decimals');

      final results = await Future.wait([
        _client.call(contract: contract, function: nameFunction, params: []),
        _client.call(contract: contract, function: symbolFunction, params: []),
        _client.call(
          contract: contract,
          function: decimalsFunction,
          params: [],
        ),
      ]);

      final name = results[0].first as String;
      final symbol = results[1].first as String;
      final decimals = (results[2].first as BigInt).toInt();

      return {'name': name, 'symbol': symbol, 'decimals': decimals};
    } catch (e, s) {
      developer.log(
        'Error fetching token details for $contractHex',
        name: _serviceName,
        error: e,
        stackTrace: s,
      );
      rethrow;
    }
  }

  /// Memeriksa apakah alamat kontrak valid dan sesuai standar ERC-20.
  Future<bool> validateTokenContract(String contractHex) async {
    developer.log('Validating contract $contractHex', name: _serviceName);
    try {
      final contract = _getErc20Contract(contractHex);
      final nameFunction = contract.function('name');
      await _client.call(
        contract: contract,
        function: nameFunction,
        params: [],
      );
      return true;
    } catch (e) {
      developer.log(
        'Contract $contractHex is NOT a valid ERC20 token',
        name: _serviceName,
        error: e,
      );
      return false;
    }
  }
}
