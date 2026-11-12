# Rencana Perombakan Fitur Home (Blockchain Dynamic Dashboard)

## 1. Tujuan
Mengubah fitur Home dari tampilan statis menjadi dasbor dinamis yang menggunakan blockchain sebagai **Source of Truth**. Saldo akan diambil langsung dari alamat wallet pengguna yang tersimpan di Secure Storage.

## 2. Strategi Integrasi Data
Berdasarkan analisis fitur `tokens` dan `transaction`, kita akan memanfaatkan provider yang sudah ada dan membuat provider baru khusus untuk agregasi saldo di Home.

### A. Pengambilan Alamat Wallet
Menggunakan `userWalletAddressProvider` dari `@lib/src/features/transaction/presentation/providers/transaction_providers.dart`. Provider ini sudah menangani pengambilan Private Key dan derivasi Public Key (Alamat).

### B. Saldo Native (ETH/Base Asset)
Membuat `nativeBalanceProvider` (atau serupa) yang memanggil `blockchainService.nativeCurrency.getBalance(address)`.

### C. Saldo Token (GLD)
Memanfaatkan `tokenNotifierProvider` dari `@lib/src/features/tokens/presentation/providers/token_provider.dart`. 
*   **Catatan**: Saat ini `.env` dikonfigurasi untuk GLD (Gold Token), sehingga `tokenNotifierProvider` secara otomatis akan mengambil saldo GLD.

## 3. Komponen Baru & Perubahan Logic

### `home_providers.dart` (Baru)
Buat file ini untuk menyimpan logika agregasi:
1.  **`totalBalanceProvider`**: 
    *   Menggabungkan saldo dari `nativeBalanceProvider` dan `tokenNotifierProvider`.
    *   Melakukan kalkulasi estimasi nilai dalam IDR (sementara menggunakan kurs statis atau mock service).
    *   Output: Objek yang berisi total IDR dan detail saldo tiap aset.

### `home_screen.dart` (Refactor)
1.  **Rename**: Ubah `home_screen_backup.dart` menjadi `home_screen.dart`.
2.  **State Management**: Ganti `StatefulWidget` dengan `ConsumerStatefulWidget` (Riverpod).
3.  **Navigation**: Integrasikan `HomeController` untuk mengelola navigasi bawah agar lebih konsisten dengan arsitektur proyek.

## 4. Pembaruan UI (Presentation)

### `BalanceSection`
*   Ubah menjadi `ConsumerWidget`.
*   Tampilkan loading spinner saat data sedang di-fetch.
*   Hubungkan ke `totalBalanceProvider` untuk menampilkan angka Rupiah yang nyata.

### `AssetList`
*   Tetap menggunakan `tokenNotifierProvider` namun pastikan UI menangani kondisi empty state dengan baik.
*   Tambahkan item "Native Asset" (ETH/Base) di bagian paling atas daftar aset secara eksplisit jika belum ada.

## 5. Langkah-langkah Implementasi
1.  **Pembersihan**: Hapus file `home_screen_backup.dart` (setelah rename) dan pastikan import di `main.dart` atau router diperbarui.
2.  **Provider Setup**: Implementasikan `totalBalanceProvider` di `lib/src/features/home/presentation/providers/home_providers.dart`.
3.  **UI Binding**: Update `home_body_widgets.dart` untuk mengonsumsi provider baru.
4.  **Testing**: Verifikasi dengan alamat wallet yang memiliki saldo GLD on-chain.

## 6. Integrasi dengan Fitur Lain
*   **Transaction**: `ActionButtons` (Send/Receive) sudah terhubung dengan benar ke fitur transaksi.
*   **Tokens**: Fitur `ManageTokensScreen` akan tetap sinkron karena menggunakan provider yang sama (`tokenNotifierProvider`).

---
**Status Saat Ini**: GLD digunakan sebagai token utama dalam `.env`. IDRT akan ditambahkan setelah kontrak tersedia dengan memperbarui `TokenService`.
