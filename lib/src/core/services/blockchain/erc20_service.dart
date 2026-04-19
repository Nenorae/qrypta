import 'dart:developer' as developer;
import 'package:qrypta/src/core/config/blockchain_config.dart';
import 'package:web3dart/web3dart.dart';

/// Layanan untuk mengelola interaksi dengan kontrak token standar ERC-20.
class Erc20Service {
  final Web3Client _client;
  final String _serviceName = 'Erc20Service';

  Erc20Service(this._client);

  /// Mengembalikan instance kontrak ERC-20 berdasarkan alamat kontrak dengan ABI JSON murni.
  DeployedContract _getErc20Contract(String contractHex) {
    developer.log('--- INIT CONTRACT ---', name: _serviceName);
    developer.log('Raw contractHex input: "$contractHex"', name: _serviceName);

    if (contractHex.isEmpty) {
      developer.log('CRITICAL ERROR: contractHex KOSONG!', name: _serviceName);
    } else if (!contractHex.startsWith('0x')) {
      developer.log(
        'CRITICAL WARNING: contractHex tidak diawali dengan 0x! (Panjang: ${contractHex.length})',
        name: _serviceName,
      );
    }

    final contractAddress = EthereumAddress.fromHex(contractHex);
    developer.log(
      'Parsed EthereumAddress: ${contractAddress.hex}',
      name: _serviceName,
    );

    // ABI FORMAT JSON STANDAR ETHEREUM. JANGAN DIUBAH KE ARRAY STRING!
    final abiString = '''
    [
      {
        "constant": true,
        "inputs": [{"name": "owner", "type": "address"}],
        "name": "balanceOf",
        "outputs": [{"name": "", "type": "uint256"}],
        "type": "function"
      },
      {
        "constant": false,
        "inputs": [
          {"name": "to", "type": "address"},
          {"name": "value", "type": "uint256"}
        ],
        "name": "transfer",
        "outputs": [{"name": "", "type": "bool"}],
        "type": "function"
      },
      {
        "constant": true,
        "inputs": [],
        "name": "name",
        "outputs": [{"name": "", "type": "string"}],
        "type": "function"
      },
      {
        "constant": true,
        "inputs": [],
        "name": "symbol",
        "outputs": [{"name": "", "type": "string"}],
        "type": "function"
      },
      {
        "constant": true,
        "inputs": [],
        "name": "decimals",
        "outputs": [{"name": "", "type": "uint8"}],
        "type": "function"
      }
    ]
    ''';

    return DeployedContract(
      ContractAbi.fromJson(abiString, 'ERC20'),
      contractAddress,
    );
  }

  /// Mengambil saldo token ERC-20 dari alamat pengguna tertentu.
  Future<BigInt> getErc20Balance(String contractHex, String ownerHex) async {
    developer.log(
      '========== START getErc20Balance ==========',
      name: _serviceName,
    );
    developer.log('Target Contract: $contractHex', name: _serviceName);
    developer.log('Target Owner: $ownerHex', name: _serviceName);

    try {
      final contract = _getErc20Contract(contractHex);
      final balanceFunction = contract.function('balanceOf');

      developer.log(
        'Parsing ownerHex to EthereumAddress...',
        name: _serviceName,
      );
      final ownerAddress = EthereumAddress.fromHex(ownerHex);

      developer.log(
        'EXECUTING RPC CALL: eth_call (balanceOf)',
        name: _serviceName,
      );
      final result = await _client.call(
        contract: contract,
        function: balanceFunction,
        params: [ownerAddress],
      );

      if (result.isEmpty) {
        developer.log(
          'WARNING: RPC mengembalikan nilai kosong. Cek apakah ini jebakan Proxy Admin!',
          name: _serviceName,
        );
        return BigInt.zero;
      }

      final balance = result.first as BigInt;
      developer.log(
        'RPC CALL SUCCESS. Balance (BigInt raw): $balance',
        name: _serviceName,
      );
      developer.log(
        '========== END getErc20Balance ==========',
        name: _serviceName,
      );

      return balance;
    } catch (e, s) {
      developer.log(
        '========== ERROR in getErc20Balance ==========',
        name: _serviceName,
      );
      developer.log('Error Type: ${e.runtimeType}', name: _serviceName);
      developer.log('Error Message: $e', name: _serviceName);
      _diagnoseCommonErrors(e);
      developer.log('Stack Trace:', name: _serviceName, stackTrace: s);
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
    developer.log(
      '========== START sendErc20Token ==========',
      name: _serviceName,
    );
    developer.log('Amount to send (raw): $amount', name: _serviceName);
    developer.log('To Recipient: $recipientHex', name: _serviceName);

    try {
      developer.log('Parsing Credentials...', name: _serviceName);
      final credentials = EthPrivateKey.fromHex(privateKey);

      final contract = _getErc20Contract(contractHex);
      final transferFunction = contract.function('transfer');

      developer.log('Parsing Recipient Address...', name: _serviceName);
      final recipientAddress = EthereumAddress.fromHex(recipientHex);

      developer.log('Building Transaction...', name: _serviceName);
      final transaction = Transaction.callContract(
        contract: contract,
        function: transferFunction,
        parameters: [recipientAddress, amount],
      );

      developer.log(
        'EXECUTING RPC CALL: eth_sendRawTransaction',
        name: _serviceName,
      );
      final txHash = await _client.sendTransaction(
        credentials,
        transaction,
        chainId: BlockchainConfig.chainId,
      );

      developer.log('TRANSACTION SUCCESS. Hash: $txHash', name: _serviceName);
      developer.log(
        '========== END sendErc20Token ==========',
        name: _serviceName,
      );
      return txHash;
    } catch (e, s) {
      developer.log(
        '========== ERROR in sendErc20Token ==========',
        name: _serviceName,
      );
      developer.log('Error Type: ${e.runtimeType}', name: _serviceName);
      developer.log('Error Message: $e', name: _serviceName);
      _diagnoseCommonErrors(e);
      developer.log('Stack Trace:', name: _serviceName, stackTrace: s);
      rethrow;
    }
  }

  /// Mengambil detail dasar token (nama, simbol, desimal).
  Future<Map<String, dynamic>> getTokenDetails(String contractHex) async {
    developer.log(
      '========== START getTokenDetails ==========',
      name: _serviceName,
    );
    developer.log('Target Contract: $contractHex', name: _serviceName);

    try {
      final contract = _getErc20Contract(contractHex);
      final nameFunction = contract.function('name');
      final symbolFunction = contract.function('symbol');
      final decimalsFunction = contract.function('decimals');

      developer.log(
        'EXECUTING RPC CALLS: name, symbol, decimals',
        name: _serviceName,
      );
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

      developer.log(
        'RESULTS: Name="$name", Symbol="$symbol", Decimals=$decimals',
        name: _serviceName,
      );
      developer.log(
        '========== END getTokenDetails ==========',
        name: _serviceName,
      );

      return {'name': name, 'symbol': symbol, 'decimals': decimals};
    } catch (e, s) {
      developer.log(
        '========== ERROR in getTokenDetails ==========',
        name: _serviceName,
      );
      developer.log('Error Type: ${e.runtimeType}', name: _serviceName);
      developer.log('Error Message: $e', name: _serviceName);
      _diagnoseCommonErrors(e);
      developer.log('Stack Trace:', name: _serviceName, stackTrace: s);
      rethrow;
    }
  }

  /// Memeriksa apakah alamat kontrak valid dan merespons fungsi ERC-20.
  Future<bool> validateTokenContract(String contractHex) async {
    developer.log(
      '========== START validateTokenContract ==========',
      name: _serviceName,
    );
    developer.log('Target Contract: $contractHex', name: _serviceName);

    try {
      final contract = _getErc20Contract(contractHex);
      final nameFunction = contract.function('name');

      developer.log('EXECUTING RPC CALL: eth_call (name)', name: _serviceName);
      await _client.call(
        contract: contract,
        function: nameFunction,
        params: [],
      );

      developer.log(
        'VALIDATION SUCCESS: Kontrak merespons fungsi ERC20',
        name: _serviceName,
      );
      developer.log(
        '========== END validateTokenContract ==========',
        name: _serviceName,
      );
      return true;
    } catch (e) {
      developer.log(
        '========== VALIDATION FAILED ==========',
        name: _serviceName,
      );
      developer.log('Error Type: ${e.runtimeType}', name: _serviceName);
      developer.log('Error Message: $e', name: _serviceName);
      developer.log(
        'DIAGNOSIS: Alamat ini bukan kontrak ERC20 yang valid, mati, atau tidak ter-deploy dengan benar.',
        name: _serviceName,
      );
      return false;
    }
  }

  /// Fungsi internal untuk menebak penyebab error secara otomatis
  void _diagnoseCommonErrors(Object e) {
    final errorString = e.toString().toLowerCase();
    if (e is FormatException) {
      developer.log(
        'DIAGNOSIS OTOMATIS: String Hex cacat. Periksa file .env dari spasi atau karakter ilegal.',
        name: _serviceName,
      );
    } else if (errorString.contains('socket') ||
        errorString.contains('connection refused') ||
        errorString.contains('timeout')) {
      developer.log(
        'DIAGNOSIS OTOMATIS: Jaringan RPC mati/tidak terjangkau. Jika pakai Emulator, pastikan IP bukan 127.0.0.1 tetapi 10.0.2.2 atau IP Lokal.',
        name: _serviceName,
      );
    } else if (errorString.contains('rpcerror')) {
      developer.log(
        'DIAGNOSIS OTOMATIS: Node merespons tapi menolak eksekusi. Kontrak mungkin tidak ada di alamat tersebut.',
        name: _serviceName,
      );
    }
  }
}
