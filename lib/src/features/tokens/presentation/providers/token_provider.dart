import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/data/repositories/wallet_repository.dart';
import '../../../transaction/presentation/providers/transaction_providers.dart';

import '../../../../core/data/models/token_model.dart';

class TokenNotifier extends StateNotifier<AsyncValue<List<TokenModel>>> { // Changed to List<TokenModel>
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
      final userAddressAsync = await _ref.watch(userWalletAddressProvider.future);
      if (userAddressAsync == null || userAddressAsync.isEmpty) {
        state = const AsyncValue.data([]);
        return;
      }
      final walletRepository = _ref.read(walletRepositoryProvider);

      await for (final queryResult in walletRepository.watchWalletAssets(userAddressAsync)) {
        if (queryResult.hasException) {
          throw queryResult.exception!;
        }
        final List<dynamic>? tokensData =
            queryResult.data?['wallet']?['tokens'] as List<dynamic>?;
        if (tokensData == null) {
          state = const AsyncValue.data([]);
          return;
        }
        final tokens = tokensData
            .map((tokenJson) => TokenModel.fromJson(tokenJson))
            .toList();
        state = AsyncValue.data(tokens);
        return; // Process only the first emission for initial data
      }
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }
}

final tokenNotifierProvider =
    StateNotifierProvider<TokenNotifier, AsyncValue<List<TokenModel>>>((ref) { // Changed to List<TokenModel>
  return TokenNotifier(
    ref: ref,
  );
});

