# PROGRESS KERJA: ELIMINASI FALLBACK PALSU & VERIFIKASI KONDISI NYATA
**Proyek:** Qrypta & Bali Tourist ID  
**Baseline Audit:** `docs/AUDIT_TEMUAN_KESALAHAN_DAN_FALLBACK_PALSU.md`  
**Master Plan:** `docs/RENCANA_KERJA_ELIMINASI_FALLBACK_PALSU.md`  
**Branch Kerja:** `fix/real-behavior`  
**Terakhir Diperbarui:** 17 November 2026  

---

## 1. RINGKASAN PROGRESS & STATUS FASE

| Phase | Fokus Pekerjaan | Estimasi | Status | Catatan / Target |
| :--- | :--- | :--- | :--- | :--- |
| **Phase 0** | **Baseline, Reproduksi, Guard CI, Staging Environment** | **2-3 h** | **✅ Selesai** | **Baseline lengkap, 94 catch diinventarisir, reality-guard CI merah aktif.** |
| **Phase 1** | **Konfigurasi Dinamis & Sanitasi Jaringan (.env & Dart loopback)** | **3-4 h** | **✅ Selesai** | **F-02, F-20 tuntas: AppConfig compile-time defines, ConfigValidator (R5), NetworkHealthService, permission manifest.** |
| **Phase 2** | **Fondasi Arsitektur (AppFailure, Tx State Machine, Hive Outbox)** | **3 h** | **✅ Selesai** | **AppFailure taxonomy, TxStateMachine & TxRecovery, Hive OutboxWorker idempoten, AuditMigrationService.** |
| **Phase 3** | **Transaksi Finansial Nyata (Tourist Levy ERC-20 & QRIS IDRT)** | **5-6 h** | **✅ Selesai** | **F-03, F-03b, F-04, F-09, F-09b, F-10, F-10b tuntas: eliminasi fallback hash, single-source idrtBalanceProvider.** |
| **Phase 4** | **Consent, Revocation & Financial Audit Nyata** | **5 h** | **✅ Selesai** | **F-05, F-06, F-07, F-12, F-12b, F-21 tuntas: outbox offline queue, zero-PII ActorRef, sanitasi James Wilson & catch kosong.** |
| **Phase 5A** | **Mesin OCR MRZ Paspor Nyata (Google ML Kit Text Recognition)** | **6-8 h** | **✅ Selesai** | **F-01, F-19, F-23 tuntas: kamera optik asli ML Kit, MrzExtractor, MrzFrameConsensus, eliminasi MobileScanner & bypass demo, input manual ICAO.** |
| **Phase 5B** | **Penerbitan BTID Otoritatif & Sanitasi Data Identitas** | **4 h** | **✅ Selesai** | **F-08, F-11, F-11b, F-13, F-13b tuntas: penerbitan server otoritatif, eliminasi BTID & DOB statis, Zero-PII passportHash HMAC-SHA256, HolderProfile.** |
| **Phase 6** | **Parser Standar QRIS EMVCo TLV & Validasi CRC16-CCITT** | **4-5 h** | **✅ Selesai** | **F-14, F-14b, F-24 tuntas: eliminasi string match coffee/tour/MCH, background Isolate.run, 32 real QRIS fixtures.** |
| **Phase 7** | **Merchant Handshake Dua Arah Nyata (WebSocket/SSE + Push)** | **7-9 h** | **✅ Selesai** | **F-15, F-15b tuntas: RealtimeChannelService (WS+HTTP sync), PushNotificationService, Dynamic QR canonical secp256k1 signature, eliminasi triggerMerchantSimulation dari UI & logic, CLI tools/merchant_sim.** |
| Phase 8 | Pembacaan Chip e-Passport NFC & Passive Authentication (PA) | 10-15 h | ⬜ Belum | F-17 (bergantung keputusan D-1). |
| Phase 9 | Pelabelan Eksplisit Simulasi Liveness Wajah | 1 h | ⬜ Belum | F-18 (satu-satunya dummy resmi, wajib berlabel SIMULASI). |
| Phase 10 | Pengujian Lapangan Lintas Level (L1-L4) & Reality Gate Final | +4 h | ⬜ Belum | Verifikasi HP fisik, receipt explorer, no mock claim. |

---

## 2. TABEL PELACAKAN TEMUAN (F-01 s/d F-24)

> Status Legend:  
> `⬜ Belum` | `🔄 Dalam pengerjaan` | `✅ Selesai` | `⏭️ Ditunda (alasan)`

| ID | Judul Singkat Masalah & Lokasi | Severity | Phase | Status | PR / Commit | Bukti & Catatan Baseline | Tanggal |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **F-01** | `MobileScanner` (barcode) dipakai untuk MRZ; `google_mlkit` tidak pernah dipanggil | Kritis | 5A | ✅ Selesai | Branch `fix/real-behavior` | `MobileScanner` digantikan pipeline optik `camera` + `google_mlkit_text_recognition`, `MrzExtractor`, dan `MrzFrameConsensus`. | 2026-11-18 |
| **F-02** | `.env` berisi `127.0.0.1` dikemas ke bundle asset APK rilis | Kritis | 1 | ✅ Selesai | Branch `fix/real-behavior` | `.env` dihapus dari assets & `.gitignore`, dependensi `flutter_dotenv` dibuang, migrasi ke `AppConfig`. | 2026-11-17 |
| **F-03** | Fallback hash keccak256 palsu saat pembayaran Tourist Levy via wallet gagal | Kritis | 3 | ✅ Selesai | Branch `fix/real-behavior` | Dieliminasi dari `payment_controller.dart`. Transaksi wajib on-chain dengan receipt status 1. | 2026-11-18 |
| **F-03b** | Jalur Visa/Counter QR di `payment_controller.dart` juga memproduksi hash keccak256 palsu | Kritis | 3 | ✅ Selesai | Branch `fix/real-behavior` | Dieliminasi dari `payment_controller.dart`. Metode non-wallet ditolak via ValidationFailure. | 2026-11-18 |
| **F-04** | Fallback hash keccak256 palsu saat pembayaran QRIS merchant via wallet gagal | Kritis | 3 | ✅ Selesai | Branch `fix/real-behavior` | Dieliminasi dari `payment_controller.dart`. Intent dikelola TxStateMachine dan diverifikasi on-chain. | 2026-11-18 |
| **F-05** | Consent submit ditelan `catch`, otomatis disimpan status "Approved" lokal | Tinggi | 4 | ✅ Selesai | Branch `fix/real-behavior` | Dieliminasi dari `verification_transaction_service.dart`. Approval wajib ack 2xx Fastify, error dilempar sebagai AppFailure. | 2026-11-18 |
| **F-06** | Revocation akses ditelan `catch`, otomatis disimpan status "Revoked" lokal | Tinggi | 4 | ✅ Selesai | Branch `fix/real-behavior` | Pencabutan dialihkan ke Outbox saat offline dengan status pending_sync dan peringatan merchant access jelas. | 2026-11-18 |
| **F-07** | Audit finansial levy & QRIS ditelan `catch` hanya dengan `developer.log` | Tinggi | 4 | ✅ Selesai | Branch `fix/real-behavior` | Audit levy & QRIS dialihkan ke Outbox saat offline dengan status pending_sync (R7). | 2026-11-18 |
| **F-08** | Audit penerbitan BTID ditelan `catch`, kartu tetap terbit dengan hash keccak palsu | Tinggi | 5B | ✅ Selesai | Branch `fix/real-behavior` | Eliminasi silent catch lokal di `btid_issued_screen.dart`. Kartu BTID hanya tampil setelah penerbitan otoritatif server berhasil. | 2026-11-19 |
| **F-09** | Saldo default `Rp 2.480.000` di `levy_payment_screen.dart` | Tinggi | 3 | ✅ Selesai | Branch `fix/real-behavior` | Dieliminasi, bermigrasi ke single-source idrtBalanceFormattedProvider. | 2026-11-18 |
| **F-09b** | Saldo default `Rp 2.480.000` di `tab_home.dart` dan `qris_payment_screen.dart` | Tinggi | 3 | ✅ Selesai | Branch `fix/real-behavior` | Dieliminasi dari seluruh file, nol hit grep di seluruh repo. | 2026-11-18 |
| **F-10** | Hash statis kuitansi `0x7b2f8a1e...` di `levy_payment_screen.dart` | Sedang | 3 | ✅ Selesai | Branch `fix/real-behavior` | Dieliminasi, digantikan hash on-chain riil dari state BtidCredentialModel/LevyReceiptData. | 2026-11-18 |
| **F-10b** | Hash statis kuitansi `0x7b2f8a1e...` di `tab_home.dart` dan `tab_profile.dart` | Sedang | 3 | ✅ Selesai | Branch `fix/real-behavior` | Dieliminasi dari dashboard dan profil, nol hit grep di seluruh repo. | 2026-11-18 |
| **F-11** | Nomor BTID statis `BTID-2026-4471-0938` di `btid_issued_screen.dart` | Tinggi | 5B | ✅ Selesai | Branch `fix/real-behavior` | Dieliminasi dari `btid_issued_screen.dart`, nomor BTID resmi diterbitkan oleh backend ezsign-core. | 2026-11-19 |
| **F-11b** | Nomor BTID statis tersebar di 8 file tambahan (model deserializer, controller, screens) | Tinggi | 5B | ✅ Selesai | Branch `fix/real-behavior` | Dieliminasi dari seluruh basis kode `lib/` (0 hit grep). Default demo constructor dihapus. | 2026-11-19 |
| **F-12** | Actor `James Wilson` di 5 lokasi service audit | Tinggi | 4/5B | ✅ Selesai | Branch `fix/real-behavior` | ActorRef salted hash (zero-PII D-8) menggantikan literal James Wilson di seluruh service audit. | 2026-11-18 |
| **F-12b** | `James Wilson` tertanam di DTO model, factory MRZ parser, dan UI screens | Tinggi | 5B | ✅ Selesai | Branch `fix/real-behavior` | James Wilson dieliminasi 100% dari seluruh `lib/` (grep: 0 hit). demoJamesWilson dipindah ke test/fixtures/. | 2026-11-18 |
| **F-13** | Default imigrasi (DOB, expiry, visaType) di `btid_issued_screen.dart` | Tinggi | 5B | ✅ Selesai | Branch `fix/real-behavior` | Dieliminasi. DOB dan docExpiry diambil strictly dari MRZ dan dicek kedaluwarsa; visaType dari backend imigrasi. | 2026-11-19 |
| **F-13b** | Default imigrasi (`1988-04-12`, `2031-08-15`, `e-VOA B1`) tertanam di DTO model | Tinggi | 5B | ✅ Selesai | Branch `fix/real-behavior` | Dieliminasi dari `btid_credential_model.dart` (wajib di fromJson, throw FormatException) & policy_matrix (0 hit grep di lib/). | 2026-11-19 |
| **F-14** | Parser QRIS EMVCo TLV tidak ada; string match 'coffee'/'tour'/MCH di `tab_pay.dart` | Tinggi | 6 | ✅ Selesai | Branch `fix/real-behavior` | Dieliminasi. Digantikan QrisParser murni rekursif TLV + validasi integritas CRC16/CCITT-FALSE di isolate. | 2026-11-19 |
| **F-14b** | Duplikasi logika string match di `qr_scanner_screen.dart` & `policy_matrix_constants` | Tinggi | 6 | ✅ Selesai | Branch `fix/real-behavior` | Dieliminasi dari seluruh features. QrPayloadRouter deterministik dan MerchantResolverService konsorsium. | 2026-11-19 |
| **F-15** | Handshake merchant hanya simulasi in-app berbasis delay timer | Tinggi | 7 | ✅ Selesai | Branch `fix/real-behavior` | Dieliminasi. Membangun RealtimeChannelService (WebSocket + HTTP sync fallback) dan PushNotificationService. | 2026-11-20 |
| **F-15b** | Pemanggilan `triggerMerchantSimulation` tersebar di 3 lokasi UI | Tinggi | 7 | ✅ Selesai | Branch `fix/real-behavior` | Dieliminasi dari `tab_home.dart`, `tab_explore.dart`, `dynamic_qr_screen.dart`, dan controller. 0 hit grep di lib/. | 2026-11-20 |
| **F-16** | 43 test suite lulus hanya unit test + `MockClient` (ilusi coverage) | Tinggi | 10 | 🔄 Dalam pengerjaan | Branch `fix/real-behavior` | Pengujian berjenjang aktif: L1 (unit), L2 (integrasi nyata), L3 (chaos/ketahanan). Total 170 tests lulus. | 2026-11-20 |
| **F-17** | Modul pembacaan chip NFC & Passive Authentication hanya simulasi timer | Sedang | 8 | ⬜ Belum | - | Terverifikasi di `passport_verification_flow_screen.dart:102,420`. | 2026-11-17 |
| **F-18** | Liveness wajah dummy skor 98.7% tanpa label simulasi | Rendah | 9 | ⬜ Belum | - | Terverifikasi di `passport_verification_flow_screen.dart:790` (MATCH SCORE: 98.7%). | 2026-11-17 |
| **F-19** | Tombol "Fast Demo Mode" di welcome screen & factory `demoJamesWilson()` di `lib/` | Kritis | 0/5A | ✅ Selesai | Branch `fix/real-behavior` | Tombol Fast Demo Mode dan shortcut demo dihapus dari seluruh onboarding; factory dipindah ke `test/fixtures/`. | 2026-11-18 |
| **F-20** | Alamat loopback `127.0.0.1` hardcoded langsung di kode Dart (bukan hanya .env) | Kritis | 1 | ✅ Selesai | Branch `fix/real-behavior` | Dieliminasi dari `blockchain_config.dart`, `graphql_provider.dart`, `payment_controller.dart`. Check 7 Reality Guard lolos hijau. | 2026-11-17 |
| **F-21** | Blok `catch (_) {}` kosong total tanpa logging ditemukan di 14 titik | Tinggi | 2/3/4 | ✅ Selesai | Branch `fix/real-behavior` | Seluruh blok catch kosong di `lib/` telah disanitasi 100% (grep: 0 hit). Check Reality Guard hijau. | 2026-11-18 |
| **F-22** | Android Manifest tidak mendeklarasikan izin `CAMERA` & `NFC` di manifest utama | Tinggi | 1/5A/8 | ✅ Selesai (Kamera) | Branch `fix/real-behavior` | Izin `CAMERA` telah aktif di manifest dan dikelola via runtime `permission_handler` di `mrz_scanner_screen.dart`. | 2026-11-18 |
| **F-23** | Dependensi `camera` tidak terpasang di `pubspec.yaml` untuk frame OCR ML Kit | Kritis | 5A | ✅ Selesai | Branch `fix/real-behavior` | Terpasang `camera: ^0.12.2` & `permission_handler: ^13.0.2` di `pubspec.yaml`. | 2026-11-18 |
| **F-24** | Tombol quick test di `send_scanner_screen.dart` memuat fixture JSON merchant statis | Sedang | 6 | ✅ Selesai | Branch `fix/real-behavior` | Tombol simulasi injeksi payload demo dihapus dari send_scanner_screen.dart. | 2026-11-19 |

---

## 3. LOG AKTIVITAS HARIAN

### 17 November 2026 - Phase 0 Execution
- **Branch dibuat:** `fix/real-behavior`.
- **Audit Temuan Baseline:** Verifikasi seluruh temuan F-01 s/d F-21 + temuan tambahan F-22, F-23, F-24. Seluruh nomor baris dan file terpetakan akurat.
- **Inventarisasi Blok Catch:** Ditemukan 94 blok catch di `lib/`, dengan 49 di antaranya terbukti menelan error (14 di antaranya adalah `catch (_) {}` kosong total). Hasil didokumentasikan di `docs/audit/catch_inventory.md`.
- **Implementasi Guard CI:** Skrip `tools/reality_guard.sh` dibuat dan dieksekusi. Berhasil membuktikan status **MERAH** (menemukan 9 kategori pelanggaran fatal).
- **Penegakan Lint Dart:** Aturan `avoid_catches_without_on_clauses`, `empty_catches`, dan `only_throw_errors` diaktifkan di `analysis_options.yaml`, menghasilkan 62 warning aktif.
- **Environment Staging:** Dibuat konfigurasi `docker-compose.staging.yml` (Besu, Postgres, ezsign-core, Caddy) dan skrip inisialisasi `tools/seed_staging.sh`.
- **Status Akhir Phase 0:** Selesai 100%. Lanjut ke Phase 1 (Konfigurasi & Jaringan).

### 17 November 2026 - Phase 1 Execution
- **Eliminasi `.env` & flutter_dotenv (F-02):** Menghapus dependensi `flutter_dotenv` dan aset `.env` dari `pubspec.yaml`. Seluruh konfigurasi dipindahkan ke `AppConfig` via `--dart-define` / `--dart-define-from-file`.
- **Eliminasi Hardcoded Loopback Dart (F-20):** Membersihkan `127.0.0.1` dan fallback loopback dari `blockchain_config.dart`, `graphql_provider.dart`, `token_service.dart`, dan `payment_controller.dart`. Check 7 Reality Guard kini **HIJAU** (`✅ [PASS] Tidak ada loopback hardcoded di config Dart`).
- **Implementasi `ConfigValidator` (Golden Rule R5):** Menolak build/startup jika variabel wajib kosong atau jika build staging/prod menggunakan loopback (`127.0.0.0/8`, `localhost`, `10.0.2.2`) atau skema cleartext HTTP. Menyediakan layar `ConfigErrorApp` jika validasi gagal.
- **Implementasi `NetworkHealthService` (Phase 1.2b):** Melakukan health check berkala dan reaktif terhadap Besu JSON-RPC (`eth_chainId`, `eth_blockNumber`) dan `ezsign-core` (`GET /health`), dengan deteksi chain mismatch dan pelaporan degradasi tanpa fake fallback. Menyediakan komponen banner `NetworkStatusBanner` di `HomeScreen`.
- **Sanitasi Platform Android (Phase 1.3):** Menambahkan deklarasi izin `CAMERA` dan `NFC` ke `AndroidManifest.xml` utama, serta konfigurasi debug `network_security_config.xml` untuk pembatasan cleartext HTTP hanya di build debug.
- **Template Lingkungan:** Menyiapkan `env/dev.example.json`, `env/staging.example.json`, `env/prod.example.json`, mengonfigurasi `.gitignore` untuk melindungi file JSON lokal.
- **Pengujian Unit L1:** Dibuat 13 pengujian unit baru (`test/config_validator_test.dart` & `test/network_health_service_test.dart`). Seluruh 56 pengujian proyek lulus 100%.
- **Status Akhir Phase 1:** Selesai 100%. Siap lanjut ke Phase 2 (Fondasi Arsitektur).

### 18 November 2026 - Phase 2 Execution
- **Taksonomi Error Bertipe (AppFailure & NetworkExceptionAdapter):** Membuat `lib/src/core/error/app_failure.dart` (11 kelas error bertipe) dan `lib/src/core/error/network_exception_adapter.dart` yang membungkus seluruh pemanggilan IO, HTTP, dan JSON-RPC ke tipe terstruktur tanpa silent catch.
- **State Machine On-Chain & Recovery (Phase 2.2):** Mengimplementasikan `TxState`, `TxIntent`, `TxIntentRepository`, `TxStateMachine`, dan `TxRecoveryService`. Menegakkan aturan transisi legal dan persistensi intent sebelum broadcast. Menyediakan polling receipt terstruktur dengan timeout 120s dan pemulihan otomatis saat aplikasi restart.
- **Pola Outbox Server (Phase 2.3):** Membangun `OutboxItem`, `OutboxRepository`, dan `OutboxWorker` dengan backoff eksponensial (5s hingga 15m), header `Idempotency-Key` (UUID v4), serta pembedaan jelas antara penolakan client permanen (4xx) dan retry error transient (5xx/network).
- **Sanitasi Model Audit & Migrasi Hive (Phase 2.4):** Memperbarui `AuditTransactionModel` dengan `syncStatus`, `serverId`, `anchorTxHash`, `actorWallet`, `actorRef`, dan `txHash` nullable. Menghilangkan fallback statis `'James Wilson'` (F-12b) dari `fromJson`. Mengimplementasikan `AuditMigrationService` untuk menandai seluruh record warisan lama sebagai `legacy_unverified`.
- **Sanitasi Silent Catch (F-21):** Mengganti `catch (_) {}` kosong di `transaction_service.dart:253` dan `verification_transaction_service.dart:441,471` dengan penanganan ber-logging terstruktur.
- **Infrastruktur Providers:** Menyediakan `foundation_providers.dart` dan mengintegrasikan startup lifecycle di `lib/main.dart`.
- **Pengujian Unit L1:** Dibuat 19 pengujian unit baru di `test/phase2_foundation_test.dart`. Total pengujian aktif seluruh proyek kini **75/75 lulus 100%**.
- **Status Akhir Phase 2:** Selesai 100%. Siap melangkah ke Phase 3 (Transaksi Finansial) & Phase 4 (Consent/Audit).

### 18 November 2026 - Phase 3 Execution
- **Eliminasi Fallback Hash Palsu (F-03, F-03b, F-04):** Menghapus seluruh pembuatan hash keccak256 deterministik dari seed string di `payment_controller.dart`. Seluruh transaksi diarahkan lewat `TxStateMachine`, broadcast langsung ke node Besu, dan receipt diverifikasi via `TxRecoveryService.pollReceiptUntilMined(txHash)`.
- **Eliminasi Jalur Simulasi Kartu Visa (F-03b):** Menolak metode pembayaran non-wallet dengan melempar `ValidationFailure` terstruktur.
- **Eliminasi Saldo Default Statis (F-09, F-09b):** Menghapus `Rp 2.480.000` dari `levy_payment_screen.dart`, `qris_payment_screen.dart`, dan `tab_home.dart`. Seluruh saldo kini dibaca dari satu sumber: `idrtBalanceProvider` & `idrtBalanceFormattedProvider`.
- **Eliminasi Hash Kuitansi Statis (F-10, F-10b):** Menghapus literal `0x7b2f8a1e9c4d3b5a7e6f8a9b0c1d2e3f4a5b6c7d`. Menambahkan field `levyTxHash` pada `BtidCredentialModel` sehingga kuitansi hanya menampilkan hash on-chain yang valid.
- **Sanitasi Silent Catch (F-21):** Mengeliminasi 6 blok `catch (_) {}` kosong di `payment_controller.dart` dan 3 blok di `btid_provider.dart`.
- **Pengujian Unit L1:** Dibuat 9 pengujian unit baru di `test/phase3_financial_transaction_test.dart`. Total pengujian aktif seluruh proyek kini **84/84 lulus 100%**.
- **Status Akhir Phase 3:** Selesai 100%. Siap melangkah ke Phase 4 (Consent, Revocation & Financial Audit).

### 18 November 2026 - Phase 4 Execution
- **Eliminasi Fallback Palsu Consent Submission (F-05):** Menghapus penelanan error pada blok catch `signAndSubmitConsent`. Persetujuan consent kini wajib mendapatkan konfirmasi 2xx dari Fastify middleware `ezsign-core` dan menyertakan header `Idempotency-Key`. Jika server gagal, transaksi melempar `AppFailure` bertipe tanpa membuat status Approved palsu lokal.
- **Eliminasi Fallback Palsu Revocation (F-06):** Mengintegrasikan `revokeMerchantAccess` dengan `OutboxRepository`. Pada kondisi offline, rekaman ditandai `pending_sync` disertai peringatan akses merchant, dan dijadwalkan untuk dikirim ulang via `OutboxWorker`.
- **Eliminasi Penelanan Error Audit Finansial (F-07):** Mengintegrasikan `recordLevyPaymentAudit` dan `recordQrisPaymentAudit` dengan antrean Outbox saat server offline dengan status `pending_sync` (R7) tanpa memalsukan status `synced`.
- **Sanitasi Aktor & Privasi Zero-PII (F-12 & F-12b):** Mengimplementasikan model `ActorRef` dengan hash kriptografi bergaram (D-8). Menghapus seluruh kemunculan literal `'James Wilson'` di seluruh basis kode `lib/` (0 hit). Memindahkan `demoJamesWilson()` ke fixture pengujian dan menghapus tombol fast demo bypass dari `welcome_screen.dart` dan `mrz_scanner_screen.dart`.
- **Sanitasi Silent Catch (F-21):** Mengeliminasi 100% blok `catch (_) {}` kosong di `lib/` (`verification_controller.dart`, `tab_pay.dart`, `qr_scanner_screen.dart`). Check Reality Guard untuk catch kosong kini berstatus HIJAU.
- **UI Status Sinkronisasi & Sync Center (Phase 4.5):** Menambahkan chip visual status sinkronisasi (`Synced`, `Menunggu Sinkron`, `Ditolak Server`, `Tidak Terverifikasi`), kotak detail error/peringatan, dan antarmuka `Sync Center` interaktif dengan tombol "Kirim Ulang Sekarang" di `privacy_audit_screen.dart`.
- **Pengujian Unit L1:** Dibuat 12 pengujian unit baru di `test/phase4_consent_audit_test.dart`. Total pengujian aktif seluruh proyek kini **96/96 lulus 100% (0 failed)**.
- **Status Akhir Phase 4:** Selesai 100%. Siap melangkah ke Phase 5A (Mesin OCR MRZ Paspor Asli).

### 18 November 2026 - Phase 5A Execution
- **Eliminasi MobileScanner & Integrasi ML Kit Asli (F-01, F-23):** Melepas `MobileScanner` dari pemindai MRZ paspor. Mengintegrasikan kamera native (`camera: ^0.12.2`) dan Google ML Kit Text Recognition (`google_mlkit_text_recognition: ^1.0.2`) dengan kompensasi sensor rotasi dan throttle frame 250ms.
- **Ekstraksi & Koreksi Optik Berbasis Field (MrzExtractor):** Mengembangkan mesin ekstraksi pasangan baris TD3 dengan koreksi karakter optik berbasis tipe field ICAO Doc 9303 modulo 10 (angka vs huruf vs filler `<`).
- **Konsensus Multi-Frame (MrzFrameConsensus):** Mensyaratkan minimal 2 frame berturut-turut menghasilkan MRZ identik dalam jendela 2 detik untuk menjamin 0 false acceptances.
- **Eliminasi Fast Demo Bypass & James Wilson (F-19):** Menghapus tombol demo dari `mrz_scanner_screen.dart` dan memindahkan factory demo ke `test/fixtures/`. Menyediakan form Input Paspor Manual tervalidasi ICAO sebagai alternatif nyata.
- **Pengujian Unit L1:** Dibuat 18 pengujian unit baru di `test/phase5a_mrz_ocr_test.dart`. Total pengujian aktif seluruh proyek menjadi **114/114 lulus 100%**.
- **Status Akhir Phase 5A:** Selesai 100%. Siap melangkah ke Phase 5B (Penerbitan BTID Otoritatif).

### 19 November 2026 - Phase 5B Execution
- **Penerbitan BTID Otoritatif dari Server (Phase 5B.1 / F-11 & F-08):** Membangun `BtidIssuanceService` yang mengeksekusi `POST /credentials/btid` ke backend middleware `ezsign-core` dengan header `Idempotency-Key` (SHA-256) untuk mencegah penerbitan ganda. Kartu BTID hanya dirender setelah server merespons HTTP 200/201 dengan `btidNumber` resmi.
- **Eliminasi Silent Catch Fallback Lokal (F-08):** Menghapus penelanan error catch di `btid_issued_screen.dart:96`. Jika backend offline atau gagal, aplikasi menampilkan layar error "Penerbitan Belum Dapat Diselesaikan" dengan tombol "Coba Lagi" tanpa menampilkan kartu palsu.
- **Eliminasi Total BTID Statis (F-11 & F-11b):** Menghapus literal `BTID-2026-4471-0938` dari seluruh basis kode `lib/` (0 hit grep). Menghapus `BtidCredentialModel.defaultDemo()`, membersihkan fallback di `dynamic_qr_screen.dart`, `tab_profile.dart`, dan `levy_payment_screen.dart`.
- **Eliminasi Default Imigrasi & Sanitasi Model (F-13 & F-13b):** Menghapus `'1988-04-12'`, `'2031-08-15'`, dan `'e-VOA B1'` dari `lib/` (0 hit grep). Memperketat deserialisasi `BtidCredentialModel.fromJson` agar melempar `FormatException` jika field wajib (`btidNumber`, `fullName`, `nationality`, `dob`, `docExpiry`) tidak tersedia.
- **Validasi Paspor Pre-Flight & Proteksi Kedaluwarsa (Phase 5B.2):** Validasi ketat paspor sebelum panggilan jaringan: tanggal lahir dan kedaluwarsa wajib valid, dan paspor yang telah kedaluwarsa seketika ditolak dengan `ValidationFailure`.
- **Resolusi Data Imigrasi Otoritatif vs Deklarasi Mandiri (Phase 5B.3 / D-2):** Mengintegrasikan `fetchImmigrationData` via `GET /immigration/evoa?passportHash=...`. Jika backend imigrasi tidak tersedia, sistem mencatat status `source: "self_declared"` secara transparan tanpa status verified palsu.
- **Holder Profile & Identitas Aktor Real (Phase 5B.4 / F-12 UI):** Mengimplementasikan model `HolderProfile` dan provider `holderProfileProvider` yang mengikat identitas aktif ke `ActorRef` zero-PII (salted HMAC-SHA256).
- **Pengujian Unit L1:** Dibuat 17 pengujian unit baru di `test/phase5b_btid_issuance_test.dart`. Total pengujian aktif seluruh proyek kini **131/131 lulus 100% (0 failed)**.
- **Status Akhir Phase 5B:** Selesai 100%. Siap melangkah ke Phase 6 (Parser QRIS EMVCo TLV & CRC16).

### 19 November 2026 - Phase 6 Execution
- **Implementasi Mesin Parser QRIS EMVCo TLV & CRC16 Asli (Phase 6.2 / F-14):** Membangun `QrisParser` murni yang mengekstraksi seluruh tag EMVCo MPM dan Standar Nasional QRIS (PADG BI No. 21/18/PADG/2019) secara rekursif (tags 26–51, 62). Mengimplementasikan validasi kriptografis CRC16/CCITT-FALSE (poly `0x1021`, init `0xFFFF`) atas seluruh string payload hingga tag `6304`. Menolak seketika payload dengan CRC korup, mata uang non-IDR (bukan 360), nominal tidak valid, atau tag wajib hilang.
- **Eksekusi Parsing pada Background Isolate (Phase 6.2 #5):** Mengimplementasikan `QrisParser.parseInIsolate` via `Isolate.run`, menjamin rendering kamera scanner pada UI thread tetap responsif (60 FPS) tanpa freeze saat memproses string QR kompleks.
- **Router Payload Deterministik (`QrPayloadRouter` - Phase 6.1):** Menghilangkan seluruh tebakan kata kunci dan pencocokan string bebas. Urutan routing ketat:
  1. Diawali `000201` -> kandidat EMVCo QRIS -> `QrisParser`.
  2. Regex `^0x[0-9a-fA-F]{40}$` -> alamat dompet EVM langsung, dengan penegakan validasi checksum EIP-55 bila huruf campuran (mixed-case).
  3. JSON berskema versi (`{"v":1,"type":...,"sig":...}`) -> protokol native Qrypta dengan verifikasi tanda tangan secp256k1 (130 hex + 0x prefix).
  4. Selain itu -> seketika melempar `ValidationFailure("QR tidak dikenali.")` tanpa tebakan atau fallback default.
- **Layanan Resolusi Merchant Otoritatif (`MerchantResolverService` - Phase 6.3 / D-4):** Mengintegrasikan lookup identitas merchant ke endpoint backend `GET /merchants/resolve?nmid=...`. Memvalidasi bahwa stiker QRIS fisik terhubung ke rail Rupiah perbankan (PJP), dan pembayaran on-chain IDRT hanya dieksekusi apabila merchant terdaftar dan berstatus `verified: true` di konsorsium. Apabila NMID tidak terdaftar atau HTTP 404, sistem melempar `MerchantNotRegistered` tanpa transaksi dan tanpa memalsukan status sukses.
- **Pembersihan String-Match Primitif & Duplikasi Scanner (Phase 6.4 / F-14 & F-14b):**
  - Menghapus 100% percabangan `coffee`, `tour`, `MCH-3311`, dan `MCH-5520` dari `tab_pay.dart` dan `qr_scanner_screen.dart`.
  - Menghapus tombol shortcut simulasi injeksi payload demo dari `send_scanner_screen.dart`.
  - Menghapus fallback default nilai parameter konstruktor di `qris_payment_screen.dart` (mewajibkan `merchantName`, `merchantId`, `merchantAddress`).
  - Memindahkan fixture data uji staging `MCH-3311` dan `MCH-5520` ke `test/fixtures/demo_merchants_fixture.dart`. Kode produksi `lib/` kini 100% bebas dari literal merchant uji.
  - Check Reality Guard CI `F-14b` dan Check 1 kini berstatus **HIJAU** (`✅ [PASS] Tidak ada string-match merchant primitif di features/` & `✅ [PASS] Tidak ada literal palsu dasar di lib/`).
- **Koleksi Fixture Representatif 32 QRIS Riil:** Membuat `test/fixtures/qris_fixtures.dart` yang memuat 32 payload QRIS riil terverifikasi CRC16 bit-level (statis, dinamis, berbagai acquirer perbankan nasional & dompet digital: BCA, Mandiri, BRI, BNI, BPD Bali, GoPay, OVO, DANA, ShopeePay, LinkAja, Nobu, CIMB, Permata, Danamon, BSI, Netzme, Xendit, DOKU, OttoPay, KasPro).
- **Pengujian Unit & Integrasi L1 & L2 (Phase 6.5):** Dibuat 26 pengujian komprehensif di `test/phase6_qris_parser_test.dart` (32 fixture parsing, ekstraksi statis/dinamis/tip/fee, pengujian isolate, 10 uji negatif CRC/panjang/mata uang/negara, 300 iterasi fuzzing mutasi bit-flip acak, routing deterministik, dan resolusi merchant L2). Total pengujian aktif seluruh proyek kini **157/157 lulus 100% (0 failed)**.
- **Status Akhir Phase 6:** Selesai 100%. Siap melangkah ke Phase 7 (Handshake Merchant Dua Arah & WebSocket/FCM).

### 20 November 2026 - Phase 7 Execution
- **Spesifikasi Protokol Handshake & Tanda Tangan Kriptografis Dynamic QR (Phase 7.1 / F-15):** Memperbarui generator Dynamic QR 45 detik di `VerificationTransactionService` untuk menyertakan skema canonical `{v, sessionId, nonce, exp, wallet, btid, token, sig}` yang ditandatangani menggunakan kunci privat dompet wisatawan via `signPersonalMessageToUint8List`. Membangun validator statis `verifyDynamicQrToken` dengan pemulihan kunci publik `ecRecover` dan pencegahan kedaluwarsa ketat.
- **Layanan Kanal Dua Arah Real-Time (`RealtimeChannelService` - Phase 7.2 #1 / F-15):** Membangun layanan WebSocket/SSE dengan rekoneksi eksponensial otomatis (1s s/d 30s), heartbeat berkala (ping setiap 25s), pemulihan pesan terlewat via endpoint REST `GET /verification/requests?since=`, serta cadangan polling berkala saat soket offline.
- **Layanan Push Notification Background (`PushNotificationService` - Phase 7.2 #2):** Membangun modul integrasi token FCM ke endpoint backend `POST /notifications/register-token` dan handler pesan background yang membuka layar persetujuan atribut secara langsung.
- **Eliminasi Total Simulasi In-App `triggerMerchantSimulation` (Phase 7.2 #3 & F-15b):**
  - Menghapus method `triggerMerchantSimulation` 100% dari `VerificationController`.
  - Menghapus tombol shortcut simulasi dari `dynamic_qr_screen.dart` dan menggantikannya dengan kartu status koneksi WebSocket real-time dan listener navigasi otomatis ke `ConsentRequestScreen`.
  - Menghapus pemanggilan simulasi dari `tab_home.dart:638` dan `tab_explore.dart:257`, mengalihkannya untuk menampilkan Dynamic QR kepada merchant asli.
  - Check Reality Guard CI `F-15b` dan Check 6 kini berstatus **HIJAU** (0 hit grep di seluruh `lib/`).
- **Alat Penguji Merchant Standalone (`tools/merchant_sim/merchant_sim.dart` - Phase 7.3):** Membangun CLI eksternal independen yang berperan sebagai terminal pemindai merchant: memvalidasi struktur QR dan signature secp256k1, mengirimkan `POST /verification/requests` ke server, dan memantau status persetujuan wisatawan secara real-time melalui jaringan.
- **Sanitasi Silent Catch & Integritas Reality Guard (Golden Rule R1):** Membersihkan seluruh catch yang hanya memuat `developer.log` di seluruh basis kode `lib/`. `bash tools/reality_guard.sh` kini **HIJAU 100% (Seluruh 12 aturan lolos)**.
- **Pengujian Unit, Integrasi & Chaos L1/L2/L3 (Phase 7.4):** Dibuat 13 pengujian komprehensif di `test/phase7_merchant_handshake_test.dart` (validasi signature/exp, websocket subscription, event streaming, filtering duplikat/expired, HTTP sync fallback, chaos disconnect backoff, registrasi push, dan end-to-end handshake flow). Total pengujian aktif seluruh proyek kini **170/170 lulus 100% (0 failed)**.
- **Status Akhir Phase 7:** Selesai 100%. Siap melangkah ke Phase 8 (NFC Chip Read & Passive Authentication).
