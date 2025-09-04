import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:qrypta/src/features/authentication/data/datasources/authentication_local_data_source.dart';
import 'package:qrypta/src/features/authentication/domain/repositories/authentication_repository.dart';
import 'package:wallet/wallet.dart' as wallet;

// --- Top-level functions for isolate computation ---

// Note: These functions must be top-level or static to be used with compute().

String _generateMnemonic(String _) {
  // This function now accepts a dummy argument to match the compute signature.
  final mnemonic = wallet.generateMnemonic().join(' ');
  log('Generated mnemonic: "$mnemonic"', name: 'AuthRepo');
  return mnemonic;
}

String _getPrivateKeyFromMnemonic(String mnemonic) {
  try {
    log('Deriving private key from mnemonic: "$mnemonic"', name: 'AuthRepo');
    final mnemonicList = mnemonic.split(' ');
    final seed = wallet.mnemonicToSeed(mnemonicList, passphrase: '');
    final master = wallet.ExtendedPrivateKey.master(seed, wallet.xprv);
    final root = master.forPath("m/44'/60'/0'/0/0");
    final privateKeyBigInt = (root as wallet.ExtendedPrivateKey).key;
    final privateKey = privateKeyBigInt.toRadixString(16).padLeft(64, '0');
    log('Derived private key: $privateKey', name: 'AuthRepo');
    return privateKey;
  } catch (e) {
    log('Error deriving private key: $e', name: 'AuthRepo', error: e);
    // Exceptions in isolates should be re-thrown to be caught by the main isolate.
    throw Exception('Failed to generate private key from mnemonic: $e');
  }
}

// This is a helper for other top-level functions.
wallet.PrivateKey _createPrivateKey(String privateKeyHex) =>
    wallet.PrivateKey(BigInt.parse(privateKeyHex, radix: 16));

String _getPublicKey(String privateKeyHex) {
  try {
    final publicKey = wallet.ethereum.createPublicKey(_createPrivateKey(privateKeyHex));
    return publicKey.toString();
  } catch (e) {
    throw Exception('Failed to generate public key: $e');
  }
}

String _getCustomBlockchainAddress(String privateKeyHex) {
  try {
    final publicKey =
        wallet.ethereum.createPublicKey(_createPrivateKey(privateKeyHex));
    return wallet.ethereum.createAddress(publicKey);
  } catch (e) {
    throw Exception('Failed to generate address: $e');
  }
}

String _getChecksumAddress(String privateKeyHex) {
  try {
    final publicKey =
        wallet.ethereum.createPublicKey(_createPrivateKey(privateKeyHex));
    final addressString = wallet.ethereum.createAddress(publicKey);
    return wallet.EthereumAddress.fromHex(
      addressString,
    ).toString();
  } catch (e) {
    throw Exception('Failed to generate checksum address: $e');
  }
}

class AuthenticationRepositoryImpl implements AuthenticationRepository {
  final AuthenticationLocalDataSource localDataSource;

  AuthenticationRepositoryImpl({required this.localDataSource});

  @override
  Future<String> generateMnemonic() async => await compute(_generateMnemonic, '');

  @override
  Future<String> getPrivateKeyFromMnemonic(String mnemonic) async {
    try {
      return await compute(_getPrivateKeyFromMnemonic, mnemonic);
    } catch (e) {
      log('Error in getPrivateKeyFromMnemonic: $e', name: 'AuthRepo', error: e);
      // Rethrowing the exception from compute.
      throw Exception('Failed to generate private key from mnemonic: $e');
    }
  }

  @override
  Future<String> getPublicKey(String privateKeyHex) async {
    try {
      return await compute(_getPublicKey, privateKeyHex);
    } catch (e) {
      throw Exception('Failed to generate public key: $e');
    }
  }

  @override
  Future<void> savePrivateKey(String privateKey) =>
      localDataSource.savePrivateKey(privateKey);

  @override
  Future<String?> getPrivateKey() => localDataSource.getPrivateKey();

  Future<String> getCustomBlockchainAddress(String privateKeyHex) async {
    try {
      return await compute(_getCustomBlockchainAddress, privateKeyHex);
    } catch (e) {
      throw Exception('Failed to generate address: $e');
    }
  }

  bool isValidCustomAddress(String address) {
    try {
      // Coba buat instance alamat dan paksa validasi checksum EIP-55.
      // Jika alamat tidak valid (baik format atau checksum-nya),
      // baris ini akan melempar sebuah exception.
      wallet.EthereumAddress.fromHex(address);

      // Jika tidak ada exception, berarti alamat tersebut valid.
      return true;
    } catch (e) {
      // Jika terjadi exception, berarti alamat tidak valid.
      return false;
    }
  }

  Future<String> getChecksumAddress(String privateKeyHex) async {
    try {
      return await compute(_getChecksumAddress, privateKeyHex);
    } catch (e) {
      throw Exception('Failed to generate checksum address: $e');
    }
  }

  bool isValidPrivateKeyHex(String privateKeyHex) {
    try {
      return privateKeyHex.length == 64 &&
          BigInt.tryParse(privateKeyHex, radix: 16) != null;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, String>> generateKeyPair() async {
    try {
      final mnemonic = await generateMnemonic();
      final privateKey = await getPrivateKeyFromMnemonic(mnemonic);
      final publicKey = await getPublicKey(privateKey);
      final address = await getCustomBlockchainAddress(privateKey);

      return {
        'mnemonic': mnemonic,
        'privateKey': privateKey,
        'publicKey': publicKey,
        'address': address,
      };
    } catch (e) {
      throw Exception('Failed to generate keypair: $e');
    }
  }

  String normalizePrivateKey(String privateKey) {
    final key =
        privateKey.startsWith('0x') ? privateKey.substring(2) : privateKey;
    return key.padLeft(64, '0');
  }

  String getPrivateKeyWithPrefix(String privateKeyHex) =>
      '0x${normalizePrivateKey(privateKeyHex)}';

  Future<bool> verifySignature(
    String message,
    String signature,
    String publicKeyHex,
  ) async {
    try {
      // Implementation untuk verifikasi signature jika diperlukan
      // Ini adalah placeholder untuk future implementation
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> savePin(String pin) async {
    await localDataSource.savePin(pin);
  }

  @override
  Future<bool> verifyPin(String pin) async {
    final storedPin = await localDataSource.getPin();
    return storedPin == pin;
  }

  @override
  Future<String?> getPin() async {
    return await localDataSource.getPin();
  }
  
  @override
  Future<void> saveMnemonic(String mnemonic) => localDataSource.saveMnemonic(mnemonic);
}
