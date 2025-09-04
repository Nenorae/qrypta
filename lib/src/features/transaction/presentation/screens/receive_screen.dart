import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as provider;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:qrypta/src/core/config/theme/app_colors.dart';
import 'package:qrypta/src/features/authentication/presentation/providers/auth_providers.dart';
import 'package:qrypta/src/features/transaction/logic/transaction_controller.dart';
import 'package:share_plus/share_plus.dart';

class ReceiveScreen extends ConsumerWidget {
  const ReceiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    developer.log('Building ReceiveScreen', name: 'ReceiveScreen');
    final authRepository = ref.watch(authRepositoryProvider);

    return provider.ChangeNotifierProvider(
      create: (_) => TransactionController(authRepository),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: AppColors.font),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: provider.Consumer<TransactionController>(
          builder: (context, controller, child) {
            if (controller.isLoading) {
              developer.log('ReceiveScreen: Loading wallet', name: 'ReceiveScreen');
              return const Center(child: CircularProgressIndicator());
            }

            final String? ethAddress = controller.ethAddress;
            if (ethAddress == null) {
              developer.log('ReceiveScreen: Wallet not loaded', name: 'ReceiveScreen');
              return const Center(child: Text('Could not load wallet.'));
            }

            final String truncatedAddress =
                '${ethAddress.substring(0, 8)}...${ethAddress.substring(ethAddress.length - 8)}';

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Receive',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.font,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        truncatedAddress,
                        style: const TextStyle(
                          color: AppColors.font,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      _buildCircleButton(
                        icon: Icons.share,
                        onTap: () {
                          developer.log('Sharing address: $ethAddress', name: 'ReceiveScreen');
                          Share.share('My Ethereum Address: $ethAddress');
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildCircleButton(
                        icon: Icons.copy,
                        onTap: () {
                          developer.log('Copying address: $ethAddress', name: 'ReceiveScreen');
                          Clipboard.setData(ClipboardData(text: ethAddress));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Address copied to clipboard!'),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: QrImageView(
                        data: ethAddress,
                        version: QrVersions.auto,
                        size: 220.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Scan address to receive payment!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.font, fontSize: 14),
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
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
                      child: const Text('DONE'),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primary.withOpacity(0.5),
        ),
        child: Icon(icon, color: AppColors.font, size: 20),
      ),
    );
  }
}
