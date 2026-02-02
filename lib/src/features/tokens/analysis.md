# Analisis Layanan Fitur Token

Dokumen ini menganalisis bagaimana fitur token berinteraksi dengan sumber data eksternal, baik itu koneksi langsung ke blockchain maupun ke server perantara (indexer/blockscan).

Berdasarkan arsitektur saat ini, fitur token **tidak lagi berkomunikasi langsung dengan node blockchain**. Semua pengambilan data diabstraksi melalui repository yang terhubung ke server GraphQL.

## 1. Layanan Menuju Server (Indexer/Blockscan via GraphQL)

Layanan-layanan ini bertanggung jawab untuk mengambil data aset (token) yang sudah diindeks oleh server.

-   **File:** `lib/src/features/tokens/presentation/providers/token_provider.dart`
    -   **Mekanisme:** Menggunakan `StateNotifierProvider` untuk memanggil `walletRepository.watchWalletAssets`. Ini adalah *subscription* GraphQL yang secara *real-time* mendengarkan perubahan pada data dompet di server.

-   **File:** `lib/src/features/tokens/presentation/screens/manage_tokens_screen.dart`
    -   **Mekanisme:** Menggunakan `StreamProvider` (`userWalletTokensStreamProvider`) yang juga terhubung ke `walletRepository.watchWalletAssets`. Seluruh data yang ditampilkan (nama, simbol, saldo, logo) berasal dari respons server GraphQL.

## 2. Layanan yang Menggunakan Blockchain

Tidak ada file di dalam `lib/src/features/tokens/**` yang membuat koneksi RPC langsung ke blockchain (misalnya, menggunakan `web3dart` untuk memanggil fungsi *smart contract* secara langsung dari sini).

Fungsi yang berhubungan langsung dengan blockchain (seperti *signing* transaksi) kemungkinan besar terletak di luar fitur `tokens`, misalnya di dalam:
-   `lib/src/core/data/repositories/`
-   `lib/src/features/transaction/`

Tugas utama dari fitur `tokens` adalah untuk **menampilkan data** yang telah disediakan oleh server.
