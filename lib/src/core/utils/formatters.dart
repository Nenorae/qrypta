// lib/src/core/utils/formatters.dart
import 'package:intl/intl.dart';

/// Shortens an Ethereum address to a more readable format e.g., "0x1234...5678"
String formatAddress(String address, {int visibleChars = 6}) {
  if (address.length < visibleChars * 2 + 2) {
    return address;
  }
  final start = address.substring(0, visibleChars + 2);
  final end = address.substring(address.length - visibleChars);
  return '$start...$end';
}

/// Formats a value in Ether to a human-readable string with a fixed number of decimal places.
String formatEther(double value, {int maxFractionDigits = 6}) {
  final formatter = NumberFormat()
    ..minimumFractionDigits = 2
    ..maximumFractionDigits = maxFractionDigits;
  return formatter.format(value);
}

/// Parses a string representation of an amount into a BigInt with given decimals.
/// Avoids floating-point precision loss (IEEE 754) and prevents 64-bit integer overflow.
BigInt parseAmountToBigInt(String amountText, int decimals) {
  final cleanText = amountText.trim().replaceAll(',', '.');
  if (cleanText.isEmpty) return BigInt.zero;

  final parts = cleanText.split('.');
  String integerPart = parts[0].replaceAll(RegExp(r'[^0-9]'), '');
  if (integerPart.isEmpty) integerPart = '0';

  String fractionalPart = parts.length > 1 ? parts[1].replaceAll(RegExp(r'[^0-9]'), '') : '';
  if (fractionalPart.length > decimals) {
    fractionalPart = fractionalPart.substring(0, decimals);
  } else {
    fractionalPart = fractionalPart.padRight(decimals, '0');
  }

  final fullString = '$integerPart$fractionalPart';
  return BigInt.tryParse(fullString) ?? BigInt.zero;
}

/// Formats a BigInt value (e.g., ERC-20 token or Wei balance) into a human-readable string.
/// Uses BigInt integer division (~/) and modulo (%) to avoid IEEE 754 precision loss.
String formatBigInt(
  BigInt value,
  int decimals, {
  int maxFractionDigits = 2,
  bool isCurrency = false,
  String currencySymbol = 'Rp ',
}) {
  if (value == BigInt.zero) {
    return isCurrency ? '${currencySymbol}0' : '0.00';
  }

  final isNegative = value.isNegative;
  final positiveValue = value.abs();
  final divisor = BigInt.from(10).pow(decimals);
  final integerPart = positiveValue ~/ divisor;
  final remainder = positiveValue % divisor;

  // Format integer part with thousands separators
  final intFormatted = _formatBigIntThousands(integerPart, isCurrency ? '.' : ',');

  if (decimals == 0 || maxFractionDigits <= 0) {
    final prefix = isNegative ? '-' : '';
    final symbol = isCurrency ? currencySymbol : '';
    return '$prefix$symbol$intFormatted';
  }

  // Calculate fractional string
  final remainderPadded = remainder.toString().padLeft(decimals, '0');
  String fractionalString = remainderPadded.substring(
    0,
    remainderPadded.length < maxFractionDigits ? remainderPadded.length : maxFractionDigits,
  );

  // If currency and no fractional part left, format as clean integer currency
  if (isCurrency && remainder == BigInt.zero) {
    final prefix = isNegative ? '-' : '';
    return '$prefix$currencySymbol$intFormatted';
  }

  final decimalSeparator = isCurrency ? ',' : '.';
  final prefix = isNegative ? '-' : '';
  final symbol = isCurrency ? currencySymbol : '';
  return '$prefix$symbol$intFormatted$decimalSeparator$fractionalString';
}

/// Formats a BigInt with custom thousands separator without converting to double.
String _formatBigIntThousands(BigInt n, String separator) {
  final s = n.toString();
  final buffer = StringBuffer();
  final length = s.length;
  for (int i = 0; i < length; i++) {
    if (i > 0 && (length - i) % 3 == 0) {
      buffer.write(separator);
    }
    buffer.write(s[i]);
  }
  return buffer.toString();
}
