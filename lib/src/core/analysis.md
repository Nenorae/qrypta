# Analisis Direktori `lib/src/core`

Direktori `lib/src/core` adalah jantung dari aplikasi, berisi semua logika inti, konfigurasi, dan layanan yang tidak terikat pada fitur spesifik. Struktur ini memungkinkan pemisahan yang jelas antara fungsionalitas inti yang dapat digunakan kembali dan kode UI/fitur.

## 1. `config`

Direktori ini bertanggung jawab untuk semua konfigurasi tingkat aplikasi.

### `blockchain_config.dart`

- **Tujuan**: Menyimpan semua konstanta yang terkait dengan koneksi ke blockchain.
- **Isi**:
  - `rpcUrl`: URL endpoint RPC dari node blockchain (misalnya, node Besu).
  - `chainId`: ID unik dari jaringan blockchain untuk memastikan transaksi dikirim ke jaringan yang benar.
  - `name`: Nama jaringan yang bisa dibaca manusia untuk ditampilkan di UI.
  - `currencySymbol`: Simbol mata uang native jaringan (misalnya, "ETH").

### `theme/`

- **Tujuan**: Mengelola tampilan dan nuansa visual aplikasi.
  - `app_colors.dart`: Mendefinisikan palet warna aplikasi secara terpusat. Ini berisi warna untuk latar belakang, teks, elemen primer, dan aksen.
  - `app_theme.dart`: Mendefinisikan `ThemeData` untuk aplikasi, menggunakan warna dari `app_colors.dart`. Ini mengkonfigurasi gaya untuk komponen umum seperti `AppBar`, `ElevatedButton`, dan `InputDecoration`.

## 2. `data`

Direktori ini mengelola data, termasuk model dan cara data tersebut diambil dan disimpan.

### `models/token_model.dart`

- **Tujuan**: Mendefinisikan struktur data untuk sebuah token.
- **Isi**:
  - `symbol`, `name`, `decimals`: Properti dasar dari sebuah token.
  - `balance`: Jumlah token yang dimiliki, menggunakan `BigInt` untuk presisi tinggi.
  - `logoUrl`: URL opsional untuk logo token.

### `repositories/wallet_repository.dart`

- **Tujuan**: Bertanggung jawab untuk mengambil data terkait dompet dari sumber eksternal.
- **Isi**:
  - `WalletRepository`: Kelas yang berisi metode untuk berinteraksi dengan data dompet.
  - `watchWalletAssets`: Metode yang menggunakan `watchQuery` dari `graphql_flutter` untuk mendengarkan pembaruan aset dompet dari server GraphQL secara *real-time*.
  - `walletRepositoryProvider`: Provider Riverpod untuk menyediakan instance `WalletRepository` ke seluruh aplikasi.

## 3. `error`

Direktori ini mendefinisikan kelas-kelas pengecualian (exception) khusus aplikasi.

### `exceptions.dart`

- **Tujuan**: Membuat jenis kesalahan yang spesifik dan dapat ditangani.
- **Isi**:
  - `ServerException`: Untuk kesalahan yang berasal dari server.
  - `NetworkException`: Untuk masalah jaringan seperti tidak ada koneksi internet.
  - `WalletNotFoundException`: Ketika dompet yang dicari tidak ditemukan.

## 4. `graphql`

Direktori ini berisi semua yang terkait dengan interaksi GraphQL.

### `graphql_provider.dart`

- **Tujuan**: Mengkonfigurasi dan menyediakan klien GraphQL.
- **Isi**:
  - `graphqlClientProvider`: Provider Riverpod yang membuat instance `GraphQLClient`. Ini mengkonfigurasi `HttpLink` (URL server GraphQL) dan `GraphQLCache` (menggunakan Hive untuk persistensi cache).

### `queries.dart`

- **Tujuan**: Menyimpan semua query dan mutasi GraphQL sebagai string konstanta.
- **Isi**:
  - `getMyWalletQuery`: Query untuk mengambil daftar token dan saldo untuk alamat tertentu.
  - `sendRawTransactionMutation`: Mutasi untuk mengirimkan *signed transaction* dalam format heksadesimal ke server untuk disiarkan ke blockchain.

## 5. `services`

Direktori ini berisi kelas-kelas layanan yang merangkum logika bisnis atau interaksi dengan API eksternal.

### `authentication_service.dart`

- **Tujuan**: Menyediakan fungsionalitas otentikasi lokal.
- **Isi**:
  - Menggunakan package `local_auth` untuk memicu otentikasi biometrik (sidik jari/wajah) atau PIN/pola perangkat.

### `blockchain/`

Ini adalah sub-direktori yang paling kompleks, berisi semua layanan untuk berinteraksi dengan blockchain.

- **`blockchain_service.dart` (Gateway Utama)**:
  - **Tujuan**: Bertindak sebagai titik akses tunggal (*gateway*) untuk semua layanan blockchain. Ini menginisialisasi `Web3Client` dan semua sub-layanan lainnya.
  - **Provider**: `blockchainServiceProvider` (Riverpod) memastikan hanya ada satu instance dari layanan ini di seluruh aplikasi.

- **`wallet_service.dart`**:
  - **Tujuan**: Menyediakan utilitas terkait dompet yang tidak memerlukan koneksi ke node.
  - **Fungsi**: Membuat *private key* baru, mendapatkan alamat dari *private key*, dan memvalidasi format alamat Ethereum.

- **`native_currency_service.dart`**:
  - **Tujuan**: Mengelola interaksi dengan mata uang asli blockchain (seperti ETH).
  - **Fungsi**: Mengambil saldo dan mengirim mata uang asli.

- **`erc20_service.dart`**:
  - **Tujuan**: Mengelola interaksi dengan kontrak token standar ERC-20.
  - **Fungsi**: Mengambil saldo token, mengirim token, mendapatkan detail token (nama, simbol, desimal), dan memvalidasi apakah sebuah alamat kontrak adalah token ERC-20 yang valid.

- **`transaction_service.dart`**:
  - **Tujuan**: Mengelola pengiriman, pemantauan, dan pengambilan riwayat transaksi.
  - **Fitur Hibrida**:
    - **Interaksi GraphQL**: Mengirim *signed transaction* dan mengambil riwayat transaksi dari *block explorer* (seperti Blockscout) melalui API GraphQL. Ini lebih cepat dan efisien daripada memindai blok secara manual.
    - **Interaksi RPC Langsung**: Menggunakan `Web3Client` untuk mendapatkan *receipt* transaksi dan menunggu konfirmasi transaksi langsung dari node blockchain.

## 6. `shared_widgets`

Direktori ini berisi widget-widget UI yang dapat digunakan kembali di berbagai fitur.

### `error_display_widget.dart`

- **Tujuan**: Menyediakan cara standar untuk menampilkan pesan kesalahan kepada pengguna.
- **Fitur**: Menampilkan ikon, pesan kesalahan, dan tombol "Coba Lagi" opsional.

## 7. `utils`

Direktori ini berisi fungsi-fungsi utilitas atau pembantu.

### `formatters.dart`

- **Tujuan**: Menyediakan fungsi untuk memformat data agar lebih mudah dibaca oleh pengguna.
- **Fungsi**:
  - `formatAddress`: Mempersingkat alamat Ethereum (misalnya, `0x1234...5678`).
  - `formatEther`: Memformat nilai `double` menjadi string dengan jumlah desimal yang sesuai.
  - `formatBigInt`: Mengonversi nilai `BigInt` (biasanya dalam unit terkecil seperti Wei) menjadi representasi `double` yang dapat dibaca dengan mempertimbangkan jumlah desimal token.
