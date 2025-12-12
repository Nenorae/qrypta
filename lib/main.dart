import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Ganti dengan path file Anda yang sebenarnya
import 'package:qrypta/src/core/config/theme/app_theme.dart';
import 'package:qrypta/src/features/authentication/presentation/providers/auth_providers.dart';
import 'package:qrypta/src/features/authentication/presentation/screens/auth_wrapper.dart';
import 'package:qrypta/src/features/authentication/presentation/screens/pin_verification_screen.dart';
import 'package:qrypta/src/features/home/presentation/screens/home_screen_backup.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sharedPrefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sharedPrefs),
    ],
    child: const MyApp(),
  ));
}

// 1. Root Widget Aplikasi
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Qrypta',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      // Pintu masuk aplikasi sekarang adalah Initializer, bukan AppLockWrapper lagi.
      home: const Initializer(),
    );
  }
}

// 2. Layar Inisialisasi (Gerbang Utama)
// Tugasnya hanya menunggu semua data siap sebelum melanjutkan.
class Initializer extends ConsumerStatefulWidget {
  const Initializer({super.key});

  @override
  ConsumerState<Initializer> createState() => _InitializerState();
}

class _InitializerState extends ConsumerState<Initializer> {
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // INI BAGIAN PALING PENTING:
    // Aplikasi akan "berhenti" di baris ini dan menunggu hingga
    // Future dari authStateProvider selesai dan memberikan data.
    try {
      await ref.read(authStateProvider.future);

      // Setelah data siap, baru kita navigasi ke Wrapper utama.
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const AppLockWrapper()),
        );
      }
    } catch (e) {
      // Jika terjadi error saat inisialisasi, Anda bisa menanganinya di sini
      // Misalnya, menampilkan dialog error.
      print("Error during initialization: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // Selama menunggu, tampilkan layar loading.
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

// 3. Wrapper Utama yang Sekarang Jauh Lebih Sederhana dan Kuat
class AppLockWrapper extends ConsumerStatefulWidget {
  const AppLockWrapper({super.key});

  @override
  ConsumerState<AppLockWrapper> createState() => _AppLockWrapperState();
}

class _AppLockWrapperState extends ConsumerState<AppLockWrapper>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Kunci aplikasi saat masuk ke background jika user punya wallet
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      final hasWallet = ref.read(authStateProvider).value ?? false;
      if (hasWallet) {
        ref.read(appLockProvider.notifier).lock();
      }
    }
  }

  void _handleUnlock() {
    ref.read(appLockProvider.notifier).unlock();
  }

  void _handleVerificationFailed(int attempts) {
    // Tambahkan logika jika verifikasi gagal
  }

  @override
  Widget build(BuildContext context) {
    // Karena kita tahu data sudah siap, kita bisa langsung mengambil nilainya.
    // Tidak perlu lagi authState.when() yang rumit!
    final hasWallet = ref.watch(authStateProvider).value ?? false;
    final isLocked = ref.watch(appLockProvider);

    // Logika routing sekarang sangat bersih, cepat, dan anti-gagal.
    if (!hasWallet) {
      return const AuthWrapper();
    }

    if (isLocked) {
      return PinVerificationScreen(
        title: 'Enter PIN to Unlock',
        subtitle: 'Please enter your PIN to continue',
        onVerificationSuccess: _handleUnlock,
        onVerificationFailed: (dynamic attempts) {
          if (attempts is int) {
            _handleVerificationFailed(attempts);
          }
        },
      );
    } else {
      return const HomeScreen();
    }
  }

  
}

// 4. Provider dan StateNotifier (tidak berubah)
final appLockProvider = StateNotifierProvider<AppLockNotifier, bool>((ref) {
  return AppLockNotifier();
});

class AppLockNotifier extends StateNotifier<bool> {
  // Selalu mulai dalam keadaan terkunci
  AppLockNotifier() : super(true);

  void lock() => state = true;
  void unlock() => state = false;
}
