import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qrypta/src/core/config/theme/app_colors.dart';
import 'package:qrypta/src/core/data/models/token_model.dart';
import 'package:qrypta/src/features/home/presentation/providers/home_providers.dart';

// WIDGET 1: Bagian Saldo
class BalanceSection extends ConsumerWidget {
  const BalanceSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalBalanceAsync = ref.watch(totalBalanceProvider);
    final NumberFormat currencyFormatter =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp. ', decimalDigits: 2);

    return totalBalanceAsync.when(
      data: (balance) {
        return Column(
          children: [
            Text(
              currencyFormatter.format(balance.totalValueInIdr),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Total Balance (GLD/IDRT)',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }
}

// WIDGET 3: Bagian Daftar Aset
class AssetList extends ConsumerWidget {
  const AssetList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalBalanceAsync = ref.watch(totalBalanceProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: totalBalanceAsync.when(
        data: (balance) {
          final List<TokenModel> allAssets = [
            // Add Native ETH explicitly at the top
            TokenModel(
              contractAddress: 'native',
              symbol: 'ETH',
              name: 'Ethereum (Gas Fee Asset)',
              decimals: 18,
              balance: balance.nativeBalance.getInWei,
              logoUrl:
                  'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/ethereum/info/logo.png',
            ),
            ...balance.tokenBalances,
          ];

          return Column(
            children: allAssets.map((token) {
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
    final balanceDouble = balance.toDouble() / pow(10, decimals);
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
                placeholder: (context, url) =>
                    Center(child: Text(token.symbol[0])),
                errorWidget: (context, url, error) =>
                    const Icon(Icons.token), // Placeholder icon
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
                  Text(_formatBalance(token.balance, token.decimals),
                      style: const TextStyle(color: Colors.white70)),
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
