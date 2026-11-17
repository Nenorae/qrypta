// test/config_validator_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:qrypta/src/core/config/config_validator.dart';

void main() {
  group('Phase 1 - ConfigValidator Unit Tests (Level L1)', () {
    const validDevConfig = {
      'flavor': 'dev',
      'rpcUrl': 'http://10.0.2.2:8545',
      'chainId': 1338,
      'graphqlUrl': 'http://10.0.2.2:4000/graphql',
      'ezsignUrl': 'http://10.0.2.2:3000/api/v1',
      'idrtContractAddress': '0xF12b5dd4EAD5F743C6BaA640B0216200e89B60Da',
      'idrtDecimals': 18,
      'bapendaTreasuryAddress': '0x3565E871c841A8cE127B0e05Eb512a865F93845B',
    };

    const validStagingConfig = {
      'flavor': 'staging',
      'rpcUrl': 'https://besu-staging.qrypta.id:8545',
      'chainId': 1338,
      'graphqlUrl': 'https://indexer.staging.qrypta.id/graphql',
      'ezsignUrl': 'https://api.staging.qrypta.id/api/v1',
      'idrtContractAddress': '0xF12b5dd4EAD5F743C6BaA640B0216200e89B60Da',
      'idrtDecimals': 18,
      'bapendaTreasuryAddress': '0x3565E871c841A8cE127B0e05Eb512a865F93845B',
    };

    const validProdConfig = {
      'flavor': 'prod',
      'rpcUrl': 'https://rpc.qrypta.id',
      'chainId': 2026,
      'graphqlUrl': 'https://indexer.qrypta.id/graphql',
      'ezsignUrl': 'https://api.qrypta.id/api/v1',
      'idrtContractAddress': '0xF12b5dd4EAD5F743C6BaA640B0216200e89B60Da',
      'idrtDecimals': 18,
      'bapendaTreasuryAddress': '0x3565E871c841A8cE127B0e05Eb512a865F93845B',
    };

    test('Valid Dev configuration passes validation', () {
      final errors = ConfigValidator.validateValues(
        flavor: validDevConfig['flavor'] as String,
        rpcUrl: validDevConfig['rpcUrl'] as String,
        chainId: validDevConfig['chainId'] as int,
        graphqlUrl: validDevConfig['graphqlUrl'] as String,
        ezsignUrl: validDevConfig['ezsignUrl'] as String,
        idrtContractAddress: validDevConfig['idrtContractAddress'] as String,
        idrtDecimals: validDevConfig['idrtDecimals'] as int,
        bapendaTreasuryAddress: validDevConfig['bapendaTreasuryAddress'] as String,
      );

      expect(errors, isEmpty);
    });

    test('Valid Staging configuration passes validation', () {
      final errors = ConfigValidator.validateValues(
        flavor: validStagingConfig['flavor'] as String,
        rpcUrl: validStagingConfig['rpcUrl'] as String,
        chainId: validStagingConfig['chainId'] as int,
        graphqlUrl: validStagingConfig['graphqlUrl'] as String,
        ezsignUrl: validStagingConfig['ezsignUrl'] as String,
        idrtContractAddress: validStagingConfig['idrtContractAddress'] as String,
        idrtDecimals: validStagingConfig['idrtDecimals'] as int,
        bapendaTreasuryAddress: validStagingConfig['bapendaTreasuryAddress'] as String,
      );

      expect(errors, isEmpty);
    });

    test('Valid Prod configuration passes validation', () {
      final errors = ConfigValidator.validateValues(
        flavor: validProdConfig['flavor'] as String,
        rpcUrl: validProdConfig['rpcUrl'] as String,
        chainId: validProdConfig['chainId'] as int,
        graphqlUrl: validProdConfig['graphqlUrl'] as String,
        ezsignUrl: validProdConfig['ezsignUrl'] as String,
        idrtContractAddress: validProdConfig['idrtContractAddress'] as String,
        idrtDecimals: validProdConfig['idrtDecimals'] as int,
        bapendaTreasuryAddress: validProdConfig['bapendaTreasuryAddress'] as String,
      );

      expect(errors, isEmpty);
    });

    test('Golden Rule R5: Staging build rejects loopback and emulator addresses', () {
      final loopbackHosts = [
        '127.0.0.1',
        'localhost',
        '10.0.2.2',
        '0.0.0.0',
        '127.0.1.1',
        '[::1]',
      ];

      for (final host in loopbackHosts) {
        final errors = ConfigValidator.validateValues(
          flavor: 'staging',
          rpcUrl: 'https://$host:8545',
          chainId: 1338,
          graphqlUrl: 'https://$host:4000/graphql',
          ezsignUrl: 'https://$host:3000/api/v1',
          idrtContractAddress: '0xF12b5dd4EAD5F743C6BaA640B0216200e89B60Da',
          idrtDecimals: 18,
          bapendaTreasuryAddress: '0x3565E871c841A8cE127B0e05Eb512a865F93845B',
        );

        final expectedRawHost = host.replaceAll('[', '').replaceAll(']', '');
        expect(
          errors.any((e) => e.contains('Golden Rule R5 Violation') && e.contains(expectedRawHost)),
          isTrue,
          reason: 'Expected host $host to be rejected in staging',
        );
      }
    });

    test('Golden Rule R5: Prod build rejects unencrypted cleartext HTTP schemes', () {
      final errors = ConfigValidator.validateValues(
        flavor: 'prod',
        rpcUrl: 'http://rpc.qrypta.id',
        chainId: 2026,
        graphqlUrl: 'http://indexer.qrypta.id/graphql',
        ezsignUrl: 'http://api.qrypta.id/api/v1',
        idrtContractAddress: '0xF12b5dd4EAD5F743C6BaA640B0216200e89B60Da',
        idrtDecimals: 18,
        bapendaTreasuryAddress: '0x3565E871c841A8cE127B0e05Eb512a865F93845B',
      );

      expect(errors.length, equals(3));
      for (final err in errors) {
        expect(err.contains('Golden Rule R5 Violation'), isTrue);
        expect(err.contains('skema aman'), isTrue);
      }
    });

    test('RPC WSS scheme is accepted for Staging and Prod', () {
      final errors = ConfigValidator.validateValues(
        flavor: 'staging',
        rpcUrl: 'wss://besu-staging.qrypta.id:8546',
        chainId: 1338,
        graphqlUrl: 'https://indexer.staging.qrypta.id/graphql',
        ezsignUrl: 'https://api.staging.qrypta.id/api/v1',
        idrtContractAddress: '0xF12b5dd4EAD5F743C6BaA640B0216200e89B60Da',
        idrtDecimals: 18,
        bapendaTreasuryAddress: '0x3565E871c841A8cE127B0e05Eb512a865F93845B',
      );

      expect(errors, isEmpty);
    });

    test('Rejects invalid Ethereum address format for IDRT and Treasury', () {
      final errors = ConfigValidator.validateValues(
        flavor: 'dev',
        rpcUrl: 'http://10.0.2.2:8545',
        chainId: 1338,
        graphqlUrl: 'http://10.0.2.2:4000/graphql',
        ezsignUrl: 'http://10.0.2.2:3000/api/v1',
        idrtContractAddress: '0xInvalidAddress',
        idrtDecimals: 18,
        bapendaTreasuryAddress: 'NotEvenAHex',
      );

      expect(errors.length, equals(2));
      expect(errors[0].contains('IDRT_CONTRACT_ADDRESS'), isTrue);
      expect(errors[1].contains('BAPENDA_TREASURY_ADDRESS'), isTrue);
    });

    test('Rejects invalid or non-positive Chain ID', () {
      final errors = ConfigValidator.validateValues(
        flavor: 'dev',
        rpcUrl: 'http://10.0.2.2:8545',
        chainId: 0,
        graphqlUrl: 'http://10.0.2.2:4000/graphql',
        ezsignUrl: 'http://10.0.2.2:3000/api/v1',
        idrtContractAddress: '0xF12b5dd4EAD5F743C6BaA640B0216200e89B60Da',
        idrtDecimals: 18,
        bapendaTreasuryAddress: '0x3565E871c841A8cE127B0e05Eb512a865F93845B',
      );

      expect(errors.any((e) => e.contains('CHAIN_ID harus bilangan bulat positif')), isTrue);
    });

    test('Rejects unknown FLAVOR string', () {
      final errors = ConfigValidator.validateValues(
        flavor: 'testing_unknown',
        rpcUrl: 'http://10.0.2.2:8545',
        chainId: 1338,
        graphqlUrl: 'http://10.0.2.2:4000/graphql',
        ezsignUrl: 'http://10.0.2.2:3000/api/v1',
        idrtContractAddress: '0xF12b5dd4EAD5F743C6BaA640B0216200e89B60Da',
        idrtDecimals: 18,
        bapendaTreasuryAddress: '0x3565E871c841A8cE127B0e05Eb512a865F93845B',
      );

      expect(errors.any((e) => e.contains("FLAVOR 'testing_unknown' tidak valid")), isTrue);
    });
  });
}
