// lib/src/features/transaction/data/repositories/transaction_repository_impl.dart
import 'package:qrypta/src/core/services/blockchain/blockchain_service.dart';
import 'package:qrypta/src/features/transaction/domain/repositories/transaction_repository.dart';
import 'package:qrypta/src/core/services/blockchain/transaction_service.dart';


class TransactionRepositoryImpl implements TransactionRepository {
  final BlockchainService _blockchainService;

  TransactionRepositoryImpl(this._blockchainService);

  @override
  Future<List<Transaction>> getRecentTransactions({
    required String userAddressHex,
  }) async {
    final page = await _blockchainService.transaction.getRecentTransactions(
      userAddressHex: userAddressHex,
    );
    return page.transactions;
  }
}
