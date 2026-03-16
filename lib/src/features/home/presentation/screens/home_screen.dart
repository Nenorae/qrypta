import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypta/src/core/config/theme/app_colors.dart';
import 'package:qrypta/src/features/home/logic/home_controller.dart';
import 'package:qrypta/src/features/home/presentation/widgets/action_buttons.dart';
import 'package:qrypta/src/features/home/presentation/widgets/home_body_widgets.dart';
import 'package:qrypta/src/features/home/presentation/providers/home_providers.dart';
import 'package:qrypta/src/features/tokens/presentation/providers/token_provider.dart';
import 'package:qrypta/src/features/profile/presentation/screens/profile_screen.dart';
import 'package:qrypta/src/features/tokens/presentation/screens/manage_tokens_screen.dart';
import 'package:qrypta/src/features/transaction/presentation/screens/transaction_history_screen.dart';

final homeControllerProvider =
    ChangeNotifierProvider((ref) => HomeController());

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  void _onItemTapped(int index) {
    final controller = ref.read(homeControllerProvider);
    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => const TransactionHistoryScreen()),
      );
    } else if (index == 2) {
      _onQrButtonPressed();
    } else if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ManageTokensScreen()),
      );
    } else if (index == 4) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ProfileScreen()),
      );
    } else {
      controller.setSelectedIndex(index);
    }
  }

  void _onQrButtonPressed() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      builder: (context) {
        return const Padding(
          padding: EdgeInsets.all(16.0),
          child: ActionButtons(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = ref.watch(homeControllerProvider).selectedIndex;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNavBar(selectedIndex),
      extendBody: true,
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      title: const Text(
        'QRYPTA',
        style: TextStyle(
          color: AppColors.accent,
          fontWeight: FontWeight.bold,
          fontSize: 24,
        ),
      ),
      actions: [
        IconButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            );
          },
          icon: const CircleAvatar(
            backgroundColor: AppColors.primary,
            child: Icon(Icons.person, color: AppColors.accent, size: 20),
          ),
        ),
        IconButton(
          onPressed: () => print('Tombol Notifikasi ditekan'),
          icon: const Icon(
            Icons.notifications,
            color: AppColors.accent,
            size: 28,
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildBody() {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(totalBalanceProvider);
        await ref.read(tokenNotifierProvider.notifier).fetchUserTokens();
      },
      child: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0)
                .copyWith(top: 8, bottom: 120),
            children: const [
              BalanceSection(),
              SizedBox(height: 24),
              AssetList(),
            ],
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 150,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.background.withOpacity(0),
                    AppColors.background,
                  ],
                  stops: const [0.0, 0.9],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar(int selectedIndex) {
    return Container(
      margin: const EdgeInsets.all(20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(50),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: BottomNavigationBar(
            currentIndex: selectedIndex,
            onTap: _onItemTapped,
            backgroundColor: Colors.white.withOpacity(0.15),
            type: BottomNavigationBarType.fixed,
            showSelectedLabels: false,
            showUnselectedLabels: false,
            selectedItemColor: AppColors.accent,
            unselectedItemColor: Colors.white.withOpacity(0.7),
            elevation: 0,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.history), label: 'History'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.qr_code_scanner), label: 'Scan'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.search), label: 'Discover'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline), label: 'Profile'),
            ],
          ),
        ),
      ),
    );
  }
}
