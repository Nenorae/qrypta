// lib/src/core/transaction/state_machine/tx_intent.dart

import 'tx_state.dart';

/// Model intent transaksi on-chain yang dipersist sebelum broadcast (Phase 2.2).
/// Memastikan state transaksi tidak hilang saat aplikasi crash atau koneksi terputus.
class TxIntent {
  final String intentId;
  final String kind;
  final String ref;
  final String from;
  final String to;
  final String amount;
  final int? nonce;
  final String? txHash;
  final TxState state;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? failureReason;
  final BigInt? blockNumber;

  const TxIntent({
    required this.intentId,
    required this.kind,
    required this.ref,
    required this.from,
    required this.to,
    required this.amount,
    this.nonce,
    this.txHash,
    required this.state,
    required this.createdAt,
    required this.updatedAt,
    this.failureReason,
    this.blockNumber,
  });

  TxIntent copyWith({
    String? intentId,
    String? kind,
    String? ref,
    String? from,
    String? to,
    String? amount,
    int? nonce,
    String? txHash,
    TxState? state,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? failureReason,
    BigInt? blockNumber,
  }) {
    return TxIntent(
      intentId: intentId ?? this.intentId,
      kind: kind ?? this.kind,
      ref: ref ?? this.ref,
      from: from ?? this.from,
      to: to ?? this.to,
      amount: amount ?? this.amount,
      nonce: nonce ?? this.nonce,
      txHash: txHash ?? this.txHash,
      state: state ?? this.state,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      failureReason: failureReason ?? this.failureReason,
      blockNumber: blockNumber ?? this.blockNumber,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'intentId': intentId,
      'kind': kind,
      'ref': ref,
      'from': from,
      'to': to,
      'amount': amount,
      'nonce': nonce,
      'txHash': txHash,
      'state': state.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'failureReason': failureReason,
      'blockNumber': blockNumber?.toString(),
    };
  }

  factory TxIntent.fromJson(Map<String, dynamic> json) {
    final stateStr = json['state'] as String? ?? 'idle';
    final state = TxState.values.firstWhere(
      (s) => s.name.toLowerCase() == stateStr.toLowerCase(),
      orElse: () => TxState.idle,
    );

    return TxIntent(
      intentId: json['intentId'] as String? ?? '',
      kind: json['kind'] as String? ?? 'transfer',
      ref: json['ref'] as String? ?? '',
      from: json['from'] as String? ?? '',
      to: json['to'] as String? ?? '',
      amount: json['amount'] as String? ?? '0',
      nonce: json['nonce'] as int?,
      txHash: json['txHash'] as String?,
      state: state,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      failureReason: json['failureReason'] as String?,
      blockNumber: json['blockNumber'] != null
          ? BigInt.tryParse(json['blockNumber'].toString())
          : null,
    );
  }
}
