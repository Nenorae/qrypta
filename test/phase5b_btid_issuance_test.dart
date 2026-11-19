// test/phase5b_btid_issuance_test.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:qrypta/src/core/data/models/btid_credential_model.dart';
import 'package:qrypta/src/core/data/models/holder_profile.dart';
import 'package:qrypta/src/core/data/models/immigration_data.dart';
import 'package:qrypta/src/core/error/app_failure.dart';
import 'package:qrypta/src/core/services/identity/btid_issuance_service.dart';
import 'package:qrypta/src/core/utils/mrz_parser.dart';
import 'package:qrypta/src/features/authentication/presentation/providers/btid_provider.dart';

void main() {
  const testWalletAddress = '0x71CB05EE1b1F506fF321Da3CE92a540AC401B4D0';

  // Sample valid MRZ parse result for testing
  final validMrz = MrzParseResult(
    rawLine1: 'P<GBRWAYFARER<<ALEXANDER<<<<<<<<<<<<<<<<<<<<',
    rawLine2: '7481920310GBR9206155M3106152XYZ987<<<<<<<<02',
    documentType: 'P',
    issuingCountry: 'GBR',
    surname: 'WAYFARER',
    givenNames: 'ALEXANDER',
    fullName: 'WAYFARER ALEXANDER',
    passportNumber: '748192031',
    passportMasked: '••••••031',
    nationality: 'GBR',
    birthDate: DateTime(1992, 6, 15),
    birthDateFormatted: '15 Jun 1992',
    sex: 'M',
    expiryDate: DateTime.now().add(const Duration(days: 365 * 5)), // Valid 5 years in future
    expiryDateFormatted: '15 Jun 2031',
    personalNumber: 'XYZ987',
    isPassportNumberValid: true,
    isBirthDateValid: true,
    isExpiryDateValid: true,
    isCompositeValid: true,
  );

  group('Phase 5B.1 & 5B.2: Zero-PII Passport Hash & Idempotency (Level L1)', () {
    test('generatePassportHash produces deterministic 64-char HMAC-SHA256 hex', () {
      final hash1 = BtidIssuanceService.generatePassportHash(
        nationality: 'GBR',
        passportNumber: '748192031',
        dob: '1992-06-15',
      );

      final hash2 = BtidIssuanceService.generatePassportHash(
        nationality: 'GBR',
        passportNumber: '748192031',
        dob: '1992-06-15',
      );

      expect(hash1, equals(hash2));
      expect(hash1.length, equals(64));
      // Does not contain plaintext passport number (Golden Rule R9)
      expect(hash1.contains('748192031'), isFalse);
    });

    test('generatePassportHash produces different hash for different identity inputs', () {
      final hashA = BtidIssuanceService.generatePassportHash(
        nationality: 'GBR',
        passportNumber: '748192031',
        dob: '1992-06-15',
      );

      final hashB = BtidIssuanceService.generatePassportHash(
        nationality: 'AUS',
        passportNumber: 'N1234567',
        dob: '1995-10-20',
      );

      expect(hashA, isNot(equals(hashB)));
    });

    test('computeIdempotencyKey produces deterministic SHA-256 hex', () {
      final hash = BtidIssuanceService.generatePassportHash(
        nationality: 'GBR',
        passportNumber: '748192031',
        dob: '1992-06-15',
      );

      final key1 = BtidIssuanceService.computeIdempotencyKey(
        passportHash: hash,
        walletAddress: testWalletAddress,
      );

      final key2 = BtidIssuanceService.computeIdempotencyKey(
        passportHash: hash,
        walletAddress: testWalletAddress,
      );

      expect(key1, equals(key2));
      expect(key1.length, equals(64));
    });
  });

  group('Phase 5B.2: Strict Pre-flight Biodata & Expiry Validation (Level L1)', () {
    test('Rejects expired passport with ValidationFailure', () async {
      final expiredMrz = MrzParseResult(
        rawLine1: 'P<GBRWAYFARER<<ALEXANDER<<<<<<<<<<<<<<<<<<<<',
        rawLine2: '7481920310GBR9206155M2611082<<<<<<<<<<<<<<02',
        documentType: 'P',
        issuingCountry: 'GBR',
        surname: 'WAYFARER',
        givenNames: 'ALEXANDER',
        fullName: 'WAYFARER ALEXANDER',
        passportNumber: '748192031',
        passportMasked: '••••••031',
        nationality: 'GBR',
        birthDate: DateTime(1992, 6, 15),
        birthDateFormatted: '15 Jun 1992',
        sex: 'M',
        expiryDate: DateTime.now().subtract(const Duration(days: 10)), // Expired 10 days ago!
        expiryDateFormatted: '08 Nov 2026',
        personalNumber: '',
        isPassportNumberValid: true,
        isBirthDateValid: true,
        isExpiryDateValid: true,
        isCompositeValid: true,
      );

      final service = BtidIssuanceService(
        httpClient: http_testing.MockClient((_) async => http.Response('{}', 200)),
        baseUrl: 'http://staging.test/api/v1',
      );

      expect(
        () => service.issueCredential(
          mrzResult: expiredMrz,
          walletAddress: testWalletAddress,
        ),
        throwsA(
          isA<ValidationFailure>().having(
            (e) => e.message,
            'message',
            contains('kedaluwarsa'),
          ),
        ),
      );
    });

    test('Rejects missing birthDate or expiryDate with ValidationFailure', () async {
      final nullDatesMrz = MrzParseResult(
        rawLine1: '',
        rawLine2: '',
        documentType: 'P',
        issuingCountry: 'GBR',
        surname: 'WAYFARER',
        givenNames: 'ALEXANDER',
        fullName: 'WAYFARER ALEXANDER',
        passportNumber: '748192031',
        passportMasked: '••••••031',
        nationality: 'GBR',
        birthDate: null,
        birthDateFormatted: '',
        sex: 'M',
        expiryDate: null,
        expiryDateFormatted: '',
        personalNumber: '',
        isPassportNumberValid: true,
        isBirthDateValid: false,
        isExpiryDateValid: false,
        isCompositeValid: false,
      );

      final service = BtidIssuanceService(
        httpClient: http_testing.MockClient((_) async => http.Response('{}', 200)),
        baseUrl: 'http://staging.test/api/v1',
      );

      expect(
        () => service.issueCredential(
          mrzResult: nullDatesMrz,
          walletAddress: testWalletAddress,
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('Rejects empty wallet address with ValidationFailure', () async {
      final service = BtidIssuanceService(
        httpClient: http_testing.MockClient((_) async => http.Response('{}', 200)),
        baseUrl: 'http://staging.test/api/v1',
      );

      expect(
        () => service.issueCredential(
          mrzResult: validMrz,
          walletAddress: '   ',
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });
  });

  group('Phase 5B.1: Authoritative Server Issuance & Anti-Fake Fallback (F-11, F-08)', () {
    test('Throws ServerRejected when backend returns 500 and does NOT issue credential', () async {
      final mockClient = http_testing.MockClient((req) async {
        return http.Response(
          jsonEncode({'error': 'Internal server error in ezsign-core'}),
          500,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = BtidIssuanceService(
        httpClient: mockClient,
        baseUrl: 'http://staging.test/api/v1',
      );

      expect(
        () => service.issueCredential(
          mrzResult: validMrz,
          walletAddress: testWalletAddress,
        ),
        throwsA(isA<ServerRejected>()),
      );
    });

    test('Throws NetworkUnreachable when server connection is refused', () async {
      final mockClient = http_testing.MockClient((req) async {
        throw http.ClientException('Connection refused');
      });

      final service = BtidIssuanceService(
        httpClient: mockClient,
        baseUrl: 'http://staging.test/api/v1',
      );

      expect(
        () => service.issueCredential(
          mrzResult: validMrz,
          walletAddress: testWalletAddress,
        ),
        throwsA(isA<NetworkUnreachable>()),
      );
    });

    test('Throws RequestTimeout when server times out', () async {
      final mockClient = http_testing.MockClient((req) async {
        throw TimeoutException('Request timed out after 10s');
      });

      final service = BtidIssuanceService(
        httpClient: mockClient,
        baseUrl: 'http://staging.test/api/v1',
      );

      expect(
        () => service.issueCredential(
          mrzResult: validMrz,
          walletAddress: testWalletAddress,
        ),
        throwsA(isA<RequestTimeout>()),
      );
    });

    test('Successfully issues BTID with server-assigned btidNumber when server returns 201', () async {
      String? capturedIdempotencyKey;
      Map<String, dynamic>? capturedBody;

      const serverAssignedBtid = 'BTID-2026-9812-4411';

      final mockClient = http_testing.MockClient((req) async {
        if (req.url.path.contains('/immigration/evoa')) {
          return http.Response(
            jsonEncode({
              'data': {
                'visaType': 'Official Tourist Visa (B1)',
                'stayExpiry': '2026-12-31',
              }
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (req.url.path.contains('/credentials/btid')) {
          capturedIdempotencyKey = req.headers['Idempotency-Key'];
          capturedBody = jsonDecode(req.body);

          return http.Response(
            jsonEncode({
              'status': 'success',
              'data': {
                'btidNumber': serverAssignedBtid,
                'issuedAt': '2026-11-18T10:00:00Z',
                'expiresAt': '2026-12-31',
                'anchorTxHash': '0x8899aabbccddeeff00112233445566778899aabbccddeeff0011223344556677',
                'credentialId': 'cred-uuid-8812',
              }
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }

        return http.Response('Not Found', 404);
      });

      final service = BtidIssuanceService(
        httpClient: mockClient,
        baseUrl: 'http://staging.test/api/v1',
      );

      final cred = await service.issueCredential(
        mrzResult: validMrz,
        walletAddress: testWalletAddress,
      );

      expect(cred.btidNumber, equals(serverAssignedBtid));
      expect(cred.fullName, equals('WAYFARER ALEXANDER'));
      expect(cred.visaType, equals('Official Tourist Visa (B1)'));
      expect(cred.stayExpiry, equals('2026-12-31'));
      expect(cred.immigrationSource, equals('immigration_authority'));
      expect(cred.anchorTxHash, isNotNull);

      // Verify Idempotency-Key header was attached
      expect(capturedIdempotencyKey, isNotNull);
      expect(capturedIdempotencyKey!.length, equals(64));

      // Verify payload contains Zero-PII passportHash
      expect(capturedBody!['passportHash'], isNotNull);
      expect(capturedBody!['walletAddress'], equals(testWalletAddress));
      expect(capturedBody!['livenessMode'], equals('SIMULATED'));
    });
  });

  group('Phase 5B.3: Immigration Data Resolution (D-2)', () {
    test('Returns authoritative immigration data when server responds 200', () async {
      final mockClient = http_testing.MockClient((req) async {
        return http.Response(
          jsonEncode({
            'data': {
              'visaType': 'Official Tourist Visa (B1)',
              'stayExpiry': '2026-12-25',
            }
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = BtidIssuanceService(
        httpClient: mockClient,
        baseUrl: 'http://staging.test/api/v1',
      );

      final immi = await service.fetchImmigrationData(passportHash: 'hash-abc');
      expect(immi.isAuthoritative, isTrue);
      expect(immi.source, equals('immigration_authority'));
      expect(immi.visaType, equals('Official Tourist Visa (B1)'));
      expect(immi.stayExpiry, equals('2026-12-25'));
    });

    test('Returns self_declared fallback data when authority server is offline or 404', () async {
      final mockClient = http_testing.MockClient((req) async {
        return http.Response('Endpoint not found', 404);
      });

      final service = BtidIssuanceService(
        httpClient: mockClient,
        baseUrl: 'http://staging.test/api/v1',
      );

      final immi = await service.fetchImmigrationData(passportHash: 'hash-abc');
      expect(immi.isAuthoritative, isFalse);
      expect(immi.source, equals('self_declared'));
      expect(immi.visaType, contains('Self-declared'));
      expect(immi.stayExpiry, isNull);
    });
  });

  group('Phase 5B.4: HolderProfile Model & Provider (F-12 UI)', () {
    test('HolderProfile encapsulates traveler identity and zero-PII actorRef', () {
      final profile = HolderProfile.fromCredential(
        fullName: 'Alexander Wayfarer',
        walletAddress: testWalletAddress,
        btidNumber: 'BTID-2026-9812-4411',
      );

      expect(profile.name, equals('Alexander Wayfarer'));
      expect(profile.walletAddress, equals(testWalletAddress));
      expect(profile.btidNumber, equals('BTID-2026-9812-4411'));
      expect(profile.actorRef, startsWith('0x'));
      expect(profile.actorRef.length, equals(18)); // '0x' + 16 hex chars
      expect(profile.actorRef.contains('Alexander'), isFalse); // Zero PII (D-8)
    });

    test('holderProfileProvider returns null when btidCredentialProvider is empty', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final profile = container.read(holderProfileProvider);
      expect(profile, isNull);
    });
  });

  group('Phase 5B Sanitization: BtidCredentialModel fromJson Strictness', () {
    test('Throws FormatException if btidNumber is missing in fromJson', () {
      final invalidJson = {
        'fullName': 'Alexander Wayfarer',
        'nationality': 'GBR',
        'dob': '1992-06-15',
        'docExpiry': '2031-08-15',
      };

      expect(
        () => BtidCredentialModel.fromJson(invalidJson),
        throwsA(isA<FormatException>()),
      );
    });

    test('Throws FormatException if dob or docExpiry is missing in fromJson', () {
      final missingDob = {
        'btidNumber': 'BTID-2026-1122-3344',
        'fullName': 'Alexander Wayfarer',
        'nationality': 'GBR',
        'docExpiry': '2031-08-15',
      };

      expect(
        () => BtidCredentialModel.fromJson(missingDob),
        throwsA(isA<FormatException>()),
      );
    });

    test('Throws FormatException if fullName or nationality is missing in fromJson', () {
      final missingName = {
        'btidNumber': 'BTID-2026-1122-3344',
        'nationality': 'GBR',
        'dob': '1992-06-15',
        'docExpiry': '2031-08-15',
      };

      expect(
        () => BtidCredentialModel.fromJson(missingName),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
