import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:accounting_app_flutter/settings/settings_model.dart';
import 'package:accounting_app_flutter/settings/settings_store_io.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('settings_store_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  File settingsFile() =>
      File('${tempDir.path}${Platform.pathSeparator}settings.json');

  group('JsonFileSettingsStore', () {
    test('missing file returns null', () async {
      final store = JsonFileSettingsStore(settingsFile());
      expect(await store.load(), isNull);
    });

    test('save then load round-trips settings', () async {
      final store = JsonFileSettingsStore(settingsFile());
      const s = AppSettings(
        appearance: AppearanceSettings(
          themeMode: ThemeMode.dark,
          density: AppDensity.spacious,
          fontScale: 1.2,
        ),
        locale: LocaleSettings(language: AppLanguage.english),
      );
      await store.save(s);
      expect(await store.load(), s);
    });

    test('envelope version is written', () async {
      final store = JsonFileSettingsStore(settingsFile());
      await store.save(const AppSettings());
      final raw = await settingsFile().readAsString();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      expect(decoded['version'], 1);
      expect(decoded['settings'], isA<Map>());
    });

    test('corrupt file returns null, not throw', () async {
      final f = settingsFile();
      await f.parent.create(recursive: true);
      await f.writeAsString('{ not json');
      final store = JsonFileSettingsStore(f);
      expect(await store.load(), isNull);
    });

    test('unknown envelope version returns null', () async {
      final f = settingsFile();
      await f.parent.create(recursive: true);
      await f.writeAsString(jsonEncode({
        'version': 99,
        'settings': <String, dynamic>{},
      }));
      final store = JsonFileSettingsStore(f);
      expect(await store.load(), isNull);
    });

    test('no .tmp residue after save', () async {
      final store = JsonFileSettingsStore(settingsFile());
      await store.save(const AppSettings());
      final residue = File('${settingsFile().path}.tmp');
      expect(await residue.exists(), isFalse);
    });

    test('creates parent directory on save', () async {
      final nested = File(
        '${tempDir.path}${Platform.pathSeparator}a${Platform.pathSeparator}b'
        '${Platform.pathSeparator}settings.json',
      );
      final store = JsonFileSettingsStore(nested);
      await store.save(const AppSettings());
      expect(await nested.exists(), isTrue);
    });
  });
}