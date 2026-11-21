// lib/src/features/authentication/presentation/widgets/passport_flow/nfc_step_view.dart

import 'package:flutter/material.dart';

/// Tampilan tahap pembacaan chip e-Passport via NFC (Phase 8.1).
class NfcStepView extends StatelessWidget {
  final Animation<double> pulseAnimation;
  final String? nfcErrorMessage;
  final String nfcStageMessage;
  final double nfcProgress;
  final bool isNfcScanning;
  final VoidCallback onRetry;

  const NfcStepView({
    super.key,
    required this.pulseAnimation,
    required this.nfcErrorMessage,
    required this.nfcStageMessage,
    required this.nfcProgress,
    required this.isNfcScanning,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(),
        Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: pulseAnimation,
                builder: (context, child) {
                  return Container(
                    width: 170 + (pulseAnimation.value * 25),
                    height: 170 + (pulseAnimation.value * 25),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (nfcErrorMessage != null
                              ? Colors.redAccent
                              : const Color(0xFFA78BFA))
                          .withValues(alpha: 0.08),
                    ),
                  );
                },
              ),
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (nfcErrorMessage != null
                          ? Colors.redAccent
                          : const Color(0xFFA78BFA))
                      .withValues(alpha: 0.15),
                  border: Border.all(
                    color: (nfcErrorMessage != null
                            ? Colors.redAccent
                            : const Color(0xFFA78BFA))
                        .withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
              ),
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: nfcErrorMessage != null
                        ? [const Color(0xFFEF4444), const Color(0xFF991B1B)]
                        : [const Color(0xFF8B5CF6), const Color(0xFF4C1D95)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (nfcErrorMessage != null
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF8B5CF6))
                          .withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  nfcErrorMessage != null ? Icons.nfc_outlined : Icons.nfc_rounded,
                  size: 48,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 36),

        // Tahapan Teks Berurutan Real-Time
        Text(
          nfcErrorMessage ?? nfcStageMessage,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: nfcErrorMessage != null ? Colors.redAccent : Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),

        // Progress Bar
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: nfcErrorMessage != null ? 0.0 : nfcProgress,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(
              nfcErrorMessage != null ? Colors.redAccent : const Color(0xFFA78BFA),
            ),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          nfcErrorMessage != null
              ? 'Please resolve the error and try scanning again'
              : 'Hold passport firmly against phone NFC area (back antenna)',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 12,
          ),
        ),

        const Spacer(),

        // Tombol Retry bila terjadi kegagalan atau hardware belum scan
        if (nfcErrorMessage != null || !isNfcScanning)
          SizedBox(
            height: 48,
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFA78BFA)),
                ),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(
                nfcErrorMessage != null ? 'Try Scanning Again' : 'Start NFC Scan',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        const SizedBox(height: 10),
      ],
    );
  }
}
