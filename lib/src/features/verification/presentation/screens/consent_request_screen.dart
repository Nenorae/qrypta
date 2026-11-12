// lib/src/features/verification/presentation/screens/consent_request_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypta/src/core/config/theme/app_colors.dart';
import 'package:qrypta/src/core/data/models/consent_request_model.dart';
import 'package:qrypta/src/core/services/authentication_service.dart';
import 'package:qrypta/src/features/authentication/presentation/providers/auth_providers.dart';
import 'package:qrypta/src/features/authentication/presentation/providers/btid_provider.dart';
import 'package:qrypta/src/features/verification/data/policy_matrix_constants.dart';
import 'package:qrypta/src/features/verification/logic/verification_controller.dart';
import 'package:qrypta/src/features/verification/presentation/screens/consent_shared_screen.dart';

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
        return cred?.fullName ?? 'James Wilson';
      case 'nationality':
        return '${cred?.nationality ?? "GBR"} (United Kingdom)';
      case 'passport_number':
        return cred?.passportMasked ?? '••••••789';
      case 'identity':
        return 'Verified (On-chain proof)';
      case 'passport_auth':
        return 'Authentic — Passive Auth Verified';
      case 'id_validity':
        return 'Valid until 18 Jan 2027';
      case 'levy_status':
        return (cred?.isLevyPaid ?? false) ? 'Paid (LVY-88412)' : 'Unpaid';
      case 'stay_valid':
        return 'Valid — ${cred?.daysRemaining ?? 28} days remaining';
      case 'stay_expiry':
        return cred?.stayExpiry ?? '2026-11-14';
      case 'over18':
        return 'Over 18 — verified (Zero-Knowledge)';
      case 'over21':
        return 'Over 21 — verified (Zero-Knowledge)';
      case 'driving':
        return 'Verified — International Permit Category B';
      case 'dob':
        return cred?.dob ?? '12 May 1988';
      case 'arrival':
        return cred?.arrivalDate ?? '2026-10-15';
      case 'departure':
        return '2026-11-14';
      case 'visa_type':
        return cred?.visaType ?? 'e-VOA B1 Visit Visa';
      case 'emergency':
        return 'S. Wilson · +44 ••• 4471';
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
        throw Exception('Private key not found in secure storage');
      }

      final cred = ref.read(btidCredentialProvider);
      final approvedMap = <String, dynamic>{
        'btid': cred?.btidNumber ?? 'BTID-2026-4471-0938',
        'fullName': cred?.fullName ?? 'James Wilson',
        'walletAddress': cred?.walletAddress ?? '',
      };

      for (final key in _selectedFields) {
        approvedMap[key] = _resolveAttributeValue(key);
      }

      // Buat request dengan daftar atribut yang benar-benar dicentang oleh user
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
      final approvedMap = <String, dynamic>{
        'btid': cred?.btidNumber ?? 'BTID-2026-4471-0938',
        'fullName': cred?.fullName ?? 'James Wilson',
      };

      await ref.read(verificationControllerProvider.notifier).rejectConsent(
            request: widget.request,
            approvedData: approvedMap,
            privateKeyHex: privateKey,
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131D2D),
        title: Text(
          'Ask ${widget.request.staffName}',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select clarification to send to merchant terminal:',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            _buildClarificationOption(ctx, 'Why do you need my passport number?'),
            _buildClarificationOption(ctx, 'Can I check in without date of birth?'),
            _buildClarificationOption(ctx, 'What is your regional data retention policy?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildClarificationOption(BuildContext ctx, String text) {
    return InkWell(
      onTap: () {
        Navigator.pop(ctx);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Clarification sent to ${widget.request.staffName}'),
            backgroundColor: const Color(0xFF0D9488),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            const Icon(Icons.help_outline_rounded, size: 16, color: Color(0xFF2DD4BF)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
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
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131D2D),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.accent.withValues(alpha: 0.15),
                              border: Border.all(color: AppColors.accent),
                            ),
                            child: const Icon(
                              Icons.storefront_rounded,
                              color: AppColors.accent,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        widget.request.merchantName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0D9488).withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'Verified',
                                        style: TextStyle(
                                          color: Color(0xFF2DD4BF),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${widget.request.staffName} · ${widget.request.staffRole}',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Purpose: ${widget.request.purposeTemplate.replaceAll('_', ' ').toUpperCase()}',
                                  style: TextStyle(
                                    color: AppColors.accent.withValues(alpha: 0.9),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
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

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0C1322),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF2DD4BF).withValues(alpha: 0.3)
                                : Colors.white10,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: isSelected,
                              activeColor: const Color(0xFF2DD4BF),
                              checkColor: const Color(0xFF080D1A),
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedFields.add(fieldKey);
                                  } else {
                                    // Cegah uncheck jika atribut tunggal
                                    if (_selectedFields.length > 1) {
                                      _selectedFields.remove(fieldKey);
                                    }
                                  }
                                });
                              },
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        label,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        value,
                                        style: const TextStyle(
                                          color: Color(0xFF5EEAD4),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    reason,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.5),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 12),

                    // Klausul Retensi Data
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131D2D),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time_rounded, size: 16, color: Colors.white60),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              widget.request.retentionPolicy,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Biometric Protection Guarantee
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1A2E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFA78BFA).withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.shield_outlined, size: 16, color: Color(0xFFA78BFA)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: const Text(
                              'Never shared: Biometric template, live face capture, and full passport chip contents.',
                              style: TextStyle(
                                color: Color(0xFFA78BFA),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
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
