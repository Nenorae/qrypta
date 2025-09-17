// Abstraksi untuk datasource token lokal
abstract class TokenLocalDataSource {
  /// Mengambil semua alamat kontrak token yang tersimpan.
  /// Mengembalikan list kosong jika tidak ada.
  Future<List<String>> getTokenAddresses();

  /// Menambahkan alamat kontrak token baru ke penyimpanan.
  /// Alamat akan divalidasi dan disimpan dalam format lowercase.
  Future<void> addTokenAddress(String address);

  /// Menghapus alamat kontrak token dari penyimpanan.
  Future<void> removeTokenAddress(String address);
}
