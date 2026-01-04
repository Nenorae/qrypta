import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart'; // Import shimmer package

import 'package:qrypta/src/core/data/repositories/wallet_repository.dart';
import 'package:qrypta/src/core/data/models/token_model.dart';

// Placeholder for TokenListItem - will be properly defined later
class TokenListItem extends StatelessWidget {
  final TokenModel token;
  const TokenListItem({Key? key, required this.token}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: ListTile(
        leading: SizedBox(
          width: 40,
          height: 40,
          child: CachedNetworkImage(
            imageUrl: token.logoUrl ?? '', // Use empty string for null to avoid errors
            placeholder: (context, url) => Center(child: Text(token.symbol[0])),
            errorWidget: (context, url, error) => const Icon(Icons.token), // Placeholder icon
          ),
        ),
        title: Text(token.name),
        subtitle: Text(token.symbol),
        trailing: Text(
          // Assuming the balance is in smallest unit, converting to readable format
          '${(token.balance / BigInt.from(10).pow(token.decimals)).toStringAsFixed(token.decimals)}',
        ),
      ),
    );
  }
}

// Widget for Shimmer Loading Effect
class ShimmerLoadingList extends StatelessWidget {
  const ShimmerLoadingList({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[850]!,
      highlightColor: Colors.grey[800]!,
      child: ListView.builder(
        itemCount: 5, // Show 5 shimmering items
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: ListTile(
              leading: Container(
                width: 40,
                height: 40,
                color: Colors.white,
              ),
              title: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.6,
                  height: 10.0,
                  color: Colors.white,
                ),
              ),
              subtitle: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.4,
                  height: 10.0,
                  color: Colors.white,
                ),
              ),
              trailing: Container(
                width: 50,
                height: 10.0,
                color: Colors.white,
              ),
            ),
          );
        },
      ),
    );
  }
}

// TODO: Replace with actual user wallet address later
const String _testWalletAddress = '0x123...'; // Placeholder

final userWalletTokensStreamProvider =
    StreamProvider.family<List<TokenModel>, String>((ref, address) {
  final walletRepository = ref.watch(walletRepositoryProvider);
  return walletRepository.watchWalletAssets(address).map((event) {
    if (event.hasException) {
      throw event.exception!;
    }
    final List<dynamic>? tokensData =
        event.data?['wallet']?['tokens'] as List<dynamic>?;
    if (tokensData == null) {
      return [];
    }
    return tokensData
        .map((tokenJson) => TokenModel.fromJson(tokenJson))
        .toList();
  });
});

class ManageTokensScreen extends ConsumerWidget {
  const ManageTokensScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokensAsyncValue = ref.watch(userWalletTokensStreamProvider(_testWalletAddress));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Token'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Invalidate the provider to refetch data
          ref.invalidate(userWalletTokensStreamProvider(_testWalletAddress));
        },
        child: tokensAsyncValue.when(
          data: (tokens) {
            if (tokens.isEmpty) {
              return const Center(
                child: Text('Anda belum memiliki token apapun.'),
              );
            }
            return ListView.builder(
              itemCount: tokens.length,
              itemBuilder: (context, index) {
                final token = tokens[index];
                return TokenListItem(
                  token: token,
                  // onDelete: () => _showDeleteConfirmation(context, ref, token.contractAddress), // Manual delete is removed
                );
              },
            );
          },
          loading: () => const ShimmerLoadingList(), // Replaced with ShimmerLoadingList
          error: (error, stack) => Center(
            child: Text('Gagal memuat token: $error'),
          ),
        ),
      ),
    );
  }
}
