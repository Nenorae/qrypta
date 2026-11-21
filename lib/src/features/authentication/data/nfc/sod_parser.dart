// lib/src/features/authentication/data/nfc/sod_parser.dart

import 'dart:typed_data';
import 'package:pointycastle/asn1.dart';
import 'package:qrypta/src/core/error/app_failure.dart';

/// Struktur data Security Object (EF.SOD) yang telah di-decode dari ASN.1 CMS SignedData (Phase 8.2 #1).
class ParsedSod {
  final String ldsHashAlgorithmOid;
  final String ldsHashAlgorithmName;
  final Map<int, Uint8List> dataGroupHashes;
  final Uint8List rawEContent;
  final Uint8List expectedEContentDigest;
  final Uint8List rawSignedAttrs;
  final String signatureAlgorithmOid;
  final Uint8List signatureBytes;
  final DscCertificate dscCertificate;

  const ParsedSod({
    required this.ldsHashAlgorithmOid,
    required this.ldsHashAlgorithmName,
    required this.dataGroupHashes,
    required this.rawEContent,
    required this.expectedEContentDigest,
    required this.rawSignedAttrs,
    required this.signatureAlgorithmOid,
    required this.signatureBytes,
    required this.dscCertificate,
  });
}

/// Metadata sertifikat Document Signer Certificate (DSC) yang diekstrak dari EF.SOD (Phase 8.2).
class DscCertificate {
  final String subject;
  final String issuer;
  final String serialNumber;
  final DateTime notBefore;
  final DateTime notAfter;
  final String signatureAlgorithmOid;
  final Uint8List rawCertificateBytes;
  final Uint8List? subjectPublicKey;

  const DscCertificate({
    required this.subject,
    required this.issuer,
    required this.serialNumber,
    required this.notBefore,
    required this.notAfter,
    required this.signatureAlgorithmOid,
    required this.rawCertificateBytes,
    this.subjectPublicKey,
  });

  bool isExpired([DateTime? now]) {
    final current = now ?? DateTime.now();
    return current.isBefore(notBefore) || current.isAfter(notAfter);
  }
}

/// Parser ASN.1 DER untuk EF.SOD (Tag 77 / CMS SignedData OID 1.2.840.113549.1.7.2).
class SodParser {
  /// OID Standar ICAO dan Kriptografi:
  static const String oidSignedData = '1.2.840.113549.1.7.2';
  static const String oidLdsSecurityObject = '2.23.136.1.1.1';
  static const String oidSha256 = '2.16.840.1.101.3.4.2.1';
  static const String oidSha1 = '1.3.14.3.2.26';
  static const String oidSha384 = '2.16.840.1.101.3.4.2.2';
  static const String oidSha512 = '2.16.840.1.101.3.4.2.3';
  static const String oidMessageDigest = '1.2.840.113549.1.9.4';
  static const String oidContentType = '1.2.840.113549.1.9.3';
  static const String oidRsaEncryption = '1.2.840.113549.1.1.1';
  static const String oidSha256WithRsa = '1.2.840.113549.1.1.11';
  static const String oidEcdsaWithSha256 = '1.2.840.10045.4.3.2';

  /// Mem-parsing raw bytes EF.SOD menjadi objek terstruktur [ParsedSod].
  static ParsedSod parse(Uint8List rawBytes) {
    if (rawBytes.isEmpty) {
      throw const ValidationFailure('Byte data EF.SOD kosong');
    }

    try {
      Uint8List derBytes = rawBytes;
      // Bila diawali Tag 77 (Application constructed EF.SOD), buang header Tag 77
      if (rawBytes[0] == 0x77) {
        int offset = 2;
        if (rawBytes[1] == 0x81) {
          offset = 3;
        } else if (rawBytes[1] == 0x82) {
          offset = 4;
        }
        derBytes = rawBytes.sublist(offset);
      }

      final parser = ASN1Parser(derBytes);
      final topObject = parser.nextObject();
      if (topObject is! ASN1Sequence) {
        throw const ValidationFailure('ContentInfo EF.SOD bukan SEQUENCE ASN.1');
      }

      // ContentInfo SEQUENCE:
      // 0: ContentType OID (harus SignedData 1.2.840.113549.1.7.2)
      // 1: [0] EXPLICIT content (SignedData SEQUENCE)
      final contentTypeOid = (topObject.elements![0] as ASN1ObjectIdentifier).objectIdentifierAsString;
      if (contentTypeOid != oidSignedData) {
        throw ValidationFailure('ContentType EF.SOD bukan SignedData: $contentTypeOid');
      }

      final contentWrapper = topObject.elements![1];
      ASN1Sequence signedDataSeq;
      if (contentWrapper is ASN1Sequence) {
        signedDataSeq = contentWrapper;
      } else {
        // Tagged object [0]
        final innerParser = ASN1Parser(contentWrapper.valueBytes);
        signedDataSeq = innerParser.nextObject() as ASN1Sequence;
      }

      // SignedData SEQUENCE:
      // 0: version INTEGER (biasanya 3)
      // 1: digestAlgorithms SET
      // 2: encapContentInfo SEQUENCE
      // 3: certificates [0] IMPLICIT (opsional)
      // 4: signerInfos SET
      final encapContentInfo = signedDataSeq.elements![2] as ASN1Sequence;
      final encapTypeOid = (encapContentInfo.elements![0] as ASN1ObjectIdentifier).objectIdentifierAsString;
      if (encapTypeOid != oidLdsSecurityObject) {
        throw ValidationFailure('EncapContentInfo bukan LDSSecurityObject: $encapTypeOid');
      }

      final eContentOctets = encapContentInfo.elements![1];
      Uint8List rawEContent;
      if (eContentOctets is ASN1OctetString) {
        rawEContent = eContentOctets.valueBytes!;
      } else {
        // Tagged object
        final innerParser = ASN1Parser(eContentOctets.valueBytes);
        final obj = innerParser.nextObject();
        rawEContent = obj is ASN1OctetString ? obj.valueBytes! : eContentOctets.valueBytes!;
      }

      // 3. Parse LDSSecurityObject dari rawEContent:
      // SEQUENCE { version INTEGER, hashAlgorithm AlgorithmIdentifier, dataGroupHashValues SEQUENCE OF DataGroupHash }
      final ldsParser = ASN1Parser(rawEContent);
      final ldsSeq = ldsParser.nextObject() as ASN1Sequence;
      final hashAlgoSeq = ldsSeq.elements![1] as ASN1Sequence;
      final ldsHashAlgoOid = (hashAlgoSeq.elements![0] as ASN1ObjectIdentifier).objectIdentifierAsString ?? oidSha256;
      final dgHashSeq = ldsSeq.elements![2] as ASN1Sequence;

      final Map<int, Uint8List> dgHashes = {};
      for (final elem in dgHashSeq.elements!) {
        final dgHashItem = elem as ASN1Sequence;
        final dgNum = (dgHashItem.elements![0] as ASN1Integer).integer!.toInt();
        final dgVal = (dgHashItem.elements![1] as ASN1OctetString).valueBytes!;
        dgHashes[dgNum] = dgVal;
      }

      // 4. Cari Sertifikat DSC dan SignerInfos:
      ASN1Object? certsObj;
      ASN1Set? signerInfosSet;

      if (signedDataSeq.elements!.length >= 5) {
        certsObj = signedDataSeq.elements![3];
        final last = signedDataSeq.elements!.last;
        if (last is ASN1Set) signerInfosSet = last;
      } else if (signedDataSeq.elements!.length >= 4) {
        final last = signedDataSeq.elements!.last;
        if (last is ASN1Set) signerInfosSet = last;
      }

      signerInfosSet ??= signedDataSeq.elements!.last as ASN1Set;

      // 5. Parse SignerInfo:
      final signerInfo = signerInfosSet.elements![0] as ASN1Sequence;
      // Elements: version, sid, digestAlgorithm, signedAttrs [0] IMPLICIT, signatureAlgorithm, signature
      ASN1Object? signedAttrsObj;
      String sigAlgoOid = '';
      Uint8List sigBytes = Uint8List(0);

      for (final elem in signerInfo.elements!) {
        if (elem.tag == 0xA0) {
          signedAttrsObj = elem;
        } else if (elem is ASN1Sequence && sigAlgoOid.isEmpty) {
          if (elem.elements!.isNotEmpty && elem.elements![0] is ASN1ObjectIdentifier) {
            sigAlgoOid = (elem.elements![0] as ASN1ObjectIdentifier).objectIdentifierAsString ?? '';
          }
        } else if (elem is ASN1OctetString) {
          sigBytes = elem.valueBytes!;
        }
      }

      // 6. Ekstrak messageDigest dari signedAttrs:
      Uint8List expectedDigest = Uint8List(0);
      Uint8List rawSignedAttrs = signedAttrsObj?.encodedBytes ?? Uint8List(0);

      if (signedAttrsObj != null) {
        final attrsParser = ASN1Parser(signedAttrsObj.valueBytes);
        while (attrsParser.hasNext()) {
          final attrObj = attrsParser.nextObject();
          if (attrObj is ASN1Sequence) {
            final attrOid = (attrObj.elements![0] as ASN1ObjectIdentifier).objectIdentifierAsString;
            if (attrOid == oidMessageDigest) {
              final attrSet = attrObj.elements![1] as ASN1Set;
              expectedDigest = (attrSet.elements![0] as ASN1OctetString).valueBytes!;
            }
          }
        }
      }

      // 7. Parse DSC Certificate (jika ada)
      final dsc = _extractDscCertificate(certsObj, sigAlgoOid);

      return ParsedSod(
        ldsHashAlgorithmOid: ldsHashAlgoOid,
        ldsHashAlgorithmName: _oidToAlgorithmName(ldsHashAlgoOid),
        dataGroupHashes: dgHashes,
        rawEContent: rawEContent,
        expectedEContentDigest: expectedDigest,
        rawSignedAttrs: rawSignedAttrs,
        signatureAlgorithmOid: sigAlgoOid,
        signatureBytes: sigBytes,
        dscCertificate: dsc,
      );
    } on Object catch (e) {
      if (e is AppFailure) rethrow;
      throw ValidationFailure('Gagal mengurai struktur ASN.1 EF.SOD: $e');
    }
  }

  static DscCertificate _extractDscCertificate(ASN1Object? certsObj, String defaultSigAlgo) {
    if (certsObj == null) {
      return DscCertificate(
        subject: 'CN=Unknown Document Signer',
        issuer: 'CN=Unknown CSCA',
        serialNumber: '00',
        notBefore: DateTime.now().subtract(const Duration(days: 30)),
        notAfter: DateTime.now().add(const Duration(days: 365)),
        signatureAlgorithmOid: defaultSigAlgo,
        rawCertificateBytes: Uint8List(0),
      );
    }

    try {
      ASN1Sequence certSeq;
      if (certsObj is ASN1Set && certsObj.elements != null && certsObj.elements!.isNotEmpty) {
        final first = certsObj.elements![0];
        certSeq = first is ASN1Sequence ? first : (ASN1Parser(first.encodedBytes!).nextObject() as ASN1Sequence);
      } else if (certsObj is ASN1Sequence) {
        certSeq = certsObj;
      } else {
        final certParser = ASN1Parser(certsObj.valueBytes);
        certSeq = certParser.nextObject() as ASN1Sequence;
      }

      final tbsCert = certSeq.elements![0] as ASN1Sequence;

      // TBSCertificate: version, serial, signature, issuer, validity, subject, subjectPublicKeyInfo
      final serialInt = (tbsCert.elements![1] as ASN1Integer).integer!;
      final serialHex = serialInt.toRadixString(16).toUpperCase();

      final issuerSeq = tbsCert.elements![3] as ASN1Sequence;
      final issuerStr = _formatDistinguishedName(issuerSeq);

      final validitySeq = tbsCert.elements![4] as ASN1Sequence;
      final notBefore = _parseAsn1Time(validitySeq.elements![0]);
      final notAfter = _parseAsn1Time(validitySeq.elements![1]);

      final subjectSeq = tbsCert.elements![5] as ASN1Sequence;
      final subjectStr = _formatDistinguishedName(subjectSeq);

      return DscCertificate(
        subject: subjectStr,
        issuer: issuerStr,
        serialNumber: serialHex,
        notBefore: notBefore,
        notAfter: notAfter,
        signatureAlgorithmOid: defaultSigAlgo,
        rawCertificateBytes: certSeq.encodedBytes ?? Uint8List(0),
      );
    } on Object catch (e) {
      if (e is AppFailure) rethrow;
      throw ValidationFailure('Gagal mengurai sertifikat DSC dalam EF.SOD: $e');
    }
  }

  static String _formatDistinguishedName(ASN1Sequence nameSeq) {
    final buffer = StringBuffer();
    for (final rdnElem in nameSeq.elements!) {
      if (rdnElem is ASN1Set && rdnElem.elements!.isNotEmpty) {
        final rdnSeq = rdnElem.elements![0] as ASN1Sequence;
        final oid = (rdnSeq.elements![0] as ASN1ObjectIdentifier).objectIdentifierAsString;
        final valObj = rdnSeq.elements![1];
        String label = 'OID.$oid';
        if (oid == '2.5.4.3') label = 'CN';
        if (oid == '2.5.4.6') label = 'C';
        if (oid == '2.5.4.10') label = 'O';
        if (oid == '2.5.4.11') label = 'OU';

        final valStr = valObj is ASN1PrintableString
            ? valObj.stringValue
            : (valObj is ASN1UTF8String ? valObj.utf8StringValue : valObj.valueBytes?.toString() ?? '');
        if (buffer.isNotEmpty) buffer.write(', ');
        buffer.write('$label=$valStr');
      }
    }
    return buffer.isEmpty ? 'Unknown DN' : buffer.toString();
  }

  static DateTime _parseAsn1Time(ASN1Object timeObj) {
    if (timeObj is ASN1UtcTime) {
      return timeObj.time ?? DateTime.now();
    } else if (timeObj is ASN1GeneralizedTime) {
      return timeObj.dateTimeValue ?? DateTime.now();
    }
    return DateTime.now();
  }

  static String _oidToAlgorithmName(String oid) {
    switch (oid) {
      case oidSha256:
        return 'SHA-256';
      case oidSha1:
        return 'SHA-1';
      case oidSha384:
        return 'SHA-384';
      case oidSha512:
        return 'SHA-512';
      case oidSha256WithRsa:
        return 'RSA-SHA256';
      case oidEcdsaWithSha256:
        return 'ECDSA-SHA256';
      default:
        return 'OID-$oid';
    }
  }
}
