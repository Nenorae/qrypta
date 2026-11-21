// lib/src/features/home/presentation/widgets/home_portfolio_section.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qrypta/src/core/config/theme/app_colors.dart';
import 'package:qrypta/src/features/verification/presentation/screens/dynamic_qr_screen.dart';

/// Bar ringkasan saldo IDRT dan alamat dompet EVM wisatawan (Phase 3).
class HomePortfolioBar extends StatelessWidget {
  final String balance;
  final String? walletAddress;

  const HomePortfolioBar({
    super.key,
    required this.balance,
    required this.walletAddress,
  });

  @override
  Widget build(BuildContext context) {
    final shortWallet = (walletAddress != null && walletAddress!.length > 14)
        ? '${walletAddress!.substring(0, 6)}...${walletAddress!.substring(walletAddress!.length - 4)}'
        : (walletAddress ?? '0x71CB...B4D0');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2DD4BF).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Color(0xFF2DD4BF),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'IDRT Balance (Besu)',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    balance,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          InkWell(
            onTap: () {
              if (walletAddress != null) {
                Clipboard.setData(ClipboardData(text: walletAddress!));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Wallet address copied to clipboard.'),
                    backgroundColor: Color(0xFF0F766E),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Row(
                children: [
                  Text(
                    shortWallet,
                    style: const TextStyle(
                      color: Color(0xFF2DD4BF),
                      fontFamily: 'monospace',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.copy_rounded, size: 12, color: Color(0xFF2DD4BF)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bar tombol shortcut cepat dashboard (Show my ID & Pay with QRIS).
class HomeQuickActionBar extends StatelessWidget {
  final void Function(int tabIndex) onNavigateToTab;

  const HomeQuickActionBar({super.key, required this.onNavigateToTab});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Show my ID
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DynamicQrScreen()),
              );
            },
            icon: const Icon(Icons.qr_code_2_rounded, size: 20),
            label: const Text(
              'Show my ID',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Pay with QRIS
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => onNavigateToTab(1), // Switch ke Tab Pay
            icon: const Icon(Icons.payment_rounded, size: 20),
            label: const Text(
              'Pay with QRIS',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: const Color(0xFF0A0F1D),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
