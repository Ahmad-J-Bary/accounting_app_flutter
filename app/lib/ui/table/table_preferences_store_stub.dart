import 'table_preferences.dart';

/// Store used when no file system is available (web) or in tests.
class MemoryTablePreferencesStore implements TablePreferencesStore {
  MemoryTablePreferencesStore([Map<String, Object?>? initial])
    : _tables = <String, Object?>{...?initial};

  final Map<String, Object?> _tables;

  @override
  Future<Map<String, Object?>?> load(String tableId) async {
    final value = _tables[tableId];
    return value is Map<String, Object?> ? value : null;
  }

  @override
  Future<void> save(String tableId, Map<String, Object?> value) async {
    _tables[tableId] = value;
  }

  @override
  Future<void> clear(String tableId) async {
    _tables.remove(tableId);
  }
}

TablePreferencesStore createDefaultTablePreferencesStore() =>
    MemoryTablePreferencesStore();
