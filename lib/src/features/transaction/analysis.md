# Analisis Fitur Transaksi (Unified Architecture)

Dokumen ini merinci arsitektur dan fungsionalitas fitur `transaction` di Qrypta, yang mencakup siklus hidup lengkap aset digital: pengiriman, penerimaan, pemantauan status, dan riwayat transaksi.

## 1. Arsitektur Terpadu
Fitur ini mengimplementasikan prinsip *Clean Architecture* dan *Layered Architecture* untuk memastikan skalabilitas dan keamanan tinggi dalam interaksi blockchain.

### A. Domain Layer (Kebutuhan Bisnis)
- **`TransactionRepository`**: Kontrak (interface) untuk operasi data transaksi.
- **`GetRecentTransactionsUseCase`**: Logika bisnis murni untuk mengambil riwayat transaksi pengguna dari blockchain.

### B. Data Layer (Implementasi Data)
- **`TransactionRepositoryImpl`**: Implementasi konkrit yang menggunakan `BlockchainService` untuk berkomunikasi dengan jaringan (RPC/Indexer).

### C. Logic / Controller Layer (State Management)
- **`SendController` (Riverpod Notifier)**: 
    - Mengelola state pengiriman (`SendState`).
    - Melakukan validasi input.
    - Mengeksekusi *Offline Signing* dan *Broadcasting* untuk ETH maupun Token ERC20 (IDRT).
- **`TransactionController` (ChangeNotifier)**: 
    - Mengelola siklus hidup wallet di tingkat fitur (Load, Create, Import).
    - Menghubungkan logika autentikasi dengan kebutuhan transaksi.

### D. Presentation Layer (Antarmuka Pengguna)
- **Screens**:
    - `SendScreen`: UI input pengiriman dengan dukungan pemilihan aset.
    - `ReceiveScreen`: Menampilkan alamat wallet dalam format teks dan QR Code untuk penerimaan aset.
    - `TransactionHistoryScreen`: Daftar riwayat transaksi masuk dan keluar.
    - `ConfirmationPage`: Pemantau status transaksi secara real-time (Polling Receipt).
    - `SendScannerScreen`: Integrasi kamera untuk pemindaian alamat QR.
- **Widgets**:
    - `TransactionListItem`: Komponen visual untuk representasi data transaksi individu (Sent/Received).

## 2. Alur Kerja Utama (Workflow)

### I. Proses Pengiriman (Sending)
1. **Input**: Pengguna memasukkan alamat (manual/QR) dan jumlah di `SendScreen`.
2. **Execution**: `SendController` mengambil *Private Key*, menandatangani transaksi secara offline, dan mengirimkan hex transaksi ke blockchain.
3. **Verification**: Navigasi ke `ConfirmationPage` yang melakukan polling hingga transaksi mendapatkan resi (receipt) dari blockchain.

### II. Proses Penerimaan (Receiving)
1. `ReceiveScreen` mengambil alamat publik wallet pengguna.
2. Alamat dikonversi menjadi QR Code menggunakan `QrImageView`.
3. Tersedia fitur *Copy to Clipboard* dan *Share Address*.

### III. Riwayat Transaksi (History)
1. `transactionHistoryProvider` memicu `GetRecentTransactionsUseCase`.
2. Data diambil melalui repository dan ditampilkan secara asinkron di `TransactionHistoryScreen`.
3. UI secara otomatis membedakan transaksi masuk (hijau) dan keluar (merah) berdasarkan alamat pengguna.

## 3. Integrasi Provider & State
Fitur ini menggunakan Riverpod sebagai orkestrator utama:
- **`transactionRepositoryProvider`**: Menyediakan akses ke implementasi repository.
- **`userWalletAddressProvider`**: Provider asinkron untuk mendapatkan alamat wallet pengguna saat ini.
- **`transactionHistoryProvider`**: Mengelola status loading/error/data untuk riwayat transaksi.
- **`sendControllerProvider`**: Mengelola state UI selama proses transaksi berlangsung.

## 4. Keamanan & Validasi
- **Offline Signing**: Kunci privat tidak pernah meninggalkan perangkat; transaksi ditandatangani secara lokal sebelum dikirim ke RPC.
- **Checksum Address**: Penggunaan alamat Ethereum yang tervalidasi checksum untuk mencegah kesalahan kirim.
- **Input Validation**: Pemeriksaan format alamat dan kecukupan saldo sebelum proses *signing* dimulai.
