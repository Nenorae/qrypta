import 'dart:convert';
import 'dart:developer';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class AuthenticationLocalDataSource {
  Future<void> savePrivateKey(String privateKey);
  Future<String?> getPrivateKey();
  Future<String?> getMnemonic();
  Future<void> saveMnemonic(String mnemonic);
  Future<String?> read({required String key});
  Future<void> savePin(String pin);
  Future<String?> getPin();
}

class AuthenticationLocalDataSourceImpl
    implements AuthenticationLocalDataSource {
  final FlutterSecureStorage secureStorage;

  AuthenticationLocalDataSourceImpl({required this.secureStorage});

  @override
  Future<void> savePrivateKey(String privateKey) async {
    log('Saving private key to secure storage', name: 'AuthLocalDataSource');
    await secureStorage.write(key: 'privateKey', value: privateKey);
  }

  @override
  Future<String?> getPrivateKey() async {
    final privateKey = await secureStorage.read(key: 'privateKey');
    log('Retrieved private key from secure storage (present: ${privateKey != null})', name: 'AuthLocalDataSource');
    return privateKey;
  }

  @override
  Future<void> saveMnemonic(String mnemonic) async {
    log('Saving mnemonic to secure storage', name: 'AuthLocalDataSource');
    await secureStorage.write(key: 'mnemonic', value: mnemonic);
  }

  @override
  Future<String?> getMnemonic() async {
    final mnemonic = await secureStorage.read(key: 'mnemonic');
    log('Retrieved mnemonic from secure storage (present: ${mnemonic != null})', name: 'AuthLocalDataSource');
    return mnemonic;
  }

  @override
  Future<String?> read({required String key}) {
    return secureStorage.read(key: key);
  }

  @override
  Future<void> savePin(String pin) async {
    final hashedPin = sha256.convert(utf8.encode(pin)).toString();
    await secureStorage.write(key: 'pin', value: hashedPin);
  }

  @override
  Future<String?> getPin() async {
    return await secureStorage.read(key: 'pin');
  }
}
