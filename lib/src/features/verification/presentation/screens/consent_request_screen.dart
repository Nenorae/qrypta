// lib/src/features/verification/presentation/screens/consent_request_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypta/src/core/config/theme/app_colors.dart';
import 'package:qrypta/src/core/data/models/consent_request_model.dart';
import 'package:qrypta/src/core/error/app_failure.dart';
import 'package:qrypta/src/core/services/authentication_service.dart';
import 'package:qrypta/src/features/authentication/presentation/providers/auth_providers.dart';
import 'package:qrypta/src/features/authentication/presentation/providers/btid_provider.dart';
import 'package:qrypta/src/features/verification/data/policy_matrix_constants.dart';
import 'package:qrypta/src/features/verification/logic/verification_controller.dart';
import 'package:qrypta/src/features/verification/presentation/screens/consent_shared_screen.dart';
import 'package:qrypta/src/features/verification/presentation/widgets/consent_attribute_tile.dart';
import 'package:qrypta/src/features/verification/presentation/widgets/consent_biometric_guarantee.dart';
import 'package:qrypta/src/features/verification/presentation/widgets/consent_clarification_dialog.dart';
import 'package:qrypta/src/features/verification/presentation/widgets/consent_merchant_header.dart';

export 'package:qrypta/src/features/verification/presentation/widgets/consent_attribute_tile.dart';
export 'package:qrypta/src/features/verification/presentation/widgets/consent_biometric_guarantee.dart';
export 'package:qrypta/src/features/verification/presentation/widgets/consent_clarification_dialog.dart';
export 'package:qrypta/src/features/verification/presentation/widgets/consent_merchant_header.dart';

class ConsentRequestScreen extends ConsumerStatefulWidget {
  final ConsentRequestModel request;

  const ConsentRequestScreen({
    super.key,
    required this.request,
  });

  @override
  ConsumerState<ConsentRequestScreen> createState() => _ConsentRequestScreenState();
}

class _ConsentRequestScreenState extends ConsumerState<ConsentRequestScreen> {
  late Set<String> _selectedFields;
  late int _remainingSeconds;
  Timer? _countdownTimer;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedFields = Set.from(widget.request.requestedFields);
    _remainingSeconds = widget.request.expiresAt.difference(DateTime.now()).inSeconds;
    if (_remainingSeconds <= 0) _remainingSeconds = 180;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_remainingSeconds > 1) {
          _remainingSeconds--;
        } else {
          timer.cancel();
          Navigator.pop(context);
        }
      });
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  String _formatTimer(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _resolveAttributeValue(String key) {
    final cred = ref.read(btidCredentialProvider);
    switch (key) {
      case 'name':
        return (cred?.fullName.isNotEmpty == true) ? cred!.fullName : 'Tourist';
      case 'nationality':
        return cred?.nationality ?? 'IDN';
      case 'passport_number':
        return cred?.passportMasked ?? '••••••';
      case 'identity':
        return 'Verified (On-chain proof)';
      case 'passport_auth':
        return 'Authentic — Passive Auth Verified';
      case 'id_validity':
        return 'Valid until 18 Jan 2027';
      case 'levy_status':
        return (cred?.isLevyPaid ?? false) ? 'Paid (${cred?.levyReceiptRef ?? "LVY"})' : 'Unpaid';
      case 'stay_valid':
        return 'Valid — ${cred?.daysRemaining ?? 30} days remaining';
      case 'stay_expiry':
        return cred?.stayExpiry ?? '';
      case 'over18':
        return 'Over 18 — verified (Zero-Knowledge)';
      case 'over21':
        return 'Over 21 — verified (Zero-Knowledge)';
      case 'driving':
        return 'Verified — International Permit Category B';
      case 'dob':
        return cred?.dob ?? '';
      case 'arrival':
        return cred?.arrivalDate ?? '';
      case 'departure':
        return '';
      case 'visa_type':
        return (cred?.visaType.isNotEmpty == true) ? cred!.visaType : 'Tourist Visa';
      case 'emergency':
        return 'Registered Emergency Contact';
      case 'payment_confirm':
        return 'Payment Confirmed';
      default:
        return 'Verified';
    }
  }

  Future<void> _handleApprove() async {
    setState(() => _isSubmitting = true);

    try {
      // 1. Verifikasi Biometrik / Autentikasi Pengguna
      final authOk = await AuthenticationService.authenticate(
        'Authorize purpose-bound data sharing with ${widget.request.merchantName}',
      );

      if (!authOk) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Authentication failed. Consent not signed.'),
              backgroundColor: Colors.redAccent,
            ),
          );
          setState(() => _isSubmitting = false);
        }
        return;
      }

      // 2. Ambil private key dari secure storage
      final privateKey = await ref.read(getPrivateKeyUseCaseProvider)();
      if (privateKey == null || privateKey.isEmpty) {
        throw const ValidationFailure('Private key not found in secure storage');
      }

      final cred = ref.read(btidCredentialProvider);
      if (cred == null || cred.btidNumber.isEmpty) {
        throw const ValidationFailure('Kredensial BTID belum aktif. Selesaikan onboarding terlebih dahulu.');
      }

      final actor = ref.read(actorRefProvider);
      final approvedMap = <String, dynamic>{
        'btid': cred.btidNumber,
        'fullName': cred.fullName.isNotEmpty ? cred.fullName : 'Tourist',
        'walletAddress': cred.walletAddress,
      };

      for (final key in _selectedFields) {
        approvedMap[key] = _resolveAttributeValue(key);
      }

      final finalRequest = widget.request.copyWith(
        requestedFields: _selectedFields.toList(),
      );

      // 3. Tanda tangani canonical digest dan kirim ke Fastify middleware -> Besu
      final audit = await ref
          .read(verificationControllerProvider.notifier)
          .approveConsent(
            request: finalRequest,
            approvedData: approvedMap,
            privateKeyHex: privateKey,
            actor: actor,
          );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ConsentSharedScreen(
            request: finalRequest,
            audit: audit,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving consent: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _handleReject() async {
    setState(() => _isSubmitting = true);

    try {
      final privateKey = await ref.read(getPrivateKeyUseCaseProvider)() ?? '0x0';
      final cred = ref.read(btidCredentialProvider);
      final actor = ref.read(actorRefProvider);
      final approvedMap = <String, dynamic>{
        'btid': cred?.btidNumber ?? '',
        'fullName': (cred?.fullName.isNotEmpty == true) ? cred!.fullName : 'Tourist',
        'walletAddress': cred?.walletAddress ?? '',
      };

      await ref.read(verificationControllerProvider.notifier).rejectConsent(
            request: widget.request,
            approvedData: approvedMap,
            privateKeyHex: privateKey,
            actor: actor,
          );

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  void _showAskMerchantDialog() {
    ConsentClarificationDialog.show(
      context: context,
      staffName: widget.request.staffName,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Verification Request',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer_outlined, size: 12, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      _formatTimer(_remainingSeconds),
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Courier',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Merchant Header Card
                    ConsentMerchantHeader(request: widget.request),
                    const SizedBox(height: 18),

                    // Section Title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Requested Attributes',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${_selectedFields.length} of ${widget.request.requestedFields.length} shared',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Attribute List
                    ...widget.request.requestedFields.map((fieldKey) {
                      final attr = ATTRS[fieldKey];
                      final label = attr?.label ?? fieldKey;
                      final reason = attr?.defaultReason ?? 'Required for verification';
                      final value = _resolveAttributeValue(fieldKey);
                      final isSelected = _selectedFields.contains(fieldKey);

                      return ConsentAttributeTile(
                        label: label,
                        value: value,
                        reason: reason,
                        isSelected: isSelected,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedFields.add(fieldKey);
                            } else {
                              if (_selectedFields.length > 1) {
                                _selectedFields.remove(fieldKey);
                              }
                            }
                          });
                        },
                      );
                    }),

                    const SizedBox(height: 12),

                    // Klausul Retensi Data & Biometric Guarantee
                    ConsentBiometricGuarantee(
                      retentionPolicy: widget.request.retentionPolicy,
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // Bottom Actions Bar
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                border: Border(top: BorderSide(color: Colors.white10)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Tombol Ask Merchant
                      Expanded(
                        flex: 1,
                        child: OutlinedButton(
                          onPressed: _isSubmitting ? null : _showAskMerchantDialog,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: const BorderSide(color: Colors.white24),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Ask', style: TextStyle(fontSize: 13)),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Tombol Reject
                      Expanded(
                        flex: 1,
                        child: OutlinedButton(
                          onPressed: _isSubmitting ? null : _handleReject,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Reject', style: TextStyle(fontSize: 13)),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Tombol Approve & Share
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _handleApprove,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: const Color(0xFF0A0F1D),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.fingerprint_rounded, size: 18),
                                    SizedBox(width: 6),
                                    Text(
                                      'Approve & share',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
