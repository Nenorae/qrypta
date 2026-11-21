// test/phase8_nfc_widget_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:qrypta/src/core/error/app_failure.dart';
import 'package:qrypta/src/core/utils/mrz_parser.dart';
import 'package:qrypta/src/features/authentication/data/nfc/nfc_passport_service.dart';
import 'package:qrypta/src/features/authentication/domain/models/nfc_passport_models.dart';
import 'package:qrypta/src/features/authentication/presentation/screens/passport_verification_flow_screen.dart';
import 'fixtures/nfc_fixtures.dart';

class MockNfcPassportService extends NfcPassportService {
  final NfcAvailability mockAvailability;
  final PassportChipData? mockSuccessData;
  final AppFailure? mockFailure;

  MockNfcPassportService({
    this.mockAvailability = NfcAvailability.enabled,
    this.mockSuccessData,
    this.mockFailure,
  });

  @override
  Future<NfcAvailability> checkHardwareAvailability() async {
    return mockAvailability;
  }

  @override
  Future<void> startPhysicalScanningSession({
    required MrzParseResult cameraMrz,
    required NfcProgressCallback onProgress,
    required void Function(PassportChipData data) onSuccess,
    required void Function(AppFailure failure) onError,
  }) async {
    onProgress(NfcReadStage.waitingForPassport, 'Hold passport firmly against phone back antenna');
    if (mockFailure != null) {
      onError(mockFailure!);
    } else if (mockSuccessData != null) {
      onProgress(NfcReadStage.establishingSecureChannel, 'Establishing secure channel (BAC/PACE)...');
      onProgress(NfcReadStage.readingDg1, 'Reading passport data (DG1: MRZ)...');
      onProgress(NfcReadStage.readingEfSod, 'Reading signed security data (SOD)...');
      onSuccess(mockSuccessData!);
    }
  }

  @override
  Future<void> cancelScanningSession() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MrzParseResult testMrz;

  setUp(() {
    testMrz = MrzParser.parse(
      NfcTestFixtures.utopiaMrzLine1,
      NfcTestFixtures.utopiaMrzLine2,
    );
  });

  Widget createWidgetUnderTest(NfcPassportService service) {
    return MaterialApp(
      home: PassportVerificationFlowScreen(
        mrzResult: testMrz,
        nfcService: service,
      ),
    );
  }

  group('Phase 8.1 & 8.2: PassportVerificationFlowScreen Real UI Tests (Level L1)', () {
    testWidgets('L1: Displays disabled NFC warning banner when phone NFC is turned off', (tester) async {
      final mockService = MockNfcPassportService(
        mockAvailability: NfcAvailability.disabled,
      );

      await tester.pumpWidget(createWidgetUnderTest(mockService));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('NFC is disabled. Please turn on NFC in phone settings.'), findsOneWidget);
      expect(find.text('Try Scanning Again'), findsOneWidget);
    });

    testWidgets('L1: Displays unsupported hardware message when phone lacks NFC chip', (tester) async {
      final mockService = MockNfcPassportService(
        mockAvailability: NfcAvailability.unsupported,
      );

      await tester.pumpWidget(createWidgetUnderTest(mockService));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('This device does not have an NFC chip reader.'), findsOneWidget);
    });

    testWidgets('L1: Displays tag lost error message when passport is moved mid-read', (tester) async {
      final mockService = MockNfcPassportService(
        mockAvailability: NfcAvailability.enabled,
        mockFailure: const NfcTagLost('Passport tag was moved too quickly from antenna'),
      );

      await tester.pumpWidget(createWidgetUnderTest(mockService));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Passport tag was moved too quickly from antenna'), findsOneWidget);
      expect(find.text('Try Scanning Again'), findsOneWidget);
    });

    testWidgets('L1: Successfully advances to PKI Auth view and displays dynamic PassiveAuth attributes', (tester) async {
      final dg1 = NfcTestFixtures.createDg1Binary();
      final sod = NfcTestFixtures.createSodBinary(dg1Bytes: dg1, countryCode: 'UTO');

      final chipData = PassportChipData(
        ldsVersion: '1.7',
        dataGroupsPresent: [1, 2, 14],
        rawDg1: dg1,
        rawEfSod: sod,
        chipMrz: testMrz,
        passiveAuth: const PassiveAuthResult(
          isValid: true,
          status: PassiveAuthStatus.genuine,
          reasons: ['All DG hashes match SOD', 'Signature valid', 'CSCA verified'],
          issuingCountry: 'UTO',
          dscSubject: 'C=UTO, CN=Utopia Document Signer 2026',
          dscIssuer: 'C=UTO, CN=Utopia CSCA Root',
          dscSerial: 'A1B2C3D4',
          hashAlgorithm: 'SHA-256',
          signatureAlgorithm: 'RSA-SHA256',
          dgHashesMatched: {1: true},
          cscaCountry: 'Utopia (ICAO Specimen Authority)',
        ),
        readDurationMs: 850,
      );

      final mockService = MockNfcPassportService(
        mockAvailability: NfcAvailability.enabled,
        mockSuccessData: chipData,
      );

      await tester.pumpWidget(createWidgetUnderTest(mockService));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 700));

      // Memastikan berpindah ke step 2 (Passive Authentication)
      expect(find.text('Passive Authentication (ICAO Doc 9303)'), findsOneWidget);
      expect(find.textContaining('DG1 hash matched SOD (SHA-256)'), findsOneWidget);
      expect(find.textContaining('Utopia (ICAO Specimen Authority) Master List CSCA verified'), findsOneWidget);

      // Buka modal Security Details
      final detailsBtn = find.text('Security details');
      expect(detailsBtn, findsOneWidget);
      await tester.tap(detailsBtn);
      await tester.pump(const Duration(milliseconds: 300));

      // Verifikasi bahwa modal menampilkan nilai PKI dinamis, BUKAN string hardcoded
      expect(find.text('PKI Security Details'), findsOneWidget);
      expect(find.text('C=UTO, CN=Utopia Document Signer 2026'), findsOneWidget);
      expect(find.text('A1B2C3D4'), findsOneWidget);
      expect(find.text('VALIDATED · GENUINE'), findsOneWidget);
    });

    testWidgets('L1: Displays UNVERIFIED badge in trust chain when country root CSCA is missing from store', (tester) async {
      final dg1 = NfcTestFixtures.createDg1Binary();
      final sod = NfcTestFixtures.createSodBinary(dg1Bytes: dg1, countryCode: 'XYZ');

      final chipData = PassportChipData(
        ldsVersion: '1.7',
        dataGroupsPresent: [1],
        rawDg1: dg1,
        rawEfSod: sod,
        chipMrz: testMrz,
        passiveAuth: const PassiveAuthResult(
          isValid: true,
          status: PassiveAuthStatus.unverifiedNoTrustAnchor,
          reasons: ['Root CSCA for XYZ not in local trust store'],
          issuingCountry: 'XYZ',
          dscSubject: 'C=XYZ, CN=Document Signer',
          dscIssuer: 'C=XYZ, CN=CSCA Root',
          dscSerial: 'FF0011',
          hashAlgorithm: 'SHA-256',
          signatureAlgorithm: 'RSA-SHA256',
          dgHashesMatched: {1: true},
          cscaCountry: null,
        ),
        readDurationMs: 900,
      );

      final mockService = MockNfcPassportService(
        mockAvailability: NfcAvailability.enabled,
        mockSuccessData: chipData,
      );

      await tester.pumpWidget(createWidgetUnderTest(mockService));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 700));

      // Verifikasi bahwa label unverified ditampilkan secara jujur
      expect(find.textContaining('Root CSCA for ${testMrz.nationality} unverified in local trust store'), findsOneWidget);

      // Buka modal
      await tester.tap(find.text('Security details'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('UNVERIFIED · NO TRUST ANCHOR'), findsOneWidget);
    });
  });
}
