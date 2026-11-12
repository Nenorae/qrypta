# DOKUMENTASI TEKNIS PENGERJAAN MILESTONE 5
## Pembayaran Retribusi (Tourist Levy) & QRIS On-Chain Berbasis IDRT

---

## 1. Ringkasan Eksekutif & Status Milestone 5

Milestone 5 mengintegrasikan mesin transaksi token ERC-20 **IDRT (Rupiah Token)** di Hyperledger Besu dengan alur **Fase B: Penyelesaian Retribusi Wisatawan (`ScrLevy`, `ScrLevyPay`, `ScrReceipt`)** dan **Tab 2: Solusi Pembayaran QRIS Merchant (`ScrPay`, `ScrPayReceipt`)** sesuai cetak biru *Bali Tourist ID Mockup* dan *ezsign-core*.

Modul ini mentransformasi pembayaran retribusi daerah konvensional dan transaksi ritel harian wisatawan menjadi transaksi terdesentralisasi yang transparan, presisi tanpa kehilangan desimal, terikat pada kedaulatan identitas (*Self-Sovereign Identity*), dan menjamin **perlindungan privasi mutlak (Zero-PII)** di mana pihak *merchant* kafe/toko hanya menerima konfirmasi `"Payment Confirmed"` tanpa pernah menerima data paspor, kebangsaan, maupun biometrik turis.

### Matriks Perbandingan Status Milestone 5

| Parameter | Sebelum Pengerjaan Milestone 5 | Pasca Pengerjaan Milestone 5 |
| :--- | :--- | :--- |
| **Alur Retribusi Wisatawan (Fase B)** | Belum ada layar pembayaran retribusi | **`LevyPaymentScreen` (ScrLevy & ScrLevyPay) + `LevyReceiptScreen`** |
| **Kuitansi Resmi Retribusi** | Belum diimplementasikan | **Kuitansi Bapenda On-Chain + Pita MRZ Retribusi TD3 (44 Chars)** |
| **Sumber Dana Utama Retribusi** | Belum terhubung | **Qrypta IDRT Wallet Balance (Live Saldo) + Visa + Counter QR** |
| **Pemindai Pembayaran QRIS (`ScrPay`)** | Kamera scanner transfer address mentah | **Deteksi Cerdas QRIS Merchant + UI `QrisPaymentScreen`** |
| **Shortcut Demo Evaluasi QRIS** | Tidak ada | **1-Click Simulation (Bali Coffee House 85k & Bali Adventure 350k)** |
| **Penegasan Privasi Merchant** | Tidak ada kontrol data | **Zero-PII Guarantee: Nol data paspor/identitas dibagikan ke merchant** |
| **Audit On-Chain ezsign-core** | Log `BTID_CONSENT` & `BTID_ISSUED` saja | **Audit On-Chain `BTID_LEVY_PAYMENT` & `BTID_QRIS_PAYMENT` via Fastify** |
| **Integrasi Pasca-Onboarding** | Tombol Dashboard langsung | **Sekuensial Wajib/Opsional: `Issued` ➔ `Levy` ➔ `Receipt` ➔ `Dashboard`** |
| **Statistik `flutter analyze`** | Bersih (Milestone 4) | **0 Issues / Bersih Sempurna (1.6s)** |
| **Statistik `flutter test`** | 28 Tests Passed (Milestone 1–4) | **38 Tests Passed (100% Lulus)** |

---

## 2. Arsitektur Alur Transaksi Finansial & Audit Ledger

Sistem membedakan secara tegas dua jalur transaksi finansial dengan jaminan pencatatan audit *tamper-evident*:

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                        ARSITEKTUR PEMBAYARAN RETRIBUSI & QRIS                          │
└────────────────────────────────────────────────────────────────────────────────────────┘

 [WISATAWAN (JAMES WILSON)]
      │
      ├──────────────────────────────┬──────────────────────────────┐
      │                              │                              │
      ▼ (Fase B: Tourist Levy)       ▼ (Tab 2: QRIS Merchant)       ▼ (P2P Send)
 ┌──────────────────────────┐   ┌──────────────────────────┐   ┌──────────────────────────┐
 │    LevyPaymentScreen     │   │    QrisPaymentScreen     │   │        SendScreen        │
 │ • Tagihan: IDR 150.000   │   │ • Merchant: Bali Coffee  │   │ • Alamat Tujuan (0x...)  │
 │ • Rekomendasi: IDRT Wlt  │   │ • Tagihan: IDR 85.000    │   │ • Nominal Fleksibel      │
 │ • Visa / Airport QR      │   │ • ZERO-PII GUARANTEE     │   │ • Transfer Token Biasa   │
 └────────────┬─────────────┘   └────────────┬─────────────┘   └────────────┬─────────────┘
              │                              │                              │
              ▼                              ▼                              ▼
      [Otorisasi Biometrik / PIN: AuthenticationService.authenticate(reason)]
              │
              ├─────────────────────────────────────────────────────────────┤
              │ 1. Eksekusi On-Chain: Erc20Service.sendErc20Token           │
              │    - Desimal IDRT: 18 digit (BigInt shift parseAmount)      │
              │    - Treasury Bapenda: 0x3565E871c841A8cE127B0e05Eb512a865..│
              │    - Merchant Bali Coffee: 0x3311A9908F8718E237aDE73708aB5..│
              │ 2. Sinkronisasi Finalitas: waitForTransactionReceipt(txHash)│
              │ 3. Dispatch Logging: POST /api/v1/verify-identity (Fastify) │
              └──────────────────────────────┬──────────────────────────────┘
                                             │
                   ┌─────────────────────────┴─────────────────────────┐
                   ▼                                                   ▼
     ┌───────────────────────────┐                       ┌───────────────────────────┐
     │  ezsign-core (Fastify)    │                       │     HYPERLEDGER BESU      │
     │ • Queue: ezsign_logging   │                       │ • Smart Contract Treasury │
     │ • Worker Konsumsi AMQP    │                       │ • Mutasi Saldo IDRT       │
     │ • Audit Trail Imutabel    │                       │ • Bukti Kuitansi TxHash   │
     └───────────────────────────┘                       └───────────────────────────┘
```

---

## 3. Alur Pembayaran Bali Tourist Levy (Fase B)

Berdasarkan **Peraturan Daerah Provinsi Bali No. 6 Tahun 2023** tentang Kontribusi Wisatawan Asing untuk Pelindungan Kebudayaan dan Lingkungan Alam Bali:

### 3.1 Layar `LevyPaymentScreen` (`ScrLevy` & `ScrLevyPay`)
- **File:** `lib/src/features/transaction/presentation/screens/levy_payment_screen.dart`
- **Fitur & Komponen UI:**
  1. **Header Resmi Pemerintah:** Banner lambang perisai emas Pemerintah Provinsi Bali dan penegasan dasar hukum Perda No. 6/2023.
  2. **Invoice Resmi Retribusi:**
     - Nominal Resmi: **IDR 150.000** ($150000 \times 10^{18}$ IDRT).
     - Identitas Wisatawan: `James Wilson` | Paspor: `••••••789` | BTID: `BTID-2026-4471-0938`.
     - Status Badge: *PAID* (hijau) atau *PAYMENT DUE* (kuning amber).
  3. **Pilihan Sumber Dana (`PAY_METHODS`):**
     - **Qrypta IDRT Wallet Balance (Metode Utama & Direkomendasikan):** Mengambil saldo langsung secara reaktif dari `tokenNotifierProvider` (contoh: *Available: Rp 2.480.000*). Memanfaatkan *smart contract* ERC-20 di Hyperledger Besu.
     - **Credit or Debit Card:** Simulasi kartu internasional (*Visa •••• 4218*).
     - **Airport Desk Counter QR:** Pembayaran langsung di loket bandara Ngurah Rai DPS.
  4. **Logika Eksekusi Pembayaran:**
     - Otorisasi biometrik wajib (`AuthenticationService.authenticate`).
     - Transfer saldo token IDRT ke *Treasury Smart Contract Bapenda Bali* (`BlockchainConfig.bapendaTreasuryAddress`).
     - Pengiriman audit log `BTID_LEVY_PAYMENT` ke middleware `ezsign-core`.
     - Perubahan status kredensial `btid.levyStatus = 'paid'` dan penyimpanan referensi kuitansi `LVY-XXXXX`.
     - Transisi otomatis ke layar `LevyReceiptScreen`.
  5. **Opsi "Pay Later":** Wisatawan dapat menunda pembayaran dan langsung melanjutkan ke dashboard. Kartu Tourist ID akan mempertahankan status *Levy Pending* dengan badge kuning hingga diselesaikan.

---

### 3.2 Layar `LevyReceiptScreen` (`ScrReceipt`)
- **File:** `lib/src/features/transaction/presentation/screens/levy_receipt_screen.dart`
- **Fitur & Komponen UI:**
  1. **Kop Resmi Badan Pendapatan Daerah (Bapenda):** Menampilkan tulisan *PEMERINTAH PROVINSI BALI • BADAN PENDAPATAN DAERAH (BAPENDA)* dengan badge *RECONCILED ON-CHAIN • IMMUTABLE*.
  2. **Rincian Pembayaran:** Referensi kuitansi unik (`LVY-448102`), nama wisatawan, nomor paspor bertopeng, nominal IDR 150.000, metode pembayaran, stempel waktu ISO lokal, serta alamat *Treasury Contract*.
  3. **Copyable Transaction Hash:** Tombol salin satu ketukan untuk *Transaction Hash* Hyperledger Besu dengan notifikasi konfirmasi *toast SnackBar*.
  4. **Pita MRZ Retribusi Digital (Tourist Levy MRZ Strip):** Pita monospasi bergaya ICAO TD3 yang dapat dibaca mesin scanner petugas bandara/pelabuhan.
  5. **Aksi Kuitansi:** Fitur simulasi unduh kuitansi PDF resmi dan tombol kembali ke dashboard utama (`HomeScreen`).

---

## 4. Spesifikasi Standar Pita MRZ Retribusi Digital (TD3)

Untuk menjamin kompatibilitas pemindaian optik oleh petugas imigrasi dan pengawas retribusi di pintu kedatangan, kuitansi digital dilengkapi pita MRZ 2 baris berstandar lebar **tepat 44 karakter alfanumerik**:

```
Line 1: LEVY<<LVY<448102<<IDR150000<<<<<<<<<<<<<<<<
Line 2: BTID<<BTID<2026<4471<0938<<PAID<<<<<<<<<<<<
```

### Rumus Formulasi Monospasi (`LevyReceiptData`):
```dart
static String generateMrzLine1(String levyRef, int amount) {
  final cleanRef = levyRef.replaceAll('-', '<');
  final raw = 'LEVY<<$cleanRef<<IDR$amount';
  return raw.length > 44 ? raw.substring(0, 44) : raw.padRight(44, '<');
}

static String generateMrzLine2(String btidNumber) {
  final cleanBtid = btidNumber.replaceAll('-', '<');
  final raw = 'BTID<<$cleanBtid<<PAID';
  return raw.length > 44 ? raw.substring(0, 44) : raw.padRight(44, '<');
}
```

- **Line 1 (44 Karakter):** Mengidentifikasi dokumen retribusi (`LEVY`), kode transaksi unik Bapenda (`LVY<448102`), nominal mata uang (`IDR150000`), dan sisa kolom dipadatkan dengan karakter pengisi `<`.
- **Line 2 (44 Karakter):** Mengikat kode identitas turis pemegang (`BTID<2026<4471<0938`), status pelunasan hukum (`PAID`), dan dipadatkan dengan karakter `<`.

---

## 5. Refactor Scanner Qrypta Menjadi QRIS Payment (`ScrPay`)

### 5.1 Logika Pendeteksian Cerdas & Routing Multi-Format
Modifikasi pada `lib/src/features/qr_scanner/presentation/screens/qr_scanner_screen.dart` memungkinkan kamera membaca berbagai bentuk *payload* QR:

```dart
void _handleScannedData(BuildContext context, String rawData) {
  // 1. Deteksi Format JSON QRIS Dinamis
  if (rawData.startsWith('{') && rawData.endsWith('}')) {
    final decoded = jsonDecode(rawData);
    if (decoded['type'] == 'QRIS' || decoded.containsKey('merchantId')) {
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => QrisPaymentScreen(
          merchantName: decoded['merchantName'] ?? 'Bali Coffee House',
          merchantId: decoded['merchantId'] ?? 'MCH-3311',
          merchantAddress: decoded['address'] ?? '0x3311A9908F8718E237aDE73708aB59f212284bE0',
          initialAmount: decoded['amount'] ?? 85000,
          itemDescription: decoded['description'] ?? 'Merchant Settlement',
        ),
      ));
      return;
    }
  }

  // 2. Deteksi Alamat EVM Merchant Ekosistem
  if (rawData.startsWith('0x') && rawData.length == 42) {
    final merchant = demoMerchants.values
        .where((m) => m.walletAddress.toLowerCase() == rawData.toLowerCase())
        .firstOrNull;
    if (merchant != null) {
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => QrisPaymentScreen(
          merchantName: merchant.name,
          merchantId: merchant.id,
          merchantAddress: merchant.walletAddress,
          initialAmount: merchant.category == 'cafe' ? 85000 : 150000,
        ),
      ));
      return;
    }
    // Fallback Transfer P2P Standar
    Navigator.push(context, MaterialPageRoute(
      builder: (context) => SendScreen(initialAddress: rawData),
    ));
    return;
  }
}
```

### 5.2 Layar `QrisPaymentScreen` (`ScrPay`)
- **File:** `lib/src/features/transaction/presentation/screens/qris_payment_screen.dart`
- **Fitur Utama:**
  - Header profil merchant mitra resmi: `Bali Coffee House - Canggu` (MCH-3311).
  - Tampilan tagihan: Default **IDR 85.000**, dilengkapi *chips* preset cepat (50k, 85k, 150k, 250k).
  - Tampilan sumber dana: Saldo dompet Web3 IDRT secara *live*.
  - **Banner Kedaulatan Privasi (Zero-PII Callout):**
    > *"Merchant only receives Payment Confirmed — Zero passport, identity, or personal data shared."*
  - Eksekusi pembayaran aman melalui otorisasi biometrik dan transfer on-chain ERC-20 IDRT.

### 5.3 Layar `QrisReceiptScreen` (`ScrPayReceipt`)
- **File:** `lib/src/features/transaction/presentation/screens/qris_receipt_screen.dart`
- Menampilkan nomor referensi pembayaran unik `PAY-XXXXXX`, cap waktu transaksi, hash transaksi Hyperledger Besu, serta stempel jaminan *Zero-PII Protection*.

### 5.4 Panel Pintas Simulasi Demo Evaluasi
Pada `SendScannerScreen` (`send_scanner_screen.dart`), ditambahkan panel apung di bawah jendela pemindai:
- **Shortcut 1:** `☕ Bali Coffee House (IDR 85.000)`
- **Shortcut 2:** `🌋 Bali Adventure Tours (IDR 350.000)`
Fitur ini menjamin proses demonstrasi dan pengujian evaluasi berjalan 100% lancar tanpa hambatan pencahayaan atau ketiadaan kertas QR fisik.

---

## 6. Protokol Pencatatan Audit ezsign-core & Fastify Middleware

Setiap pembayaran retribusi dan transaksi QRIS secara langsung dikirimkan ke endpoint Fastify middleware `/api/v1/verify-identity` untuk dicatat ke dalam antrean RabbitMQ `ezsign_logging_queue` dan diproses oleh `tx-worker`:

### 6.1 Skema Payload Audit Tourist Levy (`BTID_LEVY_PAYMENT`)
```json
{
  "uuid": "BTID-2026-4471-0938",
  "client_type": "web3",
  "signature": "0x",
  "docType": "BTID_LEVY_PAYMENT",
  "metadata": {
    "actor": "James Wilson",
    "org": "Bali Tourism Authority (Bapenda)",
    "role": "Tourist",
    "action": "Tourist Levy paid (IDR 150,000)",
    "purpose": "Official Bali Tourist Levy Settlement",
    "record": "LVY-448102",
    "result": "Paid",
    "amount": "IDR 150,000",
    "walletAddress": "0x71CB05EE1b1F506fF321Da3CE92a540AC401B4D0",
    "txHash": "0x7b2f8a1e9c4d3b5a7e6f8a9b0c1d2e3f4a5b6c7d",
    "auditRef": "AUD-592810"
  },
  "timestamp": 1794407445
}
```

### 6.2 Skema Payload Audit QRIS Merchant (`BTID_QRIS_PAYMENT`)
```json
{
  "uuid": "0x71CB05EE1b1F506fF321Da3CE92a540AC401B4D0",
  "client_type": "web3",
  "signature": "0x",
  "docType": "BTID_QRIS_PAYMENT",
  "metadata": {
    "actor": "James Wilson",
    "org": "Bali Coffee House - Canggu",
    "role": "Customer",
    "action": "QRIS Merchant Payment (IDR 85,000)",
    "purpose": "Licensed Payment Settlement",
    "record": "PAY-882194",
    "merchantId": "MCH-3311",
    "result": "Paid",
    "amount": "IDR 85,000",
    "itemDescription": "Specialty Coffee & Pastry",
    "walletAddress": "0x71CB05EE1b1F506fF321Da3CE92a540AC401B4D0",
    "txHash": "0x8821947b2f8a1e9c4d3b5a7e6f8a9b0c1d2e3f4a",
    "auditRef": "AUD-610284",
    "privacyGuarantee": "Zero personal data or identity revealed to merchant"
  },
  "timestamp": 1794407445
}
```

---

## 7. Aritmatika Token IDRT & Keamanan Dana (BigInt Scaling)

Untuk mencegah bug fatal *integer overflow* di atas 9.22 IDRT yang pernah ada di repositori lama:
1. Seluruh nominal transaksi dihitung menggunakan fungsi `parseAmountToBigInt(nominalString, 18)`.
2. Nominal Rp 150.000 dikonversi secara presisi menjadi:
   $$150.000 \times 10^{18} = 150.000.000.000.000.000.000.000\text{ (Wei IDRT)}$$
3. Tidak pernah melewati tipe data IEEE 754 `double` atau 64-bit integer biasa (`int64`), sehingga transaksi berapapun besarnya (hingga miliaran Rupiah) aman dari pemotongan presisi dan crash overflow.

---

## 8. State Management: `PaymentNotifier` & `paymentControllerProvider`

File: `lib/src/features/transaction/logic/payment_controller.dart`

```dart
class PaymentNotifier extends StateNotifier<PaymentState> {
  final Ref ref;

  PaymentNotifier(this.ref) : super(const PaymentState());

  /// Eksekusi Pembayaran Tourist Levy
  Future<LevyReceiptData> payTouristLevy({required String paymentMethod}) async;

  /// Eksekusi Pembayaran Merchant QRIS
  Future<QrisReceiptData> payQrisMerchant({
    required String merchantName,
    required String merchantId,
    required String merchantAddress,
    required int amountIdr,
    String? itemDescription,
  }) async;
}
```

### Integrasi State Lintas Fitur:
- **`btidCredentialProvider`:** Memperbarui `levyStatus` menjadi `'paid'` dan mencatat `levyReceiptRef`.
- **`tokenNotifierProvider`:** Memanggil `fetchUserTokens()` secara otomatis untuk memperbarui sisa saldo IDRT di layar utama dan kartu.
- **`verificationControllerProvider`:** Memanggil `loadAuditHistory()` agar entri audit `LVY-XXXXX` dan `PAY-XXXXXX` langsung muncul di layar *Privacy Audit* dan riwayat aktivitas terkini.

---

## 9. Hasil Pengujian Unit & Integrasi (`test/milestone5_test.dart`)

Sebanyak **10 skenario pengujian baru** telah ditambahkan dan lulus 100%:

```bash
$ export PATH="/opt/flutter/bin:$PATH" && flutter test test/milestone5_test.dart
00:00 +0: Milestone 5 - Tourist Levy & QRIS Audit Logging Tests recordLevyPaymentAudit dispatches BTID_LEVY_PAYMENT to ezsign-core and persists audit
00:00 +1: Milestone 5 - Tourist Levy & QRIS Audit Logging Tests recordQrisPaymentAudit dispatches BTID_QRIS_PAYMENT to ezsign-core with Zero-PII notice
00:00 +2: Milestone 5 - Digital Levy MRZ Strip & Receipt Data Tests generateMrzLine1 produces strict TD3 44-character line for levy reference
00:00 +3: Milestone 5 - Digital Levy MRZ Strip & Receipt Data Tests generateMrzLine2 produces strict TD3 44-character line for BTID and paid status
00:00 +4: Milestone 5 - Digital Levy MRZ Strip & Receipt Data Tests QrisReceiptData retains zero-PII privacy guarantee by default
00:00 +5: Milestone 5 - Token Arithmetic & Precision Tests Tourist Levy of 150,000 IDRT scales precisely to 18 decimals without IEEE 754 precision loss
00:00 +6: Milestone 5 - Token Arithmetic & Precision Tests QRIS Cafe payment of 85,000 IDRT scales precisely to 18 decimals
00:00 +7: Milestone 5 - Token Arithmetic & Precision Tests Bapenda Treasury Address is configured and valid EVM hex
00:00 +8: Milestone 5 - Token Arithmetic & Precision Tests Demo merchant addresses for QRIS are configured and valid EVM hex
00:00 +9: Milestone 5 - BTID Credential Levy State Transitions Credential starts unpaid and transitions cleanly to paid upon levy settlement
00:01 +10: All tests passed!
```

### Akumulasi Total Test Seluruh Milestone:
- **Total Test Suite:** 5 File (`milestone1_test.dart` s/d `milestone5_test.dart`)
- **Total Uji Coba:** **38 Skenario Uji (100% Lulus)**
- **Waktu Eksekusi:** 1.0 Detik
- **Hasil Analisis Statis:** `No issues found! (ran in 1.6s)`

---

## 10. Panduan Verifikasi & Demonstrasi Evaluasi

Bagi penguji atau evaluator teknis yang ingin mendemokan Milestone 5:

1. **Jalur Onboarding ➔ Pembayaran Tourist Levy (Fase B):**
   - Jalankan aplikasi (`flutter run`).
   - Tekan tombol *Use Demo Passport (James Wilson)* pada layar MRZ scanner.
   - Selesaikan sekuensial NFC, Sertifikat PKI, dan Liveness test.
   - Pada layar *Your Bali Tourist ID is Ready*, tekan tombol **Next: Tourist Levy (IDR 150,000)**.
   - Pada layar *Bali Tourist Levy*, perhatikan saldo IDRT yang tampil (*Rp 2.480.000*).
   - Tekan **Pay IDR 150,000** ➔ Lakukan autentikasi biometrik/PIN.
   - Layar bertransisi ke **Official Levy Receipt** lengkap dengan kop Pemerintah Provinsi Bali, nomor kuitansi `LVY-XXXXX`, Transaction Hash Besu, dan pita MRZ digital retribusi.
   - Tekan *Continue to Dashboard* ➔ perhatikan badge Tourist ID kini berubah menyala hijau: **Levy Paid**.

2. **Jalur Pembayaran QRIS Merchant (Tab 2 / Quick Action):**
   - Buka menu aksi cepat pembayaran atau tab Pay.
   - Pada pemindai kamera, tekan tombol shortcut **☕ Bali Coffee House (IDR 85,000)**.
   - Layar konfirmasi tagihan `QrisPaymentScreen` akan terbuka dengan penegasan privasi *Zero-PII*.
   - Tekan **Pay IDR 85,000** ➔ Kuitansi pembayaran `PAY-XXXXXX` langsung terbit dan tercatat di audit ledger Hyperledger Besu & ezsign-core.
