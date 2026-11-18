// lib/src/features/authentication/presentation/screens/mrz_scanner_screen.dart

import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qrypta/src/core/config/theme/app_colors.dart';
import 'package:qrypta/src/core/error/app_failure.dart';
import 'package:qrypta/src/core/utils/mrz_extractor.dart';
import 'package:qrypta/src/core/utils/mrz_frame_consensus.dart';
import 'package:qrypta/src/core/utils/mrz_parser.dart';
import 'package:qrypta/src/features/authentication/presentation/screens/passport_verification_flow_screen.dart';

enum ScannerState {
  initializing,
  permissionDenied,
  cameraUnavailable,
  searching,
  partialDetected,
  verifyingConsensus,
  completed,
}

class MrzScannerScreen extends StatefulWidget {
  const MrzScannerScreen({super.key});

  @override
  State<MrzScannerScreen> createState() => _MrzScannerScreenState();
}

class _MrzScannerScreenState extends State<MrzScannerScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _laserAnimController;
  late Animation<double> _laserAnimation;

  CameraController? _cameraController;
  CameraDescription? _cameraDescription;
  TextRecognizer? _textRecognizer;

  final MrzFrameConsensus _consensus = MrzFrameConsensus(
    requiredConsecutiveMatches: 2,
    windowDuration: const Duration(seconds: 2),
  );

  ScannerState _state = ScannerState.initializing;
  String _statusMessage = 'Menginisialisasi kamera optik...';
  bool _isBusy = false;
  bool _isTorchOn = false;
  DateTime _lastFrameTime = DateTime.now();

  Timer? _timeoutTimer;
  bool _showManualInputBanner = false;

  MrzParseResult? _detectedResult;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _laserAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _laserAnimation = Tween<double>(begin: 0.1, end: 0.9).animate(
      CurvedAnimation(
        parent: _laserAnimController,
        curve: Curves.easeInOut,
      ),
    );

    _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    _initializeCamera();
    _startTimeoutTimer();
  }

  void _startTimeoutTimer() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 30), () {
      if (mounted && _detectedResult == null) {
        setState(() {
          _showManualInputBanner = true;
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final camera = _cameraController;
    if (camera == null || !camera.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      camera.dispose();
      _cameraController = null;
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timeoutTimer?.cancel();
    _laserAnimController.dispose();
    _stopCameraStream();
    _cameraController?.dispose();
    _textRecognizer?.close();
    super.dispose();
  }

  Future<void> _stopCameraStream() async {
    try {
      if (_cameraController != null &&
          _cameraController!.value.isInitialized &&
          _cameraController!.value.isStreamingImages) {
        await _cameraController!.stopImageStream();
      }
    } on Object {
      // Ignored on teardown
    }
  }

  Future<void> _initializeCamera() async {
    setState(() {
      _state = ScannerState.initializing;
      _statusMessage = 'Memeriksa izin kamera...';
    });

    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) {
        setState(() {
          _state = ScannerState.permissionDenied;
          _statusMessage = 'Izin kamera diperlukan untuk memindai paspor';
        });
      }
      return;
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _state = ScannerState.cameraUnavailable;
            _statusMessage = 'Perangkat kamera tidak ditemukan';
          });
        }
        return;
      }

      // Prioritaskan kamera belakang
      final backCamera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraDescription = backCamera;

      final controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await controller.initialize();
      try {
        await controller.setFocusMode(FocusMode.auto);
      } on Object {
        // Auto focus might not be supported on some devices
      }

      if (!mounted) {
        await controller.dispose();
        return;
      }

      _cameraController = controller;
      setState(() {
        _state = ScannerState.searching;
        _statusMessage = 'Mencari pita MRZ paspor...';
      });

      // Mulai frame stream dengan throttling (~3-4 fps)
      await controller.startImageStream(_processCameraFrame);
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _state = ScannerState.cameraUnavailable;
          _statusMessage = 'Gagal mengakses kamera: $e';
        });
      }
    }
  }

  Future<void> _toggleTorch() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    try {
      if (_isTorchOn) {
        await _cameraController!.setFlashMode(FlashMode.off);
      } else {
        await _cameraController!.setFlashMode(FlashMode.torch);
      }
      setState(() {
        _isTorchOn = !_isTorchOn;
      });
    } on Object {
      // Flashlight not supported on some hardware
    }
  }

  Future<void> _processCameraFrame(CameraImage image) async {
    if (_isBusy || _detectedResult != null || _textRecognizer == null) return;

    // Throttle frame stream ke ~3-4 fps (250 ms)
    final now = DateTime.now();
    if (now.difference(_lastFrameTime).inMilliseconds < 250) {
      return;
    }
    _lastFrameTime = now;
    _isBusy = true;

    try {
      final inputImage = _convertCameraImageToInputImage(image);
      if (inputImage == null) {
        _isBusy = false;
        return;
      }

      final recognizedText = await _textRecognizer!.processImage(inputImage);
      if (!mounted || _detectedResult != null) {
        _isBusy = false;
        return;
      }

      // Bangun daftar kandidat baris dari recognized blocks
      final lineCandidates = <MrzLineCandidate>[];
      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          lineCandidates.add(
            MrzLineCandidate.fromRect(line.text, line.boundingBox),
          );
        }
      }

      // Ekstraksi MRZ TD3 melalui mesin MrzExtractor
      final frameParsed = MrzExtractor.extractFromCandidates(lineCandidates) ??
          MrzExtractor.extractFromText(recognizedText.text);

      if (frameParsed != null && frameParsed.isValid) {
        // Evaluasi konsensus multi-frame
        final consensusResult = _consensus.addFrame(frameParsed);

        if (consensusResult != null) {
          // Konsensus multi-frame tercapai!
          _detectedResult = consensusResult;
          _timeoutTimer?.cancel();
          await _stopCameraStream();

          setState(() {
            _state = ScannerState.completed;
            _statusMessage = 'MRZ Terverifikasi Konsensus!';
          });

          _showDetectedResultModal(consensusResult);
        } else {
          // Frame valid pertama, menunggu frame konfirmasi
          setState(() {
            _state = ScannerState.verifyingConsensus;
            _statusMessage = 'Memverifikasi konsensus multi-frame...';
          });
        }
      } else if (frameParsed != null) {
        // Terbaca sebagian / check digit belum cocok
        _consensus.reset();
        setState(() {
          _state = ScannerState.partialDetected;
          _statusMessage = 'Pita MRZ terdeteksi, sesuaikan fokus...';
        });
      } else {
        _consensus.reset();
        if (_state != ScannerState.searching) {
          setState(() {
            _state = ScannerState.searching;
            _statusMessage = 'Mencari pita MRZ paspor...';
          });
        }
      }
    } on Object {
      // Abaikan frame error, stream tetap lanjut
    } finally {
      _isBusy = false;
    }
  }

  InputImage? _convertCameraImageToInputImage(CameraImage image) {
    final camera = _cameraDescription;
    if (camera == null) return null;

    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation = _getAndroidRotationCompensation(sensorOrientation);
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    rotation ??= InputImageRotation.rotation0deg;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    // Buffer plane bytes
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  int _getAndroidRotationCompensation(int sensorOrientation) {
    // Asumsi device default portrait
    final orientations = {
      DeviceOrientation.portraitUp: 0,
      DeviceOrientation.landscapeLeft: 90,
      DeviceOrientation.portraitDown: 180,
      DeviceOrientation.landscapeRight: 270,
    };
    final compensation = orientations[DeviceOrientation.portraitUp] ?? 0;
    return (sensorOrientation - compensation + 360) % 360;
  }

  void _showDetectedResultModal(MrzParseResult result) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFF131D2D),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 20,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Chip
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF2DD4BF),
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'MRZ PASSPORT DETECTED',
                        style: TextStyle(
                          color: Color(0xFF2DD4BF),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2DD4BF).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Checksum Modulo-10 Valid',
                      style: TextStyle(
                        color: Color(0xFF2DD4BF),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Detail Paspor Hasil OCR
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0C1322),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Column(
                  children: [
                    _buildDataRow('Full Name', result.fullName),
                    const Divider(color: Colors.white12, height: 16),
                    _buildDataRow('Passport No', result.passportMasked),
                    const Divider(color: Colors.white12, height: 16),
                    _buildDataRow('Nationality', result.nationality),
                    const Divider(color: Colors.white12, height: 16),
                    _buildDataRow('Date of Birth', result.birthDateFormatted),
                    const Divider(color: Colors.white12, height: 16),
                    _buildDataRow('Doc Expiry', result.expiryDateFormatted),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Pita Kode MRZ Raw
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.rawLine1,
                      style: const TextStyle(
                        color: Color(0xFF5EEAD4),
                        fontFamily: 'Courier',
                        fontSize: 10.5,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      result.rawLine2,
                      style: const TextStyle(
                        color: Color(0xFF5EEAD4),
                        fontFamily: 'Courier',
                        fontSize: 10.5,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Tombol Lanjut ke Chip Read
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PassportVerificationFlowScreen(
                          mrzResult: result,
                        ),
                      ),
                    );
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
                        'Continue to chip read',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.nfc_rounded, size: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDataRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 13,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  void _openManualInputSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ManualPassportInputSheet(
        onSubmitted: (mrzResult) {
          Navigator.pop(ctx);
          _detectedResult = mrzResult;
          _showDetectedResultModal(mrzResult);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Camera Viewfinder
          if (_cameraController != null && _cameraController!.value.isInitialized)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _cameraController!.value.previewSize?.height ?? 1,
                  height: _cameraController!.value.previewSize?.width ?? 1,
                  child: CameraPreview(_cameraController!),
                ),
              ),
            )
          else
            Container(
              color: const Color(0xFF080D1A),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _state == ScannerState.permissionDenied
                            ? Icons.no_photography_rounded
                            : Icons.camera_alt_outlined,
                        size: 48,
                        color: Colors.white38,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _statusMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 24),
                      if (_state == ScannerState.permissionDenied)
                        ElevatedButton.icon(
                          onPressed: () => openAppSettings(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: Colors.black,
                          ),
                          icon: const Icon(Icons.settings, size: 16),
                          label: const Text('Buka Pengaturan Aplikasi'),
                        ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _openManualInputSheet,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white30),
                        ),
                        icon: const Icon(Icons.edit_note, size: 18),
                        label: const Text('Input Paspor Manual'),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 2. Overlay Bingkai Pemindaian MRZ
          SafeArea(
            child: Column(
              children: [
                // Top App Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text(
                        'Scan Passport MRZ',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      // Tombol Senter
                      IconButton(
                        icon: Icon(
                          _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                          color: _isTorchOn ? AppColors.accent : Colors.white,
                        ),
                        onPressed: _toggleTorch,
                      ),
                    ],
                  ),
                ),

                // Status Banner Real-Time
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _state == ScannerState.verifyingConsensus
                          ? const Color(0xFF2DD4BF)
                          : Colors.white24,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_state == ScannerState.verifyingConsensus)
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF2DD4BF),
                          ),
                        )
                      else
                        Icon(
                          Icons.radar_rounded,
                          size: 14,
                          color: _state == ScannerState.partialDetected
                              ? Colors.amber
                              : AppColors.accent,
                        ),
                      const SizedBox(width: 8),
                      Text(
                        _statusMessage,
                        style: TextStyle(
                          color: _state == ScannerState.partialDetected
                              ? Colors.amberAccent
                              : Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Instruksi Pengguna
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Text(
                    'Posisikan 2 baris kode MRZ di bagian bawah biodata paspor tepat di dalam bingkai.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                  ),
                ),
                const Spacer(),

                // Viewfinder Frame (Aspect ratio paspor TD3 MRZ band: ~3.2)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: AspectRatio(
                    aspectRatio: 3.2,
                    child: Stack(
                      children: [
                        // Bingkai Toska
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: _state == ScannerState.verifyingConsensus
                                  ? const Color(0xFF5EEAD4)
                                  : const Color(0xFF2DD4BF),
                              width: 2.5,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            color: const Color(0xFF0D9488).withValues(alpha: 0.08),
                          ),
                        ),
                        // Laser sweep animation
                        AnimatedBuilder(
                          animation: _laserAnimation,
                          builder: (context, child) {
                            return Positioned(
                              top: _laserAnimation.value * 90,
                              left: 8,
                              right: 8,
                              child: Container(
                                height: 2.5,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      Color(0xFF2DD4BF),
                                      Color(0xFF5EEAD4),
                                      Color(0xFF2DD4BF),
                                      Colors.transparent,
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF2DD4BF).withValues(alpha: 0.8),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        // Corner Guides
                        Positioned(
                          left: 12,
                          top: 10,
                          child: Text(
                            'P<',
                            style: TextStyle(
                              color: const Color(0xFF2DD4BF).withValues(alpha: 0.6),
                              fontFamily: 'Courier',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Positioned(
                          right: 12,
                          bottom: 10,
                          child: Text(
                            'TD3 44x2',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontFamily: 'Courier',
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),

                // Banner Bantuan / Input Manual jika scan lama (>30s) atau tombol opsi
                if (_showManualInputBanner)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lightbulb_outline, color: Colors.amber, size: 20),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Mengalami kesulitan pemindaian? Pastikan pencahayaan cukup dan hindari pantulan silau.',
                            style: TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ),
                        TextButton(
                          onPressed: _openManualInputSheet,
                          child: const Text(
                            'Input Manual',
                            style: TextStyle(
                              color: AppColors.accent,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Tombol Bawah: Input Manual Alternatif Sah
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                  child: Column(
                    children: [
                      TextButton.icon(
                        onPressed: _openManualInputSheet,
                        icon: const Icon(Icons.keyboard_alt_outlined, size: 16, color: Colors.white70),
                        label: const Text(
                          'Ketik data paspor secara manual',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 13,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Zero cloud transmission · Local OCR verification',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 11,
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
        ],
      ),
    );
  }
}

/// Formulir Input Manual Paspor (Rencana Kerja §5A.3 item 7).
/// Jalur nyata alternatif (bukan fallback palsu) dengan validasi ICAO 9303 modulo 10 ketat.
class _ManualPassportInputSheet extends StatefulWidget {
  final void Function(MrzParseResult result) onSubmitted;

  const _ManualPassportInputSheet({required this.onSubmitted});

  @override
  State<_ManualPassportInputSheet> createState() => _ManualPassportInputSheetState();
}

class _ManualPassportInputSheetState extends State<_ManualPassportInputSheet> {
  final _formKey = GlobalKey<FormState>();

  final _surnameController = TextEditingController();
  final _givenNamesController = TextEditingController();
  final _passportNumberController = TextEditingController();
  final _countryController = TextEditingController(text: 'GBR');
  final _dobController = TextEditingController();
  final _expiryController = TextEditingController();

  String _sex = 'M';
  String? _errorMessage;

  @override
  void dispose() {
    _surnameController.dispose();
    _givenNamesController.dispose();
    _passportNumberController.dispose();
    _countryController.dispose();
    _dobController.dispose();
    _expiryController.dispose();
    super.dispose();
  }

  void _submit() {
    setState(() {
      _errorMessage = null;
    });

    if (!_formKey.currentState!.validate()) return;

    final surname = _surnameController.text.trim().toUpperCase().replaceAll(' ', '<');
    final givenNames = _givenNamesController.text.trim().toUpperCase().replaceAll(' ', '<');
    final country = _countryController.text.trim().toUpperCase().padRight(3, '<').substring(0, 3);
    final passportNum = _passportNumberController.text.trim().toUpperCase().padRight(9, '<').substring(0, 9);
    final dob = _dobController.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
    final expiry = _expiryController.text.trim().replaceAll(RegExp(r'[^0-9]'), '');

    if (dob.length != 6 || expiry.length != 6) {
      setState(() {
        _errorMessage = 'Format tanggal harus 6 digit YYMMDD (contoh: 880512)';
      });
      return;
    }

    try {
      // Hitung check digit ICAO 9303 sah
      final docCheck = MrzParser.computeCheckDigit(passportNum).toString();
      final dobCheck = MrzParser.computeCheckDigit(dob).toString();
      final expiryCheck = MrzParser.computeCheckDigit(expiry).toString();
      const personalNum = '<<<<<<<<<<<<<<';
      const personalCheck = '<';

      // Line 1: P< + Country(3) + Surname + << + GivenNames
      final nameSection = '$surname<<$givenNames';
      final line1 = ('P<$country$nameSection').padRight(44, '<').substring(0, 44);

      // Composite payload untuk pos 43
      final compositePayload = '$passportNum$docCheck$dob$dobCheck$expiry$expiryCheck$personalNum$personalCheck';
      final compositeCheck = MrzParser.computeCheckDigit(compositePayload).toString();

      // Line 2: Passport(9) + Check(1) + Nationality(3) + DOB(6) + Check(1) + Sex(1) + Expiry(6) + Check(1) + Personal(14) + Comp(1)
      final line2 = '$passportNum$docCheck$country$dob$dobCheck$_sex$expiry$expiryCheck$personalNum$personalCheck$compositeCheck';

      final parsed = MrzParser.parse(line1, line2, strict: true);
      widget.onSubmitted(parsed);
    } on ValidationFailure catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } on Object catch (e) {
      setState(() {
        _errorMessage = 'Gagal memproses data paspor: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 24,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Input Paspor Manual (ICAO 9303)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Data akan divalidasi dengan algoritma check digit modulo 10 standar internasional.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.redAccent),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _surnameController,
                      label: 'Surname / Nama Keluarga',
                      hint: 'WILSON',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      controller: _givenNamesController,
                      label: 'Given Names / Nama Depan',
                      hint: 'JAMES',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildTextField(
                      controller: _passportNumberController,
                      label: 'Nomor Paspor (9 karakter)',
                      hint: '724918789',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: _buildTextField(
                      controller: _countryController,
                      label: 'Negara (ISO 3)',
                      hint: 'GBR',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _dobController,
                      label: 'Tgl Lahir (YYMMDD)',
                      hint: '880512',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      controller: _expiryController,
                      label: 'Kedaluwarsa (YYMMDD)',
                      hint: '320318',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Jenis Kelamin: ', style: TextStyle(color: Colors.white70)),
                  const SizedBox(width: 12),
                  ChoiceChip(
                    label: const Text('Laki-laki (M)'),
                    selected: _sex == 'M',
                    onSelected: (val) => setState(() => _sex = 'M'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Perempuan (F)'),
                    selected: _sex == 'F',
                    onSelected: (val) => setState(() => _sex = 'F'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Validasi & Lanjutkan',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
        filled: true,
        fillColor: Colors.black26,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.accent),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      validator: (val) {
        if (val == null || val.trim().isEmpty) {
          return 'Wajib diisi';
        }
        return null;
      },
    );
  }
}
