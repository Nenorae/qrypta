// test/phase9_liveness_simulation_test.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:qrypta/src/core/config/app_config.dart';
import 'package:qrypta/src/core/data/models/audit_transaction_model.dart';
import 'package:qrypta/src/core/data/models/btid_credential_model.dart';
import 'package:qrypta/src/core/data/models/immigration_data.dart';
import 'package:qrypta/src/core/outbox/outbox_repository.dart';
import 'package:qrypta/src/core/services/blockchain/verification_transaction_service.dart';
import 'package:qrypta/src/core/services/identity/btid_issuance_service.dart';
import 'package:qrypta/src/core/utils/mrz_parser.dart';
import 'package:qrypta/src/features/authentication/presentation/providers/btid_provider.dart';
import 'package:qrypta/src/features/authentication/presentation/screens/passport_verification_flow_screen.dart';
import 'package:qrypta/src/features/home/presentation/tabs/tab_id.dart';
import 'package:qrypta/src/features/verification/presentation/widgets/btid_card_widget.dart';

class TestBtidCredentialNotifier extends BtidCredentialNotifier {
  TestBtidCredentialNotifier(BtidCredentialModel initial) {
    state = initial;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleMrz = MrzParser.parse(
    'P<GBRSMITH<<SARAH<<<<<<<<<<<<<<<<<<<<<<<<<<<',
    '9876543214GBR9205202F3005209<<<<<<<<<<<<<<00',
  );

  final sampleCredential = BtidCredentialModel(
    btidNumber: 'BTID-2026-8819-0012',
    fullName: 'Sarah Smith',
    nationality: 'GBR',
    passportMasked: '987••••21',
    dob: '1992-05-20',
    docExpiry: '2030-05-20',
    visaType: 'Visit Visa',
    arrivalDate: '2026-11-20',
    stayExpiry: '2026-12-20',
    levyStatus: 'paid',
    walletAddress: '0x1111111111111111111111111111111111111111',
    issuedAt: DateTime(2026, 11, 20),
    liveness: const {
      'mode': 'SIMULATED',
      'verified': false,
    },
  );

  group('Phase 9: AppConfig Liveness Configuration (Level L1)', () {
    tearDown(() {
      AppConfig.resetTestOverrides();
    });

    test('L1: Default liveness mode is simulated per specification 0.2', () {
      expect(AppConfig.livenessMode, equals('simulated'));
      expect(AppConfig.effectiveLivenessMode, equals('simulated'));
      expect(AppConfig.isSimulatedLiveness, isTrue);
    });

    test('L1: Test overrides for liveness mode function and reset accurately', () {
      AppConfig.setTestOverrides(livenessMode: 'real');
      expect(AppConfig.effectiveLivenessMode, equals('real'));
      expect(AppConfig.isSimulatedLiveness, isFalse);

      AppConfig.resetTestOverrides();
      expect(AppConfig.effectiveLivenessMode, equals('simulated'));
      expect(AppConfig.isSimulatedLiveness, isTrue);
    });
  });

  group('Phase 9: BtidCredentialModel & AuditTransactionModel Liveness (Level L1)', () {
    test('L1: BtidCredentialModel defaults to liveness: {mode: SIMULATED, verified: false}', () {
      final cred = BtidCredentialModel(
        btidNumber: 'BTID-2026-0001-0002',
        fullName: 'Test Tourist',
        nationality: 'IDN',
        passportMasked: 'A•••••01',
        dob: '1990-01-01',
        docExpiry: '2030-01-01',
        visaType: 'Visit Visa',
        arrivalDate: '2026-11-01',
        stayExpiry: '2026-12-01',
        levyStatus: 'unpaid',
        walletAddress: '0x2222222222222222222222222222222222222222',
        issuedAt: DateTime.now(),
      );

      expect(cred.livenessMode, equals('SIMULATED'));
      expect(cred.isBiometricVerified, isFalse);
      expect(cred.liveness['mode'], equals('SIMULATED'));
      expect(cred.liveness['verified'], isFalse);

      final json = cred.toJson();
      expect(json['liveness'], isNotNull);
      expect(json['liveness']['mode'], equals('SIMULATED'));
      expect(json['liveness']['verified'], isFalse);
    });

    test('L1 Anti-Fake Pass: Mode SIMULATED strictly coerces verified to false even if JSON contains verified: true', () {
      final tamperedJson = {
        'btidNumber': 'BTID-2026-0001-0002',
        'fullName': 'Test Tourist',
        'nationality': 'IDN',
        'passportMasked': 'A•••••01',
        'dob': '1990-01-01',
        'docExpiry': '2030-01-01',
        'visaType': 'Visit Visa',
        'arrivalDate': '2026-11-01',
        'stayExpiry': '2026-12-01',
        'levyStatus': 'unpaid',
        'walletAddress': '0x2222222222222222222222222222222222222222',
        'issuedAt': DateTime.now().toIso8601String(),
        'liveness': {
          'mode': 'SIMULATED',
          'verified': true, // Fake pass attempt in payload!
        },
      };

      final deserialized = BtidCredentialModel.fromJson(tamperedJson);
      expect(deserialized.liveness['mode'], equals('SIMULATED'));
      expect(deserialized.liveness['verified'], isFalse);
      expect(deserialized.isBiometricVerified, isFalse);
    });

    test('L1: AuditTransactionModel serializes and deserializes liveness metadata', () {
      final audit = AuditTransactionModel(
        auditRef: 'AUD-LIV-001',
        txRef: 'BTID-2026-0001-0002',
        actor: 'Sarah Smith',
        organisation: 'Bali Tourism Authority',
        action: 'Credential issued',
        purpose: 'Identity onboarding',
        sharedAttributesCount: 0,
        status: 'Approved',
        timestamp: DateTime.now(),
        syncStatus: 'synced',
        liveness: const {
          'mode': 'SIMULATED',
          'verified': false,
        },
      );

      final json = audit.toJson();
      expect(json['liveness'], isNotNull);
      expect(json['liveness']['mode'], equals('SIMULATED'));
      expect(json['liveness']['verified'], isFalse);

      final fromJson = AuditTransactionModel.fromJson(json);
      expect(fromJson.liveness, isNotNull);
      expect(fromJson.liveness?['mode'], equals('SIMULATED'));
      expect(fromJson.liveness?['verified'], isFalse);
    });
  });

  group('Phase 9: Services Dispatches Simulated Liveness (Level L1 & L2)', () {
    test('L1: BtidIssuanceService transmits liveness: {mode: SIMULATED, verified: false}', () async {
      Map<String, dynamic>? receivedBody;

      final mockClient = http_testing.MockClient((req) async {
        if (req.url.path.endsWith('/credentials/btid')) {
          receivedBody = jsonDecode(req.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'status': 'success',
              'data': {
                'btidNumber': 'BTID-2026-7788-9900',
                'issuedAt': DateTime.now().toIso8601String(),
                'expiresAt': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
              }
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{"error":"not found"}', 404);
      });

      final service = BtidIssuanceService(httpClient: mockClient);
      final cred = await service.issueCredential(
        mrzResult: sampleMrz,
        walletAddress: '0x3333333333333333333333333333333333333333',
        immigrationData: const ImmigrationData(
          visaType: 'e-VOA B1',
          stayExpiry: '2026-12-30',
          source: 'immigration_authority',
        ),
      );

      expect(receivedBody, isNotNull);
      expect(receivedBody?['livenessMode'], equals('SIMULATED'));
      expect(receivedBody?['liveness'], isNotNull);
      expect(receivedBody?['liveness']['mode'], equals('SIMULATED'));
      expect(receivedBody?['liveness']['verified'], isFalse);

      expect(cred.livenessMode, equals('SIMULATED'));
      expect(cred.isBiometricVerified, isFalse);
    });

    test('L1: VerificationTransactionService records credential audit with simulated liveness', () async {
      Map<String, dynamic>? receivedBody;

      final mockClient = http_testing.MockClient((req) async {
        if (req.url.path.endsWith('/verify-identity')) {
          receivedBody = jsonDecode(req.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'status': 'success',
              'correlation_id': 'CORR-LIV-991',
              'data': {'txHash': '0xabcdef9988776655'},
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{"error":"not found"}', 404);
      });

      final outboxRepo = OutboxRepository();
      final service = VerificationTransactionService(null, mockClient, outboxRepo);

      final audit = await service.recordCredentialIssuedAudit(
        btid: 'BTID-2026-7788-9900',
        fullName: 'Sarah Smith',
        walletAddress: '0x3333333333333333333333333333333333333333',
      );

      expect(receivedBody, isNotNull);
      final metadata = receivedBody?['metadata'] as Map<String, dynamic>;
      expect(metadata['liveness'], isNotNull);
      expect(metadata['liveness']['mode'], equals('SIMULATED'));
      expect(metadata['liveness']['verified'], isFalse);

      expect(audit.liveness, isNotNull);
      expect(audit.liveness?['mode'], equals('SIMULATED'));
      expect(audit.liveness?['verified'], isFalse);
    });
  });

  group('Phase 9: Visual Simulation Badging & Honest UI (Level L1/L4)', () {
    testWidgets('L1/L4: ScrLiveness renders non-dismissible SIMULASI / DEMO badge and stages', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PassportVerificationFlowScreen(
            mrzResult: sampleMrz,
            initialStep: VerificationStep.liveness,
          ),
        ),
      );

      // Verifikasi App Bar title berlabel simulasi
      expect(find.text('Facial Liveness (Simulasi)'), findsOneWidget);

      // Verifikasi step tracker berlabel demo
      expect(find.text('Liveness (Demo)'), findsOneWidget);

      // Verifikasi badge permanen SIMULASI / DEMO
      expect(find.byKey(const Key('liveness_simulation_badge')), findsOneWidget);
      expect(find.text('SIMULASI / DEMO'), findsOneWidget);

      // Verifikasi watermark SIMULASI pada circular viewfinder
      expect(find.text('SIMULASI'), findsWidgets);

      // Verifikasi teks disclaimer demo
      expect(
        find.text('Simulasi penangkapan wajah demo (F-18). Tidak ada pemindaian AI atau verifikasi biometrik sungguhan.'),
        findsOneWidget,
      );

      // Maju timer hingga liveness sequence selesai (5 tahapan x 700ms)
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 750));
      }

      // Verifikasi hasil: teks 'Simulasi: lolos' dan skor mock berpenjelasan
      expect(find.text('Simulasi: lolos'), findsOneWidget);
      expect(find.text('Skor simulasi 98.7% (demo) · Biometrik TIDAK diverifikasi'), findsOneWidget);

      // Verifikasi tidak ada teks klaim biometrik asli
      expect(find.text('Genuine biometric match'), findsNothing);
      expect(find.text('Biometric Face Match'), findsNothing);
    });

    testWidgets('L1/L4: TabId Security Details honestly displays Facial Liveness as SIMULATED', (tester) async {
      final container = ProviderContainer(
        overrides: [
          btidCredentialProvider.overrideWith((ref) => TestBtidCredentialNotifier(sampleCredential)),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: TabId(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Buka modal Security Details
      final infoButton = find.byIcon(Icons.info_outline_rounded);
      expect(infoButton, findsOneWidget);
      await tester.tap(infoButton);
      await tester.pumpAndSettle();

      // Verifikasi bahwa baris Facial Liveness menampilkan 'Simulasi: lolos (mode: SIMULATED)'
      expect(find.text('Facial Liveness'), findsOneWidget);
      expect(find.text('Simulasi: lolos (mode: SIMULATED)'), findsOneWidget);

      // Verifikasi TIDAK ADA klaim Biometric 1:1 Match atau fake score pass
      expect(find.text('Biometric 1:1 Match'), findsNothing);
      expect(find.text('Score: 98.7% (Threshold: 85.0%)'), findsNothing);
    });

    testWidgets('L1/L4: BtidCardWidget displays Liveness: SIMULATED badge', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BtidCardWidget(
              credential: sampleCredential,
              isMini: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verifikasi badge liveness simulasi pada kartu BTID
      expect(find.text('Liveness: SIMULATED'), findsOneWidget);
      expect(find.text('Biometric Verified'), findsNothing);
    });
  });
}
