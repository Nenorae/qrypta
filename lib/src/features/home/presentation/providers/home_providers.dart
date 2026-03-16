import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypta/src/core/data/models/token_model.dart';
import 'package:qrypta/src/core/services/blockchain/blockchain_service.dart';
import 'package:qrypta/src/features/tokens/presentation/providers/token_provider.dart';
import 'package:qrypta/src/features/transaction/presentation/providers/transaction_providers.dart';
import 'package:web3dart/web3dart.dart';

final nativeBalanceProvider = FutureProvider<EtherAmount>((ref) async {
  final userAddressStr = await ref.watch(userWalletAddressProvider.future);
  if (userAddressStr == null) {
    return EtherAmount.zero();
  }
  final userAddress = EthereumAddress.fromHex(userAddressStr);
  final blockchainService = ref.read(blockchainServiceProvider);
  return blockchainService.nativeCurrency.getBalance(userAddress);
});

class TotalBalance {
  final double totalValueInIdr;
  final EtherAmount nativeBalance;
  final List<TokenModel> tokenBalances;

  TotalBalance({
    required this.totalValueInIdr,
    required this.nativeBalance,
    required this.tokenBalances,
  });
}

final totalBalanceProvider = FutureProvider<TotalBalance>((ref) async {
  final nativeBalance = await ref.watch(nativeBalanceProvider.future);
  
  // tokenNotifierProvider returns AsyncValue<List<TokenModel>>
  final tokenBalancesState = ref.watch(tokenNotifierProvider);
  
  // We need to wait for the tokens to be loaded
  final tokenBalances = tokenBalancesState.when(
    data: (tokens) => tokens,
    loading: () => <TokenModel>[], // Or throw an error if we prefer to wait
    error: (err, stack) => <TokenModel>[],
  );

  if (tokenBalancesState.isLoading) {
    // If it's still loading, we might want this provider to also be in a loading state.
    // However, since we are inside a FutureProvider, we can just await if it was a future.
    // Since it's a StateNotifier, we can use ref.watch and return something or wait.
    // To make it react correctly, watching is enough.
  }

  // GLD is treated 1:1 with IDR for now. Native ETH is only for gas.
  double totalValueInIdr = 0.0;

  for (final token in tokenBalances) {
    // Convert BigInt balance to double using token decimals for accurate calculation
    final balance = token.balance.toDouble() / pow(10, token.decimals);
    totalValueInIdr += balance;
  }

  return TotalBalance(
    totalValueInIdr: totalValueInIdr,
    nativeBalance: nativeBalance,
    tokenBalances: tokenBalances,
  );
});
