# RENCANA KERJA: ELIMINASI FALLBACK PALSU & PENGUJIAN KONDISI NYATA
**Proyek:** Qrypta & Bali Tourist ID
**Sumber temuan:** `AUDIT_TEMUAN_KESALAHAN_DAN_FALLBACK_PALSU.md`
**Tanggal rencana:** 17 November 2026

---

## 0. RINGKASAN & RUANG LINGKUP

### 0.1 Tujuan
Mengubah aplikasi dari prototipe yang "terlihat berhasil" menjadi aplikasi yang **hanya menyatakan sukses jika sukses benar-benar terjadi** (on-chain, di server, atau di perangkat), dan **menyatakan gagal secara transparan** jika tidak.

### 0.2 Yang tetap DUMMY (satu-satunya, dan harus berlabel jelas)
| Modul | Status | Syarat |
| :--- | :--- | :--- |
| Face recognition / Liveness (`ScrLiveness`, skor 98.7%) | **DUMMY** | Wajib berlabel "SIMULASI" di UI, dicatat sebagai `liveness: SIMULATED` di kredensial/audit, tidak boleh dihitung sebagai verifikasi biometrik sungguhan. |

### 0.3 Yang menjadi ASLI (semua selain di atas)
OCR MRZ paspor, konfigurasi jaringan, transfer ERC-20 (levy & QRIS), saldo dompet, kuitansi, audit/consent/revocation, penerbitan BTID, data identitas/imigrasi, parser QRIS EMVCo, handshake merchant dua arah, dan (sesuai instruksi "yang lainnya asli") NFC chip read + Passive Authentication.

### 0.4 Batasan dokumen ini
Rencana ini disusun dari **membaca file audit saja**. Path file, nomor baris, dan nama class dikutip dari audit dan **belum diverifikasi ke repo**. Karena itu Phase 0 wajib mereproduksi setiap temuan sebelum perbaikan dimulai.

---

## 1. ASUMSI & KEPUTUSAN TERBUKA

Keputusan ini mengubah desain. Berikan jawaban sebelum fase terkait dimulai.

| ID | Pertanyaan | Asumsi default rencana ini | Dibutuhkan sebelum |
| :--- | :--- | :--- | :--- |
| D-1 | NFC & Passive Authentication: real atau tetap dummy? Audit §7 menyebut dummy "sesuai ketetapan", instruksi terbaru menyebut hanya wajah yang dummy. | **Real** (Phase 8). Bisa ditunda tanpa memblokir fase lain. | Phase 8 |
| D-2 | Sumber `visaType` dan `stayExpiry` (tidak ada di paspor). | Diambil dari backend e-VOA/imigrasi via API. Jika backend belum ada, input pengguna berlabel "self-declared". | Phase 5 |
| D-3 | Bagaimana `levyRef` terikat ke transaksi on-chain (ERC-20 `transfer` tidak punya memo). | Rekonsiliasi server: app POST `txHash`, server verifikasi on-chain lalu menandai *Paid*. | Phase 3 |
| D-4 | Pemetaan QRIS asli (NMID) ke wallet merchant, dan jalur settlement. | Resolver backend `NMID -> wallet`. Merchant belum terdaftar = error jelas, bukan sukses palsu. | Phase 6 |
| D-5 | Transport handshake merchant: WebSocket/SSE, FCM, atau polling. | WebSocket/SSE saat foreground + FCM untuk background + polling sebagai cadangan transport. | Phase 7 |
| D-6 | Hosting staging/prod: domain, TLS, tunnel/VPS. | Reverse proxy TLS (Caddy/nginx) di VPS atau Cloudflare Tunnel. | Phase 1 |
| D-7 | Parameter chain: konsensus (QBFT/IBFT2/Clique), `decimals()` IDRT, kebijakan gas (min-gas-price 0 atau tidak). | Dibaca langsung dari chain pada Phase 1, tidak di-hardcode. | Phase 3 |
| D-8 | Data pribadi di audit: nama lengkap boleh tampil plaintext? | Tidak. Gunakan wallet/DID + hash bergaram. | Phase 4 |
| D-9 | Platform target: Android saja atau iOS juga (NFC iOS butuh entitlement). | Android dulu. | Phase 8 |

---

## 2. ATURAN WAJIB (GOLDEN RULES)

Aturan ini ditegakkan lewat code review **dan** CI (lihat Phase 0.4).

| # | Aturan |
| :--- | :--- |
| R1 | **Tidak ada `catch` yang menelan error.** Setiap `catch` harus (a) melempar `AppFailure` bertipe, atau (b) memasukkan pekerjaan ke *outbox* dengan status terlihat di UI. Hanya `developer.log` = dilarang. |
| R2 | **Sukses hanya setelah konfirmasi otoritatif:** receipt on-chain `status=1` untuk transfer, ack server untuk consent/revocation/BTID. |
| R3 | **Tidak ada nilai literal identitas/keuangan di `lib/`:** tanpa `James Wilson`, `BTID-2026-4471-0938`, `Rp 2.480.000`, hash statis, DOB statis. |
| R4 | **Dummy hanya untuk liveness wajah**, wajib berlabel eksplisit dan tercatat sebagai simulasi. |
| R5 | **Build release menolak start** jika konfigurasi berisi loopback/localhost/`10.0.2.2` atau skema bukan HTTPS (kecuali flavor dev). |
| R6 | **Mock hanya boleh di test level L1.** Klaim "test lulus" wajib menyebut levelnya (unit / integrasi / E2E perangkat). |
| R7 | **Status lokal dan status otoritatif harus dibedakan** (`local_only`, `pending_sync`, `synced`, `rejected`). Kondisi `pending_sync` tidak boleh tampil sebagai "Approved/Paid/Anchored". |
| R8 | **Fitur simulasi in-app (`triggerMerchantSimulation`, dsb.) tidak ada di build staging/prod.** Hanya di flavor dev. |
| R9 | **PII minimal:** tidak ada MRZ, foto paspor, atau nomor paspor mentah di log, repo, atau payload audit. |

---

## 3. INVENTARIS TEMUAN -> WORKSTREAM

| ID | Temuan (rujukan audit) | Severity | Phase |
| :--- | :--- | :--- | :--- |
| F-01 | `MobileScanner` (barcode) dipakai untuk MRZ; `google_mlkit_text_recognition` tidak pernah dipanggil (§1) | Kritis | 5A |
| F-02 | `.env` berisi `127.0.0.1` ikut dikemas ke APK rilis (§2) | Kritis | 1 |
| F-03 | Fallback hash keccak256 palsu pada pembayaran Tourist Levy via wallet (§3A.1) | Kritis | 3 |
| F-04 | Fallback hash palsu pada pembayaran QRIS via wallet (§3A.2) | Kritis | 3 |
| **F-03b** | **Metode pembayaran Visa/Counter QR di `payment_controller.dart` juga menghasilkan hash keccak256 palsu via `fallbackSeed` (jalur `else` yang tidak ada di audit §3A)** | **Kritis** | **3** |
| F-05 | Consent submit: `catch` lalu simpan "Approved" lokal (§3B.1) | Tinggi | 4 |
| F-06 | Revocation: `catch` lalu simpan "Revoked" lokal (§3B.2) | Tinggi | 4 |
| F-07 | Audit finansial levy & QRIS ditelan `catch` (§3B.3) | Tinggi | 4 |
| F-08 | Audit penerbitan BTID ditelan `catch`, kartu tetap tampil (§3C) | Tinggi | 5B |
| F-09 | Saldo default `Rp 2.480.000` di `levy_payment_screen.dart` (§3D.1) | Tinggi | 3 |
| **F-09b** | **Saldo default `Rp 2.480.000` JUGA ada di `tab_home.dart:48` dan `qris_payment_screen.dart:54` — dua file ini tidak disebut di audit §3D.1** | **Tinggi** | **3** |
| F-10 | Hash statis `0x7b2f8a1e...` pada viewer kuitansi di `levy_payment_screen.dart` (§3D.2) | Sedang | 3 |
| **F-10b** | **Hash statis yang sama `0x7b2f8a1e...` JUGA ada di `tab_home.dart:509` dan `tab_profile.dart:87` — dua file ini tidak disebut di audit §3D.2** | **Sedang** | **3** |
| F-11 | Nomor BTID statis `BTID-2026-4471-0938` di `btid_issued_screen.dart` (§4.1) | Tinggi | 5B |
| **F-11b** | **Literal `BTID-2026-4471-0938` juga ada sebagai default di `btid_credential_model.dart:fromJson` (baris 98,119), `verification_transaction_service.dart:72`, `verification_controller.dart:107`, `consent_request_screen.dart:139,192`, `dynamic_qr_screen.dart:45`, `privacy_audit_screen.dart:167`, `tab_home.dart:500`, `tab_profile.dart:29` — 8 file tambahan di luar yang disebutkan audit §4.1** | **Tinggi** | **5B** |
| F-12 | Actor `James Wilson` di 5 lokasi service audit (§4.2) | Tinggi | 4 / 5B |
| **F-12b** | **`James Wilson` JUGA ada di: `btid_credential_model.dart:fromJson` (baris 99,120 — default model deserialisasi), `audit_transaction_model.dart:fromJson` (baris 88 — default deserialisasi audit), `mrz_parser.dart:demoJamesWilson()` (factory data demo), `tab_home.dart:42,503`, `tab_profile.dart:28`, `consent_request_screen.dart:69,140,193`, `verification_controller.dart` — sumber tertanam jauh lebih dalam dari yang terdeteksi audit §4.2** | **Tinggi** | **5B / Phase 0** |
| F-13 | Default imigrasi: DOB, docExpiry, visaType, stayExpiry di `btid_issued_screen.dart` (§4.3) | Tinggi | 5B |
| **F-13b** | **Default imigrasi yang sama (`1988-04-12`, `2031-08-15`, `e-VOA B1`) juga ada di `btid_credential_model.dart:fromJson` (baris 102-104,123-125) dan `consent_request_screen.dart:99` — model data itu sendiri cacat, bukan hanya layar** | **Tinggi** | **5B** |
| F-14 | Parser QRIS EMVCo TLV + CRC tidak ada; hanya string-match "coffee"/"tour"/MCH-* (§5A) | Tinggi | 6 |
| **F-14b** | **Duplikasi logika yang sama ada di `qr_scanner_screen.dart` (file scanner terpisah dari `tab_pay.dart`) — keduanya harus diganti parser EMVCo** | **Tinggi** | **6** |
| F-15 | Handshake merchant hanya simulasi in-app, tanpa kanal real-time (§5B) | Tinggi | 7 |
| **F-15b** | **`triggerMerchantSimulation` dipanggil dari 3 tempat: `tab_home.dart:633`, `tab_explore.dart:257`, `dynamic_qr_screen.dart:31` — ketiganya harus dihapus dari build staging/prod (R8), bukan hanya dari satu layar** | **Tinggi** | **7** |
| F-16 | 43 test lulus hanya unit test + `MockClient` (§6) | Tinggi | 10 (lintas fase) |
| F-17 | NFC & Passive Authentication dummy (§7) | Sedang | 8 (bergantung D-1) |
| F-18 | Liveness wajah dummy tanpa label (§7) | Rendah | 9 (tetap dummy, diberi label) |
| **F-19** | **Tombol "Fast Demo Mode (James Wilson)" di `welcome_screen.dart:225-248` memanggil `MrzParseResult.demoJamesWilson()` dan melewati seluruh alur OCR — bypass onboarding yang sepenuhnya invisible di audit asli; harus dihapus dari build non-dev** | **Kritis** | **Phase 0 / 5A** |
| **F-20** | **Loopback `127.0.0.1` hardcoded langsung di kode Dart (`blockchain_config.dart:7,23` dan `graphql_provider.dart:7-8`) sebagai default fallback `?? 'http://127.0.0.1:...'` — terpisah dari masalah `.env` (F-02); bahkan setelah `.env` diperbaiki, kode Dart akan jatuh ke loopback jika key hilang** | **Kritis** | **1** |
| **F-21** | **`catch (_) {}` benar-benar kosong (tanpa log sama sekali) di `tab_pay.dart:50`, `qr_scanner_screen.dart:76`, `verification_controller.dart:122,281`, `payment_controller.dart:207,241,244,343,367,370`, `transaction_service.dart:253` — lebih banyak dari yang terdata di audit §3** | **Tinggi** | **2 / 3 / 4** |

**Temuan tambahan yang dicurigai dan harus dicek di Phase 0** (tidak disebut audit, tetapi umum terjadi pada gejala yang sama):
- Izin `INTERNET` mungkin hanya ada di manifest debug/profile, bukan manifest utama, sehingga APK rilis tidak bisa memakai jaringan sama sekali.
- Android memblokir *cleartext HTTP* pada target SDK modern. Konfigurasi `http://` di rilis akan gagal sekalipun IP-nya benar.
- `.env` sebagai asset Flutter bisa dibaca siapa pun lewat `unzip` APK; kunci/secret tidak boleh ada di sana.
- Aturan ProGuard `-dontwarn` untuk ML Kit dapat menyembunyikan class yang hilang. Ini baru terlihat saat runtime di build rilis.
- Data audit Hive lama yang dihasilkan jalur fallback sudah "tercemar" dan perlu ditandai atau dibuang.
- **[BARU] `MrzParseResult.demoJamesWilson()` adalah factory di `mrz_parser.dart` — keberadaannya di kode produksi (`lib/`) secara struktural mengundang pemakaian yang tidak sah selain di `welcome_screen.dart`. Harus dihapus atau dipindahkan ke `lib/src/flavors/dev/` atau paket test-only.**
- **[BARU] `policy_matrix_constants.dart` mendefinisikan `MCH-3311` dan `MCH-5520` sebagai data fixture merchant. Dengan hilangnya string-match di `tab_pay.dart`/`qr_scanner_screen.dart` (Phase 6), data ini harus dipindahkan ke seed staging, bukan tetap di kode produksi.**
- **[BARU] `blockchain_config.dart` dan `graphql_provider.dart` memuat `127.0.0.1` langsung sebagai string default Dart (bukan hanya dari `.env`), menjadikannya loopback ganda yang tidak ter-cover hanya dengan mengganti `.env`.**

---

## 4. PETA FASE, DEPENDENSI, ESTIMASI

Estimasi kasar dalam hari-orang (asumsi 1-2 developer + akses ke tim backend ezsign-core). Belum termasuk waktu tunggu perangkat/paspor.

```
Phase 0  Baseline, reproduksi, guard CI, environment uji ..... 2-3 h
   │
Phase 1  Konfigurasi & jaringan (F-02) ....................... 3-4 h
   │
Phase 2  Fondasi: error model, state machine, outbox ......... 3 h
   │
   ├── Phase 3  Transaksi keuangan (F-03,04,09,10) ........... 5-6 h
   ├── Phase 4  Consent/revocation/audit (F-05,06,07,12) ..... 5 h
   ├── Phase 5A OCR MRZ (F-01) ............................... 6-8 h   (independen dari 3/4)
   │      └── Phase 5B BTID & data identitas (F-08,11,12,13) . 4 h
   ├── Phase 6  Parser QRIS (F-14) ........................... 4-5 h
   ├── Phase 7  Handshake merchant (F-15) .................... 7-9 h   (butuh backend)
   └── Phase 8  NFC + Passive Auth (F-17) .................... 10-15 h (butuh D-1, paspor-e)
Phase 9  Pelabelan liveness dummy (F-18) ..................... 1 h
Phase 10 Program uji lintas fase + Reality Gate + dokumen .... berjalan paralel, +4 h penutup
```

Catatan urutan: Phase 5A (OCR) tidak bergantung jaringan sehingga boleh jalan paralel dengan Phase 1-2, tetapi pengujian end-to-end apa pun di HP fisik **memerlukan Phase 1 selesai**.

---

## 5. RINCIAN PER FASE

### PHASE 0: BASELINE, REPRODUKSI, GUARD CI

**Tujuan:** memastikan temuan audit benar di repo, dan membuat jaring pengaman agar regresi tidak bisa masuk lagi.

**0.1 Verifikasi temuan (1 hari)**
1. Checkout branch kerja `fix/real-behavior` dari main.
2. Untuk tiap F-xx, buka file/baris yang dirujuk audit, catat apakah masih akurat. Catat baris yang bergeser.
3. Reproduksi gejala di HP fisik dengan APK rilis saat ini (rekam layar): scan paspor tidak mendeteksi, pembayaran "sukses" tanpa tx di chain, saldo `Rp 2.480.000`.
4. Cek manifest: `android/app/src/main/AndroidManifest.xml` memuat `INTERNET`, `CAMERA`, dan (untuk Phase 8) `NFC`? Cek `android:usesCleartextTraffic` dan `networkSecurityConfig`.
5. Cek `pubspec.yaml`: versi `camera`, `google_mlkit_text_recognition`, `mobile_scanner`, `flutter_dotenv`, `web3dart`, `hive`. Catat versi terpasang.
6. Hasilkan **Daftar Pencarian Literal** (grep) untuk semua nilai palsu: `James Wilson`, `BTID-2026-4471-0938`, `2.480.000`, `0x7b2f8a1e`, `1988-04-12`, `2031-08-15`, `e-VOA B1`, `fallbackSeed`, `MCH-3311`, `MCH-5520`, `127.0.0.1`, `localhost`, `triggerMerchantSimulation`.
7. Cari semua `catch (` di `lib/` dan klasifikasikan: menelan error / mengubah ke failure / sah. Simpan sebagai `docs/audit/catch_inventory.md`.

**[TAMBAHAN 0.1 — wajib setelah grep awal]**
8. **Verifikasi cakupan literal palsu yang lebih luas dari yang disebutkan audit.** Grep berikut harus dijalankan dan hasilnya dicatat di `catch_inventory.md`:
   ```bash
   # Semua file yang mengandung literal palsu (termasuk yang tidak disebut audit)
   grep -rln "James Wilson\|BTID-2026-4471-0938\|1988-04-12\|2031-08-15\|e-VOA B1\|0x7b2f8a1e\|2\.480\.000\|fallbackSeed\|MCH-3311\|MCH-5520\|127\.0\.0\.1\|localhost\|triggerMerchantSimulation\|demoJamesWilson" lib/
   ```
   Verifikasi bahwa minimal file-file ini terkena (temuan aktual, bukan dugaan):
   - `lib/src/core/data/models/btid_credential_model.dart` — `fromJson` default James Wilson & BTID (F-11b, F-12b, F-13b)
   - `lib/src/core/data/models/audit_transaction_model.dart` — `fromJson` default James Wilson (F-12b)
   - `lib/src/core/utils/mrz_parser.dart` — factory `demoJamesWilson()` (F-19)
   - `lib/src/core/config/blockchain_config.dart` — loopback hardcoded di Dart (F-20)
   - `lib/src/core/graphql/graphql_provider.dart` — loopback hardcoded di Dart (F-20)
   - `lib/src/features/authentication/presentation/screens/welcome_screen.dart` — tombol "Fast Demo Mode" (F-19)
   - `lib/src/features/home/presentation/tabs/tab_home.dart` — saldo, hash, BTID, James Wilson (F-09b, F-10b, F-11b, F-12b)
   - `lib/src/features/home/presentation/tabs/tab_profile.dart` — hash statis, BTID default (F-10b, F-11b)
   - `lib/src/features/transaction/presentation/screens/qris_payment_screen.dart` — saldo default `Rp 2.480.000` (F-09b)
   - `lib/src/features/verification/presentation/screens/consent_request_screen.dart` — James Wilson & BTID fallback (F-11b, F-12b)
   - `lib/src/features/verification/presentation/screens/dynamic_qr_screen.dart` — BTID & `triggerMerchantSimulation` (F-11b, F-15b)
   - `lib/src/features/verification/presentation/screens/privacy_audit_screen.dart` — BTID fallback (F-11b)
   - `lib/src/features/verification/data/policy_matrix_constants.dart` — MCH-3311, MCH-5520 (F-14b)
   - `lib/src/features/qr_scanner/presentation/screens/qr_scanner_screen.dart` — string-match MCH duplikat dari `tab_pay.dart` (F-14b)
9. **Verifikasi `catch` kosong di luar yang terdata audit.** Tambahkan ke `catch_inventory.md`:
   ```bash
   grep -rn "catch (_) {}" lib/
   # Konfirmasi minimal: tab_pay.dart:50, qr_scanner_screen.dart:76,
   # verification_controller.dart:122,281, payment_controller.dart:207,241,244,343,367,370
   ```
10. **Verifikasi jalur payment Visa/Counter QR.** Buka `payment_controller.dart` sekitar baris 215-250 (blok `else` di method levy). Konfirmasi apakah ada jalur pembayaran selain wallet-ERC20 yang juga menghasilkan hash keccak256 palsu — ini adalah F-03b yang tidak ada di audit asli.
11. **Catat jumlah total temuan aktual** (F-01..F-21 + temuan baru jika ada) di `PROGRESS.md`.

**0.2 Pelacakan:** buat `docs/work/PROGRESS.md` berisi tabel F-01..F-18 dengan kolom: status, PR, bukti (tx hash/rekaman/log), tanggal.

**[TAMBAHAN 0.2 — tabel PROGRESS.md harus diperluas ke F-01..F-21]**
Tabel `PROGRESS.md` harus mencakup semua temuan baru hasil verifikasi di Phase 0.1. Template yang diperbarui:

```markdown
| ID    | Judul singkat                                               | Severity | Phase | Status        | PR/Commit | Bukti                     | Tanggal |
| :---- | :---------------------------------------------------------- | :------- | :---- | :------------ | :-------- | :------------------------ | :------ |
| F-01  | MobileScanner dipakai untuk MRZ                             | Kritis   | 5A    | ⬜ Belum      |           |                           |         |
| F-02  | .env loopback dikemas ke APK                                | Kritis   | 1     | ⬜ Belum      |           |                           |         |
| F-03  | Fallback hash keccak256 Levy                                | Kritis   | 3     | ⬜ Belum      |           |                           |         |
| F-03b | Jalur Visa/Counter QR juga hash palsu                       | Kritis   | 3     | ⬜ Belum      |           |                           |         |
| F-04  | Fallback hash keccak256 QRIS                                | Kritis   | 3     | ⬜ Belum      |           |                           |         |
| F-05  | Consent catch -> Approved lokal                             | Tinggi   | 4     | ⬜ Belum      |           |                           |         |
| F-06  | Revocation catch -> Revoked lokal                           | Tinggi   | 4     | ⬜ Belum      |           |                           |         |
| F-07  | Audit finansial ditelan catch                               | Tinggi   | 4     | ⬜ Belum      |           |                           |         |
| F-08  | Audit BTID ditelan catch, kartu tetap tampil                | Tinggi   | 5B    | ⬜ Belum      |           |                           |         |
| F-09  | Saldo Rp 2.480.000 di levy_payment_screen                   | Tinggi   | 3     | ⬜ Belum      |           |                           |         |
| F-09b | Saldo Rp 2.480.000 di tab_home & qris_payment_screen        | Tinggi   | 3     | ⬜ Belum      |           |                           |         |
| F-10  | Hash statis 0x7b2f8a1e di levy_payment_screen               | Sedang   | 3     | ⬜ Belum      |           |                           |         |
| F-10b | Hash statis 0x7b2f8a1e di tab_home & tab_profile            | Sedang   | 3     | ⬜ Belum      |           |                           |         |
| F-11  | BTID statis di btid_issued_screen                           | Tinggi   | 5B    | ⬜ Belum      |           |                           |         |
| F-11b | BTID statis di 8 file tambahan (model, controller, screens) | Tinggi   | 5B    | ⬜ Belum      |           |                           |         |
| F-12  | Actor James Wilson di 5 lokasi service                      | Tinggi   | 4/5B  | ⬜ Belum      |           |                           |         |
| F-12b | James Wilson di model data, MRZ parser, UI screens          | Tinggi   | 5B    | ⬜ Belum      |           |                           |         |
| F-13  | Default DOB/docExpiry/visaType di btid_issued_screen        | Tinggi   | 5B    | ⬜ Belum      |           |                           |         |
| F-13b | Default yang sama di btid_credential_model & consent_screen | Tinggi   | 5B    | ⬜ Belum      |           |                           |         |
| F-14  | QRIS string-match coffee/tour/MCH di tab_pay                | Tinggi   | 6     | ✅ Selesai    | 19 Nov    | Nenorae                   | PR #6   |
| F-14b | Duplikasi string-match di qr_scanner_screen & policy_matrix | Tinggi   | 6     | ✅ Selesai    | 19 Nov    | Nenorae                   | PR #6   |
| F-15  | Handshake merchant hanya simulasi in-app                    | Tinggi   | 7     | ⬜ Belum      |           |                           |         |
| F-15b | triggerMerchantSimulation di 3 titik panggilan              | Tinggi   | 7     | ⬜ Belum      |           |                           |         |
| F-16  | 43 test hanya unit + MockClient                             | Tinggi   | 10    | ⬜ Belum      |           |                           |         |
| F-17  | NFC & PA dummy                                              | Sedang   | 8     | ⬜ Belum      |           |                           |         |
| F-18  | Liveness dummy tanpa label                                  | Rendah   | 9     | ⬜ Belum      |           |                           |         |
| F-19  | Tombol Fast Demo Mode & demoJamesWilson() di lib/           | Kritis   | 0/5A  | ⬜ Belum      |           |                           |         |
| F-20  | Loopback 127.0.0.1 hardcoded di kode Dart                   | Kritis   | 1     | ⬜ Belum      |           |                           |         |
| F-21  | catch(_){} kosong di 10+ lokasi                             | Tinggi   | 2/3/4 | ⬜ Belum      |           |                           |         |
```
Status: `⬜ Belum` / `🔄 Dalam pengerjaan` / `✅ Selesai` / `⏭️ Ditunda (alasan)`

**0.3 Environment uji nyata (staging)**
- `docker-compose.staging.yml` berisi: Besu (chain uji tersendiri, ID berbeda dari prod), ezsign-core (Fastify), RabbitMQ/AMQP bila dipakai, GraphQL indexer bila dipakai, Postgres bila dipakai, reverse proxy TLS.
- Deploy token IDRT uji + akun uji ber-saldo (faucet script).
- Skrip `tools/seed_staging.sh`: deploy kontrak, mint IDRT, daftarkan merchant uji.
- Dua HP Android fisik minimal (satu low-end, satu mid/high) + satu "perangkat merchant" (HP/laptop) untuk Phase 7.

**0.4 Guard CI (wajib sebelum fase lain)**
Tambahkan job CI `reality-guard`:
```bash
#!/usr/bin/env bash
# tools/reality_guard.sh  -> gagalkan build jika ada pola terlarang di lib/
set -euo pipefail
FORBIDDEN='James Wilson|BTID-2026-4471-0938|2\.480\.000|0x7b2f8a1e|fallbackSeed|MCH-3311|MCH-5520|1988-04-12|2031-08-15'
if grep -rEn "$FORBIDDEN" lib/ ; then echo "Literal palsu ditemukan"; exit 1; fi
# keccak256 dipakai untuk membuat txHash di luar lapisan blockchain
if grep -rEn "txHash\s*=\s*'0x\\\$\{bytesToHex\(keccak256" lib/ ; then exit 1; fi
# catch kosong / hanya log
if grep -rEnz "catch \(\w+\) \{\s*(developer\.log\([^;]*\);)?\s*\}" lib/ ; then exit 1; fi
# loopback pada konfigurasi release
if grep -rEn "127\.0\.0\.1|localhost|10\.0\.2\.2" env/prod* env/staging* 2>/dev/null ; then exit 1; fi
echo "reality-guard OK"
```
Tambahkan lint Dart: aktifkan `avoid_catches_without_on_clauses`, `empty_catches`, `only_throw_errors`.

**[TAMBAHAN 0.4 — guard tambahan wajib]**
Tambahkan pola berikut ke `reality_guard.sh` untuk menutup gap yang tidak tercover guard asal:
```bash
# F-19: factory demo harus tidak ada di lib/ (hanya boleh di test/ atau flavor dev)
if grep -rEn "demoJamesWilson\(\)" lib/ ; then
  echo "[F-19] MrzParseResult.demoJamesWilson() ditemukan di lib/ — harus di flavor dev atau test saja"; exit 1
fi
# F-19: tombol fast demo / bypass harus tidak ada di lib/ (kecuali flutter const yang dicek flavor)
if grep -rEn "Fast Demo Mode|triggerMerchantSimulation" lib/ ; then
  echo "[F-19/F-15b] Tombol demo/simulasi ditemukan di lib/ tanpa guard flavor"; exit 1
fi
# F-20: loopback hardcoded di kode Dart (bukan hanya .env)
if grep -rEn "127\.0\.0\.1|localhost" lib/src/core/config/ lib/src/core/graphql/ 2>/dev/null ; then
  echo "[F-20] Loopback hardcoded di konfigurasi Dart"; exit 1
fi
# F-14b: string-match merchant primitif (bukan hanya di tab_pay, tapi juga qr_scanner_screen)
if grep -rEn "'coffee'|\"coffee\"|'tour'|\"tour\"|MCH-3311|MCH-5520" lib/src/features/ 2>/dev/null | grep -v "policy_matrix_constants\|test\|flavor" ; then
  echo "[F-14b] String-match merchant primitif ditemukan — harus diganti parser EMVCo"; exit 1
fi
# F-21: catch benar-benar kosong (catch (_) {}) — lebih ketat dari guard asal
if grep -rEn "catch \(_\) \{\}" lib/ ; then
  echo "[F-21] catch (_) {} kosong total ditemukan — harus melempar atau mencatat AppFailure"; exit 1
fi
# Tambahkan ke regex FORBIDDEN untuk e-VOA hardcoded
if grep -rEn "e-VOA B1" lib/ ; then
  echo "[F-13b] visaType hardcoded e-VOA B1 ditemukan"; exit 1
fi
echo "reality-guard-extended OK"
```

**Kriteria selesai Phase 0:** setiap F-xx terverifikasi/direproduksi, guard CI **merah** pada kode saat ini (membuktikan guard bekerja), staging stack berjalan dan bisa di-query dari HP lewat jaringan.

---

### PHASE 1: KONFIGURASI & JARINGAN (F-02)

**Masalah:** `.env` berisi `127.0.0.1`; `.env` ikut ke APK; kemungkinan `INTERNET` dan cleartext bermasalah.

**1.1 Ganti mekanisme konfigurasi**
1. Hapus `.env` dari daftar `assets:` di `pubspec.yaml`. Hapus dependensi `flutter_dotenv` jika tidak ada pemakai lain.
2. Buat `lib/src/core/config/app_config.dart`:
   ```dart
   class AppConfig {
     static const rpcUrl      = String.fromEnvironment('RPC_URL');
     static const chainId     = int.fromEnvironment('CHAIN_ID');
     static const graphqlUrl  = String.fromEnvironment('GRAPHQL_URL');
     static const ezsignUrl   = String.fromEnvironment('EZSIGN_API_URL');
     static const flavor      = String.fromEnvironment('FLAVOR'); // dev|staging|prod
     static const liveness    = String.fromEnvironment('LIVENESS_MODE', defaultValue: 'simulated');
   }
   ```
3. Buat `env/dev.json`, `env/staging.json`, `env/prod.json`. Build dengan:
   `flutter build apk --release --dart-define-from-file=env/staging.json`
4. Tambahkan ke `.gitignore` file env yang berisi alamat internal sensitif; commit hanya `env/*.example.json`.

**[TAMBAHAN 1.1 — F-20: hapus loopback dari kode Dart]**
5. **Hapus default loopback dari `blockchain_config.dart` dan `graphql_provider.dart`.** Saat ini keduanya memuat pola `dotenv.env['KEY'] ?? 'http://127.0.0.1:PORT'` yang membuat loopback sebagai fallback kode Dart — terpisah dari masalah `.env`. Setelah migrasi ke `AppConfig` (langkah 2 di atas), tidak ada `defaultValue` loopback yang boleh tersisa. Jika `String.fromEnvironment` kosong (`''`), `ConfigValidator` di langkah 1.2 harus menolak, **bukan** jatuh ke loopback.
   ```dart
   // SEBELUM (blockchain_config.dart) — HARUS DIHAPUS:
   dotenv.isInitialized ? (dotenv.env['RPC_URL'] ?? 'http://127.0.0.1:8545') : 'http://127.0.0.1:8545';
   
   // SESUDAH (via AppConfig):
   static String get rpcUrl {
     final url = AppConfig.rpcUrl;
     if (url.isEmpty) throw const MissingConfigException('RPC_URL');
     return url;
   }
   ```
6. **Hapus `flutter_dotenv` seluruhnya** setelah semua pemakai di kode (`blockchain_config.dart`, `graphql_provider.dart`, `payment_controller.dart` yang membaca `IDRT_CONTRACT_ADDRESS`, `IDRT_DECIMALS`, `CHAIN_ID`) dimigrasikan ke `AppConfig`. Lakukan grep untuk memastikan tidak ada sisa `dotenv.env[` di `lib/`.
7. File `blockchain_config.dart` dan `graphql_provider.dart` itu sendiri bisa dihapus (digabung ke `AppConfig`) atau direfaktor menjadi thin accessor tanpa hardcode apapun.

**1.2 `ConfigValidator` (menegakkan R5)**
- Dipanggil di `main()` sebelum `runApp`. Aturan:
  - Semua URL wajib terisi.
  - Untuk `staging`/`prod`: skema wajib `https`, host bukan loopback/privat (`127.*`, `localhost`, `10.0.2.2`, `0.0.0.0`), dan RPC wajib `wss`/`https`.
  - Untuk `dev`: `http` LAN diizinkan.
- Jika gagal: tampilkan layar error konfigurasi permanen (bukan crash senyap), log alasan.

**1.2b Health check saat startup & runtime**
- `NetworkHealthService` memeriksa: `GET {ezsign}/health`, JSON-RPC `eth_chainId` (harus sama dengan `AppConfig.chainId`), `eth_blockNumber`.
- Hasil dipublikasikan ke provider `networkStatusProvider` (online/degraded/offline per komponen). UI menampilkan banner jelas ("Blockchain tidak terjangkau").
- Tidak ada nilai default saat gagal; komponen yang down = fitur terkait dinonaktifkan dengan alasan.

**1.3 Android**
- `AndroidManifest.xml` utama: tambahkan `<uses-permission android:name="android.permission.INTERNET"/>` (jika belum ada di main), `CAMERA`, dan `NFC` (Phase 8).
- Tanpa `usesCleartextTraffic="true"` di rilis. Untuk dev LAN: `src/debug/res/xml/network_security_config.xml` yang hanya mengizinkan cleartext untuk host dev dan hanya aktif di debug.
- Pertimbangkan certificate pinning untuk host ezsign (opsional, catat sebagai hardening).

**1.4 Server / infrastruktur (koordinasi backend)**
- Besu: jangan membuka JSON-RPC mentah ke publik. Tempatkan di belakang reverse proxy TLS dengan allowlist/rate limit, atau akses via gateway ezsign-core. Atur `--rpc-http-host`, `--host-allowlist`, dan `--rpc-http-api` sesuai kebutuhan minimum.
- Pastikan firewall membuka hanya port proxy (443), bukan 8545/3000 mentah.
- Waktu server sinkron (NTP) karena QR dinamis dan token kedaluwarsa bergantung waktu.

**1.5 Pengujian Phase 1**
| Level | Uji |
| :--- | :--- |
| L1 | `ConfigValidator`: tabel kasus (loopback, http di prod, kosong, chainId 0) -> ditolak; konfigurasi valid -> lolos. |
| L2 | Health check terhadap staging nyata: semua hijau; matikan Besu -> status RPC merah, ezsign tetap hijau. |
| L4 | Pasang APK **rilis** di HP fisik via Wi-Fi dan via data seluler: banner online muncul, `eth_chainId` benar. |
| Inspeksi | `unzip -p app-release.apk 'assets/flutter_assets/*' | grep -E '127\.0\.0\.1|localhost'` harus kosong; `aapt dump permissions app-release.apk` memuat `INTERNET`. |

**Kriteria selesai:** APK rilis dari HP fisik benar-benar menjangkau Besu dan ezsign-core di staging, dan menolak start dengan konfigurasi loopback.

---

### PHASE 2: FONDASI (ERROR MODEL, STATE MACHINE, OUTBOX)

Dipakai oleh Phase 3, 4, 5B, 7. Kerjakan sekali, dengan baik.

**2.1 Taksonomi error (`AppFailure`)**
```dart
sealed class AppFailure implements Exception { final String message; const AppFailure(this.message); }
class NetworkUnreachable extends AppFailure { const NetworkUnreachable(super.m); }
class RequestTimeout extends AppFailure { const RequestTimeout(super.m); }
class ServerRejected extends AppFailure { final int status; final String? code; const ServerRejected(super.m, this.status, this.code); }
class RpcFailure extends AppFailure { final int? code; const RpcFailure(super.m, this.code); }
class InsufficientBalance extends AppFailure { const InsufficientBalance(super.m); }
class InsufficientGas extends AppFailure { const InsufficientGas(super.m); }
class ChainMismatch extends AppFailure { const ChainMismatch(super.m); }
class TxReverted extends AppFailure { final String txHash; const TxReverted(super.m, this.txHash); }
class TxPendingTimeout extends AppFailure { final String txHash; const TxPendingTimeout(super.m, this.txHash); }
class ValidationFailure extends AppFailure { const ValidationFailure(super.m); }
```
Semua pemanggilan HTTP/RPC dibungkus adapter yang memetakan `SocketException`, `TimeoutException`, `HandshakeException`, status HTTP, dan error JSON-RPC ke tipe di atas.

**2.2 State machine transaksi on-chain**
```
idle -> preparing -> signing -> broadcasting -> pending -> confirmed
                                      │             │
                                      └─> failed <──┘   (juga: reverted, timeout)
```
- **Intent record dipersist sebelum broadcast** (Hive): `intentId`, `kind`, `ref` (levyRef/payRef), `from`, `to`, `amount`, `nonce`, `txHash` (diisi setelah broadcast), `state`, `createdAt`.
- Saat app dibuka ulang, `TxRecoveryService` memproses semua intent `broadcasting|pending`: query `eth_getTransactionReceipt`, perbarui state. Mencegah transaksi terkirim tetapi UI tidak tahu (dan mencegah bayar dua kali).
- `confirmed` hanya jika receipt ada, `status == 0x1`, dan log `Transfer(from,to,value)` cocok dengan intent. Konfirmasi blok disesuaikan konsensus chain (D-7; QBFT/IBFT2 final seketika, Clique butuh beberapa blok).
- Polling receipt: interval 2 detik, batas 120 detik -> `TxPendingTimeout` (intent tetap `pending`, bukan dianggap gagal; user diberi tombol "Cek ulang").

**2.3 Outbox untuk pengiriman audit/consent ke server**
- Koleksi Hive `outbox`: `id` (UUID, juga sebagai `Idempotency-Key`), `type`, `payload`, `attempts`, `nextAttemptAt`, `status` (`pending|sent|rejected|needs_attention`), `lastError`.
- `OutboxWorker`: jalan saat app foreground, saat konektivitas pulih (`connectivity_plus`), dan periodik. Backoff eksponensial 5s -> 15m, maksimum N percobaan lalu `needs_attention`.
- Server wajib idempoten terhadap `Idempotency-Key` (koordinasi backend).
- Outbox **bukan fallback palsu**: statusnya tampil di UI sebagai `pending_sync`, dan tidak pernah ditampilkan sebagai berhasil sebelum ack server.

**2.4 Perubahan model audit & migrasi Hive**
- `AuditTransactionModel` ditambah: `syncStatus` (`local_only|pending_sync|synced|rejected`), `serverId`, `anchorTxHash?`, `lastError?`, `actorWallet`, `actorRef`.
- Naikkan versi adapter Hive. Migrasi: semua record lama ditandai `legacy_unverified` (tampil abu-abu "tidak terverifikasi") atau dibersihkan; tidak boleh ada yang tampil sebagai terverifikasi.
- `txHash` nullable. Record tanpa hash nyata tidak boleh punya status `Approved/Paid`.

**2.5 Pengujian Phase 2**
- L1: pemetaan exception -> `AppFailure` (tabel); transisi state machine (termasuk transisi ilegal ditolak); backoff outbox; migrasi Hive dari fixture data lama.
- L2: `TxRecoveryService` dengan Besu nyata: kirim tx, matikan app (simulasi) sebelum polling selesai, jalankan ulang -> state benar.

---

### PHASE 3: TRANSAKSI KEUANGAN (F-03, F-04, F-09, F-10)

**3.1 Hapus fallback hash palsu (F-03, F-04)**
1. Di `payment_controller.dart` hapus kedua blok `catch` yang membuat `fallbackSeed` + `keccak256`. Pastikan tidak ada jalur lain yang menghasilkan `txHash` bukan dari node.
2. Ganti dengan alur state machine Phase 2:
   - Validasi awal: `chainId` node == `AppConfig.chainId`, saldo IDRT >= nominal, saldo native cukup jika chain memerlukan gas (D-7), alamat tujuan valid (EIP-55 bila mixed-case).
   - Cegah ganda: tombol bayar dinonaktifkan saat intent aktif; cek apakah `levyRef` sudah punya intent `confirmed`/`pending`.
   - Tanda tangan **lokal** dengan kunci wallet yang disimpan aman (Android Keystore / `flutter_secure_storage`); broadcast raw tx lewat RPC.
   - Tunggu receipt + verifikasi log `Transfer`.
3. **Levy (D-3):** setelah `confirmed`, POST `/levy/{ref}/payments {txHash}` (dengan `Idempotency-Key`). Status **Paid** di UI hanya setelah server memverifikasi on-chain dan mengembalikan ack. Jika server tidak terjangkau tetapi tx sudah `confirmed`: tampilkan "Pembayaran terkonfirmasi di blockchain, pencatatan ke server tertunda" (via outbox), **bukan** "Paid".
4. **QRIS merchant:** alur sama; tujuan transfer diambil dari resolver merchant (Phase 6), bukan dari string-match.
5. Pesan sukses hijau ("successfully paid and anchored on-chain") hanya dirender dari state `confirmed` + (untuk levy) ack server.
6. Pesan error per `AppFailure` yang spesifik, plus aksi: "Coba lagi", "Cek status transaksi", "Hubungi bantuan" (menyertakan `intentId`).

**[TAMBAHAN 3.1 — F-03b: jalur pembayaran Visa/Counter QR juga menghasilkan hash palsu]**
7. **Audit dan hapus jalur `else` di method pembayaran levy** (`payment_controller.dart` sekitar baris 215–240). Jalur ini (selain ERC-20 wallet) menghasilkan `txHash` palsu via:
   ```dart
   // HARUS DIHAPUS — ini "metode simulasi kartu visa/counter QR"
   await Future.delayed(const Duration(milliseconds: 1400));
   final fallbackSeed = '$levyRef-card-${DateTime.now().millisecondsSinceEpoch}';
   txHash = '0x${bytesToHex(keccak256(utf8.encode(fallbackSeed)))}';
   ```
   Keputusan produk diperlukan: apakah pembayaran Visa/Counter QR akan didukung secara nyata (integrasi PJP/bank) atau dihapus seluruhnya dari UI? Sampai ada keputusan, **opsi ini harus dinonaktifkan** (tombol dibuang atau ditandai "Belum tersedia") dan tidak boleh menghasilkan status "Paid" apapun.
8. Lakukan grep untuk semua pola `keccak256(utf8.encode(` di `lib/` untuk memastikan tidak ada titik pembuatan hash palsu yang terlewat.

**3.2 Saldo nyata (F-09)**
- Hapus `String idrtBalanceFormatted = 'Rp 2.480.000'`.
- `idrtBalanceProvider` (AsyncValue): `balanceOf(wallet)` via RPC; ambil `decimals()` dari kontrak (jangan hardcode); format dengan `BigInt` (hindari `double`).
- State `loading` -> shimmer; `error` -> teks "Saldo tidak tersedia" + tombol *Coba lagi*; tombol Bayar **nonaktif** saat saldo belum diketahui.
- Segarkan saldo setelah transaksi `confirmed` dan saat app kembali ke foreground.

**[TAMBAHAN 3.2 — F-09b: saldo hardcoded di 2 file tambahan]**
- **`tab_home.dart:48`**: `String idrtBalance = 'Rp 2.480.000'` — tampil di dashboard utama. Harus dihubungkan ke `idrtBalanceProvider` yang sama, bukan nilai terpisah.
- **`qris_payment_screen.dart:54`**: `String idrtBalanceFormatted = 'Rp 2.480.000'` — tampil di layar pembayaran QRIS. Harus dari `idrtBalanceProvider`.
- **Strategi satu sumber:** `idrtBalanceProvider` adalah provider tunggal yang dikonsumsi oleh `tab_home.dart`, `levy_payment_screen.dart`, dan `qris_payment_screen.dart`. Tidak boleh ada deklarasi `String idrtBalance...` lokal yang statis di ketiga file ini.

**3.3 Kuitansi dari data nyata (F-10)**
- Hapus `txHash: '0x7b2f8a1e...'` di `levy_payment_screen.dart`.
- Viewer kuitansi memuat record berdasarkan `levyRef` dari Hive/server (`GET /levy/{ref}/receipt`): `txHash`, nominal, waktu, nomor blok, nomor kuitansi dari server.
- Jika data tidak ada: tampilkan "Kuitansi tidak tersedia" dengan opsi muat ulang, bukan kuitansi tiruan.
- Tampilkan tautan/ID transaksi yang bisa disalin; (opsional) link ke block explorer staging.

**[TAMBAHAN 3.3 — F-10b: hash statis yang sama di 2 file tambahan]**
- **`tab_home.dart:509`**: `txHash: '0x7b2f8a1e9c4d3b5a7e6f8a9b0c1d2e3f4a5b6c7d'` — dipasok ke widget ringkasan levy di dashboard. Harus diganti dengan data nyata dari `levyRef` (referensi levy yang aktif/terakhir dari `btidCredentialProvider` atau store lokal).
- **`tab_profile.dart:87`**: `txHash: '0x7b2f8a1e9c4d3b5a7e6f8a9b0c1d2e3f4a5b6c7d'` — tampil di profil. Alur yang sama.
- **Strategi:** widget kuitansi harus menerima `txHash` dari state nyata (lewat provider) dan menampilkan "belum tersedia" jika null, bukan menerima literal string. Grep untuk `0x7b2f8a1e` di seluruh `lib/` wajib hasilkan nol temuan setelah Phase 3 selesai.

**3.4 Pengujian Phase 3** (rincian lengkap di §6)
- L1: validasi alamat, format saldo BigInt, transisi state, tidak ada jalur `txHash` tanpa node.
- L2 (Besu nyata): bayar sukses -> saldo sumber turun & saldo tujuan naik sesuai nominal; transfer dengan saldo kurang -> `InsufficientBalance`; chainId salah -> `ChainMismatch`; kontrak revert -> `TxReverted`.
- L3 (chaos): matikan Besu saat `broadcasting` -> UI error, **tidak ada kuitansi, tidak ada status Paid**; hidupkan lagi -> recovery menyelesaikan atau menandai gagal.
- L4 (HP rilis): satu transaksi levy dan satu QRIS end-to-end, lalu verifikasi independen dengan `eth_getTransactionReceipt` (§6.5).

---

### PHASE 4: CONSENT, REVOCATION, AUDIT (F-05, F-06, F-07, F-12 bagian service)

**4.1 Consent submission (F-05)** (`verification_transaction_service.dart` ~baris 127-149)
- Hapus `catch` yang diam-diam membuat `AuditTransactionModel(... 'Approved')`.
- Alur baru:
  1. Pengguna menekan Setujui -> state `submitting`.
  2. POST consent ke middleware dengan `Idempotency-Key`. Hanya jika respons 2xx dan ada `serverId`/`consentId`, buat record `Approved` dengan `syncStatus = synced`.
  3. Jika gagal: tampilkan error, **permintaan verifikasi tetap pending** di layar (bisa coba lagi). Boleh diantrikan ke outbox hanya jika produk memutuskan consent boleh "diantre"; default: **tidak**, karena merchant tidak bisa mengakses data sebelum server menerima consent, jadi menampilkan "Approved" menyesatkan.
- `txHash`/`anchorTxHash` berasal dari respons server (jangkar on-chain asli), bukan digest lokal. Digest lokal boleh disimpan sebagai `payloadDigest` dengan nama yang jujur, tidak dipakai sebagai `txHash`.

**4.2 Revocation (F-06)** (~baris 220-228)
- Revocation lebih sensitif secara keamanan. Alur:
  1. POST revoke. Jika sukses -> `Revoked` + `synced`.
  2. Jika gagal: masukkan outbox dengan status UI **"Pencabutan belum terkirim. Merchant mungkin masih memiliki akses."** (merah/oranye), coba ulang otomatis, notifikasi lokal saat berhasil/gagal permanen. Tidak boleh tampil "Revoked" sebelum ack.
- Server mengirim event pencabutan ke merchant (verifikasi di Phase 7).

**4.3 Audit finansial (F-07)** (~baris 281-288, 346-354)
- Audit pembayaran adalah *pencatatan atas transaksi yang sudah nyata*. Karena transaksi on-chain-nya sah, pengiriman audit boleh lewat outbox, dengan syarat R7: status `pending_sync` tampil jelas, dan tidak disebut "audited/anchored" sebelum ack.
- Payload audit memuat `txHash` **nyata** (hasil Phase 3), `intentId`, nominal, `actorWallet`.

**4.4 Actor (F-12) - bagian service**
- Hapus semua literal `'James Wilson'` (baris ~234, 266, 295, 328, 360).
- Ubah signature: parameter `required ActorRef actor` (wallet + referensi/hash kredensial), diisi dari `holderProfileProvider` (sumber: kredensial yang diterbitkan Phase 5B). Tidak ada nilai default.
- Privasi (D-8): payload audit memuat `actorWallet` dan `actorRef` (hash bergaram), bukan nama lengkap plaintext, kecuali ada keputusan eksplisit.
- Jika kredensial belum ada saat audit dipanggil: lempar `ValidationFailure`, bukan memakai nama default.

**[TAMBAHAN 4.4 — F-12b: 'James Wilson' jauh lebih tersebar dari 5 lokasi audit]**
Hapus literal `'James Wilson'` dari **seluruh** lokasi berikut (verifikasi aktual dari grep):
- `verification_transaction_service.dart` baris ~234, 266, 295, 328, 360 (sudah diketahui audit)
- `verification_transaction_service.dart:156`: `approvedData['fullName']?.toString() ?? 'James Wilson'` — ini tidak disebut audit; hapus default, lempar `ValidationFailure` jika `fullName` null
- `btid_credential_model.dart:fromJson` (baris 99, 120): default James Wilson di deserialisasi JSON — **berbahaya karena setiap decode JSON yang field-nya hilang akan menghasilkan "James Wilson"**; hapus default, jadikan `fullName` nullable atau lempar `FormatException`
- `audit_transaction_model.dart:fromJson` (baris ~88): default James Wilson di deserialisasi audit — hapus, jadikan nullable
- `mrz_parser.dart`: hapus factory `demoJamesWilson()` dari `lib/` seluruhnya (atau pindahkan ke `test/fixtures/mrz_fixtures.dart`)
- `tab_home.dart:42,503`: `btidCred?.fullName ?? 'James Wilson'` — hapus default, tampilkan shimmer/placeholder jika null
- `tab_profile.dart:28`: sama
- `consent_request_screen.dart:69,140,193`: sama
- `welcome_screen.dart`: hapus tombol "Fast Demo Mode (James Wilson)" dari build non-dev (F-19)

**[TAMBAHAN 4.5 — F-21: catch kosong tambahan di luar yang terdata audit]**
Audit berikut tidak disebut di Phase 4 asli tapi harus dibenahi dalam workstream yang sama:
- `verification_controller.dart:122` — `catch (_) {}` kosong setelah `loadExistingSession`; tidak ada sinyal ke UI jika session gagal dimuat
- `verification_controller.dart:281` — `catch (_) {}` kosong, konteks tidak jelas tanpa membaca kode; harus diklasifikasikan dan diubah ke `AppFailure`
- `payment_controller.dart:207,241,244` — `catch (_) {}` kosong saat menunggu receipt transaksi; ini berbeda dari fallback hash (F-03) namun tetap menelan error `waitForTransactionReceipt`; harus diubah ke log bertipe atau penanganan `TxPendingTimeout`
- `transaction_service.dart:253` — `catch (_) {}` kosong dalam internal service
- `tab_pay.dart:50` dan `qr_scanner_screen.dart:76` — `catch (_) {}` saat decode JSON QR; jika JSON rusak hasilnya diabaikan total; harus melempar `ValidationFailure("QR tidak dapat di-decode")` yang terlihat di UI

**4.5 UI status sinkronisasi**
- Daftar riwayat audit menampilkan chip: `Synced` / `Menunggu sinkron` / `Ditolak server` / `Tidak terverifikasi (data lama)`.
- Halaman *Sync Center*: daftar outbox, tombol "Kirim ulang sekarang", detail error.

**4.6 Pengujian Phase 4**
- L1: pembentukan payload, pemetaan status, outbox idempoten.
- L2 (ezsign-core nyata): consent -> server menyimpan; revoke -> server menandai; verifikasi data di database server/GraphQL.
- L3 (chaos): matikan Fastify -> consent gagal terlihat, tidak ada record Approved; revoke -> outbox + banner; hidupkan Fastify -> outbox terkirim tepat satu kali (cek idempotensi dengan menyalakan/mematikan berulang saat kirim).
- L4: dua perangkat (Phase 7) memastikan merchant benar-benar kehilangan akses setelah revoke.

---

### PHASE 5A: OCR MRZ PASPOR ASLI (F-01)

**Tujuan:** kamera membaca dua baris MRZ TD3 (2 x 44 karakter) dari paspor fisik dan menghasilkan `MrzData` yang tervalidasi check digit.

**5A.1 Dependensi**
- Tambah/verifikasi: `camera`, `google_mlkit_text_recognition` (cek kompatibilitas versi terbaru dengan Flutter/AGP proyek; versi `^1.0.2` dari audit perlu diperiksa).
- `mobile_scanner` **tetap** untuk pemindai QR (tab pay), tetapi **dilepas dari `mrz_scanner_screen.dart`**.
- Izin kamera runtime (`permission_handler`) dengan penanganan *denied/permanently denied* yang jelas.

**[TAMBAHAN 5A.1 — F-19: hapus bypass onboarding sebelum OCR dianggap selesai]**
- **Hapus tombol "Fast Demo Mode (James Wilson)"** dari `welcome_screen.dart`. Ini bypass yang memakai `MrzParseResult.demoJamesWilson()` untuk melewati OCR sepenuhnya. Harus dihapus dari build staging/prod; jika diperlukan untuk dev, pindahkan ke layar `DevMenu` yang terkunci di belakang `AppConfig.flavor == 'dev'`.
- **Hapus atau relokasi factory `MrzParseResult.demoJamesWilson()`** dari `lib/src/core/utils/mrz_parser.dart`. Pindahkan ke `test/fixtures/mrz_fixtures.dart` sebagai helper test-only. Jika pindahan dilakukan, pastikan tidak ada impor `mrz_parser.dart` di `lib/` yang menggunakan factory ini — cek dengan grep.
- **Kriteria selesai Phase 5A sekarang mencakup:** tidak ada tombol "Fast Demo Mode" di build rilis/staging, `MrzParseResult.demoJamesWilson()` tidak ada di `lib/`, dan guard CI merah jika `demoJamesWilson` muncul di `lib/`.

**5A.2 Pipeline kamera -> teks**
1. `CameraController(camera, ResolutionPreset.high, enableAudio: false, imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888)`. Aktifkan autofokus kontinu, sediakan tombol senter.
2. `startImageStream`; **throttle** ~3-4 fps (proses 1 frame per ~250-300 ms, buang frame selama masih memproses, flag `_busy`).
3. Konversi `CameraImage -> InputImage` dengan metadata benar: `size`, `rotation` (dari `sensorOrientation` + orientasi perangkat), `format`, `bytesPerRow`. Kesalahan rotasi adalah penyebab umum OCR "tidak membaca apa-apa".
4. `TextRecognizer(script: TextRecognitionScript.latin)`; panggil `processImage`.
5. Tutup `TextRecognizer` dan hentikan stream di `dispose`; tangani lifecycle (pause/resume app).

**5A.3 Ekstraksi MRZ dari teks OCR** (`MrzExtractor`, class murni agar mudah diuji)
1. Kumpulkan semua baris dari `RecognizedText`, `toUpperCase()`, hapus spasi.
2. Kandidat baris 1: panjang 44 (toleransi 43-45 setelah pembersihan), diawali `P` + (`<` atau jenis dokumen) + kode negara 3 huruf. Baris 2: panjang 44.
3. Pilih pasangan baris berurutan secara vertikal (urut posisi `boundingBox`), baris 2 tepat di bawah baris 1.
4. **Koreksi karakter OCR berbasis tipe field** (bukan ganti buta):
   - Field angka (tanggal lahir, kedaluwarsa, check digit): `O->0, Q->0, D->0, I->1, L->1, B->8, S->5, Z->2, G->6`.
   - Field alfabet (kode negara, nama): `0->O, 1->I, 8->B, 5->S, 2->Z`.
   - Karakter pengisi `<` sering terbaca `K`, `C`, `(`, `«`, `‹`; koreksi hanya pada posisi pengisi/akhir nama dan **hanya diterima jika check digit lolos sesudahnya**.
5. **Validasi ICAO 9303** (wajib, sebagai penentu benar/tidak):
   ```dart
   int mrzCheck(String s) {
     const w = [7, 3, 1];
     var sum = 0;
     for (var i = 0; i < s.length; i++) {
       final c = s.codeUnitAt(i);
       final v = (c >= 48 && c <= 57) ? c - 48 : (c >= 65 && c <= 90) ? c - 55 : 0; // '<' = 0
       sum += v * w[i % 3];
     }
     return sum % 10;
   }
   ```
   Cek: nomor dokumen, tanggal lahir, tanggal kedaluwarsa, personal number (bila ada), dan composite check digit (posisi 44).
6. **Konsensus multi-frame:** terima hasil hanya jika (a) semua check digit lolos pada satu frame **dan** (b) hasil yang sama muncul pada minimal 2 frame berurutan dalam jendela 2 detik. Ini menekan salah baca langka yang kebetulan lolos.
7. Timeout 30 detik tanpa hasil -> tampilkan panduan (cahaya, jarak, hindari silau) dan tawarkan **input manual** (form nomor dokumen, tanggal lahir, kedaluwarsa dengan validasi check digit yang sama). Input manual adalah jalur nyata alternatif, bukan fallback palsu.

**5A.4 `MrzParser`**
- Audit `MrzParser.parse` yang ada (milestone3). Pastikan: validasi check digit sungguhan (bukan hanya parsing posisi), parsing nama (`SURNAME<<GIVEN<NAMES`), tanggal dengan inferensi abad yang benar (tanggal lahir: jika `yy` > tahun berjalan -> `19yy`, selain itu `20yy`; kedaluwarsa: `20yy`), penanganan kode negara khusus (mis. `D` untuk Jerman), jenis kelamin `M/F/<`.
- Output `MrzData` bersifat tak-null untuk field wajib (`documentNumber`, `dob`, `expiry`, `nationality`, `surname`, `givenNames`). Jika parsing gagal -> `ValidationFailure`, tidak pernah diisi default.

**5A.5 UI/UX**
- Overlay panduan berbentuk pita MRZ (rasio ~ 88 mm x 10 mm), area crop untuk ML Kit (meningkatkan akurasi & kecepatan).
- Umpan balik status: "Mencari MRZ...", "Terbaca sebagian...", "Berhasil".
- Tidak menyimpan frame ke disk, tidak mencatat teks MRZ di log (R9). Bersihkan buffer setelah selesai.

**5A.6 Release/R8**
- Tinjau aturan ProGuard `-dontwarn` dari `RELEASE_FIX_LOG.md`. Uji **build rilis** di HP fisik: OCR benar-benar berjalan (bukan hanya build sukses). Jika class hilang saat runtime, gunakan `-keep` yang tepat, bukan hanya `-dontwarn`.

**5A.7 Pengujian Phase 5A**
- L1: `mrzCheck` dengan vektor ICAO. Spesimen ICAO (Utopia) untuk fixture:
  ```
  P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<
  L898902C36UTO7408122F1204159ZE184226B<<<<<10
  ```
  Harapan: check digit nomor dokumen = 6, DOB = 2, kedaluwarsa = 9, personal number = 1, composite = 0 (verifikasi ulang manual terhadap dokumen ICAO 9303 saat menulis test).
- L1: kasus rusak (1 karakter salah, `<` terbaca `K`, spasi menyelip, panjang 43/45) -> dikoreksi atau ditolak sesuai aturan; **tidak pernah** menerima data dengan check digit salah.
- L2 (offline regression pada gambar nyata): kumpulan foto MRZ (cetakan spesimen + dokumen berizin) dijalankan lewat `TextRecognizer` di emulator/perangkat; metrik di §6.3.
- L4: matriks perangkat x kondisi cahaya x paspor (§6.3).

**Kriteria selesai:** paspor fisik di HP fisik (build rilis) terbaca dalam <= 5 detik pada >= 95% percobaan kondisi normal, **0 salah-terima** (field salah yang lolos).

---

### PHASE 5B: BTID & DATA IDENTITAS (F-08, F-11, F-12 bagian UI, F-13)

**5B.1 Penerbitan BTID nyata (F-11, F-08)** (`btid_issued_screen.dart` ~baris 66, 88-97)
- Hapus literal `btidNumber: 'BTID-2026-4471-0938'`.
- Nomor BTID **diterbitkan server** (otoritatif, unik, tidak bisa ditebak klien): `POST /credentials/btid` dengan:
  - `passportHash` = HMAC/SHA-256 bergaram dari (negara + nomor dokumen + DOB), **bukan** nomor mentah (R9),
  - `walletAddress`,
  - data imigrasi tervalidasi (5B.3),
  - `livenessMode: "SIMULATED"` (Phase 9),
  - `Idempotency-Key` = hash(passportHash + wallet) agar re-issue tidak menghasilkan BTID kedua.
- Respons: `btidNumber`, `issuedAt`, `expiresAt`, `anchorTxHash`, `credentialId`.
- **Kartu BTID hanya ditampilkan setelah respons sukses.** Hapus `catch` "Audit record dispatched with local fallback" (F-08). Jika backend offline: layar "Penerbitan belum dapat diselesaikan" + *Coba lagi* (tanpa kartu).
- Format nomor mengikuti keputusan backend (mis. `BTID-YYYY-<NNNN>-<NNNN>`); klien tidak membangun nomor sendiri.

**[TAMBAHAN 5B.1 — F-11b: BTID statis tertanam di model data, bukan hanya di layar]**
Literal `BTID-2026-4471-0938` ada di **8 lokasi tambahan** di luar `btid_issued_screen.dart`:
- **`btid_credential_model.dart:fromJson` (baris 98, 119)**: default deserialisasi dan constructor demo — jika server mengembalikan JSON tanpa `btidNumber`, model langsung terisi BTID palsu tanpa error. Hapus default; jadikan `btidNumber` required di `fromJson`, lempar `FormatException` jika tidak ada.
- **`verification_transaction_service.dart:72`**: `approvedData['btid']?.toString() ?? 'BTID-2026-4471-0938'` — hapus default; lempar `ValidationFailure` jika btid null
- **`verification_controller.dart:107`**: default BTID dalam state internal — hapus; state harus nullable sampai BTID diterbitkan server
- **`consent_request_screen.dart:139,192`**: payload consent menggunakan BTID default — hapus; lempar error jika BTID belum ada (pengguna harus menyelesaikan onboarding dulu)
- **`dynamic_qr_screen.dart:45`**: QR dinamis menggunakan BTID default — QR tidak boleh di-generate jika BTID null
- **`privacy_audit_screen.dart:167`**: BTID default di screen audit
- **`tab_home.dart:500`** dan **`tab_profile.dart:29`**: display default
- Strategi: `btidCredentialProvider` mengembalikan `null` jika belum ada BTID nyata. Semua konsumen harus menangani `null` dengan menampilkan state "Belum terdaftar" atau menonaktifkan aksi, bukan mengisi BTID palsu.

**5B.2 Penghapusan default data pribadi (F-13)**
- `dob` dan `docExpiry` **hanya** dari `MrzData`. Hapus fallback `'1988-04-12'` dan `'2031-08-15'`. Jika null -> alur kembali ke pemindaian (tidak boleh lanjut).
- Validasi: paspor belum kedaluwarsa (dan sisa masa berlaku sesuai aturan imigrasi, bila ada, mis. >= 6 bulan) -> jika tidak, tolak dengan pesan jelas.
- Nama = `givenNames + surname` dari MRZ.

**[TAMBAHAN 5B.2 — F-13b: default data pribadi juga tertanam di model data, bukan hanya di layar]**
- **`btid_credential_model.dart:fromJson` baris 102-104 dan 119-125**: `dob: ?? '1988-04-12'`, `docExpiry: ?? '2031-08-15'`, `visaType: ?? 'e-VOA B1'` — ini adalah **default di lapisan model/deserialisasi**, bukan hanya di UI. Jika backend mengirim respons tanpa field ini, model langsung terisi data James Wilson tanpa error apapun.
  - Hapus semua default ini dari `fromJson` dan `BtidCredentialModel.demo()` / constructor.
  - `dob` dan `docExpiry` harus `required` atau nullable-without-default; jika null dari JSON, lempar `FormatException`.
  - `visaType` nullable; konsumen menampilkan "Tidak diketahui" jika null — **bukan** `e-VOA B1`.
- **`consent_request_screen.dart:99`**: `cred?.visaType ?? 'e-VOA B1 Visit Visa'` — hapus default, tampilkan "Tidak tersedia" jika null.
- **Implikasi luas:** setelah `btid_credential_model.dart` dibenahi, lakukan grep untuk semua `BtidCredentialModel.fromJson(` dan pastikan pemanggil menangani exception, bukan membiarkan default palsu mengisi data.

**5B.3 Visa & masa tinggal (D-2)**
- Hapus `visaType: 'e-VOA B1'` dan hitungan flat `now.add(30 days)`.
- `visaType`, `stayExpiry` berasal dari `GET /immigration/evoa?passportHash=...` (backend). Tampilkan `stayExpiry` sebagai tanggal otoritatif dari server.
- Jika belum ada backend: input pengguna dengan label "diisi pengguna, belum diverifikasi" dan dicatat `source: "self_declared"` pada kredensial. Tidak boleh tampil sebagai data terverifikasi.

**5B.4 Actor dari identitas nyata (F-12 sisi UI)**
- Setelah BTID terbit, simpan `HolderProfile` (nama, wallet, `credentialId`, `actorRef`) di penyimpanan aman. `holderProfileProvider` menjadi satu-satunya sumber actor untuk Phase 4.

**5B.5 Pengujian Phase 5B**
- L1: pembentukan `passportHash` (deterministik, bergaram, tidak reversibel di payload); validasi tanggal; penolakan paspor kedaluwarsa.
- L2: terbitkan BTID untuk dua identitas berbeda -> dua nomor berbeda; terbitkan ulang identitas sama -> nomor sama (idempoten); matikan backend -> tidak ada kartu.
- L4: scan paspor nyata -> BTID menampilkan nama/DOB/kedaluwarsa **identik** dengan paspor fisik; cek bahwa nama di log audit adalah `actorRef`, bukan nama lain.
- Guard CI: tidak ada literal James Wilson di `lib/`.

---

### PHASE 6: PARSER QRIS EMVCo ASLI (F-14)

**Tujuan:** memindai stiker QRIS asli, mem-parsing TLV, memvalidasi CRC, dan merutekan pembayaran; menghapus string-match `coffee`/`tour`/`MCH-*`.

**6.1 Router payload QR** (`QrPayloadRouter`, class murni)
Urutan deteksi:
1. Diawali `000201` -> kandidat EMVCo/QRIS -> `QrisParser`.
2. Regex `^0x[0-9a-fA-F]{40}$` -> alamat wallet langsung (validasi checksum EIP-55 bila huruf campuran).
3. JSON dengan skema versi terdefinisi (`{"v":1,"type":...,"sig":...}`) -> QR native Qrypta, **dengan verifikasi tanda tangan**; bukan pencocokan kata kunci.
4. Selain itu -> `ValidationFailure("QR tidak dikenali")`. Tidak ada tebakan.

**6.2 `QrisParser`**
1. Parser TLV generik: `tag(2) + length(2) + value`, rekursif untuk tag template (26-51, 62, 64). Tolak jika panjang melewati batas string.
2. Validasi CRC: tag `63`, panjang `04`; CRC16/CCITT-FALSE (poly `0x1021`, init `0xFFFF`) atas seluruh string sampai dan termasuk `6304`, dibandingkan dengan 4 hex terakhir (case-insensitive).
   ```dart
   int crc16(String s) {
     var crc = 0xFFFF;
     for (final b in utf8.encode(s)) {
       crc ^= b << 8;
       for (var i = 0; i < 8; i++) {
         crc = (crc & 0x8000) != 0 ? ((crc << 1) ^ 0x1021) : (crc << 1);
         crc &= 0xFFFF;
       }
     }
     return crc;
   }
   ```
3. Ekstrak dan validasi field: `00`=`01`; `01` = `11` (statis) / `12` (dinamis); template merchant account (26-51) dengan sub-tag GUID/NMID (QRIS nasional) dan kode merchant; `52` MCC; `53` = `360` (IDR); `54` nominal (wajib untuk dinamis; untuk statis input pengguna); `55/56/57` tip/fee; `58` = `ID`; `59` nama merchant; `60` kota; `61` kode pos; `62` additional data.
4. Tolak: CRC salah, mata uang bukan 360, nominal <= 0 atau format tidak valid, tag wajib hilang, nominal dinamis berbeda dengan yang akan dibayar.
5. Jalankan parsing di isolate: `Isolate.run(() => QrisParser.parse(raw))` (sesuai klaim dokumen arsitektur), agar UI scanner tidak freeze.

**6.3 Resolusi merchant & settlement (D-4)**
- `GET /merchants/resolve?nmid=...` -> `{merchantId, walletAddress, displayName, verified}`.
- NMID tidak terdaftar -> `MerchantNotRegistered("Merchant ini belum menerima pembayaran Qrypta")`, tanpa transaksi dan tanpa sukses palsu.
- Layar konfirmasi menampilkan nama merchant dari QR **dan** status terverifikasi registry; nominal; total (termasuk tip/fee); tombol Bayar -> alur Phase 3.
- Catatan jujur: stiker QRIS asli bermuara pada rail rupiah (PJP/bank). Pembayaran IDRT on-chain hanya berlaku untuk merchant yang terdaftar di konsorsium. Ini harus dikomunikasikan di UI dan dokumen, bukan disamarkan.

**6.4 Pembersihan**
- Hapus semua cabang `coffee`, `tour`, `MCH-3311`, `MCH-5520` dari `tab_pay.dart`. Data merchant uji dipindahkan ke seed staging (Phase 0.3), bukan ke kode aplikasi.

**[TAMBAHAN 6.4 — F-14b: duplikasi logika string-match di file scanner kedua]**
- **`qr_scanner_screen.dart`** (layar scanner terpisah dari `tab_pay.dart`) memuat logika string-match yang **identik** dengan `tab_pay.dart`: `MCH-3311`, `MCH-5520`, `coffee`, `tour`. Keduanya harus diganti dengan `QrPayloadRouter` (6.1) secara bersamaan — jangan hanya memperbaiki satu file.
- **`policy_matrix_constants.dart`**: definisi `MCH-3311` dan `MCH-5520` sebagai data fixture harus **dipindahkan ke `tools/seed_staging.sh`** (Phase 0.3) atau ke file fixture test-only. Tidak boleh ada di `lib/src/features/verification/data/` pada build prod.
- Setelah Phase 6 selesai, guard CI `F-14b` di `reality_guard.sh` harus hijau (tidak ada `MCH-3311`, `MCH-5520`, `coffee`, `tour` di `lib/src/features/`).

**6.5 Pengujian Phase 6**
- L1 (fixture nyata): >= 30 string QRIS riil (statis & dinamis, berbagai acquirer/penyedia, dengan tip, nominal, tanpa nominal). Diperoleh dengan memindai stiker/struk asli dengan izin pemilik, simpan **string-nya** (bukan data pribadi).
- L1 negatif: CRC diubah 1 karakter, panjang TLV salah, mata uang 840, tag hilang, string terpotong, string sangat panjang (fuzz) -> selalu error terkontrol, tidak crash.
- L1 properti/fuzz: acak byte pada fixture valid -> parser tidak melempar exception tak terkelola.
- L2: resolver terhadap staging (merchant terdaftar vs tidak).
- L4: pindai stiker QRIS fisik (layar HP lain & cetakan) dengan HP fisik; ukur waktu deteksi dan FPS UI saat parsing (tidak turun drastis).

---

### PHASE 7: HANDSHAKE MERCHANT DUA ARAH (F-15)

**Tujuan:** merchant (perangkat terpisah) memindai QR dinamis turis -> turis menerima permintaan consent real-time -> persetujuan/penolakan/pencabutan tercermin di sisi merchant.

**7.1 Spesifikasi protokol (disepakati dengan backend di Phase 0, dibekukan di sini)**
- **QR dinamis turis** (rotasi 45 detik): `{v, sessionId, nonce, exp, wallet/DID, sig}`; `sig` = tanda tangan kunci wallet atas payload; `nonce` unik per rotasi; `exp` = sekarang + 45 detik (waktu server/terkoreksi).
- **Merchant -> server:** `POST /verification/requests {sessionId, nonce, merchantId, requestedAttributes[], purpose}`, request ditandatangani/diautentikasi (API key + signature, atau mTLS). Server memverifikasi `sig`, `exp`, dan nonce belum dipakai (anti-replay).
- **Server -> turis:** dorongan real-time melalui WebSocket/SSE (foreground) dan FCM (background/terminated) (D-5). Polling berinterval sebagai cadangan transport jika socket putus.
- **Turis -> server:** consent/deny/revoke (Phase 4). **Server -> merchant:** hasil (approved + atribut/URL terbatas, denied, revoked, expired) lewat kanal serupa.
- Identitas merchant ditampilkan dari **registry terverifikasi**, bukan string bebas dari payload.

**7.2 Implementasi sisi aplikasi turis**
1. `RealtimeChannelService`: koneksi WS/SSE dengan autentikasi, reconnect eksponensial, heartbeat, pemulihan pesan terlewat via `GET /verification/requests?since=`.
2. Integrasi FCM (token terdaftar ke server, handle `onMessage`, `onBackgroundMessage`, notifikasi yang membuka layar consent).
3. `VerificationController`: sumber permintaan = kanal real-time, **bukan** `triggerMerchantSimulation`. Hapus tombol simulasi di Tab Home, Explore, dan di bawah Dynamic QR dari build staging/prod; boleh tersisa di flavor `dev` saja (R8).
4. QR dinamis ditandatangani dengan kunci wallet; rotasi 45 detik didasarkan waktu yang tersinkron, ditangani saat app di-background/resume.
5. Layar consent menampilkan: identitas merchant terverifikasi, atribut yang diminta (minimum yang perlu), tujuan, sisa waktu permintaan; opsi Setuju/Tolak. Hasil melalui alur Phase 4 (tanpa "Approved" palsu).
6. Daftar "Akses aktif" + tombol Cabut (Phase 4.2).

**[TAMBAHAN 7.2 — F-15b: 3 titik pemanggilan triggerMerchantSimulation, bukan 1]**
Fungsi `triggerMerchantSimulation` dipanggil dari **3 lokasi** yang semuanya harus dihapus dari build non-dev:
- **`tab_home.dart:633`**: tombol simulasi di shortcut bawah QR dinamis pada dashboard utama
- **`tab_explore.dart:257`**: tombol simulasi pada daftar merchant di Tab Explore
- **`dynamic_qr_screen.dart:31`**: tombol simulasi langsung di bawah QR dinamis pada layar penuh

Penghapusan dari ketiga lokasi ini harus dilakukan **sebelum** `RealtimeChannelService` live (agar tidak ada momen di mana simulasi dihapus tetapi kanal real-time belum siap — ini akan membuat fitur consent buta total). Urutan yang aman:
1. Implementasikan `RealtimeChannelService` (stub yang terkoneksi tapi belum mengirim event).
2. Verifikasi koneksi WS/SSE hidup di staging.
3. **Baru kemudian** hapus ketiga tombol simulasi.
4. Verifikasi L4 bahwa event real dari server tiba di HP.

Jika fase harus berjalan bertahap: `triggerMerchantSimulation` boleh **tetap ada di `lib/`** sementara diproteksi `if (AppConfig.flavor == 'dev')` — tapi ini harus menjadi temporary, bukan solusi permanen. Guard CI harus merah untuk `triggerMerchantSimulation` di luar blok flavor-guard.

**7.3 Alat uji merchant (bukan fitur app)**
- `tools/merchant_sim/` (CLI Node/Dart atau web kecil) yang berperan sebagai merchant: memindai/menerima payload QR (input teks atau kamera laptop), mengirim request ke server, menunggu hasil. Ini alat uji yang memakai **jaringan dan server nyata**, bukan simulasi di dalam aplikasi.
- Idealnya juga ada versi aplikasi/halaman merchant sungguhan di sisi backend; alat ini minimal untuk pengujian otomatis.

**7.4 Pengujian Phase 7**
- L2: kontrak API (skema request/respons) diverifikasi terhadap server nyata.
- L3: replay nonce lama -> ditolak; QR kedaluwarsa (>45 d) -> ditolak; payload dimodifikasi (sig salah) -> ditolak; merchant tidak terdaftar -> ditolak; WS diputus/dipulihkan -> permintaan yang tertinggal tetap sampai.
- L4 (dua perangkat fisik): merchant memindai QR turis -> permintaan muncul di HP turis < 3 detik (jaringan Wi-Fi) dan < 5 detik (4G); app turis di-background -> notifikasi FCM muncul dan membuka layar consent; app dimatikan total -> notifikasi tetap tiba; revoke di turis -> merchant menerima event revoked dan akses tak lagi valid (diuji dengan percobaan akses ulang).
- Ukur dan catat latensi p50/p95 end-to-end.

---

### PHASE 8: NFC CHIP READ + PASSIVE AUTHENTICATION (F-17) [bergantung D-1]

> Fase ini besar dan memerlukan **paspor elektronik fisik** serta HP Android ber-NFC. Boleh dikerjakan terakhir, atau dikeluarkan jika D-1 diputuskan "tetap dummy". Jika tetap dummy, terapkan pelabelan seperti Phase 9 pada `ScrNfc` dan `ScrAuth`.

**8.1 Pembacaan chip (ICAO 9303 / ISO-14443 IsoDep)**
1. Izin `NFC` di manifest; deteksi ketersediaan & status NFC (aktif/nonaktif) dengan arahan UI.
2. Kunci akses **BAC** diturunkan dari MRZ hasil Phase 5A (nomor dokumen + DOB + kedaluwarsa, lengkap dengan check digit). (PACE bila chip mendukung; BAC sebagai jalur umum.)
3. Baca `EF.COM`, `DG1` (cocokkan dengan MRZ hasil OCR; beda = tolak), `EF.SOD`. `DG2` (foto wajah, JPEG2000) opsional: tampilkan hanya jika decoder tersedia; tidak diperlukan karena wajah tetap dummy.
4. Implementasi: evaluasi pustaka Dart (mis. `dmrtd`, **perlu divalidasi** kematangan & lisensinya) atau modul native (JMRTD) via platform channel.
5. Tangani error nyata: tag hilang di tengah baca (pengguna menggeser paspor), BAC gagal (MRZ salah), timeout; berikan pesan dan opsi ulang. Tidak ada timer animasi palsu: progres harus mengikuti langkah APDU nyata.

**8.2 Passive Authentication (verifikasi SOD)**
1. Parse `EF.SOD` (CMS/PKCS#7 SignedData): ekstrak sertifikat DSC dan daftar hash DG.
2. Verifikasi tanda tangan SOD dengan DSC.
3. Hitung hash tiap DG yang dibaca, cocokkan dengan hash di SOD.
4. Validasi rantai DSC -> CSCA terhadap **trust store CSCA** (master list / ICAO PKD; ketersediaan per negara perlu diputuskan), termasuk masa berlaku dan CRL jika tersedia.
5. Output `PassiveAuthResult {valid, reasons[], cscaCountry, dscSerial}`; hasil ditampilkan nyata (bukan rantai statis di `ScrAuth`).
6. (Opsional/hardening) Chip Authentication/Active Authentication untuk deteksi kloning.
- Negara tanpa CSCA di trust store: status `UNVERIFIED_NO_TRUST_ANCHOR` ditampilkan jujur, kebijakan lolos/tidak ditentukan produk.

**8.3 Pengujian Phase 8**
- L1: parser SOD, pencocokan hash, dengan fixture SOD valid & dimodifikasi.
- L4: >= 3 paspor elektronik dari negara berbeda (dengan izin pemilik), >= 2 model HP (posisi antena NFC berbeda). Uji negatif: MRZ salah -> BAC gagal; paspor digeser -> error tertangani; DG1 dimodifikasi pada fixture -> PA gagal; DSC kedaluwarsa -> ditolak/ditandai.
- Metrik: waktu baca total, tingkat keberhasilan baca percobaan pertama.

---

### PHASE 9: LIVENESS WAJAH TETAP DUMMY, DIBUAT JUJUR (F-18)

1. `ScrLiveness` tetap menampilkan viewfinder + skor simulasi, **tetapi** tambahkan lencana tetap "SIMULASI / DEMO" yang tidak bisa disembunyikan.
2. Config `LIVENESS_MODE=simulated` (default, satu-satunya nilai yang diimplementasikan). Jika di masa depan ada mode `real`, titik masuknya sudah ada.
3. Hasil liveness dicatat di kredensial/audit sebagai `liveness: {mode: "SIMULATED", verified: false}`. Layar BTID tidak boleh mencantumkan "Biometric verified" sebagai fakta.
4. Skor 98.7% tidak ditampilkan sebagai metrik asli; ganti teks menjadi mis. "Simulasi: lolos".
5. Uji: L1 memastikan field `liveness.mode` selalu `SIMULATED`; L4 visual memastikan lencana terlihat; guard CI mencegah teks "verified biometric" tanpa kondisi.

---

## 6. PROGRAM PENGUJIAN SESUAI KONDISI NYATA (F-16)

### 6.1 Prinsip
1. **Dua sumber kebenaran:** hasil yang dilaporkan aplikasi selalu diverifikasi oleh jalur independen (RPC langsung ke node, query database server, bukan dari aplikasi yang sama).
2. **Uji build rilis di HP fisik**, bukan hanya debug/emulator (R8, izin, cleartext, performa kamera hanya terlihat di sini).
3. **Kegagalan adalah skenario utama,** bukan pengecualian: setiap fitur yang memanggil jaringan punya matriks kegagalan.
4. **Mock dibatasi di L1** (R6). `MockClient` boleh dipakai untuk memeriksa pemetaan error, bukan sebagai bukti fitur berfungsi.
5. **Setiap laporan test menyebut levelnya.** Angka "N tests passed" tanpa level dilarang di dokumentasi.

### 6.2 Level pengujian

| Level | Nama | Lingkungan | Boleh mock? | Contoh | Dijalankan |
| :--- | :--- | :--- | :--- | :--- | :--- |
| L0 | Statis | CI | n/a | `reality_guard.sh`, lint, secret scan (gitleaks), analisis APK | Setiap commit |
| L1 | Unit | CI | Ya | check digit MRZ, TLV/CRC, state machine, pemetaan error, outbox | Setiap commit |
| L2 | Integrasi nyata | CI + docker staging (Besu, ezsign-core, DB) | **Tidak** | transfer ERC-20 nyata, consent ke server nyata, resolver merchant | Setiap PR ke main + nightly |
| L3 | Chaos / ketahanan | Docker staging + toxiproxy | Tidak | server mati, latensi, timeout, partial response, restart di tengah tx | Nightly + sebelum rilis |
| L4 | E2E perangkat fisik (rilis) | APK rilis, HP fisik, jaringan nyata | Tidak | scan paspor, bayar, QRIS, handshake dua perangkat | Sebelum tiap rilis (skrip manual terstruktur) |
| L5 | Penerimaan lapangan | Pengguna/rekan nyata, kondisi nyata | Tidak | uji di lokasi dengan 4G, paspor beragam | Sebelum rilis besar |

Implementasi teknis:
- L2: paket `integration_test` / `dart test` dengan tag `@Tags(['integration'])` yang membaca `STAGING_*` dari `--dart-define`; **gagal** (bukan skip) jika staging tidak terjangkau agar tidak ada "hijau semu".
- L3: `toxiproxy` di depan Besu dan ezsign-core (latency, timeout, `reset_peer`, `limit_data`) + `docker stop/start`.
- L4: `flutter drive`/`integration_test` di perangkat untuk bagian yang otomatis (navigasi, saldo, banner); bagian fisik (kamera ke paspor/QRIS, NFC) memakai **lembar uji manual** (§6.7) dengan bukti rekaman layar.

### 6.3 Matriks pengujian OCR MRZ (L2/L4)

**Dataset (privasi, R9):** jangan commit paspor asli. Gunakan (a) spesimen ICAO/paspor contoh dan MRZ sintetis dicetak dengan font OCR-B pada kertas/kartu, (b) dokumen asli milik tim/relawan dengan persetujuan tertulis, foto disimpan terenkripsi di luar repo, tidak disebarkan.

| Dimensi | Variasi minimum |
| :--- | :--- |
| Perangkat | >= 1 Android low-end (RAM <= 3 GB, kamera biasa), >= 1 mid, >= 1 flagship |
| Paspor | >= 6 negara/desain berbeda, termasuk sampul/laminasi mengkilap, paspor lama (aus), nama panjang, nama dengan `<` banyak |
| Cahaya | Terang alami, ruang dalam normal, redup, lampu menyilaukan/glare |
| Posisi | Jarak 10-25 cm, sudut miring hingga ~20 derajat, tangan bergetar |
| Orientasi | Portrait & landscape, HP diputar |

**Metrik & ambang (L4):** waktu sampai terbaca (p50, p95), tingkat keberhasilan <= 10 detik, **salah-terima = 0**, penggunaan CPU/baterai/suhu saat 60 detik pemindaian, tidak ada crash/ANR. Ambang lulus: keberhasilan >= 95% pada kondisi "normal", >= 80% pada "sulit", salah-terima 0.

### 6.4 Matriks pengujian kegagalan jaringan (L3) untuk setiap fitur jaringan

| Skenario | Besu | ezsign | Harapan (levy/QRIS) | Harapan (consent/revoke/BTID) |
| :--- | :--- | :--- | :--- | :--- |
| Semua sehat | up | up | `confirmed` + Paid/kuitansi nyata | synced |
| RPC mati sebelum kirim | down | up | error `NetworkUnreachable`, nol kuitansi, nol "Paid" | n/a |
| RPC mati setelah broadcast | down | up | state `pending`, recovery menyelesaikan saat pulih | n/a |
| ezsign mati, RPC hidup | up | down | tx `confirmed` tapi status "pencatatan tertunda" (outbox), bukan "Paid" | consent: error, tidak ada Approved; revoke: outbox + banner peringatan; BTID: tidak ada kartu |
| Keduanya mati | down | down | pembayaran dinonaktifkan, saldo "tidak tersedia" | semua aksi ditolak dengan pesan jelas |
| Timeout lambat (latensi > 30 d) | slow | slow | `RequestTimeout`, tidak ada sukses palsu | sama |
| Respons 5xx | n/a | 500 | n/a | `ServerRejected`/retry via outbox sesuai jenis aksi |
| Respons 4xx (ditolak) | n/a | 400/409/422 | n/a | `rejected`, tampil alasan, tidak di-retry buta |
| Respons terpotong/JSON rusak | n/a | rusak | n/a | error terkontrol, tidak crash |
| TLS tidak valid | n/a | cert salah | koneksi ditolak | koneksi ditolak |
| Airplane mode | - | - | banner offline, aksi jaringan dinonaktifkan | sama; outbox menunggu |
| App dimatikan paksa saat tx | up | up | pemulihan saat app dibuka (intent diselesaikan) | outbox lanjut |
| Tap bayar dua kali / dua perangkat | up | up | hanya satu transfer | n/a |
| Nonce bentrok / `nonce too low` | up | up | ditangani (ambil nonce ulang) atau error jelas | n/a |
| Saldo token kurang | up | up | `InsufficientBalance` sebelum broadcast | n/a |
| Gas/native kurang (bila berlaku) | up | up | `InsufficientGas` | n/a |
| `chainId` node != konfigurasi | wrong | up | `ChainMismatch`, transaksi diblokir | n/a |

Setiap sel di atas menjadi satu test L3 otomatis bila memungkinkan; sisanya masuk lembar uji manual.

### 6.5 Verifikasi independen (oracle) untuk transaksi

Setelah L4 menampilkan "sukses", **jangan percaya layar**. Jalankan:
```bash
# tools/verify_tx.sh <txHash>
curl -s -X POST "$RPC_URL" -H 'Content-Type: application/json' \
  --data "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"eth_getTransactionReceipt\",\"params\":[\"$1\"]}" \
  | jq '.result | {status, blockNumber, from, to, logs: (.logs | length)}'
```
Lalu cek: `status == "0x1"`, ada log `Transfer` dengan `from/to/value` sesuai, dan panggilan `balanceOf` sebelum/sesudah berubah tepat sebesar nominal. Untuk server: query database/GraphQL untuk memastikan record audit/levy ada dan terikat ke `txHash` yang sama. Hash dari layar harus **sama** dengan yang ada di chain; hash yang tidak ditemukan di chain = bug kritis.

### 6.6 Uji kontrak & kepatuhan konfigurasi
- **Kontrak API:** skema OpenAPI/JSON Schema ezsign-core menjadi sumber kebenaran; klien diuji terhadap server nyata (L2) dan skema divalidasi di CI. Perubahan server yang mematahkan klien menggagalkan nightly.
- **Pemeriksaan artefak rilis (L0):** skrip memeriksa APK: tidak ada `.env`, tidak ada `127.0.0.1/localhost`, izin `INTERNET`/`CAMERA`/`NFC` benar, `usesCleartextTraffic` tidak aktif, tidak ada secret (gitleaks).
- **Keamanan dasar:** kunci wallet hanya di Keystore/secure storage, tidak ada di log; MRZ tidak di log; backup aplikasi (`allowBackup`) ditinjau.

### 6.7 Lembar uji E2E perangkat fisik (L4) - dijalankan per rilis

Tiap baris: **langkah -> hasil yang diharapkan -> bukti (rekaman/tx hash/log) -> Lulus/Gagal -> penguji/tanggal/perangkat**.

| # | Skenario | Hasil diharapkan | Verifikasi independen |
| :--- | :--- | :--- | :--- |
| E1 | Install APK rilis staging, buka tanpa jaringan | Banner offline, aksi jaringan nonaktif, tidak ada saldo palsu | Tidak ada nilai `2.480.000` |
| E2 | Buka dengan jaringan | Health check hijau, chainId cocok | `eth_chainId` manual |
| E3 | Scan paspor fisik | MRZ terbaca <= 10 d; nama/DOB/kedaluwarsa sesuai paspor | Bandingkan dengan dokumen |
| E4 | Lanjut tanpa jaringan di akhir (penerbitan BTID) | Tidak ada kartu BTID, ada pesan coba lagi | DB server tidak berisi BTID |
| E5 | Terbitkan BTID dengan jaringan | Nomor BTID unik dari server | Query DB server; nomor != `BTID-2026-4471-0938` |
| E6 | Bayar levy (saldo cukup) | Status `pending` lalu `confirmed`, Paid setelah ack server, kuitansi dengan hash nyata | `verify_tx.sh`, saldo berubah |
| E7 | Bayar levy saat RPC dimatikan di tengah | Error/pending; tidak Paid; tidak ada kuitansi | `balanceOf` tidak berubah |
| E8 | Buka kembali kuitansi levy | Hash = hash E6, bukan statis | Bandingkan hash |
| E9 | Pindai QRIS asli milik merchant terdaftar -> bayar | Parser membaca, nama merchant benar, transfer terkonfirmasi | `verify_tx.sh` + log merchant |
| E10 | Pindai QRIS merchant tidak terdaftar | "Merchant belum terdaftar", tidak ada transaksi | Tidak ada tx baru |
| E11 | Pindai QRIS dengan CRC dirusak | Ditolak | - |
| E12 | Merchant memindai QR dinamis turis | Permintaan consent muncul di HP turis < 5 d | Log server |
| E13 | Setuju consent | Server `consent` tercatat, merchant menerima hasil | DB server |
| E14 | Cabut akses | Merchant menerima event revoked, akses ditolak | Percobaan akses merchant gagal |
| E15 | Cabut akses saat server mati | Banner "belum terkirim", otomatis terkirim saat pulih | DB server setelah pulih |
| E16 | App di-background lalu merchant memindai | Notifikasi FCM -> layar consent | Log FCM/server |
| E17 | Liveness | Lencana "SIMULASI" terlihat; kredensial mencatat `SIMULATED` | Isi respons kredensial |
| E18 | (Phase 8) NFC paspor-e | Data DG1 cocok MRZ, PA valid/ditandai sesuai trust store | Log PA, fixture |

### 6.8 Perbaikan klaim pengujian lama
- Ubah `DOKUMENTASI_TEKNIS_MILESTONE_6.md`: ganti klaim "43/43 lulus" dengan tabel per level (L1/L2/L3/L4) dan tautan bukti. Test lama yang hanya memakai `MockClient` dilabeli L1, tidak dihitung sebagai bukti integrasi.
- Pasang penanda **"BELUM DIIMPLEMENTASIKAN"** pada klaim dokumen arsitektur (Parser QRIS di isolate, handshake real-time) sampai Phase 6/7 selesai, lalu hapus penanda dan perbarui isinya.
- Tambahkan badge CI terpisah: `unit`, `integration`, `chaos`. Nightly hijau pada integrasi dan chaos adalah syarat rilis.

---

## 7. REALITY GATE (SYARAT GO/NO-GO RILIS)

Rilis diizinkan hanya jika **semua** terpenuhi:

- [ ] `reality_guard.sh` hijau; tidak ada literal palsu; tidak ada `catch` penelan error (R1-R3).
- [ ] APK rilis tidak memuat `.env`/loopback; `ConfigValidator` menolak konfigurasi tidak sah (R5).
- [ ] Seluruh F-01..F-17 berstatus *selesai* di `PROGRESS.md` dengan bukti terlampir (atau F-17 dengan keputusan D-1 yang tercatat).
- [ ] L2 integrasi dan L3 chaos hijau pada nightly 5 hari berturut-turut.
- [ ] Lembar L4 (E1-E17) lulus pada >= 2 perangkat fisik berbeda; E18 jika Phase 8 aktif.
- [ ] Setiap "sukses" di UI diverifikasi oracle independen dalam L4 (tx hash ada di chain; record ada di DB server).
- [ ] Skenario "server mati" tidak menghasilkan satu pun status Paid/Approved/Revoked/BTID palsu (diverifikasi lewat DB & chain).
- [ ] Lencana liveness "SIMULASI" terlihat dan tercatat sebagai `SIMULATED`.
- [ ] Dokumentasi diperbarui jujur (§6.8); tidak ada klaim fitur yang belum ada.
- [ ] Tinjauan PII: tidak ada MRZ/nomor paspor/nama lengkap di log atau payload audit tanpa keputusan eksplisit (R9, D-8).
- [ ] **[BARU — F-19]** Tidak ada tombol "Fast Demo Mode" atau pemanggilan `demoJamesWilson()` di APK staging/prod; `reality_guard.sh` guard F-19 hijau.
- [ ] **[BARU — F-20]** Tidak ada `127.0.0.1`/`localhost` di kode Dart (`blockchain_config.dart`, `graphql_provider.dart`, dan semua file config); guard F-20 hijau.
- [ ] **[BARU — F-03b]** Tidak ada jalur pembayaran Visa/Counter QR yang menghasilkan status "Paid" tanpa transaksi nyata; opsi ini dinonaktifkan atau dihapus dari UI.
- [ ] **[BARU — F-09b/F-10b]** Grep untuk `Rp 2.480.000` dan `0x7b2f8a1e` di seluruh `lib/` mengembalikan nol hasil.
- [ ] **[BARU — F-11b/F-12b/F-13b]** `BtidCredentialModel.fromJson` tidak memiliki default James Wilson / BTID statis / DOB palsu; `AuditTransactionModel.fromJson` tidak memiliki default James Wilson; grep `btid_credential_model.dart` dan `audit_transaction_model.dart` untuk literal palsu mengembalikan nol hasil.
- [x] **[BARU — F-14b]** `qr_scanner_screen.dart` dan `policy_matrix_constants.dart` tidak mengandung MCH-3311/MCH-5520/`coffee`/`tour` di build prod.
- [ ] **[BARU — F-15b]** Ketiga titik pemanggilan `triggerMerchantSimulation` dihapus dari build staging/prod; tidak ada di `tab_home.dart`, `tab_explore.dart`, `dynamic_qr_screen.dart`.
- [ ] **[BARU — F-21]** Tidak ada `catch (_) {}` kosong di `lib/`; semua exception tertangani dengan `AppFailure` bertipe atau masuk outbox.

---

## 8. RISIKO & MITIGASI

| Risiko | Dampak | Mitigasi |
| :--- | :--- | :--- |
| ML Kit membaca MRZ kurang akurat pada OCR-B/kondisi sulit | OCR sering gagal | Crop ROI, multi-frame, koreksi berbasis check digit, input manual tervalidasi, uji matriks perangkat sejak awal |
| Backend ezsign-core belum punya endpoint yang dibutuhkan (BTID, resolver, WS, e-VOA, idempotensi) | Phase 4-7 terblokir | Bekukan kontrak API di Phase 0; minta backend menyiapkan stub nyata di staging lebih awal; tandai ketergantungan di `PROGRESS.md` |
| Besu/IDRT parameter berbeda dari asumsi (gas, decimals, konsensus) | Bug nominal/gagal bayar | Baca dari chain (D-7); uji L2 dengan nilai ekstrem (dust, nominal besar) |
| Paspor elektronik/CSCA sulit didapat untuk Phase 8 | Phase 8 molor | Jadikan opsional (D-1); mulai dengan paspor tim; tentukan cakupan negara trust store |
| FCM/background push tidak andal di beberapa vendor Android (battery optimization) | Notifikasi consent terlambat | Uji pada beberapa merek; kombinasi WS + FCM + polling; arahan pengaturan baterai |
| Data audit lama di Hive tercemar | Riwayat menyesatkan | Migrasi `legacy_unverified` (Phase 2.4) |
| Rotasi QR dan jam perangkat tidak sinkron | QR ditolak/tidak sah | Koreksi offset waktu dari server, toleransi kecil, uji dengan jam diubah |
| Ketergantungan ke tim eksternal (infra TLS/domain) | Phase 1 tertunda | Mulai dari tunnel (Cloudflare/Tailscale) sebagai staging sementara |
| Tim tergoda "menghijaukan" test dengan mock | Ilusi kembali | R6, badge CI per level, Reality Gate, review wajib untuk test baru |

---

## 9. LAMPIRAN

### 9.1 Checklist PR (wajib dicentang setiap PR)
- [ ] Tidak ada `catch` yang hanya log (R1).
- [ ] Tidak ada literal identitas/keuangan/hash baru (R3).
- [ ] UI sukses hanya dari state terkonfirmasi (R2/R7).
- [ ] Ada test pada level yang tepat; test jaringan tidak memakai mock sebagai satu-satunya bukti (R6).
- [ ] Skenario gagal (offline/timeout/5xx) sudah diuji.
- [ ] Tidak ada PII di log (R9).
- [ ] `PROGRESS.md` diperbarui dengan bukti.

### 9.2 Template bukti per temuan (`docs/audit/evidence/F-xx.md`)
```
Temuan: F-xx - <judul>
Commit/PR: <tautan>
Perilaku sebelum: <rekaman/log>
Perilaku sesudah: <rekaman/log>
Tes otomatis: <nama tes, level, tautan run CI>
Tes perangkat: <lembar L4, perangkat, tanggal, penguji>
Verifikasi independen: <tx hash / query DB / output verify_tx.sh>
Catatan risiko tersisa: <...>
```

### 9.3 Urutan eksekusi yang disarankan (ringkas)
1. Phase 0 (verifikasi + guard CI merah + staging siap).
2. Phase 1 (APK rilis bisa menjangkau server) dan paralel Phase 5A (OCR).
3. Phase 2 (fondasi), lalu Phase 3 dan Phase 4 paralel.
4. Phase 5B setelah 5A dan backend BTID siap.
5. Phase 6, lalu Phase 7.
6. Phase 8 sesuai D-1; Phase 9 kapan saja (kecil).
7. Phase 10: lengkapi lembar L4, jalankan Reality Gate, perbarui dokumentasi.
