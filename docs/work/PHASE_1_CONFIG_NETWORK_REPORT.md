# LAPORAN HASIL EKSEKUSI PHASE 1: KONFIGURASI DINAMIS & SANITASI JARINGAN
**Proyek:** Qrypta & Bali Tourist ID  
**Dokumen Referensi:** [RENCANA_KERJA_ELIMINASI_FALLBACK_PALSU.md](file:///home/ganen/qrypta/docs/RENCANA_KERJA_ELIMINASI_FALLBACK_PALSU.md)  
**Dokumen Baseline:** [PHASE_0_BASELINE_REPORT.md](file:///home/ganen/qrypta/docs/work/PHASE_0_BASELINE_REPORT.md)  
**Branch Kerja:** `fix/real-behavior`  
**Waktu Eksekusi:** 17 November 2026  

---

## 1. EKSEKUTIF SUMMARY & TUJUAN PHASE 1

Phase 1 berfokus pada **penghapusan total ilusi koneksi lokal dan mekanisme konfigurasi statis yang rapuh**:
1. **Eliminasi Paket `.env` & flutter_dotenv (F-02):** File `.env` yang sebelumnya dibundel ke dalam APK rilis telah dikeluarkan dari deklarasi aset `pubspec.yaml`, dan dependensi `flutter_dotenv` telah dicabut seluruhnya dari codebase.
2. **Eliminasi Loopback Hardcoded di Dart (F-20):** Seluruh fallback alamat `127.0.0.1` dan `localhost` pada file konfigurasi Dart (`blockchain_config.dart`, `graphql_provider.dart`, `token_service.dart`, `payment_controller.dart`) telah dihapus secara tuntas.
3. **Pemberlakuan Golden Rule R5 via `ConfigValidator`:** Build release, staging, maupun prod menolak start secara permanen jika mendeteksi alamat loopback/emulator (`127.0.0.0/8`, `localhost`, `10.0.2.2`, `::1`) atau skema protokol tidak aman (`http://`).
4. **Pemantauan Kesehatan Jaringan Otoritatif (`NetworkHealthService`):** Mengimplementasikan health-check nyata dan reaktif terhadap node JSON-RPC Hyperledger Besu (`eth_chainId`, `eth_blockNumber`) serta gateway `ezsign-core` (`GET /health`), dilengkapi deteksi *chain ID mismatch* dan komponen UI banner peringatan (`NetworkStatusBanner`).
5. **Sanitasi Platform Android (F-22):** Menambahkan deklarasi izin `CAMERA` dan `NFC` pada `AndroidManifest.xml` utama serta membatasi kelonggaran lalu lintas cleartext HTTP hanya pada build mode debug melalui `network_security_config.xml`.

Seluruh target Phase 1 diselesaikan dengan clean code, terverifikasi via 13 pengujian unit baru (Level L1) dan 56 dari 56 pengujian proyek lulus 100%.

---

## 2. RINCIAN PEKERJAAN & REFAKTORING (CLEAN CODE)

### 2.1 Arsitektur Konfigurasi Baru: `AppConfig` (`lib/src/core/config/app_config.dart`)
Mekanisme runtime `dotenv.env['KEY']` digantikan secara struktural oleh strongly-typed compile-time constants melalui `String.fromEnvironment` dan `int.fromEnvironment`:
- Mendukung pemisahan lingkungan build: `dev`, `staging`, `prod` melalui flag standar Flutter:
  `flutter run --dart-define-from-file=env/dev.json`
  `flutter build apk --release --dart-define-from-file=env/staging.json`
- File konfigurasi lokal (`env/*.json`) dikecualikan dari version control via `.gitignore`, sementara file template terdaftar (`env/*.example.json`) disimpan sebagai referensi tim.

### 2.2 Penegakan Golden Rule R5: `ConfigValidator` (`lib/src/core/config/config_validator.dart`)
Dipanggil pada awal fungsi `main()` sebelum `runApp`:
- **Pemeriksaan Kelengkapan:** Memastikan variabel krusial tidak kosong (`RPC_URL`, `CHAIN_ID > 0`, `GRAPHQL_URL`, `EZSIGN_API_URL`, `IDRT_CONTRACT_ADDRESS`, `BAPENDA_TREASURY_ADDRESS`).
- **Validasi Format Alamat:** Memverifikasi integritas alamat hex Ethereum (0x + 40 karakter hex).
- **Aturan Ketat Non-Dev (Staging & Prod):**
  - Skema RPC wajib `https` atau `wss`.
  - Skema API / GraphQL wajib `https`.
  - Host dilarang menggunakan alamat loopback (`127.*`, `localhost`, `10.0.2.2`, `0.0.0.0`, `::1`).
- **Fail-Safe UI Screen (`ConfigErrorApp`):** Jika konfigurasi melanggar aturan, aplikasi tidak crash diam-diam, melainkan menyajikan antarmuka diagnostik bertema gelap yang merinci setiap pelanggaran secara transparan.

### 2.3 Eliminasi Loopback di Layanan Terkait
- **[blockchain_config.dart](file:///home/ganen/qrypta/lib/src/core/config/blockchain_config.dart):** Menghapus seluruh ternary `dotenv.env['RPC_URL'] ?? 'http://127.0.0.1:8545'`. Mengubah class menjadi fasad murni yang mendelegasikan pemanggilan langsung ke `AppConfig`.
- **[graphql_provider.dart](file:///home/ganen/qrypta/lib/src/core/graphql/graphql_provider.dart):** Mengarahkan endpoint GraphQL langsung ke `AppConfig.graphqlUrl` tanpa dependensi `dotenv`.
- **[token_service.dart](file:///home/ganen/qrypta/lib/src/features/tokens/data/token_service.dart):** Membaca parameter IDRT resmi (`AppConfig.idrtContractAddress`, `AppConfig.idrtDecimals`, dll).
- **[payment_controller.dart](file:///home/ganen/qrypta/lib/src/features/transaction/logic/payment_controller.dart):** Menghapus impor `flutter_dotenv` dan membaca alamat kontrak IDRT langsung dari `AppConfig`.

### 2.4 Health Check Jaringan Otoritatif: `NetworkHealthService` (`lib/src/core/services/network/`)
- Melakukan probe berkala terhadap:
  1. `ezsign-core`: Endpoint `GET {EZSIGN_API_URL}/health`.
  2. `Hyperledger Besu`: Batch JSON-RPC `eth_chainId` dan `eth_blockNumber`.
- Menilai kesesuaian `reportedChainId` dari node dengan `AppConfig.chainId`. Jika berbeda, status jaringan ditandai sebagai `ComponentStatus.degraded` dengan error spesifik.
- Menyediakan `NetworkHealthNotifier` berbasis Riverpod dan banner `NetworkStatusBanner` di bagian atas dashboard (`HomeScreen`), sehingga user mendapatkan peringatan seketika saat RPC down, tanpa ada pemalsuan keberhasilan transaksi.

### 2.5 Android Platform Hardening
1. **[AndroidManifest.xml (Main)](file:///home/ganen/qrypta/android/app/src/main/AndroidManifest.xml):**
   - Menambahkan izin `android.permission.CAMERA` dan fitur hardware kamera opsional.
   - Menambahkan izin `android.permission.NFC` dan fitur hardware NFC opsional.
2. **[network_security_config.xml (Debug Only)](file:///home/ganen/qrypta/android/app/src/debug/res/xml/network_security_config.xml):**
   - Mengizinkan cleartext HTTP secara eksklusif pada target build debug/emulator dev.
   - Target release tetap menerapkan proteksi bawaan Android (cleartext diblokir secara default).

---

## 3. BUKTI PENGUJIAN & VERIFIKASI (VERIFICATION EVIDENCE)

### 3.1 Status CI Guard (`tools/reality_guard.sh`)
Eksekusi terhadap codebase setelah Phase 1:
```bash
$ ./tools/reality_guard.sh
...
✅ [PASS] Tidak ada loopback di konfigurasi env non-dev
✅ [PASS] Tidak ada loopback hardcoded di config Dart
==================================================================
🚨 [REALITY GUARD MERAH] Ditemukan 8 pelanggaran fatal integritas kode!
```
- **Check 4 (Konfigurasi non-dev):** **HIJAU / LULUS**
- **Check 7 (F-20 Loopback Dart):** **HIJAU / LULUS** (berhasil dieliminasi dari `lib/src/core/config/` dan `graphql/`).
- Pelanggaran tersisa turun dari 9 ke 8 (pelanggaran yang tersisa berada dalam lingkup Phase 2, 3, 4, 5A, 5B, 6, 7).

### 3.2 Pengujian Unit (Level L1)
Dijalankan via `flutter test`:
- `test/config_validator_test.dart` (9 test):
  - Validasi konfigurasi `dev`, `staging`, `prod`.
  - Penolakan alamat loopback (`127.0.0.1`, `localhost`, `10.0.2.2`, `::1`) pada staging/prod.
  - Penolakan skema cleartext HTTP pada staging/prod.
  - Penerimaan skema WSS pada RPC.
  - Penolakan format alamat Ethereum yang cacat.
  - Penolakan chain ID non-positif.
  - Penolakan flavor tidak dikenal.
- `test/network_health_service_test.dart` (4 test):
  - Pelaporan `OverallHealthStatus.online` saat Besu RPC dan EzSign sehat.
  - Pelaporan `OverallHealthStatus.degraded` saat EzSign mengembalikan error 503.
  - Pelaporan `OverallHealthStatus.degraded` saat terjadi Chain ID mismatch.
  - Pelaporan `OverallHealthStatus.offline` saat koneksi terputus total.
- **Hasil Keseluruhan:** **56 dari 56 test LULUS 100%**.

---

## 4. DAFTAR VARIABEL ASLI APLIKASI (ENVIRONMENT VARIABLES GUIDE)

Berikut adalah daftar variabel konfigurasi asli yang harus diisikan pada file `env/staging.json` atau `env/prod.json` saat menghubungkan aplikasi ke jaringan server nyata:

| Nama Variabel | Tipe Data | Wajib? | Keterangan & Aturan Nilai | Contoh Nilai Staging | Contoh Nilai Produksi |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`FLAVOR`** | String | Ya | Lingkungan aplikasi: `dev`, `staging`, atau `prod`. | `"staging"` | `"prod"` |
| **`RPC_URL`** | String (URI) | Ya | Endpoint JSON-RPC node Hyperledger Besu. Wajib berawalan `https://` atau `wss://` pada staging & prod. Tidak boleh loopback/IP emulator. | `"https://besu-staging.qrypta.id:8545"` | `"https://rpc.qrypta.id"` |
| **`CHAIN_ID`** | Integer | Ya | EVM Chain ID resmi dari jaringan Hyperledger Besu yang dituju. Harus bilangan bulat > 0. Node RPC akan divalidasi harus cocok dengan nilai ini. | `"1338"` | `"2026"` |
| **`NETWORK_NAME`** | String | Tidak | Nama display jaringan yang akan ditampilkan pada label antarmuka pengguna. | `"Hyperledger Besu Bali Testnet"` | `"Bali Sovereign Chain Net"` |
| **`CURRENCY_SYMBOL`**| String | Tidak | Simbol gas/mata uang native jaringan (misal: `ETH` atau `BALI`). | `"BALI"` | `"BALI"` |
| **`GRAPHQL_URL`** | String (URI) | Ya | Endpoint GraphQL untuk query riwayat transaksi/indexer. Wajib `https://` pada staging & prod. | `"https://indexer.staging.qrypta.id/graphql"` | `"https://indexer.qrypta.id/graphql"` |
| **`EZSIGN_API_URL`** | String (URI) | Ya | Endpoint API middleware `ezsign-core` (Fastify service). Wajib `https://` pada staging & prod. | `"https://api.staging.qrypta.id/api/v1"` | `"https://api.qrypta.id/api/v1"` |
| **`IDRT_CONTRACT_ADDRESS`** | String (Hex) | Ya | Alamat kontrak pintar token ERC-20 Indonesian Rupiah Token (IDRT). Format hex 42 karakter (0x...). | `"0xF12b5dd4EAD5F743C6BaA640B0216200e89B60Da"` | `"0x<Alamat_IDRT_Resmi_Mainnet>"` |
| **`IDRT_NAME`** | String | Tidak | Nama representasi token IDRT. | `"Rupiah Token"` | `"Rupiah Token"` |
| **`IDRT_SYMBOL`** | String | Tidak | Simbol ticker token. | `"IDRT"` | `"IDRT"` |
| **`IDRT_DECIMALS`** | Integer | Tidak | Presisi desimal token ERC-20 IDRT (standar: 18). | `"18"` | `"18"` |
| **`BAPENDA_TREASURY_ADDRESS`** | String (Hex) | Ya | Alamat dompet / smart contract resmi kas daerah Bapenda Provinsi Bali penerima Tourist Levy. Format hex 42 karakter (0x...). | `"0x3565E871c841A8cE127B0e05Eb512a865F93845B"` | `"0x3565E871c841A8cE127B0e05Eb512a865F93845B"` |
| **`LIVENESS_MODE`** | String | Tidak | Mode verifikasi liveness wajah (`simulated` atau `real`). Per §0.2 modul wajah adalah satu-satunya modul simulasi berizin. | `"simulated"` | `"simulated"` |

### 4.1 Cara Menjalankan & Membangun APK Menggunakan Variabel di Atas

1. **Menjalankan pada mode Dev (Localhost / Android Emulator):**
   ```bash
   flutter run --dart-define-from-file=env/dev.json
   ```

2. **Menjalankan / Build APK Staging (Jaringan Uji Nyata):**
   ```bash
   flutter build apk --release --dart-define-from-file=env/staging.json
   ```

3. **Membangun APK Rilis Produksi (Production Sovereign Net):**
   ```bash
   flutter build apk --release --dart-define-from-file=env/prod.json
   ```

---

## 5. KESIMPULAN & LANGKAH SELANJUTNYA

Phase 1 telah rampung 100%:
- **F-02** (`.env` ikut ke APK) : **TERSELESAIKAN**
- **F-20** (Hardcoded loopback Dart) : **TERSELESAIKAN**
- **Golden Rule R5** (Pencegahan build tidak aman) : **TERPASANG & TERVERIFIKASI**
- **Integritas Jaringan** : **TERPASANG DENGAN HEALTH-CHECK OTORITATIF**

Aplikasi kini berada dalam fondasi konfigurasi yang solid dan siap memasuki **Phase 2: Fondasi Arsitektur (Model AppFailure, State Machine Transaksi, dan Hive Outbox Sync)**.
