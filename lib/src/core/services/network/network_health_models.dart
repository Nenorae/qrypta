// lib/src/core/services/network/network_health_models.dart

/// Health status of an individual infrastructure component.
enum ComponentStatus {
  healthy,
  degraded,
  unreachable,
  checking,
}

/// Overall infrastructure health status aggregated across RPC and EzSign.
enum OverallHealthStatus {
  online,
  degraded,
  offline,
}

/// Snapshot report of network and backend health.
class NetworkHealthReport {
  final ComponentStatus rpcStatus;
  final ComponentStatus ezsignStatus;
  final int? rpcLatencyMs;
  final int? ezsignLatencyMs;
  final BigInt? currentBlockNumber;
  final int? reportedChainId;
  final String? rpcError;
  final String? ezsignError;
  final DateTime lastChecked;

  const NetworkHealthReport({
    required this.rpcStatus,
    required this.ezsignStatus,
    this.rpcLatencyMs,
    this.ezsignLatencyMs,
    this.currentBlockNumber,
    this.reportedChainId,
    this.rpcError,
    this.ezsignError,
    required this.lastChecked,
  });

  factory NetworkHealthReport.initial() {
    return NetworkHealthReport(
      rpcStatus: ComponentStatus.checking,
      ezsignStatus: ComponentStatus.checking,
      lastChecked: DateTime.now(),
    );
  }

  OverallHealthStatus get overallStatus {
    if (rpcStatus == ComponentStatus.healthy &&
        ezsignStatus == ComponentStatus.healthy) {
      return OverallHealthStatus.online;
    }
    if (rpcStatus == ComponentStatus.unreachable &&
        ezsignStatus == ComponentStatus.unreachable) {
      return OverallHealthStatus.offline;
    }
    return OverallHealthStatus.degraded;
  }

  bool get isRpcHealthy => rpcStatus == ComponentStatus.healthy;
  bool get isEzsignHealthy => ezsignStatus == ComponentStatus.healthy;
  bool get isAllHealthy => overallStatus == OverallHealthStatus.online;
}
