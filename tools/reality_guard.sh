#!/usr/bin/env bash
# ==============================================================================
# tools/reality_guard.sh
# CI Guard: Gagalkan build jika ada mekanisme fallback palsu, literal terlarang,
# silent catch, atau loopback hardcoded di direktori produksi (lib/ & env/).
# Sesuai spesifikasi RENCANA_KERJA_ELIMINASI_FALLBACK_PALSU.md (Phase 0.4)
# ==============================================================================
set -euo pipefail

FAILURES=0

echo "🔍 [REALITY GUARD] Memulai audit integritas kode..."

# 1. Pengecekan Literal Palsu Terlarang di lib/
FORBIDDEN='James Wilson|BTID-2026-4471-0938|2\.480\.000|0x7b2f8a1e|fallbackSeed|MCH-3311|MCH-5520|1988-04-12|2031-08-15'
if grep -rEn "$FORBIDDEN" lib/ 2>/dev/null; then
  echo "❌ [FAIL] Literal palsu terlarang ditemukan di lib/"
  FAILURES=$((FAILURES + 1))
else
  echo "✅ [PASS] Tidak ada literal palsu dasar di lib/"
fi

# 2. Pengecekan keccak256 untuk pemalsuan txHash di luar node
if grep -rEn "txHash\s*=\s*['\"]0x\\\$\{bytesToHex\(keccak256" lib/ 2>/dev/null; then
  echo "❌ [FAIL] Pemalsuan txHash via keccak256 lokal ditemukan di lib/"
  FAILURES=$((FAILURES + 1))
else
  echo "✅ [PASS] Tidak ada pemalsuan txHash via keccak256 di lib/"
fi

# 3. Pengecekan catch kosong / hanya developer.log
if grep -rEnz "catch \(\w+\) \{\s*(developer\.log\([^;]*\);)?\s*\}" lib/ 2>/dev/null; then
  echo "❌ [FAIL] Catch kosong atau hanya developer.log ditemukan di lib/"
  FAILURES=$((FAILURES + 1))
else
  echo "✅ [PASS] Tidak ada catch kosong / hanya log di lib/"
fi

# 4. Pengecekan loopback pada konfigurasi release/staging
if grep -rEn "127\.0\.0\.1|localhost|10\.0\.2\.2" env/prod* env/staging* 2>/dev/null; then
  echo "❌ [FAIL] Alamat loopback ditemukan pada file konfigurasi non-dev!"
  FAILURES=$((FAILURES + 1))
else
  echo "✅ [PASS] Tidak ada loopback di konfigurasi env non-dev"
fi

# 5. [F-19] Factory demo demoJamesWilson() tidak boleh ada di lib/
if grep -rEn "demoJamesWilson\(\)" lib/ 2>/dev/null; then
  echo "❌ [FAIL] [F-19] MrzParseResult.demoJamesWilson() ditemukan di lib/ (harus di flavor dev atau test/)"
  FAILURES=$((FAILURES + 1))
else
  echo "✅ [PASS] Tidak ada demoJamesWilson() di lib/"
fi

# 6. [F-19/F-15b] Tombol demo / fast bypass / simulasi in-app tanpa guard flavor
if grep -rEn "Fast Demo Mode|triggerMerchantSimulation" lib/ 2>/dev/null; then
  echo "❌ [FAIL] [F-19/F-15b] Tombol Fast Demo atau triggerMerchantSimulation ditemukan di lib/"
  FAILURES=$((FAILURES + 1))
else
  echo "✅ [PASS] Tidak ada tombol demo/simulasi tanpa guard di lib/"
fi

# 7. [F-20] Loopback hardcoded di kode Dart (bukan hanya .env)
if grep -rEn "127\.0\.0\.1|localhost" lib/src/core/config/ lib/src/core/graphql/ 2>/dev/null; then
  echo "❌ [FAIL] [F-20] Alamat loopback hardcoded ditemukan di lib/src/core/config/ atau graphql/"
  FAILURES=$((FAILURES + 1))
else
  echo "✅ [PASS] Tidak ada loopback hardcoded di config Dart"
fi

# 8. [F-14b] String-match merchant primitif (coffee/tour/MCH-3311/MCH-5520) di features
if grep -rEn "'coffee'|\"coffee\"|'tour'|\"tour\"|MCH-3311|MCH-5520" lib/src/features/ 2>/dev/null | grep -v "policy_matrix_constants\|test\|flavor" ; then
  echo "❌ [FAIL] [F-14b] String-match merchant primitif ditemukan di lib/src/features/ (harus diganti EMVCo)"
  FAILURES=$((FAILURES + 1))
else
  echo "✅ [PASS] Tidak ada string-match merchant primitif di features/"
fi

# 9. [F-21] Catch benar-benar kosong total: catch (_) {}
if grep -rEn "catch \(_\) \{\}" lib/ 2>/dev/null; then
  echo "❌ [FAIL] [F-21] catch (_) {} kosong total ditemukan di lib/ (wajib melempar AppFailure)"
  FAILURES=$((FAILURES + 1))
else
  echo "✅ [PASS] Tidak ada catch (_) {} kosong di lib/"
fi

# 10. [F-13b] visaType hardcoded e-VOA B1 di lib/
if grep -rEn "e-VOA B1" lib/ 2>/dev/null; then
  echo "❌ [FAIL] [F-13b] Hardcoded visaType 'e-VOA B1' ditemukan di lib/"
  FAILURES=$((FAILURES + 1))
else
  echo "✅ [PASS] Tidak ada hardcoded visaType di lib/"
fi

# 11. [F-01] MobileScanner tidak boleh digunakan di mrz_scanner_screen.dart (wajib Google ML Kit)
if grep -rEn "MobileScanner" lib/src/features/authentication/presentation/screens/mrz_scanner_screen.dart 2>/dev/null; then
  echo "❌ [FAIL] [F-01] MobileScanner masih digunakan di mrz_scanner_screen.dart (wajib ML Kit Text Recognition)"
  FAILURES=$((FAILURES + 1))
else
  echo "✅ [PASS] [F-01] MobileScanner berhasil dieliminasi dari pemindai MRZ"
fi

# 12. [F-12/R3] Literal 'JAMES WILSON' (huruf besar) tidak boleh ada di lib/
if grep -rEn "JAMES WILSON" lib/ 2>/dev/null; then
  echo "❌ [FAIL] [F-12/R3] Literal 'JAMES WILSON' ditemukan di lib/"
  FAILURES=$((FAILURES + 1))
else
  echo "✅ [PASS] Tidak ada literal 'JAMES WILSON' di lib/"
fi

echo "=================================================================="
if [ $FAILURES -gt 0 ]; then
  echo "🚨 [REALITY GUARD MERAH] Ditemukan $FAILURES pelanggaran fatal integritas kode!"
  echo "Build/CI DITOLAK sampai seluruh fallback palsu dieliminasi."
  exit 1
else
  echo "🎉 [REALITY GUARD HIJAU] Seluruh kode mematuhi Golden Rules integritas."
  exit 0
fi
