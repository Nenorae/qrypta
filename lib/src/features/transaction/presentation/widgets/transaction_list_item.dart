// lib/src/features/transaction/presentation/widgets/transaction_list_item.dart
import 'package:flutter/material.dart';
import 'package:qrypta/src/core/utils/formatters.dart';
import 'package:qrypta/src/core/services/blockchain/transaction_service.dart'; // Import new Transaction model
import 'package:web3dart/web3dart.dart' as web3; // Aliased web3dart

class TransactionListItem extends StatelessWidget {
  final Transaction transaction; // Changed to new Transaction model
  final String currentUserAddress;

  const TransactionListItem({
    super.key,
    required this.transaction,
    required this.currentUserAddress,
  });

  @override
  Widget build(BuildContext context) {
    final isSender =
        transaction.fromAddress.toLowerCase() == currentUserAddress.toLowerCase();

    final toAddress = transaction.toAddress;

    // Convert value from String (WEI) to Ether
    final double valueInEther = web3.EtherAmount.fromUnitAndValue( // Use web3.EtherAmount
      web3.EtherUnit.wei, // Use web3.EtherUnit
      BigInt.parse(transaction.value),
    ).getValueInUnit(web3.EtherUnit.ether); // Use web3.EtherUnit


    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isSender ? Colors.redAccent : Colors.greenAccent,
          child: Icon(
            isSender ? Icons.arrow_outward : Icons.arrow_downward,
            color: Colors.white,
          ),
        ),
        title: Text(
          isSender
              ? 'Sent ${formatEther(valueInEther)} ETH'
              : 'Received ${formatEther(valueInEther)} ETH',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          isSender
              ? 'To: ${formatAddress(toAddress)}'
              : 'From: ${formatAddress(transaction.fromAddress)}',
          style: TextStyle(color: Colors.grey[400]),
        ),
        trailing: Text(
          'Block: ${transaction.blockNumber}',
          style: TextStyle(color: Colors.grey[500], fontSize: 12),
        ),
      ),
    );
  }
}
