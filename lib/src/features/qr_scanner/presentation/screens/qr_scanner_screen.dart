
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qrypta/src/core/config/theme/app_colors.dart';
import 'package:qrypta/src/features/transaction/presentation/screens/send_screen.dart';
import 'package:qrypta/src/features/transaction/presentation/screens/receive_screen.dart';
import 'package:qrypta/src/features/transaction/presentation/screens/send_scanner_screen.dart';
import 'package:qrypta/src/features/transaction/presentation/screens/qris_payment_screen.dart';
import 'package:qrypta/src/features/verification/data/policy_matrix_constants.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _handleScannedData(BuildContext context, String rawData) {
    try {
      if (rawData.startsWith('{') && rawData.endsWith('}')) {
        final decoded = jsonDecode(rawData);
        final type = decoded['type']?.toString().toUpperCase();
        if (type == 'QRIS' ||
            decoded.containsKey('merchantId') ||
            decoded.containsKey('amount')) {
          final merchantName = decoded['merchantName'] ??
              decoded['name'] ??
              'Bali Coffee House - Canggu';
          final merchantId =
              decoded['merchantId'] ?? decoded['id'] ?? 'MCH-3311';
          final merchantAddress = decoded['address'] ??
              decoded['walletAddress'] ??
              '0x3311A9908F8718E237aDE73708aB59f212284bE0';
          final amount =
              int.tryParse(decoded['amount']?.toString() ?? '85000') ?? 85000;
          final desc = decoded['description'] ??
              decoded['desc'] ??
              'Merchant Settlement';

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => QrisPaymentScreen(
                merchantName: merchantName,
                merchantId: merchantId,
                merchantAddress: merchantAddress,
                initialAmount: amount,
                itemDescription: desc,
              ),
            ),
          );
          return;
        }
      }
    } catch (_) {}

    // Check by known merchant identifiers
    if (rawData.contains('MCH-3311') || rawData.toLowerCase().contains('coffee')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const QrisPaymentScreen(
            merchantName: 'Bali Coffee House - Canggu',
            merchantId: 'MCH-3311',
            merchantAddress: '0x3311A9908F8718E237aDE73708aB59f212284bE0',
            initialAmount: 85000,
            itemDescription: 'Specialty Coffee & Pastry',
          ),
        ),
      );
      return;
    }

    if (rawData.contains('MCH-5520') || rawData.toLowerCase().contains('tour')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const QrisPaymentScreen(
            merchantName: 'Bali Adventure Tours',
            merchantId: 'MCH-5520',
            merchantAddress: '0x5520e5ff38a7c645bcf56b823e590d9a6c9cf141',
            initialAmount: 350000,
            itemDescription: 'Mount Batur Sunrise Trek',
          ),
        ),
      );
      return;
    }

    // Check by known EVM merchant address
    if (rawData.startsWith('0x') && rawData.length == 42) {
      final merchant = demoMerchants.values
          .where((m) => m.walletAddress.toLowerCase() == rawData.toLowerCase())
          .firstOrNull;
      if (merchant != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => QrisPaymentScreen(
              merchantName: merchant.name,
              merchantId: merchant.id,
              merchantAddress: merchant.walletAddress,
              initialAmount: merchant.category == 'cafe' ? 85000 : 150000,
              itemDescription: 'Merchant QRIS Service',
            ),
          ),
        );
        return;
      }

      // Standalone EVM Transfer
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SendScreen(initialAddress: rawData),
        ),
      );
      return;
    }

    // Default Fallback: Open QRIS confirmation screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const QrisPaymentScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            children: [
              SendScannerScreen(
                onScanResult: (scanned) {
                  _handleScannedData(context, scanned);
                },
              ),
              const ReceiveScreen(),
            ],
          ),
          _buildOverlayControls(),
        ],
      ),
    );
  }

  Widget _buildOverlayControls() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildControlButton(
              icon: Icons.close,
              onPressed: () => Navigator.of(context).pop(),
            ),
            _buildPageSwitcher(),
            const SizedBox(width: 48), // Spacer to balance the row
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton(
      {required IconData icon, required VoidCallback onPressed}) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }

  Widget _buildPageSwitcher() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(50),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSwitcherItem(text: 'Send', index: 0),
          const SizedBox(width: 4),
          _buildSwitcherItem(text: 'Receive', index: 1),
        ],
      ),
    );
  }

  Widget _buildSwitcherItem({required String text, required int index}) {
    final bool isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => _onPageChanged(index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(50),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isActive ? AppColors.accent : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
