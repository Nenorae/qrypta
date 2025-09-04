// lib/src/features/transaction/presentation/screens/send_scanner_screen.dart

import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qrypta/src/core/config/theme/app_colors.dart';

class SendScannerScreen extends StatefulWidget {
  final Function(String) onScanResult;

  const SendScannerScreen({super.key, required this.onScanResult});

  @override
  State<SendScannerScreen> createState() => _SendScannerScreenState();
}

class _SendScannerScreenState extends State<SendScannerScreen> {
  final MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );

  // Manual state management untuk torch
  bool _isTorchOn = false;

  @override
  void dispose() {
    developer.log('Disposing SendScannerScreen', name: 'SendScannerScreen');
    controller.dispose();
    super.dispose();
  }

  Future<void> _toggleTorch() async {
    try {
      await controller.toggleTorch();
      setState(() {
        _isTorchOn = !_isTorchOn;
      });
      developer.log('Torch toggled: $_isTorchOn', name: 'SendScannerScreen');
    } catch (e, s) {
      developer.log('Error toggling torch', name: 'SendScannerScreen', error: e, stackTrace: s);
    }
  }

  @override
  Widget build(BuildContext context) {
    developer.log('Building SendScannerScreen', name: 'SendScannerScreen');
    final scanWindow = Rect.fromCenter(
      center: MediaQuery.of(context).size.center(Offset.zero),
      width: 250,
      height: 250,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.font),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          // SOLUSI 1: Menggunakan state management manual
          IconButton(
            onPressed: _toggleTorch,
            icon: Icon(
              _isTorchOn ? Icons.flash_on : Icons.flash_off,
              color: AppColors.font,
            ),
          ),
          IconButton(
            onPressed: () {
              developer.log('Switching camera', name: 'SendScannerScreen');
              controller.switchCamera();
            },
            icon: const Icon(Icons.flip_camera_ios, color: AppColors.font),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            scanWindow: scanWindow,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                final String? scannedAddress = barcodes.first.rawValue;
                if (scannedAddress != null) {
                  developer.log('Scanned address: $scannedAddress', name: 'SendScannerScreen');
                  controller.stop();
                  widget.onScanResult(scannedAddress);
                }
              }
            },
          ),
          // Membuat overlay dengan lubang di tengah
          CustomPaint(
            painter: ScannerOverlayPainter(scanWindow),
            child: Container(),
          ),
        ],
      ),
    );
  }
}

// Custom painter untuk menggambar overlay scanner
class ScannerOverlayPainter extends CustomPainter {
  final Rect scanWindow;

  ScannerOverlayPainter(this.scanWindow);

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPath = Path()..addRect(Rect.largest);
    final cutoutPath = Path()..addRect(scanWindow);

    final backgroundPaint = Paint()..color = Colors.black.withOpacity(0.5);

    final backgroundWithCutout = Path.combine(
      PathOperation.difference,
      backgroundPath,
      cutoutPath,
    );

    canvas.drawPath(backgroundWithCutout, backgroundPaint);

    final borderPaint =
        Paint()
          ..color = AppColors.font
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;

    // Menggambar sudut-sudut
    const cornerLength = 30.0;

    // Sudut kiri atas
    canvas.drawPath(
      Path()
        ..moveTo(scanWindow.left, scanWindow.top + cornerLength)
        ..lineTo(scanWindow.left, scanWindow.top)
        ..lineTo(scanWindow.left + cornerLength, scanWindow.top),
      borderPaint,
    );

    // Sudut kanan atas
    canvas.drawPath(
      Path()
        ..moveTo(scanWindow.right - cornerLength, scanWindow.top)
        ..lineTo(scanWindow.right, scanWindow.top)
        ..lineTo(scanWindow.right, scanWindow.top + cornerLength),
      borderPaint,
    );

    // Sudut kiri bawah
    canvas.drawPath(
      Path()
        ..moveTo(scanWindow.left, scanWindow.bottom - cornerLength)
        ..lineTo(scanWindow.left, scanWindow.bottom)
        ..lineTo(scanWindow.left + cornerLength, scanWindow.bottom),
      borderPaint,
    );

    // Sudut kanan bawah
    canvas.drawPath(
      Path()
        ..moveTo(scanWindow.right - cornerLength, scanWindow.bottom)
        ..lineTo(scanWindow.right, scanWindow.bottom)
        ..lineTo(scanWindow.right, scanWindow.bottom - cornerLength),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

