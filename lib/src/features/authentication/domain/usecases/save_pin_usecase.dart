import 'dart:developer';

import 'package:qrypta/src/features/authentication/domain/repositories/authentication_repository.dart';

class SavePinUseCase {
  final AuthenticationRepository repository;

  SavePinUseCase(this.repository);

  Future<void> call(String pin) async {
    log('Executing SavePinUseCase', name: 'SavePinUseCase');
    try {
      await repository.savePin(pin);
      log('SavePinUseCase successful', name: 'SavePinUseCase');
    } catch (e, s) {
      log('Error in SavePinUseCase', name: 'SavePinUseCase', error: e, stackTrace: s);
      rethrow;
    }
  }
}
