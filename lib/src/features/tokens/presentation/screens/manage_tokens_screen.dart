import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/token_provider.dart';
import '../widgets/token_list_item.dart';
import 'add_manual_token_screen.dart';

class ManageTokensScreen extends ConsumerWidget {
  const ManageTokensScreen({super.key});

  void _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    String tokenAddress,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Hapus Token'),
          content: const Text('Apakah Anda yakin ingin menghapus token ini?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Batal'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: const Text('Hapus', style: TextStyle(color: Colors.red)),
              onPressed: () {
                ref
                    .read(tokenNotifierProvider.notifier)
                    .removeToken(tokenAddress);
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokensAsyncValue = ref.watch(tokenNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Token'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(tokenNotifierProvider.notifier).fetchUserTokens(),
        child: tokensAsyncValue.when(
          data: (tokens) {
            if (tokens.isEmpty) {
              return const Center(
                child: Text('Anda belum menambahkan token apapun.'),
              );
            }
            return ListView.builder(
              itemCount: tokens.length,
              itemBuilder: (context, index) {
                final token = tokens[index];
                return TokenListItem(
                  token: token,
                  onDelete: () => _showDeleteConfirmation(
                    context,
                    ref,
                    token.contractAddress,
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Text('Gagal memuat token: $error'),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const AddTokenManualScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
