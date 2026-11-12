
import 'package:flutter/material.dart';
import 'package:qrypta/src/core/config/theme/app_colors.dart';
import 'package:qrypta/src/features/qr_scanner/presentation/screens/qr_scanner_screen.dart';
import 'package:qrypta/src/features/transaction/presentation/screens/levy_payment_screen.dart';
import 'package:qrypta/src/features/transaction/presentation/screens/send_screen.dart';
import 'package:qrypta/src/features/transaction/presentation/screens/receive_screen.dart';

class ActionButtons extends StatelessWidget {
  const ActionButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildListTile(
          context,
          icon: Icons.qr_code_scanner_rounded,
          label: 'Pay with QRIS (ScrPay)',
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const QrScannerScreen()),
            );
          },
        ),
        _buildListTile(
          context,
          icon: Icons.receipt_long_rounded,
          label: 'Tourist Levy (IDR 150,000)',
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const LevyPaymentScreen()),
            );
          },
        ),
        _buildListTile(
          context,
          icon: Icons.arrow_upward,
          label: 'Send Tokens (P2P)',
          onTap: () {
            Navigator.pop(context); // Close the modal first
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SendScreen()),
            );
          },
        ),
        _buildListTile(
          context,
          icon: Icons.arrow_downward,
          label: 'Receive Tokens',
          onTap: () {
            Navigator.pop(context); // Close the modal first
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ReceiveScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildListTile(
    BuildContext context,
      {required IconData icon, required String label, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: AppColors.accent),
      title: Text(label, style: const TextStyle(color: Colors.white)),
      onTap: onTap,
    );
  }
}
