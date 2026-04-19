// lib/src/features/transaction/presentation/providers/transaction_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypta/src/core/services/blockchain/blockchain_service.dart';
import 'package:qrypta/src/features/authentication/presentation/providers/auth_providers.dart';
import 'package:qrypta/src/features/transaction/data/repositories/transaction_repository_impl.dart';
import 'package:qrypta/src/features/transaction/domain/repositories/transaction_repository.dart';
import 'package:qrypta/src/features/transaction/domain/usecases/get_recent_transactions_usecase.dart';
import 'package:qrypta/src/core/services/blockchain/transaction_service.dart';

// Data Layer Provider
final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  final blockchainService = ref.watch(blockchainServiceProvider);
  return TransactionRepositoryImpl(blockchainService);
});

// Domain Layer Provider
final getRecentTransactionsUseCaseProvider =
    Provider<GetRecentTransactionsUseCase>((ref) {
  final repository = ref.watch(transactionRepositoryProvider);
  return GetRecentTransactionsUseCase(repository);
});

/// Provider that exposes the current user's wallet address (public key).
final userWalletAddressProvider = FutureProvider<String?>((ref) async {
  final getPrivateKey = ref.watch(getPrivateKeyUseCaseProvider);
  final getChecksumAddress = ref.watch(getChecksumAddressUseCaseProvider);

  final privateKey = await getPrivateKey();
  if (privateKey == null || privateKey.isEmpty) {
    return null;
  }
  return getChecksumAddress(privateKey);
});

// Presentation Layer Provider
final transactionHistoryProvider =
    FutureProvider<List<Transaction>>((ref) async {
  // 1. Get the UseCase
  final getRecentTransactions = ref.watch(getRecentTransactionsUseCaseProvider);

  // 2. Get the user's public address from the new provider
  final publicKey = await ref.watch(userWalletAddressProvider.future);

  // 3. Fetch the transactions if a public key exists
  if (publicKey == null || publicKey.isEmpty) {
    return [];
  }
  return getRecentTransactions(userAddressHex: publicKey);
});
