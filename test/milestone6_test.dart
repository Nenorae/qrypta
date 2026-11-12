// test/milestone6_test.dart

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qrypta/src/core/config/blockchain_config.dart';
import 'package:qrypta/src/core/data/models/btid_credential_model.dart';
import 'package:qrypta/src/core/data/models/consent_request_model.dart';
import 'package:qrypta/src/core/services/blockchain/verification_transaction_service.dart';
import 'package:qrypta/src/core/utils/formatters.dart';
import 'package:qrypta/src/core/utils/mrz_parser.dart';
import 'package:qrypta/src/features/home/logic/home_controller.dart';
import 'package:qrypta/src/features/transaction/logic/payment_controller.dart';
import 'package:qrypta/src/features/verification/data/policy_matrix_constants.dart';

void main() {
  group('Milestone 6 - End-to-End System Integration Tests', () {
    const testPrivateKey = '4c0883a69102937d6231471b3dbb6832dbca04a98113a19e6fd4f263402d6aec';

    test('Full Lifecycle: Onboarding -> Levy Payment -> Selective Disclosure -> Revocation -> QRIS', () async {
      final List<String> dispatchedDocTypes = [];

      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/verify-identity')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          dispatchedDocTypes.add(body['docType'] as String);
          return http.Response(
            jsonEncode({
              'success': true,
              'status': 'ACCEPTED',
              'correlation_id': '0xbesu_e2e_tx_hash_${dispatchedDocTypes.length}',
            }),
            202,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final verificationService = VerificationTransactionService(null, mockClient);

      // --- STEP 1: Onboarding Paspor (OCR MRZ TD3) ---
      const line1 = 'P<GBRWILSON<<JAMES<<<<<<<<<<<<<<<<<<<<<<<<<<';
      const line2 = '7249187895GBR8805120M3203189<<<<<<<<<<<<<<02';
      final mrzResult = MrzParser.parse(line1, line2);
      expect(mrzResult.isValid, isTrue);
      expect(mrzResult.fullName, equals('JAMES WILSON'));
      expect(mrzResult.passportNumber, equals('724918789'));

      // Issuance Audit to ezsign-core
      await verificationService.recordCredentialIssuedAudit(
        btid: 'BTID-2026-4471-0938',
        fullName: mrzResult.fullName,
        walletAddress: '0x71CB05EE1b1F506fF321Da3CE92a540AC401B4D0',
      );
      expect(dispatchedDocTypes.contains('BTID_ISSUED'), isTrue);

      var credential = BtidCredentialModel(
        btidNumber: 'BTID-2026-4471-0938',
        fullName: mrzResult.fullName,
        nationality: mrzResult.nationality,
        passportMasked: '••••••789',
        dob: mrzResult.birthDateFormatted,
        docExpiry: mrzResult.expiryDateFormatted,
        visaType: 'e-VOA B1',
        arrivalDate: '2026-10-15',
        stayExpiry: DateTime.now().add(const Duration(days: 28)).toIso8601String(),
        levyStatus: 'unpaid',
        walletAddress: '0x71CB05EE1b1F506fF321Da3CE92a540AC401B4D0',
        issuedAt: DateTime.now(),
      );
      expect(credential.isLevyPaid, isFalse);

      // --- STEP 2: Pembayaran Tourist Levy Rp 150.000 IDRT ---
      final levyAmountBigInt = parseAmountToBigInt('150000', 18);
      expect(levyAmountBigInt, equals(BigInt.from(150000) * BigInt.from(10).pow(18)));

      final levyAudit = await verificationService.recordLevyPaymentAudit(
        levyRef: 'LVY-448102',
        txHash: '0x7b2f8a1e9c4d3b5a7e6f8a9b0c1d2e3f4a5b6c7d',
        btid: credential.btidNumber,
        amountFormatted: 'IDR 150,000',
        walletAddress: credential.walletAddress,
      );
      expect(levyAudit.status, equals('Paid'));
      expect(dispatchedDocTypes.contains('BTID_LEVY_PAYMENT'), isTrue);

      // Mutasi State Kredensial Menjadi Paid
      credential = credential.copyWith(levyStatus: 'paid', levyReceiptRef: 'LVY-448102');
      expect(credential.isLevyPaid, isTrue);

      // Validasi MRZ Retribusi TD3 44 Karakter
      final mrzLine1 = LevyReceiptData.generateMrzLine1('LVY-448102', 150000);
      final mrzLine2 = LevyReceiptData.generateMrzLine2(credential.btidNumber);
      expect(mrzLine1.length, equals(44));
      expect(mrzLine2.length, equals(44));

      // --- STEP 3: Dynamic QR 45 Detik Generation ---
      final qrJson = verificationService.generateDynamicQrToken(
        credential.btidNumber,
        credential.walletAddress,
        validitySeconds: 45,
      );
      final qrDecoded = jsonDecode(qrJson) as Map<String, dynamic>;
      expect(qrDecoded['btid'], equals('BTID-2026-4471-0938'));
      expect(qrDecoded['token'].toString().startsWith('QRT-'), isTrue);

      // --- STEP 4: Selective Disclosure Handshake (Hotel Check-in) ---
      final hotelRequest = ConsentRequestModel(
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

      final consentAudit = await verificationService.signAndSubmitConsent(
        privateKeyHex: testPrivateKey,
        request: hotelRequest,
        approvedData: {
          'btid': credential.btidNumber,
          'fullName': credential.fullName,
          'name': credential.fullName,
          'nationality': credential.nationality,
          'levy_status': 'Paid (LVY-448102)',
        },
        isApproved: true,
      );
      expect(dispatchedDocTypes.contains('BTID_CONSENT'), isTrue);
      expect(consentAudit.isApproved, isTrue);
      expect(consentAudit.txRef, equals('TX-448102'));

      // --- STEP 5: Pencabutan Hak Akses (Stop Future Access / Revoke) ---
      final revokeAudit = await verificationService.revokeMerchantAccess(
        privateKeyHex: testPrivateKey,
        txRef: 'TX-448102',
        merchantId: 'MCH-1042',
        btid: credential.btidNumber,
        merchantName: 'Bali Ocean Resort',
      );
      expect(dispatchedDocTypes.contains('BTID_REVOKE'), isTrue);
      expect(revokeAudit.status, equals('Revoked'));
      expect(revokeAudit.isRevoked, isTrue);

      // --- STEP 6: Pembayaran Merchant QRIS IDR 85.000 (Zero-PII) ---
      final qrisAmountBigInt = parseAmountToBigInt('85000', 18);
      expect(qrisAmountBigInt, equals(BigInt.from(85000) * BigInt.from(10).pow(18)));

      final qrisAudit = await verificationService.recordQrisPaymentAudit(
        payRef: 'PAY-882194',
        txHash: '0x8821947b2f8a1e9c4d3b5a7e6f8a9b0c1d2e3f4a',
        merchantName: 'Bali Coffee House - Canggu',
        merchantId: 'MCH-3311',
        amountFormatted: 'IDR 85,000',
        walletAddress: credential.walletAddress,
        itemDescription: 'Specialty Coffee & Pastry',
      );
      expect(dispatchedDocTypes.contains('BTID_QRIS_PAYMENT'), isTrue);
      expect(qrisAudit.status, equals('Paid'));

      // Verifikasi seluruh riwayat audit tercatat (4 entri unik, dengan TX-448102 berstatus Revoked)
      final allAudits = await verificationService.getAuditTransactions();
      expect(allAudits.length, equals(4));
      final revokedRecord = allAudits.firstWhere((a) => a.txRef == 'TX-448102');
      expect(revokedRecord.status, equals('Revoked'));
      expect(revokedRecord.isRevoked, isTrue);

      // Verifikasi 5 docTypes unik dikirimkan ke middleware ezsign-core
      expect(dispatchedDocTypes, containsAll([
        'BTID_ISSUED',
        'BTID_LEVY_PAYMENT',
        'BTID_CONSENT',
        'BTID_REVOKE',
        'BTID_QRIS_PAYMENT',
      ]));
    });
  });

  group('Milestone 6 - Dashboard 5-Tab Navigation State Tests', () {
    test('HomeController properly handles 5-tab indexing', () {
      final controller = HomeController();
      expect(controller.selectedIndex, equals(0));

      controller.setSelectedIndex(1);
      expect(controller.selectedIndex, equals(1)); // Pay

      controller.setSelectedIndex(2);
      expect(controller.selectedIndex, equals(2)); // ID

      controller.setSelectedIndex(3);
      expect(controller.selectedIndex, equals(3)); // Explore

      controller.setSelectedIndex(4);
      expect(controller.selectedIndex, equals(4)); // Profile
    });

    test('Explore tab ecosystem merchants contain exactly 5 official partners', () {
      expect(demoMerchants.length, equals(5));
      expect(demoMerchants.containsKey('hotel'), isTrue);
      expect(demoMerchants.containsKey('car'), isTrue);
      expect(demoMerchants.containsKey('cafe'), isTrue);
      expect(demoMerchants.containsKey('esim'), isTrue);
      expect(demoMerchants.containsKey('tour'), isTrue);

      final hotel = demoMerchants['hotel']!;
      expect(hotel.name, equals('Bali Ocean Resort'));
      expect(hotel.defaultTemplate, equals('hotel_checkin'));
      expect(hotel.walletAddress.startsWith('0x'), isTrue);
    });

    test('System policy matrix permanently locks biometric sharing across all 5 merchant categories', () {
      for (final category in ['hotel', 'car', 'cafe', 'esim', 'tour']) {
        final policy = defaultPolicy[category];
        expect(policy, isNotNull);
        expect(policy!['biometric'], equals('prohibited'),
            reason: 'Biometric face embedding must NEVER be allowed for category $category');
      }
    });

    test('BlockchainConfig points to dynamic environment or verified defaults', () {
      expect(BlockchainConfig.rpcUrl, isNotEmpty);
      expect(BlockchainConfig.ezsignApiUrl, contains('/api/v1'));
      expect(BlockchainConfig.bapendaTreasuryAddress, equals('0x3565E871c841A8cE127B0e05Eb512a865F93845B'));
    });
  });
}
