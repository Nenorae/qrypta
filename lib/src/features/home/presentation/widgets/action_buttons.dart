
import 'package:flutter/material.dart';
import 'package:qrypta/src/core/config/theme/app_colors.dart';
import 'package:qrypta/src/features/send_money/presentation/screens/send_money_screen.dart';
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
          icon: Icons.swap_horiz,
          label: 'Swap',
          onTap: () {
            Navigator.pop(context); // Close the modal
            print('Tombol SWAP ditekan');
            // TODO: Implement Swap functionality
          },
        ),
        _buildListTile(
          context,
          icon: Icons.payment,
          label: 'Payment',
          onTap: () {
            Navigator.pop(context); // Close the modal
            print('Tombol PAYMENT ditekan');
            // TODO: Implement Payment functionality
          },
        ),
        _buildListTile(
          context,
          icon: Icons.arrow_upward,
          label: 'Send',
          onTap: () {
            Navigator.pop(context); // Close the modal first
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SendMoneyScreen()),
            );
          },
        ),
        _buildListTile(
          context,
          icon: Icons.arrow_downward,
          label: 'Receive',
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
