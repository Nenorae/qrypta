// lib/src/features/verification/presentation/widgets/consent_biometric_guarantee.dart

import 'package:flutter/material.dart';

/// Kartu jaminan perlindungan data biometrik dan klausul retensi data (Phase 4 & Policy Matrix).
class ConsentBiometricGuarantee extends StatelessWidget {
  final String retentionPolicy;

  const ConsentBiometricGuarantee({super.key, required this.retentionPolicy});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Klausul Retensi Data
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF131D2D),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              const Icon(Icons.access_time_rounded, size: 16, color: Colors.white60),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  retentionPolicy,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Biometric Protection Guarantee
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1A2E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFA78BFA).withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.shield_outlined, size: 16, color: Color(0xFFA78BFA)),
              const SizedBox(width: 10),
              Expanded(
                child: const Text(
                  'Never shared: Biometric template, live face capture, and full passport chip contents.',
                  style: TextStyle(
                    color: Color(0xFFA78BFA),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
