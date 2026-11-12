# DOKUMENTASI TEKNIS PENGERJAAN MILESTONE 4
## Mesin Transaksi Verifikasi Identitas & Selective Disclosure

---

## 1. Ringkasan Eksekutif & Status Milestone 4

Milestone 4 mengimplementasikan inti nilai utama dari inovasi **Bali Tourist ID**: **Protokol Selective Disclosure & Persetujuan Kriptografis Berbasis Tujuan (*Purpose-Bound Cryptographic Consent*)**.

Modul ini sepenuhnya mengeliminasi praktik konvensional berbahaya berupa fotokopi paspor fisik di hotel, rental kendaraan, atau tempat hiburan. Wisatawan kini mengendalikan kedaulatan data identitas mereka (*Self-Sovereign Identity*) melalui **Dynamic Rotating QR Code (45 Detik)**, meninjau permintaan atribut terikat regulasi pemerintah pada layar **Consent Request**, menandatangani transaksi persetujuan menggunakan kunci privat lokal `secp256k1` (*Zero-PII on-chain*), serta memegang kendali audit mandiri dan pencabutan hak akses (*Revocation*) pada **Privacy Audit Centre**.

### Matriks Perbandingan Status Milestone 4

| Parameter | Sebelum Pengerjaan Milestone 4 | Pasca Pengerjaan Milestone 4 |
| :--- | :--- | :--- |
| **Penyajian QR Identitas** | Layar statis alamat wallet EVM | **QR Dinamis 45s Ephemeral Token (`QRT-XXXXXXXXXX`)** |
| **Persetujuan Atribut Turis** | Belum ada layar seleksi data | **Checklist Atribut Terikat Tujuan + Otorisasi Biometrik** |
| **Matriks Regulasi & Privasi** | Belum diimplementasikan | **18 Atribut Resmi + 1 Biometrik Terkunci + 9 Template Pemda** |
| **Simulasi Handshake Merchant** | Belum ada mekanisme uji coba | **Panel Simulasi 1-Klik (Hotel, Car Rental, Cafe ZK-Age)** |
| **Bukti Transaksi & TxHash** | Transaksi transfer saldo saja | **Bukti Pertukaran `TX-XXXXXX` + TxHash Besu + Copyable** |
| **Audit Riwayat & Pencabutan** | Riwayat transfer token saja | **Self-Audit Dashboard + Unduh Kuitansi JSON + Revoke + Report** |
| **Statistik `flutter analyze`** | Bersih (Milestone 3) | **0 Issues / Bersih Sempurna** |
| **Statistik `flutter test`** | 18 Tests Passed (Milestone 1–3) | **28 Tests Passed (100% Lulus)** |

---

## 2. Arsitektur Protokol Selective Disclosure & Cryptographic Handshake

Alur pertukaran data verifikasi antara wisatawan, pedagang (*merchant*), middleware `ezsign-core`, dan blockchain Hyperledger Besu dirancang tanpa pernah membocorkan data pribadi mentah (*raw PII*) ke ledger publik:

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                        PROTOKOL DYNAMIC QR & CRYPTOGRAPHIC CONSENT                     │
└────────────────────────────────────────────────────────────────────────────────────────┘

 [TURIS APP (JAMES)]             [MERCHANT APP (HOTEL)]          [ezsign-core & BESU]
          │                                    │                                 │
          │── 1. Terbitkan QR Dinamis (45s) ──►│                                 │
          │      (Token: `QRT-9X2KL8MPQ1`)     │                                 │
          │                                    │                                 │
          │                                    │── 2. Kirim Permintaan Data ────►│
          │◄── 3. Push Notifikasi Permintaan ──│      (Template: hotel_checkin)  │
          │      (TX-448102: 6 Atribut)        │                                 │
          │                                    │                                 │
          ▼                                                                      │
   [Tinjau Consent]                                                              │
   • Full name: James Wilson                                                     │
   • Stay validity: Valid (28d left)                                             │
   • Levy: Paid (LVY-88412)                                                      │
   • Retensi: 30 hari akomodasi                                                  │
   • Biometrik: TERKUNCI PERMANEN                                                │
          │                                                                      │
          │── 4. Approve & Sign Personal ───────────────────────────────────────►│
          │      (Digest SHA-256 + secp256k1)                                    │ • AMQP Enqueue
          │                                    │                                 │ • Dynamic Nonce
          │                                    │◄── 5. Terima Atribut Terbatas ──│ • smart contract
          │                                    │      (Check-in sukses, NO FOTO) │   recordVerification
          │                                                                      │
          ▼                                                                      ▼
   [ScrShared / ScrPrivacy]                                             [HYPERLEDGER BESU]
   • Ref: TX-448102                                                     • Immutable Audit Trail
   • TxHash: 0x7b2f...81c9                                              • Keccak256 userHash
   • Fitur: Revoke & Report                                             • Status: APPROVED
```

---

## 3. Matriks Minimalisasi Data & Kebijakan Privasi (`policy_matrix_constants.dart`)

File: `lib/src/features/verification/data/policy_matrix_constants.dart`

### 3.1 Daftar 18 Atribut Resmi + 1 Biometrik Terkunci
Sistem mendefinisikan secara ketat seluruh atribut yang dapat diminta di dalam ekosistem pariwisata:

| Kunci Atribut | Label Atribut | Deskripsi Data | Alasan Standar Regulasi |
| :--- | :--- | :--- | :--- |
| `name` | Full Name | Nama lengkap resmi sesuai paspor | Identifikasi registrasi buku tamu resmi |
| `nationality` | Nationality | Kode negara 3 huruf ICAO | Pelaporan statistik keimigrasian daerah |
| `identity` | Identity Verified | Status lolos verifikasi digital | Bukti onboarding terakreditasi pemerintah |
| `passport_auth`| Passport Authenticated | Status keaslian chip ePassport | Menjamin paspor fisik bukan dokumen palsu |
| `id_validity` | Tourist ID Validity | Masa berlaku identitas digital turis | Memastikan kredensial turis masih aktif |
| `levy_status` | Tourist Levy Status | Status pelunasan retribusi Rp 150.000| Kepatuhan kontribusi pelestarian pariwisata |
| `over18` | Age Eligibility (18+) | Hasil verifikasi usia dewasa (18+) | Verifikasi tanpa membuka tanggal lahir |
| `over21` | Age Eligibility (21+) | Hasil verifikasi usia dewasa (21+) | Kepatuhan izin masuk lounge/klub malam |
| `dob` | Exact Date of Birth | Tanggal, bulan, dan tahun kelahiran | Keperluan identifikasi khusus perbankan/rs |
| `passport_number`| Passport Number | Nomor paspor bertopeng (`••••••789`) | Verifikasi buku register penginapan pemda |
| `arrival` | Arrival Date | Tanggal masuk wilayah Indonesia | Validasi durasi tinggal sah |
| `departure` | Departure Date | Tanggal rencana keberangkatan | Sinkronisasi reservasi kamar hotel |
| `visa_type` | Visa Class | Jenis visa imigrasi aktif (e-VOA B1) | Validasi kategori izin kunjungan turis |
| `stay_valid` | Permitted Stay Status | Status izin tinggal dan sisa hari | Mencegah pelanggaran overstay keimigrasian |
| `stay_expiry` | Stay Permit Expiry | Tanggal kedaluwarsa izin tinggal | Batas akhir izin sewa kendaraan bermotor |
| `driving` | Driving Credential | Status SIM Internasional Kategori B | Syarat wajib legalitas rental mobil/motor |
| `payment_confirm`| Payment Confirmation | Konfirmasi penyelesaian transaksi | Bukti lunas tanpa menyertakan PII |
| `emergency` | Emergency Contact | Kontak kerabat darurat bertopeng | Penanganan darurat medis atau bencana alam |
| `biometric` | Biometric Face Template| Vektor embedding wajah pengguna | **PERMANEN PROHIBITED (TIDAK DIBAGIKAN)** |

### 3.2 Daftar 9 Template Akses Resmi Pemerintah (`TEMPLATES`)
Merchant dibatasi oleh 9 template tujuan resmi pemerintah dan **tidak diizinkan membuat permintaan isian bebas (*no free-form requests*)**:

1. **`hotel_checkin` (Hotel Check-in):**
   - *Kategori Berhak:* `hotel`
   - *Core Fields:* `name`, `nationality`, `id_validity`, `passport_auth`, `levy_status`, `stay_valid`.
   - *Optional Fields:* `passport_number`, `dob`, `arrival`, `departure`, `visa_type`, `stay_expiry`.
   - *Klausul Retensi:* Disimpan 30 hari sesuai peraturan daerah akomodasi wisata.
2. **`vehicle_rental` (Vehicle Rental Eligibility):**
   - *Kategori Berhak:* `car`
   - *Core Fields:* `name`, `identity`, `over18`, `id_validity`, `passport_auth`, `driving`.
   - *Optional Fields:* `dob`, `stay_expiry`.
   - *Klausul Retensi:* Disimpan selama masa sewa kendaraan ditambah 90 hari.
3. **`esim_activation` (eSIM Cellular Activation):**
   - *Kategori Berhak:* `esim`
   - *Core Fields:* `identity`, `id_validity`.
   - *Optional Fields:* `name`, `nationality`, `passport_auth`, `passport_number`, `stay_expiry`.
   - *Klausul Retensi:* Disimpan selama durasi paket telekomunikasi aktif.
4. **`stay_validity` (Permitted Stay Confirmation):**
   - *Kategori Berhak:* `hotel`, `esim`, `car`, `tour`
   - *Core Fields:* `stay_valid`.
   - *Klausul Retensi:* Hasil boolean saja. Berkas imigrasi mentah tidak pernah dibagikan.
5. **`age_check` (Age Verification):**
   - *Kategori Berhak:* `hotel`, `car`, `cafe`, `tour`, `esim`
   - *Core Fields:* `over18`.
   - *Optional Fields:* `over21`.
   - *Klausul Retensi:* Hasil verifikasi umur instan. Nol data yang disimpan di luar referensi transaksi.
6. **`tour_participation` (Tour Participation):**
   - *Kategori Berhak:* `tour`
   - *Core Fields:* `name`, `identity`, `id_validity`, `over18`.
   - *Klausul Retensi:* Disimpan selama tanggal tur ditambah 14 hari.
7. **`levy_check` (Tourist Levy Verification):**
   - *Kategori Berhak:* `hotel`, `esim`, `tour`
   - *Core Fields:* `levy_status`.
   - *Klausul Retensi:* Status retribusi saja. Detail rekening bank/kartu tidak pernah dibagikan.
8. **`payment_confirm` (Payment Confirmation):**
   - *Kategori Berhak:* `cafe`, `hotel`, `car`, `tour`, `esim`
   - *Core Fields:* `payment_confirm`.
   - *Klausul Retensi:* Dikelola oleh penyedia gerbang pembayaran berlisensi.
9. **`emergency_support` (Emergency Support):**
   - *Kategori Berhak:* `tour`, `hotel`
   - *Core Fields:* `name`, `identity`, `emergency`.
   - *Klausul Retensi:* Disimpan selama penanganan insiden darurat berlangsung.

### 3.3 Matriks Kebijakan Kategori Merchant (`DEFAULT_POLICY`)

```
┌─────────────────┬───────────┬───────────┬───────────┬───────────┬───────────┐
│ Atribut         │ Hotel     │ Car       │ Cafe      │ eSIM      │ Tour      │
├─────────────────┼───────────┼───────────┼───────────┼───────────┼───────────┤
│ name            │ Allowed   │ Allowed   │ Prohibit  │ Condition │ Allowed   │
│ nationality     │ Allowed   │ Allowed   │ Prohibit  │ Condition │ Condition │
│ passport_number │ Condition │ Condition │ Prohibit  │ Condition │ Prohibit  │
│ over18          │ Condition │ Allowed   │ Condition │ Condition │ Allowed   │
│ dob             │ Condition │ Condition │ Prohibit  │ Prohibit  │ Condition │
│ driving         │ Prohibit  │ Allowed   │ Prohibit  │ Prohibit  │ Prohibit  │
│ payment_confirm │ Allowed   │ Allowed   │ Allowed   │ Allowed   │ Allowed   │
│ biometric       │ PROHIBIT  │ PROHIBIT  │ PROHIBIT  │ PROHIBIT  │ PROHIBIT  │
└─────────────────┴───────────┴───────────┴───────────┴───────────┴───────────┘
```

---

## 4. Implementasi Komponen & Layar Transaksi

### 4.1 Controller Transaksi (`verification_controller.dart`)
- **File:** `lib/src/features/verification/logic/verification_controller.dart`
- **State Management:** Riverpod `StateNotifierProvider<VerificationNotifier, VerificationState>`.
- **Fungsi Utama:**
  - `startOrRefreshQr()`: Menghasilkan token acak 45 detik via `VerificationTransactionService.generateDynamicQrToken()`, mereset timer, dan mengelola hitung mundur setiap detik.
  - `triggerMerchantSimulation(String category)`: Membangkitkan objek `ConsentRequestModel` simulasi untuk kebutuhan demo interaktif (Bali Ocean Resort, Island Drive Car Rental, Bali Coffee House).
  - `approveConsent(...)`: Menandatangani canonical digest secara kriptografis (`signAndSubmitConsent`), mencatat ke Hive box lokal, dan mengembalikan `AuditTransactionModel`.
  - `rejectConsent(...)`: Menandatangani penolakan eksplisit dan mencatat outcome `REJECTED` ke blockchain.
  - `revokeAccess(...)`: Menandatangani instruksi pencabutan izin merchant di masa depan dan mengubah status lokal menjadi `Revoked`.
  - `loadAuditHistory()`: Mengambil seluruh histori transaksi dari penyimpanan lokal dan service.

### 4.2 Dynamic QR Screen (`dynamic_qr_screen.dart` - ScrQr)
- **File:** `lib/src/features/verification/presentation/screens/dynamic_qr_screen.dart`
- **Spesifikasi UI/UX:**
  - Menampilkan badge nomor BTID wisatawan: `BTID-2026-4471-0938`.
  - Timer visual progres hitung mundur dari **45 detik ke 0 detik**.
  - Kode QR (`qr_flutter`) merender payload JSON berformat:
    ```json
    {
      "token": "QRT-9X2KL8MPQ1",
      "btid": "BTID-2026-4471-0938",
      "wallet": "0x71CB05EE1b1F506fF321Da3CE92a540AC401B4D0",
      "exp": 1794407445
    }
    ```
  - **Penanganan Kedaluwarsa:** Saat timer menyentuh 0s, kode QR otomatis diburamkan (*opacity 0.08*), muncul overlay peringatan *"Code Expired - 45-second validity ended"*, dan tombol **"Refresh code"** aktif.
  - **Dev/Demo Handshake Simulation:** Panel bawah menyediakan 3 tombol chip simulasi cepat (*Bali Ocean Resort*, *Island Drive Car Rental*, *Bali Coffee House*) yang langsung memunculkan alur persetujuan saat ditekan.

### 4.3 Consent Request Screen (`consent_request_screen.dart` - ScrConsent)
- **File:** `lib/src/features/verification/presentation/screens/consent_request_screen.dart`
- **Spesifikasi UI/UX:**
  - Header identitas merchant terakreditasi: Nama merchant (*Bali Ocean Resort*), petugas kasir (*Kadek Sari · Front Desk Agent*), badge *Verified Business*, dan timer kedaluwarsa request (3 menit).
  - **Checklist Atribut Dinamis:** Menampilkan nilai data riil yang disesuaikan dengan jenis izin (misal: *Age eligibility: Over 18 — verified* tanpa tanggal lahir untuk kategori kafe).
  - Wisatawan memiliki hak interaktif untuk mencentang/menolak atribut opsional (*Selective Disclosure*).
  - Kotak klausul retensi resmi (*"Retained for 30 days under regional accommodation policy"*).
  - Peringatan proteksi biometrik: *"Never shared: Biometric template, live face capture, and full passport chip contents"*.
  - **Tombol Aksi:**
    - `Ask`: Membuka dialog klarifikasi langsung ke kasir (*"Why do you need my passport number?"*).
    - `Reject`: Menolak transaksi persetujuan.
    - `Approve & share`: Memanggil otorisasi biometrik/PIN `AuthenticationService.authenticate()`, mengambil *private key* dari Secure Storage, menandatangani transaksi, mengirimkannya ke Besu via Fastify, lalu membuka layar konfirmasi `ConsentSharedScreen`.

### 4.4 Consent Shared Screen (`consent_shared_screen.dart` - ScrShared)
- **File:** `lib/src/features/verification/presentation/screens/consent_shared_screen.dart`
- **Spesifikasi UI/UX:**
  - Ikon centang toska beranimasi dengan teks *"Data Shared Successfully"*.
  - Rincian kuitansi transaksi: Nomor referensi transaksi (`TX-XXXXXX`), kode audit (`AUD-XXXXXX`), nama merchant, petugas kasir, tujuan akses, cap waktu ISO, dan status `APPROVED`.
  - Kotak Transaksi Blockchain: Menampilkan *Transaction Hash* Hyperledger Besu (`0x...`) dengan tombol **"Copy"** 1-klik ke clipboard.
  - Ringkasan pill atribut minimal yang diserahkan.
  - Tombol **"View in Privacy Audit Centre"** untuk memeriksa status akses.

### 4.5 Privacy Audit Screen (`privacy_audit_screen.dart` - ScrPrivacy)
- **File:** `lib/src/features/verification/presentation/screens/privacy_audit_screen.dart`
- **Spesifikasi UI/UX:**
  - **3 Kartu Statistik di Bagian Atas:**
    - `Approved`: Total transaksi pertukaran data yang disetujui (badge toska).
    - `Rejected`: Total transaksi yang ditolak wisatawan (badge merah).
    - `Active Access`: Total merchant aktif yang memiliki izin akses (badge ungu).
  - **Riwayat Transaksi Lengkap:** Menampilkan seluruh log aktivitas audit dengan status transaksi, nomor referensi `TX-XXXXXX`, cap waktu, dan link hash transaksi Besu.
  - **3 Tombol Aksi Fungsional per Transaksi (Sesuai Spesifikasi Milestone 4):**
    1. **`Receipt` (Download Consent Receipt):** Membuka Modal BottomSheet yang menampilkan JSON tanda terima kriptografis (tanda tangan EIP-191, TxHash Besu, metadata lengkap) dengan tombol copy.
    2. **`Revoke` (Stop Future Access):** Menandatangani instruksi pencabutan akses dengan kunci privat lokal, mengirimkannya ke blockchain Besu, dan mengubah status izin menjadi `REVOKED`.
    3. **`Report` (Report Unexpected Access):** Membuka modal investigasi dan menerbitkan tiket komplain resmi berformat `EXC-XXXX` ke antrean pengaduan kepatuhan pemerintah (*GovExceptions Queue*).

---

## 5. Protokol Kriptografi On-Chain Zero-PII

Untuk mematuhi regulasi perlindungan data pribadi (UU PDP & GDPR), data identitas mentah wisatawan **tidak pernah diunggah ke ledger blockchain**.

### 5.1 Format Canonical Payload untuk Penandatanganan
Saat tombol persetujuan ditekan, aplikasi menyusun digest kanonikal:
```json
{
  "txRef": "TX-448102",
  "btidHash": "0x7a89b...3c12",
  "merchantId": "MCH-1042",
  "purpose": "hotel_checkin",
  "attributeKeys": ["name", "nationality", "id_validity", "passport_auth", "levy_status", "stay_valid"],
  "outcome": "APPROVED",
  "timestamp": "2026-11-12T06:30:00Z"
}
```

### 5.2 Penandatanganan EIP-191 / Personal Sign
Aplikasi menggunakan pustaka `web3dart` untuk menandatangani hash UTF-8 dari payload kanonikal tersebut:
```dart
final signatureBytes = ethKey.signPersonalMessageToUint8List(
  Uint8List.fromList(utf8.encode(canonicalJson)),
);
final signatureHex = '0x${bytesToHex(signatureBytes)}';
```
Tanda tangan ini menghasilkan bukti non-repudiasi (*proof of explicit consent*) yang tidak dapat disangkal oleh pihak manapun, kemudian dikirimkan ke Fastify middleware $\rightarrow$ RabbitMQ $\rightarrow$ tx-worker $\rightarrow$ smart contract `recordVerification(...)` pada Hyperledger Besu.

---

## 6. Hasil Pengujian Unit Testing & Kompilasi

### 6.1 Hasil Eksekusi `flutter test`
Seluruh 28 skenario uji pada Milestone 1, 2, 3, dan 4 berhasil dieksekusi dengan tingkat kelulusan **100%**:

```bash
$ cd /home/ganen/qrypta && /opt/flutter/bin/flutter test

00:00 +0: Milestone 3 - computeCheckDigit correctly computes weighted 7-3-1 modulo 10
00:00 +1: Milestone 3 - MrzParser correctly parses James Wilson TD3 passport lines and validates
00:00 +2: Milestone 3 - MrzParser detects tampered passport or invalid check digit
00:00 +3: Milestone 3 - MrzParser.detectAndParseFromText extracts TD3 lines from noisy OCR output
00:00 +4: Milestone 3 - demoJamesWilson factory produces verified credential data
00:00 +5: Milestone 3 - BtidCredentialModel correctly computes stay duration and status
00:00 +6: Milestone 3 - VerificationTransactionService records credential issued audit
00:00 +7: Milestone 4 - ATTRS defines all 19 official attributes and protects biometrics
00:00 +8: Milestone 4 - DEFAULT_POLICY strictly prohibits biometrics across all business categories
00:00 +9: Milestone 4 - Cafe policy strictly protects PII while allowing ZK age verification
00:00 +10: Milestone 4 - TEMPLATES defines 9 official government-accredited templates
00:00 +11: Milestone 4 - Dynamic QR token has valid 45s structure and binds BTID
00:00 +12: Milestone 4 - Demo merchants map accurately reflects ecosystem partners
00:00 +13: Milestone 4 - signAndSubmitConsent produces valid secp256k1 signature and canonical audit
00:00 +14: Milestone 4 - signAndSubmitConsent records rejection with 0 shared attributes
00:00 +15: Milestone 4 - revokeMerchantAccess successfully marks audit record as Revoked
00:00 +16: Milestone 4 - AuditTransactionModel accurately tracks states and counts
00:00 +17: Milestone 1 - parseAmountToBigInt correctly scales 150,000 IDRT to 18 decimals without overflow
00:00 +18: Milestone 1 - parseAmountToBigInt correctly handles fractional decimal amounts
00:00 +19: Milestone 1 - formatBigInt avoids IEEE 754 precision loss and formats Indonesian Rupiah
00:00 +20: Milestone 1 - formatBigInt correctly formats zero and decimals
00:00 +21: Milestone 1 - PIN is securely hashed using SHA-256
00:00 +22: Milestone 2 - BtidCredentialModel serializes and deserializes accurately
00:00 +23: Milestone 2 - ConsentRequestModel serializes correctly and checks expiration
00:00 +24: Milestone 2 - AuditTransactionModel tracks states correctly
00:00 +25: Milestone 2 - generateDynamicQrToken outputs valid 45-second ephemeral JSON token
00:00 +26: Milestone 2 - signAndSubmitConsent produces valid EVM signature and dispatches to Fastify
00:00 +27: Milestone 2 - revokeMerchantAccess successfully marks audit record as Revoked
00:00 +28: All tests passed!
```

### 6.2 Hasil Eksekusi `flutter analyze`
Analisis statis kode pada repositori berada dalam kondisi bersih sempurna tanpa error maupun warning:

```bash
$ cd /home/ganen/qrypta && /opt/flutter/bin/flutter analyze
Analyzing qrypta...                                             
No issues found! (ran in 1.6s)
```

---

## 7. Ringkasan File yang Dibuat & Dimodifikasi pada Milestone 4

| Path File | Kategori | Ringkasan Fungsi |
| :--- | :--- | :--- |
| `lib/src/features/verification/data/policy_matrix_constants.dart` | **Baru** | Definisi 18 atribut data + 1 biometric, 9 template resmi, matriks izin, 5 merchant demo |
| `lib/src/features/verification/logic/verification_controller.dart` | **Baru** | Riverpod Notifier untuk timer QR 45s, simulasi handshake, consent sign, revoke, audit |
| `lib/src/features/verification/presentation/screens/dynamic_qr_screen.dart` | **Baru** | Layar QR dinamis 45s (ScrQr) + blur saat expired + tombol refresh + trigger simulasi |
| `lib/src/features/verification/presentation/screens/consent_request_screen.dart` | **Baru** | Layar persetujuan atribut terikat tujuan (ScrConsent) + timer 3 menit + biometric sign |
| `lib/src/features/verification/presentation/screens/consent_shared_screen.dart` | **Baru** | Layar konfirmasi transaksi pertukaran data (ScrShared) + TxHash Besu copyable |
| `lib/src/features/verification/presentation/screens/privacy_audit_screen.dart` | **Baru** | Pusat audit privasi (ScrPrivacy) + 3 metrik statistik + unduh receipt + revoke + report |
| `test/milestone4_test.dart` | **Baru** | 10 skenario unit test matriks kebijakan, token 45s, tanda tangan EIP-191, dan pencabutan izin |
| `docs/architecture/DOKUMENTASI_TEKNIS_MILESTONE_4.md` | **Baru** | Dokumentasi teknis komprehensif Milestone 4 |
