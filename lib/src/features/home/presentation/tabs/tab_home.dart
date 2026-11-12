// lib/src/features/home/presentation/tabs/tab_home.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypta/src/core/config/blockchain_config.dart';
import 'package:qrypta/src/core/config/theme/app_colors.dart';
import 'package:qrypta/src/core/utils/formatters.dart';
import 'package:qrypta/src/features/authentication/presentation/providers/btid_provider.dart';
import 'package:qrypta/src/features/tokens/presentation/providers/token_provider.dart';
import 'package:qrypta/src/features/transaction/logic/payment_controller.dart';
import 'package:qrypta/src/features/transaction/presentation/screens/levy_payment_screen.dart';
import 'package:qrypta/src/features/transaction/presentation/screens/levy_receipt_screen.dart';
import 'package:qrypta/src/features/verification/logic/verification_controller.dart';
import 'package:qrypta/src/features/verification/presentation/screens/consent_request_screen.dart';
import 'package:qrypta/src/features/verification/presentation/screens/dynamic_qr_screen.dart';
import 'package:qrypta/src/features/verification/presentation/screens/privacy_audit_screen.dart';
import 'package:qrypta/src/features/verification/presentation/widgets/btid_card_widget.dart';

class TabHome extends ConsumerWidget {
  final Function(int) onNavigateToTab;

  const TabHome({
    super.key,
    required this.onNavigateToTab,
  });

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 4 && hour < 12) return 'Selamat pagi';
    if (hour >= 12 && hour < 15) return 'Selamat siang';
    if (hour >= 15 && hour < 18) return 'Selamat sore';
    return 'Selamat malam';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final btidCred = ref.watch(btidCredentialProvider);
    final verificationState = ref.watch(verificationControllerProvider);
    final tokensAsync = ref.watch(tokenNotifierProvider);

    final fullName = btidCred?.fullName ?? 'James Wilson';
    final firstName = fullName.split(' ').first;
    final isPaid = btidCred?.isLevyPaid ?? false;
    final activeRequest = verificationState.activeConsentRequest;

    // Ambil saldo IDRT
    String idrtBalance = 'Rp 2.480.000';
    tokensAsync.whenData((tokens) {
      final idrt = tokens.where((t) => t.symbol == 'IDRT').firstOrNull;
      if (idrt != null && idrt.balance > BigInt.zero) {
        idrtBalance = formatBigInt(
          idrt.balance,
          idrt.decimals,
          isCurrency: true,
        );
      }
    });

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(tokenNotifierProvider.notifier).fetchUserTokens();
        await ref.read(verificationControllerProvider.notifier).loadAuditHistory();
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0).copyWith(top: 8, bottom: 120),
        children: [
          // 1. Smart Greeting Header
          _buildGreetingHeader(firstName),
          const SizedBox(height: 14),

          // 2. Pending Request Alert Banner (Muncul jika ada request merchant)
          if (activeRequest != null) ...[
            _buildPendingAlertBanner(context, activeRequest),
            const SizedBox(height: 14),
          ],

          // 3. Mini BTID Card
          if (btidCred != null)
            BtidCardWidget(
              credential: btidCred,
              isMini: true,
            ),
          const SizedBox(height: 12),

          // 4. Saldo Portofolio IDRT & Wallet Bar
          _buildPortfolioBar(context, idrtBalance, btidCred?.walletAddress),
          const SizedBox(height: 16),

          // 5. Quick Action Bar (Show my ID & Pay with QRIS)
          _buildQuickActionBar(context),
          const SizedBox(height: 16),

          // 6. Widget Permitted Stay (Izin Tinggal Imigrasi - ScrVisa)
          _buildPermittedStayWidget(context, btidCred),
          const SizedBox(height: 16),

          // 7. Banner Status Tourist Levy
          _buildLevyBanner(context, isPaid, btidCred),
          const SizedBox(height: 20),

          // 8. Grid Layanan Wisata Terpercaya (Trusted Services Grid)
          _buildServicesGrid(context, ref),
          const SizedBox(height: 24),

          // 9. Riwayat Aktivitas Terkini (Recent Activity)
          _buildRecentActivitySection(context, verificationState),
        ],
      ),
    );
  }

  Widget _buildGreetingHeader(String firstName) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_getGreeting()}, $firstName',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: const [
                Icon(Icons.location_on_rounded, size: 14, color: Color(0xFF2DD4BF)),
                SizedBox(width: 4),
                Text(
                  'Bali, Indonesia • Verified Tourist Identity',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF0F766E).withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF2DD4BF).withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.shield_rounded, size: 13, color: Color(0xFF2DD4BF)),
              SizedBox(width: 4),
              Text(
                'e-Passport',
                style: TextStyle(
                  color: Color(0xFF2DD4BF),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPendingAlertBanner(BuildContext context, dynamic request) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ConsentRequestScreen(request: request),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF78350F).withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_active_rounded,
                color: Color(0xFFFBBF24),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '1 consent request waiting',
                    style: TextStyle(
                      color: Color(0xFFFDE68A),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${request.merchantName} • ${request.purposeTemplate}',
                    style: const TextStyle(
                      color: Color(0xFFD1D5DB),
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFFBBF24),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPortfolioBar(BuildContext context, String balance, String? walletAddress) {
    final shortWallet = (walletAddress != null && walletAddress.length > 14)
        ? '${walletAddress.substring(0, 6)}...${walletAddress.substring(walletAddress.length - 4)}'
        : (walletAddress ?? '0x71CB...B4D0');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2DD4BF).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Color(0xFF2DD4BF),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'IDRT Balance (Besu)',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    balance,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          InkWell(
            onTap: () {
              if (walletAddress != null) {
                Clipboard.setData(ClipboardData(text: walletAddress));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Wallet address copied to clipboard.'),
                    backgroundColor: Color(0xFF0F766E),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Row(
                children: [
                  Text(
                    shortWallet,
                    style: const TextStyle(
                      color: Color(0xFF2DD4BF),
                      fontFamily: 'monospace',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.copy_rounded, size: 12, color: Color(0xFF2DD4BF)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionBar(BuildContext context) {
    return Row(
      children: [
        // Show my ID
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DynamicQrScreen()),
              );
            },
            icon: const Icon(Icons.qr_code_2_rounded, size: 20),
            label: const Text(
              'Show my ID',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Pay with QRIS
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => onNavigateToTab(1), // Switch ke Tab Pay
            icon: const Icon(Icons.payment_rounded, size: 20),
            label: const Text(
              'Pay with QRIS',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: const Color(0xFF0A0F1D),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPermittedStayWidget(BuildContext context, dynamic btidCred) {
    final daysLeft = btidCred?.daysRemaining ?? 28;
    final visaType = btidCred?.visaType ?? 'e-VOA B1';

    return InkWell(
      onTap: () => _showPermittedStayDetails(context, btidCred),
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
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF065F46).withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.calendar_month_rounded,
                color: Color(0xFF34D399),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Permitted Stay Status',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$visaType • $daysLeft days remaining',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Immigration Status: Valid • Click for Details',
                    style: TextStyle(
                      color: Color(0xFF34D399),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF64748B),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevyBanner(BuildContext context, bool isPaid, dynamic btidCred) {
    if (isPaid) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF065F46).withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF34D399), size: 18),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Official Tourist Levy Settled',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Ref: ${btidCred?.levyReceiptRef ?? "LVY-448102"}',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ],
            ),
            TextButton(
              onPressed: () {
                final receiptRef = btidCred?.levyReceiptRef ?? 'LVY-448102';
                final btidNumber = btidCred?.btidNumber ?? 'BTID-2026-4471-0938';
                final receipt = LevyReceiptData(
                  receiptRef: receiptRef,
                  touristName: btidCred?.fullName ?? 'James Wilson',
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
                  MaterialPageRoute(
                    builder: (context) => LevyReceiptScreen(receipt: receipt),
                  ),
                );
              },
              child: const Text(
                'View Receipt',
                style: TextStyle(color: Color(0xFF2DD4BF), fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF78350F).withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFFBBF24), size: 20),
              SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tourist Levy Due (IDR 150,000)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Perda No. 6/2023 • Environmental Preservation',
                    style: TextStyle(
                      color: Color(0xFFD1D5DB),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LevyPaymentScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Pay Now',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesGrid(BuildContext context, WidgetRef ref) {
    final services = [
      {'id': 'hotel', 'label': 'Hotel Check-in', 'icon': Icons.hotel_rounded, 'color': const Color(0xFF38BDF8)},
      {'id': 'esim', 'label': 'Get eSIM', 'icon': Icons.sim_card_rounded, 'color': const Color(0xFFA78BFA)},
      {'id': 'car', 'label': 'Vehicle Rental', 'icon': Icons.directions_car_rounded, 'color': const Color(0xFFFBBF24)},
      {'id': 'transport', 'label': 'Transport', 'icon': Icons.local_taxi_rounded, 'color': const Color(0xFF34D399)},
      {'id': 'insurance', 'label': 'Insurance', 'icon': Icons.health_and_safety_rounded, 'color': const Color(0xFFF43F5E)},
      {'id': 'emergency', 'label': 'Emergency 24/7', 'icon': Icons.sos_rounded, 'color': const Color(0xFFEF4444)},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Trusted Island Services',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.05,
          ),
          itemCount: services.length,
          itemBuilder: (context, index) {
            final svc = services[index];
            return InkWell(
              onTap: () {
                final id = svc['id'] as String;
                if (id == 'hotel' || id == 'esim' || id == 'car') {
                  final req = ref.read(verificationControllerProvider.notifier).triggerMerchantSimulation(id);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ConsentRequestScreen(request: req)),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${svc['label']} verified service is connected and active.'),
                      backgroundColor: const Color(0xFF0F766E),
                    ),
                  );
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF1F2937)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (svc['color'] as Color).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        svc['icon'] as IconData,
                        color: svc['color'] as Color,
                        size: 22,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      svc['label'] as String,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFE2E8F0),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRecentActivitySection(BuildContext context, dynamic verificationState) {
    final recent = verificationState.auditHistory.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Activity',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PrivacyAuditScreen()),
                );
              },
              child: const Text(
                'View All',
                style: TextStyle(color: Color(0xFF2DD4BF), fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (recent.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1F2937)),
            ),
            child: const Center(
              child: Text(
                'No transactions recorded yet.',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recent.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final audit = recent[index];
              final isApproved = audit.status.toLowerCase() == 'approved';
              final isPaid = audit.status.toLowerCase() == 'paid';

              Color statusColor = const Color(0xFFEF4444);
              if (isApproved) statusColor = const Color(0xFF34D399);
              if (isPaid) statusColor = const Color(0xFF2DD4BF);

              return Container(
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
                        color: statusColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isPaid ? Icons.check_circle_rounded : (isApproved ? Icons.verified_rounded : Icons.block_rounded),
                        color: statusColor,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            audit.organisation,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            audit.action,
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        audit.status,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  void _showPermittedStayDetails(BuildContext context, dynamic btidCred) {
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
                    const Text(
                      'Immigration Stay Permit',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildModalRow('Visa Category', btidCred?.visaType ?? 'e-VOA B1 (Tourism)'),
                _buildModalRow('Arrival Date', btidCred?.arrivalDate ?? '2026-10-15'),
                _buildModalRow('Permit Expiry', btidCred?.stayExpiry ?? '2026-11-14'),
                _buildModalRow('Immigration Anchor', 'Kantor Imigrasi Kelas I Khusus TPI Ngurah Rai'),
                _buildModalRow('Extension Status', 'Eligible for 1x 30-day extension via official portal'),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModalRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
