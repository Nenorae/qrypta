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

/// Hardware NFC tidak aktif atau tidak didukung pada perangkat (Phase 8.1).
class NfcHardwareUnavailable extends AppFailure {
  final bool isSupported;
  const NfcHardwareUnavailable(super.message, {this.isSupported = true});

  @override
  String toString() => 'NfcHardwareUnavailable(isSupported: $isSupported): $message';
}

/// Tag NFC paspor tergeser atau koneksi terputus di tengah transmisi APDU (Phase 8.1 #5).
class NfcTagLost extends AppFailure {
  const NfcTagLost(super.message);
}

/// Otentikasi BAC gagal karena kunci MRZ tidak cocok dengan chip paspor (Phase 8.1 #2 & #5).
class NfcBacFailed extends AppFailure {
  const NfcBacFailed(super.message);
}

/// Data MRZ pada chip (DG1) berbeda dengan hasil pemindaian kamera OCR (Phase 8.1 #3).
class NfcDataMismatch extends AppFailure {
  final String cameraDocumentNumber;
  final String chipDocumentNumber;
  const NfcDataMismatch(
    super.message, {
    required this.cameraDocumentNumber,
    required this.chipDocumentNumber,
  });

  @override
  String toString() =>
      'NfcDataMismatch(camera: $cameraDocumentNumber, chip: $chipDocumentNumber): $message';
}

/// Kesalahan protokol transmisi APDU kartu pintar ISO 7816-4 / ISO 14443-4 (Phase 8.1 #5).
class NfcApduException extends AppFailure {
  final int? sw1;
  final int? sw2;
  const NfcApduException(super.message, [this.sw1, this.sw2]);

  @override
  String toString() => 'NfcApduException(sw: ${sw1?.toRadixString(16)} ${sw2?.toRadixString(16)}): $message';
}

/// Verifikasi Passive Authentication gagal (hash mismatch, signature invalid, trust chain broken) (Phase 8.2).
class NfcPassiveAuthFailed extends AppFailure {
  final String status;
  final List<String> reasons;
  const NfcPassiveAuthFailed(super.message, {required this.status, required this.reasons});

  @override
  String toString() => 'NfcPassiveAuthFailed(status: $status, reasons: $reasons): $message';
}

/// Merchant tidak terdaftar di resolver backend ezsign-core (Phase 6 / D-4).
class MerchantNotRegistered extends AppFailure {
  final String? nmid;
  const MerchantNotRegistered(super.message, [this.nmid]);

  @override
  String toString() => 'MerchantNotRegistered(nmid: $nmid): $message';
}
