import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// --- IMPORTS FILE KAMU ---
import 'package:qrypta/src/core/config/theme/app_theme.dart';
import 'package:qrypta/src/features/authentication/presentation/providers/auth_providers.dart';
import 'package:qrypta/src/features/authentication/presentation/screens/auth_wrapper.dart';
import 'package:qrypta/src/features/authentication/presentation/screens/pin_verification_screen.dart';
import 'package:qrypta/src/features/home/presentation/screens/home_screen.dart';

// Import the canonical graphqlClientProvider
import 'package:qrypta/src/core/graphql/graphql_provider.dart'
    as app_graphql_provider;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize dotenv
  await dotenv.load(fileName: ".env");

  // Initialize Hive and open the default box for graphql_flutter.
  await Hive.initFlutter();
  await Hive.openBox('graphqlClientStore');

  final sharedPrefs = await SharedPreferences.getInstance();

  // The container will now create the GraphQL client using its provider.
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sharedPrefs),
    ],
  );

  // Read the client from the provider to pass it to the GraphQLProvider widget.
  final qlClient = container.read(app_graphql_provider.graphqlClientProvider);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: GraphQLProvider(
        client: ValueNotifier(qlClient),
        child: const MyApp(),
      ),
    ),
  );
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
      home: const Initializer(),
    );
  }
}

// 2. Layar Inisialisasi
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
    try {
      // Cek status login
      await ref.read(authStateProvider.future);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const AppLockWrapper()),
        );
      }
    } catch (e) {
      debugPrint("Error during initialization: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black, // Biar tidak putih silau saat loading
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

// 3. Wrapper Utama (App Lock Logic)
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
    // Kunci aplikasi jika user keluar atau minimize app
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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final isLocked = ref.watch(appLockProvider);

    return authState.when(
      data: (hasWallet) {
        if (!hasWallet) {
          return const AuthWrapper();
        }

        if (isLocked) {
          return PinVerificationScreen(
            title: 'Enter PIN',
            subtitle: 'Unlock Qrypta Wallet',
            onVerificationSuccess: _handleUnlock,
            // Callback error simpel
            onVerificationFailed: (attempts) {
              debugPrint("Gagal unlock. Percobaan: $attempts");
            },
          );
        } else {
          return const HomeScreen();
        }
      },
      loading:
          () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
    );
  }
}

// 4. Provider AppLock
final appLockProvider = StateNotifierProvider<AppLockNotifier, bool>((ref) {
  return AppLockNotifier();
});

class AppLockNotifier extends StateNotifier<bool> {
  AppLockNotifier() : super(true); // Default terkunci

  void lock() => state = true;
  void unlock() => state = false;
}
