Jangan buang waktu satu menit pun untuk membangun fitur sekunder yang tidak menyentuh jalur transaksi (culture, lesson, events, transport, insurance, atau pengenalan wajah biometrik sungguhan). Perusahaan dan penguji tidak peduli apakah tombol video budaya Bali di aplikasimu bisa diputar; mereka peduli apakah **identitas paspor bisa diikat ke keypair kriptografi**, **transaksi persetujuan (*consent*) & pembayaran QRIS/Levy bisa ditandatangani tanpa lag**, dan **bukti transaksinya tercatat secara *immutable* di Hyperledger Besu melalui middleware dan tx-worker yang sudah kamu siapkan**.  
Saat ini repositori Flutter Qrypta-mu bahkan tidak bisa di-compile secara bersih karena bug getMyWalletQuery dan akan meledak (*integer overflow*) jika dipakai membayar Tourist Levy Rp 150.000 menggunakan token IDRT 18 desimal.  
Berikut adalah **Blueprint & Milestone Eksekusi End-to-End** yang memangkas semua beban kosmetik dan memfokuskan 100% tenagamu pada integrasi **Flutter Qrypta \+ UI Mockup Turis App \+ Backend ezsign-core**.

## **Peta Strategi Efisiensi (Apa yang Real vs Simulasi)**

Agar selesai tepat waktu dengan kualitas *enterprise*, terapkan pembagian tegas ini:

| Modul Mockup Turis App | Status Implementasi | Alasan Strategis & Efisiensi |
| :---- | :---- | :---- |
| **MRZ Passport Scanner (ScrMrz)** | **REAL (Kamera \+ Regex TD3)** | Mudah dibuat dengan google\_mlkit\_text\_recognition \+ validasi *checksum* modulo 10 (bobot 7-3-1). Memberikan efek *wow* saat demo menggunakan paspor asli. |
| **NFC Chip & Passive Auth (ScrNfc, ScrAuth)** | **SIMULASI STATE (useSequence)** | Membaca APDU ISO 14443 dan parsing ASN.1/SOD butuh berminggu-minggu dan rawan gagal di HP berbeda. Gunakan animasi timer 3 detik sesuai mockup HTML. |
| **Liveness & Face Match (ScrLiveness)** | **SIMULASI KAMERA DEPAN** | Hanya buka preview kamera depan selama 2.5 detik, tampilkan animasi SVG ring, lalu munculkan skor statis 98.7%. Nol beban ML wajah. |
| **Penerbitan BTID & Wallet (ScrIssued)** | **REAL KRIPTOGRAFI (secp256k1)** | Membangkitkan *keypair* EVM lokal di FlutterSecureStorage dan mengikatnya ke ID BTID-2026-XXXX-XXXX. |
| **Levy & QRIS Payment (ScrLevyPay, ScrPay)** | **REAL ON-CHAIN \+ MIDDLEWARE** | Eksekusi transfer token ERC-20 **IDRT** di Besu (Erc20Service) \+ catat log rekonsiliasi LVY-XXXXX / PAY-XXXXXX ke ezsign-core. |
| **Dynamic QR & Consent (ScrQr, ScrConsent)** | **REAL EIP-712 / SIGNATURE \+ BESU** | Inti utama proyekmu. *Payload* atribut yang disetujui turis di-sign dengan *private key* lokal, dikirim ke Fastify middleware $\rightarrow$ RabbitMQ $\rightarrow$ tx-worker $\rightarrow$ Besu. |
| **Privacy & Audit History (ScrPrivacy)** | **REAL INDEXER / API QUERY** | Menampilkan daftar transaksi verifikasi (TX-XXXXXX) dan pembayaran beserta *Transaction Hash* Besu dan tombol *Revoke Access*. |

## **MILESTONE 1: Operasi Pembersihan & Fondasi Core Qrypta (Hari 1 \- 2\)**

**Tujuan:** Memperbaiki seluruh *compile error*, celah keamanan, dan bug aritmatika di repositori Qrypta saat ini agar siap menjadi mesin transaksi Bali Tourist ID.

### **1.1 Perbaikan Bug Fatal & Keamanan**

* **lib/src/core/data/repositories/wallet\_repository.dart**  
  * **Aksi:** Ubah pemanggilan dokumen GraphQL di baris 13 dari gql(getMyWalletQuery) menjadi gql(getMyAssetsQuery) sesuai deklarasi di queries.dart.  
* **lib/src/features/transaction/logic/send\_controller.dart**  
  * **Aksi:** Rombak baris 87 pada fungsi kalkulasi pengiriman ERC-20 IDRT. Hapus konversi .toDouble().toInt() yang menyebabkan *integer overflow* di atas 9.22 IDRT.  
  * **Implementasi Baru:** Parse string input nominal secara langsung ke BigInt dengan menggeser titik desimal sebanyak token.decimals (18 digit), sehingga pembayaran Levy 150.000 IDRT ($150000\times 1{0}^{18}$) berjalan presisi tanpa melewati tipe double.  
* **lib/src/core/utils/formatters.dart**  
  * **Aksi:** Perbaiki fungsi formatBigInt(BigInt value, int decimals) agar melakukan pembagian menggunakan operasi BigInt (\~/) dan modulo (%) terlebih dahulu sebelum diformat ke string mata uang Rupiah, menghindari pemotongan presisi IEEE 754\.  
* **lib/src/features/authentication/ (Seluruh File)**  
  * **Aksi:** Hapus seluruh baris log('... \$privateKey'), log('... \$mnemonic') di auth\_service.dart, authentication\_local\_data\_source.dart, dan authentication\_repository\_impl.dart. Hapus print() PIN di pin\_verification\_screen.dart.  
  * **Aksi Tambahan:** Di authentication\_local\_data\_source.dart, ubah penyimpanan PIN agar di-hash menggunakan sha256 dari package crypto sebelum disimpan ke FlutterSecureStorage.

### **1.2 Konfigurasi Lingkungan & Tema UI Mockup**

* **pubspec.yaml & .env**  
  * **Aksi:** Daftarkan intl dan wallet secara eksplisit di pubspec.yaml. Tambahkan package google\_mlkit\_text\_recognition (untuk OCR MRZ Paspor).  
  * **Aksi .env:** Tambahkan variabel EZSIGN\_API\_URL=http\://\<IP\_SERVER\_KAMU\>:3000/api/v1 di samping RPC\_URL, GRAPHQL\_URL, dan IDRT\_CONTRACT\_ADDRESS.  
* **lib/src/core/config/blockchain\_config.dart & graphql\_provider.dart**  
  * **Aksi:** Ganti semua URL hardcoded (\[http\://100.92.191.4:8545\](http\://100.92.191.4:8545) dan :4000/graphql) agar mengambil nilai dari dotenv.env\['RPC\_URL'\] dan dotenv.env\['GRAPHQL\_URL'\].  
* **lib/src/core/config/theme/app\_colors.dart & app\_theme.dart**  
  * **Aksi:** Sesuaikan palet warna dengan estetika **Bali Tourist ID Mockup** (kombinasi warna *Teal/Toska* untuk status *Verified/Approved*, *Purple/Indigo* untuk aksen identitas & NFC, *Amber* untuk *Conditional/Pending*, dan *Rose* untuk *Prohibited/Rejected*). Ganti semua .withOpacity() yang *deprecated* menjadi .withValues(alpha: ...).

## **MILESTONE 2: Integrasi Service Transaksi Verifikasi ke ezsign-core (Hari 3 \- 5\)**

**Tujuan:** Membangun jembatan komunikasi antara aplikasi Flutter dan *backend* middleware/ (Fastify) $\rightarrow$ RabbitMQ $\rightarrow$ tx-worker/ yang sudah kamu miliki.

### **2.1 Pembuatan Model Data Ekosistem Turis**

Buat tiga model DTO baru di dalam **lib/src/core/data/models/**:

> 1. **btid\_credential\_model.dart**: Menyimpan atribut lokal sesuai matriks mockup: btidNumber (BTID-2026-4471-0938), fullName, nationality, passportMasked (••••••789), dob, docExpiry, visaType (e-VOA B1), arrivalDate, stayExpiry, levyStatus (paid/unpaid), levyReceiptRef (LVY-XXXXX), dan walletAddress (0x...).  
> 2. **consent\_request\_model.dart**: Merepresentasikan permintaan data dari Merchant App: requestId (TX-XXXXXX), merchantId (MCH-1042), merchantName (Bali Ocean Resort), merchantCategory (hotel), staffName (Kadek Sari), staffRole (Front Desk Agent), purposeTemplate (hotel\_checkin), requestedFields (List\<String\>), retentionPolicy (Retained for 30 days), dan expiresAt.  
> 3. **audit\_transaction\_model.dart**: Merepresentasikan log transaksi verifikasi dan pembayaran yang sudah tercatat di blockchain: auditRef (AUD-XXXXX), txRef (TX-XXXXXX / LVY-XXXXX / PAY-XXXXXX), txHash (Hash transaksi Hyperledger Besu), actor, organisation, action, purpose, sharedAttributesCount, status (Approved/Rejected/Paid), dan timestamp.

### **2.2 Pembuatan VerificationTransactionService**

Buat file baru di **lib/src/core/services/blockchain/verification\_transaction\_service.dart** dan daftarkan ke dalam facade **blockchain\_service.dart** (BlockchainService.verification):

* **Fungsi 1: generateDynamicQrToken(String btid, String walletAddress)**  
  * Menghasilkan payload string JSON/format token sementara QRT-\<10\_KARAKTER\_ACAK\> yang di-hash dengan timestamp saat ini (masa berlaku ketat **45 detik**).  
* **Fungsi 2: signAndSubmitConsent({required String privateKeyHex, required ConsentRequestModel request, required Map\<String, dynamic\> approvedData, required bool isApproved})**  
  * Menyusun payload kanonikal untuk ditandatangani (tanpa menyertakan PII mentah ke dalam digest blockchain):  
    JSON  
    {  
      "txRef": "TX-448102",  
      "btidHash": "\<keccak256\_of\_btid\>",  
      "merchantId": "MCH-1042",  
      "purpose": "hotel\_checkin",  
      "attributeKeys": \["name", "nationality", "id\_validity", "passport\_auth", "levy\_status", "stay\_valid"\],  
      "outcome": "APPROVED",  
      "timestamp": "2026-11-11T21:30:00Z"  
    }

  * Menggunakan EthPrivateKey.fromHex(privateKeyHex) dari web3dart untuk menandatangani hash SHA-256/Keccak-256 dari payload tersebut (signPersonalMessageToUint8List).  
  * Mengirimkan HTTP POST ke endpoint Fastify middleware milikmu (/api/v1/verify-identity atau /api/v1/consent/submit) dengan client\_type: "web3", uuid: btid, signature: "0x...", dan metadata audit (actor, org, role, action, purpose, record, result).  
  * Menyimpan respons auditRef (AUD-XXXXX) dan txHash secara lokal di cache Hive (HiveStore) untuk ditampilkan secara instan di UI.  
* **Fungsi 3: revokeMerchantAccess({required String privateKeyHex, required String txRef, required String merchantId})**  
  * Menandatangani instruksi pencabutan akses (Stop future access) dan mengirimkannya ke middleware agar dicatat sebagai event audit baru di Besu.

## **MILESTONE 3: Onboarding Paspor (OCR MRZ) & Auto-Keypair Issuance (Hari 6 \- 8\)**

**Tujuan:** Mengubah alur onboarding Qrypta (yang awalnya menyuruh pengguna menulis 12 kata *seed phrase*) menjadi alur **Fase A Mockup Turis App (welcome $\rightarrow$ mrz $\rightarrow$ nfc $\rightarrow$ auth $\rightarrow$ liveness $\rightarrow$ issued)**.

### **3.1 Modifikasi Alur di lib/src/features/authentication/**

Jangan hapus *use case* kriptografi BIP-39 dan secp256k1 yang sudah ada di authentication/domain/usecases/, tetapi bungkus ulang layar presentasinya di authentication/presentation/screens/:

* **Layar 1: welcome\_screen.dart (ScrWelcome)**  
  * Gunakan kembali file welcome\_screen.dart yang saat ini berstatus *orphan*. Ubah tampilannya persis seperti mockup: judul *"Verify once. Share only what is required. Explore Bali"* dan tombol Set up my Tourist ID.  
* **Layar 2: mrz\_scanner\_screen.dart (ScrMrz \- REAL OCR PASPOR)**  
  * Buat layar kamera menggunakan MobileScanner / kamera \+ google\_mlkit\_text\_recognition.  
  * Buat utility parser di lib/src/core/utils/mrz\_parser.dart untuk mendeteksi 2 baris string TD3 (masing-masing 44 karakter, diawali P\<) dan memvalidasi *check digit* dengan rumus bobot berulang 7-3-1 modulo 10:  
    \$\$\\text{Check Digit} \= \\left(\\sum\_{i=1}^{n} \\text{Nilai}(C\_i) \\times \\text{Bobot}\_i\\right) \\pmod{10}\$\$  
  * *Fitur Fallback Efisien:* Sediakan tombol kecil "Use Demo Passport (James Wilson)" di pojok layar agar saat pengujian di depan dosen/klien dan cahaya ruangan buruk, kamu bisa langsung menginjeksi data MRZ P\<GBRWILSON\<\<JAMES... dalam 1 klik tanpa macet.  
* **Layar 3: passport\_verification\_flow\_screen.dart (Gabungan ScrNfc, ScrAuth, ScrLiveness)**  
  * Gabungkan ketiga layar sekuensial ini dalam satu StatefulWidget berbasis *stepper* otomatis agar kode ringkas:  
    * **Step 1 (nfc):** Animasi radar *concentric rings* ungu dengan 6 tahapan teks berurutan (@ 600 ms).  
    * **Step 2 (auth):** Tampilan rantai sertifikat PKI (ePassport chip $\rightarrow$ Signed passport data $\rightarrow$ Document signer certificate $\rightarrow$ Country trust authority) dengan modal sheet Security details.  
    * **Step 3 (liveness):** Tampilkan frame kamera depan melingkar selama 2.5 detik, lalu render kartu skor kecocokan **98.7%** (Threshold: 85.0%).  
* **Layar 4: btid\_issued\_screen.dart (ScrIssued)**  
  * Begitu tombol Issue my Tourist ID ditekan:  
    1. Panggil generateMnemonicUseCase $\rightarrow$ getPrivateKeyFromMnemonicUseCase $\rightarrow$ savePrivateKeyUseCase di *background* (compute() isolate) tanpa menampilkan 12 kata ke layar. (Kunci tetap bisa dilihat nanti di menu Profile via autentikasi biometrik jika penguji ingin melihat bukti *wallet*\-nya).  
    2. Bangkitkan objek BtidCredentialModel (BTID-2026-4471-0938) dan simpan di storage lokal.  
    3. Tembak API ezsign-core (action: 'Credential issued', purpose: 'Identity onboarding') agar penerbitan ID langsung tercatat di blockchain Besu.  
    4. Tampilkan komponen visual kartu IdCard lengkap dengan ornamen dan badge Identity verified & Passport authenticated.

## **MILESTONE 4: Mesin Transaksi Verifikasi Identitas & Selective Disclosure (Hari 9 \- 12\)**

**Tujuan:** Membangun fitur inti tempat nilai utama proyekmu dinilai: **Dynamic QR 45 Detik (ScrQr), Persetujuan Atribut Terikat Tujuan (ScrConsent), dan Kontrol Privasi (ScrPrivacy)**.  
Buat modul fitur baru di **lib/src/features/verification/**:

lib/src/features/verification/  
├── data/  
│   └── policy\_matrix\_constants.dart    \# Matriks 18 atribut & 9 template resmi pemerintah  
├── logic/  
│   └── verification\_controller.dart    \# Riverpod Notifier untuk QR timer, Consent, & Audit  
└── presentation/  
    ├── screens/  
    │   ├── dynamic\_qr\_screen.dart      \# ScrQr (45s rotating ephemeral token)  
    │   ├── consent\_request\_screen.dart \# ScrConsent (Checklist atribut \+ Biometric Sign)  
    │   ├── consent\_shared\_screen.dart  \# ScrShared (Bukti transaksi TX-XXXXXX & TxHash)  
    │   └── privacy\_audit\_screen.dart   \# ScrPrivacy (Sharing history, Revoke, Report)  
    └── widgets/  
        └── btid\_card\_widget.dart       \# Widget kartu BTID reusable (Full & Mini)

### **4.1 Detail Implementasi per File:**

> 1. **policy\_matrix\_constants.dart**  
   * Salin konstanta ATTRS (18 atribut), TEMPLATES (9 template: hotel\_checkin, vehicle\_rental, age\_check, esim\_activation, dll.), dan DEFAULT\_POLICY (allowed, conditional, prohibited, dengan biometric terkunci permanen di prohibited) dari dokumen spesifikasi ke dalam konstanta Map Dart.  
> 2. **dynamic\_qr\_screen.dart (ScrQr)**  
   * Menggantikan fungsi ReceiveScreen lama di qr\_scanner.  
   * Menggunakan Timer.periodic(Duration(seconds: 1)) untuk menghitung mundur dari **45 detik ke 0**.  
   * Me-render QR Code menggunakan qr\_flutter yang berisi JSON singkat: {"token":"QRT-9X2KL8MPQ1","btid":"BTID-2026-4471-0938","exp":1794407445}.  
   * Saat waktu habis (0s), buramkan QR Code, tampilkan status *Code Expired*, dan sediakan tombol Refresh code.  
   * **Tombol Simulasi Handshake Merchant (Krusial untuk Demo):** Tambahkan tombol *dev/demo trigger* di bawah QR (misal: "Simulate Merchant Scan" dengan pilihan dropdown: *Bali Ocean Resort \- Hotel Check-in*, *Island Drive \- Vehicle Rental*, *Bali Coffee House \- Age Check 18+*). Saat ditekan (atau saat menerima push/polling dari middleware), aplikasi langsung memunculkan ConsentRequestScreen.  
> 3. **consent\_request\_screen.dart (ScrConsent)**  
   * Menampilkan header identitas peminta (*Bali Ocean Resort · Kadek Sari · Front Desk Agent · Verified Business*) dan timer kedaluwarsa request (3 menit).  
   * Menampilkan daftar atribut yang diminta beserta nilai riilnya dan alasan aksesnya (atau status boolean "Over 18 — verified" tanpa menampilkan tanggal lahir untuk kategori kafe/bar).  
   * Menampilkan klausul retensi data (*"Retained for 30 days"*) dan jaminan *"Never shared: biometric template, live face capture"*.  
   * **Eksekusi Tombol Approve & share:**  
     1. Memanggil AuthenticationService.authenticate("Konfirmasi berbagi data terverifikasi") (Sidik jari / FaceID / PIN).  
     2. Memanggil VerificationTransactionService.signAndSubmitConsent(...) untuk menandatangani *consent* dengan *private key* wallet Qrypta dan mengirimkannya ke Fastify middleware $\rightarrow$ RabbitMQ $\rightarrow$ tx-worker $\rightarrow$ Besu.  
     3. Berpindah ke layar ConsentSharedScreen (ScrShared) yang menampilkan nomor referensi TX-XXXXXX dan bukti *Transaction Hash* blockchain.  
> 4. **privacy\_audit\_screen.dart (ScrPrivacy)**  
   * Menampilkan 3 kartu statistik di atas: *Approved*, *Rejected*, dan *Active Access*.  
   * Menampilkan daftar seluruh riwayat berbagi data yang ditarik dari penyimpanan lokal \+ GraphQL/REST ezsign-core.  
   * Menyediakan 3 tombol aksi fungsional pada setiap detail transaksi:  
     * Download consent receipt: Menampilkan dialog/sheet berisi JSON kriptografis tanda tangan EIP-712 dan *TxHash* Besu.  
     * Stop future access: Memanggil revokeMerchantAccess() dan mengubah badge status menjadi *Access Revoked*.  
     * Report unexpected access: Mengirimkan tiket komplain EXC-XXXX ke endpoint /gov/exceptions di middleware.

## **MILESTONE 5: Pembayaran Retribusi (Levy) & QRIS On-Chain Berbasis IDRT (Hari 13 \- 15\)**

**Tujuan:** Memadukan fitur transfer token ERC-20 **IDRT** milik Qrypta dengan alur **Fase B (ScrLevy, ScrLevyPay, ScrReceipt)** dan **Tab 2 (ScrPay \- QRIS)** di mockup Turis App.

### **5.1 Alur Pembayaran Tourist Levy (lib/src/features/transaction/presentation/screens/)**

* Buat layar **levy\_payment\_screen.dart (ScrLevy & ScrLevyPay)** dan **levy\_receipt\_screen.dart (ScrReceipt)**:  
  * Menampilkan tagihan resmi **IDR 150,000** atas nama James Wilson (••••••789).  
  * Di bagian *Funding Source*, jadikan **Qrypta IDRT Wallet Balance** sebagai metode pembayaran utama (menampilkan saldo live dari tokenNotifierProvider) di samping opsi simulasi Visa/Mastercard.  
  * Ketika pengguna menekan **Pay IDR 150,000**:  
    1. Panggil otorisasi biometrik AuthenticationService.authenticate().  
    2. Eksekusi SendController.send() untuk mentransfer 150000 IDRT ke alamat *Treasury Smart Contract / Wallet Bapenda* di Hyperledger Besu.  
    3. Setelah mendapatkan txHash dan konfirmasi waitForTransactionReceipt(txHash), kirim log ke ezsign-core (action: 'Tourist Levy paid', record: 'LVY-XXXXX').  
    4. Ubah state btid.levyStatus \= 'paid', sehingga badge Levy paid di kartu Tourist ID menyala hijau dan layar menampilkan ScrReceipt lengkap dengan pita MRZ retribusi (LEVY\<\<LVY\<XXXXX\<\<IDR150000).

### **5.2 Refactor Scanner Qrypta Menjadi QRIS Payment (ScrPay)**

* Modifikasi **lib/src/features/qr\_scanner/presentation/screens/qr\_scanner\_screen.dart** dan **send\_screen.dart**:  
  * Saat kamera memindai QR Code di tab Pay:  
    * Jika QR berisi payload QRIS simulasi merchant (atau *address* EVM merchant seperti MCH-3311 / Bali Coffee House), tampilkan UI konfirmasi ala **ScrPay**: nama merchant (Bali Coffee House \- Canggu), input/nominal tagihan (IDR 85,000), dan sumber dana (IDRT Wallet Balance).  
    * Saat dibayar, sistem mengeksekusi transfer ERC-20 IDRT secara *on-chain* di jaringan Besu dan menghasilkan kuitansi PAY-XXXXXX dengan penegasan privasi: *"Merchant only received Payment Confirmed — Zero passport or personal data shared"*.

## **MILESTONE 6: Penyatuan Dashboard Utama (5 Tab Navigasi) & Pengujian End-to-End (Hari 16 \- 18\)**

**Tujuan:** Merakit seluruh modul ke dalam kerangka navigasi 5 Tab sesuai mockup **Fase C (Home, Pay, ID, Explore, Profile)** dan menguji integrasi penuh dengan middleware \+ tx-worker.

### **6.1 Rombak lib/src/features/home/presentation/screens/home\_screen.dart**

Sesuaikan BottomNavigationBar menjadi 5 tab persis seperti mockup:

> 1. **Tab 1: Home (ScrHome)**  
   * Greeting waktu otomatis (*"Selamat pagi/siang/malam, James"*).  
   * **Banner Oranye Permintaan Masuk (Pending Request Alert):** Muncul paling atas jika ada permintaan data dari merchant yang menunggu persetujuan.  
   * **Mini BTID Card** \+ **Saldo Portofolio IDRT** (menggabungkan identitas dan finansial secara elegan).  
   * **Quick Action Bar:** Tombol Show my ID (buka DynamicQrScreen) dan Pay with QRIS (buka tab Pay).  
   * **Widget Permitted Stay (ScrVisa):** Menampilkan sisa hari izin tinggal (*e-VOA · 28 days remaining*).  
   * **Recent Activity List:** Menggabungkan 3 transaksi terakhir (baik transaksi berbagi data TX-XXXXXX maupun pembayaran PAY-XXXXXX / LVY-XXXXX) lengkap dengan status on-chain-nya.  
> 2. **Tab 2: Pay (ScrPay)** — Pemindai QRIS & Pembayaran IDRT.  
> 3. **Tab 3: ID (ScrIdTab)** — Tampilan penuh kartu BTID-2026-4471-0938, tombol Show Dynamic QR, dan modal Security Details.  
> 4. **Tab 4: Explore (ScrExplore)** — Daftar statis 5 merchant ekosistem dari konstanta data (Bali Ocean Resort, Island Drive Car Rental, Bali Coffee House, Bali Connect eSIM, Bali Adventure Tours) beserta status akreditasinya.Jika salah satu merchant diklik, kamu bisa langsung memicu simulasi permintaan transaksi verifikasi untuk merchant tersebut (sangat memudahkan saat demo).  
> 5. **Tab 5: Profile (ScrProfile)** — Berisi tautan ke Privacy & activity (ScrPrivacy), Levy receipt (ScrReceipt), 3 toggle pengaturan privasi (hotelAuto, levyShare, marketing), serta menu SecurityGroup bawaan Qrypta (lihat *Private Key* / *Seed Phrase* dengan biometrik) untuk membuktikan kepada penguji bahwa aplikasi ini benar-benar berjalan di atas dompet Web3 asli.

### **6.2 Checklist Pengujian Integrasi Akhir (End-to-End Verification)**

Sebelum dinyatakan selesai, jalankan skenario pengujian berantai ini dari awal hingga akhir:

> 1. Nyalakan container Docker untuk node **Hyperledger Besu**, **Redis**, **RabbitMQ**, layanan **Fastify middleware**, dan **tx-worker** di server/VM-mu.  
> 2. Buka aplikasi Flutter di HP $\rightarrow$ jalankan scan paspor di ScrMrz $\rightarrow$ selesaikan penerbitan BTID $\rightarrow$ pastikan *wallet address* (0x...) terbentuk dan log Credential issued masuk ke antrean RabbitMQ hingga tercatat di smart contract Besu.  
> 3. Lakukan pembayaran **Tourist Levy Rp 150.000** menggunakan saldo token IDRT $\rightarrow$ pastikan saldo IDRT berkurang di blockchain, *Transaction Receipt* berhasil didapatkan oleh waitForTransactionReceipt, dan kuitansi LVY-XXXXX terbit.  
> 4. Buka Show my ID (ScrQr) $\rightarrow$ picu permintaan verifikasi *Hotel Check-in* (Bali Ocean Resort) $\rightarrow$ setujui di layar ScrConsent dengan sidik jari $\rightarrow$ pastikan *signature* diterima oleh Fastify middleware, diproses oleh tx-worker \+ Vault KMS, dan *hash* transaksinya muncul di layar Privacy & activity (ScrPrivacy).

Mau kita mulai eksekusi kode dari **Milestone 1** (memperbaiki bug overflow SendController dan wallet\_repository.dart) atau langsung membuat kode **VerificationTransactionService** untuk **Milestone 2**?