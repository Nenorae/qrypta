// lib/src/core/services/blockchain/verification_transaction_service.dart

import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';
import 'dart:typed_data';

import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:qrypta/src/core/config/blockchain_config.dart';
import 'package:qrypta/src/core/data/models/audit_transaction_model.dart';
import 'package:qrypta/src/core/data/models/consent_request_model.dart';
import 'package:web3dart/crypto.dart';
import 'package:web3dart/web3dart.dart';

class VerificationTransactionService {
  final Web3Client? _web3Client;
  final http.Client _httpClient;
  static const String _boxName = 'audit_transactions_box';
  static const String _serviceName = 'VerificationTxService';

  // In-memory fallback if Hive is not yet initialized in tests
  final List<AuditTransactionModel> _memoryAuditCache = [];

  VerificationTransactionService([
    this._web3Client,
    http.Client? httpClient,
  ]) : _httpClient = httpClient ?? http.Client();

  /// Optional Web3Client for on-chain verification checks
  Web3Client? get web3Client => _web3Client;

  /// Generates a rotating ephemeral dynamic QR token (strictly 45s validity).
  /// Format: QRT-<10_ALPHANUMERIC_CHARS> with timestamp expiry and BTID binding.
  String generateDynamicQrToken(
    String btid,
    String walletAddress, {
    int validitySeconds = 45,
  }) {
    const chars = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
    final random = Random.secure();
    final tokenCode = StringBuffer('QRT-');
    for (int i = 0; i < 10; i++) {
      tokenCode.write(chars[random.nextInt(chars.length)]);
    }

    final expTimestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + validitySeconds;

    final payload = {
      'token': tokenCode.toString(),
      'btid': btid,
      'wallet': walletAddress,
      'exp': expTimestamp,
    };

    return jsonEncode(payload);
  }

  /// Digitally signs canonical consent attributes and submits to ezsign-core Fastify middleware.
  /// Canonical digest excludes raw PII and anchors only purpose-bound attribute keys and outcome.
  Future<AuditTransactionModel> signAndSubmitConsent({
    required String privateKeyHex,
    required ConsentRequestModel request,
    required Map<String, dynamic> approvedData,
    required bool isApproved,
  }) async {
    final cleanKey = _cleanHexKey(privateKeyHex);
    final ethKey = EthPrivateKey.fromHex(cleanKey);
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final nowEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final btid = approvedData['btid']?.toString() ?? 'BTID-2026-4471-0938';
    final btidHashHex = '0x${bytesToHex(keccak256(utf8.encode(btid)))}';

    // 1. Build canonical payload for cryptographic signing (zero raw PII)
    final canonicalPayload = {
      'txRef': request.requestId,
      'btidHash': btidHashHex,
      'merchantId': request.merchantId,
      'purpose': request.purposeTemplate,
      'attributeKeys': request.requestedFields,
      'outcome': isApproved ? 'APPROVED' : 'REJECTED',
      'timestamp': nowIso,
    };

    final canonicalJson = jsonEncode(canonicalPayload);
    final canonicalDigestBytes = keccak256(utf8.encode(canonicalJson));
    final canonicalDigestHex = '0x${bytesToHex(canonicalDigestBytes)}';

    // 2. Sign canonical payload using private key
    final signatureBytes = ethKey.signPersonalMessageToUint8List(
      Uint8List.fromList(utf8.encode(canonicalJson)),
    );
    final signatureHex = '0x${bytesToHex(signatureBytes)}';

    developer.log(
      'Signed consent for ${request.requestId} (outcome: ${isApproved ? "APPROVED" : "REJECTED"})',
      name: _serviceName,
    );

    final auditRef = _generateAuditRef();
    String txHash = '0x${bytesToHex(canonicalDigestBytes)}';

    // 3. Dispatch to ezsign-core Fastify middleware -> RabbitMQ -> tx-worker -> Besu
    final middlewareEndpoint = Uri.parse('${BlockchainConfig.ezsignApiUrl}/verify-identity');
    final middlewareBody = {
      'uuid': btid,
      'client_type': 'web3',
      'signature': signatureHex,
      'docType': 'BTID_CONSENT',
      'metadata': {
        'actor': approvedData['fullName']?.toString() ?? 'Tourist',
        'org': request.merchantName,
        'role': 'Tourist',
        'action': isApproved ? 'Identity shared with merchant' : 'Identity sharing rejected',
        'purpose': request.purposeTemplate,
        'record': request.requestId,
        'result': isApproved ? 'Approved' : 'Rejected',
        'sharedAttributesCount': isApproved ? request.requestedFields.length : 0,
        'attributeKeys': request.requestedFields,
        'canonicalDigest': canonicalDigestHex,
        'auditRef': auditRef,
      },
      'timestamp': nowEpoch,
    };

    try {
      final response = await _httpClient.post(
        middlewareEndpoint,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(middlewareBody),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 || response.statusCode == 202) {
        final resJson = jsonDecode(response.body);
        final returnedId = resJson['correlation_id'] ?? resJson['data']?['txHash'];
        if (returnedId != null) {
          txHash = returnedId.toString().startsWith('0x')
              ? returnedId.toString()
              : '0x${bytesToHex(keccak256(utf8.encode(returnedId.toString())))}';
        }
      }
    } catch (e) {
      // Graceful fallback for offline demo / decoupled execution
      developer.log(
        'Fastify middleware unreachable ($middlewareEndpoint): $e. Using local immutable digest.',
        name: _serviceName,
      );
    }

    // 4. Construct Audit Transaction Model and persist locally
    final auditModel = AuditTransactionModel(
      auditRef: auditRef,
      txRef: request.requestId,
      txHash: txHash,
      actor: approvedData['fullName']?.toString() ?? 'James Wilson',
      organisation: request.merchantName,
      action: isApproved ? 'Identity shared with merchant' : 'Identity sharing rejected',
      purpose: request.purposeTemplate,
      sharedAttributesCount: isApproved ? request.requestedFields.length : 0,
      status: isApproved ? 'Approved' : 'Rejected',
      timestamp: DateTime.now(),
      attributeKeys: request.requestedFields,
      receiptSignature: signatureHex,
    );

    await saveAuditTransaction(auditModel);
    return auditModel;
  }

  /// Signs and submits a revocation request for a merchant's access.
  Future<AuditTransactionModel> revokeMerchantAccess({
    required String privateKeyHex,
    required String txRef,
    required String merchantId,
    required String btid,
    String? merchantName,
  }) async {
    final cleanKey = _cleanHexKey(privateKeyHex);
    final ethKey = EthPrivateKey.fromHex(cleanKey);
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final nowEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final revokePayload = {
      'txRef': txRef,
      'btid': btid,
      'merchantId': merchantId,
      'action': 'REVOKE_ACCESS',
      'timestamp': nowIso,
    };

    final payloadJson = jsonEncode(revokePayload);
    final signatureBytes = ethKey.signPersonalMessageToUint8List(
      Uint8List.fromList(utf8.encode(payloadJson)),
    );
    final signatureHex = '0x${bytesToHex(signatureBytes)}';

    final auditRef = _generateAuditRef();
    String txHash = '0x${bytesToHex(keccak256(utf8.encode(payloadJson)))}';

    final middlewareEndpoint = Uri.parse('${BlockchainConfig.ezsignApiUrl}/verify-identity');
    final middlewareBody = {
      'uuid': btid,
      'client_type': 'web3',
      'signature': signatureHex,
      'docType': 'BTID_REVOKE',
      'metadata': {
        'actor': 'Tourist',
        'org': merchantName ?? merchantId,
        'role': 'Tourist',
        'action': 'Merchant access revoked',
        'purpose': 'Revoke future access',
        'record': txRef,
        'result': 'Revoked',
        'auditRef': auditRef,
      },
      'timestamp': nowEpoch,
    };

    try {
      await _httpClient.post(
        middlewareEndpoint,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(middlewareBody),
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      developer.log('Revocation submit offline fallback: $e', name: _serviceName);
    }

    final auditModel = AuditTransactionModel(
      auditRef: auditRef,
      txRef: txRef,
      txHash: txHash,
      actor: 'James Wilson',
      organisation: merchantName ?? merchantId,
      action: 'Merchant access revoked',
      purpose: 'Revoke future access',
      sharedAttributesCount: 0,
      status: 'Revoked',
      timestamp: DateTime.now(),
      receiptSignature: signatureHex,
    );

    await saveAuditTransaction(auditModel);
    return auditModel;
  }

  /// Records an on-chain Tourist Levy payment audit entry and dispatches to ezsign-core.
  Future<AuditTransactionModel> recordLevyPaymentAudit({
    required String levyRef,
    required String txHash,
    required String btid,
    required String amountFormatted,
    required String walletAddress,
  }) async {
    final auditRef = _generateAuditRef();
    final nowEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final middlewareEndpoint = Uri.parse('${BlockchainConfig.ezsignApiUrl}/verify-identity');
    final middlewareBody = {
      'uuid': btid,
      'client_type': 'web3',
      'signature': '0x',
      'docType': 'BTID_LEVY_PAYMENT',
      'metadata': {
        'actor': 'James Wilson',
        'org': 'Bali Tourism Authority (Bapenda)',
        'role': 'Tourist',
        'action': 'Tourist Levy paid ($amountFormatted)',
        'purpose': 'Official Bali Tourist Levy Settlement',
        'record': levyRef,
        'result': 'Paid',
        'amount': amountFormatted,
        'walletAddress': walletAddress,
        'txHash': txHash,
        'auditRef': auditRef,
      },
      'timestamp': nowEpoch,
    };

    try {
      await _httpClient.post(
        middlewareEndpoint,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(middlewareBody),
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      developer.log('Levy payment audit submit fallback: $e', name: _serviceName);
    }

    final audit = AuditTransactionModel(
      auditRef: auditRef,
      txRef: levyRef,
      txHash: txHash,
      actor: 'James Wilson',
      organisation: 'Bali Tourism Authority (Bapenda)',
      action: 'Tourist Levy paid ($amountFormatted)',
      purpose: 'Official Bali Tourist Levy',
      sharedAttributesCount: 0,
      status: 'Paid',
      timestamp: DateTime.now(),
    );

    await saveAuditTransaction(audit);
    return audit;
  }

  /// Records an on-chain QRIS Merchant Payment audit entry and dispatches to ezsign-core.
  Future<AuditTransactionModel> recordQrisPaymentAudit({
    required String payRef,
    required String txHash,
    required String merchantName,
    required String merchantId,
    required String amountFormatted,
    required String walletAddress,
    String? itemDescription,
  }) async {
    final auditRef = _generateAuditRef();
    final nowEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final middlewareEndpoint = Uri.parse('${BlockchainConfig.ezsignApiUrl}/verify-identity');
    final middlewareBody = {
      'uuid': walletAddress,
      'client_type': 'web3',
      'signature': '0x',
      'docType': 'BTID_QRIS_PAYMENT',
      'metadata': {
        'actor': 'James Wilson',
        'org': merchantName,
        'role': 'Customer',
        'action': 'QRIS Merchant Payment ($amountFormatted)',
        'purpose': 'Licensed Payment Settlement',
        'record': payRef,
        'merchantId': merchantId,
        'result': 'Paid',
        'amount': amountFormatted,
        'itemDescription': itemDescription ?? 'Merchant settlement',
        'walletAddress': walletAddress,
        'txHash': txHash,
        'auditRef': auditRef,
        'privacyGuarantee': 'Zero personal data or identity revealed to merchant',
      },
      'timestamp': nowEpoch,
    };

    try {
      await _httpClient.post(
        middlewareEndpoint,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(middlewareBody),
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      developer.log('QRIS payment audit submit fallback: $e', name: _serviceName);
    }

    final audit = AuditTransactionModel(
      auditRef: auditRef,
      txRef: payRef,
      txHash: txHash,
      actor: 'James Wilson',
      organisation: merchantName,
      action: 'QRIS Payment ($amountFormatted)',
      purpose: 'Payment Settlement',
      sharedAttributesCount: 0,
      status: 'Paid',
      timestamp: DateTime.now(),
    );

    await saveAuditTransaction(audit);
    return audit;
  }

  /// Records a credential issuance audit entry (Fase A - ScrIssued) and dispatches to ezsign-core.
  Future<AuditTransactionModel> recordCredentialIssuedAudit({
    required String btid,
    required String fullName,
    required String walletAddress,
  }) async {
    final auditRef = _generateAuditRef();
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final nowEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final txHash = '0x${bytesToHex(keccak256(utf8.encode("$btid-$walletAddress-$nowIso")))}';

    final middlewareEndpoint = Uri.parse('${BlockchainConfig.ezsignApiUrl}/verify-identity');
    final middlewareBody = {
      'uuid': btid,
      'client_type': 'web3',
      'signature': '0x',
      'docType': 'BTID_ISSUED',
      'metadata': {
        'actor': 'System (Bali Tourism Authority)',
        'org': 'Bali Tourism Authority & Immigration',
        'role': 'Issuer',
        'action': 'Credential issued',
        'purpose': 'Identity onboarding',
        'record': btid,
        'result': 'Issued',
        'walletAddress': walletAddress,
        'auditRef': auditRef,
      },
      'timestamp': nowEpoch,
    };

    try {
      await _httpClient.post(
        middlewareEndpoint,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(middlewareBody),
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      developer.log('Credential issued audit submit fallback: $e', name: _serviceName);
    }

    final audit = AuditTransactionModel(
      auditRef: auditRef,
      txRef: btid,
      txHash: txHash,
      actor: fullName,
      organisation: 'Bali Tourism Authority & Immigration',
      action: 'Credential issued',
      purpose: 'Identity onboarding',
      sharedAttributesCount: 0,
      status: 'Approved',
      timestamp: DateTime.now(),
    );

    await saveAuditTransaction(audit);
    return audit;
  }

  /// Persists an audit entry to local Hive storage and in-memory cache.
  Future<void> saveAuditTransaction(AuditTransactionModel audit) async {
    try {
      if (Hive.isBoxOpen(_boxName)) {
        final box = Hive.box(_boxName);
        await box.put(audit.txRef, audit.toJson());
      } else {
        final box = await Hive.openBox(_boxName);
        await box.put(audit.txRef, audit.toJson());
      }
    } catch (_) {
      // Memory cache fallback for test/non-flutter isolate environments
      final index = _memoryAuditCache.indexWhere((a) => a.txRef == audit.txRef);
      if (index >= 0) {
        _memoryAuditCache[index] = audit;
      } else {
        _memoryAuditCache.insert(0, audit);
      }
    }
  }

  /// Retrieves full audit transaction history.
  Future<List<AuditTransactionModel>> getAuditTransactions() async {
    final List<AuditTransactionModel> results = [];

    try {
      Box box;
      if (Hive.isBoxOpen(_boxName)) {
        box = Hive.box(_boxName);
      } else {
        box = await Hive.openBox(_boxName);
      }

      for (final key in box.keys) {
        final raw = box.get(key);
        if (raw is Map) {
          final map = Map<String, dynamic>.from(raw);
          results.add(AuditTransactionModel.fromJson(map));
        }
      }
    } catch (_) {
      results.addAll(_memoryAuditCache);
    }

    if (results.isEmpty && _memoryAuditCache.isNotEmpty) {
      results.addAll(_memoryAuditCache);
    }

    // Sort descending by timestamp
    results.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return results;
  }

  // Helper utilities
  static String _cleanHexKey(String key) {
    var k = key.trim();
    if (k.startsWith('0x') || k.startsWith('0X')) {
      k = k.substring(2);
    }
    return k.padLeft(64, '0');
  }

  static String _generateAuditRef() {
    final rand = Random();
    final num = 100000 + rand.nextInt(900000);
    return 'AUD-$num';
  }

  void dispose() {
    _httpClient.close();
  }
}
