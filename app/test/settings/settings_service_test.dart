import 'package:flutter_test/flutter_test.dart';
import '../../lib/settings/settings.dart';

void main() {
  group('SettingsService', () {
    test('uses defaults when repository is empty', () async {
      final service = SettingsService(InMemorySettingsRepository());
      await service.load();
      expect(service.isLoaded, isTrue);
      expect(service.lastLoadError, isNull);
      expect(service.appPreferences.themeMode, AppThemeMode.system);
      expect(service.appPreferences.language, AppLanguage.arabic);
      expect(service.appPreferences.density, AppDensity.comfortable);
      expect(service.labelOverrides.values, isEmpty);
    });

    test('loads persisted snapshot', () async {
      final stored = SettingsSnapshot(
        schemaVersion: SettingsSnapshot.currentSchemaVersion,
        appPreferences: const AppPreferences(
          themeMode: AppThemeMode.dark,
          language: AppLanguage.english,
          density: AppDensity.compact,
        ),
        workspacePreferences: const WorkspacePreferences(rememberLastSection: false),
        labelOverrides: LabelOverrides.empty(),
      );
      final service = SettingsService(InMemorySettingsRepository(stored));
      await service.load();
      expect(service.appPreferences.themeMode, AppThemeMode.dark);
      expect(service.appPreferences.language, AppLanguage.english);
      expect(service.workspacePreferences.rememberLastSection, isFalse);
    });

    test('update persists to repository and survives reload', () async {
      final repo = InMemorySettingsRepository();
      final service = SettingsService(repo);
      await service.load();
      await service.updateAppPreferences(
        const AppPreferences(themeMode: AppThemeMode.dark),
      );
      final reloaded = SettingsService(repo);
      await reloaded.load();
      expect(reloaded.appPreferences.themeMode, AppThemeMode.dark);
    });

    test('resetToDefaults clears repository', () async {
      final repo = InMemorySettingsRepository();
      final service = SettingsService(repo);
      await service.load();
      await service.updateAppPreferences(
        const AppPreferences(themeMode: AppThemeMode.dark),
      );
      await service.resetToDefaults();
      expect(service.appPreferences.themeMode, AppThemeMode.system);
      expect(await repo.load(), isNull);
    });

    test('load failure falls back to defaults and records error', () async {
      final badRepo = _FailingRepo();
      final service = SettingsService(badRepo);
      await service.load();
      expect(service.lastLoadError, isNotNull);
      expect(service.appPreferences.themeMode, AppThemeMode.system);
      expect(service.isLoaded, isTrue);
    });

    test('notifies listeners on update', () async {
      final service = SettingsService(InMemorySettingsRepository());
      await service.load();
      var notified = 0;
      service.addListener(() => notified++);
      await service.updateAppPreferences(
        const AppPreferences(themeMode: AppThemeMode.dark),
      );
      expect(notified, greaterThanOrEqualTo(1));
    });
  });
}

class _FailingRepo implements SettingsRepository {
  @override
  Future<SettingsSnapshot?> load() async =>
      throw StateError('Unsupported settings schema version: 999 (expected 1)');
  @override
  Future<void> save(SettingsSnapshot snapshot) async {}
  @override
  Future<void> clear() async {}
}