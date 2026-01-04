// lib/src/core/utils/formatters.dart
import 'package:intl/intl.dart';

/// Shortens an Ethereum address to a more readable format e.g., "0x1234...5678"
String formatAddress(String address, {int visibleChars = 6}) {
  if (address.length < visibleChars * 2 + 2) {
    return address; // Not long enough to shorten
  }
  final start = address.substring(0, visibleChars + 2); // "0x" + chars
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

/// Formats a BigInt value (e.g., a balance in Wei) into a more readable format,
/// typically by dividing it by a number of decimals to get a double.
String formatBigInt(BigInt value, int decimals) {
  if (value == BigInt.zero) return '0.00';
  final asDouble = value / BigInt.from(10).pow(decimals);
  return formatEther(asDouble.toDouble());
}
