// lib/src/core/services/qr/qris_model.dart

/// Model data akun merchant QRIS (sub-tag 26–51) sesuai spesifikasi EMVCo & ASPI QRIS.
class QrisMerchantAccount {
  final int tag;
  final String? guid;
  final String? nmid;
  final String? criteria;
  final String? merchantId;
  final String rawValue;
  final Map<String, String> subTags;

  const QrisMerchantAccount({
    required this.tag,
    this.guid,
    this.nmid,
    this.criteria,
    this.merchantId,
    required this.rawValue,
    required this.subTags,
  });

  @override
  String toString() =>
      'QrisMerchantAccount(tag: $tag, guid: $guid, nmid: $nmid, criteria: $criteria)';
}

/// Model data tambahan QRIS (Tag 62) sesuai spesifikasi EMVCo MPM.
class QrisAdditionalData {
  final String? billNumber;
  final String? mobileNumber;
  final String? storeLabel;
  final String? loyaltyNumber;
  final String? referenceLabel;
  final String? customerLabel;
  final String? terminalLabel;
  final String? purpose;
  final Map<String, String> rawSubTags;

  const QrisAdditionalData({
    this.billNumber,
    this.mobileNumber,
    this.storeLabel,
    this.loyaltyNumber,
    this.referenceLabel,
    this.customerLabel,
    this.terminalLabel,
    this.purpose,
    required this.rawSubTags,
  });

  @override
  String toString() =>
      'QrisAdditionalData(bill: $billNumber, store: $storeLabel, terminal: $terminalLabel)';
}

/// Model hasil parsing payload QRIS EMVCo murni (Phase 6 / F-14).
/// Menyimpan seluruh tag terurai tanpa komputasi palsu atau tebakan string.
class QrisModel {
  final String rawPayload;
  final String payloadFormatIndicator; // Tag 00 ('01')
  final String pointOfInitiationMethod; // Tag 01 ('11' = statis, '12' = dinamis)
  final Map<int, QrisMerchantAccount> merchantAccounts; // Tags 26-51
  final String? nmid; // National Merchant ID
  final String? guid; // Reverse Domain / Global Unique ID
  final String? merchantCriteria; // UMI, UKE, UME, UBE
  final String merchantCategoryCode; // Tag 52 (MCC 4 digit)
  final String transactionCurrency; // Tag 53 ('360' untuk IDR)
  final double? transactionAmount; // Tag 54
  final String? tipIndicator; // Tag 55 ('01', '02', '03')
  final double? fixedFee; // Tag 56
  final double? percentageFee; // Tag 57
  final String countryCode; // Tag 58 ('ID')
  final String merchantName; // Tag 59
  final String merchantCity; // Tag 60
  final String? postalCode; // Tag 61
  final QrisAdditionalData? additionalData; // Tag 62
  final String crc; // Tag 63

  const QrisModel({
    required this.rawPayload,
    required this.payloadFormatIndicator,
    required this.pointOfInitiationMethod,
    required this.merchantAccounts,
    this.nmid,
    this.guid,
    this.merchantCriteria,
    required this.merchantCategoryCode,
    required this.transactionCurrency,
    this.transactionAmount,
    this.tipIndicator,
    this.fixedFee,
    this.percentageFee,
    required this.countryCode,
    required this.merchantName,
    required this.merchantCity,
    this.postalCode,
    this.additionalData,
    required this.crc,
  });

  /// Apakah QRIS ini bertipe dinamis (nominal diisi merchant/kasir).
  bool get isDynamic => pointOfInitiationMethod == '12';

  /// Apakah QRIS ini bertipe statis (nominal dapat diinput oleh pembayar).
  bool get isStatic => pointOfInitiationMethod == '11';

  /// Menghitung total tagihan termasuk tip / fee jika ada.
  double get totalAmount {
    final base = transactionAmount ?? 0.0;
    if (fixedFee != null && fixedFee! > 0) {
      return base + fixedFee!;
    }
    if (percentageFee != null && percentageFee! > 0) {
      return base + (base * (percentageFee! / 100.0));
    }
    return base;
  }

  @override
  String toString() =>
      'QrisModel(merchant: $merchantName, nmid: $nmid, amount: $transactionAmount, city: $merchantCity, dynamic: $isDynamic)';
}
