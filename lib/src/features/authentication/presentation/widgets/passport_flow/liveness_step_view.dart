// lib/src/features/authentication/presentation/widgets/passport_flow/liveness_step_view.dart

import 'package:flutter/material.dart';
import 'package:qrypta/src/core/config/theme/app_colors.dart';

/// Tampilan tahap liveness wajah berlabel SIMULASI transparan (Golden Rule R4 & Phase 9).
class LivenessStepView extends StatelessWidget {
  final Animation<double> radarAnimation;
  final bool livenessComplete;
  final String currentStageMessage;
  final VoidCallback? onIssueTouristId;

  const LivenessStepView({
    super.key,
    required this.radarAnimation,
    required this.livenessComplete,
    required this.currentStageMessage,
    required this.onIssueTouristId,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 4),

          // Lencana Tetap SIMULASI / DEMO (Golden Rule R4 & Phase 9.1)
          Center(
            child: Container(
              key: const Key('liveness_simulation_badge'),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFF59E0B),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(
                    Icons.science_outlined,
                    size: 14,
                    color: Color(0xFFF59E0B),
                  ),
                  SizedBox(width: 6),
                  Text(
                    'SIMULASI / DEMO',
                    style: TextStyle(
                      color: Color(0xFFF59E0B),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Facial Liveness (Simulated / Demo)',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Simulasi penangkapan wajah demo (F-18). Tidak ada pemindaian AI atau verifikasi biometrik sungguhan.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 20),

          // Circular Camera Viewfinder
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                RotationTransition(
                  turns: radarAnimation,
                  child: Container(
                    width: 190,
                    height: 190,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: livenessComplete
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF8B5CF6),
                        width: 3,
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 170,
                  height: 170,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF0C1322),
                  ),
                  child: ClipOval(
                    child: Center(
                      child: Icon(
                        livenessComplete
                            ? Icons.check_circle_outline_rounded
                            : Icons.face_rounded,
                        size: 90,
                        color: livenessComplete
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFFA78BFA),
                      ),
                    ),
                  ),
                ),
                // Floating SIMULASI badge across the viewfinder
                Positioned(
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'SIMULASI',
                      style: TextStyle(
                        color: Color(0xFF080D1A),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Text(
            currentStageMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),

          if (livenessComplete)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1A0F),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFF59E0B),
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Simulasi: lolos',
                          style: TextStyle(
                            color: Color(0xFFF59E0B),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Skor simulasi 98.7% (demo) · Biometrik TIDAK diverifikasi',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'SIMULASI',
                      style: TextStyle(
                        color: Color(0xFF080D1A),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.privacy_tip_outlined,
                size: 13,
                color: Colors.white.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 6),
              Text(
                'Modul simulasi berlabel resmi (R4) · Zero PII cloud transmission',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: onIssueTouristId,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: const Color(0xFF0A0F1D),
                disabledBackgroundColor: Colors.white12,
                disabledForegroundColor: Colors.white38,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text(
                    'Issue my Tourist ID',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.badge_rounded, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
