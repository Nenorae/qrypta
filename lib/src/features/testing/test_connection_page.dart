
import 'package:flutter/material.dart';
import 'package:qrypta/src/core/services/blockchain_service.dart';

class TestConnectionPage extends StatefulWidget {
  const TestConnectionPage({super.key});

  @override
  State<TestConnectionPage> createState() => _TestConnectionPageState();
}

class _TestConnectionPageState extends State<TestConnectionPage> {
  String _connectionStatus = 'Menunggu tes koneksi...';
  bool _isLoading = false;

  void _checkConnection() async {
    setState(() {
      _isLoading = true;
      _connectionStatus = 'Menghubungkan ke blockchain...';
    });

    final blockchainService = BlockchainService();
    final result = await blockchainService.getBlockchainInfo();

    setState(() {
      _connectionStatus = result;
      _isLoading = false;
    });
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
