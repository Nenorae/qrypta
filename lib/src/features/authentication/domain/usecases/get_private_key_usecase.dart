
import 'dart:developer';

import 'package:qrypta/src/features/authentication/domain/repositories/authentication_repository.dart';

class GetPrivateKeyUseCase {
  final AuthenticationRepository repository;

  GetPrivateKeyUseCase(this.repository);

  Future<String?> call() async {
    log('Executing GetPrivateKeyUseCase', name: 'GetPrivateKeyUseCase');
    try {
      final result = await repository.getPrivateKey();
      log('GetPrivateKeyUseCase successful, key is ${result != null ? 'present' : 'absent'}', name: 'GetPrivateKeyUseCase');
      return result;
    } catch (e, s) {
      log('Error in GetPrivateKeyUseCase', name: 'GetPrivateKeyUseCase', error: e, stackTrace: s);
      rethrow;
    }
  }
}
