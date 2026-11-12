# Laporan Analisa Teknis Komprehensif: Arsitektur & Integrasi QRIS Cross-Border Qrypta

Dokumen ini merupakan konsolidasi seluruh analisis teknis modul utama Qrypta, mencakup aspek arsitektur fundamental, kriptografi, manajemen state, alur kerja sistem on-chain, serta arsitektur integrasi jembatan fiat-kripto (Cross-Border Liquidity) melalui jaringan QRIS.

## 1. Arsitektur Global & Autentikasi

Aplikasi Qrypta mengadopsi Clean Architecture untuk memastikan skalabilitas dan keamanan tinggi, serta memisahkan logika Web3 dari UI.

### A. Lapisan Arsitektur

- **Domain Layer**: Berisi abstraksi repository dan Use Cases (core logic murni Dart).
- **Data Layer**: Implementasi repository menggunakan FlutterSecureStorage untuk data sensitif.
- **Application Layer**: AuthService bertindak sebagai fasilitator antar Use Cases.
- **Presentation Layer**: Menggunakan Riverpod untuk Dependency Injection dan manajemen state reaktif.

### B. Standar Kriptografi & Blockchain (EVM Compatible)

Qrypta sepenuhnya kompatibel dengan ekosistem Ethereum dan Hyperledger Besu melalui standar:

- **Algoritma**: ECDSA dengan kurva secp256k1.
- **Mnemonic (BIP39)**: Generasi seed dari frasa 12-24 kata.
- **HD Wallet (BIP32/BIP44)**: Derivation path standar Ethereum m/44'/60'/0'/0/0.
- **Address**: Keccak-256 hashing dengan implementasi EIP-55 Checksum.

### C. Optimasi Isolate (CPU-Bound Tasks)

Tugas CPU-intensif dijalankan pada Flutter Isolate melalui compute() untuk menjaga UI tetap responsif pada 60/120 FPS:

- Generasi Mnemonic & Derivasi Private Key.
- Kalkulasi Public Key & Checksum Address.
- Validasi integritas mnemonic.
- **Pengembangan Baru**: Parsing data EMVCo TLV dan validasi Cyclic Redundancy Check (CRC) dari raw string QRIS.

## 2. Analisa Fitur Home (Dashboard)

Fitur Home berfungsi sebagai pusat informasi aset pengguna.

### A. Struktur Komponen

- **BalanceSection**: Saat ini masih bersifat statis (hardcoded). Menampilkan total saldo dalam Rupiah.
- **AssetList**: Bersifat semi-dinamis. Menggunakan tokenNotifierProvider untuk menampilkan daftar aset yang terintegrasi dengan data blockchain.
- **ActionButtons**: Modal untuk akses cepat ke fitur Swap, Payment, Send, dan Receive (termasuk entry-point QRIS Scanner).

### B. Temuan & Rekomendasi

- **Inkonsistensi**: Saldo utama belum mencerminkan akumulasi nilai dari daftar aset.
- **Rencana**: Implementasi BalanceProvider untuk kalkulasi saldo real-time berdasarkan data dari blockchain RPC.

## 3. Analisa Fitur Token (Fokus IDRT)

Strategi difokuskan pada Aset Terverifikasi untuk keamanan dan performa maksimal.

### A. Mekanisme Saldo Hybrid

- Daftar aset (IDRT) dikonfigurasi melalui .env dan TokenService.
- Verifikasi saldo dilakukan secara real-time on-chain menggunakan panggilan RPC balanceOf langsung ke node blockchain (Besu).

### B. Logika Transaksi ERC20

- Menggunakan Erc20Service untuk membungkus fungsi smart contract.
- Penanganan presisi desimal (18 desimal) menggunakan BigInt sebelum pengiriman data ke blockchain.

## 4. Analisa Fitur Transaksi (Unified Workflow)

Arsitektur terpadu untuk pengiriman, penerimaan, dan pelacakan status aset.

### A. Alur Kerja Pengiriman (Sending)

1.  **Input**: Validasi format alamat (Checksum) dan kecukupan saldo.
2.  **Offline Signing**: Transaksi ditandatangani secara lokal menggunakan Private Key. Kunci privat tidak pernah meninggalkan perangkat.
3.  **Broadcasting**: Hex transaksi dikirim ke RPC node.
4.  **Verification**: Polling otomatis pada ConfirmationPage hingga transaksi mendapatkan receipt.

### B. Alur Kerja Penerimaan & Riwayat

- **Penerimaan**: Generasi QR Code dari alamat publik menggunakan QrImageView.
- **Riwayat**: transactionHistoryProvider secara otomatis membedakan transaksi Incoming (hijau) dan Outgoing (merah).

## 5. Analisa Logika Verifikasi PIN (PinVerificationScreen)

Bagian ini merinci mekanisme keamanan akses aplikasi dan otorisasi Offline Signing.

### A. Mekanisme Verifikasi

- **Controller Layer**: Menggunakan TextEditingController untuk menangkap input numerik (masking/obscure).
- **State Interaction**: Memanggil pinProvider.notifier.verifyPin(pin).
- **Logical Flow**:
    1.  Cek keberadaan input (Empty validation).
    2.  Pencocokan string literal dengan data di FlutterSecureStorage.
    3.  Eksekusi callback onVerificationSuccess jika valid (membuka kunci Private Key untuk proses signing).

### B. Protokol Debugging & Observabilitas

Sistem dilengkapi dengan log ekstensif untuk pelacakan kegagalan:

- Status initState dan dispose untuk manajemen lifecycle.
- Logging PIN yang masuk untuk verifikasi (dalam mode pengembangan).
- Logging status mounted untuk mencegah error saat memanggil callback.

## 6. Strategi Keamanan Data (Storage)

Data kritis dikelola secara eksklusif oleh FlutterSecureStorage:

- **Android**: Hardware-backed Keystore (AES).
- **iOS**: Keychain Services.
- **Data Terproteksi**: Private Key, Mnemonic, dan PIN Code.

## 7. Arsitektur Integrasi QRIS & Cross-Border Liquidity (Saga Pattern)

Modul ini adalah ekstensi dari Qrypta untuk menjembatani aset on-chain (token) dengan kewajiban pembayaran off-chain (fiat melalui jaringan QRIS GPN) dengan likuiditas yang disediakan oleh Bank Daerah.

Sistem menggunakan pola Two-Phase Commit (Saga Pattern) dengan Backend Middleware sebagai Orchestrator untuk memastikan konsistensi data.

### A. Komponen Tambahan

- **Backend Middleware (Saga Orchestrator)**: Layer service (Node.js/Spring Boot) yang menjembatani Flutter Qrypta, RPC Blockchain Node, dan API Bank Daerah.
- **Escrow Smart Contract**: Kontrak pintar khusus di jaringan Besu/EVM yang memiliki fungsi lockFunds, commitTransaction, dan rollbackTransaction.
- **Fiat Gateway (Bank API)**: API endpoint pihak penyedia likuiditas (Bank Daerah/EZsign) untuk memproses fiat ke merchant QRIS.

### B. Alur Transaksi QRIS (4 Fase)

#### Fase 1: Discovery & Inquiry (Hybrid Validation)

1.  **Scan & Local Parse**: Kamera membaca QRIS. Proses ekstraksi EMVCo TLV dan validasi algoritma CRC dilempar ke Flutter Isolate agar UI scanner tidak freeze. Jika invalid, tampilkan error instan.
2.  **Inquiry Request**: Jika CRC valid, Qrypta App mengirim payload QRIS mentah ke Backend Middleware.
3.  **Backend Validation**: Middleware memvalidasi ulang ke API Bank Daerah untuk mengecek NMID (National Merchant ID) dan status merchant. Middleware menghitung konversi Token ke IDR + Fee lalu mengembalikan Quote ke Qrypta App.

#### Fase 2: Lock (On-Chain Escrow via Offline Signing)

4.  **Authorization**: Pengguna memverifikasi rincian pembayaran dan memasukkan PIN (PinVerificationScreen).
5.  **Offline Signing & Broadcast**: Menggunakan Erc20Service (atau service contract baru), Qrypta App men-sign transaksi pemanggilan fungsi lockFunds(amount, transactionId) secara lokal dan mem-broadcast Hex ke RPC.
6.  **State Change**: Saldo (Token) pengguna dipindahkan ke alamat Escrow Contract dan statusnya dikunci (LOCKED).

#### Fase 3: Fiat Execution (Off-Chain)

7.  **Trigger Fiat Gateway**: Middleware mendeteksi status receipt LOCKED di blockchain, lalu menembak API Bank Daerah (POST /api/qris/pay) dengan Idempotency-Key untuk mencairkan IDR dari pool likuiditas ke merchant.

#### Fase 4: Resolution (Commit / Rollback)

8.  **Skenario A (Bank SUKSES - 200 OK)**:
    - Middleware memanggil fungsi commitTransaction(transactionId) pada Escrow Contract.
    - Token di-burn secara permanen. Status kontrak menjadi SETTLED. Qrypta App menampilkan notifikasi Berhasil.
9.  **Skenario B (Bank GAGAL / TIMEOUT)**:
    - Middleware memanggil fungsi rollbackTransaction(transactionId) pada Escrow Contract.
    - Token di-unlock dan dikembalikan utuh ke alamat pengguna. Status kontrak menjadi REFUNDED. Qrypta App menampilkan notifikasi Gagal & Refund.

### C. Restriksi & Keamanan Cross-Border

- **Idempotency Key**: Middleware wajib mengirimkan UUID unik ke API Bank untuk mencegah double-spending fiat jika terjadi koneksi terputus.
- **Background Worker**: Middleware menjalankan Cron Job untuk mengecek transaksi LOCKED yang stuck (> 5 menit), melakukan Inquiry Status ke Bank, lalu memaksa Commit atau Rollback.
- **Zero Trust (Smart Contract Security)**: Fungsi commitTransaction dan rollbackTransaction di Escrow Contract hanya boleh dieksekusi oleh wallet address milik Backend Middleware (onlyRelayer modifier), tidak pernah dari Qrypta App langsung.
