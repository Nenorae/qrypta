// lib/src/features/verification/presentation/widgets/sync_center_modal.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypta/src/core/outbox/outbox_item.dart';
import 'package:qrypta/src/core/outbox/outbox_repository.dart';
import 'package:qrypta/src/core/outbox/outbox_worker.dart';
import 'package:qrypta/src/core/providers/foundation_providers.dart';
import 'package:qrypta/src/features/verification/logic/verification_controller.dart';

/// Modal Sync Center untuk mengelola antrean sinkronisasi outbox offline (Phase 4.5).
class SyncCenterModal {
  static void show({
    required BuildContext context,
    required WidgetRef ref,
  }) async {
    final outboxRepo = ref.read(outboxRepositoryProvider);
    final items = await outboxRepo.getAllItems();

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFF131D2D),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.outbox_rounded, color: Color(0xFF2DD4BF), size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Sync Center',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(modalCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Kelola antrean sinkronisasi transaksi audit dan consent.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: items.isEmpty
                        ? const Center(
                            child: Text(
                              'Antrean outbox kosong. Semua rekaman telah tersinkronisasi.',
                              style: TextStyle(color: Colors.white54, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.separated(
                            itemCount: items.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 8),
                            itemBuilder: (ctx, index) {
                              final it = items[index];
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0C1322),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          it.type.toUpperCase(),
                                          style: const TextStyle(
                                            color: Color(0xFF5EEAD4),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                        Text(
                                          it.status.name.toUpperCase(),
                                          style: TextStyle(
                                            color: it.status == OutboxStatus.sent
                                                ? const Color(0xFF2DD4BF)
                                                : Colors.amber,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'ID: ${it.id}',
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 10,
                                        fontFamily: 'Courier',
                                      ),
                                    ),
                                    if (it.lastError != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Error: ${it.lastError}',
                                        style: const TextStyle(
                                          color: Colors.redAccent,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 4),
                                    Text(
                                      'Percobaan: ${it.attempts} · Dijadwalkan: ${it.nextAttemptAt}',
                                      style: const TextStyle(color: Colors.white38, fontSize: 9),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final worker = ref.read(outboxWorkerProvider);
                      final processed = await worker.processPendingQueue(
                        now: DateTime.now().add(const Duration(days: 1)),
                      );
                      await ref.read(verificationControllerProvider.notifier).loadAuditHistory();
                      final refreshed = await outboxRepo.getAllItems();
                      setModalState(() {
                        items.clear();
                        items.addAll(refreshed);
                      });
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$processed item outbox berhasil diproses.'),
                            backgroundColor: const Color(0xFF0D9488),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2DD4BF),
                      foregroundColor: const Color(0xFF0A0F1D),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.sync_rounded, size: 16),
                    label: const Text('Kirim Ulang Sekarang'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
