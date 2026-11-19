// lib/src/core/services/merchant/merchant_resolver_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:qrypta/src/core/config/app_config.dart';
import 'package:qrypta/src/core/error/app_failure.dart';
import 'package:qrypta/src/core/error/network_exception_adapter.dart';

/// Hasil resolusi identitas & dompet settlement merchant konsorsium (Phase 6.3 / D-4).
class MerchantResolutionResult {
  final String merchantId;
  final String walletAddress;
  final String displayName;
  final bool verified;
  final String? category;
  final double feePercentage;
  final int fixedFee;

  const MerchantResolutionResult({
    required this.merchantId,
    required this.walletAddress,
    required this.displayName,
    required this.verified,
    this.category,
    this.feePercentage = 0.0,
    this.fixedFee = 0,
  });

  factory MerchantResolutionResult.fromJson(Map<String, dynamic> json) {
    final merchantId = json['merchantId']?.toString() ?? json['id']?.toString();
    final walletAddress = json['walletAddress']?.toString() ?? json['address']?.toString();
    final displayName = json['displayName']?.toString() ?? json['merchantName']?.toString() ?? json['name']?.toString();
    final verified = json['verified'] == true;

    if (merchantId == null || walletAddress == null || displayName == null) {
      throw const FormatException('Data merchant resolver tidak lengkap dari server.');
    }

    return MerchantResolutionResult(
      merchantId: merchantId,
      walletAddress: walletAddress,
      displayName: displayName,
      verified: verified,
      category: json['category']?.toString(),
      feePercentage: (json['feePercentage'] is num) ? (json['feePercentage'] as num).toDouble() : 0.0,
      fixedFee: (json['fixedFee'] is num) ? (json['fixedFee'] as num).toInt() : 0,
    );
  }

  @override
  String toString() =>
      'MerchantResolutionResult(id: $merchantId, name: $displayName, wallet: $walletAddress, verified: $verified)';
}

/// Layanan resolusi NMID QRIS ke dompet merchant konsorsium (Phase 6.3 / D-4).
///
/// Menegakkan Golden Rule R1 & R2:
/// - Stiker QRIS fisik bermuara pada rail rupiah (PJP/bank).
/// - Pembayaran IDRT on-chain HANYA berlaku untuk merchant yang terdaftar di konsorsium.
/// - Jika NMID tidak terdaftar di backend, dilempar [MerchantNotRegistered], tanpa transaksi dan tanpa sukses palsu.
class MerchantResolverService {
  final http.Client _httpClient;
  final String _baseUrl;

  MerchantResolverService({
    http.Client? httpClient,
    String? baseUrl,
  })  : _httpClient = httpClient ?? http.Client(),
        _baseUrl = baseUrl ?? AppConfig.ezsignUrl;

  /// Memetakan NMID QRIS ke identitas dan dompet settlement on-chain merchant.
  Future<MerchantResolutionResult> resolve({required String nmid}) async {
    final cleanNmid = nmid.trim();
    if (cleanNmid.isEmpty) {
      throw const ValidationFailure('NMID merchant tidak boleh kosong.');
    }

    final endpoint = Uri.parse('$_baseUrl/merchants/resolve?nmid=${Uri.encodeComponent(cleanNmid)}');

    final response = await NetworkExceptionAdapter.guard(
      () => _httpClient.get(
        endpoint,
        headers: {'Accept': 'application/json'},
      ),
    );

    if (response.statusCode == 404) {
      throw MerchantNotRegistered(
        'Merchant ini belum menerima pembayaran Qrypta (NMID: $cleanNmid).',
        cleanNmid,
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final decoded = jsonDecode(response.body);
        final data = decoded is Map<String, dynamic>
            ? (decoded['data'] is Map<String, dynamic> ? decoded['data'] : decoded)
            : null;

        if (data is! Map<String, dynamic>) {
          throw const FormatException('Format respons resolver merchant bukan JSON Object.');
        }

        final result = MerchantResolutionResult.fromJson(data);
        if (!result.verified) {
          throw MerchantNotRegistered(
            'Merchant ini belum terverifikasi di konsorsium Qrypta (NMID: $cleanNmid).',
            cleanNmid,
          );
        }

        return result;
      } on FormatException catch (e) {
        throw ServerRejected(
          'Gagal membaca data merchant dari server: ${e.message}',
          response.statusCode,
        );
      }
    }

    throw ServerRejected(
      'Server resolver merchant mengembalikan status error: ${response.statusCode}',
      response.statusCode,
    );
  }
}
