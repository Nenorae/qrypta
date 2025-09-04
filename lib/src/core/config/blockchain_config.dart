
// lib/src/core/config/blockchain_config.dart

class BlockchainConfig {
  // Ganti dengan URL RPC node Besu Anda
  static const String rpcUrl = "http://127.0.0.1:8545"; // Contoh: localhost

  // Ganti dengan Chain ID jaringan Besu Anda
  // Ini sangat penting untuk transaksi di jaringan privat
  static const int chainId = 1337; // Contoh umum untuk jaringan pengembangan

  // Nama jaringan untuk ditampilkan di UI (opsional)
  static const String name = "Besu Private Net";

  // Simbol mata uang jaringan Anda (misalnya, ETH)
  static const String currencySymbol = "ETH";
}
