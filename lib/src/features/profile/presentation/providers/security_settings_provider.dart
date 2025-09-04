
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 1. Enum untuk Durasi Kunci Otomatis
enum AutoLockDuration {
  immediately,
  after1Minute,
  after5Minutes,
  after15Minutes,
  after1Hour,
  never,
}

// 2. State Notifier untuk Pengaturan Keamanan
class SecuritySettingsNotifier extends StateNotifier<SecuritySettingsState> {
  SecuritySettingsNotifier() : super(const SecuritySettingsState()) {
    _loadDuration();
  }

  static const String _durationKey = 'autoLockDuration';

  // Peta untuk mengonversi enum ke teks yang mudah dibaca
  final Map<AutoLockDuration, String> allDurations = {
    AutoLockDuration.immediately: 'Immediately',
    AutoLockDuration.after1Minute: 'After 1 minute',
    AutoLockDuration.after5Minutes: 'After 5 minutes',
    AutoLockDuration.after15Minutes: 'After 15 minutes',
    AutoLockDuration.after1Hour: 'After 1 hour',
    AutoLockDuration.never: 'Never',
  };

  Future<void> _loadDuration() async {
    state = state.copyWith(isLoading: true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedDuration = prefs.getString(_durationKey);
      final duration = AutoLockDuration.values.firstWhere(
        (e) => e.toString() == storedDuration,
        orElse: () => AutoLockDuration.after1Minute, // Nilai default
      );
      state = state.copyWith(
        selectedDuration: duration,
        durationText: allDurations[duration],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> updateDuration(AutoLockDuration newDuration) async {
    state = state.copyWith(isLoading: true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_durationKey, newDuration.toString());
      state = state.copyWith(
        selectedDuration: newDuration,
        durationText: allDurations[newDuration],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

// 3. State untuk Pengaturan Keamanan
class SecuritySettingsState {
  const SecuritySettingsState({
    this.selectedDuration = AutoLockDuration.after1Minute,
    this.durationText = 'After 1 minute',
    this.isLoading = false,
    this.error,
  });

  final AutoLockDuration selectedDuration;
  final String durationText;
  final bool isLoading;
  final String? error;

  SecuritySettingsState copyWith({
    AutoLockDuration? selectedDuration,
    String? durationText,
    bool? isLoading,
    String? error,
  }) {
    return SecuritySettingsState(
      selectedDuration: selectedDuration ?? this.selectedDuration,
      durationText: durationText ?? this.durationText,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

// 4. StateNotifierProvider Global
final securitySettingsProvider =
    StateNotifierProvider<SecuritySettingsNotifier, SecuritySettingsState>(
  (ref) => SecuritySettingsNotifier(),
);
