// lib/src/features/authentication/presentation/widgets/mrz_detected_result_sheet.dart

import 'package:flutter/material.dart';
import 'package:qrypta/src/core/config/theme/app_colors.dart';
import 'package:qrypta/src/core/utils/mrz_parser.dart';

/// Modal lembar hasil deteksi MRZ paspor yang terverifikasi (Phase 5A).
class MrzDetectedResultSheet extends StatelessWidget {
  final MrzParseResult result;
  final VoidCallback onContinue;

  const MrzDetectedResultSheet({
    super.key,
    required this.result,
    required this.onContinue,
  });

  static Future<void> show({
    required BuildContext context,
    required MrzParseResult result,
    required VoidCallback onContinue,
  }) {
    return showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MrzDetectedResultSheet(
        result: result,
        onContinue: onContinue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF131D2D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Chip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF2DD4BF),
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'MRZ PASSPORT DETECTED',
                    style: TextStyle(
                      color: Color(0xFF2DD4BF),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF2DD4BF).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Checksum Modulo-10 Valid',
                  style: TextStyle(
                    color: Color(0xFF2DD4BF),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Detail Paspor Hasil OCR
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0C1322),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Column(
              children: [
                _buildDataRow('Full Name', result.fullName),
                const Divider(color: Colors.white12, height: 16),
                _buildDataRow('Passport No', result.passportMasked),
                const Divider(color: Colors.white12, height: 16),
                _buildDataRow('Nationality', result.nationality),
                const Divider(color: Colors.white12, height: 16),
                _buildDataRow('Date of Birth', result.birthDateFormatted),
                const Divider(color: Colors.white12, height: 16),
                _buildDataRow('Doc Expiry', result.expiryDateFormatted),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Pita Kode MRZ Raw
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.rawLine1,
                  style: const TextStyle(
                    color: Color(0xFF5EEAD4),
                    fontFamily: 'Courier',
                    fontSize: 10.5,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  result.rawLine2,
                  style: const TextStyle(
                    color: Color(0xFF5EEAD4),
                    fontFamily: 'Courier',
                    fontSize: 10.5,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Tombol Lanjut ke Chip Read
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: onContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: const Color(0xFF0A0F1D),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text(
                    'Continue to chip read',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.nfc_rounded, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 13,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
