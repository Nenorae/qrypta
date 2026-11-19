// test/fixtures/demo_merchants_fixture.dart

import 'package:qrypta/src/features/verification/data/policy_matrix_constants.dart';

/// Fixture data merchant uji staging (Phase 0.3 / Phase 6.4).
/// Dipindahkan keluar dari kode produksi `lib/` untuk mematuhi Golden Rule R3.
const Map<String, DemoMerchantInfo> stagingDemoMerchants = {
  'hotel': DemoMerchantInfo(
    id: 'MCH-1042',
    name: 'Bali Ocean Resort',
    category: 'hotel',
    location: 'Nusa Dua, Bali',
    staffName: 'Kadek Sari',
    staffRole: 'Front Desk Agent',
    defaultTemplate: 'hotel_checkin',
    walletAddress: '0x1042B30Fa92742111531aC39Fe099F802F71B3E3',
  ),
  'car': DemoMerchantInfo(
    id: 'MCH-2087',
    name: 'Island Drive Car Rental',
    category: 'car',
    location: 'Kuta, Bali',
    staffName: 'Gede Mahendra',
    staffRole: 'Rental Agent',
    defaultTemplate: 'vehicle_rental',
    walletAddress: '0x2089c97fe5b2f2757f58a8a9a2a92c42289c0911',
  ),
  'cafe': DemoMerchantInfo(
    id: 'MCH-3311',
    name: 'Bali Coffee House',
    category: 'cafe',
    location: 'Canggu, Bali',
    staffName: 'Wayan Putra',
    staffRole: 'Barista & Cashier',
    defaultTemplate: 'age_check',
    walletAddress: '0x3311A9908F8718E237aDE73708aB59f212284bE0',
  ),
  'esim': DemoMerchantInfo(
    id: 'MCH-4190',
    name: 'Bali Connect eSIM',
    category: 'esim',
    location: 'Denpasar, Bali',
    staffName: 'Ketut Suastika',
    staffRole: 'Support Specialist',
    defaultTemplate: 'esim_activation',
    walletAddress: '0x4190825f385c7d2350a58adfc0f7193d256db01b',
  ),
  'tour': DemoMerchantInfo(
    id: 'MCH-5520',
    name: 'Bali Adventure Tours',
    category: 'tour',
    location: 'Ubud, Bali',
    staffName: 'Made Artha',
    staffRole: 'Head Guide',
    defaultTemplate: 'tour_participation',
    walletAddress: '0x5520e5ff38a7c645bcf56b823e590d9a6c9cf141',
  ),
};
