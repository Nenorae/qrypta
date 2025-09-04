import 'dart:developer';

import 'package:qrypta/src/features/authentication/domain/repositories/authentication_repository.dart';

class GetPrivateKeyFromMnemonicUseCase {
  final AuthenticationRepository repository;

  GetPrivateKeyFromMnemonicUseCase(this.repository);

  Future<String> call(String mnemonic) async {
    log('Executing GetPrivateKeyFromMnemonicUseCase', name: 'GetPrivateKeyFromMnemonicUseCase');
    try {
      final result = await repository.getPrivateKeyFromMnemonic(mnemonic);
      log('GetPrivateKeyFromMnemonicUseCase successful', name: 'GetPrivateKeyFromMnemonicUseCase');
      return result;
    } catch (e, s) {
      log('Error in GetPrivateKeyFromMnemonicUseCase', name: 'GetPrivateKeyFromMnemonicUseCase', error: e, stackTrace: s);
      rethrow;
    }
  }
}
