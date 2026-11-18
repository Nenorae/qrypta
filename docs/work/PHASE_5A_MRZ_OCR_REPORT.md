# LAPORAN REKAP KERJA: PHASE 5A (MESIN OCR MRZ PASPOR ASLI - GOOGLE ML KIT)
**Proyek:** Qrypta & Bali Tourist ID  
**Master Plan:** `docs/RENCANA_KERJA_ELIMINASI_FALLBACK_PALSU.md` (Phase 5A)  
**Branch:** `fix/real-behavior`  
**Tanggal Eksekusi:** 18 November 2026  
**Status Fase:** ✅ Selesai 100% (Seluruh KPI Terpenuhi Tanpa Fake Pass)

---

## 1. RINGKASAN EKSEKUTIF

Phase 5A menuntaskan eliminasi fallback palsu pada alur pemindaian paspor (onboarding biodata) dengan menggantikan pustaka pemindai barcode `MobileScanner` menjadi **pipeline optik kamera native (`camera: ^0.12.2`) dan Google ML Kit Text Recognition (`google_mlkit_text_recognition: ^1.0.2`)**, serta membangun mesin ekstraksi, koreksi optik berbasis tipe field (`MrzExtractor`), konsensus multi-frame (`MrzFrameConsensus`), dan formulir alternatif input paspor manual tervalidasi ICAO Doc 9303 modulo 10 secara ketat.

### Perbandingan Kondisi Sebelum vs Sesudah Phase 5A:

| Aspek | Kondisi Sebelum Phase 5A (Baseline Audit) | Kondisi Sesudah Phase 5A (Real Behavior) |
| :--- | :--- | :--- |
| **Pustaka Pemindai (F-01)** | Menggunakan `MobileScanner` (pemindai QR/barcode); `google_mlkit_text_recognition` tidak pernah diimpor di `lib/`. | `MobileScanner` dilepas 100% dari pemindai MRZ; menggunakan `CameraController` native + Google ML Kit Vision API Latin Text Recognition. |
| **Pipeline Frame Kamera** | Mengandalkan event barcode capture yang tidak mampu membaca teks optik MRZ paspor fisik. | Frame streaming ter-throttle (~3-4 fps, 250ms), konversi NV21/BGRA ke `InputImage` dengan kompensasi rotasi sensor perangkat yang akurat. |
| **Bypass Demo Onboarding (F-19)** | Tombol "Fast Demo Mode" di welcome screen dan tombol "Demo Passport" di pemindai memanggil `MrzParseResult.demoJamesWilson()` untuk melewati pemindaian optik. | Seluruh tombol bypass demo dihapus dari UI onboarding non-dev; factory demo dipindahkan ke `test/fixtures/`. |
| **Nilai Default Palsu di `MrzParser`** | Jika pembacaan gagal/kosong, parser diam-diam menyuntikkan `'JAMES WILSON'`, `'724918239'`, `'GBR'`, `'12 May 1988'`, dan `'18 Mar 2032'`. | Seluruh nilai default palsu dihapus 100%; parser beroperasi dalam mode `strict` dan melempar `ValidationFailure` bertipe bila data tidak valid atau field wajib kosong. |
| **Koreksi Karakter Optik OCR** | Tidak ada koreksi karakter optik; rentan gagal membaca akibat OCR-B font noise. | `MrzExtractor` menerapkan koreksi berbasis tipe field ICAO TD3 (angka vs huruf vs filler `<`) tanpa toleransi salah-terima (0 false acceptances). |
| **Ketahanan Transient Frame** | Tidak ada konsensus; 1 frame rusak dapat memicu crash atau hasil keliru. | `MrzFrameConsensus` mensyaratkan minimal 2 frame berurutan menghasilkan MRZ identik dalam jendela waktu 2 detik sebelum dinyatakan lolos. |
| **Jalur Alternatif Nyata** | Tidak ada; pengguna terjebak pada kamera yang gagal baca. | Timeout 30 detik memunculkan panduan dan formulir "Input Paspor Manual" tervalidasi check digit ICAO 9303 modulo 10 sebagai jalur nyata (bukan fallback palsu). |
| **Proteksi R8 / ProGuard** | Hanya `-dontwarn` yang menyembunyikan runtime failure di APK rilis. | Menambahkan aturan `-keep` eksplisit untuk Google ML Kit Vision API & Text Recognizer di `android/app/proguard-rules.pro`. |
| **Kepatuhan Privasi (R9)** | Potensi pencatatan log OCR. | Zero PII: frame kamera tidak pernah disimpan ke disk, teks MRZ mentah tidak pernah dicatat ke konsol/log file. Buffer frame dibersihkan seketika. |

---

## 2. DETAIL PERUBAHAN & ELIMINASI TEMUAN

### 2.1 Eliminasi MobileScanner & Integrasi ML Kit Asli (F-01, F-23)
- **File Dimodifikasi:**
  - `pubspec.yaml`
  - `lib/src/features/authentication/presentation/screens/mrz_scanner_screen.dart`
- **Tindakan:**
  - Menambahkan dependensi resmi `camera: ^0.12.2` dan `permission_handler: ^13.0.2` ke `pubspec.yaml`.
  - Melepas impor dan widget `MobileScanner` dari `mrz_scanner_screen.dart`.
  - Menginisialisasi `CameraController` dengan resolusi `ResolutionPreset.high`, format gambar `ImageFormatGroup.nv21` (Android) / `bgra8888` (iOS), dan autofokus aktif.
  - Mengintegrasikan `TextRecognizer(script: TextRecognitionScript.latin)` dari `google_mlkit_text_recognition`.
  - Mengimplementasikan throttle stream frame kamera pada interval 250 ms (~3-4 fps) dengan flag `_isBusy` untuk mencegah overload CPU dan memory leak.
  - Mengonversi `CameraImage` ke `InputImage` dengan kompensasi rotasi sensor (`sensorOrientation`) yang akurat untuk mencegah kegagalan baca orientasi potret Android.
  - Menambahkan toggle tombol senter (`FlashMode.torch` / `FlashMode.off`).

### 2.2 Eliminasi Bypass Demo & Sanitasi Literal Palsu (F-19, Golden Rules R3 & R8)
- **File Dimodifikasi:**
  - `lib/src/features/authentication/presentation/screens/mrz_scanner_screen.dart`
  - `lib/src/core/utils/mrz_parser.dart`
  - `tools/reality_guard.sh`
- **Tindakan:**
  - Menghapus tombol shortcut "Demo Passport" (`_injectDemoPassport`) dari AppBar `mrz_scanner_screen.dart`.
  - Menghapus seluruh nilai default palsu dari `MrzParser.parse`:
    - Menghapus default nama `'JAMES WILSON'` -> diganti string kosong, atau dilempar `ValidationFailure` pada mode `strict`.
    - Menghapus default nomor paspor `'724918239'` dan `'••••••789'`.
    - Menghapus default negara `'GBR'`.
    - Menghapus default tanggal lahir `'12 May 1988'` dan kedaluwarsa `'18 Mar 2032'`.
  - Menambahkan aturan pengecekan CI di `tools/reality_guard.sh`:
    - Check 11: Memverifikasi `MobileScanner` tidak ada di `mrz_scanner_screen.dart`.
    - Check 12: Memverifikasi string literal `'JAMES WILSON'` (huruf besar) tidak ada di seluruh `lib/`.

### 2.3 Implementasi Mesin Ekstraksi & Koreksi Optik Berbasis Tipe Field (`MrzExtractor` - §5A.3)
- **File Dibuat:**
  - `lib/src/core/utils/mrz_extractor.dart`
- **Tindakan:**
  - Membuat class murni `MrzExtractor` yang independen dari widget UI sehingga 100% dapat diuji di level L1.
  - Memfilter kandidat baris TD3 dengan panjang toleransi 42-46 karakter, membersihkan spasi, dan menormalisasi huruf kapital.
  - Mendeteksi Baris 1: diawali `P` diikuti `<` atau jenis paspor, dan kode negara 3 huruf.
  - Mendeteksi Baris 2: baris berikutnya yang berada di bawah Baris 1 (berdasarkan koordinat vertikal `boundingBox.top`) dan memuat digit angka.
  - Menerapkan **koreksi optik berbasis tipe field ICAO TD3**:
    - **Baris 1 (Alfabet & Pengisi):**
      - Koreksi angka ke huruf: `0->O`, `1->I`, `8->B`, `5->S`, `2->Z`.
      - Normalisasi karakter pengisi yang sering salah dibaca OCR: `(`, `)`, `[`, `]`, `{`, `}`, `«`, `‹`, `\`, `/`, `|` -> `<`.
      - Padding/substring tepat 44 karakter.
    - **Baris 2 (Struktur Field Khusus):**
      - Posisi 9 (Check Digit Dokumen): Koreksi huruf ke angka (`O/Q/D->0`, `I/L->1`, `B->8`, `S->5`, `Z->2`, `G->6`).
      - Posisi 10-12 (Kebangsaan): Koreksi angka ke huruf (`0->O`, `1->I`, `8->B`, `5->S`, `2->Z`).
      - Posisi 13-18 (DOB YYMMDD): Koreksi huruf ke angka.
      - Posisi 19 (Check Digit DOB): Koreksi huruf ke angka.
      - Posisi 20 (Jenis Kelamin): Alfabet `M`, `F`, atau `<` (dikonversi ke `X`).
      - Posisi 21-26 (Expiry YYMMDD): Koreksi huruf ke angka.
      - Posisi 27 (Check Digit Expiry): Koreksi huruf ke angka.
      - Posisi 42 (Check Digit Personal): Koreksi huruf ke angka bila bukan pengisi.
      - Posisi 43 (Check Digit Komposit): Koreksi huruf ke angka.
      - Posisi 0-8 (Nomor Dokumen): Jika check digit hampir cocok, menguji pertukaran OCR ambigu (`O<->0`, `I<->1`) dan hanya menerima jika seluruh check digit ICAO 9303 valid.

### 2.4 Implementasi Mesin Konsensus Multi-Frame (`MrzFrameConsensus` - §5A.3 item 6)
- **File Dibuat:**
  - `lib/src/core/utils/mrz_frame_consensus.dart`
- **Tindakan:**
  - Membangun `MrzFrameConsensus` untuk mengeliminasi false acceptance pada pemindaian kamera video real-time.
  - Mensyaratkan minimal 2 frame berturut-turut menghasilkan nomor paspor, tanggal lahir, tanggal kedaluwarsa, dan baris mentah TD3 yang identik dalam jendela waktu 2 detik (`windowDuration`).
  - Jika terjadi glitch atau frame kosong/rusak, counter konsensus seketika di-reset ke 0.
  - Hanya ketika konsensus terpenuhi, alur dilanjutkan ke modal konfirmasi paspor.

### 2.5 Refaktor `MrzParser` & Definisi Integritas Ketat (`MrzParser` - §5A.4)
- **File Dimodifikasi:**
  - `lib/src/core/utils/mrz_parser.dart`
- **Tindakan:**
  - Menambahkan properti getter standar: `documentNumber`, `dob`, `expiry`.
  - Memperketat getter `isValid` pada `MrzParseResult`: selain semua check digit bernilai sah, field wajib (`passportNumber`, `birthDate`, `expiryDate`, `fullName`) **tidak boleh kosong**. Hal ini mencegah string all-filler (`<<<<<<<<<`) dinyatakan sah secara keliru.
  - Menambahkan metode `validateOrThrow()`: melempar `ValidationFailure` bertipe jika dokumen rusak atau check digit gagal.
  - Menambahkan metode `validateNotExpired({DateTime? referenceTime})`: melempar `ValidationFailure` jika paspor telah kedaluwarsa.
  - Memperbaiki inferensi tanggal:
    - Tanggal lahir: jika 2-digit tahun > tahun berjalan, disimpulkan abad 1900, selain itu 2000.
    - Tanggal kedaluwarsa: selalu disimpulkan abad 2000.
  - Mendukung kode negara khusus seperti Jerman (`D` atau `DEU`).

### 2.6 Implementasi Formulir Input Paspor Manual Tervalidasi ICAO 9303 (§5A.3 item 7)
- **File Dimodifikasi:**
  - `lib/src/features/authentication/presentation/screens/mrz_scanner_screen.dart`
- **Tindakan:**
  - Menambahkan timer timeout pemindaian 30 detik. Jika dalam 30 detik pemindaian kamera belum berhasil mencapai konsensus (misal karena lensa kotor, cahaya menyilaukan, atau paspor fisik rusak/lusuh), aplikasi menampilkan kartu bantuan pencahayaan dan tombol "Input Manual".
  - Serta menyediakan tombol alternatif "Ketik data paspor secara manual" di bagian bawah layar.
  - Membuat modal lembar bawah `_ManualPassportInputSheet`:
    - Mengambil input nama keluarga (surname), nama depan (given names), nomor paspor (9 karakter), kode negara ISO 3 huruf, tanggal lahir (YYMMDD), tanggal kedaluwarsa (YYMMDD), dan jenis kelamin (M/F).
    - Membangun 2 baris TD3 dengan check digit ICAO 9303 modulo 10 terhitung nyata (`computeCheckDigit`).
    - Mem-parsing melalui `MrzParser.parse(..., strict: true)`.
    - Ini adalah **jalur nyata alternatif** yang sah menurut standar ICAO 9303, bukan fallback palsu.

### 2.7 Aturan R8 / ProGuard Keep Rules untuk Google ML Kit Vision API (§5A.6)
- **File Dimodifikasi:**
  - `android/app/proguard-rules.pro`
- **Tindakan:**
  - Menambahkan aturan `-keep` untuk mencegah optimizer R8 menghapus kelas ML Kit pada APK rilis:
    ```pro
    # Keep Latin text recognizer and Vision API classes from R8 stripping
    -keep class com.google.mlkit.vision.text.** { *; }
    -keep interface com.google.mlkit.vision.text.** { *; }
    -keep class com.google.android.gms.vision.** { *; }
    ```

---

## 3. HASIL VERIFIKASI PENGUJIAN

### 3.1 Pengujian Unit Phase 5A (Level L1)
- **File Pengujian:** `test/phase5a_mrz_ocr_test.dart`
- **Hasil:** 18/18 pengujian lulus 100% (0 gagal).

| No | Nama Kasus Uji | Level | Hasil | Verifikasi |
| :--- | :--- | :--- | :--- | :--- |
| 1 | ICAO Doc 9303 Utopia specimen validates all check digits accurately | L1 | ✅ LULUS | Modulo-10 doc=6, dob=2, expiry=9, personal=1, composite=0 valid. |
| 2 | MrzParser strictly parses ICAO Utopia specimen with zero fake fallbacks | L1 | ✅ LULUS | Seluruh atribut parsed cocok spesimen ICAO Doc 9303 Part 9 tanpa fallback. |
| 3 | Special country code handling: Germany (D) | L1 | ✅ LULUS | Negara `D` (DEU) di baris 1 dan baris 2 ter-parse akurat. |
| 4 | Century inference: DOB in 1900s vs 2000s and Expiry in 2000s | L1 | ✅ LULUS | DOB 95 -> 1995, Expiry 35 -> 2035 terinferensi akurat. |
| 5 | MrzParser does not inject James Wilson or fake static data when input is empty | L1 | ✅ LULUS | Input kosong menghasilkan string kosong & `isValid == false` (bukan James Wilson). |
| 6 | MrzParser in strict mode throws ValidationFailure on empty or invalid MRZ | L1 | ✅ LULUS | Strict parse melempar `ValidationFailure` bertipe saat data kosong. |
| 7 | Zero false acceptance: Tampered passport check digit is rejected | L1 | ✅ LULUS | Check digit paspor dirusak 6->7 langsung ditolak (`isValid=false`). |
| 8 | Zero false acceptance: Tampered DOB check digit is rejected | L1 | ✅ LULUS | Check digit DOB dirusak 2->5 langsung ditolak (`isValid=false`). |
| 9 | Zero false acceptance: Tampered composite check digit is rejected | L1 | ✅ LULUS | Composite check digit dirusak 0->9 langsung ditolak (`isValid=false`). |
| 10 | Corrects numeric fields misread as letters (O->0, I->1, B->8, S->5, Z->2) | L1 | ✅ LULUS | Field DOB `74O8I2Z` dan Expiry `IZO4IS9` berhasil dikoreksi ke angka sah. |
| 11 | Corrects alphabet fields misread as digits (0->O, 1->I) | L1 | ✅ LULUS | Kebangsaan `UT0` berhasil dikoreksi menjadi `UTO`. |
| 12 | Normalizes corrupted filler characters (parentheses, brackets, guillemets) | L1 | ✅ LULUS | Karakter `(`, `)`, `[`, `«`, `‹` dinormalisasi menjadi `<`. |
| 13 | Extracts MRZ from noisy text containing headers and extraneous lines | L1 | ✅ LULUS | Teks OCR bercampur header, footer, dan noise baris berhasil diekstraksi. |
| 14 | Respects vertical bounding box ordering: Line 2 must be below Line 1 | L1 | ✅ LULUS | Baris diurutkan berdasarkan `boundingBox.top` sebelum parsing pasangan. |
| 15 | Requires 2 consecutive matching frames to confirm consensus | L1 | ✅ LULUS | Frame 1 tidak memicu trigger; Frame 2 identik langsung memicu konsensus. |
| 16 | Glitch or invalid intermediate frame resets consensus counter | L1 | ✅ LULUS | Frame rusak di tengah mereset counter konsensus ke 0. |
| 17 | Expired time window resets consensus | L1 | ✅ LULUS | Frame yang tiba melebihi jendela waktu 2 detik mereset jendela konsensus. |
| 18 | Manual Passport Entry generates 100% valid ICAO 9303 TD3 lines and parses strictly | L1 | ✅ LULUS | Input manual menghasilkan baris TD3 dengan modulo 10 sah dan terverifikasi strict. |

### 3.2 Status Keseluruhan Test Suite Proyek
- **Total Pengujian:** 114 test (96 test eksisting + 18 test baru Phase 5A).
- **Hasil:** 114/114 Passed (100% Lulus, 0 Gagal, 0 Flaky).

---

## 4. AUDIT KEPATUHAN GOLDEN RULES & CI REALITY GUARD

| Aturan | Deskripsi | Status | Pembuktian |
| :--- | :--- | :--- | :--- |
| **R1** | **Tidak ada catch menelan error** | ✅ Patuh | Seluruh blok penanganan stream kamera dan parsing menggunakan exception bertipe `ValidationFailure` atau `on Object catch`. Catch kosong di pemindai dieliminasi. |
| **R2** | **Sukses hanya setelah konfirmasi otoritatif** | ✅ Patuh | Pemindai hanya menyatakan sukses jika konsensus multi-frame (minimal 2 frame berurutan) dan seluruh check digit ICAO 9303 lolos. 0 salah-terima. |
| **R3** | **Tidak ada literal identitas/keuangan palsu** | ✅ Patuh | Literal `'JAMES WILSON'`, `'724918239'`, `'12 May 1988'`, `'18 Mar 2032'`, dan `'GBR'` dihapus dari `mrz_parser.dart`. Grep `JAMES WILSON`: 0 hit. |
| **R8** | **Fitur simulasi in-app tidak ada di rilis/prod** | ✅ Patuh | Tombol shortcut "Demo Passport" dan "Fast Demo Mode" dihapus dari alur produksi. |
| **R9** | **Zero PII di log & disk** | ✅ Patuh | Buffer frame kamera segera dibuang; tidak ada penyimpanan citra paspor ke disk; tidak ada pencatatan string MRZ mentah ke log. |

### Hasil Audit `tools/reality_guard.sh`:
- ✅ `[PASS] [F-01] MobileScanner berhasil dieliminasi dari pemindai MRZ`
- ✅ `[PASS] Tidak ada demoJamesWilson() di lib/`
- ✅ `[PASS] Tidak ada literal 'JAMES WILSON' di lib/`
- ✅ `[PASS] Tidak ada catch (_) {} kosong di lib/`

---

## 5. REKOMENDASI & LANGKAH SELANJUTNYA

Dengan tuntasnya **Phase 5A**, modul pemindaian identitas paspor telah beroperasi secara nyata menggunakan Google ML Kit dan kamera optik native.

Langkah berikutnya sesuai peta kerja:
- **Phase 5B: Penerbitan BTID Otoritatif & Sanitasi Data Identitas (F-08, F-11, F-11b, F-13, F-13b):**
  - Mengintegrasikan hasil `MrzParseResult` dari Phase 5A dengan endpoint backend `POST /credentials/btid`.
  - Mengeliminasi nomor BTID statis `'BTID-2026-4471-0938'` di `btid_credential_model.dart`, `btid_issued_screen.dart`, dan layar profil/home.
  - Mengeliminasi default imigrasi `'e-VOA B1'` dan `'1988-04-12'` dari model data dan UI.
  - Memastikan kartu BTID hanya tampil setelah respon sukses dari backend ezsign-core (Golden Rule R2).
