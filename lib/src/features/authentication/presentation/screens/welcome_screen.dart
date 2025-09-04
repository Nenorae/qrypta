// lib/src/features/authentication/presentation/screens/welcome_screen.dart

import 'package:flutter/material.dart';
import 'package:qrypta/src/core/config/theme/app_colors.dart';
import 'package:qrypta/src/features/authentication/presentation/screens/signup_screen.dart';
import 'package:qrypta/src/features/authentication/presentation/screens/login_screen.dart'; // <-- Import LoginScreen

// import 'package:flutter_wallet/src/features/authentication/presentation/screens/login_screen.dart'; // Nanti dibuat

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // Logo Aplikasi
              const Icon(
                Icons.shield, // Placeholder Logo
                size: 100,
                color: AppColors.accent,
              ),
              const SizedBox(height: 24),
              const Text(
                'Selamat Datang',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.font,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Dompet digital terpercaya untuk semua kebutuhan Anda.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.font.withOpacity(0.8),
                  fontSize: 16,
                ),
              ),
              const Spacer(),

              // Tombol Buat Akun Baru
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SignUpScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.background,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'BUAT DOMPET',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Tombol Sudah Punya Akun
              SizedBox(
                height: 50,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(), // <-- Arahkan ke LoginScreen
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.font,
                    side: const BorderSide(color: AppColors.primary, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('IMPOR DOMPET'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
