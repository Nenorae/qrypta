// lib/src/core/services/blockchain/audit_storage_service.dart

import 'dart:developer' as developer;
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:qrypta/src/core/data/models/audit_transaction_model.dart';

/// Penyimpanan lokal rekaman transaksi audit (Hive + Cache Memori) (Phase 2.4).
class AuditStorageService {
  static const String _boxName = 'audit_transactions_box';
  static const String _serviceName = 'AuditStorageService';

  final List<AuditTransactionModel> _memoryAuditCache = [];

  List<AuditTransactionModel> get memoryCache => List.unmodifiable(_memoryAuditCache);

  /// Menyimpan catatan audit ke penyimpanan Hive dan cache in-memory.
  Future<void> saveAuditTransaction(AuditTransactionModel audit) async {
    try {
      Box box;
      if (Hive.isBoxOpen(_boxName)) {
        box = Hive.box(_boxName);
      } else {
        box = await Hive.openBox(_boxName);
      }
      await box.put(audit.txRef, audit.toJson());
    } on Object catch (e) {
      developer.log('Penyimpanan Hive gagal, fallback ke memori isolat: $e', name: _serviceName);
      final index = _memoryAuditCache.indexWhere((a) => a.txRef == audit.txRef);
      if (index >= 0) {
        _memoryAuditCache[index] = audit;
      } else {
        _memoryAuditCache.insert(0, audit);
      }
    }
  }

  /// Mengambil seluruh riwayat transaksi audit terurut berdasarkan waktu terbaru.
  Future<List<AuditTransactionModel>> getAuditTransactions() async {
    final List<AuditTransactionModel> results = [];

    try {
      Box box;
      if (Hive.isBoxOpen(_boxName)) {
        box = Hive.box(_boxName);
      } else {
        box = await Hive.openBox(_boxName);
      }

      for (final key in box.keys) {
        final raw = box.get(key);
        if (raw is Map) {
          final map = Map<String, dynamic>.from(raw);
          results.add(AuditTransactionModel.fromJson(map));
        }
      }
    } on Object catch (e) {
      developer.log('Pembacaan Hive audit gagal, mengambil dari memori: $e', name: _serviceName);
      results.addAll(_memoryAuditCache);
    }

    if (results.isEmpty && _memoryAuditCache.isNotEmpty) {
      results.addAll(_memoryAuditCache);
    }

    results.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return results;
  }
}
