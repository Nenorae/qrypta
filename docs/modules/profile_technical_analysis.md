# Analisa Teknis: Fitur Profile & Settings Qrypta

Dokumen ini mendeskripsikan implementasi teknis dari modul `lib/src/features/profile`, yang mencakup manajemen akun, pengaturan keamanan, dan integrasi sistem autentikasi untuk perlindungan data sensitif.

## 1. Arsitektur Komponen
Modul ini menggunakan pendekatan **Modular Grouping** pada lapisan presentasi untuk memastikan skalabilitas UI:

*   **SecurityGroup**: Menangani fungsi kritis seperti pengungkapan kunci rahasia dan durasi penguncian otomatis.
*   **AccountManagementGroup**: Abstraksi untuk operasi multi-akun (HD Wallet derivation).
*   **NetworkGroup**: Manajemen RPC Endpoint dan konfigurasi blockchain.
*   **GeneralGroup**: Informasi aplikasi dan bantuan.

## 2. Manajemen State & Persistensi

### A. Security Settings (Non-Sensitif)
Pengaturan seperti *Auto-Lock Duration* dikelola menggunakan `StateNotifier` dan disimpan secara permanen menggunakan `SharedPreferences`.

*   **Provider**: `securitySettingsProvider` (`StateNotifierProvider`).
*   **Persistensi**: Menggunakan key `autoLockDuration`.
*   **Enum-based Logic**: Menggunakan enum `AutoLockDuration` untuk memetakan indeks storage ke logika durasi aplikasi (Immediate, 1m, 5m, dsb).
*   **State**: `SecuritySettingsState` yang bersifat immutable, mengandung status loading, data durasi, dan error handling.

### B. Wallet Secrets (Sensitif)
Akses ke data rahasia (*Mnemonic* & *Private Key*) tidak disimpan di dalam state profil secara permanen, melainkan ditarik secara reaktif dari lapisan autentikasi.

*   **Data Source**: `walletSecretsProvider` (terletak di modul autentikasi).
*   **Mechanism**: Mengambil data dari `FlutterSecureStorage` hanya saat dibutuhkan (Lazy Loading).

## 3. Protokol Keamanan Pengungkapan Rahasia (Secret Reveal)
Qrypta menerapkan **Multi-factor Challenge** internal sebelum menampilkan data sensitif:

1.  **Trigger**: User menekan "Show Recovery Phrase" atau "Show Private Key".
2.  **Authentication Challenge**: Memanggil `AuthenticationService.authenticate()`.
    *   Fungsi ini memicu dialog sistem (Biometrik atau PIN Perangkat).
    *   Hanya jika fungsi mengembalikan `true`, alur dilanjutkan.
3.  **Context Validation**: Menggunakan pengecekan `context.mounted` sebelum navigasi untuk mencegah *memory leaks* atau *crash* pada operasi asinkron.
4.  **Navigation**: Mengarahkan ke `RevealSecretScreen` dengan membawa data rahasia yang telah didekripsi.

## 4. Implementasi RevealSecretScreen
Layar ini dirancang untuk keamanan dan kejelasan visual:

*   **SecretType**: Enum untuk membedakan perlakuan UI:
    *   `mnemonic`: Ditampilkan dalam bentuk `GridView` dengan indeks (BIP39 standard).
    *   `privateKey`: Ditampilkan dalam `SelectableText` dengan font **monospace** untuk menghindari ambiguitas karakter (misal: `1` vs `l`, `0` vs `O`).
*   **Obfuscation Strategy**: Menggunakan `primary.withOpacity(0.4)` pada container untuk menjaga kontras teks namun tetap mengikuti tema gelap aplikasi.
*   **Clipboard Integration**: Menggunakan `Clipboard.setData` untuk menyalin data ke *system tray* dengan notifikasi SnackBar.

## 5. Alur Data Security Settings (Sequence)
1.  `SecuritySettingsNotifier` diinisialisasi.
2.  `_loadDuration()` memanggil `SharedPreferences.getInstance()`.
3.  Data diambil berdasarkan string key `autoLockDuration`.
4.  State diperbarui -> UI `SecurityGroup` melakukan *re-build* reaktif.
5.  `updateDuration()` dipanggil user -> Storage diperbarui -> State diperbarui.

## 6. Penanganan Error
*   **State Handling**: Jika terjadi kegagalan akses storage, state akan menyimpan pesan error yang dapat ditampilkan di UI.
*   **Logging**: Menggunakan `dart:developer` dengan namespace `SecurityGroup` untuk melacak kegagalan pengambilan data rahasia dari storage.

---
*Dokumen ini dibuat otomatis sebagai bagian dari dokumentasi teknis Qrypta.*
