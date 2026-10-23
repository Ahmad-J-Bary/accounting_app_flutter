import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'settings_model.dart';
import 'settings_store.dart';

class JsonFileSettingsStore implements SettingsStore {
  JsonFileSettingsStore(this.file);

  final File file;

  static const int _envelopeVersion = 1;

  @override
  Future<AppSettings?> load() async {
    try {
      if (!await file.exists()) return null;
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final map = Map<String, dynamic>.from(decoded);
      final version = map['version'] as int? ?? 0;
      if (version != _envelopeVersion) {
        // Migration chain hook. v1 has no prior versions.
        return null;
      }
      final payload = map['settings'];
      if (payload is! Map) return null;
      return AppSettings.fromJson(Map<String, dynamic>.from(payload));
    } catch (_) {
      // Corrupt file, IO failure, or unexpected shape → defaults, never throw.
      return null;
    }
  }

  @override
  Future<void> save(AppSettings settings) async {
    final envelope = <String, dynamic>{
      'version': _envelopeVersion,
      'settings': settings.toJson(),
    };
    final dir = file.parent;
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(envelope), flush: true);
    await tmp.rename(file.path);
  }
}

/// Creates an IO-backed store under
/// `<appSupport>/settings/profiles/<profileId>/settings.json`.
/// profileId defaults to 'default' until login ships.
Future<SettingsStore> createSettingsStore({String? profileId}) async {
  final base = await getApplicationSupportDirectory();
  final profile = profileId ?? 'default';
  final file = File(
    '${base.path}${Platform.pathSeparator}settings${Platform.pathSeparator}'
    'profiles${Platform.pathSeparator}$profile${Platform.pathSeparator}'
    'settings.json',
  );
  return JsonFileSettingsStore(file);
}