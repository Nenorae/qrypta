# LAPORAN REKAP KERJA: PHASE 4 (CONSENT, REVOCATION & AUDIT NYATA)
**Proyek:** Qrypta & Bali Tourist ID  
**Master Plan:** `docs/RENCANA_KERJA_ELIMINASI_FALLBACK_PALSU.md` (Phase 4)  
**Branch:** `fix/real-behavior`  
**Tanggal Eksekusi:** 18 November 2026  
**Status Fase:** Selesai 100% (Seluruh KPI Terverifikasi)

---

## 1. RINGKASAN EKSEKUTIF

Phase 4 menuntaskan eliminasi fallback palsu pada modul persetujuan data (cryptographic consent), pencabutan izin akses merchant (revocation), dan pencatatan audit finansial, serta membersihkan seluruh nilai literal aktor 'James Wilson' dan blok penangkap error tanpa penanganan (silent catch) di seluruh basis kode.

Sebelum Phase 4:
1. Pengajuan consent yang gagal menjangkau middleware Fastify (`ezsign-core`) ditelan oleh blok `catch` dan otomatis disimpan secara lokal sebagai "Approved" dengan hash digest lokal yang menyerupai hash transaksi on-chain.
2. Pencabutan akses merchant (`revokeMerchantAccess`) saat offline langsung menandai status lokal "Revoked" tanpa jaminan penyampaian ke server, sehingga menciptakan ilusi keamanan.
3. Audit finansial Tourist Levy dan QRIS Merchant menelan kegagalan HTTP hanya dengan logging konsol.
4. Identitas aktor di-hardcode ke string literal `'James Wilson'` di lapisan service, model DTO, dan berbagai layar UI.
5. Terdapat blok `catch (_) {}` kosong yang mengabaikan kegagalan parsing JSON dan inisialisasi state.

Melalui Phase 4, seluruh alur telah diselaraskan dengan Golden Rules R1, R2, R3, dan R7 menggunakan integrasi `OutboxRepository`, `OutboxWorker`, dan model `ActorRef` bergaram (zero-PII).

---

## 2. DETAIL PERUBAHAN & ELIMINASI TEMUAN

### 2.1 Eliminasi Fallback Palsu Consent Submission (F-05)
- **File:** `lib/src/core/services/blockchain/verification_transaction_service.dart`
- **Tindakan:**
  - Menghapus penelanan error pada blok `catch` di `signAndSubmitConsent`.
  - Mengimplementasikan validasi wajib: BTID dan nama pemegang kredensial harus terisi; jika kosong, dilempar `ValidationFailure`.
  - Menambahkan header `Idempotency-Key` (UUID v4) pada setiap request HTTP POST ke endpoint Fastify `/verify-identity`.
  - Pada skenario persetujuan (`isApproved == true`): status `Approved` dan `syncStatus = 'synced'` hanya dicatat jika server merespons kode status 2xx (200/202) dan mengembalikan identitas server/korelasi yang sah. Jika server offline atau menolak (4xx/5xx), service melempar `AppFailure` bertipe (`ServerRejected` atau `NetworkUnreachable`). Tidak ada rekaman `Approved` palsu yang dibuat secara lokal.
  - Pada skenario penolakan (`isApproved == false`): jika server offline, item penolakan dimasukkan ke antrean Outbox (`type: 'audit_consent'`) dengan status `pending_sync` sehingga server dapat menerima pencatatan penolakan saat konektivitas pulih.

### 2.2 Eliminasi Fallback Palsu Revocation (F-06)
- **File:** `lib/src/core/services/blockchain/verification_transaction_service.dart`
- **Tindakan:**
  - Mengintegrasikan pengiriman pencabutan akses merchant dengan `OutboxRepository`.
  - Jika server merespons 2xx, transaksi audit dicatat dengan `status = 'Revoked'` dan `syncStatus = 'synced'`.
  - Jika server offline atau terjadi timeout, item pencabutan dimasukkan ke antrean Outbox (`type: 'audit_revocation'`) dan status lokal ditandai `status = 'Revoked'` dengan `syncStatus = 'pending_sync'` serta peringatan eksplisit: `"Pencabutan belum terkirim ke server. Merchant mungkin masih memiliki akses."`.
  - Menghilangkan pembuatan hash keccak256 palsu lokal sebagai substitusi `txHash`.

### 2.3 Eliminasi Penelanan Error Audit Finansial (F-07)
- **File:** `lib/src/core/services/blockchain/verification_transaction_service.dart`
- **Tindakan:**
  - Metode `recordLevyPaymentAudit` dan `recordQrisPaymentAudit` tidak lagi menelan error HTTP.
  - Karena transaksi on-chain telah terkonfirmasi sah (receipt status 1 dari Phase 3), kegagalan komunikasi ke server ezsign-core secara otomatis dialihkan ke `OutboxRepository` (`type: 'audit_levy'` dan `'audit_qris'`).
  - Rekaman audit lokal ditandai dengan `syncStatus = 'pending_sync'` dan `lastError = 'Audit server tertunda. Transaksi on-chain tetap sah.'`, menjaga diferensiasi status lokal vs status otoritatif (Golden Rule R7).

### 2.4 Sanitasi Aktor & Privasi Zero-PII (F-12 & F-12b)
- **File Dibuat / Diperbarui:**
  - `lib/src/core/data/models/actor_ref.dart` (Model baru)
  - `lib/src/core/data/models/btid_credential_model.dart`
  - `lib/src/core/utils/mrz_parser.dart`
  - `lib/src/features/authentication/presentation/providers/btid_provider.dart`
  - `lib/src/features/verification/presentation/screens/consent_request_screen.dart`
  - `lib/src/features/verification/presentation/screens/privacy_audit_screen.dart`
  - `lib/src/features/home/presentation/tabs/tab_home.dart`
  - `lib/src/features/home/presentation/tabs/tab_profile.dart`
  - `lib/src/features/transaction/presentation/screens/levy_payment_screen.dart`
  - `lib/src/features/authentication/presentation/screens/welcome_screen.dart`
  - `lib/src/features/authentication/presentation/screens/mrz_scanner_screen.dart`
- **Tindakan:**
  - Membuat model `ActorRef` yang menggenerasikan hash bergaram (`actorRef`) untuk payload audit zero-PII (Keputusan Desain D-8). Nama lengkap dan paspor mentah tidak dikirimkan ke log audit eksternal.
  - Menghapus seluruh kemunculan string literal `'James Wilson'` di seluruh direktori `lib/` (hasil grep: 0 hit).
  - Menghapus factory `MrzParseResult.demoJamesWilson()` dari `lib/src/core/utils/mrz_parser.dart` dan memindahkannya ke `test/fixtures/mrz_fixtures.dart` untuk keperluan pengujian murni.
  - Menghapus tombol jalan pintas demo "Fast Demo Mode (James Wilson)" dari `welcome_screen.dart` dan `mrz_scanner_screen.dart` guna menegakkan Golden Rule R8.

### 2.5 Eliminasi Blok Catch Kosong (F-21)
- **File Terkena:**
  - `lib/src/features/verification/logic/verification_controller.dart` (baris 122 & 281)
  - `lib/src/features/home/presentation/tabs/tab_pay.dart` (baris 50)
  - `lib/src/features/qr_scanner/presentation/screens/qr_scanner_screen.dart` (baris 76)
- **Tindakan:**
  - Mengganti seluruh blok `catch (_) {}` kosong dengan penanganan exception terstruktur menggunakan `on Object catch (e)` dan logging diagnostik.
  - Hasil audit grep untuk pola `catch (_) {}` di seluruh `lib/`: 0 hit.

### 2.6 Implementasi UI Status Sinkronisasi & Sync Center (Phase 4.5)
- **File:** `lib/src/features/verification/presentation/screens/privacy_audit_screen.dart`
- **Tindakan:**
  - Menambahkan chip visual `syncStatus` pada setiap kartu riwayat audit:
    - `Synced` (Hijau / Teal)
    - `Menunggu Sinkron` (Kuning / Oranye)
    - `Ditolak Server` (Merah)
    - `Tidak Terverifikasi` (Abu-abu, data warisan)
  - Menampilkan kotak pesan error/peringatan jika item memiliki `lastError`.
  - Menambahkan tombol aksi `Sync Center` pada AppBar dengan modal lembar bawah interaktif untuk memantau daftar antrean Outbox dan tombol `Kirim Ulang Sekarang` yang mengeksekusi `OutboxWorker.processPendingQueue()`.
  - Menghapus fallback statis `'BTID-2026-4471-0938'` pada aksi pencabutan izin.

---

## 3. HASIL VERIFIKASI PENGUJIAN

1. **Pengujian Unit Phase 4 (Level L1):**
   - File: `test/phase4_consent_audit_test.dart`
   - Jumlah Pengujian: 12 pengujian baru.
   - Hasil: 12/12 lulus 100%.
   - Cakupan pengujian:
     - Penolakan pembuatan status Approved lokal saat Fastify 500.
     - Penolakan saat jaringan putus (offline) pada consent approval.
     - Penerimaan consent dengan status `synced` dan penerimaan Idempotency-Key saat 202.
     - Pengalihan penolakan (rejection) ke Outbox saat offline.
     - Pencatatan revocation dengan status `synced` saat sukses.
     - Pengalihan revocation ke Outbox dengan status `pending_sync` dan pesan peringatan saat offline.
     - Pengalihan audit levy & QRIS ke Outbox dengan status `pending_sync` saat offline.
     - Anonimisasi hash bergaram pada `ActorRef` tanpa mengekspos PII.
     - Validasi penolakan input kosong pada BTID dan Nama.
     - Verifikasi pemrosesan antrean outbox oleh `OutboxWorker`.

2. **Pengujian Menyeluruh Seluruh Proyek:**
   - Hasil eksekusi `flutter test`: **96/96 tes lulus 100% (0 failed)**.
   - Durasi eksekusi: ~4 detik.
   - Seluruh test warisan (Milestone 2, 3, 4, 5, 6, Phase 1, Phase 2, Phase 3) tetap hijau tanpa regresi.

3. **Verifikasi Integritas Kode (Reality Guard):**
   - `catch (_) {}`: **0 hit** (Check Reality Guard: PASS).
   - `demoJamesWilson()` di `lib/`: **0 hit** (Check Reality Guard: PASS).
   - `James Wilson` di `lib/`: **0 hit**.
   - `txHash` keccak palsu di lapisan service: **0 hit**.

---

## 4. KESIAPAN FASE BERIKUTNYA

Dengan tuntasnya Phase 4:
- Seluruh modul persetujuan, pencabutan izin, dan audit identitas telah beroperasi secara otoritatif dan terlindungi oleh mekanisme Outbox idempoten.
- Lapisan service dan presentasi telah bersih dari data demo statis James Wilson.
- Siap melanjutkan ke **Phase 5A: Mesin OCR MRZ Paspor Asli (Google ML Kit Text Recognition)** untuk mengeliminasi pemakaian barcode scanner (`MobileScanner`) pada pemindaian paspor fisik.
