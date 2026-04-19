# Qrypta Core Services Architecture

Dokumen ini merangkum fungsionalitas teknis dari lapisan layanan (service layer) yang mengelola logika inti keamanan dan interaksi blockchain.

## 1. Keamanan Lokal

### [AuthenticationService](authentication_service.dart)
Layanan wrapper untuk `local_auth` yang mengelola verifikasi identitas di level perangkat.
- **Mekanisme**: Menggunakan Biometrik (Fingerprint/FaceID) atau fallback ke sistem keamanan OS (PIN/Passcode).
- **Fungsi Utama**: `authenticate()` digunakan sebagai *gatekeeper* sebelum akses ke data sensitif (seperti penandatanganan transaksi).

## 2. Blockchain Services Gateway

### [BlockchainService](blockchain/blockchain_service.dart)
Bertindak sebagai **Gateway/Facade** utama dan penyedia dependensi (via Riverpod `blockchainServiceProvider`).
- **Komponen**: Menginisialisasi `Web3Client` (HTTP RPC) dan `GraphQLClient`.
- **Delegasi**: Mendistribusikan client ke sub-layanan spesifik (`wallet`, `nativeCurrency`, `erc20`, dan `transaction`).

## 3. Sub-Layanan Blockchain (`/blockchain`)

### [WalletService](blockchain/wallet_service.dart)
Fokus pada kriptografi dasar dan manajemen kunci asimetris.
- **Teknis**: Menggunakan `web3dart` untuk derivasi `EthereumAddress` dari `EthPrivateKey`.
- **Fungsi**: Validasi format alamat hex, pembuatan entropy untuk *private key* baru, dan konversi format kunci.

### [NativeCurrencyService](blockchain/native_currency_service.dart)
Mengelola aset utama jaringan (ETH).
- **Fungsi**: 
  - `getBalance()`: Query saldo langsung ke state blockchain.
  - `sendTransaction()`: Membuat objek `Transaction`, menandatangani dengan `credentials`, dan melakukan broadcast ke jaringan.

### [Erc20Service](blockchain/erc20_service.dart)
Interaksi dengan *Smart Contract* melalui ABI (Application Binary Interface).
- **Abstraksi**: Menggunakan `DeployedContract` untuk memetakan fungsi standar ERC-20 (`balanceOf`, `transfer`, `decimals`).
- **Fitur**: Mendukung validasi kontrak untuk memastikan alamat yang dimasukkan pengguna adalah token yang valid sebelum ditambahkan ke wallet.

### [TransactionService](blockchain/transaction_service.dart)
Layanan hibrida yang mengoptimalkan pengambilan data besar melalui GraphQL dan data *real-time* melalui RPC.
- **GraphQL Integration**:
  - `getRecentTransactions()`: Mengambil data terindeks (history) dengan paginasi efisien.
  - `sendSignedTransaction()`: Melakukan broadcast transaksi via mutation GraphQL (jika didukung oleh backend).
- **RPC Integration**:
  - `waitForTransactionReceipt()`: Polling status transaksi hingga masuk ke blok (dengan mekanisme `Timer` dan `Completer`).
  - `estimateTransactionFee()`: Menghitung biaya gas berdasarkan `gasPrice` terbaru dan estimasi konsumsi gas unit (misal: 21,000 untuk transfer standar).
  - `getNonce()`: Mengambil `transactionCount` untuk mencegah serangan replay.
