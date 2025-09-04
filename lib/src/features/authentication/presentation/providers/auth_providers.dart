import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:qrypta/src/features/authentication/application/auth_service.dart';
import 'package:qrypta/src/features/authentication/data/datasources/authentication_local_data_source.dart';
import 'package:qrypta/src/features/authentication/data/repositories/authentication_repository_impl.dart';
import 'package:qrypta/src/features/authentication/domain/repositories/authentication_repository.dart';
import 'package:qrypta/src/features/authentication/domain/usecases/generate_mnemonic_usecase.dart';
import 'package:qrypta/src/features/authentication/domain/usecases/get_private_key_usecase.dart';
import 'package:qrypta/src/features/authentication/domain/usecases/save_mnemonic_usecase.dart';
import 'package:qrypta/src/features/authentication/domain/usecases/save_pin_usecase.dart';
import 'package:qrypta/src/features/authentication/domain/usecases/save_private_key_usecase.dart';
import 'package:qrypta/src/features/authentication/domain/usecases/get_private_key_from_mnemonic_usecase.dart';
import 'package:qrypta/src/features/authentication/domain/usecases/get_public_key_usecase.dart';
import 'package:qrypta/src/features/authentication/domain/usecases/verify_pin_usecase.dart';
import 'package:qrypta/src/features/authentication/domain/usecases/get_pin_usecase.dart';


// Data Layer
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) => const FlutterSecureStorage());

final authLocalDataSourceProvider = Provider<AuthenticationLocalDataSource>((ref) {
  return AuthenticationLocalDataSourceImpl(
    secureStorage: ref.watch(secureStorageProvider),
  );
});

final authRepositoryProvider = Provider<AuthenticationRepository>((ref) {
  return AuthenticationRepositoryImpl(
    localDataSource: ref.watch(authLocalDataSourceProvider),
  );
});

// Domain Layer (Use Cases)
final generateMnemonicUseCaseProvider = Provider<GenerateMnemonicUseCase>(
  (ref) => GenerateMnemonicUseCase(ref.watch(authRepositoryProvider)),
);

final saveMnemonicUseCaseProvider = Provider<SaveMnemonicUseCase>(
  (ref) => SaveMnemonicUseCase(ref.watch(authRepositoryProvider)),
);

final savePrivateKeyUseCaseProvider = Provider<SavePrivateKeyUseCase>(
  (ref) => SavePrivateKeyUseCase(ref.watch(authRepositoryProvider)),
);

final getPrivateKeyUseCaseProvider = Provider<GetPrivateKeyUseCase>(
  (ref) => GetPrivateKeyUseCase(ref.watch(authRepositoryProvider)),
);

final getPrivateKeyFromMnemonicUseCaseProvider = Provider<GetPrivateKeyFromMnemonicUseCase>(
  (ref) => GetPrivateKeyFromMnemonicUseCase(ref.watch(authRepositoryProvider)),
);

final getPublicKeyUseCaseProvider = Provider<GetPublicKeyUseCase>(
  (ref) => GetPublicKeyUseCase(ref.watch(authRepositoryProvider)),
);

final savePinUseCaseProvider = Provider<SavePinUseCase>(
  (ref) => SavePinUseCase(ref.watch(authRepositoryProvider)),
);

final verifyPinUseCaseProvider = Provider<VerifyPinUseCase>(
  (ref) => VerifyPinUseCase(ref.watch(authRepositoryProvider)),
);

// Application Layer
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    generateMnemonicUseCase: ref.watch(generateMnemonicUseCaseProvider),
    savePrivateKeyUseCase: ref.watch(savePrivateKeyUseCaseProvider),
    getPrivateKeyUseCase: ref.watch(getPrivateKeyUseCaseProvider),
    getPrivateKeyFromMnemonicUseCase: ref.watch(getPrivateKeyFromMnemonicUseCaseProvider),
    getPublicKeyUseCase: ref.watch(getPublicKeyUseCaseProvider),
    savePinUseCase: ref.watch(savePinUseCaseProvider),
    verifyPinUseCase: ref.watch(verifyPinUseCaseProvider),
  );
});

// Other providers
final mnemonicProvider = FutureProvider<String>((ref) {
  final authService = ref.read(authServiceProvider);
  return authService.generateMnemonic();
});

final walletSecretsProvider = FutureProvider<Map<String, String?>>((ref) async {
  final localDataSource = ref.watch(authLocalDataSourceProvider);
  final mnemonic = await localDataSource.read(key: 'mnemonic');
  final privateKey = await localDataSource.read(key: 'privateKey');
  return {
    'mnemonic': mnemonic,
    'privateKey': privateKey,
  };
});


// ... (kode lainnya tetap sama)

final getPinUseCaseProvider = Provider<GetPinUseCase>(
  (ref) => GetPinUseCase(ref.watch(authRepositoryProvider)),
);

// ... (kode lainnya tetap sama)

// Provider to check if a wallet exists
final authStateProvider = FutureProvider<bool>((ref) async {
  final getPrivateKeyUseCase = ref.watch(getPrivateKeyUseCaseProvider);
  final getPinUseCase = ref.watch(getPinUseCaseProvider);

  final privateKey = await getPrivateKeyUseCase();
  final pin = await getPinUseCase();

  // Returns true if both private key and pin exist, otherwise false.
  return privateKey != null && privateKey.isNotEmpty && pin != null && pin.isNotEmpty;
});