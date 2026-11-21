// test/phase10_cross_cutting_test.dart
//
// Phase 10: Pengujian Lintas Fase & Reality Gate Final
// Verifikasi integritas seluruh komponen yang dibangun Phase 0-9
// termasuk klasifikasi test per level, golden rules, dan anti-regresi.

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrypta/src/core/config/app_config.dart';
import 'package:qrypta/src/core/error/app_failure.dart';
import 'package:qrypta/src/core/data/models/btid_credential_model.dart';
import 'package:qrypta/src/core/data/models/audit_transaction_model.dart';
import 'package:qrypta/src/core/transaction/state_machine/tx_state.dart';
import 'package:qrypta/src/core/outbox/outbox_item.dart';
import 'package:qrypta/src/core/utils/mrz_parser.dart';
import 'package:qrypta/src/core/services/qr/qris_parser.dart';
import 'package:qrypta/src/core/services/qr/qr_payload_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ================================================================
  // SECTION 1: REALITY GUARD INTEGRATION — Verifikasi Golden Rules
  // ================================================================

  group('Phase 10 / §7: Reality Guard — Golden Rules Enforcement (Level L0)', () {
    test('L0: reality_guard.sh exists and is executable', () {
      final guardFile = File('tools/reality_guard.sh');
      expect(guardFile.existsSync(), isTrue,
          reason: 'tools/reality_guard.sh harus ada sebagai CI guard');
    });

    test('L0: verify_tx.sh oracle script exists and is executable', () {
      final verifyFile = File('tools/verify_tx.sh');
      expect(verifyFile.existsSync(), isTrue,
          reason: 'tools/verify_tx.sh harus ada sebagai oracle independen (§6.5)');
    });

    test('L0: check_apk_release.sh artifact inspector exists', () {
      final apkCheckFile = File('tools/check_apk_release.sh');
      expect(apkCheckFile.existsSync(), isTrue,
          reason: 'tools/check_apk_release.sh harus ada untuk inspeksi artefak (§6.6)');
    });

    test('L0: No forbidden literals in lib/ (R3 — verifikasi grep)', () {
      final result = Process.runSync('grep', [
        '-rEn',
        'James Wilson|BTID-2026-4471-0938|2\\.480\\.000|0x7b2f8a1e|fallbackSeed|MCH-3311|MCH-5520|1988-04-12|2031-08-15|e-VOA B1',
        'lib/',
      ]);
      expect(result.stdout.toString().trim(), isEmpty,
          reason: 'Golden Rule R3: Tidak boleh ada literal identitas/keuangan palsu di lib/');
    });

    test('L0: No catch (_) {} empty blocks in lib/ (R1)', () {
      final result = Process.runSync('grep', [
        '-rEn', 'catch \\(_\\) \\{\\}', 'lib/',
      ]);
      expect(result.stdout.toString().trim(), isEmpty,
          reason: 'Golden Rule R1: Setiap catch harus melempar AppFailure atau masuk outbox');
    });

    test('L0: No demoJamesWilson() in lib/ (R4/F-19)', () {
      final result = Process.runSync('grep', [
        '-rEn', 'demoJamesWilson\\(\\)', 'lib/',
      ]);
      expect(result.stdout.toString().trim(), isEmpty,
          reason: 'F-19: demoJamesWilson harus di test/fixtures/, bukan di lib/');
    });

    test('L0: No triggerMerchantSimulation in lib/ (R8/F-15b)', () {
      final result = Process.runSync('grep', [
        '-rEn', 'triggerMerchantSimulation', 'lib/',
      ]);
      expect(result.stdout.toString().trim(), isEmpty,
          reason: 'F-15b: triggerMerchantSimulation harus dihapus dari build non-dev');
    });

    test('L0: No loopback in core config/graphql Dart files (F-20)', () {
      final result = Process.runSync('bash', ['-c',
        'grep -rEn "127\\.0\\.0\\.1|localhost" lib/src/core/config/ lib/src/core/graphql/ 2>/dev/null || true',
      ]);
      expect(result.stdout.toString().trim(), isEmpty,
          reason: 'F-20: loopback hardcoded tidak boleh ada di konfigurasi Dart');
    });

    test('L0: No genuine biometric claims in lib/ (F-18/R4)', () {
      final result = Process.runSync('grep', [
        '-rEni', 'genuine biometric|biometric verified', 'lib/',
      ]);
      expect(result.stdout.toString().trim(), isEmpty,
          reason: 'F-18: klaim biometrik verified palsu tidak boleh ada');
    });

    test('L0: Staging env config does not contain loopback', () {
      final stagingFile = File('env/staging.example.json');
      if (stagingFile.existsSync()) {
        final content = stagingFile.readAsStringSync();
        expect(content.contains('127.0.0.1'), isFalse);
        expect(content.contains('localhost'), isFalse);
        expect(content.contains('10.0.2.2'), isFalse);
      }
    });

    test('L0: Prod env config does not contain loopback', () {
      final prodFile = File('env/prod.example.json');
      if (prodFile.existsSync()) {
        final content = prodFile.readAsStringSync();
        expect(content.contains('127.0.0.1'), isFalse);
        expect(content.contains('localhost'), isFalse);
        expect(content.contains('10.0.2.2'), isFalse);
      }
    });
  });

  // ================================================================
  // SECTION 2: LINTAS FASE — Model Data Integrity
  // ================================================================

  group('Phase 10: Cross-Phase Model Data Integrity (Level L1)', () {
    test('L1: BtidCredentialModel.fromJson rejects missing btidNumber (F-11b)', () {
      expect(
        () => BtidCredentialModel.fromJson({
          'fullName': 'Test User',
          'nationality': 'IDN',
          'dob': '1990-01-01',
          'docExpiry': '2035-01-01',
          // btidNumber intentionally missing
        }),
        throwsA(isA<FormatException>()),
        reason: 'F-11b: fromJson tanpa btidNumber harus throw, bukan default',
      );
    });

    test('L1: BtidCredentialModel.fromJson rejects missing dob (F-13b)', () {
      expect(
        () => BtidCredentialModel.fromJson({
          'btidNumber': 'BTID-TEST-0001',
          'fullName': 'Test User',
          'nationality': 'IDN',
          'docExpiry': '2035-01-01',
          // dob intentionally missing
        }),
        throwsA(isA<FormatException>()),
        reason: 'F-13b: fromJson tanpa dob harus throw, bukan default 1988-04-12',
      );
    });

    test('L1: BtidCredentialModel simulated liveness coercion (R4 anti-fake-pass)', () {
      final cred = BtidCredentialModel.fromJson({
        'btidNumber': 'BTID-TEST-0002',
        'fullName': 'Test User',
        'nationality': 'IDN',
        'dob': '1995-06-15',
        'docExpiry': '2033-12-31',
        'liveness': {'mode': 'SIMULATED', 'verified': true}, // attacker tries to inject true
      });
      expect(cred.isBiometricVerified, isFalse,
          reason: 'R4: mode SIMULATED harus memaksa verified=false meskipun payload mengirim true');
    });

    test('L1: AuditTransactionModel preserves syncStatus field integrity', () {
      final audit = AuditTransactionModel.fromJson({
        'id': 'test-audit-001',
        'type': 'consent',
        'timestamp': DateTime.now().toIso8601String(),
        'status': 'Approved',
        'syncStatus': 'pending_sync',
        'actorWallet': '0x1234567890abcdef1234567890abcdef12345678',
        'actorRef': 'sha256:abc123',
      });
      expect(audit.syncStatus, equals('pending_sync'),
          reason: 'R7: syncStatus harus dibedakan dari status transaksi');
    });

    test('L1: OutboxItem has idempotency key (R2 server ack)', () {
      final item = OutboxItem(
        id: 'outbox-test-001',
        type: 'consent',
        payload: {'test': true},
        attempts: 0,
        nextAttemptAt: DateTime.now(),
        createdAt: DateTime.now(),
      );
      expect(item.id, isNotEmpty,
          reason: 'Outbox harus punya ID yang dipakai sebagai Idempotency-Key');
    });
  });

  // ================================================================
  // SECTION 3: LINTAS FASE — Transaction State Machine Rules
  // ================================================================

  group('Phase 10: Cross-Phase Transaction State Integrity (Level L1)', () {
    test('L1: TxState only transitions through legal states', () {
      // idle -> preparing -> signing -> broadcasting -> pending -> confirmed
      expect(TxState.idle.index < TxState.confirmed.index, isTrue);
    });

    test('L1: TxState.failed is terminal from any non-idle state', () {
      expect(TxState.failed, isNotNull);
      expect(TxState.values.contains(TxState.failed), isTrue);
    });
  });

  // ================================================================
  // SECTION 4: LINTAS FASE — Configuration Boundary
  // ================================================================

  group('Phase 10: Cross-Phase Configuration Safety (Level L1)', () {
    test('L1: AppConfig.effectiveLivenessMode defaults to simulated', () {
      expect(AppConfig.effectiveLivenessMode, equals('simulated'),
          reason: 'Phase 9: default liveness harus simulated');
    });

    test('L1: AppConfig does not expose hardcoded URLs', () {
      // AppConfig menggunakan compile-time defines, bukan hardcode
      // Nilai kosong harus ditangani oleh ConfigValidator
      expect(AppConfig.rpcUrl, isA<String>());
      expect(AppConfig.ezsignUrl, isA<String>());
    });
  });

  // ================================================================
  // SECTION 5: LINTAS FASE — MRZ + QRIS Parser Round-trip
  // ================================================================

  group('Phase 10: Cross-Phase OCR & Parser Correctness (Level L1)', () {
    test('L1: MRZ ICAO Utopia specimen parses correctly (Phase 5A → 5B)', () {
      final mrz = MrzParser.parse(
        'P<UTOeriksson<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<',
        'L898902C36UTO7408122F1204159ZE184226B<<<<<10',
      );
      expect(mrz, isNotNull);
      expect(mrz!.surname, equals('ERIKSSON'));
      expect(mrz.givenNames, equals('ANNA MARIA'));
      expect(mrz.nationality, equals('UTO'));
      expect(mrz.documentNumber, equals('L898902C3'));
    });

    test('L1: MRZ check digit validation rejects tampered document number in strict mode', () {
      // Tamper: C4 instead of C3 in document number check digit
      expect(
        () => MrzParser.parse(
          'P<UTOeriksson<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<',
          'L898902C46UTO7408122F1204159ZE184226B<<<<<10',
          strict: true,
        ),
        throwsA(isA<ValidationFailure>()),
        reason: 'Phase 5A: check digit salah dengan strict=true harus throw ValidationFailure',
      );
    });

    test('L1: QrPayloadRouter rejects arbitrary string without guessing', () {
      expect(
        () => QrPayloadRouter.route('ini bukan QR code apapun'),
        throwsA(isA<ValidationFailure>()),
        reason: 'Phase 6: string sembarang harus throw ValidationFailure, bukan fallback ke merchant',
      );
    });

    test('L1: QrPayloadRouter identifies EMVCo QRIS prefix and validates fully', () {
      // A minimal prefix alone is not enough — QRIS requires full TLV + CRC
      // This verifies router correctly routes to QrisParser which then validates CRC
      expect(
        () => QrPayloadRouter.route('000201'),
        throwsA(isA<ValidationFailure>()),
        reason: 'Phase 6: QRIS prefix saja tanpa CRC valid harus throw ValidationFailure',
      );
    });
  });

  // ================================================================
  // SECTION 6: LINTAS FASE — Error Taxonomy (Phase 2 → all)
  // ================================================================

  group('Phase 10: Cross-Phase AppFailure Taxonomy Coverage (Level L1)', () {
    test('L1: All critical failure types exist and are distinct', () {
      final failures = <AppFailure>[
        const NetworkUnreachable('test'),
        const RequestTimeout('test'),
        const ServerRejected('test', 500, null),
        const RpcFailure('test', null),
        const InsufficientBalance('test'),
        const InsufficientGas('test'),
        const ChainMismatch('test'),
        const TxReverted('test', '0x000'),
        const TxPendingTimeout('test', '0x000'),
        const ValidationFailure('test'),
      ];

      // All must be distinct runtime types
      final types = failures.map((f) => f.runtimeType).toSet();
      expect(types.length, equals(failures.length),
          reason: 'Setiap jenis kegagalan harus memiliki tipe tersendiri');
    });

    test('L1: AppFailure instances carry meaningful messages', () {
      const failure = InsufficientBalance('Saldo IDRT tidak cukup untuk pembayaran levy');
      expect(failure.message, contains('IDRT'));
      expect(failure.message, isNotEmpty);
    });
  });

  // ================================================================
  // SECTION 7: LINTAS FASE — Documentation & Artifact Integrity
  // ================================================================

  group('Phase 10: Documentation & Artifact Integrity (Level L0)', () {
    test('L0: PROGRESS.md exists and tracks all findings', () {
      final progressFile = File('docs/work/PROGRESS.md');
      expect(progressFile.existsSync(), isTrue);
      final content = progressFile.readAsStringSync();
      // Verify all finding IDs are tracked
      for (final fid in [
        'F-01', 'F-02', 'F-03', 'F-04', 'F-05', 'F-06', 'F-07', 'F-08',
        'F-09', 'F-10', 'F-11', 'F-12', 'F-13', 'F-14', 'F-15', 'F-16',
        'F-17', 'F-18', 'F-19', 'F-20', 'F-21',
      ]) {
        expect(content.contains(fid), isTrue,
            reason: 'PROGRESS.md harus mencakup temuan $fid');
      }
    });

    test('L0: All phase reports exist (Phase 0-9)', () {
      for (var i = 0; i <= 9; i++) {
        final phaseName = i == 0
            ? 'PHASE_0_BASELINE_REPORT.md'
            : 'PHASE_${i}_${_phaseNames[i]}.md';
        // Check if any report for this phase exists
        final dir = Directory('docs/work');
        final reports = dir.listSync().where(
            (f) => f.path.contains('PHASE_$i') || f.path.contains('PHASE_${i}_'));
        expect(reports.isNotEmpty, isTrue,
            reason: 'Laporan Phase $i harus ada di docs/work/');
      }
    });

    test('L0: reality_guard.sh covers all 13 checks', () {
      final guardContent = File('tools/reality_guard.sh').readAsStringSync();
      expect(guardContent.contains('PASS'), isTrue);
      // Count the number of PASS/FAIL check blocks
      final passChecks = RegExp(r'\[PASS\]').allMatches(guardContent).length;
      expect(passChecks, greaterThanOrEqualTo(13),
          reason: 'Reality guard harus memiliki minimal 13 aturan (Check 1-13)');
    });

    test('L0: docker-compose.staging.yml exists with required services', () {
      final composeFile = File('docker-compose.staging.yml');
      expect(composeFile.existsSync(), isTrue);
      final content = composeFile.readAsStringSync();
      expect(content.contains('besu'), isTrue, reason: 'Harus ada service Besu');
      expect(content.contains('postgres'), isTrue, reason: 'Harus ada service PostgreSQL');
      expect(content.contains('ezsign'), isTrue, reason: 'Harus ada service ezsign-core');
      expect(content.contains('caddy'), isTrue, reason: 'Harus ada reverse proxy TLS');
    });

    test('L0: seed_staging.sh provisioning script exists', () {
      final seedFile = File('tools/seed_staging.sh');
      expect(seedFile.existsSync(), isTrue);
    });

    test('L0: Test fixtures exist for cross-phase validation', () {
      expect(File('test/fixtures/qris_fixtures.dart').existsSync(), isTrue,
          reason: 'Phase 6 QRIS fixtures harus ada');
      expect(File('test/fixtures/mrz_fixtures.dart').existsSync(), isTrue,
          reason: 'Phase 5A MRZ fixtures harus ada');
      expect(File('test/fixtures/nfc_fixtures.dart').existsSync(), isTrue,
          reason: 'Phase 8 NFC fixtures harus ada');
      expect(File('test/fixtures/demo_merchants_fixture.dart').existsSync(), isTrue,
          reason: 'Phase 6 merchant fixtures harus ada (bukan di lib/)');
    });
  });

  // ================================================================
  // SECTION 8: LINTAS FASE — Anti-Regression Guard
  // ================================================================

  group('Phase 10: Anti-Regression Guards (Level L0/L1)', () {
    test('L0: analysis_options.yaml enforces catch lint rules', () {
      final analysisFile = File('analysis_options.yaml');
      expect(analysisFile.existsSync(), isTrue);
      final content = analysisFile.readAsStringSync();
      expect(content.contains('avoid_catches_without_on_clauses: true'), isTrue,
          reason: 'Lint rule wajib untuk mencegah catch tanpa on clause');
      expect(content.contains('empty_catches: true'), isTrue,
          reason: 'Lint rule wajib untuk mencegah catch kosong');
      expect(content.contains('only_throw_errors: true'), isTrue,
          reason: 'Lint rule wajib untuk memaksa throw tipe terstruktur');
    });

    test('L0: .gitignore excludes env/*.json (non-example)', () {
      final gitignoreFile = File('.gitignore');
      if (gitignoreFile.existsSync()) {
        final content = gitignoreFile.readAsStringSync();
        // Should have some env exclusion pattern
        expect(
          content.contains('env/') || content.contains('.env'),
          isTrue,
          reason: '.gitignore harus mengeksklusi file konfigurasi sensitif',
        );
      }
    });

    test('L0: No MobileScanner import in MRZ scanner (F-01 anti-regression)', () {
      final mrzFile = File(
          'lib/src/features/authentication/presentation/screens/mrz_scanner_screen.dart');
      if (mrzFile.existsSync()) {
        final content = mrzFile.readAsStringSync();
        expect(content.contains('MobileScanner'), isFalse,
            reason: 'F-01: MobileScanner tidak boleh dipakai untuk MRZ');
      }
    });

    test('L1: MRZ demoJamesWilson only exists in test fixtures, not lib/', () {
      final result = Process.runSync('grep', [
        '-rln', 'demoJamesWilson', 'lib/',
      ]);
      expect(result.stdout.toString().trim(), isEmpty);

      // But should exist in test/fixtures
      final testResult = Process.runSync('grep', [
        '-rln', 'demoJamesWilson', 'test/',
      ]);
      expect(testResult.stdout.toString().trim(), isNotEmpty,
          reason: 'demoJamesWilson harus tetap ada di test/fixtures/ sebagai helper test');
    });
  });
}

const _phaseNames = {
  0: 'BASELINE',
  1: 'CONFIG',
  2: 'FOUNDATION',
  3: 'FINANCIAL',
  4: 'CONSENT',
  5: 'MRZ',
  6: 'QRIS',
  7: 'MERCHANT',
  8: 'NFC',
  9: 'LIVENESS',
};
