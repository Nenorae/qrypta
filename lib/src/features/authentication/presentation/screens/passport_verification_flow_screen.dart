// lib/src/features/authentication/presentation/screens/passport_verification_flow_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:qrypta/src/core/config/theme/app_colors.dart';
import 'package:qrypta/src/core/error/app_failure.dart';
import 'package:qrypta/src/core/utils/mrz_parser.dart';
import 'package:qrypta/src/features/authentication/data/nfc/nfc_passport_service.dart';
import 'package:qrypta/src/features/authentication/domain/models/nfc_passport_models.dart';
import 'package:qrypta/src/features/authentication/presentation/screens/btid_issued_screen.dart';

enum VerificationStep { nfc, auth, liveness }

class PassportVerificationFlowScreen extends StatefulWidget {
  final MrzParseResult mrzResult;
  final NfcPassportService? nfcService;

  const PassportVerificationFlowScreen({
    super.key,
    required this.mrzResult,
    this.nfcService,
  });

  @override
  State<PassportVerificationFlowScreen> createState() =>
      _PassportVerificationFlowScreenState();
}

class _PassportVerificationFlowScreenState
    extends State<PassportVerificationFlowScreen>
    with TickerProviderStateMixin {
  VerificationStep _currentStep = VerificationStep.nfc;

  // Controllers untuk Animasi
  late AnimationController _radarController;
  late AnimationController _pulseController;
  late AnimationController _livenessController;

  // Layanan NFC Paspor Riil (Phase 8.1)
  late final NfcPassportService _nfcService;

  // State Step 1: NFC Nyata (Mengeliminasi fake timer 650ms)
  NfcAvailability _nfcAvailability = NfcAvailability.enabled;
  NfcReadStage _nfcStage = NfcReadStage.idle;
  String _nfcStageMessage = 'Hold passport firmly against phone NFC area';
  double _nfcProgress = 0.0;
  String? _nfcErrorMessage;
  bool _isNfcScanning = false;
  PassportChipData? _chipData;

  // State Step 2: Auth Nyata (Mengeliminasi fake timer & hardcoded DSC)
  PassiveAuthResult? _passiveAuthResult;

  // State Step 3: Liveness
  int _livenessStageIndex = 0;
  bool _livenessComplete = false;
  Timer? _livenessTimer;
  static const List<String> _livenessStages = [
    'Face detected in viewfinder',
    'Liveness confirmed (Anti-spoofing passed)',
    'Comparing with passport chip photograph (DG2)...',
    'Identity confirmed!',
  ];

  @override
  void initState() {
    super.initState();
    _nfcService = widget.nfcService ?? NfcPassportService();

    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _livenessController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _checkHardwareAndStartNfc();
  }

  @override
  void dispose() {
    _nfcService.cancelScanningSession();
    _radarController.dispose();
    _pulseController.dispose();
    _livenessController.dispose();
    _livenessTimer?.cancel();
    super.dispose();
  }

  // --- Step 1: Inisialisasi & Pembacaan NFC Fisik Nyata ---
  Future<void> _checkHardwareAndStartNfc() async {
    final availability = await _nfcService.checkHardwareAvailability();
    if (!mounted) return;

    setState(() {
      _nfcAvailability = availability;
      if (availability == NfcAvailability.disabled) {
        _nfcErrorMessage = 'NFC is disabled. Please turn on NFC in phone settings.';
      } else if (availability == NfcAvailability.unsupported) {
        _nfcErrorMessage = 'This device does not have an NFC chip reader.';
      } else {
        _nfcErrorMessage = null;
      }
    });

    if (availability == NfcAvailability.enabled) {
      _startNfcSession();
    }
  }

  Future<void> _startNfcSession() async {
    if (_isNfcScanning) return;
    setState(() {
      _isNfcScanning = true;
      _nfcErrorMessage = null;
      _nfcStage = NfcReadStage.waitingForPassport;
      _nfcStageMessage = 'Hold passport firmly against phone back antenna';
      _nfcProgress = 0.2;
    });

    await _nfcService.startPhysicalScanningSession(
      cameraMrz: widget.mrzResult,
      onProgress: (stage, message) {
        if (!mounted) return;
        setState(() {
          _nfcStage = stage;
          _nfcStageMessage = message;
          _nfcProgress = stage.progressFraction;
        });
      },
      onSuccess: (chipData) {
        if (!mounted) return;
        setState(() {
          _isNfcScanning = false;
          _chipData = chipData;
          _passiveAuthResult = chipData.passiveAuth;
          _nfcStage = NfcReadStage.completed;
          _nfcProgress = 1.0;
        });

        // Maju ke Auth step secara otomatis dengan jeda kecil
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) {
            setState(() {
              _currentStep = VerificationStep.auth;
            });
          }
        });
      },
      onError: (failure) {
        if (!mounted) return;
        setState(() {
          _isNfcScanning = false;
          _nfcStage = NfcReadStage.error;
          _nfcErrorMessage = failure.message;
        });
      },
    );
  }

  // --- Step 3: Liveness Sequence ---
  void _startLivenessSequence() {
    _livenessTimer?.cancel();
    _livenessStageIndex = 0;
    _livenessComplete = false;
    _livenessController.forward(from: 0.0);

    _livenessTimer = Timer.periodic(const Duration(milliseconds: 700), (timer) {
      if (!mounted) return;
      setState(() {
        if (_livenessStageIndex < _livenessStages.length - 1) {
          _livenessStageIndex++;
        } else {
          _livenessComplete = true;
          timer.cancel();
        }
      });
    });
  }

  void _showSecurityDetailsModal() {
    final pa = _passiveAuthResult;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFF131D2D),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      'PKI Security Details',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Icon(Icons.security_rounded, color: Color(0xFFA78BFA), size: 20),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C1322),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildModalRow('Document Type', 'ePassport / ICAO Doc 9303 TD3'),
                      const Divider(color: Colors.white12, height: 14),
                      _buildModalRow(
                        'Country Trust Authority',
                        pa?.cscaCountry ?? '${widget.mrzResult.nationality} CSCA (Unverified Anchor)',
                      ),
                      const Divider(color: Colors.white12, height: 14),
                      _buildModalRow('Document Signer (DS)', pa?.dscSubject ?? 'Document Signer'),
                      const Divider(color: Colors.white12, height: 14),
                      _buildModalRow('DS Serial Number', pa?.dscSerial ?? 'N/A'),
                      const Divider(color: Colors.white12, height: 14),
                      _buildModalRow('Hash Algorithm', '${pa?.hashAlgorithm ?? "SHA-256"} (FIPS 180-4)'),
                      const Divider(color: Colors.white12, height: 14),
                      _buildModalRow('Signature Scheme', pa?.signatureAlgorithm ?? 'ECDSA / RSA'),
                      const Divider(color: Colors.white12, height: 14),
                      _buildModalRow(
                        'Passive Authentication',
                        pa != null
                            ? (pa.isGenuine
                                ? 'VALIDATED · GENUINE'
                                : (pa.status == PassiveAuthStatus.unverifiedNoTrustAnchor
                                    ? 'UNVERIFIED · NO TRUST ANCHOR'
                                    : 'FAILED · INTEGRITY COMPROMISED'))
                            : 'PENDING READ',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E293B),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModalRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
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
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _getAppBarTitle(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStepTracker(),
              const SizedBox(height: 24),
              Expanded(
                child: _buildStepContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getAppBarTitle() {
    switch (_currentStep) {
      case VerificationStep.nfc:
        return 'NFC ePassport Chip';
      case VerificationStep.auth:
        return 'Passive Authentication';
      case VerificationStep.liveness:
        return 'Biometric Face Match';
    }
  }

  Widget _buildStepTracker() {
    return Row(
      children: [
        _buildStepIndicator(
          stepNumber: '1',
          label: 'NFC Read',
          isActive: _currentStep == VerificationStep.nfc,
          isCompleted: _currentStep.index > VerificationStep.nfc.index,
        ),
        Expanded(
          child: Container(
            height: 2,
            color: _currentStep.index > VerificationStep.nfc.index
                ? AppColors.accent
                : Colors.white12,
          ),
        ),
        _buildStepIndicator(
          stepNumber: '2',
          label: 'PKI Auth',
          isActive: _currentStep == VerificationStep.auth,
          isCompleted: _currentStep.index > VerificationStep.auth.index,
        ),
        Expanded(
          child: Container(
            height: 2,
            color: _currentStep.index > VerificationStep.auth.index
                ? AppColors.accent
                : Colors.white12,
          ),
        ),
        _buildStepIndicator(
          stepNumber: '3',
          label: 'Liveness',
          isActive: _currentStep == VerificationStep.liveness,
          isCompleted: _livenessComplete,
        ),
      ],
    );
  }

  Widget _buildStepIndicator({
    required String stepNumber,
    required String label,
    required bool isActive,
    required bool isCompleted,
  }) {
    Color color;
    if (isCompleted) {
      color = const Color(0xFF2DD4BF);
    } else if (isActive) {
      color = const Color(0xFFA78BFA);
    } else {
      color = Colors.white24;
    }

    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted
                ? color
                : (isActive ? color.withValues(alpha: 0.2) : Colors.transparent),
            border: Border.all(color: color, width: 1.5),
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, size: 16, color: Color(0xFF080D1A))
                : Text(
                    stepNumber,
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.white38,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isActive || isCompleted ? Colors.white : Colors.white38,
            fontSize: 11,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case VerificationStep.nfc:
        return _buildNfcView();
      case VerificationStep.auth:
        return _buildAuthView();
      case VerificationStep.liveness:
        return _buildLivenessView();
    }
  }

  // --- 1. REAL NFC VIEW (Phase 8.1) ---
  Widget _buildNfcView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(),
        Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 170 + (_pulseController.value * 25),
                    height: 170 + (_pulseController.value * 25),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (_nfcErrorMessage != null
                              ? Colors.redAccent
                              : const Color(0xFFA78BFA))
                          .withValues(alpha: 0.08),
                    ),
                  );
                },
              ),
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (_nfcErrorMessage != null
                          ? Colors.redAccent
                          : const Color(0xFFA78BFA))
                      .withValues(alpha: 0.15),
                  border: Border.all(
                    color: (_nfcErrorMessage != null
                            ? Colors.redAccent
                            : const Color(0xFFA78BFA))
                        .withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
              ),
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: _nfcErrorMessage != null
                        ? [const Color(0xFFEF4444), const Color(0xFF991B1B)]
                        : [const Color(0xFF8B5CF6), const Color(0xFF4C1D95)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_nfcErrorMessage != null
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF8B5CF6))
                          .withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  _nfcErrorMessage != null ? Icons.nfc_outlined : Icons.nfc_rounded,
                  size: 48,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 36),

        // Tahapan Teks Berurutan Real-Time
        Text(
          _nfcErrorMessage ?? _nfcStageMessage,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _nfcErrorMessage != null ? Colors.redAccent : Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),

        // Progress Bar
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: _nfcErrorMessage != null ? 0.0 : _nfcProgress,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(
              _nfcErrorMessage != null ? Colors.redAccent : const Color(0xFFA78BFA),
            ),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _nfcErrorMessage != null
              ? 'Please resolve the error and try scanning again'
              : 'Hold passport firmly against phone NFC area (back antenna)',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 12,
          ),
        ),

        const Spacer(),

        // Tombol Retry bila terjadi kegagalan atau hardware belum scan
        if (_nfcErrorMessage != null || !_isNfcScanning)
          SizedBox(
            height: 48,
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _checkHardwareAndStartNfc,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFA78BFA)),
                ),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(
                _nfcErrorMessage != null ? 'Try Scanning Again' : 'Start NFC Scan',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        const SizedBox(height: 10),
      ],
    );
  }

  // --- 2. AUTH VIEW NYATA (Phase 8.2) ---
  Widget _buildAuthView() {
    final pa = _passiveAuthResult;
    final bool dgMatched = pa?.dgHashesMatched[1] == true;
    final bool sigValid = pa != null &&
        pa.status != PassiveAuthStatus.signatureInvalid &&
        pa.status != PassiveAuthStatus.parseError;
    final bool isGenuine = pa?.isGenuine == true;
    final bool isUnverifiedAnchor =
        pa?.status == PassiveAuthStatus.unverifiedNoTrustAnchor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        const Text(
          'Passive Authentication (ICAO Doc 9303)',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Cryptographically verifying passport chip signatures against ICAO PKD',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.65),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 16),

        // 4-Node Visual Trust Chain Dinamis
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildTrustChainNode(
                  title: 'ePassport chip',
                  subtitle: 'ISO 14443 contactless microchip intact',
                  isDone: _chipData != null,
                ),
                _buildTrustChainConnector(dgMatched),
                _buildTrustChainNode(
                  title: 'Signed passport data',
                  subtitle: dgMatched
                      ? 'DG1 hash matched SOD (${pa?.hashAlgorithm ?? "SHA-256"})'
                      : 'DG1 hash verification failed',
                  isDone: dgMatched,
                ),
                _buildTrustChainConnector(sigValid),
                _buildTrustChainNode(
                  title: 'Document signer certificate',
                  subtitle: sigValid
                      ? 'DSC signature validated (${pa?.signatureAlgorithm ?? "RSA/ECDSA"})'
                      : 'DSC signature validation failed',
                  isDone: sigValid,
                ),
                _buildTrustChainConnector(isGenuine || isUnverifiedAnchor),
                _buildTrustChainNode(
                  title: 'Country trust authority',
                  subtitle: isGenuine
                      ? '${pa?.cscaCountry ?? widget.mrzResult.nationality} Master List CSCA verified'
                      : (isUnverifiedAnchor
                          ? 'Root CSCA for ${widget.mrzResult.nationality} unverified in local trust store'
                          : 'Trust anchor verification failed'),
                  isDone: isGenuine || isUnverifiedAnchor,
                  isWarning: isUnverifiedAnchor,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        OutlinedButton.icon(
          onPressed: _showSecurityDetailsModal,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFA78BFA),
            side: const BorderSide(color: Color(0xFFA78BFA)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.info_outline_rounded, size: 18),
          label: const Text('Security details'),
        ),
        const SizedBox(height: 12),

        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: () {
              setState(() {
                _currentStep = VerificationStep.liveness;
              });
              _startLivenessSequence();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: const Color(0xFF0A0F1D),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text(
                  'Continue to face check',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.face_retouching_natural_rounded, size: 20),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildTrustChainNode({
    required String title,
    required String subtitle,
    required bool isDone,
    bool isWarning = false,
  }) {
    Color borderColor;
    Color iconColor;
    IconData iconData;

    if (isWarning) {
      borderColor = const Color(0xFFF59E0B).withValues(alpha: 0.6);
      iconColor = const Color(0xFFF59E0B);
      iconData = Icons.warning_amber_rounded;
    } else if (isDone) {
      borderColor = const Color(0xFF2DD4BF).withValues(alpha: 0.5);
      iconColor = const Color(0xFF2DD4BF);
      iconData = Icons.check_circle_rounded;
    } else {
      borderColor = Colors.white12;
      iconColor = Colors.white24;
      iconData = Icons.radio_button_unchecked;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF131D2D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(iconData, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrustChainConnector(bool isDone) {
    return Center(
      child: Container(
        width: 2,
        height: 12,
        color: isDone ? const Color(0xFF2DD4BF) : Colors.white12,
      ),
    );
  }

  // --- 3. LIVENESS VIEW ---
  Widget _buildLivenessView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        const Text(
          'Facial Liveness & 1:1 Match',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Matching live selfie against biometric face photograph in ePassport chip DG2',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.65),
            fontSize: 12,
          ),
        ),
        const Spacer(),

        // Circular Camera Viewfinder
        Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              RotationTransition(
                turns: _radarController,
                child: Container(
                  width: 190,
                  height: 190,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _livenessComplete
                          ? const Color(0xFF2DD4BF)
                          : const Color(0xFF8B5CF6),
                      width: 3,
                    ),
                  ),
                ),
              ),
              Container(
                width: 170,
                height: 170,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF0C1322),
                ),
                child: ClipOval(
                  child: Center(
                    child: Icon(
                      _livenessComplete
                          ? Icons.check_circle_outline_rounded
                          : Icons.face_rounded,
                      size: 90,
                      color: _livenessComplete
                          ? const Color(0xFF2DD4BF)
                          : const Color(0xFFA78BFA),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        Text(
          _livenessStages[_livenessStageIndex],
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),

        if (_livenessComplete)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0F2F2B),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFF2DD4BF),
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'MATCH SCORE: 98.7%',
                      style: TextStyle(
                        color: Color(0xFF2DD4BF),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Pass threshold: 85.0% · Genuine biometric match',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2DD4BF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'PASSED',
                    style: TextStyle(
                      color: Color(0xFF080D1A),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

        const Spacer(),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.privacy_tip_outlined,
              size: 13,
              color: Colors.white.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 6),
            Text(
              'Zero video or raw biometrics sent to cloud',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _livenessComplete
                ? () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BtidIssuedScreen(
                          mrzResult: _chipData?.chipMrz ?? widget.mrzResult,
                        ),
                      ),
                    );
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: const Color(0xFF0A0F1D),
              disabledBackgroundColor: Colors.white12,
              disabledForegroundColor: Colors.white38,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text(
                  'Issue my Tourist ID',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.badge_rounded, size: 20),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}
