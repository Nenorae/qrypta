// lib/src/features/verification/presentation/widgets/consent_clarification_dialog.dart

import 'package:flutter/material.dart';

/// Dialog klarifikasi pertanyaan wisatawan kepada petugas merchant (Phase 4).
class ConsentClarificationDialog extends StatelessWidget {
  final String staffName;

  const ConsentClarificationDialog({super.key, required this.staffName});

  static void show({
    required BuildContext context,
    required String staffName,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => ConsentClarificationDialog(staffName: staffName),
    );
  }

  Widget _buildClarificationOption(BuildContext ctx, String text) {
    return InkWell(
      onTap: () {
        Navigator.pop(ctx);
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text('Clarification sent to $staffName'),
            backgroundColor: const Color(0xFF0D9488),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            const Icon(Icons.help_outline_rounded, size: 16, color: Color(0xFF2DD4BF)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF131D2D),
      title: Text(
        'Ask $staffName',
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select clarification to send to merchant terminal:',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 12),
          _buildClarificationOption(context, 'Why do you need my passport number?'),
          _buildClarificationOption(context, 'Can I check in without date of birth?'),
          _buildClarificationOption(context, 'What is your regional data retention policy?'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
