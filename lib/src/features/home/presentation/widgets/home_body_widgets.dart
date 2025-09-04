
// lib/src/features/home/presentation/widgets/home_body_widgets.dart

import 'package:flutter/material.dart';
import 'package:qrypta/src/core/config/theme/app_colors.dart';

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
class AssetList extends StatelessWidget {
  const AssetList({super.key});

  // Dummy data dipindahkan ke sini agar relevan dengan widgetnya
  final List<Map<String, String>> assets = const [
    {'icon': '₿', 'name': 'Bitcoin', 'value': 'Rp. 1.742.260.105,49'},
    {'icon': 'Ξ', 'name': 'Ethereum', 'value': 'Rp. 41.660.221,98'},
    {'icon': '♦', 'name': 'BNB', 'value': 'Rp. 10.706.068,24'},
    {'icon': 'S', 'name': 'Solana', 'value': 'Rp. 2.150.789,12'},
    {'icon': '₮', 'name': 'Tether USDT', 'value': 'Rp. 16.350,00'},
    {'icon': 'D', 'name': 'Dogecoin', 'value': 'Rp. 2.500,75'},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: assets.map((asset) {
          return _AssetListItem(
            icon: asset['icon']!,
            name: asset['name']!,
            value: asset['value']!,
            onTap: () => print('${asset['name']} ditekan'),
          );
        }).toList(),
      ),
    );
  }
}


// --- WIDGET HELPER (Private) ---

// Helper untuk Item Aset (sekarang menjadi widget private)
class _AssetListItem extends StatelessWidget {
  final String icon;
  final String name;
  final String value;
  final VoidCallback onTap;

  const _AssetListItem({
    required this.icon,
    required this.name,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.background,
              child: Text(
                icon,
                style: const TextStyle(color: AppColors.accent, fontSize: 20),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(value, style: const TextStyle(color: Colors.white70)),
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
