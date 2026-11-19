// lib/src/features/qr_scanner/presentation/screens/qr_scanner_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypta/src/core/config/theme/app_colors.dart';
import 'package:qrypta/src/core/error/app_failure.dart';
import 'package:qrypta/src/core/providers/merchant_providers.dart';
import 'package:qrypta/src/core/services/qr/qr_payload_router.dart';
import 'package:qrypta/src/features/transaction/presentation/screens/qris_payment_screen.dart';
import 'package:qrypta/src/features/transaction/presentation/screens/receive_screen.dart';
import 'package:qrypta/src/features/transaction/presentation/screens/send_scanner_screen.dart';
import 'package:qrypta/src/features/transaction/presentation/screens/send_screen.dart';

/// Layar pemindai QR mandiri untuk Tab Scan (Phase 6 / F-14b).
/// Menggunakan `QrPayloadRouter` murni dan resolusi merchant otoritatif.
class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen> {
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

  Future<void> _handleScannedData(BuildContext context, String rawData) async {
    try {
      final routeResult = await QrPayloadRouter.routeAsync(rawData);

      if (!mounted) return;

      switch (routeResult) {
        case QrisRoute(:final qris):
          final nmid = qris.nmid;
          if (nmid == null || nmid.isEmpty) {
            _showErrorDialog(
              title: 'QRIS Tidak Lengkap',
              message:
                  'Kode QRIS tidak memuat National Merchant ID (NMID) yang valid.',
            );
            return;
          }

          // Resolusi merchant via ezsign-core konsorsium (Phase 6.3 / D-4)
          final resolver = ref.read(merchantResolverServiceProvider);
          final resolved = await resolver.resolve(nmid: nmid);

          if (!mounted) return;

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
      if (!mounted) return;
      _showErrorDialog(
        title: 'Merchant Belum Terdaftar',
        message:
            '${e.message}\n\nStiker QRIS fisik terhubung ke rail Rupiah perbankan/PJP. Pembayaran on-chain IDRT hanya diproses untuk merchant mitra konsorsium Qrypta terakreditasi.',
      );
    } on ValidationFailure catch (e) {
      if (!mounted) return;
      _showErrorDialog(
        title: 'QR Tidak Valid',
        message: e.message,
      );
    } on AppFailure catch (e) {
      if (!mounted) return;
      _showErrorDialog(
        title: 'Gagal Menghubungi Server',
        message: e.message,
      );
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog(
        title: 'Kesalahan Pemindaian',
        message: 'Gagal memproses kode QR: $e',
      );
    }
  }

  void _showErrorDialog({
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
