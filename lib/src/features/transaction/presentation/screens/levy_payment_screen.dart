// lib/src/features/transaction/presentation/screens/levy_payment_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypta/src/core/config/blockchain_config.dart';
import 'package:qrypta/src/core/config/theme/app_colors.dart';
import 'package:qrypta/src/core/utils/formatters.dart';
import 'package:qrypta/src/features/authentication/presentation/providers/btid_provider.dart';
import 'package:qrypta/src/features/home/presentation/screens/home_screen.dart';
import 'package:qrypta/src/features/tokens/presentation/providers/token_provider.dart';
import 'package:qrypta/src/features/transaction/logic/payment_controller.dart';
import 'package:qrypta/src/features/transaction/presentation/screens/levy_receipt_screen.dart';

class LevyPaymentScreen extends ConsumerStatefulWidget {
  const LevyPaymentScreen({super.key});

  @override
  ConsumerState<LevyPaymentScreen> createState() => _LevyPaymentScreenState();
}

class _LevyPaymentScreenState extends ConsumerState<LevyPaymentScreen> {
  String _selectedMethod = 'wallet'; // 'wallet', 'card', 'qr'

  @override
  Widget build(BuildContext context) {
    final btidCred = ref.watch(btidCredentialProvider);
    final paymentState = ref.watch(paymentControllerProvider);
    final tokensAsync = ref.watch(tokenNotifierProvider);

    final isPaid = btidCred?.isLevyPaid ?? false;
    final fullName = btidCred?.fullName ?? 'James Wilson';
    final passportMasked = btidCred?.passportMasked ?? '••••••789';
    final btidNumber = btidCred?.btidNumber ?? 'BTID-2026-4471-0938';

    // Ambil saldo IDRT dari tokenNotifierProvider
    String idrtBalanceFormatted = 'Rp 2.480.000';
    tokensAsync.whenData((tokens) {
      final idrt = tokens.where((t) => t.symbol == 'IDRT').firstOrNull;
      if (idrt != null && idrt.balance > BigInt.zero) {
        idrtBalanceFormatted = formatBigInt(
          idrt.balance,
          idrt.decimals,
          isCurrency: true,
        );
      }
    });

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
          'Bali Tourist Levy',
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
              // 1. Government Official Header
              _buildOfficialBanner(),
              const SizedBox(height: 16),

              // 2. Bill Invoice Card
              _buildInvoiceCard(
                fullName: fullName,
                passportMasked: passportMasked,
                btidNumber: btidNumber,
                isPaid: isPaid,
              ),
              const SizedBox(height: 16),

              // 3. Legal Regulation Notice
              _buildLegalNotice(),
              const SizedBox(height: 20),

              // 4. Funding Source Section
              if (!isPaid) ...[
                const Text(
                  'Select Funding Source',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildMethodTile(
                  id: 'wallet',
                  title: 'Qrypta IDRT Wallet Balance',
                  subtitle: 'Available: $idrtBalanceFormatted',
                  icon: Icons.account_balance_wallet_rounded,
                  badge: 'Recommended • Web3 Instant',
                  badgeColor: const Color(0xFF2DD4BF),
                ),
                const SizedBox(height: 10),
                _buildMethodTile(
                  id: 'card',
                  title: 'Credit or Debit Card',
                  subtitle: 'Visa •••• 4218',
                  icon: Icons.credit_card_rounded,
                ),
                const SizedBox(height: 10),
                _buildMethodTile(
                  id: 'qr',
                  title: 'Airport Desk Counter QR',
                  subtitle: 'Ngurah Rai DPS International Terminal',
                  icon: Icons.qr_code_scanner_rounded,
                ),
                const SizedBox(height: 28),
              ],

              // 5. Action Buttons
              if (isPaid) ...[
                _buildPaidAction(btidCred),
              ] else ...[
                _buildPayAction(paymentState),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOfficialBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shield_rounded, color: Color(0xFFF59E0B), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Official Provincial Tourist Levy',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Bali Provincial Government • Perda No. 6/2023',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceCard({
    required String fullName,
    required String passportMasked,
    required String btidNumber,
    required bool isPaid,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Column(
        children: [
          // Amount Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'TOTAL DUE',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'IDR 150,000',
                      style: TextStyle(
                        color: Color(0xFF2DD4BF),
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isPaid
                        ? const Color(0xFF065F46).withValues(alpha: 0.5)
                        : const Color(0xFF78350F).withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isPaid
                          ? const Color(0xFF10B981)
                          : const Color(0xFFF59E0B),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPaid ? Icons.check_circle_rounded : Icons.pending_rounded,
                        color: isPaid ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isPaid ? 'PAID' : 'PAYMENT DUE',
                        style: TextStyle(
                          color: isPaid ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
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
                _buildInfoRow('Traveler', fullName),
                const Divider(color: Color(0xFF1F2937), height: 18),
                _buildInfoRow('Passport', passportMasked),
                const Divider(color: Color(0xFF1F2937), height: 18),
                _buildInfoRow('Tourist ID', btidNumber),
                const Divider(color: Color(0xFF1F2937), height: 18),
                _buildInfoRow('Treasury Entity', 'Bapenda Bali On-Chain Pool'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildLegalNotice() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.info_outline_rounded, color: Color(0xFF38BDF8), size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Under Bali Provincial Regulation No. 6/2023, every international visitor contributes IDR 150,000 towards environmental preservation, cultural heritage protection, and local infrastructure development.',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodTile({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
    String? badge,
    Color? badgeColor,
  }) {
    final isSelected = _selectedMethod == id;

    return InkWell(
      onTap: () => setState(() => _selectedMethod = id),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF0F766E).withValues(alpha: 0.15)
              : const Color(0xFF111827),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF2DD4BF) : const Color(0xFF1F2937),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF2DD4BF).withValues(alpha: 0.2)
                    : const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected ? const Color(0xFF2DD4BF) : const Color(0xFF94A3B8),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: isSelected ? Colors.white : const Color(0xFFE2E8F0),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (badgeColor ?? const Color(0xFF2DD4BF)).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              color: badgeColor ?? const Color(0xFF2DD4BF),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? const Color(0xFF2DD4BF) : const Color(0xFF475569),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPayAction(PaymentState state) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: state.isLoading ? null : _handlePayment,
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

  Widget _buildPaidAction(dynamic btidCred) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () {
              final receiptRef = btidCred?.levyReceiptRef ?? 'LVY-448102';
              final btidNumber = btidCred?.btidNumber ?? 'BTID-2026-4471-0938';
              final receipt = LevyReceiptData(
                receiptRef: receiptRef,
                touristName: btidCred?.fullName ?? 'James Wilson',
                btidNumber: btidNumber,
                passportMasked: btidCred?.passportMasked ?? '••••••789',
                amount: 'IDR 150,000',
                amountRaw: 150000,
                paymentMethod: 'Qrypta IDRT Wallet Balance',
                txHash: '0x7b2f8a1e9c4d3b5a7e6f8a9b0c1d2e3f4a5b6c7d',
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

  Future<void> _handlePayment() async {
    try {
      final receipt = await ref
          .read(paymentControllerProvider.notifier)
          .payTouristLevy(paymentMethod: _selectedMethod);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tourist Levy successfully paid and anchored on-chain!'),
          backgroundColor: Color(0xFF0F766E),
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => LevyReceiptScreen(receipt: receipt),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }
}
