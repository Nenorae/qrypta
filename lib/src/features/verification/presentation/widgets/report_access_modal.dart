// lib/src/features/verification/presentation/widgets/report_access_modal.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:qrypta/src/core/data/models/audit_transaction_model.dart';

/// Modal pelaporan akses data merchant mencurigakan ke queue otoritas (Phase 4).
class ReportAccessModal extends StatelessWidget {
  final AuditTransactionModel audit;

  const ReportAccessModal({super.key, required this.audit});

  static void show({
    required BuildContext context,
    required AuditTransactionModel audit,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => ReportAccessModal(audit: audit),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rand = Random();
    final excRef = 'EXC-${1000 + rand.nextInt(9000)}';

    return Container(
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
            children: const [
              Icon(Icons.report_problem_rounded, color: Colors.amber, size: 22),
              SizedBox(width: 10),
              Text(
                'Report Unexpected Access',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Submit an exception report regarding ${audit.organisation} to the Bali Tourism Authority compliance queue.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0C1322),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                _buildReportDetail('Complaint Ref', excRef),
                const Divider(color: Colors.white12, height: 12),
                _buildReportDetail('Transaction', audit.txRef),
                const Divider(color: Colors.white12, height: 12),
                _buildReportDetail('Subject', audit.organisation),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Report $excRef dispatched to Government Exceptions Queue'),
                  backgroundColor: const Color(0xFF0D9488),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber[700],
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Submit Report to Authorities',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportDetail(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 12,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
