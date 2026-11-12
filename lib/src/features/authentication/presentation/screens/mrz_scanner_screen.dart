// lib/src/features/authentication/presentation/screens/mrz_scanner_screen.dart

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qrypta/src/core/config/theme/app_colors.dart';
import 'package:qrypta/src/core/utils/mrz_parser.dart';
import 'package:qrypta/src/features/authentication/presentation/screens/passport_verification_flow_screen.dart';

class MrzScannerScreen extends StatefulWidget {
  const MrzScannerScreen({super.key});

  @override
  State<MrzScannerScreen> createState() => _MrzScannerScreenState();
}

class _MrzScannerScreenState extends State<MrzScannerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _laserAnimController;
  late Animation<double> _laserAnimation;

  MobileScannerController? _scannerController;
  bool _isProcessing = false;
  MrzParseResult? _detectedResult;

  @override
  void initState() {
    super.initState();
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

    try {
      _scannerController = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        facing: CameraFacing.back,
        torchEnabled: false,
      );
    } catch (_) {
      // Graceful fallback jika di platform tanpa camera native
    }
  }

  @override
  void dispose() {
    _laserAnimController.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  void _injectDemoPassport() {
    setState(() {
      _isProcessing = true;
    });

    // Injeksi data resmi James Wilson
    final demoResult = MrzParseResult.demoJamesWilson();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _detectedResult = demoResult;
      });
      _showDetectedResultModal(demoResult);
    });
  }

  void _onBarcodesDetected(BarcodeCapture capture) {
    if (_isProcessing || _detectedResult != null) return;

    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue != null && rawValue.isNotEmpty) {
        final parsed = MrzParser.detectAndParseFromText(rawValue);
        if (parsed != null && parsed.isValid) {
          setState(() {
            _detectedResult = parsed;
          });
          _showDetectedResultModal(parsed);
          break;
        }
      }
    }
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
                    _buildDataRow('Nationality', '${result.nationality} (United Kingdom)'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Camera Viewfinder / MobileScanner
          if (_scannerController != null)
            MobileScanner(
              controller: _scannerController!,
              onDetect: _onBarcodesDetected,
            )
          else
            Container(
              color: const Color(0xFF080D1A),
              child: const Center(
                child: Text(
                  'Optical Camera Ready',
                  style: TextStyle(color: Colors.white54),
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
                      // Tombol Cepat Demo Passport
                      TextButton.icon(
                        onPressed: _injectDemoPassport,
                        style: TextButton.styleFrom(
                          backgroundColor: AppColors.accent.withValues(alpha: 0.2),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(color: AppColors.accent),
                          ),
                        ),
                        icon: const Icon(Icons.flash_on_rounded, size: 14, color: AppColors.accent),
                        label: const Text(
                          'Demo Passport',
                          style: TextStyle(
                            color: AppColors.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
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
                    'Align the 2-line MRZ at the bottom of your passport biodata page inside the frame.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                  ),
                ),
                const Spacer(),

                // Viewfinder Frame (Aspect ratio paspor TD3 MRZ band)
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
                              color: const Color(0xFF2DD4BF),
                              width: 2,
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

                // Tombol Bawah: Direct Action untuk Pengujian Mudah
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _injectDemoPassport,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E293B),
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: AppColors.accent.withValues(alpha: 0.5),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.fingerprint_rounded, color: AppColors.accent),
                          label: const Text(
                            'Use Demo Passport (James Wilson)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
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
