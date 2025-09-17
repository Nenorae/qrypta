// lib/src/features/tokens/domain/usecases/add_manual_custom_token.dart

import 'package:qrypta/src/core/data/models/token_model.dart';
import 'package:qrypta/src/features/tokens/domain/repositories/token_repository.dart';

/// Use case untuk menambahkan token ERC-20 secara manual.
class AddManualTokenUseCase {
  final TokenRepository _repository;
  AddManualTokenUseCase(this._repository);

  /// Memanggil use case.
  ///
  /// [token]: Data token yang diinput manual oleh pengguna.
  /// Akan melempar Exception jika alamat kontrak tidak valid.
  Future<void> call(Token token) async {
    // 1. Validasi kontrak terlebih dahulu
    final isValid = await _repository.validateTokenContract(
      token.contractAddress,
    );

    if (!isValid) {
      throw Exception('Kontrak tidak valid atau bukan token ERC-20');
    }

    // 2. Jika valid, simpan data token yang diinput manual
    await _repository.saveManualToken(token);
  }
}
