import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qrypta/src/core/config/theme/app_colors.dart';
import 'package:qrypta/src/core/config/blockchain_config.dart';
import 'package:qrypta/src/features/blockchain/services/blockchain_service.dart';
import 'package:qrypta/src/features/send_money/logic/send_money_controller.dart';
import 'package:qrypta/src/features/transaction/presentation/screens/send_scanner_screen.dart';
import 'package:qrypta/src/features/transaction/screens/confirmation_page.dart';
import 'package:web3dart/web3dart.dart';

class SendMoneyScreen extends StatelessWidget {
  final String? initialAddress;

  const SendMoneyScreen({super.key, this.initialAddress});

  @override
  Widget build(BuildContext context) {
    developer.log('Building SendMoneyScreen', name: 'SendMoneyScreen');
    return ChangeNotifierProvider(
      create: (_) => SendMoneyController()..addressController.text = initialAddress ?? '',
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Send Crypto'),
          backgroundColor: AppColors.background,
          elevation: 0,
        ),
        body: Consumer<SendMoneyController>(
          builder: (context, controller, child) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildAddressInput(context, controller),
                  const SizedBox(height: 24),
                  _buildAmountInput(controller),
                  const SizedBox(height: 32),
                  _buildContinueButton(context, controller),
                  if (controller.errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      controller.errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            );
          },
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

  Widget _buildContinueButton(BuildContext context, SendMoneyController controller) {
    return ElevatedButton(
      onPressed: () async {
        developer.log('Continue button pressed', name: 'SendMoneyScreen');
        final address = controller.addressController.text;
        final amountStr = controller.amountController.text;

        if (address.isEmpty || amountStr.isEmpty) {
          developer.log('Address or amount is empty', name: 'SendMoneyScreen');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter address and amount.')),
          );
          return;
        }

        final amount = double.tryParse(amountStr);
        if (amount == null) {
          developer.log('Invalid amount: $amountStr', name: 'SendMoneyScreen');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid amount.')),
          );
          return;
        }

        final blockchainService = BlockchainService();
        try {
          final recipient = EthereumAddress.fromHex(address);
          final value = EtherAmount.fromUnitAndValue(EtherUnit.ether, amount);

          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return const Center(child: CircularProgressIndicator());
            },
          );

          developer.log('Estimating transaction fee', name: 'SendMoneyScreen');
          final estimatedFee = await blockchainService.estimateTransactionFee(to: recipient, value: value);
          developer.log('Estimated fee: $estimatedFee', name: 'SendMoneyScreen');

          Navigator.pop(context); // Close loading dialog

          developer.log('Navigating to confirmation page', name: 'SendMoneyScreen');
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ConfirmationPage(
                recipientAddress: address,
                amount: value,
                estimatedFee: EtherAmount.fromUnitAndValue(EtherUnit.wei, estimatedFee),
              ),
            ),
          );
        } catch (e, s) {
          developer.log('Error during transaction preparation: $e', name: 'SendMoneyScreen', error: e, stackTrace: s);
          if (Navigator.canPop(context)) {
            Navigator.pop(context); // Close loading dialog
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('An error occurred: ${e.toString()}')),
          );
        } finally {
          await blockchainService.dispose();
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: const Text('Continue', style: TextStyle(fontSize: 18, color: AppColors.background)),
    );
  }
}