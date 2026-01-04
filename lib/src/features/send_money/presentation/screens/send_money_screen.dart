import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Riverpod
import 'package:qrypta/src/core/config/theme/app_colors.dart';
import 'package:qrypta/src/core/config/blockchain_config.dart';
import 'package:qrypta/src/features/send_money/logic/send_money_controller.dart'; // Import the Riverpod controller
import 'package:qrypta/src/features/transaction/presentation/screens/send_scanner_screen.dart';
import 'package:qrypta/src/features/transaction/screens/confirmation_page.dart';
import 'package:web3dart/web3dart.dart';

class SendMoneyScreen extends ConsumerStatefulWidget { // Change to ConsumerStatefulWidget
  final String? initialAddress;

  const SendMoneyScreen({super.key, this.initialAddress});

  @override
  ConsumerState<SendMoneyScreen> createState() => _SendMoneyScreenState();
}

class _SendMoneyScreenState extends ConsumerState<SendMoneyScreen> {
  @override
  void initState() {
    super.initState();
    // Use a post-frame callback to ensure context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialAddress != null) {
        ref.read(sendMoneyControllerProvider.notifier).addressController.text =
            widget.initialAddress!;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    developer.log('Building SendMoneyScreen', name: 'SendMoneyScreen');
    final sendMoneyState = ref.watch(sendMoneyControllerProvider); // Watch the state
    final sendMoneyController = ref.read(sendMoneyControllerProvider.notifier); // Read the notifier

    // Listen for transaction hash changes to navigate
    ref.listen<SendMoneyState>(sendMoneyControllerProvider, (previous, next) {
      if (next.transactionHash != null && next.transactionHash != previous?.transactionHash) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ConfirmationPage(
              recipientAddress: sendMoneyController.addressController.text,
              amount: EtherAmount.fromUnitAndValue(EtherUnit.ether, double.parse(sendMoneyController.amountController.text)),
              estimatedFee: EtherAmount.zero(), // Placeholder, actual fee might be needed here
              transactionHash: next.transactionHash,
            ),
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Send Crypto'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildAddressInput(context, sendMoneyController),
            const SizedBox(height: 24),
            _buildAmountInput(sendMoneyController),
            const SizedBox(height: 32),
            _buildContinueButton(context, sendMoneyState, sendMoneyController),
            if (sendMoneyState.errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                sendMoneyState.errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
            if (sendMoneyState.isSending) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAddressInput(BuildContext context, SendMoneyController controller) {
    return TextField(
      controller: controller.addressController,
      decoration: InputDecoration(
        labelText: 'Recipient Address',
        hintText: 'Enter wallet address',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        suffixIcon: IconButton(
          icon: const Icon(Icons.qr_code_scanner),
          onPressed: () async {
            developer.log('QR scanner button pressed', name: 'SendMoneyScreen');
            final scannedAddress = await Navigator.push<String>(
              context,
              MaterialPageRoute(builder: (context) => SendScannerScreen(onScanResult: (address) {  },)),
            );
            if (scannedAddress != null && scannedAddress.isNotEmpty) {
              developer.log('Scanned address: $scannedAddress', name: 'SendMoneyScreen');
              controller.addressController.text = scannedAddress;
            }
          },
        ),
      ),
    );
  }

  Widget _buildAmountInput(SendMoneyController controller) {
    return TextField(
      controller: controller.amountController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: 'Amount',
        hintText: '0.00',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        suffixText: BlockchainConfig.currencySymbol,
      ),
    );
  }

  Widget _buildContinueButton(BuildContext context, SendMoneyState state, SendMoneyController controller) {
    return ElevatedButton(
      onPressed: state.isSending
          ? null // Disable button when sending
          : () async {
              developer.log('Continue button pressed', name: 'SendMoneyScreen');
              await controller.sendTransaction();
              // Navigation will be handled by the ref.listen
            },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: state.isSending
          ? const CircularProgressIndicator(color: Colors.white)
          : const Text('Continue', style: TextStyle(fontSize: 18, color: AppColors.background)),
    );
  }
}