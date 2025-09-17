// token_provider.dart

class TokenNotifier extends StateNotifier<AsyncValue<List<Token>>> {
  final AddManualTokenUseCase _addManualTokenUseCase;
  // ... constructor dan method lainnya

  Future<bool> addManualToken(Token token) async {
    state = const AsyncValue.loading();
    try {
      // Panggil use case
      await _addManualTokenUseCase(token);
      // Muat ulang daftar token untuk memperbarui UI
      await fetchUserTokens();
      return true;
    } catch (e) {
      // Jika gagal, kembalikan state ke data sebelumnya
      // dan return false
      state = AsyncValue.data(state.value ?? []);
      return false;
    }
  }
}
