// lib/src/features/home/presentation/tabs/tab_profile.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypta/src/core/config/blockchain_config.dart';
import 'package:qrypta/src/features/authentication/presentation/providers/btid_provider.dart';
import 'package:qrypta/src/features/profile/presentation/widgets/security_group.dart';
import 'package:qrypta/src/features/transaction/logic/payment_controller.dart';
import 'package:qrypta/src/features/transaction/presentation/screens/levy_payment_screen.dart';
import 'package:qrypta/src/features/transaction/presentation/screens/levy_receipt_screen.dart';
import 'package:qrypta/src/features/verification/presentation/screens/privacy_audit_screen.dart';

class TabProfile extends ConsumerStatefulWidget {
  const TabProfile({super.key});

  @override
  ConsumerState<TabProfile> createState() => _TabProfileState();
}

class _TabProfileState extends ConsumerState<TabProfile> {
  bool _hotelAuto = true;
  bool _levyShare = true;
  bool _marketing = false;

  @override
  Widget build(BuildContext context) {
    final btidCred = ref.watch(btidCredentialProvider);
    final fullName = btidCred?.fullName ?? 'James Wilson';
    final btidNumber = btidCred?.btidNumber ?? 'BTID-2026-4471-0938';
    final nationality = btidCred?.nationality ?? 'GBR';
    final isPaid = btidCred?.isLevyPaid ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Profile & Privacy Controls',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          children: [
            // 1. Traveler Identity Header
            _buildProfileHeader(fullName, btidNumber, nationality),
            const SizedBox(height: 18),

            // 2. Trust & Privacy Hub
            _buildSectionHeader('Trust & Identity Hub'),
            const SizedBox(height: 8),
            _buildTile(
              icon: Icons.security_rounded,
              title: 'Privacy & Activity Centre',
              subtitle: 'Audit logs, shared attributes, and revoke access',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PrivacyAuditScreen()),
                );
              },
            ),
            const SizedBox(height: 8),
            _buildTile(
              icon: Icons.receipt_long_rounded,
              title: 'Official Tourist Levy Receipt',
              subtitle: isPaid ? 'View on-chain Bapenda receipt' : 'Status: Unpaid (IDR 150,000)',
              badge: isPaid ? 'Paid' : 'Due',
              badgeColor: isPaid ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
              onTap: () {
                if (isPaid) {
                  final receiptRef = btidCred?.levyReceiptRef ?? 'LVY-448102';
                  final receipt = LevyReceiptData(
                    receiptRef: receiptRef,
                    touristName: fullName,
                    btidNumber: btidNumber,
                    passportMasked: btidCred?.passportMasked ?? '••••••789',
                    amount: 'IDR 150,000',
                    amountRaw: 150000,
                    paymentMethod: 'Qrypta IDRT Wallet Balance',
                    txHash: '0x7b2f8a1e9c4d3b5a7e6f8a9b0c1d2e3f4a5b6c7d',
                    timestamp: DateTime.now(),
                    bapendaAddress: BlockchainConfig.bapendaTreasuryAddress,
                    mrzLine1: LevyReceiptData.generateMrzLine1(receiptRef, 150000),
                    mrzLine2: LevyReceiptData.generateMrzLine2(btidNumber),
                  );
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => LevyReceiptScreen(receipt: receipt)),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LevyPaymentScreen()),
                  );
                }
              },
            ),
            const SizedBox(height: 8),
            _buildTile(
              icon: Icons.directions_car_rounded,
              title: 'Driving Credential Status',
              subtitle: 'Category B International Driving Permit (Valid)',
              badge: 'Valid',
              badgeColor: const Color(0xFF34D399),
              onTap: () => _showDrivingDetails(context),
            ),
            const SizedBox(height: 20),

            // 3. Global Privacy Permissions (Toggles)
            _buildSectionHeader('Global Privacy Permissions'),
            const SizedBox(height: 8),
            _buildSwitchTile(
              title: 'Hotel Fast-Track Auto Check-in',
              subtitle: 'Auto-share check-in attributes with properties visited within 30 days',
              value: _hotelAuto,
              onChanged: (val) => setState(() => _hotelAuto = val),
            ),
            const SizedBox(height: 8),
            _buildSwitchTile(
              title: 'Merchant Levy Verification',
              subtitle: 'Allow accredited merchants to verify Levy status (returns boolean only)',
              value: _levyShare,
              onChanged: (val) => setState(() => _levyShare = val),
            ),
            const SizedBox(height: 8),
            _buildSwitchTile(
              title: 'Anonymous Local Offers',
              subtitle: 'Share nationality for regional cultural discounts (Zero name or PII)',
              value: _marketing,
              onChanged: (val) => setState(() => _marketing = val),
            ),
            const SizedBox(height: 20),

            // 4. Web3 Wallet & Key Security (Qrypta SecurityGroup)
            _buildSectionHeader('Web3 Security & Cryptographic Vault'),
            const SizedBox(height: 8),
            const SecurityGroup(),
            const SizedBox(height: 20),

            // 5. System Philosophy & Principles
            _buildPrinciplesCard(),
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(String fullName, String btidNumber, String nationality) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F766E), Color(0xFF2DD4BF)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.person_rounded, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      fullName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text('🇬🇧', style: TextStyle(fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  btidNumber,
                  style: const TextStyle(
                    color: Color(0xFF2DD4BF),
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF065F46).withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'VERIFIED VISITOR • PASSPORT AUTHENTICATED',
                    style: TextStyle(
                      color: Color(0xFF34D399),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.6,
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

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF94A3B8),
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String title,
    required String subtitle,
    String? badge,
    Color? badgeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF1F2937)),
        ),
        child: Row(
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
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                  ),
                ],
              ),
            ),
            if (badge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (badgeColor ?? const Color(0xFF2DD4BF)).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    color: badgeColor ?? const Color(0xFF2DD4BF),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF64748B), size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Row(
        children: [
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
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: const Color(0xFF2DD4BF),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildPrinciplesCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Row(
            children: [
              Icon(Icons.policy_rounded, size: 16, color: Color(0xFF2DD4BF)),
              SizedBox(width: 8),
              Text(
                'Bali Tourist ID Privacy Covenant',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            '• Verify Once: No paper passport photocopying at hotels or merchants.\n• Share Selectively: Only government-regulated minimum attributes.\n• Zero Biometrics: Face vectors never leave device enclave.\n• Immutable Audit: All consents anchored to Hyperledger Besu.',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, height: 1.5),
          ),
        ],
      ),
    );
  }

  void _showDrivingDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.directions_car_rounded, color: Color(0xFFFBBF24)),
            SizedBox(width: 10),
            Text('Driving Credential', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('License Category: Class B (Motor Vehicle & Scooter)', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            SizedBox(height: 6),
            Text('Issuing Country: United Kingdom (DVLA)', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
            SizedBox(height: 6),
            Text('Status: Accredited for Bali Scooter & Car Rental (Polda Bali Compliant)', style: TextStyle(color: Color(0xFF34D399), fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Color(0xFF2DD4BF))),
          ),
        ],
      ),
    );
  }
}
