// lib/src/features/tokens/domain/usecases/remove_custom_token.dart

import 'package:qrypta/src/features/tokens/domain/repositories/token_repository.dart';

/// Use case untuk menghapus token kustom dari penyimpanan lokal.
class RemoveCustomTokenUseCase {
  final TokenRepository _repository;

  RemoveCustomTokenUseCase(this._repository);

  /// Memanggil use case.
  ///
  /// [contractAddress]: Alamat kontrak dari token yang akan dihapus.
  Future<void> call({required String contractAddress}) async {
    // Langsung delegasikan tugas penghapusan ke repository.
    await _repository.removeToken(contractAddress);
  }
}
