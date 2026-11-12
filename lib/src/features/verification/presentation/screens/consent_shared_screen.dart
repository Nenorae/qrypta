// lib/src/features/verification/presentation/screens/consent_shared_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qrypta/src/core/config/theme/app_colors.dart';
import 'package:qrypta/src/core/data/models/audit_transaction_model.dart';
import 'package:qrypta/src/core/data/models/consent_request_model.dart';
import 'package:qrypta/src/features/verification/data/policy_matrix_constants.dart';
import 'package:qrypta/src/features/verification/presentation/screens/privacy_audit_screen.dart';

class ConsentSharedScreen extends StatelessWidget {
  final ConsentRequestModel request;
  final AuditTransactionModel audit;

  const ConsentSharedScreen({
    super.key,
    required this.request,
    required this.audit,
  });

  @override
  Widget build(BuildContext context) {
    final timestampFormatted =
        DateFormat('dd MMM yyyy · HH:mm:ss').format(audit.timestamp);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              // Success Animated Icon
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF0D9488).withValues(alpha: 0.2),
                    border: Border.all(
                      color: const Color(0xFF2DD4BF),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2DD4BF).withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Color(0xFF2DD4BF),
                    size: 44,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                'Data Shared Successfully',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Purpose-limited attributes transmitted to ${request.merchantName}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 24),

              // Transaction Receipt Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF131D2D),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    _buildReceiptRow('Transaction Ref', request.requestId, isHighlight: true),
                    const Divider(color: Colors.white12, height: 18),
                    _buildReceiptRow('Audit Code', audit.auditRef),
                    const Divider(color: Colors.white12, height: 18),
                    _buildReceiptRow('Recipient', request.merchantName),
                    const Divider(color: Colors.white12, height: 18),
                    _buildReceiptRow('Staff Agent', '${request.staffName} (${request.staffRole})'),
                    const Divider(color: Colors.white12, height: 18),
                    _buildReceiptRow('Purpose', request.purposeTemplate.replaceAll('_', ' ').toUpperCase()),
                    const Divider(color: Colors.white12, height: 18),
                    _buildReceiptRow('Timestamp', timestampFormatted),
                    const Divider(color: Colors.white12, height: 18),
                    _buildReceiptRow('Status', audit.status, statusColor: const Color(0xFF2DD4BF)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Blockchain TxHash Box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0C1322),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.link_rounded, size: 14, color: Color(0xFFA78BFA)),
                            SizedBox(width: 6),
                            Text(
                              'HYPERLEDGER BESU TX HASH',
                              style: TextStyle(
                                color: Color(0xFFA78BFA),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: audit.txHash));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Transaction Hash copied to clipboard'),
                                backgroundColor: Color(0xFF0D9488),
                              ),
                            );
                          },
                          child: Row(
                            children: const [
                              Icon(Icons.copy_rounded, size: 12, color: Colors.white70),
                              SizedBox(width: 4),
                              Text(
                                'Copy',
                                style: TextStyle(color: Colors.white70, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      audit.txHash,
                      style: const TextStyle(
                        color: Color(0xFF5EEAD4),
                        fontFamily: 'Courier',
                        fontSize: 11,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Attributes Disclosed Summary
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF131D2D),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Shared Attributes (${audit.attributeKeys?.length ?? 0})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: (audit.attributeKeys ?? []).map((key) {
                        final label = ATTRS[key]?.label ?? key;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D9488).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF2DD4BF).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            label,
                            style: const TextStyle(
                              color: Color(0xFF2DD4BF),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Action Buttons
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PrivacyAuditScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: const Color(0xFF0A0F1D),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.shield_outlined, size: 18),
                  label: const Text(
                    'View in Privacy Audit Centre',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Back to QR Screen'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptRow(
    String label,
    String value, {
    bool isHighlight = false,
    Color? statusColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 12,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: statusColor ?? (isHighlight ? const Color(0xFF5EEAD4) : Colors.white),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            fontFamily: isHighlight ? 'Courier' : null,
          ),
        ),
      ],
    );
  }
}
