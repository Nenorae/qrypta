// lib/src/core/services/blockchain/blockchain_service.dart

import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:http/http.dart';
import 'package:qrypta/src/core/config/blockchain_config.dart'; // Sesuaikan path
import 'package:qrypta/src/core/graphql/graphql_provider.dart'; // Impor untuk mengakses graphqlClientProvider
import 'package:web3dart/web3dart.dart';

// Impor semua sub-service
import 'wallet_service.dart';
import 'native_currency_service.dart';
import 'erc20_service.dart';
import 'transaction_service.dart';

/// Provider tunggal untuk BlockchainService
final blockchainServiceProvider = Provider<BlockchainService>((ref) {
  final graphQLClient = ref.watch(graphqlClientProvider);
  final client = Web3Client(BlockchainConfig.rpcUrl, Client());
  
  final service = BlockchainService(client, graphQLClient);

  ref.onDispose(() => service.dispose());

  return service;
});

/// GATEWAY UTAMA untuk semua interaksi dengan blockchain.
///
/// Kelas ini menginisialisasi dan mendelegasikan panggilan ke sub-service
/// yang lebih spesifik. Di bagian lain aplikasi, Anda hanya perlu
/// menggunakan `blockchainServiceProvider`.
class BlockchainService {
  late final Web3Client _client;
  final String _serviceName = 'BlockchainService';

  // Deklarasi sub-service yang akan diakses
  late final WalletService wallet;
  late final NativeCurrencyService nativeCurrency;
  late final Erc20Service erc20;
  late final TransactionService transaction;

  // Konstruktor diubah untuk menerima dependensi
  BlockchainService(this._client, GraphQLClient graphQLClient) {
    developer.log(
      '[INFO] Gateway Initialized with RPC: ${BlockchainConfig.rpcUrl}',
      name: _serviceName,
    );

    // Inisialisasi semua sub-service dengan client yang sesuai
    wallet = WalletService(); // Tidak butuh client
    nativeCurrency = NativeCurrencyService(_client);
    erc20 = Erc20Service(_client);
    // Sekarang TransactionService menerima kedua client
    transaction = TransactionService(_client, graphQLClient);
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
