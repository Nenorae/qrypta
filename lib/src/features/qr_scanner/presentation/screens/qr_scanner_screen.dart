
import 'package:flutter/material.dart';
import 'package:qrypta/src/core/config/theme/app_colors.dart';
import 'package:qrypta/src/features/send_money/presentation/screens/send_money_screen.dart';
import 'package:qrypta/src/features/transaction/presentation/screens/receive_screen.dart';
import 'package:qrypta/src/features/transaction/presentation/screens/send_scanner_screen.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            children: [
              SendScannerScreen(
                onScanResult: (address) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SendMoneyScreen(initialAddress: address),
                    ),
                  );
                },
              ),
              const ReceiveScreen(),
            ],
          ),
          _buildOverlayControls(),
        ],
      ),
    );
  }

  Widget _buildOverlayControls() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildControlButton(
              icon: Icons.close,
              onPressed: () => Navigator.of(context).pop(),
            ),
            _buildPageSwitcher(),
            const SizedBox(width: 48), // Spacer to balance the row
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton(
      {required IconData icon, required VoidCallback onPressed}) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }

  Widget _buildPageSwitcher() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(50),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSwitcherItem(text: 'Send', index: 0),
          const SizedBox(width: 4),
          _buildSwitcherItem(text: 'Receive', index: 1),
        ],
      ),
    );
  }

  Widget _buildSwitcherItem({required String text, required int index}) {
    final bool isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => _onPageChanged(index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(50),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isActive ? AppColors.accent : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
