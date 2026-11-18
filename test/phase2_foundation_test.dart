// test/phase2_foundation_test.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:web3dart/json_rpc.dart';
import 'package:web3dart/web3dart.dart';

import 'package:qrypta/src/core/error/app_failure.dart';
import 'package:qrypta/src/core/error/network_exception_adapter.dart';
import 'package:qrypta/src/core/transaction/state_machine/tx_state.dart';
import 'package:qrypta/src/core/transaction/state_machine/tx_intent.dart';
import 'package:qrypta/src/core/transaction/state_machine/tx_intent_repository.dart';
import 'package:qrypta/src/core/transaction/state_machine/tx_state_machine.dart';
import 'package:qrypta/src/core/transaction/state_machine/tx_recovery_service.dart';
import 'package:qrypta/src/core/outbox/outbox_item.dart';
import 'package:qrypta/src/core/outbox/outbox_repository.dart';
import 'package:qrypta/src/core/outbox/outbox_worker.dart';
import 'package:qrypta/src/core/data/models/audit_transaction_model.dart';
import 'package:qrypta/src/core/services/audit/audit_migration_service.dart';
import 'package:qrypta/src/core/utils/uuid_util.dart';

void main() {
  group('Phase 2.1: AppFailure Taxonomy & NetworkExceptionAdapter (Level L1)', () {
    test('Maps SocketException and network drop to NetworkUnreachable', () {
      const socketError = SocketException('Failed host lookup: test.besu.node');
      final failure = NetworkExceptionAdapter.fromException(socketError);

      expect(failure, isA<NetworkUnreachable>());
      expect(failure.message, contains('Host tidak terjangkau'));
    });

    test('Maps TimeoutException to RequestTimeout', () {
      final timeoutError = TimeoutException('RPC call timed out after 10s');
      final failure = NetworkExceptionAdapter.fromException(timeoutError);

      expect(failure, isA<RequestTimeout>());
      expect(failure.message, contains('timed out'));
    });

    test('Maps HandshakeException to NetworkUnreachable (TLS issue)', () {
      const tlsError = HandshakeException('Certificate validation failed');
      final failure = NetworkExceptionAdapter.fromException(tlsError);

      expect(failure, isA<NetworkUnreachable>());
      expect(failure.message, contains('TLS/SSL'));
    });

    test('Maps HTTP 4xx and 5xx responses to ServerRejected with status and code', () {
      final f404 = NetworkExceptionAdapter.fromHttpResponse(
        404,
        jsonEncode({'error': {'code': 'NOT_FOUND', 'message': 'Merchant not found'}}),
      );
      expect(f404, isA<ServerRejected>());
      final s404 = f404 as ServerRejected;
      expect(s404.status, equals(404));
      expect(s404.code, equals('NOT_FOUND'));
      expect(s404.message, contains('Merchant not found'));

      final f503 = NetworkExceptionAdapter.fromHttpResponse(503, 'Service Unavailable');
      expect(f503, isA<ServerRejected>());
      expect((f503 as ServerRejected).status, equals(503));
    });

    test('Maps RPC errors: Insufficient funds -> InsufficientBalance', () {
      final rpcError = RPCError(-32000, 'insufficient funds for gas * price + value', null);
      final failure = NetworkExceptionAdapter.fromException(rpcError);

      expect(failure, isA<InsufficientBalance>());
      expect(failure.message, contains('Saldo akun tidak mencukupi'));
    });

    test('Maps RPC errors: Intrinsic gas too low -> InsufficientGas', () {
      final rpcError = RPCError(-32000, 'intrinsic gas too low', null);
      final failure = NetworkExceptionAdapter.fromException(rpcError);

      expect(failure, isA<InsufficientGas>());
      expect(failure.message, contains('Gas native tidak mencukupi'));
    });

    test('Maps RPC errors: Execution reverted -> TxReverted', () {
      final rpcError = RPCError(3, 'execution reverted: ERC20: transfer amount exceeds balance', null);
      final failure = NetworkExceptionAdapter.fromException(rpcError);

      expect(failure, isA<TxReverted>());
      expect(failure.message, contains('dibatalkan'));
    });

    test('NetworkExceptionAdapter.guard wraps async operations and preserves typed errors', () async {
      expect(
        () => NetworkExceptionAdapter.guard(() async {
          throw const SocketException('Connection refused');
        }),
        throwsA(isA<NetworkUnreachable>()),
      );
    });
  });

  group('Phase 2.2: On-Chain Transaction State Machine & Recovery (Level L1)', () {
    late TxIntentRepository repo;
    late TxStateMachine stateMachine;

    setUp(() {
      repo = TxIntentRepository();
      stateMachine = TxStateMachine(repository: repo);
    });

    test('Happy path transitions: idle -> preparing -> signing -> broadcasting -> pending -> confirmed', () async {
      expect(stateMachine.currentState, equals(TxState.idle));

      // 1. Start intent
      final intent = await stateMachine.startIntent(
        kind: 'levy',
        ref: 'LEV-TEST-001',
        from: '0x1111111111111111111111111111111111111111',
        to: '0x2222222222222222222222222222222222222222',
        amount: '150000000000000000000000',
        nonce: 4,
      );
      expect(stateMachine.currentState, equals(TxState.preparing));
      expect(intent.ref, equals('LEV-TEST-001'));

      // 2. Transition to signing
      await stateMachine.transitionTo(TxState.signing);
      expect(stateMachine.currentState, equals(TxState.signing));

      // 3. Transition to broadcasting
      await stateMachine.transitionTo(TxState.broadcasting);
      expect(stateMachine.currentState, equals(TxState.broadcasting));

      // 4. Transition to pending with real txHash
      await stateMachine.transitionTo(
        TxState.pending,
        txHash: '0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
      );
      expect(stateMachine.currentState, equals(TxState.pending));
      expect(stateMachine.currentIntent?.txHash, startsWith('0xabcdef'));

      // 5. Transition to confirmed with blockNumber
      await stateMachine.transitionTo(
        TxState.confirmed,
        blockNumber: BigInt.from(10052),
      );
      expect(stateMachine.currentState, equals(TxState.confirmed));
      expect(stateMachine.currentIntent?.blockNumber, equals(BigInt.from(10052)));
      expect(stateMachine.currentState.isTerminal, isTrue);

      // Verify persistence in repository
      final saved = await repo.getIntent(intent.intentId);
      expect(saved?.state, equals(TxState.confirmed));
      expect(saved?.blockNumber, equals(BigInt.from(10052)));
    });

    test('Rejects illegal state transitions (Golden Rule R2)', () async {
      await stateMachine.startIntent(
        kind: 'levy',
        ref: 'LEV-TEST-ILLEGAL',
        from: '0x1111111111111111111111111111111111111111',
        to: '0x2222222222222222222222222222222222222222',
        amount: '150000',
      );

      // Illegal: attempting jump directly from preparing to confirmed without broadcasting/pending
      expect(
        () => stateMachine.transitionTo(TxState.confirmed),
        throwsA(isA<ValidationFailure>()),
      );

      // After preparing, moving to signing is legal
      await stateMachine.transitionTo(TxState.signing);

      // Illegal: jumping from signing to confirmed
      expect(
        () => stateMachine.transitionTo(TxState.confirmed),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('TxRecoveryService marks broadcast interrupted without txHash as failed', () async {
      final interrupted = TxIntent(
        intentId: UuidUtil.generateV4(),
        kind: 'levy',
        ref: 'LEV-INT-001',
        from: '0x1111111111111111111111111111111111111111',
        to: '0x2222222222222222222222222222222222222222',
        amount: '150000',
        state: TxState.broadcasting,
        txHash: null, // App died before node returned hash
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        updatedAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      await repo.saveIntent(interrupted);

      final recovery = TxRecoveryService(repository: repo);
      final recovered = await recovery.recoverUnresolvedIntents();

      expect(recovered.length, equals(1));
      expect(recovered.first.state, equals(TxState.failed));
      expect(recovered.first.failureReason, contains('Aplikasi terhenti'));
    });
  });

  group('Phase 2.3: Outbox Pattern & Sync Worker (Level L1)', () {
    late OutboxRepository outboxRepo;

    setUp(() {
      outboxRepo = OutboxRepository();
    });

    test('Exponential backoff scales accurately (5s -> 10s -> 20s -> 40s ... max 900s)', () {
      expect(OutboxItem.calculateBackoff(0).inSeconds, equals(5));
      expect(OutboxItem.calculateBackoff(1).inSeconds, equals(5));
      expect(OutboxItem.calculateBackoff(2).inSeconds, equals(10));
      expect(OutboxItem.calculateBackoff(3).inSeconds, equals(20));
      expect(OutboxItem.calculateBackoff(4).inSeconds, equals(40));
      expect(OutboxItem.calculateBackoff(5).inSeconds, equals(80));
      expect(OutboxItem.calculateBackoff(6).inSeconds, equals(160));
      expect(OutboxItem.calculateBackoff(7).inSeconds, equals(320));
      expect(OutboxItem.calculateBackoff(8).inSeconds, equals(640));
      // Max clamp 900 seconds (15 minutes)
      expect(OutboxItem.calculateBackoff(9).inSeconds, equals(900));
      expect(OutboxItem.calculateBackoff(15).inSeconds, equals(900));
    });

    test('OutboxWorker successfully dispatches pending item with Idempotency-Key and marks sent', () async {
      final mockClient = MockClient((request) async {
        expect(request.headers['Idempotency-Key'], isNotNull);
        expect(request.headers['Content-Type'], equals('application/json'));
        return http.Response(
          jsonEncode({'status': 'OK', 'serverId': 'SRV-CONSENT-991'}),
          200,
        );
      });

      final worker = OutboxWorker(
        repository: outboxRepo,
        client: mockClient,
        baseUrl: 'https://staging.ezsign.qrypta.id',
      );

      final item = OutboxItem(
        id: UuidUtil.generateV4(),
        type: 'audit_consent',
        endpoint: '/api/consent',
        payload: {'subject': 'BTID-TEST-001', 'merchant': 'Bali Resort'},
        nextAttemptAt: DateTime.now().subtract(const Duration(seconds: 10)),
        createdAt: DateTime.now(),
      );
      await outboxRepo.enqueue(item);

      final processed = await worker.processPendingQueue();
      expect(processed, equals(1));

      final updated = await outboxRepo.getItemById(item.id);
      expect(updated?.status, equals(OutboxStatus.sent));
      expect(updated?.sentAt, isNotNull);
      expect(updated?.responsePayload?['serverId'], equals('SRV-CONSENT-991'));
    });

    test('OutboxWorker permanently rejects 4xx client errors without blind retries', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'error': 'INVALID_SIGNATURE', 'message': 'Signature mismatch'}),
          400,
        );
      });

      final worker = OutboxWorker(
        repository: outboxRepo,
        client: mockClient,
        baseUrl: 'https://staging.ezsign.qrypta.id',
      );

      final item = OutboxItem(
        id: UuidUtil.generateV4(),
        type: 'audit_consent',
        payload: {'subject': 'MALFORMED'},
        nextAttemptAt: DateTime.now().subtract(const Duration(seconds: 5)),
        createdAt: DateTime.now(),
      );
      await outboxRepo.enqueue(item);

      await worker.processPendingQueue();

      final updated = await outboxRepo.getItemById(item.id);
      expect(updated?.status, equals(OutboxStatus.rejected));
      expect(updated?.lastError, contains('HTTP 400'));
    });

    test('OutboxWorker marks status as needs_attention when maxAttempts reached', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final worker = OutboxWorker(
        repository: outboxRepo,
        client: mockClient,
        baseUrl: 'https://staging.ezsign.qrypta.id',
        maxAttempts: 3,
      );

      final item = OutboxItem(
        id: UuidUtil.generateV4(),
        type: 'audit_levy',
        attempts: 2, // Next failure will hit maxAttempts (3)
        payload: {'ref': 'LEV-001'},
        nextAttemptAt: DateTime.now().subtract(const Duration(seconds: 5)),
        createdAt: DateTime.now(),
      );
      await outboxRepo.enqueue(item);

      await worker.processPendingQueue();

      final updated = await outboxRepo.getItemById(item.id);
      expect(updated?.attempts, equals(3));
      expect(updated?.status, equals(OutboxStatus.needs_attention));
    });
  });

  group('Phase 2.4: Audit Model Enhancements & Hive Migration (Level L1)', () {
    test('AuditTransactionModel defaults to legacy_unverified when syncStatus is absent in json', () {
      // Legacy JSON fixture without syncStatus (old schema before Phase 2)
      final legacyJson = {
        'auditRef': 'AUD-LEGACY-01',
        'txRef': 'TX-LEGACY-01',
        'actor': 'Anonymous Traveler',
        'organisation': 'Demo Hotel',
        'action': 'Verify',
        'purpose': 'Checkin',
        'sharedAttributesCount': 2,
        'status': 'Approved',
        'timestamp': DateTime.now().toIso8601String(),
      };

      final model = AuditTransactionModel.fromJson(legacyJson);
      expect(model.syncStatus, equals('legacy_unverified'));
      expect(model.isLegacyUnverified, isTrue);
      expect(model.isSynced, isFalse);
    });

    test('AuditTransactionModel does NOT use James Wilson fallback in deserialization', () {
      final rawJson = {
        'auditRef': 'AUD-EMPTY-ACTOR',
        'txRef': 'TX-001',
        'actorWallet': '0x9999999999999999999999999999999999999999',
        'organisation': 'Bali Ecosystem',
        'action': 'Identity Verification',
        'purpose': 'General Verification',
        'status': 'Pending',
      };

      final model = AuditTransactionModel.fromJson(rawJson);
      expect(model.actor, equals('0x9999999999999999999999999999999999999999'));
      expect(model.actor, isNot(contains('James Wilson')));
    });

    test('AuditTransactionModel supports nullable txHash without false 0x placeholder', () {
      final rawJson = {
        'auditRef': 'AUD-NO-HASH',
        'txRef': 'TX-002',
        'status': 'Pending',
      };

      final model = AuditTransactionModel.fromJson(rawJson);
      expect(model.txHash, isNull);
    });

    test('UuidUtil generates valid RFC 4122 v4 UUID strings', () {
      final uuid = UuidUtil.generateV4();
      final uuidRegex = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
      expect(uuidRegex.hasMatch(uuid), isTrue);
    });
  });
}
