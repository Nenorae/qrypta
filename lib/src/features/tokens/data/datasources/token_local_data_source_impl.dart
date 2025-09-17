import 'package:shared_preferences/shared_preferences.dart';
import 'token_local_data_source.dart';

class TokenLocalDataSourceImpl implements TokenLocalDataSource {
  final SharedPreferences sharedPreferences;

  // Kunci konstan untuk menyimpan data di SharedPreferences.
  // Mencegah kesalahan pengetikan.
  static const _kTokenAddressesKey = 'CACHED_TOKEN_ADDRESSES';

  TokenLocalDataSourceImpl({required this.sharedPreferences});

  @override
  Future<void> addTokenAddress(String address) async {
    // Standar Ethereum: Validasi format alamat dasar.
    // Alamat harus diawali '0x' diikuti oleh 40 karakter heksadesimal.
    final ethAddressRegex = RegExp(r'^0x[a-fA-F0-9]{40}$');
    if (!ethAddressRegex.hasMatch(address)) {
      throw ArgumentError('Invalid Ethereum address format.');
    }

    // Mengambil daftar alamat yang sudah ada.
    final List<String> currentAddresses =
        sharedPreferences.getStringList(_kTokenAddressesKey) ?? [];

    // Standar Ethereum: Alamat secara teknis case-insensitive, tapi untuk
    // konsistensi dan mencegah duplikasi, simpan dalam format lowercase.
    final String lowercasedAddress = address.toLowerCase();

    // Pastikan tidak ada duplikat sebelum menambahkan.
    if (!currentAddresses.contains(lowercasedAddress)) {
      final updatedAddresses = [...currentAddresses, lowercasedAddress];
      await sharedPreferences.setStringList(
        _kTokenAddressesKey,
        updatedAddresses,
      );
    }
  }

  @override
  Future<List<String>> getTokenAddresses() {
    // Mengambil data dari SharedPreferences.
    // Jika kunci tidak ada (null), kembalikan list kosong.
    final addresses =
        sharedPreferences.getStringList(_kTokenAddressesKey) ?? [];
    return Future.value(addresses);
  }

  @override
  Future<void> removeTokenAddress(String address) async {
    final List<String> currentAddresses =
        sharedPreferences.getStringList(_kTokenAddressesKey) ?? [];

    // Hapus alamat (dalam format lowercase agar cocok dengan data yang disimpan).
    currentAddresses.remove(address.toLowerCase());

    // Simpan kembali daftar yang telah diperbarui.
    await sharedPreferences.setStringList(
      _kTokenAddressesKey,
      currentAddresses,
    );
  }
}
