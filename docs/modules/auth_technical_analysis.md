# Analisa Teknis: Fitur Autentikasi Qrypta

Dokumen ini berisi penjelasan teknis mendalam mengenai arsitektur, implementasi kriptografi, dan alur kerja fitur autentikasi pada modul `lib/src/features/authentication`.

## 1. Arsitektur Sistem
Modul ini mengadopsi **Clean Architecture** dengan pemisahan tanggung jawab yang ketat:

*   **Domain Layer**: Berisi abstraksi repository dan Use Cases. Ini adalah core business logic yang murni Dart tanpa dependensi framework.
*   **Data Layer**: Implementasi repository dan data sources (Local Storage menggunakan `FlutterSecureStorage`).
*   **Application Layer**: `AuthService` bertindak sebagai koordinator antar Use Cases untuk menyederhanakan interaksi bagi lapisan presentasi.
*   **Presentation Layer (Non-UI)**: Menggunakan **Riverpod** untuk Dependency Injection dan State Management (`StateNotifier`).

## 2. Implementasi Kriptografi & Standar Blockchain
Qrypta menggunakan standar industri Ethereum yang memastikan interoperabilitas penuh dengan EVM-compatible chains (termasuk Hyperledger Besu).

### A. Algoritma Kunci
*   **Kurva Elips**: Menggunakan `secp256k1` melalui algoritma **ECDSA** (Elliptic Curve Digital Signature Algorithm).
*   **Mnemonic (BIP39)**: Menghasilkan 12-24 kata acak yang kemudian diubah menjadi *seed* 512-bit.
*   **Derivasi Kunci (BIP32/BIP44)**:
    *   Menggunakan *Hierarchical Deterministic (HD) Wallet*.
    *   **Derivation Path**: `m/44'/60'/0'/0/0`
        *   `44'`: Standar BIP44.
        *   `60'`: Coin type Ethereum.
        *   `0'/0/0`: Account 0, Chain 0 (external), Index 0.

### B. Representasi Alamat
*   **Ethereum Address**: Dihasilkan dari *Keccak-256 hash* dari public key (diambil 20 byte terakhir).
*   **EIP-55 Checksum**: Implementasi `getChecksumAddress` memastikan alamat memiliki *case-sensitivity* yang valid untuk mencegah kesalahan pengetikan manual (misal: `0x...A1b2...`).

## 3. Optimasi Performa (Concurrency)
Operasi kriptografi (seperti `mnemonicToSeed` dan derivasi kunci) adalah tugas yang memakan CPU intensif. Untuk menjaga UI tetap responsif (60/120 FPS), Qrypta menggunakan **Flutter Isolate** via fungsi `compute()`.

Fungsi-fungsi berikut dieksekusi di *background isolate*:
*   `_generateMnemonic`
*   `_getPrivateKeyFromMnemonic`
*   `_getPublicKey`
*   `_getChecksumAddress`
*   `_isMnemonicValid`

## 4. Keamanan Data (Storage Strategy)
Data sensitif tidak pernah disimpan dalam `SharedPreferences` atau database lokal biasa.
*   **Penyimpanan**: Menggunakan `FlutterSecureStorage`.
    *   **Android**: Menggunakan hardware-backed **Keystore** (AES encryption).
    *   **iOS**: Menggunakan **Keychain Services**.
*   **Data Terproteksi**: `privateKey`, `mnemonic`, dan `pin`.

## 5. Analisa Fungsi Utama

### A. Wallet Creation Flow (`AuthService.createWallet`)
1.  Menerima frasa mnemonic.
2.  Memanggil `GetPrivateKeyFromMnemonicUseCase`.
3.  Menurunkan Private Key (Hex 64 char).
4.  Menghasilkan Public Key dari Private Key.
5.  Menyimpan Private Key ke secure storage secara asinkron.
6.  Mengembalikan Map berisi pasangan kunci.

### B. PIN Management
*   **Hashing**: Saat ini PIN disimpan secara langsung di secure storage. *Rekomendasi masa depan: Gunakan PBKDF2 atau Argon2 untuk hashing sebelum penyimpanan.*
*   **Verification**: Dibandingkan secara literal antara input user dengan data yang diambil dari `FlutterSecureStorage`.

## 6. Dependency Graph (Riverpod)
Sistem menggunakan pola *top-down* injection:
1.  `secureStorageProvider`: Inisialisasi library storage.
2.  `authLocalDataSourceProvider`: Memberikan akses ke storage keys.
3.  `authRepositoryProvider`: Mengimplementasikan logika bisnis data.
4.  `useCaseProviders`: Granularitas fungsi (misal: `savePinUseCaseProvider`).
5.  `authServiceProvider`: Facade untuk UI berinteraksi dengan domain.
6.  `authStateProvider`: `FutureProvider` yang menentukan status aplikasi (apakah user sudah memiliki wallet & PIN).

## 7. Validasi Data
*   **Mnemonic Validation**: Mengecek jumlah kata (12, 15, 18, 21, 24) dan integritas checksum mnemonic sebelum proses impor dilakukan.
*   **Address Validation**: Menggunakan `EthereumAddress.fromHex()` untuk memastikan format heksadesimal valid.

---
*Dokumen ini dibuat otomatis sebagai bagian dari dokumentasi teknis Qrypta.*
