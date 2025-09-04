// lib/src/features/authentication/presentation/screens/signup_screen.dart

import 'package:flutter/material.dart';
import '../../../../core/config/theme/app_colors.dart'; // Import warna kustom

class SignUpScreen extends StatelessWidget {
  const SignUpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 40.0,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Logo Aplikasi
                // TODO: Ganti Icon dengan widget Image.asset('assets/icons/logo.png') Anda
                const Icon(
                  Icons.shield, // Placeholder Logo
                  size: 100,
                  color: AppColors.accent,
                ),
                const SizedBox(height: 50),

                // 2. Form Username dan NIK (dalam satu baris)
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        label: 'Username',
                        hint: 'Username',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: _buildTextField(label: 'NIK', hint: 'NIK')),
                  ],
                ),
                const SizedBox(height: 20),

                // 3. Form Password
                _buildTextField(
                  label: 'Password',
                  hint: '••••••••',
                  isPassword: true,
                ),
                const SizedBox(height: 20),

                // 4. Form Konfirmasi Password
                _buildTextField(
                  label: 'Confirm Password',
                  hint: '••••••••',
                  isPassword: true,
                ),
                const SizedBox(height: 40),

                // 5. Tombol Sign Up
                SizedBox(
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () {
                      // TODO: Tambahkan logika untuk sign up
                      print('Tombol Sign Up ditekan');
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.font,
                      side: const BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'SIGN UP',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper widget untuk membuat form field agar tidak duplikat kode
  Widget _buildTextField({
    required String label,
    required String hint,
    bool isPassword = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.font,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          obscureText: isPassword,
          style: const TextStyle(color: AppColors.font),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.font.withOpacity(0.5)),
            filled: true,
            fillColor: AppColors.primary.withOpacity(0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }
}
