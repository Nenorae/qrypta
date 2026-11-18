// lib/src/core/services/audit/audit_migration_service.dart

import 'dart:developer' as developer;
import 'package:hive_ce/hive.dart';
import 'package:qrypta/src/core/data/models/audit_transaction_model.dart';

/// Hasil laporan migrasi data audit lama (Phase 2.4).
class AuditMigrationReport {
  final int totalScanned;
  final int migratedLegacyCount;
  final int validCount;

  const AuditMigrationReport({
    required this.totalScanned,
    required this.migratedLegacyCount,
    required this.validCount,
  });

  @override
  String toString() =>
      'AuditMigrationReport(scanned: $totalScanned, legacyMarked: $migratedLegacyCount, valid: $validCount)';
}

/// Service migrasi database lokal Hive untuk catatan audit (Phase 2.4).
/// Mengubah seluruh catatan audit lama tanpa konfirmasi otoritatif menjadi 'legacy_unverified'.
class AuditMigrationService {
  static const String defaultBoxName = 'audit_transactions';
  static const String _logTag = 'AuditMigrationService';

  final Box? _injectedBox;

  AuditMigrationService({Box? box}) : _injectedBox = box;

  Future<Box> _getBox([String boxName = defaultBoxName]) async {
    if (_injectedBox != null) return _injectedBox!;
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box(boxName);
    }
    return await Hive.openBox(boxName);
  }

  /// Memindai box audit dan menandai seluruh record warisan (legacy) sebagai legacy_unverified.
  Future<AuditMigrationReport> migrateAuditStore({String boxName = defaultBoxName}) async {
    int totalScanned = 0;
    int migratedLegacy = 0;
    int validCount = 0;

    try {
      final box = await _getBox(boxName);

      for (final key in box.keys.toList()) {
        totalScanned++;
        final raw = box.get(key);
        if (raw is! Map) continue;

        final map = Map<String, dynamic>.from(raw);
        final rawSyncStatus = map['syncStatus'] as String?;
        final txHash = map['txHash'] as String?;

        // Deteksi record lama:
        // 1. syncStatus belum pernah diset
        // 2. Status 'Approved' atau 'Paid' namun txHash kosong / palsu ('0x' / null)
        final isLegacy = rawSyncStatus == null ||
            (rawSyncStatus != 'synced' && rawSyncStatus != 'pending_sync' && rawSyncStatus != 'rejected') ||
            ((map['status'] == 'Approved' || map['status'] == 'Paid') && (txHash == null || txHash.isEmpty || txHash == '0x'));

        if (isLegacy) {
          map['syncStatus'] = 'legacy_unverified';
          map['lastError'] = 'Data warisan audit lokal sebelum validasi otoritatif.';
          await box.put(key, map);
          migratedLegacy++;
        } else {
          validCount++;
        }
      }
      developer.log(
        'Migrasi audit selesai: $totalScanned dipindai, $migratedLegacy ditandai legacy_unverified',
        name: _logTag,
      );
    } on Object catch (e) {
      developer.log('Gagal menjalankan migrasi audit store: $e', name: _logTag);
    }

    return AuditMigrationReport(
      totalScanned: totalScanned,
      migratedLegacyCount: migratedLegacy,
      validCount: validCount,
    );
  }

  /// Mengonversi Map mentah ke model dengan jaminan status warisan (legacy) terisolasi.
  static AuditTransactionModel deserializeWithMigration(Map<String, dynamic> map) {
    return AuditTransactionModel.fromJson(map);
  }
}
