// lib/src/core/data/models/audit_transaction_model.dart

/// Model catatan transaksi audit identitas dan pembayaran (Phase 2.4).
/// Mengikuti Golden Rule R7: Status lokal dan status otoritatif dibedakan secara eksplisit.
class AuditTransactionModel {
  final String auditRef;
  final String txRef;
  final String? txHash; // Nullable: tidak boleh ada txHash palsu sebelum mined on-chain
  final String actor;
  final String organisation;
  final String action;
  final String purpose;
  final int sharedAttributesCount;
  final String status; // 'Approved', 'Rejected', 'Paid', 'Revoked', 'Pending'
  final DateTime timestamp;
  final List<String>? attributeKeys;
  final String? receiptSignature;

  // Field status sinkronisasi & verifikasi (Phase 2.4)
  final String syncStatus; // 'local_only', 'pending_sync', 'synced', 'rejected', 'legacy_unverified'
  final String? serverId;
  final String? anchorTxHash;
  final String? lastError;
  final String? actorWallet;
  final String? actorRef;
  final Map<String, dynamic>? liveness;

  const AuditTransactionModel({
    required this.auditRef,
    required this.txRef,
    this.txHash,
    required this.actor,
    required this.organisation,
    required this.action,
    required this.purpose,
    required this.sharedAttributesCount,
    required this.status,
    required this.timestamp,
    this.attributeKeys,
    this.receiptSignature,
    this.syncStatus = 'pending_sync',
    this.serverId,
    this.anchorTxHash,
    this.lastError,
    this.actorWallet,
    this.actorRef,
    this.liveness,
  });

  bool get isApproved => status.toLowerCase() == 'approved';
  bool get isPaid => status.toLowerCase() == 'paid';
  bool get isRevoked => status.toLowerCase() == 'revoked';
  bool get isSynced => syncStatus.toLowerCase() == 'synced';
  bool get isPendingSync => syncStatus.toLowerCase() == 'pending_sync';
  bool get isLegacyUnverified => syncStatus.toLowerCase() == 'legacy_unverified';

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
    String? syncStatus,
    String? serverId,
    String? anchorTxHash,
    String? lastError,
    String? actorWallet,
    String? actorRef,
    Map<String, dynamic>? liveness,
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
      syncStatus: syncStatus ?? this.syncStatus,
      serverId: serverId ?? this.serverId,
      anchorTxHash: anchorTxHash ?? this.anchorTxHash,
      lastError: lastError ?? this.lastError,
      actorWallet: actorWallet ?? this.actorWallet,
      actorRef: actorRef ?? this.actorRef,
      liveness: liveness ?? this.liveness,
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
      'syncStatus': syncStatus,
      'serverId': serverId,
      'anchorTxHash': anchorTxHash,
      'lastError': lastError,
      'actorWallet': actorWallet,
      'actorRef': actorRef,
      'liveness': liveness,
    };
  }

  factory AuditTransactionModel.fromJson(Map<String, dynamic> json) {
    // Record lama tanpa field syncStatus otomatis ditandai legacy_unverified
    final rawSyncStatus = json['syncStatus'] as String?;
    final syncStatus = rawSyncStatus ?? 'legacy_unverified';

    final livenessRaw = json['liveness'];
    final liveness = (livenessRaw is Map)
        ? Map<String, dynamic>.from(livenessRaw)
        : null;

    return AuditTransactionModel(
      auditRef: json['auditRef'] as String? ?? 'AUD-000000',
      txRef: json['txRef'] as String? ?? 'TX-000000',
      txHash: json['txHash'] as String?,
      actor: json['actor'] as String? ?? (json['actorWallet'] as String? ?? 'Anonymous'),
      organisation: json['organisation'] as String? ?? 'Bali Ecosystem',
      action: json['action'] as String? ?? 'Identity Verification',
      purpose: json['purpose'] as String? ?? 'General Verification',
      sharedAttributesCount: json['sharedAttributesCount'] as int? ?? 0,
      status: json['status'] as String? ?? 'Pending',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      attributeKeys: (json['attributeKeys'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      receiptSignature: json['receiptSignature'] as String?,
      syncStatus: syncStatus,
      serverId: json['serverId'] as String?,
      anchorTxHash: json['anchorTxHash'] as String?,
      lastError: json['lastError'] as String?,
      actorWallet: json['actorWallet'] as String?,
      actorRef: json['actorRef'] as String?,
      liveness: liveness,
    );
  }
}
