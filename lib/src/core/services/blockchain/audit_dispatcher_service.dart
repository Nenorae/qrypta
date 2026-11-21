// lib/src/core/services/blockchain/audit_dispatcher_service.dart

import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:qrypta/src/core/config/app_config.dart';
import 'package:qrypta/src/core/config/blockchain_config.dart';
import 'package:qrypta/src/core/data/models/actor_ref.dart';
import 'package:qrypta/src/core/data/models/audit_transaction_model.dart';
import 'package:qrypta/src/core/error/app_failure.dart';
import 'package:qrypta/src/core/error/network_exception_adapter.dart';
import 'package:qrypta/src/core/outbox/outbox_item.dart';
import 'package:qrypta/src/core/outbox/outbox_repository.dart';
import 'package:qrypta/src/core/utils/uuid_util.dart';

/// Layanan pengiriman dan pencatatan audit transaksi finansial dan kredensial (Phase 2.3, 4.3, 5B.1).
class AuditDispatcherService {
  final http.Client _httpClient;
  final OutboxRepository _outboxRepository;
  final Future<void> Function(AuditTransactionModel audit) _saveAuditCallback;

  static const String _serviceName = 'AuditDispatcher';

  AuditDispatcherService({
    required http.Client httpClient,
    required OutboxRepository outboxRepository,
    required Future<void> Function(AuditTransactionModel audit) saveAuditCallback,
  })  : _httpClient = httpClient,
        _outboxRepository = outboxRepository,
        _saveAuditCallback = saveAuditCallback;

  static String generateAuditRef() {
    final random = Random();
    final num = 100000 + random.nextInt(900000);
    return 'AUD-$num';
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
    final auditRef = generateAuditRef();
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

    await _saveAuditCallback(audit);
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
    final auditRef = generateAuditRef();
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

    await _saveAuditCallback(audit);
    return audit;
  }

  /// Records a credential issuance audit entry (Fase A - ScrIssued) and dispatches to ezsign-core.
  Future<AuditTransactionModel> recordCredentialIssuedAudit({
    required String btid,
    required String fullName,
    required String walletAddress,
  }) async {
    final auditRef = generateAuditRef();
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
        'liveness': {
          'mode': AppConfig.effectiveLivenessMode.toUpperCase(),
          'verified': false,
        },
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
      liveness: {
        'mode': AppConfig.effectiveLivenessMode.toUpperCase(),
        'verified': false,
      },
    );

    await _saveAuditCallback(audit);
    return audit;
  }
}
