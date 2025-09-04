import 'dart:developer';

import 'package:flutter/material.dart';
// Pastikan path import ini benar sesuai struktur proyek Anda
import 'package:qrypta/src/core/config/theme/app_colors.dart';
import 'package:qrypta/src/features/authentication/presentation/screens/wallet_setup_seed_phrase_screen.dart';

class WalletSetupScreen extends StatelessWidget {
  const WalletSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Log ini akan berjalan jika layar berhasil dibuat
    log('Building WalletSetupScreen', name: 'WalletSetupScreen');

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
                Icons.shield_outlined,
                size: 100,
                color: AppColors.primary,
              ),
              const SizedBox(height: 24),
              const Text(
                'Selamat Datang di Qrypta',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.font,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Dompet kripto pribadi yang aman dan terdesentralisasi.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.font.withOpacity(0.8),
                  fontSize: 16,
                ),
              ),
              const Spacer(),

              // Tombol Buat Dompet Baru dengan try-catch
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    try {
                      // Log paling atas untuk menandai fungsi dimulai
                      log(
                        'Memulai onPressed Buat Dompet Baru',
                        name: 'WalletSetupScreen',
                      );

                      // Logika asli Anda
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => const WalletSetupSeedPhraseScreen(),
                        ),
                      );

                      // Log di akhir untuk menandai fungsi selesai tanpa error
                      log(
                        'Berhasil menjalankan onPressed Buat Dompet Baru',
                        name: 'WalletSetupScreen',
                      );
                    } catch (e, stackTrace) {
                      // Blok ini akan menangkap error yang mungkin terjadi
                      print('🔴 TERJADI ERROR di Tombol Buat Dompet Baru 🔴');
                      log(
                        'Error di onPressed Buat Dompet Baru',
                        name: 'WalletSetupError',
                        error: e,
                        stackTrace: stackTrace,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.font,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'BUAT DOMPET BARU',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Tombol Import Dompet dengan try-catch
              SizedBox(
                height: 50,
                child: OutlinedButton(
                  onPressed: () {
                    try {
                      // Log paling atas untuk menandai fungsi dimulai
                      log(
                        'Memulai onPressed Import Dompet',
                        name: 'WalletSetupScreen',
                      );
                      print('Memulai onPressed Import Dompet');

                      // TODO: Arahkan ke halaman import via seed phrase
                      // Letakkan logika import Anda di sini

                      // Log di akhir untuk menandai fungsi selesai tanpa error
                      log(
                        'Berhasil menjalankan onPressed Import Dompet',
                        name: 'WalletSetupScreen',
                      );
                    } catch (e, stackTrace) {
                      // Blok ini akan menangkap error yang mungkin terjadi
                      print('🔴 TERJADI ERROR di Tombol Import Dompet 🔴');
                      log(
                        'Error di onPressed Import Dompet',
                        name: 'WalletSetupError',
                        error: e,
                        stackTrace: stackTrace,
                      );
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.font,
                    side: const BorderSide(color: AppColors.primary, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('SAYA SUDAH PUNYA DOMPET'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
