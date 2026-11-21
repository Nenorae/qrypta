// test/phase7_merchant_handshake_test.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qrypta/src/core/data/models/actor_ref.dart';
import 'package:qrypta/src/core/data/models/btid_credential_model.dart';
import 'package:qrypta/src/core/data/models/consent_request_model.dart';
import 'package:qrypta/src/core/error/app_failure.dart';
import 'package:qrypta/src/core/services/blockchain/verification_transaction_service.dart';
import 'package:qrypta/src/core/services/notifications/push_notification_service.dart';
import 'package:qrypta/src/core/services/realtime/realtime_channel_service.dart';
import 'package:qrypta/src/features/authentication/presentation/providers/btid_provider.dart';
import 'package:qrypta/src/features/verification/logic/verification_controller.dart';
import 'package:web3dart/crypto.dart';
import 'package:web3dart/web3dart.dart';

/// Mock socket controller untuk pengujian deterministik L1/L2 WebSocket.
class MockRealtimeSocket implements IRealtimeSocket {
  final StreamController<dynamic> _incomingController = StreamController<dynamic>.broadcast();
  final List<dynamic> sentMessages = [];
  bool isClosed = false;

  @override
  Stream<dynamic> get stream => _incomingController.stream;

  @override
  void add(dynamic data) {
    sentMessages.add(data);
  }

  @override
  Future<void> close([int? status, String? reason]) async {
    isClosed = true;
    await _incomingController.close();
  }

  void simulateIncomingMessage(String jsonString) {
    _incomingController.add(jsonString);
  }

  void simulateSocketError(Object error) {
    _incomingController.addError(error);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Test private key & wallet address deterministik
  const testPrivateKeyHex = '4c0883a69102937d6231471b3dbb6832dbca04a98113a19e6fd4f263402d6aec';
  final testEthKey = EthPrivateKey.fromHex(testPrivateKeyHex);
  final testWalletAddress = testEthKey.address.hexEip55;
  const testBtid = 'BTID-2026-9921-8812';

  group('Phase 7.1: Dynamic QR Token Protocol & Cryptography Tests (Level L1)', () {
    late VerificationTransactionService service;

    setUp(() {
      service = VerificationTransactionService();
    });

    test('L1: Generates canonical 45-second signed Dynamic QR token per Phase 7.1 spec', () {
      final qrString = service.generateDynamicQrToken(
        testBtid,
        testWalletAddress,
        privateKeyHex: testPrivateKeyHex,
        validitySeconds: 45,
      );

      final decoded = jsonDecode(qrString) as Map<String, dynamic>;

      expect(decoded['v'], equals(1));
      expect(decoded['sessionId'], isNotEmpty);
      expect(decoded['nonce'], startsWith('0x'));
      expect(decoded['wallet'], equals(testWalletAddress));
      expect(decoded['btid'], equals(testBtid));
      expect(decoded['token'], startsWith('QRT-'));
      expect(decoded['sig'], startsWith('0x'));
      expect(decoded['sig'].toString().length, greaterThanOrEqualTo(130));

      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final exp = decoded['exp'] as int;
      expect(exp - nowSec, inInclusiveRange(43, 46));

      // Verifikasi keabsahan kriptografis tanda tangan
      final isValid = VerificationTransactionService.verifyDynamicQrToken(payload: decoded);
      expect(isValid, isTrue);
    });

    test('L1: Rejects expired dynamic QR token (>45 seconds)', () {
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final expiredEpoch = nowSec - 10;

      final payload = {
        'v': 1,
        'sessionId': 'session-1234',
        'nonce': '0xabcdef1234567890',
        'exp': expiredEpoch,
        'wallet': testWalletAddress,
        'btid': testBtid,
        'token': 'QRT-EXP1234567',
        'sig': '0x1234',
      };

      final isValid = VerificationTransactionService.verifyDynamicQrToken(payload: payload);
      expect(isValid, isFalse);
    });

    test('L1: Rejects tampered dynamic QR payload (signature mismatch)', () {
      final qrString = service.generateDynamicQrToken(
        testBtid,
        testWalletAddress,
        privateKeyHex: testPrivateKeyHex,
        validitySeconds: 45,
      );

      final decoded = jsonDecode(qrString) as Map<String, dynamic>;

      // Ubah salah satu field penting (misal target btid atau wallet)
      decoded['btid'] = 'BTID-2026-TAMPERED-001';

      final isValid = VerificationTransactionService.verifyDynamicQrToken(payload: decoded);
      expect(isValid, isFalse);
    });

    test('L1: Rejects dynamic QR signed by a different wallet address', () {
      // Buat signer asing
      final foreignKey = EthPrivateKey.createRandom(Random.secure());
      final foreignWallet = foreignKey.address.hexEip55;

      final qrString = service.generateDynamicQrToken(
        testBtid,
        testWalletAddress, // Wallet klaim adalah testWalletAddress
        privateKeyHex: bytesToHex(foreignKey.privateKey), // Namun ditandatangani oleh foreignKey
        validitySeconds: 45,
      );

      final decoded = jsonDecode(qrString) as Map<String, dynamic>;
      final isValid = VerificationTransactionService.verifyDynamicQrToken(payload: decoded);
      expect(isValid, isFalse);
    });
  });

  group('Phase 7.2: RealtimeChannelService Transport & Event Handling (Level L1 & L2)', () {
    late MockRealtimeSocket mockSocket;
    late RealtimeChannelService realtimeService;

    setUp(() {
      mockSocket = MockRealtimeSocket();
      realtimeService = RealtimeChannelService(
        socketConnector: (uri, {headers}) async => mockSocket,
        wsBaseUrl: 'wss://test.staging.local/ws/handshake',
        httpBaseUrl: 'https://test.staging.local',
      );
    });

    tearDown(() {
      realtimeService.dispose();
    });

    test('L1: Connects and transmits subscribe handshake packet with active wallet address', () async {
      final statusList = <RealtimeConnectionStatus>[];
      realtimeService.statusStream.listen(statusList.add);

      await realtimeService.connect(
        walletAddress: testWalletAddress,
        btid: testBtid,
      );

      expect(realtimeService.status, equals(RealtimeConnectionStatus.connected));
      expect(realtimeService.subscribedWallet, equals(testWalletAddress.toLowerCase()));
      expect(mockSocket.sentMessages.length, equals(1));

      final sentJson = jsonDecode(mockSocket.sentMessages.first as String);
      expect(sentJson['action'], equals('subscribe'));
      expect(sentJson['wallet'], equals(testWalletAddress.toLowerCase()));
      expect(sentJson['btid'], equals(testBtid));
    });

    test('L1: Receives real-time consent_request event and emits to requestStream', () async {
      await realtimeService.connect(walletAddress: testWalletAddress, btid: testBtid);

      ConsentRequestModel? receivedRequest;
      realtimeService.requestStream.listen((req) => receivedRequest = req);

      final incomingEvent = {
        'action': 'consent_request',
        'requestId': 'TX-778899',
        'merchantId': 'MCH-1042',
        'merchantName': 'Bali Ocean Resort',
        'merchantCategory': 'hotel',
        'staffName': 'Kadek Sari',
        'staffRole': 'Front Desk Agent',
        'purposeTemplate': 'hotel_checkin',
        'requestedFields': ['name', 'nationality', 'id_validity', 'stay_valid'],
        'retentionPolicy': 'Retained for 30 days under Bali regional lodging policy',
        'expiresAt': DateTime.now().add(const Duration(minutes: 3)).toIso8601String(),
      };

      mockSocket.simulateIncomingMessage(jsonEncode(incomingEvent));

      await pumpEventQueue();

      expect(receivedRequest, isNotNull);
      expect(receivedRequest!.requestId, equals('TX-778899'));
      expect(receivedRequest!.merchantName, equals('Bali Ocean Resort'));
      expect(receivedRequest!.requestedFields.length, equals(4));
    });

    test('L1: Filters out expired and duplicate consent requests', () async {
      await realtimeService.connect(walletAddress: testWalletAddress, btid: testBtid);

      final receivedList = <ConsentRequestModel>[];
      realtimeService.requestStream.listen(receivedList.add);

      final expiredEvent = {
        'action': 'consent_request',
        'requestId': 'TX-EXPIRED-01',
        'merchantId': 'MCH-1042',
        'merchantName': 'Bali Ocean Resort',
        'merchantCategory': 'hotel',
        'staffName': 'Kadek Sari',
        'staffRole': 'Front Desk',
        'purposeTemplate': 'hotel_checkin',
        'requestedFields': ['name'],
        'retentionPolicy': '30 days',
        'expiresAt': DateTime.now().subtract(const Duration(minutes: 1)).toIso8601String(),
      };

      // 1. Kirim event kedaluwarsa
      mockSocket.simulateIncomingMessage(jsonEncode(expiredEvent));
      await pumpEventQueue();
      expect(receivedList.isEmpty, isTrue);

      // 2. Kirim event valid
      final validEvent = {
        'action': 'consent_request',
        'requestId': 'TX-VALID-01',
        'merchantId': 'MCH-1042',
        'merchantName': 'Bali Ocean Resort',
        'merchantCategory': 'hotel',
        'staffName': 'Kadek Sari',
        'staffRole': 'Front Desk',
        'purposeTemplate': 'hotel_checkin',
        'requestedFields': ['name'],
        'retentionPolicy': '30 days',
        'expiresAt': DateTime.now().add(const Duration(minutes: 3)).toIso8601String(),
      };

      mockSocket.simulateIncomingMessage(jsonEncode(validEvent));
      await pumpEventQueue();
      expect(receivedList.length, equals(1));

      // 3. Kirim duplikat event yang sama
      mockSocket.simulateIncomingMessage(jsonEncode(validEvent));
      await pumpEventQueue();
      expect(receivedList.length, equals(1)); // Tidak bertambah
    });

    test('L2: syncMissedRequests polls and recovers active requests via HTTP', () async {
      final mockHttpClient = MockClient((request) async {
        expect(request.url.path, equals('/verification/requests'));
        expect(request.url.queryParameters['wallet'], equals(testWalletAddress.toLowerCase()));

        final responseBody = {
          'status': 'success',
          'requests': [
            {
              'requestId': 'TX-MISSED-99',
              'merchantId': 'MCH-2087',
              'merchantName': 'Island Drive Car Rental',
              'merchantCategory': 'car',
              'staffName': 'Gede Mahendra',
              'staffRole': 'Rental Agent',
              'purposeTemplate': 'vehicle_rental',
              'requestedFields': ['name', 'driving', 'over18'],
              'retentionPolicy': '90 days',
              'expiresAt': DateTime.now().add(const Duration(minutes: 3)).toIso8601String(),
            }
          ]
        };

        return http.Response(jsonEncode(responseBody), 200, headers: {'content-type': 'application/json'});
      });

      final pollingService = RealtimeChannelService(
        httpClient: mockHttpClient,
        socketConnector: (uri, {headers}) async => mockSocket,
        httpBaseUrl: 'https://test.staging.local',
      );

      final recovered = await pollingService.syncMissedRequests(walletAddress: testWalletAddress);
      expect(recovered.length, equals(1));
      expect(recovered.first.requestId, equals('TX-MISSED-99'));
      expect(recovered.first.merchantName, equals('Island Drive Car Rental'));

      pollingService.dispose();
    });

    test('L3 Chaos: Socket error triggers reconnecting state with exponential backoff', () async {
      final statusHistory = <RealtimeConnectionStatus>[];
      realtimeService.statusStream.listen(statusHistory.add);

      await realtimeService.connect(walletAddress: testWalletAddress, btid: testBtid);
      expect(realtimeService.status, equals(RealtimeConnectionStatus.connected));

      // Simulasikan putus koneksi mendadak
      mockSocket.simulateSocketError(const SocketException('Remote host reset connection'));
      await pumpEventQueue();

      expect(realtimeService.status, equals(RealtimeConnectionStatus.reconnecting));
    });
  });

  group('Phase 7.2: PushNotificationService Tests (Level L1)', () {
    test('L1: Registers FCM device token with ezsign-core server', () async {
      bool serverCalled = false;
      final mockHttpClient = MockClient((request) async {
        expect(request.url.path, equals('/notifications/register-token'));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['wallet'], equals(testWalletAddress.toLowerCase()));
        expect(body['deviceToken'], equals('fcm_token_sample_123456'));
        serverCalled = true;
        return http.Response('{"status":"registered"}', 200, headers: {'content-type': 'application/json'});
      });

      final pushService = PushNotificationService(
        httpClient: mockHttpClient,
        baseUrl: 'https://test.staging.local',
      );

      final success = await pushService.registerDeviceToken(
        walletAddress: testWalletAddress,
        btid: testBtid,
        deviceToken: 'fcm_token_sample_123456',
      );

      expect(success, isTrue);
      expect(serverCalled, isTrue);
      expect(pushService.status, equals(PushNotificationStatus.registered));
      pushService.dispose();
    });

    test('L1: Handles incoming push notification payload and emits ConsentRequestModel', () async {
      final pushService = PushNotificationService();
      ConsentRequestModel? receivedPushRequest;
      pushService.pushRequestStream.listen((req) => receivedPushRequest = req);

      final pushData = {
        'type': 'consent_request',
        'requestId': 'TX-PUSH-5566',
        'merchantId': 'MCH-4190',
        'merchantName': 'Bali Connect eSIM',
        'merchantCategory': 'esim',
        'staffName': 'Ketut Suastika',
        'staffRole': 'Support Specialist',
        'purposeTemplate': 'esim_activation',
        'requestedFields': ['identity', 'id_validity'],
        'retentionPolicy': 'Active duration',
        'expiresAt': DateTime.now().add(const Duration(minutes: 3)).toIso8601String(),
      };

      pushService.handleIncomingPushPayload(pushData);
      await pumpEventQueue();

      expect(receivedPushRequest, isNotNull);
      expect(receivedPushRequest!.requestId, equals('TX-PUSH-5566'));
      expect(receivedPushRequest!.merchantName, equals('Bali Connect eSIM'));

      pushService.dispose();
    });
  });

  group('Phase 7.2 & 7.4: VerificationController End-to-End Handshake Flow (Level L2)', () {
    late MockRealtimeSocket mockSocket;
    late RealtimeChannelService realtimeService;
    late VerificationTransactionService verificationService;
    late ProviderContainer container;

    setUp(() {
      mockSocket = MockRealtimeSocket();
      realtimeService = RealtimeChannelService(
        socketConnector: (uri, {headers}) async => mockSocket,
      );

      final mockHttpClient = MockClient((request) async {
        if (request.url.path.endsWith('/verify-identity')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['docType'], equals('BTID_CONSENT'));
          return http.Response(
            jsonEncode({
              'status': 'success',
              'correlation_id': 'CORR-998811',
              'data': {
                'txHash': '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
              }
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{"error":"not found"}', 404);
      });

      verificationService = VerificationTransactionService(
        null,
        mockHttpClient,
      );

      container = ProviderContainer(
        overrides: [
          btidCredentialProvider.overrideWith((ref) => BtidCredentialNotifier()),
          verificationControllerProvider.overrideWith((ref) => VerificationNotifier(
                ref,
                verificationService,
                realtimeService: realtimeService,
              )),
        ],
      );

      // Inisiasi dummy credential aktif
      container.read(btidCredentialProvider.notifier).saveCredential(
            BtidCredentialModel(
              btidNumber: testBtid,
              fullName: 'Ayu Lestari',
              nationality: 'IDN',
              passportMasked: 'A•••••89',
              dob: '1995-06-15',
              docExpiry: '2030-06-15',
              visaType: 'Visit Visa',
              arrivalDate: '2026-11-15',
              stayExpiry: '2026-12-15',
              levyStatus: 'paid',
              walletAddress: testWalletAddress,
              issuedAt: DateTime.now(),
            ),
          );
    });

    tearDown(() {
      container.dispose();
      realtimeService.dispose();
    });

    test('L2: Dynamic QR start connects realtime channel and handles incoming merchant scan', () async {
      final controller = container.read(verificationControllerProvider.notifier);

      // 1. Wisatawan membuka Dynamic QR
      await controller.startOrRefreshQr(
        btid: testBtid,
        walletAddress: testWalletAddress,
        privateKeyHex: testPrivateKeyHex,
      );

      final qrState = container.read(verificationControllerProvider);
      expect(qrState.currentQrToken, isNotEmpty);
      expect(qrState.tokenCode, startsWith('QRT-'));
      expect(qrState.remainingSeconds, inInclusiveRange(44, 45));
      expect(qrState.isQrExpired, isFalse);

      // 2. Merchant scanner memindai QR dan menyiarkan permintaan verifikasi
      final incomingMerchantRequest = {
        'action': 'consent_request',
        'requestId': 'TX-LIVE-1001',
        'merchantId': 'MCH-1042',
        'merchantName': 'Bali Ocean Resort',
        'merchantCategory': 'hotel',
        'staffName': 'Kadek Sari',
        'staffRole': 'Front Desk Agent',
        'purposeTemplate': 'hotel_checkin',
        'requestedFields': ['name', 'nationality', 'id_validity', 'stay_valid'],
        'retentionPolicy': '30 days',
        'expiresAt': DateTime.now().add(const Duration(minutes: 3)).toIso8601String(),
      };

      mockSocket.simulateIncomingMessage(jsonEncode(incomingMerchantRequest));
      await pumpEventQueue();

      // State activeConsentRequest otomatis terisi dari kanal real-time (bukan simulasi timer)
      final stateWithRequest = container.read(verificationControllerProvider);
      expect(stateWithRequest.activeConsentRequest, isNotNull);
      expect(stateWithRequest.activeConsentRequest!.requestId, equals('TX-LIVE-1001'));
      expect(stateWithRequest.activeConsentRequest!.merchantName, equals('Bali Ocean Resort'));

      // 3. Wisatawan menyetujui (Approve) consent
      final actor = ActorRef.fromCredential(
        walletAddress: testWalletAddress,
        btidNumber: testBtid,
        name: 'Ayu Lestari',
      );

      final audit = await controller.approveConsent(
        request: stateWithRequest.activeConsentRequest!,
        approvedData: {
          'btid': testBtid,
          'fullName': 'Ayu Lestari',
          'walletAddress': testWalletAddress,
          'name': 'Ayu Lestari',
          'nationality': 'IDN',
        },
        privateKeyHex: testPrivateKeyHex,
        actor: actor,
      );

      expect(audit.status, equals('Approved'));
      expect(audit.syncStatus, equals('synced'));

      // 4. Setelah disetujui, activeConsentRequest dibersihkan
      final stateAfterApprove = container.read(verificationControllerProvider);
      expect(stateAfterApprove.activeConsentRequest, isNull);
      expect(stateAfterApprove.auditHistory.any((a) => a.txRef == 'TX-LIVE-1001'), isTrue);
    });

    test('L2: Rejecting consent sets audit status Rejected and clears active consent request', () async {
      final controller = container.read(verificationControllerProvider.notifier);

      final testRequest = ConsentRequestModel(
        requestId: 'TX-REJECT-99',
        merchantId: 'MCH-3311',
        merchantName: 'Bali Coffee House',
        merchantCategory: 'cafe',
        staffName: 'Wayan Putra',
        staffRole: 'Barista',
        purposeTemplate: 'age_check',
        requestedFields: ['over18'],
        retentionPolicy: 'Instant check',
        expiresAt: DateTime.now().add(const Duration(minutes: 3)),
      );

      controller.handleIncomingConsentRequest(testRequest);
      expect(container.read(verificationControllerProvider).activeConsentRequest, isNotNull);

      final audit = await controller.rejectConsent(
        request: testRequest,
        approvedData: {'btid': testBtid, 'fullName': 'Ayu Lestari'},
        privateKeyHex: testPrivateKeyHex,
      );

      expect(audit.status, equals('Rejected'));
      expect(container.read(verificationControllerProvider).activeConsentRequest, isNull);
    });
  });
}
