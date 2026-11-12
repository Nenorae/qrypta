// lib/src/features/transaction/presentation/screens/qris_payment_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qrypta/src/core/config/theme/app_colors.dart';
import 'package:qrypta/src/core/utils/formatters.dart';
import 'package:qrypta/src/features/tokens/presentation/providers/token_provider.dart';
import 'package:qrypta/src/features/transaction/logic/payment_controller.dart';
import 'package:qrypta/src/features/transaction/presentation/screens/qris_receipt_screen.dart';

class QrisPaymentScreen extends ConsumerStatefulWidget {
  final String merchantName;
  final String merchantId;
  final String merchantAddress;
  final int initialAmount;
  final String itemDescription;

  const QrisPaymentScreen({
    super.key,
    this.merchantName = 'Bali Coffee House - Canggu',
    this.merchantId = 'MCH-3311',
    this.merchantAddress = '0x3311A9908F8718E237aDE73708aB59f212284bE0',
    this.initialAmount = 85000,
    this.itemDescription = 'Specialty Coffee & Pastry',
  });

  @override
  ConsumerState<QrisPaymentScreen> createState() => _QrisPaymentScreenState();
}

class _QrisPaymentScreenState extends ConsumerState<QrisPaymentScreen> {
  late final TextEditingController _amountController;
  int _currentAmount = 85000;

  @override
  void initState() {
    super.initState();
    _currentAmount = widget.initialAmount;
    _amountController = TextEditingController(text: _currentAmount.toString());
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paymentState = ref.watch(paymentControllerProvider);
    final tokensAsync = ref.watch(tokenNotifierProvider);

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

    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'IDR ',
      decimalDigits: 0,
    );

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
          'QRIS Payment',
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
              // 1. Merchant Header Card
              _buildMerchantCard(),
              const SizedBox(height: 16),

              // 2. Amount Input Card
              _buildAmountCard(currencyFormatter),
              const SizedBox(height: 16),

              // 3. Quick Preset Chips
              _buildPresetChips(),
              const SizedBox(height: 20),

              // 4. Funding Source Section
              _buildFundingSource(idrtBalanceFormatted),
              const SizedBox(height: 16),

              // 5. Zero-PII Privacy Banner
              _buildPrivacyBanner(),
              const SizedBox(height: 28),

              // 6. Action Button
              _buildPayButton(paymentState, currencyFormatter),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMerchantCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF2DD4BF).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF2DD4BF).withValues(alpha: 0.3)),
            ),
            child: const Icon(
              Icons.storefront_rounded,
              color: Color(0xFF2DD4BF),
              size: 26,
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
                        widget.merchantName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.verified_rounded,
                      color: Color(0xFF2DD4BF),
                      size: 16,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.merchantId} • ${widget.itemDescription}',
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountCard(NumberFormat currencyFormatter) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        children: [
          const Text(
            'BILL AMOUNT',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 11,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            currencyFormatter.format(_currentAmount),
            style: const TextStyle(
              color: Color(0xFF2DD4BF),
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Settled via ERC-20 Rupiah Token (IDRT)',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChips() {
    final presets = [50000, 85000, 150000, 250000];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: presets.map((amount) {
        final isSelected = _currentAmount == amount;
        final label = '${amount ~/ 1000}k';
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: InkWell(
              onTap: () {
                setState(() {
                  _currentAmount = amount;
                  _amountController.text = amount.toString();
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF2DD4BF).withValues(alpha: 0.2)
                      : const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF2DD4BF) : const Color(0xFF1F2937),
                  ),
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? const Color(0xFF2DD4BF) : const Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFundingSource(String balanceFormatted) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF2DD4BF).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: Color(0xFF2DD4BF),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Funding Source',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Qrypta IDRT Wallet Balance',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Available: $balanceFormatted',
                  style: const TextStyle(
                    color: Color(0xFF2DD4BF),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF2DD4BF),
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2DD4BF).withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.lock_person_rounded, color: Color(0xFF2DD4BF), size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Merchant only receives Payment Confirmed — Zero passport, identity, or personal data shared.',
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

  Widget _buildPayButton(PaymentState state, NumberFormat currencyFormatter) {
    return SizedBox(
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
                children: [
                  const Icon(Icons.payment_rounded, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Pay ${currencyFormatter.format(_currentAmount)}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _handlePayment() async {
    try {
      final receipt = await ref
          .read(paymentControllerProvider.notifier)
          .payQrisMerchant(
            merchantName: widget.merchantName,
            merchantId: widget.merchantId,
            merchantAddress: widget.merchantAddress,
            amountIdr: _currentAmount,
            itemDescription: widget.itemDescription,
          );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment confirmed and recorded on-chain!'),
          backgroundColor: Color(0xFF0F766E),
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => QrisReceiptScreen(receipt: receipt),
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
