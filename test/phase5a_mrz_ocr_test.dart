// test/phase5a_mrz_ocr_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:qrypta/src/core/error/app_failure.dart';
import 'package:qrypta/src/core/utils/mrz_extractor.dart';
import 'package:qrypta/src/core/utils/mrz_frame_consensus.dart';
import 'package:qrypta/src/core/utils/mrz_parser.dart';

void main() {
  group('Phase 5A: ICAO 9303 TD3 Check Digit & Parser Compliance (Level L1)', () {
    // Vektor uji resmi ICAO Doc 9303 Part 9 (Spesimen Utopia - Eriksson Anna Maria)
    const utopiaLine1 = 'P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<';
    const utopiaLine2 = 'L898902C36UTO7408122F1204159ZE184226B<<<<<10';

    test('ICAO Doc 9303 Utopia specimen validates all check digits accurately', () {
      // 1. Check digit nomor dokumen: 'L898902C3' -> 6
      expect(MrzParser.computeCheckDigit('L898902C3'), 6);
      expect(MrzParser.verifyCheckDigit('L898902C3', '6'), true);

      // 2. Check digit tanggal lahir: '740812' -> 2
      expect(MrzParser.computeCheckDigit('740812'), 2);
      expect(MrzParser.verifyCheckDigit('740812', '2'), true);

      // 3. Check digit tanggal kedaluwarsa: '120415' -> 9
      expect(MrzParser.computeCheckDigit('120415'), 9);
      expect(MrzParser.verifyCheckDigit('120415', '9'), true);

      // 4. Check digit personal number: 'ZE184226B<<<<<' -> 1
      expect(MrzParser.computeCheckDigit('ZE184226B<<<<<'), 1);
      expect(MrzParser.verifyCheckDigit('ZE184226B<<<<<', '1'), true);

      // 5. Composite check digit: doc(0-10) + dob(13-20) + expiry&optional(21-43)
      final compositePayload = 'L898902C3674081221204159ZE184226B<<<<<1';
      expect(MrzParser.computeCheckDigit(compositePayload), 0);
      expect(MrzParser.verifyCheckDigit(compositePayload, '0'), true);
    });

    test('MrzParser strictly parses ICAO Utopia specimen with zero fake fallbacks', () {
      final result = MrzParser.parse(utopiaLine1, utopiaLine2, strict: true);

      expect(result.documentType, 'P');
      expect(result.issuingCountry, 'UTO');
      expect(result.surname, 'ERIKSSON');
      expect(result.givenNames, 'ANNA MARIA');
      expect(result.fullName, 'ANNA MARIA ERIKSSON');
      expect(result.passportNumber, 'L898902C3');
      expect(result.documentNumber, 'L898902C3');
      expect(result.passportMasked, '••••••2C3');
      expect(result.nationality, 'UTO');
      expect(result.sex, 'F');
      expect(result.personalNumber, 'ZE184226B');

      // Verifikasi inferensi tanggal
      expect(result.birthDate, DateTime(1974, 8, 12));
      expect(result.birthDateFormatted, '12 Aug 1974');
      expect(result.expiryDate, DateTime(2012, 4, 15));
      expect(result.expiryDateFormatted, '15 Apr 2012');

      // Verifikasi seluruh flag keabsahan
      expect(result.isPassportNumberValid, true);
      expect(result.isBirthDateValid, true);
      expect(result.isExpiryDateValid, true);
      expect(result.isCompositeValid, true);
      expect(result.isValid, true);
    });

    test('Special country code handling: Germany (D)', () {
      const deLine1 = 'P<D<<MUSTERMANN<<ERIKA<<<<<<<<<<<<<<<<<<<<<<';
      const deLine2 = 'C01X00T478D<<6408125F2702283<<<<<<<<<<<<<<<08';

      final result = MrzParser.parse(deLine1, deLine2);
      expect(result.issuingCountry, 'D');
      expect(result.surname, 'MUSTERMANN');
      expect(result.givenNames, 'ERIKA');
      expect(result.fullName, 'ERIKA MUSTERMANN');
      expect(result.nationality, 'D');
    });

    test('Century inference: DOB in 1900s vs 2000s and Expiry in 2000s', () {
      // DOB '950101' -> 1995 (karena 95 > tahun berjalan)
      const line1 = 'P<UTOTEST<<PERSON<<<<<<<<<<<<<<<<<<<<<<<<<<<';
      const line2 = '1234567897UTO9501014M3501011<<<<<<<<<<<<<<04';

      final result = MrzParser.parse(line1, line2);
      expect(result.birthDate?.year, 1995);
      expect(result.expiryDate?.year, 2035);
    });
  });

  group('Phase 5A: Elimination of Fake Fallbacks & Strict Validation (Golden Rules R2 & R3)', () {
    test('MrzParser does not inject James Wilson or fake static data when input is empty', () {
      final result = MrzParser.parse('', '');

      // Tidak boleh ada James Wilson atau fallback palsu lainnya
      expect(result.fullName, isEmpty);
      expect(result.fullName, isNot(contains('JAMES WILSON')));
      expect(result.passportNumber, isEmpty);
      expect(result.passportNumber, isNot('724918239'));
      expect(result.passportMasked, isEmpty);
      expect(result.passportMasked, isNot('••••••789'));
      expect(result.birthDate, isNull);
      expect(result.birthDateFormatted, isEmpty);
      expect(result.birthDateFormatted, isNot('12 May 1988'));
      expect(result.expiryDate, isNull);
      expect(result.expiryDateFormatted, isEmpty);
      expect(result.expiryDateFormatted, isNot('18 Mar 2032'));
      expect(result.issuingCountry, isEmpty);
      expect(result.issuingCountry, isNot('GBR'));
      expect(result.nationality, isEmpty);
      expect(result.nationality, isNot('GBR'));
      expect(result.isValid, false);
    });

    test('MrzParser in strict mode throws ValidationFailure on empty or invalid MRZ', () {
      expect(
        () => MrzParser.parse('', '', strict: true),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('Zero false acceptance: Tampered passport check digit is rejected', () {
      // Ubah check digit nomor paspor dari 6 menjadi 7
      const tamperedLine2 = 'L898902C37UTO7408122F1204159ZE184226B<<<<<10';
      const line1 = 'P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<';

      final result = MrzParser.parse(line1, tamperedLine2);
      expect(result.isPassportNumberValid, false);
      expect(result.isValid, false);

      expect(
        () => result.validateOrThrow(),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('Zero false acceptance: Tampered DOB check digit is rejected', () {
      // Ubah check digit DOB dari 2 menjadi 5
      const tamperedLine2 = 'L898902C36UTO7408125F1204159ZE184226B<<<<<10';
      const line1 = 'P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<';

      final result = MrzParser.parse(line1, tamperedLine2);
      expect(result.isBirthDateValid, false);
      expect(result.isValid, false);
      expect(() => result.validateOrThrow(), throwsA(isA<ValidationFailure>()));
    });

    test('Zero false acceptance: Tampered composite check digit is rejected', () {
      // Ubah composite check digit akhir dari 0 menjadi 9
      const tamperedLine2 = 'L898902C36UTO7408122F1204159ZE184226B<<<<<19';
      const line1 = 'P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<';

      final result = MrzParser.parse(line1, tamperedLine2);
      expect(result.isCompositeValid, false);
      expect(result.isValid, false);
      expect(() => result.validateOrThrow(), throwsA(isA<ValidationFailure>()));
    });
  });

  group('Phase 5A: MrzExtractor - Field-Based OCR Character Corrections (Level L1)', () {
    test('Corrects numeric fields misread as letters (O->0, I->1, B->8, S->5, Z->2)', () {
      // Misalkan OCR membaca DOB 7408122 sebagai '74O8I2Z' dan Expiry 1204159 sebagai 'IZO4IS9'
      const line1 = 'P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<';
      const noisyLine2 = 'L898902C36UTO74O8I2ZFIZO4IS9ZE184226B<<<<<1O';

      final extracted = MrzExtractor.extractFromLines([line1, noisyLine2]);

      expect(extracted, isNotNull);
      expect(extracted!.passportNumber, 'L898902C3');
      expect(extracted.birthDate, DateTime(1974, 8, 12));
      expect(extracted.expiryDate, DateTime(2012, 4, 15));
      expect(extracted.isValid, true);
    });

    test('Corrects alphabet fields misread as digits (0->O, 1->I)', () {
      // Misalkan OCR membaca kebangsaan UTO sebagai 'UT0'
      const line1 = 'P<UT0ERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<';
      const line2 = 'L898902C36UT07408122F1204159ZE184226B<<<<<10';

      final extracted = MrzExtractor.extractFromLines([line1, line2]);

      expect(extracted, isNotNull);
      expect(extracted!.issuingCountry, 'UTO');
      expect(extracted.nationality, 'UTO');
      expect(extracted.isValid, true);
    });

    test('Normalizes corrupted filler characters (parentheses, brackets, guillemets)', () {
      // Misalkan karakter '<' dibaca sebagai '(', ')', '[', '«', '‹', atau '/'
      const line1 = 'P(UTOERIKSSON((ANNA(MARIA«««««««««««««««««««';
      const line2 = 'L898902C36UTO7408122F1204159ZE184226B‹‹‹‹‹10';

      final extracted = MrzExtractor.extractFromLines([line1, line2]);

      expect(extracted, isNotNull);
      expect(extracted!.surname, 'ERIKSSON');
      expect(extracted.givenNames, 'ANNA MARIA');
      expect(extracted.personalNumber, 'ZE184226B');
      expect(extracted.isValid, true);
    });

    test('Extracts MRZ from noisy text containing headers and extraneous lines', () {
      const noisyOcr = '''
PASSPORT / PASSEPORT
REPUBLIC OF UTOPIA
Type/Type: P  Code: UTO  No: L898902C3
P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<
Random text between lines?
L898902C36UTO7408122F1204159ZE184226B<<<<<10
FOOTER BARCODE 123456789
      ''';

      final extracted = MrzExtractor.extractFromText(noisyOcr);

      expect(extracted, isNotNull);
      expect(extracted!.fullName, 'ANNA MARIA ERIKSSON');
      expect(extracted.passportNumber, 'L898902C3');
      expect(extracted.isValid, true);
    });

    test('Respects vertical bounding box ordering: Line 2 must be below Line 1', () {
      final candidates = [
        const MrzLineCandidate('L898902C36UTO7408122F1204159ZE184226B<<<<<10', 500.0), // Di bawah
        const MrzLineCandidate('P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<', 420.0), // Di atas
      ];

      final extracted = MrzExtractor.extractFromCandidates(candidates);

      expect(extracted, isNotNull);
      expect(extracted!.surname, 'ERIKSSON');
      expect(extracted.passportNumber, 'L898902C3');
    });
  });

  group('Phase 5A: Multi-Frame Consensus Engine (Level L1)', () {
    const line1 = 'P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<';
    const line2 = 'L898902C36UTO7408122F1204159ZE184226B<<<<<10';

    test('Requires 2 consecutive matching frames to confirm consensus', () {
      final consensus = MrzFrameConsensus(
        requiredConsecutiveMatches: 2,
        windowDuration: const Duration(seconds: 2),
      );

      final validFrame = MrzParser.parse(line1, line2);
      final t0 = DateTime(2026, 11, 18, 12, 0, 0);

      // Frame 1: Belum memenuhi threshold 2 frame
      final res1 = consensus.addFrame(validFrame, now: t0);
      expect(res1, isNull);
      expect(consensus.consecutiveCount, 1);

      // Frame 2 (250ms kemudian): Mencapai threshold 2 frame berurutan!
      final t1 = t0.add(const Duration(milliseconds: 250));
      final res2 = consensus.addFrame(validFrame, now: t1);
      expect(res2, isNotNull);
      expect(res2!.fullName, 'ANNA MARIA ERIKSSON');
      expect(res2.passportNumber, 'L898902C3');
    });

    test('Glitch or invalid intermediate frame resets consensus counter', () {
      final consensus = MrzFrameConsensus(
        requiredConsecutiveMatches: 2,
        windowDuration: const Duration(seconds: 2),
      );

      final validFrame = MrzParser.parse(line1, line2);
      final invalidFrame = MrzParser.parse('', '');
      final t0 = DateTime(2026, 11, 18, 12, 0, 0);

      // Frame 1: Valid
      expect(consensus.addFrame(validFrame, now: t0), isNull);
      expect(consensus.consecutiveCount, 1);

      // Frame 2: Glitch / Rusak -> Reset counter ke 0
      final t1 = t0.add(const Duration(milliseconds: 250));
      expect(consensus.addFrame(invalidFrame, now: t1), isNull);
      expect(consensus.consecutiveCount, 0);

      // Frame 3: Valid -> Baru frame 1 lagi
      final t2 = t1.add(const Duration(milliseconds: 250));
      expect(consensus.addFrame(validFrame, now: t2), isNull);
      expect(consensus.consecutiveCount, 1);

      // Frame 4: Valid -> Konsensus tercapai
      final t3 = t2.add(const Duration(milliseconds: 250));
      final confirmed = consensus.addFrame(validFrame, now: t3);
      expect(confirmed, isNotNull);
    });

    test('Expired time window resets consensus', () {
      final consensus = MrzFrameConsensus(
        requiredConsecutiveMatches: 2,
        windowDuration: const Duration(seconds: 2),
      );

      final validFrame = MrzParser.parse(line1, line2);
      final t0 = DateTime(2026, 11, 18, 12, 0, 0);

      // Frame 1 pada t0
      expect(consensus.addFrame(validFrame, now: t0), isNull);

      // Frame 2 tiba 3 detik kemudian (> 2 detik windowDuration)
      final t1 = t0.add(const Duration(seconds: 3));
      final res = consensus.addFrame(validFrame, now: t1);
      expect(res, isNull); // Window kedaluwarsa, frame ini menjadi frame 1 di window baru
      expect(consensus.consecutiveCount, 1);
    });
  });

  group('Phase 5A: Manual Passport Entry Algorithmic Integrity', () {
    test('Generates 100% valid ICAO 9303 TD3 lines and parses strictly', () {
      // Simulasi input manual pengguna
      const surname = 'DOE';
      const givenNames = 'JOHN';
      const country = 'AUS';
      const passportNum = 'N12345678';
      const dob = '900315'; // 15 Mar 1990
      const expiry = '300315'; // 15 Mar 2030
      const sex = 'M';

      // Hitung check digits sesuai aturan ICAO 9303
      final docCheck = MrzParser.computeCheckDigit(passportNum).toString();
      final dobCheck = MrzParser.computeCheckDigit(dob).toString();
      final expiryCheck = MrzParser.computeCheckDigit(expiry).toString();
      const personalNum = '<<<<<<<<<<<<<<';
      const personalCheck = '<';

      final nameSection = '$surname<<$givenNames';
      final line1 = ('P<$country$nameSection').padRight(44, '<').substring(0, 44);

      final compositePayload = '$passportNum$docCheck$dob$dobCheck$expiry$expiryCheck$personalNum$personalCheck';
      final compositeCheck = MrzParser.computeCheckDigit(compositePayload).toString();

      final line2 = '$passportNum$docCheck$country$dob$dobCheck$sex$expiry$expiryCheck$personalNum$personalCheck$compositeCheck';

      // Parse dengan strict: true
      final parsed = MrzParser.parse(line1, line2, strict: true);

      expect(parsed.surname, 'DOE');
      expect(parsed.givenNames, 'JOHN');
      expect(parsed.fullName, 'JOHN DOE');
      expect(parsed.passportNumber, 'N12345678');
      expect(parsed.nationality, 'AUS');
      expect(parsed.birthDate, DateTime(1990, 3, 15));
      expect(parsed.expiryDate, DateTime(2030, 3, 15));
      expect(parsed.isValid, true);
    });
  });
}
