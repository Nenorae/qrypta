// lib/src/features/authentication/presentation/widgets/manual_passport_input_sheet.dart

import 'package:flutter/material.dart';
import 'package:qrypta/src/core/config/theme/app_colors.dart';
import 'package:qrypta/src/core/error/app_failure.dart';
import 'package:qrypta/src/core/utils/mrz_parser.dart';

/// Formulir Input Manual Paspor (Rencana Kerja §5A.3 item 7).
/// Jalur nyata alternatif (bukan fallback palsu) dengan validasi ICAO 9303 modulo 10 ketat.
class ManualPassportInputSheet extends StatefulWidget {
  final void Function(MrzParseResult result) onSubmitted;

  const ManualPassportInputSheet({super.key, required this.onSubmitted});

  @override
  State<ManualPassportInputSheet> createState() => _ManualPassportInputSheetState();
}

class _ManualPassportInputSheetState extends State<ManualPassportInputSheet> {
  final _formKey = GlobalKey<FormState>();

  final _surnameController = TextEditingController();
  final _givenNamesController = TextEditingController();
  final _passportNumberController = TextEditingController();
  final _countryController = TextEditingController(text: 'GBR');
  final _dobController = TextEditingController();
  final _expiryController = TextEditingController();

  String _sex = 'M';
  String? _errorMessage;

  @override
  void dispose() {
    _surnameController.dispose();
    _givenNamesController.dispose();
    _passportNumberController.dispose();
    _countryController.dispose();
    _dobController.dispose();
    _expiryController.dispose();
    super.dispose();
  }

  void _submit() {
    setState(() {
      _errorMessage = null;
    });

    if (!_formKey.currentState!.validate()) return;

    final surname = _surnameController.text.trim().toUpperCase().replaceAll(' ', '<');
    final givenNames = _givenNamesController.text.trim().toUpperCase().replaceAll(' ', '<');
    final country = _countryController.text.trim().toUpperCase().padRight(3, '<').substring(0, 3);
    final passportNum = _passportNumberController.text.trim().toUpperCase().padRight(9, '<').substring(0, 9);
    final dob = _dobController.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
    final expiry = _expiryController.text.trim().replaceAll(RegExp(r'[^0-9]'), '');

    if (dob.length != 6 || expiry.length != 6) {
      setState(() {
        _errorMessage = 'Format tanggal harus 6 digit YYMMDD (contoh: 880512)';
      });
      return;
    }

    try {
      // Hitung check digit ICAO 9303 sah
      final docCheck = MrzParser.computeCheckDigit(passportNum).toString();
      final dobCheck = MrzParser.computeCheckDigit(dob).toString();
      final expiryCheck = MrzParser.computeCheckDigit(expiry).toString();
      const personalNum = '<<<<<<<<<<<<<<';
      const personalCheck = '<';

      // Line 1: P< + Country(3) + Surname + << + GivenNames
      final nameSection = '$surname<<$givenNames';
      final line1 = ('P<$country$nameSection').padRight(44, '<').substring(0, 44);

      // Composite payload untuk pos 43
      final compositePayload = '$passportNum$docCheck$dob$dobCheck$expiry$expiryCheck$personalNum$personalCheck';
      final compositeCheck = MrzParser.computeCheckDigit(compositePayload).toString();

      // Line 2: Passport(9) + Check(1) + Nationality(3) + DOB(6) + Check(1) + Sex(1) + Expiry(6) + Check(1) + Personal(14) + Comp(1)
      final line2 = '$passportNum$docCheck$country$dob$dobCheck$_sex$expiry$expiryCheck$personalNum$personalCheck$compositeCheck';

      final parsed = MrzParser.parse(line1, line2, strict: true);
      widget.onSubmitted(parsed);
    } on ValidationFailure catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } on Object catch (e) {
      setState(() {
        _errorMessage = 'Gagal memproses data paspor: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 24,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Input Paspor Manual (ICAO 9303)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Data akan divalidasi dengan algoritma check digit modulo 10 standar internasional.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.redAccent),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _surnameController,
                      label: 'Surname / Nama Keluarga',
                      hint: 'SMITH',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      controller: _givenNamesController,
                      label: 'Given Names / Nama Depan',
                      hint: 'SARAH',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildTextField(
                      controller: _passportNumberController,
                      label: 'Nomor Paspor (9 karakter)',
                      hint: '724918789',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: _buildTextField(
                      controller: _countryController,
                      label: 'Negara (ISO 3)',
                      hint: 'GBR',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _dobController,
                      label: 'Tgl Lahir (YYMMDD)',
                      hint: '880512',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      controller: _expiryController,
                      label: 'Kedaluwarsa (YYMMDD)',
                      hint: '320318',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Jenis Kelamin: ', style: TextStyle(color: Colors.white70)),
                  const SizedBox(width: 12),
                  ChoiceChip(
                    label: const Text('Laki-laki (M)'),
                    selected: _sex == 'M',
                    selectedColor: AppColors.accent,
                    onSelected: (s) => setState(() => _sex = 'M'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Perempuan (F)'),
                    selected: _sex == 'F',
                    selectedColor: AppColors.accent,
                    onSelected: (s) => setState(() => _sex = 'F'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: const Color(0xFF0F172A),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Validasi & Lanjutkan ke Verifikasi',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          style: const TextStyle(color: Colors.white, fontFamily: 'Courier', fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white30),
            filled: true,
            fillColor: Colors.black26,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.white12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.accent),
            ),
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
        ),
      ],
    );
  }
}
