// lib/src/features/home/presentation/tabs/tab_id.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypta/src/core/config/blockchain_config.dart';
import 'package:qrypta/src/core/config/theme/app_colors.dart';
import 'package:qrypta/src/features/authentication/presentation/providers/btid_provider.dart';
import 'package:qrypta/src/features/verification/presentation/screens/dynamic_qr_screen.dart';
import 'package:qrypta/src/features/verification/presentation/widgets/btid_card_widget.dart';

class TabId extends ConsumerWidget {
  const TabId({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final btidCred = ref.watch(btidCredentialProvider);

    if (btidCred == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0F1D),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Bali Tourist ID',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded, color: Color(0xFF2DD4BF)),
            tooltip: 'Security Details',
            onPressed: () => _showSecurityDetails(context, btidCred),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Full BTID Card Visual
              BtidCardWidget(
                credential: btidCred,
                isMini: false,
              ),
              const SizedBox(height: 20),

              // 2. Action Button: Show Dynamic Rotating QR Code
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DynamicQrScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.qr_code_2_rounded, size: 22),
                  label: const Text(
                    'Show Dynamic QR Code (45s)',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: const Color(0xFF0A0F1D),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 3. Security Details Button
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () => _showSecurityDetails(context, btidCred),
                  icon: const Icon(Icons.shield_outlined, size: 18, color: Color(0xFF2DD4BF)),
                  label: const Text(
                    'View Security & Cryptographic Details',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF334155)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 4. Educational & Legal Notice Cards
              _buildNoticeCard(
                icon: Icons.menu_book_rounded,
                title: 'Official Identity Proxy',
                description:
                    'Your digital BTID serves as an authenticated identity proxy across accredited Bali businesses without requiring paper passport copies.',
              ),
              const SizedBox(height: 10),
              _buildNoticeCard(
                icon: Icons.lock_outline_rounded,
                title: 'Zero Biometric Exposure',
                description:
                    'Your passport chip biometrics and live facial capture vectors never leave your device. Only purpose-bound cryptographic consent is signed.',
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoticeCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF2DD4BF).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF2DD4BF), size: 18),
          ),
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
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSecurityDetails(BuildContext context, dynamic btidCred) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.verified_user_rounded, color: Color(0xFF2DD4BF), size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Security & Trust Details',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildSecurityRow('Chip Authenticity', 'Passive Auth (ICAO 9303 SOD Validated)', true),
                _buildSecurityRow('Document Signer (DS)', 'HM Passport Office (UK CSCA Anchor)', true),
                _buildSecurityRow('Biometric 1:1 Match', 'Score: 98.7% (Threshold: 85.0%)', true),
                _buildSecurityRow('Linked EVM Wallet', _maskAddr(btidCred.walletAddress), true),
                _buildSecurityRow('Ledger Network', BlockchainConfig.name, true),
                _buildSecurityRow('Audit Trail', 'ezsign-core Fastify AMQP Worker', true),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSecurityRow(String label, String value, bool isSuccess) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSuccess) ...[
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF34D399), size: 14),
                  const SizedBox(width: 5),
                ],
                Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _maskAddr(String addr) {
    if (addr.length > 14) {
      return '${addr.substring(0, 6)}...${addr.substring(addr.length - 4)}';
    }
    return addr;
  }
}
