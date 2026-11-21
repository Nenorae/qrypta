// lib/src/features/authentication/data/nfc/nfc_passport_service.dart

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:qrypta/src/core/error/app_failure.dart';
import 'package:qrypta/src/core/utils/mrz_parser.dart';
import 'package:qrypta/src/features/authentication/data/nfc/apdu_service.dart';
import 'package:qrypta/src/features/authentication/data/nfc/bac_crypto.dart';
import 'package:qrypta/src/features/authentication/data/nfc/csca_trust_store.dart';
import 'package:qrypta/src/features/authentication/data/nfc/iso_dep_transceiver.dart';
import 'package:qrypta/src/features/authentication/data/nfc/passive_auth_service.dart';
import 'package:qrypta/src/features/authentication/domain/models/nfc_passport_models.dart';

/// Callback untuk memantau kemajuan pembacaan chip NFC secara riil (Phase 8.1 #5).
typedef NfcProgressCallback = void Function(NfcReadStage stage, String message);

/// Service orkestrasi pembacaan chip e-Passport NFC dan Passive Authentication (Phase 8).
class NfcPassportService {
  final PassiveAuthService _passiveAuthService;
  final CscaTrustStore _trustStore;

  NfcPassportService({
    PassiveAuthService? passiveAuthService,
    CscaTrustStore? trustStore,
  })  : _trustStore = trustStore ?? CscaTrustStore(),
        _passiveAuthService = passiveAuthService ??
            PassiveAuthService(trustStore: trustStore ?? CscaTrustStore());

  /// Memeriksa ketersediaan dan status hardware NFC pada perangkat fisik (Phase 8.1 #1).
  Future<NfcAvailability> checkHardwareAvailability() async {
    try {
      return await NfcManager.instance.checkAvailability();
    } on Object catch (e) {
      if (e is AppFailure) rethrow;
      return NfcAvailability.unsupported;
    }
  }

  /// Menjalankan sesi pembacaan chip e-Passport terautentikasi melalui transceiver ISO-DEP.
  Future<PassportChipData> readPassport({
    required IsoDepTransceiver transceiver,
    required MrzParseResult cameraMrz,
    NfcProgressCallback? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();

    // 1. Verifikasi koneksi fisik transceiver
    onProgress?.call(NfcReadStage.checkingHardware, 'Connecting to passport contactless antenna...');
    if (!transceiver.isConnected) {
      throw const NfcTagLost('Transceiver paspor tidak terhubung');
    }

    // 2. Select Application ICAO (AID: A0000002471001)
    onProgress?.call(NfcReadStage.establishingSecureChannel, 'Selecting ICAO ePassport application...');
    await ApduService.selectPassportApplication(transceiver);

    // 3. Negosiasi BAC (Basic Access Control)
    onProgress?.call(NfcReadStage.establishingSecureChannel, 'Establishing secure channel (BAC/PACE)...');
    final rndIcc = await ApduService.getChallenge(transceiver);

    // Turunkan kunci Kseed, Kenc, Kmac dari MRZ hasil scan kamera (Phase 5A)
    final kseed = BacCrypto.deriveBacSeedFromMrz(
      documentNumber: cameraMrz.documentNumber,
      birthDate: cameraMrz.birthDateFormatted,
      expiryDate: cameraMrz.expiryDateFormatted,
    );
    final kenc = BacCrypto.deriveBacKey(kseed, 1);
    final kmac = BacCrypto.deriveBacKey(kseed, 2);

    // Bangkitkan bilangan acak perangkat IFD
    final random = Random.secure();
    final rndIfd = Uint8List(8);
    for (int i = 0; i < 8; i++) {
      rndIfd[i] = random.nextInt(256);
    }
    final kIfd = Uint8List(16);
    for (int i = 0; i < 16; i++) {
      kIfd[i] = random.nextInt(256);
    }

    final authData = BacCrypto.buildExternalAuthenticateData(
      kenc: kenc,
      kmac: kmac,
      rndIcc: rndIcc,
      rndIfd: rndIfd,
      kIfd: kIfd,
    );

    final cardCryptogram = await ApduService.externalAuthenticate(transceiver, authData);
    final sessionKeys = BacCrypto.verifyExternalAuthenticateResponse(
      kenc: kenc,
      kmac: kmac,
      rndIfd: rndIfd,
      responseBytes: cardCryptogram,
    );

    // 4. Membaca EF.COM (File ID 011E)
    onProgress?.call(NfcReadStage.readingEfCom, 'Reading elementary file directory (EF.COM)...');
    final efComBytes = await ApduService.readFullElementaryFile(
      transceiver,
      ApduService.fileIdEfCom,
      sessionKeys,
    );
    final parsedEfCom = _parseEfCom(efComBytes);

    // 5. Membaca DG1 (File ID 0101) - Data MRZ Chip
    onProgress?.call(NfcReadStage.readingDg1, 'Reading passport data (DG1: MRZ)...');
    final dg1Bytes = await ApduService.readFullElementaryFile(
      transceiver,
      ApduService.fileIdDg1,
      sessionKeys,
    );
    final chipMrz = _parseDg1Mrz(dg1Bytes);

    // 6. VALIDASI KRITIS (Phase 8.1 #3): Cocokkan DG1 Chip dengan MRZ OCR Kamera!
    checkMrzConsistency(cameraMrz: cameraMrz, chipMrz: chipMrz);

    // 7. Membaca EF.SOD (File ID 011D) - Security Object for Data
    onProgress?.call(NfcReadStage.readingEfSod, 'Reading signed security data (SOD)...');
    final efSodBytes = await ApduService.readFullElementaryFile(
      transceiver,
      ApduService.fileIdEfSod,
      sessionKeys,
    );

    // 8. Verifikasi Kriptografis Passive Authentication (PA)
    onProgress?.call(NfcReadStage.readingEfSod, 'Cryptographically verifying SOD against ICAO PKD CSCA...');
    final passiveAuthResult = _passiveAuthService.verifyPassiveAuthentication(
      rawSod: efSodBytes,
      dataGroups: {1: dg1Bytes},
      issuingCountry: chipMrz.nationality.isNotEmpty ? chipMrz.nationality : cameraMrz.nationality,
    );

    stopwatch.stop();
    onProgress?.call(NfcReadStage.completed, 'Chip read and Passive Authentication completed!');

    return PassportChipData(
      ldsVersion: parsedEfCom.ldsVersion,
      dataGroupsPresent: parsedEfCom.tagsPresent,
      rawDg1: dg1Bytes,
      rawEfSod: efSodBytes,
      chipMrz: chipMrz,
      passiveAuth: passiveAuthResult,
      readDurationMs: stopwatch.elapsedMilliseconds,
    );
  }

  /// Memulai sesi scanning NFC fisik dengan polling tag ISO 14443-4 pada HP Android (Phase 8.1).
  Future<void> startPhysicalScanningSession({
    required MrzParseResult cameraMrz,
    required NfcProgressCallback onProgress,
    required void Function(PassportChipData data) onSuccess,
    required void Function(AppFailure failure) onError,
  }) async {
    final availability = await checkHardwareAvailability();
    if (availability == NfcAvailability.disabled) {
      onError(const NfcHardwareUnavailable('NFC is disabled. Please enable NFC in settings.'));
      return;
    }
    if (availability == NfcAvailability.unsupported) {
      onError(const NfcHardwareUnavailable('NFC is not supported on this device.', isSupported: false));
      return;
    }

    onProgress(NfcReadStage.waitingForPassport, 'Hold passport firmly against phone NFC area');

    try {
      await NfcManager.instance.startSession(
        pollingOptions: {NfcPollingOption.iso14443},
        onDiscovered: (NfcTag tag) async {
          try {
            final transceiver = NfcManagerIsoDepTransceiver.fromTag(tag);
            final result = await readPassport(
              transceiver: transceiver,
              cameraMrz: cameraMrz,
              onProgress: onProgress,
            );
            await NfcManager.instance.stopSession();
            onSuccess(result);
          } on AppFailure catch (e) {
            await NfcManager.instance.stopSession();
            onError(e);
          } on Object catch (e) {
            await NfcManager.instance.stopSession();
            onError(NfcApduException('NFC reading failed: $e'));
          }
        },
      );
    } on Object catch (e) {
      onError(NfcHardwareUnavailable('Failed to start NFC session: $e'));
    }
  }

  /// Membatalkan sesi scanning fisik aktif.
  Future<void> cancelScanningSession() async {
    try {
      await NfcManager.instance.stopSession();
    } on Object catch (e) {
      if (e is AppFailure) rethrow;
    }
  }

  /// Mencocokkan data MRZ chip terhadap pemindaian optik kamera (Phase 8.1 #3).
  static void checkMrzConsistency({
    required MrzParseResult cameraMrz,
    required MrzParseResult chipMrz,
  }) {
    final cleanCamDoc = cameraMrz.documentNumber.replaceAll('<', '').trim().toUpperCase();
    final cleanChipDoc = chipMrz.documentNumber.replaceAll('<', '').trim().toUpperCase();

    if (cleanCamDoc != cleanChipDoc) {
      throw NfcDataMismatch(
        'Nomor dokumen pada chip NFC ($cleanChipDoc) tidak cocok dengan kamera ($cleanCamDoc)',
        cameraDocumentNumber: cleanCamDoc,
        chipDocumentNumber: cleanChipDoc,
      );
    }

    final cleanCamDob = cameraMrz.birthDateFormatted.replaceAll(RegExp(r'[^0-9]'), '');
    final cleanChipDob = chipMrz.birthDateFormatted.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanCamDob.isNotEmpty && cleanChipDob.isNotEmpty && cleanCamDob != cleanChipDob) {
      throw NfcDataMismatch(
        'Tanggal lahir pada chip NFC ($cleanChipDob) tidak cocok dengan kamera ($cleanCamDob)',
        cameraDocumentNumber: cleanCamDoc,
        chipDocumentNumber: cleanChipDoc,
      );
    }

    final cleanCamExp = cameraMrz.expiryDateFormatted.replaceAll(RegExp(r'[^0-9]'), '');
    final cleanChipExp = chipMrz.expiryDateFormatted.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanCamExp.isNotEmpty && cleanChipExp.isNotEmpty && cleanCamExp != cleanChipExp) {
      throw NfcDataMismatch(
        'Tanggal kedaluwarsa pada chip NFC ($cleanChipExp) tidak cocok dengan kamera ($cleanCamExp)',
        cameraDocumentNumber: cleanCamDoc,
        chipDocumentNumber: cleanChipDoc,
      );
    }
  }

  /// Mem-parsing raw EF.COM (Tag 60) menjadi struktur versi LDS dan daftar tag Data Group.
  static ({String ldsVersion, List<int> tagsPresent}) _parseEfCom(Uint8List bytes) {
    if (bytes.length < 5 || bytes[0] != 0x60) {
      return (ldsVersion: '1.7', tagsPresent: [1, 2, 14]);
    }
    // Cari tag 5F01 (LDS Version) dan 5F36 (Tag list)
    int idx = 2;
    if (bytes[1] >= 0x80) {
      idx = 2 + (bytes[1] & 0x7F);
    }
    String version = '1.7';
    final List<int> tags = [];

    while (idx < bytes.length - 2) {
      final tag = bytes[idx];
      if (tag == 0x5F && idx + 1 < bytes.length) {
        final subtag = bytes[idx + 1];
        final len = bytes[idx + 2];
        if (subtag == 0x01) {
          // LDS version (4 bytes ASCII: mis. "0107")
          final vBytes = bytes.sublist(idx + 3, idx + 3 + len);
          version = utf8.decode(vBytes, allowMalformed: true);
        } else if (subtag == 0x36) {
          // Tag list
          for (int t = idx + 3; t < idx + 3 + len; t++) {
            tags.add(bytes[t]);
          }
        }
        idx += 3 + len;
      } else {
        idx++;
      }
    }

    return (
      ldsVersion: version.isNotEmpty ? version : '1.7',
      tagsPresent: tags.isNotEmpty ? tags : [1, 2, 14],
    );
  }

  /// Mem-parsing raw DG1 (Tag 61 -> Tag 5F1F -> 88 byte string MRZ TD3).
  static MrzParseResult _parseDg1Mrz(Uint8List dg1Bytes) {
    if (dg1Bytes.isEmpty) {
      throw const ValidationFailure('Byte DG1 paspor kosong');
    }
    // Cari teks string 88 karakter (2 baris x 44 karakter)
    final text = utf8.decode(dg1Bytes, allowMalformed: true);
    // Cari pattern 2 baris 44 karakter TD3
    for (int i = 0; i <= text.length - 88; i++) {
      final candidate = text.substring(i, i + 88);
      if (candidate.startsWith('P') || candidate.startsWith('I') || candidate.startsWith('A')) {
        final line1 = candidate.substring(0, 44);
        final line2 = candidate.substring(44, 88);
        final result = MrzParser.parse(line1, line2);
        if (result.passportNumber.isNotEmpty) {
          return result;
        }
      }
    }

    // Fallback bila DG1 berformat TLV murni
    if (dg1Bytes.length >= 88) {
      final tail88 = dg1Bytes.sublist(dg1Bytes.length - 88);
      final tailText = utf8.decode(tail88, allowMalformed: true);
      final line1 = tailText.substring(0, 44);
      final line2 = tailText.substring(44, 88);
      return MrzParser.parse(line1, line2);
    }

    throw const ValidationFailure('Format DG1 chip paspor tidak memuat 88-karakter MRZ TD3');
  }
}
