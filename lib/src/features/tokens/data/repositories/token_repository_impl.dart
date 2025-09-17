// lib/src/features/tokens/data/repositories/token_repository_impl.dart

// Hapus import 'package:web3dart/web3dart.dart; karena tidak lagi dibutuhkan di sini.
import '../../../../core/data/models/token_model.dart';
import '../../../../core/services/blockchain_service.dart'; // Ganti path jika perlu
import '../../domain/repositories/token_repository.dart';
import '../datasources/token_local_data_source.dart';

/// Implementasi dari TokenRepository.
/// Kelas ini berfungsi sebagai jembatan yang mengorkestrasi data dari
/// BlockchainService (untuk data on-chain) dan TokenLocalDataSource (untuk data di perangkat).
class TokenRepositoryImpl implements TokenRepository {
  // --- DEPENDENSI BARU ---
  // Tidak lagi bergantung pada Web3Client, melainkan service yang lebih tinggi.
  final BlockchainService blockchainService;
  final TokenLocalDataSource localDataSource;

  TokenRepositoryImpl({
    required this.blockchainService,
    required this.localDataSource,
  });

  // =======================================================
  // ==           OPERASI BLOCKCHAIN (Delegasi)           ==
  // =======================================================

  @override
  Future<Token> getTokenDetails(String contractAddress) async {
    // Tugas sepenuhnya didelegasikan ke BlockchainService.
    // Repositori tidak perlu tahu cara kerja web3dart.
    final detailsMap = await blockchainService.getTokenDetails(contractAddress);

    // Repositori bertanggung jawab mengubah Map menjadi objek Model
    return Token(
      name: detailsMap['name'] as String,
      symbol: detailsMap['symbol'] as String,
      decimals: detailsMap['decimals'] as int,
      contractAddress: detailsMap['address'] as String,
    );
  }

  @override
  Future<BigInt> fetchTokenBalance({
    required String contractAddress,
    required String walletAddress,
  }) async {
    // Delegasi penuh ke BlockchainService.
    return blockchainService.getErc20Balance(contractAddress, walletAddress);
  }

  @override
  Future<bool> validateTokenContract(String contractAddress) async {
    // Delegasi penuh ke BlockchainService.
    return blockchainService.validateTokenContract(contractAddress);
  }

  // =======================================================
  // ==        OPERASI PENYIMPANAN LOKAL (Delegasi)       ==
  // =======================================================

  @override
  Future<void> saveManualToken(Token token) async {
    // Tidak ada perubahan, tetap mendelegasikan ke data source lokal.
    await localDataSource.addTokenAddress(token.contractAddress);
  }

  @override
  Future<void> removeToken(String contractAddress) async {
    // Tidak ada perubahan, tetap mendelegasikan ke data source lokal.
    await localDataSource.removeTokenAddress(contractAddress);
  }

  @override
  Future<List<Token>> getSavedTokens() async {
    // 1. Ambil daftar alamat dari penyimpanan lokal (DataSource)
    final addresses = await localDataSource.getTokenAddresses();

    if (addresses.isEmpty) {
      return [];
    }

    // 2. Untuk setiap alamat, ambil detail lengkapnya dari Blockchain (melalui Service)
    //    Metode ini memanggil `getTokenDetails` miliknya sendiri, yang sudah didelegasikan.
    final tokenFutures =
        addresses.map((addr) => getTokenDetails(addr)).toList();

    try {
      final tokens = await Future.wait(tokenFutures);
      return tokens;
    } catch (e) {
      print('Error fetching saved tokens details: $e');
      // Berikan feedback bahwa beberapa token mungkin gagal dimuat
      return [];
    }
  }
}
