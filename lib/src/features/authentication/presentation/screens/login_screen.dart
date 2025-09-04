// lib/src/features/authentication/presentation/screens/login_screen.dart

import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypta/src/core/config/theme/app_colors.dart';
import 'package:qrypta/src/features/authentication/presentation/providers/wallet_provider.dart';
import 'package:qrypta/src/features/authentication/presentation/screens/wallet_setup_pin_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _mnemonicController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _mnemonicController.dispose();
    super.dispose();
  }

  void _importWallet() {
    if (_formKey.currentState!.validate()) {
      final mnemonic = _mnemonicController.text.trim();
      log('Importing wallet with mnemonic: $mnemonic', name: 'LoginScreen');
      
      // Use the existing provider to "create" (import) the wallet
      ref.read(walletProvider.notifier).createWallet(mnemonic);

      // Navigate to PIN setup screen
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const WalletSetupPinScreen(),
        ),
        (route) => route.isFirst,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Import Wallet', style: TextStyle(color: AppColors.font)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.font),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Enter your secret recovery phrase to restore your wallet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.font, fontSize: 16),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _mnemonicController,
                  maxLines: 4,
                  style: const TextStyle(color: AppColors.font),
                  decoration: InputDecoration(
                    hintText: 'Seed phrase...',
                    hintStyle: TextStyle(color: AppColors.font.withOpacity(0.5)),
                    filled: true,
                    fillColor: AppColors.primary.withOpacity(0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().split(' ').length < 12) {
                      return 'Please enter a valid seed phrase (usually 12, 18, or 24 words).';
                    }
                    return null;
                  },
                ),
                const Spacer(),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _importWallet,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.background,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'IMPORT',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
}
