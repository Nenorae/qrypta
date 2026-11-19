// lib/src/core/data/models/immigration_data.dart

/// Model data visa dan izin tinggal imigrasi (Phase 5B.3 / D-2).
/// Membedakan secara transparan antara data terverifikasi otoritatif dari backend imigrasi
/// (`immigration_authority`) dan deklarasi mandiri pengguna (`self_declared`).
class ImmigrationData {
  final String visaType;
  final String? stayExpiry;
  final String source; // 'immigration_authority' | 'self_declared'

  const ImmigrationData({
    required this.visaType,
    this.stayExpiry,
    required this.source,
  });

  bool get isAuthoritative => source == 'immigration_authority';

  Map<String, dynamic> toJson() {
    return {
      'visaType': visaType,
      'stayExpiry': stayExpiry,
      'source': source,
    };
  }

  factory ImmigrationData.fromJson(Map<String, dynamic> json) {
    return ImmigrationData(
      visaType: json['visaType'] as String? ?? 'Visit Visa',
      stayExpiry: json['stayExpiry'] as String?,
      source: json['source'] as String? ?? 'self_declared',
    );
  }

  @override
  String toString() =>
      'ImmigrationData(visa: $visaType, stayExpiry: $stayExpiry, source: $source, authoritative: $isAuthoritative)';
}
