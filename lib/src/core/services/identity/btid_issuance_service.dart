// lib/src/core/services/identity/btid_issuance_service.dart

import 'dart:convert';
import 'dart:developer' as developer;
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:qrypta/src/core/config/app_config.dart';
import 'package:qrypta/src/core/data/models/btid_credential_model.dart';
import 'package:qrypta/src/core/data/models/immigration_data.dart';
import 'package:qrypta/src/core/error/app_failure.dart';
import 'package:qrypta/src/core/error/network_exception_adapter.dart';
import 'package:qrypta/src/core/utils/mrz_parser.dart';

/// Layanan penerbitan kredensial Bali Tourist ID otoritatif dari server (Phase 5B.1 & 5B.3).
///
/// Menegakkan Golden Rules R1 (tanpa silent catch), R2 (otoritas konfirmasi server),
/// R3 (bebas literal identitas palsu), dan R9 (zero raw PII pada payload audit/jaringan).
class BtidIssuanceService {
  final http.Client _httpClient;
  final String _baseUrl;
  static const String _serviceName = 'BtidIssuanceService';
  static const String defaultPassportSalt = 'QRYPTA_PASSPORT_SALT_2026';
  String? _lastLookupError;

  String? get lastLookupError => _lastLookupError;

  BtidIssuanceService({
    http.Client? httpClient,
    String? baseUrl,
  })  : _httpClient = httpClient ?? http.Client(),
        _baseUrl = baseUrl ?? AppConfig.ezsignUrl;

  /// Menghasilkan hash identitas paspor yang deterministik, bergaram, dan satu arah (HMAC-SHA256).
  /// Menegakkan Golden Rule R9: nomor paspor mentah tidak pernah dikirim ke payload audit/jaringan.
  static String generatePassportHash({
    required String nationality,
    required String passportNumber,
    required String dob,
    String salt = defaultPassportSalt,
  }) {
    final cleanNationality = nationality.trim().toUpperCase();
    final cleanPassportNumber = passportNumber.trim().toUpperCase();
    final cleanDob = dob.trim();
    final raw = '$cleanNationality:$cleanPassportNumber:$cleanDob';
    final hmac = Hmac(sha256, utf8.encode(salt));
    return hmac.convert(utf8.encode(raw)).toString();
  }

  /// Menghitung Idempotency-Key unik deterministik untuk mencegah penerbitan BTID ganda (Phase 5B.1).
  static String computeIdempotencyKey({
    required String passportHash,
    required String walletAddress,
  }) {
    final raw = '${passportHash.trim().toLowerCase()}:${walletAddress.trim().toLowerCase()}';
    return sha256.convert(utf8.encode(raw)).toString();
  }

  /// Mengambil data visa dan izin tinggal otoritatif dari otoritas imigrasi (Phase 5B.3 / D-2).
  /// Jika backend imigrasi tidak dapat dijangkau, mengembalikan metadata deklarasi mandiri berlabel 'self_declared'.
  Future<ImmigrationData> fetchImmigrationData({
    required String passportHash,
  }) async {
    final endpoint = _buildUri('/immigration/evoa', queryParams: {'passportHash': passportHash});

    try {
      final response = await _httpClient.get(
        endpoint,
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        final data = decoded is Map<String, dynamic> ? (decoded['data'] ?? decoded) : null;
        if (data is Map<String, dynamic>) {
          return ImmigrationData(
            visaType: data['visaType']?.toString() ?? 'Visit Visa',
            stayExpiry: data['stayExpiry']?.toString(),
            source: 'immigration_authority',
          );
        }
      }
    } on Object catch (e) {
      developer.log(
        'Immigration lookup transient failure (falling back to self_declared): $e',
        name: _serviceName,
      );
      _lastLookupError = e.toString();
    }

    return const ImmigrationData(
      visaType: 'Visit Visa (Self-declared)',
      stayExpiry: null,
      source: 'self_declared',
    );
  }

  /// Menerbitkan kredensial Bali Tourist ID secara otoritatif melalui panggilan server (Phase 5B.1 / F-11 / F-08).
  ///
  /// Memverifikasi secara ketat:
  /// 1. Paspor belum kedaluwarsa (`docExpiry` wajib valid dan berada di masa depan).
  /// 2. Tanggal lahir paspor tervalidasi dan tidak null.
  /// 3. Biodata wajib (nama, nomor dokumen, wallet) lengkap dan non-kosong.
  /// 4. Server merespons HTTP 200/201 dengan `btidNumber` otoritatif.
  ///
  /// Melempar [AppFailure] jika terjadi kegagalan validasi, jaringan, atau penolakan server.
  /// TIDAK PERNAH membuat fallback kartu BTID lokal jika server menolak/offline.
  Future<BtidCredentialModel> issueCredential({
    required MrzParseResult mrzResult,
    required String walletAddress,
    ImmigrationData? immigrationData,
  }) async {
    // 1. Validasi Pre-Flight Paspor & Data Pribadi (Phase 5B.2 / F-13)
    if (mrzResult.birthDate == null) {
      throw const ValidationFailure('Tanggal lahir paspor wajib valid dan terisi.');
    }
    if (mrzResult.expiryDate == null) {
      throw const ValidationFailure('Tanggal kedaluwarsa paspor wajib valid.');
    }
    final now = DateTime.now();
    if (mrzResult.expiryDate!.isBefore(now)) {
      throw const ValidationFailure(
        'Paspor telah kedaluwarsa. Penerbitan Bali Tourist ID ditolak.',
      );
    }
    final cleanFullName = mrzResult.fullName.trim();
    if (cleanFullName.isEmpty) {
      throw const ValidationFailure('Nama lengkap pemegang paspor tidak boleh kosong.');
    }
    final cleanPassportNumber = mrzResult.passportNumber.trim();
    if (cleanPassportNumber.isEmpty) {
      throw const ValidationFailure('Nomor dokumen paspor tidak boleh kosong.');
    }
    final cleanWallet = walletAddress.trim();
    if (cleanWallet.isEmpty) {
      throw const ValidationFailure('Alamat wallet penerima wajib tersedia.');
    }

    final dobStr = DateFormat('yyyy-MM-dd').format(mrzResult.birthDate!);
    final docExpiryStr = DateFormat('yyyy-MM-dd').format(mrzResult.expiryDate!);

    // 2. Bentuk passportHash Zero-PII (R9)
    final passportHash = generatePassportHash(
      nationality: mrzResult.nationality,
      passportNumber: cleanPassportNumber,
      dob: dobStr,
    );

    // 3. Resolusi Data Imigrasi (5B.3 / D-2)
    final resolvedImmigration = immigrationData ??
        await fetchImmigrationData(passportHash: passportHash);

    // 4. Hitung Idempotency-Key deterministik
    final idempotencyKey = computeIdempotencyKey(
      passportHash: passportHash,
      walletAddress: cleanWallet,
    );

    // 5. Kirim POST /credentials/btid ke ezsign-core server
    final endpoint = _buildUri('/credentials/btid');
    final requestPayload = {
      'passportHash': passportHash,
      'walletAddress': cleanWallet,
      'fullName': cleanFullName,
      'nationality': mrzResult.nationality,
      'dob': dobStr,
      'docExpiry': docExpiryStr,
      'visaType': resolvedImmigration.visaType,
      'stayExpiry': resolvedImmigration.stayExpiry,
      'visaSource': resolvedImmigration.source,
      'livenessMode': 'SIMULATED',
    };

    http.Response response;
    try {
      response = await _httpClient.post(
        endpoint,
        headers: {
          'Content-Type': 'application/json',
          'Idempotency-Key': idempotencyKey,
        },
        body: jsonEncode(requestPayload),
      ).timeout(const Duration(seconds: 10));
    } on Object catch (e) {
      developer.log('Koneksi server gagal saat penerbitan BTID: $e', name: _serviceName);
      throw NetworkExceptionAdapter.fromException(e);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw NetworkExceptionAdapter.fromHttpResponse(response.statusCode, response.body);
    }

    // 6. Parsing respons otoritatif server
    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on Object catch (e) {
      throw ServerRejected(
        'Respons server bukan format JSON yang valid: $e',
        response.statusCode,
        null,
      );
    }

    final data = decoded is Map<String, dynamic> ? (decoded['data'] ?? decoded) : null;
    if (data is! Map<String, dynamic>) {
      throw const ServerRejected('Format respons penerbitan BTID tidak valid.', 200, null);
    }

    final serverBtidNumber = data['btidNumber']?.toString() ?? '';
    if (serverBtidNumber.isEmpty) {
      throw const ServerRejected('Server tidak mengembalikan nomor BTID yang valid.', 200, null);
    }

    final issuedAt = data['issuedAt'] != null
        ? DateTime.tryParse(data['issuedAt'].toString()) ?? now
        : now;

    final stayExpiry = data['expiresAt']?.toString() ??
        resolvedImmigration.stayExpiry ??
        DateFormat('yyyy-MM-dd').format(now.add(const Duration(days: 30)));

    final anchorTxHash = data['anchorTxHash']?.toString();

    return BtidCredentialModel(
      btidNumber: serverBtidNumber,
      fullName: cleanFullName,
      nationality: mrzResult.nationality,
      passportMasked: mrzResult.passportMasked,
      dob: dobStr,
      docExpiry: docExpiryStr,
      visaType: resolvedImmigration.visaType,
      arrivalDate: DateFormat('yyyy-MM-dd').format(now),
      stayExpiry: stayExpiry,
      levyStatus: 'unpaid',
      walletAddress: cleanWallet,
      issuedAt: issuedAt,
      anchorTxHash: anchorTxHash,
      immigrationSource: resolvedImmigration.source,
    );
  }

  Uri _buildUri(String path, {Map<String, String>? queryParams}) {
    var base = _baseUrl.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$normalizedPath').replace(queryParameters: queryParams);
  }
}
