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
import 'package:qrypta/src/features/authentication/presentation/widgets/manual_passport_input_sheet.dart';
import 'package:qrypta/src/features/authentication/presentation/widgets/mrz_detected_result_sheet.dart';
import 'package:qrypta/src/features/authentication/presentation/widgets/mrz_scanner_overlay.dart';

export 'package:qrypta/src/features/authentication/presentation/widgets/manual_passport_input_sheet.dart';
export 'package:qrypta/src/features/authentication/presentation/widgets/mrz_detected_result_sheet.dart';
export 'package:qrypta/src/features/authentication/presentation/widgets/mrz_scanner_overlay.dart';

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
    MrzDetectedResultSheet.show(
      context: context,
      result: result,
      onContinue: () {
        Navigator.pop(context);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PassportVerificationFlowScreen(
              mrzResult: result,
            ),
          ),
        );
      },
    );
  }

  void _openManualInputSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ManualPassportInputSheet(
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
          MrzScannerOverlay(
            state: _state,
            statusMessage: _statusMessage,
            isTorchOn: _isTorchOn,
            laserAnimation: _laserAnimation,
            onToggleTorch: _toggleTorch,
            onOpenManualInput: _openManualInputSheet,
            onBack: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}


