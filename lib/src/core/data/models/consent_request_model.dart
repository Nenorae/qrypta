// lib/src/core/data/models/consent_request_model.dart

class ConsentRequestModel {
  final String requestId;
  final String merchantId;
  final String merchantName;
  final String merchantCategory;
  final String staffName;
  final String staffRole;
  final String purposeTemplate;
  final List<String> requestedFields;
  final String retentionPolicy;
  final DateTime expiresAt;

  const ConsentRequestModel({
    required this.requestId,
    required this.merchantId,
    required this.merchantName,
    required this.merchantCategory,
    required this.staffName,
    required this.staffRole,
    required this.purposeTemplate,
    required this.requestedFields,
    required this.retentionPolicy,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  ConsentRequestModel copyWith({
    String? requestId,
    String? merchantId,
    String? merchantName,
    String? merchantCategory,
    String? staffName,
    String? staffRole,
    String? purposeTemplate,
    List<String>? requestedFields,
    String? retentionPolicy,
    DateTime? expiresAt,
  }) {
    return ConsentRequestModel(
      requestId: requestId ?? this.requestId,
      merchantId: merchantId ?? this.merchantId,
      merchantName: merchantName ?? this.merchantName,
      merchantCategory: merchantCategory ?? this.merchantCategory,
      staffName: staffName ?? this.staffName,
      staffRole: staffRole ?? this.staffRole,
      purposeTemplate: purposeTemplate ?? this.purposeTemplate,
      requestedFields: requestedFields ?? this.requestedFields,
      retentionPolicy: retentionPolicy ?? this.retentionPolicy,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'requestId': requestId,
      'merchantId': merchantId,
      'merchantName': merchantName,
      'merchantCategory': merchantCategory,
      'staffName': staffName,
      'staffRole': staffRole,
      'purposeTemplate': purposeTemplate,
      'requestedFields': requestedFields,
      'retentionPolicy': retentionPolicy,
      'expiresAt': expiresAt.toIso8601String(),
    };
  }

  factory ConsentRequestModel.fromJson(Map<String, dynamic> json) {
    return ConsentRequestModel(
      requestId: json['requestId'] as String? ?? 'TX-448102',
      merchantId: json['merchantId'] as String? ?? 'MCH-1042',
      merchantName: json['merchantName'] as String? ?? 'Bali Ocean Resort',
      merchantCategory: json['merchantCategory'] as String? ?? 'hotel',
      staffName: json['staffName'] as String? ?? 'Kadek Sari',
      staffRole: json['staffRole'] as String? ?? 'Front Desk Agent',
      purposeTemplate: json['purposeTemplate'] as String? ?? 'hotel_checkin',
      requestedFields: (json['requestedFields'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const ['name', 'nationality', 'id_validity', 'passport_auth', 'levy_status', 'stay_valid'],
      retentionPolicy: json['retentionPolicy'] as String? ?? 'Retained for 30 days',
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'] as String) ??
              DateTime.now().add(const Duration(minutes: 3))
          : DateTime.now().add(const Duration(minutes: 3)),
    );
  }
}
