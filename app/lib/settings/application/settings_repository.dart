import '../contracts/app_preferences.dart';
import '../contracts/label_overrides.dart';
import '../contracts/workspace_preferences.dart';

/// A complete, versioned snapshot of persisted settings.
class SettingsSnapshot {
  final int schemaVersion;
  final AppPreferences appPreferences;
  final WorkspacePreferences workspacePreferences;
  final LabelOverrides labelOverrides;

  const SettingsSnapshot({
    required this.schemaVersion,
    required this.appPreferences,
    required this.workspacePreferences,
    required this.labelOverrides,
  });

  static const int currentSchemaVersion = 1;

  static SettingsSnapshot defaults() => SettingsSnapshot(
        schemaVersion: currentSchemaVersion,
        appPreferences: const AppPreferences(),
        workspacePreferences: const WorkspacePreferences(),
        labelOverrides: LabelOverrides.empty(),
      );

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'appPreferences': appPreferences.toJson(),
        'workspacePreferences': workspacePreferences.toJson(),
        'labelOverrides': labelOverrides.toJson(),
      };

  static SettingsSnapshot fromJson(Map<String, dynamic> json) {
    final version = json['schemaVersion'] as int? ?? 0;
    if (version != currentSchemaVersion) {
      throw StateError(
        'Unsupported settings schema version: $version '
        '(expected $currentSchemaVersion)',
      );
    }
    final app = json['appPreferences'];
    final ws = json['workspacePreferences'];
    final labels = json['labelOverrides'];
    return SettingsSnapshot(
      schemaVersion: version,
      appPreferences: app is Map
          ? AppPreferences.fromJson(Map<String, dynamic>.from(app))
          : const AppPreferences(),
      workspacePreferences: ws is Map
          ? WorkspacePreferences.fromJson(Map<String, dynamic>.from(ws))
          : const WorkspacePreferences(),
      labelOverrides: labels is Map
          ? LabelOverrides.fromJson(Map<String, dynamic>.from(labels))
          : LabelOverrides.empty(),
    );
  }
}

/// Persistence boundary. Implementations must not contain business policy.
abstract class SettingsRepository {
  Future<SettingsSnapshot?> load();
  Future<void> save(SettingsSnapshot snapshot);
  Future<void> clear();
}