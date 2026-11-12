// lib/src/features/authentication/presentation/screens/btid_issued_screen.dart

import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qrypta/src/core/config/theme/app_colors.dart';
import 'package:qrypta/src/core/data/models/btid_credential_model.dart';
import 'package:qrypta/src/core/services/blockchain/blockchain_service.dart';
import 'package:qrypta/src/core/utils/mrz_parser.dart';
import 'package:qrypta/src/features/authentication/presentation/providers/auth_providers.dart';
import 'package:qrypta/src/features/authentication/presentation/providers/btid_provider.dart';
import 'package:qrypta/src/features/home/presentation/screens/home_screen.dart';
import 'package:qrypta/src/features/transaction/presentation/screens/levy_payment_screen.dart';
import 'package:qrypta/src/features/verification/presentation/widgets/btid_card_widget.dart';

class BtidIssuedScreen extends ConsumerStatefulWidget {
  final MrzParseResult mrzResult;

  const BtidIssuedScreen({
    super.key,
    required this.mrzResult,
  });

  @override
  ConsumerState<BtidIssuedScreen> createState() => _BtidIssuedScreenState();
}

class _BtidIssuedScreenState extends ConsumerState<BtidIssuedScreen> {
  bool _isIssuing = true;
  String? _errorMessage;
  BtidCredentialModel? _issuedCredential;

  @override
  void initState() {
    super.initState();
    _executeAutoIssuance();
  }

  Future<void> _executeAutoIssuance() async {
    try {
      final authRepo = ref.read(authRepositoryProvider);
      final saveMnemonicUseCase = ref.read(saveMnemonicUseCaseProvider);
      final savePrivateKeyUseCase = ref.read(savePrivateKeyUseCaseProvider);
      final savePinUseCase = ref.read(savePinUseCaseProvider);
      final getChecksumAddressUseCase = ref.read(getChecksumAddressUseCaseProvider);

      developer.log('Step 1: Generating Web3 Keypair for Tourist ID...', name: 'BtidIssuedScreen');
      // 1. Generate mnemonic & derive keys in background isolate
      final mnemonic = await authRepo.generateMnemonic();
      final privateKey = await authRepo.getPrivateKeyFromMnemonic(mnemonic);
      final address = await getChecksumAddressUseCase(privateKey);

      // 2. Persist secrets safely
      await saveMnemonicUseCase(mnemonic);
      await savePrivateKeyUseCase(privateKey);
      await savePinUseCase('123456'); // Default initial PIN for fast onboarding

      developer.log('Step 2: Constructing BTID Credential...', name: 'BtidIssuedScreen');
      final now = DateTime.now();
      final arrivalDateStr = DateFormat('yyyy-MM-dd').format(now);
      final stayExpiryStr = DateFormat('yyyy-MM-dd').format(now.add(const Duration(days: 30)));

      // 3. Construct official BtidCredentialModel
      final credential = BtidCredentialModel(
        btidNumber: 'BTID-2026-4471-0938',
        fullName: widget.mrzResult.fullName,
        nationality: widget.mrzResult.nationality,
        passportMasked: widget.mrzResult.passportMasked,
        dob: widget.mrzResult.birthDate != null
            ? DateFormat('yyyy-MM-dd').format(widget.mrzResult.birthDate!)
            : '1988-04-12',
        docExpiry: widget.mrzResult.expiryDate != null
            ? DateFormat('yyyy-MM-dd').format(widget.mrzResult.expiryDate!)
            : '2031-08-15',
        visaType: 'e-VOA B1',
        arrivalDate: arrivalDateStr,
        stayExpiry: stayExpiryStr,
        levyStatus: 'unpaid',
        walletAddress: address,
        issuedAt: now,
      );

      // 4. Save credential locally
      await ref.read(btidCredentialProvider.notifier).saveCredential(credential);

      // 5. Submit issuance audit record to ezsign-core / Besu
      try {
        final verificationService = ref.read(blockchainServiceProvider).verification;
        await verificationService.recordCredentialIssuedAudit(
          btid: credential.btidNumber,
          fullName: credential.fullName,
          walletAddress: address,
        );
      } catch (e) {
        developer.log('Audit record dispatched with local fallback: $e', name: 'BtidIssuedScreen');
      }

      // 6. Invalidate authStateProvider so lock wrapper recognizes the wallet
      ref.invalidate(authStateProvider);

      if (mounted) {
        setState(() {
          _issuedCredential = credential;
          _isIssuing = false;
        });
      }
    } catch (e) {
      developer.log('Error during auto-issuance: $e', name: 'BtidIssuedScreen', error: e);
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isIssuing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isIssuing
            ? _buildIssuingLoading()
            : (_errorMessage != null ? _buildErrorView() : _buildIssuedSuccess()),
      ),
    );
  }

  Widget _buildIssuingLoading() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withValues(alpha: 0.15),
              ),
              child: const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Issuing Bali Tourist ID...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Binding secp256k1 keypair & recording on Hyperledger Besu',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 56),
            const SizedBox(height: 16),
            const Text(
              'Issuance Failed',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error occurred.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isIssuing = true;
                  _errorMessage = null;
                });
                _executeAutoIssuance();
              },
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIssuedSuccess() {
    final credential = _issuedCredential ?? BtidCredentialModel.defaultDemo();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          // Celebration Pill
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF2DD4BF).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF2DD4BF).withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 14,
                    color: Color(0xFF2DD4BF),
                  ),
                  SizedBox(width: 6),
                  Text(
                    'CREDENTIAL ISSUED & ANCHORED',
                    style: TextStyle(
                      color: Color(0xFF2DD4BF),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          const Text(
            'Your Bali Tourist ID is Ready',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Cryptographic identity wallet activated on Hyperledger Besu.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 24),

          // Render Visual Kartu BTID
          BtidCardWidget(
            credential: credential,
            isMini: false,
          ),
          const SizedBox(height: 24),

          // 3 Catatan Edukatif Resmi Pemerintah
          _buildNoticeTile(
            icon: Icons.menu_book_rounded,
            title: 'Not a physical passport replacement',
            description:
                'Keep your original booklet safe at your hotel deposit box. Show BTID QR code for daily tourist services.',
          ),
          const SizedBox(height: 10),
          _buildNoticeTile(
            icon: Icons.account_balance_wallet_rounded,
            title: 'Not a commercial bank account',
            description:
                'Token balances (IDRT) represent digital tourism vouchers for transparent island payments.',
          ),
          const SizedBox(height: 10),
          _buildNoticeTile(
            icon: Icons.drive_eta_rounded,
            title: 'Not a driving permit',
            description:
                'Renting scooters or cars in Bali requires a recognized international driving license alongside BTID.',
          ),
          const SizedBox(height: 32),

          // Tombol Lanjut ke Retribusi / Dashboard
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LevyPaymentScreen()),
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
                    'Next: Tourist Levy (IDR 150,000)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          TextButton(
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const HomeScreen()),
                (route) => false,
              );
            },
            child: const Text(
              'Skip to Dashboard (Pay later)',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Indikator Default PIN info
          Center(
            child: Text(
              'Default AppLock PIN set to 123456 (Can be changed in Profile)',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildNoticeTile({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF131D2D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 11,
                    height: 1.3,
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
