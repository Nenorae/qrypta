import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/models/token_model.dart';
import '../providers/token_provider.dart';

class AddTokenManualScreen extends ConsumerStatefulWidget {
  const AddTokenManualScreen({super.key});

  @override
  ConsumerState<AddTokenManualScreen> createState() =>
      _AddTokenManualScreenState();
}

class _AddTokenManualScreenState extends ConsumerState<AddTokenManualScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _nameController = TextEditingController();
  final _symbolController = TextEditingController();
  final _decimalsController = TextEditingController();

  @override
  void dispose() {
    _addressController.dispose();
    _nameController.dispose();
    _symbolController.dispose();
    _decimalsController.dispose();
    super.dispose();
  }

  void _saveToken() async {
    if (_formKey.currentState!.validate()) {
      final tokenNotifier = ref.read(tokenNotifierProvider.notifier);

      final tokenData = Token(
        contractAddress: _addressController.text,
        name: _nameController.text,
        symbol: _symbolController.text,
        decimals: int.tryParse(_decimalsController.text) ?? 0,
      );

      // Tampilkan loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final success = await tokenNotifier.addManualToken(tokenData);

      // Tutup dialog loading
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (success) {
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Token berhasil ditambahkan!')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Gagal menambahkan token. Periksa kembali data Anda.')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tambah Token Manual'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Alamat Kontrak',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Alamat kontrak tidak boleh kosong';
                  }
                  // TODO: Tambahkan validasi alamat ethereum jika perlu
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Token',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Nama token tidak boleh kosong';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _symbolController,
                decoration: const InputDecoration(
                  labelText: 'Simbol Token',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Simbol token tidak boleh kosong';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _decimalsController,
                decoration: const InputDecoration(
                  labelText: 'Desimal',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Desimal tidak boleh kosong';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Masukkan angka yang valid';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveToken,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Simpan Token'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
