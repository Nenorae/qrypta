# LEMBAR UJI E2E PERANGKAT FISIK (L4) — QRYPTA & BALI TOURIST ID
**Sesuai spesifikasi:** `RENCANA_KERJA_ELIMINASI_FALLBACK_PALSU.md` §6.7  
**Dihasilkan oleh:** Phase 10  
**Versi Template:** 1.0  

---

## INSTRUKSI PELAKSANAAN

- **Perangkat minimal:** 2 HP Android fisik (1 low-end, 1 mid/high) + 1 perangkat merchant (HP/laptop)
- **Build:** APK rilis staging (`flutter build apk --release --dart-define-from-file=env/staging.json`)
- **Jaringan:** Staging stack aktif (docker-compose.staging.yml)
- **Setiap baris:** langkah → hasil diharapkan → bukti (rekaman layar / tx hash / log) → Lulus/Gagal → penguji/tanggal/perangkat
- **Aturan:** Jangan percaya layar. Setiap "sukses" diverifikasi oleh oracle independen (`tools/verify_tx.sh`, query DB server).

---

## TABEL UJI

| #   | Skenario | Langkah | Hasil Diharapkan | Verifikasi Independen | Status | Bukti | Perangkat | Penguji | Tanggal |
| :-- | :------- | :------ | :--------------- | :-------------------- | :----- | :---- | :-------- | :------ | :------ |
| **E1** | Install APK rilis, buka tanpa jaringan | 1. Build APK staging rilis. 2. Pasang di HP fisik. 3. Matikan WiFi & data seluler. 4. Buka app. | Banner offline muncul, aksi jaringan nonaktif, saldo "Tidak tersedia", tidak ada nilai `2.480.000` atau hash statis. | Tidak ada traffic keluar via `tcpdump`/Wireshark. | ⬜ | | | | |
| **E2** | Buka dengan jaringan | 1. Nyalakan WiFi/data. 2. Buka ulang app. | Health check hijau, chainId cocok staging (1338), banner online. | `curl -X POST $RPC -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}'` == `0x53a` | ⬜ | | | | |
| **E3** | Scan paspor fisik | 1. Navigasi ke scan paspor. 2. Arahkan kamera ke halaman MRZ paspor fisik. | MRZ terbaca ≤ 10 detik; nama, DOB, kedaluwarsa sesuai paspor; check digit valid. | Bandingkan visual dengan dokumen fisik. | ⬜ | | | | |
| **E4** | Penerbitan BTID tanpa jaringan | 1. Setelah scan paspor, matikan jaringan. 2. Lanjutkan ke penerbitan BTID. | Tidak ada kartu BTID, pesan "Penerbitan belum dapat diselesaikan" + tombol "Coba Lagi". | `SELECT * FROM btid_credentials WHERE wallet='...'` di DB → kosong. | ⬜ | | | | |
| **E5** | Terbitkan BTID dengan jaringan | 1. Nyalakan jaringan. 2. Tekan "Coba Lagi" atau ulangi alur. | Nomor BTID unik dari server muncul di kartu, format `BTID-YYYY-NNNN-NNNN`, bukan `BTID-2026-4471-0938`. | Query DB server: nomor BTID cocok, record ada. | ⬜ | | | | |
| **E6** | Bayar levy (saldo cukup) | 1. Navigasi ke pembayaran levy. 2. Saldo tampil dari chain (bukan 2.480.000). 3. Bayar. | Status `pending` → `confirmed`, UI menampilkan "Paid" HANYA setelah ack server, kuitansi dengan hash nyata. | `tools/verify_tx.sh <txHash>` → status 0x1, log Transfer valid, `balanceOf` turun sesuai nominal. | ⬜ | | | | |
| **E7** | Bayar levy saat RPC mati | 1. Matikan Besu staging (`docker stop qrypta-besu-staging`). 2. Coba bayar levy. | Error `NetworkUnreachable` / timeout; TIDAK ada status "Paid"; TIDAK ada kuitansi palsu. | `balanceOf` sebelum & sesudah SAMA (tidak berubah). | ⬜ | | | | |
| **E8** | Buka kembali kuitansi levy | 1. Navigasi ke riwayat transaksi. 2. Buka kuitansi levy dari E6. | Hash di kuitansi = hash yang sama dari E6, bukan `0x7b2f8a1e...` statis. | Bandingkan hash manual. | ⬜ | | | | |
| **E9** | Pindai QRIS merchant terdaftar | 1. Pindai stiker QRIS fisik merchant terdaftar. 2. Konfirmasi pembayaran. | Parser EMVCo membaca TLV + CRC valid, nama merchant benar dari registry, transfer terkonfirmasi on-chain. | `tools/verify_tx.sh <txHash>` + log merchant sim. | ⬜ | | | | |
| **E10** | Pindai QRIS merchant tidak terdaftar | 1. Pindai stiker QRIS merchant yang TIDAK terdaftar di konsorsium. | Pesan "Merchant belum terdaftar di Qrypta", TIDAK ada transaksi. | Tidak ada tx baru di chain. | ⬜ | | | | |
| **E11** | Pindai QRIS dengan CRC dirusak | 1. Tampilkan QR QRIS dengan CRC sengaja diubah 1 karakter. 2. Scan. | Payload ditolak: "CRC tidak valid". | — | ⬜ | | | | |
| **E12** | Merchant scan QR dinamis turis | 1. Turis buka Dynamic QR. 2. Merchant scan QR via `tools/merchant_sim/`. | Permintaan consent muncul di HP turis < 5 detik (WiFi) / < 8 detik (4G). | Log server: entry verification request. | ⬜ | | | | |
| **E13** | Setujui consent | 1. Turis tekan "Setujui" pada layar consent. | Server mencatat consent, merchant menerima hasil approved. | DB server: record consent `status=approved`, `syncStatus=synced`. | ⬜ | | | | |
| **E14** | Cabut akses | 1. Turis navigasi ke "Akses Aktif". 2. Tekan "Cabut" pada merchant dari E13. | Merchant menerima event revoked, akses tak lagi valid. | Percobaan ulang akses oleh merchant → ditolak. | ⬜ | | | | |
| **E15** | Cabut akses saat server mati | 1. Matikan ezsign-core. 2. Cabut akses. | Banner "Pencabutan belum terkirim, merchant mungkin masih memiliki akses" (oranye). Outbox mencatat entry `pending_sync`. 3. Hidupkan ezsign-core. 4. Outbox mengirim ulang otomatis. | DB server setelah pulih: revocation tersimpan. | ⬜ | | | | |
| **E16** | App di-background, merchant scan | 1. Turis minimize app (bukan kill). 2. Merchant scan QR dinamis yang masih valid. | Notifikasi push muncul, membuka layar consent saat di-tap. | Log FCM/server. | ⬜ | | | | |
| **E17** | Liveness wajah (simulasi) | 1. Navigasi ke step liveness di alur verifikasi. | Lencana "SIMULASI / DEMO" terlihat jelas; kredensial mencatat `liveness: {mode: SIMULATED, verified: false}`. | Inspect payload BTID credential. | ⬜ | | | | |
| **E18** | NFC paspor-e (jika Phase 8 aktif) | 1. Navigasi ke step NFC. 2. Tempelkan paspor elektronik fisik. | Data DG1 cocok MRZ, Passive Authentication valid (atau `UNVERIFIED_NO_TRUST_ANCHOR` jika negara tidak di trust store). | Log PA detail, fixture. | ⬜ | | | | |

---

## CATATAN PENTING

1. **Status legend:** `⬜ Belum` / `✅ Lulus` / `❌ Gagal` / `⏭️ Dilewati (alasan)`
2. Setiap "Gagal" wajib dilaporkan dengan detail: langkah mana, apa yang terjadi vs diharapkan, screenshot/rekaman.
3. E7 dan E15 (skenario server mati) adalah **pengujian paling kritis** — satu pun status sukses palsu = gagal total.
4. Seluruh tes E1-E18 harus dijalankan pada **minimal 2 perangkat berbeda** sebelum rilis.
5. Lembar ini diisi ulang setiap siklus rilis.
