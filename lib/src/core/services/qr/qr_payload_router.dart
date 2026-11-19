// lib/src/core/services/qr/qr_payload_router.dart

import 'dart:convert';
import 'package:qrypta/src/core/error/app_failure.dart';
import 'package:qrypta/src/core/services/qr/qris_model.dart';
import 'package:qrypta/src/core/services/qr/qris_parser.dart';
import 'package:web3dart/web3dart.dart';

/// Jenis rute payload QR yang teridentifikasi secara deterministik.
sealed class QrRouteResult {
  const QrRouteResult();
}

/// Rute QRIS EMVCo standar (PADG BI / EMVCo MPM).
class QrisRoute extends QrRouteResult {
  final QrisModel qris;
  const QrisRoute(this.qris);

  @override
  String toString() => 'QrisRoute(merchant: ${qris.merchantName}, nmid: ${qris.nmid})';
}

/// Rute transfer langsung alamat dompet EVM (0x...).
class WalletAddressRoute extends QrRouteResult {
  final String address;
  const WalletAddressRoute(this.address);

  @override
  String toString() => 'WalletAddressRoute(address: $address)';
}

/// Rute QR native protokol Qrypta dengan tanda tangan kriptografi tervalidasi.
class NativeQryptaRoute extends QrRouteResult {
  final Map<String, dynamic> payload;
  final int version;
  final String type;
  final String signature;

  const NativeQryptaRoute({
    required this.payload,
    required this.version,
    required this.type,
    required this.signature,
  });

  @override
  String toString() => 'NativeQryptaRoute(v: $version, type: $type)';
}

/// Router payload pemindaian QR (Phase 6.1 / F-14 / F-14b).
///
/// Menegakkan urutan deteksi deterministik tanpa komputasi tebakan (Golden Rule R1 & R4):
/// 1. Diawali '000201' -> kandidat EMVCo/QRIS -> QrisParser.
/// 2. Regex ^0x[0-9a-fA-F]{40}$ -> alamat dompet EVM langsung (validasi EIP-55 bila huruf campuran).
/// 3. JSON berskema versi terdefinisi {"v":1,"type":...,"sig":...} -> QR native Qrypta dengan verifikasi tanda tangan.
/// 4. Selain itu -> melempar ValidationFailure("QR tidak dikenali").
class QrPayloadRouter {
  const QrPayloadRouter._();

  static final RegExp _evmAddressRegex = RegExp(r'^0x[0-9a-fA-F]{40}$');

  /// Memeriksa apakah sebuah string alamat Ethereum menggunakan mixed-case.
  static bool _isMixedCase(String s) {
    final hexLetters = s.startsWith('0x') ? s.substring(2) : s;
    final onlyLetters = hexLetters.replaceAll(RegExp(r'[0-9]'), '');
    if (onlyLetters.isEmpty) return false;
    final hasLower = onlyLetters.split('').any((c) => c.toLowerCase() == c && c.toUpperCase() != c);
    final hasUpper = onlyLetters.split('').any((c) => c.toUpperCase() == c && c.toLowerCase() != c);
    return hasLower && hasUpper;
  }

  /// Memverifikasi format tanda tangan kriptografi secp256k1 (65 bytes = 130 hex + 0x prefix = 132 chars).
  static bool _isValidSignatureHex(String sig) {
    if (!sig.startsWith('0x')) return false;
    final hexPart = sig.substring(2);
    if (hexPart.length != 130) return false;
    return RegExp(r'^[0-9a-fA-F]+$').hasMatch(hexPart);
  }

  /// Menentukan rute payload QR secara sinkronus.
  /// Melempar [ValidationFailure] jika format QR tidak dikenali atau verifikasi gagal.
  static QrRouteResult route(String rawData) {
    final trimmed = rawData.trim();
    if (trimmed.isEmpty) {
      throw const ValidationFailure('Payload QR kosong.');
    }

    // 1. Kandidat EMVCo/QRIS: Wajib diawali 000201
    if (trimmed.startsWith('000201')) {
      final qris = QrisParser.parse(trimmed);
      return QrisRoute(qris);
    }

    // 2. Alamat Dompet EVM Standar: 0x diikuti 40 karakter heksadesimal
    if (_evmAddressRegex.hasMatch(trimmed)) {
      if (_isMixedCase(trimmed)) {
        try {
          // Validasi ketat checksum EIP-55
          EthereumAddress.fromHex(trimmed, enforceEip55: true);
        } catch (_) {
          throw const ValidationFailure(
            'Alamat Ethereum memiliki format checksum EIP-55 tidak valid.',
          );
        }
      } else {
        try {
          EthereumAddress.fromHex(trimmed);
        } catch (_) {
          throw const ValidationFailure(
            'Alamat Ethereum tidak valid.',
          );
        }
      }
      return WalletAddressRoute(trimmed);
    }

    // 3. JSON dengan Skema Versi Terdefinisi (Protokol Native Qrypta)
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map<String, dynamic>) {
          final version = decoded['v'] ?? decoded['version'];
          final type = decoded['type']?.toString();
          final sig = decoded['sig']?.toString() ?? decoded['signature']?.toString();

          if (version != null && type != null && sig != null) {
            final vInt = int.tryParse(version.toString());
            if (vInt == null || vInt < 1) {
              throw const ValidationFailure(
                'Versi skema QR native Qrypta tidak didukung.',
              );
            }

            if (!_isValidSignatureHex(sig)) {
              throw const ValidationFailure(
                'Tanda tangan kriptografi QR native Qrypta tidak valid (format secp256k1 salah).',
              );
            }

            return NativeQryptaRoute(
              payload: decoded,
              version: vInt,
              type: type,
              signature: sig,
            );
          }
        }
      } on FormatException {
        throw const ValidationFailure('Format JSON QR rusak atau tidak valid.');
      }
    }

    // 4. Selain itu -> Gagal terdefinisi (Tidak ada tebakan kata kunci)
    throw const ValidationFailure('QR tidak dikenali.');
  }

  /// Menentukan rute payload QR dengan parsing QRIS pada background Isolate.
  static Future<QrRouteResult> routeAsync(String rawData) async {
    final trimmed = rawData.trim();
    if (trimmed.startsWith('000201')) {
      final qris = await QrisParser.parseInIsolate(trimmed);
      return QrisRoute(qris);
    }
    return route(trimmed);
  }
}
