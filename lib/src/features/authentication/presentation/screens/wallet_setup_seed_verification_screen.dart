import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypta/src/core/config/theme/app_colors.dart';
import 'package:qrypta/src/features/authentication/presentation/providers/wallet_provider.dart';
import 'package:qrypta/src/features/authentication/presentation/screens/wallet_setup_pin_screen.dart';

class WalletSetupSeedVerificationScreen extends ConsumerStatefulWidget {
  final List<String> seedPhrase;

  const WalletSetupSeedVerificationScreen({super.key, required this.seedPhrase});

  @override
  ConsumerState<WalletSetupSeedVerificationScreen> createState() =>
      _WalletSetupSeedVerificationScreenState();
}

class _WalletSetupSeedVerificationScreenState extends ConsumerState<WalletSetupSeedVerificationScreen> {
  List<String> shuffledSeedPhrase = [];
  List<String> selectedWords = [];

  @override
  void initState() {
    super.initState();
    log('Initializing WalletSetupSeedVerificationScreen', name: 'WalletSetupSeedVerificationScreen');
    log('Original seed phrase: ${widget.seedPhrase.join(' ')}', name: 'WalletSetupSeedVerificationScreen');
    shuffledSeedPhrase = List.from(widget.seedPhrase)..shuffle();
    log('Shuffled seed phrase: ${shuffledSeedPhrase.join(' ')}', name: 'WalletSetupSeedVerificationScreen');
  }

  void _onWordSelected(String word) {
    setState(() {
      log('Word selected: $word', name: 'WalletSetupSeedVerificationScreen');
      selectedWords.add(word);
      shuffledSeedPhrase.remove(word);
      log('Selected words: ${selectedWords.join(' ')}', name: 'WalletSetupSeedVerificationScreen');
    });
  }

  void _onWordDeselected(String word) {
    setState(() {
      log('Word deselected: $word', name: 'WalletSetupSeedVerificationScreen');
      selectedWords.remove(word);
      shuffledSeedPhrase.add(word);
      log('Selected words: ${selectedWords.join(' ')}', name: 'WalletSetupSeedVerificationScreen');
    });
  }

  void _verifySeedPhrase() {
    log('Verify button pressed', name: 'WalletSetupSeedVerificationScreen');
    final isCorrect = selectedWords.join(' ') == widget.seedPhrase.join(' ');
    log('Verification result: $isCorrect', name: 'WalletSetupSeedVerificationScreen');

    if (isCorrect) {
      log('Seed phrase is correct. Creating wallet...', name: 'WalletSetupSeedVerificationScreen');
      ref.read(walletProvider.notifier).createWallet(widget.seedPhrase.join(' '));
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const WalletSetupPinScreen(),
        ),
      );
    } else {
      log('Seed phrase is incorrect', name: 'WalletSetupSeedVerificationScreen');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Incorrect seed phrase. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    log('Building WalletSetupSeedVerificationScreen', name: 'WalletSetupSeedVerificationScreen');
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
          'Verify Recovery Phrase',
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
                'Tap the words to put them next to each other in the correct order.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.font, fontSize: 16),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: selectedWords.map((word) {
                    return Chip(
                      label: Text(word),
                      onDeleted: () => _onWordDeselected(word),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: shuffledSeedPhrase.map((word) {
                  return ElevatedButton(
                    onPressed: () => _onWordSelected(word),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.font,
                    ),
                    child: Text(word),
                  );
                }).toList(),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _verifySeedPhrase,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.background,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('VERIFY'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}