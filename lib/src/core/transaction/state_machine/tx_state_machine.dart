// lib/src/core/transaction/state_machine/tx_state_machine.dart

import 'package:qrypta/src/core/error/app_failure.dart';
import 'package:qrypta/src/core/utils/uuid_util.dart';
import 'tx_intent.dart';
import 'tx_intent_repository.dart';
import 'tx_state.dart';

/// State Machine pengelola siklus hidup satu transaksi on-chain.
/// Memastikan Golden Rule R2: Sukses hanya dapat dicapai setelah status confirmed otoritatif.
class TxStateMachine {
  final TxIntentRepository _repository;
  TxIntent? _currentIntent;

  TxStateMachine({required TxIntentRepository repository, TxIntent? initialIntent})
      : _repository = repository,
        _currentIntent = initialIntent;

  TxIntent? get currentIntent => _currentIntent;
  TxState get currentState => _currentIntent?.state ?? TxState.idle;

  /// Memulai intent transaksi baru dengan status awal preparing.
  Future<TxIntent> startIntent({
    required String kind,
    required String ref,
    required String from,
    required String to,
    required String amount,
    int? nonce,
  }) async {
    final now = DateTime.now();
    final intent = TxIntent(
      intentId: UuidUtil.generateV4(),
      kind: kind,
      ref: ref,
      from: from,
      to: to,
      amount: amount,
      nonce: nonce,
      state: TxState.preparing,
      createdAt: now,
      updatedAt: now,
    );

    _currentIntent = intent;
    await _repository.saveIntent(intent);
    return intent;
  }

  /// Melakukan transisi ke status baru. Melempar [ValidationFailure] jika transisi ilegal.
  Future<TxIntent> transitionTo(
    TxState nextState, {
    String? txHash,
    String? failureReason,
    BigInt? blockNumber,
  }) async {
    final intent = _currentIntent;
    if (intent == null) {
      throw const ValidationFailure('Tidak ada intent transaksi yang sedang aktif.');
    }

    if (!intent.state.canTransitionTo(nextState)) {
      throw ValidationFailure(
        'Transisi status transaksi ilegal: tidak dapat berpindah dari ${intent.state.name} ke ${nextState.name}.',
      );
    }

    final updated = intent.copyWith(
      state: nextState,
      txHash: txHash ?? intent.txHash,
      failureReason: failureReason ?? intent.failureReason,
      blockNumber: blockNumber ?? intent.blockNumber,
      updatedAt: DateTime.now(),
    );

    _currentIntent = updated;
    await _repository.saveIntent(updated);
    return updated;
  }

  /// Memuat intent yang tersimpan untuk melanjutkan tracking atau recovery.
  void resumeIntent(TxIntent intent) {
    _currentIntent = intent;
  }
}
