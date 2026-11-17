// lib/src/core/config/app_config.dart
import 'package:flutter/foundation.dart';

/// AppConfig provides strongly-typed, compile-time and runtime environment
/// configurations injected via `--dart-define` or `--dart-define-from-file`.
///
/// In accordance with Golden Rule R5 and Phase 1 specifications:
/// - No secret or sensitive internal addresses are hardcoded.
/// - No fallback to loopback addresses is permitted.
/// - Configuration validity must be verified by [ConfigValidator] at startup.
class AppConfig {
  AppConfig._();

  /// Application environment flavor: 'dev', 'staging', or 'prod'.
  static const String flavor = String.fromEnvironment(
    'FLAVOR',
    defaultValue: 'dev',
  );

  /// JSON-RPC URL for the Hyperledger Besu EVM blockchain node.
  static String get rpcUrl => _testRpcUrl ?? const String.fromEnvironment('RPC_URL');
  static String? _testRpcUrl;

  /// EVM Chain ID for the target blockchain network.
  static const int chainId = int.fromEnvironment('CHAIN_ID', defaultValue: 0);

  /// Network display name in the UI.
  static const String networkName = String.fromEnvironment(
    'NETWORK_NAME',
    defaultValue: 'Hyperledger Besu Bali Net',
  );

  /// Native gas currency symbol (e.g. ETH, BALI).
  static const String currencySymbol = String.fromEnvironment(
    'CURRENCY_SYMBOL',
    defaultValue: 'ETH',
  );

  /// GraphQL indexer endpoint URL.
  static const String graphqlUrl = String.fromEnvironment('GRAPHQL_URL');

  /// ezsign-core Fastify middleware API base URL.
  static String get ezsignUrl => _testEzsignUrl ?? const String.fromEnvironment('EZSIGN_API_URL');
  static String? _testEzsignUrl;

  /// ERC-20 Smart Contract Address for Indonesian Rupiah Token (IDRT).
  static const String idrtContractAddress = String.fromEnvironment(
    'IDRT_CONTRACT_ADDRESS',
  );

  /// Token name for IDRT.
  static const String idrtName = String.fromEnvironment(
    'IDRT_NAME',
    defaultValue: 'Rupiah Token',
  );

  /// Token symbol for IDRT.
  static const String idrtSymbol = String.fromEnvironment(
    'IDRT_SYMBOL',
    defaultValue: 'IDRT',
  );

  /// Token decimals for IDRT (typically 18).
  static const int idrtDecimals = int.fromEnvironment(
    'IDRT_DECIMALS',
    defaultValue: 18,
  );

  /// Official Bali Provincial Government (Bapenda) Treasury Address for Tourist Levy.
  static String get bapendaTreasuryAddress =>
      _testBapendaTreasury ??
      const String.fromEnvironment(
        'BAPENDA_TREASURY_ADDRESS',
        defaultValue: '0x3565E871c841A8cE127B0e05Eb512a865F93845B',
      );
  static String? _testBapendaTreasury;

  /// Allows test suites to provide mocks or sandbox endpoints without violating immutability in production.
  @visibleForTesting
  static void setTestOverrides({
    String? rpcUrl,
    String? ezsignUrl,
    String? bapendaTreasuryAddress,
  }) {
    _testRpcUrl = rpcUrl;
    _testEzsignUrl = ezsignUrl;
    _testBapendaTreasury = bapendaTreasuryAddress;
  }

  /// Resets test overrides to compiled environment constants.
  @visibleForTesting
  static void resetTestOverrides() {
    _testRpcUrl = null;
    _testEzsignUrl = null;
    _testBapendaTreasury = null;
  }

  /// Liveness mode: 'simulated' (the only permitted dummy module per §0.2) or 'real'.
  static const String livenessMode = String.fromEnvironment(
    'LIVENESS_MODE',
    defaultValue: 'simulated',
  );

  // Helper flags
  static bool get isDev => flavor == 'dev';
  static bool get isStaging => flavor == 'staging';
  static bool get isProd => flavor == 'prod';
  static bool get isSimulatedLiveness => livenessMode == 'simulated';

  /// Returns a sanitized map of public configurations (safe for debug logs).
  static Map<String, dynamic> toSanitizedMap() {
    return {
      'flavor': flavor,
      'rpcUrl': rpcUrl,
      'chainId': chainId,
      'networkName': networkName,
      'currencySymbol': currencySymbol,
      'graphqlUrl': graphqlUrl,
      'ezsignUrl': ezsignUrl,
      'idrtContractAddress': idrtContractAddress,
      'idrtName': idrtName,
      'idrtSymbol': idrtSymbol,
      'idrtDecimals': idrtDecimals,
      'bapendaTreasuryAddress': bapendaTreasuryAddress,
      'livenessMode': livenessMode,
      'kDebugMode': kDebugMode,
    };
  }
}
