import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypta/src/features/authentication/presentation/providers/auth_providers.dart';
import 'package:qrypta/src/features/authentication/presentation/screens/wallet_setup_screen.dart';

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    log('Building AuthWrapper', name: 'AuthWrapper');
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (hasWallet) {
        // In the new architecture, this widget is only reached if the user
        // does NOT have a wallet. So we always direct to the setup screen.
        log(
          'AuthWrapper: Navigating to WalletSetupScreen',
          name: 'AuthWrapper',
        );
        return const WalletSetupScreen();
      },
      loading: () {
        log('AuthWrapper: Loading auth state', name: 'AuthWrapper');
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
      error: (error, stackTrace) {
        log(
          'AuthWrapper: Error loading auth state: $error',
          name: 'AuthWrapper',
          error: error,
          stackTrace: stackTrace,
        );
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.redAccent,
                    size: 60,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Something Went Wrong',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'We couldn\'t check your wallet status. Please restart the app and try again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
