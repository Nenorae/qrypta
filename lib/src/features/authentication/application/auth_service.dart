import 'dart:developer';

import 'package:qrypta/src/features/authentication/domain/usecases/generate_mnemonic_usecase.dart';
import 'package:qrypta/src/features/authentication/domain/usecases/get_private_key_usecase.dart';
import 'package:qrypta/src/features/authentication/domain/usecases/save_private_key_usecase.dart';
import 'package:qrypta/src/features/authentication/domain/usecases/get_private_key_from_mnemonic_usecase.dart';
import 'package:qrypta/src/features/authentication/domain/usecases/get_public_key_usecase.dart';
import 'package:qrypta/src/features/authentication/domain/usecases/save_pin_usecase.dart';
import 'package:qrypta/src/features/authentication/domain/usecases/verify_pin_usecase.dart';

class AuthService {
  final GenerateMnemonicUseCase generateMnemonicUseCase;
  final SavePrivateKeyUseCase savePrivateKeyUseCase;
  final GetPrivateKeyUseCase getPrivateKeyUseCase;
  final GetPrivateKeyFromMnemonicUseCase getPrivateKeyFromMnemonicUseCase;
  final GetPublicKeyUseCase getPublicKeyUseCase;
  final SavePinUseCase savePinUseCase;
  final VerifyPinUseCase verifyPinUseCase;

  AuthService({
    required this.generateMnemonicUseCase,
    required this.savePrivateKeyUseCase,
    required this.getPrivateKeyUseCase,
    required this.getPrivateKeyFromMnemonicUseCase,
    required this.getPublicKeyUseCase,
    required this.savePinUseCase,
    required this.verifyPinUseCase,
  });

  Future<String> generateMnemonic() async {
    log('Generating mnemonic...', name: 'AuthService');
    final mnemonic = await generateMnemonicUseCase();
    log('Generated mnemonic: "$mnemonic"', name: 'AuthService');
    return mnemonic;
  }

  Future<void> savePrivateKey(String privateKey) async {
    log('Saving private key...', name: 'AuthService');
    await savePrivateKeyUseCase(privateKey);
    log('Private key saved.', name: 'AuthService');
  }

  Future<String?> getPrivateKey() async {
    log('Getting private key...', name: 'AuthService');
    final privateKey = await getPrivateKeyUseCase();
    log('Retrieved private key: $privateKey', name: 'AuthService');
    return privateKey;
  }

  Future<Map<String, String>> createWallet(String mnemonic) async {
    log('Creating wallet with mnemonic: "$mnemonic"', name: 'AuthService');
    final privateKey = await getPrivateKeyFromMnemonicUseCase(mnemonic);
    log('Derived private key: $privateKey', name: 'AuthService');
    final publicKey = await getPublicKeyUseCase(privateKey);
    log('Derived public key: $publicKey', name: 'AuthService');
    await savePrivateKey(privateKey);
    log('Wallet created successfully.', name: 'AuthService');
    return {'privateKey': privateKey, 'publicKey': publicKey};
  }

  Future<void> savePin(String pin) async {
    await savePinUseCase(pin);
  }

  Future<bool> verifyPin(String pin) async {
    return await verifyPinUseCase(pin);
  }
}