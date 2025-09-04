import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:qrypta/src/features/blockchain/services/blockchain_service.dart';
import 'package:web3dart/web3dart.dart';

class ConfirmationPage extends StatefulWidget {
  final String recipientAddress;
  final EtherAmount amount;
  final EtherAmount estimatedFee;

  const ConfirmationPage({
    super.key,
    required this.recipientAddress,
    required this.amount,
    required this.estimatedFee,
  });

  @override
  State<ConfirmationPage> createState() => _ConfirmationPageState();
}

class _ConfirmationPageState extends State<ConfirmationPage> {
  bool _isSending = false;

  Future<String?> _getPrivateKey() async {
    developer.log('Retrieving private key', name: 'ConfirmationPage');
    // TODO: Implement secure private key retrieval
    return "YOUR_PRIVATE_KEY"; // Ganti dengan private key Anda
  }

  Future<bool> _showPinPrompt(BuildContext context) async {
    developer.log('Showing PIN prompt', name: 'ConfirmationPage');
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter PIN'),
        content: const TextField(
          obscureText: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: 'PIN'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              developer.log('PIN prompt cancelled', name: 'ConfirmationPage');
              Navigator.pop(context, false);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              developer.log('PIN prompt confirmed', name: 'ConfirmationPage');
              Navigator.pop(context, true);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showSuccessDialog(String txHash, bool isConfirmed) {
    developer.log('Showing success dialog for tx: $txHash, confirmed: $isConfirmed', name: 'ConfirmationPage');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isConfirmed ? 'Transaction Confirmed' : 'Transaction Sent'),
        content: Text('Transaction Hash: $txHash'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String error) {
    developer.log('Showing error dialog: $error', name: 'ConfirmationPage');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(error),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendTransaction() async {
    developer.log('Initiating send transaction process', name: 'ConfirmationPage');
    final pinConfirmed = await _showPinPrompt(context);
    if (!pinConfirmed) {
      developer.log('PIN not confirmed, aborting transaction', name: 'ConfirmationPage');
      return;
    }

    final privateKey = await _getPrivateKey();
    if (privateKey == null) {
      developer.log('Private key not found', name: 'ConfirmationPage');
      _showErrorDialog('Private key not found.');
      return;
    }

    setState(() {
      _isSending = true;
    });

    final blockchainService = BlockchainService();
    try {
      final recipient = EthereumAddress.fromHex(widget.recipientAddress);
      developer.log('Sending transaction to ${widget.recipientAddress}', name: 'ConfirmationPage');
      final txHash = await blockchainService.sendTransaction(privateKey, recipient, widget.amount);
      developer.log('Transaction sent, hash: $txHash', name: 'ConfirmationPage');

      _showSuccessDialog(txHash, false); // Show sent status immediately

      developer.log('Waiting for transaction receipt for tx: $txHash', name: 'ConfirmationPage');
      final receipt = await blockchainService.waitForTransactionReceipt(txHash);
      developer.log('Transaction receipt received for tx: $txHash, status: ${receipt.status}', name: 'ConfirmationPage');

      if (mounted) {
        Navigator.pop(context); // Close the 'Sent' dialog
        _showSuccessDialog(txHash, receipt.status ?? false);
      }

    } catch (e, s) {
      developer.log('Error sending transaction', name: 'ConfirmationPage', error: e, stackTrace: s);
      if (mounted) {
        _showErrorDialog(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
      await blockchainService.dispose();
      developer.log('Transaction process finished', name: 'ConfirmationPage');
    }
  }

  @override
  Widget build(BuildContext context) {
    developer.log('Building ConfirmationPage', name: 'ConfirmationPage');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm Transaction'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SUMMARY',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    _buildSummaryRow('To:', widget.recipientAddress),
                    const SizedBox(height: 8),
                    _buildSummaryRow('Amount:', '${widget.amount.getValueInUnit(EtherUnit.ether)} ETH'),
                    const SizedBox(height: 8),
                    _buildSummaryRow('Estimated Fee:', '${widget.estimatedFee.getValueInUnit(EtherUnit.ether)} ETH'),
                  ],
                ),
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _isSending ? null : _sendTransaction,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isSending
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Confirm and Send'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String title, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(color: Colors.grey)),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}