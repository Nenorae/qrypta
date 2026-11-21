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
import 'package:qrypta/src/features/home/presentation/widgets/home_levy_banner.dart';
import 'package:qrypta/src/features/home/presentation/widgets/home_permitted_stay_card.dart';
import 'package:qrypta/src/features/home/presentation/widgets/home_portfolio_section.dart';
import 'package:qrypta/src/features/home/presentation/widgets/home_recent_activity_section.dart';
import 'package:qrypta/src/features/home/presentation/widgets/home_services_grid.dart';

export 'package:qrypta/src/features/home/presentation/widgets/home_levy_banner.dart';
export 'package:qrypta/src/features/home/presentation/widgets/home_permitted_stay_card.dart';
export 'package:qrypta/src/features/home/presentation/widgets/home_portfolio_section.dart';
export 'package:qrypta/src/features/home/presentation/widgets/home_recent_activity_section.dart';
export 'package:qrypta/src/features/home/presentation/widgets/home_services_grid.dart';

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

    final fullName = (btidCred?.fullName.isNotEmpty == true) ? btidCred!.fullName : 'Tourist';
    final firstName = fullName.split(' ').first;
    final isPaid = btidCred?.isLevyPaid ?? false;
    final activeRequest = verificationState.activeConsentRequest;

    // Ambil saldo IDRT dari provider tunggal
    final idrtBalance = ref.watch(idrtBalanceFormattedProvider);

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
          HomePortfolioBar(balance: idrtBalance, walletAddress: btidCred?.walletAddress),
          const SizedBox(height: 16),

          // 5. Quick Action Bar (Show my ID & Pay with QRIS)
          HomeQuickActionBar(onNavigateToTab: onNavigateToTab),
          const SizedBox(height: 16),

          // 6. Widget Permitted Stay (Izin Tinggal Imigrasi - ScrVisa)
          HomePermittedStayCard(btidCred: btidCred),
          const SizedBox(height: 16),

          // 7. Banner Status Tourist Levy
          HomeLevyBanner(isPaid: isPaid, btidCred: btidCred),
          const SizedBox(height: 20),

          // 8. Grid Layanan Wisata Terpercaya (Trusted Services Grid)
          const HomeServicesGrid(),
          const SizedBox(height: 24),

          // 9. Riwayat Aktivitas Terkini (Recent Activity)
          HomeRecentActivitySection(verificationState: verificationState),
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

}
