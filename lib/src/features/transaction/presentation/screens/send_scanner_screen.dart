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
          // Demo QRIS Simulation Floating Controls
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.qr_code_2_rounded, size: 14, color: Color(0xFF2DD4BF)),
                        SizedBox(width: 6),
                        Text(
                          'DEMO QRIS SIMULATION SHORTCUT',
                          style: TextStyle(
                            color: Color(0xFF2DD4BF),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              controller.stop();
                              widget.onScanResult(
                                '{"type":"QRIS","merchantId":"MCH-3311","merchantName":"Bali Coffee House - Canggu","amount":85000,"address":"0x3311A9908F8718E237aDE73708aB59f212284bE0","description":"Specialty Coffee & Pastry"}',
                              );
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF2DD4BF).withValues(alpha: 0.3)),
                              ),
                              child: Column(
                                children: const [
                                  Text(
                                    'Bali Coffee House',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'IDR 85,000',
                                    style: TextStyle(
                                      color: Color(0xFF2DD4BF),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              controller.stop();
                              widget.onScanResult(
                                '{"type":"QRIS","merchantId":"MCH-5520","merchantName":"Bali Adventure Tours","amount":350000,"address":"0x5520e5ff38a7c645bcf56b823e590d9a6c9cf141","description":"Mount Batur Sunrise Trek"}',
                              );
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF2DD4BF).withValues(alpha: 0.3)),
                              ),
                              child: Column(
                                children: const [
                                  Text(
                                    'Bali Adventure',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'IDR 350,000',
                                    style: TextStyle(
                                      color: Color(0xFF2DD4BF),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
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

    final backgroundPaint = Paint()..color = Colors.black.withValues(alpha: 0.5);

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

