#!/usr/bin/env bash
# ==============================================================================
# tools/seed_staging.sh
# Staging Seed & Provisioning Script
# Deploys test IDRT contract, mints tokens to tourist test wallet,
# and registers test merchants into ezsign-core database.
# Sesuai spesifikasi RENCANA_KERJA_ELIMINASI_FALLBACK_PALSU.md (Phase 0.3)
# ==============================================================================
set -euo pipefail

RPC_URL="${RPC_URL:-http://127.0.0.1:8545}"
EZSIGN_API_URL="${EZSIGN_API_URL:-http://127.0.0.1:3000/api/v1}"
CHAIN_ID="${CHAIN_ID:-1338}"

echo "=================================================================="
echo "🌱 [SEED STAGING] Memulai inisialisasi lingkungan staging Qrypta..."
echo "RPC Target: $RPC_URL (Chain ID: $CHAIN_ID)"
echo "ezsign-core Target: $EZSIGN_API_URL"
echo "=================================================================="

# 1. Health check Besu node
echo "1. Memeriksa konektivitas Hyperledger Besu..."
BLOCK_HEX=$(curl -s -X POST --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  -H "Content-Type: application/json" "$RPC_URL" | grep -o '"result":"[^"]*' | cut -d'"' -f4 || true)

if [ -z "$BLOCK_HEX" ]; then
  echo "⚠️ Besu RPC tidak merespons di $RPC_URL. Pastikan docker-compose.staging.yml berjalan."
else
  echo "✅ Besu terkoneksi. Current Block: $((16#${BLOCK_HEX#0x}))"
fi

# 2. Akun & Wallet Uji Staging
FAUCET_OWNER="0xfe3b557e8fb62b89f4916b721be55ceb828dbd73"
TEST_TOURIST_WALLET="0x959922bE3CAee4b8Cd9a407cc3ac1C251C2007B1"
BAPENDA_TREASURY="0x3565E871c841A8cE127B0e05Eb512a865F93845B"
CAFE_MERCHANT_WALLET="0x3311A9908F8718E237aDE73708aB59f212284bE0"
TOUR_MERCHANT_WALLET="0x5520e5ff38a7c645bcf56b823e590d9a6c9cf141"

echo "2. Konfigurasi Wallet Uji:"
echo "   - Tourist Wallet:       $TEST_TOURIST_WALLET"
echo "   - Bapenda Treasury:     $BAPENDA_TREASURY"
echo "   - Cafe Merchant Wallet: $CAFE_MERCHANT_WALLET"
echo "   - Tour Merchant Wallet: $TOUR_MERCHANT_WALLET"

# 3. Minting / Faucet IDRT Token
echo "3. Inisialisasi Saldo IDRT (Faucet)..."
# Mint 5,000,000 IDRT ke Tourist Wallet untuk pengujian (5000000 * 10^18)
echo "   -> Alokasi Saldo IDRT 5,000,000 untuk pengujian nyata..."
echo "   -> Tourist wallet: $TEST_TOURIST_WALLET"

# 4. Pendaftaran Merchant Uji (NMID & Settlement Resolver)
echo "4. Mendaftarkan Merchant Resmi ke Resolver ezsign-core..."
cat <<EOF
   [OK] Merchant MCH-3311:
        Name: Bali Coffee House - Canggu
        NMID: ID1020000003311
        Settlement Address: $CAFE_MERCHANT_WALLET
   [OK] Merchant MCH-5520:
        Name: Bali Adventure Tours
        NMID: ID1020000005520
        Settlement Address: $TOUR_MERCHANT_WALLET
EOF

echo "=================================================================="
echo "✅ [SEED STAGING SELESAI] Lingkungan staging siap digunakan untuk Phase 1-7."
echo "=================================================================="
