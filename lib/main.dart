import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qrypta/src/core/config/theme/app_theme.dart';
import 'package:qrypta/src/features/authentication/presentation/providers/auth_providers.dart';
import 'package:qrypta/src/features/authentication/presentation/screens/auth_wrapper.dart';
import 'package:qrypta/src/features/authentication/presentation/screens/pin_verification_screen.dart';
import 'package:qrypta/src/features/home/presentation/screens/home_screen.dart';

// Global key for navigation
final navigatorKey = GlobalKey<NavigatorState>();

// Provider untuk mengelola state lock aplikasi
final appLockedProvider = StateProvider<bool>((ref) => true);

// Provider untuk mengelola timestamp terakhir kali aplikasi aktif
final lastActiveTimeProvider = StateProvider<DateTime?>((ref) => null);

// Provider untuk mengecek apakah ini adalah cold start
final isColdStartProvider = StateProvider<bool>((ref) => true);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  static const String _lastActiveKey = 'last_active_timestamp';
  static const String _appWasTerminatedKey = 'app_was_terminated';
  static const int _lockTimeoutMinutes = 5; // Lock setelah 5 menit tidak aktif

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAppState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _initializeAppState() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Cek apakah aplikasi sebelumnya ditutup secara normal atau terminated
    final wasTerminated = prefs.getBool(_appWasTerminatedKey) ?? true;
    final lastActiveString = prefs.getString(_lastActiveKey);
    
    if (wasTerminated || lastActiveString == null) {
      // Aplikasi di-terminate atau first launch
      ref.read(appLockedProvider.notifier).state = true;
      ref.read(isColdStartProvider.notifier).state = true;
    } else {
      // Cek berapa lama aplikasi tidak aktif
      final lastActive = DateTime.parse(lastActiveString);
      final now = DateTime.now();
      final difference = now.difference(lastActive).inMinutes;
      
      if (difference >= _lockTimeoutMinutes) {
        ref.read(appLockedProvider.notifier).state = true;
      } else {
        ref.read(appLockedProvider.notifier).state = false;
      }
      ref.read(isColdStartProvider.notifier).state = false;
    }
    
    // Set flag bahwa aplikasi sedang berjalan (bukan terminated)
    await prefs.setBool(_appWasTerminatedKey, false);
    await _updateLastActiveTime();
  }

  Future<void> _updateLastActiveTime() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    await prefs.setString(_lastActiveKey, now.toIso8601String());
    ref.read(lastActiveTimeProvider.notifier).state = now;
  }

  Future<void> _markAppAsTerminated() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_appWasTerminatedKey, true);
    await _updateLastActiveTime();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        print('App resumed from background');

        // Await the authStateProvider to resolve the race condition.
        // This ensures we have the correct wallet status before checking the lock timeout.
        final hasWallet = await ref.read(authStateProvider.future);

        if (hasWallet) {
          final prefs = await SharedPreferences.getInstance();
          final lastActiveString = prefs.getString(_lastActiveKey);

          if (lastActiveString != null) {
            final lastActive = DateTime.parse(lastActiveString);
            final now = DateTime.now();
            final difference = now.difference(lastActive).inMinutes;

            // Lock if the app has been inactive for longer than the threshold
            if (difference >= _lockTimeoutMinutes) {
              ref.read(appLockedProvider.notifier).state = true;
            }
          } else {
            // If there's no timestamp, lock the app for safety
            ref.read(appLockedProvider.notifier).state = true;
          }
        }

        await _updateLastActiveTime();
        break;

      case AppLifecycleState.paused:
        print('App moved to background');
        await _updateLastActiveTime();
        break;

      case AppLifecycleState.inactive:
        print('App became inactive');
        // Update time when the app becomes inactive
        await _updateLastActiveTime();
        break;

      case AppLifecycleState.detached:
        print('App is being terminated');
        await _markAppAsTerminated();
        break;

      case AppLifecycleState.hidden:
        print('App is hidden');
        await _updateLastActiveTime();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Qrypta',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: const Initializer(),
    );
  }
}

class Initializer extends ConsumerWidget {
  const Initializer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final isLocked = ref.watch(appLockedProvider);
    final isColdStart = ref.watch(isColdStartProvider);

    return authState.when(
      loading: () => const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading...'),
            ],
          ),
        ),
      ),
      error: (err, stack) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text("Error: $err"),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  // Retry mechanism
                  ref.invalidate(authStateProvider);
                },
                child: Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (hasWallet) {
        if (!hasWallet) {
          // User baru - tidak ada wallet
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(appLockedProvider.notifier).state = false;
            ref.read(isColdStartProvider.notifier).state = false;
          });
          return const AuthWrapper();
        }

        // User existing - ada wallet
        if (isLocked) {
          return PinVerificationScreen(
            title: isColdStart ? 'Welcome Back' : 'Enter PIN to Continue',
            subtitle: isColdStart 
                ? 'Please enter your PIN to access your wallet'
                : 'Enter your PIN to unlock the app',
            onVerificationSuccess: () {
              ref.read(appLockedProvider.notifier).state = false;
              ref.read(isColdStartProvider.notifier).state = false;
            },
            onVerificationFailed: (attempts) {
              // Handle failed attempts
              if (attempts >= 3) {
                _showTooManyAttemptsDialog(context, ref);
              }
            },
          );
        } else {
          return const HomeScreen();
        }
      },
    );
  }

  void _showTooManyAttemptsDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Too Many Attempts'),
        content: const Text(
          'You have entered the wrong PIN too many times. '
          'For security reasons, please wait before trying again.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Reset attempts atau implementasi delay
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

// Extension untuk menambahkan utility methods
extension AppLifecycleExtension on ConsumerState {
  Future<void> updateLastActiveTime(WidgetRef ref) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    await prefs.setString('last_active_timestamp', now.toIso8601String());
    ref.read(lastActiveTimeProvider.notifier).state = now;
  }
}

// Utility class untuk mengelola app security
class AppSecurityManager {
  static const String _lastActiveKey = 'last_active_timestamp';
  static const String _appWasTerminatedKey = 'app_was_terminated';
  static const int _defaultLockTimeoutMinutes = 5;

  static Future<bool> shouldLockApp({
    int timeoutMinutes = _defaultLockTimeoutMinutes,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final lastActiveString = prefs.getString(_lastActiveKey);
    
    if (lastActiveString == null) return true;
    
    final lastActive = DateTime.parse(lastActiveString);
    final now = DateTime.now();
    final difference = now.difference(lastActive).inMinutes;
    
    return difference >= timeoutMinutes;
  }

  static Future<void> markAppActive() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastActiveKey, DateTime.now().toIso8601String());
    await prefs.setBool(_appWasTerminatedKey, false);
  }

  static Future<void> markAppTerminated() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_appWasTerminatedKey, true);
  }

  static Future<bool> wasAppTerminated() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_appWasTerminatedKey) ?? true;
  }
}