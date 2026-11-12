// lib/src/core/data/models/audit_transaction_model.dart

class AuditTransactionModel {
  final String auditRef;
  final String txRef;
  final String txHash;
  final String actor;
  final String organisation;
  final String action;
  final String purpose;
  final int sharedAttributesCount;
  final String status; // 'Approved', 'Rejected', 'Paid', 'Revoked'
  final DateTime timestamp;
  final List<String>? attributeKeys;
  final String? receiptSignature;

  const AuditTransactionModel({
    required this.auditRef,
    required this.txRef,
    required this.txHash,
    required this.actor,
    required this.organisation,
    required this.action,
    required this.purpose,
    required this.sharedAttributesCount,
    required this.status,
    required this.timestamp,
    this.attributeKeys,
    this.receiptSignature,
  });

  bool get isApproved => status.toLowerCase() == 'approved';
  bool get isPaid => status.toLowerCase() == 'paid';
  bool get isRevoked => status.toLowerCase() == 'revoked';

  AuditTransactionModel copyWith({
    String? auditRef,
    String? txRef,
    String? txHash,
    String? actor,
    String? organisation,
    String? action,
    String? purpose,
    int? sharedAttributesCount,
    String? status,
    DateTime? timestamp,
    List<String>? attributeKeys,
    String? receiptSignature,
  }) {
    return AuditTransactionModel(
      auditRef: auditRef ?? this.auditRef,
      txRef: txRef ?? this.txRef,
      txHash: txHash ?? this.txHash,
      actor: actor ?? this.actor,
      organisation: organisation ?? this.organisation,
      action: action ?? this.action,
      purpose: purpose ?? this.purpose,
      sharedAttributesCount: sharedAttributesCount ?? this.sharedAttributesCount,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      attributeKeys: attributeKeys ?? this.attributeKeys,
      receiptSignature: receiptSignature ?? this.receiptSignature,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'auditRef': auditRef,
      'txRef': txRef,
      'txHash': txHash,
      'actor': actor,
      'organisation': organisation,
      'action': action,
      'purpose': purpose,
      'sharedAttributesCount': sharedAttributesCount,
      'status': status,
      'timestamp': timestamp.toIso8601String(),
      'attributeKeys': attributeKeys,
      'receiptSignature': receiptSignature,
    };
  }

  factory AuditTransactionModel.fromJson(Map<String, dynamic> json) {
    return AuditTransactionModel(
      auditRef: json['auditRef'] as String? ?? 'AUD-000000',
      txRef: json['txRef'] as String? ?? 'TX-000000',
      txHash: json['txHash'] as String? ?? '0x',
      actor: json['actor'] as String? ?? 'James Wilson',
      organisation: json['organisation'] as String? ?? 'Bali Ecosystem',
      action: json['action'] as String? ?? 'Identity Verification',
      purpose: json['purpose'] as String? ?? 'General Verification',
      sharedAttributesCount: json['sharedAttributesCount'] as int? ?? 0,
      status: json['status'] as String? ?? 'Approved',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      attributeKeys: (json['attributeKeys'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      receiptSignature: json['receiptSignature'] as String?,
    );
  }
}
