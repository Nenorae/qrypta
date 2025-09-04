
import 'dart:developer' as developer;
import 'package:flutter/material.dart';

// Enum untuk merepresentasikan level biaya transaksi
enum FeeLevel { low, medium, high }

class SendMoneyController extends ChangeNotifier {
  final TextEditingController addressController = TextEditingController();
  final TextEditingController amountController = TextEditingController();

  FeeLevel _selectedFee = FeeLevel.medium;
  bool _isSending = false;
  String? _errorMessage;

  FeeLevel get selectedFee => _selectedFee;
  bool get isSending => _isSending;
  String? get errorMessage => _errorMessage;

  // Mengubah level biaya yang dipilih
  void setFeeLevel(FeeLevel fee) {
    developer.log('Setting fee level to: $fee', name: 'SendMoneyController');
    _selectedFee = fee;
    notifyListeners();
  }

  // Fungsi untuk memvalidasi input
  bool _validateInput() {
    developer.log('Validating input', name: 'SendMoneyController');
    if (addressController.text.isEmpty) {
      _errorMessage = "Recipient address cannot be empty.";
      developer.log('Validation failed: Recipient address is empty', name: 'SendMoneyController');
      return false;
    }
    if (amountController.text.isEmpty || double.tryParse(amountController.text) == null || double.parse(amountController.text) <= 0) {
      _errorMessage = "Please enter a valid amount.";
      developer.log('Validation failed: Invalid amount', name: 'SendMoneyController');
      return false;
    }
    _errorMessage = null;
    developer.log('Validation successful', name: 'SendMoneyController');
    return true;
  }

  // Fungsi utama untuk mengirim transaksi
  Future<void> sendTransaction() async {
    developer.log('Attempting to send transaction', name: 'SendMoneyController');
    if (!_validateInput()) {
      notifyListeners();
      return;
    }

    _isSending = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Simulasi proses pengiriman (misalnya, panggilan API)
      developer.log('Simulating transaction sending...', name: 'SendMoneyController');
      await Future.delayed(const Duration(seconds: 2));

      // Logika setelah berhasil (bisa diganti dengan navigasi atau notifikasi)
      developer.log('Transaction successful!', name: 'SendMoneyController');
      developer.log('Address: ${addressController.text}', name: 'SendMoneyController');
      developer.log('Amount: ${amountController.text}', name: 'SendMoneyController');
      developer.log('Fee: $_selectedFee', name: 'SendMoneyController');

    } catch (e, s) {
      _errorMessage = "Failed to send transaction. Please try again.";
      developer.log('Failed to send transaction', name: 'SendMoneyController', error: e, stackTrace: s);
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    developer.log('Disposing SendMoneyController', name: 'SendMoneyController');
    addressController.dispose();
    amountController.dispose();
    super.dispose();
  }
}
