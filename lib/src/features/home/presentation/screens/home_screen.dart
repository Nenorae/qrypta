// lib/src/features/home/presentation/screens/home_screen.dart


import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:qrypta/src/core/config/theme/app_colors.dart';
import 'package:qrypta/src/features/home/presentation/widgets/action_buttons.dart';
import 'package:qrypta/src/features/home/presentation/widgets/home_body_widgets.dart';
import 'package:qrypta/src/features/profile/presentation/screens/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0; // Untuk melacak item aktif di bottom nav

  void _onItemTapped(int index) {
    if (index == 2) { // Index 2 adalah untuk QR Code Scanner
      _onQrButtonPressed();
    } else if (index == 4) { // Index 4 adalah untuk Profile
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ProfileScreen()),
      );
    } else {
      setState(() {
        _selectedIndex = index;
      });
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNavBar(),
      extendBody: true, // Membuat body bisa berada di belakang bottom nav bar
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
    return Stack(
      children: [
        // Konten utama yang bisa di-scroll
        ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0).copyWith(
            top: 8,
            bottom: 120, // Padding agar tidak tertutup nav bar & fade
          ),
          children: const [
            BalanceSection(),
            SizedBox(height: 24),
            AssetList(),
          ],
        ),
        // Efek Fading di bagian bawah
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
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      margin: const EdgeInsets.all(20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(50),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
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
              BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
              BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner), label: 'Scan'),
              BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: 'Stats'),
              BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
            ],
          ),
        ),
      ),
    );
  }
}
