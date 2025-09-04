import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypta/src/core/config/theme/app_colors.dart';
import 'package:qrypta/src/core/services/authentication_service.dart';
import 'package:qrypta/src/features/authentication/presentation/providers/auth_providers.dart';
import 'package:qrypta/src/features/profile/presentation/providers/security_settings_provider.dart';
import 'package:qrypta/src/features/profile/presentation/screens/change_pin_screen.dart';
import 'package:qrypta/src/features/profile/presentation/screens/reveal_secret_screen.dart' as reveal_secret;

class SecurityGroup extends ConsumerWidget {
  const SecurityGroup({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(securitySettingsProvider);
    final walletSecrets = ref.watch(walletSecretsProvider);

    return _buildGroupContainer(
      context,
      title: 'Security',
      children: [
        walletSecrets.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) {
            log('Error loading wallet secrets: $err', name: 'SecurityGroup', error: err, stackTrace: stack);
            return Text('Error: $err');
          },
          data: (secrets) {
            final mnemonic = secrets['mnemonic'];
            final privateKey = secrets['privateKey'];
            log('Wallet secrets loaded: mnemonic is ${mnemonic != null ? 'present' : 'absent'}, private key is ${privateKey != null ? 'present' : 'absent'}', name: 'SecurityGroup');

            return Column(
              children: [
                _buildListTile(
                  context,
                  title: 'Show Recovery Phrase',
                  onTap:
                      mnemonic != null
                          ? () {
                              log('Show Recovery Phrase tapped', name: 'SecurityGroup');
                              _handleSecretReveal(
                                context,
                                title: 'Recovery Phrase',
                                secretData: mnemonic,
                                warningText:
                                    'Anyone with this phrase can access your funds. Store it securely.',
                                type:
                                    reveal_secret
                                        .SecretType
                                        .mnemonic, // ✅ TAMBAHKAN BARIS INI
                              );
                            }
                          : null,
                ),
                _buildListTile(
                  context,
                  title: 'Change PIN',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ChangePinScreen()),
                    );
                  },
                ),
                _buildListTile(
                  context,
                  title: 'Auto-Lock',
                  trailing: settings.isLoading ? 'Loading...' : settings.durationText,
                  onTap: () => _showAutoLockOptions(context, ref),
                ),
                _buildListTile(
                  context,
                  title: 'Show Private Key',
                  onTap:
                      privateKey != null
                          ? () {
                              log('Show Private Key tapped', name: 'SecurityGroup');
                              _handleSecretReveal(
                                context,
                                title: 'Private Key',
                                secretData: privateKey,
                                warningText:
                                    'Exposing your private key is risky. Only do this if you know what you are doing.',
                                type:
                                    reveal_secret
                                        .SecretType
                                        .privateKey, // ✅ TAMBAHKAN BARIS INI
                              );
                            }
                          : null,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _handleSecretReveal(BuildContext context, {
    required String title,
    required String secretData,
    required String warningText,
    required reveal_secret.SecretType type,
  }) async {
    log('Attempting to reveal $title', name: 'SecurityGroup');
    final isAuthenticated = await AuthenticationService.authenticate(
      'Please authenticate to reveal your $title',
    );

    if (isAuthenticated && context.mounted) {
      log('Authentication successful for $title', name: 'SecurityGroup');
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => reveal_secret.RevealSecretScreen(
            title: title,
            secretData: secretData,
            warningText: warningText,
            type: type,
          ),
        ),
      );
    } else if (context.mounted) {
      log('Authentication failed for $title', name: 'SecurityGroup');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Authentication Failed')),
      );
    }
  }

  void _showAutoLockOptions(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(securitySettingsProvider.notifier);
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            // 👇 Perbaikan ada di baris ini
            children: 
                notifier.allDurations.entries.map((entry) {
                  // 'entry' sekarang adalah sebuah MapEntry,
                  // sehingga Anda bisa memanggil entry.key dan entry.value
                  return ListTile(
                    title: Text(entry.value),
                    onTap: () {
                      notifier.updateDuration(entry.key);
                      Navigator.of(context).pop();
                    },
                  );
                }).toList(), // .toList() sekarang bisa digunakan dengan benar
          ),
        );
      },
    );
  }

  Widget _buildGroupContainer(BuildContext context, {required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _buildListTile(BuildContext context, {required String title, String? trailing, VoidCallback? onTap}) {
    return ListTile(
      title: Text(title, style: const TextStyle(color: Colors.white)),
      trailing: trailing != null
          ? Text(trailing, style: const TextStyle(color: Colors.white70))
          : const Icon(Icons.chevron_right, color: Colors.white54),
      onTap: onTap,
      enabled: onTap != null,
      contentPadding: EdgeInsets.zero,
    );
  }
}
