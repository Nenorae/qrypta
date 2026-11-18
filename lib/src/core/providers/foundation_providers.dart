// lib/src/core/providers/foundation_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:qrypta/src/core/config/app_config.dart';
import 'package:qrypta/src/core/outbox/outbox_repository.dart';
import 'package:qrypta/src/core/outbox/outbox_worker.dart';
import 'package:qrypta/src/core/services/audit/audit_migration_service.dart';
import 'package:qrypta/src/core/transaction/state_machine/tx_intent_repository.dart';
import 'package:qrypta/src/core/transaction/state_machine/tx_recovery_service.dart';

/// Provider untuk repository penyimpanan intent transaksi.
final txIntentRepositoryProvider = Provider<TxIntentRepository>((ref) {
  return TxIntentRepository();
});

/// Provider untuk service pemulihan transaksi on-chain terputus.
final txRecoveryServiceProvider = Provider<TxRecoveryService>((ref) {
  final repo = ref.watch(txIntentRepositoryProvider);
  return TxRecoveryService(repository: repo);
});

/// Provider untuk repository antrean Outbox.
final outboxRepositoryProvider = Provider<OutboxRepository>((ref) {
  return OutboxRepository();
});

/// Provider untuk background worker pengiriman outbox.
final outboxWorkerProvider = Provider<OutboxWorker>((ref) {
  final repo = ref.watch(outboxRepositoryProvider);
  final client = http.Client();
  final worker = OutboxWorker(
    repository: repo,
    client: client,
    baseUrl: AppConfig.ezsignUrl,
  );
  ref.onDispose(() {
    worker.dispose();
    client.close();
  });
  return worker;
});

/// Provider untuk migrasi database audit ke status otoritatif.
final auditMigrationServiceProvider = Provider<AuditMigrationService>((ref) {
  return AuditMigrationService();
});
