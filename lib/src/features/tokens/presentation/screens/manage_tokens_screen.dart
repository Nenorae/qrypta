import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:qrypta/src/core/data/models/token_model.dart';
import 'package:qrypta/src/core/shared_widgets/error_display_widget.dart';
import 'package:qrypta/src/features/tokens/presentation/providers/token_provider.dart';
import 'package:qrypta/src/features/transaction/presentation/screens/send_screen.dart';

class TokenListItem extends StatelessWidget {
  final TokenModel token;
  const TokenListItem({super.key, required this.token});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: ListTile(
        leading: SizedBox(
          width: 40,
          height: 40,
          child: token.logoUrl != null && token.logoUrl!.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: token.logoUrl!,
                  placeholder: (context, url) => Center(child: Text(token.symbol[0])),
                  errorWidget: (context, url, error) => const Icon(Icons.token),
                )
              : CircleAvatar(child: Text(token.symbol[0])),
        ),
        title: Text(token.name),
        subtitle: Text(token.symbol),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${(token.balance / BigInt.from(10).pow(token.decimals)).toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => SendScreen(token: token)),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                minimumSize: const Size(60, 30),
              ),
              child: const Text('Send', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}

class ShimmerLoadingList extends StatelessWidget {
  const ShimmerLoadingList({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[850]!,
      highlightColor: Colors.grey[800]!,
      child: ListView.builder(
        itemCount: 5,
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: ListTile(
              leading: Container(width: 40, height: 40, color: Colors.white),
              title: Container(width: 100, height: 10, color: Colors.white),
              subtitle: Container(width: 50, height: 10, color: Colors.white),
              trailing: Container(width: 50, height: 20, color: Colors.white),
            ),
          );
        },
      ),
    );
  }
}

class ManageTokensScreen extends ConsumerWidget {
  const ManageTokensScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokensAsyncValue = ref.watch(tokenNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Token'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(tokenNotifierProvider.notifier).fetchUserTokens();
        },
        child: tokensAsyncValue.when(
          data: (tokens) {
            if (tokens.isEmpty) {
              return const Center(child: Text('Tidak ada token yang ditemukan.'));
            }
            return ListView.builder(
              itemCount: tokens.length,
              itemBuilder: (context, index) {
                return TokenListItem(token: tokens[index]);
              },
            );
          },
          loading: () => const ShimmerLoadingList(),
          error: (error, stack) => ErrorDisplayWidget(
            message: 'Gagal memuat token: $error',
            onRetry: () => ref.read(tokenNotifierProvider.notifier).fetchUserTokens(),
          ),
        ),
      ),
    );
  }
}
