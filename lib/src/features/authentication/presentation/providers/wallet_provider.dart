import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypta/src/features/authentication/presentation/providers/auth_providers.dart';

final walletProvider = StateNotifierProvider<WalletNotifier, WalletState>((ref) {
  return WalletNotifier(ref);
});

class WalletState {
  final String? privateKey;
  final String? publicKey;
  final bool isLoading;
  final String? error;

  WalletState({
    this.privateKey,
    this.publicKey,
    this.isLoading = false,
    this.error,
  });

  WalletState copyWith({
    String? privateKey,
    String? publicKey,
    bool? isLoading,
    String? error,
  }) {
    return WalletState(
      privateKey: privateKey ?? this.privateKey,
      publicKey: publicKey ?? this.publicKey,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class WalletNotifier extends StateNotifier<WalletState> {
  final Ref ref;

  WalletNotifier(this.ref) : super(WalletState());

  Future<void> createWallet(String mnemonic) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final authService = ref.read(authServiceProvider);
      final walletData = await authService.createWallet(mnemonic);
      state = state.copyWith(
        privateKey: walletData['privateKey'],
        publicKey: walletData['publicKey'],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> checkExistingWallet() async {
    final getPrivateKeyUseCase = ref.read(getPrivateKeyUseCaseProvider);
    final getPinUseCase = ref.read(getPinUseCaseProvider);
    final privateKey = await getPrivateKeyUseCase();
    final pin = await getPinUseCase();
    return privateKey != null && privateKey.isNotEmpty && pin != null && pin.isNotEmpty;
  }
}