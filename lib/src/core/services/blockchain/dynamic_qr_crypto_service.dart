// lib/src/core/services/blockchain/dynamic_qr_crypto_service.dart

import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';
import 'dart:typed_data';

import 'package:qrypta/src/core/error/app_failure.dart';
import 'package:qrypta/src/core/utils/uuid_util.dart';
import 'package:web3dart/crypto.dart';
import 'package:web3dart/web3dart.dart';

/// Layanan kriptografi untuk pembuatan dan verifikasi tanda tangan Dynamic Rotating QR (Phase 7.1).
class DynamicQrCryptoService {
  static const String _logTag = 'DynamicQrCrypto';

  /// Membersihkan prefix '0x' dan memvalidasi panjang kunci heksadesimal privat.
  static String cleanHexKey(String key) {
    var clean = key.trim();
    if (clean.startsWith('0x') || clean.startsWith('0X')) {
      clean = clean.substring(2);
    }
    return clean.padLeft(64, '0');
  }

  /// Menghasilkan payload JSON Dynamic Rotating QR Code berdurasi 45 detik (Phase 7.1).
  ///
  /// Menegakkan spesifikasi Phase 7.1:
  /// - `v`: versi protokol (1)
  /// - `sessionId`: UUID unik per sesi
  /// - `nonce`: nilai heksadesimal acak anti-replay
  /// - `exp`: timestamp Unix kedaluwarsa (sekarang + validitySeconds)
  /// - `wallet`: alamat wallet turis
  /// - `btid`: nomor resmi Bali Tourist ID
  /// - `token`: kode representasi visual alfanumerik (QRT-XXXXXXXXXX)
  /// - `sig`: tanda tangan digital secp256k1 atas payload kanonikal
  static String generateDynamicQrToken(
    String btid,
    String walletAddress, {
    String? privateKeyHex,
    String? customSessionId,
    String? customNonce,
    int validitySeconds = 45,
  }) {
    if (btid.isEmpty) {
      throw const ValidationFailure('BTID tidak boleh kosong saat membuat token QR dinamis.');
    }
    const chars = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
    final random = Random.secure();
    final tokenCode = StringBuffer('QRT-');
    for (int i = 0; i < 10; i++) {
      tokenCode.write(chars[random.nextInt(chars.length)]);
    }

    final sessionId = customSessionId ?? UuidUtil.generateV4();
    final nonceBytes = Uint8List(16);
    for (int i = 0; i < 16; i++) {
      nonceBytes[i] = random.nextInt(256);
    }
    final nonce = customNonce ?? '0x${bytesToHex(nonceBytes)}';
    final expTimestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + validitySeconds;

    String? signatureHex;
    if (privateKeyHex != null && privateKeyHex.isNotEmpty) {
      final cleanKey = cleanHexKey(privateKeyHex);
      final ethKey = EthPrivateKey.fromHex(cleanKey);
      final canonicalPayload =
          'v=1&sessionId=$sessionId&nonce=$nonce&exp=$expTimestamp&wallet=${walletAddress.toLowerCase()}&btid=$btid';
      final sigBytes = ethKey.signPersonalMessageToUint8List(
        Uint8List.fromList(utf8.encode(canonicalPayload)),
      );
      signatureHex = '0x${bytesToHex(sigBytes)}';
    }

    final payload = {
      'v': 1,
      'sessionId': sessionId,
      'nonce': nonce,
      'exp': expTimestamp,
      'wallet': walletAddress,
      'btid': btid,
      'token': tokenCode.toString(),
      if (signatureHex != null) 'sig': signatureHex,
    };

    return jsonEncode(payload);
  }

  /// Memverifikasi keabsahan kriptografis dan masa berlaku payload QR Dinamis wisatawan (Phase 7.1).
  static bool verifyDynamicQrToken({
    required Map<String, dynamic> payload,
    int? currentEpochSeconds,
  }) {
    final v = payload['v'];
    final sessionId = payload['sessionId']?.toString();
    final nonce = payload['nonce']?.toString();
    final exp = payload['exp'];
    final wallet = payload['wallet']?.toString();
    final btid = payload['btid']?.toString();
    final sig = payload['sig']?.toString();

    if (v != 1 || sessionId == null || nonce == null || exp == null || wallet == null || btid == null) {
      return false;
    }

    final expInt = exp is int ? exp : int.tryParse(exp.toString());
    if (expInt == null) return false;

    final nowSec = currentEpochSeconds ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);
    if (expInt <= nowSec) {
      return false; // Kedaluwarsa
    }

    if (sig == null || !sig.startsWith('0x') || sig.length < 130) {
      return false; // Signature tidak ada atau tidak valid
    }

    try {
      final canonicalPayload =
          'v=1&sessionId=$sessionId&nonce=$nonce&exp=$expInt&wallet=${wallet.toLowerCase()}&btid=$btid';
      final cleanSig = sig.startsWith('0x') ? sig.substring(2) : sig;
      final sigBytes = hexToBytes(cleanSig);

      var vByte = sigBytes[64];
      if (vByte < 27) vByte += 27;

      final messageHash = keccak256(
        Uint8List.fromList(
          utf8.encode('\x19Ethereum Signed Message:\n${canonicalPayload.length}$canonicalPayload'),
        ),
      );

      final recoveredPublicKey = ecRecover(
        messageHash,
        MsgSignature(
          bytesToUnsignedInt(sigBytes.sublist(0, 32)),
          bytesToUnsignedInt(sigBytes.sublist(32, 64)),
          vByte,
        ),
      );

      final recoveredAddress = bytesToHex(
        keccak256(recoveredPublicKey).sublist(12),
        include0x: true,
      );

      return recoveredAddress.toLowerCase() == wallet.toLowerCase();
    } on Object catch (e, st) {
      developer.log('verifyDynamicQrToken failed: $e\n$st', name: _logTag);
      return false;
    }
  }
}
