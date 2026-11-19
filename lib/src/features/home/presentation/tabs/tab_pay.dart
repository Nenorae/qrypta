// lib/src/features/home/presentation/tabs/tab_pay.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypta/src/core/error/app_failure.dart';
import 'package:qrypta/src/core/providers/merchant_providers.dart';
import 'package:qrypta/src/core/services/qr/qr_payload_router.dart';
import 'package:qrypta/src/features/transaction/presentation/screens/qris_payment_screen.dart';
import 'package:qrypta/src/features/transaction/presentation/screens/send_scanner_screen.dart';
import 'package:qrypta/src/features/transaction/presentation/screens/send_screen.dart';

/// Tab Pembayaran QRIS & Transfer Dompet (Phase 6 / F-14).
/// Menggunakan `QrPayloadRouter` murni, parsing QRIS di background isolate,
/// dan resolusi merchant otoritatif tanpa string-match primitif atau fallback palsu.
class TabPay extends ConsumerWidget {
  const TabPay({super.key});

  Future<void> _handleScannedData(
    BuildContext context,
    WidgetRef ref,
    String rawData,
  ) async {
    try {
      final routeResult = await QrPayloadRouter.routeAsync(rawData);

      if (!context.mounted) return;

      switch (routeResult) {
        case QrisRoute(:final qris):
          final nmid = qris.nmid;
          if (nmid == null || nmid.isEmpty) {
            _showErrorDialog(
              context,
              title: 'QRIS Tidak Lengkap',
              message:
                  'Kode QRIS tidak memuat National Merchant ID (NMID) yang valid.',
            );
            return;
          }

          // Resolusi merchant via ezsign-core konsorsium (Phase 6.3 / D-4)
          final resolver = ref.read(merchantResolverServiceProvider);
          final resolved = await resolver.resolve(nmid: nmid);

          if (!context.mounted) return;

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => QrisPaymentScreen(
                merchantName: resolved.displayName,
                merchantId: resolved.merchantId,
                merchantAddress: resolved.walletAddress,
                initialAmount: (qris.transactionAmount ?? 0.0).toInt(),
                itemDescription: qris.additionalData?.storeLabel ??
                    qris.additionalData?.billNumber ??
                    'Pembayaran QRIS Merchant',
                isAmountLocked: qris.isDynamic,
              ),
            ),
          );
          return;

        case WalletAddressRoute(:final address):
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SendScreen(initialAddress: address),
            ),
          );
          return;

        case NativeQryptaRoute(:final type):
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('QR Native Qrypta terdeteksi: $type'),
              backgroundColor: const Color(0xFF0F766E),
            ),
          );
          return;
      }
    } on MerchantNotRegistered catch (e) {
      if (!context.mounted) return;
      _showErrorDialog(
        context,
        title: 'Merchant Belum Terdaftar',
        message:
            '${e.message}\n\nStiker QRIS fisik terhubung ke rail Rupiah perbankan/PJP. Pembayaran on-chain IDRT hanya diproses untuk merchant mitra konsorsium Qrypta terakreditasi.',
      );
    } on ValidationFailure catch (e) {
      if (!context.mounted) return;
      _showErrorDialog(
        context,
        title: 'QR Tidak Valid',
        message: e.message,
      );
    } on AppFailure catch (e) {
      if (!context.mounted) return;
      _showErrorDialog(
        context,
        title: 'Gagal Menghubungi Server',
        message: e.message,
      );
    } catch (e) {
      if (!context.mounted) return;
      _showErrorDialog(
        context,
        title: 'Kesalahan Pemindaian',
        message: 'Gagal memproses kode QR: $e',
      );
    }
  }

  void _showErrorDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Color(0xFFF43F5E), size: 24),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Tutup', style: TextStyle(color: Color(0xFF2DD4BF))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          SendScannerScreen(
            onScanResult: (result) => _handleScannedData(context, ref, result),
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
                  backgroundColor:
                      const Color(0xFF1E293B).withValues(alpha: 0.8),
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
