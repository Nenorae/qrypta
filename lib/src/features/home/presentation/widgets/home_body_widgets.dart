
// lib/src/features/home/presentation/widgets/home_body_widgets.dart

import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypta/src/core/config/theme/app_colors.dart';
import 'package:qrypta/src/core/data/models/token_model.dart';
import 'package:qrypta/src/features/tokens/presentation/providers/token_provider.dart';

// WIDGET 1: Bagian Saldo
class BalanceSection extends StatelessWidget {
  const BalanceSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Text(
          'RP. 253.456.782,21',
          style: TextStyle(
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4),
        Text(
          '~ 0.145406 BTC',
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
      ],
    );
  }
}

// WIDGET 3: Bagian Daftar Aset
class AssetList extends ConsumerWidget {
  const AssetList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokensAsync = ref.watch(tokenNotifierProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: tokensAsync.when(
        data: (tokens) {
          if (tokens.isEmpty) {
            return const Center(child: Text('No assets found.'));
          }
          return Column(
            children: tokens.map((token) {
              return _AssetListItem(
                token: token,
                onTap: () => print('${token.name} ditekan'),
              );
            }).toList(),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error: $error'),
        ),
      ),
    );
  }
}


// --- WIDGET HELPER (Private) ---

// Helper untuk Item Aset (sekarang menjadi widget private)
class _AssetListItem extends StatelessWidget {
  final TokenModel token;
  final VoidCallback onTap;

  const _AssetListItem({
    required this.token,
    required this.onTap,
  });

  String _formatBalance(BigInt balance, int decimals) {
    if (balance == BigInt.zero) {
      return '0';
    }
    final balanceDouble = balance / BigInt.from(pow(10, decimals));
    return balanceDouble.toStringAsFixed(4); // Tampilkan 4 angka desimal
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CachedNetworkImage(
                imageUrl: token.logoUrl ?? '', // Use empty string for null to avoid errors
                placeholder: (context, url) => Center(child: Text(token.symbol[0])),
                errorWidget: (context, url, error) => const Icon(Icons.token), // Placeholder icon
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    token.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(_formatBalance(token.balance, token.decimals), style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white54),
          ],
        ),
      ),
    );
  }
}
