// lib/src/core/services/blockchain/transaction_service.dart

import 'dart:async';
import 'dart:developer' as developer;
import 'package:web3dart/web3dart.dart';

/// Menyediakan utilitas untuk memeriksa, menunggu, dan memperkirakan biaya transaksi di blockchain.
class TransactionService {
  final Web3Client _client;
  final String _serviceName = 'TransactionService';

  TransactionService(this._client);

  /// Mengambil detail tanda terima (receipt) dari sebuah transaksi berdasarkan hash-nya.
  /// Mengembalikan `null` jika transaksi belum di-mine.
  Future<TransactionReceipt?> getTransactionReceipt(String txHash) async {
    developer.log(
      '[INFO] Fetching receipt for tx: $txHash',
      name: _serviceName,
    );
    try {
      return await _client.getTransactionReceipt(txHash);
    } catch (e, s) {
      developer.log(
        '[ERROR] Error fetching transaction receipt',
        name: _serviceName,
        error: e,
        stackTrace: s,
      );
      rethrow;
    }
  }

  /// Menunggu hingga sebuah transaksi di-mine dan mengembalikan tanda terimanya.
  /// Akan mengalami timeout jika menunggu terlalu lama.
  Future<TransactionReceipt> waitForTransactionReceipt(String txHash) async {
    developer.log(
      '[INFO] Waiting for receipt for tx: $txHash',
      name: _serviceName,
    );
    const pollInterval = Duration(seconds: 2);
    const timeout = Duration(minutes: 1); // Timeout setelah 1 menit
    final completer = Completer<TransactionReceipt>();

    // Polling secara periodik untuk memeriksa status transaksi
    Timer.periodic(pollInterval, (timer) async {
      if (completer.isCompleted) {
        timer.cancel();
        return;
      }
      final receipt = await getTransactionReceipt(txHash);
      if (receipt != null) {
        developer.log(
          '[INFO] Receipt found for tx: $txHash',
          name: _serviceName,
        );
        timer.cancel();
        completer.complete(receipt);
      }
    });

    return completer.future.timeout(
      timeout,
      onTimeout: () {
        if (!completer.isCompleted) {
          throw TimeoutException(
            'Transaction receipt lookup timed out for hash $txHash',
          );
        }
        return completer.future;
      },
    );
  }

  /// Mendapatkan nonce (jumlah transaksi yang telah dikirim) dari sebuah alamat.
  /// Penting untuk menandatangani transaksi baru.
  Future<int> getNonce(String addressHex) async {
    developer.log('[INFO] Fetching nonce for: $addressHex', name: _serviceName);
    try {
      final address = EthereumAddress.fromHex(addressHex);
      return await _client.getTransactionCount(address);
    } catch (e, s) {
      developer.log(
        '[ERROR] Error fetching nonce',
        name: _serviceName,
        error: e,
        stackTrace: s,
      );
      rethrow;
    }
  }

  /// Mengambil informasi detail sebuah transaksi dari blockchain berdasarkan hash-nya.
  Future<TransactionInformation?> getTransactionByHash(String txHash) async {
    developer.log(
      '[INFO] Fetching transaction info for: $txHash',
      name: _serviceName,
    );
    try {
      return await _client.getTransactionByHash(txHash);
    } catch (e, s) {
      developer.log(
        '[ERROR] Error fetching transaction info',
        name: _serviceName,
        error: e,
        stackTrace: s,
      );
      rethrow;
    }
  }

  /// Memperkirakan total biaya (gas fee) dalam Wei untuk sebuah transaksi.
  /// Ini adalah hasil dari `gasPrice * estimatedGas`.
  Future<BigInt> estimateTransactionFee({
    required EthereumAddress to,
    EtherAmount? value,
    // Tambahkan parameter lain jika diperlukan, seperti `data` untuk interaksi kontrak
  }) async {
    developer.log('[INFO] Estimating fee to: ${to.hex}', name: _serviceName);
    try {
      final gasPrice = await _client.getGasPrice();
      final estimatedGasLimit = await _client.estimateGas(to: to, value: value);
      final totalFee = gasPrice.getInWei * estimatedGasLimit;
      developer.log('[INFO] Estimated fee: $totalFee Wei', name: _serviceName);
      return totalFee;
    } catch (e, s) {
      developer.log(
        '[ERROR] Error estimating fee',
        name: _serviceName,
        error: e,
        stackTrace: s,
      );
      rethrow;
    }
  }
}
