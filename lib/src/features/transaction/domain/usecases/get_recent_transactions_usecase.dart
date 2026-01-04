// lib/src/features/transaction/domain/usecases/get_recent_transactions_usecase.dart
import 'package:qrypta/src/features/transaction/domain/repositories/transaction_repository.dart';
import 'package:qrypta/src/core/services/blockchain/transaction_service.dart';

class GetRecentTransactionsUseCase {
  final TransactionRepository _repository;

  GetRecentTransactionsUseCase(this._repository);

  Future<List<Transaction>> call({
    required String userAddressHex,
  }) {
    return _repository.getRecentTransactions(userAddressHex: userAddressHex);
  }
}
