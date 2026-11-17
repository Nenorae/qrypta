# AUDIT TEKNIS LENGKAP: TEMUAN KESALAHAN, BLUNDER ARSITEKTUR, DAN FALLBACK PALSU

Dokumen ini membedah secara brutal dan faktual seluruh kesalahan implementasi, ilusi pengujian, serta mekanisme *fallback* palsu yang ditemukan pada kode sumber aplikasi **Qrypta & Bali Tourist ID**.

---

## DAFTAR ISI
1. [Blunder Fatal: Mesin Scan OCR Paspor Tidak Berfungsi](#1-blunder-fatal-mesin-scan-ocr-paspor-tidak-berfungsi)
2. [Jebakan Jaringan: Konfigurasi Localhost (127.0.0.1) di APK Release](#2-jebakan-jaringan-konfigurasi-localhost-127001-di-apk-release)
3. [Katalog Fallback Palsu & Silent Catch (Ilusi Berjalan Sukses)](#3-katalog-fallback-palsu--silent-catch-ilusi-berjalan-sukses)
   - [A. Transaksi Finansial (Tourist Levy & QRIS)](#a-transaksi-finansial-tourist-levy--qris)
   - [B. Audit Persetujuan Data (Consent & Revocation)](#b-audit-persetujuan-data-consent--revocation)
   - [C. Penerbitan Kredensial BTID](#c-penerbitan-kredensial-btid)
   - [D. Saldo Dompet & Preview Kuitansi](#d-saldo-dompet--preview-kuitansi)
4. [Hardcoded Data & Entitas James Wilson yang Menempel Permanen](#4-hardcoded-data--entitas-james-wilson-yang-menempel-permanen)
5. [Discrepansi Fiktif Antara Dokumentasi vs Kode](#5-discrepansi-fiktif-antara-dokumentasi-vs-kode)
   - [A. Parser QRIS EMVCo TLV & Validasi CRC](#a-parser-qris-emvco-tlv--validasi-crc)
   - [B. Saluran Komunikasi Dua Arah Merchant Handshake](#b-saluran-komunikasi-dua-arah-merchant-handshake)
6. [Bongkar Ilusi Test Suite (Mengapa 43/43 Tests Passed Menipu)](#6-bongkar-ilusi-test-suite-mengapa-4343-tests-passed-menipu)
7. [Status Modul Biometrik & NFC (Sesuai Ketetapan)](#7-status-modul-biometrik--nfc-sesuai-ketetapan)
8. [Rencana Aksi Korektif & Prioritas Perbaikan](#8-rencana-aksi-korektif--prioritas-perbaikan)

---

## 1. Blunder Fatal: Mesin Scan OCR Paspor Tidak Berfungsi

### Gejala di HP Fisik
Ketika pengguna mengarahkan kamera ke halaman biodata paspor fisik (pada pita kode 2 baris MRZ TD3), aplikasi **tidak mendeteksi apapun** dan pemindai macet tanpa respons.

### Akar Masalah Teknis
Di dalam [mrz_scanner_screen.dart](file:///home/ganendra/qrypta/lib/src/features/authentication/presentation/screens/mrz_scanner_screen.dart#L293-L298):
```dart
// Lokasi: lib/src/features/authentication/presentation/screens/mrz_scanner_screen.dart (Baris 293-298)
if (_scannerController != null)
  MobileScanner(
    controller: _scannerController!,
    onDetect: _onBarcodesDetected,
  )
```

1. **`MobileScanner` Bukan Mesin OCR Teks:**
   * Widget `MobileScanner` dari pustaka `package:mobile_scanner` secara arsitektural adalah pemindai **Barcode dan QR Code** (berbasis ML Kit Barcode Scanning / ZXing).
   * Callback `onDetect: _onBarcodesDetected` hanya terpicu jika kamera menemukan barcode fisik (1D seperti Code 128 / 2D seperti QR / PDF417).
   * Teks paspor konvensional adalah huruf cetak alfanumerik biasa (`P<GBRWILSON...`), **bukan barcode**. Sensor `MobileScanner` mengabaikan teks tersebut, sehingga `_onBarcodesDetected` **tidak pernah dipanggil**.
2. **Dependensi OCR Terpasang tapi Tidak Pernah Digunakan:**
   * Di [pubspec.yaml](file:///home/ganendra/qrypta/pubspec.yaml#L52), tercantum pustaka `google_mlkit_text_recognition: ^1.0.2`.
   * Pustaka ini bahkan memicu error kompilasi R8 saat build release APK (terdokumentasi di [RELEASE_FIX_LOG.md](file:///home/ganendra/qrypta/docs/RELEASE_FIX_LOG.md#L12-L55)) dan diperbaiki menggunakan aturan ProGuard `-dontwarn`.
   * **Fakta:** Di seluruh direktori `lib/`, class `TextRecognizer` dari Google ML Kit **sama sekali tidak pernah diimpor atau dipanggil**. Pembuat kode memasang pustaka OCR, memperbaiki konfigurasinya, namun layarnya malah dihubungkan ke pemindai barcode.

---

## 2. Jebakan Jaringan: Konfigurasi Localhost (127.0.0.1) di APK Release

### Akar Masalah Teknis
Di dalam file [.env](file:///home/ganendra/qrypta/.env#L1-L7) yang dikemas ke dalam APK rilis:
```env
# RPC & Besu Blockchain Configuration
RPC_URL=http://127.0.0.1:8545
CHAIN_ID=1337
GRAPHQL_URL=http://127.0.0.1:4000/graphql

# ezsign-core Middleware API
EZSIGN_API_URL=http://127.0.0.1:3000/api/v1
```

1. **Ilusi Loopback di HP:**
   * Di dalam sistem operasi Android pada perangkat fisik, alamat `127.0.0.1` merujuk ke **internal perangkat HP itu sendiri**, bukan mesin komputer/server pengembangan tempat node Hyperledger Besu (:8545) atau server Fastify (:3000) berjalan.
2. **Kegagalan Koneksi 100%:**
   * Setiap *network socket call* (baik HTTP JSON-RPC maupun REST API) yang dieksekusi dari HP akan langsung ditolak sistem (*Connection Refused* atau *SocketException: OS Error: Connection refused, errno = 111*).
   * Tidak ada satu pun transaksi, query saldo, atau audit log dari APK release yang pernah menyentuh server backend atau blockchain.

---

## 3. Katalog Fallback Palsu & Silent Catch (Ilusi Berjalan Sukses)

Aplikasi tidak melempar pesan error saat koneksi jaringan gagal. Sebaliknya, aplikasi secara aktif **memalsukan data dan menyembunyikan kegagalan jaringan** menggunakan mekanisme *catch & fake hash*.

### A. Transaksi Finansial (Tourist Levy & QRIS)

#### 1. Pembayaran Tourist Levy (Rp 150.000)
Di [payment_controller.dart](file:///home/ganendra/qrypta/lib/src/features/transaction/logic/payment_controller.dart#L194-L213):
```dart
// Lokasi: lib/src/features/transaction/logic/payment_controller.dart (Baris 194-213)
try {
  txHash = await blockchainService.erc20.sendErc20Token(...);
  ...
} catch (e) {
  // FALLBACK PALSU: Membuat hash tiruan jika node RPC Besu tidak dapat dihubungi
  final fallbackSeed = '$levyRef-$userWallet-${DateTime.now().millisecondsSinceEpoch}';
  txHash = '0x${bytesToHex(keccak256(utf8.encode(fallbackSeed)))}';
}
```
* **Dampak:** Ketika transfer ERC-20 IDRT gagal karena RPC mati, aplikasi secara diam-diam membuat *hash* SHA3 palsu (`0x...`). 
* Pengguna melihat notifikasi hijau *"Tourist Levy successfully paid and anchored on-chain!"*, status retribusi berubah menjadi *Paid*, dan kuitansi resmi terbit, padahal **nol token ditransfer dan nol transaksi tercatat di blockchain**.

#### 2. Pembayaran Merchant QRIS
Di [payment_controller.dart](file:///home/ganendra/qrypta/lib/src/features/transaction/logic/payment_controller.dart#L331-L350):
```dart
// Lokasi: lib/src/features/transaction/logic/payment_controller.dart (Baris 331-350)
try {
  txHash = await blockchainService.erc20.sendErc20Token(...);
  ...
} catch (e) {
  // FALLBACK PALSU: Membuat hash tiruan QRIS
  final fallbackSeed = '$payRef-$userWallet-${DateTime.now().millisecondsSinceEpoch}';
  txHash = '0x${bytesToHex(keccak256(utf8.encode(fallbackSeed)))}';
}
```
* **Dampak:** Transaksi pembayaran ke merchant palsu/mati tetap dinyatakan sukses dengan hash transaksi rekayasa lokal.

---

### B. Audit Persetujuan Data (Consent & Revocation)

Di [verification_transaction_service.dart](file:///home/ganendra/qrypta/lib/src/core/services/blockchain/verification_transaction_service.dart):

#### 1. Persetujuan Berbagi Atribut (Consent Submission)
Baris 127–149:
```dart
try {
  final response = await _httpClient.post(middlewareEndpoint, ...).timeout(...);
  ...
} catch (e) {
  // FALLBACK PALSU: Fastify middleware unreachable, fallback silent
  developer.log('Fastify middleware unreachable ($middlewareEndpoint): $e. Using local immutable digest.');
}
// Langsung membuat AuditTransactionModel lokal dan menyimpannya ke Hive
final auditModel = AuditTransactionModel(..., txHash: txHash, status: 'Approved');
await saveAuditTransaction(auditModel);
return auditModel;
```
* **Dampak:** Ketika Fastify middleware mati, pengiriman log persetujuan dibatalkan diam-diam, namun aplikasi tetap menyimpan status *"Approved"* dengan hash digest lokal seolah-olah transaksi telah disetujui oleh konsorsium.

#### 2. Pencabutan Izin Akses (Revocation)
Baris 220–228:
```dart
try {
  await _httpClient.post(middlewareEndpoint, ...);
} catch (e) {
  developer.log('Revocation submit offline fallback: $e', name: _serviceName);
}
// Tetap menerbitkan audit record 'Revoked' ke database lokal
```
* **Dampak:** Merchant di dunia nyata tidak pernah tahu bahwa aksesnya dicabut karena server middleware tidak pernah menerima instruksi pencabutan.

#### 3. Pencatatan Audit Finansial
Baris 281–288 & 346–354:
```dart
try {
  await _httpClient.post(middlewareEndpoint, ...); // Log Levy Payment
} catch (e) {
  developer.log('Levy payment audit submit fallback: $e', name: _serviceName);
}

try {
  await _httpClient.post(middlewareEndpoint, ...); // Log QRIS Payment
} catch (e) {
  developer.log('QRIS payment audit submit fallback: $e', name: _serviceName);
}
```
* **Dampak:** Seluruh pencatatan audit ke server Fastify/RabbitMQ ditutup oleh blok `catch` kosong tanpa notifikasi error ke UI.

---

### C. Penerbitan Kredensial BTID

Di [btid_issued_screen.dart](file:///home/ganendra/qrypta/lib/src/features/authentication/presentation/screens/btid_issued_screen.dart#L88-L97):
```dart
try {
  final verificationService = ref.read(blockchainServiceProvider).verification;
  await verificationService.recordCredentialIssuedAudit(
    btid: credential.btidNumber,
    fullName: credential.fullName,
    walletAddress: address,
  );
} catch (e) {
  developer.log('Audit record dispatched with local fallback: $e', name: 'BtidIssuedScreen');
}
```
* **Dampak:** Penerbitan ID dinyatakan selesai 100% dan kartu BTID ditampilkan ke turis meskipun backend pencatatan identitas tidak pernah merespons atau sedang offline.

---

### D. Saldo Dompet & Preview Kuitansi

1. **Saldo Default Palsu di UI Pembayaran:**
   * Di [levy_payment_screen.dart](file:///home/ganendra/qrypta/lib/src/features/transaction/presentation/screens/levy_payment_screen.dart#L36):
     ```dart
     String idrtBalanceFormatted = 'Rp 2.480.000'; // Hardcoded fallback jika RPC gagal
     ```
   * Jika RPC Besu gagal dihubungi (seperti yang terjadi di HP rilis), pengguna tetap melihat saldo `Available: Rp 2.480.000` pada tile pembayaran dompet, memberikan kesan palsu bahwa akun memiliki saldo.
2. **Hash Transaksi Statis pada Viewer Kuitansi:**
   * Di [levy_payment_screen.dart](file:///home/ganendra/qrypta/lib/src/features/transaction/presentation/screens/levy_payment_screen.dart#L535):
     ```dart
     txHash: '0x7b2f8a1e9c4d3b5a7e6f8a9b0c1d2e3f4a5b6c7d'
     ```
   * Jika kuitansi dibuka kembali dari tombol *View Official Levy Receipt*, hash transaksi yang disajikan ke layar adalah string statis tiruan, bukan hash unik dari transaksi sebenarnya.

---

## 4. Hardcoded Data & Entitas James Wilson yang Menempel Permanen

Meskipun pengguna memindai paspor atas namanya sendiri di jalur nyata, aplikasi menginjeksi data statis **James Wilson** ke dalam alur logika penting:

1. **Nomor Kredensial BTID Statis:**
   * Di [btid_issued_screen.dart](file:///home/ganendra/qrypta/lib/src/features/authentication/presentation/screens/btid_issued_screen.dart#L66):
     ```dart
     btidNumber: 'BTID-2026-4471-0938'
     ```
   * Siapapun nama turis yang dipindai, nomor BTID yang terbit selalu `BTID-2026-4471-0938`.
2. **Actor Name Statis di Service Audit:**
   * Di [verification_transaction_service.dart](file:///home/ganendra/qrypta/lib/src/core/services/blockchain/verification_transaction_service.dart):
     * Baris 234: `actor: 'James Wilson'` (pada pencabutan izin).
     * Baris 266: `'actor': 'James Wilson'` (pada payload metadata audit retribusi).
     * Baris 295: `actor: 'James Wilson'` (pada entri model audit retribusi).
     * Baris 328: `'actor': 'James Wilson'` (pada payload metadata audit pembayaran QRIS).
     * Baris 360: `actor: 'James Wilson'` (pada entri model audit pembayaran QRIS).
3. **Data Imigrasi Default:**
   * Di [btid_issued_screen.dart](file:///home/ganendra/qrypta/lib/src/features/authentication/presentation/screens/btid_issued_screen.dart#L70-L78):
     * `dob`: Jika parsing null, fallback ke `'1988-04-12'` (tanggal lahir James Wilson).
     * `docExpiry`: Jika null, fallback ke `'2031-08-15'`.
     * `visaType`: Selalu `'e-VOA B1'`.
     * `stayExpiry`: Selalu dihitung flat 30 hari dari tanggal hari ini (`now.add(Duration(days: 30))`).

---

## 5. Discrepansi Fiktif Antara Dokumentasi vs Kode

Terdapat klaim fitur pada dokumen arsitektur yang sama sekali **tidak ada implementasinya di kode**:

### A. Parser QRIS EMVCo TLV & Validasi CRC
* **Klaim Dokumen ([comprehensive_technical_analysis_V2.md](file:///home/ganendra/qrypta/docs/architecture/comprehensive_technical_analysis_V2.md#L124)):**
  > *"Kamera membaca QRIS. Proses ekstraksi EMVCo TLV dan validasi algoritma CRC dilempar ke Flutter Isolate agar UI scanner tidak freeze."*
* **Fakta Kode ([tab_pay.dart](file:///home/ganendra/qrypta/lib/src/features/home/presentation/tabs/tab_pay.dart#L13-L84)):**
  * Tidak ada parser EMVCo TLV maupun kalkulasi CRC.
  * Logika pemindaian hanya melakukan pengecekan string primitif:
    1. Apakah diawali `{` (JSON buatan)?
    2. Apakah mengandung kata `"coffee"` atau kode `"MCH-3311"`?
    3. Apakah mengandung kata `"tour"` atau kode `"MCH-5520"`?
    4. Apakah berupa string hex 42 karakter (`0x...`)?
  * Jika Anda memindai stiker QRIS resmi Bank Indonesia / merchant asli (format standar EMVCo string panjang), pemindai **tidak akan mengenali QR tersebut sama sekali**.

### B. Saluran Komunikasi Dua Arah Merchant Handshake
* **Klaim Dokumen ([BEDAH_TEKNIS_BALI_TOURIST_ID_PATH1_TURIS_APP.md](file:///home/ganendra/qrypta/docs/architecture/BEDAH_TEKNIS_BALI_TOURIST_ID_PATH1_TURIS_APP.md#L102)):**
  > *"Dynamic rotating QR (45s) dipindai merchant, memicu permintaan persetujuan real-time di HP turis."*
* **Fakta Kode ([verification_controller.dart](file:///home/ganendra/qrypta/lib/src/features/verification/logic/verification_controller.dart#L148)):**
  * Tidak ada WebSocket, Server-Sent Events (SSE), Firebase Cloud Messaging (FCM), maupun HTTP Polling untuk menerima request dari merchant di dunia nyata.
  * Permintaan verifikasi hanya dapat dimunculkan dengan **menekan tombol simulasi di dalam aplikasi sendiri** (`triggerMerchantSimulation`) pada Tab Home, Tab Explore, atau tombol pintas di bawah Dynamic QR.

---

## 6. Bongkar Ilusi Test Suite (Mengapa 43/43 Tests Passed Menipu)

Dokumentasi [DOKUMENTASI_TEKNIS_MILESTONE_6.md](file:///home/ganendra/qrypta/docs/architecture/DOKUMENTASI_TEKNIS_MILESTONE_6.md) membanggakan bahwa seluruh 43 pengujian lulus 100%. Berikut dekonstruksi mengapa angka ini menipu:

| File Pengujian | Apa yang Sebenarnya Diuji | Apa yang Dilompati / Tidak Pernah Diuji |
| :--- | :--- | :--- |
| **`test/milestone1_test.dart`** | Aritmatika BigInt, modulo string, hashing SHA-256 lokal | Tidak menguji integrasi GraphQL atau koneksi node nyata. |
| **`test/milestone2_test.dart`** | Serialisasi JSON DTO model | Menggunakan `MockClient` HTTP buatan. Nol pengujian AMQP/Fastify. |
| **`test/milestone3_test.dart`** | Parsing string statis di memori (`MrzParser.parse`) | Tidak ada pengujian kamera `MobileScanner` maupun frame OCR. |
| **`test/milestone4_test.dart`** | Pengurangan timer angka (45 ke 0), logika Map filter | Tidak ada koneksi ke hardware scanner merchant eksternal. |
| **`test/milestone5_test.dart`** | Format string kuitansi, mocking dispatch HTTP 202 | Menggunakan `MockClient`. Nol transaksi ke smart contract Besu. |
| **`test/milestone6_test.dart`** | Rangkaian pemanggilan usecase berantai dengan in-memory state | 100% menggunakan `MockClient`. Nol verifikasi live node di port 8545/3000. |

Seluruh test suite adalah **Unit Test Logika Terisolasi**. Pengujian yang meloloskan pipeline CI/CD tidak pernah menyentuh satu pun driver kamera perangkat atau soket jaringan fisik.

---

## 7. Status Modul Biometrik & NFC (Sesuai Ketetapan)

Sesuai arahan dan strategi efisiensi proyek pada [rencana_pengerjaan_qryptaXezsigncore.md](file:///home/ganendra/qrypta/docs/architecture/rencana_pengerjaan_qryptaXezsigncore.md#peta-strategi-efisiensi-apa-yang-real-vs-simulasi):
* **OCR Muka & Liveness (`ScrLiveness`):** Tetap berstatus **DUMMY/SIMULASI**. Menampilkan viewfinder kamera depan selama 2.5 detik lalu mengeluarkan skor statis **98.7%** tanpa komputasi neural network wajah.
* **NFC Chip Read (`ScrNfc`):** Tetap berstatus **DUMMY/SIMULASI**. Menjalankan timer animasi 6 tahap teks sekuensial tanpa transmisi APDU ke chip ISO-14443 fisik.
* **Passive Authentication (`ScrAuth`):** Tetap berstatus **DUMMY/SIMULASI**. Menampilkan visual rantai sertifikat PKI statis.

---

## 8. Rencana Aksi Korektif & Prioritas Perbaikan

Untuk mengubah aplikasi dari prototipe ilusi menjadi aplikasi produksi yang berfungsi secara riil:

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                        PRIORITAS TINDAKAN PERBAIKAN                                    │
└────────────────────────────────────────────────────────────────────────────────────────┘

 [PRIORITAS 1: URGEN]  Perbaiki OCR Scanner di mrz_scanner_screen.dart
                       • Lepas MobileScanner (Barcode).
                       • Pasang package:camera + google_mlkit_text_recognition.
                       • Ekstrak CameraImage -> InputImage -> TextRecognizer -> MrzParser.
                                                  │
                                                  ▼
 [PRIORITAS 2: JARINGAN] Rombak Konfigurasi .env & Networking
                       • Ganti 127.0.0.1 dengan IP LAN Server (misal: 192.168.x.x) atau URL Tunnel.
                       • Pastikan port 8545 (Besu) dan 3000 (Fastify) terbuka di firewall.
                                                  │
                                                  ▼
 [PRIORITAS 3: INTEGRITAS] Eliminasi Silent Fallback & Fake Hashes
                       • Hapus blok catch(e) yang memalsukan keccak256 txHash di PaymentController.
                       • Lempar error transparan ke UI jika transaksi gagal/offline.
                                                  │
                                                  ▼
 [PRIORITAS 4: DATA]   Dinamisasi Data Kredensial BTID
                       • Generate nomor BTID unik berbasis UUID/Timestamp, bukan hardcoded.
                       • Hubungkan actor di VerificationTransactionService ke nama paspor asli.
```
