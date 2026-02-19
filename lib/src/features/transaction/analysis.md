# Analisis Fitur Transaksi (Unified Architecture)

Dokumen ini menganalisis arsitektur fitur transaksi yang telah digabungkan (merger), mencakup pengelolaan wallet, penandatanganan transaksi, dan pelaporan status.

## 1. Arsitektur Terpusat
Fitur `transaction` kini menjadi satu-satunya pusat kendali untuk semua aktivitas pemindahan aset (ETH dan Token). Fitur `send_money` telah dihapus dan digabungkan ke dalam modul ini untuk memastikan konsistensi keamanan dan kode.

## 2. Komponen Utama

### A. Logic: `SendController`
- **Tanggung Jawab**: Eksekutor tunggal transaksi.
- **Kemampuan**: Mendukung pengiriman mata uang Native (ETH) dan Token ERC20 (IDRT).
- **Mekanisme**:
  1. Validasi input (alamat & jumlah).
  2. Pengambilan Private Key dari secure storage.
  3. Penandatanganan transaksi secara offline (Offline Signing).
  4. Penyiaran ke jaringan blockchain melalui RPC.

### B. Presentation: `SendScreen`
- **Tanggung Jawab**: Antarmuka pengguna (UI) tunggal untuk semua jenis pengiriman.
- **Fitur**: Mendukung input manual dan pemindaian alamat melalui QR Code.
- **Reusability**: Menggunakan parameter `TokenModel? token` untuk menentukan apakah transaksi bersifat native atau token.

### C. Presentation: `ConfirmationPage` (Reporter)
- **Tanggung Jawab**: Pelapor status transaksi (Passive Mode).
- **Mekanisme**: Menerima `transactionHash`, lalu melakukan polling melalui `waitForTransactionReceipt` untuk mendapatkan konfirmasi dari blockchain.
- **Visual**: Menampilkan detail transaksi (To, Amount, Fee, Hash) dan status akhir (Success/Failed).

## 3. Aliran Data (Workflow)
1. **Initiate**: `SendScreen` (ETH) atau `ManageTokensScreen` (Token) memicu navigasi ke `SendScreen`.
2. **Execute**: User input data -> `SendController` melakukan *Signing* dan *Broadcast*.
3. **Report**: Setelah mendapat hash, navigasi otomatis ke `ConfirmationPage`.
4. **Finalize**: `ConfirmationPage` menampilkan resi setelah transaksi terverifikasi di blockchain.

## 4. Keuntungan Struktur Baru
- **Single Point of Truth**: Tidak ada duplikasi logika penandatanganan transaksi.
- **Easier Maintenance**: Perubahan pada logika pengiriman hanya perlu dilakukan di satu file (`send_controller.dart`).
- **Clean UI**: Antarmuka pengiriman konsisten untuk semua aset.
