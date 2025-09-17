// add_manual_token_screen.dart

class AddManualTokenScreen extends ConsumerStatefulWidget {
  // ... constructor
}

class _AddManualTokenScreenState extends ConsumerState<AddManualTokenScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _nameController = TextEditingController();
  final _symbolController = TextEditingController();
  final _decimalsController = TextEditingController();

  void _saveToken() async {
    if (_formKey.currentState!.validate()) {
      // Ambil provider-nya
      final tokenNotifier = ref.read(tokenProvider.notifier);

      final tokenData = Token(
        contractAddress: _addressController.text,
        name: _nameController.text,
        symbol: _symbolController.text,
        decimals: int.parse(_decimalsController.text),
      );

      // Panggil method untuk menambahkan token
      final success = await tokenNotifier.addManualToken(tokenData);

      if (success) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Token berhasil ditambahkan!')));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal: Kontrak tidak valid.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Tambah Token Manual')),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _addressController,
              decoration: InputDecoration(labelText: 'Alamat Kontrak'),
            ),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(labelText: 'Nama Token'),
            ),
            TextFormField(
              controller: _symbolController,
              decoration: InputDecoration(labelText: 'Simbol Token'),
            ),
            TextFormField(
              controller: _decimalsController,
              decoration: InputDecoration(labelText: 'Desimal'),
              keyboardType: TextInputType.number,
            ),
            ElevatedButton(onPressed: _saveToken, child: Text('Simpan')),
          ],
        ),
      ),
    );
  }
}
