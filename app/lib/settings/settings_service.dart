import 'package:flutter/material.dart';

import 'settings_model.dart';
import 'settings_store.dart';

/// Single source of truth for user-tier settings.
/// Load once at startup, then read/update through this service.
class SettingsService extends ChangeNotifier {
  SettingsService(this._store);

  final SettingsStore _store;
  AppSettings _settings = const AppSettings();
  bool _loaded = false;
  Object? _lastError;

  AppSettings get settings => _settings;
  AppearanceSettings get appearance => _settings.appearance;
  LocaleSettings get locale => _settings.locale;
  bool get isLoaded => _loaded;
  Object? get lastError => _lastError;

  Future<void> load() async {
    _lastError = null;
    try {
      final stored = await _store.load();
      _settings = stored ?? const AppSettings();
    } catch (e) {
      _settings = const AppSettings();
      _lastError = e;
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> updateAppearance(AppearanceSettings a) async {
    _settings =
        _settings.copyWith(appearance: AppearanceSettings.sanitize(a));
    notifyListeners();
    await _persistSafely();
  }

  Future<void> updateLocale(LocaleSettings l) async {
    _settings = _settings.copyWith(locale: l);
    notifyListeners();
    await _persistSafely();
  }

  Future<void> setThemeMode(ThemeMode m) =>
      updateAppearance(_settings.appearance.copyWith(themeMode: m));

  Future<void> cycleThemeMode() {
    final next = switch (_settings.appearance.themeMode) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    };
    return setThemeMode(next);
  }

  Future<void> setDensity(AppDensity d) =>
      updateAppearance(_settings.appearance.copyWith(density: d));

  Future<void> setFontScale(double s) =>
      updateAppearance(_settings.appearance.copyWith(fontScale: s));

  Future<void> reset() async {
    _settings = const AppSettings();
    notifyListeners();
    await _persistSafely();
  }

  Future<void> _persistSafely() async {
    try {
      await _store.save(_settings);
    } catch (e) {
      _lastError = e;
      // Settings are a convenience; never break the app for a write failure.
      debugPrint('SettingsService: failed to persist: $e');
    }
  }
}