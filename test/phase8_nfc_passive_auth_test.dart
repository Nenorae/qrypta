// test/phase8_nfc_passive_auth_test.dart

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrypta/src/core/error/app_failure.dart';
import 'package:qrypta/src/core/utils/mrz_parser.dart';
import 'package:qrypta/src/features/authentication/data/nfc/apdu_service.dart';
import 'package:qrypta/src/features/authentication/data/nfc/bac_crypto.dart';
import 'package:qrypta/src/features/authentication/data/nfc/csca_trust_store.dart';
import 'package:qrypta/src/features/authentication/data/nfc/iso_dep_transceiver.dart';
import 'package:qrypta/src/features/authentication/data/nfc/nfc_passport_service.dart';
import 'package:qrypta/src/features/authentication/data/nfc/passive_auth_service.dart';
import 'package:qrypta/src/features/authentication/data/nfc/sod_parser.dart';
import 'package:qrypta/src/features/authentication/domain/models/nfc_passport_models.dart';
import 'fixtures/nfc_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 8.1: ICAO Doc 9303 BAC Key Derivation & Cryptography (Level L1)', () {
    test('L1: Derives BAC seed from MRZ data matching ICAO Doc 9303 Part 11 Appendix D.1', () {
      // Vector spesimen resmi ICAO 9303 Part 11 App D.1:
      // DocNum = L898902C<3, DOB = 6908061, EXP = 9406236
      final kseed = BacCrypto.deriveBacSeedFromMrz(
        documentNumber: 'L898902C<',
        birthDate: '690806',
        expiryDate: '940623',
      );

      // Kseed persis: 23 9A B9 CB 28 2D AF 66 23 1D C5 A4 DF 6B FB AE
      const expectedKseedHex = '239AB9CB282DAF66231DC5A4DF6BFBAE';
      final actualKseedHex = kseed.map((b) => b.toRadixString(16).padLeft(2, '0')).join('').toUpperCase();

      expect(actualKseedHex, equals(expectedKseedHex));
    });

    test('L1: Derives Kenc and Kmac with odd-parity adjustment matching ICAO Doc 9303 Appendix D.1', () {
      final kseed = Uint8List.fromList([
        0x23, 0x9A, 0xB9, 0xCB, 0x28, 0x2D, 0xAF, 0x66,
        0x23, 0x1D, 0xC5, 0xA4, 0xDF, 0x6B, 0xFB, 0xAE,
      ]);

      final kenc = BacCrypto.deriveBacKey(kseed, 1);
      final kmac = BacCrypto.deriveBacKey(kseed, 2);

      // Nilai resmi Appendix D.1.2:
      // Kenc = AB 94 FD EC F2 67 4F DF B9 B3 91 F8 5D 7F 76 F2
      // Kmac = 79 62 D9 EC E0 3D 1A CD 4C 76 08 9D CE 13 15 43
      const expectedKencHex = 'AB94FDECF2674FDFB9B391F85D7F76F2';
      const expectedKmacHex = '7962D9ECE03D1ACD4C76089DCE131543';

      final actualKencHex = kenc.map((b) => b.toRadixString(16).padLeft(2, '0')).join('').toUpperCase();
      final actualKmacHex = kmac.map((b) => b.toRadixString(16).padLeft(2, '0')).join('').toUpperCase();

      expect(actualKencHex, equals(expectedKencHex));
      expect(actualKmacHex, equals(expectedKmacHex));
    });

    test('L1: Computes ISO/IEC 9797-1 Retail MAC Algorithm 3 over binary payloads', () {
      final kmac = Uint8List.fromList([
        0x79, 0x62, 0xD9, 0xEC, 0xE0, 0x3D, 0x1A, 0xCD,
        0x4C, 0x76, 0x08, 0x9D, 0xCE, 0x13, 0x15, 0x43,
      ]);
      final payload = Uint8List.fromList([0x01, 0x02, 0x03, 0x04, 0x05]);
      final mac = BacCrypto.retailMac(kmac, payload);

      expect(mac.length, equals(8));

      // Determinisme MAC: payload identik menghasilkan hash MAC identik
      final mac2 = BacCrypto.retailMac(kmac, payload);
      expect(mac, equals(mac2));

      // Modifikasi 1 bit mengubah MAC total (avalanche effect)
      final corruptedPayload = Uint8List.fromList([0x01, 0x02, 0x03, 0x04, 0x06]);
      final corruptedMac = BacCrypto.retailMac(kmac, corruptedPayload);
      expect(mac, isNot(equals(corruptedMac)));
    });

    test('L1: 2-key 3DES CBC encryption and decryption roundtrip preserves binary fidelity', () {
      final kenc = Uint8List.fromList([
        0xAB, 0x94, 0xFD, 0xEC, 0xF2, 0x67, 0x4F, 0xDF,
        0xB9, 0xB3, 0x91, 0xF8, 0x5D, 0x7F, 0x76, 0xF2,
      ]);
      final iv = Uint8List(8);
      final plaintext = Uint8List.fromList(List.generate(32, (i) => (i * 7) & 0xFF));

      final ciphertext = BacCrypto.des3CbcEncrypt(kenc, iv, plaintext);
      expect(ciphertext.length, equals(plaintext.length));
      expect(ciphertext, isNot(equals(plaintext)));

      final decrypted = BacCrypto.des3CbcDecrypt(kenc, iv, ciphertext);
      expect(decrypted, equals(plaintext));
    });

    test('L1: Generates mutual authentication cryptogram (eIFD + mIFD) with 40-byte length', () {
      final kenc = Uint8List(16);
      final kmac = Uint8List(16);
      final rndIcc = Uint8List(8);
      final rndIfd = Uint8List(8);
      final kIfd = Uint8List(16);

      final authData = BacCrypto.buildExternalAuthenticateData(
        kenc: kenc,
        kmac: kmac,
        rndIcc: rndIcc,
        rndIfd: rndIfd,
        kIfd: kIfd,
      );

      // eIFD (32 bytes) + mIFD (8 bytes) = 40 bytes
      expect(authData.length, equals(40));
    });

    test('L1: Increment SSC increments big-endian counter correctly', () {
      final ssc = Uint8List.fromList([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFE]);
      BacCrypto.incrementSsc(ssc);
      expect(ssc.last, equals(0xFF));

      BacCrypto.incrementSsc(ssc);
      expect(ssc[6], equals(0x01));
      expect(ssc[7], equals(0x00));
    });
  });

  group('Phase 8.1: APDU Framing & IsoDep Transceiver Operations (Level L1)', () {
    test('L1: Builds SELECT APPLICATION (AID A0000002471001) command and parses SW 9000', () async {
      final transceiver = MemoryIsoDepTransceiver();
      // Script respons 9000 untuk Select Application
      transceiver.registerApduResponse('00A4040C07A0000002471001', Uint8List.fromList([0x90, 0x00]));

      await ApduService.selectPassportApplication(transceiver);
      expect(transceiver.isConnected, isTrue);
    });

    test('L1: Rejects status word 6982 as typed NfcBacFailed', () async {
      final transceiver = MemoryIsoDepTransceiver();
      // Script respons 6982 (Security status not satisfied)
      transceiver.registerApduResponse('00A4040C07A0000002471001', Uint8List.fromList([0x69, 0x82]));

      expect(
        () => ApduService.selectPassportApplication(transceiver),
        throwsA(isA<NfcBacFailed>()),
      );
    });

    test('L1: Rejects unknown status words as typed NfcApduException', () async {
      final transceiver = MemoryIsoDepTransceiver();
      // Script respons 6A82 (File not found)
      transceiver.registerApduResponse('00A4040C07A0000002471001', Uint8List.fromList([0x6A, 0x82]));

      expect(
        () => ApduService.selectPassportApplication(transceiver),
        throwsA(isA<NfcApduException>()),
      );
    });

    test('L1: Reads binary files with automatic chunking and ASN.1 length decoding', () async {
      final transceiver = MemoryIsoDepTransceiver();
      final dg1Data = NfcTestFixtures.createDg1Binary();

      // Script SELECT FILE DG1 (0101) -> 9000
      transceiver.registerApduResponse('00A4020C020101', Uint8List.fromList([0x90, 0x00]));

      // Handler READ BINARY cerdas
      final memoryTransceiver = MemoryIsoDepTransceiver(
        customHandler: (apdu) {
          final hex = apdu.map((b) => b.toRadixString(16).padLeft(2, '0')).join('').toUpperCase();
          if (hex == '00A4020C020101') {
            return Uint8List.fromList([0x90, 0x00]);
          }
          if (apdu[1] == 0xB0) {
            final offset = (apdu[2] << 8) | apdu[3];
            final length = apdu[4];
            final slice = dg1Data.sublist(offset, offset + length > dg1Data.length ? dg1Data.length : offset + length);
            return Uint8List.fromList([...slice, 0x90, 0x00]);
          }
          return Uint8List.fromList([0x90, 0x00]);
        },
      );

      final result = await ApduService.readFullElementaryFile(
        memoryTransceiver,
        ApduService.fileIdDg1,
        null,
      );

      expect(result.length, equals(dg1Data.length));
      expect(result, equals(dg1Data));
    });

    test('L1 Chaos: Simulates tag loss mid-read and converts to typed NfcTagLost', () async {
      final transceiver = MemoryIsoDepTransceiver();
      transceiver.triggerTagLoss();

      expect(
        () => ApduService.selectPassportApplication(transceiver),
        throwsA(isA<NfcTagLost>()),
      );
    });
  });

  group('Phase 8.1: End-to-End NFC Passport Read & MRZ Cross-Validation (Level L1)', () {
    late MrzParseResult utopiaMrz;
    late Uint8List testDg1;
    late Uint8List testEfCom;
    late Uint8List testEfSod;

    setUp(() {
      utopiaMrz = MrzParser.parse(
        NfcTestFixtures.utopiaMrzLine1,
        NfcTestFixtures.utopiaMrzLine2,
      );
      testDg1 = NfcTestFixtures.createDg1Binary();
      testEfCom = NfcTestFixtures.createEfComBinary();
      testEfSod = NfcTestFixtures.createSodBinary(dg1Bytes: testDg1, countryCode: 'UTO');
    });

    MemoryIsoDepTransceiver buildMockPassportCardTransceiver({
      Uint8List? customDg1,
      bool failBac = false,
      bool dropTagOnSod = false,
    }) {
      final activeDg1 = customDg1 ?? testDg1;

      return MemoryIsoDepTransceiver(
        customHandler: (apdu) {
          final hex = apdu.map((b) => b.toRadixString(16).padLeft(2, '0')).join('').toUpperCase();

          // 1. SELECT APPLICATION (AID: A0000002471001)
          if (hex == '00A4040C07A0000002471001') {
            return Uint8List.fromList([0x90, 0x00]);
          }

          // 2. GET CHALLENGE
          if (hex == '0084000008') {
            final dummyRndIcc = Uint8List.fromList([0x46, 0x08, 0xF9, 0x19, 0x88, 0x70, 0x22, 0x12]);
            return Uint8List.fromList([...dummyRndIcc, 0x90, 0x00]);
          }

          // 3. EXTERNAL AUTHENTICATE
          if (apdu[1] == 0x82) {
            if (failBac) {
              return Uint8List.fromList([0x69, 0x82]); // Reject BAC
            }
            // Respons kartu External Authenticate (32 byte eICC + 8 byte mICC + 9000)
            final dummyEIcc = Uint8List(32);
            final dummyMIcc = Uint8List(8);
            // Kloning respons terenkripsi valid
            return Uint8List.fromList([...dummyEIcc, ...dummyMIcc, 0x90, 0x00]);
          }

          // 4. SELECT FILE
          if (apdu[1] == 0xA4) {
            return Uint8List.fromList([0x90, 0x00]);
          }

          // 5. READ BINARY
          if (apdu[1] == 0xB0) {
            if (dropTagOnSod && hex.contains('011D')) {
              throw const NfcTagLost('Tag moved away during SOD read');
            }
            final offset = (apdu[2] << 8) | apdu[3];
            final length = apdu[4];

            // Tentukan file mana yang dibaca
            Uint8List targetFile = testEfCom;
            if (offset == 0 && length == 4) {
              targetFile = activeDg1; // default check
            }
            final slice = targetFile.sublist(
              offset,
              offset + length > targetFile.length ? targetFile.length : offset + length,
            );
            return Uint8List.fromList([...slice, 0x90, 0x00]);
          }

          return Uint8List.fromList([0x90, 0x00]);
        },
      );
    }

    test('L1 Negative: Rejects passport chip when DG1 MRZ does not match camera scan MRZ (NfcDataMismatch)', () {
      final cameraMrz = MrzParser.parse(
        NfcTestFixtures.utopiaMrzLine1,
        NfcTestFixtures.utopiaMrzLine2,
      );

      // Buat DG1 dengan nomor paspor berbeda: L999999C
      final tamperedDg1 = NfcTestFixtures.createDg1Binary(
        line2: 'L999999C36UTO7408122F1204159ZE184226B<<<<<10',
      );
      final chipMrz = MrzParser.parse(
        NfcTestFixtures.utopiaMrzLine1,
        'L999999C36UTO7408122F1204159ZE184226B<<<<<10',
      );

      // Verifikasi bahwa validator melempar NfcDataMismatch
      expect(
        () => NfcPassportService.checkMrzConsistency(cameraMrz: cameraMrz, chipMrz: chipMrz),
        throwsA(isA<NfcDataMismatch>()),
      );
    });

    test('L1 Negative: Rejects when BAC Mutual Authentication fails (NfcBacFailed)', () async {
      final transceiver = buildMockPassportCardTransceiver(failBac: true);
      final service = NfcPassportService();

      expect(
        () => service.readPassport(transceiver: transceiver, cameraMrz: utopiaMrz),
        throwsA(isA<NfcBacFailed>()),
      );
    });
  });

  group('Phase 8.2: Passive Authentication (PA) & Trust Store Verification (Level L1)', () {
    late Uint8List dg1Bytes;
    late Uint8List authenticSod;
    late PassiveAuthService paService;

    setUp(() {
      dg1Bytes = NfcTestFixtures.createDg1Binary();
      authenticSod = NfcTestFixtures.createSodBinary(dg1Bytes: dg1Bytes, countryCode: 'UTO');
      paService = PassiveAuthService();
    });

    test('L1 Positive: Genuine e-Passport with valid DG1 hash, DSC, and Utopia CSCA returns genuine', () {
      final result = paService.verifyPassiveAuthentication(
        rawSod: authenticSod,
        dataGroups: {1: dg1Bytes},
        issuingCountry: 'UTO',
      );

      expect(result.isValid, isTrue);
      expect(result.status, equals(PassiveAuthStatus.genuine));
      expect(result.isGenuine, isTrue);
      expect(result.dgHashesMatched[1], isTrue);
      expect(result.cscaCountry, contains('Utopia'));
    });

    test('L1 Negative: Tampered DG1 bytes trigger PassiveAuthStatus.hashMismatch (isValid == false)', () {
      // Modifikasi 1 byte pada DG1
      final tamperedDg1 = Uint8List.fromList(dg1Bytes);
      tamperedDg1[20] ^= 0xFF;

      final result = paService.verifyPassiveAuthentication(
        rawSod: authenticSod,
        dataGroups: {1: tamperedDg1},
        issuingCountry: 'UTO',
      );

      expect(result.isValid, isFalse);
      expect(result.status, equals(PassiveAuthStatus.hashMismatch));
      expect(result.isTampered, isTrue);
      expect(result.dgHashesMatched[1], isFalse);
      expect(result.reasons.any((r) => r.contains('Hash Data Group 1 tidak cocok')), isTrue);
    });

    test('L1 Negative: Corrupted/missing digital signature triggers PassiveAuthStatus.signatureInvalid', () {
      final corruptedSigSod = NfcTestFixtures.createSodBinary(
        dg1Bytes: dg1Bytes,
        countryCode: 'UTO',
        corruptSignature: true,
      );

      final result = paService.verifyPassiveAuthentication(
        rawSod: corruptedSigSod,
        dataGroups: {1: dg1Bytes},
        issuingCountry: 'UTO',
      );

      expect(result.isValid, isFalse);
      expect(result.status, equals(PassiveAuthStatus.signatureInvalid));
      expect(result.reasons.any((r) => r.contains('Tanda tangan digital SOD')), isTrue);
    });

    test('L1 Negative: Expired Document Signer Certificate (DSC) triggers PassiveAuthStatus.expiredDsc', () {
      final expiredSod = NfcTestFixtures.createSodBinary(
        dg1Bytes: dg1Bytes,
        countryCode: 'UTO',
        expiredDsc: true, // notAfter: 2015
      );

      final result = paService.verifyPassiveAuthentication(
        rawSod: expiredSod,
        dataGroups: {1: dg1Bytes},
        issuingCountry: 'UTO',
      );

      expect(result.isValid, isFalse);
      expect(result.status, equals(PassiveAuthStatus.expiredDsc));
      expect(result.reasons.any((r) => r.contains('telah kedaluwarsa')), isTrue);
    });

    test('L1 Honest Unverified Anchor: Country without CSCA in trust store returns unverifiedNoTrustAnchor', () {
      // Negara 'XYZ' tidak terdaftar dalam Master List CscaTrustStore
      final unlistedCountrySod = NfcTestFixtures.createSodBinary(
        dg1Bytes: dg1Bytes,
        countryCode: 'XYZ',
      );

      final result = paService.verifyPassiveAuthentication(
        rawSod: unlistedCountrySod,
        dataGroups: {1: dg1Bytes},
        issuingCountry: 'XYZ',
      );

      // Data Group & SOD sah secara matematis, namun status ditandai secara jujur
      expect(result.isValid, isTrue);
      expect(result.status, equals(PassiveAuthStatus.unverifiedNoTrustAnchor));
      expect(result.hasTrustAnchor, isFalse);
      expect(result.cscaCountry, isNull);
      expect(result.reasons.any((r) => r.contains('UNVERIFIED_NO_TRUST_ANCHOR')), isTrue);
    });
  });

  group('Phase 8.2: CSCA Trust Store Master List Coverage Tests', () {
    test('Trust store contains sovereign anchors for IDN, GBR, USA, AUS, DEU, SGP, UTO', () {
      final store = CscaTrustStore();
      final sovereignList = ['IDN', 'GBR', 'USA', 'AUS', 'DEU', 'SGP', 'UTO'];

      for (final code in sovereignList) {
        expect(store.hasTrustAnchor(code), isTrue, reason: 'Root CSCA for $code must be registered');
        final cert = store.getTrustAnchor(code);
        expect(cert, isNotNull);
        expect(cert!.authorityName, isNotEmpty);
        expect(cert.isValidAt(DateTime(2026, 11, 21)), isTrue);
      }
    });

    test('Registers dynamic CSCA certificates into trust store', () {
      final store = CscaTrustStore();
      const newCountry = 'NZL';
      expect(store.hasTrustAnchor(newCountry), isFalse);

      store.registerCscaCertificate(
        CscaCertificate(
          countryCode: newCountry,
          countryName: 'New Zealand',
          authorityName: 'Department of Internal Affairs CSCA',
          thumbprintSha256: '99AABBCCDDEEFF00112233445566778899AABBCCDDEEFF001122334455667788',
          notBefore: DateTime(2020, 1, 1),
          notAfter: DateTime(2035, 1, 1),
        ),
      );

      expect(store.hasTrustAnchor(newCountry), isTrue);
    });
  });
}
