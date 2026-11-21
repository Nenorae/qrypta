// lib/src/features/authentication/presentation/widgets/passport_flow/passive_auth_step_view.dart

import 'package:flutter/material.dart';
import 'package:qrypta/src/core/config/theme/app_colors.dart';
import 'package:qrypta/src/features/authentication/domain/models/nfc_passport_models.dart';
import 'package:qrypta/src/core/utils/mrz_parser.dart';

/// Tampilan tahap verifikasi Passive Authentication kriptografis (Phase 8.2).
class PassiveAuthStepView extends StatelessWidget {
  final PassiveAuthResult? passiveAuthResult;
  final PassportChipData? chipData;
  final MrzParseResult mrzResult;
  final VoidCallback onShowSecurityDetails;
  final VoidCallback onContinueToLiveness;

  const PassiveAuthStepView({
    super.key,
    required this.passiveAuthResult,
    required this.chipData,
    required this.mrzResult,
    required this.onShowSecurityDetails,
    required this.onContinueToLiveness,
  });

  @override
  Widget build(BuildContext context) {
    final pa = passiveAuthResult;
    final bool dgMatched = pa?.dgHashesMatched[1] == true;
    final bool sigValid = pa != null &&
        pa.status != PassiveAuthStatus.signatureInvalid &&
        pa.status != PassiveAuthStatus.parseError;
    final bool isGenuine = pa?.isGenuine == true;
    final bool isUnverifiedAnchor =
        pa?.status == PassiveAuthStatus.unverifiedNoTrustAnchor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        const Text(
          'Passive Authentication (ICAO Doc 9303)',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Cryptographically verifying passport chip signatures against ICAO PKD',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.65),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 16),

        // 4-Node Visual Trust Chain Dinamis
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildTrustChainNode(
                  title: 'ePassport chip',
                  subtitle: 'ISO 14443 contactless microchip intact',
                  isDone: chipData != null,
                ),
                _buildTrustChainConnector(dgMatched),
                _buildTrustChainNode(
                  title: 'Signed passport data',
                  subtitle: dgMatched
                      ? 'DG1 hash matched SOD (${pa?.hashAlgorithm ?? "SHA-256"})'
                      : 'DG1 hash verification failed',
                  isDone: dgMatched,
                ),
                _buildTrustChainConnector(sigValid),
                _buildTrustChainNode(
                  title: 'Document signer certificate',
                  subtitle: sigValid
                      ? 'DSC signature validated (${pa?.signatureAlgorithm ?? "RSA/ECDSA"})'
                      : 'DSC signature validation failed',
                  isDone: sigValid,
                ),
                _buildTrustChainConnector(isGenuine || isUnverifiedAnchor),
                _buildTrustChainNode(
                  title: 'Country trust authority',
                  subtitle: isGenuine
                      ? '${pa?.cscaCountry ?? mrzResult.nationality} Master List CSCA verified'
                      : (isUnverifiedAnchor
                          ? 'Root CSCA for ${mrzResult.nationality} unverified in local trust store'
                          : 'Trust anchor verification failed'),
                  isDone: isGenuine || isUnverifiedAnchor,
                  isWarning: isUnverifiedAnchor,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        OutlinedButton.icon(
          onPressed: onShowSecurityDetails,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFA78BFA),
            side: const BorderSide(color: Color(0xFFA78BFA)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.info_outline_rounded, size: 18),
          label: const Text('Security details'),
        ),
        const SizedBox(height: 12),

        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: onContinueToLiveness,
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
                  'Continue to face check (Simulated)',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.face_retouching_natural_rounded, size: 20),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildTrustChainNode({
    required String title,
    required String subtitle,
    required bool isDone,
    bool isWarning = false,
  }) {
    Color borderColor;
    Color iconColor;
    IconData iconData;

    if (isWarning) {
      borderColor = const Color(0xFFF59E0B).withValues(alpha: 0.6);
      iconColor = const Color(0xFFF59E0B);
      iconData = Icons.warning_amber_rounded;
    } else if (isDone) {
      borderColor = const Color(0xFF2DD4BF).withValues(alpha: 0.5);
      iconColor = const Color(0xFF2DD4BF);
      iconData = Icons.check_circle_rounded;
    } else {
      borderColor = Colors.white12;
      iconColor = Colors.white24;
      iconData = Icons.radio_button_unchecked;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF131D2D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(iconData, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrustChainConnector(bool isDone) {
    return Center(
      child: Container(
        width: 2,
        height: 12,
        color: isDone ? const Color(0xFF2DD4BF) : Colors.white12,
      ),
    );
  }
}
