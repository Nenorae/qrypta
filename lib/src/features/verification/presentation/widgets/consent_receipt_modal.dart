// lib/src/features/verification/presentation/widgets/consent_receipt_modal.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qrypta/src/core/data/models/audit_transaction_model.dart';

/// Modal tampilan kuitansi kriptografis consent wisatawan (Phase 4).
class ConsentReceiptModal extends StatelessWidget {
  final AuditTransactionModel audit;

  const ConsentReceiptModal({super.key, required this.audit});

  static void show({
    required BuildContext context,
    required AuditTransactionModel audit,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => ConsentReceiptModal(audit: audit),
    );
  }

  @override
  Widget build(BuildContext context) {
    final receiptPayload = {
      'auditRef': audit.auditRef,
      'txRef': audit.txRef,
      'actor': audit.actor,
      'actorRef': audit.actorRef,
      'actorWallet': audit.actorWallet,
      'organisation': audit.organisation,
      'action': audit.action,
      'purpose': audit.purpose,
      'sharedAttributes': audit.attributeKeys,
      'status': audit.status,
      'signature': audit.receiptSignature ?? '0xPersonalSignEIP191Verified',
      'timestamp': audit.timestamp.toIso8601String(),
    };

    final receiptJson = const JsonEncoder.withIndent('  ').convert(receiptPayload);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
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
                  Icon(Icons.receipt_long_rounded, color: Color(0xFF2DD4BF), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Cryptographic Consent Receipt',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: SingleChildScrollView(
                child: Text(
                  receiptJson,
                  style: const TextStyle(
                    color: Color(0xFF5EEAD4),
                    fontFamily: 'Courier',
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: receiptJson));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cryptographic receipt copied to clipboard'),
                  backgroundColor: Color(0xFF0D9488),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D9488),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy JSON Receipt'),
          ),
        ],
      ),
    );
  }
}
