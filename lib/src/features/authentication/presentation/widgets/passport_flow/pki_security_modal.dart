// lib/src/features/authentication/presentation/widgets/passport_flow/pki_security_modal.dart

import 'package:flutter/material.dart';
import 'package:qrypta/src/features/authentication/domain/models/nfc_passport_models.dart';
import 'package:qrypta/src/core/utils/mrz_parser.dart';

/// Modal rincian keamanan kriptografis PKI paspor (Phase 8.2).
class PkiSecurityModal extends StatelessWidget {
  final PassiveAuthResult? passiveAuthResult;
  final MrzParseResult mrzResult;

  const PkiSecurityModal({
    super.key,
    required this.passiveAuthResult,
    required this.mrzResult,
  });

  static void show({
    required BuildContext context,
    required PassiveAuthResult? passiveAuthResult,
    required MrzParseResult mrzResult,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PkiSecurityModal(
        passiveAuthResult: passiveAuthResult,
        mrzResult: mrzResult,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pa = passiveAuthResult;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF131D2D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  'PKI Security Details',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(Icons.security_rounded, color: Color(0xFFA78BFA), size: 20),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0C1322),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildModalRow('Document Type', 'ePassport / ICAO Doc 9303 TD3'),
                  const Divider(color: Colors.white12, height: 14),
                  _buildModalRow(
                    'Country Trust Authority',
                    pa?.cscaCountry ?? '${mrzResult.nationality} CSCA (Unverified Anchor)',
                  ),
                  const Divider(color: Colors.white12, height: 14),
                  _buildModalRow('Document Signer (DS)', pa?.dscSubject ?? 'Document Signer'),
                  const Divider(color: Colors.white12, height: 14),
                  _buildModalRow('DS Serial Number', pa?.dscSerial ?? 'N/A'),
                  const Divider(color: Colors.white12, height: 14),
                  _buildModalRow('Hash Algorithm', '${pa?.hashAlgorithm ?? "SHA-256"} (FIPS 180-4)'),
                  const Divider(color: Colors.white12, height: 14),
                  _buildModalRow('Signature Scheme', pa?.signatureAlgorithm ?? 'ECDSA / RSA'),
                  const Divider(color: Colors.white12, height: 14),
                  _buildModalRow(
                    'Passive Authentication',
                    pa != null
                        ? (pa.isGenuine
                            ? 'VALIDATED · GENUINE'
                            : (pa.status == PassiveAuthStatus.unverifiedNoTrustAnchor
                                ? 'UNVERIFIED · NO TRUST ANCHOR'
                                : 'FAILED · INTEGRITY COMPROMISED'))
                        : 'PENDING READ',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModalRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
