import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypta/src/core/config/theme/app_colors.dart';
import 'package:qrypta/src/features/authentication/presentation/screens/wallet_setup_pin_confirmation_screen.dart';

class WalletSetupPinScreen extends ConsumerWidget {
  const WalletSetupPinScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    log('Building WalletSetupPinScreen', name: 'WalletSetupPinScreen');
    final pinController = TextEditingController();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.font),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Create PIN',
          style: TextStyle(color: AppColors.font),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Create a 6-digit PIN to secure your wallet.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.font, fontSize: 16),
              ),
              const SizedBox(height: 24),
              // PIN input field
              TextFormField(
                controller: pinController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                obscureText: true,
                style: const TextStyle(color: AppColors.font),
                decoration: InputDecoration(
                  hintText: 'Enter 6-digit PIN',
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
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  log('Continue button pressed with PIN: ${pinController.text}', name: 'WalletSetupPinScreen');
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WalletSetupPinConfirmationScreen(
                        pin: pinController.text,
                      ),
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
                child: const Text('CONTINUE'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
