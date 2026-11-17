# Log Perbaikan Build APK Release (Qrypta)

## Ringkasan Build
- **Target**: APK Release Android
- **Output**: `build/app/outputs/flutter-apk/app-release.apk`
- **Status**: Berhasil dikompilasi (105.4 MB)

---

## Daftar Error & Masalah yang Diatasi

### 1. R8 Minification Failure pada ML Kit Text Recognition
- **Gejala Error**:
  ```text
  ERROR: Missing classes detected while running R8.
  ERROR: R8: Missing class com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions$Builder
  Missing class com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
  Missing class com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions$Builder
  Missing class com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
  Missing class com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions$Builder
  Missing class com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
  Missing class com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions$Builder
  Missing class com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions

  FAILURE: Build failed with an exception.
  * What went wrong:
  Execution failed for task ':app:minifyReleaseWithR8'.
  > Compilation failed to complete
  ```
- **Akar Masalah**:
  Package `google_mlkit_text_recognition` memuat kode Java/Kotlin yang merujuk ke opsi pengenal teks bahasa non-Latin (Chinese, Devanagari, Japanese, Korean). Karena dependensi Google Play Services ML Kit untuk bahasa-bahasa tersebut bersifat opsional dan tidak dimasukkan ke dalam `build.gradle`, R8 (compiler ProGuard Android) mendeteksi class-class tersebut hilang dan secara default membatalkan proses minifikasi release.
- **Tindakan Perbaikan**:
  1. Membuat file aturan ProGuard `android/app/proguard-rules.pro`:
     ```proguard
     -dontwarn com.google.mlkit.vision.text.**
     -dontwarn com.google.mlkit.vision.text.chinese.**
     -dontwarn com.google.mlkit.vision.text.devanagari.**
     -dontwarn com.google.mlkit.vision.text.japanese.**
     -dontwarn com.google.mlkit.vision.text.korean.**
     ```
  2. Mendaftarkan aturan ProGuard ke blok `buildTypes.release` di `android/app/build.gradle.kts`:
     ```kotlin
     buildTypes {
         release {
             signingConfig = signingConfigs.getByName("debug")
             proguardFiles(
                 getDefaultProguardFile("proguard-android-optimize.txt"),
                 "proguard-rules.pro"
             )
         }
     }
     ```
- **Alasan**:
  Menginstruksikan R8 untuk mengabaikan peringatan (*dontwarn*) pada paket opsi bahasa yang tidak disertakan, sehingga proses tree-shaking dan minifikasi R8 dapat diselesaikan tanpa merusak fungsionalitas pengenalan teks Latin standar.

---

### 2. Penyesuaian Pendukung Release Sebelumnya
- **Internet Permission (`android/app/src/main/AndroidManifest.xml`)**:
  - Penambahan `<uses-permission android:name="android.permission.INTERNET"/>` pada manifest utama agar HTTP/GraphQL request dapat berjalan pada build release (secara default debug manifest menyediakannya, tetapi release manifest tidak jika tidak dideklarasikan).
- **AAPT Packaging (`android/app/build.gradle.kts`)**:
  - Penambahan `aaptOptions { noCompress("env") }` untuk memastikan file `.env` aset tidak rusak/terkompresi secara keliru saat dikemas ke dalam APK.
- **Error Boundary Inisialisasi (`lib/main.dart`)**:
  - Membungkus inisialisasi `.env` dan Hive dengan blok `try-catch` serta menyediakan fallback UI jika terjadi kegagalan inisialisasi awal.

---

## Catatan Produksi (Technical Debt & Warning)
1. **Signing Config**:
   APK release saat ini menggunakan signing key debug (`signingConfig = signingConfigs.getByName("debug")`). Untuk distribusi ke Google Play Store atau produksi publik, wajib membuat keystore resmi (`.jks` / `.keystore`) dan mengonfigurasi credentials signing di `android/key.properties`.
2. **Kotlin Gradle Plugin (KGP) Warning**:
   Plugin `mobile_scanner`, `share_plus`, dan `shared_preferences_android` masih mengaplikasikan KGP versi lama dan perlu dipantau saat pembaruan Flutter di masa depan.
