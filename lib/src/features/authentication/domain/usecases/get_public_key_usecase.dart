import 'dart:developer';

import 'package:qrypta/src/features/authentication/domain/repositories/authentication_repository.dart';

class GetPublicKeyUseCase {
  final AuthenticationRepository repository;

  GetPublicKeyUseCase(this.repository);

  Future<String> call(String privateKey) async {
    log('Executing GetPublicKeyUseCase', name: 'GetPublicKeyUseCase');
    try {
      final result = await repository.getPublicKey(privateKey);
      log('GetPublicKeyUseCase successful', name: 'GetPublicKeyUseCase');
      return result;
    } catch (e, s) {
      log('Error in GetPublicKeyUseCase', name: 'GetPublicKeyUseCase', error: e, stackTrace: s);
      rethrow;
    }
  }
}
