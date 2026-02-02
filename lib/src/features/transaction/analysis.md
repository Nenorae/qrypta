# Analisis Layanan Fitur Transaksi

Dokumen ini menganalisis bagaimana fitur transaksi berinteraksi dengan sumber data eksternal. Terdapat pemisahan yang jelas antara pengambilan data historis dan pengiriman transaksi baru.

## 1. Layanan Menuju Server (Indexer/Blockscan)

Aktivitas ini berfokus pada pengambilan data riwayat transaksi yang telah diindeks oleh server untuk efisiensi.

-   **File:** `lib/src/features/transaction/data/repositories/transaction_repository_impl.dart`
    -   **Mekanisme:** File ini adalah inti dari pengambilan riwayat. Ia memanggil `_blockchainService.transaction.getRecentTransactions`. Metode ini diasumsikan menghubungi sebuah API server (seperti Blockscout/Etherscan) untuk mendapatkan daftar transaksi yang sudah jadi, bukan memindai blok satu per satu dari node blockchain.

-   **File:** `lib/src/features/transaction/presentation/providers/transaction_providers.dart`
    -   **Mekanisme:** Provider `transactionHistoryProvider` menggunakan repository di atas untuk menyediakan data riwayat transaksi ke lapisan UI secara reaktif.

-   **File:** `lib/src/features/transaction/presentation/screens/transaction_history_screen.dart`
    -   **Mekanisme:** Widget ini hanya menampilkan data yang disediakan oleh `transactionHistoryProvider`, memisahkan sepenuhnya logika UI dari pengambilan data.

## 2. Layanan Menggunakan RPC Blockchain Langsung

Aktivitas ini melibatkan interaksi langsung dengan node blockchain, yang diperlukan untuk mengirim transaksi baru dan mengelola kunci.

-   **File:** `lib/src/features/transaction/screens/confirmation_page.dart`
    -   **Mekanisme:** Ini adalah titik utama di mana interaksi RPC terjadi.
        1.  **Pengiriman Transaksi:** Memanggil `blockchainService.sendTransaction(...)`. Secara internal, metode ini bertanggung jawab untuk menandatangani transaksi menggunakan *private key* dan mengirimkannya ke node blockchain melalui **panggilan RPC `eth_sendRawTransaction`**.
        2.  **Pengecekan Status:** Memanggil `blockchainService.waitForTransactionReceipt(txHash)` yang secara periodik melakukan **panggilan RPC `eth_getTransactionReceipt`** untuk memeriksa apakah transaksi telah dikonfirmasi oleh jaringan.

-   **File:** `lib//src/features/transaction/logic/transaction_controller.dart`
    -   **Mekanisme:** Meskipun tidak secara langsung melakukan panggilan RPC, *controller* ini melakukan operasi kriptografi fundamental di sisi klien. Ia mengelola *private key* dan menggunakan `web3dart` untuk mempersiapkan kredensial (`EthPrivateKey`) yang akan digunakan untuk menandatangani transaksi sebelum dikirim melalui RPC di `ConfirmationPage`.
