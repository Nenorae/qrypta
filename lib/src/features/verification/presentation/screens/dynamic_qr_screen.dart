// lib/src/features/verification/presentation/screens/dynamic_qr_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:qrypta/src/core/config/theme/app_colors.dart';
import 'package:qrypta/src/features/authentication/presentation/providers/btid_provider.dart';
import 'package:qrypta/src/features/verification/logic/verification_controller.dart';
import 'package:qrypta/src/features/verification/presentation/screens/consent_request_screen.dart';
import 'package:qrypta/src/features/verification/presentation/screens/privacy_audit_screen.dart';

class DynamicQrScreen extends ConsumerStatefulWidget {
  const DynamicQrScreen({super.key});

  @override
  ConsumerState<DynamicQrScreen> createState() => _DynamicQrScreenState();
}

class _DynamicQrScreenState extends ConsumerState<DynamicQrScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(verificationControllerProvider.notifier).startOrRefreshQr();
    });
  }

  void _onSimulateScan(String category) {
    final request = ref
        .read(verificationControllerProvider.notifier)
        .triggerMerchantSimulation(category);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConsentRequestScreen(request: request),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(verificationControllerProvider);
    final credential = ref.watch(btidCredentialProvider);
    final btidNumber = credential?.btidNumber ?? 'BTID-2026-4471-0938';
    final progress = state.remainingSeconds / 45.0;

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
          'Dynamic Tourist QR',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, color: AppColors.accent),
            tooltip: 'Privacy Audit',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PrivacyAuditScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header ID Info
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D9488).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF2DD4BF).withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.shield_rounded, size: 14, color: Color(0xFF2DD4BF)),
                      const SizedBox(width: 6),
                      Text(
                        btidNumber,
                        style: const TextStyle(
                          color: Color(0xFF2DD4BF),
                          fontSize: 12,
                          fontFamily: 'Courier',
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              const Text(
                'Show this code to verified merchant',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Merchant scanner initiates a purpose-limited consent request',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 24),

              // Kartu QR Utama dengan Efek Glow
              Center(
                child: Container(
                  width: 270,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: state.isQrExpired
                            ? Colors.redAccent.withValues(alpha: 0.25)
                            : AppColors.accent.withValues(alpha: 0.25),
                        blurRadius: 28,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // QR Code Widget
                      Opacity(
                        opacity: state.isQrExpired ? 0.08 : 1.0,
                        child: state.currentQrToken.isNotEmpty
                            ? QrImageView(
                                data: state.currentQrToken,
                                version: QrVersions.auto,
                                size: 230.0,
                                backgroundColor: Colors.white,
                                eyeStyle: const QrEyeStyle(
                                  eyeShape: QrEyeShape.square,
                                  color: Color(0xFF0F3B37),
                                ),
                                dataModuleStyle: const QrDataModuleStyle(
                                  dataModuleShape: QrDataModuleShape.square,
                                  color: Color(0xFF0A0F1D),
                                ),
                              )
                            : const SizedBox(
                                height: 230,
                                child: Center(child: CircularProgressIndicator()),
                              ),
                      ),

                      // Overlay jika QR Kedaluwarsa (0 detik)
                      if (state.isQrExpired)
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.red.withValues(alpha: 0.1),
                              ),
                              child: const Icon(
                                Icons.timer_off_rounded,
                                color: Colors.redAccent,
                                size: 40,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Code Expired',
                              style: TextStyle(
                                color: Color(0xFF0A0F1D),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              '45-second validity ended',
                              style: TextStyle(color: Colors.black54, fontSize: 12),
                            ),
                            const SizedBox(height: 14),
                            ElevatedButton.icon(
                              onPressed: () {
                                ref
                                    .read(verificationControllerProvider.notifier)
                                    .startOrRefreshQr();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0D9488),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('Refresh code'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Countdown Timer & Token Info
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF131D2D),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 16,
                              color: state.isQrExpired
                                  ? Colors.redAccent
                                  : const Color(0xFF2DD4BF),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              state.isQrExpired
                                  ? 'Code Expired'
                                  : 'Expires in: ${state.remainingSeconds}s',
                              style: TextStyle(
                                color: state.isQrExpired
                                    ? Colors.redAccent
                                    : Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          state.tokenCode,
                          style: const TextStyle(
                            color: Color(0xFF5EEAD4),
                            fontFamily: 'Courier',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white12,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          state.remainingSeconds < 10
                              ? Colors.redAccent
                              : const Color(0xFF2DD4BF),
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Garansi Privasi Ephemeral
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_clock_rounded,
                    size: 13,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Zero raw passport data inside QR · 45s Ephemeral Token',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Dev/Demo Panel: Simulate Merchant Scan
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFA78BFA).withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.terminal_rounded, size: 16, color: Color(0xFFA78BFA)),
                        SizedBox(width: 8),
                        Text(
                          'DEMO HANDSHAKE SIMULATION',
                          style: TextStyle(
                            color: Color(0xFFA78BFA),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Simulate an authorized merchant scanning this dynamic QR code:',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildSimulationChip(
                          icon: Icons.hotel_rounded,
                          label: 'Bali Ocean Resort (Hotel)',
                          onTap: () => _onSimulateScan('hotel'),
                        ),
                        _buildSimulationChip(
                          icon: Icons.directions_car_rounded,
                          label: 'Island Drive (Car Rental)',
                          onTap: () => _onSimulateScan('car'),
                        ),
                        _buildSimulationChip(
                          icon: Icons.coffee_rounded,
                          label: 'Bali Coffee (Age Check 18+)',
                          onTap: () => _onSimulateScan('cafe'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSimulationChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFFA78BFA).withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: const Color(0xFFA78BFA)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
