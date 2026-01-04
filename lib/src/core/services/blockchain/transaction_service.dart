// lib/src/core/services/blockchain/transaction_service.dart

import 'dart:async';
import 'dart:developer' as developer;
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:web3dart/web3dart.dart';
import 'package:qrypta/src/core/graphql/queries.dart'; // Import queries.dart for the mutation

// Model untuk satu transaksi dari GraphQL
class Transaction {
  final String hash;
  final int blockNumber;
  final String fromAddress;
  final String toAddress;
  final String value; // Value dalam WEI, tetap String untuk presisi

  Transaction({
    required this.hash,
    required this.blockNumber,
    required this.fromAddress,
    required this.toAddress,
    required this.value,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      hash: json['hash'] ?? 'N/A',
      blockNumber: int.tryParse(json['blockNumber']?.toString() ?? '0') ?? 0,
      fromAddress: json['fromAddress'] ?? 'N/A',
      toAddress: json['toAddress'] ?? 'N/A',
      value: json['value'] ?? '0',
    );
  }
}

// Model untuk halaman transaksi yang dipaginasi dari GraphQL
class TransactionPage {
  final List<Transaction> transactions;
  final int totalCount;

  TransactionPage({required this.transactions, required this.totalCount});

  factory TransactionPage.fromJson(Map<String, dynamic> json) {
    var txList = json['transactions'] as List;
    List<Transaction> transactions =
        txList.map((i) => Transaction.fromJson(i)).toList();

    return TransactionPage(
      transactions: transactions,
      totalCount: json['totalCount'] ?? 0,
    );
  }
}

class TransactionService {
  final Web3Client _client;
  final GraphQLClient _graphQLClient;
  final String _serviceName = 'TransactionService';

  // Konstruktor diperbarui untuk menerima kedua client
  TransactionService(this._client, this._graphQLClient);

  /// Mengirim raw signed transaction hex melalui GraphQL mutation.
  Future<String> sendSignedTransaction(String signedTransactionHex) async {
    developer.log('[INFO] Sending signed transaction via GraphQL', name: _serviceName);

    final MutationOptions options = MutationOptions(
      document: gql(sendRawTransactionMutation),
      variables: <String, dynamic>{
        'signedTransactionHex': signedTransactionHex,
      },
      fetchPolicy: FetchPolicy.networkOnly, // Always send to network
    );

    try {
      final QueryResult result = await _graphQLClient.mutate(options);

      if (result.hasException) {
        developer.log(
          '[ERROR] GraphQL mutation exception: ${result.exception.toString()}',
          name: _serviceName,
          error: result.exception,
        );
        throw result.exception!;
      }

      final String? txHash = result.data?['sendTransaction']?['txHash'] as String?;

      if (txHash == null || txHash.isEmpty) {
        developer.log('[ERROR] Transaction hash not returned by GraphQL server.', name: _serviceName);
        throw Exception('Transaction hash not returned by GraphQL server.');
      }
      developer.log('[INFO] Transaction sent, hash: $txHash', name: _serviceName);
      return txHash;
    } catch (e, s) {
      developer.log(
        '[ERROR] Error sending signed transaction',
        name: _serviceName,
        error: e,
        stackTrace: s,
      );
      rethrow;
    }
  }

  /// Mengambil riwayat transaksi dari blockscan GraphQL.
  Future<TransactionPage> getRecentTransactions({
    required String userAddressHex,
    int page = 1,
    int limit = 20,
  }) async {
    developer.log(
      '[INFO] Fetching recent transactions for $userAddressHex from GraphQL (page: $page, limit: $limit)',
      name: _serviceName,
    );

    final String query = r'''
      query GetTransactions($address: String!, $page: Int, $limit: Int) {
        getTransactionsByAddress(address: $address, page: $page, limit: $limit) {
          transactions {
            hash
            blockNumber
            fromAddress
            toAddress
            value
          }
          totalCount
        }
      }
    ''';

    final options = QueryOptions(
      document: gql(query),
      variables: {
        'address': userAddressHex,
        'page': page,
        'limit': limit,
      },
      fetchPolicy: FetchPolicy.networkOnly, // Selalu ambil dari jaringan
    );

    try {
      final result = await _graphQLClient.query(options);

      if (result.hasException) {
        throw result.exception!;
      }

      if (result.data == null) {
        developer.log('[WARN] GraphQL returned null data', name: _serviceName);
        return TransactionPage(transactions: [], totalCount: 0);
      }

      final data = result.data!['getTransactionsByAddress'];
      final pageData = TransactionPage.fromJson(data);
      developer.log(
        '[INFO] Found ${pageData.transactions.length} transactions, total: ${pageData.totalCount}',
        name: _serviceName,
      );
      return pageData;
    } catch (e, s) {
      developer.log(
        '[ERROR] Error fetching recent transactions from GraphQL',
        name: _serviceName,
        error: e,
        stackTrace: s,
      );
      // Mengembalikan halaman kosong jika terjadi error
      return TransactionPage(transactions: [], totalCount: 0);
    }
  }

  /// Mengambil detail transaksi berdasarkan hash dari blockscan GraphQL.
  Future<Transaction?> getTransactionByHash(String txHash) async {
    developer.log('[INFO] Fetching tx by hash from GraphQL: $txHash', name: _serviceName);
    
    final String query = r'''
      query GetTransactionByHash($hash: String!) {
        getTransactionByHash(hash: $hash) {
          hash
          blockNumber
          fromAddress
          toAddress
          value
        }
      }
    ''';
    
    final options = QueryOptions(
      document: gql(query),
      variables: {'hash': txHash},
      fetchPolicy: FetchPolicy.networkOnly,
    );

    try {
      final result = await _graphQLClient.query(options);

      if (result.hasException) {
        throw result.exception!;
      }
      
      if (result.data == null || result.data!['getTransactionByHash'] == null) {
        developer.log('[INFO] Tx not found in GraphQL: $txHash', name: _serviceName);
        return null;
      }
      
      return Transaction.fromJson(result.data!['getTransactionByHash']);
    } catch (e, s) {
       developer.log(
        '[ERROR] Error fetching transaction by hash from GraphQL',
        name: _serviceName,
        error: e,
        stackTrace: s,
      );
      return null;
    }
  }


  // --- Fungsi di bawah ini tetap menggunakan Web3Client untuk interaksi langsung ke blockchain ---

  Future<TransactionReceipt?> getTransactionReceipt(String txHash) async {
    try {
      return await _client.getTransactionReceipt(txHash);
    } catch (e, s) {
      developer.log(
        '[ERROR] Receipt fetch error',
        name: _serviceName,
        error: e,
        stackTrace: s,
      );
      rethrow;
    }
  }

  Future<TransactionReceipt> waitForTransactionReceipt(String txHash) async {
    developer.log('[INFO] Waiting for receipt: $txHash', name: _serviceName);
    const pollInterval = Duration(seconds: 2);
    const timeout = Duration(minutes: 1);
    final completer = Completer<TransactionReceipt>();

    final timer = Timer.periodic(pollInterval, (timer) async {
      if (completer.isCompleted) {
        timer.cancel();
        return;
      }
      try {
        final receipt = await getTransactionReceipt(txHash);
        if (receipt != null) {
          timer.cancel();
          if (!completer.isCompleted) completer.complete(receipt);
        }
      } catch (_) {}
    });

    return completer.future.timeout(
      timeout,
      onTimeout: () {
        timer.cancel();
        throw TimeoutException('Timeout waiting for receipt $txHash');
      },
    );
  }

  Future<int> getNonce(String addressHex) async {
    final address = EthereumAddress.fromHex(addressHex);
    return await _client.getTransactionCount(address);
  }

  Future<BigInt> estimateTransactionFee({
    required EthereumAddress to,
    EtherAmount? value,
  }) async {
    final gasPrice = await _client.getGasPrice();
    final estimatedGas = BigInt.from(21000); // Standard transfer
    return gasPrice.getInWei * estimatedGas;
  }
}
