// lib/src/features/tokens/domain/repositories/token_repository.dart

import 'package:qrypta/src/core/data/models/token_model.dart';

/// Kontrak (Interface) untuk mengelola semua data terkait token,
/// baik dari blockchain maupun penyimpanan lokal.
abstract class TokenRepository {
  // =======================================================
  // ==                OPERASI BLOCKCHAIN                 ==
  // =======================================================

  /// Mengambil detail token (nama, simbol, desimal) dari sebuah kontrak ERC-20.
  Future<Token> getTokenDetails(String contractAddress);

  /// Mengambil saldo spesifik sebuah token ERC-20 untuk alamat wallet tertentu.
  /// Menggunakan `BigInt` karena saldo token bisa sangat besar.
  Future<BigInt> fetchTokenBalance({
    required String contractAddress,
    required String walletAddress,
  });

  /// Memvalidasi apakah sebuah alamat kontrak adalah token ERC-20 yang valid
  /// dengan mencoba memanggil fungsi standar di dalamnya.
  Future<bool> validateTokenContract(String contractAddress);

  // =======================================================
  // ==              OPERASI PENYIMPANAN LOKAL            ==
  // =======================================================

  /// Menyimpan data token yang diinput manual ke penyimpanan lokal.
  Future<void> saveManualToken(Token token);

  /// Mengambil daftar token yang telah disimpan pengguna dari penyimpanan lokal.
  /// Daftar token ini mungkin belum memiliki data saldo terbaru.
  Future<List<Token>> getSavedTokens();

  /// Menghapus token dari daftar simpanan pengguna berdasarkan alamat kontraknya.
  Future<void> removeToken(String contractAddress);
}
