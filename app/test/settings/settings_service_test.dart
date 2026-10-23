import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:accounting_app_flutter/settings/settings_model.dart';
import 'package:accounting_app_flutter/settings/settings_service.dart';
import 'package:accounting_app_flutter/settings/settings_store.dart';

class _FailingStore implements SettingsStore {
  @override
  Future<AppSettings?> load() async => throw StateError('boom');
  @override
  Future<void> save(AppSettings settings) async => throw StateError('boom');
}

void main() {
  group('SettingsService.load', () {
    test('uses defaults when store returns null', () async {
      final s = SettingsService(InMemorySettingsStore());
      await s.load();
      expect(s.isLoaded, isTrue);
      expect(s.lastError, isNull);
      expect(s.appearance.themeMode, ThemeMode.system);
      expect(s.appearance.density, AppDensity.compact);
      expect(s.locale.language, AppLanguage.arabic);
    });

    test('loads stored snapshot', () async {
      final stored = AppSettings(
        appearance: const AppearanceSettings(themeMode: ThemeMode.dark),
      );
      final s = SettingsService(InMemorySettingsStore(stored));
      await s.load();
      expect(s.appearance.themeMode, ThemeMode.dark);
    });

    test('failing store falls back to defaults and records error', () async {
      final s = SettingsService(_FailingStore());
      await s.load();
      expect(s.isLoaded, isTrue);
      expect(s.lastError, isNotNull);
      expect(s.appearance.themeMode, ThemeMode.system);
    });
  });

  group('SettingsService updates', () {
    test('setThemeMode persists and notifies', () async {
      final store = InMemorySettingsStore();
      final s = SettingsService(store);
      await s.load();
      var notified = 0;
      s.addListener(() => notified++);
      await s.setThemeMode(ThemeMode.dark);
      expect(s.appearance.themeMode, ThemeMode.dark);
      expect(notified, greaterThanOrEqualTo(1));
      final reloaded = SettingsService(store);
      await reloaded.load();
      expect(reloaded.appearance.themeMode, ThemeMode.dark);
    });

    test('cycleThemeMode cycles system → light → dark → system', () async {
      final s = SettingsService(InMemorySettingsStore());
      await s.load();
      expect(s.appearance.themeMode, ThemeMode.system);
      await s.cycleThemeMode();
      expect(s.appearance.themeMode, ThemeMode.light);
      await s.cycleThemeMode();
      expect(s.appearance.themeMode, ThemeMode.dark);
      await s.cycleThemeMode();
      expect(s.appearance.themeMode, ThemeMode.system);
    });

    test('setFontScale clamps on update', () async {
      final s = SettingsService(InMemorySettingsStore());
      await s.load();
      await s.setFontScale(9.9);
      expect(s.appearance.fontScale, 1.5);
      await s.setFontScale(0.1);
      expect(s.appearance.fontScale, 0.8);
    });

    test('setDensity persists', () async {
      final store = InMemorySettingsStore();
      final s = SettingsService(store);
      await s.load();
      await s.setDensity(AppDensity.spacious);
      final reloaded = SettingsService(store);
      await reloaded.load();
      expect(reloaded.appearance.density, AppDensity.spacious);
    });

    test('updateLocale persists', () async {
      final store = InMemorySettingsStore();
      final s = SettingsService(store);
      await s.load();
      await s.updateLocale(
        const LocaleSettings(language: AppLanguage.english),
      );
      final reloaded = SettingsService(store);
      await reloaded.load();
      expect(reloaded.locale.language, AppLanguage.english);
    });

    test('failing save never throws, records error', () async {
      final s = SettingsService(_FailingStore());
      // load fails → defaults
      await s.load();
      // subsequent save also fails but must not throw
      await s.setThemeMode(ThemeMode.dark);
      expect(s.appearance.themeMode, ThemeMode.dark);
      expect(s.lastError, isNotNull);
    });

    test('reset returns to defaults', () async {
      final store = InMemorySettingsStore();
      final s = SettingsService(store);
      await s.load();
      await s.setThemeMode(ThemeMode.dark);
      await s.reset();
      expect(s.appearance.themeMode, ThemeMode.system);
      final reloaded = SettingsService(store);
      await reloaded.load();
      expect(reloaded.appearance.themeMode, ThemeMode.system);
    });
  });
}