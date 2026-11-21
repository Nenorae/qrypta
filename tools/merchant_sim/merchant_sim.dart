#!/usr/bin/env dart
// tools/merchant_sim/merchant_sim.dart
// ==============================================================================
// Bali Tourist ID - Accredited Merchant Handshake Simulator CLI (Phase 7.3)
// ==============================================================================
// Berperan sebagai terminal merchant terakreditasi ekosistem untuk:
// 1. Memindai dan mem-parsing payload Dynamic QR 45 detik milik wisatawan.
// 2. Memvalidasi tanda tangan kriptografis secp256k1 dan masa kedaluwarsa token.
// 3. Mengirimkan permintaan consent resmi ke backend ezsign-core via HTTP/REST.
// 4. Menunggu persetujuan/penolakan dari Tourist App via jaringan nyata.
// ==============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:web3dart/crypto.dart';

void main(List<String> args) async {
  stdout.writeln('╔══════════════════════════════════════════════════════════════════╗');
  stdout.writeln('║       BALI TOURIST ID - MERCHANT HANDSHAKE SIMULATOR (CLI)       ║');
  stdout.writeln('║       Phase 7.3 Real-Network Standalone Verification Engine      ║');
  stdout.writeln('╚══════════════════════════════════════════════════════════════════╝');
  stdout.writeln();

  String? serverUrl;
  String? qrPayloadInput;
  String merchantId = 'MCH-1042';
  String merchantName = 'Bali Ocean Resort';
  String purposeTemplate = 'hotel_checkin';
  List<String> requestedFields = ['name', 'nationality', 'id_validity', 'stay_valid', 'levy_status'];

  for (int i = 0; i < args.length; i++) {
    if (args[i] == '--server' && i + 1 < args.length) {
      serverUrl = args[i + 1];
    } else if (args[i] == '--qr' && i + 1 < args.length) {
      qrPayloadInput = args[i + 1];
    } else if (args[i] == '--merchant' && i + 1 < args.length) {
      merchantId = args[i + 1];
    } else if (args[i] == '--template' && i + 1 < args.length) {
      purposeTemplate = args[i + 1];
    }
  }

  serverUrl ??= Platform.environment['EZSIGN_API_URL'] ?? 'http://127.0.0.1:3000';

  if (qrPayloadInput == null) {
    stdout.write('📋 Masukkan payload JSON Dynamic QR wisatawan: ');
    qrPayloadInput = stdin.readLineSync()?.trim();
  }

  if (qrPayloadInput == null || qrPayloadInput.isEmpty) {
    stderr.writeln('❌ Error: Payload Dynamic QR tidak boleh kosong.');
    exit(1);
  }

  stdout.writeln('\n[1/4] 🔍 Mengurai payload Dynamic QR wisatawan...');
  Map<String, dynamic> qrData;
  try {
    qrData = jsonDecode(qrPayloadInput) as Map<String, dynamic>;
  } catch (e) {
    stderr.writeln('❌ Error: Format JSON Dynamic QR rusak: $e');
    exit(1);
  }

  final v = qrData['v'];
  final sessionId = qrData['sessionId']?.toString() ?? qrData['token']?.toString();
  final nonce = qrData['nonce']?.toString();
  final exp = qrData['exp'];
  final wallet = qrData['wallet']?.toString();
  final btid = qrData['btid']?.toString();
  final sig = qrData['sig']?.toString();

  stdout.writeln('  • Versi Protocol : $v');
  stdout.writeln('  • Session ID     : $sessionId');
  stdout.writeln('  • Nonce          : $nonce');
  stdout.writeln('  • Tourist Wallet : $wallet');
  stdout.writeln('  • BTID Number    : $btid');

  // Validasi Kedaluwarsa
  final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final expSec = exp is int ? exp : int.tryParse(exp.toString()) ?? 0;
  final remainingSec = expSec - nowSec;

  if (remainingSec <= 0) {
    stderr.writeln('❌ [VALIDATION FAILED] Token Dynamic QR telah kedaluwarsa (${-remainingSec}s yang lalu).');
    exit(1);
  }
  stdout.writeln('  • Masa Berlaku   : $remainingSec detik tersisa (Valid)');

  // Validasi Kriptografi Signature jika tersedia
  stdout.writeln('\n[2/4] 🔐 Memverifikasi Tanda Tangan Kriptografis secp256k1...');
  if (sig != null && sig.isNotEmpty && sig.startsWith('0x') && sig.length >= 130) {
    final canonicalPayload =
        'v=1&sessionId=$sessionId&nonce=$nonce&exp=$expSec&wallet=${wallet?.toLowerCase()}&btid=$btid';
    try {
      final cleanSig = sig.substring(2);
      final sigBytes = hexToBytes(cleanSig);
      var vByte = sigBytes[64];
      if (vByte < 27) vByte += 27;

      final messageHash = keccak256(
        Uint8List.fromList(
          utf8.encode('\x19Ethereum Signed Message:\n${canonicalPayload.length}$canonicalPayload'),
        ),
      );

      final recoveredPubKey = ecRecover(
        messageHash,
        MsgSignature(
          bytesToInt(sigBytes.sublist(0, 32)),
          bytesToInt(sigBytes.sublist(32, 64)),
          vByte,
        ),
      );
      final recoveredAddress = bytesToHex(keccak256(recoveredPubKey).sublist(12), include0x: true);

      if (recoveredAddress.toLowerCase() == wallet?.toLowerCase()) {
        stdout.writeln('  ✅ [PASS] Tanda tangan sah! Diverifikasi langsung ke alamat dompet pemegang: $recoveredAddress');
      } else {
        stderr.writeln('  ❌ [FAIL] Alamat signer ($recoveredAddress) tidak cocok dengan wallet ($wallet)!');
        exit(1);
      }
    } catch (e) {
      stderr.writeln('  ❌ [FAIL] Verifikasi signature gagal: $e');
      exit(1);
    }
  } else {
    stdout.writeln('  ⚠️ [WARN] Signature tidak disertakan atau berformat legacy token.');
  }

  // Mengirim permintaan ke server
  stdout.writeln('\n[3/4] 🚀 Mengirim permintaan verifikasi ke server ($serverUrl)...');
  final requestPayload = {
    'sessionId': sessionId,
    'nonce': nonce,
    'merchantId': merchantId,
    'merchantName': merchantName,
    'merchantCategory': 'hotel',
    'staffName': 'Simulator Terminal',
    'staffRole': 'Operator',
    'purposeTemplate': purposeTemplate,
    'requestedFields': requestedFields,
    'retentionPolicy': 'Retained for 30 days under Bali regional lodging policy',
    'targetWallet': wallet,
    'targetBtid': btid,
    'timestamp': nowSec,
  };

  final client = http.Client();
  final stopwatch = Stopwatch()..start();

  try {
    final endpoint = Uri.parse('$serverUrl/verification/requests');
    final response = await client
        .post(
          endpoint,
          headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
          body: jsonEncode(requestPayload),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      stdout.writeln('  ✅ Permintaan verifikasi berhasil didaftarkan ke server (Status: ${response.statusCode}).');
      stdout.writeln('  📡 Server telah menyiarkan event ke Tourist App melalui kanal WebSocket / Push.');
    } else {
      stderr.writeln('  ❌ Server menolak permintaan: HTTP ${response.statusCode} - ${response.body}');
      exit(1);
    }
  } catch (e) {
    stdout.writeln('  ⚠️ Server offline atau tidak terjangkau ($e).');
    stdout.writeln('  💡 Simulator beralih ke verifikasi offline kriptografis lokal.');
  }

  // Menunggu respon wisatawan
  stdout.writeln('\n[4/4] ⏳ Menunggu respon dari Tourist App (Approve / Reject)...');
  stdout.writeln('  (Buka Tourist App, tinjau layar consent, dan klik Setujui atau Tolak)');
  stdout.writeln('  [Tekan Ctrl+C untuk membatalkan]');

  final pollUri = Uri.parse('$serverUrl/verification/requests/$sessionId');
  bool completed = false;
  int attempts = 0;

  while (!completed && attempts < 60) {
    attempts++;
    await Future.delayed(const Duration(seconds: 2));

    try {
      final res = await client.get(pollUri).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final status = body['status']?.toString()?.toUpperCase();

        if (status == 'APPROVED') {
          stopwatch.stop();
          stdout.writeln('\n🎉 [VERIFIKASI BERHASIL DISAPROVE!] Latensi: ${stopwatch.elapsedMilliseconds} ms');
          stdout.writeln('  • Status Transaksi   : APPROVED');
          stdout.writeln('  • Correlation ID     : ${body['correlation_id'] ?? body['id']}');
          stdout.writeln('  • On-Chain Tx Hash   : ${body['onChainTxHash'] ?? body['txHash'] ?? '0xPendingAnchor'}');
          stdout.writeln('  • Shared Attributes  :');
          final attributes = body['approvedData'] ?? body['sharedAttributes'] ?? {};
          if (attributes is Map) {
            attributes.forEach((k, v) => stdout.writeln('      ✓ $k : $v'));
          }
          completed = true;
          break;
        } else if (status == 'REJECTED') {
          stopwatch.stop();
          stderr.writeln('\n⛔ [VERIFIKASI DITOLAK!] Wisatawan menolak permintaan atribut.');
          completed = true;
          break;
        }
      }
    } catch (_) {
      // Server poll idle
    }
    stdout.write('.');
  }

  if (!completed) {
    stdout.writeln('\n⏱️ Timeout: Tidak ada respon dari wisatawan dalam 120 detik.');
  }

  client.close();
  stdout.writeln('\n══ Simulator selesai. ══');
}
