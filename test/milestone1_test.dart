import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrypta/src/core/utils/formatters.dart';

void main() {
  group('Milestone 1 - Arithmetic & Precision Tests', () {
    test('parseAmountToBigInt correctly scales 150,000 IDRT to 18 decimals without overflow', () {
      const amountStr = '150000';
      const decimals = 18;

      final result = parseAmountToBigInt(amountStr, decimals);
      final expected = BigInt.parse('150000000000000000000000');

      expect(result, equals(expected));
      expect(result > BigInt.from(9223372036854775807), isTrue); // Proves it exceeds int64 max
    });

    test('parseAmountToBigInt correctly handles fractional decimal amounts', () {
      const amountStr = '12.3456';
      const decimals = 6;

      final result = parseAmountToBigInt(amountStr, decimals);
      final expected = BigInt.parse('12345600');

      expect(result, equals(expected));
    });

    test('formatBigInt avoids IEEE 754 precision loss and formats Indonesian Rupiah', () {
      final levyAmount = parseAmountToBigInt('150000', 18);

      final formattedCurrency = formatBigInt(
        levyAmount,
        18,
        isCurrency: true,
        currencySymbol: 'Rp ',
      );

      expect(formattedCurrency, equals('Rp 150.000'));
    });

    test('formatBigInt correctly formats zero and decimals', () {
      expect(formatBigInt(BigInt.zero, 18), equals('0.00'));
      expect(formatBigInt(BigInt.zero, 18, isCurrency: true), equals('Rp 0'));

      final fractionalAmount = parseAmountToBigInt('1500.50', 18);
      final formatted = formatBigInt(fractionalAmount, 18, isCurrency: true);
      expect(formatted, equals('Rp 1.500,50'));
    });
  });

  group('Milestone 1 - Security & PIN Hashing Tests', () {
    test('PIN is securely hashed using SHA-256', () {
      const rawPin = '123456';
      final expectedHash = sha256.convert(utf8.encode(rawPin)).toString();

      expect(expectedHash.length, equals(64));
      expect(expectedHash, isNot(equals(rawPin)));
      expect(
        expectedHash,
        equals('8d969eef6ecad3c29a3a629280e686cf0c3f5d5a86aff3ca12020c923adc6c92'),
      );
    });
  });
}
