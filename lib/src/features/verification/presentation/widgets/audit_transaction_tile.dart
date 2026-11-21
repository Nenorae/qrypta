// lib/src/features/verification/presentation/widgets/audit_transaction_tile.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qrypta/src/core/data/models/audit_transaction_model.dart';

/// Badge visual status sinkronisasi audit (Phase 4.5).
class SyncStatusBadge extends StatelessWidget {
  final String syncStatus;

  const SyncStatusBadge({super.key, required this.syncStatus});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    IconData icon;

    switch (syncStatus.toLowerCase()) {
      case 'synced':
        color = const Color(0xFF2DD4BF);
        label = 'Synced';
        icon = Icons.cloud_done_rounded;
        break;
      case 'pending_sync':
        color = const Color(0xFFF59E0B);
        label = 'Menunggu Sinkron';
        icon = Icons.sync_rounded;
        break;
      case 'rejected':
        color = Colors.redAccent;
        label = 'Ditolak Server';
        icon = Icons.cloud_off_rounded;
        break;
      case 'legacy_unverified':
      default:
        color = Colors.white38;
        label = 'Tidak Terverifikasi';
        icon = Icons.history_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartu visual riwayat audit transaksi persetujuan/pembayaran (Phase 4.5).
class AuditTransactionTile extends StatelessWidget {
  final AuditTransactionModel audit;
  final VoidCallback onViewReceipt;
  final VoidCallback onRevoke;
  final VoidCallback onReport;

  const AuditTransactionTile({
    super.key,
    required this.audit,
    required this.onViewReceipt,
    required this.onRevoke,
    required this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    final isRevoked = audit.status.toLowerCase() == 'revoked';
    final isApproved = audit.status.toLowerCase() == 'approved';
    final isRejected = audit.status.toLowerCase() == 'rejected';

    Color statusColor = const Color(0xFF2DD4BF);
    if (isRejected) statusColor = Colors.redAccent;
    if (isRevoked) statusColor = Colors.amber;

    final dateStr = DateFormat('dd MMM · HH:mm').format(audit.timestamp);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131D2D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRevoked
              ? Colors.amber.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Merchant & Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: statusColor.withValues(alpha: 0.15),
                      ),
                      child: Icon(
                        isApproved
                            ? Icons.verified_rounded
                            : (isRevoked ? Icons.block_rounded : Icons.cancel_rounded),
                        color: statusColor,
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        audit.organisation,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SyncStatusBadge(syncStatus: audit.syncStatus),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      audit.status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Action & Purpose
          Text(
            audit.action,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
            ),
          ),
          if (audit.lastError != null && audit.lastError!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 12, color: Colors.amber),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      audit.lastError!,
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 4),

          // Metadata Row: TxRef & Date
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ref: ${audit.txRef}',
                style: const TextStyle(
                  color: Color(0xFF5EEAD4),
                  fontFamily: 'Courier',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                dateStr,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 11,
                ),
              ),
            ],
          ),

          // TxHash Preview
          if (audit.txHash != null && audit.txHash!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link_rounded, size: 11, color: Color(0xFFA78BFA)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      audit.txHash!,
                      style: const TextStyle(
                        color: Color(0xFFA78BFA),
                        fontFamily: 'Courier',
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),

          // 3 Functional Action Buttons (Specification Checklist)
          Row(
            children: [
              // 1. Download Consent Receipt
              Expanded(
                child: OutlinedButton(
                  onPressed: onViewReceipt,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2DD4BF),
                    side: BorderSide(color: const Color(0xFF2DD4BF).withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Receipt', style: TextStyle(fontSize: 11)),
                ),
              ),
              const SizedBox(width: 8),

              // 2. Stop Future Access (Revoke)
              if (!isRevoked && isApproved) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: onRevoke,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.4)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Revoke', style: TextStyle(fontSize: 11)),
                  ),
                ),
                const SizedBox(width: 8),
              ],

              // 3. Report Unexpected Access
              Expanded(
                child: OutlinedButton(
                  onPressed: onReport,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.amber,
                    side: BorderSide(color: Colors.amber.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Report', style: TextStyle(fontSize: 11)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
