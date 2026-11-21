// lib/src/features/verification/presentation/screens/privacy_audit_screen.dart

import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qrypta/src/core/config/theme/app_colors.dart';
import 'package:qrypta/src/core/data/models/audit_transaction_model.dart';
import 'package:qrypta/src/core/outbox/outbox_item.dart';
import 'package:qrypta/src/core/providers/foundation_providers.dart';
import 'package:qrypta/src/features/authentication/presentation/providers/auth_providers.dart';
import 'package:qrypta/src/features/authentication/presentation/providers/btid_provider.dart';
import 'package:qrypta/src/features/verification/logic/verification_controller.dart';
import 'package:qrypta/src/features/verification/presentation/widgets/audit_transaction_tile.dart';
import 'package:qrypta/src/features/verification/presentation/widgets/consent_receipt_modal.dart';
import 'package:qrypta/src/features/verification/presentation/widgets/report_access_modal.dart';
import 'package:qrypta/src/features/verification/presentation/widgets/sync_center_modal.dart';

export 'package:qrypta/src/features/verification/presentation/widgets/audit_transaction_tile.dart';
export 'package:qrypta/src/features/verification/presentation/widgets/consent_receipt_modal.dart';
export 'package:qrypta/src/features/verification/presentation/widgets/report_access_modal.dart';
export 'package:qrypta/src/features/verification/presentation/widgets/sync_center_modal.dart';

class PrivacyAuditScreen extends ConsumerStatefulWidget {
  const PrivacyAuditScreen({super.key});

  @override
  ConsumerState<PrivacyAuditScreen> createState() => _PrivacyAuditScreenState();
}

class _PrivacyAuditScreenState extends ConsumerState<PrivacyAuditScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(verificationControllerProvider.notifier).loadAuditHistory();
    });
  }

  void _showConsentReceiptModal(AuditTransactionModel audit) {
    ConsentReceiptModal.show(context: context, audit: audit);
  }

  Future<void> _handleRevokeAccess(AuditTransactionModel audit) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131D2D),
        title: const Text('Revoke Merchant Access?', style: TextStyle(color: Colors.white)),
        content: Text(
          'This will record a cryptographic revocation on Hyperledger Besu. ${audit.organisation} will be blocked from future data requests.',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Revoke Access'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final cred = ref.read(btidCredentialProvider);
      if (cred == null || cred.btidNumber.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('BTID tidak ditemukan.'), backgroundColor: Colors.redAccent),
          );
        }
        return;
      }
      final privateKey = await ref.read(getPrivateKeyUseCaseProvider)() ?? '0x0';
      final actor = ref.read(actorRefProvider);

      await ref.read(verificationControllerProvider.notifier).revokeAccess(
            txRef: audit.txRef,
            merchantId: audit.organisation,
            merchantName: audit.organisation,
            privateKeyHex: privateKey,
            btid: cred.btidNumber,
            actor: actor,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Access for ${audit.organisation} revoked on Hyperledger Besu'),
            backgroundColor: Colors.amber[800],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Revocation failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _showSyncCenterModal() {
    SyncCenterModal.show(context: context, ref: ref);
  }


  void _showReportAccessModal(AuditTransactionModel audit) {
    ReportAccessModal.show(context: context, audit: audit);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(verificationControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Privacy & Sharing Audit',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Sync Center',
            icon: const Icon(Icons.sync_rounded, color: Color(0xFF2DD4BF)),
            onPressed: _showSyncCenterModal,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 3 Metric Cards at Top
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      label: 'Approved',
                      count: state.approvedCount,
                      color: const Color(0xFF2DD4BF),
                      icon: Icons.check_circle_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricCard(
                      label: 'Rejected',
                      count: state.rejectedCount,
                      color: Colors.redAccent,
                      icon: Icons.cancel_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricCard(
                      label: 'Active Access',
                      count: state.activeAccessCount,
                      color: const Color(0xFFA78BFA),
                      icon: Icons.vpn_key_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Consent & Access History',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${state.auditHistory.length} total entries',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // History List
              if (state.auditHistory.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131D2D),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.history_toggle_off_rounded,
                          size: 40,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No consent transactions yet',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Transactions will appear here when merchants verify your QR',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...state.auditHistory.map(
                  (audit) => AuditTransactionTile(
                    audit: audit,
                    onViewReceipt: () => _showConsentReceiptModal(audit),
                    onRevoke: () => _handleRevokeAccess(audit),
                    onReport: () => _showReportAccessModal(audit),
                  ),
                ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String label,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF131D2D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 6),
          Text(
            count.toString(),
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
