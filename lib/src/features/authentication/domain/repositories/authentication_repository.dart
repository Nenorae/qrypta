abstract class AuthenticationRepository {
  Future<String> generateMnemonic();

  Future<String> getPrivateKeyFromMnemonic(String mnemonic);

  Future<String> getPublicKey(String privateKey);

  Future<void> savePrivateKey(String privateKey);

  Future<String?> getPrivateKey();

  Future<void> saveMnemonic(String mnemonic);

  Future<void> savePin(String pin);

  Future<bool> verifyPin(String pin);

  Future<String?> getPin();
}