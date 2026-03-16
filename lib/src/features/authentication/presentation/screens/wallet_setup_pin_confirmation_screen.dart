import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypta/src/core/config/theme/app_colors.dart';
import 'package:qrypta/src/features/authentication/presentation/providers/pin_provider.dart';
import 'package:qrypta/src/features/home/presentation/screens/home_screen.dart';

class WalletSetupPinConfirmationScreen extends ConsumerWidget {
  final String pin;
  const WalletSetupPinConfirmationScreen({super.key, required this.pin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    log('Building WalletSetupPinConfirmationScreen', name: 'WalletSetupPinConfirmationScreen');
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
          'Confirm PIN',
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
                'Confirm your 6-digit PIN.',
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
                  hintText: 'Confirm 6-digit PIN',
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
                onPressed: () async {
                  log('Confirm button pressed', name: 'WalletSetupPinConfirmationScreen');
                  if (pinController.text == pin) {
                    log('PINs match. Saving PIN...', name: 'WalletSetupPinConfirmationScreen');
                    await ref.read(pinProvider.notifier).savePin(pin);
                    log('PIN saved. Navigating to HomeScreen', name: 'WalletSetupPinConfirmationScreen');
                    if (!context.mounted) return;
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HomeScreen(),
                      ),
                      (Route<dynamic> route) => false,
                    );
                  } else {
                    log('PINs do not match', name: 'WalletSetupPinConfirmationScreen');
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('PINs do not match. Please try again.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.background,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('CONFIRM'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
