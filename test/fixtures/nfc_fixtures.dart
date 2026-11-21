// test/fixtures/nfc_fixtures.dart

import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/asn1.dart';
import 'package:qrypta/src/features/authentication/data/nfc/sod_parser.dart';

/// Fixture data pembacaan chip NFC e-Passport ICAO Doc 9303 (Level L1).
class NfcTestFixtures {
  /// Spesimen ICAO Utopia TD3 MRZ (Doc 9303 Part 11 Appendix D)
  static const String utopiaMrzLine1 = 'P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<';
  static const String utopiaMrzLine2 = 'L898902C36UTO7408122F1204159ZE184226B<<<<<10';

  /// Membuat binary DG1 lengkap (Tag 61 -> Tag 5F1F -> 88 byte TD3 MRZ)
  static Uint8List createDg1Binary({String? line1, String? line2}) {
    final l1 = (line1 ?? utopiaMrzLine1).padRight(44, '<').substring(0, 44);
    final l2 = (line2 ?? utopiaMrzLine2).padRight(44, '<').substring(0, 44);
    final mrz88 = utf8.encode('$l1$l2');

    // TLV Tag 5F1F
    final tag5f1f = Uint8List.fromList([0x5F, 0x1F, mrz88.length, ...mrz88]);
    // Outer Tag 61
    final tag61 = Uint8List.fromList([0x61, tag5f1f.length, ...tag5f1f]);
    return tag61;
  }

  /// Membuat binary EF.COM (Tag 60 -> LDS Version 5F01 & Tag List 5F36)
  static Uint8List createEfComBinary({String version = '0107', List<int>? dataGroups}) {
    final vBytes = utf8.encode(version);
    final dgList = dataGroups ?? [0x01, 0x02, 0x0E];

    final doLds = Uint8List.fromList([0x5F, 0x01, vBytes.length, ...vBytes]);
    final doTags = Uint8List.fromList([0x5F, 0x36, dgList.length, ...dgList]);
    final content = Uint8List.fromList([...doLds, ...doTags]);

    return Uint8List.fromList([0x60, content.length, ...content]);
  }

  /// Membangun binary EF.SOD asli (Tag 77 -> CMS SignedData ASN.1 DER)
  static Uint8List createSodBinary({
    required Uint8List dg1Bytes,
    String countryCode = 'UTO',
    bool corruptDgHash = false,
    bool corruptSignature = false,
    bool expiredDsc = false,
  }) {
    // 1. Hash DG1
    final dg1Hash = sha256.convert(dg1Bytes).bytes;
    final effectiveDg1Hash = corruptDgHash
        ? Uint8List.fromList(dg1Hash.map((b) => b ^ 0xFF).toList())
        : Uint8List.fromList(dg1Hash);

    // 2. LDSSecurityObject
    final ldsSeq = ASN1Sequence(elements: [
      ASN1Integer(BigInt.zero),
      ASN1Sequence(elements: [
        ASN1ObjectIdentifier.fromIdentifierString(SodParser.oidSha256),
        ASN1Null(),
      ]),
      ASN1Sequence(elements: [
        ASN1Sequence(elements: [
          ASN1Integer(BigInt.one), // DG1
          ASN1OctetString(octets: effectiveDg1Hash),
        ]),
      ]),
    ]);
    final ldsBytes = ldsSeq.encode();

    // 3. messageDigest = SHA-256(ldsBytes)
    final eContentDigest = Uint8List.fromList(sha256.convert(ldsBytes).bytes);

    // 4. signedAttrs
    final signedAttrs = ASN1Set(elements: [
      ASN1Sequence(elements: [
        ASN1ObjectIdentifier.fromIdentifierString(SodParser.oidContentType),
        ASN1Set(elements: [
          ASN1ObjectIdentifier.fromIdentifierString(SodParser.oidLdsSecurityObject),
        ]),
      ]),
      ASN1Sequence(elements: [
        ASN1ObjectIdentifier.fromIdentifierString(SodParser.oidMessageDigest),
        ASN1Set(elements: [
          ASN1OctetString(octets: eContentDigest),
        ]),
      ]),
    ]);

    // 5. Signature bytes
    final sigRaw = Uint8List.fromList([
      0x30, 0x44, 0x02, 0x20,
      ...List.generate(32, (i) => (i + 1) & 0xFF),
      0x02, 0x20,
      ...List.generate(32, (i) => (i + 33) & 0xFF),
    ]);
    final effectiveSig = corruptSignature ? Uint8List(0) : sigRaw;

    // 6. DSC Certificate SEQUENCE
    final notBefore = expiredDsc ? DateTime(2010, 1, 1) : DateTime(2020, 1, 1);
    final notAfter = expiredDsc ? DateTime(2015, 1, 1) : DateTime(2030, 1, 1);

    final dscSeq = ASN1Sequence(elements: [
      ASN1Sequence(elements: [
        ASN1Integer(BigInt.from(2)),
        ASN1Integer(BigInt.parse('1029384756', radix: 16)),
        ASN1Sequence(elements: [
          ASN1ObjectIdentifier.fromIdentifierString(SodParser.oidSha256WithRsa),
          ASN1Null(),
        ]),
        ASN1Sequence(elements: [
          ASN1Set(elements: [
            ASN1Sequence(elements: [
              ASN1ObjectIdentifier.fromIdentifierString('2.5.4.6'),
              ASN1PrintableString(stringValue: countryCode),
            ]),
          ]),
          ASN1Set(elements: [
            ASN1Sequence(elements: [
              ASN1ObjectIdentifier.fromIdentifierString('2.5.4.3'),
              ASN1PrintableString(stringValue: '$countryCode CSCA Root'),
            ]),
          ]),
        ]),
        ASN1Sequence(elements: [
          ASN1UtcTime(notBefore),
          ASN1UtcTime(notAfter),
        ]),
        ASN1Sequence(elements: [
          ASN1Set(elements: [
            ASN1Sequence(elements: [
              ASN1ObjectIdentifier.fromIdentifierString('2.5.4.6'),
              ASN1PrintableString(stringValue: countryCode),
            ]),
          ]),
          ASN1Set(elements: [
            ASN1Sequence(elements: [
              ASN1ObjectIdentifier.fromIdentifierString('2.5.4.3'),
              ASN1PrintableString(stringValue: '$countryCode Document Signer DS-2024'),
            ]),
          ]),
        ]),
        ASN1Sequence(elements: [
          ASN1Sequence(elements: [
            ASN1ObjectIdentifier.fromIdentifierString(SodParser.oidRsaEncryption),
            ASN1Null(),
          ]),
          ASN1BitString(stringValues: Uint8List(64)),
        ]),
      ]),
      ASN1Sequence(elements: [
        ASN1ObjectIdentifier.fromIdentifierString(SodParser.oidSha256WithRsa),
        ASN1Null(),
      ]),
      ASN1BitString(stringValues: Uint8List(64)),
    ]);

    // 7. SignedData
    final signedData = ASN1Sequence(elements: [
      ASN1Integer(BigInt.from(3)),
      ASN1Set(elements: [
        ASN1Sequence(elements: [
          ASN1ObjectIdentifier.fromIdentifierString(SodParser.oidSha256),
          ASN1Null(),
        ]),
      ]),
      ASN1Sequence(elements: [
        ASN1ObjectIdentifier.fromIdentifierString(SodParser.oidLdsSecurityObject),
        ASN1OctetString(octets: ldsBytes),
      ]),
      ASN1Set(elements: [dscSeq]),
      ASN1Set(elements: [
        ASN1Sequence(elements: [
          ASN1Integer(BigInt.one),
          ASN1Sequence(elements: [
            ASN1Sequence(elements: []),
            ASN1Integer(BigInt.one),
          ]),
          ASN1Sequence(elements: [
            ASN1ObjectIdentifier.fromIdentifierString(SodParser.oidSha256),
            ASN1Null(),
          ]),
          ASN1Sequence(elements: signedAttrs.elements ?? []),
          ASN1Sequence(elements: [
            ASN1ObjectIdentifier.fromIdentifierString(SodParser.oidSha256WithRsa),
            ASN1Null(),
          ]),
          ASN1OctetString(octets: effectiveSig),
        ]),
      ]),
    ]);

    // 8. ContentInfo
    final contentInfo = ASN1Sequence(elements: [
      ASN1ObjectIdentifier.fromIdentifierString(SodParser.oidSignedData),
      signedData,
    ]);
    final ciEncoded = contentInfo.encode();

    return Uint8List.fromList([
      0x77,
      0x82,
      (ciEncoded.length >> 8) & 0xFF,
      ciEncoded.length & 0xFF,
      ...ciEncoded,
    ]);
  }
}
