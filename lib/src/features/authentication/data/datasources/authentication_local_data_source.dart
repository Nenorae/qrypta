import 'dart:developer';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class AuthenticationLocalDataSource {
  Future<void> savePrivateKey(String privateKey);
  Future<String?> getPrivateKey();
  Future<String?> getMnemonic();
  Future<void> saveMnemonic(String mnemonic);
  Future<String?> read({required String key});
  Future<void> savePin(String pin); // Added method declaration
  Future<String?> getPin(); // Added method declaration
}

class AuthenticationLocalDataSourceImpl
    implements AuthenticationLocalDataSource {
  final FlutterSecureStorage secureStorage;

  AuthenticationLocalDataSourceImpl({required this.secureStorage});

  @override
  Future<void> savePrivateKey(String privateKey) async {
    log('Saving private key: $privateKey', name: 'AuthLocalDataSource');
    await secureStorage.write(key: 'privateKey', value: privateKey);
  }

  @override
  Future<String?> getPrivateKey() async {
    final privateKey = await secureStorage.read(key: 'privateKey');
    log('Retrieved private key: $privateKey', name: 'AuthLocalDataSource');
    return privateKey;
  }

  @override
  Future<void> saveMnemonic(String mnemonic) async {
    log('Saving mnemonic: "$mnemonic"', name: 'AuthLocalDataSource');
    await secureStorage.write(key: 'mnemonic', value: mnemonic);
  }

  @override
  Future<String?> getMnemonic() async {
    final mnemonic = await secureStorage.read(key: 'mnemonic');
    log('Retrieved mnemonic: "$mnemonic"', name: 'AuthLocalDataSource');
    return mnemonic;
  }

  @override
  Future<String?> read({required String key}) {
    return secureStorage.read(key: key);
  }

  @override
  Future<void> savePin(String pin) async {
    await secureStorage.write(key: 'pin', value: pin);
  }

  @override
  Future<String?> getPin() async {
    return await secureStorage.read(key: 'pin');
  }
}
