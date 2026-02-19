import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypta/src/core/services/blockchain/blockchain_service.dart';
import '../../../transaction/presentation/providers/transaction_providers.dart';
import '../../data/token_service.dart';
import '../../../../core/data/models/token_model.dart';

class TokenNotifier extends StateNotifier<AsyncValue<List<TokenModel>>> {
  final Ref _ref;

  TokenNotifier({
    required Ref ref,
  })  : _ref = ref,
        super(const AsyncValue.loading()) {
    fetchUserTokens();
  }

  Future<void> fetchUserTokens() async {
    state = const AsyncValue.loading();
    try {
      final userAddress = await _ref.read(userWalletAddressProvider.future);
      if (userAddress == null || userAddress.isEmpty) {
        state = const AsyncValue.data([]);
        return;
      }

      final blockchainService = _ref.read(blockchainServiceProvider);

      // 1. Get the list of hardcoded token assets (IDRT) from .env
      final initialTokens = tokenServiceProvider.getHardcodedTokens();

      if (initialTokens.isEmpty) {
        state = const AsyncValue.data([]);
        return;
      }

      // 2. For each token, fetch its balance directly from the blockchain via RPC
      final List<TokenModel> finalTokens = [];
      for (final token in initialTokens) {
        try {
          final newBalance = await blockchainService.erc20.getErc20Balance(
            token.contractAddress,
            userAddress,
          );
          
          finalTokens.add(TokenModel(
            contractAddress: token.contractAddress,
            symbol: token.symbol,
            name: token.name,
            decimals: token.decimals,
            balance: newBalance,
            logoUrl: token.logoUrl,
          ));
        } catch (e) {
          // If RPC fails, fallback to zero balance for UI safety
          finalTokens.add(token);
        }
      }

      state = AsyncValue.data(finalTokens);

    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }
}

final tokenNotifierProvider =
    StateNotifierProvider<TokenNotifier, AsyncValue<List<TokenModel>>>((ref) {
  return TokenNotifier(
    ref: ref,
  );
});

