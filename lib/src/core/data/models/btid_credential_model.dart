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
  final String? levyTxHash;
  final String walletAddress;
  final DateTime issuedAt;
  final String? anchorTxHash;
  final String immigrationSource;

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
    this.levyTxHash,
    required this.walletAddress,
    required this.issuedAt,
    this.anchorTxHash,
    this.immigrationSource = 'self_declared',
  });

  bool get isLevyPaid => levyStatus.toLowerCase() == 'paid';

  int get daysRemaining {
    try {
      final expiryDate = DateTime.parse(stayExpiry);
      final difference = expiryDate.difference(DateTime.now()).inDays;
      return difference < 0 ? 0 : difference;
    } on Object catch (_) {
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
    String? levyTxHash,
    String? walletAddress,
    DateTime? issuedAt,
    String? anchorTxHash,
    String? immigrationSource,
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
      levyTxHash: levyTxHash ?? this.levyTxHash,
      walletAddress: walletAddress ?? this.walletAddress,
      issuedAt: issuedAt ?? this.issuedAt,
      anchorTxHash: anchorTxHash ?? this.anchorTxHash,
      immigrationSource: immigrationSource ?? this.immigrationSource,
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
      'levyTxHash': levyTxHash,
      'walletAddress': walletAddress,
      'issuedAt': issuedAt.toIso8601String(),
      'anchorTxHash': anchorTxHash,
      'immigrationSource': immigrationSource,
    };
  }

  factory BtidCredentialModel.fromJson(Map<String, dynamic> json) {
    final btid = json['btidNumber'] as String?;
    if (btid == null || btid.trim().isEmpty) {
      throw const FormatException('Missing required field: btidNumber');
    }

    final fullName = json['fullName'] as String?;
    if (fullName == null || fullName.trim().isEmpty) {
      throw const FormatException('Missing required field: fullName');
    }

    final dob = json['dob'] as String?;
    if (dob == null || dob.trim().isEmpty) {
      throw const FormatException('Missing required field: dob');
    }

    final docExpiry = json['docExpiry'] as String?;
    if (docExpiry == null || docExpiry.trim().isEmpty) {
      throw const FormatException('Missing required field: docExpiry');
    }

    final nationality = json['nationality'] as String?;
    if (nationality == null || nationality.trim().isEmpty) {
      throw const FormatException('Missing required field: nationality');
    }

    return BtidCredentialModel(
      btidNumber: btid,
      fullName: fullName,
      nationality: nationality,
      passportMasked: json['passportMasked'] as String? ?? '••••••',
      dob: dob,
      docExpiry: docExpiry,
      visaType: json['visaType'] as String? ?? 'Visit Visa',
      arrivalDate: json['arrivalDate'] as String? ?? '',
      stayExpiry: json['stayExpiry'] as String? ?? '',
      levyStatus: json['levyStatus'] as String? ?? 'unpaid',
      levyReceiptRef: json['levyReceiptRef'] as String?,
      levyTxHash: json['levyTxHash'] as String?,
      walletAddress: json['walletAddress'] as String? ?? '',
      issuedAt: json['issuedAt'] != null
          ? DateTime.tryParse(json['issuedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      anchorTxHash: json['anchorTxHash'] as String?,
      immigrationSource: json['immigrationSource'] as String? ?? 'self_declared',
    );
  }
}
