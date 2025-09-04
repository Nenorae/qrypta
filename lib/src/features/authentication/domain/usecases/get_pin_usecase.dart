import 'dart:developer';

import 'package:qrypta/src/features/authentication/domain/repositories/authentication_repository.dart';

class GetPinUseCase {
  final AuthenticationRepository repository;

  GetPinUseCase(this.repository);

  Future<String?> call() async {
    log('Executing GetPinUseCase', name: 'GetPinUseCase');
    try {
      final result = await repository.getPin();
      log('GetPinUseCase successful, pin is ${result != null ? 'present' : 'absent'}', name: 'GetPinUseCase');
      return result;
    } catch (e, s) {
      log('Error in GetPinUseCase', name: 'GetPinUseCase', error: e, stackTrace: s);
      rethrow;
    }
  }
}
