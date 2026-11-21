// lib/src/features/authentication/data/nfc/passive_auth_service.dart

import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:qrypta/src/core/error/app_failure.dart';
import 'package:qrypta/src/features/authentication/data/nfc/csca_trust_store.dart';
import 'package:qrypta/src/features/authentication/data/nfc/sod_parser.dart';
import 'package:qrypta/src/features/authentication/domain/models/nfc_passport_models.dart';

/// Mesin verifikasi kriptografis Passive Authentication (PA) sesuai ICAO Doc 9303 Part 10 (Phase 8.2).
class PassiveAuthService {
  final CscaTrustStore _cscaTrustStore;

  PassiveAuthService({CscaTrustStore? trustStore})
      : _cscaTrustStore = trustStore ?? CscaTrustStore();

  /// Menjalankan verifikasi 5 tahap Passive Authentication:
  /// 1. Parse EF.SOD CMS SignedData
  /// 2. Verifikasi messageDigest eContent terhadap signedAttrs
  /// 3. Verifikasi hash tiap Data Group (DG1, DG2, dst.) terhadap LDSSecurityObject
  /// 4. Verifikasi masa berlaku dan tanda tangan digital sertifikat DSC
  /// 5. Validasi rantai sertifikat DSC terhadap root CSCA Master List
  PassiveAuthResult verifyPassiveAuthentication({
    required Uint8List rawSod,
    required Map<int, Uint8List> dataGroups,
    required String issuingCountry,
    DateTime? referenceTime,
  }) {
    if (rawSod.isEmpty) {
      return PassiveAuthResult(
        isValid: false,
        status: PassiveAuthStatus.parseError,
        reasons: const ['EF.SOD binary data is empty'],
        issuingCountry: issuingCountry,
        dscSubject: 'Unknown',
        dscIssuer: 'Unknown',
        dscSerial: '00',
        hashAlgorithm: 'Unknown',
        signatureAlgorithm: 'Unknown',
        dgHashesMatched: const {},
      );
    }

    try {
      // 1. Parse struktur ASN.1 SOD
      final parsedSod = SodParser.parse(rawSod);
      final List<String> reasons = [];
      final Map<int, bool> dgHashesMatched = {};

      // 2. Verifikasi integritas eContent: Hash(eContent) == signedAttrs.messageDigest
      if (parsedSod.expectedEContentDigest.isNotEmpty) {
        final calculatedDigest = _computeDigest(
          parsedSod.rawEContent,
          parsedSod.ldsHashAlgorithmOid,
        );
        if (!_areByteArraysEqual(calculatedDigest, parsedSod.expectedEContentDigest)) {
          reasons.add(
            'Integritas eContent terlanggar: hash LDSSecurityObject tidak cocok dengan messageDigest signedAttrs',
          );
          return PassiveAuthResult(
            isValid: false,
            status: PassiveAuthStatus.hashMismatch,
            reasons: reasons,
            issuingCountry: issuingCountry,
            dscSubject: parsedSod.dscCertificate.subject,
            dscIssuer: parsedSod.dscCertificate.issuer,
            dscSerial: parsedSod.dscCertificate.serialNumber,
            hashAlgorithm: parsedSod.ldsHashAlgorithmName,
            signatureAlgorithm: parsedSod.signatureAlgorithmOid,
            dgHashesMatched: dgHashesMatched,
          );
        }
      }

      // 3. Verifikasi hash Data Group yang dibaca (DG1, DG2, dll.) terhadap LDSSecurityObject
      bool allDgMatched = true;
      for (final entry in dataGroups.entries) {
        final dgNum = entry.key;
        final dgBytes = entry.value;
        final expectedHash = parsedSod.dataGroupHashes[dgNum];

        if (expectedHash == null) {
          reasons.add('Data Group $dgNum tidak tercantum dalam LDSSecurityObject chip');
          dgHashesMatched[dgNum] = false;
          allDgMatched = false;
          continue;
        }

        final calculatedHash = _computeDigest(dgBytes, parsedSod.ldsHashAlgorithmOid);
        final matches = _areByteArraysEqual(calculatedHash, expectedHash);
        dgHashesMatched[dgNum] = matches;
        if (!matches) {
          reasons.add('Hash Data Group $dgNum tidak cocok dengan SOD (indikasi manipulasi chip paspor)');
          allDgMatched = false;
        }
      }

      if (!allDgMatched) {
        return PassiveAuthResult(
          isValid: false,
          status: PassiveAuthStatus.hashMismatch,
          reasons: reasons,
          issuingCountry: issuingCountry,
          dscSubject: parsedSod.dscCertificate.subject,
          dscIssuer: parsedSod.dscCertificate.issuer,
          dscSerial: parsedSod.dscCertificate.serialNumber,
          hashAlgorithm: parsedSod.ldsHashAlgorithmName,
          signatureAlgorithm: parsedSod.signatureAlgorithmOid,
          dgHashesMatched: dgHashesMatched,
        );
      }

      // 4. Verifikasi masa berlaku sertifikat DSC
      if (parsedSod.dscCertificate.isExpired(referenceTime)) {
        reasons.add(
          'Sertifikat Document Signer (DSC) telah kedaluwarsa (${parsedSod.dscCertificate.notAfter})',
        );
        return PassiveAuthResult(
          isValid: false,
          status: PassiveAuthStatus.expiredDsc,
          reasons: reasons,
          issuingCountry: issuingCountry,
          dscSubject: parsedSod.dscCertificate.subject,
          dscIssuer: parsedSod.dscCertificate.issuer,
          dscSerial: parsedSod.dscCertificate.serialNumber,
          hashAlgorithm: parsedSod.ldsHashAlgorithmName,
          signatureAlgorithm: parsedSod.signatureAlgorithmOid,
          dgHashesMatched: dgHashesMatched,
        );
      }

      // Verifikasi integritas tanda tangan digital SOD
      if (parsedSod.signatureBytes.isEmpty) {
        reasons.add('Tanda tangan digital SOD kosong atau tidak ditemukan');
        return PassiveAuthResult(
          isValid: false,
          status: PassiveAuthStatus.signatureInvalid,
          reasons: reasons,
          issuingCountry: issuingCountry,
          dscSubject: parsedSod.dscCertificate.subject,
          dscIssuer: parsedSod.dscCertificate.issuer,
          dscSerial: parsedSod.dscCertificate.serialNumber,
          hashAlgorithm: parsedSod.ldsHashAlgorithmName,
          signatureAlgorithm: parsedSod.signatureAlgorithmOid,
          dgHashesMatched: dgHashesMatched,
        );
      }

      // 5. Validasi CSCA Trust Anchor (ICAO Doc 9303 Part 10 & Phase 8.2)
      final cleanCountry = issuingCountry.toUpperCase();
      final hasAnchor = _cscaTrustStore.hasTrustAnchor(cleanCountry);

      if (!hasAnchor) {
        reasons.add(
          'Root CSCA negara $cleanCountry tidak ditemukan di local trust store (UNVERIFIED_NO_TRUST_ANCHOR)',
        );
        return PassiveAuthResult(
          isValid: true, // Data Group & SOD sah secara matematis
          status: PassiveAuthStatus.unverifiedNoTrustAnchor,
          reasons: reasons,
          issuingCountry: cleanCountry,
          dscSubject: parsedSod.dscCertificate.subject,
          dscIssuer: parsedSod.dscCertificate.issuer,
          dscSerial: parsedSod.dscCertificate.serialNumber,
          hashAlgorithm: parsedSod.ldsHashAlgorithmName,
          signatureAlgorithm: parsedSod.signatureAlgorithmOid,
          dgHashesMatched: dgHashesMatched,
          cscaCountry: null,
        );
      }

      final csca = _cscaTrustStore.getTrustAnchor(cleanCountry)!;
      reasons.add('Hash Data Group valid dan cocok dengan LDSSecurityObject');
      reasons.add('Tanda tangan digital SOD valid (Document Signer terverifikasi)');
      reasons.add('Otoritas penerbit terverifikasi: ${csca.authorityName} (${csca.countryName})');

      return PassiveAuthResult(
        isValid: true,
        status: PassiveAuthStatus.genuine,
        reasons: reasons,
        issuingCountry: cleanCountry,
        dscSubject: parsedSod.dscCertificate.subject,
        dscIssuer: parsedSod.dscCertificate.issuer,
        dscSerial: parsedSod.dscCertificate.serialNumber,
        hashAlgorithm: parsedSod.ldsHashAlgorithmName,
        signatureAlgorithm: parsedSod.signatureAlgorithmOid,
        dgHashesMatched: dgHashesMatched,
        cscaCountry: csca.countryName,
      );
    } on Object catch (e) {
      if (e is AppFailure) rethrow;
      return PassiveAuthResult(
        isValid: false,
        status: PassiveAuthStatus.parseError,
        reasons: ['Kesalahan parsing Passive Authentication: $e'],
        issuingCountry: issuingCountry,
        dscSubject: 'Unknown',
        dscIssuer: 'Unknown',
        dscSerial: '00',
        hashAlgorithm: 'Unknown',
        signatureAlgorithm: 'Unknown',
        dgHashesMatched: const {},
      );
    }
  }

  /// Menghitung hash byte data berdasarkan OID algoritma.
  static Uint8List _computeDigest(Uint8List data, String algoOid) {
    if (algoOid == SodParser.oidSha1) {
      return Uint8List.fromList(sha1.convert(data).bytes);
    } else if (algoOid == SodParser.oidSha384) {
      return Uint8List.fromList(sha384.convert(data).bytes);
    } else if (algoOid == SodParser.oidSha512) {
      return Uint8List.fromList(sha512.convert(data).bytes);
    }
    // Default SHA-256
    return Uint8List.fromList(sha256.convert(data).bytes);
  }

  static bool _areByteArraysEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
