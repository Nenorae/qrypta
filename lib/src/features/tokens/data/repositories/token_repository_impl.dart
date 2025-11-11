// lib/src/features/tokens/data/repositories/token_repository_impl.dart

import '../../../../core/data/models/token_model.dart';
import '../../../../core/services/blockchain/blockchain_service.dart';
import '../../domain/repositories/token_repository.dart';
import '../datasources/token_local_data_source.dart';

/// Implementation of [TokenRepository].
/// Acts as a bridge between [BlockchainService] (on-chain data)
/// and [TokenLocalDataSource] (local device data).
class TokenRepositoryImpl implements TokenRepository {
  final BlockchainService blockchainService;
  final TokenLocalDataSource localDataSource;

  TokenRepositoryImpl({
    required this.blockchainService,
    required this.localDataSource,
  });

  // blockchain operation

  @override
  Future<Token> getTokenDetails(String contractAddress) async {
    final details = await blockchainService.erc20.getTokenDetails(
      contractAddress,
    );

    return Token(
      name: details['name'] as String,
      symbol: details['symbol'] as String,
      decimals: details['decimals'] as int,
      contractAddress: contractAddress,
    );
  }

  @override
  Future<BigInt> fetchTokenBalance({
    required String contractAddress,
    required String walletAddress,
  }) async {
    return blockchainService.erc20.getErc20Balance(
      contractAddress,
      walletAddress,
    );
  }

  @override
  Future<bool> validateTokenContract(String contractAddress) async {
    return blockchainService.erc20.validateTokenContract(contractAddress);
  }

  // local operation

  @override
  Future<void> saveManualToken(Token token) async {
    await localDataSource.addTokenAddress(token.contractAddress);
  }

  @override
  Future<void> removeToken(String contractAddress) async {
    await localDataSource.removeTokenAddress(contractAddress);
  }

  @override
  Future<List<Token>> getSavedTokens(String walletAddress) async {
    final addresses = await localDataSource.getTokenAddresses();
    if (addresses.isEmpty) return [];

    try {
      final detailFutures =
          addresses.map((addr) => getTokenDetails(addr)).toList();

      final balanceFutures =
          addresses
              .map(
                (addr) => fetchTokenBalance(
                  contractAddress: addr,
                  walletAddress: walletAddress,
                ),
              )
              .toList();

      final tokens = await Future.wait(detailFutures);
      final balances = await Future.wait(balanceFutures);

      final result = List<Token>.generate(tokens.length, (i) {
        return Token(
          name: tokens[i].name,
          symbol: tokens[i].symbol,
          decimals: tokens[i].decimals,
          contractAddress: tokens[i].contractAddress,
          balance: balances[i],
        );
      });

      return result;
    } catch (e) {
      print('Error fetching token data: $e');
      return [];
    }
  }
}
