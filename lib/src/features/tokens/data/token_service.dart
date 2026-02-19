import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:qrypta/src/core/data/models/token_model.dart';

class TokenService {
  /// Mendapatkan daftar token yang di-hardcode dari file .env
  List<TokenModel> getHardcodedTokens() {
    final contractAddress = dotenv.env['IDRT_CONTRACT_ADDRESS'] ?? '';
    final name = dotenv.env['IDRT_NAME'] ?? 'Rupiah Token';
    final symbol = dotenv.env['IDRT_SYMBOL'] ?? 'IDRT';
    final decimals = int.tryParse(dotenv.env['IDRT_DECIMALS'] ?? '18') ?? 18;

    if (contractAddress.isEmpty) {
      return [];
    }

    return [
      TokenModel(
        contractAddress: contractAddress,
        name: name,
        symbol: symbol,
        decimals: decimals,
        balance: BigInt.zero, // Saldo akan diupdate via blockchain RPC
      ),
    ];
  }
}

final tokenServiceProvider = TokenService();
