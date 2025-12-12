import 'package:flutter/material.dart';
import 'dart:math';

import '../../../../core/data/models/token_model.dart';

class TokenListItem extends StatelessWidget {
  final Token token;
  final VoidCallback onDelete;

  const TokenListItem({
    super.key,
    required this.token,
    required this.onDelete,
  });

  String _formatBalance(BigInt balance, int decimals) {
    if (balance == BigInt.zero) {
      return '0';
    }
    final balanceDouble = balance / BigInt.from(pow(10, decimals));
    return balanceDouble.toStringAsFixed(4); // Tampilkan 4 angka desimal
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        // Placeholder, bisa diganti dengan logo token
        child: Text(token.symbol.substring(0, 1)),
      ),
      title: Text(token.name),
      subtitle: Text(token.symbol),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _formatBalance(token.balance ?? BigInt.zero, token.decimals),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.redAccent),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
