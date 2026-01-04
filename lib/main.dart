import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- IMPORTS FILE KAMU ---
import 'package:qrypta/src/core/config/theme/app_theme.dart';
import 'package:qrypta/src/features/authentication/presentation/providers/auth_providers.dart';
import 'package:qrypta/src/features/authentication/presentation/screens/auth_wrapper.dart';
import 'package:qrypta/src/features/authentication/presentation/screens/pin_verification_screen.dart';
import 'package:qrypta/src/features/home/presentation/screens/home_screen_backup.dart';

// Import the canonical graphqlClientProvider
import 'package:qrypta/src/core/graphql/graphql_provider.dart'
    as app_graphql_provider;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Hive and open the box.
  // The HiveStore from graphql_flutter defaults to using a box named 'graphql'.
  await Hive.initFlutter();
  final box = await Hive.openBox('graphql');

  // 2. Manually create the GraphQLClient instance AFTER Hive is ready.
  // This uses the same logic as your graphql_provider.dart but at the correct time.
  final HttpLink httpLink = HttpLink('https://api.qrypta.id/graphql');
  final store = HiveStore(box); // This will find the 'graphql' box opened above.
  final cache = GraphQLCache(store: store);
  final qlClient = GraphQLClient(link: httpLink, cache: cache);

  final sharedPrefs = await SharedPreferences.getInstance();

  // 3. Setup Provider Container, OVERRIDING the graphqlClientProvider
  //    to return the instance we just safely created.
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sharedPrefs),
      // Any part of the app asking for graphqlClientProvider will now get our `qlClient` instance.
      app_graphql_provider.graphqlClientProvider.overrideWithValue(qlClient),
    ],
  );

  // 4. Run the App. We pass the container to the UncontrolledProviderScope.
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
