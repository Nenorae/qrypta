// lib/src/features/verification/presentation/widgets/consent_attribute_tile.dart

import 'package:flutter/material.dart';

/// Ubin pemilihan selektif atribut identitas wisatawan yang akan dibagikan (Phase 4).
class ConsentAttributeTile extends StatelessWidget {
  final String label;
  final String value;
  final String reason;
  final bool isSelected;
  final ValueChanged<bool?> onChanged;

  const ConsentAttributeTile({
    super.key,
    required this.label,
    required this.value,
    required this.reason,
    required this.isSelected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1322),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF2DD4BF).withValues(alpha: 0.3)
              : Colors.white10,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: isSelected,
            activeColor: const Color(0xFF2DD4BF),
            checkColor: const Color(0xFF080D1A),
            onChanged: onChanged,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      value,
                      style: const TextStyle(
                        color: Color(0xFF5EEAD4),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  reason,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
