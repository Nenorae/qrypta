
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypta/src/features/authentication/presentation/providers/auth_providers.dart';

class PinState {
  final String? pin;
  final bool isLoading;
  final String? error;

  PinState({
    this.pin,
    this.isLoading = false,
    this.error,
  });

  PinState copyWith({
    String? pin,
    bool? isLoading,
    String? error,
  }) {
    return PinState(
      pin: pin ?? this.pin,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class PinNotifier extends StateNotifier<PinState> {
  final Ref ref;
  PinNotifier(this.ref) : super(PinState());

  Future<void> savePin(String pin) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await ref.read(authServiceProvider).savePin(pin);
      state = state.copyWith(pin: pin, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> verifyPin(String pin) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await ref.read(authServiceProvider).verifyPin(pin);
      state = state.copyWith(isLoading: false);
      return result;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }
}

final pinProvider = StateNotifierProvider<PinNotifier, PinState>((ref) {
  return PinNotifier(ref);
});
