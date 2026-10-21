import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'table_preferences.dart';

/// File-backed table preferences.
///
/// The whole document is kept in memory after the first read. A corrupt or
/// unreadable file is treated as "no preferences" and never blocks the UI.
class JsonFileTablePreferencesStore implements TablePreferencesStore {
  JsonFileTablePreferencesStore({this.fileName = 'table_preferences.json'});

  final String fileName;
  Map<String, Object?>? _cache;
  Future<File>? _fileFuture;

  Future<File> _file() {
    return _fileFuture ??= () async {
      final directory = await getApplicationSupportDirectory();
      await directory.create(recursive: true);
      return File('${directory.path}${Platform.pathSeparator}$fileName');
    }();
  }

  Future<Map<String, Object?>> _read() async {
    final cached = _cache;
    if (cached != null) {
      return cached;
    }
    try {
      final file = await _file();
      if (!await file.exists()) {
        return _cache = <String, Object?>{};
      }
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, Object?>) {
        final tables = decoded['tables'];
        return _cache = tables is Map<String, Object?>
            ? Map<String, Object?>.from(tables)
            : <String, Object?>{};
      }
    } catch (error) {
      debugPrint('تعذّر قراءة تفضيلات الجداول: $error');
    }
    return _cache = <String, Object?>{};
  }

  Future<void> _write(Map<String, Object?> tables) async {
    final file = await _file();
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      jsonEncode(<String, Object?>{'version': 1, 'tables': tables}),
      flush: true,
    );
    await temporary.rename(file.path);
  }

  @override
  Future<Map<String, Object?>?> load(String tableId) async {
    final tables = await _read();
    final value = tables[tableId];
    return value is Map<String, Object?> ? value : null;
  }

  @override
  Future<void> save(String tableId, Map<String, Object?> value) async {
    final tables = Map<String, Object?>.from(await _read());
    tables[tableId] = value;
    _cache = tables;
    try {
      await _write(tables);
    } catch (error) {
      // Preferences are a convenience; a read-only or locked profile must not
      // break accounting work.
      debugPrint('تعذّر حفظ تفضيلات الجداول: $error');
    }
  }

  @override
  Future<void> clear(String tableId) async {
    final tables = Map<String, Object?>.from(await _read());
    if (tables.remove(tableId) == null) {
      return;
    }
    _cache = tables;
    try {
      await _write(tables);
    } catch (error) {
      debugPrint('تعذّر مسح تفضيلات الجداول: $error');
    }
  }
}

TablePreferencesStore createDefaultTablePreferencesStore() =>
    JsonFileTablePreferencesStore();
