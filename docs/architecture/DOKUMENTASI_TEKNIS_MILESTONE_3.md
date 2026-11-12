# DOKUMENTASI TEKNIS PENGERJAAN MILESTONE 3
## Onboarding Paspor (OCR MRZ) & Auto-Keypair Issuance

---

## 1. Ringkasan Eksekutif & Status Milestone 3

Milestone 3 mentransformasi alur orientasi (*onboarding*) repositori Qrypta dari dompet kripto konvensional (yang membebani turis awam dengan 12 kata *seed phrase*) menjadi **Fase A Mockup Turis App: Onboarding & Identity Proofing (`welcome` ➔ `mrz` ➔ `nfc` ➔ `auth` ➔ `liveness` ➔ `issued`)**.

Kunci privat kriptografi Web3 (`secp256k1`) kini dibangkitkan secara otomatis di *background isolate* tanpa memperlihatkan kompleksitas blockchain kepada wisatawan, lalu secara langsung diikatkan ke kredensial resmi **Bali Tourist ID (`BTID-2026-4471-0938`)** dan dicatat dalam audit trail Hyperledger Besu melalui middleware `ezsign-core`.

### Matriks Perbandingan Status Milestone 3

| Parameter | Sebelum Pengerjaan Milestone 3 | Pasca Pengerjaan Milestone 3 |
| :--- | :--- | :--- |
| **Alur Onboarding** | Seed Phrase 12 Kata Manual (`WalletSetupScreen`) | **Fase A Mockup Turis App (6 Langkah)** |
| **Ekstraksi MRZ Paspor** | Belum ada parser / scanner optik | **Real OCR + Validasi Checksum Modulo 10 TD3** |
| **Fallback Demo Evaluasi** | Tidak ada | **1-Click Demo Passport (James Wilson)** |
| **NFC & Passive Auth** | Belum terintegrasi | **Simulasi Sekuensial 6-Tahap & Visual PKI Chain** |
| **Liveness & Face Match** | Belum terintegrasi | **Viewfinder Melingkar + Skor Kecocokan 98.7%** |
| **Penerbitan Keypair** | Menampilkan 12 kata rahasia ke layar | **Auto-Generation di Background Isolate** |
| **Kredensial Digital BTID** | Belum ada visualisasi kartu | **`BtidCardWidget` Interaktif (Full & Mini)** |
| **Audit On-Chain Penerbitan** | Belum ada pencatatan ke Besu | **Audit `docType: BTID_ISSUED` via Fastify / Besu** |
| **Statistik `flutter analyze`** | Bersih (Milestone 2) | **0 Issues / Bersih Sempurna** |
| **Statistik `flutter test`** | 11 Tests Passed (Milestone 1 & 2) | **18 Tests Passed (100% Lulus)** |

---

## 2. Arsitektur State Machine & Alur Data Fase A

Alur Onboarding Fase A dirancang dengan filosofi **Verify Once, Zero Raw Data Stored, Decentralized Trust**:

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                               FASE A: ONBOARDING SIKLUS HIDUP                          │
└────────────────────────────────────────────────────────────────────────────────────────┘

 ┌───────────────┐     ┌───────────────┐     ┌───────────────┐     ┌───────────────┐
 │  ScrWelcome   │ ──► │    ScrMrz     │ ──► │    ScrNfc     │ ──► │    ScrAuth    │
 │ (Intro & Edu) │     │ (Camera OCR)  │     │  (APDU Read)  │     │  (PKI Chain)  │
 └───────────────┘     └───────┬───────┘     └───────────────┘     └───────┬───────┘
                               │                                           │
                        1-Click Demo                                5-Step Integrity
                        James Wilson                                 & Trust Verification
                               │                                           │
                               ▼                                           ▼
                       ┌───────────────┐                           ┌───────────────┐
                       │   ScrIssued   │ ◄──────────────────────── │  ScrLiveness  │
                       │  (IdCard +    │      1:1 Local Match      │ (Anti-Spoof   │
                       │   Auto-Key)   │        Score 98.7%        │  Score >85%)  │
                       └───────┬───────┘                           └───────────────┘
                               │
            ┌──────────────────┴──────────────────┐
            ▼                                     ▼
┌───────────────────────────────┐     ┌───────────────────────────────┐
│     LOCAL SECURE STORAGE      │     │      ezsign-core / BESU       │
│ • AES-256 Encrypted Keypair   │     │ • Event: 'Credential issued'  │
│ • SHA-256 Hashed PIN '123456' │     │ • Record: 'BTID-2026-4471-...'│
│ • BtidCredentialModel (Hive)  │     │ • Immutable On-Chain Audit    │
└───────────────────────────────┘     └───────────────────────────────┘
```

---

## 3. Bedah Mesin OCR & TD3 Checksum Engine (`mrz_parser.dart`)

### 3.1 Spesifikasi ICAO Doc 9303 Part 9 & 10 (Format TD3)
Format TD3 digunakan pada paspor standar internasional, terdiri dari **2 baris masing-masing tepat 44 karakter alfanumerik**:
- **Baris 1:**
  - Posisi 1–2: Kode Dokumen (`P<` untuk paspor umum).
  - Posisi 3–5: Negara Penerbit ICAO 3 huruf (contoh: `GBR`, `IDN`).
  - Posisi 6–44: Nama Pemegang (*Primary Identifier / Surname* `<<` *Secondary Identifier / Given Names*, dipadatkan dengan karakter `<` hingga 39 karakter).
- **Baris 2:**
  - Posisi 1–9: Nomor Paspor (9 karakter).
  - Posisi 10: *Check digit* nomor paspor (1 karakter).
  - Posisi 11–13: Kebangsaan pemegang (3 huruf).
  - Posisi 14–19: Tanggal lahir format `YYMMDD` (6 karakter).
  - Posisi 20: *Check digit* tanggal lahir (1 karakter).
  - Posisi 21: Jenis kelamin (`M`, `F`, atau `<`).
  - Posisi 22–27: Tanggal kedaluwarsa dokumen format `YYMMDD` (6 karakter).
  - Posisi 28: *Check digit* tanggal kedaluwarsa (1 karakter).
  - Posisi 29–42: Nomor pribadi / data opsional (14 karakter).
  - Posisi 43: *Check digit* nomor pribadi (1 karakter).
  - Posisi 44: *Composite check digit* (1 karakter, mencakup paspor, DOB, expiry, dan personal number).

### 3.2 Rumus Matematis Bobot 7-3-1 Modulo 10
Setiap karakter $C_i$ dikonversi menjadi bobot numerik:
- Angka `'0'` – `'9'` $\rightarrow$ $0 – 9$
- Huruf `'A'` – `'Z'` $\rightarrow$ $10 – 35$
- Karakter pengisi `'<'` $\rightarrow$ $0$

Algoritma mengalikan setiap posisi dengan bobot berulang $\mathbf{W} = [7, 3, 1]$:
$$\text{Sum} = \sum_{i=0}^{n-1} \text{Nilai}(C_i) \times W_{i \pmod 3}$$
$$\text{Check Digit} = \text{Sum} \pmod{10}$$

### 3.3 Pembuktian Matematis Paspor James Wilson
Pita MRZ resmi James Wilson:
```
Line 1: P<GBRWILSON<<JAMES<<<<<<<<<<<<<<<<<<<<<<<<<<
Line 2: 7249187895GBR8805120M3203189<<<<<<<<<<<<<<02
```

1. **Nomor Paspor (`724918789`):**
   $$\text{Sum} = 7(7) + 2(3) + 4(1) + 9(7) + 1(3) + 8(1) + 7(7) + 8(3) + 9(1)$$
   $$\text{Sum} = 49 + 6 + 4 + 63 + 3 + 8 + 49 + 24 + 9 = 215$$
   $$\text{Check Digit} = 215 \pmod{10} = \mathbf{5} \quad \text{(Sesuai Posisi 10)}$$

2. **Tanggal Lahir (`880512` - 12 Mei 1988):**
   $$\text{Sum} = 8(7) + 8(3) + 0(1) + 5(7) + 1(3) + 2(1) = 56 + 24 + 0 + 35 + 3 + 2 = 120$$
   $$\text{Check Digit} = 120 \pmod{10} = \mathbf{0} \quad \text{(Sesuai Posisi 20)}$$

3. **Tanggal Kedaluwarsa (`320318` - 18 Maret 2032):**
   $$\text{Sum} = 3(7) + 2(3) + 0(1) + 3(7) + 1(3) + 8(1) = 21 + 6 + 0 + 21 + 3 + 8 = 59$$
   $$\text{Check Digit} = 59 \pmod{10} = \mathbf{9} \quad \text{(Sesuai Posisi 28)}$$

4. **Composite Check Digit:**
   Menggabungkan Posisi 1–10 + 14–20 + 22–43:
   $$\text{Payload} = \texttt{724918789588051203203189<<<<<<<<<<<<<<0}$$
   $$\text{Sum} = 282 \implies \text{Check Digit} = 282 \pmod{10} = \mathbf{2} \quad \text{(Sesuai Posisi 44)}$$

### 3.4 Fitur Tangguh & Fallback Demo
- **`MrzParser.detectAndParseFromText(String ocrText)`**: Secara otomatis memindai teks mentah multi-baris dari kamera, menyaring noise teks non-MRZ, dan mengekstraksi pasangan baris TD3 yang valid.
- **`MrzParseResult.demoJamesWilson()`**: Menginjeksi data paspor James Wilson dalam 1 klik instan saat presentasi atau pengujian dalam kondisi ruangan minim cahaya.

---

## 4. Implementasi Komponen Presentasi Fase A

### 4.1 `welcome_screen.dart` (ScrWelcome)
- **File:** `lib/src/features/authentication/presentation/screens/welcome_screen.dart`
- **Tampilan UI/UX:**
  - Header badge: `BALI TOURIST TRUST ECOSYSTEM`.
  - Judul Mockup: *"Verify once. Share only what is required. Explore Bali."*
  - 3 Kartu Edukasi Keamanan:
    1. *Verify once, stay secure:* Paspor fisik tetap di brankas hotel.
    2. *Zero physical photocopies:* Merchant hanya melihat atribut terikat tujuan.
    3. *Tamper-evident audit trail:* Setiap akses dicatat di Hyperledger Besu.
  - Tombol Primer: **"Set up my Tourist ID"** $\rightarrow$ membuka `MrzScannerScreen`.
  - Tombol Cepat: **"Fast Demo Mode (James Wilson)"** $\rightarrow$ melewati pemindaian fisik untuk pengujian cepat.

### 4.2 `mrz_scanner_screen.dart` (ScrMrz - Real OCR & Viewfinder)
- **File:** `lib/src/features/authentication/presentation/screens/mrz_scanner_screen.dart`
- **Fitur Teknis:**
  - Viewfinder kamera optik berbasis `MobileScanner` dengan rasio paspor TD3 (3.2 : 1).
  - Garis laser animasi berulang (*laser sweep animation*) warna toska khas Bali Tourist ID.
  - Tombol pojok atas & bawah: **"Use Demo Passport (James Wilson)"**.
  - Modal BottomSheet otomatis saat MRZ terdeteksi: menampilkan Nama Lengkap, Nomor Paspor Tersamar (`••••••789`), Kebangsaan (`GBR`), Tanggal Lahir, Tanggal Kedaluwarsa, dan pita string MRZ monospaced.
  - Tombol **"Continue to chip read"** mentransisikan data ke stepper verifikasi berikutnya.

### 4.3 `passport_verification_flow_screen.dart` (ScrNfc, ScrAuth, ScrLiveness)
- **File:** `lib/src/features/authentication/presentation/screens/passport_verification_flow_screen.dart`
- Menggabungkan tiga layar verifikasi sekuensial dalam satu `StatefulWidget` berbasis *stepper* otomatis:
  1. **Step 1 — NFC ePassport Chip Read (`ScrNfc`):**
     - Animasi radar konsentris pulsa ungu (*pulsing concentric rings*) berpusat pada ikon NFC.
     - Progress bar berjalan halus dari 0% hingga 100%.
     - 6 tahapan sekuensial ICAO (@ 650 ms):
       - *Connecting to passport contactless antenna...*
       - *Establishing secure channel (BAC/PACE)...*
       - *Reading passport data (DG1: MRZ)...*
       - *Reading passport photograph (DG2: Biometrics)...*
       - *Reading signed security data (SOD)...*
       - *Chip read successfully!*
     - Transisi otomatis ke Step 2 begitu selesai.
  2. **Step 2 — Passive Authentication (`ScrAuth`):**
     - Rantai sertifikat PKI 4 simpul visual bertaut:
       `ePassport chip` $\rightarrow$ `Signed passport data` $\rightarrow$ `Document signer certificate` $\rightarrow$ `Country trust authority`.
     - Tombol **"Security details"**: membuka Modal BottomSheet menampilkan algoritma enkripsi (ECDSA BrainpoolP256r1, SHA-256), identitas penandatangan (HMPO CSCA), dan status keaslian data (*GENUINE / VALIDATED*).
     - Tombol **"Continue to face check"** melangkah ke Step 3.
  3. **Step 3 — Facial Liveness & 1:1 Match (`ScrLiveness`):**
     - Viewfinder melingkar dengan cincin radar bercahaya (*glowing spinning ring*).
     - Urutan verifikasi 4 tahap: *Face detected*, *Liveness confirmed (Anti-spoofing)*, *Comparing with chip photo (DG2)*, *Identity confirmed!*
     - Kartu Skor Kecocokan Biometrik:
       - **Match Score: 98.7%**
       - Ambang Batas Kelulusan (*Pass Threshold*): **85.0%**
       - Status: **PASSED**
     - Garansi Privasi: *"Zero video or raw biometrics sent to cloud. 1:1 local match."*
     - Tombol **"Issue my Tourist ID"** membuka layar penerbitan kredensial.

### 4.4 `btid_issued_screen.dart` (ScrIssued - Auto-Keypair & On-Chain Anchoring)
- **File:** `lib/src/features/authentication/presentation/screens/btid_issued_screen.dart`
- **Mekanisme Otomatis:**
  1. Memanggil `authRepo.generateMnemonic()` dan `getPrivateKeyFromMnemonic()` di *isolate* terpisah tanpa menampilkan 12 kata rahasia ke layar.
  2. Mengikat alamat Ethereum (`getChecksumAddressUseCase`) ke kredensial identitas.
  3. Mengeset PIN awal default (`'123456'`) sehingga `authStateProvider` langsung bernilai `true` (pengguna tidak perlu setup manual; PIN dapat diubah nanti di Profile).
  4. Mengonstruksi objek `BtidCredentialModel`:
     - `btidNumber`: `BTID-2026-4471-0938`
     - `fullName`: `James Wilson` (dari MRZ)
     - `nationality`: `GBR`
     - `passportMasked`: `••••••789`
     - `visaType`: `e-VOA B1`
     - `stayExpiry`: 30 hari dari tanggal penerbitan
     - `levyStatus`: `'unpaid'`
     - `walletAddress`: Alamat EVM yang baru dibangkitkan
  5. Menyimpan kredensial ke persistent storage lokal (Hive box `btid_credential_box`).
  6. Mengirimkan catatan audit penerbitan kredensial (`recordCredentialIssuedAudit`) ke middleware Fastify / Besu.
  7. Menampilkan kartu identitas visual `BtidCardWidget` dan 3 klausul peringatan resmi:
     - *Not a physical passport replacement:* Simpan paspor asli di brankas hotel.
     - *Not a commercial bank account:* Saldo token IDRT adalah voucher wisata.
     - *Not a driving permit:* Sewa kendaraan memerlukan SIM internasional yang sah.
  8. Tombol **"Continue to Dashboard"** langsung membawa wisatawan ke `HomeScreen`.

---

## 5. Komponen Visual Kartu BTID (`BtidCardWidget`)

File: `lib/src/features/verification/presentation/widgets/btid_card_widget.dart`

Widget kartu identitas digital dirancang reusable dengan 2 mode tampilan:
1. **Full Card Mode:**
   - Gradien warna gelap toska/navy/indigo (`#0F3B37` $\rightarrow$ `#132A38` $\rightarrow$ `#1C1A2E`).
   - Watermark lambang perisai/Garuda transparan di latar belakang.
   - Header: Lambang resmi Pemerintah Provinsi Bali, judul "BALI TOURIST ID", dan badge "ACTIVE".
   - Foto avatar, Nama Lengkap, Nomor Paspor Tersamar (`••••••789`), Kebangsaan (`GBR`), Jenis Visa, dan sisa izin tinggal.
   - Kotak monospaced berisi nomor BTID (`BTID-2026-4471-0938`) dan alamat wallet Web3 (`0x71C...B29`).
   - 3 Security Badges: *Identity Verified* (toska), *Passport Authenticated* (indigo), dan *Levy Pending/Paid* (amber/hijau).
2. **Mini Card Mode:**
   - Desain ringkas satu baris untuk disematkan di dashboard utama (`HomeScreen`), menampilkan avatar mini, nama, nomor BTID, dan status retribusi.

---

## 6. Integrasi State Management & Audit Ekosistem

### 6.1 `btid_provider.dart`
- **File:** `lib/src/features/authentication/presentation/providers/btid_provider.dart`
- Mengelola state `BtidCredentialModel?` menggunakan Riverpod `StateNotifier`.
- Menyediakan metode persistensi:
  - `saveCredential(BtidCredentialModel credential)`: Menyimpan ke Hive box `btid_credential_box` dengan fallback SharedPreferences.
  - `updateLevyStatus(String status, {String? receiptRef})`: Memperbarui status retribusi menjadi `paid` dan mencatat nomor kuitansi `LVY-XXXXX`.
  - `loadCredential()`: Memuat kredensial saat aplikasi dinyalakan.

### 6.2 Alur Root Router (`auth_wrapper.dart`)
- **File:** `lib/src/features/authentication/presentation/screens/auth_wrapper.dart`
- Diperbarui agar ketika aplikasi mendeteksi pengguna baru (belum memiliki wallet dan PIN), navigasi langsung diarahkan ke `WelcomeScreen()` (Fase A) alih-alih `WalletSetupScreen()` lama.

### 6.3 Audit Trail Onboarding (`VerificationTransactionService`)
- Metode baru ditambahkan pada `verification_transaction_service.dart`:
  ```dart
  Future<AuditTransactionModel> recordCredentialIssuedAudit({
    required String btid,
    required String fullName,
    required String walletAddress,
  })
  ```
- Menghasilkan referensi audit unik `AUD-XXXXXX` dan payload audit `docType: BTID_ISSUED` dengan metadata:
  - *Actor:* System (Bali Tourism Authority)
  - *Organisation:* Bali Tourism Authority & Immigration
  - *Action:* Credential issued
  - *Purpose:* Identity onboarding
  - *Result:* Issued / Approved
- Dikirimkan ke Fastify endpoint `/api/v1/verify-identity` untuk diteruskan ke RabbitMQ dan dicatat di Hyperledger Besu.

---

## 7. Hasil Pengujian Unit Testing & Kompilasi

### 7.1 Hasil Eksekusi `flutter test`
Seluruh 18 skenario uji pada Milestone 1, 2, dan 3 berhasil dieksekusi dengan tingkat kelulusan **100%**:

```bash
$ cd /home/ganen/qrypta && /opt/flutter/bin/flutter test

00:00 +0: loading /home/ganen/qrypta/test/milestone3_test.dart
00:00 +1: Milestone 3 - computeCheckDigit correctly computes weighted 7-3-1 modulo 10
00:00 +2: Milestone 3 - MrzParser correctly parses James Wilson TD3 passport lines and validates
00:00 +3: Milestone 3 - MrzParser detects tampered passport or invalid check digit
00:00 +4: Milestone 3 - MrzParser.detectAndParseFromText extracts TD3 lines from noisy OCR output
00:00 +5: Milestone 3 - demoJamesWilson factory produces verified credential data
00:00 +6: Milestone 3 - BtidCredentialModel correctly computes stay duration and status
00:00 +7: Milestone 3 - VerificationTransactionService records credential issued audit
00:00 +8: Milestone 1 - parseAmountToBigInt correctly scales 150,000 IDRT to 18 decimals without overflow
00:00 +9: Milestone 1 - parseAmountToBigInt correctly handles fractional decimal amounts
00:00 +10: Milestone 1 - formatBigInt avoids IEEE 754 precision loss and formats Indonesian Rupiah
00:00 +11: Milestone 1 - formatBigInt correctly formats zero and decimals
00:00 +12: Milestone 1 - PIN is securely hashed using SHA-256
00:00 +13: Milestone 2 - BtidCredentialModel serializes and deserializes accurately
00:00 +14: Milestone 2 - ConsentRequestModel serializes correctly and checks expiration
00:00 +15: Milestone 2 - AuditTransactionModel tracks states correctly
00:00 +16: Milestone 2 - generateDynamicQrToken outputs valid 45-second ephemeral JSON token
00:00 +17: Milestone 2 - signAndSubmitConsent produces valid EVM signature and dispatches to Fastify
00:00 +18: Milestone 2 - revokeMerchantAccess successfully marks audit record as Revoked
00:00 +18: All tests passed!
```

### 7.2 Hasil Eksekusi `flutter analyze`
Analisis statis kode pada repositori berada dalam kondisi bersih tanpa peringatan:

```bash
$ cd /home/ganen/qrypta && /opt/flutter/bin/flutter analyze
Analyzing qrypta...                                             
No issues found! (ran in 1.6s)
```

---

## 8. Ringkasan File yang Diubah & Dibuat pada Milestone 3

| Path File | Kategori | Ringkasan Fungsi |
| :--- | :--- | :--- |
| `lib/src/core/utils/mrz_parser.dart` | **Baru** | Mesin parser ICAO Doc 9303 TD3 & validasi modulo 10 weighted 7-3-1 |
| `lib/src/features/verification/presentation/widgets/btid_card_widget.dart` | **Baru** | Widget kartu digital resmi BTID (Full Card & Mini Card) |
| `lib/src/features/authentication/presentation/providers/btid_provider.dart` | **Baru** | State notifier Riverpod & persistensi kredensial BTID lokal (Hive) |
| `lib/src/features/authentication/presentation/screens/welcome_screen.dart` | **Refactor** | Layar edukasi orientasi turis (ScrWelcome) sesuai mockup |
| `lib/src/features/authentication/presentation/screens/mrz_scanner_screen.dart` | **Baru** | Pemindai OCR kamera realtime + laser animation + 1-click fallback demo |
| `lib/src/features/authentication/presentation/screens/passport_verification_flow_screen.dart` | **Baru** | Stepper sekuensial ScrNfc (6-step), ScrAuth (PKI chain), ScrLiveness (98.7%) |
| `lib/src/features/authentication/presentation/screens/btid_issued_screen.dart` | **Baru** | Layar auto-keypair generation, binding kredensial, & audit Besu |
| `lib/src/features/authentication/presentation/screens/auth_wrapper.dart` | **Refactor** | Pengalihan user baru ke alur `WelcomeScreen` |
| `lib/src/core/services/blockchain/verification_transaction_service.dart` | **Pembaruan** | Penambahan fungsi `recordCredentialIssuedAudit` |
| `test/milestone3_test.dart` | **Baru** | Unit test checksum TD3, ekstraksi OCR, persistensi BTID, & audit Besu |
| `docs/architecture/DOKUMENTASI_TEKNIS_MILESTONE_3.md` | **Baru** | Dokumentasi teknis komprehensif Milestone 3 |
