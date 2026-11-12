import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qrypta/src/core/data/models/audit_transaction_model.dart';
import 'package:qrypta/src/core/data/models/btid_credential_model.dart';
import 'package:qrypta/src/core/data/models/consent_request_model.dart';
import 'package:qrypta/src/core/services/blockchain/verification_transaction_service.dart';

void main() {
  group('Milestone 2 - DTO Models Unit Tests', () {
    test('BtidCredentialModel serializes and deserializes accurately', () {
      final credential = BtidCredentialModel(
        btidNumber: 'BTID-2026-4471-0938',
        fullName: 'James Wilson',
        nationality: 'GBR',
        passportMasked: '••••••789',
        dob: '1988-04-12',
        docExpiry: '2031-08-15',
        visaType: 'e-VOA B1',
        arrivalDate: '2026-10-15',
        stayExpiry: DateTime.now().add(const Duration(days: 28)).toIso8601String(),
        levyStatus: 'paid',
        levyReceiptRef: 'LVY-448102',
        walletAddress: '0x71C67Ed3E3b326e6129b80D8dcbf3eEAE2946b29',
        issuedAt: DateTime.now(),
      );

      final json = credential.toJson();
      final parsed = BtidCredentialModel.fromJson(json);

      expect(parsed.btidNumber, equals('BTID-2026-4471-0938'));
      expect(parsed.isLevyPaid, isTrue);
      expect(parsed.daysRemaining, greaterThanOrEqualTo(27));
      expect(parsed.levyReceiptRef, equals('LVY-448102'));
    });

    test('ConsentRequestModel serializes correctly and checks expiration', () {
      final request = ConsentRequestModel(
        requestId: 'TX-448102',
        merchantId: 'MCH-1042',
        merchantName: 'Bali Ocean Resort',
        merchantCategory: 'hotel',
        staffName: 'Kadek Sari',
        staffRole: 'Front Desk Agent',
        purposeTemplate: 'hotel_checkin',
        requestedFields: ['name', 'nationality', 'id_validity', 'stay_valid'],
        retentionPolicy: 'Retained for 30 days',
        expiresAt: DateTime.now().add(const Duration(minutes: 3)),
      );

      final json = request.toJson();
      final parsed = ConsentRequestModel.fromJson(json);

      expect(parsed.requestId, equals('TX-448102'));
      expect(parsed.merchantName, equals('Bali Ocean Resort'));
      expect(parsed.requestedFields.length, equals(4));
      expect(parsed.isExpired, isFalse);
    });

    test('AuditTransactionModel tracks states correctly', () {
      final audit = AuditTransactionModel(
        auditRef: 'AUD-883192',
        txRef: 'TX-448102',
        txHash: '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
        actor: 'James Wilson',
        organisation: 'Bali Ocean Resort',
        action: 'Identity shared with merchant',
        purpose: 'hotel_checkin',
        sharedAttributesCount: 4,
        status: 'Approved',
        timestamp: DateTime.now(),
      );

      expect(audit.isApproved, isTrue);
      expect(audit.isPaid, isFalse);
      expect(audit.isRevoked, isFalse);

      final revoked = audit.copyWith(status: 'Revoked');
      expect(revoked.isRevoked, isTrue);
      expect(revoked.isApproved, isFalse);
    });
  });

  group('Milestone 2 - VerificationTransactionService Cryptography & Workflows', () {
    // Standard test private key for EVM (32 bytes hex)
    const testPrivateKey = '4c0883a69102937d6231471b3dbb6832dbca04a98113a19e6fd4f263402d6aec';

    test('generateDynamicQrToken outputs valid 45-second ephemeral JSON token', () {
      final service = VerificationTransactionService();
      final qrString = service.generateDynamicQrToken(
        'BTID-2026-4471-0938',
        '0x71C67Ed3E3b326e6129b80D8dcbf3eEAE2946b29',
        validitySeconds: 45,
      );

      final decoded = jsonDecode(qrString) as Map<String, dynamic>;
      expect(decoded.containsKey('token'), isTrue);
      expect(decoded['token'].toString().startsWith('QRT-'), isTrue);
      expect(decoded['btid'], equals('BTID-2026-4471-0938'));
      expect(decoded['wallet'], equals('0x71C67Ed3E3b326e6129b80D8dcbf3eEAE2946b29'));

      final exp = decoded['exp'] as int;
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      expect(exp - nowSec, inInclusiveRange(43, 46));
    });

    test('signAndSubmitConsent produces valid EVM signature and dispatches to Fastify', () async {
      bool mockServerCalled = false;
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/verify-identity')) {
          mockServerCalled = true;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['client_type'], equals('web3'));
          expect(body['docType'], equals('BTID_CONSENT'));
          expect(body['signature'].toString().startsWith('0x'), isTrue);
          expect(body['metadata']['purpose'], equals('hotel_checkin'));
          expect(body['metadata']['record'], equals('TX-448102'));

          return http.Response(
            jsonEncode({
              'success': true,
              'status': 'ACCEPTED',
              'correlation_id': '0xmockedbesutransactionhash1234567890abcdef',
            }),
            202,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final service = VerificationTransactionService(null, mockClient);

      final consentRequest = ConsentRequestModel(
        requestId: 'TX-448102',
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

      final approvedData = {
        'btid': 'BTID-2026-4471-0938',
        'fullName': 'James Wilson',
        'nationality': 'GBR',
      };

      final audit = await service.signAndSubmitConsent(
        privateKeyHex: testPrivateKey,
        request: consentRequest,
        approvedData: approvedData,
        isApproved: true,
      );

      expect(mockServerCalled, isTrue);
      expect(audit.status, equals('Approved'));
      expect(audit.txRef, equals('TX-448102'));
      expect(audit.receiptSignature != null, isTrue);
      expect(audit.receiptSignature!.startsWith('0x'), isTrue);

      final history = await service.getAuditTransactions();
      expect(history.any((a) => a.txRef == 'TX-448102'), isTrue);
    });

    test('revokeMerchantAccess successfully marks audit record as Revoked', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'success': true, 'status': 'ACCEPTED'}),
          202,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = VerificationTransactionService(null, mockClient);

      final revokedAudit = await service.revokeMerchantAccess(
        privateKeyHex: testPrivateKey,
        txRef: 'TX-448102',
        merchantId: 'MCH-1042',
        btid: 'BTID-2026-4471-0938',
        merchantName: 'Bali Ocean Resort',
      );

      expect(revokedAudit.isRevoked, isTrue);
      expect(revokedAudit.status, equals('Revoked'));
      expect(revokedAudit.receiptSignature != null, isTrue);

      final history = await service.getAuditTransactions();
      expect(history.first.status, equals('Revoked'));
    });
  });
}
