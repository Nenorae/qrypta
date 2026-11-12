# Analisis Fitur Token: Integrasi Rupiah Token (IDRT)

Dokumen ini merangkum arsitektur dan implementasi fitur token pada aplikasi Qrypta, yang saat ini difokuskan pada penggunaan **Rupiah Token (IDRT)** secara *hardcoded*.

## 1. Strategi Arsitektur: Fokus & Kecepatan
Aplikasi telah beralih dari model penemuan token dinamis (GraphQL Discover) ke model **Aset Terverifikasi**. Strategi ini dipilih untuk memastikan pengguna hanya berinteraksi dengan aset resmi (IDRT) dengan performa maksimal.

## 2. Komponen Utama Fitur

### A. Konfigurasi & Data (`.env` & `TokenService`)
- **Pemisahan Konfigurasi**: Alamat kontrak dan metadata token dipisahkan ke dalam file `.env` untuk memudahkan perubahan antar lingkungan (dev/prod) tanpa mengubah kode program.
- **Data Provider**: `TokenService` bertindak sebagai penyedia aset tunggal yang memetakan variabel lingkungan ke dalam model `TokenModel`.

### B. Verifikasi Saldo (Hybrid RPC)
Meskipun daftar aset bersifat statis (hardcoded), saldo pengguna tetap diverifikasi secara **real-time dan on-chain**:
1. `TokenNotifier` mengambil daftar IDRT.
2. Untuk setiap aset, sistem melakukan panggilan RPC `balanceOf` langsung ke node blockchain (Besu).
3. Hal ini menjamin bahwa saldo yang dilihat pengguna adalah 100% akurat sesuai status blockchain terbaru.

### C. Logika Transfer (`IdrtTransferController`)
- **Mandiri**: Memiliki logika validasi dan eksekusi yang terpisah dari transfer mata uang native (ETH).
- **Integrasi Core**: Menggunakan `Erc20Service` untuk membungkus fungsi `transfer(address,uint256)` pada smart contract.
- **Handling Presisi**: Mengonversi input desimal pengguna secara akurat ke dalam satuan `BigInt` (misal: 18 desimal) sebelum dikirim ke blockchain.

### D. Antarmuka Pengguna (UI/UX)
- **`ManageTokensScreen`**: Berfungsi sebagai dashboard aset dengan tombol aksi cepat untuk pengiriman.
- **`SendIdrtScreen`**: UI khusus pengiriman token yang terintegrasi dengan pemindai QR dan sistem konfirmasi transaksi.

## 3. Aliran Data (Data Flow)
1. **Load**: Aplikasi memuat `.env` -> `TokenService` memberikan data IDRT.
2. **Sync**: `TokenNotifier` meminta saldo ke Blockchain RPC -> State diperbarui dengan saldo terbaru.
3. **Action**: User menekan "Send" -> `SendIdrtScreen` terbuka -> User input data.
4. **Execute**: `IdrtTransferController` menandatangani transaksi secara offline -> Dikirim ke Blockchain -> User menerima Hash Transaksi.

## 4. Kesimpulan
Implementasi saat ini mengutamakan **keandalan (reliability)** dengan melakukan verifikasi on-chain langsung dan **kemudahan pemeliharaan (maintainability)** melalui penggunaan variabel lingkungan. Fitur dinamis (Discover/GraphQL) telah dinonaktifkan untuk memberikan fokus penuh pada ekosistem IDRT di jaringan privat Besu.
