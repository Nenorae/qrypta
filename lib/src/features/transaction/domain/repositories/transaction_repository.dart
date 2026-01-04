// lib/src/features/transaction/domain/repositories/transaction_repository.dart
import 'package:qrypta/src/core/services/blockchain/transaction_service.dart';

abstract class TransactionRepository {
  Future<List<Transaction>> getRecentTransactions({
    required String userAddressHex,
  });
}
