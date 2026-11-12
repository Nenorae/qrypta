# DOKUMENTASI TEKNIS PENGERJAAN MILESTONE 1
## Bali Tourist ID (Qrypta Engine & ezsign-core Foundation)

---

## 1. Ringkasan Eksekutif & Status Milestone 1

| Parameter | Status Sebelum Pengerjaan | Status Pasca Pengerjaan |
| :--- | :--- | :--- |
| **Kondisi Kompilasi (`flutter analyze`)** | **Gagal (106 Issues, Fatal Identifier Error)** | **BERSIH (0 Issues / No issues found)** |
| **Keamanan Kunci Privat & Mnemonic** | **Bocor ke Logger & Console** | **ZERO EXPOSURE (Log dibersihkan)** |
| **Aritmatika Nominal Token ERC-20 (IDRT)** | **Integer Overflow di atas 9.22 IDRT** | **Presisi Arbitrer (BigInt Parse & Shift)** |
| **Penyimpanan PIN Lokal** | **Plaintext di Secure Storage** | **Kriptografis (SHA-256 Hashed)** |
| **Konfigurasi Node & Middleware** | **Hardcoded IP (`100.92.191.4`)** | **Dinamis via Environment (`.env`)** |
| **Palet Tema & Desain UI** | **Hijau Tua Statis & Deprecated `.withOpacity`** | **Matriks Warna Mockup Bali Tourist ID** |
| **Unit Testing** | **Tidak Ada (`test/` kosong)** | **100% Passed (5 Skenario Uji)** |

---

## 2. Rincian Perbaikan Bug Fatal & Keamanan (Seksi 1.1)

### 2.1 Perbaikan Identifier Query GraphQL
- **File:** `lib/src/core/data/repositories/wallet_repository.dart`
- **Masalah:** Baris 13 memanggil `document: gql(getMyWalletQuery)` yang tidak pernah dideklarasikan di `queries.dart`, menyebabkan `compile error: undefined_identifier`.
- **Solusi Bersih:**
  1. Mengubah pemanggilan menjadi `document: gql(getMyAssetsQuery)`.
  2. Menyelaraskan nama variabel input dari `'address'` menjadi `'walletAddress': address` agar sesuai dengan skema GraphQL `MyAssets($walletAddress: String!)`.

```dart
// lib/src/core/data/repositories/wallet_repository.dart
Stream<QueryResult> watchWalletAssets(String address) {
  final WatchQueryOptions options = WatchQueryOptions(
    document: gql(getMyAssetsQuery),
    variables: <String, dynamic>{
      'walletAddress': address,
    },
    fetchResults: true,
    fetchPolicy: FetchPolicy.cacheAndNetwork,
  );

  return client.watchQuery(options).stream;
}
```

---

### 2.2 Eliminasi Integer Overflow & Presisi Arbitrer ERC-20
- **File:** `lib/src/features/transaction/logic/send_controller.dart`
- **Masalah:** Baris lama:
  ```dart
  final amountBigInt = BigInt.from(amountDouble * (BigInt.from(10).pow(token.decimals).toDouble()).toInt());
  ```
  Pada arsitektur Dart, tipe data `int` bertipe 64-bit signed integer dengan batas maksimum $2^{63}-1 \approx 9.223.372.036.854.775.807$. Untuk token dengan 18 desimal (seperti IDRT), pengali $10^{18}$ sudah bernilai $10^{18}$. Jika pengguna mentransfer nominal $\ge 9.23$ IDRT (misal Tourist Levy sebesar Rp 150.000 IDRT $= 150.000 \times 10^{18}$), konversi `.toInt()` mengalami crash *integer overflow*, menghasilkan angka negatif atau melempar runtime exception. Selain itu, konversi melewati `double` memicu pemotongan presisi desimal IEEE 754.
- **Solusi Bersih:**
  Mengimplementasikan fungsi `parseAmountToBigInt(String amountText, int decimals)` pada `lib/src/core/utils/formatters.dart`. Fungsi ini melakukan pemisahan string (*string splitting*) antara bagian integer dan fraksional, melakukan *padding* nol ke kanan sepanjang `decimals`, lalu menggabungkannya dan mem-parsing langsung ke tipe data `BigInt` tanpa pernah menyentuh `double` atau `int64`.

```dart
// lib/src/core/utils/formatters.dart
BigInt parseAmountToBigInt(String amountText, int decimals) {
  final cleanText = amountText.trim().replaceAll(',', '.');
  if (cleanText.isEmpty) return BigInt.zero;

  final parts = cleanText.split('.');
  String integerPart = parts[0].replaceAll(RegExp(r'[^0-9]'), '');
  if (integerPart.isEmpty) integerPart = '0';

  String fractionalPart = parts.length > 1 ? parts[1].replaceAll(RegExp(r'[^0-9]'), '') : '';
  if (fractionalPart.length > decimals) {
    fractionalPart = fractionalPart.substring(0, decimals);
  } else {
    fractionalPart = fractionalPart.padRight(decimals, '0');
  }

  final fullString = '$integerPart$fractionalPart';
  return BigInt.tryParse(fullString) ?? BigInt.zero;
}
```

Pembaruan pada `send_controller.dart`:
```dart
if (token == null) {
  // Transfer ETH Asli (18 desimal)
  final amountInWei = parseAmountToBigInt(amountText, 18);
  txHash = await blockchainService.nativeCurrency.sendTransaction(
    privateKey,
    EthereumAddress.fromHex(recipient),
    EtherAmount.fromBigInt(EtherUnit.wei, amountInWei),
  );
} else {
  // Transfer ERC-20 IDRT dengan presisi arbitrer
  final amountBigInt = parseAmountToBigInt(amountText, token.decimals);
  txHash = await blockchainService.erc20.sendErc20Token(
    privateKey: privateKey,
    contractHex: token.contractAddress,
    recipientHex: recipient,
    amount: amountBigInt,
  );
}
```

---

### 2.3 Formatter Rupiah & BigInt Tanpa Kehilangan Presisi
- **File:** `lib/src/core/utils/formatters.dart`
- **Masalah:** Fungsi `formatBigInt` sebelumnya membagi `value / BigInt.from(10).pow(decimals)` yang menghasilkan tipe `double`, memicu pemotongan angka signifikan.
- **Solusi Bersih:**
  Menggunakan operator pembagian integer BigInt (`~/`) untuk memperoleh nilai bulat nominal Rupiah, dan operator modulo (`%`) untuk memperoleh sisa desimal, kemudian memformat pemisah ribuan titik (`.`) sesuai kaidah moneter Indonesia.

```dart
String formatBigInt(
  BigInt value,
  int decimals, {
  int maxFractionDigits = 2,
  bool isCurrency = false,
  String currencySymbol = 'Rp ',
}) {
  if (value == BigInt.zero) {
    return isCurrency ? '${currencySymbol}0' : '0.00';
  }

  final isNegative = value.isNegative;
  final positiveValue = value.abs();
  final divisor = BigInt.from(10).pow(decimals);
  final integerPart = positiveValue ~/ divisor;
  final remainder = positiveValue % divisor;

  final intFormatted = _formatBigIntThousands(integerPart, isCurrency ? '.' : ',');

  if (decimals == 0 || maxFractionDigits <= 0 || (isCurrency && remainder == BigInt.zero)) {
    final prefix = isNegative ? '-' : '';
    final symbol = isCurrency ? currencySymbol : '';
    return '$prefix$symbol$intFormatted';
  }

  final remainderPadded = remainder.toString().padLeft(decimals, '0');
  final fractionalString = remainderPadded.substring(
    0,
    remainderPadded.length < maxFractionDigits ? remainderPadded.length : maxFractionDigits,
  );

  final decimalSeparator = isCurrency ? ',' : '.';
  final prefix = isNegative ? '-' : '';
  final symbol = isCurrency ? currencySymbol : '';
  return '$prefix$symbol$intFormatted$decimalSeparator$fractionalString';
}
```

---

### 2.4 Sanitasi Log Kunci Privat, Mnemonic, dan Hashing PIN
- **File Terdampak:**
  - `lib/src/features/authentication/application/auth_service.dart`
  - `lib/src/features/authentication/data/datasources/authentication_local_data_source.dart`
  - `lib/src/features/authentication/data/repositories/authentication_repository_impl.dart`
  - `lib/src/features/authentication/presentation/screens/pin_verification_screen.dart`
  - `lib/src/features/authentication/presentation/screens/login_screen.dart`
  - `lib/src/features/authentication/presentation/screens/wallet_setup_pin_screen.dart`
  - `lib/src/features/authentication/presentation/screens/wallet_setup_seed_verification_screen.dart`
  - `lib/src/features/authentication/presentation/screens/wallet_setup_seed_phrase_screen.dart`

- **Tindakan Remediasi:**
  1. **Penghapusan Total Kebocoran Kunci:** Menghapus seluruh string interpolasi `$privateKey`, `$mnemonic`, dan teks input PIN dari `log()` maupun `print()`. Log diganti dengan pesan status statis tanpa menyertakan payload rahasia.
  2. **Hashing PIN dengan SHA-256:**
     Pada `authentication_local_data_source.dart`, PIN pengguna di-hash menggunakan algoritma SHA-256 (`crypto` package) sebelum disimpan ke dalam `FlutterSecureStorage`:
     ```dart
     @override
     Future<void> savePin(String pin) async {
       final hashedPin = sha256.convert(utf8.encode(pin)).toString();
       await secureStorage.write(key: 'pin', value: hashedPin);
     }
     ```
  3. **Verifikasi PIN Berbasis Hash:**
     Pada `authentication_repository_impl.dart`, proses `verifyPin` membandingkan hash SHA-256 dari input PIN pengguna dengan nilai hash yang tersimpan, mempertahankan fallback kompatibilitas:
     ```dart
     @override
     Future<bool> verifyPin(String pin) async {
       final storedPin = await localDataSource.getPin();
       if (storedPin == null) return false;
       final hashedPin = sha256.convert(utf8.encode(pin)).toString();
       return storedPin == hashedPin || storedPin == pin;
     }
     ```

---

## 3. Konfigurasi Lingkungan & Tema Bali Tourist ID (Seksi 1.2)

### 3.1 Registrasi Dependensi & Struktur Assets
Pada `pubspec.yaml`, telah ditambahkan dependensi langsung:
- `intl: ^0.20.3` (Mendukung formatting mata uang dan tanggal ICAO)
- `wallet: ^0.0.13` (Kriptografi BIP-39, HD Wallet BIP-44, dan utilitas Ethereum)
- `google_mlkit_text_recognition: ^1.0.2` (Engine OCR untuk pemindaian MRZ Paspor TD3 pada Milestone 3)

Folder assets berikut telah diinisialisasi untuk mencegah warning Flutter Engine:
- `assets/images/`
- `assets/icons/`
- `assets/fonts/`

### 3.2 Pembaruan Environment (`.env`)
Nilai konfigurasi jaringan sekarang terpusat pada file `.env`:
```env
# RPC & Besu Blockchain Configuration
RPC_URL=http://127.0.0.1:8545
CHAIN_ID=1337
GRAPHQL_URL=http://127.0.0.1:4000/graphql

# ezsign-core Fastify Middleware API
EZSIGN_API_URL=http://127.0.0.1:3000/api/v1

# IDRT (Indonesian Rupiah Token) ERC-20 Configuration
IDRT_CONTRACT_ADDRESS=0xF12b5dd4EAD5F743C6BaA640B0216200e89B60Da
IDRT_NAME=Rupiah Token
IDRT_SYMBOL=IDRT
IDRT_DECIMALS=18
```

### 3.3 Dynamic Binding pada Core Config & GraphQL Provider
- **`lib/src/core/config/blockchain_config.dart`:**
  Seluruh nilai statis kini membaca `dotenv.env`:
  ```dart
  class BlockchainConfig {
    static String get rpcUrl => dotenv.env['RPC_URL'] ?? 'http://127.0.0.1:8545';
    static int get chainId => int.tryParse(dotenv.env['CHAIN_ID'] ?? '1337') ?? 1337;
    static String get name => dotenv.env['NETWORK_NAME'] ?? 'Hyperledger Besu Bali Net';
    static String get currencySymbol => dotenv.env['CURRENCY_SYMBOL'] ?? 'ETH';
    static String get ezsignApiUrl => dotenv.env['EZSIGN_API_URL'] ?? 'http://127.0.0.1:3000/api/v1';
  }
  ```
- **`lib/src/core/graphql/graphql_provider.dart`:**
  URL endpoint GraphQL mengambil nilai dinamis dari `dotenv.env['GRAPHQL_URL']`.

---

### 3.4 Penyelarasan Palet Desain Mockup Bali Tourist ID
Sesuai rancangan pada `BEDAH_TEKNIS_BALI_TOURIST_ID_PATH1_TURIS_APP.md` dan file mockup HTML, palet warna `AppColors` dirombak total ke matriks standar terpercaya:

```
┌────────────────────────────────────────────────────────────────────────┐
│                   BALI TOURIST ID COLOR SYSTEM                         │
├───────────────────┬────────────────────────────────────────────────────┤
│ Teal / Toska      │ Status VERIFIED / APPROVED (#0F8E82, #2FBFAF)      │
│ Purple / Indigo   │ Identitas Wisatawan, NFC Radar, Royal (#4B2E83)    │
│ Amber             │ Status CONDITIONAL / PENDING (#E29A17, #B87A08)    │
│ Rose / Crimson    │ Status PROHIBITED / REJECTED (#D64545, #B93232)    │
│ Obsidian Slate    │ Background Gelap & Surface (#0B111E, #131D2E)      │
└───────────────────┴────────────────────────────────────────────────────┘
```

Seluruh penggunaan fungsi `withOpacity()` yang deprecated di seluruh kode aplikasi telah digantikan dengan `.withValues(alpha: ...)`.

---

## 4. Hasil Verifikasi & Pengujian Otomatis

### 4.1 Pengujian Unit Otomatis (`test/milestone1_test.dart`)
Telah dibuat rangkaian unit test otomatis untuk menjamin presisi moneter dan keamanan:

```
00:00 +0: Milestone 1 - Arithmetic & Precision Tests parseAmountToBigInt correctly scales 150,000 IDRT to 18 decimals without overflow
00:00 +1: Milestone 1 - Arithmetic & Precision Tests parseAmountToBigInt correctly handles fractional decimal amounts
00:00 +2: Milestone 1 - Arithmetic & Precision Tests formatBigInt avoids IEEE 754 precision loss and formats Indonesian Rupiah
00:00 +3: Milestone 1 - Arithmetic & Precision Tests formatBigInt correctly formats zero and decimals
00:00 +4: Milestone 1 - Security & PIN Hashing Tests PIN is securely hashed using SHA-256
00:00 +5: All tests passed!
```

### 4.2 Analisis Statis Kode (`flutter analyze`)
```
Ganens-MacBook / Linux Environment:
$ flutter analyze
Analyzing qrypta...
No issues found! (ran in 2.3s)
```

Repositori Qrypta kini berada dalam status bersih, stabil, aman, dan siap menjadi fondasi eksekusi integrasi transaksi **Milestone 2 (VerificationTransactionService & ezsign-core DTOs)**.
