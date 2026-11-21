// lib/src/features/home/presentation/widgets/home_levy_banner.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypta/src/core/config/blockchain_config.dart';
import 'package:qrypta/src/features/transaction/logic/payment_controller.dart';
import 'package:qrypta/src/features/transaction/presentation/screens/levy_payment_screen.dart';
import 'package:qrypta/src/features/transaction/presentation/screens/levy_receipt_screen.dart';

/// Banner status pembayaran Tourist Levy (Paid settled vs Due) pada dashboard (Phase 3).
class HomeLevyBanner extends ConsumerWidget {
  final bool isPaid;
  final dynamic btidCred;

  const HomeLevyBanner({
    super.key,
    required this.isPaid,
    required this.btidCred,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isPaid) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF065F46).withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF34D399), size: 18),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Official Tourist Levy Settled',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Ref: ${btidCred?.levyReceiptRef ?? "-"}',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ],
            ),
            TextButton(
              onPressed: () {
                final txHash = btidCred?.levyTxHash ??
                    (ref.read(paymentControllerProvider).lastLevyReceipt?.txHash ?? '');

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
              child: const Text(
                'View Receipt',
                style: TextStyle(color: Color(0xFF2DD4BF), fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF78350F).withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFFBBF24), size: 20),
              SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tourist Levy Due (IDR 150,000)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Perda No. 6/2023 • Environmental Preservation',
                    style: TextStyle(
                      color: Color(0xFFD1D5DB),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LevyPaymentScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Pay Now',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
