// lib/src/core/outbox/outbox_worker.dart

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:qrypta/src/core/config/app_config.dart';
import 'outbox_item.dart';
import 'outbox_repository.dart';

/// Worker untuk memproses antrean Outbox secara asinkron dengan backoff eksponensial (Phase 2.3).
/// Memastikan idempotency pada sisi server via header HTTP `Idempotency-Key`.
class OutboxWorker {
  final OutboxRepository _repository;
  final http.Client _client;
  final String _baseUrl;
  final int maxAttempts;
  static const String _logTag = 'OutboxWorker';

  Timer? _periodicTimer;
  bool _isProcessing = false;

  OutboxWorker({
    required OutboxRepository repository,
    http.Client? client,
    String? baseUrl,
    this.maxAttempts = 5,
  })  : _repository = repository,
        _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? AppConfig.ezsignUrl;

  /// Memulai sinkronisasi periodik (default setiap 30 detik).
  void startPeriodicSync({Duration interval = const Duration(seconds: 30)}) {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(interval, (_) => processPendingQueue());
  }

  /// Menghentikan sinkronisasi periodik.
  void stopPeriodicSync() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  /// Memproses item pending yang sudah jatuh tempo.
  Future<int> processPendingQueue({DateTime? now}) async {
    if (_isProcessing) return 0;
    _isProcessing = true;

    int processedCount = 0;
    try {
      final dueItems = await _repository.getPendingDueItems(now: now);
      for (final item in dueItems) {
        final success = await _dispatchItem(item);
        if (success) processedCount++;
      }
    } finally {
      _isProcessing = false;
    }

    return processedCount;
  }

  /// Mengirim satu item outbox ke server ezsign-core / middleware.
  Future<bool> _dispatchItem(OutboxItem item) async {
    final targetUrl = _resolveUrl(item);
    if (targetUrl.isEmpty) {
      developer.log('Target URL kosong untuk item outbox ${item.id}', name: _logTag);
      return false;
    }

    final uri = Uri.parse(targetUrl);
    final payloadBytes = utf8.encode(jsonEncode(item.payload));

    try {
      final response = await _client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Idempotency-Key': item.id,
        },
        body: payloadBytes,
      ).timeout(const Duration(seconds: 15));

      final statusCode = response.statusCode;

      // 1. Sukses 2xx: Server menerima dan mengonfirmasi
      if (statusCode >= 200 && statusCode < 300) {
        Map<String, dynamic>? decodedResponse;
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            decodedResponse = decoded;
          }
        } on Object {
          // Response body non-json diterima
        }

        final updated = item.copyWith(
          status: OutboxStatus.sent,
          sentAt: DateTime.now(),
          responsePayload: decodedResponse,
          lastError: null,
        );
        await _repository.update(updated);
        developer.log('Item outbox ${item.id} berhasil disinkronkan (${item.type})', name: _logTag);
        return true;
      }

      // 2. Client Rejection 4xx (selain 408 Timeout dan 429 Rate Limit): Penolakan permanen
      if (statusCode >= 400 && statusCode < 500 && statusCode != 408 && statusCode != 429) {
        final updated = item.copyWith(
          status: OutboxStatus.rejected,
          lastError: 'Server menolak request (HTTP $statusCode): ${response.body}',
        );
        await _repository.update(updated);
        developer.log('Item outbox ${item.id} ditolak server permanen (HTTP $statusCode)', name: _logTag);
        return false;
      }

      // 3. Transient Server Error (5xx, 408, 429): Lakukan retry dengan backoff
      await _handleTransientFailure(
        item,
        'Server merespons error HTTP $statusCode: ${response.body}',
      );
      return false;
    } on Object catch (e) {
      // 4. Kegagalan Jaringan / Timeout: Lakukan retry dengan backoff
      await _handleTransientFailure(item, e.toString());
      return false;
    }
  }

  Future<void> _handleTransientFailure(OutboxItem item, String errorMsg) async {
    final nextAttempts = item.attempts + 1;
    final isExceeded = nextAttempts >= maxAttempts;

    final nextAttemptAt = isExceeded
        ? item.nextAttemptAt
        : DateTime.now().add(OutboxItem.calculateBackoff(nextAttempts));

    final updated = item.copyWith(
      attempts: nextAttempts,
      nextAttemptAt: nextAttemptAt,
      status: isExceeded ? OutboxStatus.needs_attention : OutboxStatus.pending,
      lastError: errorMsg,
    );

    await _repository.update(updated);
    developer.log(
      'Item outbox ${item.id} gagal dikirim (percobaan ke-$nextAttempts/$maxAttempts): $errorMsg',
      name: _logTag,
    );
  }

  String _resolveUrl(OutboxItem item) {
    if (item.endpoint != null && item.endpoint!.isNotEmpty) {
      if (item.endpoint!.startsWith('http://') || item.endpoint!.startsWith('https://')) {
        return item.endpoint!;
      }
      final cleanBase = _baseUrl.endsWith('/') ? _baseUrl.substring(0, _baseUrl.length - 1) : _baseUrl;
      final cleanPath = item.endpoint!.startsWith('/') ? item.endpoint! : '/${item.endpoint!}';
      return '$cleanBase$cleanPath';
    }

    final cleanBase = _baseUrl.endsWith('/') ? _baseUrl.substring(0, _baseUrl.length - 1) : _baseUrl;
    switch (item.type) {
      case 'audit_consent':
      case 'consent':
        return '$cleanBase/api/consent';
      case 'audit_revocation':
      case 'revocation':
        return '$cleanBase/api/consent/revoke';
      case 'audit_levy':
      case 'levy_audit':
        return '$cleanBase/api/audit/levy';
      case 'audit_qris':
      case 'qris_audit':
        return '$cleanBase/api/audit/qris';
      case 'audit_credential':
      case 'credential_audit':
        return '$cleanBase/api/audit/credential';
      default:
        return '$cleanBase/api/audit/generic';
    }
  }

  void dispose() {
    stopPeriodicSync();
  }
}
