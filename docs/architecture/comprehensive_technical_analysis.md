# Laporan Analisa Teknis Komprehensif: Arsitektur & Fitur Qrypta

Dokumen ini merupakan konsolidasi seluruh analisis teknis modul utama Qrypta, mencakup aspek arsitektur, kriptografi, manajemen state, dan alur kerja sistem.

---

## 1. Arsitektur Global & Autentikasi
Aplikasi Qrypta mengadopsi **Clean Architecture** untuk memastikan skalabilitas dan keamanan tinggi.

### A. Lapisan Arsitektur
*   **Domain Layer**: Berisi abstraksi repository dan Use Cases (core logic murni Dart).
*   **Data Layer**: Implementasi repository menggunakan `FlutterSecureStorage` untuk data sensitif.
*   **Application Layer**: `AuthService` bertindak sebagai fasilitator antar Use Cases.
*   **Presentation Layer**: Menggunakan **Riverpod** untuk Dependency Injection dan manajemen state reaktif.

### B. Standar Kriptografi & Blockchain (EVM Compatible)
Qrypta sepenuhnya kompatibel dengan ekosistem Ethereum dan Hyperledger Besu melalui standar:
*   **Algoritma**: ECDSA dengan kurva **secp256k1**.
*   **Mnemonic (BIP39)**: Generasi *seed* dari frasa 12-24 kata.
*   **HD Wallet (BIP32/BIP44)**: Derivation path standar Ethereum `m/44'/60'/0'/0/0`.
*   **Address**: Keccak-256 hashing dengan implementasi **EIP-55 Checksum**.

### C. Optimasi Isolate
Tugas CPU-intensif dijalankan pada **Flutter Isolate** melalui `compute()` untuk menjaga UI tetap responsif pada 60/120 FPS:
*   Generasi Mnemonic & Derivasi Private Key.
*   Kalkulasi Public Key & Checksum Address.
*   Validasi integritas mnemonic.

---

## 2. Analisa Fitur Home (Dashboard)
Fitur Home berfungsi sebagai pusat informasi aset pengguna.

### A. Struktur Komponen
*   **BalanceSection**: Saat ini masih bersifat **statis** (hardcoded). Menampilkan total saldo dalam Rupiah.
*   **AssetList**: Bersifat **semi-dinamis**. Menggunakan `tokenNotifierProvider` untuk menampilkan daftar aset yang terintegrasi dengan data blockchain.
*   **ActionButtons**: Modal untuk akses cepat ke fitur Swap, Payment, Send, dan Receive.

### B. Temuan & Rekomendasi
*   **Inkonsistensi**: Saldo utama belum mencerminkan akumulasi nilai dari daftar aset.
*   **Rencana**: Implementasi `BalanceProvider` untuk kalkulasi saldo real-time berdasarkan data dari blockchain RPC.

---

## 3. Analisa Fitur Token (Fokus IDRT)
Strategi difokuskan pada **Aset Terverifikasi** untuk keamanan dan performa maksimal.

### A. Mekanisme Saldo Hybrid
*   Daftar aset (IDRT) dikonfigurasi melalui `.env` dan `TokenService`.
*   Verifikasi saldo dilakukan secara **real-time on-chain** menggunakan panggilan RPC `balanceOf` langsung ke node blockchain (Besu).

### B. Logika Transaksi ERC20
*   Menggunakan `Erc20Service` untuk membungkus fungsi smart contract.
*   Penanganan presisi desimal (18 desimal) menggunakan `BigInt` sebelum pengiriman data ke blockchain.

---

## 4. Analisa Fitur Transaksi (Unified Workflow)
Arsitektur terpadu untuk pengiriman, penerimaan, dan pelacakan status aset.

### A. Alur Kerja Pengiriman (Sending)
1.  **Input**: Validasi format alamat (Checksum) dan kecukupan saldo.
2.  **Offline Signing**: Transaksi ditandatangani secara lokal menggunakan Private Key. Kunci privat **tidak pernah** meninggalkan perangkat.
3.  **Broadcasting**: Hex transaksi dikirim ke RPC node.
4.  **Verification**: Polling otomatis pada `ConfirmationPage` hingga transaksi mendapatkan *receipt*.

### B. Alur Kerja Penerimaan & Riwayat
*   **Penerimaan**: Generasi QR Code dari alamat publik menggunakan `QrImageView`.
*   **Riwayat**: `transactionHistoryProvider` secara otomatis membedakan transaksi *Incoming* (hijau) dan *Outgoing* (merah).

---

## 5. Analisa Logika Verifikasi PIN (`PinVerificationScreen`)
Bagian ini merinci mekanisme keamanan akses aplikasi berdasarkan implementasi pada `pin_verification_screen.dart`.

### A. Mekanisme Verifikasi
*   **Controller Layer**: Menggunakan `TextEditingController` untuk menangkap input numerik (masking/obscure).
*   **State Interaction**: Memanggil `pinProvider.notifier.verifyPin(pin)`.
*   **Logical Flow**:
    1.  Cek keberadaan input (Empty validation).
    2.  Pencocokan string literal dengan data di `FlutterSecureStorage`.
    3.  Eksekusi callback `onVerificationSuccess` jika valid.

### B. Protokol Debugging & Observabilitas
Sistem dilengkapi dengan log ekstensif untuk pelacakan kegagalan:
*   Status `initState` dan `dispose` untuk manajemen lifecycle.
*   Logging PIN yang masuk untuk verifikasi (dalam mode pengembangan).
*   Logging status `mounted` untuk mencegah error saat memanggil callback pada widget yang sudah dihancurkan.

---

## 6. Strategi Keamanan Data (Storage)
Data kritis dikelola secara eksklusif oleh `FlutterSecureStorage`:
*   **Android**: Hardware-backed **Keystore** (AES).
*   **iOS**: **Keychain Services**.
*   **Data Terproteksi**: Private Key, Mnemonic, dan PIN Code.

---
*Dokumen ini merupakan rangkuman teknis otoritatif untuk pengembangan Qrypta.*
