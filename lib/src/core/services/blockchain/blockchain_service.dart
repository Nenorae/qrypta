// lib/src/core/services/blockchain/blockchain_service.dart

import 'dart:developer' as developer;
import 'package:http/http.dart';
import 'package:qrypta/src/core/config/blockchain_config.dart'; // Sesuaikan path
import 'package:web3dart/web3dart.dart';

// Impor semua sub-service
import 'wallet_service.dart';
import 'native_currency_service.dart';
import 'erc20_service.dart';
import 'transaction_service.dart';

/// GATEWAY UTAMA untuk semua interaksi dengan blockchain.
///
/// Kelas ini menginisialisasi dan mendelegasikan panggilan ke sub-service
/// yang lebih spesifik. Di bagian lain aplikasi, Anda hanya perlu
/// mengimpor dan menggunakan kelas ini.
class BlockchainService {
  late final Web3Client _client;
  final String _serviceName = 'BlockchainService';

  // Deklarasi sub-service yang akan diakses
  late final WalletService wallet;
  late final NativeCurrencyService nativeCurrency;
  late final Erc20Service erc20;
  late final TransactionService transaction;

  BlockchainService() {
    // 1. Inisialisasi client utama
    _client = Web3Client(BlockchainConfig.rpcUrl, Client());
    developer.log(
      '[INFO] Gateway Initialized with RPC: ${BlockchainConfig.rpcUrl}',
      name: _serviceName,
    );

    // 2. Inisialisasi semua sub-service dengan client yang sama
    wallet = WalletService(); // Tidak butuh client
    nativeCurrency = NativeCurrencyService(_client);
    erc20 = Erc20Service(_client);
    transaction = TransactionService(_client);
  }

  // -- Core Client Getter (jika diperlukan akses langsung) --
  Web3Client get client => _client;

  // -- General Utilities --
  Future<void> dispose() async {
    developer.log(
      '[INFO] Disposing BlockchainService gateway client.',
      name: _serviceName,
    );
    await _client.dispose();
  }
}
