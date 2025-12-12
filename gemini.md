# 📱 PROJECT CONTEXT REPORT

**Generated on:** 2025-12-10 17:44:45.525124

---

## 📋 Project Overview

- **Project Name:** qrypta
- **Description:** A new Flutter project.
- **Version:** 1.0.0+1
- **Flutter SDK:** ^3.7.0
- **Working Directory:** /home/ganendra/qrypta

---

## 📦 Dependencies Analysis

### Core Dependencies:

- `cupertino_icons`: ^1.0.8
- `pinput`: ^5.0.1
- `shared_preferences`: ^2.5.3
- `qr_flutter`: ^4.1.0
- `mobile_scanner`: ^7.0.1
- `share_plus`: ^11.0.0
- `web3dart`: ^2.7.1
- `flutter_secure_storage`: ^9.2.4
- `flutter_riverpod`: ^2.6.1
- `http`: ^1.4.0
- `convert`: ^3.1.2
- `crypto`: ^3.0.6
- `provider`: ^6.1.5
- `local_auth`: ^2.3.0

### Dev Dependencies:

- `flutter_lints`: ^6.0.0
- `yaml`: ^3.1.3

---

## 📊 Code Statistics

- **Total Dart files:** 78
- **Total lines of code:** 5653

### Components Breakdown:

- **Models:** 1 files
- **Screens:** 22 files
- **Pages:** 1 files
- **Services:** 8 files
- **Widgets:** 9 files
- **Controllers:** 3 files
- **Utils:** 2 files
- **Providers:** 5 files

---

## 📂 Project Structure

```
├── README.md
├── analysis_options.yaml
├── devtools_options.yaml
├── generate_context.dart
├── lib
│   ├── main.dart
│   ├── src
│   │   ├── core
│   │   │   ├── config
│   │   │   │   ├── blockchain_config.dart
│   │   │   │   ├── router
│   │   │   │   │   └── app_router.dart
│   │   │   │   └── theme
│   │   │   │       ├── app_colors.dart
│   │   │   │       └── app_theme.dart
│   │   │   ├── data
│   │   │   │   └── models
│   │   │   │       └── token_model.dart
│   │   │   ├── services
│   │   │   │   ├── authentication_service.dart
│   │   │   │   └── blockchain
│   │   │   │       ├── blockchain_service.dart
│   │   │   │       ├── erc20_service.dart
│   │   │   │       ├── native_currency_service.dart
│   │   │   │       ├── transaction_service.dart
│   │   │   │       └── wallet_service.dart
│   │   │   ├── shared_widgets
│   │   │   │   ├── custom_button.dart
│   │   │   │   └── loading_indicator.dart
│   │   │   └── utils
│   │   │       ├── constants.dart
│   │   │       └── formatters.dart
│   │   └── features
│   │       ├── authentication
│   │       │   ├── application
│   │       │   │   └── auth_service.dart
│   │       │   ├── data
│   │       │   │   ├── datasources
│   │       │   │   │   └── authentication_local_data_source.dart
│   │       │   │   └── repositories
│   │       │   │       └── authentication_repository_impl.dart
│   │       │   ├── domain
│   │       │   │   ├── repositories
│   │       │   │   │   └── authentication_repository.dart
│   │       │   │   └── usecases
│   │       │   │       ├── generate_mnemonic_usecase.dart
│   │       │   │       ├── get_pin_usecase.dart
│   │       │   │       ├── get_private_key_from_mnemonic_usecase.dart
│   │       │   │       ├── get_private_key_usecase.dart
│   │       │   │       ├── get_public_key_usecase.dart
│   │       │   │       ├── save_mnemonic_usecase.dart
│   │       │   │       ├── save_pin_usecase.dart
│   │       │   │       ├── save_private_key_usecase.dart
│   │       │   │       └── verify_pin_usecase.dart
│   │       │   └── presentation
│   │       │       ├── providers
│   │       │       │   ├── auth_providers.dart
│   │       │       │   ├── pin_provider.dart
│   │       │       │   └── wallet_provider.dart
│   │       │       └── screens
│   │       │           ├── auth_wrapper.dart
│   │       │           ├── login_screen.dart
│   │       │           ├── pin_verification_screen.dart
│   │       │           ├── signup_screen.dart
│   │       │           ├── wallet_setup_pin_confirmation_screen.dart
│   │       │           ├── wallet_setup_pin_screen.dart
│   │       │           ├── wallet_setup_screen.dart
│   │       │           ├── wallet_setup_seed_phrase_screen.dart
│   │       │           ├── wallet_setup_seed_verification_screen.dart
│   │       │           └── welcome_screen.dart
│   │       ├── blockchain
│   │       │   └── services
│   │       │       └── blockchain_service.dart
│   │       ├── home
│   │       │   ├── logic
│   │       │   │   └── home_controller.dart
│   │       │   └── presentation
│   │       │       ├── screens
│   │       │       │   └── home_screen_backup.dart
│   │       │       └── widgets
│   │       │           ├── action_buttons.dart
│   │       │           ├── balance_card.dart
│   │       │           └── home_body_widgets.dart
│   │       ├── profile
│   │       │   ├── application
│   │       │   │   └── security_settings_notifier.dart
│   │       │   └── presentation
│   │       │       ├── providers
│   │       │       │   └── security_settings_provider.dart
│   │       │       ├── screens
│   │       │       │   ├── change_pin_screen.dart
│   │       │       │   ├── profile_screen.dart
│   │       │       │   └── reveal_secret_screen.dart
│   │       │       └── widgets
│   │       │           ├── account_management_group.dart
│   │       │           ├── general_group.dart
│   │       │           ├── network_group.dart
│   │       │           └── security_group.dart
│   │       ├── qr_scanner
│   │       │   └── presentation
│   │       │       └── screens
│   │       │           └── qr_scanner_screen.dart
│   │       ├── send_money
│   │       │   ├── logic
│   │       │   │   └── send_money_controller.dart
│   │       │   └── presentation
│   │       │       └── screens
│   │       │           └── send_money_screen.dart
│   │       ├── testing
│   │       │   └── test_connection_page.dart
│   │       ├── tokens
│   │       │   ├── data
│   │       │   │   ├── datasources
│   │       │   │   │   ├── token_local_data_source.dart
│   │       │   │   │   └── token_local_data_source_impl.dart
│   │       │   │   └── repositories
│   │       │   │       └── token_repository_impl.dart
│   │       │   ├── domain
│   │       │   │   ├── repositories
│   │       │   │   │   └── token_repository.dart
│   │       │   │   └── usecases
│   │       │   │       ├── add_manual_custom_token.dart
│   │       │   │       ├── get_user_tokens.dart
│   │       │   │       └── remove_custom_token.dart
│   │       │   ├── presentation
│   │       │   │   ├── providers
│   │       │   │   │   └── token_provider.dart
│   │       │   │   ├── screens
│   │       │   │   │   ├── add_manual_token_screen.dart
│   │       │   │   │   └── manage_tokens_screen.dart
│   │       │   │   └── widgets
│   │       │   │       └── token_list_item.dart
│   │       │   └── readme.md
│   │       └── transaction
│   │           ├── logic
│   │           │   └── transaction_controller.dart
│   │           ├── presentation
│   │           │   ├── screens
│   │           │   │   ├── receive_screen.dart
│   │           │   │   ├── send_scanner_screen.dart
│   │           │   │   └── transaction_history_screen.dart
│   │           │   └── widgets
│   │           │       └── transaction_list_item.dart
│   │           └── screens
│   │               └── confirmation_page.dart
│   └── testing blockchain
│       ├── blockchain_service_testing.dart
│       ├── chain_service_testing.dart
│       └── client_provider_testing.dart
├── main.txt
├── pubspec.lock
├── pubspec.yaml
├── start.sh
```

## 🎯 Key Components

### Models (1 files)

- `lib/src/core/data/models/token_model.dart`

### Screens (22 files)

- `lib/src/features/home/presentation/screens/home_screen_backup.dart`
- `lib/src/features/qr_scanner/presentation/screens/qr_scanner_screen.dart`
- `lib/src/features/profile/presentation/screens/profile_screen.dart`
- `lib/src/features/profile/presentation/screens/change_pin_screen.dart`
- `lib/src/features/profile/presentation/screens/reveal_secret_screen.dart`
- `lib/src/features/send_money/presentation/screens/send_money_screen.dart`
- `lib/src/features/transaction/presentation/screens/transaction_history_screen.dart`
- `lib/src/features/transaction/presentation/screens/send_scanner_screen.dart`
- `lib/src/features/transaction/presentation/screens/receive_screen.dart`
- `lib/src/features/transaction/screens/confirmation_page.dart`

### Pages (1 files)

- `lib/src/features/transaction/screens/confirmation_page.dart`

### Services (8 files)

- `lib/src/core/services/blockchain/wallet_service.dart`
- `lib/src/core/services/blockchain/erc20_service.dart`
- `lib/src/core/services/blockchain/transaction_service.dart`
- `lib/src/core/services/blockchain/blockchain_service.dart`
- `lib/src/core/services/blockchain/native_currency_service.dart`
- `lib/src/core/services/authentication_service.dart`
- `lib/src/features/blockchain/services/blockchain_service.dart`
- `lib/src/features/authentication/application/auth_service.dart`

### Widgets (9 files)

- `lib/src/features/home/presentation/widgets/home_body_widgets.dart`
- `lib/src/features/home/presentation/widgets/balance_card.dart`
- `lib/src/features/home/presentation/widgets/action_buttons.dart`
- `lib/src/features/profile/presentation/widgets/network_group.dart`
- `lib/src/features/profile/presentation/widgets/account_management_group.dart`
- `lib/src/features/profile/presentation/widgets/security_group.dart`
- `lib/src/features/profile/presentation/widgets/general_group.dart`
- `lib/src/features/transaction/presentation/widgets/transaction_list_item.dart`
- `lib/src/features/tokens/presentation/widgets/token_list_item.dart`

### Controllers (3 files)

- `lib/src/features/home/logic/home_controller.dart`
- `lib/src/features/send_money/logic/send_money_controller.dart`
- `lib/src/features/transaction/logic/transaction_controller.dart`

### Utils (2 files)

- `lib/src/core/utils/formatters.dart`
- `lib/src/core/utils/constants.dart`

### Providers (5 files)

- `lib/src/features/profile/presentation/providers/security_settings_provider.dart`
- `lib/src/features/authentication/presentation/providers/pin_provider.dart`
- `lib/src/features/authentication/presentation/providers/wallet_provider.dart`
- `lib/src/features/authentication/presentation/providers/auth_providers.dart`
- `lib/src/features/tokens/presentation/providers/token_provider.dart`

---

## 🛣️ App Navigation

*No dedicated routes file found. Routes may be defined in main.dart*

---

## 🔧 State Management

**Detected:** Provider, Riverpod, Riverpod

---

## 🔧 Configuration Files

### 📄 File: `pubspec.yaml` (34 lines)

```yaml
name: qrypta
description: "A new Flutter project."
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: ^3.7.0

dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  pinput: ^5.0.1
  shared_preferences: ^2.5.3
  qr_flutter: ^4.1.0
  mobile_scanner: ^7.0.1
  share_plus: ^11.0.0
  web3dart: ^2.7.1
  flutter_secure_storage: ^9.2.4
  flutter_riverpod: ^2.6.1
  http: ^1.4.0
  convert: ^3.1.2
  crypto: ^3.0.6
  provider: ^6.1.5
  local_auth: ^2.3.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  yaml: ^3.1.3

flutter:
  uses-material-design: true
  assets:
    - assets/images/
    - assets/icons/
    - assets/fonts/
```

### 📄 File: `analysis_options.yaml` (25 lines)

```yaml
# This file configures the analyzer, which statically analyzes Dart code to
# check for errors, warnings, and lints.
#
# The issues identified by the analyzer are surfaced in the UI of Dart-enabled
# IDEs (https://dart.dev/tools#ides-and-editors). The analyzer can also be
# invoked from the command line by running `flutter analyze`.

# The following line activates a set of recommended lints for Flutter apps,
# packages, and plugins designed to encourage good coding practices.
include: package:flutter_lints/flutter.yaml

linter:
  # The lint rules applied to this project can be customized in the
  # section below to disable rules from the `package:flutter_lints/flutter.yaml`
  # included above or to enable additional rules. A list of all available lints
  # and their documentation is published at https://dart.dev/lints.
  #
  # Instead of disabling a lint rule for the entire project in the
  # section below, it can also be suppressed for a single line of code
  # or a specific dart file by using the `// ignore: name_of_lint` and
  # `// ignore_for_file: name_of_lint` syntax on the line or in the file
  # producing the lint.
  rules:
    # avoid_print: false  # Uncomment to disable the `avoid_print` rule
    # prefer_single_quotes: true  # Uncomment to enable the `prefer_single_quotes` rule

# Additional information about this file can be found at
# https://dart.dev/guides/language/analysis-options

```

## 🔑 Critical Files Content

### 📄 File: `lib/main.dart` (135 lines)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Ganti dengan path file Anda yang sebenarnya
import 'package:qrypta/src/core/config/theme/app_theme.dart';
import 'package:qrypta/src/features/authentication/presentation/providers/auth_providers.dart';
import 'package:qrypta/src/features/authentication/presentation/screens/auth_wrapper.dart';
import 'package:qrypta/src/features/authentication/presentation/screens/pin_verification_screen.dart';
import 'package:qrypta/src/features/home/presentation/screens/home_screen_backup.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: MyApp()));
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

```
