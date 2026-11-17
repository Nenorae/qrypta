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
| Phase 1 | Konfigurasi Dinamis & Sanitasi Jaringan (.env & Dart loopback) | 3-4 h | ⬜ Belum | F-02, F-20, migrasi ke `AppConfig`, hapus `.env` dari assets. |
| Phase 2 | Fondasi Arsitektur (AppFailure, Tx State Machine, Hive Outbox) | 3 h | ⬜ Belum | Penghentian silent swallow, outbox sync offline. |
| Phase 3 | Transaksi Finansial Nyata (Tourist Levy ERC-20 & QRIS IDRT) | 5-6 h | ⬜ Belum | F-03, F-03b, F-04, F-09, F-09b, F-10, F-10b. |
| Phase 4 | Consent, Revocation & Financial Audit Nyata | 5 h | ⬜ Belum | F-05, F-06, F-07, F-12, F-12b, sanitasi 'James Wilson'. |
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
| **F-02** | `.env` berisi `127.0.0.1` dikemas ke bundle asset APK rilis | Kritis | 1 | ⬜ Belum | - | Terverifikasi di `pubspec.yaml:68` dan `.env:2,4,7`. | 2026-11-17 |
| **F-03** | Fallback hash keccak256 palsu saat pembayaran Tourist Levy via wallet gagal | Kritis | 3 | ⬜ Belum | - | Terverifikasi di `payment_controller.dart:210-212`. Hash dibuat dari seed lokal. | 2026-11-17 |
| **F-03b** | Jalur Visa/Counter QR di `payment_controller.dart` juga memproduksi hash keccak256 palsu | Kritis | 3 | ⬜ Belum | - | Terverifikasi di `payment_controller.dart:217-219`. Blok `else` bypass tanpa PJP nyata. | 2026-11-17 |
| **F-04** | Fallback hash keccak256 palsu saat pembayaran QRIS merchant via wallet gagal | Kritis | 3 | ⬜ Belum | - | Terverifikasi di `payment_controller.dart:346-348`. Rekayasa hash saat RPC Besu mati. | 2026-11-17 |
| **F-05** | Consent submit ditelan `catch`, otomatis disimpan status "Approved" lokal | Tinggi | 4 | ⬜ Belum | - | Terverifikasi di `verification_transaction_service.dart:143-161`. | 2026-11-17 |
| **F-06** | Revocation akses ditelan `catch`, otomatis disimpan status "Revoked" lokal | Tinggi | 4 | ⬜ Belum | - | Terverifikasi di `verification_transaction_service.dart:226-239`. | 2026-11-17 |
| **F-07** | Audit finansial levy & QRIS ditelan `catch` hanya dengan `developer.log` | Tinggi | 4 | ⬜ Belum | - | Terverifikasi di `verification_transaction_service.dart:287,352`. | 2026-11-17 |
| **F-08** | Audit penerbitan BTID ditelan `catch`, kartu tetap terbit dengan hash keccak palsu | Tinggi | 5B | ⬜ Belum | - | Terverifikasi di `verification_transaction_service.dart:382,410`. | 2026-11-17 |
| **F-09** | Saldo default `Rp 2.480.000` di `levy_payment_screen.dart` | Tinggi | 3 | ⬜ Belum | - | Terverifikasi di `levy_payment_screen.dart:36`. | 2026-11-17 |
| **F-09b** | Saldo default `Rp 2.480.000` di `tab_home.dart` dan `qris_payment_screen.dart` | Tinggi | 3 | ⬜ Belum | - | Terverifikasi di `tab_home.dart:48` dan `qris_payment_screen.dart:54`. | 2026-11-17 |
| **F-10** | Hash statis kuitansi `0x7b2f8a1e...` di `levy_payment_screen.dart` | Sedang | 3 | ⬜ Belum | - | Terverifikasi di `levy_payment_screen.dart:535`. | 2026-11-17 |
| **F-10b** | Hash statis kuitansi `0x7b2f8a1e...` di `tab_home.dart` dan `tab_profile.dart` | Sedang | 3 | ⬜ Belum | - | Terverifikasi di `tab_home.dart:509` dan `tab_profile.dart:87`. | 2026-11-17 |
| **F-11** | Nomor BTID statis `BTID-2026-4471-0938` di `btid_issued_screen.dart` | Tinggi | 5B | ⬜ Belum | - | Terverifikasi di `btid_issued_screen.dart:66`. | 2026-11-17 |
| **F-11b** | Nomor BTID statis tersebar di 8 file tambahan (model deserializer, controller, screens) | Tinggi | 5B | ⬜ Belum | - | Terverifikasi 14 hit di 10 file (termasuk `btid_credential_model.dart:98,119`). | 2026-11-17 |
| **F-12** | Actor `James Wilson` di 5 lokasi service audit | Tinggi | 4/5B | ⬜ Belum | - | Terverifikasi di `verification_transaction_service.dart:234,266,295,328,360`. | 2026-11-17 |
| **F-12b** | `James Wilson` tertanam di DTO model, factory MRZ parser, dan UI screens | Tinggi | 5B | ⬜ Belum | - | Terverifikasi 23 hit di 10 file (`btid_credential_model.dart`, `mrz_parser.dart`, dll). | 2026-11-17 |
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
| **F-20** | Alamat loopback `127.0.0.1` hardcoded langsung di kode Dart (bukan hanya .env) | Kritis | 1 | ⬜ Belum | - | Terverifikasi di `blockchain_config.dart:7,23` dan `graphql_provider.dart:7-8`. | 2026-11-17 |
| **F-21** | Blok `catch (_) {}` kosong total tanpa logging ditemukan di 14 titik | Tinggi | 2/3/4 | ⬜ Belum | - | Terverifikasi: 14 titik di `payment_controller`, `transaction_service`, dll. | 2026-11-17 |
| **F-22** | Android Manifest tidak mendeklarasikan izin `CAMERA` & `NFC` di manifest utama | Tinggi | 1/5A/8 | ⬜ Belum | - | Terverifikasi di `android/app/src/main/AndroidManifest.xml` (hanya `INTERNET`). | 2026-11-17 |
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
