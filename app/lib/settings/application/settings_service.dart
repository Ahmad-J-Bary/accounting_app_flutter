import 'package:flutter/foundation.dart';

import '../contracts/app_preferences.dart';
import '../contracts/label_overrides.dart';
import '../contracts/workspace_preferences.dart';
import 'settings_repository.dart';

/// Central orchestrator. Loads defaults + persisted snapshot, merges, validates,
/// and notifies listeners. Owns precedence: defaults < persisted snapshot.
class SettingsService extends ChangeNotifier {
  final SettingsRepository _repository;
  SettingsSnapshot _snapshot = SettingsSnapshot.defaults();
  bool _loaded = false;
  Object? _lastLoadError;

  SettingsService(this._repository);

  bool get isLoaded => _loaded;
  Object? get lastLoadError => _lastLoadError;

  AppPreferences get appPreferences => _snapshot.appPreferences;
  WorkspacePreferences get workspacePreferences => _snapshot.workspacePreferences;
  LabelOverrides get labelOverrides => _snapshot.labelOverrides;

  Future<void> load() async {
    _lastLoadError = null;
    try {
      final stored = await _repository.load();
      _snapshot = stored ?? SettingsSnapshot.defaults();
    } catch (e) {
      _snapshot = SettingsSnapshot.defaults();
      _lastLoadError = e;
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> updateAppPreferences(AppPreferences prefs) async {
    _snapshot = SettingsSnapshot(
      schemaVersion: _snapshot.schemaVersion,
      appPreferences: prefs,
      workspacePreferences: _snapshot.workspacePreferences,
      labelOverrides: _snapshot.labelOverrides,
    );
    await _repository.save(_snapshot);
    notifyListeners();
  }

  Future<void> updateWorkspacePreferences(WorkspacePreferences prefs) async {
    _snapshot = SettingsSnapshot(
      schemaVersion: _snapshot.schemaVersion,
      appPreferences: _snapshot.appPreferences,
      workspacePreferences: prefs,
      labelOverrides: _snapshot.labelOverrides,
    );
    await _repository.save(_snapshot);
    notifyListeners();
  }

  /// [overrides] is already validated at construction time.
  Future<void> updateLabelOverrides(LabelOverrides overrides) async {
    _snapshot = SettingsSnapshot(
      schemaVersion: _snapshot.schemaVersion,
      appPreferences: _snapshot.appPreferences,
      workspacePreferences: _snapshot.workspacePreferences,
      labelOverrides: overrides,
    );
    await _repository.save(_snapshot);
    notifyListeners();
  }

  Future<void> resetToDefaults() async {
    _snapshot = SettingsSnapshot.defaults();
    await _repository.clear();
    notifyListeners();
  }
}