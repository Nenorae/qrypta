
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypta/src/features/authentication/presentation/providers/auth_providers.dart';
import 'package:qrypta/src/features/authentication/presentation/screens/wallet_setup_seed_verification_screen.dart';

class WalletSetupSeedPhraseScreen extends ConsumerWidget {
  const WalletSetupSeedPhraseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    log('Building WalletSetupSeedPhraseScreen', name: 'WalletSetupSeedPhraseScreen');

    ref.listen<AsyncValue<String>>(mnemonicProvider, (previous, next) {
      log('mnemonicProvider listener triggered', name: 'WalletSetupSeedPhraseScreen');
      if (next is AsyncData<String>) {
        final mnemonicValue = next.value;
        log('Mnemonic received: "$mnemonicValue"', name: 'WalletSetupSeedPhraseScreen');
        final saveMnemonic = ref.read(saveMnemonicUseCaseProvider);
        log('Calling saveMnemonic use case', name: 'WalletSetupSeedPhraseScreen');
        saveMnemonic(mnemonicValue).then((_) {
          log('saveMnemonic use case completed', name: 'WalletSetupSeedPhraseScreen');
        }).catchError((e) {
          log('Error saving mnemonic: $e', name: 'WalletSetupSeedPhraseScreen', error: e);
        });
      }
    });

    final mnemonicAsyncValue = ref.watch(mnemonicProvider);

    return Scaffold(
      body: SafeArea(
        child: mnemonicAsyncValue.when(
          data: (mnemonic) {
            log('Mnemonic data available: "$mnemonic"', name: 'WalletSetupSeedPhraseScreen');
            final seedPhrase = mnemonic.split(' ');
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Write down or copy these words in the right order and save them somewhere safe.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: seedPhrase.map((word) {
                        return Chip(label: Text(word));
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      log('Continue button pressed', name: 'WalletSetupSeedPhraseScreen');
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              WalletSetupSeedVerificationScreen(
                            seedPhrase: seedPhrase,
                          ),
                        ),
                      );
                    },
                    child: const Text('CONTINUE'),
                  ),
                ],
              ),
            );
          },
          loading: () {
            log('Mnemonic is loading', name: 'WalletSetupSeedPhraseScreen');
            return const Center(child: CircularProgressIndicator());
          },
          error: (error, stackTrace) {
            log('Error fetching mnemonic: $error', name: 'WalletSetupSeedPhraseScreen', error: error, stackTrace: stackTrace);
            return Center(child: Text('Error: $error'));
          },
        ),
      ),
    );
  }
}
