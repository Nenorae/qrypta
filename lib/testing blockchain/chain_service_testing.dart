import 'package:flutter/foundation.dart';
import 'package:web3dart/web3dart.dart';

class ChainService {
  final Web3Client _client;

  ChainService(this._client);

  Future<String> getBlockchainInfo() async {
    if (kDebugMode) {
      print('ChainService: Attempting to get block number...');
    }
    try {
      final blockNum = await _client.getBlockNumber();
      final result = "Koneksi berhasil! Nomor blok saat ini: $blockNum";
      if (kDebugMode) {
        print('ChainService: Success! $result');
      }
      return result;
    } catch (e) {
      final errorMessage = "Koneksi gagal: ${e.toString()}";
      if (kDebugMode) {
        print('ChainService: Error! $errorMessage');
      }
      return errorMessage;
    }
  }
}
