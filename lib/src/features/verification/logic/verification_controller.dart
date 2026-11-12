// lib/src/features/verification/logic/verification_controller.dart

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypta/src/core/data/models/audit_transaction_model.dart';
import 'package:qrypta/src/core/data/models/consent_request_model.dart';
import 'package:qrypta/src/core/services/blockchain/blockchain_service.dart';
import 'package:qrypta/src/core/services/blockchain/verification_transaction_service.dart';
import 'package:qrypta/src/features/authentication/presentation/providers/btid_provider.dart';
import 'package:qrypta/src/features/verification/data/policy_matrix_constants.dart';

class VerificationState {
  final String currentQrToken;
  final String tokenCode;
  final int remainingSeconds;
  final bool isQrExpired;
  final ConsentRequestModel? activeConsentRequest;
  final List<AuditTransactionModel> auditHistory;
  final bool isLoading;
  final String? errorMessage;

  const VerificationState({
    this.currentQrToken = '',
    this.tokenCode = '',
    this.remainingSeconds = 45,
    this.isQrExpired = false,
    this.activeConsentRequest,
    this.auditHistory = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  int get approvedCount =>
      auditHistory.where((a) => a.status.toLowerCase() == 'approved').length;

  int get rejectedCount =>
      auditHistory.where((a) => a.status.toLowerCase() == 'rejected').length;

  int get activeAccessCount {
    final activeMerchants = <String>{};
    for (final audit in auditHistory) {
      if (audit.status.toLowerCase() == 'approved') {
        activeMerchants.add(audit.organisation);
      } else if (audit.status.toLowerCase() == 'revoked') {
        activeMerchants.remove(audit.organisation);
      }
    }
    return activeMerchants.length;
  }

  VerificationState copyWith({
    String? currentQrToken,
    String? tokenCode,
    int? remainingSeconds,
    bool? isQrExpired,
    ConsentRequestModel? activeConsentRequest,
    bool clearActiveConsent = false,
    List<AuditTransactionModel>? auditHistory,
    bool? isLoading,
    String? errorMessage,
  }) {
    return VerificationState(
      currentQrToken: currentQrToken ?? this.currentQrToken,
      tokenCode: tokenCode ?? this.tokenCode,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      isQrExpired: isQrExpired ?? this.isQrExpired,
      activeConsentRequest: clearActiveConsent
          ? null
          : (activeConsentRequest ?? this.activeConsentRequest),
      auditHistory: auditHistory ?? this.auditHistory,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

final verificationControllerProvider =
    StateNotifierProvider<VerificationNotifier, VerificationState>((ref) {
  final verificationService = ref.watch(blockchainServiceProvider).verification;
  return VerificationNotifier(ref, verificationService);
});

class VerificationNotifier extends StateNotifier<VerificationState> {
  final Ref ref;
  final VerificationTransactionService _verificationService;
  Timer? _countdownTimer;

  VerificationNotifier(this.ref, this._verificationService)
      : super(const VerificationState()) {
    loadAuditHistory();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  /// Memulai atau memperbarui QR Dinamis 45 Detik
  void startOrRefreshQr({String? btid, String? walletAddress}) {
    _countdownTimer?.cancel();

    final activeBtid = btid ??
        ref.read(btidCredentialProvider)?.btidNumber ??
        'BTID-2026-4471-0938';
    final activeWallet = walletAddress ??
        ref.read(btidCredentialProvider)?.walletAddress ??
        '0x71CB05EE1b1F506fF321Da3CE92a540AC401B4D0';

    final jsonPayload = _verificationService.generateDynamicQrToken(
      activeBtid,
      activeWallet,
      validitySeconds: 45,
    );

    String extractedToken = 'QRT-9X2KL8MPQ1';
    try {
      final decoded = jsonDecode(jsonPayload);
      extractedToken = decoded['token']?.toString() ?? extractedToken;
    } catch (_) {}

    state = state.copyWith(
      currentQrToken: jsonPayload,
      tokenCode: extractedToken,
      remainingSeconds: 45,
      isQrExpired: false,
    );

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.remainingSeconds > 1) {
        state = state.copyWith(
          remainingSeconds: state.remainingSeconds - 1,
          isQrExpired: false,
        );
      } else {
        timer.cancel();
        state = state.copyWith(
          remainingSeconds: 0,
          isQrExpired: true,
        );
      }
    });
  }

  /// Memicu simulasi merchant scan (Hotel, Car Rental, Cafe, dll.) untuk keperluan presentasi & pengujian
  ConsentRequestModel triggerMerchantSimulation(String category) {
    final merchant = DEMO_MERCHANTS[category] ?? DEMO_MERCHANTS['hotel']!;
    final template = TEMPLATES[merchant.defaultTemplate] ?? TEMPLATES['hotel_checkin']!;
    final rand = Random();
    final reqId = 'TX-${100000 + rand.nextInt(900000)}';

    // Menggabungkan core fields dan 1-2 optional fields
    final fields = List<String>.from(template.coreFields);
    if (template.optionalFields.isNotEmpty && fields.length < 8) {
      fields.add(template.optionalFields.first);
    }

    final request = ConsentRequestModel(
      requestId: reqId,
      merchantId: merchant.id,
      merchantName: merchant.name,
      merchantCategory: merchant.category,
      staffName: merchant.staffName,
      staffRole: merchant.staffRole,
      purposeTemplate: template.id,
      requestedFields: fields,
      retentionPolicy: template.retentionPolicy,
      expiresAt: DateTime.now().add(const Duration(minutes: 3)),
    );

    state = state.copyWith(activeConsentRequest: request);
    return request;
  }

  /// Menyetujui dan menandatangani cryptographic consent
  Future<AuditTransactionModel> approveConsent({
    required ConsentRequestModel request,
    required Map<String, dynamic> approvedData,
    required String privateKeyHex,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final audit = await _verificationService.signAndSubmitConsent(
        privateKeyHex: privateKeyHex,
        request: request,
        approvedData: approvedData,
        isApproved: true,
      );

      final updatedList = [audit, ...state.auditHistory.where((a) => a.txRef != audit.txRef)];
      state = state.copyWith(
        auditHistory: updatedList,
        isLoading: false,
        clearActiveConsent: true,
      );

      return audit;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      rethrow;
    }
  }

  /// Menolak permintaan atribut merchant
  Future<AuditTransactionModel> rejectConsent({
    required ConsentRequestModel request,
    required Map<String, dynamic> approvedData,
    required String privateKeyHex,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final audit = await _verificationService.signAndSubmitConsent(
        privateKeyHex: privateKeyHex,
        request: request,
        approvedData: approvedData,
        isApproved: false,
      );

      final updatedList = [audit, ...state.auditHistory.where((a) => a.txRef != audit.txRef)];
      state = state.copyWith(
        auditHistory: updatedList,
        isLoading: false,
        clearActiveConsent: true,
      );

      return audit;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      rethrow;
    }
  }

  /// Mencabut izin merchant di masa depan (Stop Future Access)
  Future<AuditTransactionModel> revokeAccess({
    required String txRef,
    required String merchantId,
    required String privateKeyHex,
    required String btid,
    String? merchantName,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final audit = await _verificationService.revokeMerchantAccess(
        privateKeyHex: privateKeyHex,
        txRef: txRef,
        merchantId: merchantId,
        btid: btid,
        merchantName: merchantName,
      );

      // Perbarui status record di riwayat audit
      final updatedList = state.auditHistory.map((item) {
        if (item.txRef == txRef || item.organisation == (merchantName ?? merchantId)) {
          return item.copyWith(status: 'Revoked');
        }
        return item;
      }).toList();

      state = state.copyWith(
        auditHistory: [audit, ...updatedList.where((a) => a.txRef != audit.txRef)],
        isLoading: false,
      );

      return audit;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      rethrow;
    }
  }

  /// Memuat riwayat audit dari storage
  Future<void> loadAuditHistory() async {
    try {
      final list = await _verificationService.getAuditTransactions();
      state = state.copyWith(auditHistory: list);
    } catch (_) {}
  }

  void clearActiveConsent() {
    state = state.copyWith(clearActiveConsent: true);
  }
}
