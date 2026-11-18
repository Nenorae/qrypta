// lib/src/core/utils/mrz_frame_consensus.dart

import 'package:qrypta/src/core/utils/mrz_parser.dart';

/// Mesin konsensus multi-frame MRZ (Rencana Kerja §5A.3 item 6).
/// Mencegah false-positive (salah-terima OCR kebetulan lolos check digit)
/// dengan mensyaratkan minimal [requiredConsecutiveMatches] frame berurutan
/// menghasilkan MRZ yang identik dalam jendela waktu [windowDuration].
class MrzFrameConsensus {
  final int requiredConsecutiveMatches;
  final Duration windowDuration;

  MrzParseResult? _lastResult;
  int _consecutiveCount = 0;
  DateTime? _firstMatchTime;

  MrzFrameConsensus({
    this.requiredConsecutiveMatches = 2,
    this.windowDuration = const Duration(seconds: 2),
  });

  /// Jumlah frame berurutan saat ini yang cocok.
  int get consecutiveCount => _consecutiveCount;

  /// Nilai MRZ terakhir yang sedang berada di jendela konsensus.
  MrzParseResult? get lastCandidate => _lastResult;

  /// Memproses hasil MRZ dari frame kamera saat ini.
  /// Mengembalikan [MrzParseResult] hanya jika konsensus multi-frame terpenuhi.
  /// Mengembalikan `null` jika masih mengumpulkan frame atau frame tidak valid.
  MrzParseResult? addFrame(MrzParseResult? frameResult, {DateTime? now}) {
    final currentTime = now ?? DateTime.now();

    // Frame kosong atau check digit gagal langsung mereset konsensus
    if (frameResult == null || !frameResult.isValid) {
      _reset();
      return null;
    }

    // Frame pertama dalam kandidat konsensus
    if (_lastResult == null || _firstMatchTime == null) {
      _lastResult = frameResult;
      _firstMatchTime = currentTime;
      _consecutiveCount = 1;

      if (_consecutiveCount >= requiredConsecutiveMatches) {
        final confirmed = _lastResult!;
        _reset();
        return confirmed;
      }
      return null;
    }

    // Periksa apakah jendela waktu masih berlaku
    final elapsed = currentTime.difference(_firstMatchTime!);
    if (elapsed > windowDuration || elapsed.isNegative) {
      // Jendela kedaluwarsa: mulai jendela baru dengan frame ini
      _lastResult = frameResult;
      _firstMatchTime = currentTime;
      _consecutiveCount = 1;
      return null;
    }

    // Periksa apakah frame ini identik dengan frame sebelumnya
    final isIdentical = _isSamePassport(_lastResult!, frameResult);

    if (isIdentical) {
      _consecutiveCount++;
      if (_consecutiveCount >= requiredConsecutiveMatches) {
        final confirmed = frameResult;
        _reset();
        return confirmed;
      }
      return null;
    } else {
      // Frame berbeda (mungkin pergantian paspor atau glitch), mulai jendela baru
      _lastResult = frameResult;
      _firstMatchTime = currentTime;
      _consecutiveCount = 1;
      return null;
    }
  }

  bool _isSamePassport(MrzParseResult a, MrzParseResult b) {
    return a.passportNumber == b.passportNumber &&
        a.rawLine1 == b.rawLine1 &&
        a.rawLine2 == b.rawLine2 &&
        a.birthDate == b.birthDate &&
        a.expiryDate == b.expiryDate;
  }

  void _reset() {
    _lastResult = null;
    _consecutiveCount = 0;
    _firstMatchTime = null;
  }

  /// Reset manual seluruh state konsensus
  void reset() => _reset();
}
