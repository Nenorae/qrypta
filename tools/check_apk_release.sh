#!/usr/bin/env bash
# ==============================================================================
# tools/check_apk_release.sh <path_to_apk>
# Pemeriksaan Artefak APK Rilis — Verifikasi kepatuhan keamanan & konfigurasi.
# Sesuai spesifikasi RENCANA_KERJA Phase 10 / §6.6
# ==============================================================================
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <path_to_apk>"
  echo "  path_to_apk : Path ke file APK rilis yang akan diperiksa"
  exit 1
fi

APK_PATH="$1"
FAILURES=0

if [ ! -f "$APK_PATH" ]; then
  echo "❌ File APK tidak ditemukan: $APK_PATH"
  exit 1
fi

echo "=================================================================="
echo "🔍 [APK RELEASE CHECK] Pemeriksaan Artefak APK Rilis"
echo "  APK: $APK_PATH"
echo "  Size: $(du -h "$APK_PATH" | cut -f1)"
echo "=================================================================="

# 1. Cek .env tidak ada di dalam APK
echo ""
echo "1. Memeriksa tidak ada file .env dikemas ke APK..."
ENV_FILES=$(unzip -l "$APK_PATH" 2>/dev/null | grep -i "\.env" || true)
if [ -n "$ENV_FILES" ]; then
  echo "   ❌ [FAIL] File .env ditemukan dalam APK:"
  echo "   $ENV_FILES"
  FAILURES=$((FAILURES + 1))
else
  echo "   ✅ [PASS] Tidak ada file .env dalam APK."
fi

# 2. Cek tidak ada loopback/localhost di assets flutter
echo ""
echo "2. Memeriksa tidak ada loopback/localhost di flutter assets..."
LOOPBACK_HITS=$(unzip -p "$APK_PATH" 'assets/flutter_assets/*' 2>/dev/null | grep -Ei '127\.0\.0\.1|localhost|10\.0\.2\.2' || true)
if [ -n "$LOOPBACK_HITS" ]; then
  echo "   ❌ [FAIL] Alamat loopback ditemukan di flutter assets:"
  echo "   $LOOPBACK_HITS" | head -5
  FAILURES=$((FAILURES + 1))
else
  echo "   ✅ [PASS] Tidak ada loopback di flutter assets."
fi

# 3. Cek izin Android (INTERNET, CAMERA, NFC)
echo ""
echo "3. Memeriksa deklarasi izin Android..."
AAPT_BIN=""
if command -v aapt &> /dev/null; then
  AAPT_BIN="aapt"
elif [ -n "${ANDROID_HOME:-}" ] && [ -d "$ANDROID_HOME/build-tools" ]; then
  AAPT_CANDIDATE=$(find "$ANDROID_HOME/build-tools" -name "aapt" -type f -executable 2>/dev/null | sort -V | tail -n1 || true)
  if [ -n "$AAPT_CANDIDATE" ]; then
    AAPT_BIN="$AAPT_CANDIDATE"
  fi
fi

if [ -n "$AAPT_BIN" ]; then
  PERMISSIONS=$("$AAPT_BIN" dump permissions "$APK_PATH" 2>/dev/null || true)
  
  for PERM in "android.permission.INTERNET" "android.permission.CAMERA"; do
    if echo "$PERMISSIONS" | grep -q "$PERM"; then
      echo "   ✅ [PASS] Izin $PERM dideklarasikan."
    else
      echo "   ❌ [FAIL] Izin $PERM TIDAK dideklarasikan!"
      FAILURES=$((FAILURES + 1))
    fi
  done
  
  # NFC opsional tapi diinformasikan
  if echo "$PERMISSIONS" | grep -q "android.permission.NFC"; then
    echo "   ✅ [INFO] Izin NFC dideklarasikan."
  else
    echo "   ⚠️  [WARN] Izin NFC belum dideklarasikan (diperlukan Phase 8)."
  fi
else
  echo "   ⚠️  [SKIP] aapt tidak ditemukan — periksa izin secara manual."
fi

# 4. Cek usesCleartextTraffic
echo ""
echo "4. Memeriksa AndroidManifest untuk cleartext traffic..."
MANIFEST=$(unzip -p "$APK_PATH" 'AndroidManifest.xml' 2>/dev/null | strings || true)
if echo "$MANIFEST" | grep -qi "cleartextTraffic.*true" 2>/dev/null; then
  echo "   ❌ [FAIL] usesCleartextTraffic=true terdeteksi di manifest!"
  FAILURES=$((FAILURES + 1))
else
  echo "   ✅ [PASS] Tidak ada cleartext traffic override di manifest."
fi

# 5. Cek literal terlarang di APK (binary scan)
echo ""
echo "5. Memeriksa literal terlarang di seluruh isi APK..."
FORBIDDEN_PATTERNS=("James Wilson" "BTID-2026-4471-0938" "fallbackSeed" "demoJamesWilson")
for PATTERN in "${FORBIDDEN_PATTERNS[@]}"; do
  HIT=$(unzip -p "$APK_PATH" '*.dex' 2>/dev/null | strings | grep -F "$PATTERN" || true)
  if [ -n "$HIT" ]; then
    echo "   ❌ [FAIL] Literal terlarang '$PATTERN' ditemukan dalam DEX!"
    FAILURES=$((FAILURES + 1))
  else
    echo "   ✅ [PASS] '$PATTERN' tidak ada dalam DEX."
  fi
done

# 6. Cek secret/private key exposure (basic heuristic)
echo ""
echo "6. Memeriksa potensi kebocoran secret/key..."
SECRET_PATTERNS=("PRIVATE_KEY" "private_key" "-----BEGIN" "secret_key" "api_secret")
for PATTERN in "${SECRET_PATTERNS[@]}"; do
  HIT=$(unzip -p "$APK_PATH" 'assets/*' 2>/dev/null | strings | grep -F -- "$PATTERN" || true)
  if [ -n "$HIT" ]; then
    echo "   ⚠️  [WARN] Potensi secret '$PATTERN' ditemukan di assets!"
  fi
done
echo "   ✅ [INFO] Pemeriksaan secret dasar selesai."

# Ringkasan
echo ""
echo "=================================================================="
if [ $FAILURES -gt 0 ]; then
  echo "🚨 [APK CHECK GAGAL] Ditemukan $FAILURES masalah pada artefak APK rilis!"
  exit 1
else
  echo "✅ [APK CHECK LULUS] Artefak APK rilis memenuhi standar kepatuhan."
fi
echo "=================================================================="
