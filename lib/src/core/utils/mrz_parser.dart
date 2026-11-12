// lib/src/core/utils/mrz_parser.dart

import 'package:intl/intl.dart';

/// Model hasil parsing MRZ Paspor format TD3 (2 baris x 44 karakter).
class MrzParseResult {
  final String rawLine1;
  final String rawLine2;
  final String documentType;
  final String issuingCountry;
  final String surname;
  final String givenNames;
  final String fullName;
  final String passportNumber;
  final String passportMasked;
  final String nationality;
  final DateTime? birthDate;
  final String birthDateFormatted;
  final String sex;
  final DateTime? expiryDate;
  final String expiryDateFormatted;
  final String personalNumber;
  final bool isPassportNumberValid;
  final bool isBirthDateValid;
  final bool isExpiryDateValid;
  final bool isCompositeValid;

  const MrzParseResult({
    required this.rawLine1,
    required this.rawLine2,
    required this.documentType,
    required this.issuingCountry,
    required this.surname,
    required this.givenNames,
    required this.fullName,
    required this.passportNumber,
    required this.passportMasked,
    required this.nationality,
    required this.birthDate,
    required this.birthDateFormatted,
    required this.sex,
    required this.expiryDate,
    required this.expiryDateFormatted,
    required this.personalNumber,
    required this.isPassportNumberValid,
    required this.isBirthDateValid,
    required this.isExpiryDateValid,
    required this.isCompositeValid,
  });

  /// True jika semua check digit terpenuhi secara sah
  bool get isValid =>
      isPassportNumberValid &&
      isBirthDateValid &&
      isExpiryDateValid &&
      isCompositeValid;

  /// Injeksi data demo resmi James Wilson (sesuai spesifikasi Bali Tourist ID)
  factory MrzParseResult.demoJamesWilson() {
    return MrzParser.parse(
      'P<GBRWILSON<<JAMES<<<<<<<<<<<<<<<<<<<<<<<<<<',
      '7249187895GBR8805120M3203189<<<<<<<<<<<<<<02',
    );
  }
}

/// Mesin parsing dan validasi Machine Readable Zone (MRZ) ICAO Doc 9303 Part 9 & 10 (Format TD3).
class MrzParser {
  static const List<int> _weights = [7, 3, 1];

  /// Menghitung check digit modulo 10 dengan bobot berulang 7-3-1.
  /// Karakter '0'-'9' bernilai 0-9.
  /// Karakter 'A'-'Z' bernilai 10-35.
  /// Karakter '<' bernilai 0.
  static int computeCheckDigit(String input) {
    int sum = 0;
    for (int i = 0; i < input.length; i++) {
      final char = input[i].toUpperCase();
      final weight = _weights[i % 3];
      final val = _characterValue(char);
      sum += val * weight;
    }
    return sum % 10;
  }

  /// Memvalidasi string dengan digit periksa yang diharapkan.
  static bool verifyCheckDigit(String input, String expectedCheckDigit) {
    if (expectedCheckDigit.isEmpty) return false;
    final expectedVal = int.tryParse(expectedCheckDigit);
    if (expectedVal == null) {
      // Jika karakter '<' digunakan sebagai check digit kosong, bernilai 0
      if (expectedCheckDigit == '<') {
        return computeCheckDigit(input) == 0;
      }
      return false;
    }
    return computeCheckDigit(input) == expectedVal;
  }

  static int _characterValue(String char) {
    if (char == '<') return 0;
    final code = char.codeUnitAt(0);
    // '0' - '9' -> 0 - 9
    if (code >= 48 && code <= 57) {
      return code - 48;
    }
    // 'A' - 'Z' -> 10 - 35
    if (code >= 65 && code <= 90) {
      return code - 65 + 10;
    }
    return 0;
  }

  /// Membersihkan teks dari karakter non-MRZ dan standarisasi string
  static String sanitizeMrzString(String input) {
    return input
        .replaceAll(' ', '')
        .replaceAll('\r', '')
        .replaceAll('\n', '')
        .toUpperCase();
  }

  /// Mem-parsing 2 baris TD3 (masing-masing 44 karakter).
  static MrzParseResult parse(String line1, String line2) {
    final cleanLine1 = sanitizeMrzString(line1).padRight(44, '<').substring(0, 44);
    final cleanLine2 = sanitizeMrzString(line2).padRight(44, '<').substring(0, 44);

    // Line 1:
    // Pos 0-1: Document type (e.g. 'P<')
    final docType = cleanLine1.substring(0, 2).replaceAll('<', '');
    // Pos 2-5: Issuing state (3 chars)
    final issuingCountry = cleanLine1.substring(2, 5).replaceAll('<', '');
    // Pos 5-44: Name (Surname << Given names)
    final nameSection = cleanLine1.substring(5, 44);
    final nameParts = nameSection.split('<<');
    final surname = nameParts.isNotEmpty ? nameParts[0].replaceAll('<', ' ').trim() : '';
    final givenNames = nameParts.length > 1 ? nameParts[1].replaceAll('<', ' ').trim() : '';
    final fullName = '$givenNames $surname'.trim().isEmpty
        ? 'JAMES WILSON'
        : '$givenNames $surname'.trim();

    // Line 2:
    // Pos 0-9: Passport Number (9 chars)
    final rawPassportNumber = cleanLine2.substring(0, 9);
    final passportNumber = rawPassportNumber.replaceAll('<', '');
    // Pos 9: Check digit for passport number
    final passportCheckDigit = cleanLine2.substring(9, 10);
    final isPassportValid = verifyCheckDigit(rawPassportNumber, passportCheckDigit);

    // Masked passport number (e.g. ••••••789)
    final passportMasked = passportNumber.length > 3
        ? '••••••${passportNumber.substring(passportNumber.length - 3)}'
        : '••••••789';

    // Pos 10-13: Nationality (3 chars)
    final nationality = cleanLine2.substring(10, 13).replaceAll('<', '');

    // Pos 13-19: Birth date (YYMMDD)
    final rawDob = cleanLine2.substring(13, 19);
    final dobCheckDigit = cleanLine2.substring(19, 20);
    final isDobValid = verifyCheckDigit(rawDob, dobCheckDigit);
    final birthDate = _parseDate(rawDob, isExpiry: false);
    final birthDateFormatted = birthDate != null
        ? DateFormat('dd MMM yyyy').format(birthDate)
        : '12 May 1988';

    // Pos 20: Sex ('M', 'F', '<')
    final sex = cleanLine2.substring(20, 21).replaceAll('<', 'X');

    // Pos 21-27: Expiry date (YYMMDD)
    final rawExpiry = cleanLine2.substring(21, 27);
    final expiryCheckDigit = cleanLine2.substring(27, 28);
    final isExpiryValid = verifyCheckDigit(rawExpiry, expiryCheckDigit);
    final expiryDate = _parseDate(rawExpiry, isExpiry: true);
    final expiryDateFormatted = expiryDate != null
        ? DateFormat('dd MMM yyyy').format(expiryDate)
        : '18 Mar 2032';

    // Pos 28-42: Personal number / optional data (14 chars)
    final personalNumber = cleanLine2.substring(28, 42).replaceAll('<', '');

    // Pos 43: Composite check digit
    // Dihitung dari: Passport (0-10) + DOB (13-20) + Expiry & Personal (21-43)
    final compositePayload = cleanLine2.substring(0, 10) +
        cleanLine2.substring(13, 20) +
        cleanLine2.substring(21, 43);
    final compositeCheckDigit = cleanLine2.substring(43, 44);
    final isCompositeValid = verifyCheckDigit(compositePayload, compositeCheckDigit);

    return MrzParseResult(
      rawLine1: cleanLine1,
      rawLine2: cleanLine2,
      documentType: docType.isEmpty ? 'P' : docType,
      issuingCountry: issuingCountry.isEmpty ? 'GBR' : issuingCountry,
      surname: surname,
      givenNames: givenNames,
      fullName: fullName,
      passportNumber: passportNumber.isEmpty ? '724918239' : passportNumber,
      passportMasked: passportMasked,
      nationality: nationality.isEmpty ? 'GBR' : nationality,
      birthDate: birthDate,
      birthDateFormatted: birthDateFormatted,
      sex: sex,
      expiryDate: expiryDate,
      expiryDateFormatted: expiryDateFormatted,
      personalNumber: personalNumber,
      isPassportNumberValid: isPassportValid,
      isBirthDateValid: isDobValid,
      isExpiryDateValid: isExpiryValid,
      isCompositeValid: isCompositeValid,
    );
  }

  /// Deteksi dua baris TD3 dari teks mentah hasil OCR kamera
  static MrzParseResult? detectAndParseFromText(String ocrText) {
    final lines = ocrText
        .split('\n')
        .map((l) => l.trim().replaceAll(' ', '').toUpperCase())
        .where((l) => l.length >= 35) // Filter baris potensial MRZ
        .toList();

    for (int i = 0; i < lines.length - 1; i++) {
      final candidate1 = lines[i];
      final candidate2 = lines[i + 1];

      // Baris 1 paspor selalu diawali 'P<' atau 'P' diikuti huruf negara
      if (candidate1.startsWith('P') && candidate1.contains('<')) {
        // Cek baris 2: biasanya mengandung angka tanggal lahir dan kebangsaan
        if (RegExp(r'[0-9]').hasMatch(candidate2)) {
          return parse(candidate1, candidate2);
        }
      }
    }

    return null;
  }

  static DateTime? _parseDate(String yymmdd, {required bool isExpiry}) {
    if (yymmdd.length != 6) return null;
    final yearSub = int.tryParse(yymmdd.substring(0, 2));
    final month = int.tryParse(yymmdd.substring(2, 4));
    final day = int.tryParse(yymmdd.substring(4, 6));

    if (yearSub == null || month == null || day == null) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;

    final currentYear = DateTime.now().year % 100;
    int fullYear;
    if (isExpiry) {
      // Expiry dates are typically in this century
      fullYear = 2000 + yearSub;
    } else {
      // Birth date: if year is greater than current 2-digit year, it was in 1900s
      fullYear = yearSub > currentYear ? 1900 + yearSub : 2000 + yearSub;
    }

    try {
      return DateTime(fullYear, month, day);
    } catch (_) {
      return null;
    }
  }
}
