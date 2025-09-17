import 'package:flutter/foundation.dart';
import 'package:http/http.dart';
import 'package:web3dart/web3dart.dart';

class BlockchainService {
  // Alamat RPC dari Nginx load balancer yang mengarah ke node Besu
  final String _rpcUrl = "http://100.92.191.4:8556";

  late Web3Client _client;

  BlockchainService() {
    if (kDebugMode) {
      print('BlockchainService: Initializing with RPC URL: $_rpcUrl');
    }
    _client = Web3Client(_rpcUrl, Client());
  }

  Future<String> getBlockchainInfo() async {
    if (kDebugMode) {
      print('BlockchainService: Attempting to get block number...');
    }
    try {
      final blockNum = await _client.getBlockNumber();
      final result = "Koneksi berhasil! Nomor blok saat ini: $blockNum";
      if (kDebugMode) {
        print('BlockchainService: Success! $result');
      }
      return result;
    } catch (e) {
      final errorMessage = "Koneksi gagal: ${e.toString()}";
      if (kDebugMode) {
        print('BlockchainService: Error! $errorMessage');
      }
      return errorMessage;
    } finally {
      if (kDebugMode) {
        print('BlockchainService: Disposing client.');
      }
      await _client.dispose();
    }
  }
}
