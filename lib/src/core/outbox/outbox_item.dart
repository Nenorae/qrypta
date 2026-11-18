// lib/src/core/outbox/outbox_item.dart

import 'dart:math';

/// Status item di antrean Outbox (Phase 2.3).
enum OutboxStatus {
  pending,
  sent,
  rejected,
  needs_attention;

  bool get isDone => this == sent || this == rejected;
  bool get canRetry => this == pending;
}

/// Model rekaman outbox untuk sinkronisasi audit dan consent ke server.
/// [id] berfungsi ganda sebagai primary key lokal dan HTTP Idempotency-Key.
class OutboxItem {
  final String id;
  final String type;
  final String? endpoint;
  final Map<String, dynamic> payload;
  final int attempts;
  final DateTime nextAttemptAt;
  final OutboxStatus status;
  final String? lastError;
  final DateTime createdAt;
  final DateTime? sentAt;
  final Map<String, dynamic>? responsePayload;

  const OutboxItem({
    required this.id,
    required this.type,
    this.endpoint,
    required this.payload,
    this.attempts = 0,
    required this.nextAttemptAt,
    this.status = OutboxStatus.pending,
    this.lastError,
    required this.createdAt,
    this.sentAt,
    this.responsePayload,
  });

  /// Menghitung interval backoff eksponensial: 5s -> 10s -> 20s ... maks 15 menit (900s).
  static Duration calculateBackoff(int attempts) {
    if (attempts <= 0) return const Duration(seconds: 5);
    final seconds = (5 * pow(2, attempts - 1)).clamp(5, 900).toInt();
    return Duration(seconds: seconds);
  }

  OutboxItem copyWith({
    String? id,
    String? type,
    String? endpoint,
    Map<String, dynamic>? payload,
    int? attempts,
    DateTime? nextAttemptAt,
    OutboxStatus? status,
    String? lastError,
    DateTime? createdAt,
    DateTime? sentAt,
    Map<String, dynamic>? responsePayload,
  }) {
    return OutboxItem(
      id: id ?? this.id,
      type: type ?? this.type,
      endpoint: endpoint ?? this.endpoint,
      payload: payload ?? this.payload,
      attempts: attempts ?? this.attempts,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      status: status ?? this.status,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
      sentAt: sentAt ?? this.sentAt,
      responsePayload: responsePayload ?? this.responsePayload,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'endpoint': endpoint,
      'payload': payload,
      'attempts': attempts,
      'nextAttemptAt': nextAttemptAt.toIso8601String(),
      'status': status.name,
      'lastError': lastError,
      'createdAt': createdAt.toIso8601String(),
      'sentAt': sentAt?.toIso8601String(),
      'responsePayload': responsePayload,
    };
  }

  factory OutboxItem.fromJson(Map<String, dynamic> json) {
    final statusStr = json['status'] as String? ?? 'pending';
    final status = OutboxStatus.values.firstWhere(
      (s) => s.name.toLowerCase() == statusStr.toLowerCase(),
      orElse: () => OutboxStatus.pending,
    );

    return OutboxItem(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      endpoint: json['endpoint'] as String?,
      payload: json['payload'] is Map
          ? Map<String, dynamic>.from(json['payload'] as Map)
          : {},
      attempts: json['attempts'] as int? ?? 0,
      nextAttemptAt: json['nextAttemptAt'] != null
          ? DateTime.tryParse(json['nextAttemptAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      status: status,
      lastError: json['lastError'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      sentAt: json['sentAt'] != null
          ? DateTime.tryParse(json['sentAt'] as String)
          : null,
      responsePayload: json['responsePayload'] is Map
          ? Map<String, dynamic>.from(json['responsePayload'] as Map)
          : null,
    );
  }
}
