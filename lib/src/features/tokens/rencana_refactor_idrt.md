# Rencana Refaktor: Integrasi IDRT (Hardcoded)

Dokumen ini menjelaskan rencana untuk mengintegrasikan Rupiah Token (IDRT) secara langsung ke dalam aplikasi, menggantikan mekanisme penemuan token yang dinamis (GraphQL Discover) dengan data yang di-hardcode untuk efisiensi dan fokus pada transaksi transfer.

## 1. Konfigurasi Variabel Lingkungan (`.env`)

Seluruh data sensitif dan konfigurasi token akan dipisahkan ke dalam file `.env` di root proyek.

- `IDRT_CONTRACT_ADDRESS`: Alamat kontrak smart contract IDRT di jaringan Besu.
- `IDRT_NAME`: Nama token (misal: Rupiah Token).
- `IDRT_SYMBOL`: Simbol token (misal: IDRT).
- `IDRT_DECIMALS`: Jumlah desimal token (misal: 18).

## 2. Pembersihan & Fokus Fitur

- **Hapus Fitur Discover**: Sesuai instruksi, fitur untuk mencari token secara dinamis (Token Discovery) akan diabaikan.
- **Hardcoded Asset List**: Aplikasi hanya akan mengenali IDRT sebagai aset utama yang didukung untuk saat ini.

## 3. Perubahan pada Data Layer

### `lib/src/features/tokens/data/token_service.dart` (Baru atau Modifikasi)
- Membuat service yang memuat data IDRT dari `.env`.
- `getHardcodedTokens()`: Mengembalikan list `TokenModel` yang berisi data IDRT.

## 4. Perubahan pada Presentation Layer

### `lib/src/features/tokens/presentation/providers/token_provider.dart`
- Mengubah `TokenNotifier` agar tidak lagi memanggil repository GraphQL untuk daftar aset.
- Menggunakan data dari `token_service.dart` (hardcoded).
- Tetap mempertahankan verifikasi saldo secara langsung ke blockchain (Direct RPC) untuk akurasi.

## 5. Fitur Transfer (Kirim Token)

- Memastikan `send_money` mendukung transaksi ERC20 menggunakan data IDRT yang di-hardcode.
- Mengintegrasikan `blockchainService.erc20.sendErc20Token` dengan input yang divalidasi.

## 6. Langkah Implementasi

1. [x] Tambahkan `flutter_dotenv` ke `pubspec.yaml`.
2. [x] Buat file `.env` dan tambahkan ke `assets`.
3. [ ] Inisialisasi `dotenv` di `main.dart`.
4. [ ] Implementasi `TokenService` untuk memuat data dari `.env`.
5. [ ] Refaktor `TokenNotifier` untuk menggunakan data hardcoded.
6. [ ] Validasi alur kirim token antar wallet menggunakan IDRT.
