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
| Phase 5A | Mesin OCR MRZ Paspor Nyata (Google ML Kit Text Recognition) | 6-8 h | ⬜ Belum | F-01, F-19 (eliminasi MobileScanner & bypass demo). |
| Phase 5B | Penerbitan BTID Otoritatif & Sanitasi Data Identitas | 4 h | ⬜ Belum | F-08, F-11, F-11b, F-13, F-13b (eliminasi BTID/DOB statis). |
| Phase 6 | Parser Standar QRIS EMVCo TLV & Validasi CRC16-CCITT | 4-5 h | ⬜ Belum | F-14, F-14b (eliminasi string match coffee/tour). |
| Phase 7 | Merchant Handshake Dua Arah Nyata (WebSocket/SSE + Push) | 7-9 h | ⬜ Belum | F-15, F-15b (eliminasi timer in-app simulation). |
| Phase 8 | Pembacaan Chip e-Passport NFC & Passive Authentication (PA) | 10-15 h | ⬜ Belum | F-17 (bergantung keputusan D-1). |
| Phase 9 | Pelabelan Eksplisit Simulasi Liveness Wajah | 1 h | ⬜ Belum | F-18 (satu-satunya dummy resmi, wajib berlabel SIMULASI). |
| Phase 10 | Pengujian Lapangan Lintas Level (L1-L4) & Reality Gate Final | +4 h | ⬜ Belum | Verifikasi HP fisik, receipt explorer, no mock claim. |

---

## 2. TABEL PELACAKAN TEMUAN (F-01 s/d F-24)

> Status Legend:  
> `⬜ Belum` | `🔄 Dalam pengerjaan` | `✅ Selesai` | `⏭️ Ditunda (alasan)`

| ID | Judul Singkat Masalah & Lokasi | Severity | Phase | Status | PR / Commit | Bukti & Catatan Baseline | Tanggal |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **F-01** | `MobileScanner` (barcode) dipakai untuk MRZ; `google_mlkit` tidak pernah dipanggil | Kritis | 5A | ⬜ Belum | - | Terverifikasi di `mrz_scanner_screen.dart:295`. ML Kit tidak diimpor sama sekali di `lib/`. | 2026-11-17 |
| **F-02** | `.env` berisi `127.0.0.1` dikemas ke bundle asset APK rilis | Kritis | 1 | ✅ Selesai | Branch `fix/real-behavior` | `.env` dihapus dari assets & `.gitignore`, dependensi `flutter_dotenv` dibuang, migrasi ke `AppConfig`. | 2026-11-17 |
| **F-03** | Fallback hash keccak256 palsu saat pembayaran Tourist Levy via wallet gagal | Kritis | 3 | ✅ Selesai | Branch `fix/real-behavior` | Dieliminasi dari `payment_controller.dart`. Transaksi wajib on-chain dengan receipt status 1. | 2026-11-18 |
| **F-03b** | Jalur Visa/Counter QR di `payment_controller.dart` juga memproduksi hash keccak256 palsu | Kritis | 3 | ✅ Selesai | Branch `fix/real-behavior` | Dieliminasi dari `payment_controller.dart`. Metode non-wallet ditolak via ValidationFailure. | 2026-11-18 |
| **F-04** | Fallback hash keccak256 palsu saat pembayaran QRIS merchant via wallet gagal | Kritis | 3 | ✅ Selesai | Branch `fix/real-behavior` | Dieliminasi dari `payment_controller.dart`. Intent dikelola TxStateMachine dan diverifikasi on-chain. | 2026-11-18 |
| **F-05** | Consent submit ditelan `catch`, otomatis disimpan status "Approved" lokal | Tinggi | 4 | ✅ Selesai | Branch `fix/real-behavior` | Dieliminasi dari `verification_transaction_service.dart`. Approval wajib ack 2xx Fastify, error dilempar sebagai AppFailure. | 2026-11-18 |
| **F-06** | Revocation akses ditelan `catch`, otomatis disimpan status "Revoked" lokal | Tinggi | 4 | ✅ Selesai | Branch `fix/real-behavior` | Pencabutan dialihkan ke Outbox saat offline dengan status pending_sync dan peringatan merchant access jelas. | 2026-11-18 |
| **F-07** | Audit finansial levy & QRIS ditelan `catch` hanya dengan `developer.log` | Tinggi | 4 | ✅ Selesai | Branch `fix/real-behavior` | Audit levy & QRIS dialihkan ke Outbox saat offline dengan status pending_sync (R7). | 2026-11-18 |
| **F-08** | Audit penerbitan BTID ditelan `catch`, kartu tetap terbit dengan hash keccak palsu | Tinggi | 5B | ⬜ Belum | - | Terverifikasi di `verification_transaction_service.dart:382,410`. | 2026-11-17 |
| **F-09** | Saldo default `Rp 2.480.000` di `levy_payment_screen.dart` | Tinggi | 3 | ✅ Selesai | Branch `fix/real-behavior` | Dieliminasi, bermigrasi ke single-source idrtBalanceFormattedProvider. | 2026-11-18 |
| **F-09b** | Saldo default `Rp 2.480.000` di `tab_home.dart` dan `qris_payment_screen.dart` | Tinggi | 3 | ✅ Selesai | Branch `fix/real-behavior` | Dieliminasi dari seluruh file, nol hit grep di seluruh repo. | 2026-11-18 |
| **F-10** | Hash statis kuitansi `0x7b2f8a1e...` di `levy_payment_screen.dart` | Sedang | 3 | ✅ Selesai | Branch `fix/real-behavior` | Dieliminasi, digantikan hash on-chain riil dari state BtidCredentialModel/LevyReceiptData. | 2026-11-18 |
| **F-10b** | Hash statis kuitansi `0x7b2f8a1e...` di `tab_home.dart` dan `tab_profile.dart` | Sedang | 3 | ✅ Selesai | Branch `fix/real-behavior` | Dieliminasi dari dashboard dan profil, nol hit grep di seluruh repo. | 2026-11-18 |
| **F-11** | Nomor BTID statis `BTID-2026-4471-0938` di `btid_issued_screen.dart` | Tinggi | 5B | ⬜ Belum | - | Terverifikasi di `btid_issued_screen.dart:66`. | 2026-11-17 |
| **F-11b** | Nomor BTID statis tersebar di 8 file tambahan (model deserializer, controller, screens) | Tinggi | 5B | ⬜ Belum | - | Terverifikasi 14 hit di 10 file (termasuk `btid_credential_model.dart:98,119`). | 2026-11-17 |
| **F-12** | Actor `James Wilson` di 5 lokasi service audit | Tinggi | 4/5B | ✅ Selesai | Branch `fix/real-behavior` | ActorRef salted hash (zero-PII D-8) menggantikan literal James Wilson di seluruh service audit. | 2026-11-18 |
| **F-12b** | `James Wilson` tertanam di DTO model, factory MRZ parser, dan UI screens | Tinggi | 5B | ✅ Selesai | Branch `fix/real-behavior` | James Wilson dieliminasi 100% dari seluruh `lib/` (grep: 0 hit). demoJamesWilson dipindah ke test/fixtures/. | 2026-11-18 |
| **F-13** | Default imigrasi (DOB, expiry, visaType) di `btid_issued_screen.dart` | Tinggi | 5B | ⬜ Belum | - | Terverifikasi di `btid_issued_screen.dart:72-76`. | 2026-11-17 |
| **F-13b** | Default imigrasi (`1988-04-12`, `2031-08-15`, `e-VOA B1`) tertanam di DTO model | Tinggi | 5B | ⬜ Belum | - | Terverifikasi di `btid_credential_model.dart:102-104,123-125`. | 2026-11-17 |
| **F-14** | Parser QRIS EMVCo TLV tidak ada; string match 'coffee'/'tour'/MCH di `tab_pay.dart` | Tinggi | 6 | ⬜ Belum | - | Terverifikasi di `tab_pay.dart:25,53,69`. | 2026-11-17 |
| **F-14b** | Duplikasi logika string match di `qr_scanner_screen.dart` & `policy_matrix_constants` | Tinggi | 6 | ⬜ Belum | - | Terverifikasi di `qr_scanner_screen.dart:51,79,95`. | 2026-11-17 |
| **F-15** | Handshake merchant hanya simulasi in-app berbasis delay timer | Tinggi | 7 | ⬜ Belum | - | Terverifikasi di `verification_controller.dart:148`. Tidak ada koneksi transport. | 2026-11-17 |
| **F-15b** | Pemanggilan `triggerMerchantSimulation` tersebar di 3 lokasi UI | Tinggi | 7 | ⬜ Belum | - | Terverifikasi di `tab_home.dart:633`, `tab_explore.dart:257`, `dynamic_qr_screen.dart:31`. | 2026-11-17 |
| **F-16** | 43 test suite lulus hanya unit test + `MockClient` (ilusi coverage) | Tinggi | 10 | ⬜ Belum | - | Terverifikasi: 43 unit test lulus via MockClient tanpa pengujian RPC/server nyata. | 2026-11-17 |
| **F-17** | Modul pembacaan chip NFC & Passive Authentication hanya simulasi timer | Sedang | 8 | ⬜ Belum | - | Terverifikasi di `passport_verification_flow_screen.dart:102,420`. | 2026-11-17 |
| **F-18** | Liveness wajah dummy skor 98.7% tanpa label simulasi | Rendah | 9 | ⬜ Belum | - | Terverifikasi di `passport_verification_flow_screen.dart:790` (MATCH SCORE: 98.7%). | 2026-11-17 |
| **F-19** | Tombol "Fast Demo Mode" di welcome screen & factory `demoJamesWilson()` di `lib/` | Kritis | 0/5A | ⬜ Belum | - | Terverifikasi di `welcome_screen.dart:225-248` & `mrz_parser.dart:58`. | 2026-11-17 |
| **F-20** | Alamat loopback `127.0.0.1` hardcoded langsung di kode Dart (bukan hanya .env) | Kritis | 1 | ✅ Selesai | Branch `fix/real-behavior` | Dieliminasi dari `blockchain_config.dart`, `graphql_provider.dart`, `payment_controller.dart`. Check 7 Reality Guard lolos hijau. | 2026-11-17 |
| **F-21** | Blok `catch (_) {}` kosong total tanpa logging ditemukan di 14 titik | Tinggi | 2/3/4 | ✅ Selesai | Branch `fix/real-behavior` | Seluruh blok catch kosong di `lib/` telah disanitasi 100% (grep: 0 hit). Check Reality Guard hijau. | 2026-11-18 |
| **F-22** | Android Manifest tidak mendeklarasikan izin `CAMERA` & `NFC` di manifest utama | Tinggi | 1/5A/8 | 🔄 Parsial (Manifest) | Branch `fix/real-behavior` | Izin `CAMERA` & `NFC` ditambahkan ke `AndroidManifest.xml` utama; security config cleartext debug ditambahkan. | 2026-11-17 |
| **F-23** | Dependensi `camera` tidak terpasang di `pubspec.yaml` untuk frame OCR ML Kit | Kritis | 5A | ⬜ Belum | - | Terverifikasi di `pubspec.lock`: `camera: NOT INSTALLED`. | 2026-11-17 |
| **F-24** | Tombol quick test di `send_scanner_screen.dart` memuat fixture JSON merchant statis | Sedang | 6 | ⬜ Belum | - | Terverifikasi di `send_scanner_screen.dart:143,186`. | 2026-11-17 |

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
