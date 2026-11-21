// lib/src/features/authentication/domain/models/nfc_passport_models.dart

import 'dart:typed_data';
import 'package:qrypta/src/core/utils/mrz_parser.dart';

/// Tahapan status pembacaan chip NFC e-Passport secara riil (Phase 8.1 #5).
/// Menggantikan timer delay animasi palsu di ScrNfc.
enum NfcReadStage {
  idle,
  checkingHardware,
  waitingForPassport,
  establishingSecureChannel,
  readingEfCom,
  readingDg1,
  readingEfSod,
  completed,
  error;

  String get humanReadableDescription {
    switch (this) {
      case NfcReadStage.idle:
        return 'Ready to scan ePassport';
      case NfcReadStage.checkingHardware:
        return 'Checking NFC hardware status...';
      case NfcReadStage.waitingForPassport:
        return 'Hold passport firmly against phone NFC area';
      case NfcReadStage.establishingSecureChannel:
        return 'Establishing secure channel (BAC/PACE)...';
      case NfcReadStage.readingEfCom:
        return 'Reading elementary file directory (EF.COM)...';
      case NfcReadStage.readingDg1:
        return 'Reading passport MRZ data (DG1)...';
      case NfcReadStage.readingEfSod:
        return 'Reading signed security object (EF.SOD)...';
      case NfcReadStage.completed:
        return 'Passport chip read successfully!';
      case NfcReadStage.error:
        return 'Passport chip read error';
    }
  }

  double get progressFraction {
    switch (this) {
      case NfcReadStage.idle:
        return 0.0;
      case NfcReadStage.checkingHardware:
        return 0.1;
      case NfcReadStage.waitingForPassport:
        return 0.25;
      case NfcReadStage.establishingSecureChannel:
        return 0.45;
      case NfcReadStage.readingEfCom:
        return 0.65;
      case NfcReadStage.readingDg1:
        return 0.80;
      case NfcReadStage.readingEfSod:
        return 0.95;
      case NfcReadStage.completed:
        return 1.0;
      case NfcReadStage.error:
        return 0.0;
    }
  }
}

/// Status hasil verifikasi kriptografis Passive Authentication (ICAO Doc 9303 Part 10 & Phase 8.2).
enum PassiveAuthStatus {
  /// Seluruh hash Data Group cocok dengan EF.SOD, signature DSC sah, dan CSCA terverifikasi di Master List.
  genuine,

  /// Salah satu atau lebih hash DG (mis. DG1) tidak cocok dengan hash list di LDSSecurityObject (termodifikasi).
  hashMismatch,

  /// Tanda tangan digital EF.SOD tidak dapat diverifikasi menggunakan kunci publik DSC.
  signatureInvalid,

  /// Sertifikat penandatangan dokumen (DSC) telah kedaluwarsa atau belum berlaku.
  expiredDsc,

  /// Hash dan signature valid secara matematis, namun root CSCA negara penerbit tidak ditemukan di trust store lokal.
  /// Ditampilkan jujur sesuai spesifikasi Phase 8.2 tanpa memalsukan status verifikasi otoritas.
  unverifiedNoTrustAnchor,

  /// Struktur ASN.1 CMS SignedData rusak atau tidak dapat di-parse.
  parseError;

  bool get isGenuine => this == PassiveAuthStatus.genuine;
  bool get isTampered => this == PassiveAuthStatus.hashMismatch || this == PassiveAuthStatus.signatureInvalid;
}

/// Hasil verifikasi Passive Authentication (PA) lengkap (Phase 8.2 #5).
class PassiveAuthResult {
  final bool isValid;
  final PassiveAuthStatus status;
  final List<String> reasons;
  final String issuingCountry;
  final String dscSubject;
  final String dscIssuer;
  final String dscSerial;
  final String hashAlgorithm;
  final String signatureAlgorithm;
  final Map<int, bool> dgHashesMatched;
  final String? cscaCountry;

  const PassiveAuthResult({
    required this.isValid,
    required this.status,
    required this.reasons,
    required this.issuingCountry,
    required this.dscSubject,
    required this.dscIssuer,
    required this.dscSerial,
    required this.hashAlgorithm,
    required this.signatureAlgorithm,
    required this.dgHashesMatched,
    this.cscaCountry,
  });

  bool get isGenuine => status == PassiveAuthStatus.genuine;
  bool get isTampered => status.isTampered;
  bool get hasTrustAnchor => status != PassiveAuthStatus.unverifiedNoTrustAnchor;

  Map<String, dynamic> toJson() {
    return {
      'isValid': isValid,
      'status': status.name,
      'reasons': reasons,
      'issuingCountry': issuingCountry,
      'dscSubject': dscSubject,
      'dscIssuer': dscIssuer,
      'dscSerial': dscSerial,
      'hashAlgorithm': hashAlgorithm,
      'signatureAlgorithm': signatureAlgorithm,
      'dgHashesMatched': dgHashesMatched.map((k, v) => MapEntry(k.toString(), v)),
      'cscaCountry': cscaCountry,
    };
  }

  @override
  String toString() =>
      'PassiveAuthResult(status: ${status.name}, country: $issuingCountry, dscSerial: $dscSerial, valid: $isValid)';
}

/// Data terpadu hasil pembacaan chip e-Passport fisik (Phase 8.1).
class PassportChipData {
  final String ldsVersion;
  final List<int> dataGroupsPresent;
  final Uint8List rawDg1;
  final Uint8List rawEfSod;
  final MrzParseResult chipMrz;
  final PassiveAuthResult passiveAuth;
  final int readDurationMs;

  const PassportChipData({
    required this.ldsVersion,
    required this.dataGroupsPresent,
    required this.rawDg1,
    required this.rawEfSod,
    required this.chipMrz,
    required this.passiveAuth,
    required this.readDurationMs,
  });

  Map<String, dynamic> toJson() {
    return {
      'ldsVersion': ldsVersion,
      'dataGroupsPresent': dataGroupsPresent,
      'chipMrz': {
        'documentNumber': chipMrz.documentNumber,
        'nationality': chipMrz.nationality,
        'dob': chipMrz.birthDateFormatted,
        'expiry': chipMrz.expiryDateFormatted,
        'fullName': chipMrz.fullName,
      },
      'passiveAuth': passiveAuth.toJson(),
      'readDurationMs': readDurationMs,
    };
  }
}
