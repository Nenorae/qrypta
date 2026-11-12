# DOKUMENTASI TEKNIS PENGERJAAN MILESTONE 2
## Integrasi Service Transaksi Verifikasi & Data Ekosistem ezsign-core

---

## 1. Ringkasan Eksekutif & Arsitektur Milestone 2

Milestone 2 menghubungkan aplikasi Flutter (Qrypta / Tourist App) dengan ekosistem backend terdesentralisasi **ezsign-core** (`Fastify Middleware` -> `RabbitMQ ezsign_logging_queue` -> `tx-worker` -> `Hyperledger Besu`).

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                        FLUTTER CLIENT (TOURIST TRUST APP)                              │
│                                                                                        │
│  [BtidCredentialModel]    [ConsentRequestModel]         [AuditTransactionModel]       │
│           │                         │                              ▲                   │
│           ▼                         ▼                              │                   │
│  ┌─────────────────────────────────────────────────────────────────┴────────────────┐  │
│  │                    VerificationTransactionService                                │  │
│  │  • generateDynamicQrToken(45s rotating token)                                    │  │
│  │  • signAndSubmitConsent(secp256k1 EIP-191 personal sign over canonical digest)   │  │
│  │  • revokeMerchantAccess(cryptographic access revocation)                         │  │
│  │  • Local Persistence via Hive Box ('audit_transactions_box')                     │  │
│  └─────────────────────────────────┬────────────────────────────────────────────────┘  │
└────────────────────────────────────┼───────────────────────────────────────────────────┘
                                     │ HTTP POST /api/v1/verify-identity
                                     ▼ (docType: BTID_CONSENT / BTID_REVOKE)
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                        ezsign-core FASTIFY MIDDLEWARE                                  │
│  • Endpoint: POST /api/v1/verify-identity                                              │
│  • Rate Limiting & Schema Validation                                                   │
│  • Returns 202 ACCEPTED with correlation_id                                            │
└────────────────────────────────────┬───────────────────────────────────────────────────┘
                                     │ AMQP Enqueue
                                     ▼ (Queue: ezsign_logging_queue)
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                        RABBITMQ MESSAGE BROKER                                         │
└────────────────────────────────────┬───────────────────────────────────────────────────┘
                                     │ Prefetch(1) Worker Consume
                                     ▼
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                        tx-worker (Ethers.js + Nonce Manager)                           │
│  • Keccak256 userHash derivation                                                       │
│  • Dynamic Nonce Sync                                                                  │
│  • Invokes Smart Contract recordVerification(...)                                      │
└────────────────────────────────────┬───────────────────────────────────────────────────┘
                                     │ QBFT Consensus Finality
                                     ▼
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                        HYPERLEDGER BESU BLOCKCHAIN                                     │
│  • Smart Contract: recordVerification(bytes32, string, bytes, uint256, string)        │
│  • Tamper-evident, immutable audit trail                                               │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Model Data Ekosistem Turis (Seksi 2.1)

Tiga Data Transfer Object (DTO) model telah dibuat di dalam `lib/src/core/data/models/`:

### 2.1 `btid_credential_model.dart`
Menyimpan kredensial digital Bali Tourist ID (BTID) hasil verifikasi paspor dan integrasi imigrasi:
- `btidNumber`: Identifier resmi berformat `BTID-YYYY-XXXX-XXXX` (contoh: `BTID-2026-4471-0938`).
- `fullName`: Nama lengkap wisatawan sesuai dokumen paspor (contoh: `James Wilson`).
- `nationality`: Kode negara ICAO 3 huruf (contoh: `GBR`).
- `passportMasked`: Nomor paspor tersensor demi perlindungan privasi (contoh: `••••••789`).
- `dob` & `docExpiry`: Tanggal lahir dan tanggal kedaluwarsa dokumen.
- `visaType`: Jenis visa imigrasi aktif (contoh: `e-VOA B1`).
- `arrivalDate` & `stayExpiry`: Tanggal kedatangan dan batas izin tinggal di Bali.
- `levyStatus`: Status retribusi wisatawan (`'paid'` / `'unpaid'`).
- `levyReceiptRef`: Referensi kuitansi retribusi resmi (contoh: `LVY-448102`).
- `walletAddress`: Alamat publik Ethereum/Besu yang terikat (`0x...`).
- `issuedAt`: Timestamp penerbitan kredensial.
- **Getters:**
  - `isLevyPaid`: Mengecek status lunas retribusi.
  - `daysRemaining`: Menghitung sisa hari izin tinggal terhadap `stayExpiry`.

### 2.2 `consent_request_model.dart`
Merepresentasikan permintaan verifikasi dari aplikasi merchant yang memindai QR dinamis wisatawan:
- `requestId`: Referensi transaksi pertukaran data (format `TX-XXXXXX`).
- `merchantId`: ID akreditasi merchant (contoh: `MCH-1042`).
- `merchantName`: Nama bisnis terdaftar (contoh: `Bali Ocean Resort`).
- `merchantCategory`: Kategori bisnis (`hotel`, `car_rental`, `cafe_bar`, `esim`, `attraction`).
- `staffName` & `staffRole`: Identitas petugas penanggung jawab pemindaian.
- `purposeTemplate`: Kategori tujuan resmi pemerintah (contoh: `hotel_checkin`, `vehicle_rental`, `age_check_18`).
- `requestedFields`: Daftar atribut terikat tujuan (`List<String>`).
- `retentionPolicy`: Klausul retensi data (contoh: `Retained for 30 days`).
- `expiresAt`: Waktu kedaluwarsa permintaan (default 3 menit).

### 2.3 `audit_transaction_model.dart`
Merepresentasikan entri riwayat audit transaksi on-chain yang dapat diverifikasi:
- `auditRef`: Kode referensi audit lokal (format `AUD-XXXXXX`).
- `txRef`: Referensi transaksi terkait (`TX-XXXXXX`, `LVY-XXXXX`, `PAY-XXXXXX`).
- `txHash`: Hash transaksi Hyperledger Besu hasil konsensus.
- `actor`: Subjek yang memberikan persetujuan (`James Wilson`).
- `organisation`: Entitas penerima data (`Bali Ocean Resort`).
- `action`: Tindakan yang dilakukan (`Identity shared with merchant`, `Tourist Levy paid`, dll.).
- `purpose`: Tujuan pemrosesan data.
- `sharedAttributesCount`: Jumlah atribut yang disetujui untuk diungkapkan.
- `status`: Status akhir transaksi (`Approved`, `Rejected`, `Paid`, `Revoked`).
- `timestamp`: Waktu pencatatan.
- `attributeKeys`: Daftar kunci atribut yang diungkapkan.
- `receiptSignature`: Tanda tangan kriptografis EIP-191 yang dapat dibuktikan.

---

## 3. Implementasi `VerificationTransactionService` (Seksi 2.2)

File: `lib/src/core/services/blockchain/verification_transaction_service.dart`  
Terdaftar pada facade `BlockchainService.verification` di `blockchain_service.dart`.

### 3.1 Dynamic Rotating QR Token (45 Detik)
```dart
String generateDynamicQrToken(String btid, String walletAddress, {int validitySeconds = 45})
```
- Menghasilkan token acak berformat `QRT-<10_KARAKTER_ALFANUMERIK>`.
- Mengikat identitas `btid`, `wallet`, dan waktu kedaluwarsa absolut `exp` ($T_{\text{sekarang}} + 45\text{ detik}$).
- Dikemas dalam payload JSON ringkas yang dapat dipindai instan oleh Merchant Scanner tanpa fragmentasi data.

### 3.2 Protokol Cryptographic Consent (Zero-PII On-Chain)
```dart
Future<AuditTransactionModel> signAndSubmitConsent({
  required String privateKeyHex,
  required ConsentRequestModel request,
  required Map<String, dynamic> approvedData,
  required bool isApproved,
})
```
1. **Pembuatan Canonical Payload:**
   Sistem menyusun intisari persetujuan tanpa pernah memasukkan Personally Identifiable Information (PII) mentah ke dalam digest yang dikirim ke blockchain:
   ```json
   {
     "txRef": "TX-448102",
     "btidHash": "0x<keccak256_of_btid>",
     "merchantId": "MCH-1042",
     "purpose": "hotel_checkin",
     "attributeKeys": ["name", "nationality", "id_validity", "stay_valid"],
     "outcome": "APPROVED",
     "timestamp": "2026-11-12T06:30:00Z"
   }
   ```
2. **Penandatanganan Kriptografis (secp256k1 EIP-191):**
   Menggunakan `EthPrivateKey.fromHex(cleanKey).signPersonalMessageToUint8List()` untuk menandatangani byte UTF-8 dari canonical JSON. Menghasilkan tanda tangan 65-byte berawalan `0x`.
3. **Pengiriman ke Fastify Middleware:**
   Mengirimkan `POST /api/v1/verify-identity` dengan `client_type: 'web3'`, `uuid: btid`, `signature`, metadata audit lengkap, dan timestamp.
4. **Resiliensi & Persistence:**
   - Menyimpan bukti transaksi ke Hive Box `audit_transactions_box` (dengan in-memory fallback untuk isolasi test).
   - Menghasilkan objek `AuditTransactionModel` lengkap dengan `auditRef` dan `txHash` untuk rendering instan di UI.

### 3.3 Pencabutan Akses Merchant (Revocation Protocol)
```dart
Future<AuditTransactionModel> revokeMerchantAccess({
  required String privateKeyHex,
  required String txRef,
  required String merchantId,
  required String btid,
  String? merchantName,
})
```
- Menandatangani instruksi pencabutan akses (`action: 'REVOKE_ACCESS'`) menggunakan kunci privat lokal.
- Mengirimkan event `BTID_REVOKE` ke endpoint middleware agar tercatat sebagai log audit baru di Besu.
- Memperbarui status riwayat transaksi lokal menjadi `'Revoked'`.

### 3.4 Pencatatan Audit Pembayaran Retribusi (Levy)
```dart
Future<AuditTransactionModel> recordLevyPaymentAudit({
  required String levyRef,
  required String txHash,
  required String btid,
  required String amountFormatted,
  required String walletAddress,
})
```
- Mengikat bukti transfer token IDRT ke log audit resmi Dinas Pariwisata Bali dengan status `'Paid'`.

---

## 4. Pengujian & Verifikasi Otomatis

Telah dibuat suite pengujian `test/milestone2_test.dart` menggunakan `MockClient` untuk mensimulasikan interaksi Fastify middleware:

```
$ flutter test test/milestone1_test.dart test/milestone2_test.dart
00:00 +0: Milestone 1 - Arithmetic & Precision Tests parseAmountToBigInt correctly scales 150,000 IDRT to 18 decimals without overflow
00:00 +1: Milestone 1 - Arithmetic & Precision Tests parseAmountToBigInt correctly handles fractional decimal amounts
00:00 +2: Milestone 1 - Arithmetic & Precision Tests formatBigInt avoids IEEE 754 precision loss and formats Indonesian Rupiah
00:00 +3: Milestone 1 - Arithmetic & Precision Tests formatBigInt correctly formats zero and decimals
00:00 +4: Milestone 1 - Security & PIN Hashing Tests PIN is securely hashed using SHA-256
00:00 +5: Milestone 2 - DTO Models Unit Tests BtidCredentialModel serializes and deserializes accurately
00:00 +6: Milestone 2 - DTO Models Unit Tests ConsentRequestModel serializes correctly and checks expiration
00:00 +7: Milestone 2 - DTO Models Unit Tests AuditTransactionModel tracks states correctly
00:00 +8: Milestone 2 - VerificationTransactionService Cryptography & Workflows generateDynamicQrToken outputs valid 45-second ephemeral JSON token
00:00 +9: Milestone 2 - VerificationTransactionService Cryptography & Workflows signAndSubmitConsent produces valid EVM signature and dispatches to Fastify
00:00 +10: Milestone 2 - VerificationTransactionService Cryptography & Workflows revokeMerchantAccess successfully marks audit record as Revoked
00:00 +11: All tests passed!
```

Analisis statis kode `flutter analyze`:
```
$ flutter analyze
Analyzing qrypta...
No issues found! (ran in 2.1s)
```

Milestone 2 telah tuntas dengan kode bersih, teruji, dan siap melangkah ke **Milestone 3 (Onboarding Paspor OCR MRZ & Auto-Keypair Issuance)**.
