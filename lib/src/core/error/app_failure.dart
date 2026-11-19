// lib/src/core/error/app_failure.dart

/// Taksonomi error bertipe sesuai Rencana Kerja Eliminasi Fallback Palsu §2.1.
/// Menggantikan silent catch dan error string arbitrer.
sealed class AppFailure implements Exception {
  final String message;
  const AppFailure(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

/// Jaringan lokal tidak ada, host tidak terjangkau, atau koneksi socket putus.
class NetworkUnreachable extends AppFailure {
  const NetworkUnreachable(super.message);
}

/// Request melebihi batas waktu toleransi tanpa respons server.
class RequestTimeout extends AppFailure {
  const RequestTimeout(super.message);
}

/// Server HTTP mengembalikan respons kegagalan (4xx / 5xx).
class ServerRejected extends AppFailure {
  final int status;
  final String? code;
  const ServerRejected(super.message, this.status, [this.code]);

  @override
  String toString() => 'ServerRejected(status: $status, code: $code): $message';
}

/// Node RPC mengembalikan JSON-RPC error spesifik.
class RpcFailure extends AppFailure {
  final int? code;
  const RpcFailure(super.message, [this.code]);

  @override
  String toString() => 'RpcFailure(code: $code): $message';
}

/// Saldo token (IDRT) pengguna tidak mencukupi untuk pembayaran.
class InsufficientBalance extends AppFailure {
  const InsufficientBalance(super.message);
}

/// Saldo gas native (ETH/BIF) tidak mencukupi untuk eksekusi transaksi.
class InsufficientGas extends AppFailure {
  const InsufficientGas(super.message);
}

/// ID rantai (Chain ID) node tidak sesuai dengan konfigurasi aplikasi.
class ChainMismatch extends AppFailure {
  const ChainMismatch(super.message);
}

/// Transaksi on-chain dibatalkan (reverted) oleh EVM (status 0x0).
class TxReverted extends AppFailure {
  final String txHash;
  const TxReverted(super.message, this.txHash);

  @override
  String toString() => 'TxReverted(txHash: $txHash): $message';
}

/// Transaksi on-chain belum mendapat receipt setelah batas waktu polling maksimal.
class TxPendingTimeout extends AppFailure {
  final String txHash;
  const TxPendingTimeout(super.message, this.txHash);

  @override
  String toString() => 'TxPendingTimeout(txHash: $txHash): $message';
}

/// Validasi input, state, atau payload bisnis gagal sebelum dikirim.
class ValidationFailure extends AppFailure {
  const ValidationFailure(super.message);
}

/// Merchant tidak terdaftar di resolver backend ezsign-core (Phase 6 / D-4).
class MerchantNotRegistered extends AppFailure {
  final String? nmid;
  const MerchantNotRegistered(super.message, [this.nmid]);

  @override
  String toString() => 'MerchantNotRegistered(nmid: $nmid): $message';
}
