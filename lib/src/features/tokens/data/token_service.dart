// lib/src/features/tokens/data/token_service.dart
import 'package:qrypta/src/core/config/app_config.dart';
import 'package:qrypta/src/core/data/models/token_model.dart';

class TokenService {
  /// Mendapatkan daftar token resmi (IDRT) dari konfigurasi aplikasi [AppConfig].
  List<TokenModel> getHardcodedTokens() {
    final contractAddress = AppConfig.idrtContractAddress;

    if (contractAddress.isEmpty) {
      return [];
    }

    return [
      TokenModel(
        contractAddress: contractAddress,
        name: AppConfig.idrtName,
        symbol: AppConfig.idrtSymbol,
        decimals: AppConfig.idrtDecimals,
        balance: BigInt.zero, // Saldo akan diupdate via blockchain RPC
      ),
    ];
  }
}

final tokenServiceProvider = TokenService();
