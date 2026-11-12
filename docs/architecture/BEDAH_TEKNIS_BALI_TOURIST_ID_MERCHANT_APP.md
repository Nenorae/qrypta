# BEDAH TEKNIS ARSITEKTUR BALI TOURIST ID
## Bagian: Merchant App (Relying Party, Purpose-Bound Requests, & Zero-Photocopy Engine)

---

## DAFTAR ISI
1. [Executive Summary: Peran Merchant App dalam Ekosistem](#1-executive-summary-peran-merchant-app-dalam-ekosistem)
2. [Prinsip Desain: Paradigma Tanpa Fotokopi (Zero-Photocopy Paradigm)](#2-prinsip-desain-paradigma-tanpa-fotokopi-zero-photocopy-paradigm)
3. [Daftar Seluruh Kebutuhan Sistem Merchant App (Technical Requirements)](#3-daftar-seluruh-kebutuhan-sistem-merchant-app-technical-requirements)
4. [Struktur Model Data & Manajemen State Kasir (Counter State)](#4-struktur-model-data--manajemen-state-kasir-counter-state)
5. [Matriks Peran Staf Pedagang (Merchant Staff Roles & Privileges)](#5-matriks-peran-staf-pedagang-merchant-staff-roles--privileges)
6. [Bongkar Seluruh Alur & Layar Navigasi Merchant App (State Machine Deep Dive)](#6-bongkar-seluruh-alur--layar-navigasi-merchant-app-state-machine-deep-dive)
   - [Layar 1: Login & Otorisasi Staf (`MerchantLogin`)](#layar-1-login--otorisasi-staf-merchantlogin)
   - [Layar 2: Shell & Bilah Navigasi Konter (`MShell` & `MerchantCounter`)](#layar-2-shell--bilah-navigasi-konter-mshell--merchantcounter)
   - [Layar 3: Beranda Konter Operasional (`MerchantHome`)](#layar-3-beranda-konter-operasional-merchanthome)
   - [Layar 4: Pemindai Kode QR Dinamis (`MerchantScan`)](#layar-4-pemindai-kode-qr-dinamis-merchantscan)
   - [Layar 5: Pemilihan Template Berbasis Tujuan (`MerchantTemplates`)](#layar-5-pemilihan-template-berbasis-tujuan-merchanttemplates)
   - [Layar 6: Menunggu Persetujuan Wisatawan (`MerchantWaiting`)](#layar-6-menunggu-persetujuan-wisatawan-merchantwaiting)
   - [Layar 7: Hasil Verifikasi & Integrasi Vertikal (`MerchantResult`)](#layar-7-hasil-verifikasi--integrasi-vertikal-merchantresult)
   - [Layar 8: Riwayat Permintaan & Kebijakan Data (`MerchantActivity`)](#layar-8-riwayat-permintaan--kebijakan-data-merchantactivity)
   - [Layar 9: Manajemen Akun Staf & Kredensial Bisnis (`MerchantStaff`)](#layar-9-manajemen-akun-staf--kredensial-bisnis-merchantstaff)
7. [Deep Dive: Integrasi Vertikal Layanan Industri (Vertical Service Integrations)](#7-deep-dive-integrasi-vertikal-layanan-industri-vertical-service-integrations)
   - [A. Integrasi Perhotelan: Check-In Mandiri & Ekspor Payload PMS](#a-integrasi-perhotelan-check-in-mandiri--ekspor-payload-pms)
   - [B. Integrasi Rental Kendaraan: Verifikasi SIM Terpisah (Decoupled Driving Check)](#b-integrasi-rental-kendaraan-verifikasi-sim-terpisah-decoupled-driving-check)
   - [C. Integrasi Kafe & Hiburan: Verifikasi Batas Usia Tanpa Tanggal Lahir (Age Gate)](#c-integrasi-kafe--hiburan-verifikasi-batas-usia-tanpa-tanggal-lahir-age-gate)
   - [D. Integrasi Telekomunikasi: Registrasi SIM Digital Berbasis Trust Anchor](#d-integrasi-telekomunikasi-registrasi-sim-digital-berbasis-trust-anchor)
8. [Matriks Template Permintaan Resmi Pemerintah (Authorized Request Templates)](#8-matriks-template-permintaan-resmi-pemerintah-authorized-request-templates)
9. [Bagaimana Merchant Melakukan Verifikasi Kredensial (Verification Mechanics)](#9-bagaimana-merchant-melakukan-verifikasi-kredensial-verification-mechanics)
10. [Arsitektur Alur Data (Data Flow Architecture) Merchant App](#10-arsitektur-alur-data-data-flow-architecture-merchant-app)
11. [Keterhubungan Trilateral: Merchant App <-> Turis App <-> Government Portal](#11-keterhubungan-trilateral-merchant-app---turis-app---government-portal)
12. [Integrasi dengan Arsitektur Repositori ezsign-core (Web2-Web3 Backbone)](#12-integrasi-dengan-arsitektur-repositori-ezsign-core-web2-web3-backbone)
13. [Kesimpulan & Manfaat Bisnis bagi Industri Pariwisata Bali](#13-kesimpulan--manfaat-bisnis-bagi-industri-pariwisata-bali)

---

## 1. Executive Summary: Peran Merchant App dalam Ekosistem

Di dalam ekosistem **Bali Tourist ID**, **Merchant App** beroperasi sebagai pihak **Penerima Kredensial & Pemverifikasi Terpercaya (Relying Party / Verifier)** dalam kerangka Segitiga Kepercayaan (*Decentralized Trust Triangle*).

Merchant App dirancang khusus untuk para pelaku industri pariwisata di Bali—mencakup perhotelan (*accommodation*), persewaan kendaraan bermotor (*vehicle rental*), restoran dan kelab pantai (*food & beverage*), penyedia jasa telekomunikasi (*eSIM/telecom*), serta biro perjalanan wisata (*tour operator*).

### Transformasi Fundamental Operasional Bisnis:
1. **Menggantikan Fotokopi Paspor Manual:** Menghilangkan praktik kuno memfotokopi fisik buku paspor tamu di meja resepsionis hotel atau meja konter rental mobil yang selama ini menjadi sumber utama kebocoran data identitas turis di Bali.
2. **Permintaan Terikat Tujuan (Purpose-Bound Requests):** Merchant dilarang meminta data secara acak atau sembarangan. Setiap kali meminta data, merchant wajib memilih template tujuan resmi yang telah disetujui oleh Badan Otoritas Pariwisata (*Bali Tourism Authority*).
3. **Persetujuan Eksplisit per Transaksi (Cryptographic Consent Handshake):** Merchant tidak dapat menyedot data secara sepihak. Informasi hanya mengalir ke layar konter setelah wisatawan menekan tombol konfirmasi di Turis App miliknya.
4. **Ketiadaan Akses Tetap (Zero Standing Access):** Merchant hanya memegang data yang diizinkan selama masa retensi layanan berlangsung. Merchant **tidak memiliki standing access** ke akun, lokasi GPS, maupun data perlintasan wisatawan di luar properti bisnisnya.

---

## 2. Prinsip Desain: Paradigma Tanpa Fotokopi (Zero-Photocopy Paradigm)

Selama puluhan tahun, regulasi perhotelan dan sewa kendaraan di Indonesia mewajibkan identifikasi tamu asing. Akibat ketiadaan infrastruktur verifikasi digital, pelaku usaha terpaksa mengarsipkan salinan fotokopi paspor fisik di lemari berkas atau file PDF di komputer konter tanpa enkripsi.

Merchant App Bali Tourist ID menghadirkan **Zero-Photocopy Paradigm**:

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│                   PARADIGMA TRADISIONAL VS BALI TOURIST ID                       │
├─────────────────────────────────────────────────┬────────────────────────────────┤
│         PRAKTIK LAMA (FOTOKOPI FISIK)           │   MERCHANT APP (BALI TOURIST ID)│
├─────────────────────────────────────────────────┼────────────────────────────────┤
│ • Tamu menyerahkan paspor fisik ke kasir        │ • Paspor fisik tetap di saku   │
│ • Resepsionis memfotokopi halaman biodata       │ • Kasir scan Dynamic QR 45 detik│
│ • Fotokopi memuat data sensitif tak relevan:    │ • Hanya menerima klaim yang     │
│   nomor paspor, tanda tangan, tanggal lahir     │   diizinkan regulasi pemda     │
│ • Berkas kertas disimpan di gudang tanpa audit  │ • Jejak transaksi diaudit jelas│
│ • Berkas rawan dicuri, difoto HP, atau bocor   │ • Tidak ada salinan paspor     │
│ • Kafe/bar melihat tanggal lahir saat cek usia  │ • Bar hanya menerima sinyal     │
│                                                 │   "Over 18 — Verified"         │
└─────────────────────────────────────────────────┴────────────────────────────────┘
```

### Manfaat Perlindungan Hukum bagi Pengusaha:
- **Kepatuhan terhadap UU PDP No. 27 Tahun 2022:** Merchant terbebas dari ancaman pidana dan denda administratif kebocoran data pribadi karena sistem tidak lagi menyimpan data mentah paspor (*raw passport images*).
- **Proses Check-In Super Cepat:** Waktu check-in hotel atau sewa mobil dipangkas drastis dari rata-rata 8–12 menit menjadi kurang dari **30 detik**.

---

## 3. Daftar Seluruh Kebutuhan Sistem Merchant App (Technical Requirements)

Untuk mengimplementasikan Merchant App dari prototipe mock-up ke aplikasi bisnis native siap produksi (*Point-of-Sale / Tablet Stand / Web Portal*), dibutuhkan spesifikasi teknis berikut:

### 3.1 Kebutuhan Perangkat Keras (Hardware Requirements)
- **Perangkat Terminal Konter:** Tablet layar sentuh (iPad / Android Tablet 10 inci) atau smartphone konter khusus staf dengan penyangga meja (*kiosk counter stand*).
- **Kamera Pembaca Barcode/QR:** Kamera belakang resolusi minimal 1080p dengan kecepatan pemindaian tinggi (60 fps) atau barcode scanner 2D stasioner berbasis USB/Bluetooth (Honeywell/Zebra).
- **Konektivitas Jaringan:** Koneksi internet stabil (WiFi bisnis atau 4G/5G seluler) dengan latensi kurang dari 200 ms untuk menjamin proses handshake selesai sebelum masa kedaluwarsa token QR (45 detik) berakhir.

### 3.2 Kebutuhan Perangkat Lunak & Antarmuka Integrasi
- **Modul Pemindai Dynamic QR (High-Speed Scanner Engine):**
  - Mesin pembaca kode QR teroptimasi standar ISO/IEC 18004.
  - Parser token berbasis string acak alfanumerik (contoh: `QRT-9X2KL8MPQ1`).
  - Timer anti-kedaluwarsa otomatis yang sinkron dengan jam server NTP Otoritas Pariwisata.
- **Session Handshake & Event Listener:**
  - Protokol komunikasi real-time dua arah (WebSocket atau Server-Sent Events / SSE) antara terminal merchant, gateway ekosistem, dan smartphone wisatawan.
- **Integration Adapter ke Sistem Internal Bisnis:**
  - **Property Management System (PMS) Adapter:** REST API client untuk mengekspor payload data tamu terverifikasi ke sistem perhotelan global (Oracle Opera, Cloudbeds, Guesty, Protel).
  - **Fleet & Rental Management Adapter:** Konektor ke sistem persewaan armada mobil/motor untuk penerbitan digital agreement sewa.
  - **Point of Sale (POS) Adapter:** Konektor ke cash register mesin kasir untuk konfirmasi pembayaran tiket/makanan.

### 3.3 Kredensial Keamanan & Kriptografi Merchant
- **Merchant Business Credential (X.509 Digital Certificate):** Setiap entitas bisnis memegang sertifikat digital resmi yang ditandatangani oleh Root CA Otoritas Pariwisata Bali, berisi atribut `Merchant ID`, `Category`, dan masa berlaku sertifikat (rotasi berkala 1 tahun).
- **Per-Device Staf API Key / Token JWT:** Token sesi staf yang terikat pada nama individu (`staff`) dan peran jabatan (`role`) guna menjamin pertanggungjawaban personal pada setiap tarikan data.

---

## 4. Struktur Model Data & Manajemen State Kasir (Counter State)

Di dalam prototipe, seluruh siklus operasional kasir dikelola melalui sub-state `state.merchant` dan didukung oleh array bisnis global `state.merchants`:

```typescript
interface MerchantCounterState {
  id: string | null;            // Contoh: 'MCH-1042'
  staff: string | null;         // Contoh: 'Kadek Sari'
  role: string | null;          // Contoh: 'Front Desk Agent'
  screen: 'login' | 'home' | 'scan' | 'templates' | 'waiting' | 'result' | 'activity' | 'staff';
  activeRequest: string | null; // ID request transaksi konsen yang sedang aktif
}
```

### Entitas Bisnis Merchant (`MERCHANTS[]`):
Prototipe menyematkan 5 profil entitas bisnis riil mewakili sektor pariwisata unggulan Bali:
1. **`MCH-1042` — Bali Ocean Resort** (Kategori: `hotel` / Seminyak):
   - Staf terdaftar: `Kadek Sari` (*Front Desk Agent*), `Wayan Putra` (*Merchant Supervisor*).
   - Template diizinkan: `hotel_checkin`, `levy_check`, `stay_validity`, `age_check`.
   - Volume historis: 1.284 pemindaian.
2. **`MCH-2087` — Island Drive Car Rental** (Kategori: `car` / Kuta):
   - Staf terdaftar: `Gede Mahendra` (*Rental Agent*), `Ni Luh Ratih` (*Compliance Officer*).
   - Template diizinkan: `vehicle_rental`, `stay_validity`, `age_check`.
   - Volume historis: 462 pemindaian.
3. **`MCH-3311` — Bali Coffee House** (Kategori: `cafe` / Canggu):
   - Staf terdaftar: `Putu Adi` (*Front Desk Agent*).
   - Template diizinkan: `payment_confirm`, `age_check`.
   - Volume historis: 3.908 transaksi pembayaran.
4. **`MCH-4520` — Bali Connect eSIM** (Kategori: `esim` / Bandara Ngurah Rai):
   - Staf terdaftar: `Komang Dewi` (*Merchant Administrator*).
   - Template diizinkan: `esim_activation`, `stay_validity`, `levy_check`.
   - Volume historis: 771 pemindaian.
5. **`MCH-5099` — Bali Adventure Tours** (Kategori: `tour` / Ubud):
   - Staf terdaftar: `Made Surya` (*Merchant Supervisor*).
   - Template diizinkan: `tour_participation`, `age_check`, `emergency_support`.
   - Status: `pending` (Awaiting authority approval).

---

## 5. Matriks Peran Staf Pedagang (Merchant Staff Roles & Privileges)

Sistem menetapkan 5 peran standar staf internal bisnis (`MERCHANT_ROLES`) untuk membatasi wewenang operasional:

| Peran Staf Pedagang | Hak Akses Operasional Kasir | Wewenang Khusus | Batasan Keamanan |
|---|---|---|---|
| **Front Desk Agent** | Scan QR, Create Request, Selesaikan Check-in, Cek Retribusi | Menjalankan operasional harian check-in tamu hotel atau pemesanan kafe | Tidak dapat menyetujui dokumen sewa mobil; tidak dapat mengubah template |
| **Rental Agent** | Scan QR, Create Request Rental, Kirim Permintaan SIM | Memeriksa kelayakan mengemudi dan menyetujui penerbitan perjanjian sewa | Terbatas pada armada kendaraan; tidak dapat mengakses fitur audit internal |
| **Merchant Supervisor** | Akses Penuh Konter, Review Riwayat Transaksi Bisnis | Membatalkan permintaan macet, mengekspor laporan ke sistem PMS properti | Tidak dapat mengubah konfigurasi sertifikat bisnis |
| **Compliance Officer** | Audit Trail Bisnis, Monitoring Insiden Pelanggaran | Meninjau kepatuhan staf terhadap klausul retensi data dan investigasi komplain | Memegang wewenang audit internal berkala (*internal compliance audit*) |
| **Merchant Administrator** | Pengelolaan Akun Staf, Rotasi Kredensial, Pengaturan Template | Mengajukan penambahan template ke Otoritas Pariwisata dan rotasi sertifikat | Menjadi kontak resmi entitas hukum terhadap pemerintah |

---

## 6. Bongkar Seluruh Alur & Layar Navigasi Merchant App (State Machine Deep Dive)

Berikut adalah dekonstruksi teknis dari seluruh alur antarmuka Merchant App dari saat login hingga penyelesaian transaksi:

```
[START: MerchantLogin]
         │
         ▼
[Pilih Bisnis & Staf Role] ──► Otorisasi Berhasil ──► [MShell Counter]
                                                            │
         ┌──────────────────────────────────────────────────┴─────────────────────────────────┐
         ▼                                                  ▼                                 ▼
   [Tab: Counter]                                    [Tab: Activity]                   [Tab: Staff]
   (MerchantHome)                                  (MerchantActivity)                 (MerchantStaff)
         │                                         Log riwayat transaksi              Daftar akun staf
         ├──────────────────────────────┐          kepatuhan & retensi                & sertifikat bisnis
         ▼                              ▼
  [MerchantScan]              [MerchantTemplates]
  Kamera baca token QR        Pilih template resmi
  (Batas waktu 45 detik)      (hotel, car, age, dsb)
         │                              │
         └──────────────┬───────────────┘
                        ▼
               [MerchantWaiting]
               Radar menunggu persetujuan
               wisatawan di Turis App
                        │
         ┌──────────────┴──────────────┐
         ▼                             ▼
  [Wisatawan Menolak]           [Wisatawan Menyetujui]
  Outcome: Rejection            Outcome: Approved
  Data: None (0 bytes)          Data: Payload Terverifikasi
         │                             │
         └──────────────┬──────────────┘
                        ▼
                [MerchantResult]
                Eksekusi layanan:
                ├── Hotel  : Kirim payload ke PMS Room 508
                ├── Rental : Verifikasi SIM & Approve Rental
                └── Kafe   : Banner OVER 18 - VERIFIED
```

---

### Layar 1: Login & Otorisasi Staf (`MerchantLogin`)
- **Tujuan UI/UX:** Memilih identitas bisnis demo dan menetapkan akun staf yang bertanggung jawab di meja konter.
- **Komponen Interaktif:**
  - Pemilihan Profil Bisnis (`state.merchants`): Menampilkan nama, kode merchant, kategori, dan badge status akreditasi (*Active, Suspended, Pending*).
  - Pemilihan Akun Staf Operasional: Avatar inisial nama, nama staf, dan jabatan.
- **Aksi:** Tombol `Open the counter` mengeset state `merchant.id`, `merchant.staff`, dan `merchant.role`, lalu mengarahkan ke layar konter utama.

---

### Layar 2: Shell & Bilah Navigasi Konter (`MShell` & `MerchantCounter`)
- **Header Tetap (Sticky Header):**
  - Ikon kategori bisnis (hotel, car, cafe, sim, tour).
  - Nama resmi perusahaan dan nama staf yang sedang bertugas (contoh: *Bali Ocean Resort · Kadek Sari · Front Desk Agent*).
  - Status Akreditasi Kredensial Bisnis: Badge hijau toska (*Verified · credential active*), merah (*Access suspended*), atau kuning (*Pending review*).
  - Tombol Keluar (*Logout*).
- **Sub-Navigasi 3 Tab:**
  1. `Counter`: Antarmuka operasional kasir harian.
  2. `Activity`: Riwayat transaksi dan audit penarikan data merchant.
  3. `Staff & access`: Direktori staf internal dan detail sertifikat bisnis.
- **Mekanisme Interseptor Suspensi Sanksi Pemerintah:**
  Di dalam fungsi `MerchantCounter()`, sistem menanamkan pengaman otomatis:
  ```javascript
  const blocked = m.status !== 'active' && ['scan', 'templates', 'waiting'].includes(mm.screen);
  useEffect(() => { if (blocked) go('home'); }, [blocked]);
  ```
  Jika pemerintah menangguhkan akses merchant di Government Portal, kasir **seketika terpental kembali ke beranda** dan tidak dapat membuka kamera pemindai maupun mengirimkan permohonan data baru.

---

### Layar 3: Beranda Konter Operasional (`MerchantHome`)
- **Banner Peringatan Penangguhan Akses:** Muncul jika status merchant $\ne$ `active` (contoh: *"Access suspended by the tourism authority — Existing records are unaffected, but no new visitor information can be requested until access is restored"*).
- **4 Kartu Metrik Kasir (`MStat`):**
  - `Verifications today`: Total verifikasi yang dilayani hari ini.
  - `Pending approvals`: Jumlah request yang sedang mengambang menunggu respon turis.
  - `Completed`: Total transaksi sukses (Disetujui atau Pembayaran Berhasil).
  - `Credential expires`: Masa berlaku sertifikat digital bisnis (contoh: *Feb 2027*).
- **Widget Permintaan Tertunda Aktif:** Jika terdapat request yang belum dijawab turis, muncul kartu oranye dengan tombol pintas pembatalan request (`Cancel request`).
- **2 Pintu Masuk Transaksi Konter (Action Cards):**
  1. Tombol Ungu Berornamen Barong: `Scan Tourist ID` (Membuka kamera pemindai).
  2. Tombol Putih Minimalis: `Create a request` (Langsung membuka katalog template resmi).
- **Tabel 5 Aktivitas Terkini:** Menampilkan ringkasan transaksi instan beserta badge status persetujuan (*Approved by visitor* vs *Rejected by visitor*).

---

### Layar 4: Pemindai Kode QR Dinamis (`MerchantScan`)
- **Tujuan UI/UX:** Membaca kode QR satu kali pakai (*one-time dynamic token*) dari layar ponsel wisatawan.
- **Logika Pemindaian & Deteksi:**
  - Viewfinder persegi berlatar belakang gelap dengan bingkai bidik toska dan garis laser vertikal beranimasi (*sweep animation*).
  - Prototipe mensimulasikan penemuan token QR dalam waktu 2.200 ms.
- **Penanganan Kondisi Token Kedaluwarsa (QR Expired Handler):**
  Jika token yang dipindai telah melampaui masa aktif 45 detik, layar pemindai mengunci ke tampilan peringatan:
  - Ikon jam pasir kuning: *"Code expired — The visitor's one-time code is no longer valid. Ask them to refresh it in their app"*.
  - Tombol aksi: `Scan again` atau `Back to the counter`.
- **Hasil Sukses Pemindaian (`phase === 'found'`):**
  - Menampilkan kartu toska: **"Tourist ID detected"**.
  - Rincian Sesi Handshake:
    - *Credential:* Active (Status identitas valid).
    - *Issuer:* Trusted (Diterbitkan resmi oleh Otoritas Bali).
    - *One-time token:* String sesi unik (contoh: `QRT-9X2KL8MPQ1`).
    - *Token expires:* Hitung mundur detik tersisa.
  - Penegasan Privasi Konter: *"No visitor details are shown yet. Choose a purpose and the visitor decides what to share."*
  - Tombol `Request information` mentransisikan ke layar `templates`.

---

### Layar 5: Pemilihan Template Berbasis Tujuan (`MerchantTemplates`)
- **Tujuan UI/UX:** Menyusun berkas permohonan data yang sah secara hukum dan etika privasi.
- **Pemberitahuan Larangan Permintaan Bebas (*Ban on Free-Form Requests*):**
  Panel tegas menyatakan: *"You cannot create a free-form request. Fields are controlled by your merchant category, your staff role and current government policy configuration"*.
- **Katalog Template Tersedia (`templatesFor(state, m)`):**
  Merchant memilih salah satu kartu tujuan yang diizinkan (contoh pada Bali Ocean Resort: *Hotel check-in*, *Tourist Levy verification*, *Permitted stay confirmation*, *Age verification*).
- **Pengaturan Atribut Permintaan:**
  Setelah template dipilih:
  1. **Atribut Wajib (*Always Requested / Core Fields*):** Atribut primer yang harus disertakan. Jika ada atribut wajib yang diblokir oleh pemerintah di Tab Config, atribut tersebut otomatis **dicoret garis merah** dengan badge *"Blocked by policy"*.
  2. **Atribut Opsional (*Optional under configured policy*):** Kotak centang untuk atribut sekunder (contoh: *Passport number*, *Date of birth*, *Arrival date*).
  3. **Klausul Retensi Resmi (*Retention Notice*):** Menampilkan kalimat transparansi hukum yang akan dibaca oleh wisatawan (contoh: *"Retained for 30 days under configured demo accommodation policy"*).
- **Pengiriman Permintaan:**
  Tombol `Send request to visitor` memanggil fungsi arsitektural `buildRequest()`:
  ```javascript
  const req = buildRequest(state, m, tpl, staff, role, extraFields);
  ```
  Request diberi nomor referensi unik `TX-XXXXXX`, cap kedaluwarsa 3 menit, lalu didistribusikan ke Turis App. Layar kasir berpindah ke `waiting`.

---

### Layar 6: Menunggu Persetujuan Wisatawan (`MerchantWaiting`)
- **Tujuan UI/UX:** Menjaga visibilitas kasir saat tamu sedang meninjau rincian permintaan data di ponselnya.
- **Animasi Visual:** Lingkaran konsentris radar ungu berdenyut melingkupi ikon ponsel.
- **Rincian Status:** Menampilkan tujuan permohonan, jumlah atribut yang diminta, nomor transaksi referensi `TX-XXXXXX`, dan waktu kedaluwarsa request (*Expires in 3 minutes*).
- **Sinkronisasi Otomatis:** Hook `useEffect` memantau status `req.status`. Begitu wisatawan menekan tombol di ponselnya (berubah menjadi `approved` atau `rejected`), layar kasir **secara instan bertransisi** ke layar `result`.

---

### Layar 7: Hasil Verifikasi & Integrasi Vertikal (`MerchantResult`)
Inilah puncak interaksi bisnis. Tampilan layar terbagi menjadi dua skenario hasil:

#### Skenario A: Wisatawan Menolak / Request Kedaluwarsa
- Kartu peringatan merah mawar: **"Visitor declined"** atau **"Request expired"**.
- Konfirmasi Privasi: *"You received a rejection result and no visitor information. Data received: None"*.
- Panduan Kasir: Staf dapat menawarkan proses konvensional di konter fisik atau mencoba template tujuan lain (`Try a different purpose`).

#### Skenario B: Wisatawan Menyetujui Transaksi (Approved by Visitor)
- Kartu toska sukses: **"Check-in information received"** atau **"Verified information received"**.
- Daftar atribut terverifikasi ditampilkan rapi dengan badge hijau:
  - *Full name:* James Wilson
  - *Nationality:* United Kingdom
  - *Identity verified:* Verified
  - *Passport authentication:* Authentic — passive authentication passed
  - *Tourist ID validity:* Valid until 18 January 2027
  - *Tourist Levy status:* Paid · LVY-88412
  - *Permitted stay:* Valid — 28 day(s) remaining
- Kuitansi Transaksi: Menampilkan nomor referensi konsen `TX-XXXXXX`, cap waktu persetujuan ISO, dan nama staf kasir yang bertanggung jawab.
- **Sub-Modul Integrasi Vertikal Khusus:** (Dijabarkan rinci pada [Bab 7](#7-deep-dive-integrasi-vertikal-layanan-industri-vertical-service-integrations)).

---

### Layar 8: Riwayat Permintaan & Kebijakan Data (`MerchantActivity`)
- **Tabel Log Permintaan Bisnis:**
  Merekam seluruh transaksi yang pernah dilakukan oleh kasir bisnis tersebut:
  - Nomor referensi konsen (`TX-XXXXXX`).
  - Tujuan permohonan (*Purpose*).
  - Nama staf kasir yang bertugas (*Staff*).
  - Waktu pelaksanaan transaksi (*Time*).
  - Jumlah atribut data yang diserahkan wisatawan (*Items*).
  - Status akhir (*Approved [badge hijau]*, *Rejected [badge merah]*, *Expired [badge abu-abu]*).
- **Prinsip Penyimpanan Data Pedagang (*What We Store Statement*):**
  Panel penegasan hukum dan etika:
  *"Only the attributes the visitor approved, plus the consent reference and timestamp. We never receive biometric templates, live face captures, or full passport chip contents — and we have no standing access to any visitor's record."*

---

### Layar 9: Manajemen Akun Staf & Kredensial Bisnis (`MerchantStaff`)
- **Tabel Akun Staf Konter:** Menampilkan seluruh nama pegawai terdaftar beserta perannya (`Front Desk Agent`, `Supervisor`, dll.) dengan penanda badge ungu *"Signed in"* pada akun yang sedang aktif.
- **Identitas Kredensial Kriptografis Perusahaan:**
  - *Merchant ID:* Kode unik berformat `MCH-XXXX`.
  - *Category:* Kategori usaha terdaftar.
  - *Verification status:* Terverifikasi resmi oleh Otoritas Pariwisata.
  - *Authorisation:* Status otorisasi sistem (*Active*).
  - *Credential expiry:* Tanggal kedaluwarsa sertifikat bisnis (contoh: *14 Feb 2027*).
  - *Approved purposes:* Daftar template resmi yang diizinkan untuk bisnis tersebut.

---

## 7. Deep Dive: Integrasi Vertikal Layanan Industri (Vertical Service Integrations)

Merchant App bukan sekadar aplikasi pemeriksa ID statis, melainkan platform yang memiliki alur kerja (*business workflow*) khusus yang disesuaikan dengan kebutuhan operasional masing-masing sektor industri:

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                      SUB-MODUL INTEGRASI SPESIFIK INDUSTRI                              │
├────────────────────────────┬─────────────────────────────┬──────────────────────────────┤
│    PERHOTELAN / HOTEL      │   RENTAL MOBIL / KENDARAAN  │     KAFE / BEACH CLUB        │
│    (Bali Ocean Resort)     │  (Island Drive Car Rental)  │    (Bali Coffee House)       │
├────────────────────────────┼─────────────────────────────┼──────────────────────────────┤
│ • Alokasi Kamar: Room 508  │ • Evaluasi 3 Pintu Kelayakan│ • Banner OVER 18 - VERIFIED  │
│ • Selesaikan Check-In Tamu │ • Decoupled Driving Check   │ • Zero DOB Disclosed         │
│ • Ekspor Payload JSON PMS: │ • Approval Rental Agreement │ • Konfirmasi Pembayaran QRIS │
│   Opera, Cloudbeds, dsb    │ • Terbit Dokumen: RNT-XXXXXX│   tanpa meminta fotokopi     │
└────────────────────────────┴─────────────────────────────┴──────────────────────────────┘
```

---

### A. Integrasi Perhotelan: Check-In Mandiri & Ekspor Payload PMS
Pada sektor akomodasi (`hotel`), setelah tamu menyetujui template `hotel_checkin`:
1. **Penyelesaian Check-In di Konter:**
   Layar menampilkan nomor kamar yang dialokasikan (contoh: *Room 508*) dan status *Check-in complete*.
2. **Ekspor Payload ke Property Management System (PMS):**
   Staf menekan tombol `Send to property system`. Sistem menghasilkan payload JSON terstandarisasi yang siap dikonsumsi oleh PMS perhotelan global:
   ```json
   {
     "guest": "James Wilson",
     "nationality": "United Kingdom",
     "room": "508",
     "identity": "verified",
     "passport_auth": "verified",
     "levy_status": "paid",
     "consent_ref": "TX-448102",
     "biometrics": null
   }
   ```
3. **Pencatatan Audit Otomatis:**
   Sistem mencatat event audit:
   `audit({ actor: 'Kadek Sari', org: 'Bali Ocean Resort', action: 'Exported check-in record to property system', purpose: 'Hotel check-in', record: 'TX-448102', result: 'Exported — demo PMS' })`.

---

### B. Integrasi Rental Kendaraan: Verifikasi SIM Terpisah (Decoupled Driving Check)
Pada sektor penyewaan kendaraan (`car`), kepemilikan Tourist ID **hanya membuktikan identitas diri, bukan hak mengemudi**. Merchant App memisahkan pemeriksaan ini secara tegas:
1. **Evaluasi Tiga Pintu Kelayakan (*Three-Tier Rental Eligibility*):**
   - *Pintu 1 (Identitas):* Terkonfirmasi lewat Bali Tourist ID (Status: *Verified*).
   - *Pintu 2 (Batas Usia):* Terkonfirmasi usia 18+ (Status: *Confirmed*).
   - *Pintu 3 (Kredensial Mengemudi):* Diperiksa secara independen (Status: *Verified — Category B* vs *Additional verification required*).
2. **Workflow Permintaan SIM Asing:**
   - Jika wisatawan belum menyerahkan SIM, staf menekan tombol `Ask for driving credential`. Turis App menerima notifikasi: *"Please provide or verify your driving credential"*.
   - Wisatawan mengunggah foto SIM nasional atau International Driving Permit (IDP) di Turis App miliknya.
   - Staf rental menekan `Review submitted document`. Jika sesuai ketentuan kategori B, staf menekan verifikasi.
3. **Penerbitan Kontrak Sewa Resmi (*Rental Agreement*):**
   Setelah ketiga pintu berstatus hijau, tombol `Approve the rental` aktif. Staf menyetujui sewa dan sistem menerbitkan bukti digital sewa berformat `RNT-XXXXXX` lengkap dengan rujukan audit `AUD-XXXXX`.

---

### C. Integrasi Kafe & Hiburan: Verifikasi Batas Usia Tanpa Tanggal Lahir (Age Gate)
Untuk restoran, bar malam, kelab pantai, atau kafe (`cafe`), regulasi hanya mewajibkan memastikan pelanggan telah cukup umur (18+ untuk kelab malam atau 21+ untuk minuman beralkohol tertentu):
1. **Banner Visual Hijau Toska:**
   Layar kasir menampilkan kotak besar bertuliskan:
   $$\text{\textbf{OVER 18 — VERIFIED}}$$
   $$\text{\textit{"Only what is needed. Nothing more."}}$$
2. **Ketiadaan Data Sensitif (*Zero-Disclosure Rule*):**
   Panel menegaskan secara transparan kepada kasir:
   *"Not disclosed: exact date of birth, passport number, address, passport photograph"*.
   Kasir tidak pernah melihat tanggal lahir asli tamu. Privasi wisatawan terlindungi mutlak, sementara pelaku usaha memenuhi kewajiban hukum peraturan daerah.

---

### D. Integrasi Telekomunikasi: Registrasi SIM Digital Berbasis Trust Anchor
Pada penyedia telekomunikasi (`esim`), registrasi nomor seluler prabayar wisatawan asing yang sebelumnya mewajibkan pengunggahan foto paspor ke server provider kini disederhanakan:
- Merchant meminta template `esim_activation` (hanya meminta bukti `identity` dan `id_validity`).
- Provider mengaktifkan nomor eSIM secara instan karena identitas turis telah dijamin oleh Root CA Otoritas Bali dan Ditjen Imigrasi, memangkas biaya verifikasi manual dan mencegah penimbunan arsip paspor di server swasta.

---

## 8. Matriks Template Permintaan Resmi Pemerintah (Authorized Request Templates)

Merchant dibatasi oleh 9 template tujuan resmi (`TEMPLATES`). Merchant **tidak dapat meminta atribut di luar koridor template tersebut**:

| ID Template | Nama Label Resmi | Kategori Merchant yang Berhak | Atribut Wajib (*Core Fields*) | Atribut Opsional (*Optional Fields*) | Klausul Retensi Data Resmi Pemerintah |
|---|---|---|---|---|---|
| `hotel_checkin` | **Hotel check-in** | `hotel` | `name`, `nationality`, `id_validity`, `passport_auth`, `levy_status`, `stay_valid` | `passport_number`, `dob`, `arrival`, `departure`, `visa_type`, `stay_expiry` | Disimpan selama 30 hari sesuai kebijakan akomodasi pemda. |
| `vehicle_rental`| **Vehicle rental eligibility** | `car` | `name`, `identity`, `over18`, `id_validity`, `passport_auth`, `driving` | `dob`, `stay_expiry` | Disimpan selama masa sewa kendaraan ditambah 90 hari. |
| `esim_activation`| **eSIM activation** | `esim` | `identity`, `id_validity` | `name`, `nationality`, `passport_auth`, `passport_number`, `stay_expiry` | Disimpan selama durasi paket langganan aktif. |
| `stay_validity` | **Permitted stay confirmation** | `hotel`, `esim`, `car`, `tour` | `stay_valid` | `stay_expiry`, `name` | Hanya hasil boolean. Berkas imigrasi tidak pernah dibagikan. |
| `age_check` | **Age verification** | `hotel`, `car`, `cafe`, `tour`, `esim` | `over18` | `over21` | Hanya hasil verifikasi usia. Tidak ada data yang disimpan di luar referensi transaksi. |
| `tour_participation`| **Tour participation** | `tour` | `name`, `identity`, `id_validity`, `over18` | `nationality`, `emergency_contact`, `levy_status` | Disimpan selama tanggal aktivitas tur ditambah 14 hari. |
| `levy_check` | **Tourist Levy verification** | `hotel`, `esim`, `tour` | `levy_status` | `name` | Hanya hasil status retribusi. Data instrumen pembayaran kartu tidak dibagikan. |
| `payment_confirm`| **Payment confirmation** | `cafe`, `hotel`, `car`, `tour`, `esim` | `payment_confirm` | *(Kosong)* | Konfirmasi pembayaran saja, dikelola oleh penyedia pembayaran berlisensi. |
| `emergency_support`| **Emergency support** | `tour`, `hotel` | `name`, `identity`, `emergency_contact` | `nationality` | Disimpan selama durasi penanganan insiden darurat berlangsung. |

---

## 9. Bagaimana Merchant Melakukan Verifikasi Kredensial (Verification Mechanics)

Bagian ini menguraikan mekanisme kriptografi dan komputasi di balik pemindaian kode QR hingga penerimaan data oleh Merchant App:

```
┌───────────────────────────────────────────────────────────────────────────────────┐
│               MEKANISME VERIFIKASI KREDENSIAL PADA MERCHANT APP                   │
└───────────────────────────────────────────────────────────────────────────────────┘

 [1. PEMINDAIAN DYNAMIC QR]
  Kamera Merchant membaca kode QR di Turis App
  ├── Ekstraksi Payload: String Ephemeral Token 'QRT-XXXXXXXXXX'
  ├── Validasi Format Token & Nonce Keamanan
  └── Cek Masa Berlaku Token: Timestamp Saat Ini <= Waktu Terbit + 45 Detik?
      ├── Kedaluwarsa ──► Tampilkan Error 'Code Expired', Instruksikan Refresh
      └── Valid        ──► Eksekusi Handshake Sesi ke Ecosystem Hub
        │
        ▼
 [2. VALIDASI KREDENSIAL BISNIS MERCHANT]
  Sebelum permohonan diteruskan ke Turis App, Gateway memverifikasi Merchant:
  ├── Cek Status Merchant di Direktori Pemerintah: Apakah 'active'?
  │   └── Jika 'suspended' / 'revoked' ──► Blokir Permintaan Seketika (Kill Switch)
  ├── Cek Masa Berlaku Sertifikat Usaha: credExpiry >= Waktu Saat Ini
  └── Cek Template yang Diminta: Apakah tplId terdaftar di daftar izin merchant?
        │
        ▼
 [3. DISPATCH REQUEST & SELECTIVE DISCLOSURE HANDSHAKE]
  Merchant App mengirimkan paket request terenkripsi ke Turis App:
  ├── Membawa Parameter: Merchant ID, Nama Bisnis, Staf, Template, Atribut
  ├── Turis App menerima notifikasi dan menampilkan Consent Screen
  └── Wisatawan memilih:
      ├── DECLINE ──► Kirim Sinyal Penolakan (0 atribut data diserahkan)
      └── APPROVE ──► Kunci privat Turis App menandatangani paket atribut (EIP-712 / W3C)
        │
        ▼
 [4. PENERIMAAN KLAIM & AUDIT SEALING]
  Merchant App menerima paket data yang telah disetujui:
  ├── Validasi Tanda Tangan Kredensial terhadap Root Public Key Otoritas Bali
  ├── Ekstraksi Atribut ke Antarmuka Kasir (Check-in Hotel / Rental Mobil)
  └── Pengiriman Bukti Konsen ke Ledger Audit Ekosistem (AUD-XXXXX)
```

---

## 10. Arsitektur Alur Data (Data Flow Architecture) Merchant App

### Alur Data Pemindaian QR, Permintaan Template, dan Respon Tamu

```
[Merchant App (Kasir)]              [Ecosystem Relay Hub]                 [Turis App (Ponsel Tamu)]
          │                                   │                                       │
          │── 1. Scan QR Dinamis ─────────────►│◄── Menerbitkan QR Sesi (45s) ─────────│
          │      (Token: `QRT-9X2KL8MPQ1`)    │    (Token: `QRT-9X2KL8MPQ1`)          │
          │                                   │                                       │
          │── 2. Kirim Permintaan Data ──────►│                                       │
          │      Template: hotel_checkin      │── 3. Push Notifikasi Permintaan ─────►│
          │      Core: name, stay, levy       │      "Bali Ocean Resort meminta..."   │
          │      Optional: passport_number    │                                       │
          │                                   │                                       │ Tamu meninjau
          │                                   │                                       │ klausul retensi 30d
          │                                   │                                       │ & rincian data
          │                                   │                                       │
          │                                   │◄── 4. Klik 'Approve & share' ─────────│
          │                                   │    (Atribut disetujui + Signature)    │
          │◄── 5. Terima Payload Terverifikasi─│                                       │
          │      • Guest: James Wilson        │                                       │── Catat di Sharing
          │      • Permitted Stay: Valid      │                                       │   History Wisatawan
          │      • Tourist Levy: Paid         │                                       │
          │                                   │                                       │
          │── 6. Terbitkan Rekor PMS ─────────│── 7. Kirim Log Transaksi Konsen ─────►│ [Gov Audit DB]
          │      (Room 508 / TX-448102)       │      (Aktor, Staf, Merchant, Ref)     │
```

---

### Alur Data Pemutusan Akses Instan (Kill Switch Interceptor Flow)

```
[Pemerintah di GovPortal]            [Ecosystem State Bus]               [Merchant App (Konter Toko)]
           │                                   │                                       │
           │── 1. Pejabat Suspend Merchant ───►│                                       │
           │      (MCH-2087: Sanksi Pelanggaran)│                                       │
           │                                   │── 2. Broadcast Status: 'suspended' ──►│
           │                                   │                                       │
           │                                   │                                       │ Kasir sedang di layar
           │                                   │                                       │ scan / templates
           │                                   │                                       │
           │                                   │                                       │── 3. Interseptor Trigger:
           │                                   │                                       │   blocked === true
           │                                   │                                       │
           │                                   │                                       │◄── 4. Paksa Kembali ke Home
           │                                   │                                       │   Tampilkan Banner Merah
           │                                   │                                       │   "Access Suspended by
           │                                   │                                       │    Tourism Authority"
```

---

## 11. Keterhubungan Trilateral: Merchant App <-> Turis App <-> Government Portal

Merchant App menjadi simpul operasional yang mengikat hak privasi turis dan kepatuhan hukum daerah:

```
                               ┌────────────────────────────────────────────────────────┐
                               │                    GOVERNMENT PORTAL                   │
                               │          (Akreditasi, Template Izin, Kill Switch)      │
                               └───────────────────┬────────────────┬───────────────────┘
                                                   │                │
                          Pengawasan Kuota Request │                │ Matriks Kebijakan Akses
                          & Audit Kepatuhan Sanksi │                │ & Standar Template Resmi
                                                   ▼                ▼
                                  ┌───────────────────────┐  ┌───────────────────────┐
                                  │     MERCHANT APP      │  │       TURIS APP       │
                                  │ (Relying Party / Toko)│  │ (Holder / Wisatawan)  │
                                  └───────────┬───────────┘  └───────────┬───────────┘
                                              │                          │
                                              └────────── Dynamic QR ────┘
                                                     Consent Handshake
                                                   (Zero-Photocopy Flow)
```

### Sinergi Tiga Arah yang Terjadi:
1. **Pencegahan Permintaan Berlebih (*Data Over-Collection Prevention*):**
   Merchant tidak dapat meminta nomor paspor turis di kafe/bar karena Matriks Kebijakan Pemerintah di Tab Config telah mengunci atribut `passport_number` untuk kategori `cafe` pada status **`prohibited`**.
2. **Perlindungan Terhadap Penyalahgunaan Identitas:**
   Jika merchant nakal mencoba meminta data berulang-ulang tanpa transaksi nyata, algoritma anomali di Government Portal otomatis menandai lonjakan tersebut sebagai kasus pengecualian `high severity` (`EXC-4451`).
3. **Pencabutan Akses Sepihak oleh Wisatawan (*Revocation Privilege*):**
   Jika tamu merasa tidak nyaman setelah check-out dari hotel, tamu dapat membuka menu `privacy` di Turis App dan menekan tombol **`Stop future access`**. Sinyal pencabutan ini langsung memutus izin merchant untuk meminta data pembaruan di masa mendatang.

---

## 12. Integrasi dengan Arsitektur Repositori ezsign-core (Web2-Web3 Backbone)

Sama seperti Tourist App dan Government Portal, arsitektur Merchant App dirancang terhubung harmonis dengan repositori **`ezsign-core`**:

```
┌──────────────────────────────────────────────────────────────────────────────────────────┐
│                    INTEGRASI MERCHANT APP KE DALAM EZSIGN-CORE                           │
└──────────────────────────────────────────────────────────────────────────────────────────┘

  [TERMINAL MERCHANT APP (TABLET KASIR)]
  ├── Pemindaian Dynamic QR Wisatawan (45s TTL)
  ├── Handshake Template Permintaan Berbasis Tujuan (hotel_checkin, vehicle_rental)
  └── Penerimaan Payload Konsen yang Ditandatangani Wisatawan
            │
            ▼
  [MIDDLEWARE FASTIFY & RABBITMQ] (Direktori: `middleware/`)
  ├── Endpoint REST API Kasir: `/merchant/request/dispatch` & `/merchant/verify/token`
  ├── Otentikasi Staf Kasir via JWT Token ber-role resmi (Front Desk / Rental Agent)
  └── Publikasi payload audit konsen ke RabbitMQ Exchange: `ezsign.audit.merchant`
            │
            ▼
  [TX-WORKER & HASHICORP VAULT KMS] (Direktori: `tx-worker/`)
  ├── Worker mengambil pesan konsen dari antrean RabbitMQ
  ├── Verifikasi validitas digital signature wisatawan dan merchant credential
  └── Penandatanganan batch audit record via HashiCorp Vault KMS
            │
            ▼
  [SMART CONTRACT HYPERLEDGER BESU QBFT] (Direktori: `smartcontract/`)
  ├── Menyimpan digest hash bukti persetujuan konsen tamu (`TX-XXXXXX`) ke blockchain
  └── Memastikan bukti kesepakatan sewa kendaraan atau check-in hotel sah secara hukum
      dan anti-penyangkalan (Non-Repudiation) di kemudian hari
```

### Rincian Integrasi Komponen `ezsign-core`:
1. **Modul `middleware/`:**
   - Menyediakan API serverless berkecepatan tinggi untuk melayani jutaan transaksi pemindaian QR harian di seluruh hotel dan restoran di Bali.
   - Bertindak sebagai *Policy Enforcement Point (PEP)* yang memvalidasi bahwa atribut yang diminta merchant tidak melanggar aturan yang diset di Government Portal.
2. **Modul `tx-worker/`:**
   - Menghilangkan beban komputasi kriptografi berat dari tablet kasir toko dengan memindahkan proses validasi signature ke background worker asinkron.
3. **Modul `smartcontract/`:**
   - Menghasilkan bukti hukum anti-penyangkalan (*non-repudiation*). Jika terjadi sengketa sewa kendaraan (misal: turis merusak mobil sewaan lalu mengaku tidak pernah menyewa), bukti konsen yang terpatri di blockchain Besu QBFT menjadi alat bukti elektronik yang berkekuatan hukum tetap sesuai UU ITE.

---

## 13. Kesimpulan & Manfaat Bisnis bagi Industri Pariwisata Bali

Bedah teknis terhadap **Merchant App** pada prototype `bali-tourist-id Mock Up Final Version.html` membuktikan bahwa aplikasi ini memberikan lompatan efisiensi bisnis raksasa bagi sektor swasta pariwisata:

1. **Efisiensi Meja Resepsionis & Kasir:**
   Proses check-in hotel dan rental kendaraan yang dulunya lambat dan berbelit-belit kini tuntas dalam hitungan detik (*tap and go*), menghilangkan antrean panjang turis di lobi hotel.
2. **Eliminasi Risiko Hukum Kebocoran Data (Zero Liability):**
   Dengan tidak lagi menyimpan fotokopi paspor fisik maupun arsip file paspor di komputer kantor, pelaku usaha di Bali terbebas 100% dari risiko denda miliaran rupiah akibat pelanggaran Undang-Undang Perlindungan Data Pribadi (UU PDP).
3. **Pemberdayaan Industri Lokal:**
   Ekosistem ini menjamin perlakuan adil (*level playing field*) bagi bisnis lokal Bali. Pelaku usaha mikro (kafe lokal, rental motor lokal) memiliki akses ke infrastruktur verifikasi digital kelas dunia yang setara dengan jaringan hotel bintang lima internasional.
4. **Kesiapan Menuju Masa Depan Digital (Future-Proof):**
   Arsitektur purpose-bound request dan dynamic QR handshake adalah standar emas privasi global yang menempatkan Bali sebagai destinasi pariwisata berbasis teknologi identitas terpercaya (*Trusted Visitor Ecosystem*) pertama di Asia Tenggara.

---
*Dokumen ini disusun sebagai spesifikasi teknis dan analisis bedah mendalam sistem Bali Tourist ID (Bagian: Merchant App).*
