import 'dart:developer';

import 'package:qrypta/src/features/authentication/domain/repositories/authentication_repository.dart';

class SaveMnemonicUseCase {
  final AuthenticationRepository repository;

  SaveMnemonicUseCase(this.repository);

  Future<void> call(String mnemonic) async {
    log('Executing SaveMnemonicUseCase', name: 'SaveMnemonicUseCase');
    try {
      await repository.saveMnemonic(mnemonic);
      log('SaveMnemonicUseCase successful', name: 'SaveMnemonicUseCase');
    } catch (e, s) {
      log('Error in SaveMnemonicUseCase', name: 'SaveMnemonicUseCase', error: e, stackTrace: s);
      rethrow;
    }
  }
}
