import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart'; // Import shimmer package

import 'package:qrypta/src/core/data/repositories/wallet_repository.dart';
import 'package:qrypta/src/core/data/models/token_model.dart';

import 'dart:async';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:graphql_flutter/graphql_flutter.dart' hide NetworkException, ServerException;
import 'package:qrypta/src/core/error/exceptions.dart';

import 'package:qrypta/src/core/shared_widgets/error_display_widget.dart';
import '../../../transaction/presentation/providers/transaction_providers.dart';


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
// const String _testWalletAddress = '0x123...'; // Placeholder - REMOVED

final userWalletTokensStreamProvider =
    StreamProvider.family<List<TokenModel>, String>((ref, address) {
  final walletRepository = ref.watch(walletRepositoryProvider);

  // This transformer handles data parsing, error interpretation, and logging
  final transformer =
      StreamTransformer<QueryResult, List<TokenModel>>.fromHandlers(
    handleData: (queryResult, sink) {
      if (queryResult.hasException) {
        // Pass the exception to handleError
        sink.addError(queryResult.exception!);
        return;
      }
      final List<dynamic>? tokensData =
          queryResult.data?['wallet']?['tokens'] as List<dynamic>?;

      if (tokensData == null) {
        // Treat missing data as a success with an empty list
        sink.add([]);
        return;
      }
      final tokens = tokensData
          .map((tokenJson) => TokenModel.fromJson(tokenJson))
          .toList();
      sink.add(tokens);
    },
    handleError: (error, stackTrace, sink) {
      // Log the technical error for debugging
      developer.log(
        'Error fetching wallet assets',
        name: 'TokenProvider',
        error: error,
        stackTrace: stackTrace,
      );

      // Interpret the error and throw a user-friendly custom exception
      if (error is SocketException) {
        sink.addError(
            NetworkException("Koneksi internet Anda bermasalah."));
      } else if (error is OperationException) {
        // You can add more specific checks here based on GraphQL error codes
        if(error.graphqlErrors.isNotEmpty && error.graphqlErrors.first.message.toLowerCase().contains('not found')){
            sink.addError(WalletNotFoundException('Dompet tidak ditemukan.'));
        } else {
            sink.addError(ServerException("Layanan sedang mengalami gangguan."));
        }
      } else {
        sink.addError(
            ServerException("Terjadi kesalahan yang tidak terduga."));
      }
    },
  );

  return walletRepository.watchWalletAssets(address).transform(transformer);
});


class ManageTokensScreen extends ConsumerWidget {
  const ManageTokensScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // First, get the user's wallet address asynchronously.
    final userAddressAsync = ref.watch(userWalletAddressProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Token'),
      ),
      // Handle the state of fetching the address itself
      body: userAddressAsync.when(
        loading: () => const ShimmerLoadingList(),
        error: (err, stack) => ErrorDisplayWidget(
          message: 'Gagal memuat alamat dompet Anda.',
          onRetry: () => ref.invalidate(userWalletAddressProvider),
        ),
        data: (userAddress) {
          // Handle case where user might not have a wallet yet
          if (userAddress == null || userAddress.isEmpty) {
            return const ErrorDisplayWidget(
              message:
                  'Dompet tidak aktif. Silakan buat atau impor dompet terlebih dahulu.',
            );
          }

          // Once we have the address, watch the tokens provider
          final tokensAsyncValue =
              ref.watch(userWalletTokensStreamProvider(userAddress));

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(userWalletTokensStreamProvider(userAddress));
            },
            child: tokensAsyncValue.when(
              data: (tokens) {
                if (tokens.isEmpty) {
                  // Ensure this part is also scrollable for the RefreshIndicator
                  return LayoutBuilder(builder: (context, constraints) {
                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(minHeight: constraints.maxHeight),
                        child: const Center(
                          child: Text('Anda belum memiliki token apapun.'),
                        ),
                      ),
                    );
                  });
                }
                return ListView.builder(
                  itemCount: tokens.length,
                  itemBuilder: (context, index) {
                    final token = tokens[index];
                    return TokenListItem(
                      token: token,
                    );
                  },
                );
              },
              loading: () => const ShimmerLoadingList(),
              error: (error, stack) {
                final message = switch (error) {
                  NetworkException() => error.message,
                  WalletNotFoundException() => error.message,
                  ServerException() => error.message,
                  _ => 'Terjadi kesalahan saat memuat token.',
                };

                return ErrorDisplayWidget(
                  message: message,
                  onRetry: () {
                    ref.invalidate(userWalletTokensStreamProvider(userAddress));
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
