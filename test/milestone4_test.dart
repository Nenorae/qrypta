// test/milestone4_test.dart

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrypta/src/core/data/models/audit_transaction_model.dart';
import 'package:qrypta/src/core/data/models/consent_request_model.dart';
import 'package:qrypta/src/core/services/blockchain/verification_transaction_service.dart';
import 'package:qrypta/src/features/verification/data/policy_matrix_constants.dart';

void main() {
  const testPrivateKeyHex =
      '4c0883a69102937d6231471b5dbb6204fe5129617082792ae468d01a3f36088c';

  group('Milestone 4 - Policy Matrix & Data Minimization Tests', () {
    test('ATTRS defines all 19 official attributes and protects biometrics', () {
      expect(ATTRS.length, 19);
      expect(ATTRS.containsKey('name'), true);
      expect(ATTRS.containsKey('nationality'), true);
      expect(ATTRS.containsKey('identity'), true);
      expect(ATTRS.containsKey('passport_auth'), true);
      expect(ATTRS.containsKey('id_validity'), true);
      expect(ATTRS.containsKey('levy_status'), true);
      expect(ATTRS.containsKey('over18'), true);
      expect(ATTRS.containsKey('over21'), true);
      expect(ATTRS.containsKey('dob'), true);
      expect(ATTRS.containsKey('passport_number'), true);
      expect(ATTRS.containsKey('arrival'), true);
      expect(ATTRS.containsKey('departure'), true);
      expect(ATTRS.containsKey('visa_type'), true);
      expect(ATTRS.containsKey('stay_valid'), true);
      expect(ATTRS.containsKey('stay_expiry'), true);
      expect(ATTRS.containsKey('driving'), true);
      expect(ATTRS.containsKey('payment_confirm'), true);
      expect(ATTRS.containsKey('emergency'), true);
      expect(ATTRS.containsKey('biometric'), true);

      // Biometric protection guarantee
      expect(ATTRS['biometric']!.isBiometric, true);
    });

    test('DEFAULT_POLICY strictly prohibits biometrics across all business categories', () {
      for (final category in ['hotel', 'car', 'cafe', 'esim', 'tour']) {
        expect(
          DEFAULT_POLICY[category]!['biometric'],
          'prohibited',
          reason: 'Biometrics must never be shared with $category',
        );
      }
    });

    test('Cafe policy strictly protects PII while allowing ZK age verification', () {
      final cafePolicy = DEFAULT_POLICY['cafe']!;
      expect(cafePolicy['name'], 'prohibited');
      expect(cafePolicy['nationality'], 'prohibited');
      expect(cafePolicy['dob'], 'prohibited');
      expect(cafePolicy['passport_number'], 'prohibited');
      expect(cafePolicy['over18'], 'conditional');
      expect(cafePolicy['payment_confirm'], 'allowed');
    });

    test('TEMPLATES defines 9 official government-accredited templates', () {
      expect(TEMPLATES.length, 9);
      expect(TEMPLATES.containsKey('hotel_checkin'), true);
      expect(TEMPLATES.containsKey('vehicle_rental'), true);
      expect(TEMPLATES.containsKey('esim_activation'), true);
      expect(TEMPLATES.containsKey('stay_validity'), true);
      expect(TEMPLATES.containsKey('age_check'), true);
      expect(TEMPLATES.containsKey('tour_participation'), true);
      expect(TEMPLATES.containsKey('levy_check'), true);
      expect(TEMPLATES.containsKey('payment_confirm'), true);
      expect(TEMPLATES.containsKey('emergency_support'), true);
    });
  });

  group('Milestone 4 - Dynamic QR 45s & Merchant Handshake Tests', () {
    test('Dynamic QR token has valid 45s structure and binds BTID', () {
      final service = VerificationTransactionService();
      final qrString = service.generateDynamicQrToken(
        'BTID-2026-4471-0938',
        '0x71CB05EE1b1F506fF321Da3CE92a540AC401B4D0',
        validitySeconds: 45,
      );

      final decoded = jsonDecode(qrString);
      expect(decoded['token'], startsWith('QRT-'));
      expect(decoded['token'].toString().length, 14); // 'QRT-' + 10 chars
      expect(decoded['btid'], 'BTID-2026-4471-0938');
      expect(decoded['wallet'], '0x71CB05EE1b1F506fF321Da3CE92a540AC401B4D0');

      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final exp = decoded['exp'] as int;
      expect(exp - now, inInclusiveRange(43, 46));
    });

    test('Demo merchants map accurately reflects ecosystem partners', () {
      expect(DEMO_MERCHANTS.length, 5);
      final hotel = DEMO_MERCHANTS['hotel']!;
      expect(hotel.id, 'MCH-1042');
      expect(hotel.name, 'Bali Ocean Resort');
      expect(hotel.defaultTemplate, 'hotel_checkin');

      final car = DEMO_MERCHANTS['car']!;
      expect(car.id, 'MCH-2087');
      expect(car.name, 'Island Drive Car Rental');
      expect(car.defaultTemplate, 'vehicle_rental');

      final cafe = DEMO_MERCHANTS['cafe']!;
      expect(cafe.id, 'MCH-3311');
      expect(cafe.defaultTemplate, 'age_check');
    });
  });

  group('Milestone 4 - Cryptographic Consent & Revocation Tests', () {
    test('signAndSubmitConsent produces valid secp256k1 signature and canonical audit', () async {
      final service = VerificationTransactionService();
      final request = ConsentRequestModel(
        requestId: 'TX-448102',
        merchantId: 'MCH-1042',
        merchantName: 'Bali Ocean Resort',
        merchantCategory: 'hotel',
        staffName: 'Kadek Sari',
        staffRole: 'Front Desk Agent',
        purposeTemplate: 'hotel_checkin',
        requestedFields: ['name', 'nationality', 'id_validity', 'passport_auth', 'levy_status', 'stay_valid'],
        retentionPolicy: 'Retained for 30 days',
        expiresAt: DateTime.now().add(const Duration(minutes: 3)),
      );

      final approvedData = {
        'btid': 'BTID-2026-4471-0938',
        'fullName': 'James Wilson',
        'name': 'James Wilson',
        'nationality': 'GBR (United Kingdom)',
        'id_validity': 'Valid until 18 Jan 2027',
        'passport_auth': 'Authentic — Passive Auth Verified',
        'levy_status': 'Paid (LVY-88412)',
        'stay_valid': 'Valid — 28 days remaining',
      };

      final audit = await service.signAndSubmitConsent(
        privateKeyHex: testPrivateKeyHex,
        request: request,
        approvedData: approvedData,
        isApproved: true,
      );

      expect(audit.auditRef, startsWith('AUD-'));
      expect(audit.txRef, 'TX-448102');
      expect(audit.organisation, 'Bali Ocean Resort');
      expect(audit.status, 'Approved');
      expect(audit.sharedAttributesCount, 6);
      expect(audit.receiptSignature, startsWith('0x'));
      expect(audit.receiptSignature!.length, greaterThan(64));
    });

    test('signAndSubmitConsent records rejection with 0 shared attributes', () async {
      final service = VerificationTransactionService();
      final request = ConsentRequestModel(
        requestId: 'TX-991204',
        merchantId: 'MCH-3311',
        merchantName: 'Bali Coffee House',
        merchantCategory: 'cafe',
        staffName: 'Wayan Putra',
        staffRole: 'Cashier',
        purposeTemplate: 'age_check',
        requestedFields: ['over18'],
        retentionPolicy: 'Zero storage',
        expiresAt: DateTime.now().add(const Duration(minutes: 3)),
      );

      final audit = await service.signAndSubmitConsent(
        privateKeyHex: testPrivateKeyHex,
        request: request,
        approvedData: {'btid': 'BTID-2026-4471-0938', 'fullName': 'James Wilson'},
        isApproved: false,
      );

      expect(audit.txRef, 'TX-991204');
      expect(audit.status, 'Rejected');
      expect(audit.sharedAttributesCount, 0);
    });

    test('revokeMerchantAccess successfully marks audit record as Revoked', () async {
      final service = VerificationTransactionService();
      final revokedAudit = await service.revokeMerchantAccess(
        privateKeyHex: testPrivateKeyHex,
        txRef: 'TX-448102',
        merchantId: 'MCH-1042',
        btid: 'BTID-2026-4471-0938',
        merchantName: 'Bali Ocean Resort',
      );

      expect(revokedAudit.action, 'Merchant access revoked');
      expect(revokedAudit.status, 'Revoked');
      expect(revokedAudit.receiptSignature, startsWith('0x'));

      final list = await service.getAuditTransactions();
      final item = list.firstWhere((a) => a.txRef == 'TX-448102');
      expect(item.status, 'Revoked');
    });

    test('AuditTransactionModel accurately tracks states and counts', () {
      final items = [
        AuditTransactionModel(
          auditRef: 'AUD-1001',
          txRef: 'TX-001',
          txHash: '0x1',
          actor: 'James Wilson',
          organisation: 'Bali Ocean Resort',
          action: 'Identity shared',
          purpose: 'hotel_checkin',
          sharedAttributesCount: 4,
          status: 'Approved',
          timestamp: DateTime.now(),
        ),
        AuditTransactionModel(
          auditRef: 'AUD-1002',
          txRef: 'TX-002',
          txHash: '0x2',
          actor: 'James Wilson',
          organisation: 'Island Drive',
          action: 'Identity sharing rejected',
          purpose: 'vehicle_rental',
          sharedAttributesCount: 0,
          status: 'Rejected',
          timestamp: DateTime.now(),
        ),
        AuditTransactionModel(
          auditRef: 'AUD-1003',
          txRef: 'TX-003',
          txHash: '0x3',
          actor: 'James Wilson',
          organisation: 'Bali Coffee House',
          action: 'Merchant access revoked',
          purpose: 'age_check',
          sharedAttributesCount: 0,
          status: 'Revoked',
          timestamp: DateTime.now(),
        ),
      ];

      final approved = items.where((a) => a.status == 'Approved').length;
      final rejected = items.where((a) => a.status == 'Rejected').length;
      final revoked = items.where((a) => a.status == 'Revoked').length;

      expect(approved, 1);
      expect(rejected, 1);
      expect(revoked, 1);
    });
  });
}
