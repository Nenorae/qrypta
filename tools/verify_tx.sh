#!/usr/bin/env bash
# ==============================================================================
# tools/verify_tx.sh <txHash>
# Oracle Independen: Verifikasi transaksi on-chain tanpa mempercayai UI app.
# Sesuai spesifikasi RENCANA_KERJA Phase 10 / §6.5
# ==============================================================================
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <txHash> [rpc_url]"
  echo "  txHash  : Hash transaksi EVM (0x...)"
  echo "  rpc_url : (opsional) URL JSON-RPC Besu, default dari RPC_URL env"
  exit 1
fi

TX_HASH="$1"
RPC="${2:-${RPC_URL:-http://127.0.0.1:8545}}"

echo "=================================================================="
echo "🔍 [VERIFY TX] Oracle Independen — Verifikasi Transaksi On-Chain"
echo "  TX Hash : $TX_HASH"
echo "  RPC URL : $RPC"
echo "=================================================================="

# 1. Ambil receipt
echo ""
echo "1. Mengambil eth_getTransactionReceipt..."
RECEIPT=$(curl -s -X POST "$RPC" -H 'Content-Type: application/json' \
  --data "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"eth_getTransactionReceipt\",\"params\":[\"$TX_HASH\"]}")

RESULT=$(echo "$RECEIPT" | jq -r '.result')

if [ "$RESULT" = "null" ] || [ -z "$RESULT" ]; then
  echo "❌ [GAGAL] Transaksi TIDAK DITEMUKAN di blockchain."
  echo "   Receipt null — transaksi belum di-mine atau hash salah."
  echo "   Raw response: $RECEIPT"
  exit 1
fi

STATUS=$(echo "$RECEIPT" | jq -r '.result.status')
BLOCK=$(echo "$RECEIPT" | jq -r '.result.blockNumber')
FROM=$(echo "$RECEIPT" | jq -r '.result.from')
TO=$(echo "$RECEIPT" | jq -r '.result.to')
LOGS_COUNT=$(echo "$RECEIPT" | jq -r '.result.logs | length')
GAS_USED=$(echo "$RECEIPT" | jq -r '.result.gasUsed')

echo "   Status     : $STATUS"
echo "   Block      : $BLOCK (dec: $((16#${BLOCK#0x})))"
echo "   From       : $FROM"
echo "   To         : $TO"
echo "   Gas Used   : $GAS_USED"
echo "   Logs Count : $LOGS_COUNT"

# 2. Verifikasi status
echo ""
echo "2. Verifikasi Status Receipt..."
if [ "$STATUS" = "0x1" ]; then
  echo "   ✅ Status = 0x1 (SUCCESS) — Transaksi berhasil di-mine."
else
  echo "   ❌ Status = $STATUS (REVERTED/FAILED) — Transaksi gagal on-chain."
  exit 1
fi

# 3. Verifikasi log Transfer (ERC-20)
echo ""
echo "3. Memeriksa Log Event Transfer ERC-20..."
# Transfer(address,address,uint256) keccak256 topic
TRANSFER_TOPIC="0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"

TRANSFER_LOG=$(echo "$RECEIPT" | jq -r --arg topic "$TRANSFER_TOPIC" \
  '.result.logs[] | select(.topics[0] == $topic) | {from: .topics[1], to: .topics[2], value: .data}')

if [ -z "$TRANSFER_LOG" ]; then
  echo "   ⚠️  Tidak ada log Transfer ERC-20 ditemukan."
  echo "   Ini mungkin bukan transaksi ERC-20, atau kontrak tidak meng-emit Transfer."
else
  echo "   ✅ Log Transfer ditemukan:"
  echo "$TRANSFER_LOG" | jq .
fi

# 4. Ambil detail transaksi
echo ""
echo "4. Mengambil eth_getTransactionByHash untuk detail..."
TX_DETAIL=$(curl -s -X POST "$RPC" -H 'Content-Type: application/json' \
  --data "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"eth_getTransactionByHash\",\"params\":[\"$TX_HASH\"]}")

TX_VALUE=$(echo "$TX_DETAIL" | jq -r '.result.value')
TX_INPUT=$(echo "$TX_DETAIL" | jq -r '.result.input')
TX_NONCE=$(echo "$TX_DETAIL" | jq -r '.result.nonce')

echo "   Value (native) : $TX_VALUE"
echo "   Nonce           : $TX_NONCE"
echo "   Input Data Len  : ${#TX_INPUT} chars"

# 5. Ringkasan
echo ""
echo "=================================================================="
if [ "$STATUS" = "0x1" ]; then
  echo "✅ [VERIFY TX PASS] Transaksi $TX_HASH VALID dan CONFIRMED on-chain."
else
  echo "❌ [VERIFY TX FAIL] Transaksi $TX_HASH GAGAL on-chain."
fi
echo "=================================================================="
