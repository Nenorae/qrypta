import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypta/src/core/config/theme/app_colors.dart';
import 'package:qrypta/src/features/authentication/presentation/providers/pin_provider.dart';

class PinVerificationScreen extends ConsumerStatefulWidget {
  final VoidCallback onVerificationSuccess;
  final void Function(int attempts)? onVerificationFailed;
  final String title;
  final String subtitle;

  const PinVerificationScreen({
    super.key,
    required this.onVerificationSuccess,
    this.onVerificationFailed,
    this.title = 'Enter PIN',
    this.subtitle = 'Please enter your 6-digit PIN to continue',
  });

  @override
  ConsumerState<PinVerificationScreen> createState() =>
      _PinVerificationScreenState();
}

class _PinVerificationScreenState extends ConsumerState<PinVerificationScreen> {
  final pinController = TextEditingController();
  int _failedAttempts = 0;

  @override
  void dispose() {
    pinController.dispose();
    super.dispose();
  }

  Future<void> _verifyPin() async {
    if (pinController.text.isEmpty) {
      return;
    }

    final isPinCorrect = await ref
        .read(pinProvider.notifier)
        .verifyPin(pinController.text);

    if (!mounted) {
      return;
    }

    if (isPinCorrect) {
      widget.onVerificationSuccess();
    } else {
      _failedAttempts++;
      widget.onVerificationFailed?.call(_failedAttempts);
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
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.font,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.font, fontSize: 16),
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
                  color: AppColors.font,
                  fontSize: 24,
                  letterSpacing: 12,
                ),
                decoration: InputDecoration(
                  counterText: "",
                  hintText: '------',
                  hintStyle: TextStyle(
                    color: AppColors.font.withValues(alpha: 0.5),
                    fontSize: 24,
                    letterSpacing: 12,
                  ),
                  filled: true,
                  fillColor: AppColors.primary.withValues(alpha: 0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                onChanged: (value) {
                  if (value.length == 6) {
                    _verifyPin();
                  }
                },
              ),
              const Spacer(),
              // Verify Button
              ElevatedButton(
                onPressed: pinState.isLoading ? null : _verifyPin,
                child: pinState.isLoading
                    ? const CircularProgressIndicator()
                    : const Text(
                        'Verify',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
