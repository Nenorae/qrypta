// lib/src/core/config/blockchain_config.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

class BlockchainConfig {
  /// RPC URL for Hyperledger Besu node
  static String get rpcUrl =>
      dotenv.isInitialized ? (dotenv.env['RPC_URL'] ?? 'http://127.0.0.1:8545') : 'http://127.0.0.1:8545';

  /// Chain ID for Besu network
  static int get chainId =>
      int.tryParse(dotenv.isInitialized ? (dotenv.env['CHAIN_ID'] ?? '1337') : '1337') ?? 1337;

  /// Network name for display in UI
  static String get name =>
      dotenv.isInitialized ? (dotenv.env['NETWORK_NAME'] ?? 'Hyperledger Besu Bali Net') : 'Hyperledger Besu Bali Net';

  /// Native currency symbol
  static String get currencySymbol =>
      dotenv.isInitialized ? (dotenv.env['CURRENCY_SYMBOL'] ?? 'ETH') : 'ETH';

  /// ezsign-core Fastify middleware API base URL
  static String get ezsignApiUrl =>
      dotenv.isInitialized ? (dotenv.env['EZSIGN_API_URL'] ?? 'http://127.0.0.1:3000/api/v1') : 'http://127.0.0.1:3000/api/v1';

  /// Official Bali Provincial Government (Bapenda) Treasury Address for Tourist Levy
  static String get bapendaTreasuryAddress =>
      dotenv.isInitialized
          ? (dotenv.env['BAPENDA_TREASURY_ADDRESS'] ?? '0x3565E871c841A8cE127B0e05Eb512a865F93845B')
          : '0x3565E871c841A8cE127B0e05Eb512a865F93845B';
}
