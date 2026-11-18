// lib/src/core/utils/mrz_extractor.dart

import 'dart:ui';
import 'package:qrypta/src/core/utils/mrz_parser.dart';

/// Representasi kandidat baris teks MRZ beserta koordinat vertikal untuk pengurutan.
class MrzLineCandidate {
  final String text;
  final double? top;

  const MrzLineCandidate(this.text, [this.top]);

  factory MrzLineCandidate.fromRect(String text, Rect? boundingBox) {
    return MrzLineCandidate(text, boundingBox?.top);
  }
}

/// Mesin ekstraksi dan koreksi karakter Machine Readable Zone (MRZ) TD3 ICAO Doc 9303 (Rencana Kerja §5A.3).
/// Melakukan penyaringan baris, pengurutan vertikal, koreksi optik berbasis tipe field,
/// dan penegakan check digit ICAO tanpa toleransi salah-terima (zero false acceptances).
class MrzExtractor {
  // Peta substitusi karakter angka yang sering salah dibaca oleh OCR sebagai huruf
  static const Map<String, String> _letterToDigitMap = {
    'O': '0',
    'Q': '0',
    'D': '0',
    'I': '1',
    'L': '1',
    'B': '8',
    'S': '5',
    'Z': '2',
    'G': '6',
  };

  // Peta substitusi karakter huruf yang sering salah dibaca oleh OCR sebagai angka
  static const Map<String, String> _digitToLetterMap = {
    '0': 'O',
    '1': 'I',
    '8': 'B',
    '5': 'S',
    '2': 'Z',
  };

  /// Ekstraksi MRZ TD3 dari teks mentah OCR kamera.
  static MrzParseResult? extractFromText(String rawText) {
    final rawLines = rawText.split('\n');
    return extractFromLines(rawLines);
  }

  /// Ekstraksi MRZ TD3 dari daftar baris teks string.
  static MrzParseResult? extractFromLines(List<String> rawLines) {
    final candidates = rawLines
        .asMap()
        .entries
        .map((e) => MrzLineCandidate(e.value, e.key.toDouble()))
        .toList();
    return extractFromCandidates(candidates);
  }

  /// Ekstraksi MRZ TD3 dari daftar [MrzLineCandidate] dengan koordinat vertikal.
  static MrzParseResult? extractFromCandidates(List<MrzLineCandidate> rawCandidates) {
    // 1. Bersihkan dan normalisasi setiap baris
    final cleanedCandidates = <MrzLineCandidate>[];
    for (final c in rawCandidates) {
      final sanitized = _sanitizeRawLine(c.text);
      if (sanitized.length >= 36) {
        cleanedCandidates.add(MrzLineCandidate(sanitized, c.top));
      }
    }

    // 2. Urutkan secara vertikal jika informasi posisi tersedia
    cleanedCandidates.sort((a, b) {
      if (a.top != null && b.top != null) {
        return a.top!.compareTo(b.top!);
      }
      return 0;
    });

    // 3. Cari pasangan baris 1 dan baris 2 yang memenuhi syarat TD3
    for (int i = 0; i < cleanedCandidates.length; i++) {
      final line1Candidate = cleanedCandidates[i];

      // Baris 1 paspor TD3 diawali 'P' dan karakter pengisi '<' atau jenis paspor
      if (!_isPotentialLine1(line1Candidate.text)) continue;

      for (int j = i + 1; j < cleanedCandidates.length; j++) {
        final line2Candidate = cleanedCandidates[j];

        // Pastikan baris 2 berada di bawah baris 1 jika posisi vertikal diketahui
        if (line1Candidate.top != null &&
            line2Candidate.top != null &&
            line2Candidate.top! <= line1Candidate.top!) {
          continue;
        }

        // Cek apakah kandidat baris 2 memiliki karakteristik baris kedua (nomor, DOB, expiry)
        if (!_isPotentialLine2(line2Candidate.text)) continue;

        // Coba koreksi dan validasi pasangan baris
        final parsed = _tryCorrectAndParse(line1Candidate.text, line2Candidate.text);
        if (parsed != null && parsed.isValid) {
          return parsed;
        }
      }
    }

    return null;
  }

  static bool _isPotentialLine1(String text) {
    if (text.length < 36) return false;
    final upper = text.toUpperCase();
    if (!upper.startsWith('P')) return false;
    // Baris 1 biasanya mengandung pemisah nama '<<' atau kode negara di awal
    return upper.contains('<') || upper.contains('«') || upper.contains('‹');
  }

  static bool _isPotentialLine2(String text) {
    if (text.length < 36) return false;
    // Baris 2 wajib mengandung digit angka (DOB, expiry)
    return RegExp(r'[0-9]').hasMatch(text);
  }

  static String _sanitizeRawLine(String input) {
    return input
        .replaceAll(' ', '')
        .replaceAll('\r', '')
        .replaceAll('\t', '')
        .toUpperCase();
  }

  /// Melakukan koreksi karakter berbasis tipe field ICAO TD3 dan memvalidasi check digit.
  static MrzParseResult? _tryCorrectAndParse(String rawLine1, String rawLine2) {
    final correctedLine1 = _correctLine1(rawLine1);
    final correctedLine2 = _correctLine2(rawLine2);

    if (correctedLine1.length != 44 || correctedLine2.length != 44) {
      return null;
    }

    // Parse dan validasi ICAO 9303 check digit
    final result = MrzParser.parse(correctedLine1, correctedLine2);
    if (result.isValid) {
      return result;
    }

    // Jika gagal pada dokumen check digit saja, coba perbaiki karakter ambigu di nomor dokumen (pos 0-9)
    if (!result.isPassportNumberValid && result.isBirthDateValid && result.isExpiryDateValid) {
      final docNumberAlternative = _tryAlternateDocNumber(correctedLine2);
      if (docNumberAlternative != null) {
        final altResult = MrzParser.parse(correctedLine1, docNumberAlternative);
        if (altResult.isValid) {
          return altResult;
        }
      }
    }

    return null;
  }

  /// Koreksi field-based pada Baris 1 TD3:
  /// Baris 1 hanya terdiri dari karakter alfabet (A-Z) dan karakter pengisi '<'.
  static String _correctLine1(String input) {
    final buffer = StringBuffer();
    final chars = input.split('');

    for (int i = 0; i < chars.length; i++) {
      var c = chars[i];

      // Normalisasi karakter pengisi yang sering salah dibaca OCR
      if (c == '(' ||
          c == ')' ||
          c == '[' ||
          c == ']' ||
          c == '{' ||
          c == '}' ||
          c == '«' ||
          c == '‹' ||
          c == '\\' ||
          c == '/' ||
          c == '|') {
        c = '<';
      }

      // Substitusi angka menjadi huruf (Line 1 adalah nama dan kode negara)
      if (_digitToLetterMap.containsKey(c)) {
        c = _digitToLetterMap[c]!;
      }

      buffer.write(c);
    }

    var result = buffer.toString();
    // Potong atau tambahkan '<' hingga tepat 44 karakter
    if (result.length > 44) {
      result = result.substring(0, 44);
    } else if (result.length < 44) {
      result = result.padRight(44, '<');
    }

    return result;
  }

  /// Koreksi field-based pada Baris 2 TD3:
  /// Memanfaatkan aturan tipe field ICAO Doc 9303:
  /// Pos 0-8: Dokumen (Alfanumerik)
  /// Pos 9: Check Digit Dokumen (Angka)
  /// Pos 10-12: Kebangsaan (Alfabet)
  /// Pos 13-18: DOB (Angka YYMMDD)
  /// Pos 19: Check Digit DOB (Angka)
  /// Pos 20: Jenis Kelamin (Alfabet M/F/<)
  /// Pos 21-26: Expiry (Angka YYMMDD)
  /// Pos 27: Check Digit Expiry (Angka)
  /// Pos 28-41: Personal Number (Alfanumerik + <)
  /// Pos 42: Check Digit Personal Number (Angka / <)
  /// Pos 43: Check Digit Komposit (Angka)
  static String _correctLine2(String input) {
    // Normalisasi karakter pengisi awal
    var normalized = input
        .replaceAll('(', '<')
        .replaceAll(')', '<')
        .replaceAll('[', '<')
        .replaceAll(']', '<')
        .replaceAll('«', '<')
        .replaceAll('‹', '<')
        .replaceAll('/', '<')
        .replaceAll('\\', '<');

    if (normalized.length > 44) {
      normalized = normalized.substring(0, 44);
    } else if (normalized.length < 44) {
      normalized = normalized.padRight(44, '<');
    }

    final chars = normalized.split('');

    // Pos 9: Check Digit Dokumen -> Angka
    chars[9] = _toDigit(chars[9]);

    // Pos 10-12: Kebangsaan -> Alfabet
    for (int i = 10; i <= 12; i++) {
      chars[i] = _toLetter(chars[i]);
    }

    // Pos 13-18: Tanggal Lahir (YYMMDD) -> Angka
    for (int i = 13; i <= 18; i++) {
      chars[i] = _toDigit(chars[i]);
    }

    // Pos 19: Check Digit DOB -> Angka
    chars[19] = _toDigit(chars[19]);

    // Pos 20: Jenis Kelamin -> Alfabet (M/F/<)
    chars[20] = _toLetter(chars[20]);

    // Pos 21-26: Tanggal Kedaluwarsa (YYMMDD) -> Angka
    for (int i = 21; i <= 26; i++) {
      chars[i] = _toDigit(chars[i]);
    }

    // Pos 27: Check Digit Kedaluwarsa -> Angka
    chars[27] = _toDigit(chars[27]);

    // Pos 42: Check Digit Personal Number (bila bukan pengisi '<')
    if (chars[42] != '<') {
      chars[42] = _toDigit(chars[42]);
    }

    // Pos 43: Check Digit Komposit -> Angka
    chars[43] = _toDigit(chars[43]);

    return chars.join('');
  }

  static String _toDigit(String c) {
    return _letterToDigitMap[c] ?? c;
  }

  static String _toLetter(String c) {
    return _digitToLetterMap[c] ?? c;
  }

  /// Coba alternatif pertukaran O/0 atau I/1 pada nomor dokumen jika check digit hampir cocok.
  static String? _tryAlternateDocNumber(String line2) {
    final chars = line2.split('');
    final rawDoc = chars.sublist(0, 9).join('');
    final expectedCheck = chars[9];

    // Coba ganti 'O' dengan '0'
    if (rawDoc.contains('O')) {
      final alt = rawDoc.replaceAll('O', '0');
      if (MrzParser.verifyCheckDigit(alt, expectedCheck)) {
        for (int i = 0; i < 9; i++) {
          chars[i] = alt[i];
        }
        return chars.join('');
      }
    }

    // Coba ganti '0' dengan 'O'
    if (rawDoc.contains('0')) {
      final alt = rawDoc.replaceAll('0', 'O');
      if (MrzParser.verifyCheckDigit(alt, expectedCheck)) {
        for (int i = 0; i < 9; i++) {
          chars[i] = alt[i];
        }
        return chars.join('');
      }
    }

    // Coba ganti 'I' dengan '1'
    if (rawDoc.contains('I')) {
      final alt = rawDoc.replaceAll('I', '1');
      if (MrzParser.verifyCheckDigit(alt, expectedCheck)) {
        for (int i = 0; i < 9; i++) {
          chars[i] = alt[i];
        }
        return chars.join('');
      }
    }

    return null;
  }
}
