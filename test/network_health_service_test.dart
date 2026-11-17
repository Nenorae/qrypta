// test/network_health_service_test.dart

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qrypta/src/core/services/network/network_health_service.dart';

void main() {
  group('Phase 1 - NetworkHealthService Unit Tests (Level L1)', () {
    const testRpcUrl = 'http://mock-besu.local:8545';
    const testEzsignUrl = 'http://mock-ezsign.local:3000/api/v1';
    const testChainId = 1338;

    test('Reports online when both Besu RPC and EzSign are healthy', () async {
      final mockClient = MockClient((request) async {
        // Mock EzSign /health
        if (request.url.path.endsWith('/health')) {
          return http.Response(jsonEncode({'status': 'ok'}), 200);
        }

        // Mock Besu JSON-RPC
        if (request.body.contains('eth_chainId')) {
          return http.Response(
            jsonEncode([
              {'jsonrpc': '2.0', 'id': 1, 'result': '0x53a'}, // 0x53a = 1338
              {'jsonrpc': '2.0', 'id': 2, 'result': '0x100'}, // 0x100 = 256
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        return http.Response('Not Found', 404);
      });

      final service = NetworkHealthService(
        client: mockClient,
        rpcUrl: testRpcUrl,
        ezsignUrl: testEzsignUrl,
        expectedChainId: testChainId,
      );
      final report = await service.checkHealth();

      expect(report.isRpcHealthy, isTrue);
      expect(report.isEzsignHealthy, isTrue);
      expect(report.overallStatus, equals(OverallHealthStatus.online));
      expect(report.currentBlockNumber, equals(BigInt.from(256)));
      expect(report.reportedChainId, equals(1338));
    });

    test('Reports degraded when EzSign returns 503 error', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/health')) {
          return http.Response('Service Unavailable', 503);
        }

        if (request.body.contains('eth_chainId')) {
          return http.Response(
            jsonEncode([
              {'jsonrpc': '2.0', 'id': 1, 'result': '0x53a'},
              {'jsonrpc': '2.0', 'id': 2, 'result': '0x10'},
            ]),
            200,
          );
        }

        return http.Response('Not Found', 404);
      });

      final service = NetworkHealthService(
        client: mockClient,
        rpcUrl: testRpcUrl,
        ezsignUrl: testEzsignUrl,
        expectedChainId: testChainId,
      );
      final report = await service.checkHealth();

      expect(report.isRpcHealthy, isTrue);
      expect(report.ezsignStatus, equals(ComponentStatus.degraded));
      expect(report.overallStatus, equals(OverallHealthStatus.degraded));
    });

    test('Reports degraded when Besu RPC returns chainId mismatch', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/health')) {
          return http.Response(jsonEncode({'status': 'ok'}), 200);
        }

        if (request.body.contains('eth_chainId')) {
          return http.Response(
            jsonEncode([
              {'jsonrpc': '2.0', 'id': 1, 'result': '0x1'}, // Mainnet (1) instead of 1338
              {'jsonrpc': '2.0', 'id': 2, 'result': '0x100'},
            ]),
            200,
          );
        }

        return http.Response('Not Found', 404);
      });

      final service = NetworkHealthService(
        client: mockClient,
        rpcUrl: testRpcUrl,
        ezsignUrl: testEzsignUrl,
        expectedChainId: testChainId,
      );
      final report = await service.checkHealth();

      expect(report.rpcStatus, equals(ComponentStatus.degraded));
      expect(report.isEzsignHealthy, isTrue);
      expect(report.overallStatus, equals(OverallHealthStatus.degraded));
      expect(report.rpcError, contains('Chain ID mismatch'));
    });

    test('Reports offline when both RPC and EzSign fail completely', () async {
      final mockClient = MockClient((request) async {
        throw http.ClientException('Connection refused');
      });

      final service = NetworkHealthService(
        client: mockClient,
        rpcUrl: testRpcUrl,
        ezsignUrl: testEzsignUrl,
        expectedChainId: testChainId,
      );
      final report = await service.checkHealth();

      expect(report.rpcStatus, equals(ComponentStatus.unreachable));
      expect(report.ezsignStatus, equals(ComponentStatus.unreachable));
      expect(report.overallStatus, equals(OverallHealthStatus.offline));
      expect(report.rpcError, contains('Connection refused'));
      expect(report.ezsignError, contains('Connection refused'));
    });
  });
}
