// lib/src/core/services/network/network_health_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:qrypta/src/core/config/app_config.dart';
import 'network_health_models.dart';

export 'network_health_models.dart';

/// Service responsible for probing live health of infrastructure endpoints:
/// 1. ezsign-core Fastify API (GET /health)
/// 2. Hyperledger Besu JSON-RPC (eth_chainId & eth_blockNumber)
///
/// Complies with Phase 1.2b: Honest error reporting without silent fake fallbacks.
class NetworkHealthService {
  final http.Client _client;
  final String _rpcUrl;
  final String _ezsignUrl;
  final int _expectedChainId;
  static const String _logTag = 'NetworkHealthService';

  NetworkHealthService({
    http.Client? client,
    String? rpcUrl,
    String? ezsignUrl,
    int? expectedChainId,
  })  : _client = client ?? http.Client(),
        _rpcUrl = rpcUrl ?? AppConfig.rpcUrl,
        _ezsignUrl = ezsignUrl ?? AppConfig.ezsignUrl,
        _expectedChainId = expectedChainId ?? AppConfig.chainId;

  /// Performs concurrent probes against Besu RPC and ezsign-core.
  Future<NetworkHealthReport> checkHealth() async {
    final results = await Future.wait([
      _probeRpc(),
      _probeEzsign(),
    ]);

    final rpcResult = results[0] as _RpcProbeResult;
    final ezsignResult = results[1] as _EzsignProbeResult;

    return NetworkHealthReport(
      rpcStatus: rpcResult.status,
      ezsignStatus: ezsignResult.status,
      rpcLatencyMs: rpcResult.latencyMs,
      ezsignLatencyMs: ezsignResult.latencyMs,
      currentBlockNumber: rpcResult.blockNumber,
      reportedChainId: rpcResult.chainId,
      rpcError: rpcResult.errorMessage,
      ezsignError: ezsignResult.errorMessage,
      lastChecked: DateTime.now(),
    );
  }

  Future<_RpcProbeResult> _probeRpc() async {
    if (_rpcUrl.isEmpty) {
      return _RpcProbeResult(
        status: ComponentStatus.unreachable,
        errorMessage: 'RPC_URL belum dikonfigurasi.',
      );
    }

    final stopwatch = Stopwatch()..start();
    try {
      final uri = Uri.parse(_rpcUrl);

      // JSON-RPC batch call for eth_chainId and eth_blockNumber
      final payload = jsonEncode([
        {'jsonrpc': '2.0', 'method': 'eth_chainId', 'params': [], 'id': 1},
        {'jsonrpc': '2.0', 'method': 'eth_blockNumber', 'params': [], 'id': 2},
      ]);

      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: payload,
      ).timeout(const Duration(seconds: 6));

      stopwatch.stop();

      if (response.statusCode != 200) {
        return _RpcProbeResult(
          status: ComponentStatus.unreachable,
          latencyMs: stopwatch.elapsedMilliseconds,
          errorMessage: 'RPC HTTP Error: status ${response.statusCode}',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List || decoded.isEmpty) {
        return _RpcProbeResult(
          status: ComponentStatus.degraded,
          latencyMs: stopwatch.elapsedMilliseconds,
          errorMessage: 'Respon JSON-RPC tidak valid.',
        );
      }

      int? reportedChainId;
      BigInt? blockNumber;

      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          final id = item['id'];
          final result = item['result'];
          if (id == 1 && result is String) {
            reportedChainId = int.tryParse(result.startsWith('0x') ? result.substring(2) : result, radix: 16);
          } else if (id == 2 && result is String) {
            blockNumber = BigInt.tryParse(result.startsWith('0x') ? result.substring(2) : result, radix: 16);
          }
        }
      }

      // Check Chain ID match
      if (reportedChainId != null && reportedChainId != _expectedChainId) {
        developer.log(
          'Chain ID mismatch: Node returned $reportedChainId, expected $_expectedChainId',
          name: _logTag,
        );
        return _RpcProbeResult(
          status: ComponentStatus.degraded,
          latencyMs: stopwatch.elapsedMilliseconds,
          chainId: reportedChainId,
          blockNumber: blockNumber,
          errorMessage: 'Chain ID mismatch: Node ($reportedChainId) != App ($_expectedChainId)',
        );
      }

      return _RpcProbeResult(
        status: ComponentStatus.healthy,
        latencyMs: stopwatch.elapsedMilliseconds,
        chainId: reportedChainId,
        blockNumber: blockNumber,
      );
    } on Object catch (e) {
      stopwatch.stop();
      developer.log('RPC health check failure: $e', name: _logTag);
      return _RpcProbeResult(
        status: ComponentStatus.unreachable,
        latencyMs: stopwatch.elapsedMilliseconds,
        errorMessage: e.toString(),
      );
    }
  }

  Future<_EzsignProbeResult> _probeEzsign() async {
    if (_ezsignUrl.isEmpty) {
      return _EzsignProbeResult(
        status: ComponentStatus.unreachable,
        errorMessage: 'EZSIGN_API_URL belum dikonfigurasi.',
      );
    }

    final stopwatch = Stopwatch()..start();
    try {
      // ezsign-core health endpoint is at {base_url}/health or {base_origin}/health
      final baseUri = Uri.parse(_ezsignUrl);
      final healthUri = baseUri.replace(path: '/health');

      final response = await _client.get(
        healthUri,
      ).timeout(const Duration(seconds: 5));

      stopwatch.stop();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return _EzsignProbeResult(
          status: ComponentStatus.healthy,
          latencyMs: stopwatch.elapsedMilliseconds,
        );
      } else {
        return _EzsignProbeResult(
          status: ComponentStatus.degraded,
          latencyMs: stopwatch.elapsedMilliseconds,
          errorMessage: 'EzSign status: ${response.statusCode}',
        );
      }
    } on Object catch (e) {
      stopwatch.stop();
      developer.log('EzSign health check failure: $e', name: _logTag);
      return _EzsignProbeResult(
        status: ComponentStatus.unreachable,
        latencyMs: stopwatch.elapsedMilliseconds,
        errorMessage: e.toString(),
      );
    }
  }

  void dispose() {
    _client.close();
  }
}

class _RpcProbeResult {
  final ComponentStatus status;
  final int? latencyMs;
  final int? chainId;
  final BigInt? blockNumber;
  final String? errorMessage;

  _RpcProbeResult({
    required this.status,
    this.latencyMs,
    this.chainId,
    this.blockNumber,
    this.errorMessage,
  });
}

class _EzsignProbeResult {
  final ComponentStatus status;
  final int? latencyMs;
  final String? errorMessage;

  _EzsignProbeResult({
    required this.status,
    this.latencyMs,
    this.errorMessage,
  });
}

/// Riverpod provider for [NetworkHealthService].
final networkHealthServiceProvider = Provider<NetworkHealthService>((ref) {
  final service = NetworkHealthService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Riverpod StateNotifier for managing reactive application network health state.
class NetworkHealthNotifier extends StateNotifier<NetworkHealthReport> {
  final NetworkHealthService _service;
  Timer? _periodicTimer;

  NetworkHealthNotifier(this._service) : super(NetworkHealthReport.initial()) {
    checkHealth();
  }

  /// Manually trigger a health probe.
  Future<void> checkHealth() async {
    final report = await _service.checkHealth();
    if (mounted) {
      state = report;
    }
  }

  /// Start periodic monitoring (e.g. every 30 seconds).
  void startPeriodicChecks({Duration interval = const Duration(seconds: 30)}) {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(interval, (_) => checkHealth());
  }

  /// Stop periodic monitoring.
  void stopPeriodicChecks() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  @override
  void dispose() {
    _periodicTimer?.cancel();
    super.dispose();
  }
}

/// Provider for observing reactive network health across UI components.
final networkHealthProvider =
    StateNotifierProvider<NetworkHealthNotifier, NetworkHealthReport>((ref) {
  return NetworkHealthNotifier(ref.watch(networkHealthServiceProvider));
});
