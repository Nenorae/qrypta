// lib/src/features/home/presentation/tabs/tab_explore.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypta/src/features/verification/data/policy_matrix_constants.dart';
import 'package:qrypta/src/features/verification/logic/verification_controller.dart';
import 'package:qrypta/src/features/verification/presentation/screens/consent_request_screen.dart';

class TabExplore extends ConsumerStatefulWidget {
  const TabExplore({super.key});

  @override
  ConsumerState<TabExplore> createState() => _TabExploreState();
}

class _TabExploreState extends ConsumerState<TabExplore> {
  String _selectedCategory = 'all';

  @override
  Widget build(BuildContext context) {
    final allMerchants = demoMerchants.values.toList();
    final filteredMerchants = _selectedCategory == 'all'
        ? allMerchants
        : allMerchants.where((m) => m.category == _selectedCategory).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Explore Bali Ecosystem',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Accredited Government Partner Network',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          children: [
            // 1. Filter Chips Row
            _buildFilterChips(),
            const SizedBox(height: 16),

            // 2. Info Banner
            _buildInfoBanner(),
            const SizedBox(height: 16),

            // 3. Merchants List
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredMerchants.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final merchant = filteredMerchants[index];
                return _buildMerchantCard(context, merchant);
              },
            ),
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = [
      {'id': 'all', 'label': 'All'},
      {'id': 'hotel', 'label': 'Stay'},
      {'id': 'cafe', 'label': 'Eat & Drink'},
      {'id': 'car', 'label': 'Drive'},
      {'id': 'esim', 'label': 'Connect'},
      {'id': 'tour', 'label': 'Tours'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = _selectedCategory == f['id'];
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilterChip(
              selected: isSelected,
              label: Text(f['label']!),
              labelStyle: TextStyle(
                color: isSelected ? Colors.black : const Color(0xFFCBD5E1),
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
              backgroundColor: const Color(0xFF1E293B),
              selectedColor: const Color(0xFF2DD4BF),
              checkmarkColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? const Color(0xFF2DD4BF) : const Color(0xFF334155),
                ),
              ),
              onSelected: (val) {
                setState(() => _selectedCategory = f['id']!);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F766E).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2DD4BF).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: const [
          Icon(Icons.touch_app_rounded, color: Color(0xFF2DD4BF), size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tap any merchant below to trigger a live Selective Disclosure verification handshake simulation.',
              style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 11, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMerchantCard(BuildContext context, DemoMerchantInfo merchant) {
    IconData categoryIcon = Icons.storefront_rounded;
    Color iconColor = const Color(0xFF2DD4BF);

    if (merchant.category == 'hotel') {
      categoryIcon = Icons.hotel_rounded;
      iconColor = const Color(0xFF38BDF8);
    } else if (merchant.category == 'car') {
      categoryIcon = Icons.directions_car_rounded;
      iconColor = const Color(0xFFFBBF24);
    } else if (merchant.category == 'cafe') {
      categoryIcon = Icons.local_cafe_rounded;
      iconColor = const Color(0xFFA78BFA);
    } else if (merchant.category == 'esim') {
      categoryIcon = Icons.sim_card_rounded;
      iconColor = const Color(0xFF34D399);
    } else if (merchant.category == 'tour') {
      categoryIcon = Icons.landscape_rounded;
      iconColor = const Color(0xFFF43F5E);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(categoryIcon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            merchant.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.verified_rounded,
                          color: Color(0xFF2DD4BF),
                          size: 15,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${merchant.id} • ${merchant.location}',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Default Purpose: ${merchant.defaultTemplate}',
                  style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11),
                ),
                Text(
                  'Agent: ${merchant.staffName}',
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton.icon(
              onPressed: () {
                final req = ref
                    .read(verificationControllerProvider.notifier)
                    .triggerMerchantSimulation(merchant.category);

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ConsentRequestScreen(request: req),
                  ),
                );
              },
              icon: const Icon(Icons.fingerprint_rounded, size: 18),
              label: const Text(
                'Simulate Verification Handshake',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
