import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:qrypta/src/features/authentication/domain/repositories/authentication_repository.dart';
import 'package:web3dart/web3dart.dart' as web3;

class TransactionController extends ChangeNotifier {
  final AuthenticationRepository _authenticationRepository;
  String? _ethAddress;
  web3.EthPrivateKey? _credentials; // Gunakan web3.EthPrivateKey secara eksplisit
  bool _isLoading = true;

  String? get ethAddress => _ethAddress;
  bool get isLoading => _isLoading;

  TransactionController(this._authenticationRepository) {
    loadWallet();
  }

  Future<void> loadWallet() async {
    developer.log('Loading wallet', name: 'TransactionController');
    _isLoading = true;
    notifyListeners();

    try {
      final privateKeyHex = await _authenticationRepository.getPrivateKey();
      if (privateKeyHex != null) {
        // Gunakan EthPrivateKey dari web3dart
        _credentials = web3.EthPrivateKey.fromHex(privateKeyHex);
        // Gunakan properti yang benar untuk mendapatkan alamat
        _ethAddress = _credentials!.address.toString();
        developer.log('Wallet loaded successfully. Address: $_ethAddress', name: 'TransactionController');
      } else {
        developer.log('No private key found, creating a new wallet', name: 'TransactionController');
        await createWallet();
      }
    } catch (e, s) {
      developer.log('Error loading wallet', name: 'TransactionController', error: e, stackTrace: s);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String> createWallet() async {
    developer.log('Creating a new wallet', name: 'TransactionController');
    _isLoading = true;
    notifyListeners();

    try {
      final mnemonic = await _authenticationRepository.generateMnemonic();
      final privateKeyHex = await _authenticationRepository
          .getPrivateKeyFromMnemonic(mnemonic);
      await _authenticationRepository.savePrivateKey(privateKeyHex);

      // Inisialisasi ulang wallet setelah membuat baru
      await loadWallet();
      developer.log('New wallet created successfully', name: 'TransactionController');
      return mnemonic;
    } catch (e, s) {
      developer.log('Error creating wallet', name: 'TransactionController', error: e, stackTrace: s);
      rethrow;
    }
  }

  Future<void> importWallet(String mnemonic) async {
    developer.log('Importing wallet from mnemonic', name: 'TransactionController');
    _isLoading = true;
    notifyListeners();

    try {
      final privateKeyHex = await _authenticationRepository
          .getPrivateKeyFromMnemonic(mnemonic);
      await _authenticationRepository.savePrivateKey(privateKeyHex);
      await loadWallet();
      developer.log('Wallet imported successfully', name: 'TransactionController');
    } catch (e, s) {
      developer.log('Error importing wallet', name: 'TransactionController', error: e, stackTrace: s);
      rethrow;
    }
  }
}