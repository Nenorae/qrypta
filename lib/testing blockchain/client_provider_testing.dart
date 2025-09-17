import 'package:http/http.dart';
import 'package:web3dart/web3dart.dart';

class BlockchainClientProvider {
  final String _rpcUrl = "http://100.92.191.4:8556";
  Web3Client? _client;

  Web3Client getClient() {
    _client ??= Web3Client(_rpcUrl, Client());
    return _client!;
  }

  Future<void> dispose() async {
    if (_client != null) {
      await _client!.dispose();
      _client = null;
    }
  }
}
