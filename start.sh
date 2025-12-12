    # =================================================================
# SCRIPT UNTUK MEMBUAT STRUKTUR FOLDER APLIKASI FLUTTER WALLET
# =================================================================

# Hapus file test bawaan yang tidak relevan untuk memulai
rm test/widget_test.dart

# Buat struktur folder utama di dalam lib/src dan folder assets
echo "Membuat direktori inti..."
mkdir -p lib/src/core lib/src/features assets/images assets/icons assets/fonts

# --- Membuat Struktur Folder `core` ---
echo "Membuat struktur folder 'core'..."
mkdir -p lib/src/core/config/router
mkdir -p lib/src/core/config/theme
mkdir -p lib/src/core/data/models
mkdir -p lib/src/core/shared_widgets
mkdir -p lib/src/core/utils

# --- Membuat file-file di dalam `core` ---
echo "Membuat file-file di dalam 'core'..."
touch lib/src/core/config/router/app_router.dart
touch lib/src/core/config/theme/app_colors.dart
touch lib/src/core/config/theme/app_theme.dart
touch lib/src/core/shared_widgets/custom_button.dart
touch lib/src/core/shared_widgets/loading_indicator.dart
touch lib/src/core/utils/constants.dart
touch lib/src/core/utils/formatters.dart
# Membuat file .gitkeep agar folder kosong tetap terlacak oleh Git
touch lib/src/core/data/models/.gitkeep

# --- Membuat Struktur Folder `features` ---
echo "Membuat struktur folder untuk setiap 'fitur'..."

# Fitur: Authentication
mkdir -p lib/src/features/authentication/presentation/screens
mkdir -p lib/src/features/authentication/presentation/widgets
mkdir -p lib/src/features/authentication/logic

# Fitur: Home
mkdir -p lib/src/features/home/presentation/screens
mkdir -p lib/src/features/home/presentation/widgets
mkdir -p lib/src/features/home/logic

# Fitur: Transaction
mkdir -p lib/src/features/transaction/presentation/screens
mkdir -p lib/src/features/transaction/presentation/widgets
mkdir -p lib/src/features/transaction/logic

# Fitur: Send Money
mkdir -p lib/src/features/send_money/presentation/screens
mkdir -p lib/src/features/send_money/presentation/widgets
mkdir -p lib/src/features/send_money/logic

# --- Membuat beberapa contoh file di dalam `features` ---
echo "Membuat beberapa contoh file di dalam 'fitur'..."
touch lib/src/features/authentication/presentation/screens/login_screen.dart
touch lib/src/features/authentication/logic/auth_controller.dart

touch lib/src/features/home/presentation/screens/home_screen.dart
touch lib/src/features/home/presentation/widgets/balance_card.dart
touch lib/src/features/home/logic/home_controller.dart

touch lib/src/features/transaction/presentation/screens/transaction_history_screen.dart
touch lib/src/features/transaction/presentation/widgets/transaction_list_item.dart
touch lib/src/features/transaction/logic/transaction_controller.dart

touch lib/src/features/send_money/presentation/screens/send_money_screen.dart
touch lib/src/features/send_money/logic/send_money_controller.dart

# Selesai!
echo ""
echo "✅ Struktur folder dan file berhasil dibuat!"
echo "Jangan lupa untuk mengedit 'pubspec.yaml' untuk mendaftarkan folder assets."