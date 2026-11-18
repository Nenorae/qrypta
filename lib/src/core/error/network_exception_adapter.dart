// lib/src/core/error/network_exception_adapter.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:web3dart/json_rpc.dart';
import 'app_failure.dart';

/// Adapter untuk memetakan error IO, HTTP, dan JSON-RPC menjadi [AppFailure] bertipe.
/// Memastikan Golden Rule R1: Tidak ada error yang ditelan atau diubah menjadi string sembarangan.
class NetworkExceptionAdapter {
  /// Memetakan sembarang exception objek ke turunan [AppFailure].
  static AppFailure fromException(Object error, [StackTrace? stackTrace]) {
    if (error is AppFailure) {
      return error;
    }

    if (error is TimeoutException) {
      return RequestTimeout(
        error.message ?? 'Batas waktu koneksi terlampaui.',
      );
    }

    if (error is SocketException) {
      return NetworkUnreachable(
        'Koneksi jaringan gagal: ${error.message} (${error.osError?.message ?? 'Host tidak terjangkau'}).',
      );
    }

    if (error is HandshakeException || error is TlsException) {
      return NetworkUnreachable(
        'Kegagalan negosiasi TLS/SSL keamanan jaringan: $error.',
      );
    }

    if (error is http.ClientException) {
      final msg = error.message.toLowerCase();
      if (msg.contains('connection refused') || msg.contains('failed to connect')) {
        return NetworkUnreachable('Server tujuan menolak koneksi: ${error.message}.');
      }
      return NetworkUnreachable('Error client HTTP: ${error.message}.');
    }

    if (error is HttpException) {
      return NetworkUnreachable('Protokol HTTP gagal: ${error.message}.');
    }

    if (error is RPCError) {
      return fromRpcError(error.errorCode, error.message);
    }

    if (error is FormatException) {
      return ValidationFailure('Format data atau JSON tidak valid: ${error.message}.');
    }

    // Default error tak terduga
    return ValidationFailure('Kesalahan sistem tak terduga: ${error.toString()}');
  }

  /// Memetakan respons HTTP status code (4xx / 5xx) menjadi [ServerRejected].
  static AppFailure fromHttpResponse(int statusCode, String responseBody) {
    String? extractedCode;
    String message = 'Server menolak permintaan dengan status HTTP $statusCode.';

    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is Map<String, dynamic>) {
        if (decoded.containsKey('error')) {
          final err = decoded['error'];
          if (err is Map) {
            message = err['message']?.toString() ?? message;
            extractedCode = err['code']?.toString();
          } else {
            message = err.toString();
          }
        } else if (decoded.containsKey('message')) {
          message = decoded['message'].toString();
        }
        extractedCode ??= decoded['code']?.toString();
      }
    } on Object {
      // Body bukan JSON, gunakan pesan status baku
    }

    return ServerRejected(message, statusCode, extractedCode);
  }

  /// Memetakan error code JSON-RPC ke [AppFailure] spesifik.
  static AppFailure fromRpcError(int? code, String message) {
    final lower = message.toLowerCase();

    // Deteksi error saldo tidak cukup
    if (lower.contains('insufficient funds') || lower.contains('gas * price + value')) {
      return InsufficientBalance('Saldo akun tidak mencukupi untuk transaksi ini: $message');
    }

    // Deteksi gas limit / intrinsic gas too low
    if (lower.contains('intrinsic gas too low') || lower.contains('out of gas')) {
      return InsufficientGas('Gas native tidak mencukupi atau estimasi gas terlalu rendah: $message');
    }

    // Deteksi chain mismatch
    if (lower.contains('chain id') || code == -32000 && lower.contains('wrong chain')) {
      return ChainMismatch('Ketidaksesuaian Chain ID node: $message');
    }

    // Deteksi revert
    if (lower.contains('execution reverted') || lower.contains('revert')) {
      return TxReverted('Eksekusi kontrak EVM dibatalkan (reverted): $message', '');
    }

    return RpcFailure(message, code);
  }

  /// Membungkus eksekusi async dan otomatis memetakan exception ke [AppFailure].
  static Future<T> guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on Object catch (e, st) {
      throw fromException(e, st);
    }
  }
}
