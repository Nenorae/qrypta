// lib/src/core/transaction/state_machine/tx_recovery_service.dart

import 'dart:async';
import 'dart:developer' as developer;
import 'package:web3dart/web3dart.dart';
import 'package:qrypta/src/core/error/app_failure.dart';
import 'tx_intent.dart';
import 'tx_intent_repository.dart';
import 'tx_state.dart';
import 'tx_state_machine.dart';

/// Service untuk memulihkan transaksi yang terputus (recovering pending intents)
/// dan melakukan polling receipt transaksi on-chain secara terstruktur (Phase 2.2).
class TxRecoveryService {
  final TxIntentRepository _repository;
  final Web3Client? _web3Client;
  static const String _logTag = 'TxRecoveryService';

  TxRecoveryService({
    required TxIntentRepository repository,
    Web3Client? web3Client,
  })  : _repository = repository,
        _web3Client = web3Client;

  /// Memproses semua intent berstatus broadcasting atau pending saat aplikasi dibuka ulang.
  Future<List<TxIntent>> recoverUnresolvedIntents({int timeoutSeconds = 120}) async {
    final unresolved = await _repository.getUnresolvedIntents();
    final List<TxIntent> recovered = [];

    for (final intent in unresolved) {
      final machine = TxStateMachine(repository: _repository, initialIntent: intent);

      // Transaksi yang mati saat broadcasting tanpa hash
      if (intent.txHash == null || intent.txHash!.isEmpty) {
        if (intent.state == TxState.broadcasting) {
          final updated = await machine.transitionTo(
            TxState.failed,
            failureReason: 'Aplikasi terhenti sebelum txHash diterima dari node RPC.',
          );
          recovered.add(updated);
        }
        continue;
      }

      final txHash = intent.txHash!;
      if (_web3Client == null) {
        developer.log('Web3Client tidak tersedia untuk memverifikasi receipt: $txHash', name: _logTag);
        recovered.add(intent);
        continue;
      }

      try {
        final receipt = await _web3Client.getTransactionReceipt(txHash);
        if (receipt != null) {
          if (receipt.status == true) {
            final updated = await machine.transitionTo(
              TxState.confirmed,
              blockNumber: BigInt.from(receipt.blockNumber.blockNum),
            );
            recovered.add(updated);
          } else {
            final updated = await machine.transitionTo(
              TxState.reverted,
              failureReason: 'EVM transaction execution reverted (status 0x0).',
            );
            recovered.add(updated);
          }
        } else {
          // Receipt belum ada di node
          final elapsed = DateTime.now().difference(intent.updatedAt).inSeconds;
          if (elapsed >= timeoutSeconds && intent.state != TxState.timeout) {
            final updated = await machine.transitionTo(
              TxState.timeout,
              failureReason: 'Receipt belum terbit setelah $elapsed detik (TxPendingTimeout).',
            );
            recovered.add(updated);
          } else {
            recovered.add(intent);
          }
        }
      } on Object catch (e) {
        developer.log('Gagal memeriksa receipt saat recovery ($txHash): $e', name: _logTag);
        recovered.add(intent);
      }
    }

    return recovered;
  }

  /// Melakukan polling receipt transaksi dengan interval 2s dan timeout 120s.
  /// Melempar [TxPendingTimeout] atau [TxReverted] jika transaksi tidak sukses.
  Future<TransactionReceipt> pollReceiptUntilMined(
    String txHash, {
    Duration pollInterval = const Duration(seconds: 2),
    Duration timeout = const Duration(seconds: 120),
  }) async {
    final client = _web3Client;
    if (client == null) {
      throw const NetworkUnreachable('Web3Client tidak diinisialisasi untuk polling receipt.');
    }

    final completer = Completer<TransactionReceipt>();
    final stopwatch = Stopwatch()..start();

    Timer? timer;
    timer = Timer.periodic(pollInterval, (t) async {
      if (completer.isCompleted) {
        t.cancel();
        return;
      }

      if (stopwatch.elapsed >= timeout) {
        t.cancel();
        if (!completer.isCompleted) {
          completer.completeError(
            TxPendingTimeout('Batas waktu polling receipt 120 detik terlampaui.', txHash),
          );
        }
        return;
      }

      try {
        final receipt = await client.getTransactionReceipt(txHash);
        if (receipt != null) {
          t.cancel();
          if (!completer.isCompleted) {
            if (receipt.status == true) {
              completer.complete(receipt);
            } else {
              completer.completeError(
                TxReverted('Transaksi dieksekusi tetapi di-revert oleh smart contract.', txHash),
              );
            }
          }
        }
      } on Object catch (e) {
        // Log kegagalan transient saat polling tanpa mematikan loop
        developer.log('Polling receipt error transient ($txHash): $e', name: _logTag);
      }
    });

    return completer.future;
  }
}
