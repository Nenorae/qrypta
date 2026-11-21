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
import 'package:qrypta/src/features/authentication/presentation/widgets/passport_flow/liveness_step_view.dart';
import 'package:qrypta/src/features/authentication/presentation/widgets/passport_flow/nfc_step_view.dart';
import 'package:qrypta/src/features/authentication/presentation/widgets/passport_flow/passive_auth_step_view.dart';
import 'package:qrypta/src/features/authentication/presentation/widgets/passport_flow/pki_security_modal.dart';

export 'package:qrypta/src/features/authentication/presentation/widgets/passport_flow/liveness_step_view.dart';
export 'package:qrypta/src/features/authentication/presentation/widgets/passport_flow/nfc_step_view.dart';
export 'package:qrypta/src/features/authentication/presentation/widgets/passport_flow/passive_auth_step_view.dart';
export 'package:qrypta/src/features/authentication/presentation/widgets/passport_flow/pki_security_modal.dart';

enum VerificationStep { nfc, auth, liveness }

class PassportVerificationFlowScreen extends StatefulWidget {
  final MrzParseResult mrzResult;
  final NfcPassportService? nfcService;
  final VerificationStep? initialStep;

  const PassportVerificationFlowScreen({
    super.key,
    required this.mrzResult,
    this.nfcService,
    this.initialStep,
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
    'Posisikan wajah di dalam frame (Preview Simulasi)',
    'Simulasi deteksi sudut dan pencahayaan wajah...',
    'Simulasi pengujian anti-spoofing liveness...',
    'Simulasi perbandingan foto terhadap paspor DG2...',
    'Simulasi: lolos (Biometrik TIDAK diverifikasi secara nyata)',
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

    if (widget.initialStep != null) {
      _currentStep = widget.initialStep!;
      if (_currentStep == VerificationStep.liveness) {
        _startLivenessSequence();
      }
    } else {
      _checkHardwareAndStartNfc();
    }
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
    PkiSecurityModal.show(
      context: context,
      passiveAuthResult: _passiveAuthResult,
      mrzResult: widget.mrzResult,
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
        return 'Facial Liveness (Simulasi)';
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
          label: 'Liveness (Demo)',
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
        return NfcStepView(
          pulseAnimation: _pulseController,
          nfcErrorMessage: _nfcErrorMessage,
          nfcStageMessage: _nfcStageMessage,
          nfcProgress: _nfcProgress,
          isNfcScanning: _isNfcScanning,
          onRetry: _checkHardwareAndStartNfc,
        );
      case VerificationStep.auth:
        return PassiveAuthStepView(
          passiveAuthResult: _passiveAuthResult,
          chipData: _chipData,
          mrzResult: widget.mrzResult,
          onShowSecurityDetails: _showSecurityDetailsModal,
          onContinueToLiveness: () {
            setState(() {
              _currentStep = VerificationStep.liveness;
            });
            _startLivenessSequence();
          },
        );
      case VerificationStep.liveness:
        return LivenessStepView(
          radarAnimation: _radarController,
          livenessComplete: _livenessComplete,
          currentStageMessage: _livenessStages[_livenessStageIndex],
          onIssueTouristId: _livenessComplete
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
        );
    }
  }
}
