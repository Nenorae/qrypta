import 'package:qrypta/src/features/authentication/domain/repositories/authentication_repository.dart';

class ValidateMnemonicUseCase {
  final AuthenticationRepository repository;

  ValidateMnemonicUseCase(this.repository);

  Future<bool> call(String mnemonic) async {
    // This use case simply calls the repository method.
    // Additional business logic could be added here in the future if needed.
    return await repository.isMnemonicValid(mnemonic);
  }
}
