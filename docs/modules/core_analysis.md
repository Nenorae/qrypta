# Laporan Analisis Teknis Komprehensif: Core Architecture (`lib/src/core/`)

Dokumen ini merupakan referensi teknis mendalam mengenai arsitektur, spesifikasi protokol, peran setiap komponen, mekanisme komunikasi kode, serta evaluasi kritis terhadap celah keamanan (*vulnerabilities*), bug kompilasi, dan utang teknis (*technical debt*) pada direktori `lib/src/core/`.

---

## 1. Executive Summary & Spesifikasi Teknis

Direktori `lib/src/core/` bertindak sebagai fondasi infrastruktur utama aplikasi Qrypta. Modul ini menyediakan abstraksi konektivitas blockchain (EVM/Hyperledger Besu), protokol querying/mutasi (JSON-RPC & GraphQL), sistem penyimpanan cache offline, manajemen tema grafis, utilitas matematis/kriptografis presisi tinggi, dan otentikasi keamanan perangkat keras.

### 1.1 Matriks Spesifikasi Teknis Core

| Komponen | Pustaka / Spesifikasi | Versi Dependensi | Keterangan Teknis |
| :--- | :--- | :--- | :--- |
| **Language & SDK** | Dart SDK | `^3.7.0` | Menjalankan *Sound Null Safety* tanpa kompromi. |
| **Framework UI** | Flutter Material 3 | `sdk: flutter` | Sistem tema gelap terpusat (`darkTheme`) dan shared UI components. |
| **Web3 Client (RPC)** | `web3dart` / `http` | `^2.7.1` / `^1.4.0` | Klien JSON-RPC Ethereum/Besu (EIP-155, ABI Encoding/Decoding, `eth_call`). |
| **Indexer Client** | `graphql_flutter` / `graphql` | `^5.2.1` / `^5.2.3` | Pengambilan data terindeks & mutasi raw tx via GraphQL Link. |
| **Offline Cache** | `hive_ce` / `hive_ce_flutter` | `^2.0.0` | Persistensi cache GraphQL query berbasis binary storage (`HiveStore`). |
| **State Management** | `flutter_riverpod` | `^2.6.1` | Dependency Injection (DI) & Lifecycle Management (`blockchainServiceProvider`). |
| **Hardware Security** | `local_auth` | `^2.3.0` | Biometrik (Fingerprint/FaceID) & Fallback Device PIN/Passcode. |
| **Kriptografi & Encoding** | `crypto` / `convert` | `^3.0.6` / `^3.1.2` | Hashing Keccak-256, Hex Encoding/Decoding. |
| **Environment Config** | `flutter_dotenv` | `^6.0.0` | Pengelolaan variabel lingkungan runtime (`.env`). |

### 1.2 Topologi & Standar Kriptografi EVM
* **Standar Kurva Kriptografi:** ECDSA dengan kurva eliptik `secp256k1` (`EthPrivateKey`).
* **Format Alamat (Addressing):** Alamat 20-byte berbasis Keccak-256 hash dari *uncompressed public key*, mendukung validasi checksum format EIP-55.
* **Protokol Transaksi:** Transaksi EVM legacy dengan proteksi *replay attack* EIP-155 menggunakan `chainId: 1337` (Hyperledger Besu / Local Devnet).
* **Presisi Numerik Aset:** Semua representasi saldo mentah (*raw balance*) menggunakan tipe data `BigInt` (256-bit unsigned integer) guna menghindari presisi terpotong pada batas floating point IEEE 754 (maksimal 53 bit mantissa).

---

## 2. Dekonstruksi Terperinci Peran Setiap Folder & File

Struktur hirarki berkas pada `lib/src/core/`:

```
lib/src/core/
├── config/
│   ├── blockchain_config.dart       # Parameter node RPC, chain ID, dan simbol kurensi
│   ├── router/
│   │   └── app_router.dart          [FILE KOSONG: 0 Bytes]
│   └── theme/
│       ├── app_colors.dart          # Palet warna primer, background, aksen, font
│       └── app_theme.dart           # Definisi ThemeData (Material 3 Dark Theme)
├── data/
│   ├── models/
│   │   ├── .gitkeep
│   │   └── token_model.dart         # Model DTO token ERC-20 presisi BigInt
│   └── repositories/
│       └── wallet_repository.dart   [KOMPILASI ERROR: Undefined getMyWalletQuery]
├── error/
│   └── exceptions.dart              # Hirarki custom exceptions (Server, Network, WalletNotFound)
├── graphql/
│   ├── graphql_provider.dart        # Inisialisasi GraphQLClient dengan cache persisten Hive
│   └── queries.dart                 # Query & mutation string GraphQL (Assets, Discovery, RawTx)
├── services/
│   ├── authentication_service.dart  # Wrapper statis local_auth biometrik OS
│   ├── services_summary.md          # Dokumentasi ringkas service blockchain
│   └── blockchain/
│       ├── blockchain_service.dart  # Facade / Gateway utama seluruh interaksi Web3
│       ├── erc20_service.dart       # Interaksi smart contract ERC-20 via ABI JSON murni
│       ├── native_currency_service.dart # Transaksi & saldo native currency (ETH/Wei)
│       ├── transaction_service.dart # Layanan hibrida: GraphQL history & RPC polling receipt
│       └── wallet_service.dart      # Utilitas kriptografi murni Dart (kunci & validasi hex)
├── shared_widgets/
│   ├── custom_button.dart           [FILE KOSONG: 0 Bytes]
│   ├── error_display_widget.dart    # Widget presentasi error dengan aksi retry
│   └── loading_indicator.dart       [FILE KOSONG: 0 Bytes]
└── utils/
    ├── constants.dart               [FILE KOSONG: 0 Bytes]
    └── formatters.dart              # Formatter alamat hex terpotong & format BigInt/Ether
```

### 2.1 Direktori `config/`
* **`blockchain_config.dart`**:
  - Menyimpan konstanta konfigurasi statis:
    - `rpcUrl = "http://100.92.191.4:8545"` (Endpoint node Besu).
    - `chainId = 1337` (EIP-155 Chain ID).
    - `name = "Besu Private Net"`.
    - `currencySymbol = "ETH"`.
  - Berperan sebagai sumber acuan parameter blockchain untuk inisialisasi client.
* **`router/app_router.dart`**:
  - Berukuran **0 byte**. Awalnya dirancang untuk konfigurasi routing deklaratif (seperti `go_router`), namun implementasi navigasi di aplikasi masih menggunakan `Navigator.push` secara imperatif di level widget.
* **`theme/app_colors.dart`**:
  - Menetapkan warna hex konstan: `background = Color(0xFF032221)`, `primary = Color(0xFF03624C)`, `accent = Color(0xFF03624C)`, dan `font = Color(0xFFEFE9E7)`.
* **`theme/app_theme.dart`**:
  - Memetakan `AppColors` ke dalam `ThemeData.darkTheme` (AppBar, ColorScheme, Input Decoration, ElevatedButton, dan ChipTheme).

### 2.2 Direktori `error/`
* **`exceptions.dart`**:
  - `ServerException`: Dilemparkan saat node RPC / indexer backend menolak request atau eksekusi smart contract me-revert state.
  - `NetworkException`: Mengisolasi kegagalan transmisi socket HTTP, DNS, atau koneksi terputus.
  - `WalletNotFoundException`: Mengindikasikan dompet belum terdaftar pada indexer GraphQL.

### 2.3 Direktori `shared_widgets/`
* **`error_display_widget.dart`**:
  - Komponen presentasi standar yang menampilkan icon error, pesan human-readable, dan tombol coba lagi (`onRetry`).
* **`loading_indicator.dart` & `custom_button.dart`**:
  - Berukuran **0 byte** (kosong tanpa kode), menyebabkan duplikasi implementasi widget loading dan tombol secara lokal di fitur-fitur lain.

### 2.4 Direktori `graphql/`
* **`graphql_provider.dart`**:
  - Menginisialisasi `GraphQLClient` via Riverpod `graphqlClientProvider`.
  - Menggunakan `HttpLink` yang mengarah ke endpoint hardcoded `http://100.92.191.4:4000/graphql`.
  - Memanfaatkan `GraphQLCache(store: HiveStore())` untuk offline-first caching hasil kueri riwayat transaksi.
* **`queries.dart`**:
  - Dokumen kueri GraphQL:
    - `getMyAssetsQuery`: Query saldo seluruh token ERC-20 milik `walletAddress`.
    - `getDiscoverTokensQuery`: Query pagination penemuan token di ekosistem.
    - `sendRawTransactionMutation`: Mutasi pengiriman hex transaksi tertanda (`signedTransactionHex`) ke relayer backend.

### 2.5 Direktori `utils/`
* **`formatters.dart`**:
  - `formatAddress`: Memotong alamat hex EVM (`0x1234...5678`) untuk estetika UI.
  - `formatEther`: Memformat double menggunakan `NumberFormat` dari package `intl`.
  - `formatBigInt`: Mengonversi nilai `BigInt` (satuan Wei) ke representasi desimal berdasarkan jumlah desimal token ($10^{\text{decimals}}$).
* **`constants.dart`**:
  - Berukuran **0 byte** (kosong).

### 2.6 Direktori `data/`
* **`models/token_model.dart`**:
  - Model DTO immutable untuk token ERC-20: `contractAddress`, `symbol`, `name`, `decimals`, `balance` (`BigInt`), dan `logoUrl`.
  - Dilengkapi factory `TokenModel.fromJson` yang melakukan parsing nilai saldo via `BigInt.parse()`.
* **`repositories/wallet_repository.dart`**:
  - Menghubungkan query GraphQL secara reaktif via `watchWalletAssets()`.
  - Menggunakan kebijakan `FetchPolicy.cacheAndNetwork`.
  - Di-inject via Riverpod `walletRepositoryProvider`.

### 2.7 Direktori `services/`
* **`authentication_service.dart`**:
  - Abstraksi tipis di atas `local_auth` dengan method statis `authenticate(String reason)`.
  - Mengonfigurasi `AuthenticationOptions(biometricOnly: false, stickyAuth: true)`.
* **`blockchain/blockchain_service.dart` (The Facade/Gateway)**:
  - Menyediakan single entry point untuk interaksi Web3 via `blockchainServiceProvider`.
  - Menginisialisasi satu instance `Web3Client` bersama untuk RPC Besu.
  - Mengorkestrasi dan menyuntikkan client ke 4 sub-service:
    - `wallet = WalletService()` (kriptografi lokal).
    - `nativeCurrency = NativeCurrencyService(_client)` (interaksi ETH native).
    - `erc20 = Erc20Service(_client)` (interaksi smart contract ERC-20).
    - `transaction = TransactionService(_client, graphQLClient)` (layanan transaksi hibrida).
  - Mengelola siklus hidup resource (`client.dispose()`) yang diikatkan pada Riverpod `ref.onDispose()`.
* **`blockchain/wallet_service.dart`**:
  - Operasi kriptografi lokal murni Dart tanpa dependensi jaringan:
    - `isValidAddress`: Validasi string hex menggunakan `EthereumAddress.fromHex()`.
    - `createRandomPrivateKey`: Membangkitkan entropi CSPRNG via `Random.secure()` untuk membentuk `EthPrivateKey`.
    - `getAddressFromPrivateKey`: Derivasi deterministik alamat EVM dari private key.
    - `getPrivateKeyHex`: Konversi byte array kunci privat ke format hex `0x...`.
* **`blockchain/erc20_service.dart`**:
  - Mengelola komunikasi Smart Contract standar ERC-20.
  - Memetakan ABI JSON secara murni (`ContractAbi.fromJson`) ke `DeployedContract`:
    - `balanceOf(address)`: Mengambil saldo via `_client.call()` (`eth_call`).
    - `transfer(to, value)`: Membangun `Transaction.callContract` dan menandatanganinya dengan private key untuk disiarkan via `_client.sendTransaction()`.
    - `getTokenDetails`: Mengambil metadata `name`, `symbol`, dan `decimals` secara paralel via `Future.wait()`.
    - `validateTokenContract`: *Dry-run* verifikasi kontrak dengan memanggil fungsi `name()`.
* **`blockchain/native_currency_service.dart`**:
  - Mengelola aset dasar jaringan (ETH):
    - `getBalance`: Memanggil RPC `eth_getBalance` untuk mendapatkan saldo dalam unit terkecil (Wei).
    - `sendTransaction`: Membangun objek `Transaction(to, value)` dan menyiarkannya menggunakan chain ID EIP-155.
* **`blockchain/transaction_service.dart`**:
  - **Layanan Hibrida (Hybrid RPC & GraphQL):**
    - Sisi GraphQL:
      - `sendSignedTransaction`: Relay signed hex via mutasi `sendRawTransactionMutation`.
      - `getRecentTransactions`: Pengambilan riwayat transaksi terpaginasi via query `getTransactionsByAddress`.
      - `getTransactionByHash`: Query data transaksi individual dari indexer backend.
    - Sisi RPC (Web3Client):
      - `getTransactionReceipt`: Mengambil receipt via `eth_getTransactionReceipt`.
      - `waitForTransactionReceipt`: Polling asynchronous berbasis `Timer.periodic` (interval 2 detik, timeout 60 detik) yang dibungkus dalam `Completer<TransactionReceipt>`.
      - `getNonce`: Mengambil `transactionCount` akun pengirim via `eth_getTransactionCount`.
      - `estimateTransactionFee`: Menghitung estimasi gas berdasarkan `gasPrice` dikalikan estimasi flat 21,000 gas.

---

## 3. Cara Kode Berkomunikasi (Communication Patterns & Pipelines)

Komunikasi antar-komponen di dalam `core` dan interaksinya dengan layer fitur mengikuti beberapa pola terstruktur:

### 3.1 Pola Arsitektur Utama (Design Patterns)
1. **Facade / Gateway Pattern (`BlockchainService`):**
   Layer UI maupun Feature Controller tidak perlu membuat koneksi RPC atau menginisialisasi sub-service sendiri. Cukup menggunakan `blockchainServiceProvider`:
   ```dart
   // Contoh dari layer fitur:
   ref.read(blockchainServiceProvider).erc20.getErc20Balance(contract, address);
   ref.read(blockchainServiceProvider).transaction.waitForTransactionReceipt(txHash);
   ```
2. **Dependency Injection via Riverpod Container:**
   `Web3Client` dan `GraphQLClient` dibuat sebagai singleton provider yang dikelola siklus hidupnya oleh Riverpod. Teardown koneksi HTTP socket dipicu otomatis saat provider dihancurkan.
3. **Pemisahan Jalur Hibrida (Hybrid Split):**
   - **JSON-RPC (Port 8545)**: Khusus untuk operasi *state machine* on-chain yang membutuhkan status konsensus mutlak (eksekusi smart contract, saldo real-time, nonce, receipt).
   - **GraphQL (Port 4000)**: Khusus untuk data agregasi terindeks (riwayat transaksi, discovery token) dan antrean mutasi relay.

### 3.2 Diagram Aliran Data (Data Flow Pipeline)

#### Pipeline A: Eksekusi Transaksi ERC-20 On-Chain
```
[UI Screen / Notifier]
       │
       │ 1. Parameter: privateKey, contractHex, recipientHex, amount
       ▼
[BlockchainService] ──delegasi──► [Erc20Service]
                                         │
                                         ├─► 2. EthereumAddress.fromHex(recipient)
                                         ├─► 3. EthPrivateKey.fromHex(privateKey)
                                         ├─► 4. ContractAbi.fromJson(...) -> DeployedContract
                                         ├─► 5. Transaction.callContract('transfer', [to, amount])
                                         │
                                         ▼
                                  [Web3Client]
                                         │
                                         ├─► 6. eth_getTransactionCount (Nonce)
                                         ├─► 7. Offline Local Sign (ECDSA secp256k1 + EIP-155 ChainId)
                                         ├─► 8. HTTP POST JSON-RPC: eth_sendRawTransaction
                                         ▼
                              [Besu Blockchain Node]
                                         │
       ▲ 10. Return txHash               ▼
       └───────────────────────── 9. Return Transaction Hash
```

#### Pipeline B: Polling Konfirmasi Status Transaksi (`waitForTransactionReceipt`)
```
[Caller / SendController]
       │
       │ 1. Memanggil waitForTransactionReceipt(txHash)
       ▼
[TransactionService]
       │
       ├─► 2. Inisialisasi Completer<TransactionReceipt>()
       ├─► 3. Membuat Timer.periodic(Duration(seconds: 2))
       │        │
       │        ▼ (Loop berkala per 2 detik)
       │     [Web3Client.getTransactionReceipt(txHash)]
       │        │
       │        ├── [Hasil: null] ──► Lanjutkan loop
       │        └── [Hasil: Receipt] ──► Cancel Timer ──► Completer.complete(receipt)
       │
       ▼ (Timeout 60 detik)
  Completer.future (Mengembalikan Receipt ke UI atau melempar TimeoutException)
```

#### Pipeline C: Kueri Riwayat Transaksi via GraphQL
```
[TransactionFeature / UI]
       │
       ▼ 1. Query: getRecentTransactions(address, page, limit)
[TransactionService]
       │
       ▼ 2. _graphQLClient.query(QueryOptions(fetchPolicy: networkOnly))
[GraphQLClient]
       │
       ├─► 3. Hit Indexer API (http://100.92.191.4:4000/graphql)
       ▼
[Indexer Database / Blockscan]
       │
       ▼ 4. JSON Payload: { data: { getTransactionsByAddress: { transactions: [...], totalCount } } }
[TransactionService]
       │
       ▼ 5. Parsing DTO: TransactionPage.fromJson(...)
[UI Presentation Layer]
```

#### Pipeline D: Verifikasi Keamanan Biometrik
```
[Sensitive Action: Expose Key / Sign Tx]
       │
       ▼ 1. AuthenticationService.authenticate(reason)
[LocalAuthentication (Platform Channel)]
       │
       ├─► 2. OS Gatekeeper (Android BiometricPrompt / iOS LAContext)
       │        │
       │        ├── Hardware Match (Fingerprint/FaceID) ──► Return true
       │        ├── Fallback Match (PIN/Passcode) ────────► Return true
       │        └── Cancel/Failure ───────────────────────► Return false
       ▼
[UI / Controller]: Izinkan proses dilanjutkan atau batalkan aksi.
```

---

## 4. Analisis Kritis: Celah Keamanan, Bug Kompilasi, & Utang Teknis

Analisis kode baris per baris dan hasil pemeriksaan `dart analyze lib/src/core` mengungkap sejumlah isu teknis fundamental:

### 4.1 Fatal Compilation Error: Unresolved Identifier
* **Lokasi Temuan**: `lib/src/core/data/repositories/wallet_repository.dart:13:21`
  ```dart
  final WatchQueryOptions options = WatchQueryOptions(
    document: gql(getMyWalletQuery), // <--- ERROR: Undefined name 'getMyWalletQuery'
    ...
  );
  ```
* **Akar Masalah**: Konstanta yang didefinisikan pada `lib/src/core/graphql/queries.dart` adalah `getMyAssetsQuery`, bukan `getMyWalletQuery`.
* **Dampak**: Kompilasi Dart pada layer data core mengalami kegagalan fatal (`dart analyze` exit code 3).

### 4.2 Ghost Files (Berkas Kosong 0 Byte)
Ditemukan empat berkas kosong tanpa konten:
1. `lib/src/core/config/router/app_router.dart` (0 byte)
2. `lib/src/core/shared_widgets/loading_indicator.dart` (0 byte)
3. `lib/src/core/shared_widgets/custom_button.dart` (0 byte)
4. `lib/src/core/utils/constants.dart` (0 byte)
* **Dampak**: Mengaburkan arsitektur shared components dan memicu duplikasi widget lokal di berbagai modul fitur.

### 4.3 Hardcoded Endpoints Jaringan & Pengabaian `.env`
* **Lokasi**:
  - `BlockchainConfig.rpcUrl = "http://100.92.191.4:8545"` (`blockchain_config.dart`)
  - `_kGraphQLEndpoint = 'http://100.92.191.4:4000/graphql'` (`graphql_provider.dart`)
  - `BlockchainConfig.chainId = 1337`
* **Masalah**: Meskipun pustaka `flutter_dotenv` sudah di-load di `main.dart`, modul `core` sama sekali tidak membaca konfigurasi dari `dotenv.env['RPC_URL']`.
* **Dampak**: Perpindahan lingkungan (Local Besu $\rightarrow$ Testnet $\rightarrow$ Mainnet) memerlukan modifikasi hardcoded string dan *recompile* binary aplikasi. IP lokal pengembang juga bocor di repository.

### 4.4 Tabrakan Nama Class (*Namespace Collision*) & Pelanggaran Model DTO
* **Lokasi**: `lib/src/core/services/blockchain/transaction_service.dart`
* **Masalah**: File ini mendeklarasikan class `Transaction` lokal, sementara file ini juga mengimpor pustaka `web3dart` yang memiliki class internal `web3dart.Transaction`.
* **Dampak**: Membingungkan impor di file lain (harus menggunakan alias atau terbentur shadowing) dan melanggar prinsip *Clean Architecture* karena model DTO GraphQL dideklarasikan di dalam file service, bukan di `core/data/models/`.

### 4.5 Kerentanan Presisi Floating Point pada `formatBigInt`
* **Lokasi**: `lib/src/core/utils/formatters.dart`
  ```dart
  String formatBigInt(BigInt value, int decimals) {
    if (value == BigInt.zero) return '0.00';
    final asDouble = value / BigInt.from(10).pow(decimals);
    return formatEther(asDouble.toDouble());
  }
  ```
* **Akar Masalah**: Operator `/` pada `BigInt` menghasilkan nilai `double` berbasis IEEE 754 (mantissa maksimal 53-bit / ~15–17 digit presisi). Token standar memiliki 18 desimal. Nilai saldo token bernilai besar (seperti IDRT miliaran) akan mengalami pemotongan presisi desimal (*precision truncation/rounding error*).

### 4.6 Estimasi Gas yang Salah untuk Kontrak ERC-20
* **Lokasi**: `lib/src/core/services/blockchain/transaction_service.dart`
  ```dart
  final estimatedGas = BigInt.from(21000); // Standard transfer
  ```
* **Akar Masalah**: Nilai 21,000 gas hanya berlaku untuk transfer native ETH langsung antar akun EOA (*Externally Owned Account*). Eksekusi fungsi `transfer` pada smart contract ERC-20 memerlukan komputasi mutasi storage state (rata-rata 50,000 hingga 90,000 unit gas).
* **Dampak**: Estimasi biaya gas token ERC-20 yang ditampilkan kepada pengguna sebelum transaksi akan jauh lebih rendah daripada biaya riil on-chain, memicu potensi transaksi gagal akibat *out of gas*.

### 4.7 Penanganan Kunci Privat Mentah dalam Memori (*Plaintext In-Memory*)
* **Lokasi**:
  - `NativeCurrencyService.sendTransaction(String privateKey, ...)`
  - `Erc20Service.sendErc20Token({required String privateKey, ...})`
* **Akar Masalah**: Private key dilewatkan sebagai parameter bertipe `String` primitif. Objek `String` di Dart adalah *immutable* dan disimpan di dalam heap memory Garbage Collector (GC), sehingga tidak dapat dibersihkan (*memory wiped / zeroed-out*) setelah transaksi selesai.

### 4.8 Ketiadaan Manajemen Nonce Dinamis & Proteksi Race Condition
* Pada `Erc20Service` dan `NativeCurrencyService`, transaksi dikirim tanpa menyertakan parameter `nonce` eksplisit. Jika pengguna mengeksekusi dua transaksi secara berurutan dalam rentang waktu singkat, RPC node akan menolak transaksi kedua akibat *nonce duplicate* atau *nonce replacement underpriced*.

### 4.9 Desain Service Statis yang Menghambat Pengujian (*Untestable Static Service*)
* `AuthenticationService` seluruh method-nya didefinisikan sebagai `static`. Hal ini menciptakan *tight-coupling* yang menghalangi penggunaan *mocking* atau *faking* saat membuat unit testing pada layer controller atau presentation.

### 4.10 Pelanggaran Dependensi & Deprecated API
* **Missing Dependency**: `lib/src/core/utils/formatters.dart` mengimpor `package:intl/intl.dart`, namun pustaka `intl` **tidak terdaftar secara eksplisit** di `pubspec.yaml`.
* **Deprecated API**: `lib/src/core/config/theme/app_theme.dart` menggunakan `Color.withOpacity(0.5)` yang telah digantikan oleh `Color.withValues(alpha: 0.5)`.

---

## 5. Matriks Rekomendasi Solusi & Rencana Refaktor

| Prioritas | Masalah | Dampak Teknis | Rekomendasi Solusi Refaktor |
| :--- | :--- | :--- | :--- |
| **P0 - Blocker** | Compile Error `getMyWalletQuery` | Kompilasi layer data core gagal. | Ubah nama query di `wallet_repository.dart` menjadi `getMyAssetsQuery` atau perbaiki deklarasi skema GraphQL indexer. |
| **P1 - Critical** | Hardcoded Endpoints | IP lokal bocor & konfigurasi tidak fleksibel. | Refaktor `BlockchainConfig` dan `graphql_provider.dart` agar membaca nilai dinamis dari `dotenv.get('RPC_URL')` dan `dotenv.get('GRAPHQL_URL')`. |
| **P1 - Critical** | Estimasi Gas Kontrak ERC-20 | Transaksi token berisiko gagal (*out of gas*). | Perbarui `estimateTransactionFee` agar menerima data payload smart contract dan memanggil RPC `_client.estimateGas()`. |
| **P2 - Major** | Tabrakan Nama `Transaction` | Shadowing class `web3dart.Transaction`. | Pindahkan DTO transaksi GraphQL ke `core/data/models/indexed_transaction.dart`. |
| **P2 - Major** | Presisi Aritmatika Desimal | Truncation pada saldo token bernilai tinggi. | Gunakan manipulasi string desimal atau package presisi arbitrer (seperti `decimal`) sebelum konversi ke UI. |
| **P2 - Major** | Ghost Files (0 Byte) | Kebingungan arsitektur & duplikasi widget. | Hapus file kosong atau lengkapi implementasinya (misal `AppRouter` via `go_router`, button & indicator bersama). |
| **P2 - Major** | Dependensi `intl` Tidak Terdaftar | Potensi gagal build saat dependensi transitif berubah. | Tambahkan `intl: ^0.19.0` secara eksplisit pada blok `dependencies` di `pubspec.yaml`. |
| **P3 - Minor** | Abstraksi `AuthenticationService` | Tidak dapat di-mock saat unit testing. | Ubah menjadi kelas instansiasi yang didaftarkan ke Riverpod `authServiceProvider`. |
| **P3 - Minor** | Deprecated API `withOpacity` | Muncul warning pada compiler Flutter. | Ganti seluruh `.withOpacity(x)` menjadi `.withValues(alpha: x)`. |
