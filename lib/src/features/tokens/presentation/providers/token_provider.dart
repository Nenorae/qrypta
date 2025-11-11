// lib/src/features/tokens/presentation/providers/token_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/token.dart';
// Usecase lain
import '../../domain/usecases/get_saved_tokens.dart';
import '../../domain/usecases/get_token_details.dart';
import '../../../../core/services/blockchain/blockchain_service.dart'; // Ganti path jika perlu

// ==========================================================
// INI ADALAH PERBAIKAN IMPORT ANDA
import '../../domain/usecases/add_manual_custom_token.dart'; // <-- DIUBAH
// ==========================================================

/// Notifier untuk mengelola state daftar token pengguna.
///
/// State yang dikelola adalah `AsyncValue<List<Token>>` untuk menangani
/// kondisi loading, data, dan error secara asynchronous.
class TokenNotifier extends StateNotifier<AsyncValue<List<Token>>> {
  // ==========================================================
  // INI ADALAH PERBAIKAN TIPE PROPERTI
  final AddManualCustomToken _addManualTokenUseCase; // <-- DIUBAH
  // ==========================================================
  final GetSavedTokens _getSavedTokensUseCase;
  final GetTokenDetails _getTokenDetailsUseCase;
  final String _walletAddress;

  TokenNotifier({
    // ==========================================================
    // INI ADALAH PERBAIKAN TIPE PARAMETER
    required AddManualCustomToken addManualTokenUseCase, // <-- DIUBAH
    // ==========================================================
    required GetSavedTokens getSavedTokensUseCase,
    required GetTokenDetails getTokenDetailsUseCase,
    required String walletAddress,
  }) : _addManualTokenUseCase = addManualTokenUseCase,
       _getSavedTokensUseCase = getSavedTokensUseCase,
       _getTokenDetailsUseCase = getTokenDetailsUseCase,
       _walletAddress = walletAddress,
       super(const AsyncValue.loading()) {
    // Langsung muat token saat notifier diinisialisasi
    fetchUserTokens();
  }

  /// Memuat daftar token yang disimpan pengguna beserta saldonya.
  Future<void> fetchUserTokens() async {
    state = const AsyncValue.loading();
    try {
      // Use case ini diharapkan mengembalikan List<Token> yang sudah ada saldonya.
      final tokens = await _getSavedTokensUseCase.call(_walletAddress);
      state = AsyncValue.data(tokens);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  /// Menambahkan token baru berdasarkan alamat kontraknya.
  ///
  /// Metode ini akan mengambil detail token dari blockchain, menyimpannya,
  /// lalu memperbarui state.
  Future<bool> addTokenByAddress(String contractAddress) async {
    // Pertahankan data lama selama loading untuk UX yang lebih baik
    final previousState = state;
    state = const AsyncValue.loading();

    try {
      // 1. Ambil detail token dari alamat kontrak
      final token = await _getTokenDetailsUseCase.call(contractAddress);

      // 2. Simpan token tersebut (use case ini akan menyimpannya di local storage)
      await _addManualTokenUseCase.call(token);

      // 3. Muat ulang seluruh daftar token untuk menampilkan token baru
      await fetchUserTokens();
      return true;
    } catch (e, s) {
      // Jika gagal, kembalikan state ke error dan tampilkan di UI
      state = AsyncValue.error(e, s);
      // Opsi: kembalikan ke state sebelumnya jika tidak ingin menampilkan error
      // state = previousState;
      return false;
    }
  }
}

// --- DEFINISI PROVIDER ---
// Saya sudah memperbaiki `addManualTokenUseCaseProvider` di bawah.
// Anda masih perlu mengganti implementasi dummy/komentar
// dengan provider Anda yang sebenarnya.

/*
// 1. Provider untuk TokenRepository (bergantung pada implementasinya)
final tokenRepositoryProvider = Provider<TokenRepository>((ref) {
  // Ganti dengan implementasi konkret Anda
  return TokenRepositoryImpl(
    blockchainService: ref.watch(blockchainServiceProvider),
    localDataSource: ref.watch(tokenLocalDataSourceProvider),
  );
});
*/

// 2. Provider untuk Use Cases
final addManualTokenUseCaseProvider = Provider<AddManualCustomToken>((ref) {
  // <-- DIUBAH
  // Asumsi Anda punya `tokenRepositoryProvider` yang didefinisikan di atas
  // return AddManualCustomToken(ref.watch(tokenRepositoryProvider));

  // HANYA UNTUK CONTOH JIKA DI ATAS MASIH KOMENTAR:
  throw UnimplementedError('Ganti ini dengan implementasi repository Anda');
});

final getSavedTokensUseCaseProvider = Provider<GetSavedTokens>((ref) {
  // return GetSavedTokens(ref.watch(tokenRepositoryProvider));
  throw UnimplementedError('Ganti ini dengan implementasi repository Anda');
});

final getTokenDetailsUseCaseProvider = Provider<GetTokenDetails>((ref) {
  // return GetTokenDetails(ref.watch(tokenRepositoryProvider));
  throw UnimplementedError('Ganti ini dengan implementasi repository Anda');
});

// 3. Provider utama untuk TokenNotifier
final tokenNotifierProvider = StateNotifierProvider<
  TokenNotifier,
  AsyncValue<List<Token>>
>((ref) {
  // Dapatkan alamat wallet dari provider lain (misal: authProvider)
  // final walletAddress = ref.watch(authProvider).walletAddress;

  // HANYA UNTUK CONTOH:
  final walletAddress = "0xCONTOH_ALAMAT";
  if (walletAddress == "0xCONTOH_ALAMAT") {
    print(
      "PERINGATAN: Harap ganti walletAddress dummy di tokenNotifierProvider",
    );
  }

  return TokenNotifier(
    addManualTokenUseCase: ref.watch(addManualTokenUseCaseProvider),
    getSavedTokensUseCase: ref.watch(getSavedTokensUseCaseProvider),
    getTokenDetailsUseCase: ref.watch(getTokenDetailsUseCaseProvider),
    walletAddress: walletAddress,
  );
});
