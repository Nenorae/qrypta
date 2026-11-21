// lib/src/core/services/blockchain/verification_transaction_service.dart

import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';
import 'dart:typed_data';

import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:qrypta/src/core/config/blockchain_config.dart';
import 'package:qrypta/src/core/data/models/actor_ref.dart';
import 'package:qrypta/src/core/data/models/audit_transaction_model.dart';
import 'package:qrypta/src/core/data/models/consent_request_model.dart';
import 'package:qrypta/src/core/error/app_failure.dart';
import 'package:qrypta/src/core/error/network_exception_adapter.dart';
import 'package:qrypta/src/core/outbox/outbox_item.dart';
import 'package:qrypta/src/core/outbox/outbox_repository.dart';
import 'package:qrypta/src/core/utils/uuid_util.dart';
import 'package:web3dart/crypto.dart';
import 'package:web3dart/web3dart.dart';

class VerificationTransactionService {
  final Web3Client? _web3Client;
  final http.Client _httpClient;
  final OutboxRepository _outboxRepository;
  static const String _boxName = 'audit_transactions_box';
  static const String _serviceName = 'VerificationTxService';

  final List<AuditTransactionModel> _memoryAuditCache = [];

  VerificationTransactionService([
    this._web3Client,
    http.Client? httpClient,
    OutboxRepository? outboxRepository,
  ])  : _httpClient = httpClient ?? http.Client(),
        _outboxRepository = outboxRepository ?? OutboxRepository();

  Web3Client? get web3Client => _web3Client;

  /// Generates a rotating ephemeral dynamic QR token (strictly 45s validity per Phase 7.1).
  String generateDynamicQrToken(
    String btid,
    String walletAddress, {
    int validitySeconds = 45,
    String? privateKeyHex,
    String? customSessionId,
    String? customNonce,
  }) {
    if (btid.isEmpty) {
      throw const ValidationFailure('BTID tidak boleh kosong saat membuat token QR dinamis.');
    }
    const chars = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
    final random = Random.secure();
    final tokenCode = StringBuffer('QRT-');
    for (int i = 0; i < 10; i++) {
      tokenCode.write(chars[random.nextInt(chars.length)]);
    }

    final sessionId = customSessionId ?? UuidUtil.generateV4();
    final nonceBytes = Uint8List(16);
    for (int i = 0; i < 16; i++) {
      nonceBytes[i] = random.nextInt(256);
    }
    final nonce = customNonce ?? '0x${bytesToHex(nonceBytes)}';
    final expTimestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + validitySeconds;

    String? signatureHex;
    if (privateKeyHex != null && privateKeyHex.isNotEmpty) {
      final cleanKey = _cleanHexKey(privateKeyHex);
      final ethKey = EthPrivateKey.fromHex(cleanKey);
      final canonicalPayload =
          'v=1&sessionId=$sessionId&nonce=$nonce&exp=$expTimestamp&wallet=${walletAddress.toLowerCase()}&btid=$btid';
      final sigBytes = ethKey.signPersonalMessageToUint8List(
        Uint8List.fromList(utf8.encode(canonicalPayload)),
      );
      signatureHex = '0x${bytesToHex(sigBytes)}';
    }

    final payload = {
      'v': 1,
      'sessionId': sessionId,
      'nonce': nonce,
      'exp': expTimestamp,
      'wallet': walletAddress,
      'btid': btid,
      'token': tokenCode.toString(),
      if (signatureHex != null) 'sig': signatureHex,
    };

    return jsonEncode(payload);
  }

  /// Memverifikasi keabsahan kriptografis dan masa berlaku payload QR Dinamis wisatawan (Phase 7.1).
  static bool verifyDynamicQrToken({
    required Map<String, dynamic> payload,
    int? currentEpochSeconds,
  }) {
    final v = payload['v'];
    final sessionId = payload['sessionId']?.toString();
    final nonce = payload['nonce']?.toString();
    final exp = payload['exp'];
    final wallet = payload['wallet']?.toString();
    final btid = payload['btid']?.toString();
    final sig = payload['sig']?.toString();

    if (v != 1 || sessionId == null || nonce == null || exp == null || wallet == null || btid == null) {
      return false;
    }

    final expInt = exp is int ? exp : int.tryParse(exp.toString());
    if (expInt == null) return false;

    final nowSec = currentEpochSeconds ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);
    if (expInt <= nowSec) {
      return false; // Kedaluwarsa
    }

    if (sig == null || !sig.startsWith('0x') || sig.length < 130) {
      return false; // Signature tidak ada atau tidak valid
    }

    try {
      final canonicalPayload =
          'v=1&sessionId=$sessionId&nonce=$nonce&exp=$expInt&wallet=${wallet.toLowerCase()}&btid=$btid';
      final cleanSig = sig.startsWith('0x') ? sig.substring(2) : sig;
      final sigBytes = hexToBytes(cleanSig);

      var vByte = sigBytes[64];
      if (vByte < 27) vByte += 27;

      final messageHash = keccak256(
        Uint8List.fromList(
          utf8.encode('\x19Ethereum Signed Message:\n${canonicalPayload.length}$canonicalPayload'),
        ),
      );

      final recoveredPublicKey = ecRecover(
        messageHash,
        MsgSignature(
          bytesToInt(sigBytes.sublist(0, 32)),
          bytesToInt(sigBytes.sublist(32, 64)),
          vByte,
        ),
      );

      final recoveredAddress = bytesToHex(
        keccak256(recoveredPublicKey).sublist(12),
        include0x: true,
      );

      return recoveredAddress.toLowerCase() == wallet.toLowerCase();
    } on Object catch (_) {
      return false;
    }
  }

  /// Digitally signs canonical consent attributes and submits to ezsign-core Fastify middleware.
  /// Enforces Golden Rule R1, R2, and R7.
  Future<AuditTransactionModel> signAndSubmitConsent({
    required String privateKeyHex,
    required ConsentRequestModel request,
    required Map<String, dynamic> approvedData,
    required bool isApproved,
    ActorRef? actor,
  }) async {
    final cleanKey = _cleanHexKey(privateKeyHex);
    final ethKey = EthPrivateKey.fromHex(cleanKey);
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final nowEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final btid = approvedData['btid']?.toString() ?? '';
    if (btid.isEmpty) {
      throw const ValidationFailure('BTID wajib disertakan untuk otorisasi data.');
    }

    final fullName = approvedData['fullName']?.toString() ?? '';
    if (fullName.isEmpty) {
      throw const ValidationFailure('Identitas pemegang BTID wajib disertakan.');
    }

    final walletAddress = approvedData['walletAddress']?.toString() ?? ethKey.address.hexEip55;

    final resolvedActor = actor ??
        ActorRef.fromCredential(
          walletAddress: walletAddress,
          btidNumber: btid,
          name: fullName,
        );

    final btidHashHex = '0x${bytesToHex(keccak256(Uint8List.fromList(utf8.encode(btid))))}';

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
    final canonicalDigestBytes = keccak256(Uint8List.fromList(utf8.encode(canonicalJson)));
    final canonicalDigestHex = '0x${bytesToHex(canonicalDigestBytes)}';

    // 2. Sign canonical payload using private key
    final signatureBytes = ethKey.signPersonalMessageToUint8List(
      Uint8List.fromList(utf8.encode(canonicalJson)),
    );
    final signatureHex = '0x${bytesToHex(signatureBytes)}';

    final auditRef = _generateAuditRef();
    final idempotencyKey = UuidUtil.generateV4();

    // 3. Dispatch to ezsign-core Fastify middleware
    final middlewareEndpoint = Uri.parse('${BlockchainConfig.ezsignApiUrl}/verify-identity');
    final middlewareBody = {
      'uuid': btid,
      'client_type': 'web3',
      'signature': signatureHex,
      'docType': 'BTID_CONSENT',
      'metadata': {
        'actor': resolvedActor.actorRef,
        'actorWallet': resolvedActor.walletAddress,
        'actorRef': resolvedActor.actorRef,
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

    String? serverCorrelationId;
    String? onChainTxHash;

    try {
      final response = await _httpClient.post(
        middlewareEndpoint,
        headers: {
          'Content-Type': 'application/json',
          'Idempotency-Key': idempotencyKey,
        },
        body: jsonEncode(middlewareBody),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        try {
          final resJson = jsonDecode(response.body);
          if (resJson is Map<String, dynamic>) {
            serverCorrelationId = resJson['correlation_id']?.toString() ??
                resJson['data']?['txHash']?.toString() ??
                resJson['id']?.toString();
            final rawTx = resJson['data']?['txHash'] ?? resJson['txHash'];
            if (rawTx != null && rawTx.toString().startsWith('0x')) {
              onChainTxHash = rawTx.toString();
            }
          }
        } on Object catch (e) {
          developer.log('Respon body non-JSON: $e', name: _serviceName);
          throw ServerRejected('Respons body bukan format JSON valid dari server: $e', response.statusCode, 'NON_JSON_RESPONSE');
        }
      } else {
        throw NetworkExceptionAdapter.fromHttpResponse(
          response.statusCode,
          response.body,
        );
      }
    } on Object catch (e) {
      if (e is AppFailure) rethrow;

      // Golden Rule R2: Approved TIDAK BOLEH dibuat palsu saat server offline.
      if (isApproved) {
        final failure = NetworkExceptionAdapter.fromException(e);
        developer.log('Fastify middleware unreachable ($middlewareEndpoint): $failure', name: _serviceName);
        throw failure;
      } else {
        // Penolakan (Rejected) dijadwalkan via outbox
        await _outboxRepository.enqueue(
          OutboxItem(
            id: idempotencyKey,
            type: 'audit_consent',
            endpoint: '/verify-identity',
            payload: middlewareBody,
            nextAttemptAt: DateTime.now().add(const Duration(seconds: 5)),
            createdAt: DateTime.now(),
          ),
        );
        final rejectedAudit = AuditTransactionModel(
          auditRef: auditRef,
          txRef: request.requestId,
          txHash: null,
          actor: resolvedActor.name?.isNotEmpty == true ? resolvedActor.name! : resolvedActor.actorRef,
          organisation: request.merchantName,
          action: 'Identity sharing rejected',
          purpose: request.purposeTemplate,
          sharedAttributesCount: 0,
          status: 'Rejected',
          timestamp: DateTime.now(),
          attributeKeys: request.requestedFields,
          receiptSignature: signatureHex,
          syncStatus: 'pending_sync',
          lastError: 'Server offline, penolakan dijadwalkan via outbox.',
          actorWallet: resolvedActor.walletAddress,
          actorRef: resolvedActor.actorRef,
        );
        await saveAuditTransaction(rejectedAudit);
        return rejectedAudit;
      }
    }

    final auditModel = AuditTransactionModel(
      auditRef: auditRef,
      txRef: request.requestId,
      txHash: onChainTxHash,
      actor: resolvedActor.name?.isNotEmpty == true ? resolvedActor.name! : resolvedActor.actorRef,
      organisation: request.merchantName,
      action: isApproved ? 'Identity shared with merchant' : 'Identity sharing rejected',
      purpose: request.purposeTemplate,
      sharedAttributesCount: isApproved ? request.requestedFields.length : 0,
      status: isApproved ? 'Approved' : 'Rejected',
      timestamp: DateTime.now(),
      attributeKeys: request.requestedFields,
      receiptSignature: signatureHex,
      syncStatus: 'synced',
      serverId: serverCorrelationId,
      actorWallet: resolvedActor.walletAddress,
      actorRef: resolvedActor.actorRef,
    );

    await saveAuditTransaction(auditModel);
    return auditModel;
  }

  /// Signs and submits a revocation request for a merchant's access.
  /// If server is unreachable, queues in outbox and marks status with explicit pending warning (R7).
  Future<AuditTransactionModel> revokeMerchantAccess({
    required String privateKeyHex,
    required String txRef,
    required String merchantId,
    required String btid,
    String? merchantName,
    ActorRef? actor,
  }) async {
    final cleanKey = _cleanHexKey(privateKeyHex);
    final ethKey = EthPrivateKey.fromHex(cleanKey);
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final nowEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    if (btid.isEmpty) {
      throw const ValidationFailure('BTID wajib disertakan untuk pencabutan akses.');
    }

    final resolvedActor = actor ??
        ActorRef.fromCredential(
          walletAddress: ethKey.address.hexEip55,
          btidNumber: btid,
        );

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
    final idempotencyKey = UuidUtil.generateV4();

    final middlewareEndpoint = Uri.parse('${BlockchainConfig.ezsignApiUrl}/verify-identity');
    final middlewareBody = {
      'uuid': btid,
      'client_type': 'web3',
      'signature': signatureHex,
      'docType': 'BTID_REVOKE',
      'metadata': {
        'actor': resolvedActor.actorRef,
        'actorWallet': resolvedActor.walletAddress,
        'actorRef': resolvedActor.actorRef,
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

    String syncStatus = 'synced';
    String? serverCorrelationId;
    String? lastError;

    try {
      final response = await _httpClient.post(
        middlewareEndpoint,
        headers: {
          'Content-Type': 'application/json',
          'Idempotency-Key': idempotencyKey,
        },
        body: jsonEncode(middlewareBody),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        try {
          final resJson = jsonDecode(response.body);
          if (resJson is Map<String, dynamic>) {
            serverCorrelationId = resJson['correlation_id']?.toString() ??
                resJson['data']?['txHash']?.toString();
          }
        } on Object catch (e) {
          developer.log('Respon body non-JSON: $e', name: _serviceName);
          throw ServerRejected('Respons body bukan format JSON valid dari server: $e', response.statusCode, 'NON_JSON_RESPONSE');
        }
      } else {
        throw NetworkExceptionAdapter.fromHttpResponse(
          response.statusCode,
          response.body,
        );
      }
    } on Object catch (e) {
      developer.log('Pencabutan akses server gagal, dialihkan ke outbox: $e', name: _serviceName);
      syncStatus = 'pending_sync';
      lastError = 'Pencabutan belum terkirim ke server. Merchant mungkin masih memiliki akses.';

      await _outboxRepository.enqueue(
        OutboxItem(
          id: idempotencyKey,
          type: 'audit_revocation',
          endpoint: '/verify-identity',
          payload: middlewareBody,
          nextAttemptAt: DateTime.now().add(const Duration(seconds: 5)),
          createdAt: DateTime.now(),
        ),
      );
    }

    final auditModel = AuditTransactionModel(
      auditRef: auditRef,
      txRef: txRef,
      txHash: null,
      actor: resolvedActor.name?.isNotEmpty == true ? resolvedActor.name! : resolvedActor.actorRef,
      organisation: merchantName ?? merchantId,
      action: 'Merchant access revoked',
      purpose: 'Revoke future access',
      sharedAttributesCount: 0,
      status: 'Revoked',
      timestamp: DateTime.now(),
      receiptSignature: signatureHex,
      syncStatus: syncStatus,
      serverId: serverCorrelationId,
      lastError: lastError,
      actorWallet: resolvedActor.walletAddress,
      actorRef: resolvedActor.actorRef,
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
    ActorRef? actor,
  }) async {
    final auditRef = _generateAuditRef();
    final nowEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final idempotencyKey = UuidUtil.generateV4();

    final resolvedActor = actor ??
        ActorRef.fromCredential(
          walletAddress: walletAddress,
          btidNumber: btid,
        );

    final middlewareEndpoint = Uri.parse('${BlockchainConfig.ezsignApiUrl}/verify-identity');
    final middlewareBody = {
      'uuid': btid,
      'client_type': 'web3',
      'signature': '0x',
      'docType': 'BTID_LEVY_PAYMENT',
      'metadata': {
        'actor': resolvedActor.actorRef,
        'actorWallet': resolvedActor.walletAddress,
        'actorRef': resolvedActor.actorRef,
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

    String syncStatus = 'synced';
    String? serverCorrelationId;
    String? lastError;

    try {
      final response = await _httpClient.post(
        middlewareEndpoint,
        headers: {
          'Content-Type': 'application/json',
          'Idempotency-Key': idempotencyKey,
        },
        body: jsonEncode(middlewareBody),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        try {
          final resJson = jsonDecode(response.body);
          if (resJson is Map<String, dynamic>) {
            serverCorrelationId = resJson['correlation_id']?.toString() ??
                resJson['data']?['txHash']?.toString();
          }
        } on Object catch (e) {
          developer.log('Respon body non-JSON: $e', name: _serviceName);
          throw ServerRejected('Respons body bukan format JSON valid dari server: $e', response.statusCode, 'NON_JSON_RESPONSE');
        }
      } else {
        throw NetworkExceptionAdapter.fromHttpResponse(
          response.statusCode,
          response.body,
        );
      }
    } on Object catch (e) {
      developer.log('Pencatatan audit levy server tertunda, dialihkan ke outbox: $e', name: _serviceName);
      syncStatus = 'pending_sync';
      lastError = 'Audit server tertunda. Transaksi on-chain tetap sah.';

      await _outboxRepository.enqueue(
        OutboxItem(
          id: idempotencyKey,
          type: 'audit_levy',
          endpoint: '/verify-identity',
          payload: middlewareBody,
          nextAttemptAt: DateTime.now().add(const Duration(seconds: 5)),
          createdAt: DateTime.now(),
        ),
      );
    }

    final audit = AuditTransactionModel(
      auditRef: auditRef,
      txRef: levyRef,
      txHash: txHash,
      actor: resolvedActor.name?.isNotEmpty == true ? resolvedActor.name! : resolvedActor.actorRef,
      organisation: 'Bali Tourism Authority (Bapenda)',
      action: 'Tourist Levy paid ($amountFormatted)',
      purpose: 'Official Bali Tourist Levy',
      sharedAttributesCount: 0,
      status: 'Paid',
      timestamp: DateTime.now(),
      syncStatus: syncStatus,
      serverId: serverCorrelationId,
      lastError: lastError,
      actorWallet: resolvedActor.walletAddress,
      actorRef: resolvedActor.actorRef,
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
    ActorRef? actor,
  }) async {
    final auditRef = _generateAuditRef();
    final nowEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final idempotencyKey = UuidUtil.generateV4();

    final resolvedActor = actor ??
        ActorRef.fromWallet(
          walletAddress: walletAddress,
        );

    final middlewareEndpoint = Uri.parse('${BlockchainConfig.ezsignApiUrl}/verify-identity');
    final middlewareBody = {
      'uuid': walletAddress,
      'client_type': 'web3',
      'signature': '0x',
      'docType': 'BTID_QRIS_PAYMENT',
      'metadata': {
        'actor': resolvedActor.actorRef,
        'actorWallet': resolvedActor.walletAddress,
        'actorRef': resolvedActor.actorRef,
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

    String syncStatus = 'synced';
    String? serverCorrelationId;
    String? lastError;

    try {
      final response = await _httpClient.post(
        middlewareEndpoint,
        headers: {
          'Content-Type': 'application/json',
          'Idempotency-Key': idempotencyKey,
        },
        body: jsonEncode(middlewareBody),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        try {
          final resJson = jsonDecode(response.body);
          if (resJson is Map<String, dynamic>) {
            serverCorrelationId = resJson['correlation_id']?.toString() ??
                resJson['data']?['txHash']?.toString();
          }
        } on Object catch (e) {
          developer.log('Respon body non-JSON: $e', name: _serviceName);
          throw ServerRejected('Respons body bukan format JSON valid dari server: $e', response.statusCode, 'NON_JSON_RESPONSE');
        }
      } else {
        throw NetworkExceptionAdapter.fromHttpResponse(
          response.statusCode,
          response.body,
        );
      }
    } on Object catch (e) {
      developer.log('Pencatatan audit QRIS server tertunda, dialihkan ke outbox: $e', name: _serviceName);
      syncStatus = 'pending_sync';
      lastError = 'Audit server tertunda. Transaksi on-chain tetap sah.';

      await _outboxRepository.enqueue(
        OutboxItem(
          id: idempotencyKey,
          type: 'audit_qris',
          endpoint: '/verify-identity',
          payload: middlewareBody,
          nextAttemptAt: DateTime.now().add(const Duration(seconds: 5)),
          createdAt: DateTime.now(),
        ),
      );
    }

    final audit = AuditTransactionModel(
      auditRef: auditRef,
      txRef: payRef,
      txHash: txHash,
      actor: resolvedActor.name?.isNotEmpty == true ? resolvedActor.name! : resolvedActor.actorRef,
      organisation: merchantName,
      action: 'QRIS Payment ($amountFormatted)',
      purpose: 'Payment Settlement',
      sharedAttributesCount: 0,
      status: 'Paid',
      timestamp: DateTime.now(),
      syncStatus: syncStatus,
      serverId: serverCorrelationId,
      lastError: lastError,
      actorWallet: resolvedActor.walletAddress,
      actorRef: resolvedActor.actorRef,
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
    final nowEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final idempotencyKey = UuidUtil.generateV4();

    final actorRef = ActorRef.fromCredential(
      walletAddress: walletAddress,
      btidNumber: btid,
      name: fullName,
    );

    final middlewareEndpoint = Uri.parse('${BlockchainConfig.ezsignApiUrl}/verify-identity');
    final middlewareBody = {
      'uuid': btid,
      'client_type': 'web3',
      'signature': '0x',
      'docType': 'BTID_ISSUED',
      'metadata': {
        'actor': 'System (Bali Tourism Authority)',
        'actorWallet': walletAddress,
        'actorRef': actorRef.actorRef,
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

    String syncStatus = 'synced';
    String? serverCorrelationId;
    String? anchorTxHash;
    String? lastError;

    try {
      final response = await _httpClient.post(
        middlewareEndpoint,
        headers: {
          'Content-Type': 'application/json',
          'Idempotency-Key': idempotencyKey,
        },
        body: jsonEncode(middlewareBody),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        try {
          final resJson = jsonDecode(response.body);
          if (resJson is Map<String, dynamic>) {
            serverCorrelationId = resJson['correlation_id']?.toString() ??
                resJson['data']?['txHash']?.toString();
            final rawTx = resJson['data']?['txHash'] ?? resJson['txHash'];
            if (rawTx != null && rawTx.toString().startsWith('0x')) {
              anchorTxHash = rawTx.toString();
            }
          }
        } on Object catch (e) {
          developer.log('Respon body non-JSON: $e', name: _serviceName);
          throw ServerRejected('Respons body bukan format JSON valid dari server: $e', response.statusCode, 'NON_JSON_RESPONSE');
        }
      } else {
        throw NetworkExceptionAdapter.fromHttpResponse(
          response.statusCode,
          response.body,
        );
      }
    } on Object catch (e) {
      developer.log('Penerbitan audit kredensial dialihkan ke outbox: $e', name: _serviceName);
      syncStatus = 'pending_sync';
      lastError = 'Audit kredensial server tertunda.';

      await _outboxRepository.enqueue(
        OutboxItem(
          id: idempotencyKey,
          type: 'audit_credential',
          endpoint: '/verify-identity',
          payload: middlewareBody,
          nextAttemptAt: DateTime.now().add(const Duration(seconds: 5)),
          createdAt: DateTime.now(),
        ),
      );
    }

    final audit = AuditTransactionModel(
      auditRef: auditRef,
      txRef: btid,
      txHash: anchorTxHash,
      actor: fullName,
      organisation: 'Bali Tourism Authority & Immigration',
      action: 'Credential issued',
      purpose: 'Identity onboarding',
      sharedAttributesCount: 0,
      status: 'Approved',
      timestamp: DateTime.now(),
      syncStatus: syncStatus,
      serverId: serverCorrelationId,
      anchorTxHash: anchorTxHash,
      lastError: lastError,
      actorWallet: walletAddress,
      actorRef: actorRef.actorRef,
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
    } on Object catch (e) {
      developer.log('Penyimpanan Hive gagal, fallback ke memori isolat: $e', name: _serviceName);
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
    } on Object catch (e) {
      developer.log('Pembacaan Hive audit gagal, mengambil dari memori: $e', name: _serviceName);
      results.addAll(_memoryAuditCache);
    }

    if (results.isEmpty && _memoryAuditCache.isNotEmpty) {
      results.addAll(_memoryAuditCache);
    }

    results.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return results;
  }

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
