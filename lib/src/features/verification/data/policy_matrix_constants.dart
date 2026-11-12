// ignore_for_file: constant_identifier_names

// lib/src/features/verification/data/policy_matrix_constants.dart

/// Definisi 18 Atribut Ekosistem Bali Tourist ID (Berdasarkan Spesifikasi Resmi)
class AttributeDefinition {
  final String key;
  final String label;
  final String description;
  final String defaultReason;
  final bool isBiometric;

  const AttributeDefinition({
    required this.key,
    required this.label,
    required this.description,
    required this.defaultReason,
    this.isBiometric = false,
  });
}

/// Matriks 18 Atribut Resmi Ekosistem Bali Tourist ID
const Map<String, AttributeDefinition> policyAttributes = {
  'name': AttributeDefinition(
    key: 'name',
    label: 'Full Name',
    description: 'Traveler legal full name matching passport',
    defaultReason: 'Identifies the guest on official registry',
  ),
  'nationality': AttributeDefinition(
    key: 'nationality',
    label: 'Nationality',
    description: '3-letter ICAO country code',
    defaultReason: 'Required for immigration statistical reporting',
  ),
  'identity': AttributeDefinition(
    key: 'identity',
    label: 'Identity Verified',
    description: 'Cryptographic proof that tourist identity is verified',
    defaultReason: 'Proof of government-accredited digital onboarding',
  ),
  'passport_auth': AttributeDefinition(
    key: 'passport_auth',
    label: 'Passport Authenticated',
    description: 'Proof of ePassport chip Passive Authentication',
    defaultReason: 'Guarantees the physical passport is genuine',
  ),
  'id_validity': AttributeDefinition(
    key: 'id_validity',
    label: 'Tourist ID Validity',
    description: 'Validity timeframe of the issued Bali Tourist ID',
    defaultReason: 'Ensures the tourist credential is valid and active',
  ),
  'levy_status': AttributeDefinition(
    key: 'levy_status',
    label: 'Tourist Levy Status',
    description: 'Regional tourism contribution status (IDR 150,000)',
    defaultReason: 'Verifies mandatory tourism levy compliance',
  ),
  'over18': AttributeDefinition(
    key: 'over18',
    label: 'Age Eligibility (18+)',
    description: 'Zero-knowledge age verification (over 18)',
    defaultReason: 'Age verification without exposing date of birth',
  ),
  'over21': AttributeDefinition(
    key: 'over21',
    label: 'Age Eligibility (21+)',
    description: 'Zero-knowledge age verification (over 21)',
    defaultReason: 'Nightclub & lounge legal age compliance',
  ),
  'dob': AttributeDefinition(
    key: 'dob',
    label: 'Exact Date of Birth',
    description: 'Day, month, and year of birth',
    defaultReason: 'Required for special regulatory identification',
  ),
  'passport_number': AttributeDefinition(
    key: 'passport_number',
    label: 'Passport Number',
    description: 'Masked or full passport book number',
    defaultReason: 'Guest book audit compliance for lodging',
  ),
  'arrival': AttributeDefinition(
    key: 'arrival',
    label: 'Arrival Date',
    description: 'Date entered the Republic of Indonesia',
    defaultReason: 'Validates stay duration compliance',
  ),
  'departure': AttributeDefinition(
    key: 'departure',
    label: 'Departure Date',
    description: 'Estimated or confirmed departure date',
    defaultReason: 'Accommodation reservation matching',
  ),
  'visa_type': AttributeDefinition(
    key: 'visa_type',
    label: 'Visa Class',
    description: 'Official immigration visa type (e.g. e-VOA B1)',
    defaultReason: 'Validates traveler visa category',
  ),
  'stay_valid': AttributeDefinition(
    key: 'stay_valid',
    label: 'Permitted Stay Status',
    description: 'Immigration stay validity and remaining days',
    defaultReason: 'Ensures tourist is within lawful stay permit',
  ),
  'stay_expiry': AttributeDefinition(
    key: 'stay_expiry',
    label: 'Stay Permit Expiry',
    description: 'Exact expiration date of immigration permit',
    defaultReason: 'Vehicle rental and hotel check-in limit',
  ),
  'driving': AttributeDefinition(
    key: 'driving',
    label: 'Driving Credential Status',
    description: 'International driving license verified status',
    defaultReason: 'Mandatory before renting motorbikes or cars in Bali',
  ),
  'payment_confirm': AttributeDefinition(
    key: 'payment_confirm',
    label: 'Payment Confirmation',
    description: 'Cryptographic proof of QRIS or IDRT settlement',
    defaultReason: 'Payment confirmed without sharing PII',
  ),
  'emergency': AttributeDefinition(
    key: 'emergency',
    label: 'Emergency Contact',
    description: 'Kin contact name and masked telephone number',
    defaultReason: 'Used solely in case of medical or natural emergencies',
  ),
  'biometric': AttributeDefinition(
    key: 'biometric',
    label: 'Biometric Face Template',
    description: 'Raw facial biometric vector embedding',
    defaultReason: 'PERMANENTLY PROHIBITED FROM SHARING',
    isBiometric: true,
  ),
};

/// Alias ATTRS untuk kompatibilitas spesifikasi dokumen
const Map<String, AttributeDefinition> ATTRS = policyAttributes;

/// Definisi 9 Template Resmi Pemerintah
class PurposeTemplateDefinition {
  final String id;
  final String title;
  final List<String> eligibleCategories;
  final List<String> coreFields;
  final List<String> optionalFields;
  final String retentionPolicy;

  const PurposeTemplateDefinition({
    required this.id,
    required this.title,
    required this.eligibleCategories,
    required this.coreFields,
    required this.optionalFields,
    required this.retentionPolicy,
  });
}

/// Daftar 9 Template Resmi Pemerintah untuk Merchant
const Map<String, PurposeTemplateDefinition> purposeTemplates = {
  'hotel_checkin': PurposeTemplateDefinition(
    id: 'hotel_checkin',
    title: 'Hotel Check-in',
    eligibleCategories: ['hotel'],
    coreFields: ['name', 'nationality', 'id_validity', 'passport_auth', 'levy_status', 'stay_valid'],
    optionalFields: ['passport_number', 'dob', 'arrival', 'departure', 'visa_type', 'stay_expiry'],
    retentionPolicy: 'Retained for 30 days under Bali regional lodging policy',
  ),
  'vehicle_rental': PurposeTemplateDefinition(
    id: 'vehicle_rental',
    title: 'Vehicle Rental Eligibility',
    eligibleCategories: ['car'],
    coreFields: ['name', 'identity', 'over18', 'id_validity', 'passport_auth', 'driving'],
    optionalFields: ['dob', 'stay_expiry'],
    retentionPolicy: 'Retained for active vehicle rental duration + 90 days',
  ),
  'esim_activation': PurposeTemplateDefinition(
    id: 'esim_activation',
    title: 'eSIM Cellular Activation',
    eligibleCategories: ['esim'],
    coreFields: ['identity', 'id_validity'],
    optionalFields: ['name', 'nationality', 'passport_auth', 'passport_number', 'stay_expiry'],
    retentionPolicy: 'Retained for active telecom plan duration',
  ),
  'stay_validity': PurposeTemplateDefinition(
    id: 'stay_validity',
    title: 'Permitted Stay Confirmation',
    eligibleCategories: ['hotel', 'esim', 'car', 'tour'],
    coreFields: ['stay_valid'],
    optionalFields: ['stay_expiry', 'name'],
    retentionPolicy: 'Boolean verification only. Zero raw immigration records retained',
  ),
  'age_check': PurposeTemplateDefinition(
    id: 'age_check',
    title: 'Age Verification',
    eligibleCategories: ['hotel', 'car', 'cafe', 'tour', 'esim'],
    coreFields: ['over18'],
    optionalFields: ['over21'],
    retentionPolicy: 'Instant boolean check only. Zero personal data stored',
  ),
  'tour_participation': PurposeTemplateDefinition(
    id: 'tour_participation',
    title: 'Tour Participation',
    eligibleCategories: ['tour'],
    coreFields: ['name', 'identity', 'id_validity', 'over18'],
    optionalFields: ['nationality', 'emergency', 'levy_status'],
    retentionPolicy: 'Retained for tour activity date + 14 days',
  ),
  'levy_check': PurposeTemplateDefinition(
    id: 'levy_check',
    title: 'Tourist Levy Verification',
    eligibleCategories: ['hotel', 'esim', 'tour'],
    coreFields: ['levy_status'],
    optionalFields: ['name'],
    retentionPolicy: 'Levy status only. Financial details never disclosed',
  ),
  'payment_confirm': PurposeTemplateDefinition(
    id: 'payment_confirm',
    title: 'Payment Confirmation',
    eligibleCategories: ['cafe', 'hotel', 'car', 'tour', 'esim'],
    coreFields: ['payment_confirm'],
    optionalFields: [],
    retentionPolicy: 'Managed by licensed payment settlement providers',
  ),
  'emergency_support': PurposeTemplateDefinition(
    id: 'emergency_support',
    title: 'Emergency Support',
    eligibleCategories: ['tour', 'hotel'],
    coreFields: ['name', 'identity', 'emergency'],
    optionalFields: ['nationality'],
    retentionPolicy: 'Retained strictly for active emergency incident handling',
  ),
};

/// Alias TEMPLATES untuk kompatibilitas spesifikasi dokumen
const Map<String, PurposeTemplateDefinition> TEMPLATES = purposeTemplates;

/// Matriks Kebijakan Akses: allowed, conditional, prohibited
const Map<String, Map<String, String>> defaultPolicy = {
  'hotel': {
    'name': 'allowed',
    'nationality': 'allowed',
    'identity': 'allowed',
    'passport_auth': 'allowed',
    'id_validity': 'allowed',
    'levy_status': 'allowed',
    'over18': 'conditional',
    'over21': 'conditional',
    'dob': 'conditional',
    'passport_number': 'conditional',
    'arrival': 'conditional',
    'departure': 'conditional',
    'visa_type': 'conditional',
    'stay_valid': 'allowed',
    'stay_expiry': 'conditional',
    'driving': 'prohibited',
    'payment_confirm': 'allowed',
    'emergency': 'conditional',
    'biometric': 'prohibited',
  },
  'car': {
    'name': 'allowed',
    'nationality': 'allowed',
    'identity': 'allowed',
    'passport_auth': 'allowed',
    'id_validity': 'allowed',
    'levy_status': 'conditional',
    'over18': 'allowed',
    'over21': 'allowed',
    'dob': 'conditional',
    'passport_number': 'conditional',
    'arrival': 'conditional',
    'departure': 'conditional',
    'visa_type': 'prohibited',
    'stay_valid': 'allowed',
    'stay_expiry': 'conditional',
    'driving': 'allowed',
    'payment_confirm': 'allowed',
    'emergency': 'conditional',
    'biometric': 'prohibited',
  },
  'cafe': {
    'name': 'prohibited',
    'nationality': 'prohibited',
    'identity': 'conditional',
    'passport_auth': 'prohibited',
    'id_validity': 'prohibited',
    'levy_status': 'prohibited',
    'over18': 'conditional',
    'over21': 'conditional',
    'dob': 'prohibited',
    'passport_number': 'prohibited',
    'arrival': 'prohibited',
    'departure': 'prohibited',
    'visa_type': 'prohibited',
    'stay_valid': 'prohibited',
    'stay_expiry': 'prohibited',
    'driving': 'prohibited',
    'payment_confirm': 'allowed',
    'emergency': 'prohibited',
    'biometric': 'prohibited',
  },
  'esim': {
    'name': 'conditional',
    'nationality': 'conditional',
    'identity': 'allowed',
    'passport_auth': 'conditional',
    'id_validity': 'allowed',
    'levy_status': 'conditional',
    'over18': 'conditional',
    'over21': 'prohibited',
    'dob': 'prohibited',
    'passport_number': 'conditional',
    'arrival': 'prohibited',
    'departure': 'prohibited',
    'visa_type': 'prohibited',
    'stay_valid': 'allowed',
    'stay_expiry': 'conditional',
    'driving': 'prohibited',
    'payment_confirm': 'allowed',
    'emergency': 'prohibited',
    'biometric': 'prohibited',
  },
  'tour': {
    'name': 'allowed',
    'nationality': 'conditional',
    'identity': 'allowed',
    'passport_auth': 'conditional',
    'id_validity': 'allowed',
    'levy_status': 'allowed',
    'over18': 'allowed',
    'over21': 'conditional',
    'dob': 'conditional',
    'passport_number': 'prohibited',
    'arrival': 'prohibited',
    'departure': 'prohibited',
    'visa_type': 'prohibited',
    'stay_valid': 'conditional',
    'stay_expiry': 'prohibited',
    'driving': 'prohibited',
    'payment_confirm': 'allowed',
    'emergency': 'allowed',
    'biometric': 'prohibited',
  },
};

/// Alias DEFAULT_POLICY untuk kompatibilitas spesifikasi dokumen
const Map<String, Map<String, String>> DEFAULT_POLICY = defaultPolicy;

/// 5 Merchant Terakreditasi Ekosistem untuk Simulasi & Integrasi
class DemoMerchantInfo {
  final String id;
  final String name;
  final String category;
  final String location;
  final String staffName;
  final String staffRole;
  final String defaultTemplate;
  final String walletAddress;

  const DemoMerchantInfo({
    required this.id,
    required this.name,
    required this.category,
    required this.location,
    required this.staffName,
    required this.staffRole,
    required this.defaultTemplate,
    this.walletAddress = '0x89205A3A3b2A69De6Dbf7f01ED13B2108B2c43e7',
  });
}

const Map<String, DemoMerchantInfo> demoMerchants = {
  'hotel': DemoMerchantInfo(
    id: 'MCH-1042',
    name: 'Bali Ocean Resort',
    category: 'hotel',
    location: 'Seminyak, Bali',
    staffName: 'Kadek Sari',
    staffRole: 'Front Desk Agent',
    defaultTemplate: 'hotel_checkin',
    walletAddress: '0x10427b328d54236354050b188c03508f7b7643e2',
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

/// Alias DEMO_MERCHANTS untuk kompatibilitas spesifikasi dokumen
const Map<String, DemoMerchantInfo> DEMO_MERCHANTS = demoMerchants;
