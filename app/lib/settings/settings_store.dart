import 'settings_model.dart';

abstract class SettingsStore {
  Future<AppSettings?> load();
  Future<void> save(AppSettings settings);
}

/// In-memory implementation. Used by tests and as a fallback for web.
class InMemorySettingsStore implements SettingsStore {
  AppSettings? _stored;

  InMemorySettingsStore([AppSettings? initial]) : _stored = initial;

  @override
  Future<AppSettings?> load() async => _stored;

  @override
  Future<void> save(AppSettings settings) async {
    _stored = settings;
  }
}