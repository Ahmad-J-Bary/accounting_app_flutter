import '../application/settings_repository.dart';

/// In-memory implementation. Used for tests and as a safe default before
/// persistence dependency is wired in a follow-up unit (B1-b).
class InMemorySettingsRepository implements SettingsRepository {
  SettingsSnapshot? _stored;

  InMemorySettingsRepository([SettingsSnapshot? initial]) : _stored = initial;

  @override
  Future<SettingsSnapshot?> load() async => _stored;

  @override
  Future<void> save(SettingsSnapshot snapshot) async {
    _stored = snapshot;
  }

  @override
  Future<void> clear() async {
    _stored = null;
  }
}