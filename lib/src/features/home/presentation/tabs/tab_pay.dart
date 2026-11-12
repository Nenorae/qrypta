// lib/src/features/home/presentation/tabs/tab_pay.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qrypta/src/features/transaction/presentation/screens/qris_payment_screen.dart';
import 'package:qrypta/src/features/transaction/presentation/screens/send_scanner_screen.dart';
import 'package:qrypta/src/features/transaction/presentation/screens/send_screen.dart';
import 'package:qrypta/src/features/verification/data/policy_matrix_constants.dart';

class TabPay extends StatelessWidget {
  const TabPay({super.key});

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

    // Identifikasi merchant demo
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

    // Alamat EVM Standar
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

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SendScreen(initialAddress: rawData),
        ),
      );
      return;
    }

    // Default Fallback
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
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          SendScannerScreen(
            onScanResult: (result) => _handleScannedData(context, result),
          ),
          Positioned(
            top: 50,
            right: 16,
            child: SafeArea(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SendScreen()),
                  );
                },
                icon: const Icon(Icons.send_rounded, size: 16),
                label: const Text('Direct P2P', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B).withValues(alpha: 0.8),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
