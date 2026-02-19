import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypta/src/core/config/theme/app_colors.dart';
import 'package:qrypta/src/core/config/blockchain_config.dart';
import 'package:qrypta/src/features/transaction/logic/send_controller.dart';
import 'package:qrypta/src/features/transaction/presentation/screens/send_scanner_screen.dart';
import 'package:qrypta/src/features/transaction/presentation/screens/confirmation_screen.dart';
import 'package:qrypta/src/core/data/models/token_model.dart';

class SendScreen extends ConsumerStatefulWidget {
  final String? initialAddress;
  final TokenModel? token; // If null, send ETH

  const SendScreen({super.key, this.initialAddress, this.token});

  @override
  ConsumerState<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends ConsumerState<SendScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialAddress != null) {
        ref.read(sendControllerProvider.notifier).addressController.text = widget.initialAddress!;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sendState = ref.watch(sendControllerProvider);
    final sendController = ref.read(sendControllerProvider.notifier);
    final symbol = widget.token?.symbol ?? BlockchainConfig.currencySymbol;

    ref.listen<SendState>(sendControllerProvider, (previous, next) {
      if (next.transactionHash != null && next.transactionHash != previous?.transactionHash) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ConfirmationPage(
              recipientAddress: sendController.addressController.text,
              amount: sendController.amountController.text,
              estimatedFee: '0', // TODO: Implement actual gas estimation
              transactionHash: next.transactionHash!,
              tokenSymbol: symbol,
            ),
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Send $symbol'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildAddressInput(context, sendController),
            const SizedBox(height: 24),
            _buildAmountInput(sendController, symbol),
            const SizedBox(height: 40),
            _buildSendButton(sendState, sendController),
            if (sendState.errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                sendState.errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAddressInput(BuildContext context, SendController controller) {
    return TextField(
      controller: controller.addressController,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: 'Recipient Address',
        labelStyle: const TextStyle(color: Colors.grey),
        hintText: '0x...',
        hintStyle: const TextStyle(color: Colors.grey),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.grey)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accent)),
        suffixIcon: IconButton(
          icon: const Icon(Icons.qr_code_scanner, color: AppColors.accent),
          onPressed: () async {
            final scannedAddress = await Navigator.push<String>(
              context,
              MaterialPageRoute(builder: (context) => SendScannerScreen(onScanResult: (address) { Navigator.pop(context, address); },)),
            );
            if (scannedAddress != null) {
              controller.addressController.text = scannedAddress;
            }
          },
        ),
      ),
    );
  }

  Widget _buildAmountInput(SendController controller, String symbol) {
    return TextField(
      controller: controller.amountController,
      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        labelText: 'Amount',
        labelStyle: const TextStyle(color: Colors.grey, fontSize: 16),
        hintText: '0.00',
        suffixText: symbol,
        suffixStyle: const TextStyle(color: AppColors.accent, fontSize: 18),
        enabledBorder: UnderlineInputBorder(borderSide: const BorderSide(color: Colors.grey)),
        focusedBorder: UnderlineInputBorder(borderSide: const BorderSide(color: AppColors.accent)),
      ),
    );
  }

  Widget _buildSendButton(SendState state, SendController controller) {
    return ElevatedButton(
      onPressed: state.isSending ? null : () => controller.send(token: widget.token),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: state.isSending
          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: AppColors.background, strokeWidth: 2))
          : const Text('CONFIRM SEND', style: TextStyle(color: AppColors.background, fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }
}
