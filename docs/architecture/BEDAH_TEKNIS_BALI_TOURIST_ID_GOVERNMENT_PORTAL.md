# BEDAH TEKNIS ARSITEKTUR BALI TOURIST ID
## Bagian: Government Portal (Trust Anchor, Policy Engine, & Oversight Platform)

---

## DAFTAR ISI
1. [Executive Summary: Peran Government Portal dalam Ekosistem](#1-executive-summary-peran-government-portal-dalam-ekosistem)
2. [Prinsip Desain: Pengawasan Tanpa Pengintaian (Oversight without Surveillance)](#2-prinsip-desain-pengawasan-tanpa-pengintaian-oversight-without-surveillance)
3. [Daftar Seluruh Kebutuhan Sistem Government Portal (Technical Requirements)](#3-daftar-seluruh-kebutuhan-sistem-government-portal-technical-requirements)
4. [Struktur Model Data & Manajemen State Global](#4-struktur-model-data--manajemen-state-global)
5. [Matriks Kontrol Akses Berbasis Peran (Role-Based Access Control / RBAC)](#5-matriks-kontrol-akses-berbasis-peran-role-based-access-control--rbac)
6. [Bongkar 12 Modul Inti Government Portal (Deep Dive Tabs)](#6-bongkar-12-modul-inti-government-portal-deep-dive-tabs)
   - [Tab 1: Overview (`GovOverview`) — Agregasi Metrik Ekosistem](#tab-1-overview-govoverview--agregasi-metrik-ekosistem)
   - [Tab 2: Visitor Identity (`GovVisitors`) — Registri Wisatawan & Protokol Reveal](#tab-2-visitor-identity-govvisitors--registri-wisatawan--protokol-reveal)
   - [Tab 3: Immigration & Stay (`GovImmigration`) — Monitoring Izin Tinggal & Overstay Watch](#tab-3-immigration--stay-govimmigration--monitoring-izin-tinggal--overstay-watch)
   - [Tab 4: Tourist Levy (`GovLevy`) — Ledger Penerimaan & Rekonsiliasi Finansial](#tab-4-tourist-levy-govlevy--ledger-penerimaan--rekonsiliasi-finansial)
   - [Tab 5: Merchant Network (`GovMerchants`) — Akreditasi Pedagang & Kill Switch](#tab-5-merchant-network-govmerchants--akreditasi-pedagang--kill-switch)
   - [Tab 6: Service Transactions (`GovTransactions`) — Log Pertukaran Data Berbasis Tujuan](#tab-6-service-transactions-govtransactions--log-pertukaran-data-berbasis-tujuan)
   - [Tab 7: Exceptions Queue (`GovExceptions`) — Pusat Resolusi Masalah Path 2](#tab-7-exceptions-queue-govexceptions--pusat-resolusi-masalah-path-2)
   - [Tab 8: Audit & Compliance (`GovAudit`) — Immutable Ecosystem Audit Trail](#tab-8-audit--compliance-govaudit--immutable-ecosystem-audit-trail)
   - [Tab 9: Reports (`GovReports`) — Generator Laporan Kepatuhan & Finansial](#tab-9-reports-govreports--generator-laporan-kepatuhan--finansial)
   - [Tab 10: Access Management (`GovAccess`) — Tata Kelola Akun & Riwayat Pembukaan Data](#tab-10-access-management-govaccess--tata-kelola-akun--riwayat-pembukaan-data)
   - [Tab 11: Configuration (`GovConfig`) — Mesin Kebijakan Dinamis (Policy Engine)](#tab-11-configuration-govconfig--mesin-kebijakan-dinamis-policy-engine)
   - [Tab 12: Culture & Events (`GovCulture`) — Publikasi Edukasi Budaya & Kalender Adat](#tab-12-culture--events-govculture--publikasi-edukasi-budaya--kalender-adat)
7. [Bagaimana Pemerintah Melakukan Verifikasi & Pengawasan (Verification & Oversight Mechanisms)](#7-bagaimana-pemerintah-melakukan-verifikasi--pengawasan-verification--oversight-mechanisms)
   - [A. Verifikasi Kredensial & Validitas Rantai Sertifikat PKI](#a-verifikasi-kredensial--validitas-rantai-sertifikat-pki)
   - [B. Verifikasi Rekonsiliasi Pembayaran Retribusi (Levy Financial Recon)](#b-verifikasi-rekonsiliasi-pembayaran-retribusi-levy-financial-recon)
   - [C. Workflow Penanganan Tiket Pengecualian Path 2 (Assisted Verification Desk)](#c-workflow-penanganan-tiket-pengecualian-path-2-assisted-verification-desk)
   - [D. Deteksi Anomali & Penindakan Kepatuhan Merchant (Compliance Enforcement)](#d-deteksi-anomali--penindakan-kepatuhan-merchant-compliance-enforcement)
8. [Arsitektur Alur Data (Data Flow Architecture)](#8-arsitektur-alur-data-data-flow-architecture)
9. [Keterhubungan Trilateral: Government Portal <-> Turis App <-> Merchant App](#9-keterhubungan-trilateral-government-portal---turis-app---merchant-app)
10. [Integrasi dengan Arsitektur Repositori ezsign-core (Web2-Web3 Backbone)](#10-integrasi-dengan-arsitektur-repositori-ezsign-core-web2-web3-backbone)
11. [Kesimpulan & Roadmap Implementasi Pemerintah](#11-kesimpulan--roadmap-implementasi-pemerintah)

---

## 1. Executive Summary: Peran Government Portal dalam Ekosistem

Di dalam ekosistem **Bali Tourist ID**, **Government Portal** (dioperasikan oleh Badan Pengelola Pariwisata Bali / *Bali Tourism Authority* bekerja sama dengan Direktorat Jenderal Imigrasi dan Badan Pendapatan Daerah) bertindak sebagai **Pusat Gravitasi Kepercayaan (Trust Anchor & Regulatory Engine)**.

Jika Turis App adalah *Dompet Privasi (Holder)* dan Merchant App adalah *Pihak Pemverifikasi (Verifier)*, maka Government Portal memegang enam fungsi kedaulatan utama:
1. **Issuer Kredensial Digital & Penjamin Keabsahan Paspor:** Memelihara konektivitas ke Master List ICAO CSCA untuk memastikan ePassport wisatawan mancanegara diverifikasi dengan standar kriptografi global.
2. **Mesin Kebijakan Dinamis (Dynamic Policy Engine):** Menentukan hak akses data per kategori merchant (*Hotel, Rental Kendaraan, Kafe, eSIM, Tur*) melalui matriks kebijakan ketat (*Allowed, Conditional, Prohibited*).
3. **Pusat Rekonsiliasi Retribusi Pariwisata (Levy Settlement Ledger):** Memantau arus penerimaan resmi retribusi pariwisata (Rp 150.000 per wisatawan) secara real-time dari berbagai gateway pembayaran.
4. **Regulator & Pengawas Merchant (Merchant Authorisation & Kill Switch):** Mengakreditasi bisnis yang boleh beroperasi, membatasi template tujuan akses, dan memiliki wewenang menangguhkan (*suspend*) atau mencabut (*revoke*) izin merchant bermasalah secara instan.
5. **Pusat Resolusi Pengecualian Path 2 (Exception Resolution Hub):** Mengelola antrean insiden verifikasi digital (kegagalan pembacaan chip, liveness di bawah ambang batas, paspor manual) dan mengoordinasikan meja bantuan (*Assisted Verification Desk*) 24 jam di Bandara Internasional I Gusti Ngurah Rai.
6. **Penjaga Rekam Jejak Audit Tanpa Manipulasi (Tamper-Evident Auditor):** Mencatat setiap aktivitas pertukaran data, pembayaran, perubahan kebijakan, dan insiden pengungkapan data terbatas ke dalam log audit terpadu.

---

## 2. Prinsip Desain: Pengawasan Tanpa Pengintaian (Oversight without Surveillance)

Pemerintah sering kali menghadapi dilema antara keamanan wilayah dan hak privasi wisatawan. Prototipe Bali Tourist ID memecahkan masalah ini dengan mengadopsi prinsip fundamental: **Oversight without Surveillance (Pengawasan Tanpa Pengintaian)**:

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│             PRINSIP DESAIN: OVERSIGHT WITHOUT SURVEILLANCE                       │
├─────────────────────────────────────────────────┬────────────────────────────────┤
│            YANG DILAKUKAN PEMERINTAH            │    YANG DIHINDARI PEMERINTAH   │
│                 (LEGAL OVERSIGHT)               │         (MASS SURVEILLANCE)    │
├─────────────────────────────────────────────────┼────────────────────────────────┤
│ • Memantau volume agregat wisatawan aktif       │ • Tidak melacak lokasi GPS     │
│ • Memastikan retribusi terbayar lunas           │ • Tidak memetakan rute harian  │
│ • Membatasi merchant agar tidak fotokopi paspor │ • Tidak menyimpan foto wajah   │
│ • Mengawasi kepatuhan tujuan akses data         │ • Tidak memegang biometrik     │
│ • Menyediakan jalur bantuan saat sistem gagal   │ • Tidak melabeli turis 'fraud' │
│ • Audit ketat pejabat yang membuka data masker  │ • Tidak membuka nomor paspor   │
└─────────────────────────────────────────────────┴────────────────────────────────┘
```

### Pilar Privasi dalam Government Portal:
1. **Zero-Biometric Operational Storage:** Dashboard operasional pemerintah **sama sekali tidak memiliki akses** ke template biometrik matematika wajah maupun arsip foto selfie wisatawan.
2. **Field-Level Data Masking by Default:** Semua nomor paspor, tanggal lahir, dan nomor Tourist ID disamarkan secara default (contoh: `BTID-••••-••••-0938`, paspor `••••••789`).
3. **Privilege Escalation Protocol:** Pembukaan data yang disamarkan (*Unmasking/Reveal*) hanya dapat dilakukan oleh peran tertentu, wajib menyertakan alasan (*purpose*), nomor referensi perkara (*case ref*), dan langsung memicu notifikasi permanen di audit log.
4. **Bahasa Netral Pengecualian (Neutral Exception Language):** Sistem tidak pernah melabeli wisatawan sebagai "tersangka penipu" atau "ilegal". Semua kegagalan dicatat netral sebagai *Technical Exception* atau *Additional Review Required*.

---

## 3. Daftar Seluruh Kebutuhan Sistem Government Portal (Technical Requirements)

Untuk mengimplementasikan Government Portal ke dalam arsitektur backend & frontend enterprise siap pakai (*production-ready*), dibutuhkan spesifikasi teknis berikut:

### 3.1 Kebutuhan Infrastruktur Server & Cloud
- **High-Availability Web Application:** Dashboard admin berbasis Next.js / React Enterprise yang berjalan di atas cluster Kubernetes (K8s) dengan perlindungan WAF (Web Application Firewall).
- **Backend API Gateway:** Fastify / Go-based Microservices berlatensi rendah untuk melayani ribuan request transaksi merchant dan sinkronisasi status izin tinggal imigrasi.
- **Message Broker & Queue Manager:** Cluster **RabbitMQ** atau Apache Kafka untuk memproses event audit, antrean notifikasi pengecualian (*exceptions*), dan aliran data rekonsiliasi retribusi secara asinkron.
- **Relational & Ledger Database:**
  - PostgreSQL 16+ dengan ekstensi enkripsi kolom (pgcrypto) untuk data master merchant dan registri turis.
  - Append-only immutability log database (contoh: PostgreSQL dengan TimescaleDB atau Ledger DB terdesentralisasi berbasis Hyperledger Besu) untuk tabel `audit` dan `levyLedger`.
- **KMS / HSM (Hardware Security Module):** FIPS 140-2 Level 3 HSM (atau HashiCorp Vault Transit Engine) untuk mengelola kunci privat sertifikat Root CA Pemerintah Bali guna menandatangani kredensial BTID dan akreditasi merchant.

### 3.2 Kebutuhan Integrasi Sistem Eksternal
- **ICAO PKD (Public Key Directory) Synchronization Worker:**
  - Worker otomatis yang mengunduh dan memvalidasi LDIF/Master List Country Signing CA (CSCA) dari direktori ICAO secara berkala (harian).
  - Validasi Certificate Revocation List (CRL) dan status Online Certificate Status Protocol (OCSP).
- **Simulated / Live Immigration Gateway:**
  - Konektor terenkripsi mTLS (*mutual TLS*) ke sistem Direktorat Jenderal Imigrasi (SIMKIM) untuk menyinkronkan data perlintasan pelabuhan udara DPS (Nomor e-VOA, tanggal kedatangan, izin tinggal maksimum).
- **Banking Settlement & Core Payment Switch:**
  - Koneksi API ISO 20022 / Snap BI ke Bank Persepsi (BPD Bali / Bank Mandiri / payment gateway mitra) untuk memvalidasi rekonsiliasi pembayaran retribusi QRIS dan kartu internasional.

### 3.3 Kebutuhan Keamanan & Audit Kepatuhan
- **Multi-Factor Authentication (MFA):** Wajib menggunakan Hardware Security Key (FIDO2 / WebAuthn YubiKey) atau TOTP Authenticator untuk setiap login pejabat pemerintah.
- **Field-Level Encryption (FLE):** Enkripsi simetris AES-256-GCM pada level basis data untuk kolom data sensitif seperti nomor paspor asli dan tanggal lahir.

---

## 4. Struktur Model Data & Manajemen State Global

Di dalam file prototype, state Government Portal dikelola secara terpusat melalui React Context `Ctx` dalam objek `initialState()`:

```typescript
interface GovState {
  roleId: 'ops' | 'finance' | 'merchant' | 'exception' | 'admin' | 'auditor';
  tab: 'overview' | 'visitors' | 'immigration' | 'levy' | 'merchants' | 
       'culture' | 'transactions' | 'exceptions' | 'audit' | 'reports' | 
       'access' | 'config';
  officer: string; // Default: 'Ayu Pradnyani'
}
```

### Kumpulan Entitas Data Global yang Dikelola:
1. **`merchants` (`MERCHANTS[]`):** Array data pelaku usaha (ID, Nama, Kategori, Status Akreditasi, Status Verifikasi, Staf Operasional, Tanggal Kedaluwarsa Kredensial, Template Izin, Volume Transaksi, Jumlah Exception).
2. **`policy` (`DEFAULT_POLICY`):** Matriks kebijakan akses data per kategori merchant (`hotel`, `car`, `cafe`, `esim`, `tour`) yang mengatur 18 atribut data (`allowed`, `conditional`, `prohibited`).
3. **`levyLedger` (`SEED_LEVY[]`):** Buku kas rekonsiliasi retribusi pariwisata (Nomor Kuitansi `LVY-XXXXX`, Masked Tourist ID, Payment Provider, Nominal IDR, Timestamp ISO, Status Pembayaran, Status Rekonsiliasi).
4. **`exceptions` (`SEED_EXCEPTIONS[]`):** Antrean tiket anomali verifikasi dan operasional (ID Kasus `EXC-XXXX`, Jenis Anomali, Tingkat Keparahan `high|medium|low`, Timestamp, Rujukan `ref`, Status Penanganan, Nama Peninjau, Rekomendasi Solusi, Konteks Insiden).
5. **`audit` (`SEED_AUDIT[]`):** Buku besar riwayat audit immutable (Nomor Referensi `AUD-XXXXX`, Timestamp, Aktor, Organisasi, Peran, Aksi, Tujuan Akses, Record ID yang Disentuh, Hasil Operasi).
6. **`requests` & `transactions`:** Riwayat transaksi pertukaran atribut antara merchant dan wisatawan yang disetujui atau ditolak secara agregat.

---

## 5. Matriks Kontrol Akses Berbasis Peran (Role-Based Access Control / RBAC)

Tidak ada satu pejabat pun yang memiliki akses mutlak tanpa batas. Government Portal mengimplementasikan pemisahan tugas ketat (*Segregation of Duties*) melalui 6 peran resmi (`GOV_ROLES`):

| Kode Peran | Nama Jabatan Resmi (*Official Title*) | Hak Akses Tab yang Terbuka | Hak Buka Masker (*Can Reveal*) | Fokus Tugas Utama |
|---|---|---|:---:|---|
| `ops` | **Tourism Operations Officer** | overview, visitors, immigration, levy, merchants, culture, transactions, exceptions, reports | **TIDAK** | Operasional umum ekosistem pariwisata harian dan pemantauan arus wisatawan. |
| `finance` | **Levy Finance Officer** | overview, levy, transactions, reports | **TIDAK** | Audit penerimaan keuangan, rekonsiliasi bank, dan manajemen kegagalan pembayaran retribusi. |
| `merchant`| **Merchant Compliance Officer** | overview, merchants, culture, transactions, exceptions, audit, reports | **TIDAK** | Pengawasan kepatuhan pedagang, penyelidikan kuota request, dan sanksi penangguhan akses. |
| `exception`| **Identity Exception Reviewer** | overview, visitors, immigration, exceptions, audit | **YA** | Peninjauan insiden gagal verifikasi, verifikasi dokumen paspor manual, dan investigasi komplain privasi. |
| `admin` | **System Administrator** | *Semua 12 Tab* (termasuk access & config) | **YA** | Pemeliharaan sistem, manajemen role akses pejabat, dan konfigurasi matriks regulasi. |
| `auditor` | **Auditor** | overview, audit, reports | **TIDAK** | Pemeriksaan kepatuhan independen, forensik jejak audit, dan verifikasi integritas data. |

### Aturan Keamanan Khusus (*Special Security Rules*):
- Hak pembukaan data masker (`reveal: true`) **hanya diberikan kepada 2 peran**: `exception` (Reviewer Identitas) dan `admin` (Administrator Sistem).
- Pejabat keuangan (`finance`) dan pejabat operasional biasa (`ops`) **dilarang keras** melihat nomor paspor asli atau tanggal lahir wisatawan.
- Pejabat auditor (`auditor`) memiliki akses baca murni (*read-only*) ke log audit dan generator laporan, tanpa wewenang mengubah konfigurasi atau menyetujui transaksi.

---

## 6. Bongkar 12 Modul Inti Government Portal (Deep Dive Tabs)

Berikut adalah bedah teknis menyeluruh dari ke-12 tab antarmuka pada Government Portal:

```
┌────────────────────────────────────────────────────────────────────────┐
│                      GOVERNMENT PORTAL - 12 MODUL                      │
├────────────────────────────────────────────────────────────────────────┤
│ [1. Overview]     [2. Visitors]     [3. Immigration]   [4. Levy]       │
│ [5. Merchants]    [6. Transactions] [7. Exceptions]    [8. Audit]      │
│ [9. Reports]      [10. Access]      [11. Config]       [12. Culture]   │
└────────────────────────────────────────────────────────────────────────┘
```

---

### Tab 1: Overview (`GovOverview`) — Agregasi Metrik Ekosistem

Dashboard utama pemantauan ekosistem secara makro (*High-Level Operational Dashboard*):

#### Metrik Kunci yang Ditampilkan (10 Kartu GStat):
1. **Tourist IDs issued today:** Jumlah identitas BTID yang diterbitkan hari ini (Nilai baseline demo: 1.287 + penambahan dinamis jika wisatawan baru onboarded, tren +8.2% vs kemarin).
2. **Active verified visitors:** Total wisatawan terverifikasi yang saat ini berada di Bali (18.942 kredensial aktif).
3. **Passport authentication success rate:** Tingkat keberhasilan verifikasi keaslian kriptografis paspor dalam 24 jam terakhir (**98.4%**).
4. **Tourist Levy paid:** Jumlah wisatawan yang melunasi retribusi hari ini (1.231 + status sesi live).
5. **Levy collected:** Total dana retribusi terkumpul dari buku kas ledger (Format Rupiah: Rp 1.050.000.000+).
6. **Participating merchants:** Jumlah merchant terakreditasi aktif (4 bisnis aktif, 1 pending review).
7. **Verification requests:** Volume transaksi permintaan data oleh merchant dalam 24 jam terakhir (6.842+ permintaan).
8. **Visitor approval rate:** Rasio persetujuan konsen oleh wisatawan (**94%** disetujui vs 6% ditolak).
9. **Failed or expired transactions:** Jumlah transaksi yang kedaluwarsa atau gagal (27+ transaksi).
10. **Open exceptions:** Jumlah tiket anomali yang membutuhkan peninjauan pejabat (Indikator warna: rose jika > 6 kasus).

#### Visualisasi Data Analitik:
- **Registrations & Levy Settlement (`LineChart`):** Tren 7 hari penerbitan ID vs pembayaran retribusi pariwisata.
- **Identity Verification Outcomes (`Donut Chart`):** 98.4% Selesai tanpa hambatan (*Verified*), 14 kasus butuh tinjauan tambahan (*Additional Review*), 7 kasus belum selesai (*Incomplete*).
- **Visitors by Nationality (`BarRows`):** Distribusi negara asal (Australia 412, UK 301, Jerman 224, Belanda 188, Singapura 161, Prancis 143, Lainnya 512).
- **Service Usage by Category (`BarRows`):** Beban layanan terpopuler (Kafe/Payments 3.908, Hotel Check-in 1.284, eSIM 771, Rental Mobil 462, Cek Usia 604, Tur 229).
- **Merchant Participation by Category (`BarRows`):** Jumlah sebaran bisnis per kategori di seluruh Bali.

---

### Tab 2: Visitor Identity (`GovVisitors`) — Registri Wisatawan & Protokol Reveal

Registri identitas digital wisatawan terdaftar dengan kontrol kerahasiaan ketat:

#### Fitur Pencarian Multi-Kunci:
- Input pencarian cerdas (`q`) yang mampu menyaring secara instan berdasarkan:
  - Masked Tourist ID: `BTID-••••-••••-0938`
  - Nama Wisatawan: `Wilson`
  - Kode Kuitansi Retribusi: `LVY-77402`
  - Nomor Referensi Transaksi: `TX-448102`

#### Tampilan Tabel Registri:
Kolom tabel menampilkan: Tourist ID (monospaced), Nama Lengkap, Kebangsaan, Status Kredensial (*Active / Suspended*), Status Retribusi (*Paid / Pending / Failed*), dan tombol aksi `Open record`.

#### Modal Rekam Medis Wisatawan (`Visitor Record Modal`):
Ketika record wisatawan aktif (James Wilson) dibuka, antarmuka menyajikan 3 panel data:
1. **Status Kredensial & Paspor:** Status verifikasi identitas, status autentikasi paspor, negara penerbit (United Kingdom), masa berlaku kredensial (18 Jan 2027), status retribusi, dan indikator pengecualian aktif (0 kasus).
2. **Status Keimigrasian Terkoneksi:** Kelas visa (e-VOA B1), pelabuhan masuk (Bandara Ngurah Rai), tanggal kedatangan (09 Agustus 2026), tanggal batas izin tinggal, dan sisa hari izin tinggal.
3. **Protokol Pembukaan Data Terbatas (`Restricted Fields Reveal Protocol`):**
   - **Kondisi Default:** Nomor paspor, tanggal lahir, tanggal kedaluwarsa dokumen, dan referensi imigrasi dalam keadaan **tertutup bintang (masked)**.
   - **Hak Akses:** Tombol `Reveal restricted fields` hanya muncul jika role pejabat memiliki kewenangan (`role.reveal === true`). Jika tidak berwenang, muncul badge abu-abu: *"Not permitted for this role"*.
   - **Formulir Justifikasi Wajib:** Pejabat wajib mengisi dua data sebelum masker dibuka:
     - *Access Purpose (Dropdown):* Levy reconciliation enquiry, Identity exception review, Merchant complaint investigation, atau Visitor-initiated privacy report.
     - *Case Reference (Input):* Nomor tiket investigasi resmi (contoh: `REF-2026-0811`).
   - **Eksekusi & Audit:** Mengklik `Confirm and reveal` akan membuka nomor paspor (`GBR ••••••789`), tanggal lahir (`12 May 1988`), dan tanggal kedaluwarsa dokumen. Sistem **secara otomatis menulis log audit tidak terhapus**:
     `audit({ actor: 'Ayu Pradnyani', action: 'Revealed restricted visitor fields', purpose: form.purpose, record: TOURIST.touristIdMasked, result: 'Access granted · case REF-2026-0811' })`.
   - **Jaminan Privasi:** Panel menegaskan: *"Biometric template: Not available in operations"* dan *"Face image: Not available in operations"*.

---

### Tab 3: Immigration & Stay (`GovImmigration`) — Monitoring Izin Tinggal & Overstay Watch

Modul pengawasan masa tinggal wisatawan asing secara preventif tanpa pelacakan fisik:

#### Metrik Keimigrasian:
- Total wisatawan dalam masa izin tinggal valid: **18.942 orang**.
- Wisatawan yang izin tinggalnya berakhir $\le$ 5 hari: **895 orang** (*Eligible for an extension reminder*).
- Permohonan perpanjangan visa dalam proses: **342 aplikasi**.
- Jumlah kelas visa aktif di Bali: **4 kelas visa**.

#### Komponen Analisis & Distribusi:
- **Donut Chart Komposisi Visa:** e-VOA B1 (11.840 turis / 62.5%), Bebas Visa Kunjungan BVK (3.920 turis / 20.7%), Visa Kunjungan B211A (2.410 turis / 12.7%), dan KITAS Tinggal Terbatas (772 ekspatriat / 4.1%).
- **BarRows Time Remaining on Permitted Stay:**
  - Berakhir dalam 1–2 hari: 284 orang.
  - Berakhir dalam 3–5 hari: 611 orang.
  - Berakhir dalam 6–10 hari: 1.204 orang.
  - Berakhir dalam 11–20 hari: 3.388 orang.
  - Lebih dari 20 hari: 13.455 orang.
- **Tabel Stays Ending Soonest:** Daftar wisatawan yang mendekati masa kedaluwarsa visa, diurutkan dari sisa hari paling sedikit. Wisatawan dengan sisa hari $\le$ 7 hari secara otomatis memiliki status `Reminder queued` (notifikasi otomatis dikirimkan ke Turis App mereka untuk mengurus perpanjangan sebelum jatuh tempo).
- **Prinsip Netralitas Hukum:** Panel menegaskan bahwa mendekati batas waktu izin tinggal adalah proses administratif normal dan **tidak pernah dilabeli sebagai tindak pidana pelanggaran**.

---

### Tab 4: Tourist Levy (`GovLevy`) — Ledger Penerimaan & Rekonsiliasi Finansial

Pusat kendali dan audit retribusi pariwisata Bali (Perda Bali No. 6 Tahun 2023):

#### Ringkasan Kas Retribusi (Status GStat):
- Status Transaksi: **Paid** (Hijau toska), **Pending** (Kuning amber), **Failed** (Merah rose), **Refunded** (Ungu), **Exempt** (Abu-abu netral).
- Total Penerimaan Kas Terkumpul: Terkalkulasi otomatis dari buku kas `levyLedger` (contoh: `Rp 1,050,000,000`).

#### Buku Kas Transaksi Retribusi (`Levy Ledger Table`):
Menampilkan seluruh catatan transaksi pembayaran secara mendetail:
- *Reference:* Kode pembayaran unik (`LVY-77402`).
- *Tourist ID:* Nomor identitas tersamar pemohon (`BTID-••••-••••-2210`).
- *Provider:* Kanal pembayaran (Kartu Kredit Internasional, Dompet Digital, QRIS Bandara).
- *Amount:* Nominal retribusi (Rp 150.000 atau Rp 0 untuk kasus pembebasan/exempt).
- *Timestamp:* Waktu pembayaran presisi hingga detik.
- *Status:* Paid, Pending, Failed, Refunded, Exempt.
- *Reconciliation Status:*
  - `Reconciled`: Dana kliring di bank cocok 100% dengan kuitansi sistem.
  - `Awaiting settlement`: Menunggu dana masuk dari payment gateway mitra.
  - `Exception`: Kegagalan debet rekening atau selisih pembukuan.
  - `Reconciliation exception`: Transaksi berhasil di sisi turis namun belum terakui di rekening penampung kas daerah.

#### Aksi Manajemen Keuangan:
- Filter status transaksi (*All, Paid, Pending, Failed, Refunded, Exempt*).
- Tombol `Export`: Mengunduh ekstrak rekonsiliasi keuangan untuk pelaporan Badan Pemeriksa Keuangan (BPK) atau Bapenda.
- Tombol `View Receipt`: Membuka salinan kuitansi digital untuk verifikasi audit.

---

### Tab 5: Merchant Network (`GovMerchants`) — Akreditasi Pedagang & Kill Switch

Pusat tata kelola dan penegakan regulasi pelaku usaha mitra ekosistem:

#### Metrik Jaringan Pedagang:
- Bisnis berstatus **Active** (4 merchant).
- Bisnis berstatus **Pending** (1 merchant: Bali Adventure Tours).
- Bisnis berstatus **Suspended** (0 merchant default).
- Bisnis berstatus **Revoked** (0 merchant default).
- Total Insiden Pelanggaran Pedagang (*Merchant Exceptions*): Terkalkulasi otomatis.

#### Tabel Inventaris Pedagang:
Menampilkan data lengkap: Nama Bisnis, Kategori Usaha, Merchant ID (`MCH-XXXX`), Status Verifikasi Dokumen Legalitas, Status Otorisasi Akses, Jumlah Template Tujuan Diizinkan, Tanggal Kedaluwarsa Kredensial Kriptografis Usaha, Jumlah Akun Staf Kasir, Volume Pemindaian, dan Jumlah Kasus Pengecualian.

#### Modal Peninjauan Pedagang & Tindakan Kepatuhan (`Merchant Review Modal`):
Ketika baris pedagang diklik, pejabat pemerintah dapat melakukan aksi-aksi strategis:
1. **Pengaturan Template Akses yang Diizinkan (*Permitted Request Templates*):**
   - Pejabat dapat mengaktifkan atau menonaktifkan template tujuan akses data per merchant hanya dengan sekali klik (contoh: Menambah/menghapus template `hotel_checkin`, `age_check`, `stay_validity`).
   - Setiap perubahan template langsung memicu audit log dan membatasi opsi yang muncul di Merchant App pedagang bersangkutan.
2. **Audit Jejak Akses Staf Merchant:** Menampilkan daftar nama kasir/staf front desk yang terdaftar beserta perannya (`Front Desk Agent`, `Rental Agent`, `Supervisor`).
3. **Eksekusi Penegakan Kepatuhan (Compliance Action Buttons):**
   - `Approve demo merchant`: Menyetujui pendaftaran bisnis baru (mengubah status dari `pending` ke `active`).
   - `Suspend access` (**Kill Switch Ekosistem**): Menangguhkan izin akses bisnis seketika. Merchant yang disuspend langsung **diblokir dari membuat permintaan data baru** ke Tourist App.
   - `Restore access`: Memulihkan status merchant yang telah menyelesaikan investigasi sanksi.
   - `Rotate credential`: Memperbarui pasangan kunci kriptografi merchant dan memperpanjang masa berlaku kredensial hingga 1 tahun ke depan.
   - `Revoke credential`: Mencabut izin usaha secara permanen dari ekosistem identitas. Bisnis wajib mendaftar ulang dari awal jika ingin bergabung kembali.
4. **Konfirmasi Tindakan & Akuntabilitas:** Setiap tombol penindakan memicu modal konfirmasi yang mewajibkan pencatatan nama pejabat penindak dan jabatannya ke dalam audit trail permanen.

---

### Tab 6: Service Transactions (`GovTransactions`) — Log Pertukaran Data Berbasis Tujuan

Pengawasan agregat atas transaksi pertukaran data antara wisatawan dan pedagang:

#### Karakteristik Teknis:
- **Zero Centralized Plaintext Storage:** Modul ini mencatat **bahwa pertukaran data terjadi**, tujuan pertukaran, dan status persetujuan wisatawan. Nilai data pribadi wisatawan (seperti tanggal lahir atau nomor paspor) **tidak disimpan terpusat** di database pemerintah pada tabel transaksi ini.
- **Data Kolom:**
  - *Reference:* Nomor transaksi konsen (`TX-XXXXXX`).
  - *Merchant:* Nama bisnis peminta data.
  - *Purpose:* Tujuan akses berbasis template yang disetujui pemerintah.
  - *Staff:* Nama petugas kasir/front desk yang melayani.
  - *Items Shared:* Jumlah atribut data yang diserahkan wisatawan (contoh: 6 atribut).
  - *Timestamp:* Waktu transaksi presisi.
  - *Outcome:* Status persetujuan (*Approved by visitor* [badge hijau] vs *Rejected by visitor* [badge merah]).
- **Filter Berdasarkan Merchant:** Pejabat dapat menyaring riwayat transaksi per pelaku usaha untuk mengidentifikasi lonjakan request mencurigakan.

---

### Tab 7: Exceptions Queue (`GovExceptions`) — Pusat Resolusi Masalah Path 2

Inilah **Pusat Komando Jalur Cadangan (Path 2)**. Setiap kali terjadi kegagalan sistem pada Tourist App atau Merchant App, tiket pengecualian otomatis masuk ke antrean ini:

#### Klasifikasi Tingkat Keparahan (*Severity Levels*):
1. **High Severity (Merah Rose):**
   - Contoh Kasus: Sertifikat Document Signer paspor tidak dapat divalidasi ke CSCA (`EXC-4471`), lonjakan request merchant abnormal 4.2x di atas rata-rata kategori (`EXC-4451`).
   - Tindakan: Investigasi segera oleh *Identity Exception Reviewer*.
2. **Medium Severity (Kuning Amber):**
   - Contoh Kasus: Pembacaan chip NFC gagal 3x berturut-turut (`EXC-4468`), skor pencocokan wajah di bawah ambang batas 85% (`EXC-4462` skor 71.4%), kredensial merchant akan kedaluwarsa dalam 30 hari (`EXC-4455`), risiko duplikasi registrasi dokumen (`EXC-4443`).
   - Tindakan: Verifikasi dokumen manual atau bantuan reposisi NFC.
3. **Low Severity (Abu-abu / Ink):**
   - Contoh Kasus: Pembayaran retribusi ditolak oleh bank pemroses (`EXC-4459`), pemindaian berulang terhadap token Dynamic QR yang telah kedaluwarsa (`EXC-4448`).
   - Tindakan: Pemantauan sistem atau instruksi retry pembayaran.

#### Workflow Penanganan Tiket Pengecualian:
Ketika tiket diklik, muncul modal kerja resolusi:
- Menampilkan rincian: Severity, Waktu kejadian, Status terkini (*Additional review required / Verification incomplete / Technical exception*), Petugas yang ditugaskan (*Assigned Reviewer*), Konteks teknis error, dan Rekomendasi langkah berikutnya (*Next Step*).
- **Aksi Pejabat Peninjau:**
  1. `Assign to me`: Pejabat mengunci tiket atas nama dirinya sendiri (status berubah menjadi *Under review*).
  2. `Close as resolved`: Menutup tiket setelah kendala teknis atau dokumen diselesaikan.
  3. `Offer assisted verification`: Mengeskalasi kasus ke meja bantuan fisik bandara (*Assisted Verification Desk*) agar wisatawan diarahkan membawa paspor fisik ke petugas konter kedatangan.

---

### Tab 8: Audit & Compliance (`GovAudit`) — Immutable Ecosystem Audit Trail

Buku besar audit terpadu yang memantau setiap denyut nadi aktivitas di dalam ekosistem:

#### Format Struktur Log Audit:
Setiap baris audit merekam 9 atribut kritis:
1. `Reference`: Nomor tiket audit unik berformat `AUD-XXXXX`.
2. `Timestamp`: Waktu ISO presisi hingga detik.
3. `Actor`: Nama individu yang melakukan aksi (contoh: *Ayu Pradnyani*, *James Wilson*, *Kadek Sari*, atau *System*).
4. `Organisation`: Asal instansi aktor (*Bali Tourism Authority*, *Visitor*, *Bali Ocean Resort*).
5. `Role`: Peran resmi aktor (*Tourism Operations Officer*, *Tourist*, *Front Desk Agent*, *Service*).
6. `Action`: Tindakan spesifik (contoh: *Credential issued*, *Approved data request*, *Revealed restricted visitor fields*, *Suspended merchant access*).
7. `Purpose`: Alasan legal pelaksanaan tindakan (*Identity onboarding*, *Hotel check-in*, *Levy reconciliation enquiry*, *Compliance action*).
8. `Record`: ID data yang disentuh (Nomor Tourist ID tersamar, Merchant ID, atau Kode Transaksi).
9. `Result`: Hasil tindakan (*Completed*, *Issued*, *Approved*, *Access granted*, *Access suspended*).

#### Mesin Pencari & Ekspor Audit:
- Input pencarian global untuk menyaring aktor, instansi, tindakan, atau nomor record.
- Tombol `Export`: Mengunduh berkas ekstraksi audit resmi untuk keperluan pembuktian hukum dan pemeriksaan kepatuhan regulasi.

---

### Tab 9: Reports (`GovReports`) — Generator Laporan Kepatuhan & Finansial

Generator laporan resmi teragregasi untuk keperluan pelaporan berkala pimpinan daerah:

#### 6 Jenis Laporan Standar Ekosistem:
1. **Daily levy settlement (`r1`):** Laporan harian retribusi lunas, tertunda, gagal, dan pengembalian dana (*refund*) beserta status kliring perbankan.
2. **Visitor identity summary (`r2`):** Agregasi statistik keberhasilan autentikasi paspor, tingkat kelulusan liveness, dan sebaran kewarganegaraan.
3. **Merchant accountability (`r3`):** Evaluasi kinerja kepatuhan merchant, volume pemindaian, rasio persetujuan konsen, dan histori insiden pelanggaran.
4. **Consent and disclosure (`r4`):** Analisis jenis atribut data apa saja yang paling sering diminta oleh industri dan rasio penolakan wisatawan per tujuan akses.
5. **Exception review (`r5`):** Evaluasi durasi penyelesaian tiket pengecualian identitas dan beban kerja petugas reviewer.
6. **Access management (`r6`):** Audit berkala atas seluruh insiden pembukaan data bertopeng (*reveal events*) oleh pejabat pemerintah.

#### Fitur Ekspor & Visualisasi Laporan:
- Modal preview menampilkan ringkasan baris data (*Rows*), periode waktu (*24h / Weekly / Monthly*), kelengkapan data (100%), dan kurva grafik tren volume.
- Dilengkapi dengan *Machine Readable Report Band* untuk validasi integritas arsip dokumen:
  `REPORT<<BALI<TOURIST<ID<<DEMO<EXTRACT<<<<<<<<<`
  `PERIOD<20260805<20260811<<ROWS<001284<<<<<<<<<<`

---

### Tab 10: Access Management (`GovAccess`) — Tata Kelola Akun & Riwayat Pembukaan Data

Modul tata kelola keamanan internal dan audit akuntabilitas pejabat negara:

#### Komponen Utama:
1. **Matriks Otorisasi Peran Pemerintah (Role Authorization Matrix Table):**
   - Menampilkan tabel silang antara 6 Peran Pejabat (`GOV_ROLES`) dengan 12 Tab Navigasi (`GOV_TABS`).
   - Kolom penanda centang hijau menunjukkan tab mana saja yang boleh dibuka oleh masing-masing jabatan.
   - Kolom badge khusus: Penanda peran mana saja yang memiliki hak *Can reveal* (membuka masker data paspor).
   - Tombol `Switch`: Memungkinkan pengujian simulasi pergantian peran secara instan untuk presenter demonstrasi.
2. **Daftar Peran Staf Merchant Terakreditasi:** Menampilkan standardisasi jabatan staf merchant yang diakui sistem (`MERCHANT_ROLES`: *Front Desk Agent, Rental Agent, Merchant Supervisor, Compliance Officer, Merchant Administrator*).
3. **Log Insiden Pembukaan Data Rahasia (*Restricted Field Access Events Table*):**
   - Merekam secara khusus setiap kali ada pejabat yang menekan tombol `Reveal restricted fields` di Tab 2.
   - Menampilkan: Nama Pejabat & Jabatan, Alasan Pengaksesan (*Purpose*), Nomor Perkara Kasus (*Record/Case Ref*), dan Cap Waktu Kejadian.

---

### Tab 11: Configuration (`GovConfig`) — Mesin Kebijakan Dinamis (Policy Engine)

Jantung regulasi ekosistem. Dari tab ini, pemerintah menetapkan aturan main hukum yang langsung berlaku secara real-time ke seluruh Turis App dan Merchant App:

#### 1. Konfigurasi Matriks Permintaan Data (Data Request Policy Matrix):
- Mengatur izin akses terhadap 16 atribut data (`POLICY_ATTRS`) untuk 5 kategori merchant (`CAT_LABEL`):
  - `hotel`: Akomodasi
  - `car`: Rental Kendaraan
  - `cafe`: Restoran / Kafe / F&B
  - `esim`: Provider Telekomunikasi
  - `tour`: Operator Tur Wisata
- **Tiga Tingkat Status Akses (Three Policy Tones):**
  - **`allowed` (Hijau toska):** Merchant diizinkan meminta data ini secara default karena relevan dengan layanan primer.
  - **`conditional` (Kuning amber):** Merchant hanya boleh meminta atribut ini jika diatur oleh regulasi daerah tambahan (pada Turis App akan muncul badge peringatan kebijakan).
  - **`prohibited` (Merah rose):** Merchant dilarang keras meminta data ini. Field ini otomatis dicoret dan disembunyikan dari Merchant App.
- **Penguncian Biometrik Permanen (*Biometric Lock*):**
  - Atribut `biometric` berstatus **`Prohibited — locked`** secara permanen untuk seluruh kategori. Tombol pengubah dinonaktifkan (*disabled*) dan tidak dapat diubah oleh peran admin sekalipun.

#### 2. Penyesuaian Tarif Retribusi Pariwisata (Levy Configuration):
- Input dinamis besaran tarif retribusi pariwisata (default: Rp 150.000).
- Pilihan tombol preset cepat: `Rp 150,000`, `Rp 200,000`, `Rp 250,000`.
- **Dampak Real-Time:** Mengubah nilai tarif di modul ini seketika mengubah nominal tagihan yang muncul pada layar Turis App (`ScrLevy` & `ScrLevyPay`).

#### 3. Konfigurasi Masa Retensi Data & Waktu Sesi (Retention & Session TTL):
- *Accommodation record retention:* 30 hari (diterapkan pada registrasi hotel check-in).
- *Rental record retention:* Masa sewa kendaraan + 90 hari.
- *Age verification retention:* Hanya hasil boolean (tidak ada penyimpanan data).
- *Consent receipt availability:* Tersimpan di dompet wisatawan tanpa batas waktu (*indefinitely*).
- *Dynamic QR token lifetime:* Tepat **45 detik**.
- *Merchant request handshake lifetime:* Tepat **3 menit**.

---

### Tab 12: Culture & Events (`GovCulture`) — Publikasi Edukasi Budaya & Kalender Adat

Pusat diseminasi nilai budaya dan mitigasi konflik norma adat antara wisatawan dan masyarakat Bali:

#### Metrik Keterlibatan Budaya:
- Modul edukasi terbit: **5 modul** (`CULTURE.length`).
- Persentase wisatawan menyelesaikan seluruh materi: **34.8%** dari total wisatawan yang membuka orientasi.
- Agenda upacara adat diterbitkan: **12 agenda kegiatan** (`EVENTS.length`).
- Progres edukasi wisatawan demo (James Wilson): Terkoneksi live (`tourist.culture.length / 5`).

#### Rasionalitas Penempatan Fitur Budaya di Platform Identitas:
1. *Menjangkau wisatawan sebelum mendarat:* Materi edukasi disematkan langsung di alur pembayaran visa dan retribusi, bukan di brosur kertas yang sering dibuang.
2. *Mencegah pelanggaran di tempat suci:* Edukasi etiket kain kamen pura dan sesajen canang sari menekan 80%+ pemicu ketersinggungan masyarakat lokal.
3. *Pemerataan arus kunjungan:* Mempublikasikan kalender upacara mengalihkan konsentrasi wisatawan dari destinasi padat ke upacara desa adat yang ramah pengunjung.

#### Manajemen Kalender Budaya & Peringatan Penutupan Wilayah:
- Tabel kurasi kalender acara: Tanggal, Nama Upacara, Jenis Acara (*Island Ceremony, Temple Anniversary, Arts & Festival, Lunar Observance*), Lokasi Wilayah, dan Dampak Wisatawan.
- **Sakelar Publikasi Dinamis (`Publish / Hide Toggle`):** Pejabat dapat menyembunyikan atau menampilkan acara ke Turis App dengan tombol `Published / Hidden`. Setiap klik memicu audit log resmi.
- **Deteksi Penutupan Total Wilayah (*Island-wide Closure*):** Untuk hari raya besar seperti **Nyepi (`ev11`)**, sistem otomatis menyematkan badge peringatan merah: *"Island-wide closure — Visitors must remain indoors for the full day. The airport closes entirely"*.

---

## 7. Bagaimana Pemerintah Melakukan Verifikasi & Pengawasan (Verification & Oversight Mechanisms)

Bagian ini membedah mekanisme logika teknis yang dijalankan oleh Government Portal dalam melakukan verifikasi dan pengawasan terhadap seluruh entitas ekosistem:

```
┌───────────────────────────────────────────────────────────────────────────────────┐
│              MEKANISME VERIFIKASI & PENGAWASAN GOVERNMENT PORTAL                  │
└───────────────────────────────────────────────────────────────────────────────────┘

 [A. VALIDASI KREDENSIAL PASPOR & TRUST ANCHOR]
  Pemerintah mengelola Master List Sertifikat CSCA Resmi (ICAO PKD)
  ├── Unduh sertifikat publik Document Signer (DS) dari kedutaan/negara penerbit
  ├── Verifikasi validitas rantai X.509 Certificate Chain
  └── Publikasi Root Public Key Otoritas Bali ke Turis App untuk signing BTID
        │
        ▼
 [B. REKONSILIASI PENERIMAAN RETRIBUSI FINANSIAL]
  Pusat Ledger membandingkan 3 titik data secara otomatis:
  ├── Titik 1: Kuitansi digital yang diterbitkan sistem (LVY-XXXXX)
  ├── Titik 2: Mutasi kas rekening penampung bank persepsi (BPD Bali)
  └── Titik 3: Status klaim pembayaran di Turis App
  Evaluasi: Selisih data? ──► Memicu tiket rekonsiliasi exception di Tab Levy
        │
        ▼
 [C. WORKFLOW PENANGANAN TIKET PENGECUALIAN PATH 2]
  Turis App / Merchant mengalami kegagalan teknis (NFC / Face / Cert)
  ├── Sistem membuat tiket EXC-XXXX dengan status 'Additional review required'
  ├── Pejabat 'Identity Exception Reviewer' mengunci tiket ('Assign to me')
  ├── Pejabat meninjau kualitas capture dan rujukan dokumen paspor
  └── Pejabat menerbitkan rujukan meja bantuan bandara (Assisted Verification AST-XXXXX)
        │
        ▼
 [D. DETEKSI ANOMALI & PENEGAKAN SANKSI MERCHANT (KILL SWITCH)]
  Mesin pengawas memantau pola transaksi merchant secara real-time:
  ├── Kuota request melebihi batas wajar (> 4x median kategori bisnis)
  ├── Permintaan atribut di luar template yang disetujui
  └── Pejabat Compliance menekan tombol 'Suspend access'
      └── Status merchant berubah menjadi 'suspended'
      └── Turis App otomatis memblokir pemindaian QR merchant bersangkutan
```

---

### A. Verifikasi Kredensial & Validitas Rantai Sertifikat PKI
Pemerintah tidak bertindak sebagai pembuat paspor, melainkan sebagai **Pihak Penjamin Validitas Rantai Kepercayaan (PKI Trust Validator)**:
1. Portal memelihara repositori lokal sertifikat induk negara-negara dunia (*Country Signing Certification Authority / CSCA Master List*).
2. Ketika Turis App melakukan *Passive Authentication* pada ePassport, Turis App mencocokkan sertifikat Document Signer (DS) terhadap Master List yang disinkronkan dari server Government Portal.
3. Setelah ePassport terbukti sah secara kriptografis, kunci privat Otoritas Pariwisata Bali menandatangani kredensial **Bali Tourist ID (BTID)** menggunakan format standar internasional *W3C Verifiable Credentials*.

---

### B. Verifikasi Rekonsiliasi Pembayaran Retribusi (Levy Financial Recon)
Untuk mencegah kebocoran pendapatan asli daerah (*PAD*), modul `GovLevy` menjalankan algoritma rekonsiliasi tiga arah (*Three-Way Matching*):
1. **Sisi Wisatawan:** Mengirimkan bukti bayar dengan nomor referensi kuitansi `LVY-XXXXX`.
2. **Sisi Payment Gateway (Kartu/Dompet/QRIS):** Mengirimkan callback laporan transaksi sukses (*Settlement Webhook*).
3. **Sisi Rekening Kas Daerah (Bank BPD Bali):** Mengonfirmasi mutasi kredit kliring perbankan.
- Jika ketiga data cocok, status rekonsiliasi diset menjadi **`Reconciled`**.
- Jika terjadi kegagalan gateway namun dana terpotong, atau sebaliknya, status ditandai **`Reconciliation exception`** dan otomatis dilaporkan ke antrean investigasi pejabat keuangan (`finance`).

---

### C. Workflow Penanganan Tiket Pengecualian Path 2 (Assisted Verification Desk)
Ketika seorang wisatawan mengalami kegagalan mandiri di Path 1 (misal: paspor fisik tidak memiliki chip RFID / `nonEpassport`, atau skor pencocokan wajah hanya 71.4% karena pencahayaan bandara yang buruk):
1. **Penerbitan Tiket Otomatis:** Sistem membuat tiket di `GovExceptions` (contoh: `EXC-4462`).
2. **Triase oleh Petugas:** Pejabat peninjau identitas (*Identity Exception Reviewer*) melihat tiket di antrean, memeriksa riwayat kegagalan teknis, dan mengeset status menjadi *Under review*.
3. **Eskalasi ke Konter Fisik Bandara:** Petugas mengklik `Offer assisted verification`. Wisatawan di Turis App menerima petunjuk arah ke konter kedatangan 24 jam dengan kode tiket `AST-XXXXX`.
4. **Verifikasi Tatap Muka:** Petugas konter mencocokkan paspor fisik dengan wajah wisatawan secara langsung menggunakan alat pembaca stasioner (*ePassport Desktop Reader*).
5. **Penerbitan Kredensial Manual:** Petugas menekan tombol verifikasi manual di portal, menerbitkan kredensial BTID aktif, dan menutup tiket pengecualian sebagai *Resolved*.

---

### D. Deteksi Anomali & Penindakan Kepatuhan Merchant (Compliance Enforcement)
Government Portal dilengkapi dengan mesin pengawas perilaku merchant (*Merchant Behavioral Anomaly Detector*):
1. **Pendeteksian Frekuensi Request Abnormal:** Jika sebuah bisnis (misal: *Island Drive Car Rental / MCH-2087*) melakukan permintaan data dengan rasio 4.2x lipat di atas median bisnis sejenis, sistem otomatis memicu tiket `EXC-4451` berstatus *High Severity*.
2. **Pengecekan Masa Berlaku Kredensial:** Sistem mendeteksi kredensial merchant yang akan kedaluwarsa dalam 30 hari dan memberi peringatan rotasi kunci.
3. **Eksekusi Sakelar Pemutus Akses (Instant Kill Switch):**
   - Jika merchant terbukti melakukan pelanggaran privasi (misal: memaksa turis memberikan nomor paspor padahal dilarang regulasi), petugas menekan tombol `Suspend access`.
   - Mutasi state terjadi seketika: `merchants.find(m => m.id === id).status = 'suspended'`.
   - Seluruh sesi kasir merchant dibatalkan, dan jika ada turis yang memindai QR di toko tersebut, Tourist App langsung menolak permintaan dengan pesan error resmi otoritas pariwisata.

---

## 8. Arsitektur Alur Data (Data Flow Architecture)

### Alur Data Sinkronisasi Kebijakan Dinamis (GovConfig -> Turis App & Merchant)

```
[Pejabat Admin di GovConfig]
            │
            │── 1. Ubah Atribut 'dob' untuk Kategori 'hotel' (Allowed ──► Prohibited)
            ▼
[Policy Engine State Mutator]
            │
            │── 2. Perbarui State: policy.hotel.dob = 'prohibited'
            │── 3. Tulis Event ke Log Audit: "Changed policy: Accommodation · Exact date of birth → prohibited"
            ▼
[Ecosystem Event Bus / Webhook Dispatcher]
            │
            ├────────────────────────────────────────┬────────────────────────────────────────┐
            ▼                                        ▼                                        ▼
    [Merchant App: Hotel]                   [Turis App: Wisatawan]                   [Audit Ledger]
   Kadek Sari buka menu check-in          James Wilson terima request              Tercatat permanen:
   - Field 'dob' dicoret otomatis         - Field 'dob' tidak pernah               Actor: Ayu Pradnyani
   - Tidak dapat dipilih kasir              muncul di layar consent                Action: Policy Change
```

---

### Alur Data Pembukaan Data Masker Terbatas (Restricted Field Reveal Protocol)

```
[Identity Exception Reviewer]                 [GovVisitors Modal UI]                 [PostgreSQL / Secure Vault]
            │                                           │                                         │
            │── 1. Buka Detail Rekor Wisatawan ────────►│                                         │
            │                                           │── 2. Data Tampil Ter-masking ──────────►│
            │                                           │      (BTID-••••-0938, Paspor ••••••789) │
            │── 3. Klik 'Reveal restricted fields' ────►│                                         │
            │                                           │                                         │
            │◄── 4. Tampilkan Form Justifikasi ─────────│                                         │
            │       (Input Tujuan Akses & No. Kasus)    │                                         │
            │                                           │                                         │
            │── 5. Kirim Form: 'REF-2026-0811' ────────►│── 6. Validasi Hak Akses (RBAC) ────────►│
            │                                           │                                         │
            │                                           │── 7. Permintaan Dekripsi Kolom ────────►│
            │                                           │◄── 8. Return Nilai Asli (GBR ••••••789) ─│
            │                                           │                                         │
            │                                           │── 9. Dispatch Audit Log Event ─────────►│ [Audit DB]
            │                                           │      (Aktor, Kasus, Tujuan, Waktu)      │
            │◄── 10. Tampilkan Data Plaintext (Sesi) ───┴─────────────────────────────────────────┴─────────
```

---

## 9. Keterhubungan Trilateral: Government Portal <-> Turis App <-> Merchant App

Government Portal tidak berdiri sendiri, melainkan mengendalikan hubungan timbal balik trilateral secara terpadu:

```
                               ┌────────────────────────────────────────────────────────┐
                               │                    GOVERNMENT PORTAL                   │
                               │           (Trust Anchor, Policy Engine, Auditor)       │
                               └───────────────────┬────────────────┬───────────────────┘
                                                   │                │
                         Pembaruan Kebijakan Data, │                │ Akreditasi Bisnis,
                         Nominal Retribusi & Audit │                │ Template Izin & Kill Switch
                                                   ▼                ▼
                                  ┌───────────────────────┐  ┌───────────────────────┐
                                  │       TURIS APP       │  │     MERCHANT APP      │
                                  │ (Holder / Wisatawan)  │  │ (Verifier / Pedagang) │
                                  └───────────┬───────────┘  └───────────┬───────────┘
                                              │                          │
                                              └────────── Dynamic QR ────┘
                                                           (Handshake 45s)
```

### Skenario Interaksi Trilateral:
1. **Skenario Perubahan Tarif Retribusi:**
   - Pejabat pemerintah di Tab `config` menaikkan retribusi dari Rp 150.000 menjadi Rp 200.000.
   - Sinyal konfigurasi disiarkan via WebSocket/Event Bus.
   - Layar pembayaran Turis App (`ScrLevyPay`) seketika memperbarui tagihan menjadi Rp 200.000 tanpa perlu update aplikasi di app store.
2. **Skenario Penindakan Merchant Liar:**
   - Merchant terbukti meminta fotokopi paspor secara ilegal di konter fisik.
   - Wisatawan melaporkan kejadian lewat fitur *Report unexpected access* di Turis App (`ScrPrivacy`).
   - Laporan masuk ke antrean `GovExceptions` di Government Portal.
   - Pejabat Compliance menekan tombol `Suspend access` di Tab `merchants`.
   - Merchant App di konter toko tersebut langsung terkunci, dan kasir tidak dapat memindai Tourist ID turis manapun.
3. **Skenario Penyelesaian Overstay:**
   - Tab `immigration` mendeteksi izin tinggal wisatawan tersisa 2 hari.
   - Notifikasi pengingat otomatis dikirim ke widget izin tinggal di Turis App (`ScrVisa`).
   - Wisatawan mengurus perpanjangan visa secara online atau datang ke kantor imigrasi sebelum terkena denda administratif.

---

## 10. Integrasi dengan Arsitektur Repositori ezsign-core (Web2-Web3 Backbone)

Prototipe mock-up ini secara arsitektural sangat selaras untuk diimplementasikan di atas fondasi repositori **`ezsign-core`** yang sudah ada di workspace:

```
┌──────────────────────────────────────────────────────────────────────────────────────────┐
│                   INTEGRASI BALI TOURIST ID KE DALAM EZSIGN-CORE                         │
└──────────────────────────────────────────────────────────────────────────────────────────┘

  [GOVERNMENT PORTAL UI / API]
  ├── Tab GovConfig    ──► Konfigurasi Policy Engine
  ├── Tab GovExceptions──► Tiket Peninjauan Identitas
  └── Tab GovAudit     ──► Log Kepatuhan Ekosistem
            │
            ▼
  [MIDDLEWARE FASTIFY & RABBITMQ] (Direktori: `middleware/`)
  ├── Menerima event audit dari Turis App, Merchant, dan Pejabat Pemerintah
  ├── Antrean pesan asinkron melalui RabbitMQ exchange
  └── Validasi payload skema audit sesuai standar EIP-712
            │
            ▼
  [TX-WORKER & HASHICORP VAULT KMS] (Direktori: `tx-worker/`)
  ├── Mengambil event audit dari queue RabbitMQ
  ├── Meminta penandatanganan kriptografis ke HashiCorp Vault KMS (Transit Engine)
  └── Menyusun transaksi blockchain ber-signature sah otoritas pemerintah
            │
            ▼
  [SMART CONTRACT HYPERLEDGER BESU QBFT] (Direktori: `smartcontract/`)
  ├── Modular Transparent Upgradeable Proxy (EIP-1967)
  ├── Mencatat Hash Integritas Audit Log ke Smart Contract
  └── Memastikan bukti persetujuan konsen wisatawan tidak dapat diubah (Tamper-Proof)
```

### Rincian Pemetaan Komponen `ezsign-core`:
1. **Modul `middleware/` (Fastify Core Domain):**
   - Menjadi backend utama Government Portal untuk mengekspos endpoint REST API: `/gov/visitors`, `/gov/levy/reconcile`, `/gov/merchants/suspend`, dan `/gov/policy/update`.
   - Menerima log audit dari fungsi JavaScript `audit()` dan mempublikasikannya ke message broker RabbitMQ agar operasi frontend tidak mengalami lag/latensi.
2. **Modul `tx-worker/` (Transaction Worker & Vault KMS):**
   - Mengonsumsi antrean event audit dan rekonsiliasi retribusi dari RabbitMQ.
   - Menandatangani digest transaksi menggunakan private key Otoritas Pariwisata Bali yang tersimpan aman di HashiCorp Vault KMS (tanpa pernah mengekspos private key ke memori server).
3. **Modul `smartcontract/` (Hyperledger Besu QBFT Blockchain):**
   - Node validator konsorsium dijalankan oleh Otoritas Pariwisata, Ditjen Imigrasi, Bapenda Bali, dan Perwakilan Asosiasi Hotel (PHRI).
   - Menjamin bahwa riwayat audit penindakan merchant, pengungkapan data rahasia (*reveal events*), dan kuitansi retribusi berstatus **abadi, sah di mata hukum, dan mustahil dimanipulasi secara sepihak oleh oknum internal**.

---

## 11. Kesimpulan & Roadmap Implementasi Pemerintah

Bedah teknis terhadap **Government Portal** pada prototype `bali-tourist-id Mock Up Final Version.html` membuktikan bahwa portal ini dirancang dengan standar tata kelola pemerintahan digital (*GovTech*) kelas dunia:

1. **Kedaulatan & Kepercayaan Penuh:** Pemerintah memegang kendali penuh atas akreditasi merchant, legalitas izin tinggal, dan tarif retribusi tanpa perlu menjadi "negara pengintai" (*surveillance state*).
2. **Mitigasi Risiko Hukum Kebocoran Data:** Dengan meniadakan penyimpanan biometrik di server operasional dan menyamarkan data paspor secara default, pemerintah mematuhi sepenuhnya ketentuan **Undang-Undang Perlindungan Data Pribadi (UU PDP No. 27 Tahun 2022)**.
3. **Kesiapan Menghadapi Kegagalan (Path 2 Resilience):** Keberadaan antrean `GovExceptions` dan alur *Assisted Verification Desk* memastikan bahwa wisatawan yang mengalami kendala teknologi tidak terlantar di bandara, menjaga citra keramahan pariwisata Indonesia.
4. **Sinergi Sempurna dengan Repositori `ezsign-core`:** Arsitektur Web2 Fastify/RabbitMQ yang dikombinasikan dengan worker penandatangan Vault KMS dan blockchain privat Hyperledger Besu QBFT adalah pasangan teknologi ideal untuk merealisasikan rancangan prototipe ini ke fase produksi skala nasional.

---
*Dokumen ini disusun sebagai spesifikasi teknis dan analisis bedah mendalam sistem Bali Tourist ID (Bagian: Government Portal).*
