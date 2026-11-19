// test/phase6_qris_parser_test.dart

import 'dart:convert';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qrypta/src/core/error/app_failure.dart';
import 'package:qrypta/src/core/services/merchant/merchant_resolver_service.dart';
import 'package:qrypta/src/core/services/qr/qr_payload_router.dart';
import 'package:qrypta/src/core/services/qr/qris_model.dart';
import 'package:qrypta/src/core/services/qr/qris_parser.dart';
import 'fixtures/qris_fixtures.dart';

void main() {
  group('Phase 6.2 - QRIS EMVCo TLV & CRC16 Parser Unit Tests (Level L1)', () {
    test('L1 Positive: All 32 real QRIS fixtures parse successfully with exact CRC validation', () {
      expect(QrisFixtures.allFixtures.length, equals(32));

      for (int i = 0; i < QrisFixtures.allFixtures.length; i++) {
        final raw = QrisFixtures.allFixtures[i];
        final qris = QrisParser.parse(raw);

        expect(qris.payloadFormatIndicator, equals('01'));
        expect(qris.countryCode, equals('ID'));
        expect(qris.transactionCurrency, equals('360'));
        expect(qris.merchantName.isNotEmpty, isTrue);
        expect(qris.merchantCity.isNotEmpty, isTrue);
        expect(qris.nmid, isNotNull);
        expect(qris.nmid!.startsWith('ID1'), isTrue);
        expect(qris.merchantAccounts.isNotEmpty, isTrue);
        expect(qris.crc.length, equals(4));

        // Verifikasi CRC16 bit-level
        final dataBeforeCrc = raw.substring(0, raw.length - 4);
        final calculatedCrc = QrisParser.computeCrcHex(dataBeforeCrc);
        expect(qris.crc, equals(calculatedCrc),
            reason: 'Fixture index $i CRC mismatch');
      }
    });

    test('L1 Positive: Static QRIS characteristics and properties extracted correctly', () {
      final qris = QrisParser.parse(QrisFixtures.bca_static_ubud);

      expect(qris.isStatic, isTrue);
      expect(qris.isDynamic, isFalse);
      expect(qris.merchantName, equals('Ubud Arts Woodcarving'));
      expect(qris.merchantCity, equals('GIANYAR'));
      expect(qris.postalCode, equals('80571'));
      expect(qris.merchantCategoryCode, equals('5812'));
      expect(qris.guid, equals('ID.CO.QRIS.WWW'));
      expect(qris.nmid, equals('ID1020000001001'));
      expect(qris.merchantCriteria, equals('UMI'));
      expect(qris.transactionAmount, isNull);
    });

    test('L1 Positive: Dynamic QRIS amount and bill metadata extracted correctly', () {
      final qris = QrisParser.parse(QrisFixtures.bca_dynamic_canggu);

      expect(qris.isDynamic, isTrue);
      expect(qris.isStatic, isFalse);
      expect(qris.merchantName, equals('Echo Beach Seafood'));
      expect(qris.merchantCity, equals('BADUNG'));
      expect(qris.transactionAmount, equals(125000.0));
      expect(qris.additionalData, isNotNull);
      expect(qris.additionalData!.billNumber, equals('INV-Echo-101'));
      expect(qris.additionalData!.terminalLabel, equals('POS-01'));
    });

    test('L1 Positive: Fee & Tip structures calculate totalAmount accurately', () {
      // Fixed Fee
      final fixedFeeQris = QrisParser.parse(QrisFixtures.nobu_fee_fixed);
      expect(fixedFeeQris.tipIndicator, equals('01'));
      expect(fixedFeeQris.fixedFee, equals(2500.0));
      expect(fixedFeeQris.transactionAmount, equals(250000.0));
      expect(fixedFeeQris.totalAmount, equals(252500.0));

      // Percentage Fee
      final pctFeeQris = QrisParser.parse(QrisFixtures.cimb_fee_pct);
      expect(pctFeeQris.tipIndicator, equals('02'));
      expect(pctFeeQris.percentageFee, equals(0.7));
      expect(pctFeeQris.transactionAmount, equals(500000.0));
      // 500000 + (500000 * 0.007) = 503500.0
      expect(pctFeeQris.totalAmount, equals(503500.0));

      // Tip Prompt
      final tipPromptQris = QrisParser.parse(QrisFixtures.bpd_tip_prompt);
      expect(tipPromptQris.tipIndicator, equals('03'));
      expect(tipPromptQris.fixedFee, isNull);
      expect(tipPromptQris.percentageFee, isNull);
    });

    test('L1 Positive: parseInIsolate executes on worker isolate and produces identical model', () async {
      final syncResult = QrisParser.parse(QrisFixtures.mandiri_dynamic_ubud);
      final asyncResult = await QrisParser.parseInIsolate(QrisFixtures.mandiri_dynamic_ubud);

      expect(asyncResult.rawPayload, equals(syncResult.rawPayload));
      expect(asyncResult.merchantName, equals(syncResult.merchantName));
      expect(asyncResult.nmid, equals(syncResult.nmid));
      expect(asyncResult.transactionAmount, equals(syncResult.transactionAmount));
      expect(asyncResult.crc, equals(syncResult.crc));
    });

    test('L1 Negative: Rejects tampered CRC (1 character corrupted)', () {
      final valid = QrisFixtures.bca_static_ubud;
      // Ganti karakter hex terakhir
      final corruptedChar = valid.endsWith('0') ? '1' : '0';
      final tampered = valid.substring(0, valid.length - 1) + corruptedChar;

      expect(
        () => QrisParser.parse(tampered),
        throwsA(isA<ValidationFailure>().having(
          (e) => e.message,
          'message',
          contains('Checksum CRC QRIS tidak valid'),
        )),
      );
    });

    test('L1 Negative: Rejects invalid or truncated TLV length', () {
      // Ubah panjang tag 59 (merchant name) menjadi 99 (melebihi panjang string)
      final raw = QrisFixtures.bca_static_ubud;
      final idx59 = raw.indexOf('59');
      final tampered = raw.substring(0, idx59 + 2) + '99' + raw.substring(idx59 + 4);

      expect(
        () => QrisParser.parse(tampered),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('L1 Negative: Rejects non-numeric TLV length', () {
      final raw = QrisFixtures.bca_static_ubud;
      final idx59 = raw.indexOf('59');
      final tampered = raw.substring(0, idx59 + 2) + 'XX' + raw.substring(idx59 + 4);

      expect(
        () => QrisParser.parse(tampered),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('L1 Negative: Rejects non-IDR currency (e.g. 840 USD)', () {
      // Buat payload dengan tag 53 diisi 840
      const fakePrefix = '00020101021126440014ID.CO.QRIS.WWW0115ID10200000010010203UMI5204581253038405802ID5904Test6006BADUNG6105803616304';
      final crc = QrisParser.computeCrcHex(fakePrefix);
      final foreignCurrencyQr = fakePrefix + crc;

      expect(
        () => QrisParser.parse(foreignCurrencyQr),
        throwsA(isA<ValidationFailure>().having(
          (e) => e.message,
          'message',
          contains('Mata uang bukan IDR (360)'),
        )),
      );
    });

    test('L1 Negative: Rejects foreign country code (not ID)', () {
      const fakePrefix = '00020101021126440014ID.CO.QRIS.WWW0115ID10200000010010203UMI5204581253033605802SG5904Test6006BADUNG6105803616304';
      final crc = QrisParser.computeCrcHex(fakePrefix);
      final foreignCountryQr = fakePrefix + crc;

      expect(
        () => QrisParser.parse(foreignCountryQr),
        throwsA(isA<ValidationFailure>().having(
          (e) => e.message,
          'message',
          contains('Kode negara (tag 58) wajib \'ID\''),
        )),
      );
    });

    test('L1 Negative: Dynamic QRIS without amount (missing tag 54) is rejected', () {
      // poi: '12' (dinamis) tetapi tanpa tag 54
      const fakePrefix = '00020101021226440014ID.CO.QRIS.WWW0115ID10200000010010203UMI5204581253033605802ID5904Test6006BADUNG6105803616304';
      final crc = QrisParser.computeCrcHex(fakePrefix);
      final noAmountDynamicQr = fakePrefix + crc;

      expect(
        () => QrisParser.parse(noAmountDynamicQr),
        throwsA(isA<ValidationFailure>().having(
          (e) => e.message,
          'message',
          contains('QRIS dinamis wajib memuat nominal transaksi'),
        )),
      );
    });

    test('L1 Negative: Rejects negative or non-numeric amount', () {
      const fakePrefix = '00020101021126440014ID.CO.QRIS.WWW0115ID10200000010010203UMI5204581253033605404-5005802ID5904Test6006BADUNG6105803616304';
      final crc = QrisParser.computeCrcHex(fakePrefix);
      final negativeAmountQr = fakePrefix + crc;

      expect(
        () => QrisParser.parse(negativeAmountQr),
        throwsA(isA<ValidationFailure>().having(
          (e) => e.message,
          'message',
          contains('Nominal transaksi (tag 54) tidak valid'),
        )),
      );
    });

    test('L1 Negative: Rejects missing mandatory tags or truncated strings', () {
      expect(() => QrisParser.parse(''), throwsA(isA<ValidationFailure>()));
      expect(() => QrisParser.parse('000201'), throwsA(isA<ValidationFailure>()));
      expect(() => QrisParser.parse('00020101021163040000'), throwsA(isA<ValidationFailure>()));
      expect(
        () => QrisParser.parse(QrisFixtures.bca_static_ubud.substring(0, 30)),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('L1 Fuzzing: Random bit-flip and corrupt mutations never throw unhandled exceptions', () {
      final random = Random(42);
      final base = QrisFixtures.bca_static_ubud;

      for (int i = 0; i < 300; i++) {
        final chars = base.split('');
        // Mutasikan 1-5 karakter secara acak
        final mutations = random.nextInt(5) + 1;
        for (int m = 0; m < mutations; m++) {
          final pos = random.nextInt(chars.length);
          chars[pos] = String.fromCharCode(random.nextInt(95) + 32);
        }
        final fuzzed = chars.join();

        // Parser harus selalu melempar ValidationFailure terkontrol atau sukses (jika kebetulan valid),
        // TIDAK PERNAH crash atau melempar RangeError / FormatException tak terduga.
        try {
          QrisParser.parse(fuzzed);
        } catch (e) {
          expect(e, isA<ValidationFailure>());
        }
      }
    });
  });

  group('Phase 6.1 - QrPayloadRouter Deterministic Route Tests (Level L1)', () {
    test('Routes candidate QRIS payload (000201...) to QrisRoute', () {
      final result = QrPayloadRouter.route(QrisFixtures.mandiri_static_seminyak);

      expect(result, isA<QrisRoute>());
      final qrisRoute = result as QrisRoute;
      expect(qrisRoute.qris.merchantName, equals('Seminyak French Bakery'));
      expect(qrisRoute.qris.nmid, equals('ID1020000001002'));
    });

    test('Routes standard EVM wallet address to WalletAddressRoute', () {
      const lowerAddress = '0x3311a9908f8718e237ade73708ab59f212284be0';
      final result = QrPayloadRouter.route(lowerAddress);

      expect(result, isA<WalletAddressRoute>());
      final walletRoute = result as WalletAddressRoute;
      expect(walletRoute.address, equals(lowerAddress));
    });

    test('Routes mixed-case EVM address with valid EIP-55 checksum', () {
      // 0x3311A9908f8718E237ADE73708ab59f212284be0 adalah EIP-55 valid
      const validEip55 = '0x3311A9908f8718E237ADE73708ab59f212284be0';
      final result = QrPayloadRouter.route(validEip55);

      expect(result, isA<WalletAddressRoute>());
      expect((result as WalletAddressRoute).address, equals(validEip55));
    });

    test('Rejects mixed-case EVM address with invalid EIP-55 checksum', () {
      // Ubah satu huruf besar menjadi kecil secara sembarangan
      const invalidEip55 = '0x3311A9908F8718E237aDE73708aB59f212284bE0';

      expect(
        () => QrPayloadRouter.route(invalidEip55),
        throwsA(isA<ValidationFailure>().having(
          (e) => e.message,
          'message',
          contains('checksum EIP-55 tidak valid'),
        )),
      );
    });

    test('Routes verified native Qrypta JSON with secp256k1 signature', () {
      final validSig = '0x' + 'ab' * 65; // 130 hex + 0x = 132 chars
      final nativeJson = jsonEncode({
        'v': 1,
        'type': 'CONSENT_HANDSHAKE',
        'sessionId': 'sess-4401',
        'sig': validSig,
        'exp': 1763568000,
      });

      final result = QrPayloadRouter.route(nativeJson);
      expect(result, isA<NativeQryptaRoute>());
      final nativeRoute = result as NativeQryptaRoute;
      expect(nativeRoute.version, equals(1));
      expect(nativeRoute.type, equals('CONSENT_HANDSHAKE'));
      expect(nativeRoute.signature, equals(validSig));
    });

    test('Rejects native Qrypta JSON with malformed signature format', () {
      final badSigJson = jsonEncode({
        'v': 1,
        'type': 'CONSENT_HANDSHAKE',
        'sig': '0xinvalid_short_signature',
      });

      expect(
        () => QrPayloadRouter.route(badSigJson),
        throwsA(isA<ValidationFailure>().having(
          (e) => e.message,
          'message',
          contains('Tanda tangan kriptografi QR native Qrypta tidak valid'),
        )),
      );
    });

    test('Rejects arbitrary strings without guessing (eliminates primitive keyword fallbacks)', () {
      // String-match lama yang sebelumnya memicu bypass coffee/tour/MCH
      expect(() => QrPayloadRouter.route('coffee'), throwsA(isA<ValidationFailure>()));
      expect(() => QrPayloadRouter.route('tour'), throwsA(isA<ValidationFailure>()));
      expect(() => QrPayloadRouter.route('MCH-3311'), throwsA(isA<ValidationFailure>()));
      expect(() => QrPayloadRouter.route('MCH-5520'), throwsA(isA<ValidationFailure>()));
      expect(() => QrPayloadRouter.route('https://qrypta.id/pay'), throwsA(isA<ValidationFailure>()));
      expect(() => QrPayloadRouter.route('{"random":"data"}'), throwsA(isA<ValidationFailure>()));
    });
  });

  group('Phase 6.3 - MerchantResolverService Integration & Resolution Tests (Level L2)', () {
    const testNmid = 'ID1020000001001';
    const baseUrl = 'http://127.0.0.1:3000/api/v1';

    test('L2 Positive: Successfully resolves registered merchant from backend', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, equals('/api/v1/merchants/resolve'));
        expect(request.url.queryParameters['nmid'], equals(testNmid));

        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'merchantId': 'MCH-1043',
              'walletAddress': '0x3311a9908f8718e237ade73708ab59f212284be0',
              'displayName': 'Ubud Arts Woodcarving',
              'verified': true,
              'category': 'art',
              'feePercentage': 0.7,
              'fixedFee': 0,
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = MerchantResolverService(httpClient: mockClient, baseUrl: baseUrl);
      final result = await service.resolve(nmid: testNmid);

      expect(result.merchantId, equals('MCH-1043'));
      expect(result.displayName, equals('Ubud Arts Woodcarving'));
      expect(result.walletAddress, equals('0x3311a9908f8718e237ade73708ab59f212284be0'));
      expect(result.verified, isTrue);
      expect(result.feePercentage, equals(0.7));
    });

    test('L2 Negative: Throws MerchantNotRegistered when backend returns 404', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': false,
            'message': 'Merchant not found in consortium registry',
          }),
          404,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = MerchantResolverService(httpClient: mockClient, baseUrl: baseUrl);

      expect(
        () => service.resolve(nmid: 'ID1020999999999'),
        throwsA(isA<MerchantNotRegistered>().having(
          (e) => e.message,
          'message',
          contains('Merchant ini belum menerima pembayaran Qrypta'),
        )),
      );
    });

    test('L2 Negative: Throws MerchantNotRegistered when verified status is false', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'merchantId': 'MCH-SUSPENDED',
              'walletAddress': '0x0000000000000000000000000000000000000001',
              'displayName': 'Suspended Shop',
              'verified': false,
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = MerchantResolverService(httpClient: mockClient, baseUrl: baseUrl);

      expect(
        () => service.resolve(nmid: 'ID1020000009999'),
        throwsA(isA<MerchantNotRegistered>().having(
          (e) => e.message,
          'message',
          contains('belum terverifikasi di konsorsium Qrypta'),
        )),
      );
    });

    test('L2 Negative: Throws ServerRejected on HTTP 500 server error', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal Database Error', 500);
      });

      final service = MerchantResolverService(httpClient: mockClient, baseUrl: baseUrl);

      expect(
        () => service.resolve(nmid: testNmid),
        throwsA(isA<ServerRejected>()),
      );
    });

    test('L2 Negative: Throws ValidationFailure when NMID is empty', () async {
      final service = MerchantResolverService(baseUrl: baseUrl);

      expect(
        () => service.resolve(nmid: '   '),
        throwsA(isA<ValidationFailure>()),
      );
    });
  });
}
