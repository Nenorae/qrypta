# Analisis Fitur: `send_money` dan `qr_scanner`

Dokumen ini menganalisis peran dan tanggung jawab dari fitur `send_money` dan `qr_scanner` dalam hubungannya dengan fitur `transaction`.

## Ringkasan

Asumsi awal bahwa `send_money` dan `qr_scanner` hanya berisi UI/UX dan kontroler sederhana yang mengarah ke `transaction` adalah **sebagian benar dan sebagian salah**.

-   **`qr_scanner`**: Benar. Fitur ini murni lapisan UI dan navigasi.
-   **`send_money`**: Salah. Fitur ini berisi logika teknis yang lengkap dan mandiri untuk mengirim transaksi mata uang native.

---

## 1. Analisis Fitur: `qr_scanner` (Hanya UI/UX & Navigasi)

Fitur ini sesuai dengan asumsi awal. Ia berfungsi sebagai pengontrol tampilan dan tidak memiliki logika bisnis terkait blockchain.

-   **Peran Utama**:
    -   Menjadi "hub" visual yang menampung layar pemindai untuk mengirim (`SendScannerScreen`) dan menerima (`ReceiveScreen`).
    -   Mengelola navigasi antar layar berdasarkan input pengguna.

-   **Mekanisme Kerja**:
    1.  `qr_scanner_screen.dart` menampilkan `PageView` yang berisi `SendScannerScreen` (dari `features/transaction`).
    2.  Ketika kamera berhasil memindai alamat, `SendScannerScreen` memicu callback `onScanResult`.
    3.  Callback tersebut menjalankan `Navigator.push` untuk membuka `SendMoneyScreen` dan mengirimkan data alamat yang terpindai sebagai parameter.

-   **Kesimpulan**: Fitur ini adalah lapisan presentasi murni. Ia tidak membuat, menandatangani, atau mengirim transaksi.

---

## 2. Analisis Fitur: `send_money` (Logika Transaksi Lengkap)

Berlawanan dengan asumsi awal, fitur ini adalah eksekutor utama untuk pengiriman mata uang native (misalnya ETH).

-   **Peran Utama**:
    -   Menyediakan UI berupa form untuk memasukkan alamat dan jumlah.
    -   Mengandung logika bisnis lengkap untuk seluruh siklus hidup transaksi pengiriman.

-   **Mekanisme Teknis (`SendMoneyController`)**:
    Proses terjadi sepenuhnya di dalam `sendTransaction()` pada `send_money_controller.dart`:
    1.  **Ambil Kredensial**: Mendapatkan `privateKey` dari *secure storage*.
    2.  **Bangun Transaksi**: Mengambil data `nonce` dan `gasPrice` terkini dari node RPC, lalu membuat objek `Transaction` menggunakan `web3dart`.
    3.  **Tanda Tangan (Sign)**: Transaksi ditandatangani secara lokal di perangkat (`offline`) menggunakan `privateKey`.
    4.  **Kirim (Broadcast)**: Transaksi mentah yang sudah ditandatangani dikirimkan ke node blockchain melalui panggilan RPC.
    5.  **Terima Hash**: Setelah berhasil terkirim, controller menerima `transactionHash` sebagai bukti.

-   **Hubungan dengan `transaction`**:
    Fitur `send_money` **tidak mendelegasikan proses pengiriman** ke fitur `transaction`. Sebaliknya, setelah `send_money` berhasil mengirim transaksi dan mendapatkan `transactionHash`, ia baru bernavigasi ke `ConfirmationPage` (yang merupakan bagian dari `features/transaction`) hanya untuk **menampilkan hasil akhir** atau "resi" dari transaksi yang sudah terjadi.

## Kesimpulan Arsitektur Global

-   **`features/send_money`**: Dikhususkan untuk menangani logika transaksi **pengiriman mata uang native**.
-   **`features/qr_scanner`**: Dikhususkan untuk **input pengguna** via kamera.
-   **`features/transaction`**: Berfungsi sebagai **koleksi komponen transaksional yang dapat digunakan kembali (reusable)** seperti UI `ReceiveScreen`, UI `ConfirmationPage`, dan layanan untuk mengambil `Riwayat Transaksi`.
