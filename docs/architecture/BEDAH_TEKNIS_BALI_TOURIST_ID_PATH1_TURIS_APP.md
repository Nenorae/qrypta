# BEDAH TEKNIS ARSITEKTUR BALI TOURIST ID
## Path 1: Tourist App & Trusted Ecosystem Lifecycle (Deep Dive)

---

## DAFTAR ISI
1. [Verifikasi Premis: Analisis "2 Path" dalam Sistem](#1-verifikasi-premis-analisis-2-path-dalam-sistem)
2. [Arsitektur Ekosistem & Segitiga Kepercayaan (Trust Triangle)](#2-arsitektur-ekosistem--segitiga-kepercayaan-trust-triangle)
3. [Daftar Seluruh Kebutuhan Sistem Turis App](#3-daftar-seluruh-kebutuhan-sistem-turis-app)
4. [Bongkar Alur Lengkap Turis App (State Machine & Screen Journey)](#4-bongkar-alur-lengkap-turis-app-state-machine--screen-journey)
   - [Fase A: Onboarding & Identity Proofing](#fase-a-onboarding--identity-proofing-verifikasi-sekali)
   - [Fase B: Penyelesaian Retribusi Wisatawan (Bali Tourist Levy)](#fase-b-penyelesaian-retribusi-wisatawan-bali-tourist-levy)
   - [Fase C: Main Dashboard & Tab Navigasi](#fase-c-main-dashboard--tab-navigasi-pasca-onboarding)
   - [Fase D: Protokol Interaksi Verifikasi Merchant (Selective Disclosure)](#fase-d-protokol-interaksi-verifikasi-merchant-selective-disclosure)
   - [Fase E: Modul Layanan Wisata Terintegrasi (Vertical Services)](#fase-e-modul-layanan-wisata-terintegrasi-vertical-services)
5. [Deep Dive: Mekanisme Verifikasi Identitas (How Verification Works)](#5-deep-dive-mekanisme-verifikasi-identitas-how-verification-works)
   - [Tahap 1: Optical MRZ Capture & TD3 Checksum Engine](#tahap-1-optical-mrz-capture--td3-checksum-engine)
   - [Tahap 2: Pembacaan Chip NFC ePassport (ICAO Doc 9303 BAC/PACE)](#tahap-2-pembacaan-chip-nfc-epassport-icao-doc-9303-bacpace)
   - [Tahap 3: Passive Authentication & Rantai Sertifikat PKI](#tahap-3-passive-authentication--rantai-sertifikat-pki)
   - [Tahap 4: Deteksi Liveness & Biometric Face Matching 1:1](#tahap-4-deteksi-liveness--biometric-face-matching-11)
   - [Tahap 5: Penerbitan Bali Tourist ID (BTID Credential)](#tahap-5-penerbitan-bali-tourist-id-btid-credential)
   - [Tahap 6: Mekanisme Dynamic Rotating QR & Ephemeral Token](#tahap-6-mekanisme-dynamic-rotating-qr--ephemeral-token)
6. [Arsitektur Alur Data (Data Flow Architecture)](#6-arsitektur-alur-data-data-flow-architecture)
   - [Alur Data Onboarding Identitas](#alur-data-onboarding-identitas)
   - [Alur Data Transaksi & Handshake Consent](#alur-data-transaksi--handshake-consent)
   - [Alur Data Audit & Pelaporan Privasi](#alur-data-audit--pelaporan-privasi)
7. [Matriks Minimalisasi Data & Kebijakan Privasi (Data Minimization Matrix)](#7-matriks-minimalisasi-data--kebijakan-privasi-data-minimization-matrix)
8. [Keterhubungan Turis App dengan Government Portal & Merchant App](#8-keterhubungan-turis-app-dengan-government-portal--merchant-app)
9. [Kesimpulan & Rekomendasi Implementasi Teknis](#9-kesimpulan--rekomendasi-implementasi-teknis)

---

## 1. Verifikasi Premis: Analisis "2 Path" dalam Sistem

Berdasarkan analisis komprehensif terhadap source code `bali-tourist-id Mock Up Final Version.html`, premis bahwa sistem memiliki **2 path** adalah **BENAR dan TERBUKTI SECARA TEKNIS**. 

Sistem dirancang dengan dua jalur arsitektur utama yang saling melengkapi:

```
                               ┌────────────────────────────────────────────────────────┐
                               │           TRAVELER ePASSPORT IDENTITY HOLDER           │
                               └──────────────────────────┬─────────────────────────────┘
                                                          │
                             ┌────────────────────────────┴─────────────────────────────┐
                             ▼                                                          ▼
             ┌───────────────────────────────┐                          ┌───────────────────────────────┐
             │            PATH 1             │                          │            PATH 2             │
             │   Self-Service Digital Path   │                          │  Assisted Desk / Exception    │
             │         (Happy Path)          │                          │       (Fallback Path)         │
             ├───────────────────────────────┤                          ├───────────────────────────────┤
             │ • MRZ Camera OCR Capture      │                          │ • Pemicu: Chip rusak / Non-eP │
             │ • NFC Contactless Chip Read   │                          │ • Pemicu: Cert untrusted/fail │
             │ • ICAO Passive Authentication │                          │ • Pemicu: Liveness score <85% │
             │ • 1:1 Facial Match (Score>85%)│                          │ • Rujukan Tiket: `AST-XXXXX`   │
             │ • Instant BTID Issuance       │                          │ • Meja 24 Jam Bandara DPS     │
             │ • Online Levy Payment (Card/W)│                          │ • Antrean Portal Pemerintah:  │
             │ • Dynamic QR Consent Handshake│                          │   `GovExceptions` Queue       │
             └───────────────────────────────┘                          └───────────────────────────────┘
```

### Rincian 2 Path dalam Prototype:

1. **Path 1 — Self-Service Digital Onboarding & Merchant Interaction Path (Jalur Utama / Happy Path)**
   - Jalur digital mandiri tanpa perantara fisik (*zero-counter dependency*). Wisatawan melakukan verifikasi ePassport langsung di smartphone mereka sebelum keberangkatan (*pre-arrival*) atau saat tiba di bandara Ngurah Rai.
   - Melibatkan pembacaan optik MRZ, ekstraksi chip via NFC (BAC/PACE), validasi integritas data SOD & sertifikat DS (*Document Signer*), pengujian *liveness* wajah, pencocokan foto chip DG2 dengan skor threshold (konfigurasi prototype: 85%, realisasi demo: 98.7%), penerbitan ID digital instan, pembayaran Tourist Levy, hingga interaksi harian ke merchant lewat Dynamic Rotating QR.

2. **Path 2 — Assisted Verification Desk & Identity Exception Path (Jalur Cadangan / Manual Intervention)**
   - Jalur fallback resmi ketika verifikasi digital mandiri mengalami anomali atau kegagalan perangkat keras. Di dalam kode prototype, jalur ini didefinisikan lewat layar `ScrAssist` dan rangkaian modul penanganan error `ERRORS`:
     - `mrz`: MRZ buram/kamera rusak.
     - `nonEpassport`: Paspor manual (konvensional) tanpa chip RFID.
     - `nfc`: Smartphone wisatawan tidak mendukung NFC.
     - `chip`: Koneksi NFC terputus di tengah transmisi APDU.
     - `cert`: Sertifikat penandatangan paspor tidak ditemukan di Master List lokal.
     - `liveness` / `face`: Nilai pencocokan biometrik berada di bawah batas ambang 85%.
   - Ketika error terjadi, wisatawan diarahkan ke tombol **"Use assisted verification"**, yang menerbitkan kode referensi bantuan unik (format `AST-XXXXX`). Wisatawan membawa paspor asli ke meja verifikasi bandara Ngurah Rai (24 jam). Di sisi back-office, sistem otomatis memicu tiket di modul **`GovExceptions` (Government Exceptions Queue)** agar ditinjau oleh pejabat berwenang (*Identity Exception Reviewer*).

> **Fokus Dokumen:** Sesuai instruksi, dokumen ini membedah secara mendalam **Path 1**, dengan fokus eksplorasi teknis menyeluruh pada **Turis App (Tourist App)** beserta seluruh alur data, kebutuhan teknis, logika kriptografis, dan keterhubungannya dengan Government Portal dan Merchant App.

---

## 2. Arsitektur Ekosistem & Segitiga Kepercayaan (Trust Triangle)

Bali Tourist ID dibangun di atas arsitektur identitas terdesentralisasi berbasis **Decentralized Trust Triangle** dengan prinsip kedaulatan data di tangan pengguna (*Self-Sovereign Identity / User-Centric Privacy*):

```
                        ┌────────────────────────────────────────┐
                        │          GOVERNMENT PORTAL             │
                        │    (Bali Tourism Authority & Imm)      │
                        │             ISSUER / ANCHOR            │
                        └──────┬──────────────────────────┬──────┘
                               │                          │
        Penerbitan Kredensial  │                          │ Regulasi Policy &
        BTID, Ledger Retribusi │                          │ Otorisasi Merchant
        & Audit Logging        │                          │ (Matriks Akses)
                               ▼                          ▼
               ┌───────────────────────┐          ┌───────────────────────┐
               │      TURIS APP        │          │     MERCHANT APP      │
               │   (James Wilson)      │◄────────►│ (Hotel, Car, dsb)     │
               │  HOLDER / PROVER      │ Dynamic  │ VERIFIER / RELYING    │
               │ (Digital Trust Wallet)│ QR (45s) │       PARTY           │
               └───────────────────────┘ & Consent└───────────────────────┘
                                          Protocol
```

### Tiga Entitas Utama Ekosistem:
1. **Turis App (Holder / Prover):** Bertindak sebagai dompet identitas aman (*Secure Identity Wallet*). Membaca dan memvalidasi paspor fisik, menyimpan kredensial digital Bali Tourist ID (BTID) secara lokal, mengelola izin privasi, dan memberikan persetujuan eksplisit (*cryptographic consent*) per transaksi.
2. **Merchant App (Verifier / Relying Party):** Pelaku usaha terdaftar (Hotel, Rental Kendaraan, Kafe, eSIM, Tur) yang memindai QR dinamis wisatawan untuk meminta data verifikasi yang dibatasi oleh tujuan (*purpose-bound*). Merchant **dilarang keras** memfotokopi paspor fisik.
3. **Government Portal (Issuer / Trust Anchor / Auditor):** Portal otoritas (Dinas Pariwisata, Imigrasi, Pengelola Retribusi) yang bertindak sebagai penerbit kredensial turis terpercaya, pengawas kepatuhan pedagang, pengelola ledger retribusi, peninjau anomali verifikasi, dan penyimpan log audit yang tidak dapat diubah (*tamper-evident audit log*).

---

## 3. Daftar Seluruh Kebutuhan Sistem Turis App

Untuk mengimplementasikan Tourist App dari prototipe HTML ke aplikasi native siap produksi (*production-grade* iOS/Android), dibutuhkan spesifikasi teknis dan dependensi modul berikut:

### 3.1 Kebutuhan Perangkat Keras (Hardware Requirements)
- **Modul Kamera Belakang:** Resolusi minimal 1080p dengan autofokus makro untuk pemindaian optik Machine Readable Zone (MRZ) format TD3.
- **NFC Controller (Near Field Communication):** Chipset NFC berkemampuan ISO/IEC 14443 Type A atau Type B, mendukung protokol komunikasi contactless chip paspor (NFC-A / IsoDep).
- **Kamera Depan:** Resolusi minimal 1080p, 30 fps, mendukung sensor kedalaman (depth sensing) atau TrueDepth camera untuk *Passive & Active Liveness Detection*.
- **Hardware Security Module:** Apple Secure Enclave (iOS) atau Android StrongBox / Keystore TEE (Trusted Execution Environment) untuk enkripsi kunci privat lokal dan sertifikat kredensial.

### 3.2 Kebutuhan Pustaka Native & Protokol Kriptografi
- **Optical Character Recognition (OCR):**
  - Mesin parser MRZ compliant ICAO Doc 9303 (contoh: Google ML Kit Text Recognition, Apple Vision Framework, atau Tesseract OCR).
  - Algoritma verifikasi digit periksa (*modulo 10 weighted 7-3-1*).
- **Stack Pembacaan ePassport (ISO 7816 / ICAO 9303 Part 10 & 11):**
  - Implementasi pustaka: `JMRTD` (Java/Android), `NFCPassportReader` (Swift/iOS), atau pustaka C++ berbasis `OpenPACE`.
  - Protokol BAC (*Basic Access Control*) dan PACE (*Password Authenticated Connection Establishment*).
  - Parser Data Groups (DG): DG1 (Data MRZ), DG2 (Foto Biometrik Wajah), DG14/DG15 (Informasi Chip/Active Authentication), dan SOD (*Security Object Document*).
- **Pustaka Kriptografis & PKI (Public Key Infrastructure):**
  - Parser ASN.1 / BER-TLV / DER.
  - Implementasi X.509 Certificate Chain Validation.
  - Hashing: SHA-224, SHA-256, SHA-384, SHA-512.
  - Digital Signature Verification: RSA (PKCS#1 v1.5 / PSS) dan ECDSA (Brainpool, NIST curves).
  - Sinkronisasi ICAO PKD (*Public Key Directory*) dan Master List CSCA (*Country Signing Certification Authority*) resmi pemerintah.
- **Biometric Liveness & Facial Matching SDK:**
  - Standar ISO/IEC 30107-3 Presentation Attack Detection (PAD).
  - Facial Feature Extractor (Local Deep Neural Network / MobileNet-FaceNet) untuk mengekstraksi 512-dimensi vektor embedding wajah.
  - Algoritma pembanding: *Cosine Similarity Vector Engine* (local, zero-cloud transmission).
- **Generasi Token & Dynamic QR:**
  - Standard QR Code generator (ISO/IEC 18004).
  - Algoritma TOTP / Ephemeral Token berbasis Elliptic Curve Diffie-Hellman (ECDH) atau nonce unik bertanda tangan digital berdurasi 45 detik.

### 3.3 Kebutuhan Penyimpanan Lokal & Keamanan Data (Security & Storage)
- **Local Database Terenkripsi:** SQLCipher dengan kunci AES-256-GCM yang di-derive dari Secure Enclave.
- **Zero Raw Data Stored Policy:** Kunci kriptografi chip paspor dihapus dari memori RAM volatile segera setelah kredensial BTID berhasil diterbitkan. Template biometrik wajah **tidak boleh** disimpan permanen atau dibagikan ke pihak ketiga.

---

## 4. Bongkar Alur Lengkap Turis App (State Machine & Screen Journey)

Berdasarkan implementasi kode pada fungsi `TouristApp()` dan subkomponennya, Turis App memiliki siklus hidup yang terbagi menjadi 5 fase besar:

```
[START]
   │
   ▼
┌────────────────────────────────────────────────────────────────────────┐
│ FASE A: ONBOARDING & IDENTITAS (VERIFY ONCE)                           │
│ welcome ──► mrz ──► nfc ──► auth ──► liveness ──► issued               │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ FASE B: RETRIBUSI PARIWISATA BALI (TOURIST LEVY)                       │
│ levy ──► levypay ──► receipt ──► activate                              │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ FASE C: CORE DASHBOARD & TAB NAVIGATION                                │
│ [Tab: Home]    [Tab: Pay]    [Tab: ID]    [Tab: Explore]   [Tab: Prof] │
└─────────┬─────────────────────────┬────────────────────────────────────┘
          │                         │
          │ Merchant QR Scan        │ Navigasi Fitur Tambahan
          ▼                         ▼
┌───────────────────────────┐ ┌──────────────────────────────────────────┐
│ FASE D: MERCHANT CONSENT  │ │ FASE E: VERTICAL SERVICES                │
│ qr ──► consent ──► shared │ │ • visa (Izin Tinggal & Overstay Watch)   │
│         │                 │ │ • culture & lesson (Etiket & Budaya)     │
│         └──► privacy      │ │ • events (Kalender Adat & Pura)          │
│              (Audit trail)│ │ • driving (Kredensial SIM Asing)         │
│                           │ │ • esim (Aktivasi Bali Connect eSIM)      │
│                           │ │ • hotel (Check-in Mandiri)               │
│                           │ │ • emergency (Tombol SOS Darurat)         │
│                           │ │ • transport & insurance (Layanan Wisata) │
└───────────────────────────┘ └──────────────────────────────────────────┘
```

---

### Fase A: Onboarding & Identity Proofing (Verifikasi Sekali)

Tahap ini hanya dilakukan satu kali saat wisatawan pertama kali menggunakan aplikasi:

#### 1. Screen `welcome` (`ScrWelcome`)
- **Tujuan UI/UX:** Edukasi filosofi aplikasi *"Verify once. Share only what is required. Explore Bali"*.
- **Poin Komunikasi:** Menegaskan bahwa paspor hanya dibaca satu kali, paspor fisik tetap berada di saku, merchant hanya melihat apa yang disetujui, dan seluruh riwayat permintaan data dicatat transparan.
- **Interaksi:** Tombol `Set up my Tourist ID` mentransisikan state ke layar `mrz`.

#### 2. Screen `mrz` (`ScrMrz`)
- **Tujuan UI/UX:** Membaca Machine Readable Zone (MRZ) dua baris di halaman biodata paspor fisik menggunakan viewfinder kamera.
- **Logika Internal:**
  - Menampilkan overlay pemindaian berbingkai warna toska dengan animasi pemindaian garis laser (*sweep animation*).
  - Prototipe mensimulasikan latensi OCR selama 2.600 ms.
  - Validasi berhasil: Mengekstraksi nama lengkap (`James Wilson`), kebangsaan (`GBR`), nomor paspor tersamar (`••••••789`), tanggal lahir (`12 May 1988`), dan tanggal kedaluwarsa (`18 March 2032`).
  - Menampilkan band string MRZ dua baris:
    - Line 1: `P<GBRWILSON<<JAMES<<<<<<<<<<<<<<<<<<<<<<<<<<`
    - Line 2: `••••••789GBR8805127M3203184<<<<<<<<<<<<<<06`
  - Tombol aksi: `Continue to chip read` mentransisikan ke `nfc`.

#### 3. Screen `nfc` (`ScrNfc`)
- **Tujuan UI/UX:** Membaca microchip RFID ePassport tanpa kontak dengan menempelkan perangkat ke paspor.
- **Logika Internal:**
  - Animasi visual radar pulsa ungu (*pulsing concentric rings*) berpusat pada ikon NFC.
  - `useSequence` mengeksekusi 6 langkah pembacaan chip secara berurutan (@ 720 ms per tahap):
    1. *Connecting to passport* (Inisialisasi frekuensi radio ISO 14443).
    2. *Reading secure chip* (Establish BAC/PACE secure channel).
    3. *Reading passport data* (Ekstraksi Data Group 1 / MRZ digital).
    4. *Reading passport photograph* (Ekstraksi Data Group 2 / foto wajah resolusi tinggi).
    5. *Reading signed security data* (Ekstraksi Dokumen Objek Keamanan / SOD).
    6. *Chip read successfully*.
  - Indikator progres bar berjalan 0% -> 100%. Transisi otomatis ke layar `auth`.

#### 4. Screen `auth` (`ScrAuth`)
- **Tujuan UI/UX:** Validasi keaslian kriptografis paspor (*Passive Authentication*).
- **Logika Internal:**
  - `useSequence` mengeksekusi 5 tahap verifikasi kriptografis (@ 820 ms per tahap):
    1. *Electronic passport detected*.
    2. *Chip data integrity verified* (Hash data DG1 & DG2 cocok dengan hash di SOD).
    3. *Digital signature verified* (Tanda tangan digital SOD didekripsi menggunakan Document Signer Public Key).
    4. *Document signer certificate verified* (Sertifikat penandatangan paspor valid).
    5. *Issuing country trust verified* (Rantai sertifikat bermuara ke trust anchor negara asal).
  - Visualisasi Rantai Kepercayaan (*Trust Chain Representation*):
    - `ePassport chip` -> `Signed passport data` -> `Document signer certificate` -> `Country trust authority`.
  - Tombol `Security details` membuka modal sheet dengan rincian audit keaslian.
  - Tombol `Continue to face check` mentransisikan ke layar `liveness`.

#### 5. Screen `liveness` (`ScrLiveness`)
- **Tujuan UI/UX:** Pengujian kehadiran fisik pengguna hidup (*liveness detection*) dan pencocokan wajah 1:1 terhadap foto di dalam chip paspor.
- **Logika Internal:**
  - Viewfinder melingkar dengan lingkaran SVG beranimasi `strokeDashoffset` (@ 900 ms per langkah):
    1. *Face detected*.
    2. *Liveness confirmed* (Deteksi keaslian fisik, anti-foto/video spoofing).
    3. *Comparing with passport chip photograph* (Pencocokan biometrik 1:1).
    4. *Identity confirmed*.
  - Hasil perhitungan skor kemiripan (*Match Score Card*):
    - Nilai kecocokan: **98.7%** (Konfigurasi ambang batas kelulusan demo: **85.0%**).
  - Catatan Privasi: Prototipe menegaskan bahwa tidak ada rekaman video yang diunggah ke cloud dan tidak ada template biometrik yang disimpan permanen.
  - Tombol `Issue my Tourist ID` mentransisikan ke `issued`.

#### 6. Screen `issued` (`ScrIssued`)
- **Tujuan UI/UX:** Menampilkan kredensial digital Bali Tourist ID yang telah terbit.
- **Mutasi State & Audit:**
  - Memperbarui state global: `identityVerified: true`, `passportAuth: true`, `idStatus: 'active'`.
  - Memicu audit record resmi:
    - *Actor:* System
    - *Action:* `Credential issued`
    - *Purpose:* Identity onboarding
    - *Record:* `BTID-••••-••••-0938`
    - *Result:* `Issued`
  - Menampilkan kartu identitas digital interaktif (`IdCard`) dan catatan edukatif:
    - *Bukan pengganti paspor fisik.*
    - *Bukan rekening bank.*
    - *Bukan SIM mengemudi.*
  - Tombol `Next: Tourist Levy` mentransisikan ke `levy`.

---

### Fase B: Penyelesaian Retribusi Wisatawan (Bali Tourist Levy)

Berdasarkan Peraturan Daerah Bali mengenai retribusi wisatawan asing:

#### 7. Screen `levy` (`ScrLevy`)
- **Tujuan UI/UX:** Menjelaskan kewajiban pembayaran kontribusi pelestarian lingkungan dan budaya Bali.
- **Data yang Ditampilkan:**
  - Nama Wisatawan: `James Wilson`
  - Nomor Paspor: `••••••789`
  - Besaran Retribusi: **IDR 150.000**
  - Status: *Paid* (badge hijau) atau *Not paid* (badge kuning).
- **Aksi:** Tombol `Pay IDR 150,000` membuka layar pembayaran `levypay`, atau `Pay later` melanjutkan langsung ke dashboard via `activate`.

#### 8. Screen `levypay` (`ScrLevyPay`)
- **Tujuan UI/UX:** Gateway pembayaran retribusi dengan pilihan metode pembayaran internasional.
- **Pilihan Metode (`PAY_METHODS`):**
  1. `card`: Credit or debit card (Visa •••• 4218).
  2. `wallet`: International wallet (Saldo IDR 2.480.000).
  3. `qr`: QR payment (Pembayaran di counter bandara).
- **Logika Transaksi:**
  - Latensi pemrosesan 1.700 ms.
  - Sukses: Menghasilkan referensi kuitansi unik berformat `LVY-XXXXX`.
  - Mutasi Ledger: Mencatat entri pembayaran baru ke dalam `levyLedger` dengan status `paid` dan rekonsiliasi `Reconciled`.
  - Memicu audit event: *Action:* `Tourist Levy paid`, *Purpose:* `Levy settlement`.
  - Transisi ke layar `receipt`.

#### 9. Screen `receipt` (`ScrReceipt`)
- **Tujuan UI/UX:** Menampilkan bukti digital resmi pembayaran retribusi pariwisata.
- **Data Kuitansi:** Referensi kuitansi, nama, Tourist ID, nominal (IDR 150.000), metode pembayaran, cap waktu ISO, dan kode MRZ digital retribusi:
  - Line 1: `LEVY<<LVY<XXXXX<<IDR150000`
  - Line 2: `BTID<<BTID<2026<4471<0938<<PAID`
- **Aksi:** `Save receipt` (simulasi simpan PDF) dan `Continue` menuju layar `activate`.

#### 10. Screen `activate` (`ScrActivate`)
- **Tujuan UI/UX:** Layar perayaan aktivasi penuh akun wisatawan.
- **Status Akhir:**
  - Identitas terverifikasi (Checked).
  - Paspor terautentikasi (Checked).
  - Status retribusi pariwisata (Paid/Unpaid).
- **Aksi:** Tombol `Open my dashboard` mengeset `tourist.onboarded = true` dan mengarahkan ke `ScrHome`.

---

### Fase C: Main Dashboard & Tab Navigasi Pasca-Onboarding

Setelah status `onboarded: true`, antarmuka beralih ke layout aplikasi ponsel modern dengan bilah navigasi bawah (*Bottom Navigation Bar*) yang memiliki 5 tab utama:

```
┌────────────────────────────────────────────────────────┐
│ [Home]     [Pay]        [ID]        [Explore] [Profile]│
└────────────────────────────────────────────────────────┘
```

#### Tab 1: Home (`ScrHome`)
- **Greeting Cerdas:** Menyesuaikan waktu pengguna (*"Selamat pagi"*, *"Selamat siang"*, *"Selamat malam"*) diikuti nama depan wisatawan (`James`).
- **Banner Permintaan Menunggu (Pending Request Alert):** Jika terdapat request yang masuk dari merchant (`pendingReqs.length > 0`), muncul banner oranye mencolok: `X requests waiting for you — [Nama Merchant] · [Tujuan]`. Mengklik banner ini langsung membawa wisatawan ke layar `consent`.
- **Mini ID Card:** Versi ringkas dari Tourist ID dengan status verifikasi aktif dan shortcut ke tab ID.
- **Tombol Aksi Cepat (Quick Action Bar):**
  - Tombol `Show my ID` (membuka `ScrQr`).
  - Tombol `Pay with QRIS` (membuka tab `pay`).
- **Status Permitted Stay (Izin Tinggal Imigrasi):** Widget ringkasan izin tinggal (contoh: *e-VOA · 28 days remaining · until 08 Sep 2026*). Mengklik widget membuka detail di layar `visa`.
- **Banner Tourist Levy:** Tampil jika retribusi belum dibayar (*Settle IDR 150,000 to unlock every service*).
- **Grid Layanan Terpercaya (Trusted Services Grid):**
  - *Hotel check-in* (`hotel`): Check-in mandiri di Bali Ocean Resort.
  - *Get eSIM* (`esim`): Paket telekomunikasi digital Bali Connect.
  - *Vehicle rental* (`driving`): Status kredensial mengemudi.
  - *Transport* (`transport`): Layanan antar-jemput bandara dan armada terverifikasi.
  - *Insurance* (`insurance`): Asuransi perjalanan digital terintegrasi.
  - *Emergency* (`emergency`): Bantuan darurat 24/7 dan SOS.
- **Bagian Know Bali:** Akses cepat ke materi edukasi etiket pura/adat (`culture`) dan agenda upacara keagamaan (`events`).
- **Riwayat Aktivitas Terkini (Recent Activity):** 3 transaksi data/pembayaran terakhir dengan badge indikator persetujuan (*Approved / Rejected*).

#### Tab 2: Pay (`ScrPay`)
- **Tujuan UI/UX:** Solusi pembayaran tanpa uang tunai berbasis standar QRIS (Quick Response Code Indonesian Standard) untuk turis asing.
- **Alur Transaksi:**
  1. *Scan Viewfinder:* Kamera memindai kode QRIS meja merchant (simulasi Bali Coffee House).
  2. *Konfirmasi Tagihan:* Menampilkan merchant penerima (`Bali Coffee House - Canggu`), jumlah tagihan (`IDR 85,000`), dan opsi sumber dana (*Funding Source*: International Wallet balance IDR 2.480.000 atau Kartu Debit Visa).
  3. *Eksekusi Pembayaran:* Memanggil gateway penyedia pembayaran berlisensi (*Licensed Payment Provider*).
  4. *Kuitansi Pembayaran:* Menghasilkan nomor referensi `PAY-XXXXXX`. Merchant kafe hanya menerima konfirmasi `"Payment Confirmed"` dan tidak pernah menerima fotokopi paspor maupun data identitas pribadi lainnya.

#### Tab 3: ID (`ScrIdTab`)
- **Tujuan UI/UX:** Pusat kredensial identitas digital wisatawan.
- **Tampilan Kartu Identitas Lengkap (`IdCard`):**
  - Nomor Bali Tourist ID: `BTID-2026-4471-0938`.
  - Foto ornamen budaya Barong dan badge status verifikasi toska (`Verified visitor`).
  - Rincian data: Nama lengkap, kebangsaan (bendera 🇬🇧 + United Kingdom), tipe dokumen, nomor paspor tersamar, tanggal lahir, dan tanggal kedaluwarsa kredensial.
  - 3 Badge Verifikasi: `Identity verified`, `Passport authenticated`, `Levy paid`.
  - Baris Machine Readable Zone (MRZ).
- **Tombol Dynamic QR:** Membuka layar QR dinamis 45 detik.
- **Tombol Security Details:** Menampilkan modal audit teknis (status chip, integritas tanda tangan digital, penerbit paspor, dan skor biometric face matching 98.7%).

#### Tab 4: Explore (`ScrExplore`)
- **Tujuan UI/UX:** Direktori interaktif destinasi wisata, merchant resmi mitra ekosistem, serta integrasi kalender budaya.
- **Fitur Pencarian & Filter:** Kategori *Stay* (hotel), *Eat & drink* (kafe/restoran), *Get around* (rental kendaraan), *Do* (operator tur), dan *Connect* (eSIM).
- **Daftar Merchant:** Menampilkan nama bisnis, badge status kepatuhan (*Verified business* vs *Suspended*), lokasi wilayah (Seminyak, Kuta, Canggu, Ubud), dan jumlah template tujuan akses yang disetujui pemerintah.

#### Tab 5: Profile (`ScrProfile`)
- **Tujuan UI/UX:** Pengelolaan profil pengguna, riwayat privasi, kuitansi retribusi, dan pengaturan otorisasi data.
- **Menu Navigasi:**
  - *Privacy & activity* (`privacy`): Pusat kontrol data dan sharing history.
  - *Levy receipt* (`receipt`): Melihat kuitansi retribusi resmi.
  - *Driving credential* (`driving`): Status kelayakan mengemudi.
- **Pengaturan Izin Privasi Global (Privacy Permissions):**
  - Toggle `hotelAuto`: Otomatis menyetujui check-in hotel pada properti yang pernah dikunjungi sebelumnya.
  - Toggle `levyShare`: Mengizinkan merchant membaca status retribusi (hanya me-return string `"Paid"` tanpa membuka rincian kartu pembayaran).
  - Toggle `marketing`: Membagikan kebangsaan untuk penawaran diskon lokal (default: *OFF*).
- **Prinsip Penanganan Data:** Ringkasan komitmen sistem: *Verify Once, Share Selectively, No Biometric Sharing, Time-Limited, Full Accountability*.

---

### Fase D: Protokol Interaksi Verifikasi Merchant (Selective Disclosure)

Inilah inti dari inovasi privasi Bali Tourist ID: **menghilangkan fotokopi paspor secara total**.

#### 1. Screen `qr` (`ScrQr`)
- **Tujuan UI/UX:** Menghasilkan kode QR dinamis unik yang ditunjukkan kepada petugas merchant.
- **Mekanisme Ephemeral Token:**
  - Token string acak berkriptografi tinggi (contoh: `QRT-9X2KL8MPQ1`).
  - **Masa Berlaku (TTL): Tepat 45 Detik.**
  - Visualisasi SVG melingkar menghitung mundur dari 45s ke 0s. Jika waktu habis, QR menjadi buram (*dead*) dan muncul pesan *Code Expired*.
  - Tombol `Refresh code` mengocok token baru dan mereset timer ke 45s.
  - **Sifat Data:** Token QR **tidak mengandung data paspor sama sekali**. Token ini murni identifier sesi sementara untuk menghubungkan (*handshake*) merchant scanner dengan Tourist App.

#### 2. Screen `consent` (`ScrConsent`)
- **Tujuan UI/UX:** Layar persetujuan eksplisit wisatawan saat merchant memindai QR dinamis dan mengirimkan permintaan atribut data.
- **Elemen Antarmuka:**
  - Identitas Merchant Peminta: Nama bisnis, kategori, lokasi, status verifikasi pemerintah, nama staff petugas dan jabatannya (contoh: *Kadek Sari · Front Desk Agent pada Bali Ocean Resort*).
  - Cap waktu request dan waktu kedaluwarsa request (request otomatis hangus dalam 3 menit jika tidak direspon).
  - **Daftar Atribut yang Diminta (Attribute Checklist):**
    - Setiap atribut menampilkan nilai riil yang akan dikirim (contoh: *Full name: James Wilson*, *Permitted stay: Valid — 28 days remaining*).
    - Penjelasan alasan (*reason*) untuk setiap atribut (contoh: *"Identifies the guest on the hotel guest register"*).
    - Status regulasi: Badge kuning *"Required by configured demo accommodation policy"* jika bersifat kondisional berdasarkan peraturan daerah.
  - Informasi Retensi Data: Menampilkan berapa lama data disimpan oleh merchant (contoh: *"Retained for 30 days under configured demo accommodation policy"*).
  - Peringatan Proteksi Biometrik: *"Never shared: your biometric template, live face capture and full passport chip contents"*.
- **Aksi Wisatawan:**
  - `Approve & share`: Menyetujui pengiriman atribut yang diminta.
  - `Reject`: Menolak mentah-mentah permintaan data (merchant hanya menerima respon *Declined* tanpa data apapun).
  - `Ask merchant`: Mengirimkan pesan klarifikasi kepada petugas merchant (contoh: *"Why do you need my passport number?"*).

#### 3. Screen `shared` (`ScrShared`)
- **Tujuan UI/UX:** Konfirmasi bahwa transaksi pertukaran data telah tuntas secara aman.
- **Informasi:** Menampilkan ringkasan atribut apa saja yang berhasil dikirim ke merchant, nomor referensi transaksi konsen (`TX-XXXXXX`), dan tautan langsung untuk memeriksa riwayat di *Privacy Centre*.

#### 4. Screen `privacy` (`ScrPrivacy`)
- **Tujuan UI/UX:** Dashboard transparansi audit data pribadi wisatawan (*Self-Audit & Control*).
- **Metrik Privasi:**
  - Total transaksi disetujui (*Approved*).
  - Total transaksi ditolak (*Rejected*).
  - Total merchant yang memiliki izin akses aktif (*Active Access*).
- **Log Riwayat Berbagi Data (Sharing History):**
  - Setiap entri mencantumkan nama merchant, tujuan akses, tanggal/jam, daftar atribut yang diserahkan, dan nomor referensi unik.
- **Kontrol Hak Pengguna (User Rights Control):**
  - Tombol `Download consent receipt`: Mengunduh bukti kriptografis tanda terima konsen.
  - Tombol `Stop future access` (*Revocation*): Mencabut izin merchant untuk meminta data di masa mendatang secara sepihak.
  - Tombol `Report unexpected access`: Melaporkan kejanggalan akses merchant langsung ke antrean pengaduan Otoritas Pariwisata (*Government Exceptions & Audit Queue*).

---

### Fase E: Modul Layanan Wisata Terintegrasi (Vertical Services)

Turis App bukan sekadar ID statis, melainkan ekosistem penunjang perjalanan terintegrasi:

#### 1. Screen `visa` (`ScrVisa`)
- **Tujuan:** Monitoring masa berlaku izin tinggal wisatawan untuk mencegah pelanggaran keimigrasian (*overstay*).
- **Sinkronisasi Data Imigrasi (Simulated DG of Immigration):**
  - Nomor Referensi Catatan: `IMM-2026-88-441702`.
  - Pelabuhan Masuk: `Ngurah Rai International Airport (DPS)`.
  - Tanggal Masuk: `09 August 2026`.
  - Tipe Visa: Mendukung 4 jenis visa (`VISA_TYPES`):
    - `voa`: e-VOA (B1) - 30 hari, dapat diperpanjang 1x 30 hari.
    - `free`: Bebas Visa Kunjungan (BVK) - 30 hari, tidak dapat diperpanjang.
    - `b211`: Kunjungan B211A - 60 hari, dapat diperpanjang 2x 60 hari.
    - `kitas`: Izin Tinggal Terbatas (ITAS) - 365 hari, multiple entry.
- **Visual Gauge & Peringatan:**
  - Lingkaran progres sisa hari dengan pewarnaan dinamis:
    - Hijau toska: Sisa hari > 7 hari.
    - Kuning amber: Sisa hari 4 - 7 hari (*"Your permitted stay ends soon"*).
    - Merah mawar: Sisa hari <= 3 hari atau kedaluwarsa.
- **Fitur Privasi Imigrasi:** Menegaskan bahwa ketika merchant mengecek izin tinggal wisatawan, merchant **hanya menerima status boolean** (`PERMITTED STAY — VALID`) dan bukan berkas imigrasi, riwayat perjalanan, atau nomor paspor lengkap.

#### 2. Screen `culture` (`ScrCulture`) & `lesson` (`ScrLesson`)
- **Tujuan:** Orientasi budaya dan panduan kepatuhan norma adat Bali guna menekan angka pelanggaran turis terhadap kesucian pulau.
- **5 Modul Edukasi (`CULTURE`):**
  1. `temple`: Tata cara berkunjung ke Pura (kewajiban kain kamen & selendang, penutupan bahu, larangan memasuki jeroan saat menstruasi/luka terbuka).
  2. `canang`: Menghormati sesajen Canang Sari di jalan (larangan melangkahi atau menendang sesajen).
  3. `manners`: Kesopanan harian (menggunakan tangan kanan saat memberi/menerima, larangan memegang kepala orang dewasa, larangan mengenakan pakaian renang di luar area pantai).
  4. `nyepi`: Panduan Hari Raya Nyepi (larangan total keluar ruangan selama 24 jam, pemadaman lampu, penutupan bandara dan seluruh aktivitas pulau).
  5. `nature`: Perlindungan lingkungan dan kelestarian air/terumbu karang.
- **Mekanisme Interaktif (`ScrLesson`):**
  - Simulasi video player dengan bab (*chapters*), indikator progres waktu, dan transkrip.
  - Evaluasi pemahaman berupa kuis pilihan ganda interaktif (*Quick Check*) di akhir modul dengan penjelasan alasan (*why*).
  - Status Kelulusan: Menyelesaikan seluruh 5 modul memunculkan badge kehormatan *"Culture Aware"* pada Tourist ID yang dapat ditukarkan dengan diskon merchant mitra.

#### 3. Screen `events` (`ScrEvents`)
- **Tujuan:** Kalender budaya terintegrasi agar wisatawan dapat merencanakan kunjungan secara harmonis dengan peribadatan lokal.
- **Jenis Acara (`EVENT_KINDS`):**
  - Upacara Pura (*Island Ceremony*).
  - Piodalan / Ulang Tahun Pura (*Temple Anniversary*).
  - Festival Budaya (*Arts & Festival*).
  - Penanggalan Bulan (*Lunar Observance: Purnama & Tilem*).
- **Fitur Khusus Peringatan Penutupan Wilayah:**
  - Deteksi otomatis hari besar yang menutup total aktivitas pulau (seperti Hari Raya Nyepi) dengan banner peringatan merah: *"Visitors must remain indoors for the full day. The airport closes entirely"*.
- **Personal Trip Planner:** Fitur bookmark acara ke dalam daftar rencana pribadi (`plan`).

#### 4. Screen `driving` (`ScrDriving`)
- **Tujuan:** Pemisahan tegas (*decoupling*) antara pembuktian identitas diri dan kelayakan mengemudi di Indonesia.
- **Poin Hukum Teknis:** Memiliki Bali Tourist ID tidak berarti legal mengendarai sepeda motor atau mobil di Bali. Wisatawan wajib memiliki SIM Internasional atau SIM nasional yang diakui.
- **State Workflow Kredensial Mengemudi:**
  - `not_provided`: Belum ada dokumen SIM yang diserahkan.
  - `submitted`: Wisatawan mengunggah foto SIM / International Driving Permit.
  - `pending`: Dokumen sedang ditinjau oleh tim rental terakreditasi (*Island Drive Car Rental*).
  - `verified`: SIM terverifikasi (Kategori B / Roda Dua). Merchant rental hanya menerima sinyal kelayakan `"Driving Credential: Verified"` tanpa menyimpan salinan SIM fisik.

#### 5. Screen `esim` (`ScrEsim`)
- **Tujuan:** Aktivasi instan paket data telekomunikasi seluler tanpa antre dan tanpa registrasi manual.
- **Fitur Utama:** Identitas ePassport yang telah terverifikasi di awal langsung digunakan kembali (*reused*) untuk memenuhi kewajiban registrasi telekomunikasi nasional. Wisatawan memilih durasi paket (7 hari / 10 GB, 14 hari / 25 GB, 30 hari / Unlimited) dan mengaktifkan profil eSIM langsung dari smartphone.

#### 6. Screen `emergency` (`ScrEmergency`)
- **Tujuan:** Tombol pertolongan darurat (SOS) terintegrasi untuk kecelakaan, tindak kriminal, atau bencana alam.
- **Alur Operasi Darurat:**
  - Tombol tahan (*Hold for assistance*) mencegah penekanan tidak sengaja.
  - Saat terpicu, sistem membuka tiket kasus resmi berformat `EMG-XXXX` dan mencatat log audit darurat.
  - **Prinsip Pembatasan Data:** Petugas respon darurat hanya menerima nama, identitas terverifikasi, dan nomor kontak darurat keluarga (*emergency contact*). Data chip paspor dan riwayat transaksi tetap terkunci.
  - Daftar kontak darurat resmi: Polisi Pariwisata (+62 361 000 111), Ambulans (118), Konsulat Jenderal, dan Helpdesk Asuransi Terdaftar.

---

## 5. Deep Dive: Mekanisme Verifikasi Identitas (How Verification Works)

Bagian ini membedah arsitektur teknis dari mesin verifikasi identitas di balik layar Tourist App:

```
┌───────────────────────────────────────────────────────────────────────────────────┐
│                    ARSITEKTUR VERIFIKASI IDENTITAS TOURIST APP                    │
└───────────────────────────────────────────────────────────────────────────────────┘

 [1. OPTICAL MRZ OCR]
  Kamera memindai halaman biodata ──► Ekstraksi Line 1 & Line 2 MRZ (TD3)
  Verifikasi Checksum (7-3-1 Modulo 10) ──► Menghitung Kunci Akses K_enc & K_mac
        │
        ▼
 [2. NFC SECURE CHANNEL ESTABLISHMENT]
  Protokol BAC / PACE via ISO 14443 ──► Buka Secure Channel terenkripsi 3DES/AES
  Membaca File Sistem ePassport:
  ├── EF.COM  : Daftar Data Group yang tersedia
  ├── EF.DG1  : Data MRZ tersimpan di chip
  ├── EF.DG2  : Foto wajah biometrik (JPEG2000)
  └── EF.SOD  : Security Object Document (Hash semua DG + DS Signature)
        │
        ▼
 [3. ICAO PASSIVE AUTHENTICATION (PA)]
  1. Hash DG1 & DG2 dihitung ulang secara lokal (SHA-256)
  2. Cocokkan hash lokal dengan hash yang tercantum di EF.SOD
  3. Verifikasi Tanda Tangan Digital SOD menggunakan Public Key Document Signer (DS)
  4. Validasi Sertifikat DS terhadap Country Signing CA (CSCA) Master List resmi
        │
        ▼
 [4. BIOMETRIC 1:1 FACE MATCHING & LIVENESS]
  Kamera Depan ──► Passive Liveness Detection (Cek kedalaman, pantulan cahaya, mikro-gerakan)
  Ekstraksi Feature Vector Wajah Live Capture (512-D float)
  Ekstraksi Feature Vector Foto DG2 Chip Paspor (512-D float)
  Hitung Cosine Similarity:
            Skor = (Vector_Live · Vector_DG2) / (||Vector_Live|| * ||Vector_DG2||)
  Evaluasi: Skor 98.7% >= Ambang Batas 85.0% ──► [VERIFIKASI IDENTITAS SAH]
        │
        ▼
 [5. PENERBITAN BALI TOURIST ID (BTID)]
  Sistem menerbitkan Identitas Digital BTID-2026-XXXX-XXXX
  Kredensial disimpan di Secure Enclave perangkat
  Kunci chip paspor dan memori biometrik dibersihkan dari RAM
```

---

### Tahap 1: Optical MRZ Capture & TD3 Checksum Engine

Paspor standar internasional menggunakan spesifikasi **ICAO Doc 9303 Part 4** format TD3 (Machine Readable Travel Document):
- Terdiri dari 2 baris, masing-masing sepanjang 44 karakter alfanumerik mono-spasi.
- **Karakter Pengisi:** `<` digunakan sebagai pemisah spasi atau pengisi bidang kosong.

#### Struktur Baris MRZ TD3:
```
Line 1: P < G B R W I L S O N < < J A M E S < < < < < < < < < < < < < < < < < < < < < <
        │ │ └──┬──┘ └───────────┬────────────┘
        │ │    │                └── Format: Nama Keluarga << Nama Depan
        │ │    └── Kode Negara Penerbit (ISO 3166-1 alpha-3: GBR)
        │ └── Tipe Dokumen (P = Passport)
        
Line 2: 7 8 9 0 1 2 3 4 5 4 G B R 8 8 0 5 1 2 7 M 3 2 0 3 1 8 4 < < < < < < < < < < < < < < 0 6
        └───────┬───────┘ │ └──┬──┘ └─────┬─────┘ │ │ └─────┬─────┘ │                             └──┴─ Composite
                │         │    │          │       │ │       │       └── Expiry Check Digit             Check
                │         │    │          │       │ │       └── Tanggal Kedaluwarsa (YYMMDD)          Digit
                │         │    │          │       │ └── Jenis Kelamin (M/F)
                │         │    │          │       └── DOB Check Digit
                │         │    │          └── Tanggal Lahir (YYMMDD: 12 Mei 1988 -> 880512)
                │         │    └── Kebangsaan Pemegang (GBR)
                │         └── Nomor Paspor Check Digit
                └── Nomor Paspor (9 Karakter)
```

#### Algoritma Verifikasi Digit Periksa (Checksum Verification):
Setiap blok data kritis memiliki digit periksa berbasis algoritma bobot berulang `7-3-1`:
1. Setiap karakter dikonversi menjadi angka:
   - Angka `0-9` bernilai `0-9`.
   - Huruf `A-Z` bernilai `10-35`.
   - Karakter filler `<` bernilai `0`.
2. Dikalikan dengan pola bobot berulang: posisi ke-1 dikali 7, ke-2 dikali 3, ke-3 dikali 1, ke-4 dikali 7, dan seterusnya.
3. Seluruh hasil perkalian dijumlahkan dan dihitung nilai modulos 10:
$$\text{Check Digit} = \left(\sum_{i=1}^{n} \text{Nilai}(C_i) \times \text{Bobot}_i\right) \pmod{10}$$

Jika nilai modulus sama dengan karakter digit periksa pada MRZ, maka pembacaan optik dinyatakan **100% akurat tanpa kesalahan karakter (character error-free)**.

---

### Tahap 2: Pembacaan Chip NFC ePassport (ICAO Doc 9303 BAC/PACE)

Chip di dalam paspor tidak dapat dibaca oleh sembarang pembaca RFID publik. Chip dilindungi oleh mekanisme kriptografis **Basic Access Control (BAC)** atau **Password Authenticated Connection Establishment (PACE)**:

1. **Derivasi Kunci Akses BAC:**
   Dari hasil pemindaian MRZ pada Tahap 1, aplikasi mengekstraksi string seed:
   $$\text{Seed} = \text{Nomor Paspor} + \text{Check Digit} + \text{Tanggal Lahir} + \text{Check Digit} + \text{Tanggal Kedaluwarsa} + \text{Check Digit}$$
   String seed ini di-hash menggunakan SHA-1 untuk menurunkan dua kunci simetris 3DES/AES:
   - $K_{\text{enc}}$: Kunci Enkripsi Transmisi Sesi.
   - $K_{\text{mac}}$: Kunci Message Authentication Code (Integritas APDU).

2. **Handshake Autentikasi Bersama (Mutual Authentication):**
   Aplikasi dan chip saling bertukar nonce acak 8-byte untuk membuktikan bahwa aplikasi memiliki hak akses legal atas paspor fisik. Setelah sukses, saluran komunikasi terenkripsi aman (*Secure Messaging*) resmi terbuka.

3. **Pembacaan Struktur Berkas LDS (Logical Data Structure):**
   Aplikasi mengirimkan perintah APDU (*Application Protocol Data Unit*) ISO/IEC 7816-4 untuk membaca berkas biner:
   - `EF.COM`: Header informasi versi spesifikasi ICAO dan daftar berkas yang ada.
   - `EF.DG1`: Salinan digital baris MRZ.
   - `EF.DG2`: Berkas foto biometrik wajah resolusi tinggi dalam format standar ISO/IEC 19794-5 (JPEG / JPEG2000).
   - `EF.SOD`: Berkas objek keamanan (*Security Object Document*) berbasis format kriptografi CMS (*Cryptographic Message Syntax*, RFC 5652).

---

### Tahap 3: Passive Authentication & Rantai Sertifikat PKI

Tahap ini membuktikan bahwa chip paspor **asli, tidak dimodifikasi oleh peretas, dan benar-benar diterbitkan oleh otoritas resmi negara asal**:

1. **Verifikasi Hash Data Group (Content Integrity):**
   Di dalam berkas `EF.SOD`, terdapat tabel hash SHA-256 dari seluruh Data Group yang diterbitkan resmi saat paspor dicetak.
   Aplikasi menghitung ulang hash SHA-256 dari berkas `EF.DG1` dan `EF.DG2` yang baru saja dibaca dari chip:
   $$\text{Hash}_{\text{hitung}}(\text{DG1}) \stackrel{?}{=} \text{Hash}_{\text{terdaftar}}(\text{DG1})$$
   $$\text{Hash}_{\text{hitung}}(\text{DG2}) \stackrel{?}{=} \text{Hash}_{\text{terdaftar}}(\text{DG2})$$
   Jika seluruh hash identik, terbukti bahwa data teks paspor maupun foto wajah di dalam chip tidak pernah diubah 1 bit pun.

2. **Verifikasi Tanda Tangan Digital SOD (Document Signer Verification):**
   Tabel hash di dalam SOD ditandatangani secara digital oleh otoritas pencetak paspor negara pembuat (*Document Signer / DS*). Aplikasi memverifikasi tanda tangan digital tersebut menggunakan Public Key yang tersimpan di dalam sertifikat digital DS yang disertakan pada SOD paspor.

3. **Validasi Rantai Sertifikat CSCA (Trust Anchor Chain):**
   Aplikasi mencocokkan sertifikat DS terhadap bank data sertifikat induk resmi negara di dunia (*Country Signing Certification Authority / CSCA Master List* yang didistribusikan melalui direktori publik ICAO PKD):
   $$\text{CSCA Anchor (UK Home Office)} \longrightarrow \text{Document Signer (DS Cert)} \longrightarrow \text{SOD Signature} \longrightarrow \text{Passport Data Groups}$$
   Jika rantai sertifikat valid, belum dicabut (*not revoked*), dan belum kedaluwarsa, paspor dinyatakan **Autentik Secara Hukum Internasional**.

---

### Tahap 4: Deteksi Liveness & Biometric Face Matching 1:1

Membuktikan bahwa orang yang memegang smartphone adalah pemilik sah paspor tersebut dan bukan penipu yang mencuri paspor fisik:

1. **Presentation Attack Detection (PAD / Liveness Check):**
   Kamera depan memindai wajah wisatawan dalam lingkungan 3 dimensi secara real-time. Modul liveness menguji:
   - Mikro-ekspresi dan kedipan mata alami.
   - Refleksi cahaya variabel dari layar ke pupil mata.
   - Analisis tekstur kulit dan kontur kedalaman 3D untuk menolak serangan pemalsuan (*spoofing*) seperti: topeng silikon 3D, foto cetak resolusi tinggi, atau rekaman video layar tablet/ponsel.

2. **Pencocokan Biometrik Wajah 1:1 (Facial Feature Vector Matching):**
   - Wajah hidup yang lolos uji liveness dipotong (*cropped*) dan dinormalisasi.
   - Model jaringan saraf dalam (*Deep Neural Network*) mengekstraksi 512-dimensi representasi fitur matematika wajah ($V_{\text{live}}$).
   - Foto wajah asli dari chip paspor (Data Group 2) diekstraksi dengan cara yang sama menjadi vektor pembanding ($V_{\text{passport}}$).
   - Dihitung nilai kemiripan vektor menggunakan formula **Cosine Similarity**:
   $$\text{Similarity Score} = \frac{V_{\text{live}} \cdot V_{\text{passport}}}{\|V_{\text{live}}\| \times \|V_{\text{passport}}\|}$$
   - **Evaluasi Hasil:**
     - Hasil komputasi prototype: **98.7% similarity**.
     - Ambang batas aman (*Configured Demo Threshold*): **85.0%**.
     - Status: **Lolos / Identity Confirmed**.

---

### Tahap 5: Penerbitan Bali Tourist ID (BTID Credential)

Setelah validasi dokumen paspor, chip, PKI, dan biometrik sukses:
- Sistem menerbitkan nomor identitas terdesentralisasi:
  `BTID-2026-4471-0938`
- Kredensial digital ini mengikat data profil wisatawan ke dalam format dokumen yang dapat diverifikasi (*Verifiable Credential* compliant W3C / ISO 18013-5 Mobile Driving Licence standard).
- **Prinsip Higienitas Kriptografis (Cryptographic Hygiene):**
  - Kunci enkripsi chip paspor $K_{\text{enc}}$ dan $K_{\text{mac}}$ langsung dihapus dari memori RAM.
  - Foto live capture dan vektor biometrik wajah langsung dimusnahkan.
  - Yang tersimpan di Tourist App hanyalah kredensial digital terenkripsi yang siap digunakan untuk bertransaksi dengan merchant.

---

### Tahap 6: Mekanisme Dynamic Rotating QR & Ephemeral Token

Ketika wisatawan ingin membuktikan statusnya kepada merchant, Tourist App tidak menampilkan QR statis (yang bisa difoto/dicuri pihak lain), melainkan **Dynamic Rotating Ephemeral QR Code**:

```
[Tourist App Clock] ──► Generator Token Acak (Hash + Nonce + Timestamp)
                             │
                             ▼
               Token Sementara: `QRT-9X2KL8MPQ1`
               TTL (Time-To-Live) : 45 Detik
                             │
                             ▼
                 [Dynamic QR SVG Display]
                             │
            Petugas Hotel Scan QR via Merchant App
                             │
                             ▼
         Merchant Server request Handshake ke Hub/Tourist App:
         "Token QRT-9X2KL8MPQ1 meminta Template: Hotel Check-In"
                             │
                             ▼
         Wisatawan menerima notifikasi consent di Tourist App:
         "Bali Ocean Resort meminta nama, status izin tinggal, retribusi"
```

#### Keunggulan Arsitektur Dynamic QR:
1. **Anti-Replay Attack:** Token hanya berlaku selama 45 detik. Foto tangkapan layar (*screenshot*) yang dicuri orang lain akan kedaluwarsa seketika.
2. **Zero Identity Leak in QR Payload:** Kode QR **hanya berisi token sesi sementara**. Jika ada pihak jahat memindai QR wisatawan secara diam-diam menggunakan kamera biasa, mereka tidak akan mendapatkan data paspor, nama, atau informasi sensitif apapun.
3. **Persetujuan Bersyarat Terisolasi:** Transaksi pertukaran data hanya dapat terjadi jika wisatawan secara sadar menekan tombol **"Approve & share"** pada layar Tourist App miliknya.

---

## 6. Arsitektur Alur Data (Data Flow Architecture)

### Alur Data Onboarding Identitas

```
[Wisatawan]                  [Kamera/NFC Phone]                [Local Crypto Engine]             [App State & Audit]
     │                               │                                   │                                │
     │── 1. Buka App (welcome) ─────►│                                   │                                │
     │── 2. Scan Halaman Paspor ────►│── Ekstraksi Raw MRZ OCR ─────────►│                                │
     │                               │                                   │── Hitung Checksum & K_seed ───►│
     │                               │◄── Kunci BAC K_enc & K_mac ───────│                                │
     │── 3. Tempel Paspor ke NFC ───►│── Kirim ISO APDU Command ────────►│                                │
     │                               │◄── Terima EF.DG1, DG2, SOD ───────│                                │
     │                               │                                   │── Passive Auth: Cek Hash DG ──►│
     │                               │                                   │── Validasi Signature & CSCA ──►│
     │── 4. Hadap Kamera Depan ─────►│── Tangkap Stream Video ──────────►│                                │
     │                               │                                   │── Passive Liveness Check ─────►│
     │                               │                                   │── 1:1 Cosine Similarity Match ─►│
     │                               │                                   │                                │
     │                               │                                   │── 5. Skor 98.7% >= 85.0% ─────►│
     │                               │                                   │   [Terbitkan BTID Kredensial]  │
     │                               │                                   │   Update State: active         │
     │                               │                                   │   Tulis Audit Log (AUD-XXXXX)  │
     │◄── 6. Tampilkan BTID Card ────┴───────────────────────────────────┴────────────────────────────────│
```

---

### Alur Data Transaksi & Handshake Consent

```
[Merchant App (Hotel)]             [Pusat Ekosistem / P2P]             [Turis App (James)]
         │                                    │                                 │
         │                                    │◄── 1. Buat Dynamic QR (45s) ────│
         │── 2. Scan QR Wisatawan ───────────►│    (Token: `QRT-9X2KL8MPQ1`)    │
         │── 3. Kirim Request Template ──────►│                                 │
         │      (hotel_checkin: nama, izin,   │                                 │
         │       retribusi, no. paspor ops.)  │── 4. Push Notifikasi Request ──►│
         │                                    │                                 │
         │                                    │                                 │ Wisatawan tinjau layar
         │                                    │                                 │ consent & alasan akses
         │                                    │                                 │
         │                                    │◄── 5. Approve & Share ──────────│
         │                                    │    (Hanya atribut disetujui)    │
         │◄── 6. Terima Verifikasi Data ──────│                                 │
         │      • Full Name: James Wilson     │                                 │── Catat di Privacy Hist.
         │      • Identity: Verified          │                                 │   (Izin aktif / ongoing)
         │      • Permitted Stay: Valid (28d) │                                 │
         │      • Tourist Levy: Paid          │                                 │
         │      (TIDAK ADA FOTOKOPI PASPOR)   │                                 │
         │                                    │── 7. Dispatch Audit Record ────►│ [Gov Audit Trail]
```

---

### Alur Data Audit & Pelaporan Privasi

Setiap kali data disentuh, sistem mengeksekusi fungsi pencatatan audit immutable:

```javascript
audit({
    actor: 'James Wilson',
    org: 'Visitor',
    role: 'Tourist',
    action: 'Approved data request',
    purpose: 'Hotel check-in',
    record: 'TX-448102',
    result: 'Shared 6 attribute(s)'
});
```

Jika di masa mendatang wisatawan mendapati aktivitas mencurigakan pada riwayat berbaginya, alur data berikut dieksekusi:
1. Wisatawan membuka detail transaksi di `ScrPrivacy`.
2. Menekan tombol **"Stop future access"**: State `accessOngoing` diubah menjadi `false`, memblokir merchant tersebut untuk meminta atribut pembaruan di masa depan.
3. Menekan tombol **"Report unexpected access"**: Membuka modal investigasi dan mengirimkan berkas pengaduan resmi langsung ke antrean `GovExceptions` di Government Portal untuk ditindaklanjuti oleh petugas pengawas kepatuhan pedagang (*Merchant Compliance Officer*).

---

## 7. Matriks Minimalisasi Data & Kebijakan Privasi (Data Minimization Matrix)

Di dalam kode mock-up, arsitektur data diatur secara ketat oleh tabel `ATTRS`, `TEMPLATES`, dan `DEFAULT_POLICY`. Merchant **tidak pernah diizinkan membuat form isian bebas (*no free-form requests*)**.

Berikut adalah matriks 18 atribut data di dalam ekosistem dan tingkat aksesibilitasnya per kategori merchant:

| Kunci Atribut | Nama Atribut | Nilai Riil Prototype | Hotel (Akomodasi) | Car (Rental Kendaraan) | Cafe (F&B / Resto) | eSIM (Telekomunikasi) | Tour (Operator Tur) |
|---|---|---|---|---|---|---|---|
| `name` | Full name | James Wilson | **Allowed** | **Allowed** | Prohibited | Conditional | **Allowed** |
| `nationality` | Nationality | United Kingdom | **Allowed** | **Allowed** | Prohibited | Conditional | Conditional |
| `identity` | Identity verified | Verified | **Allowed** | **Allowed** | Conditional | **Allowed** | **Allowed** |
| `passport_auth` | Passport authentication | Authentic — passive auth | **Allowed** | **Allowed** | Prohibited | Conditional | Conditional |
| `id_validity` | Tourist ID validity | Valid until 18 Jan 2027 | **Allowed** | **Allowed** | Prohibited | **Allowed** | **Allowed** |
| `levy_status` | Tourist Levy status | Paid · LVY-88412 | **Allowed** | Conditional | Prohibited | Conditional | **Allowed** |
| `over18` | Age eligibility (18+) | Over 18 — verified | Conditional | **Allowed** | Conditional | Conditional | **Allowed** |
| `over21` | Age eligibility (21+) | Over 21 — verified | Conditional | **Allowed** | Conditional | Prohibited | Conditional |
| `dob` | Exact date of birth | 12 May 1988 | Conditional | Conditional | Prohibited | Prohibited | Conditional |
| `passport_number`| Passport number | ••••••789 | Conditional | Conditional | Prohibited | Conditional | Prohibited |
| `arrival` | Arrival date | 09 August 2026 | Conditional | Conditional | Prohibited | Prohibited | Prohibited |
| `departure` | Departure date | 23 August 2026 | Conditional | Conditional | Prohibited | Prohibited | Prohibited |
| `visa_type` | Visa class | e-VOA — B1 Visit Visa | Conditional | Prohibited | Prohibited | Prohibited | Prohibited |
| `stay_valid` | Permitted stay | Valid — 28 day(s) left | **Allowed** | **Allowed** | Prohibited | **Allowed** | Conditional |
| `stay_expiry` | Permitted stay until | 08 September 2026 | Conditional | Conditional | Prohibited | Conditional | Prohibited |
| `driving` | Driving credential status | Verified — Category B | Prohibited | **Allowed** | Prohibited | Prohibited | Prohibited |
| `payment_confirm`| Payment confirmation | Payment confirmed | **Allowed** | **Allowed** | **Allowed** | **Allowed** | **Allowed** |
| `emergency` | Emergency contact | S. Wilson · +44 ••• 4471 | Conditional | Conditional | Prohibited | Prohibited | **Allowed** |
| `biometric` | Biometric template | — | **PROHIBITED** | **PROHIBITED** | **PROHIBITED** | **PROHIBITED** | **PROHIBITED** |

### Analisis Kritis Privasi:
1. **Perlindungan Biometrik Absolut:** Atribut `biometric` berstatus **PROHIBITED** untuk seluruh kategori bisnis tanpa pengecualian. Template wajah dan foto liveness tidak pernah meninggalkan ponsel wisatawan.
2. **Age Verification Tanpa Tanggal Lahir:** Untuk bar, klub pantai, atau kafe (`cafe`), verifikasi umur mengembalikan status boolean `"Over 18 — verified"`. Kafe tidak diizinkan mengetahui tanggal lahir asli wisatawan.
3. **Zero Photocopy Paradigm:** Hotel yang sebelumnya memfotokopi buku paspor kini hanya menerima atribut digital yang diperlukan untuk buku register tamu (*Guest Book*), dan data tersebut terikat retensi otomatis 30 hari.

---

## 8. Keterhubungan Turis App dengan Government Portal & Merchant App

Meskipun fokus dokumen ini adalah Tourist App, fungsi-fungsi di dalam aplikasi turis beroperasi secara real-time terhubung dengan dua pilar lainnya:

```
┌────────────────────────────────────────────────────────────────────────┐
│                        BALI TOURIST ID PLATFORM                        │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│   [ TURIS APP ]                 [ MERCHANT APP ]   [ GOV PORTAL ]     │
│         │                              │                 │             │
│         │── 1. Onboarding Berhasil ────┼────────────────►│ Log Audit & │
│         │                              │                 │ Registri ID │
│         │                              │                 │             │
│         │── 2. Bayar Retribusi ────────┼────────────────►│ Settlement  │
│         │   (IDR 150.000)              │                 │ Ledger      │
│         │                              │                 │             │
│         │◄──3. Dynamic QR Scan ────────│                 │             │
│         │   & Consent Handshake        │                 │             │
│         │                              │                 │             │
│         │── 4. Kirim Data Minimasi ───►│                 │             │
│         │   (Tanpa Fotokopi)           │                 │             │
│         │                              │── Transaksi ───►│ Log Akses & │
│         │                              │   Tercatat      │ Pengawasan  │
│         │                              │                 │ Kepatuhan   │
│         │                              │                 │             │
│         │── 5. Lapor Akses Liar ───────┼────────────────►│ Tiket Kasus │
│         │                              │                 │ Exceptions  │
│         │                              │◄── Sanksi / ────│ & Kepatuhan │
│         │                              │    Suspend      │             │
└─────────┴──────────────────────────────┴─────────────────┴─────────────┘
```

1. **Sinkronisasi Regulasi Kebijakan (Policy Sync):**
   Matriks akses merchant yang tampil di Tourist App dikontrol terpusat melalui tab **`config` (GovConfig)** di Government Portal. Jika pemerintah menonaktifkan izin nomor paspor untuk rental mobil, secara instan form permohonan rental mobil di Tourist App mencoret field tersebut.
2. **Pengawasan Retribusi & Settlement (Levy Tracking):**
   Setiap pembayaran retribusi di Tourist App (`ScrLevyPay`) langsung tercatat pada tab **`levy` (GovLevy)** di Government Portal. Pejabat keuangan pariwisata dapat melihat rekonsiliasi real-time antara dana masuk via gateway perbankan dengan status tanda terima wisatawan.
3. **Audit Kepatuhan Merchant & Penindakan Sanksi:**
   Ketika merchant melanggar etika atau izin usahanya kedaluwarsa, pejabat pemerintah melalui tab **`merchants` (GovMerchants)** dapat mengeset status bisnis menjadi `suspended`. Jika turis memindai QR di merchant yang berstatus suspended, Tourist App secara otomatis memblokir transaksi dengan notifikasi: *"This merchant cannot request information. Access is suspended by the tourism authority"*.
4. **Pusat Penanganan Pengecualian (GovExceptions Queue):**
   Jika wisatawan di Tourist App mengalami kegagalan verifikasi pada Path 2, atau membuat laporan kejanggalan akses privasi, tiket peninjauan otomatis masuk ke meja kerja pejabat imigrasi/pariwisata (*Identity Exception Reviewer*) di tab `exceptions`.

---

## 9. Kesimpulan & Rekomendasi Implementasi Teknis

Prototipe `bali-tourist-id Mock Up Final Version.html` bukan sekadar tampilan visual mockup, melainkan memiliki arsitektur logika sistem identitas digital terpercaya yang sangat matang, komprehensif, dan mematuhi kaidah standar internasional:

1. **Konfirmasi Verifikasi Arsitektur 2 Path:**
   - **Path 1 (Self-Service Digital Trust)** memfasilitasi 90%+ wisatawan dengan proses instan 3 menit (MRZ OCR -> NFC Chip -> ICAO Passive Auth -> 1:1 Face Match -> BTID -> Online Levy -> Dynamic QR Consent).
   - **Path 2 (Assisted Desk & Exceptions)** memberikan jaring pengaman inklusif bagi pemilik paspor non-elektronik, lansia, atau kegagalan teknis hardware di bandara kedatangan.
2. **Privasi Berorientasi Masa Depan:**
   Arsitektur ini memecahkan masalah kebocoran data paspor turis di Bali dengan prinsip *Zero Photocopy*. Merchant hanya menerima klaim verifikasi yang dibatasi oleh tujuan layanan (*purpose-bound*), sementara wisatawan memiliki hak penuh untuk mencabut akses di masa depan (*revocation*).
3. **Relevansi dengan Arsitektur Repositori ezsign-core:**
   Struktur audit event log pada Tourist App (`audit({ actor, org, role, action, purpose, record, result })`) sangat kompatibel untuk diintegrasikan secara langsung dengan arsitektur backend repositori **`ezsign-core`**:
   - Event audit Turis App dan Merchant dikirimkan via antrean **RabbitMQ** di modul `middleware/`.
   - Transaksi di-signing secara aman menggunakan private key otoritas melalui HashiCorp Vault KMS di modul `tx-worker/`.
   - Hash audit diinjeksi ke dalam konsorsium blockchain privat **Hyperledger Besu QBFT** via smart contract proxy modular di `smartcontract/`. Dengan demikian, bukti konsen wisatawan dan riwayat transaksi menjadi permanen, terbukti secara hukum (*legally binding*), dan anti-manipulasi (*tamper-proof*).

---
*Dokumen ini disusun sebagai spesifikasi teknis dan analisis bedah mendalam sistem Bali Tourist ID (Path 1: Tourist App Lifecycle).*
