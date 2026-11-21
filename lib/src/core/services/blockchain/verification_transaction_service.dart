// lib/src/core/services/blockchain/verification_transaction_service.dart

import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:qrypta/src/core/config/app_config.dart';
import 'package:qrypta/src/core/config/blockchain_config.dart';
import 'package:qrypta/src/core/data/models/actor_ref.dart';
import 'package:qrypta/src/core/data/models/audit_transaction_model.dart';
import 'package:qrypta/src/core/data/models/consent_request_model.dart';
import 'package:qrypta/src/core/error/app_failure.dart';
import 'package:qrypta/src/core/error/network_exception_adapter.dart';
import 'package:qrypta/src/core/outbox/outbox_item.dart';
import 'package:qrypta/src/core/outbox/outbox_repository.dart';
import 'package:qrypta/src/core/services/blockchain/audit_dispatcher_service.dart';
import 'package:qrypta/src/core/services/blockchain/audit_storage_service.dart';
import 'package:qrypta/src/core/services/blockchain/dynamic_qr_crypto_service.dart';
import 'package:qrypta/src/core/utils/uuid_util.dart';
import 'package:web3dart/crypto.dart';
import 'package:web3dart/web3dart.dart';

export 'audit_dispatcher_service.dart';
export 'audit_storage_service.dart';
export 'dynamic_qr_crypto_service.dart';

class VerificationTransactionService {
  final Web3Client? _web3Client;
  final http.Client _httpClient;
  final OutboxRepository _outboxRepository;
  final AuditStorageService _auditStorage;
  late final AuditDispatcherService _auditDispatcher;
  static const String _serviceName = 'VerificationTxService';

  VerificationTransactionService([
    this._web3Client,
    http.Client? httpClient,
    OutboxRepository? outboxRepository,
    AuditStorageService? auditStorage,
  ])  : _httpClient = httpClient ?? http.Client(),
        _outboxRepository = outboxRepository ?? OutboxRepository(),
        _auditStorage = auditStorage ?? AuditStorageService() {
    _auditDispatcher = AuditDispatcherService(
      httpClient: _httpClient,
      outboxRepository: _outboxRepository,
      saveAuditCallback: _auditStorage.saveAuditTransaction,
    );
  }

  Web3Client? get web3Client => _web3Client;

  /// Generates a rotating ephemeral dynamic QR token (strictly 45s validity per Phase 7.1).
  String generateDynamicQrToken(
    String btid,
    String walletAddress, {
    int validitySeconds = 45,
    String? privateKeyHex,
    String? customSessionId,
    String? customNonce,
  }) =>
      DynamicQrCryptoService.generateDynamicQrToken(
        btid,
        walletAddress,
        validitySeconds: validitySeconds,
        privateKeyHex: privateKeyHex,
        customSessionId: customSessionId,
        customNonce: customNonce,
      );

  /// Memverifikasi keabsahan kriptografis dan masa berlaku payload QR Dinamis wisatawan (Phase 7.1).
  static bool verifyDynamicQrToken({
    required Map<String, dynamic> payload,
    int? currentEpochSeconds,
  }) =>
      DynamicQrCryptoService.verifyDynamicQrToken(
        payload: payload,
        currentEpochSeconds: currentEpochSeconds,
      );

  /// Digitally signs canonical consent attributes and submits to ezsign-core Fastify middleware.
  /// Enforces Golden Rule R1, R2, and R7.
  Future<AuditTransactionModel> signAndSubmitConsent({
    required String privateKeyHex,
    required ConsentRequestModel request,
    required Map<String, dynamic> approvedData,
    required bool isApproved,
    ActorRef? actor,
  }) async {
    final cleanKey = DynamicQrCryptoService.cleanHexKey(privateKeyHex);
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

    final auditRef = AuditDispatcherService.generateAuditRef();
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
    final cleanKey = DynamicQrCryptoService.cleanHexKey(privateKeyHex);
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

    final auditRef = AuditDispatcherService.generateAuditRef();
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
  }) =>
      _auditDispatcher.recordLevyPaymentAudit(
        levyRef: levyRef,
        txHash: txHash,
        btid: btid,
        amountFormatted: amountFormatted,
        walletAddress: walletAddress,
        actor: actor,
      );

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
  }) =>
      _auditDispatcher.recordQrisPaymentAudit(
        payRef: payRef,
        txHash: txHash,
        merchantName: merchantName,
        merchantId: merchantId,
        amountFormatted: amountFormatted,
        walletAddress: walletAddress,
        itemDescription: itemDescription,
        actor: actor,
      );

  /// Records a credential issuance audit entry (Fase A - ScrIssued) and dispatches to ezsign-core.
  Future<AuditTransactionModel> recordCredentialIssuedAudit({
    required String btid,
    required String fullName,
    required String walletAddress,
  }) =>
      _auditDispatcher.recordCredentialIssuedAudit(
        btid: btid,
        fullName: fullName,
        walletAddress: walletAddress,
      );

  /// Persists an audit entry to local Hive storage and in-memory cache.
  Future<void> saveAuditTransaction(AuditTransactionModel audit) =>
      _auditStorage.saveAuditTransaction(audit);

  /// Retrieves full audit transaction history.
  Future<List<AuditTransactionModel>> getAuditTransactions() =>
      _auditStorage.getAuditTransactions();

  void dispose() {
    _httpClient.close();
  }
}
