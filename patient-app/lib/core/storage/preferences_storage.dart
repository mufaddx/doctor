import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Non-sensitive user preferences. Anything secret belongs in TokenStorage.
class PreferencesStorage {
  PreferencesStorage(this._prefs);

  final SharedPreferences _prefs;

  static const String _themeKey = 'theme_mode';
  static const String _onboardedKey = 'has_onboarded';

  ThemeMode readThemeMode() {
    final String? stored = _prefs.getString(_themeKey);
    return switch (stored) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> saveThemeMode(ThemeMode mode) =>
      _prefs.setString(_themeKey, mode.name);

  bool hasCompletedOnboarding() => _prefs.getBool(_onboardedKey) ?? false;

  Future<void> setOnboardingComplete() => _prefs.setBool(_onboardedKey, true);
}

/// Overridden in main() once SharedPreferences has been initialised.
final preferencesStorageProvider = Provider<PreferencesStorage>((ref) {
  throw UnimplementedError('preferencesStorageProvider must be overridden');
});

/// Drives MaterialApp.themeMode and persists the user's choice.
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier(this._storage) : super(_storage.readThemeMode());

  final PreferencesStorage _storage;

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await _storage.saveThemeMode(mode);
  }

  Future<void> toggleDarkMode(bool enabled) =>
      setMode(enabled ? ThemeMode.dark : ThemeMode.light);
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier(ref.watch(preferencesStorageProvider));
});
