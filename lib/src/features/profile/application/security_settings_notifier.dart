import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AutoLockDuration { immediate, oneMinute, fiveMinutes, never }

class SecuritySettingsNotifier extends ChangeNotifier {
  static const _autoLockKey = 'autoLockDuration';

  AutoLockDuration _duration = AutoLockDuration.oneMinute; // Default value
  bool _isLoading = true;

  AutoLockDuration get duration => _duration;
  bool get isLoading => _isLoading;

  SecuritySettingsNotifier() {
    loadSettings();
  }

  String get durationText => _textFor(_duration);

  String _textFor(AutoLockDuration duration) {
    switch (duration) {
      case AutoLockDuration.immediate:
        return 'Immediate';
      case AutoLockDuration.oneMinute:
        return '1 minute';
      case AutoLockDuration.fiveMinutes:
        return '5 minutes';
      case AutoLockDuration.never:
        return 'Never';
    }
  }

  List<MapEntry<AutoLockDuration, String>> get allDurations {
    return AutoLockDuration.values
        .map((d) => MapEntry(d, _textFor(d)))
        .toList();
  }

  Future<void> loadSettings() async {
    _isLoading = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final savedIndex = prefs.getInt(_autoLockKey) ?? AutoLockDuration.oneMinute.index;
    _duration = AutoLockDuration.values[savedIndex];
    _isLoading = false;
    notifyListeners();
  }

  Future<void> updateDuration(AutoLockDuration newDuration) async {
    if (_duration == newDuration) return;

    _duration = newDuration;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_autoLockKey, newDuration.index);
  }
}