import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:accounting_app_flutter/settings/settings_model.dart';

void main() {
  group('AppearanceSettings', () {
    test('defaults match owner decisions', () {
      const a = AppearanceSettings();
      expect(a.themeMode, ThemeMode.system);
      expect(a.density, AppDensity.compact);
      expect(a.fontScale, 1.0);
    });

    test('clamps fontScale below minimum', () {
      final a = AppearanceSettings.fromJson({'fontScale': 0.1});
      expect(a.fontScale, 0.8);
    });

    test('clamps fontScale above maximum', () {
      final a = AppearanceSettings.fromJson({'fontScale': 9.9});
      expect(a.fontScale, 1.5);
    });

    test('non-finite fontScale becomes 1.0', () {
      expect(AppearanceSettings.clampFontScale(double.nan), 1.0);
      expect(AppearanceSettings.clampFontScale(double.infinity), 1.0);
    });

    test('unknown themeMode falls back to system', () {
      final a = AppearanceSettings.fromJson({'themeMode': 'plaid'});
      expect(a.themeMode, ThemeMode.system);
    });

    test('unknown density falls back to compact', () {
      final a = AppearanceSettings.fromJson({'density': 'ultra'});
      expect(a.density, AppDensity.compact);
    });

    test('JSON round-trip equality', () {
      const a = AppearanceSettings(
        themeMode: ThemeMode.dark,
        density: AppDensity.spacious,
        fontScale: 1.2,
      );
      final restored = AppearanceSettings.fromJson(
        Map<String, dynamic>.from(a.toJson()),
      );
      expect(restored, a);
    });

    test('copyWith preserves unspecified fields', () {
      const a = AppearanceSettings(themeMode: ThemeMode.dark);
      final b = a.copyWith(fontScale: 1.3);
      expect(b.themeMode, ThemeMode.dark);
      expect(b.fontScale, 1.3);
    });
  });

  group('LocaleSettings', () {
    test('defaults are Arabic + western digits', () {
      const l = LocaleSettings();
      expect(l.language, AppLanguage.arabic);
      expect(l.digits, AppDigits.western);
    });

    test('JSON round-trip', () {
      const l = LocaleSettings(language: AppLanguage.english, digits: AppDigits.eastern);
      final restored = LocaleSettings.fromJson(
        Map<String, dynamic>.from(l.toJson()),
      );
      expect(restored, l);
    });
  });

  group('AppSettings', () {
    test('default has schemaVersion 1', () {
      expect(const AppSettings().schemaVersion, 1);
    });

    test('JSON round-trip preserves both blocks', () {
      const s = AppSettings(
        appearance: AppearanceSettings(themeMode: ThemeMode.dark),
        locale: LocaleSettings(language: AppLanguage.english),
      );
      final restored = AppSettings.fromJson(
        Map<String, dynamic>.from(s.toJson()),
      );
      expect(restored, s);
    });

    test('fromJson sanitizes nested appearance', () {
      final restored = AppSettings.fromJson({
        'appearance': {'fontScale': 9.9, 'density': 'invalid'},
      });
      expect(restored.appearance.fontScale, 1.5);
      expect(restored.appearance.density, AppDensity.compact);
    });
  });
}