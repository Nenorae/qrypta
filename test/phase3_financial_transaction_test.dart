// test/phase3_financial_transaction_test.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qrypta/src/core/data/models/btid_credential_model.dart';
import 'package:qrypta/src/core/data/models/token_model.dart';
import 'package:qrypta/src/core/error/app_failure.dart';
import 'package:qrypta/src/core/transaction/state_machine/tx_intent_repository.dart';
import 'package:qrypta/src/core/transaction/state_machine/tx_state.dart';
import 'package:qrypta/src/core/transaction/state_machine/tx_state_machine.dart';
import 'package:qrypta/src/core/utils/formatters.dart';
import 'package:qrypta/src/core/services/authentication_service.dart';
import 'package:qrypta/src/features/authentication/presentation/providers/btid_provider.dart';
import 'package:qrypta/src/features/tokens/presentation/providers/token_provider.dart';
import 'package:qrypta/src/features/transaction/logic/payment_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AuthenticationService.debugBypassAuth = true;
  });

  tearDown(() {
    AuthenticationService.debugBypassAuth = null;
  });

  group('Phase 3.2: Single-Source Real IDRT Balance (Level L1)', () {
    test('idrtBalanceProvider reads directly from token models without fake 2.480.000', () {
      final container = ProviderContainer(
        overrides: [
          tokenNotifierProvider.overrideWith((ref) => _FakeTokenNotifier([
            TokenModel(
              contractAddress: '0x3B3D239855Fe20326B7484B79fA059B76A035048',
              symbol: 'IDRT',
              name: 'Rupiah Token',
              decimals: 18,
              balance: BigInt.parse('500000000000000000000000'), // 500.000 IDRT
            ),
          ])),
        ],
      );

      final balanceAsync = container.read(idrtBalanceProvider);
      expect(balanceAsync.value, equals(BigInt.parse('500000000000000000000000')));

      final formatted = container.read(idrtBalanceFormattedProvider);
      expect(formatted, equals('Rp 500.000'));
      expect(formatted, isNot(contains('2.480.000')));
    });

    test('idrtBalanceProvider formats zero balance accurately as Rp 0', () {
      final container = ProviderContainer(
        overrides: [
          tokenNotifierProvider.overrideWith((ref) => _FakeTokenNotifier([
            TokenModel(
              contractAddress: '0x3B3D239855Fe20326B7484B79fA059B76A035048',
              symbol: 'IDRT',
              name: 'Rupiah Token',
              decimals: 18,
              balance: BigInt.zero,
            ),
          ])),
        ],
      );

      final balanceAsync = container.read(idrtBalanceProvider);
      expect(balanceAsync.value, equals(BigInt.zero));

      final formatted = container.read(idrtBalanceFormattedProvider);
      expect(formatted, equals('Rp 0'));
    });

    test('formatBigInt avoids IEEE-754 precision loss for 18 decimals', () {
      final wei = BigInt.parse('150000000000000000000000'); // 150.000 IDRT
      final formatted = formatBigInt(wei, 18, isCurrency: true);
      expect(formatted, equals('Rp 150.000'));
    });
  });

  group('Phase 3.1 & 3.3: Payment Validation & Receipt Data (Level L1)', () {
    test('LevyReceiptData generates strict TD3 44-character MRZ lines', () {
      final line1 = LevyReceiptData.generateMrzLine1('LVY-448102', 150000);
      expect(line1.length, equals(44));
      expect(line1, startsWith('LEVY<<LVY<448102<<IDR150000'));

      final line2 = LevyReceiptData.generateMrzLine2('BTID-2026-4471-0938');
      expect(line2.length, equals(44));
      expect(line2, startsWith('BTID<<BTID<2026<4471<0938<<PAID'));
    });

    test('BtidCredentialModel accurately stores real levyTxHash', () {
      final cred = BtidCredentialModel(
        btidNumber: 'BTID-TEST-001',
        fullName: 'Jane Doe',
        nationality: 'AUS',
        passportMasked: '••••••123',
        dob: '1995-05-20',
        docExpiry: '2030-05-20',
        visaType: 'B213',
        arrivalDate: '2026-11-01',
        stayExpiry: '2026-12-01',
        levyStatus: 'paid',
        levyReceiptRef: 'LVY-998877',
        levyTxHash: '0xabc1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
        walletAddress: '0x1111111111111111111111111111111111111111',
        issuedAt: DateTime.now(),
      );

      expect(cred.isLevyPaid, isTrue);
      expect(cred.levyTxHash, startsWith('0xabc123'));
      expect(cred.levyTxHash, isNot(equals('0x7b2f8a1e9c4d3b5a7e6f8a9b0c1d2e3f4a5b6c7d')));
    });

    test('payTouristLevy rejects non-wallet methods without fake simulation (F-03b)', () async {
      final container = ProviderContainer(
        overrides: [
          btidCredentialProvider.overrideWith((ref) => _FakeBtidNotifier(
            BtidCredentialModel(
              btidNumber: 'BTID-TEST-002',
              fullName: 'John Smith',
              nationality: 'USA',
              passportMasked: '••••••456',
              dob: '1990-01-01',
              docExpiry: '2030-01-01',
              visaType: 'VOA',
              arrivalDate: '2026-11-10',
              stayExpiry: '2026-12-10',
              levyStatus: 'unpaid',
              walletAddress: '0x2222222222222222222222222222222222222222',
              issuedAt: DateTime.now(),
            ),
          )),
        ],
      );

      final notifier = container.read(paymentControllerProvider.notifier);

      expect(
        () => notifier.payTouristLevy(paymentMethod: 'card'),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('payTouristLevy rejects execution when BTID is already paid', () async {
      final container = ProviderContainer(
        overrides: [
          btidCredentialProvider.overrideWith((ref) => _FakeBtidNotifier(
            BtidCredentialModel(
              btidNumber: 'BTID-TEST-003',
              fullName: 'Alice Walker',
              nationality: 'GBR',
              passportMasked: '••••••789',
              dob: '1992-03-15',
              docExpiry: '2032-03-15',
              visaType: 'VOA',
              arrivalDate: '2026-11-05',
              stayExpiry: '2026-12-05',
              levyStatus: 'paid',
              walletAddress: '0x3333333333333333333333333333333333333333',
              issuedAt: DateTime.now(),
            ),
          )),
        ],
      );

      final notifier = container.read(paymentControllerProvider.notifier);

      expect(
        () => notifier.payTouristLevy(paymentMethod: 'wallet'),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('payTouristLevy rejects execution when biometric authorization fails', () async {
      AuthenticationService.debugBypassAuth = false;

      final container = ProviderContainer(
        overrides: [
          btidCredentialProvider.overrideWith((ref) => _FakeBtidNotifier(
            BtidCredentialModel(
              btidNumber: 'BTID-TEST-004',
              fullName: 'Bob Dylan',
              nationality: 'USA',
              passportMasked: '••••••321',
              dob: '1975-05-24',
              docExpiry: '2030-05-24',
              visaType: 'VOA',
              arrivalDate: '2026-11-01',
              stayExpiry: '2026-12-01',
              levyStatus: 'unpaid',
              walletAddress: '0x4444444444444444444444444444444444444444',
              issuedAt: DateTime.now(),
            ),
          )),
        ],
      );

      final notifier = container.read(paymentControllerProvider.notifier);

      expect(
        () => notifier.payTouristLevy(paymentMethod: 'wallet'),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('TxStateMachine enforces on-chain intent persistence before broadcast', () async {
      final repo = TxIntentRepository();
      final machine = TxStateMachine(repository: repo);

      final intent = await machine.startIntent(
        kind: 'levy',
        ref: 'LVY-STATE-001',
        from: '0x1111111111111111111111111111111111111111',
        to: '0x2222222222222222222222222222222222222222',
        amount: '150000000000000000000000',
      );

      expect(intent.state, equals(TxState.preparing));
      expect(intent.txHash, isNull);

      await machine.transitionTo(TxState.signing);
      await machine.transitionTo(TxState.broadcasting);
      await machine.transitionTo(TxState.pending, txHash: '0xrealhash123');

      final saved = await repo.getIntent(intent.intentId);
      expect(saved?.state, equals(TxState.pending));
      expect(saved?.txHash, equals('0xrealhash123'));
    });
  });
}

class _FakeTokenNotifier extends StateNotifier<AsyncValue<List<TokenModel>>>
    implements TokenNotifier {
  _FakeTokenNotifier(List<TokenModel> tokens) : super(AsyncValue.data(tokens));

  @override
  Future<void> fetchUserTokens() async {}
}

class _FakeBtidNotifier extends StateNotifier<BtidCredentialModel?>
    implements BtidCredentialNotifier {
  _FakeBtidNotifier(super.initial);

  @override
  Future<void> loadCredential() async {}

  @override
  Future<void> saveCredential(BtidCredentialModel credential) async {
    state = credential;
  }

  @override
  Future<void> updateLevyStatus(String status, {String? receiptRef, String? txHash}) async {
    if (state == null) return;
    state = state!.copyWith(
      levyStatus: status,
      levyReceiptRef: receiptRef ?? state!.levyReceiptRef,
      levyTxHash: txHash ?? state!.levyTxHash,
    );
  }

  @override
  Future<void> clearCredential() async {
    state = null;
  }
}
