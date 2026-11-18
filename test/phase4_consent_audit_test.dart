// test/phase4_consent_audit_test.dart

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:qrypta/src/core/data/models/actor_ref.dart';
import 'package:qrypta/src/core/data/models/consent_request_model.dart';
import 'package:qrypta/src/core/error/app_failure.dart';
import 'package:qrypta/src/core/outbox/outbox_item.dart';
import 'package:qrypta/src/core/outbox/outbox_repository.dart';
import 'package:qrypta/src/core/outbox/outbox_worker.dart';
import 'package:qrypta/src/core/services/blockchain/verification_transaction_service.dart';

void main() {
  const testPrivateKeyHex =
      '4c0883a69102937d6231471b5dbb6204fe5129617082792ae468d01a3f36088c';

  final testConsentRequest = ConsentRequestModel(
    requestId: 'TX-REQ-448102',
    merchantId: 'MCH-1042',
    merchantName: 'Bali Ocean Resort',
    merchantCategory: 'hotel',
    staffName: 'Kadek Sari',
    staffRole: 'Front Desk Agent',
    purposeTemplate: 'hotel_checkin',
    requestedFields: ['name', 'nationality', 'id_validity'],
    retentionPolicy: 'Retained for 30 days',
    expiresAt: DateTime.now().add(const Duration(minutes: 3)),
  );

  group('Phase 4.1: Consent Submission & Anti-Fake Fallback (F-05)', () {
    test('Throws AppFailure when server Fastify 500 and does NOT record Approved', () async {
      final mockClient = http_testing.MockClient((req) async {
        return http.Response(
          jsonEncode({'error': 'Internal server error in Fastify middleware'}),
          500,
          headers: {'content-type': 'application/json'},
        );
      });

      final outboxRepo = OutboxRepository();
      final service = VerificationTransactionService(null, mockClient, outboxRepo);

      final approvedData = {
        'btid': 'BTID-2026-9901-1122',
        'fullName': 'Wayfarer Traveler',
        'walletAddress': '0x71CB05EE1b1F506fF321Da3CE92a540AC401B4D0',
      };

      expect(
        () => service.signAndSubmitConsent(
          privateKeyHex: testPrivateKeyHex,
          request: testConsentRequest,
          approvedData: approvedData,
          isApproved: true,
        ),
        throwsA(isA<ServerRejected>()),
      );

      final audits = await service.getAuditTransactions();
      expect(audits.any((a) => a.txRef == 'TX-REQ-448102'), isFalse);
    });

    test('Throws NetworkUnreachable when server is completely down on approval', () async {
      final mockClient = http_testing.MockClient((req) async {
        throw http.ClientException('Connection refused');
      });

      final outboxRepo = OutboxRepository();
      final service = VerificationTransactionService(null, mockClient, outboxRepo);

      final approvedData = {
        'btid': 'BTID-2026-9901-1122',
        'fullName': 'Wayfarer Traveler',
        'walletAddress': '0x71CB05EE1b1F506fF321Da3CE92a540AC401B4D0',
      };

      expect(
        () => service.signAndSubmitConsent(
          privateKeyHex: testPrivateKeyHex,
          request: testConsentRequest,
          approvedData: approvedData,
          isApproved: true,
        ),
        throwsA(isA<NetworkUnreachable>()),
      );
    });

    test('Records Approved with syncStatus synced when Fastify returns 202', () async {
      String? receivedIdempotencyKey;
      Map<String, dynamic>? receivedBody;

      final mockClient = http_testing.MockClient((req) async {
        receivedIdempotencyKey = req.headers['Idempotency-Key'];
        receivedBody = jsonDecode(req.body);
        return http.Response(
          jsonEncode({
            'success': true,
            'status': 'ACCEPTED',
            'correlation_id': 'SRV-CONSENT-CORR-123',
            'data': {'txHash': '0xabc1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef'},
          }),
          202,
          headers: {'content-type': 'application/json'},
        );
      });

      final outboxRepo = OutboxRepository();
      final service = VerificationTransactionService(null, mockClient, outboxRepo);

      final approvedData = {
        'btid': 'BTID-2026-9901-1122',
        'fullName': 'Wayfarer Traveler',
        'walletAddress': '0x71CB05EE1b1F506fF321Da3CE92a540AC401B4D0',
      };

      final audit = await service.signAndSubmitConsent(
        privateKeyHex: testPrivateKeyHex,
        request: testConsentRequest,
        approvedData: approvedData,
        isApproved: true,
      );

      expect(receivedIdempotencyKey, isNotNull);
      expect(receivedBody?['docType'], equals('BTID_CONSENT'));
      expect(audit.status, equals('Approved'));
      expect(audit.syncStatus, equals('synced'));
      expect(audit.isSynced, isTrue);
      expect(audit.serverId, equals('SRV-CONSENT-CORR-123'));
      expect(audit.txHash, startsWith('0xabc123'));
    });

    test('Queues rejection in Outbox with pending_sync when offline', () async {
      final mockClient = http_testing.MockClient((req) async {
        throw http.ClientException('Network down');
      });

      final outboxRepo = OutboxRepository();
      final service = VerificationTransactionService(null, mockClient, outboxRepo);

      final approvedData = {
        'btid': 'BTID-2026-9901-1122',
        'fullName': 'Wayfarer Traveler',
        'walletAddress': '0x71CB05EE1b1F506fF321Da3CE92a540AC401B4D0',
      };

      final audit = await service.signAndSubmitConsent(
        privateKeyHex: testPrivateKeyHex,
        request: testConsentRequest,
        approvedData: approvedData,
        isApproved: false,
      );

      expect(audit.status, equals('Rejected'));
      expect(audit.syncStatus, equals('pending_sync'));
      expect(audit.isPendingSync, isTrue);

      final pendingItems = await outboxRepo.getAllItems();
      expect(pendingItems.any((it) => it.type == 'audit_consent'), isTrue);
    });
  });

  group('Phase 4.2: Revocation & Security Outbox (F-06)', () {
    test('Successful revocation marks record Revoked and synced', () async {
      final mockClient = http_testing.MockClient((req) async {
        return http.Response(
          jsonEncode({
            'success': true,
            'correlation_id': 'SRV-REVOKE-881',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final outboxRepo = OutboxRepository();
      final service = VerificationTransactionService(null, mockClient, outboxRepo);

      final audit = await service.revokeMerchantAccess(
        privateKeyHex: testPrivateKeyHex,
        txRef: 'TX-REQ-448102',
        merchantId: 'MCH-1042',
        btid: 'BTID-2026-9901-1122',
        merchantName: 'Bali Ocean Resort',
      );

      expect(audit.status, equals('Revoked'));
      expect(audit.syncStatus, equals('synced'));
      expect(audit.serverId, equals('SRV-REVOKE-881'));
      expect(audit.lastError, isNull);
    });

    test('Failed revocation queues in Outbox with clear merchant access warning', () async {
      final mockClient = http_testing.MockClient((req) async {
        throw http.ClientException('Connection timeout');
      });

      final outboxRepo = OutboxRepository();
      final service = VerificationTransactionService(null, mockClient, outboxRepo);

      final audit = await service.revokeMerchantAccess(
        privateKeyHex: testPrivateKeyHex,
        txRef: 'TX-REQ-448102',
        merchantId: 'MCH-1042',
        btid: 'BTID-2026-9901-1122',
        merchantName: 'Bali Ocean Resort',
      );

      expect(audit.status, equals('Revoked'));
      expect(audit.syncStatus, equals('pending_sync'));
      expect(audit.lastError, contains('Pencabutan belum terkirim ke server'));

      final items = await outboxRepo.getAllItems();
      expect(items.any((it) => it.type == 'audit_revocation'), isTrue);
    });
  });

  group('Phase 4.3: Financial Audit Persistence via Outbox (F-07)', () {
    test('recordLevyPaymentAudit queues in Outbox with pending_sync when server offline', () async {
      final mockClient = http_testing.MockClient((req) async {
        throw http.ClientException('Server 503');
      });

      final outboxRepo = OutboxRepository();
      final service = VerificationTransactionService(null, mockClient, outboxRepo);

      final audit = await service.recordLevyPaymentAudit(
        levyRef: 'LVY-998877',
        txHash: '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
        btid: 'BTID-2026-9901-1122',
        amountFormatted: 'IDR 150,000',
        walletAddress: '0x71CB05EE1b1F506fF321Da3CE92a540AC401B4D0',
      );

      expect(audit.status, equals('Paid'));
      expect(audit.syncStatus, equals('pending_sync'));
      expect(audit.txHash, equals('0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef'));

      final outboxItems = await outboxRepo.getAllItems();
      expect(outboxItems.any((it) => it.type == 'audit_levy'), isTrue);
    });

    test('recordQrisPaymentAudit queues in Outbox with pending_sync when server offline', () async {
      final mockClient = http_testing.MockClient((req) async {
        return http.Response('Service Unavailable', 503);
      });

      final outboxRepo = OutboxRepository();
      final service = VerificationTransactionService(null, mockClient, outboxRepo);

      final audit = await service.recordQrisPaymentAudit(
        payRef: 'QRIS-554433',
        txHash: '0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
        merchantName: 'Bali Organic Cafe',
        merchantId: 'MCH-9901',
        amountFormatted: 'IDR 85,000',
        walletAddress: '0x71CB05EE1b1F506fF321Da3CE92a540AC401B4D0',
      );

      expect(audit.status, equals('Paid'));
      expect(audit.syncStatus, equals('pending_sync'));

      final outboxItems = await outboxRepo.getAllItems();
      expect(outboxItems.any((it) => it.type == 'audit_qris'), isTrue);
    });
  });

  group('Phase 4.4: ActorRef Sanitization & Zero-PII Privacy (D-8 / F-12)', () {
    test('ActorRef generates salted anonymous hash without plaintext PII in audit ref', () {
      final actor = ActorRef.fromCredential(
        walletAddress: '0x71CB05EE1b1F506fF321Da3CE92a540AC401B4D0',
        btidNumber: 'BTID-2026-9901-1122',
        name: 'Sarah Connor',
      );

      expect(actor.actorRef, startsWith('0x'));
      expect(actor.actorRef.length, equals(18)); // 0x + 16 hex chars
      expect(actor.actorRef.contains('Sarah'), isFalse);
      expect(actor.actorRef.contains('BTID'), isFalse);
    });

    test('Throws ValidationFailure when BTID or Name is empty in consent', () async {
      final service = VerificationTransactionService();

      expect(
        () => service.signAndSubmitConsent(
          privateKeyHex: testPrivateKeyHex,
          request: testConsentRequest,
          approvedData: {'btid': '', 'fullName': 'Tourist'},
          isApproved: true,
        ),
        throwsA(isA<ValidationFailure>()),
      );

      expect(
        () => service.signAndSubmitConsent(
          privateKeyHex: testPrivateKeyHex,
          request: testConsentRequest,
          approvedData: {'btid': 'BTID-001', 'fullName': ''},
          isApproved: true,
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('Throws ValidationFailure when BTID is empty in revoke', () async {
      final service = VerificationTransactionService();

      expect(
        () => service.revokeMerchantAccess(
          privateKeyHex: testPrivateKeyHex,
          txRef: 'TX-001',
          merchantId: 'MCH-001',
          btid: '',
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });
  });

  group('Phase 4.5: Outbox Worker & Re-sync Integration', () {
    test('OutboxWorker processes pending revocation queue and transitions to sent', () async {
      final outboxRepo = OutboxRepository();
      final mockClient = http_testing.MockClient((req) async {
        return http.Response(
          jsonEncode({'success': true, 'correlation_id': 'SRV-OUTBOX-ACK'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final worker = OutboxWorker(
        repository: outboxRepo,
        client: mockClient,
        baseUrl: 'https://staging.ezsign.qrypta.id',
      );

      final item = OutboxItem(
        id: 'outbox-item-test-1',
        type: 'audit_revocation',
        endpoint: '/verify-identity',
        payload: {'btid': 'BTID-001', 'action': 'REVOKE_ACCESS'},
        nextAttemptAt: DateTime.now().subtract(const Duration(seconds: 1)),
        createdAt: DateTime.now(),
      );
      await outboxRepo.enqueue(item);

      final processed = await worker.processPendingQueue();
      expect(processed, equals(1));

      final updated = await outboxRepo.getItemById('outbox-item-test-1');
      expect(updated?.status, equals(OutboxStatus.sent));
      expect(updated?.sentAt, isNotNull);
    });
  });
}
