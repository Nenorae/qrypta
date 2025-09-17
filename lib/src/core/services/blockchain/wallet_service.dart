// lib/src/core/services/blockchain/wallet_service.dart

import 'dart:developer' as developer;
import 'dart:math';
import 'package:convert/convert.dart';
import 'package:web3dart/web3dart.dart';

/// Mengelola utilitas terkait wallet, seperti pembuatan kunci dan validasi alamat.
class WalletService {
  final String _serviceName = 'WalletService';

  bool isValidAddress(String address) {
    try {
      EthereumAddress.fromHex(address);
      return true;
    } catch (e) {
      developer.log(
        '[ERROR] Invalid address format: $address',
        name: _serviceName,
        error: e,
      );
      return false;
    }
  }

  Future<EthereumAddress> getAddressFromPrivateKey(String privateKey) async {
    final credentials = EthPrivateKey.fromHex(privateKey);
    return credentials.address;
  }

  EthPrivateKey createRandomPrivateKey() {
    var rng = Random.secure();
    final key = EthPrivateKey.createRandom(rng);
    developer.log('[INFO] Created new random private key.', name: _serviceName);
    return key;
  }

  String getPrivateKeyHex(EthPrivateKey key) {
    return '0x${hex.encode(key.privateKey)}';
  }
}
