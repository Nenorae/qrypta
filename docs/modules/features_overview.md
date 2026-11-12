# Laporan Analisis Teknis Komprehensif: Arsitektur Fitur (`lib/src/features/`)

Dokumen ini menyajikan dekonstruksi teknis mendalam terhadap seluruh modul fitur pada aplikasi Qrypta (`lib/src/features/`). Analisis ini mencakup arsitektur sistem, spesifikasi kriptografi, peran spesifik setiap file, mekanisme komunikasi kode lintas modul (*inter-feature* dan *core-layer communication*), serta evaluasi kritis terhadap celah keamanan (*vulnerabilities*), bug aritmatika desimal, dan utang teknis (*technical debt*).

---

## 1. Executive Summary & Arsitektur Global

Lapisan `features/` menerapkan kombinasi pola **Clean Architecture** (pada modul *authentication* dan *transaction*) dan **Feature-Driven Architecture** berbasis Riverpod. Terdapat 7 (tujuh) modul utama:

```
lib/src/features/
├── authentication/   # Manajemen identitas kriptografi, seed phrase, derivasi kunci, dan PIN
├── home/             # Dashboard agregasi saldo multi-aset (Native ETH & ERC-20 IDRT)
├── tokens/           # Pengelolaan aset terverifikasi ERC-20 (IDRT) via integrasi .env & RPC
├── transaction/      # Eksekusi transfer on-chain, polling receipt, riwayat transaksi, dan QR
├── profile/          # Pengaturan keamanan, otorisasi biometrik untuk ekspor rahasia, auto-lock
├── qr_scanner/       # Kontainer pemindai terpadu (Send Scanner & Receive QR dalam PageView)
└── testing/          # Modul diagnostik konektivitas RPC blockchain
```

### Matriks Spesifikasi Teknis Fitur

| Parameter | Spesifikasi Teknis | Implementasi Lapisan Fitur |
| :--- | :--- | :--- |
| **Pola Arsitektur** | Clean Architecture & Feature-First | Pemisahan Domain (Use Cases/Repo Interface), Data (Datasource/Repo Impl), Application (Service), dan Presentation (Riverpod/UI). |
| **Kriptografi Asimetris** | ECDSA `secp256k1` | Derivasi alamat EVM via path BIP-44 `m/44'/60'/0'/0/0`. |
| **Mnemonic Standard** | BIP-39 | Entropi kata acak 12–24 kata dengan PBKDF2 seed derivation (512-bit). |
| **Checksum Alamat** | EIP-55 Checksum | Validasi format hex mixed-case melalui `EthereumAddress`. |
| **State Management** | `flutter_riverpod` (^2.6.1) | `Notifier`, `StateNotifierProvider`, `FutureProvider`, dan `Provider`. *(Catatan: Masih terdapat residu `package:provider` / `ChangeNotifier`)*. |
| **Hardware Security** | Biometrik OS (`local_auth`) | Gatekeeper sebelum aksi pembukaan private key dan mnemonic. |
| **Penyimpanan Sensitif**| Keystore / Keychain (`flutter_secure_storage` ^9.2.4) | Enkripsi AES/RSA untuk seed phrase, private key, dan PIN. |
| **Komputasi Paralel** | Flutter Background Isolate | Eksekusi fungsi berat (`compute()`) pada derivasi kunci dan hashing Keccak-256. |
| **Hardware Kamera** | `mobile_scanner` (^7.0.1) | Analisis frame barcode untuk ekstraksi alamat penerima hex. |

---

## 2. Dekonstruksi Terperinci Peran Setiap Folder & File

### 2.1 Modul `authentication/`

Modul ini bertanggung jawab atas seluruh siklus hidup kredensial kriptografi pengguna. Mengadopsi Clean Architecture paling lengkap di dalam proyek.

```
lib/src/features/authentication/
├── application/
│   └── auth_service.dart
├── data/
│   ├── datasources/
│   │   └── authentication_local_data_source.dart
│   └── repositories/
│       └── authentication_repository_impl.dart
├── domain/
│   ├── repositories/
│   │   └── authentication_repository.dart
│   └── usecases/
│       ├── generate_mnemonic_usecase.dart
│       ├── get_checksum_address_usecase.dart
│       ├── get_pin_usecase.dart
│       ├── get_private_key_from_mnemonic_usecase.dart
│       ├── get_private_key_usecase.dart
│       ├── get_public_key_usecase.dart
│       ├── save_mnemonic_usecase.dart
│       ├── save_pin_usecase.dart
│       ├── save_private_key_usecase.dart
│       ├── validate_mnemonic_usecase.dart
│       └── verify_pin_usecase.dart
└── presentation/
    ├── providers/
    │   ├── auth_providers.dart
    │   ├── pin_provider.dart
    │   └── wallet_provider.dart
    └── screens/
        ├── auth_wrapper.dart
        ├── login_screen.dart
        ├── pin_verification_screen.dart
        ├── signup_screen.dart
        ├── wallet_setup_screen.dart
        ├── wallet_setup_seed_phrase_screen.dart
        ├── wallet_setup_seed_verification_screen.dart
        ├── wallet_setup_pin_screen.dart
        ├── wallet_setup_pin_confirmation_screen.dart
        └── welcome_screen.dart
```

#### A. Domain Layer (`domain/`)
* **`repositories/authentication_repository.dart`**: Interface kontrak bisnis yang mendefinisikan seluruh kapabilitas autentikasi, seperti `generateMnemonic()`, `getPrivateKeyFromMnemonic()`, `savePrivateKey()`, `savePin()`, dan `verifyPin()`.
* **Use Cases (11 File)**: Masing-masing use case merepresentasikan *single responsibility principle*:
  - `generate_mnemonic_usecase.dart`: Meminta generasi frasa mnemonic BIP-39 baru.
  - `get_private_key_from_mnemonic_usecase.dart`: Menderivasi seed master dan private key sesuai derivation path EVM.
  - `get_public_key_usecase.dart` & `get_checksum_address_usecase.dart`: Mengonversi private key menjadi representasi public key dan alamat ber-checksum EIP-55.
  - `validate_mnemonic_usecase.dart`: Memvalidasi panjang kata (12, 15, 18, 21, 24) dan checksum frasa.
  - `save_pin_usecase.dart`, `verify_pin_usecase.dart`, `get_pin_usecase.dart`: Manajemen verifikasi kode PIN aplikasi.
  - `save_private_key_usecase.dart`, `get_private_key_usecase.dart`, `save_mnemonic_usecase.dart`: Persistensi kunci rahasia.

#### B. Data Layer (`data/`)
* **`datasources/authentication_local_data_source.dart`**:
  - Membungkus instance `FlutterSecureStorage`.
  - Mengelola penyimpanan kunci: `'privateKey'`, `'mnemonic'`, dan `'pin'`.
* **`repositories/authentication_repository_impl.dart`**:
  - Implementasi konkrit dari `AuthenticationRepository`.
  - Menggunakan fungsi top-level terisolasi yang dijalankan via `compute()` untuk menjaga UI thread tetap pada 60/120 FPS:
    - `_generateMnemonic()`: Memanggil pustaka `package:wallet` untuk menghasilkan daftar 12 kata acak.
    - `_getPrivateKeyFromMnemonic()`: Menghasilkan 512-bit seed via `wallet.mnemonicToSeed()`, membangkitkan `ExtendedPrivateKey.master`, lalu menderivasi sub-path `m/44'/60'/0'/0/0`.
    - `_getPublicKey()`, `_getCustomBlockchainAddress()`, `_getChecksumAddress()`.
    - `_isMnemonicValid()`: Pengecekan kata dan verifikasi seed generation.

#### C. Application Layer (`application/`)
* **`auth_service.dart`**: Bertindak sebagai *facade* yang mengonsolidasikan 8 use case inti untuk menyederhanakan pemanggilan oleh Controller/Presentation layer.

#### D. Presentation Layer (`presentation/`)
* **Providers (`presentation/providers/`)**:
  - `auth_providers.dart`: Konfigurasi *Dependency Injection Tree* menggunakan Riverpod. Menyediakan `authStateProvider` (mengevaluasi ketersediaan private key dan PIN untuk menentukan status login) dan `walletSecretsProvider` (lazy loading data rahasia).
  - `pin_provider.dart`: `PinNotifier` mengelola `PinState` (`isLoading`, `pin`, `error`).
  - `wallet_provider.dart`: `WalletNotifier` mengelola state pembentukan dompet baru (`WalletState`).
* **Screens (`presentation/screens/`)**:
  - `auth_wrapper.dart`: Mengarahkan alur ke `WalletSetupScreen` jika dompet belum terdaftar.
  - `wallet_setup_screen.dart`: Titik awal onboarding (Pilihan: Buat Dompet Baru atau Import Frasa).
  - `wallet_setup_seed_phrase_screen.dart`: Menampilkan 12 kata frasa mnemonic dalam format kartu grid interaktif.
  - `wallet_setup_seed_verification_screen.dart`: Memvalidasi pemahaman pengguna dengan meminta penyusunan ulang kata-kata acak.
  - `wallet_setup_pin_screen.dart` & `wallet_setup_pin_confirmation_screen.dart`: Alur input dan konfirmasi 6 digit PIN.
  - `pin_verification_screen.dart`: Layar otentikasi PIN saat membuka kunci aplikasi.
  - `login_screen.dart`: Form import dompet melalui frasa mnemonic yang sudah ada.
  - `welcome_screen.dart` & `signup_screen.dart`: Layar registrasi berbasis data identitas (Username & NIK) — *saat ini berstatus orphan/legacy*.

---

### 2.2 Modul `home/`

Modul ini bertindak sebagai dashboard utama pengguna, menyajikan total portofolio aset dan navigasi cepat.

```
lib/src/features/home/
├── logic/
│   └── home_controller.dart
├── presentation/
│   ├── providers/
│   │   └── home_providers.dart
│   ├── screens/
│   │   └── home_screen.dart
│   └── widgets/
│       ├── action_buttons.dart
│       ├── balance_card.dart
│       └── home_body_widgets.dart
```

* **`home_controller.dart`**: Menggunakan `ChangeNotifier` untuk mengontrol `selectedIndex` pada Bottom Navigation Bar.
* **`home_providers.dart`**:
  - `nativeBalanceProvider`: `FutureProvider<EtherAmount>` yang mengambil alamat publik pengguna dari `userWalletAddressProvider`, lalu memanggil RPC `blockchainService.nativeCurrency.getBalance()`.
  - `totalBalanceProvider`: Mengagregasikan saldo native ETH dan seluruh token ERC-20 dari `tokenNotifierProvider`. Menghitung nilai konversi Rupiah dengan asumsi paritas 1:1 antara IDRT/GLD dan IDR:
    $$\text{Total IDR} = \sum \left( \frac{\text{rawBalance}}{10^{\text{decimals}}} \right)$$
* **`home_screen.dart`**:
  - Struktur scaffold utama aplikasi dengan `RefreshIndicator` yang memicu pembaruan on-chain:
    ```dart
    ref.invalidate(totalBalanceProvider);
    await ref.read(tokenNotifierProvider.notifier).fetchUserTokens();
    ```
  - Menyediakan FAB / menu akses cepat untuk membuka modal aksi transaksi (`ActionButtons`).
* **`home_body_widgets.dart`**:
  - `BalanceSection`: Menampilkan akumulasi portofolio dalam format mata uang IDR (`NumberFormat.currency(locale: 'id_ID', symbol: 'Rp. ')`).
  - `AssetList`: Menampilkan daftar token secara vertikal, menyertakan Native ETH sebagai baris teratas (gas fee asset) diikuti oleh daftar token ERC-20.
* **`action_buttons.dart`**: Lembar modal aksi cepat (Send, Receive, Swap, Payment).

---

### 2.3 Modul `tokens/`

Modul ini bertanggung jawab atas integrasi token ERC-20 (khususnya Rupiah Token / IDRT) pada jaringan privat Hyperledger Besu.

```
lib/src/features/tokens/
├── data/
│   └── token_service.dart
└── presentation/
    ├── providers/
    │   └── token_provider.dart
    └── screens/
        └── manage_tokens_screen.dart
```

* **`data/token_service.dart`**:
  - Bertindak sebagai penyedia metadata token resmi yang diinjeksi via variabel lingkungan (`.env`):
    - `IDRT_CONTRACT_ADDRESS`, `IDRT_NAME`, `IDRT_SYMBOL`, `IDRT_DECIMALS`.
  - Mengembalikan daftar `List<TokenModel>` dengan saldo awal nol (`BigInt.zero`).
* **`presentation/providers/token_provider.dart`**:
  - `TokenNotifier`: `StateNotifier<AsyncValue<List<TokenModel>>>`.
  - Mekanisme sinkronisasi: Membaca alamat dompet aktif pengguna dari `userWalletAddressProvider`, lalu melakukan iterasi pada setiap token dari `TokenService` dan mengeksekusi RPC langsung:
    ```dart
    final newBalance = await blockchainService.erc20.getErc20Balance(
      token.contractAddress,
      userAddress,
    );
    ```
  - State diperbarui dengan objek `TokenModel` baru yang memuat saldo `BigInt` termutakhir dari blockchain.
* **`presentation/screens/manage_tokens_screen.dart`**:
  - Layar daftar aset token yang dilengkapi efek visual animasi `ShimmerLoadingList` saat status loading.
  - Setiap kartu aset memiliki tombol aksi cepat `Send` yang langsung membuka form `SendScreen(token: token)`.

---

### 2.4 Modul `transaction/`

Modul paling kompleks pada layer fitur yang mengelola siklus hidup penuh transaksi EVM: konstruksi, offline signing, broadcast RPC, polling receipt, dan query riwayat terindeks.

```
lib/src/features/transaction/
├── data/
│   └── repositories/
│       └── transaction_repository_impl.dart
├── domain/
│   ├── repositories/
│   │   └── transaction_repository.dart
│   └── usecases/
│       └── get_recent_transactions_usecase.dart
├── logic/
│   ├── send_controller.dart
│   └── transaction_controller.dart
├── presentation/
│   ├── providers/
│   │   └── transaction_providers.dart
│   ├── screens/
│   │   ├── confirmation_screen.dart
│   │   ├── receive_screen.dart
│   │   ├── send_scanner_screen.dart
│   │   ├── send_screen.dart
│   │   └── transaction_history_screen.dart
│   └── widgets/
│       └── transaction_list_item.dart
```

#### A. Data & Domain Layer
* **`TransactionRepository` & `TransactionRepositoryImpl`**:
  - Interface dan implementasi untuk menjembatani komunikasi ke GraphQL indexer melalui delegasi ke `BlockchainService.transaction.getRecentTransactions()`.
* **`GetRecentTransactionsUseCase`**:
  - Menjalankan kueri riwayat transaksi terpaginasi berdasarkan `userAddressHex`.

#### B. Logic Layer
* **`send_controller.dart`**:
  - `SendController`: Riverpod `Notifier<SendState>`.
  - Mengelola `TextEditingController` untuk alamat penerima dan jumlah transfer.
  - **Alur Eksekusi Pengiriman**:
    1. Validasi teks alamat dan nominal $> 0$.
    2. Mengambil private key pengirim dari secure storage via `getPrivateKeyUseCaseProvider`.
    3. Percabangan Tipe Aset:
       - **Native ETH**: Mengonversi jumlah ke `EtherAmount` lalu memanggil `blockchainService.nativeCurrency.sendTransaction()`.
       - **ERC-20 (IDRT)**: Mengalikan nominal input dengan $10^{\text{decimals}}$, mengonversi ke `BigInt`, lalu mengeksekusi `blockchainService.erc20.sendErc20Token()`.
    4. Menyimpan hash transaksi yang dihasilkan ke dalam `SendState.transactionHash`.
* **`transaction_controller.dart`**:
  - Controller warisan (*legacy*) berbasis `ChangeNotifier` yang memuat alamat dompet atau membuat dompet baru secara otomatis jika private key kosong.

#### C. Presentation & Screens
* **`transaction_providers.dart`**:
  - `userWalletAddressProvider`: Mengambil private key dari storage dan menderivasi alamat publik EIP-55 secara reaktif.
  - `transactionHistoryProvider`: Memuat data transaksi GraphQL berdasarkan alamat publik pengguna.
* **`send_screen.dart`**:
  - Form input pengiriman aset. Mendengarkan state `sendControllerProvider` via `ref.listen` untuk melakukan navigasi otomatis ke `ConfirmationPage` begitu `transactionHash` diterbitkan.
* **`confirmation_screen.dart`**:
  - Layar pemantau status transaksi *real-time*.
  - Menjalankan `blockchainService.transaction.waitForTransactionReceipt(widget.transactionHash)` dengan batas timeout 5 menit.
  - Menampilkan feedback visual status: *Processing* (oranye), *Success* (hijau), atau *Failed/Unknown* (merah/amber).
* **`receive_screen.dart`**:
  - Menampilkan representasi alamat dompet dalam bentuk QR Code (`qr_flutter`) dan teks hex terpotong.
  - Menyediakan tombol salin ke clipboard dan integrasi share sheet (`share_plus`).
* **`send_scanner_screen.dart`**:
  - Tampilan kamera penuh menggunakan `MobileScanner`.
  - Menggunakan `CustomPainter` (`ScannerOverlayPainter`) untuk menggambar overlay semi-transparan dengan jendela lubang bidik di bagian tengah.
* **`transaction_history_screen.dart` & `transaction_list_item.dart`**:
  - Menampilkan riwayat transaksi keluar (merah) dan masuk (hijau) lengkap dengan nomor blok dan pemotongan alamat hex.

---

### 2.5 Modul `profile/`

Mengelola preferensi pengguna, keamanan perangkat, dan otorisasi pengungkapan data rahasia.

```
lib/src/features/profile/
├── application/
│   └── security_settings_notifier.dart   [FILE DUPLIKAT / DEAD CODE]
├── presentation/
│   ├── providers/
│   │   └── security_settings_provider.dart
│   ├── screens/
│   │   ├── change_pin_screen.dart        [PLACEHOLDER STUB]
│   │   ├── profile_screen.dart
│   │   └── reveal_secret_screen.dart
│   └── widgets/
│       ├── account_management_group.dart [STUB / TODO CALLBACKS]
│       ├── general_group.dart            [STUB / TODO CALLBACKS]
│       ├── network_group.dart            [STUB / TODO CALLBACKS]
│       └── security_group.dart
```

* **`security_settings_provider.dart`**:
  - Mengelola durasi auto-lock (`immediately`, `after1Minute`, `after5Minutes`, `after15Minutes`, `after1Hour`, `never`) dan menyimpannya di `SharedPreferences`.
* **`security_group.dart`**:
  - Mengakses `walletSecretsProvider` untuk memeriksa ketersediaan mnemonic dan private key.
  - Menerapkan protokol **Hardware Security Gatekeeper**: Sebelum navigasi ke layar pengungkapan data rahasia (`RevealSecretScreen`), sistem memanggil `AuthenticationService.authenticate()` yang menuntut validasi biometrik atau PIN perangkat OS.
* **`reveal_secret_screen.dart`**:
  - UI berkeamanan tinggi dengan kartu peringatan risiko.
  - Mendukung penayangan frasa mnemonic dalam bentuk chip nomor terurut atau penayangan hex private key dengan tombol salin.
* **`account_management_group.dart`, `network_group.dart`, `general_group.dart`**:
  - Komponen visual grup pengaturan. Seluruh aksi onTap saat ini masih berupa stub kosong (`// TODO`).

---

### 2.6 Modul `qr_scanner/`

```
lib/src/features/qr_scanner/
└── presentation/
    └── screens/
        └── qr_scanner_screen.dart
```

* **`qr_scanner_screen.dart`**:
  - Kontainer swipe terpadu yang menggabungkan fitur pengiriman dan penerimaan dalam satu antarmuka berbasis `PageView`:
    - **Page 0**: `SendScannerScreen` (Kamera scanner untuk menangkap alamat tujuan, langsung mengarahkan ke `SendScreen`).
    - **Page 1**: `ReceiveScreen` (Menampilkan QR Code alamat dompet sendiri).
  - Menyediakan kontrol overlay melayang: tombol switch segmented (`Send` vs `Receive`), tombol senter, dan tombol tutup.

---

### 2.7 Modul `testing/`

```
lib/src/features/testing/
└── test_connection_page.dart
```

* **`test_connection_page.dart`**:
  - Halaman uji coba mandiri (*diagnostic screen*).
  - Mengeksekusi RPC `blockchainService.client.getBlockNumber()` untuk memverifikasi apakah endpoint Hyperledger Besu merespons dengan benar.
  - *Catatan: Tidak terhubung ke rute navigasi aplikasi utama.*

---

## 3. Matriks Komunikasi Antar-Kode (Inter-Feature & Core Communication)

Aplikasi Qrypta mengandalkan aliran komunikasi data yang melintasi batasan modul. Berikut adalah analisis pola interaksi antar-kode:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                             PRESENTATION LAYER                              │
│                                                                             │
│  [HomeScreen] ──watches──► [totalBalanceProvider]                           │
│       │                              │                                      │
│    navigates                   combines balances                            │
│       │                              │                                      │
│       ▼                              ▼                                      │
│  [SendScreen] ──watches──► [TokenNotifier] ◄──reads── [TokenService (.env)] │
│       │                              │                                      │
│  triggers send                       │ calls ERC20 balanceOf                │
│       │                              │                                      │
│       ▼                              ▼                                      │
│  [SendController] ──────► [BlockchainService] ◄────── [NativeCurrency]      │
│       │                              │                                      │
└───────┼──────────────────────────────┼──────────────────────────────────────┘
        │ reads private key            │ RPC: eth_call / eth_sendRawTransaction
        ▼                              ▼
┌───────────────────────────┐  ┌──────────────────────────────────────────────┐
│  AUTHENTICATION STORAGE   │  │             BLOCKCHAIN BESU NODE             │
│                           │  │                                              │
│  [FlutterSecureStorage]   │  │  - JSON-RPC Endpoint (Port 8545)             │
│  - 'privateKey'           │  │  - Smart Contract IDRT (ERC-20 State)        │
│  - 'mnemonic'             │  │  - Indexer GraphQL API (Port 4000)           │
│  - 'pin'                  │  │                                              │
└───────────────────────────┘  └──────────────────────────────────────────────┘
```

### 3.1 Pola Aliran Data 1: Sinkronisasi Saldo Terpadu (*Unified Balance Aggregation*)
1. Saat `HomeScreen` dimuat atau ditarik ke bawah (*Pull to Refresh*), event memicu `totalBalanceProvider`.
2. `totalBalanceProvider` membaca `userWalletAddressProvider.future` dari modul `transaction`.
3. `userWalletAddressProvider` membaca private key dari `authLocalDataSourceProvider` (modul `authentication`), lalu menderivasi alamat checksum EIP-55 via `compute(_getChecksumAddress)`.
4. `totalBalanceProvider` secara simultan memicu `nativeBalanceProvider` untuk memanggil `BlockchainService.nativeCurrency.getBalance()` (Core RPC).
5. Secara bersamaan, `TokenNotifier` (modul `tokens`) memanggil `BlockchainService.erc20.getErc20Balance()` untuk alamat kontrak IDRT dari `.env`.
6. Seluruh data saldo digabungkan dan dipetakan ke nilai mata uang IDR di `BalanceSection`.

### 3.2 Pola Aliran Data 2: Eksekusi Transaksi & Pemantauan Konsensus
1. Pengguna memindai QR Code di `SendScannerScreen` (modul `transaction`).
2. Kamera membaca raw hex string dan mengirimkannya via callback `onScanResult` ke `SendScreen`.
3. Pengguna menekan tombol "Send". `SendController.send()` dijalankan:
   - Meminta private key dari `getPrivateKeyUseCaseProvider` (modul `authentication`).
   - Menghitung nilai desimal token menjadi satuan terkecil `BigInt`.
   - Menginstruksikan `BlockchainService.erc20.sendErc20Token()`.
   - Web3Client menandatangani transaksi secara offline menggunakan kurva `secp256k1` dan mengirimkannya via RPC `eth_sendRawTransaction`.
4. Begitu RPC mengembalikan hash transaksi, `SendScreen` menangkap perubahan state melalui `ref.listen` dan melakukan `Navigator.pushReplacement` ke `ConfirmationPage`.
5. `ConfirmationPage` memulai siklus polling asinkron `blockchainService.transaction.waitForTransactionReceipt(txHash)` yang melakukan kueri RPC berkala setiap 2 detik hingga tanda terima transaksi (*receipt*) masuk ke dalam blok.

### 3.3 Pola Aliran Data 3: Otorisasi Biometrik untuk Akses Kunci Privat
1. Pengguna membuka `ProfileScreen` $\rightarrow$ memilih "Show Private Key" pada `SecurityGroup`.
2. `SecurityGroup` mencegat aksi dan memanggil `AuthenticationService.authenticate()` (Core Service).
3. Pustaka `local_auth` mengaktifkan platform dialog OS (FaceID, Fingerprint, atau PIN Perangkat).
4. Jika hasil otentikasi bernilai `true`, `walletSecretsProvider` (modul `authentication`) membaca data dari `FlutterSecureStorage`.
5. String private key didekripsi dan diteruskan melalui constructor ke `RevealSecretScreen` untuk dirender ke layar pengguna.

---

## 4. Analisis Kritis: Celah Keamanan, Bug Komputasi, & Utang Teknis

Pemeriksaan baris demi baris dan analisis statis Dart mengungkapkan sejumlah kelemahan kritis yang berdampak langsung pada stabilitas dan keamanan aplikasi di lingkungan produksi.

### 4.1 Celah Keamanan Kritis (Critical Security Vulnerabilities)

#### A. Kebocoran Plaintext Kunci Privat & Mnemonic pada System Log (CWE-532)
* **Lokasi Temuan**:
  - `lib/src/features/authentication/application/auth_service.dart`:
    ```dart
    log('Generated mnemonic: "$mnemonic"', name: 'AuthService');
    log('Retrieved private key: $privateKey', name: 'AuthService');
    log('Derived private key: $privateKey', name: 'AuthService');
    ```
  - `lib/src/features/authentication/data/datasources/authentication_local_data_source.dart`:
    ```dart
    log('Saving private key: $privateKey', name: 'AuthLocalDataSource');
    log('Saving mnemonic: "$mnemonic"', name: 'AuthLocalDataSource');
    ```
  - `lib/src/features/authentication/data/repositories/authentication_repository_impl.dart`:
    ```dart
    log('Derived private key: $privateKey', name: 'AuthRepo');
    ```
* **Dampak Keamanan**: Fungsi `dart:developer log()` memancarkan pesan secara langsung ke sistem logging perangkat (Android Logcat / iOS Syslog). Aplikasi lain yang memiliki izin membaca log sistem atau penyerang yang menghubungkan perangkat via USB debugging (ADB) dapat mengekstrak seluruh kunci privat dan frasa seed dompet pengguna secara instan tanpa perlu meretas secure storage.

#### B. Kebocoran Kode PIN Pengguna pada Debug Console & Logcat
* **Lokasi Temuan**:
  - `lib/src/features/authentication/presentation/screens/pin_verification_screen.dart`:
    ```dart
    print("DEBUG::PIN_SCREEN: FUNGSI _verifyPin() DIPANGGIL.");
    print(" - PIN yang akan diverifikasi: '${pinController.text}'");
    ```
* **Dampak Keamanan**: Setiap kali pengguna menekan tombol verifikasi PIN untuk membuka dompet, kode PIN rahasia dicetak dalam bentuk teks polos (*plaintext*) ke konsol logging standar.

#### C. Penyimpanan PIN Tanpa Hashing Kriptografis (Plaintext PIN Storage)
* **Lokasi Temuan**:
  - `lib/src/features/authentication/data/datasources/authentication_local_data_source.dart`:
    ```dart
    await secureStorage.write(key: 'pin', value: pin);
    ```
  - `lib/src/features/authentication/data/repositories/authentication_repository_impl.dart`:
    ```dart
    @override
    Future<bool> verifyPin(String pin) async {
      final storedPin = await localDataSource.getPin();
      return storedPin == pin;
    }
    ```
* **Dampak Keamanan**: PIN disimpan dalam bentuk teks mentah tanpa mekanisme pengacakan *salt* maupun algoritma hashing adaptif lambat (*Argon2id*, *PBKDF2*, atau *bcrypt*). Jika secure storage diekspor atau disusupi, PIN langsung terbaca tanpa proteksi *brute-force defense*.

#### D. Ketiadaan Tantangan Keamanan pada Eksekusi Transfer Aset
* **Lokasi Temuan**: `lib/src/features/transaction/logic/send_controller.dart`
* **Akar Masalah**: Method `send()` membaca private key dari secure storage dan langsung mengeksekusi penandatanganan transaksi tanpa meminta konfirmasi PIN atau verifikasi biometrik pengguna.
* **Dampak**: Jika aplikasi dalam keadaan tidak terkunci dan perangkat dipinjamkan atau direbut, penyerang dapat mengirimkan seluruh saldo aset tanpa hambatan otorisasi apa pun.

---

### 4.2 Bug Komputasi & Presisi Aritmatika (Computational & Precision Bugs)

#### A. Konversi Desimal Berbahaya & Potensi Integer Overflow pada `SendController`
* **Lokasi Temuan**: `lib/src/features/transaction/logic/send_controller.dart:87`
  ```dart
  // SEND ERC20 TOKEN (IDRT)
  final amountBigInt = BigInt.from(
    amountDouble * (BigInt.from(10).pow(token.decimals).toDouble()).toInt()
  );
  ```
* **Dekonstruksi Bug Teknis**:
  1. Token standar EVM seperti IDRT memiliki `decimals = 18`. Nilai $10^{18} = 1.000.000.000.000.000.000$.
  2. Kode di atas memanggil `pow(10, 18).toDouble()`, lalu mengalikan dengan `amountDouble` (tipe `double`), kemudian memanggil `.toInt()`.
  3. Di Dart pada arsitektur 64-bit, tipe `int` dibatasi oleh integer bertanda 64-bit ($\text{maksimal } 2^{63}-1 \approx 9,22 \times 10^{18}$).
  4. Jika pengguna mencoba mengirim lebih dari 9,22 token IDRT (misalnya 10 IDRT $= 10 \times 10^{18} = 10^{19}$), operasi `.toInt()` akan mengalami **integer overflow** atau komputasi *clamping*, yang menyebabkan nilai `amountBigInt` menjadi negatif, rusak, atau terpotong drastis!
  5. Penggunaan tipe data `double` juga tunduk pada keterbatasan IEEE 754 mantissa (maksimal 53 bit presisi), sehingga transfer angka desimal presisi tinggi akan mengalami *rounding error*.

#### B. Ketiadaan Pemeriksaan Saldo Mandiri (*Pre-Flight Balance Check*)
* **Lokasi Temuan**: `lib/src/features/transaction/logic/send_controller.dart`
* **Masalah**: Controller tidak pernah memverifikasi apakah `userBalance >= amount + gasFee` sebelum memanggil RPC. Sistem sepenuhnya bergantung pada node blockchain untuk membatalkan (*revert*) transaksi. Ini menyebabkan latensi UI yang buruk dan pesan error RPC yang tidak bersahabat bagi pengguna awam.

---

### 4.3 Utang Teknis & Pelanggaran Arsitektur (Architectural Debt & Smells)

#### A. Dualitas State Management & Kode Liar pada `ReceiveScreen`
* **Lokasi Temuan**: `lib/src/features/transaction/presentation/screens/receive_screen.dart`
  ```dart
  // ReceiveScreen mengabaikan Riverpod dan membungkus widget dengan Provider lama:
  return provider.ChangeNotifierProvider(
    create: (_) => TransactionController(authRepository),
    child: Scaffold(
      body: provider.Consumer<TransactionController>( ... )
    ),
  );
  ```
* **Dampak**: 
  1. Terjadi percampuran *State Management* (`package:provider` dan `package:flutter_riverpod`) dalam satu file.
  2. Pada `transaction_controller.dart`, method `loadWallet()` memiliki logika berbahaya:
     ```dart
     if (privateKeyHex != null) { ... } else { await createWallet(); }
     ```
     Jika private key belum selesai dibaca saat layar dibuat, `TransactionController` dapat membangkitkan dompet baru secara sepihak dan menimpa status akun pengguna. Padahal modul transaksi sudah memiliki `userWalletAddressProvider` berbasis Riverpod yang aman dan reaktif.

#### B. Kode Terduplikasi & Konfigurasi Auto-Lock Tidak Berfungsi (*Placebo Settings*)
* **Masalah 1 (Duplikasi File)**:
  Terdapat dua file yang mendefinisikan controller auto-lock dengan nama class dan enum yang saling berkonflik:
  1. `lib/src/features/profile/application/security_settings_notifier.dart` (`ChangeNotifier`, menyimpan integer).
  2. `lib/src/features/profile/presentation/providers/security_settings_provider.dart` (`StateNotifier`, menyimpan string).
* **Masalah 2 (Fitur Palsu/Placebo)**:
  Pengaturan durasi auto-lock di `SecurityGroup` (1 menit, 5 menit, dst.) sama sekali **tidak pernah dibaca** oleh pengunci aplikasi di `lib/main.dart`:
  ```dart
  // lib/main.dart
  if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
    ref.read(appLockProvider.notifier).lock(); // Selalu mengunci instan!
  }
  ```
  Fitur pengaturan durasi auto-lock pada profil berstatus mati (*placebo*).

#### C. Dependensi Tidak Terdaftar di `pubspec.yaml`
* **Temuan**:
  - `lib/src/features/authentication/data/repositories/authentication_repository_impl.dart` mengimpor `package:wallet/wallet.dart`.
  - `lib/src/features/home/presentation/widgets/home_body_widgets.dart` mengimpor `package:intl/intl.dart`.
* **Masalah**: Kedua paket tersebut tidak tercatat di blok `dependencies` pada `pubspec.yaml` dan hanya terbawa secara transitif. Update dependensi di masa mendatang dapat menyebabkan kompilasi aplikasi mendadak gagal (*broken build*).

#### D. Komponen Layar Orphan & Stub TODO yang Terabaikan
1. **Layar Orphan (Tidak Terjangkau Navigasi)**:
   - `WelcomeScreen` & `SignUpScreen` (`authentication/presentation/screens/`).
   - `TestConnectionPage` (`testing/test_connection_page.dart`).
2. **Stub / Layar Placeholder**:
   - `ChangePinScreen` hanya menampilkan teks "This is the placeholder screen".
   - `AccountManagementGroup`, `NetworkGroup`, dan `GeneralGroup` pada profil seluruhnya berisi callback `// TODO` tanpa aksi nyata.

---

## 5. Matriks Rekomendasi Solusi & Blueprint Refaktor

| Prioritas | Masalah | Dampak Teknis | Solusi Refaktor yang Direkomendasikan |
| :--- | :--- | :--- | :--- |
| **P0 - Blocker** | Log Kunci Privat & Mnemonic | Celah kebocoran kunci di system log perangkat. | Hapus seluruh baris `log()` dan `print()` yang mencetak variabel `$privateKey`, `$mnemonic`, dan `pinController.text`. Gunakan logging framework terkontrol yang otomatis mati di mode release (`kDebugMode`). |
| **P0 - Blocker** | Bug Overflow Aritmatika Desimal IDRT | Transaksi di atas 9.22 token IDRT overflow / gagal. | Ganti kalkulasi aritmatika di `SendController` menggunakan manipulasi string desimal atau package presisi arbitrer (misal `decimal` package), lalu konversi langsung ke `BigInt` tanpa melalui `double.toInt()`. |
| **P1 - Critical** | PIN Disimpan Tanpa Hashing | PIN rentan diekstraksi dari secure storage. | Simpan PIN dalam bentuk cryptographic hash dengan salt acak: `SHA-256(pin + salt)` atau algoritma KDF (Argon2 / PBKDF2) sebelum ditulis ke `FlutterSecureStorage`. |
| **P1 - Critical** | Ketiadaan Otorisasi pada Pengiriman Aset | Siapa pun yang memegang HP aktif dapat mengirim dana. | Sisipkan *gatekeeper* otorisasi (`AuthenticationService.authenticate()` atau dialog PIN) di dalam `SendController.send()` sebelum menandatangani transaksi. |
| **P2 - Major** | Dualitas Provider di `ReceiveScreen` | Inkonsistensi arsitektur & risiko duplikasi wallet. | Hapus penggunaan `package:provider` dan `TransactionController` di `ReceiveScreen`. Gunakan `ref.watch(userWalletAddressProvider)` yang sudah tersedia di Riverpod. |
| **P2 - Major** | Fitur Auto-Lock Placebo | Pengaturan auto-lock diabaikan sistem. | Sambungkan nilai `securitySettingsProvider` ke `AppLockWrapper` di `main.dart` dengan mencatat timestamp saat aplikasi masuk ke state `paused`. |
| **P2 - Major** | Dependensi Tidak Terdaftar | Potensi gagal build saat dependensi transitif berubah. | Tambahkan `wallet` dan `intl` secara eksplisit ke dalam `pubspec.yaml`. |
| **P3 - Minor** | Dead Code & Layar Orphan | Meningkatkan beban pemeliharaan kode (*bloat*). | Hapus `security_settings_notifier.dart`, bersihkan layar orphan (`WelcomeScreen`, `SignUpScreen`), dan lengkapi atau sembunyikan menu TODO pada profil. |
