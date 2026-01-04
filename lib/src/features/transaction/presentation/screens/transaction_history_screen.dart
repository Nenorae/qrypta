// lib/src/features/transaction/presentation/screens/transaction_history_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypta/src/features/transaction/presentation/providers/transaction_providers.dart';
import 'package:qrypta/src/features/transaction/presentation/widgets/transaction_list_item.dart';

class TransactionHistoryScreen extends ConsumerWidget {
  const TransactionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(transactionHistoryProvider);
    final userAddressAsync = ref.watch(userWalletAddressProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction History'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(transactionHistoryProvider.future),
        child: historyAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: ${err.toString()}')),
          data: (transactions) {
            if (transactions.isEmpty) {
              return const Center(
                child: Text(
                  'No recent transactions found.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              );
            }
            // We need the user address for the list item, let's handle its state too
            return userAddressAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Could not get wallet address: ${err.toString()}')),
              data: (userAddress) {
                if (userAddress == null) {
                  return const Center(child: Text('Wallet not found.'));
                }
                return ListView.builder(
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final tx = transactions[index];
                    return TransactionListItem(
                      transaction: tx,
                      currentUserAddress: userAddress,
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
