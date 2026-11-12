// test/milestone3_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:qrypta/src/core/data/models/btid_credential_model.dart';
import 'package:qrypta/src/core/services/blockchain/verification_transaction_service.dart';
import 'package:qrypta/src/core/utils/mrz_parser.dart';

void main() {
  group('Milestone 3 - MRZ TD3 Checksum & Parser Unit Tests', () {
    test('computeCheckDigit correctly computes weighted 7-3-1 modulo 10', () {
      // Test cases from ICAO Doc 9303 Part 9 & 10
      expect(MrzParser.computeCheckDigit('<'), 0);
      expect(MrzParser.computeCheckDigit('0'), 0);
      expect(MrzParser.computeCheckDigit('1'), 7); // 1 * 7 = 7 % 10 = 7
      // '724918789' with weights [7, 3, 1]:
      // 7*7 + 2*3 + 4*1 + 9*7 + 1*3 + 8*1 + 7*7 + 8*3 + 9*1 = 49+6+4+63+3+8+49+24+9 = 215 % 10 = 5
      expect(MrzParser.computeCheckDigit('724918789'), 5);
      // '880512' with weights [7, 3, 1]:
      // 8*7 + 8*3 + 0*1 + 5*7 + 1*3 + 2*1 = 56+24+0+35+3+2 = 120 % 10 = 0
      expect(MrzParser.computeCheckDigit('880512'), 0);
      // '320318' with weights [7, 3, 1]:
      // 3*7 + 2*3 + 0*1 + 3*7 + 1*3 + 8*1 = 21+6+0+21+3+8 = 59 % 10 = 9
      expect(MrzParser.computeCheckDigit('320318'), 9);
    });

    test('MrzParser correctly parses James Wilson TD3 passport lines and validates', () {
      const line1 = 'P<GBRWILSON<<JAMES<<<<<<<<<<<<<<<<<<<<<<<<<<';
      const line2 = '7249187895GBR8805120M3203189<<<<<<<<<<<<<<02';

      final result = MrzParser.parse(line1, line2);

      expect(result.documentType, 'P');
      expect(result.issuingCountry, 'GBR');
      expect(result.surname, 'WILSON');
      expect(result.givenNames, 'JAMES');
      expect(result.fullName, 'JAMES WILSON');
      expect(result.nationality, 'GBR');
      expect(result.passportNumber, '724918789');
      expect(result.passportMasked, '••••••789');
      expect(result.sex, 'M');
      expect(result.birthDateFormatted, '12 May 1988');
      expect(result.expiryDateFormatted, '18 Mar 2032');
      expect(result.isPassportNumberValid, true);
      expect(result.isBirthDateValid, true);
      expect(result.isExpiryDateValid, true);
      expect(result.isCompositeValid, true);
      expect(result.isValid, true);
    });

    test('MrzParser detects tampered passport or invalid check digit', () {
      const line1 = 'P<GBRWILSON<<JAMES<<<<<<<<<<<<<<<<<<<<<<<<<<';
      // Sengaja memalsukan check digit expiry date dari 9 menjadi 3
      const tamperedLine2 = '7249187895GBR8805120M3203183<<<<<<<<<<<<<<02';

      final result = MrzParser.parse(line1, tamperedLine2);

      expect(result.isExpiryDateValid, false);
      expect(result.isValid, false);
    });

    test('MrzParser.detectAndParseFromText extracts TD3 lines from noisy OCR output', () {
      const noisyOcr = '''
PASSPORT / PASSEPORT
UNITED KINGDOM OF GREAT BRITAIN AND NORTHERN IRELAND
Type / Type: P  Code: GBR  Passport No: 724918789
P<GBRWILSON<<JAMES<<<<<<<<<<<<<<<<<<<<<<<<<<
7249187895GBR8805120M3203189<<<<<<<<<<<<<<02
Random noise OCR text below
      ''';

      final detected = MrzParser.detectAndParseFromText(noisyOcr);

      expect(detected, isNotNull);
      expect(detected!.surname, 'WILSON');
      expect(detected.givenNames, 'JAMES');
      expect(detected.nationality, 'GBR');
      expect(detected.passportMasked, '••••••789');
      expect(detected.isValid, true);
    });

    test('demoJamesWilson factory produces verified credential data', () {
      final demo = MrzParseResult.demoJamesWilson();

      expect(demo.fullName, 'JAMES WILSON');
      expect(demo.nationality, 'GBR');
      expect(demo.passportMasked, '••••••789');
      expect(demo.documentType, 'P');
      expect(demo.isValid, true);
    });
  });

  group('Milestone 3 - Onboarding State & Credential Audit Tests', () {
    test('BtidCredentialModel correctly computes stay duration and status', () {
      final now = DateTime.now();
      final cred = BtidCredentialModel(
        btidNumber: 'BTID-2026-4471-0938',
        fullName: 'James Wilson',
        nationality: 'GBR',
        passportMasked: '••••••789',
        dob: '1988-04-12',
        docExpiry: '2031-08-15',
        visaType: 'e-VOA B1',
        arrivalDate: now.toIso8601String().substring(0, 10),
        stayExpiry: now.add(const Duration(days: 30)).toIso8601String().substring(0, 10),
        levyStatus: 'unpaid',
        walletAddress: '0x71C...B29',
        issuedAt: now,
      );

      expect(cred.isLevyPaid, false);
      expect(cred.daysRemaining, inInclusiveRange(29, 30));

      final updatedPaid = cred.copyWith(levyStatus: 'paid', levyReceiptRef: 'LVY-448102');
      expect(updatedPaid.isLevyPaid, true);
      expect(updatedPaid.levyReceiptRef, 'LVY-448102');
    });

    test('VerificationTransactionService records credential issued audit', () async {
      final service = VerificationTransactionService();
      final audit = await service.recordCredentialIssuedAudit(
        btid: 'BTID-2026-4471-0938',
        fullName: 'James Wilson',
        walletAddress: '0x71CB05EE1b1F506fF321Da3CE92a540AC401B4D0',
      );

      expect(audit.auditRef, startsWith('AUD-'));
      expect(audit.txRef, 'BTID-2026-4471-0938');
      expect(audit.action, 'Credential issued');
      expect(audit.purpose, 'Identity onboarding');
      expect(audit.status, 'Approved');
      expect(audit.txHash, startsWith('0x'));

      final list = await service.getAuditTransactions();
      expect(list.any((a) => a.txRef == 'BTID-2026-4471-0938'), true);
    });
  });
}
