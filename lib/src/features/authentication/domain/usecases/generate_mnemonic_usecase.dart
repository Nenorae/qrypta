
import 'dart:developer';

import 'package:qrypta/src/features/authentication/domain/repositories/authentication_repository.dart';

class GenerateMnemonicUseCase {
  final AuthenticationRepository repository;

  GenerateMnemonicUseCase(this.repository);

  Future<String> call() async {
    log('Executing GenerateMnemonicUseCase', name: 'GenerateMnemonicUseCase');
    try {
      final result = await repository.generateMnemonic();
      log('GenerateMnemonicUseCase successful', name: 'GenerateMnemonicUseCase');
      return result;
    } catch (e, s) {
      log('Error in GenerateMnemonicUseCase', name: 'GenerateMnemonicUseCase', error: e, stackTrace: s);
      rethrow;
    }
  }
}
