// test/milestone5_test.dart

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qrypta/src/core/config/blockchain_config.dart';
import 'package:qrypta/src/core/data/models/btid_credential_model.dart';
import 'package:qrypta/src/core/services/blockchain/verification_transaction_service.dart';
import 'package:qrypta/src/core/utils/formatters.dart';
import 'package:qrypta/src/features/transaction/logic/payment_controller.dart';
import 'package:qrypta/src/features/verification/data/policy_matrix_constants.dart';

void main() {
  group('Milestone 5 - Tourist Levy & QRIS Audit Logging Tests', () {
    test('recordLevyPaymentAudit dispatches BTID_LEVY_PAYMENT to ezsign-core and persists audit', () async {
      bool mockServerCalled = false;
      Map<String, dynamic>? dispatchedBody;

      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/verify-identity')) {
          mockServerCalled = true;
          dispatchedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'success': true,
              'status': 'ACCEPTED',
              'correlation_id': '0xlevybesutxhash448102',
            }),
            202,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final service = VerificationTransactionService(null, mockClient);

      final audit = await service.recordLevyPaymentAudit(
        levyRef: 'LVY-448102',
        txHash: '0x7b2f8a1e9c4d3b5a7e6f8a9b0c1d2e3f4a5b6c7d',
        btid: 'BTID-2026-4471-0938',
        amountFormatted: 'IDR 150,000',
        walletAddress: '0x71CB05EE1b1F506fF321Da3CE92a540AC401B4D0',
      );

      expect(mockServerCalled, isTrue);
      expect(dispatchedBody!['docType'], equals('BTID_LEVY_PAYMENT'));
      expect(dispatchedBody!['uuid'], equals('BTID-2026-4471-0938'));
      expect(dispatchedBody!['metadata']['action'], equals('Tourist Levy paid (IDR 150,000)'));
      expect(dispatchedBody!['metadata']['record'], equals('LVY-448102'));
      expect(dispatchedBody!['metadata']['result'], equals('Paid'));
      expect(dispatchedBody!['metadata']['amount'], equals('IDR 150,000'));

      expect(audit.txRef, equals('LVY-448102'));
      expect(audit.status, equals('Paid'));
      expect(audit.isPaid, isTrue);
      expect(audit.organisation, equals('Bali Tourism Authority (Bapenda)'));

      // Verifikasi tersimpan di daftar riwayat audit
      final audits = await service.getAuditTransactions();
      expect(audits.any((a) => a.txRef == 'LVY-448102'), isTrue);
    });

    test('recordQrisPaymentAudit dispatches BTID_QRIS_PAYMENT to ezsign-core with Zero-PII notice', () async {
      bool mockServerCalled = false;
      Map<String, dynamic>? dispatchedBody;

      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/verify-identity')) {
          mockServerCalled = true;
          dispatchedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'success': true,
              'status': 'ACCEPTED',
              'correlation_id': '0xqrisbesutxhash882194',
            }),
            202,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final service = VerificationTransactionService(null, mockClient);

      final audit = await service.recordQrisPaymentAudit(
        payRef: 'PAY-882194',
        txHash: '0x8821947b2f8a1e9c4d3b5a7e6f8a9b0c1d2e3f4a',
        merchantName: 'Bali Coffee House - Canggu',
        merchantId: 'MCH-3311',
        amountFormatted: 'IDR 85,000',
        walletAddress: '0x71CB05EE1b1F506fF321Da3CE92a540AC401B4D0',
        itemDescription: 'Specialty Coffee & Pastry',
      );

      expect(mockServerCalled, isTrue);
      expect(dispatchedBody!['docType'], equals('BTID_QRIS_PAYMENT'));
      expect(dispatchedBody!['metadata']['merchantId'], equals('MCH-3311'));
      expect(dispatchedBody!['metadata']['record'], equals('PAY-882194'));
      expect(dispatchedBody!['metadata']['result'], equals('Paid'));
      expect(dispatchedBody!['metadata']['privacyGuarantee'], contains('Zero personal data'));

      expect(audit.txRef, equals('PAY-882194'));
      expect(audit.status, equals('Paid'));
      expect(audit.isPaid, isTrue);
      expect(audit.organisation, equals('Bali Coffee House - Canggu'));

      final audits = await service.getAuditTransactions();
      expect(audits.any((a) => a.txRef == 'PAY-882194'), isTrue);
    });
  });

  group('Milestone 5 - Digital Levy MRZ Strip & Receipt Data Tests', () {
    test('generateMrzLine1 produces strict TD3 44-character line for levy reference', () {
      final line1 = LevyReceiptData.generateMrzLine1('LVY-448102', 150000);
      expect(line1.length, equals(44));
      expect(line1.startsWith('LEVY<<LVY<448102<<IDR150000'), isTrue);
      expect(line1.endsWith('<<<<'), isTrue);
    });

    test('generateMrzLine2 produces strict TD3 44-character line for BTID and paid status', () {
      final line2 = LevyReceiptData.generateMrzLine2('BTID-2026-4471-0938');
      expect(line2.length, equals(44));
      expect(line2.startsWith('BTID<<BTID<2026<4471<0938<<PAID'), isTrue);
      expect(line2.endsWith('<<<<'), isTrue);
    });

    test('QrisReceiptData retains zero-PII privacy guarantee by default', () {
      final qrisReceipt = QrisReceiptData(
        payRef: 'PAY-104928',
        merchantName: 'Bali Coffee House - Canggu',
        merchantId: 'MCH-3311',
        merchantAddress: '0x3311A9908F8718E237aDE73708aB59f212284bE0',
        amount: 'IDR 85,000',
        amountRaw: 85000,
        paymentMethod: 'Qrypta IDRT Wallet Balance',
        txHash: '0x3311947b2f8a1e9c4d3b5a7e6f8a9b0c1d2e3f4a',
        timestamp: DateTime.now(),
        itemDescription: 'Specialty Coffee & Pastry',
      );

      expect(qrisReceipt.privacyNotice, contains('Zero passport'));
      expect(qrisReceipt.amountRaw, equals(85000));
      expect(qrisReceipt.payRef, equals('PAY-104928'));
    });
  });

  group('Milestone 5 - Token Arithmetic & Precision Tests', () {
    test('Tourist Levy of 150,000 IDRT scales precisely to 18 decimals without IEEE 754 precision loss', () {
      final amountBigInt = parseAmountToBigInt('150000', 18);
      final expected = BigInt.from(150000) * BigInt.from(10).pow(18);
      expect(amountBigInt, equals(expected));
      expect(amountBigInt.toString(), equals('150000000000000000000000'));
    });

    test('QRIS Cafe payment of 85,000 IDRT scales precisely to 18 decimals', () {
      final amountBigInt = parseAmountToBigInt('85000', 18);
      final expected = BigInt.from(85000) * BigInt.from(10).pow(18);
      expect(amountBigInt, equals(expected));
      expect(amountBigInt.toString(), equals('85000000000000000000000'));
    });

    test('Bapenda Treasury Address is configured and valid EVM hex', () {
      final bapendaAddress = BlockchainConfig.bapendaTreasuryAddress;
      expect(bapendaAddress.startsWith('0x'), isTrue);
      expect(bapendaAddress.length, equals(42));
      expect(bapendaAddress.toLowerCase(), equals('0x3565e871c841a8ce127b0e05eb512a865f93845b'));
    });

    test('Demo merchant addresses for QRIS are configured and valid EVM hex', () {
      final cafe = demoMerchants['cafe']!;
      expect(cafe.id, equals('MCH-3311'));
      expect(cafe.walletAddress.startsWith('0x'), isTrue);
      expect(cafe.walletAddress.length, equals(42));

      final tour = demoMerchants['tour']!;
      expect(tour.id, equals('MCH-5520'));
      expect(tour.walletAddress.startsWith('0x'), isTrue);
      expect(tour.walletAddress.length, equals(42));
    });
  });

  group('Milestone 5 - BTID Credential Levy State Transitions', () {
    test('Credential starts unpaid and transitions cleanly to paid upon levy settlement', () {
      final initialCred = BtidCredentialModel(
        btidNumber: 'BTID-2026-4471-0938',
        fullName: 'James Wilson',
        nationality: 'GBR',
        passportMasked: '••••••789',
        dob: '1988-04-12',
        docExpiry: '2031-08-15',
        visaType: 'e-VOA B1',
        arrivalDate: '2026-10-15',
        stayExpiry: DateTime.now().add(const Duration(days: 28)).toIso8601String(),
        levyStatus: 'unpaid',
        walletAddress: '0x71CB05EE1b1F506fF321Da3CE92a540AC401B4D0',
        issuedAt: DateTime.now(),
      );

      expect(initialCred.isLevyPaid, isFalse);
      expect(initialCred.levyReceiptRef, isNull);

      final paidCred = initialCred.copyWith(
        levyStatus: 'paid',
        levyReceiptRef: 'LVY-448102',
      );

      expect(paidCred.isLevyPaid, isTrue);
      expect(paidCred.levyReceiptRef, equals('LVY-448102'));
      expect(paidCred.levyStatus, equals('paid'));
    });
  });
}
