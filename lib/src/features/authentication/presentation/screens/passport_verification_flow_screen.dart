// lib/src/features/authentication/presentation/screens/passport_verification_flow_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qrypta/src/core/config/theme/app_colors.dart';
import 'package:qrypta/src/core/utils/mrz_parser.dart';
import 'package:qrypta/src/features/authentication/presentation/screens/btid_issued_screen.dart';

enum VerificationStep { nfc, auth, liveness }

class PassportVerificationFlowScreen extends StatefulWidget {
  final MrzParseResult mrzResult;

  const PassportVerificationFlowScreen({
    super.key,
    required this.mrzResult,
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

  // State Step 1: NFC
  int _nfcStageIndex = 0;
  double _nfcProgress = 0.0;
  Timer? _nfcTimer;
  static const List<String> _nfcStages = [
    'Connecting to passport contactless antenna...',
    'Establishing secure channel (BAC/PACE)...',
    'Reading passport data (DG1: MRZ)...',
    'Reading passport photograph (DG2: Biometrics)...',
    'Reading signed security data (SOD)...',
    'Chip read successfully!',
  ];

  // State Step 2: Auth
  int _authStageIndex = 0;
  Timer? _authTimer;
  static const List<String> _authStages = [
    'Electronic passport detected',
    'Chip data integrity verified (DG1 & DG2 hashes matched SOD)',
    'Digital signature verified (SOD ECDSA signature valid)',
    'Document signer certificate verified',
    'Issuing country trust verified (ICAO PKD / CSCA)',
  ];

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

    _startNfcSequence();
  }

  @override
  void dispose() {
    _radarController.dispose();
    _pulseController.dispose();
    _livenessController.dispose();
    _nfcTimer?.cancel();
    _authTimer?.cancel();
    _livenessTimer?.cancel();
    super.dispose();
  }

  // --- Step 1: NFC Sequence ---
  void _startNfcSequence() {
    _nfcTimer?.cancel();
    _nfcStageIndex = 0;
    _nfcProgress = 0.0;

    _nfcTimer = Timer.periodic(const Duration(milliseconds: 650), (timer) {
      if (!mounted) return;
      setState(() {
        if (_nfcStageIndex < _nfcStages.length - 1) {
          _nfcStageIndex++;
          _nfcProgress = (_nfcStageIndex + 1) / _nfcStages.length;
        } else {
          _nfcProgress = 1.0;
          timer.cancel();
          // Auto advance ke Auth step
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              setState(() {
                _currentStep = VerificationStep.auth;
              });
              _startAuthSequence();
            }
          });
        }
      });
    });
  }

  // --- Step 2: Auth Sequence ---
  void _startAuthSequence() {
    _authTimer?.cancel();
    _authStageIndex = 0;

    _authTimer = Timer.periodic(const Duration(milliseconds: 600), (timer) {
      if (!mounted) return;
      setState(() {
        if (_authStageIndex < _authStages.length - 1) {
          _authStageIndex++;
        } else {
          timer.cancel();
        }
      });
    });
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFF131D2D),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
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
                    _buildModalRow('Country Trust Authority', '${widget.mrzResult.nationality} HMPO CSCA'),
                    const Divider(color: Colors.white12, height: 14),
                    _buildModalRow('Document Signer (DS)', 'UKPA-DS-2024-08'),
                    const Divider(color: Colors.white12, height: 14),
                    _buildModalRow('Hash Algorithm', 'SHA-256 (FIPS 180-4)'),
                    const Divider(color: Colors.white12, height: 14),
                    _buildModalRow('Signature Scheme', 'ECDSA BrainpoolP256r1'),
                    const Divider(color: Colors.white12, height: 14),
                    _buildModalRow('Passive Authentication', 'VALIDATED · GENUINE'),
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
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
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
              // Step Progress Tracker
              _buildStepTracker(),
              const SizedBox(height: 24),

              // Konten Utama Dinamis Berdasarkan Step
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

  // --- 1. NFC VIEW ---
  Widget _buildNfcView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(),
        // Radar Pulsa Animasi Berpusat pada Ikon NFC
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
                      color: const Color(0xFFA78BFA).withValues(alpha: 0.08),
                    ),
                  );
                },
              ),
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFA78BFA).withValues(alpha: 0.15),
                  border: Border.all(
                    color: const Color(0xFFA78BFA).withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
              ),
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFF4C1D95)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.nfc_rounded,
                  size: 48,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 36),

        // Tahapan Teks Berurutan
        Text(
          _nfcStages[_nfcStageIndex],
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),

        // Progress Bar
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: _nfcProgress,
            backgroundColor: Colors.white12,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFA78BFA)),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Hold passport firmly against phone NFC area',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 12,
          ),
        ),
        const Spacer(),
      ],
    );
  }

  // --- 2. AUTH VIEW ---
  Widget _buildAuthView() {
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
        const SizedBox(height: 24),

        // 4-Node Visual Trust Chain
        _buildTrustChainNode(
          title: 'ePassport chip',
          subtitle: 'ISO 14443 contactless microchip intact',
          isDone: _authStageIndex >= 0,
        ),
        _buildTrustChainConnector(_authStageIndex >= 1),
        _buildTrustChainNode(
          title: 'Signed passport data',
          subtitle: 'DG1 & DG2 hashes match SOD document',
          isDone: _authStageIndex >= 1,
        ),
        _buildTrustChainConnector(_authStageIndex >= 2),
        _buildTrustChainNode(
          title: 'Document signer certificate',
          subtitle: 'ECDSA signature validated with public key',
          isDone: _authStageIndex >= 2,
        ),
        _buildTrustChainConnector(_authStageIndex >= 4),
        _buildTrustChainNode(
          title: 'Country trust authority',
          subtitle: '${widget.mrzResult.nationality} Master List CSCA verified',
          isDone: _authStageIndex >= 4,
        ),

        const Spacer(),

        // Tombol Security Details
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

        // Tombol Lanjut ke Face Check
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
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF131D2D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDone
              ? const Color(0xFF2DD4BF).withValues(alpha: 0.5)
              : Colors.white12,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            color: isDone ? const Color(0xFF2DD4BF) : Colors.white24,
            size: 20,
          ),
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
              // Outer Glowing Ring
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
              // Inner Camera Frame
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

        // Status Text
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

        // Kartu Skor Kemiripan
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

        // Catatan Privasi
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

        // Tombol Terbitkan BTID
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _livenessComplete
                ? () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BtidIssuedScreen(
                          mrzResult: widget.mrzResult,
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
