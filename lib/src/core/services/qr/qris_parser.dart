// lib/src/core/services/qr/qris_parser.dart

import 'dart:convert';
import 'dart:isolate';
import 'package:qrypta/src/core/error/app_failure.dart';
import 'package:qrypta/src/core/services/qr/qris_model.dart';

/// Mesin parser QRIS EMVCo TLV & CRC16 murni (Phase 6 / F-14).
///
/// Mematuhi spesifikasi standar EMVCo MPM dan Standar Nasional QRIS (PADG BI No. 21/18/PADG/2019).
/// Menegakkan Golden Rule R1: tidak ada komputasi palsu, tebakan string, atau penelanan error diam-diam.
class QrisParser {
  const QrisParser._();

  /// Menghitung CRC16/CCITT-FALSE (poly 0x1021, init 0xFFFF) sesuai spesifikasi EMVCo MPM §4.6.
  static int crc16(String s) {
    var crc = 0xFFFF;
    for (final b in utf8.encode(s)) {
      crc ^= b << 8;
      for (var i = 0; i < 8; i++) {
        crc = (crc & 0x8000) != 0 ? ((crc << 1) ^ 0x1021) : (crc << 1);
        crc &= 0xFFFF;
      }
    }
    return crc;
  }

  /// Menghitung string hex 4-karakter kapital dari CRC16 untuk payload tertentu.
  static String computeCrcHex(String s) {
    final crc = crc16(s);
    return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
  }

  /// Mem-parsing raw string QRIS secara sinkronus murni.
  /// Melempar [ValidationFailure] jika payload melanggar spesifikasi TLV, CRC, atau aturan bisnis QRIS.
  static QrisModel parse(String raw) {
    final trimmed = raw.trim();

    if (trimmed.isEmpty) {
      throw const ValidationFailure('Payload QRIS kosong.');
    }

    if (!trimmed.startsWith('000201')) {
      throw const ValidationFailure(
        'Format QR bukan kandidat EMVCo/QRIS (wajib diawali 000201).',
      );
    }

    // 1. Ekstraksi TLV Top-Level
    final tags = _parseTlvMap(trimmed);

    // 2. Validasi Keberadaan dan Posisi Tag 63 (CRC)
    if (!tags.containsKey('63')) {
      throw const ValidationFailure('Tag 63 (CRC) tidak ditemukan pada payload QRIS.');
    }

    final crcValue = tags['63']!;
    if (crcValue.length != 4) {
      throw ValidationFailure(
        'Panjang tag 63 (CRC) wajib 4 karakter, ditemukan: ${crcValue.length}.',
      );
    }

    // EMVCo mensyaratkan tag 6304 menjadi tag terakhir pada string.
    final crcIndex = trimmed.lastIndexOf('6304');
    if (crcIndex < 0 || crcIndex != trimmed.length - 8) {
      throw const ValidationFailure(
        'Tag 63 (CRC) wajib berada di akhir payload QRIS (panjang tepat 8 karakter terakhir).',
      );
    }

    // Validasi Kriptografi CRC16
    final dataForCrc = trimmed.substring(0, crcIndex + 4); // sampai dan termasuk '6304'
    final expectedCrc = computeCrcHex(dataForCrc);
    if (crcValue.toUpperCase() != expectedCrc) {
      throw ValidationFailure(
        'Checksum CRC QRIS tidak valid: dihitung 0x$expectedCrc, ditemukan 0x${crcValue.toUpperCase()}.',
      );
    }

    // 3. Validasi Tag-tag Wajib (Mandatory Tags)
    final pfi = tags['00'];
    if (pfi != '01') {
      throw ValidationFailure(
        'Payload Format Indicator (tag 00) tidak valid: $pfi (wajib 01).',
      );
    }

    final poi = tags['01'];
    if (poi != '11' && poi != '12') {
      throw ValidationFailure(
        'Point of Initiation Method (tag 01) harus 11 (statis) atau 12 (dinamis): ditemukan $poi.',
      );
    }

    final mcc = tags['52'];
    if (mcc == null || mcc.length != 4 || int.tryParse(mcc) == null) {
      throw ValidationFailure(
        'Merchant Category Code (tag 52) wajib 4 digit numerik: ditemukan $mcc.',
      );
    }

    final currency = tags['53'];
    if (currency != '360') {
      throw ValidationFailure(
        'Mata uang bukan IDR (360): ditemukan $currency.',
      );
    }

    // Validasi Nominal (Tag 54)
    double? amount;
    final amountStr = tags['54'];
    if (poi == '12') {
      // Dinamis: nominal wajib ada
      if (amountStr == null || amountStr.isEmpty) {
        throw const ValidationFailure(
          'QRIS dinamis wajib memuat nominal transaksi pada tag 54.',
        );
      }
    }

    if (amountStr != null) {
      amount = double.tryParse(amountStr);
      if (amount == null || amount <= 0) {
        throw ValidationFailure(
          'Nominal transaksi (tag 54) tidak valid atau <= 0: \'$amountStr\'.',
        );
      }
    }

    final country = tags['58'];
    if (country != 'ID') {
      throw ValidationFailure(
        'Kode negara (tag 58) wajib \'ID\': ditemukan $country.',
      );
    }

    final merchantName = tags['59'];
    if (merchantName == null || merchantName.trim().isEmpty) {
      throw const ValidationFailure(
        'Nama merchant (tag 59) tidak boleh kosong.',
      );
    }

    final merchantCity = tags['60'];
    if (merchantCity == null || merchantCity.trim().isEmpty) {
      throw const ValidationFailure(
        'Kota merchant (tag 60) tidak boleh kosong.',
      );
    }

    // 4. Parsing Template Merchant Account Information (Tags 26–51)
    final merchantAccounts = <int, QrisMerchantAccount>{};
    String? extractedNmid;
    String? extractedGuid;
    String? extractedCriteria;

    for (int tagNum = 26; tagNum <= 51; tagNum++) {
      final tagStr = tagNum.toString().padLeft(2, '0');
      if (tags.containsKey(tagStr)) {
        final rawVal = tags[tagStr]!;
        final subMap = _parseSubTlv(rawVal);
        final guid = subMap['00'];
        final nmid = subMap['01'];
        final criteria = subMap['02'];
        final merchantId = subMap['03'];

        merchantAccounts[tagNum] = QrisMerchantAccount(
          tag: tagNum,
          guid: guid,
          nmid: nmid,
          criteria: criteria,
          merchantId: merchantId,
          rawValue: rawVal,
          subTags: subMap,
        );

        if (extractedNmid == null && nmid != null && nmid.isNotEmpty) {
          extractedNmid = nmid;
          extractedGuid = guid;
          extractedCriteria = criteria;
        }
      }
    }

    if (merchantAccounts.isEmpty) {
      throw const ValidationFailure(
        'Informasi akun merchant (tag 26–51) tidak ditemukan pada payload QRIS.',
      );
    }

    // 5. Parsing Tag Tip / Convenience Fee (Tags 55, 56, 57)
    final tipIndicator = tags['55'];
    double? fixedFee;
    double? percentageFee;

    if (tags.containsKey('56')) {
      fixedFee = double.tryParse(tags['56']!);
      if (fixedFee != null && fixedFee < 0) fixedFee = null;
    }
    if (tags.containsKey('57')) {
      percentageFee = double.tryParse(tags['57']!);
      if (percentageFee != null && percentageFee < 0) percentageFee = null;
    }

    // 6. Parsing Additional Data Field Template (Tag 62)
    QrisAdditionalData? additionalData;
    if (tags.containsKey('62')) {
      final rawSub = _parseSubTlv(tags['62']!);
      additionalData = QrisAdditionalData(
        billNumber: rawSub['01'],
        mobileNumber: rawSub['02'],
        storeLabel: rawSub['03'],
        loyaltyNumber: rawSub['04'],
        referenceLabel: rawSub['05'],
        customerLabel: rawSub['06'],
        terminalLabel: rawSub['07'],
        purpose: rawSub['08'],
        rawSubTags: rawSub,
      );
    }

    return QrisModel(
      rawPayload: trimmed,
      payloadFormatIndicator: pfi!,
      pointOfInitiationMethod: poi!,
      merchantAccounts: merchantAccounts,
      nmid: extractedNmid,
      guid: extractedGuid,
      merchantCriteria: extractedCriteria,
      merchantCategoryCode: mcc!,
      transactionCurrency: currency!,
      transactionAmount: amount,
      tipIndicator: tipIndicator,
      fixedFee: fixedFee,
      percentageFee: percentageFee,
      countryCode: country!,
      merchantName: merchantName,
      merchantCity: merchantCity,
      postalCode: tags['61'],
      additionalData: additionalData,
      crc: crcValue.toUpperCase(),
    );
  }

  /// Menjalankan parsing pada background Isolate (Phase 6.2 #5).
  /// Menjamin UI scanner kamera berjalan mulus tanpa freeze atau frame drop.
  static Future<QrisModel> parseInIsolate(String raw) async {
    return await Isolate.run(() => QrisParser.parse(raw));
  }

  /// Parser generik TLV top-level dengan validasi panjang ketat.
  static Map<String, String> _parseTlvMap(String raw) {
    final Map<String, String> tags = {};
    int index = 0;

    while (index < raw.length) {
      if (index + 4 > raw.length) {
        throw ValidationFailure(
          'Format TLV tidak lengkap: sisa string terpotong pada indeks $index.',
        );
      }

      final tag = raw.substring(index, index + 2);
      final lenStr = raw.substring(index + 2, index + 4);
      final len = int.tryParse(lenStr);

      if (len == null || len < 0) {
        throw ValidationFailure(
          'Panjang TLV untuk tag \'$tag\' tidak valid: \'$lenStr\'.',
        );
      }

      final valStart = index + 4;
      final valEnd = valStart + len;

      if (valEnd > raw.length) {
        throw ValidationFailure(
          'Panjang TLV untuk tag \'$tag\' ($len) melebihi panjang sisa string (${raw.length - valStart}).',
        );
      }

      final value = raw.substring(valStart, valEnd);
      tags[tag] = value;
      index = valEnd;
    }

    return tags;
  }

  /// Parser TLV rekursif untuk sub-tag template (misal tag 26-51 dan tag 62).
  static Map<String, String> _parseSubTlv(String raw) {
    final Map<String, String> subTags = {};
    int index = 0;

    while (index < raw.length) {
      if (index + 4 > raw.length) break;

      final tag = raw.substring(index, index + 2);
      final lenStr = raw.substring(index + 2, index + 4);
      final len = int.tryParse(lenStr);

      if (len == null || len < 0) break;

      final valStart = index + 4;
      final valEnd = valStart + len;

      if (valEnd > raw.length) break;

      subTags[tag] = raw.substring(valStart, valEnd);
      index = valEnd;
    }

    return subTags;
  }
}
