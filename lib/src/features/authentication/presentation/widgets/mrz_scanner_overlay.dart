// lib/src/features/authentication/presentation/widgets/mrz_scanner_overlay.dart

import 'package:flutter/material.dart';
import 'package:qrypta/src/core/config/theme/app_colors.dart';

enum ScannerState {
  initializing,
  permissionDenied,
  cameraUnavailable,
  searching,
  partialDetected,
  verifyingConsensus,
  completed,
}

/// Overlay bingkai pemindaian zona MRZ paspor dengan laser sweep animasi (Phase 5A).
class MrzScannerOverlay extends StatelessWidget {
  final ScannerState state;
  final String statusMessage;
  final bool isTorchOn;
  final bool showManualInputBanner;
  final Animation<double> laserAnimation;
  final VoidCallback onToggleTorch;
  final VoidCallback onOpenManualInput;
  final VoidCallback onBack;

  const MrzScannerOverlay({
    super.key,
    required this.state,
    required this.statusMessage,
    required this.isTorchOn,
    this.showManualInputBanner = false,
    required this.laserAnimation,
    required this.onToggleTorch,
    required this.onOpenManualInput,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // Top App Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                  onPressed: onBack,
                ),
                const Text(
                  'Scan Passport MRZ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // Tombol Senter
                IconButton(
                  icon: Icon(
                    isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                    color: isTorchOn ? AppColors.accent : Colors.white,
                  ),
                  onPressed: onToggleTorch,
                ),
              ],
            ),
          ),

          // Status Banner Real-Time
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: state == ScannerState.verifyingConsensus
                    ? const Color(0xFF2DD4BF)
                    : Colors.white24,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (state == ScannerState.verifyingConsensus)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF2DD4BF),
                    ),
                  )
                else
                  Icon(
                    Icons.radar_rounded,
                    size: 14,
                    color: state == ScannerState.partialDetected
                        ? Colors.amber
                        : AppColors.accent,
                  ),
                const SizedBox(width: 8),
                Text(
                  statusMessage,
                  style: TextStyle(
                    color: state == ScannerState.partialDetected
                        ? Colors.amberAccent
                        : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Instruksi Pengguna
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              'Posisikan 2 baris kode MRZ di bagian bawah biodata paspor tepat di dalam bingkai.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 13,
              ),
            ),
          ),
          const Spacer(),

          // Viewfinder Frame (Aspect ratio paspor TD3 MRZ band: ~3.2)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: AspectRatio(
              aspectRatio: 3.2,
              child: Stack(
                children: [
                  // Bingkai Toska
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: state == ScannerState.verifyingConsensus
                            ? const Color(0xFF5EEAD4)
                            : const Color(0xFF2DD4BF),
                        width: 2.5,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      color: const Color(0xFF0D9488).withValues(alpha: 0.08),
                    ),
                  ),
                  // Laser sweep animation
                  AnimatedBuilder(
                    animation: laserAnimation,
                    builder: (context, child) {
                      return Positioned(
                        top: laserAnimation.value * 90,
                        left: 8,
                        right: 8,
                        child: Container(
                          height: 2.5,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Colors.transparent,
                                Color(0xFF2DD4BF),
                                Color(0xFF5EEAD4),
                                Color(0xFF2DD4BF),
                                Colors.transparent,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2DD4BF).withValues(alpha: 0.8),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  // Corner Guides
                  Positioned(
                    left: 12,
                    top: 10,
                    child: Text(
                      'P<',
                      style: TextStyle(
                        color: const Color(0xFF2DD4BF).withValues(alpha: 0.6),
                        fontFamily: 'Courier',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 12,
                    bottom: 10,
                    child: Text(
                      'TD3 44x2',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontFamily: 'Courier',
                        fontSize: 10,
                      ),
                    ),
                  ),
                  // Indikator Garis Bantu MRZ (2 baris putus-putus)
                  Positioned(
                    left: 16,
                    right: 16,
                    top: 26,
                    child: Container(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 26,
                    child: Container(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),

          // Banner Bantuan / Input Manual jika scan lama (>30s) atau tombol opsi
          if (showManualInputBanner)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline, color: Colors.amber, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Mengalami kesulitan pemindaian? Pastikan pencahayaan cukup dan hindari pantulan silau.',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ),
                  TextButton(
                    onPressed: onOpenManualInput,
                    child: const Text(
                      'Input Manual',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Tombol Bawah: Input Manual Alternatif Sah
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
            child: Column(
              children: [
                TextButton.icon(
                  onPressed: onOpenManualInput,
                  icon: const Icon(Icons.keyboard_alt_outlined, size: 16, color: Colors.white70),
                  label: const Text(
                    'Ketik data paspor secara manual',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 13,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Zero cloud transmission · Local OCR verification',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
