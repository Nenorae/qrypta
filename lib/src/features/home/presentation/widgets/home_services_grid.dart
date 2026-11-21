// lib/src/features/home/presentation/widgets/home_services_grid.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypta/src/features/verification/presentation/screens/dynamic_qr_screen.dart';

/// Grid layanan pariwisata terakreditasi (Phase 7.2).
class HomeServicesGrid extends ConsumerWidget {
  const HomeServicesGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  // Arahkan wisatawan untuk menampilkan Dynamic QR kepada merchant resmi (Phase 7.2 / F-15b)
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const DynamicQrScreen()),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Tunjukkan Dynamic QR Anda kepada merchant ${svc['label']} untuk memulai verifikasi real-time.'),
                      backgroundColor: const Color(0xFF0F766E),
                    ),
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
}
