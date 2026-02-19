import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypta/src/core/services/blockchain/blockchain_service.dart';
import 'package:qrypta/src/core/config/theme/app_colors.dart';

class ConfirmationPage extends ConsumerStatefulWidget {
  final String recipientAddress;
  final String amount; // Display-ready string
  final String? estimatedFee; // Display-ready string, optional
  final String transactionHash;
  final String? tokenSymbol;

  const ConfirmationPage({
    super.key,
    required this.recipientAddress,
    required this.amount,
    this.estimatedFee,
    required this.transactionHash,
    this.tokenSymbol,
  });

  @override
  ConsumerState<ConfirmationPage> createState() => _ConfirmationPageState();
}

class _ConfirmationPageState extends ConsumerState<ConfirmationPage> {
  bool _isConfirmed = false;
  bool _isLoadingStatus = true;
  String? _statusError;

  @override
  void initState() {
    super.initState();
    _waitForReceipt();
  }

  Future<void> _waitForReceipt() async {
    developer.log('Waiting for receipt for tx: ${widget.transactionHash}', name: 'ConfirmationPage');
    final blockchainService = ref.read(blockchainServiceProvider);
    
    try {
      final receipt = await blockchainService.transaction
          .waitForTransactionReceipt(widget.transactionHash)
          .timeout(const Duration(minutes: 5)); // Add timeout for safety
      
      developer.log('Receipt received. Status: ${receipt.status}', name: 'ConfirmationPage');
      
      if (mounted) {
        setState(() {
          _isConfirmed = receipt.status ?? false;
          _isLoadingStatus = false;
        });
      }
    } catch (e, s) {
      developer.log('Error waiting for receipt', name: 'ConfirmationPage', error: e, stackTrace: s);
      if (mounted) {
        setState(() {
          _statusError = e.toString().contains('TimeoutException') 
              ? 'Status check timed out. Your transaction might still be processing.' 
              : 'Failed to verify status: ${e.toString()}';
          _isLoadingStatus = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final symbol = widget.tokenSymbol ?? 'ETH';
    final statusColor = _isLoadingStatus 
        ? Colors.orange 
        : (_statusError != null ? Colors.amber[700] : (_isConfirmed ? Colors.green : Colors.red));
    
    final statusText = _isLoadingStatus 
        ? 'Processing...' 
        : (_statusError != null ? 'Status Unknown' : (_isConfirmed ? 'Transaction Success' : 'Transaction Failed'));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Transaction Status'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false, // Prevent going back to send screen
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            _buildStatusIcon(),
            const SizedBox(height: 24),
            Text(
              statusText,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
            if (_statusError != null) ...[
              const SizedBox(height: 8),
              Text(
                _statusError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
            const SizedBox(height: 40),
            _buildDetailCard(symbol),
            const Spacer(),
            ElevatedButton(
              onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('DONE', style: TextStyle(color: AppColors.background, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    if (_isLoadingStatus) {
      return const Center(child: SizedBox(height: 80, width: 80, child: CircularProgressIndicator(strokeWidth: 6, color: AppColors.accent)));
    }
    if (_statusError != null) {
      return const Center(child: Icon(Icons.info_outline, size: 100, color: Colors.amber));
    }
    return Center(
      child: Icon(
        _isConfirmed ? Icons.check_circle : Icons.cancel,
        size: 100,
        color: _isConfirmed ? Colors.green : Colors.red,
      ),
    );
  }

  Widget _buildDetailCard(String symbol) {
    return Card(
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            _buildSummaryRow('To', widget.recipientAddress),
            const Divider(height: 24, color: Colors.grey),
            _buildSummaryRow('Amount', '${widget.amount} $symbol'),
            if (widget.estimatedFee != null && widget.estimatedFee != '0') ...[
              const SizedBox(height: 12),
              _buildSummaryRow('Estimated Fee', '${widget.estimatedFee} ETH'),
            ],
            const Divider(height: 24, color: Colors.grey),
            _buildSummaryRow('Transaction Hash', widget.transactionHash, isHash: true),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String title, String value, {bool isHash = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
          overflow: isHash ? TextOverflow.ellipsis : TextOverflow.visible,
        ),
      ],
    );
  }
}
