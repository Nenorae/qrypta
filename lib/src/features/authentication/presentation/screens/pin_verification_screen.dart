import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypta/src/core/config/theme/app_colors.dart';
import 'package:qrypta/src/features/authentication/presentation/providers/pin_provider.dart';

class PinVerificationScreen extends ConsumerStatefulWidget {
  final VoidCallback onVerificationSuccess;

  const PinVerificationScreen({
    super.key,
    required this.onVerificationSuccess, required Null Function(dynamic attempts) onVerificationFailed, required String subtitle, required String title,
  });

  @override
  ConsumerState<PinVerificationScreen> createState() =>
      _PinVerificationScreenState();
}

class _PinVerificationScreenState extends ConsumerState<PinVerificationScreen> {
  final pinController = TextEditingController();

  @override
  void dispose() {
    pinController.dispose();
    super.dispose();
  }

  Future<void> _verifyPin() async {
    if (pinController.text.isEmpty) return;

    log('Unlock button pressed with PIN: ${pinController.text}',
        name: 'PinVerificationScreen');
    final isPinCorrect = await ref
        .read(pinProvider.notifier)
        .verifyPin(pinController.text);
    log('PIN verification result: $isPinCorrect', name: 'PinVerificationScreen');

    if (!mounted) return;

    if (isPinCorrect) {
      log('PIN is correct. Calling onVerificationSuccess callback.',
          name: 'PinVerificationScreen');
      widget.onVerificationSuccess();
    } else {
      log('PIN is incorrect', name: 'PinVerificationScreen');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Incorrect PIN. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pinState = ref.watch(pinProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              const Text(
                'Enter Your PIN',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.font,
                    fontSize: 24,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Enter your 6-digit PIN to unlock your wallet.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.font, fontSize: 16),
              ),
              const SizedBox(height: 40),
              // PIN input field
              TextFormField(
                controller: pinController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                obscureText: true,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.font, fontSize: 24, letterSpacing: 12),
                decoration: InputDecoration(
                  counterText: "",
                  hintText: '------',
                  hintStyle: TextStyle(color: AppColors.font.withOpacity(0.5), fontSize: 24, letterSpacing: 12),
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
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: pinState.isLoading ? null : _verifyPin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.background,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: pinState.isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: AppColors.background,
                            strokeWidth: 3,
                          ),
                        )
                      : const Text('UNLOCK'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
