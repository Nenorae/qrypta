import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/models/token_model.dart';
import '../../domain/repositories/token_repository.dart';
import '../../domain/usecases/get_user_tokens.dart';
import '../../domain/usecases/add_manual_custom_token.dart';
import '../../domain/usecases/remove_custom_token.dart';

import '../../data/repositories/token_repository_impl.dart';
import '../../data/datasources/token_local_data_source_impl.dart';

import '../../../../core/services/blockchain/blockchain_service.dart';

import '../../../authentication/presentation/providers/auth_providers.dart';

final tokenLocalDataSourceProvider = Provider((ref) {
  final sharedPreferencesPrefs = ref.watch(sharedPreferencesProvider);
  return TokenLocalDataSourceImpl(sharedPreferences: sharedPreferencesPrefs);
});

final blockchainServiceProvider = Provider((ref) {
  return BlockchainService();
});

final tokenRepositoryProvider = Provider<TokenRepository>((ref) {
  final local = ref.watch(tokenLocalDataSourceProvider);
  final chain = ref.watch(blockchainServiceProvider);
  return TokenRepositoryImpl(localDataSource: local, blockchainService: chain);
});

final getUserTokensUseCaseProvider = Provider<GetUserTokensUseCase>((ref) {
  return GetUserTokensUseCase(ref.watch(tokenRepositoryProvider));
});

final addManualTokenUseCaseProvider = Provider<AddManualTokenUseCase>((ref) {
  return AddManualTokenUseCase(ref.watch(tokenRepositoryProvider));
});

final removeCustomTokenUseCaseProvider = Provider<RemoveCustomTokenUseCase>((ref) {
  return RemoveCustomTokenUseCase(ref.watch(tokenRepositoryProvider));
});

class TokenNotifier extends StateNotifier<AsyncValue<List<Token>>> {
  final AddManualTokenUseCase _addManual;
  final GetUserTokensUseCase _getTokens;
  final RemoveCustomTokenUseCase _removeToken;
  final Ref _ref;

  TokenNotifier({
    required AddManualTokenUseCase addManualTokenUseCase,
    required GetUserTokensUseCase getUserTokensUseCase,
    required RemoveCustomTokenUseCase removeCustomTokenUseCase,
    required Ref ref,
  })  : _addManual = addManualTokenUseCase,
        _getTokens = getUserTokensUseCase,
        _removeToken = removeCustomTokenUseCase,
        _ref = ref,
        super(const AsyncValue.loading()) {
    fetchUserTokens();
  }

  Future<void> fetchUserTokens() async {
    state = const AsyncValue.loading();
    try {
      final privateKey = await _ref.read(getPrivateKeyUseCaseProvider).call();
      if (privateKey == null || privateKey.isEmpty) {
        state = const AsyncValue.data([]);
        return;
      }
      final walletAddress =
          await _ref.read(getPublicKeyUseCaseProvider).call(privateKey);

      final tokens = await _getTokens.call(walletAddress: walletAddress);
      state = AsyncValue.data(tokens);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  Future<bool> addTokenByAddress(String contractAddress) async {
    print("Error: GetTokenDetails usecase belum tersedia");
    return false;
  }

  Future<bool> addManualToken(Token token) async {
    state = const AsyncValue.loading();
    try {
      await _addManual.call(token);
      await fetchUserTokens();
      return true;
    } catch (e, s) {
      state = AsyncValue.error(e, s);
      return false;
    }
  }

  Future<void> removeToken(String contractAddress) async {
    state = const AsyncValue.loading();
    try {
      await _removeToken.call(contractAddress: contractAddress);
      await fetchUserTokens();
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }
}

final tokenNotifierProvider =
    StateNotifierProvider<TokenNotifier, AsyncValue<List<Token>>>((ref) {
  return TokenNotifier(
    addManualTokenUseCase: ref.watch(addManualTokenUseCaseProvider),
    getUserTokensUseCase: ref.watch(getUserTokensUseCaseProvider),
    removeCustomTokenUseCase: ref.watch(removeCustomTokenUseCaseProvider),
    ref: ref,
  );
});
