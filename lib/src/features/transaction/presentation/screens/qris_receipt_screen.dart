// lib/src/features/transaction/presentation/screens/qris_receipt_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qrypta/src/core/config/theme/app_colors.dart';
import 'package:qrypta/src/features/home/presentation/screens/home_screen.dart';
import 'package:qrypta/src/features/transaction/logic/payment_controller.dart';

class QrisReceiptScreen extends StatelessWidget {
  final QrisReceiptData receipt;

  const QrisReceiptScreen({
    super.key,
    required this.receipt,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm:ss');
    final formattedDate = dateFormat.format(receipt.timestamp);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
              (route) => false,
            );
          },
        ),
        title: const Text(
          'Payment Receipt',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Success Pill & Icon
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFF065F46).withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF10B981), width: 2),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Color(0xFF34D399),
                    size: 36,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Payment Successful',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Merchant QRIS Settlement Completed',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              ),
              const SizedBox(height: 20),

              // 2. Receipt Card
              _buildReceiptCard(context, formattedDate),
              const SizedBox(height: 16),

              // 3. Privacy Guarantee Callout
              _buildPrivacySeal(),
              const SizedBox(height: 24),

              // 4. Action Buttons
              _buildActionButtons(context),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptCard(BuildContext context, String formattedDate) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Column(
        children: [
          // Amount Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                const Text(
                  'AMOUNT PAID',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                    letterSpacing: 1.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  receipt.amount,
                  style: const TextStyle(
                    color: Color(0xFF2DD4BF),
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ref: ${receipt.payRef}',
                  style: const TextStyle(
                    color: Color(0xFFCBD5E1),
                    fontFamily: 'monospace',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Details List
          Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              children: [
                _buildReceiptRow('Merchant', receipt.merchantName),
                const Divider(color: Color(0xFF1F2937), height: 18),
                _buildReceiptRow('Merchant ID', receipt.merchantId),
                const Divider(color: Color(0xFF1F2937), height: 18),
                _buildReceiptRow('Description', receipt.itemDescription),
                const Divider(color: Color(0xFF1F2937), height: 18),
                _buildReceiptRow('Funding Source', receipt.paymentMethod),
                const Divider(color: Color(0xFF1F2937), height: 18),
                _buildReceiptRow('Date & Time', formattedDate),
                const Divider(color: Color(0xFF1F2937), height: 18),
                _buildCopyableHashRow(context, 'Transaction Hash', receipt.txHash),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCopyableHashRow(BuildContext context, String label, String hash) {
    final shortHash = hash.length > 18
        ? '${hash.substring(0, 10)}...${hash.substring(hash.length - 8)}'
        : hash;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        ),
        InkWell(
          onTap: () {
            Clipboard.setData(ClipboardData(text: hash));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Transaction Hash copied to clipboard.'),
                backgroundColor: Color(0xFF0F766E),
                duration: Duration(seconds: 2),
              ),
            );
          },
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  shortHash,
                  style: const TextStyle(
                    color: Color(0xFF2DD4BF),
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.copy_rounded,
                  color: Color(0xFF2DD4BF),
                  size: 14,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrivacySeal() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2DD4BF).withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.verified_user_rounded, color: Color(0xFF2DD4BF), size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Zero-PII Privacy Protection',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'The merchant only received "Payment Confirmed". Zero passport numbers, nationality, biometric embeddings, or personal identity were exposed during this transaction.',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const HomeScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: const Color(0xFF0A0F1D),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Back to Dashboard',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Payment receipt saved to downloads.'),
                  backgroundColor: Color(0xFF0F766E),
                ),
              );
            },
            icon: const Icon(Icons.download_rounded, size: 18, color: Colors.white70),
            label: const Text(
              'Save Receipt (PDF)',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF334155)),
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
