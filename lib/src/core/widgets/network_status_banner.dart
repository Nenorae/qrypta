// lib/src/core/widgets/network_status_banner.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypta/src/core/services/network/network_health_service.dart';

/// Non-intrusive yet prominent UI banner showing the real-time status of the
/// blockchain RPC node and EzSign middleware. Collapses when completely healthy.
class NetworkStatusBanner extends ConsumerWidget {
  const NetworkStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(networkHealthProvider);

    if (health.isAllHealthy || health.rpcStatus == ComponentStatus.checking) {
      return const SizedBox.shrink();
    }

    final isOffline = health.overallStatus == OverallHealthStatus.offline;
    final backgroundColor = isOffline ? const Color(0xFF8B0000) : const Color(0xFFB45309);
    final icon = isOffline ? Icons.cloud_off_rounded : Icons.warning_amber_rounded;

    String message;
    if (isOffline) {
      message = 'Koneksi Terputus: Node Besu dan EzSign API tidak dapat dijangkau.';
    } else if (!health.isRpcHealthy) {
      message = health.rpcError ?? 'Node Blockchain Besu tidak terjangkau. Fitur transfer dimatikan.';
    } else {
      message = health.ezsignError ?? 'Layanan EzSign tidak merespons. Fitur audit/sinkronisasi tertunda.';
    }

    return Container(
      width: double.infinity,
      color: backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => ref.read(networkHealthProvider.notifier).checkHealth(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Cek Ulang',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
