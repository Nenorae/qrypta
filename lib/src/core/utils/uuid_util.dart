// lib/src/core/utils/uuid_util.dart

import 'dart:math';

/// Utility untuk membuat RFC 4122 v4 UUID secara kriptografis aman.
class UuidUtil {
  static final Random _secureRandom = Random.secure();

  /// Menghasilkan format UUID v4: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx.
  static String generateV4() {
    final bytes = List<int>.generate(16, (_) => _secureRandom.nextInt(256));

    // Versi 4 (bit 4-7 dari byte ke-6 diisi 0100)
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    // Varian RFC 4122 (bit 6-7 dari byte ke-8 diisi 10)
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    String toHex(int byte) => byte.toRadixString(16).padLeft(2, '0');
    final hex = bytes.map(toHex).toList();

    return '${hex.sublist(0, 4).join()}-'
        '${hex.sublist(4, 6).join()}-'
        '${hex.sublist(6, 8).join()}-'
        '${hex.sublist(8, 10).join()}-'
        '${hex.sublist(10, 16).join()}';
  }
}
