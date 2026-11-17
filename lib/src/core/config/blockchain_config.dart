// lib/src/core/config/blockchain_config.dart
import 'app_config.dart';

/// Legacy-compatible facade that forwards configuration requests to [AppConfig].
/// Hardcoded loopback addresses and dotenv dependencies have been eliminated (F-02, F-20).
class BlockchainConfig {
  BlockchainConfig._();

  /// RPC URL for Hyperledger Besu node
  static String get rpcUrl => AppConfig.rpcUrl;

  /// Chain ID for Besu network
  static int get chainId => AppConfig.chainId;

  /// Network name for display in UI
  static String get name => AppConfig.networkName;

  /// Native currency symbol
  static String get currencySymbol => AppConfig.currencySymbol;

  /// ezsign-core Fastify middleware API base URL
  static String get ezsignApiUrl => AppConfig.ezsignUrl;

  /// Official Bali Provincial Government (Bapenda) Treasury Address for Tourist Levy
  static String get bapendaTreasuryAddress => AppConfig.bapendaTreasuryAddress;
}
