
import 'dart:developer';

import 'package:qrypta/src/features/authentication/domain/repositories/authentication_repository.dart';

class SavePrivateKeyUseCase {
  final AuthenticationRepository repository;

  SavePrivateKeyUseCase(this.repository);

  Future<void> call(String privateKey) async {
    log('Executing SavePrivateKeyUseCase', name: 'SavePrivateKeyUseCase');
    try {
      await repository.savePrivateKey(privateKey);
      log('SavePrivateKeyUseCase successful', name: 'SavePrivateKeyUseCase');
    } catch (e, s) {
      log('Error in SavePrivateKeyUseCase', name: 'SavePrivateKeyUseCase', error: e, stackTrace: s);
      rethrow;
    }
  }
}
