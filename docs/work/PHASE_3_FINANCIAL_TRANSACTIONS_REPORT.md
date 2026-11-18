# LAPORAN REKAP KERJA: PHASE 3 (TRANSAKSI KEUANGAN NYATA)
**Proyek:** Qrypta & Bali Tourist ID  
**Master Plan:** `docs/RENCANA_KERJA_ELIMINASI_FALLBACK_PALSU.md` (Phase 3)  
**Branch:** `fix/real-behavior`  
**Tanggal Eksekusi:** 18 November 2026  
**Status Fase:** Selesai 100% (Seluruh KPI Terverifikasi)

---

## 1. RINGKASAN EKSEKUTIF

Phase 3 menyelesaikan penanganan transaksi finansial dengan menghapus seluruh pembuatan hash transaksi palsu (keccak256 fallback lokal), saldo tiruan statis, dan kuitansi tiruan pada modul pembayaran Tourist Levy dan QRIS Merchant.

Sebelum Phase 3, saat node RPC Besu tidak terjangkau atau transaksi dibatalkan, aplikasi tetap menyatakan transaksi berhasil dengan merekayasa `txHash` palsu dari seed string lokal. Selain itu, saldo IDRT dan nomor kuitansi di-hardcode ke angka `Rp 2.480.000` dan hash `0x7b2f8a1e...`.

Pada Phase 3, seluruh mekanisme palsu tersebut telah dieliminasi dan digantikan dengan integrasi `TxStateMachine`, `TxRecoveryService`, dan single-source `idrtBalanceProvider`.

---

## 2. DETAIL PERUBAHAN & ELIMINASI TEMUAN

### 2.1 Eliminasi Fallback Hash Palsu (F-03, F-03b, F-04)
- **File:** `lib/src/features/transaction/logic/payment_controller.dart`
- **Tindakan:**
  - Menghapus blok fallback `fallbackSeed` dan `keccak256(utf8.encode(fallbackSeed))` pada fungsi `payTouristLevy` dan `payQrisMerchant`.
  - Menghapus impor `package:web3dart/crypto.dart` yang sebelumnya digunakan untuk membuat hash tiruan di luar node blockchain.
  - Menolak metode non-wallet (simulasi kartu Visa / Counter QR) dengan melempar `ValidationFailure` terstruktur hingga jalur PJP/bank resmi tersedia (F-03b).
  - Mengintegrasikan siklus hidup transaksi ke `TxStateMachine`: intent transaksi dipersist di Hive sebelum broadcast raw transaction ke node RPC Besu.
  - Memvalidasi receipt on-chain secara terstruktur via `TxRecoveryService.pollReceiptUntilMined(txHash)` dengan batas waktu 120 detik.
  - Hanya transaksi dengan receipt on-chain berstatus `1` (true) yang dapat beralih ke state `confirmed` dan mencatat kuitansi lunas (`paid`).

### 2.2 Eliminasi Saldo Default Statis Rp 2.480.000 (F-09, F-09b)
- **File Terkena:**
  - `lib/src/features/tokens/presentation/providers/token_provider.dart`
  - `lib/src/features/transaction/presentation/screens/levy_payment_screen.dart`
  - `lib/src/features/transaction/presentation/screens/qris_payment_screen.dart`
  - `lib/src/features/home/presentation/tabs/tab_home.dart`
- **Tindakan:**
  - Membangun `idrtBalanceProvider` dan `idrtBalanceFormattedProvider` sebagai sumber kebenaran tunggal (*single source of truth*) yang membaca saldo token IDRT langsung dari kontrak ERC-20 via node RPC.
  - Menghapus seluruh deklarasi lokal `String idrtBalance = 'Rp 2.480.000'`.
  - UI kini menampilkan status `Memuat...` saat pembacaan saldo berjalan, atau `Saldo tidak tersedia` bila terjadi kegagalan jaringan, dan menonaktifkan aksi pembayaran jika saldo kurang.

### 2.3 Eliminasi Hash Statis Kuitansi 0x7b2f8a1e... (F-10, F-10b)
- **File Terkena:**
  - `lib/src/core/data/models/btid_credential_model.dart`
  - `lib/src/features/authentication/presentation/providers/btid_provider.dart`
  - `lib/src/features/transaction/presentation/screens/levy_payment_screen.dart`
  - `lib/src/features/home/presentation/tabs/tab_home.dart`
  - `lib/src/features/home/presentation/tabs/tab_profile.dart`
- **Tindakan:**
  - Menambahkan field `levyTxHash` pada `BtidCredentialModel` dan pembaruan mutasi `updateLevyStatus('paid', txHash: ...)`.
  - Menghapus seluruh literal hash statis `0x7b2f8a1e9c4d3b5a7e6f8a9b0c1d2e3f4a5b6c7d` dari ketiga layar UI.
  - Kuitansi kini hanya merender hash transaksi on-chain yang valid dari state kredensial atau riwayat intent. Jika transaksi belum confirmed, tombol kuitansi dinonaktifkan atau memberikan notifikasi bahwa transaksi masih pending.

### 2.4 Sanitasi Silent Catch (F-21)
- **File:** `lib/src/features/transaction/logic/payment_controller.dart` & `lib/src/features/authentication/presentation/providers/btid_provider.dart`
- **Tindakan:**
  - Mengeliminasi 6 blok `catch (_) {}` kosong pada `payment_controller.dart`.
  - Mengeliminasi 3 blok `catch (_) {}` kosong pada `btid_provider.dart` dengan menambahkan logging terstruktur.

---

## 3. HASIL VERIFIKASI PENGUJIAN

1. **Pengujian Unit Phase 3 (Level L1):**
   - File: `test/phase3_financial_transaction_test.dart`
   - Hasil: 9/9 tes lulus (durasi <1 detik).
   - Mencakup: format saldo BigInt tanpa floating point loss, validasi kuitansi MRZ TD3, penolakan metode kartu simulasi, penolakan pembayaran ganda, dan transisi state machine.

2. **Pengujian Menyeluruh Seluruh Proyek:**
   - Hasil: **84/84 tes lulus 100% (0 failed)**.
   - Tidak ada regresi pada Milestone 2, 3, 4, 5, Phase 1, maupun Phase 2.

3. **Verifikasi Integritas Kode (Reality Guard):**
   - Literal terlarang `0x7b2f8a1e` dan `2.480.000` telah nol hit di seluruh `lib/`.
   - `fallbackSeed` telah nol hit di seluruh `lib/`.
   - Tidak ada lagi pemalsuan hash keccak256 di lapisan transaksi finansial.

---

## 4. KESIAPAN FASE BERIKUTNYA

Dengan tuntasnya Phase 3:
- Transaksi finansial telah sepenuhnya berpijak pada eksekusi on-chain nyata.
- Siap melanjutkan ke **Phase 4 (Consent, Revocation & Financial Audit Nyata)** untuk menuntaskan temuan F-05, F-06, F-07, dan pembersihan actor 'James Wilson' pada service audit.
