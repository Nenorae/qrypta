// lib/src/features/tokens/domain/usecases/get_user_tokens.dart

import 'package:qrypta/src/core/data/models/token_model.dart';
import 'package:qrypta/src/features/tokens/domain/repositories/token_repository.dart';

/// Use case untuk mendapatkan semua token yang disimpan pengguna beserta saldo terbarunya.
class GetUserTokensUseCase {
  final TokenRepository _repository;

  GetUserTokensUseCase(this._repository);

  /// Memanggil use case.
  ///
  /// [walletAddress]: Alamat wallet pengguna untuk memeriksa saldo token.
  /// Mengembalikan daftar token dengan saldo yang sudah diperbarui.
  Future<List<Token>> call({required String walletAddress}) async {
    // Langkah 1: Ambil daftar token yang tersimpan secara lokal.
    // Saldo pada tahap ini mungkin null atau sudah usang.
    final List<Token> savedTokens = await _repository.getSavedTokens();
    if (savedTokens.isEmpty) {
      return [];
    }

    // Langkah 2: Untuk setiap token, ambil saldo terbarunya dari blockchain.
    final List<Future<Token>> tokenBalanceFutures =
        savedTokens.map((token) async {
          try {
            final BigInt balance = await _repository.fetchTokenBalance(
              contractAddress: token.contractAddress,
              walletAddress: walletAddress,
            );
            // Buat objek baru dengan saldo yang diperbarui
            return token.copyWith(balance: balance);
          } catch (e) {
            // Jika gagal mengambil saldo untuk satu token, kembalikan data token
            // tanpa mengubah saldo (atau set ke nol).
            print('Gagal mengambil saldo untuk ${token.symbol}: $e');
            return token.copyWith(balance: BigInt.zero);
          }
        }).toList();

    // Jalankan semua permintaan saldo secara paralel dan tunggu hasilnya.
    final List<Token> tokensWithBalances = await Future.wait(
      tokenBalanceFutures,
    );

    return tokensWithBalances;
  }
}
