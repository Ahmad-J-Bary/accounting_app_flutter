import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:accounting_app_flutter/settings/settings_model.dart';

void main() {
  group('AppearanceSettings v2 defaults', () {
    test('all defaults match the approved schema', () {
      const a = AppearanceSettings();
      expect(a.themeMode, ThemeMode.system);
      expect(a.density, AppDensity.compact);
      expect(a.fontScale, 1.0);
      expect(a.theme, 'system');
      expect(a.primaryColor, 'blue');
      expect(a.uiScale, 'default');
      expect(a.motion, 'standard');
      expect(a.show['sidebar'], true);
      expect(a.show['topBar'], true);
      expect(a.show['search'], true);
      expect(a.show['notifications'], true);
      expect(a.show['breadcrumbs'], true);
      expect(a.show['tabs'], true);
    });

    test('fontScale clamps at both ends and non-finite values', () {
      expect(AppearanceSettings.clampFontScale(0.1), 0.8);
      expect(AppearanceSettings.clampFontScale(9.9), 1.5);
      expect(AppearanceSettings.clampFontScale(double.nan), 1.0);
      expect(AppearanceSettings.clampFontScale(double.infinity), 1.0);
    });
  });

  group('AppearanceSettings sanitization (v2 fields)', () {
    test('invalid theme falls back to system', () {
      final a = AppearanceSettings.fromJson({'theme': 'not-a-theme'});
      expect(a.theme, 'system');
    });

    test('valid theme is preserved', () {
      final a = AppearanceSettings.fromJson({'theme': 'midnight'});
      expect(a.theme, 'midnight');
    });

    test('invalid primaryColor falls back to blue', () {
      final a = AppearanceSettings.fromJson({'primaryColor': 'neon'});
      expect(a.primaryColor, 'blue');
    });

    test('valid primaryColor is preserved', () {
      final a = AppearanceSettings.fromJson({'primaryColor': 'emerald'});
      expect(a.primaryColor, 'emerald');
    });

    test('invalid uiScale falls back to default', () {
      final a = AppearanceSettings.fromJson({'uiScale': 'huge'});
      expect(a.uiScale, 'default');
    });

    test('invalid motion falls back to standard', () {
      final a = AppearanceSettings.fromJson({'motion': 'ultra'});
      expect(a.motion, 'standard');
    });

    test('partial show map is completed with defaults', () {
      final a = AppearanceSettings.fromJson({
        'show': {'sidebar': false, 'topBar': false},
      });
      expect(a.show['sidebar'], false);
      expect(a.show['topBar'], false);
      expect(a.show['search'], true);
      expect(a.show['notifications'], true);
      expect(a.show['breadcrumbs'], true);
      expect(a.show['tabs'], true);
    });

    test('non-bool show values are ignored, defaults apply', () {
      final a = AppearanceSettings.fromJson({
        'show': {'sidebar': 'yes', 'topBar': 1, 'search': null},
      });
      expect(a.show['sidebar'], true);
      expect(a.show['topBar'], true);
      expect(a.show['search'], true);
    });

    test('unknown show keys are dropped', () {
      final a = AppearanceSettings.fromJson({
        'show': {'sidebar': false, 'unknown': true},
      });
      expect(a.show.containsKey('unknown'), isFalse);
      expect(a.show['sidebar'], false);
    });
  });

  group('AppearanceSettings JSON roundtrip (v2)', () {
    test('all v2 fields survive roundtrip', () {
      const original = AppearanceSettings(
        themeMode: ThemeMode.dark,
        density: AppDensity.spacious,
        fontScale: 1.25,
        theme: 'midnight',
        primaryColor: 'emerald',
        uiScale: 'large',
        motion: 'high',
        show: {
          'sidebar': false,
          'topBar': true,
          'search': false,
          'notifications': true,
          'breadcrumbs': false,
          'tabs': true,
        },
      );
      final restored = AppearanceSettings.fromJson(
        Map<String, dynamic>.from(original.toJson()),
      );
      expect(restored, original);
    });
  });

  group('AppSettings schema v2', () {
    test('currentSchemaVersion is 2 and default uses it', () {
      expect(AppSettings.currentSchemaVersion, 2);
      expect(const AppSettings().schemaVersion, 2);
    });

    test('v1 payload upgrades to v2 preserving old fields', () {
      final v1 = {
        'schemaVersion': 1,
        'appearance': {
          'themeMode': 'dark',
          'density': 'comfortable',
          'fontScale': 1.1,
        },
        'locale': {
          'language': 'english',
          'digits': 'eastern',
        },
      };
      final s = AppSettings.fromJson(v1);
      expect(s.schemaVersion, 2);
      expect(s.appearance.themeMode, ThemeMode.dark);
      expect(s.appearance.density, AppDensity.comfortable);
      expect(s.appearance.fontScale, 1.1);
      expect(s.locale.language, AppLanguage.english);
      expect(s.locale.digits, AppDigits.eastern);
      // v2 fields defaulted
      expect(s.appearance.theme, 'system');
      expect(s.appearance.primaryColor, 'blue');
      expect(s.appearance.uiScale, 'default');
      expect(s.appearance.motion, 'standard');
      expect(s.appearance.show['sidebar'], true);
      expect(s.appearance.show['tabs'], true);
    });

    test('payload missing schemaVersion is treated as v0 -> v2', () {
      final v0 = {
        'appearance': {'themeMode': 'light'},
        'locale': {'language': 'arabic'},
      };
      final s = AppSettings.fromJson(v0);
      expect(s.schemaVersion, 2);
      expect(s.appearance.themeMode, ThemeMode.light);
      expect(s.appearance.theme, 'system');
    });

    test('future schema version throws (no silent corruption)', () {
      final future = {
        'schemaVersion': 99,
        'appearance': <String, dynamic>{},
        'locale': <String, dynamic>{},
      };
      expect(() => AppSettings.fromJson(future), throwsStateError);
    });

    test('v2 full roundtrip preserves everything', () {
      const original = AppSettings(
        appearance: AppearanceSettings(
          themeMode: ThemeMode.dark,
          density: AppDensity.spacious,
          fontScale: 1.3,
          theme: 'dracula',
          primaryColor: 'violet',
          uiScale: 'large',
          motion: 'none',
          show: {
            'sidebar': false,
            'topBar': true,
            'search': true,
            'notifications': false,
            'breadcrumbs': true,
            'tabs': false,
          },
        ),
        locale: LocaleSettings(
          language: AppLanguage.english,
          digits: AppDigits.eastern,
        ),
      );
      final asJson = Map<String, dynamic>.from(original.toJson());
      jsonEncode(asJson); // serializable
      final restored = AppSettings.fromJson(asJson);
      expect(restored, original);
    });
  });

  group('LocaleSettings (unchanged)', () {
    test('defaults to arabic + western', () {
      const l = LocaleSettings();
      expect(l.language, AppLanguage.arabic);
      expect(l.digits, AppDigits.western);
    });

    test('JSON roundtrip', () {
      const l = LocaleSettings(
        language: AppLanguage.english,
        digits: AppDigits.eastern,
      );
      final restored = LocaleSettings.fromJson(
        Map<String, dynamic>.from(l.toJson()),
      );
      expect(restored, l);
    });
  });
}