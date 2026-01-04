
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import for Riverpod
import 'package:qrypta/src/core/services/blockchain/blockchain_service.dart';

class TestConnectionPage extends ConsumerStatefulWidget { // Changed to ConsumerStatefulWidget
  const TestConnectionPage({super.key});

  @override
  ConsumerState<TestConnectionPage> createState() => _TestConnectionPageState();
}

class _TestConnectionPageState extends ConsumerState<TestConnectionPage> {
  String _connectionStatus = 'Menunggu tes koneksi...';
  bool _isLoading = false;

  void _checkConnection() async {
    setState(() {
      _isLoading = true;
      _connectionStatus = 'Menghubungkan ke blockchain...';
    });

    try {
      final blockchainService = ref.read(blockchainServiceProvider);
      await blockchainService.client.getBlockNumber();

      setState(() {
        _connectionStatus = 'Koneksi ke blockchain berhasil!';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _connectionStatus = 'Koneksi gagal: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tes Koneksi Blockchain'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _connectionStatus,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const CircularProgressIndicator()
            else
              ElevatedButton(
                onPressed: _checkConnection,
                child: const Text('Mulai Tes Koneksi'),
              ),
          ],
        ),
      ),
    );
  }
}
