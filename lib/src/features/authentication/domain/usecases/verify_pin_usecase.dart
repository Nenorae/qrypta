import 'dart:developer';

import 'package:qrypta/src/features/authentication/domain/repositories/authentication_repository.dart';

class VerifyPinUseCase {
  final AuthenticationRepository repository;

  VerifyPinUseCase(this.repository);

  Future<bool> call(String pin) async {
    log('Executing VerifyPinUseCase', name: 'VerifyPinUseCase');
    try {
      final result = await repository.verifyPin(pin);
      log('VerifyPinUseCase successful, result: $result', name: 'VerifyPinUseCase');
      return result;
    } catch (e, s) {
      log('Error in VerifyPinUseCase', name: 'VerifyPinUseCase', error: e, stackTrace: s);
      rethrow;
    }
  }
}
