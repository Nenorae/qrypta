// lib/src/features/transaction/presentation/widgets/levy_action_buttons.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypta/src/core/config/blockchain_config.dart';
import 'package:qrypta/src/core/config/theme/app_colors.dart';
import 'package:qrypta/src/features/home/presentation/screens/home_screen.dart';
import 'package:qrypta/src/features/transaction/logic/payment_controller.dart';
import 'package:qrypta/src/features/transaction/presentation/screens/levy_receipt_screen.dart';

/// Tombol aksi pembayaran retribusi (proses bayar, loading state, pay later) (Phase 3).
class LevyPayAction extends StatelessWidget {
  final PaymentState state;
  final VoidCallback onPay;

  const LevyPayAction({
    super.key,
    required this.state,
    required this.onPay,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: state.isLoading ? null : onPay,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: const Color(0xFF0A0F1D),
              disabledBackgroundColor: const Color(0xFF334155),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: state.isLoading
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        state.isTransferring
                            ? 'Transferring IDRT On-Chain...'
                            : 'Authorizing Biometrics...',
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.lock_outline_rounded, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Pay IDR 150,000',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: state.isLoading
              ? null
              : () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const HomeScreen()),
                    (route) => false,
                  );
                },
          child: const Text(
            'Pay later (Continue to Dashboard)',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

/// Tombol aksi setelah retribusi lunas (lihat kuitansi & kembali ke dashboard) (Phase 3).
class LevyPaidAction extends ConsumerWidget {
  final dynamic btidCred;

  const LevyPaidAction({super.key, required this.btidCred});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentState = ref.watch(paymentControllerProvider);
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () {
              final txHash = btidCred?.levyTxHash ??
                  (paymentState.lastLevyReceipt?.txHash ?? '');

              if (txHash.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Kuitansi transaksi belum terbit di blockchain.'),
                    backgroundColor: Colors.orangeAccent,
                  ),
                );
                return;
              }

              final receiptRef = btidCred?.levyReceiptRef ?? 'LVY-PENDING';
              final btidNumber = btidCred?.btidNumber ?? 'BTID-UNREGISTERED';
              final receipt = LevyReceiptData(
                receiptRef: receiptRef,
                touristName: btidCred?.fullName ?? 'Tourist',
                btidNumber: btidNumber,
                passportMasked: btidCred?.passportMasked ?? '••••••',
                amount: 'IDR 150,000',
                amountRaw: 150000,
                paymentMethod: 'Qrypta IDRT Wallet Balance',
                txHash: txHash,
                timestamp: DateTime.now(),
                bapendaAddress: BlockchainConfig.bapendaTreasuryAddress,
                mrzLine1: LevyReceiptData.generateMrzLine1(receiptRef, 150000),
                mrzLine2: LevyReceiptData.generateMrzLine2(btidNumber),
              );

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LevyReceiptScreen(receipt: receipt),
                ),
              );
            },
            icon: const Icon(Icons.receipt_long_rounded, size: 20),
            label: const Text(
              'View Official Levy Receipt',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
              (route) => false,
            );
          },
          child: const Text(
            'Back to Dashboard',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
          ),
        ),
      ],
    );
  }
}
