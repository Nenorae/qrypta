# LAPORAN REKAP KERJA: PHASE 9 (PELABELAN EKSPLISIT SIMULASI LIVENESS WAJAH)
**Proyek:** Qrypta & Bali Tourist ID  
**Master Plan:** `docs/RENCANA_KERJA_ELIMINASI_FALLBACK_PALSU.md` (Phase 9)  
**Baseline Audit:** `docs/AUDIT_TEMUAN_KESALAHAN_DAN_FALLBACK_PALSU.md` (§7, F-18)  
**Branch:** `fix/real-behavior`  
**Tanggal Eksekusi:** 21 November 2026  
**Status Fase:** ✅ Selesai 100% (Seluruh KPI Terpenuhi Tanpa Fake Pass)  
**Status Reality Guard CI:** ✅ Hijau 100% (13/13 Aturan Integritas Lolos)  

---

## 1. RINGKASAN EKSEKUTIF

Phase 9 berfokus pada penegakan **Golden Rule R4** dan penyelesaian temuan **F-18**: *"Liveness wajah dummy skor 98.7% tanpa label simulasi"*. Sesuai ketetapan arsitektur proyek pada Bagian 0.2 `RENCANA_KERJA_ELIMINASI_FALLBACK_PALSU.md`, modul pendeteksi liveness dan pencocokan biometrik wajah (`ScrLiveness`) adalah **satu-satunya modul yang secara resmi diizinkan berstatus DUMMY/SIMULASI** (karena ketiadaan model neural network on-device berlisensi dan SDK Presentation Attack Detection bersertifikasi FIDO/iBeta PAD Level 2 pada repositori turis).

Namun, pada implementasi lama (baseline audit §7):
1. Layar `ScrLiveness` menampilkan ilusi keberhasilan biometrik otentik dengan mengklaim teks: `"Biometric Face Match"`, `"Matching live selfie against biometric face photograph in ePassport chip DG2"`, `"MATCH SCORE: 98.7%"`, dan `"Pass threshold: 85.0% · Genuine biometric match"`.
2. Pada modal rincian keamanan (`TabId`), status diverifikasi sebagai fakta riil: `_buildSecurityRow('Biometric 1:1 Match', 'Score: 98.7% (Threshold: 85.0%)', true)`.
3. Kredensial digital (`BtidCredentialModel`) dan rekaman audit identitas (`AuditTransactionModel`) tidak memiliki metadata yang menyatakan bahwa verifikasi wajah tersebut hanyalah sebuah simulasi (mock), sehingga berpotensi disalahartikan sebagai verifikasi biometrik resmi pemerintah.
4. Tidak ada jaring pengaman CI (Reality Guard) yang mencegah tim developer menuliskan klaim "genuine/verified biometrics" palsu pada kode produksi.

Melalui eksekusi Phase 9, seluruh ilusi dan klaim palsu tersebut telah **dieliminasi dan ditransformasikan menjadi representasi yang 100% transparan dan jujur**:
- Menambahkan lencana visual tetap non-dismissible `SIMULASI / DEMO` pada tampilan liveness `PassportVerificationFlowScreen`.
- Mengganti seluruh narasi teks tahapan agar secara eksplisit menyatakan status pengujian demo/simulasi.
- Mengeliminasi teks `"MATCH SCORE: 98.7%"` dan `"Genuine biometric match"`, menggantikannya dengan label `"Simulasi: lolos"` disertai penjelasan `"Skor simulasi 98.7% (demo) · Biometrik TIDAK diverifikasi"` dan lencana amber `SIMULASI`.
- Menambahkan watermark overlay `SIMULASI` pada circular viewfinder kamera.
- Menstandarisasi konfigurasi `LIVENESS_MODE=simulated` pada `AppConfig` dengan hook setter pengujian untuk forward-compatibility apabila SDK biometrik riil diintegrasikan di masa mendatang.
- Memperbarui model DTO kredensial (`BtidCredentialModel`) dan audit (`AuditTransactionModel`) dengan struktur payload otoritatif: `liveness: {mode: "SIMULATED", verified: false}`.
- Menerapkan proteksi anti-tamper (*anti-fake pass coercion*) pada deserialisasi JSON model: jika mode bernilai `'SIMULATED'`, field `verified` dipaksa bernilai `false` tanpa kompromi, bahkan bila ada injeksi payload eksternal yang mengaku `verified: true`.
- Memperbarui antarmuka `TabId` dan `BtidCardWidget` agar secara jujur menampilkan `Liveness: SIMULATED` dan tidak pernah mengklaim "Biometric verified" sebagai fakta.
- Menambahkan Check 13 pada `tools/reality_guard.sh` untuk memblokir build release/staging jika ditemukan klaim biometrik palsu (`genuine biometric` atau `biometric verified`).
- Menambahkan suite pengujian komprehensif L1/L4 (`test/phase9_liveness_simulation_test.dart`) sebanyak 10 pengujian baru, membawa total pengujian aktif proyek menjadi **205/205 lulus 100%**.

---

## 2. TABEL PERBANDINGAN KONDISI: SEBELUM VS SESUDAH PHASE 9

| Dimensi Evaluasi | Kondisi Sebelum Phase 9 (Baseline Audit) | Kondisi Sesudah Phase 9 (Real & Honest Behavior) | Status KPI |
| :--- | :--- | :--- | :--- |
| **Lencana UI Liveness (Phase 9.1)** | Tidak ada label simulasi sama sekali. Tampil seolah-olah kamera melakukan pemindaian AI asli. | Lencana permanen `SIMULASI / DEMO` terpasang di posisi teratas dan watermark `SIMULASI` pada viewfinder melingkar. | ✅ LULUS |
| **Teks Judul & Tahapan (Phase 9.1)** | Menampilkan `"Biometric Face Match"` dan klaim pencocokan chip DG2 paspor palsu. | Menampilkan `"Facial Liveness (Simulasi)"`, label step `"Liveness (Demo)"`, dan tahapan eksplisit simulasi. | ✅ LULUS |
| **Penyajian Skor 98.7% (Phase 9.4)** | Ditampilkan sebagai metrik asli: `"MATCH SCORE: 98.7%"` & `"Genuine biometric match"`. | Dieliminasi. Diganti `"Simulasi: lolos"`, subtitle disclaimer mock, dan pill status `"SIMULASI"`. | ✅ LULUS |
| **Konfigurasi Mode (Phase 9.2)** | Belum ada titik masuk terpadu untuk pengalihan mode liveness ke implementasi nyata. | `AppConfig.effectiveLivenessMode` & setter pengujian `@visibleForTesting` aktif dengan default `"simulated"`. | ✅ LULUS |
| **Model Kredensial BTID (Phase 9.3)** | Tidak memuat metadata liveness; rentan dianggap terverifikasi biometrik. | `BtidCredentialModel` memuat `liveness: {mode: "SIMULATED", verified: false}` & getter `isBiometricVerified == false`. | ✅ LULUS |
| **Anti-Fake Pass Deserialisasi (Phase 9.3)** | Deserialisasi pasif menerima data apa pun dari JSON mentah. | `BtidCredentialModel.fromJson` memaksa `verified = false` jika mode adalah `'SIMULATED'` (kebal payload injeksi). | ✅ LULUS |
| **Model Audit Transaksi (Phase 9.3)** | `AuditTransactionModel` tidak mencatat mode liveness pada penerbitan BTID. | `AuditTransactionModel` memuat field `liveness` yang diserialisasikan ke JSON audit dan ezsign-core middleware. | ✅ LULUS |
| **Layanan Penerbitan (Phase 9.3)** | `BtidIssuanceService` mengirimkan string mentah `'livenessMode': 'SIMULATED'`. | Mengirimkan objek terstruktur `liveness: {mode: 'SIMULATED', verified: false}` ke endpoint `/credentials/btid`. | ✅ LULUS |
| **Audit Kredensial Server (Phase 9.3)** | `recordCredentialIssuedAudit` tidak mencantumkan metadata liveness. | Metadata `recordCredentialIssuedAudit` memuat objek liveness transparan ke ezsign-core Fastify. | ✅ LULUS |
| **Tampilan Tab ID & Detail PKI (Phase 9.3)** | Menampilkan `"Biometric 1:1 Match"` dengan checkmark hijau sukses dan skor 98.7%. | Menampilkan `"Facial Liveness"` dengan teks `"Simulasi: lolos (mode: SIMULATED)"` berikon science amber (`isSuccess: false`). | ✅ LULUS |
| **Kartu Digital BTID (Phase 9.3)** | Hanya menampilkan `Identity Verified` dan `Passport Authenticated`. | Menambahkan pill ketiga `Liveness: SIMULATED` berwarna amber bersanding dengan identitas paspor. | ✅ LULUS |
| **Proteksi CI Reality Guard (Phase 9.5)** | CI tidak memeriksa klaim biometrik palsu di antarmuka atau logika aplikasi. | Menambahkan Check 13 pada `reality_guard.sh`: mendeteksi & menolak teks `genuine biometric` / `biometric verified`. | ✅ LULUS |
| **Cakupan Pengujian Terotomatisasi (Phase 9.5)** | Nol pengujian untuk pelabelan liveness dan integritas metadata simulasi. | Dibuat 10 pengujian komprehensif di `test/phase9_liveness_simulation_test.dart` (Unit L1, API Mock L2, dan Widget L1/L4). | ✅ LULUS |

---

## 3. RINCIAN IMPLEMENTASI TEKNIS PER ITEM

### 3.1 Pelabelan Eksplisit UI `ScrLiveness` (Phase 9.1 & Golden Rule R4)
File: `lib/src/features/authentication/presentation/screens/passport_verification_flow_screen.dart`

1. **Lencana Permanen `SIMULASI / DEMO`:**
   Ditempatkan di bagian atas antarmuka `_buildLivenessView()` dengan `key: const Key('liveness_simulation_badge')`, berlatar belakang amber transparan (`Color(0xFFF59E0B)` dengan alpha 0.15) dan border amber solid 1.5px. Lencana ini bersifat non-dismissible dan berada di luar jangkauan gestur pengguna sehingga tidak dapat disembunyikan.
2. **Watermark Viewfinder Kamera:**
   Pada circular frame tempat wajah wisatawan diproyeksikan, disematkan floating badge permanen bertuliskan `SIMULASI` di bagian bawah lingkaran viewfinder. Dengan demikian, tangkapan layar atau rekaman video apa pun atas layar ini akan secara visual memperlihatkan status simulasi secara gamblang.
3. **Penyelarasan Teks Stepper & Judul Halaman:**
   - Judul App Bar diubah dari `'Biometric Face Match'` menjadi `'Facial Liveness (Simulasi)'`.
   - Label pada Step Indicator (Step 3) diubah dari `'Liveness'` menjadi `'Liveness (Demo)'`.
   - Tombol pada tahap sebelumnya (PKI Auth) diubah dari `'Continue to face check'` menjadi `'Continue to face check (Simulated)'`.
4. **Transformasi Tahapan Animasi (`_livenessStages`):**
   Kalimat tahapan yang sebelumnya memalsukan pemrosesan AI diubah menjadi kalimat yang jujur:
   - `Posisikan wajah di dalam frame (Preview Simulasi)`
   - `Simulasi deteksi sudut dan pencahayaan wajah...`
   - `Simulasi pengujian anti-spoofing liveness...`
   - `Simulasi perbandingan foto terhadap paspor DG2...`
   - `Simulasi: lolos (Biometrik TIDAK diverifikasi secara nyata)`
5. **Scrolling Aman Bebas Overflow:**
   Seluruh kolom `_buildLivenessView()` dibungkus dalam `SingleChildScrollView` dan menggantikan `Spacer()` kaku dengan `SizedBox(height: 16-20)`, menjamin layout tidak pernah mengalami overflow pada layar beresolusi rendah atau perangkat dengan font scaling aktif.

### 3.2 Konfigurasi Terpusat `LIVENESS_MODE` (Phase 9.2)
File: `lib/src/core/config/app_config.dart`

1. Mempertahankan pembacaan compile-time environment define:
   ```dart
   static const String livenessMode = String.fromEnvironment(
     'LIVENESS_MODE',
     defaultValue: 'simulated',
   );
   ```
2. Menambahkan variabel override pengujian `@visibleForTesting` dan getter `effectiveLivenessMode`:
   ```dart
   static String? _testLivenessMode;
   static String get effectiveLivenessMode => _testLivenessMode ?? livenessMode;
   static bool get isSimulatedLiveness => effectiveLivenessMode == 'simulated';
   ```
3. Mengintegrasikan pembersihan `_testLivenessMode = null` pada `AppConfig.resetTestOverrides()`.
4. Menyediakan titik masuk forward-compatibility yang bersih: apabila modul AI liveness nyata diintegrasikan di kemudian hari, konfigurasi cukup dialihkan menjadi `LIVENESS_MODE=real` tanpa merusak kompatibilitas sistem.

### 3.3 Struktur Data Kredensial & Audit Berlabel Simulasi (Phase 9.3)
File: `lib/src/core/data/models/btid_credential_model.dart` & `lib/src/core/data/models/audit_transaction_model.dart`

1. **Model Kredensial BTID (`BtidCredentialModel`):**
   - Menambahkan field wajib:
     ```dart
     final Map<String, dynamic> liveness;
     ```
   - Nilai default konstruktor:
     ```dart
     this.liveness = const {
       'mode': 'SIMULATED',
       'verified': false,
     },
     ```
   - Menambahkan helper getter:
     ```dart
     bool get isBiometricVerified => liveness['verified'] == true;
     String get livenessMode => liveness['mode']?.toString() ?? 'SIMULATED';
     ```
2. **Proteksi Anti-Fake Pass pada Deserialisasi JSON:**
   Pada method `BtidCredentialModel.fromJson`:
   ```dart
   final livenessRaw = json['liveness'];
   Map<String, dynamic> parsedLiveness;
   if (livenessRaw is Map) {
     parsedLiveness = Map<String, dynamic>.from(livenessRaw);
     // Golden Rule R4 & Phase 9.3: Mode SIMULATED tidak pernah memiliki verified = true
     if (parsedLiveness['mode']?.toString().toUpperCase() == 'SIMULATED') {
       parsedLiveness['verified'] = false;
     }
   } else {
     parsedLiveness = {
       'mode': (json['livenessMode'] as String? ?? AppConfig.effectiveLivenessMode).toUpperCase(),
       'verified': false,
     };
   }
   ```
   *Keamanan Arsitektur:* Jika backend nakal atau penyerang lokal mencoba mengubah database/cache lokal untuk menyuntikkan `liveness: {mode: "SIMULATED", verified: true}`, parser aplikasi secara deterministik menolak klaim tersebut dan memaksanya kembali menjadi `verified: false`.
3. **Model Audit Transaksi (`AuditTransactionModel`):**
   - Menambahkan field `final Map<String, dynamic>? liveness`.
   - Mengintegrasikan serialisasi dan deserialisasi pada `toJson()` dan `fromJson()`.

### 3.4 Eliminasi Skor Palsu 98.7% & Representasi Hasil Transparan (Phase 9.4)
File: `lib/src/features/authentication/presentation/screens/passport_verification_flow_screen.dart`

Ketika sekuens timer liveness selesai (`_livenessComplete == true`), kartu hasil yang sebelumnya bertuliskan:
```dart
// KONDISI LAMA (PALSU & MENYESATKAN):
Text('MATCH SCORE: 98.7%')
Text('Pass threshold: 85.0% · Genuine biometric match')
Text('PASSED') // Badge hijau sukses
```
Telah digantikan sepenuhnya dengan:
```dart
// KONDISI BARU (JUJUR & MEMATUHI R4):
Container(
  padding: const EdgeInsets.all(14),
  decoration: BoxDecoration(
    color: const Color(0xFF1E1A0F),
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: const Color(0xFFF59E0B), width: 1.2),
  ),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Simulasi: lolos',
              style: TextStyle(
                color: Color(0xFFF59E0B),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Skor simulasi 98.7% (demo) · Biometrik TIDAK diverifikasi',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF59E0B),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'SIMULASI',
          style: TextStyle(
            color: Color(0xFF080D1A),
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    ],
  ),
)
```

### 3.5 Sanitasi Seluruh Konsumen Tampilan BTID (Phase 9.3)
1. **Layar Tab ID (`lib/src/features/home/presentation/tabs/tab_id.dart`):**
   - Pada modal bottom sheet detail keamanan (`_showSecurityDetails`), baris `'Biometric 1:1 Match'` digantikan menjadi:
     ```dart
     _buildSecurityRow(
       'Facial Liveness',
       'Simulasi: lolos (mode: SIMULATED)',
       false,
       statusColor: const Color(0xFFF59E0B),
       customIcon: Icons.science_outlined,
     ),
     ```
   - Parameter `isSuccess: false` memastikan tidak ada checkmark hijau verifikasi palsu.
   - Mengaktifkan `isScrollControlled: true` dan membungkus modal dalam `SingleChildScrollView` untuk menjamin tampilan tidak mengalami overflow pada perangkat kecil.
2. **Visual Kartu BTID (`lib/src/features/verification/presentation/widgets/btid_card_widget.dart`):**
   - Menambahkan pill status ketiga pada bagian lencana kartu:
     ```dart
     _buildPill(
       icon: Icons.science_outlined,
       label: 'Liveness: SIMULATED',
       color: const Color(0xFFF59E0B),
     ),
     ```
   - Tidak pernah menampilkan teks "Biometric Verified" pada kartu resmi Bali Tourist ID.

### 3.6 Penegakan Reality Guard CI (Check 13 / Phase 9.5)
File: `tools/reality_guard.sh`

Menambahkan aturan pemeriksaan statis Check 13 pada skrip CI:
```bash
# 13. [F-18/R4] Larangan klaim biometrik asli: tidak boleh ada klaim biometrik verified/genuine tanpa simulasi di lib/
if grep -rEni "genuine biometric|biometric verified" lib/ 2>/dev/null; then
  echo "❌ [FAIL] [F-18] Klaim biometrik terverifikasi/asli ditemukan di lib/ (liveness wajib berlabel SIMULASI)"
  FAILURES=$((FAILURES + 1))
else
  echo "✅ [PASS] [F-18] Bebas dari klaim biometrik palsu di lib/"
fi
```
Hasil eksekusi `bash tools/reality_guard.sh`:
```
🔍 [REALITY GUARD] Memulai audit integritas kode...
✅ [PASS] Tidak ada literal palsu dasar di lib/
✅ [PASS] Tidak ada pemalsuan txHash via keccak256 di lib/
✅ [PASS] Tidak ada catch kosong / hanya log di lib/
✅ [PASS] Tidak ada loopback di konfigurasi env non-dev
✅ [PASS] Tidak ada demoJamesWilson() di lib/
✅ [PASS] Tidak ada tombol demo/simulasi tanpa guard di lib/
✅ [PASS] Tidak ada loopback hardcoded di config Dart
✅ [PASS] Tidak ada string-match merchant primitif di features/
✅ [PASS] Tidak ada catch (_) {} kosong di lib/
✅ [PASS] Tidak ada hardcoded visaType di lib/
✅ [PASS] [F-01] MobileScanner berhasil dieliminasi dari pemindai MRZ
✅ [PASS] Tidak ada literal 'JAMES WILSON' di lib/
✅ [PASS] [F-18] Bebas dari klaim biometrik palsu di lib/
==================================================================
🎉 [REALITY GUARD HIJAU] Seluruh kode mematuhi Golden Rules integritas.
```

---

## 4. PROGRAM PENGUJIAN PHASE 9 & HASIL VERIFIKASI

Suite pengujian terdedikasi `test/phase9_liveness_simulation_test.dart` mencakup 10 kasus uji pada level L1 (unit), L2 (integrasi layanan mock), dan L4 (widget antarmuka pengguna):

| ID Uji | Level | Deskripsi Skenario Uji | Hasil Eksekusi |
| :--- | :--- | :--- | :--- |
| **TEST-01** | L1 | `AppConfig.livenessMode` default bernilai `'simulated'` dan `isSimulatedLiveness` bernilai `true` | ✅ LULUS |
| **TEST-02** | L1 | Test override `AppConfig.setTestOverrides(livenessMode: 'real')` berfungsi dan reset akurat | ✅ LULUS |
| **TEST-03** | L1 | `BtidCredentialModel` default menginisialisasi `liveness: {mode: 'SIMULATED', verified: false}` | ✅ LULUS |
| **TEST-04** | L1 | **Anti-Fake Pass Test:** Injeksi JSON `{mode: 'SIMULATED', verified: true}` dipaksa menjadi `verified: false` | ✅ LULUS |
| **TEST-05** | L1 | `AuditTransactionModel` melakukan serialisasi & deserialisasi metadata liveness secara presisi | ✅ LULUS |
| **TEST-06** | L1/L2 | `BtidIssuanceService` mengirimkan payload `liveness: {mode: 'SIMULATED', verified: false}` ke backend | ✅ LULUS |
| **TEST-07** | L1/L2 | `VerificationTransactionService` mencatat audit penerbitan dengan objek liveness berstatus simulated | ✅ LULUS |
| **TEST-08** | L1/L4 | Widget `PassportVerificationFlowScreen` merender lencana `SIMULASI / DEMO`, watermark, dan hasil `'Simulasi: lolos'` | ✅ LULUS |
| **TEST-09** | L1/L4 | Widget `TabId` modal Security Details menampilkan `'Facial Liveness: Simulasi: lolos (mode: SIMULATED)'` | ✅ LULUS |
| **TEST-10** | L1/L4 | Widget `BtidCardWidget` menampilkan lencana amber `Liveness: SIMULATED` tanpa teks "Biometric Verified" | ✅ LULUS |

### Perbaikan Regresi Lintas Fase
Dalam pengujian integrasi global, ditemukan timeout 30 detik pada `test/phase7_merchant_handshake_test.dart`. Masalah ini berhasil didiagnosis secara presisi: konstruktor `RealtimeChannelService` di dalam group pengujian tidak dipasok dengan instance `MockClient`, sehingga memicu pemanggilan HTTP nyata yang menggantung pada sinkronisasi request tertunda. Dengan menginjeksikan `httpClient: mockHttpClient`, pengujian Phase 7 kini lulus 100% secara instan.

**Hasil Eksekusi Keseluruhan Test Suite Proyek:**
```
00:06 +205: All tests passed!
```
Total pengujian aktif proyek meningkat dari 195 menjadi **205 tests**, seluruhnya berstatus **HIJAU (0 failed, 0 skipped, 0 fake pass)**.

---

## 5. EVALUASI REALITY GATE & CHECKLIST GOLDEN RULES

| Kriteria Reality Gate / Golden Rule | Syarat Pemenuhan | Status Evaluasi | Bukti Verifikasi |
| :--- | :--- | :--- | :--- |
| **R4 (Dummy Wajah Berlabel Eksplisit)** | Liveness wajah wajib berlabel "SIMULASI/DEMO", tidak boleh dihitung sebagai biometrik sungguhan | **✅ TERPENUHI** | Lencana tetap di UI, watermark di viewfinder, dan field `isBiometricVerified == false`. |
| **R3 (Bebas Literal Palsu)** | Tidak ada teks palsu "genuine biometric" atau "biometric match" tanpa disclaimer | **✅ TERPENUHI** | Seluruh klaim asli dieliminasi, Check 13 Reality Guard lolos hijau. |
| **R7 (Pemisahan Status Otoritatif)** | Mode simulasi tidak boleh mengaku terverifikasi otoritatif | **✅ TERPENUHI** | `liveness['verified']` dipaksa `false` pada level deserialisasi DTO model. |
| **R1 (Zero Silent Catch)** | Tidak ada error catch yang ditelan senyap | **✅ TERPENUHI** | Semua pemanggilan liveness dan model terstruktur tanpa silent catch. |
| **R6 (Pembedaan Level Pengujian)** | Pengujian wajib melaporkan level (L1/L2/L4) | **✅ TERPENUHI** | Test suite terbagi jelas menjadi unit L1, integrasi service L2, dan rendering widget L4. |

---

## 6. KETERBATASAN & CATATAN PENGUJIAN FISIK

1. **Alasan Modul Tetap Dummy:**
   Sesuai kesepakatan produk dan Bagian 0.2 `RENCANA_KERJA_ELIMINASI_FALLBACK_PALSU.md`, modul deteksi wajah sengaja dibiarkan beroperasi sebagai simulasi (viewfinder kamera melingkar + timer sekuensial) karena ketiadaan neural network on-device berlisensi komersial (seperti FaceTec atau Regula Face SDK).
2. **Keterbatasan Pengujian Visual L4:**
   Pengujian visual telah diverifikasi pada level headless widget testing (`testWidgets`). Pengujian visual pada layar ponsel fisik nyata (L4) direkomendasikan untuk dijalankan pada tahap QA lapangan Phase 10 guna memastikan kontras warna lencana amber (`#F59E0B`) terbaca jelas di bawah terik sinar matahari luar ruangan.

---

## 7. KESIMPULAN & LANGKAH SELANJUTNYA

Phase 9 telah **selesai 100% secara paripurna**. Modul liveness wajah telah diubah dari prototipe yang menipu pengguna menjadi sistem yang sepenuhnya jujur, transparan, dan patuh terhadap standar audit identitas digital.

Dengan tuntasnya Phase 0, 1, 2, 3, 4, 5A, 5B, 6, 7, 8, dan 9, seluruh komponen fungsional aplikasi kini telah beroperasi sesuai kondisi nyata. Proyek sekarang siap melangkah ke fase penutup:
👉 **Phase 10: Pengujian Lapangan Lintas Level (L1–L4), Eksekusi Reality Gate Final & Pembaruan Dokumentasi**.
