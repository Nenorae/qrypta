// lib/src/features/home/presentation/screens/home_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypta/src/core/config/theme/app_colors.dart';
import 'package:qrypta/src/features/home/logic/home_controller.dart';
import 'package:qrypta/src/features/home/presentation/tabs/tab_explore.dart';
import 'package:qrypta/src/features/home/presentation/tabs/tab_home.dart';
import 'package:qrypta/src/features/home/presentation/tabs/tab_id.dart';
import 'package:qrypta/src/features/home/presentation/tabs/tab_pay.dart';
import 'package:qrypta/src/features/home/presentation/tabs/tab_profile.dart';
import 'package:qrypta/src/features/tokens/presentation/providers/token_provider.dart';
import 'package:qrypta/src/features/verification/logic/verification_controller.dart';

final homeControllerProvider =
    ChangeNotifierProvider((ref) => HomeController());

class HomeScreen extends ConsumerStatefulWidget {
  final int initialIndex;

  const HomeScreen({
    super.key,
    this.initialIndex = 0,
  });

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialIndex != 0) {
        ref.read(homeControllerProvider).setSelectedIndex(widget.initialIndex);
      }
      // Inisialisasi token & audit history saat dashboard dibuka
      ref.read(tokenNotifierProvider.notifier).fetchUserTokens();
      ref.read(verificationControllerProvider.notifier).loadAuditHistory();
    });
  }

  void _onItemTapped(int index) {
    ref.read(homeControllerProvider).setSelectedIndex(index);
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = ref.watch(homeControllerProvider).selectedIndex;

    final tabs = [
      TabHome(onNavigateToTab: _onItemTapped),
      const TabPay(),
      const TabId(),
      const TabExplore(),
      const TabProfile(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      body: IndexedStack(
        index: selectedIndex,
        children: tabs,
      ),
      bottomNavigationBar: _buildBottomNavBar(selectedIndex),
      extendBody: true,
    );
  }

  Widget _buildBottomNavBar(int selectedIndex) {
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF111827).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(
                color: const Color(0xFF334155).withValues(alpha: 0.6),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: BottomNavigationBar(
              currentIndex: selectedIndex,
              onTap: _onItemTapped,
              backgroundColor: Colors.transparent,
              type: BottomNavigationBarType.fixed,
              showSelectedLabels: true,
              showUnselectedLabels: true,
              selectedItemColor: AppColors.accent,
              unselectedItemColor: const Color(0xFF94A3B8),
              selectedFontSize: 11,
              unselectedFontSize: 10,
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
              elevation: 0,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_rounded),
                  activeIcon: Icon(Icons.home_rounded, color: AppColors.accent),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.qr_code_scanner_rounded),
                  activeIcon: Icon(Icons.qr_code_scanner_rounded, color: AppColors.accent),
                  label: 'Pay',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.badge_rounded),
                  activeIcon: Icon(Icons.badge_rounded, color: AppColors.accent),
                  label: 'ID',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.explore_rounded),
                  activeIcon: Icon(Icons.explore_rounded, color: AppColors.accent),
                  label: 'Explore',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_rounded),
                  activeIcon: Icon(Icons.person_rounded, color: AppColors.accent),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
