// lib/src/features/authentication/presentation/screens/welcome_screen.dart

import 'package:flutter/material.dart';
import 'package:qrypta/src/core/config/theme/app_colors.dart';
import 'package:qrypta/src/core/utils/mrz_parser.dart';
import 'package:qrypta/src/features/authentication/presentation/screens/login_screen.dart';
import 'package:qrypta/src/features/authentication/presentation/screens/mrz_scanner_screen.dart';
import 'package:qrypta/src/features/authentication/presentation/screens/passport_verification_flow_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              // Header Badge Ekosistem
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.shield_outlined,
                        size: 14,
                        color: AppColors.accent,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'BALI TOURIST TRUST ECOSYSTEM',
                        style: TextStyle(
                          color: AppColors.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Visual Hero Icon
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.accent.withValues(alpha: 0.25),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF0F3B37),
                        border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.6),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withValues(alpha: 0.25),
                            blurRadius: 18,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.verified_user_rounded,
                        size: 44,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Judul Utama (Sesuai Mockup ScrWelcome)
              const Text(
                'Verify once.\nShare only what is required.\nExplore Bali.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  height: 1.25,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Official digital tourist identity anchored on-chain with cryptographic privacy guarantees.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),

              // 4 Pilar Edukatif Privasi
              _buildFeatureCard(
                icon: Icons.lock_clock_rounded,
                iconColor: const Color(0xFF2DD4BF),
                title: 'Verify once, stay secure',
                description:
                    'Read passport once. Keep your physical passport safe in hotel deposit box.',
              ),
              const SizedBox(height: 12),
              _buildFeatureCard(
                icon: Icons.shield_rounded,
                iconColor: const Color(0xFFA78BFA),
                title: 'Zero physical photocopies',
                description:
                    'Merchants verify attributes digitally with purpose limitation and explicit consent.',
              ),
              const SizedBox(height: 12),
              _buildFeatureCard(
                icon: Icons.history_edu_rounded,
                iconColor: const Color(0xFFFBBF24),
                title: 'Tamper-evident audit trail',
                description:
                    'Every sharing transaction is cryptographically signed and stored on Hyperledger Besu.',
              ),
              const SizedBox(height: 36),

              // Tombol Utama: Set up my Tourist ID
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MrzScannerScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: const Color(0xFF0A0F1D),
                    elevation: 4,
                    shadowColor: AppColors.accent.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text(
                        'Set up my Tourist ID',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Tombol Impor / Login Wallet yang sudah ada
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'I already have an ID / Import Wallet',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Tombol Bypass Evaluator / Demo Cepat (1 Klik James Wilson)
              TextButton(
                onPressed: () {
                  final demoResult = MrzParseResult.demoJamesWilson();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PassportVerificationFlowScreen(
                        mrzResult: demoResult,
                      ),
                    ),
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.play_circle_outline_rounded,
                      size: 16,
                      color: AppColors.accent.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Fast Demo Mode (James Wilson)',
                      style: TextStyle(
                        color: AppColors.accent.withValues(alpha: 0.8),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 12,
                    height: 1.35,
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
