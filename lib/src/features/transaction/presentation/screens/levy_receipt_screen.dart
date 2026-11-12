// lib/src/features/transaction/presentation/screens/levy_receipt_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qrypta/src/core/config/theme/app_colors.dart';
import 'package:qrypta/src/features/home/presentation/screens/home_screen.dart';
import 'package:qrypta/src/features/transaction/logic/payment_controller.dart';

class LevyReceiptScreen extends StatelessWidget {
  final LevyReceiptData receipt;

  const LevyReceiptScreen({
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
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Levy Receipt',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Color(0xFF2DD4BF)),
            tooltip: 'Share Receipt',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Receipt shared successfully.'),
                  backgroundColor: Color(0xFF0F766E),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Official Government Header & Emblem
              _buildGovernmentHeader(),
              const SizedBox(height: 16),

              // 2. Receipt Card
              _buildReceiptCard(context, formattedDate),
              const SizedBox(height: 16),

              // 3. Digital MRZ Strip
              _buildMrzStrip(context),
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

  Widget _buildGovernmentHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.account_balance_rounded, color: Color(0xFFF59E0B), size: 22),
              SizedBox(width: 8),
              Text(
                'PEMERINTAH PROVINSI BALI',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'BADAN PENDAPATAN DAERAH (BAPENDA)',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 11,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF065F46).withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.check_circle_rounded, color: Color(0xFF34D399), size: 14),
                SizedBox(width: 6),
                Text(
                  'RECONCILED ON-CHAIN • IMMUTABLE',
                  style: TextStyle(
                    color: Color(0xFF34D399),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptCard(BuildContext context, String formattedDate) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1F2937)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
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
                  'TOTAL TOURIST LEVY',
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
                  'Ref: ${receipt.receiptRef}',
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

          // Receipt Fields
          Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              children: [
                _buildReceiptRow('Traveler Name', receipt.touristName),
                const Divider(color: Color(0xFF1F2937), height: 18),
                _buildReceiptRow('Bali Tourist ID', receipt.btidNumber),
                const Divider(color: Color(0xFF1F2937), height: 18),
                _buildReceiptRow('Passport No.', receipt.passportMasked),
                const Divider(color: Color(0xFF1F2937), height: 18),
                _buildReceiptRow('Payment Method', receipt.paymentMethod),
                const Divider(color: Color(0xFF1F2937), height: 18),
                _buildReceiptRow('Date & Time', formattedDate),
                const Divider(color: Color(0xFF1F2937), height: 18),
                _buildReceiptRow('Bapenda Treasury', _maskAddress(receipt.bapendaAddress)),
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
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 13,
          ),
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
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 13,
          ),
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

  Widget _buildMrzStrip(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2DD4BF).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.qr_code_2_rounded, size: 14, color: Color(0xFF2DD4BF)),
              SizedBox(width: 6),
              Text(
                'DIGITAL LEVY MRZ PASSPORT STRIP',
                style: TextStyle(
                  color: Color(0xFF2DD4BF),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  receipt.mrzLine1,
                  style: const TextStyle(
                    color: Color(0xFF34D399),
                    fontFamily: 'monospace',
                    fontSize: 11,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  receipt.mrzLine2,
                  style: const TextStyle(
                    color: Color(0xFF34D399),
                    fontFamily: 'monospace',
                    fontSize: 11,
                    letterSpacing: 1.1,
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
              'Continue to Dashboard',
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
                  content: Text('Receipt PDF saved to device downloads.'),
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

  String _maskAddress(String addr) {
    if (addr.length > 14) {
      return '${addr.substring(0, 6)}...${addr.substring(addr.length - 4)}';
    }
    return addr;
  }
}
