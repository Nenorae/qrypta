// lib/src/core/data/models/btid_credential_model.dart

class BtidCredentialModel {
  final String btidNumber;
  final String fullName;
  final String nationality;
  final String passportMasked;
  final String dob;
  final String docExpiry;
  final String visaType;
  final String arrivalDate;
  final String stayExpiry;
  final String levyStatus;
  final String? levyReceiptRef;
  final String walletAddress;
  final DateTime issuedAt;

  const BtidCredentialModel({
    required this.btidNumber,
    required this.fullName,
    required this.nationality,
    required this.passportMasked,
    required this.dob,
    required this.docExpiry,
    required this.visaType,
    required this.arrivalDate,
    required this.stayExpiry,
    required this.levyStatus,
    this.levyReceiptRef,
    required this.walletAddress,
    required this.issuedAt,
  });

  bool get isLevyPaid => levyStatus.toLowerCase() == 'paid';

  int get daysRemaining {
    try {
      final expiryDate = DateTime.parse(stayExpiry);
      final difference = expiryDate.difference(DateTime.now()).inDays;
      return difference < 0 ? 0 : difference;
    } catch (_) {
      return 0;
    }
  }

  BtidCredentialModel copyWith({
    String? btidNumber,
    String? fullName,
    String? nationality,
    String? passportMasked,
    String? dob,
    String? docExpiry,
    String? visaType,
    String? arrivalDate,
    String? stayExpiry,
    String? levyStatus,
    String? levyReceiptRef,
    String? walletAddress,
    DateTime? issuedAt,
  }) {
    return BtidCredentialModel(
      btidNumber: btidNumber ?? this.btidNumber,
      fullName: fullName ?? this.fullName,
      nationality: nationality ?? this.nationality,
      passportMasked: passportMasked ?? this.passportMasked,
      dob: dob ?? this.dob,
      docExpiry: docExpiry ?? this.docExpiry,
      visaType: visaType ?? this.visaType,
      arrivalDate: arrivalDate ?? this.arrivalDate,
      stayExpiry: stayExpiry ?? this.stayExpiry,
      levyStatus: levyStatus ?? this.levyStatus,
      levyReceiptRef: levyReceiptRef ?? this.levyReceiptRef,
      walletAddress: walletAddress ?? this.walletAddress,
      issuedAt: issuedAt ?? this.issuedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'btidNumber': btidNumber,
      'fullName': fullName,
      'nationality': nationality,
      'passportMasked': passportMasked,
      'dob': dob,
      'docExpiry': docExpiry,
      'visaType': visaType,
      'arrivalDate': arrivalDate,
      'stayExpiry': stayExpiry,
      'levyStatus': levyStatus,
      'levyReceiptRef': levyReceiptRef,
      'walletAddress': walletAddress,
      'issuedAt': issuedAt.toIso8601String(),
    };
  }

  factory BtidCredentialModel.fromJson(Map<String, dynamic> json) {
    return BtidCredentialModel(
      btidNumber: json['btidNumber'] as String? ?? 'BTID-2026-4471-0938',
      fullName: json['fullName'] as String? ?? 'James Wilson',
      nationality: json['nationality'] as String? ?? 'GBR',
      passportMasked: json['passportMasked'] as String? ?? '••••••789',
      dob: json['dob'] as String? ?? '1988-04-12',
      docExpiry: json['docExpiry'] as String? ?? '2031-08-15',
      visaType: json['visaType'] as String? ?? 'e-VOA B1',
      arrivalDate: json['arrivalDate'] as String? ?? '2026-10-15',
      stayExpiry: json['stayExpiry'] as String? ?? '2026-11-14',
      levyStatus: json['levyStatus'] as String? ?? 'unpaid',
      levyReceiptRef: json['levyReceiptRef'] as String?,
      walletAddress: json['walletAddress'] as String? ?? '',
      issuedAt: json['issuedAt'] != null
          ? DateTime.tryParse(json['issuedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  /// Demo default credential matching the official Bali Tourist ID specification
  factory BtidCredentialModel.defaultDemo({String walletAddress = '0x71C...B29'}) {
    return BtidCredentialModel(
      btidNumber: 'BTID-2026-4471-0938',
      fullName: 'James Wilson',
      nationality: 'GBR',
      passportMasked: '••••••789',
      dob: '1988-04-12',
      docExpiry: '2031-08-15',
      visaType: 'e-VOA B1',
      arrivalDate: '2026-10-15',
      stayExpiry: '2026-11-14',
      levyStatus: 'unpaid',
      levyReceiptRef: null,
      walletAddress: walletAddress,
      issuedAt: DateTime.now(),
    );
  }
}
