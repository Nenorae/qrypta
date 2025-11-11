// lib/src/features/tokens/domain/usecases/get_user_tokens.dart

import 'package:qrypta/src/core/data/models/token_model.dart';
import 'package:qrypta/src/features/tokens/domain/repositories/token_repository.dart';

/// Retrieves all user-saved tokens with their latest balances.
class GetUserTokensUseCase {
  final TokenRepository _repository;

  GetUserTokensUseCase(this._repository);

  Future<List<Token>> call({required String walletAddress}) async {
    final savedTokens = await _repository.getSavedTokens(walletAddress);
    if (savedTokens.isEmpty) return [];

    final futures =
        savedTokens.map((token) async {
          try {
            final balance = await _repository.fetchTokenBalance(
              contractAddress: token.contractAddress,
              walletAddress: walletAddress,
            );
            return token.copyWith(balance: balance);
          } catch (_) {
            return token.copyWith(balance: BigInt.zero);
          }
        }).toList();

    return Future.wait(futures);
  }
}
