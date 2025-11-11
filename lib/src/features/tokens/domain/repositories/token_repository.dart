// lib/src/features/tokens/domain/repositories/token_repository.dart

import 'package:qrypta/src/core/data/models/token_model.dart';

abstract class TokenRepository {
  Future<Token> getTokenDetails(String contractAddress);
  Future<BigInt> fetchTokenBalance({
    required String contractAddress,
    required String walletAddress,
  });
  Future<bool> validateTokenContract(String contractAddress);
  Future<void> saveManualToken(Token token);
  Future<List<Token>> getSavedTokens(String walletAddress);
  Future<void> removeToken(String contractAddress);
}
