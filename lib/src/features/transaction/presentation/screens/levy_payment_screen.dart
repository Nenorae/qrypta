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
import 'package:qrypta/src/features/transaction/presentation/widgets/levy_action_buttons.dart';
import 'package:qrypta/src/features/transaction/presentation/widgets/levy_invoice_card.dart';
import 'package:qrypta/src/features/transaction/presentation/widgets/levy_method_tile.dart';

export 'package:qrypta/src/features/transaction/presentation/widgets/levy_action_buttons.dart';
export 'package:qrypta/src/features/transaction/presentation/widgets/levy_invoice_card.dart';
export 'package:qrypta/src/features/transaction/presentation/widgets/levy_method_tile.dart';

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
    final fullName = (btidCred?.fullName.isNotEmpty == true) ? btidCred!.fullName : 'Traveler';
    final passportMasked = btidCred?.passportMasked ?? '-';
    final btidNumber = (btidCred?.btidNumber.isNotEmpty == true) ? btidCred!.btidNumber : 'Belum terdaftar';

    // Ambil saldo IDRT dari provider tunggal
    final idrtBalanceFormatted = ref.watch(idrtBalanceFormattedProvider);

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
              LevyInvoiceCard(
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
                LevyMethodTile(
                  id: 'wallet',
                  title: 'Qrypta IDRT Wallet Balance',
                  subtitle: 'Available: $idrtBalanceFormatted',
                  icon: Icons.account_balance_wallet_rounded,
                  badge: 'Recommended • Web3 Instant',
                  badgeColor: const Color(0xFF2DD4BF),
                  isSelected: _selectedMethod == 'wallet',
                  onSelected: (id) => setState(() => _selectedMethod = id),
                ),
                const SizedBox(height: 10),
                LevyMethodTile(
                  id: 'card',
                  title: 'Credit or Debit Card',
                  subtitle: 'Visa •••• 4218',
                  icon: Icons.credit_card_rounded,
                  isSelected: _selectedMethod == 'card',
                  onSelected: (id) => setState(() => _selectedMethod = id),
                ),
                const SizedBox(height: 10),
                LevyMethodTile(
                  id: 'qr',
                  title: 'Airport Desk Counter QR',
                  subtitle: 'Ngurah Rai DPS International Terminal',
                  icon: Icons.qr_code_scanner_rounded,
                  isSelected: _selectedMethod == 'qr',
                  onSelected: (id) => setState(() => _selectedMethod = id),
                ),
                const SizedBox(height: 28),
              ],

              // 5. Action Buttons
              if (isPaid) ...[
                LevyPaidAction(btidCred: btidCred),
              ] else ...[
                LevyPayAction(
                  state: paymentState,
                  onPay: _handlePayment,
                ),
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
