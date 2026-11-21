// lib/src/features/authentication/data/nfc/iso_dep_transceiver.dart

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:qrypta/src/core/error/app_failure.dart';

/// Abstraksi driver transceiver ISO-DEP (ISO 14443-4) untuk transmisi APDU ke chip e-Passport (Phase 8.1).
abstract class IsoDepTransceiver {
  /// Mengirimkan raw APDU command bytes dan menerima response APDU bytes (termasuk status word SW1-SW2).
  Future<Uint8List> transceive(Uint8List apdu);

  /// Mengatur batas waktu timeout komunikasi (dalam milidetik).
  Future<void> setTimeout(int timeoutMs);

  /// Menutup kanal koneksi dengan tag paspor.
  Future<void> close();

  /// Apakah transceiver saat ini dalam status terhubung aktif.
  bool get isConnected;
}

/// Implementasi transceiver ISO-DEP berbasis driver perangkat native (Android/iOS via nfc_manager).
class NfcManagerIsoDepTransceiver implements IsoDepTransceiver {
  final IsoDepAndroid? _isoDepAndroid;
  bool _closed = false;

  NfcManagerIsoDepTransceiver._(this._isoDepAndroid);

  /// Menginstansiasi transceiver dari [NfcTag] yang terdeteksi oleh NfcManager session.
  /// Melempar [NfcHardwareUnavailable] atau [NfcTagLost] bila tag bukan ISO-DEP kompatibel.
  static NfcManagerIsoDepTransceiver fromTag(NfcTag tag) {
    final isoDep = IsoDepAndroid.from(tag);
    if (isoDep == null) {
      throw const NfcHardwareUnavailable(
        'Kartu pintar yang terdeteksi bukan chip e-Passport ISO 14443-4 (IsoDep tidak didukung)',
      );
    }
    return NfcManagerIsoDepTransceiver._(isoDep);
  }

  @override
  bool get isConnected => !_closed && _isoDepAndroid != null;

  @override
  Future<Uint8List> transceive(Uint8List apdu) async {
    if (_closed || _isoDepAndroid == null) {
      throw const NfcTagLost('Koneksi ke chip paspor telah ditutup');
    }
    try {
      final response = await _isoDepAndroid.transceive(apdu);
      return response;
    } on PlatformException catch (e) {
      final msg = e.message?.toLowerCase() ?? '';
      if (msg.contains('lost') || msg.contains('disconnect') || msg.contains('out of date')) {
        throw NfcTagLost('Tag paspor tergeser dari antena ponsel: ${e.message}');
      }
      if (msg.contains('timeout')) {
        throw const RequestTimeout('Batas waktu respons chip paspor habis (IsoDep timeout)');
      }
      throw NfcApduException('Kesalahan transmisi hardware IsoDep: ${e.message}');
    } on Object catch (e) {
      if (e is AppFailure) rethrow;
      throw NfcApduException('Kesalahan transmisi IsoDep tidak terduga: $e');
    }
  }

  @override
  Future<void> setTimeout(int timeoutMs) async {
    if (_closed || _isoDepAndroid == null) return;
    try {
      await _isoDepAndroid.setTimeout(timeoutMs);
    } on Object catch (e) {
      // Beberapa chipset tidak mengizinkan modifikasi timeout secara dinamis
      if (e is AppFailure) rethrow;
    }
  }

  @override
  Future<void> close() async {
    _closed = true;
  }
}

/// Handler fungsi respons APDU simulasi untuk pengujian unit dan chaos (Level L1 / L3).
typedef ApduHandler = FutureOr<Uint8List> Function(Uint8List requestApdu);

/// Transceiver in-memory deterministik untuk pengujian logika APDU, BAC, dan SOD tanpa bergantung hardware HP fisik.
class MemoryIsoDepTransceiver implements IsoDepTransceiver {
  final Map<String, Uint8List> _scriptedResponses = {};
  ApduHandler? _customHandler;
  bool _closed = false;
  bool _simulateTagLossOnNextCall = false;
  int _timeoutMs = 5000;

  MemoryIsoDepTransceiver({Map<String, Uint8List>? scriptedResponses, ApduHandler? customHandler}) {
    if (scriptedResponses != null) {
      _scriptedResponses.addAll(scriptedResponses);
    }
    _customHandler = customHandler;
  }

  /// Mendaftarkan respons kartu untuk perintah APDU heksadesimal tertentu.
  void registerApduResponse(String requestHex, Uint8List responseBytes) {
    _scriptedResponses[requestHex.replaceAll(' ', '').toUpperCase()] = responseBytes;
  }

  /// Mensimulasikan kegagalan fisik tag terlepas pada transmisi berikutnya (Chaos testing).
  void triggerTagLoss() {
    _simulateTagLossOnNextCall = true;
  }

  @override
  bool get isConnected => !_closed;

  @override
  Future<Uint8List> transceive(Uint8List apdu) async {
    if (_closed) {
      throw const NfcTagLost('Transceiver memori telah ditutup');
    }
    if (_simulateTagLossOnNextCall) {
      _simulateTagLossOnNextCall = false;
      throw const NfcTagLost('Tag paspor tergeser di tengah pembacaan binary (simulasi)');
    }

    if (_customHandler != null) {
      return await _customHandler!(apdu);
    }

    final hex = apdu.map((b) => b.toRadixString(16).padLeft(2, '0')).join('').toUpperCase();
    if (_scriptedResponses.containsKey(hex)) {
      return _scriptedResponses[hex]!;
    }

    // Default status word 6D00 (Instruction not supported) bila tidak terdaftar
    return Uint8List.fromList([0x6D, 0x00]);
  }

  @override
  Future<void> setTimeout(int timeoutMs) async {
    _timeoutMs = timeoutMs;
  }

  @override
  Future<void> close() async {
    _closed = true;
  }
}
