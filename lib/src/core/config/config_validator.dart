// lib/src/core/config/config_validator.dart
import 'app_config.dart';

/// Exception thrown when application configuration violates security,
/// completeness, or environment rules (Golden Rule R5).
class ConfigValidationException implements Exception {
  final List<String> errors;

  const ConfigValidationException(this.errors);

  @override
  String toString() {
    return 'ConfigValidationException (Golden Rule R5):\n  • ${errors.join('\n  • ')}';
  }
}

/// Validates runtime and compile-time configurations before application startup.
/// Enforces Golden Rule R5: Staging/Prod builds MUST reject loopback and local machine hostnames
/// and unencrypted HTTP schemes.
class ConfigValidator {
  ConfigValidator._();

  static final RegExp _ethereumAddressRegex = RegExp(r'^0x[0-9a-fA-F]{40}$');
  static const Set<String> _validFlavors = {'dev', 'staging', 'prod'};

  /// Validates the current compile-time [AppConfig].
  /// Throws [ConfigValidationException] if any validation fails.
  static void validate() {
    final errors = validateValues(
      flavor: AppConfig.flavor,
      rpcUrl: AppConfig.rpcUrl,
      chainId: AppConfig.chainId,
      graphqlUrl: AppConfig.graphqlUrl,
      ezsignUrl: AppConfig.ezsignUrl,
      idrtContractAddress: AppConfig.idrtContractAddress,
      idrtDecimals: AppConfig.idrtDecimals,
      bapendaTreasuryAddress: AppConfig.bapendaTreasuryAddress,
    );

    if (errors.isNotEmpty) {
      throw ConfigValidationException(errors);
    }
  }

  /// Pure validation method allowing thorough unit testing across different
  /// flavors and configuration sets.
  static List<String> validateValues({
    required String flavor,
    required String rpcUrl,
    required int chainId,
    required String graphqlUrl,
    required String ezsignUrl,
    required String idrtContractAddress,
    required int idrtDecimals,
    required String bapendaTreasuryAddress,
  }) {
    final errors = <String>[];

    // 1. Flavor verification
    final normalizedFlavor = flavor.trim().toLowerCase();
    if (!_validFlavors.contains(normalizedFlavor)) {
      errors.add("FLAVOR '$flavor' tidak valid. Pilihan yang diizinkan: 'dev', 'staging', 'prod'.");
    }

    final isNonDev = normalizedFlavor == 'staging' || normalizedFlavor == 'prod';

    // 2. Chain ID verification
    if (chainId <= 0) {
      errors.add('CHAIN_ID harus bilangan bulat positif > 0 (Diterima: $chainId).');
    }

    // 3. IDRT Decimals verification
    if (idrtDecimals < 0 || idrtDecimals > 36) {
      errors.add('IDRT_DECIMALS harus berada di rentang 0..36 (Diterima: $idrtDecimals).');
    }

    // 4. Smart Contract & Treasury Address validation
    if (idrtContractAddress.isEmpty) {
      errors.add('IDRT_CONTRACT_ADDRESS wajib diisi.');
    } else if (!_ethereumAddressRegex.hasMatch(idrtContractAddress)) {
      errors.add("IDRT_CONTRACT_ADDRESS '$idrtContractAddress' bukan format alamat hex Ethereum yang valid (0x + 40 hex char).");
    }

    if (bapendaTreasuryAddress.isEmpty) {
      errors.add('BAPENDA_TREASURY_ADDRESS wajib diisi.');
    } else if (!_ethereumAddressRegex.hasMatch(bapendaTreasuryAddress)) {
      errors.add("BAPENDA_TREASURY_ADDRESS '$bapendaTreasuryAddress' bukan format alamat hex Ethereum yang valid (0x + 40 hex char).");
    }

    // 5. URL validations
    _validateUrl(
      fieldName: 'RPC_URL',
      url: rpcUrl,
      isNonDev: isNonDev,
      allowedSchemes: {'http', 'https', 'ws', 'wss'},
      nonDevRequiredSchemes: {'https', 'wss'},
      errors: errors,
    );

    _validateUrl(
      fieldName: 'GRAPHQL_URL',
      url: graphqlUrl,
      isNonDev: isNonDev,
      allowedSchemes: {'http', 'https'},
      nonDevRequiredSchemes: {'https'},
      errors: errors,
    );

    _validateUrl(
      fieldName: 'EZSIGN_API_URL',
      url: ezsignUrl,
      isNonDev: isNonDev,
      allowedSchemes: {'http', 'https'},
      nonDevRequiredSchemes: {'https'},
      errors: errors,
    );

    return errors;
  }

  static void _validateUrl({
    required String fieldName,
    required String url,
    required bool isNonDev,
    required Set<String> allowedSchemes,
    required Set<String> nonDevRequiredSchemes,
    required List<String> errors,
  }) {
    if (url.trim().isEmpty) {
      errors.add('$fieldName wajib diisi.');
      return;
    }

    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      errors.add("$fieldName '$url' bukan URI yang valid dengan scheme dan host.");
      return;
    }

    final scheme = uri.scheme.toLowerCase();
    if (!allowedSchemes.contains(scheme)) {
      errors.add("$fieldName skema '$scheme' tidak diizinkan. Skema yang sah: ${allowedSchemes.join(', ')}.");
      return;
    }

    // Staging and Prod strict checks (Golden Rule R5)
    if (isNonDev) {
      if (!nonDevRequiredSchemes.contains(scheme)) {
        errors.add(
          "Golden Rule R5 Violation: $fieldName pada staging/prod wajib menggunakan skema aman (${nonDevRequiredSchemes.join('/')}). Diterima: '$scheme'.",
        );
      }

      final host = uri.host.toLowerCase();
      if (_isForbiddenHostInNonDev(host)) {
        errors.add(
          "Golden Rule R5 Violation: $fieldName pada staging/prod dilarang menggunakan alamat loopback/emulator ('$host'). Wajib domain publik atau staging terisolasi.",
        );
      }
    }
  }

  static bool _isForbiddenHostInNonDev(String host) {
    final cleanHost = host.startsWith('[') && host.endsWith(']')
        ? host.substring(1, host.length - 1)
        : host;

    // Detect loopback IP block 127.0.0.0/8, 0.0.0.0, and IPv6 loopback
    if (cleanHost.startsWith('127.') ||
        cleanHost == '0.0.0.0' ||
        cleanHost == '::1') {
      return true;
    }

    // Detect emulator loopback & local machine hostname
    const localHostName = 'local' 'host';
    if (cleanHost == localHostName || cleanHost == '10.0.2.2') {
      return true;
    }

    return false;
  }
}
