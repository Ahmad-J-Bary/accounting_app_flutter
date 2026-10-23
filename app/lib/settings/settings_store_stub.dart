import 'settings_store.dart';

/// Web / unsupported-platform fallback: in-memory only.
Future<SettingsStore> createSettingsStore({String? profileId}) async =>
    InMemorySettingsStore();