// lib/src/features/verification/presentation/widgets/btid_card_widget.dart

import 'package:flutter/material.dart';
import 'package:qrypta/src/core/config/theme/app_colors.dart';
import 'package:qrypta/src/core/data/models/btid_credential_model.dart';

class BtidCardWidget extends StatelessWidget {
  final BtidCredentialModel credential;
  final bool isMini;
  final VoidCallback? onTap;

  const BtidCardWidget({
    super.key,
    required this.credential,
    this.isMini = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isMini) {
      return _buildMiniCard(context);
    }
    return _buildFullCard(context);
  }

  Widget _buildFullCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F3B37),
            Color(0xFF132A38),
            Color(0xFF1C1A2E),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              bottom: -30,
              child: Opacity(
                opacity: 0.07,
                child: const Icon(
                  Icons.shield_rounded,
                  size: 220,
                  color: Colors.white,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.accent.withValues(alpha: 0.2),
                              border: Border.all(
                                color: AppColors.accent,
                                width: 1,
                              ),
                            ),
                            child: const Icon(
                              Icons.verified_user_rounded,
                              size: 16,
                              color: AppColors.accent,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'PROVINSI BALI',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const Text(
                                'BALI TOURIST ID',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D9488).withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFF2DD4BF),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              size: 12,
                              color: Color(0xFF2DD4BF),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'ACTIVE',
                              style: TextStyle(
                                color: Color(0xFF2DD4BF),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Profile Info
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: const Color(0xFF1E293B),
                          border: Border.all(
                            color: AppColors.accent.withValues(alpha: 0.4),
                          ),
                        ),
                        child: const Icon(
                          Icons.person_rounded,
                          size: 38,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              credential.fullName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  'Passport: ${credential.passportMasked}',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.75),
                                    fontSize: 12,
                                    fontFamily: 'Courier',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    credential.nationality,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Visa: ${credential.visaType} · Stay: ${credential.daysRemaining} days left',
                              style: TextStyle(
                                color: AppColors.accent.withValues(alpha: 0.9),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // BTID Number
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          credential.btidNumber,
                          style: const TextStyle(
                            color: Color(0xFF5EEAD4),
                            fontSize: 13,
                            fontFamily: 'Courier',
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                        Text(
                          credential.walletAddress.isNotEmpty
                              ? (credential.walletAddress.length > 12
                                  ? '${credential.walletAddress.substring(0, 6)}...${credential.walletAddress.substring(credential.walletAddress.length - 4)}'
                                  : credential.walletAddress)
                              : '0xWeb3Bound',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 11,
                            fontFamily: 'Courier',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Badges
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _buildPill(
                        icon: Icons.fingerprint_rounded,
                        label: 'Identity Verified',
                        color: const Color(0xFF2DD4BF),
                      ),
                      _buildPill(
                        icon: Icons.nfc_rounded,
                        label: 'Passport Authenticated',
                        color: const Color(0xFFA78BFA),
                      ),
                      _buildPill(
                        icon: credential.isLevyPaid
                            ? Icons.check_circle_rounded
                            : Icons.access_time_rounded,
                        label: credential.isLevyPaid ? 'Levy Paid' : 'Levy Pending',
                        color: credential.isLevyPaid
                            ? const Color(0xFF34D399)
                            : const Color(0xFFFBBF24),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniCard(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF0F3B37), Color(0xFF132A38)],
          ),
          border: Border.all(
            color: AppColors.accent.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withValues(alpha: 0.2),
                border: Border.all(color: AppColors.accent),
              ),
              child: const Icon(
                Icons.verified_user_rounded,
                color: AppColors.accent,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    credential.fullName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${credential.btidNumber} · ${credential.nationality}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 11,
                      fontFamily: 'Courier',
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: credential.isLevyPaid
                    ? const Color(0xFF065F46)
                    : const Color(0xFF78350F),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                credential.isLevyPaid ? 'LEVY PAID' : 'LEVY DUE',
                style: TextStyle(
                  color: credential.isLevyPaid
                      ? const Color(0xFF34D399)
                      : const Color(0xFFFBBF24),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPill({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
