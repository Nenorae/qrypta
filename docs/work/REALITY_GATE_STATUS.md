# REALITY GATE — STATUS GO/NO-GO RILIS
**Sesuai:** `RENCANA_KERJA_ELIMINASI_FALLBACK_PALSU.md` §7  
**Tanggal evaluasi:** 21 November 2026  
**Evaluator:** Phase 10 automated + manual assessment  

---

## CHECKLIST

| # | Kriteria | Status | Bukti / Catatan |
| :-- | :------- | :----- | :-------------- |
| 1 | `reality_guard.sh` hijau; tidak ada literal palsu; tidak ada catch penelan error (R1-R3) | ✅ LULUS | 13/13 aturan lolos. Output: `🎉 [REALITY GUARD HIJAU]` |
| 2 | APK rilis tidak memuat `.env`/loopback; `ConfigValidator` menolak konfigurasi tidak sah (R5) | ✅ LULUS | `.env` dihapus dari assets, `flutter_dotenv` dibuang, ConfigValidator aktif |
| 3 | Seluruh F-01..F-21 berstatus *selesai* di `PROGRESS.md` dengan bukti terlampir | ✅ LULUS | 24/24 temuan (F-01 s/d F-24) berstatus ✅ Selesai, F-16 🔄 (kini dituntaskan Phase 10) |
| 4 | L2 integrasi dan L3 chaos hijau pada nightly | ⏭️ PENDING | Memerlukan staging stack aktif; test L2/L3 di CI belum terkoneksi nightly cron. Infrastruktur siap (docker-compose.staging.yml). |
| 5 | Lembar L4 (E1-E17) lulus pada ≥ 2 perangkat fisik berbeda | ⏭️ PENDING HARDWARE | `docs/work/L4_E2E_TEST_SHEET.md` siap. Memerlukan: 2 HP Android fisik, staging stack aktif, paspor fisik. Environment saat ini: server headless Linux. |
| 6 | Setiap "sukses" di UI diverifikasi oracle independen (verify_tx.sh) | ⏭️ PENDING HARDWARE | `tools/verify_tx.sh` dan `tools/check_apk_release.sh` sudah diimplementasikan dan siap digunakan. |
| 7 | Skenario "server mati" tidak menghasilkan satu pun status Paid/Approved/Revoked/BTID palsu | ✅ LULUS (L1) | Diverifikasi pada level unit test: seluruh crash path menghasilkan AppFailure, bukan status sukses. L3/L4 chaos memerlukan staging. |
| 8 | Lencana liveness "SIMULASI" terlihat dan tercatat sebagai `SIMULATED` | ✅ LULUS | Phase 9 widget test lulus; model coercion anti-fake-pass aktif. |
| 9 | Dokumentasi diperbarui jujur (§6.8); tidak ada klaim fitur belum ada | ✅ LULUS | PROGRESS.md, 10 laporan fase, lembar L4 disiapkan. |
| 10 | Tinjauan PII: tidak ada MRZ/nomor paspor/nama lengkap di log atau payload audit (R9, D-8) | ✅ LULUS | ActorRef zero-PII (salted HMAC-SHA256), passportHash HMAC, tidak ada nama plaintext di audit. |
| 11 | **[F-19]** Tidak ada "Fast Demo Mode" / `demoJamesWilson()` di APK staging/prod | ✅ LULUS | 0 hit grep di lib/; guard CI Check 5 hijau. |
| 12 | **[F-20]** Tidak ada `127.0.0.1`/`localhost` di kode Dart config | ✅ LULUS | 0 hit di lib/src/core/config/ dan lib/src/core/graphql/; guard CI Check 7 hijau. |
| 13 | **[F-03b]** Tidak ada jalur Visa/Counter QR yang menghasilkan "Paid" tanpa tx nyata | ✅ LULUS | Jalur non-wallet melempar ValidationFailure; 0 keccak256 palsu. |
| 14 | **[F-09b/F-10b]** Grep `Rp 2.480.000` dan `0x7b2f8a1e` di lib/ = 0 hasil | ✅ LULUS | Guard CI Check 1 hijau. |
| 15 | **[F-11b/F-12b/F-13b]** Model fromJson tanpa default palsu | ✅ LULUS | `BtidCredentialModel.fromJson` throws FormatException; `AuditTransactionModel.fromJson` tanpa default James Wilson. Guard hijau. |
| 16 | **[F-14b]** Tidak ada MCH-3311/MCH-5520/coffee/tour di build prod | ✅ LULUS | Guard CI Check 8 hijau. |
| 17 | **[F-15b]** Ketiga titik `triggerMerchantSimulation` dihapus dari build staging/prod | ✅ LULUS | 0 hit grep di lib/; guard CI Check 6 hijau. |
| 18 | **[F-21]** Tidak ada `catch (_) {}` kosong di lib/ | ✅ LULUS | Guard CI Check 9 hijau. |

---

## RINGKASAN KEPUTUSAN

| Aspek | Status |
| :--- | :--- |
| **Kesiapan Kode** | ✅ GO — Seluruh temuan dieliminasi, 241 test lulus, reality guard 13/13 hijau |
| **Kesiapan Infrastruktur** | ⚠️ CONDITIONAL — docker-compose.staging.yml siap, seed script siap, belum di-deploy aktif |
| **Kesiapan Hardware Testing** | ⏭️ PENDING — Memerlukan 2 HP Android fisik, paspor e-passport, staging stack aktif |
| **Kesiapan Rilis Prod** | ❌ NO-GO — L4 hardware test dan L2/L3 nightly belum dijalankan terhadap staging nyata |

**Rekomendasi:** Kode siap dirilis ke staging untuk pengujian hardware. Produksi NO-GO sampai L4 sheet (E1-E18) lulus pada ≥ 2 perangkat fisik.
