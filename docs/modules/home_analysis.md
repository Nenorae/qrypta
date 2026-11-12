# Analisis Teknis Fitur Home

## 1. Ikhtisar (Overview)
Fitur Home saat ini berfungsi sebagai dasbor utama aplikasi Qrypta. Namun, berdasarkan analisis kode, sebagian besar data yang ditampilkan masih bersifat statis (hardcoded) dan belum terintegrasi sepenuhnya dengan layanan blockchain sebagai sumber kebenaran (Source of Truth) untuk saldo utama.

## 2. Struktur Komponen
Fitur ini terbagi menjadi beberapa bagian utama:

### A. Presentation Layer
- **`HomeScreen` (`home_screen_backup.dart`)**:
  - Berfungsi sebagai container utama yang mengatur tata letak (AppBar, Body, dan Bottom Navigation Bar).
  - Menggunakan `StatefulWidget` untuk mengelola indeks navigasi internal, meskipun beberapa menu navigasi melakukan `Navigator.push` ke screen baru alih-alih hanya mengganti konten di dalam screen yang sama.
- **`BalanceSection` (`home_body_widgets.dart`)**:
  - Menampilkan total saldo pengguna.
  - **Status**: **STATIS**. Nilai saldo didefinisikan secara langsung dalam kode UI (`RP. 253.456.782,21`).
- **`AssetList` (`home_body_widgets.dart`)**:
  - Menampilkan daftar token/aset yang dimiliki.
  - **Status**: **SEMI-DINAMIS**. Menggunakan `tokenNotifierProvider` (Riverpod) untuk mengambil data aset. Ini adalah bagian yang paling dekat dengan integrasi data nyata, meskipun total saldo di atasnya tidak sinkron dengan akumulasi nilai aset di sini.
- **`ActionButtons` (`action_buttons.dart`)**:
  - Modal bottom sheet untuk aksi cepat seperti Swap, Payment, Send, dan Receive.

### B. Logic Layer
- **`HomeController` (`home_controller.dart`)**:
  - Sebuah `ChangeNotifier` sederhana yang menyimpan `selectedIndex`.
  - **Catatan**: Controller ini nampaknya belum digunakan secara maksimal di `HomeScreen` karena `HomeScreen` masih menggunakan state lokal `_selectedIndex`.

## 3. Analisis Sumber Kebenaran (Source of Truth)

### Apakah sudah menggunakan Service Blockchain untuk Saldo?
**Belum.**

Berdasarkan pengecekan pada `lib/src/features/home/presentation/widgets/home_body_widgets.dart`:
```dart
class BalanceSection extends StatelessWidget {
  const BalanceSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Text(
          'RP. 253.456.782,21', // HARDCODED
          style: TextStyle(...)
        ),
        // ...
      ],
    );
  }
}
```

### Bagaimana cara kerjanya sekarang?
1. **Total Saldo**: Ditampilkan sebagai teks statis. Tidak ada pemanggilan fungsi ke `BlockchainService` atau provider saldo manapun.
2. **Daftar Aset**: Menggunakan `AssetList` yang memantau `tokenNotifierProvider`. Jika provider ini terhubung ke blockchain, maka daftar aset di bawah saldo akan menampilkan data nyata, namun angka "Total Balance" di atas tetap tidak akan berubah karena tidak terhubung ke data tersebut.
3. **Navigasi**: Menggunakan perpaduan antara penggantian index `BottomNavigationBar` dan navigasi eksplisit `Navigator.push`.

## 4. Temuan Teknis & Masalah
1. **Inkonsistensi Data**: Total saldo di bagian atas tidak mencerminkan jumlah dari aset-aset yang ada di daftar bawah.
2. **Redundansi Kode**: Adanya `home_screen_backup.dart` tanpa adanya `home_screen.dart` yang utama menunjukkan kemungkinan refactoring yang belum selesai atau penamaan file yang tidak standar.
3. **Logic Separated**: `HomeController` tidak digunakan oleh UI utama, sehingga state management untuk fitur home belum terpusat.

## 5. Rekomendasi Pengembangan
1. **Integrasi Blockchain**:
   - Buat `BalanceProvider` yang menghitung total saldo berdasarkan data dari `tokenNotifierProvider` atau langsung memanggil saldo native dari `BlockchainService`.
   - Update `BalanceSection` menjadi `ConsumerWidget` agar bisa mendengarkan perubahan saldo dari provider tersebut.
2. **Sinkronisasi Mata Uang**: Mengimplementasikan service untuk konversi nilai crypto ke Rupiah (IDR) secara real-time melalui API price aggregator.
3. **Pembersihan Navigasi**: Pastikan `HomeController` digunakan secara konsisten jika ingin mengelola state navigasi bawah secara global.
4. **Rename File**: Mengubah `home_screen_backup.dart` menjadi `home_screen.dart` untuk menjaga standar penamaan proyek.
