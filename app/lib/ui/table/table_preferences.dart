import 'dart:async';

import 'package:flutter/foundation.dart';

/// Persistence boundary for table preferences.
abstract class TablePreferencesStore {
  Future<Map<String, Object?>?> load(String tableId);
  Future<void> save(String tableId, Map<String, Object?> value);
  Future<void> clear(String tableId);
}

/// Validated, immutable preferences for one table instance.
///
/// Only stable column ids are stored. Unknown ids from an older build are
/// dropped instead of being applied to a different column that happens to sit
/// at the same index.
@immutable
class TablePreferences {
  const TablePreferences({
    required this.order,
    required this.hidden,
    required this.widths,
    required this.pageSize,
    this.sortColumnId,
    this.sortAscending = true,
  });

  final List<String> order;
  final Set<String> hidden;
  final Map<String, double> widths;
  final int pageSize;
  final String? sortColumnId;
  final bool sortAscending;

  Map<String, Object?> toJson() => <String, Object?>{
    'order': order,
    'hidden': hidden.toList()..sort(),
    'widths': widths,
    'pageSize': pageSize,
    if (sortColumnId != null) 'sortColumnId': sortColumnId,
    'sortAscending': sortAscending,
  };

  @override
  bool operator ==(Object other) {
    return other is TablePreferences &&
        listEquals(other.order, order) &&
        setEquals(other.hidden, hidden) &&
        mapEquals(other.widths, widths) &&
        other.pageSize == pageSize &&
        other.sortColumnId == sortColumnId &&
        other.sortAscending == sortAscending;
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(order),
    Object.hashAll(hidden.toList()..sort()),
    Object.hashAll(
      widths.entries.map((entry) => Object.hash(entry.key, entry.value)),
    ),
    pageSize,
    sortColumnId,
    sortAscending,
  );

  static const List<int> allowedPageSizes = <int>[10, 25, 50, 100];
  static const double minWidth = 56;
  static const double maxWidth = 720;

  static TablePreferences defaults({
    required List<String> columnIds,
    Set<String> hidden = const <String>{},
    Map<String, double> widths = const <String, double>{},
    int pageSize = 25,
  }) {
    return TablePreferences(
      order: List<String>.unmodifiable(columnIds),
      hidden: Set<String>.unmodifiable(hidden),
      widths: Map<String, double>.unmodifiable(widths),
      pageSize: allowedPageSizes.contains(pageSize) ? pageSize : 25,
    );
  }

  /// Applies stored values without trusting them: stale ids are removed,
  /// new columns are appended, widths are clamped, and required columns stay
  /// visible.
  static TablePreferences sanitize(
    Map<String, Object?>? raw, {
    required List<String> columnIds,
    required Set<String> requiredColumnIds,
    required TablePreferences fallback,
  }) {
    if (raw == null) {
      return fallback;
    }

    final known = columnIds.toSet();
    final storedOrder = raw['order'];
    final order = <String>[];
    if (storedOrder is List<Object?>) {
      for (final value in storedOrder) {
        if (value is String &&
            known.contains(value) &&
            !order.contains(value)) {
          order.add(value);
        }
      }
    }
    for (final id in columnIds) {
      if (!order.contains(id)) {
        order.add(id);
      }
    }

    final hidden = <String>{};
    final storedHidden = raw['hidden'];
    if (storedHidden is List<Object?>) {
      for (final value in storedHidden) {
        if (value is String &&
            known.contains(value) &&
            !requiredColumnIds.contains(value)) {
          hidden.add(value);
        }
      }
    }
    if (hidden.length >= order.length && order.isNotEmpty) {
      hidden.remove(order.first);
    }

    final widths = <String, double>{};
    final storedWidths = raw['widths'];
    if (storedWidths is Map<Object?, Object?>) {
      for (final entry in storedWidths.entries) {
        final id = entry.key;
        final width = entry.value;
        if (id is String && known.contains(id) && width is num) {
          widths[id] = width.toDouble().clamp(minWidth, maxWidth);
        }
      }
    }

    final storedPageSize = raw['pageSize'];
    final pageSize =
        storedPageSize is int && allowedPageSizes.contains(storedPageSize)
        ? storedPageSize
        : fallback.pageSize;

    final storedSort = raw['sortColumnId'];
    final sortColumnId = storedSort is String && known.contains(storedSort)
        ? storedSort
        : null;
    final storedAscending = raw['sortAscending'];

    return TablePreferences(
      order: List<String>.unmodifiable(order),
      hidden: Set<String>.unmodifiable(hidden),
      widths: Map<String, double>.unmodifiable(widths),
      pageSize: pageSize,
      sortColumnId: sortColumnId,
      sortAscending: storedAscending is bool ? storedAscending : true,
    );
  }
}

/// Owns the preference state for a single table and persists changes in the
/// background. Loading is best-effort: until it finishes the table renders with
/// defaults, and a failed load leaves those defaults in place.
class TablePreferencesController extends ChangeNotifier {
  TablePreferencesController({
    required this.tableId,
    required List<String> columnIds,
    Set<String> requiredColumnIds = const <String>{},
    required TablePreferencesStore store,
    Map<String, double> defaultWidths = const <String, double>{},
    int defaultPageSize = 25,
  }) : _columnIds = List<String>.unmodifiable(_dedupe(columnIds)),
       _requiredColumnIds = Set<String>.unmodifiable(requiredColumnIds),
       _store = store,
       _defaults = TablePreferences.defaults(
         columnIds: _dedupe(columnIds),
         widths: defaultWidths,
         pageSize: defaultPageSize,
       ),
       _value = TablePreferences.defaults(
         columnIds: _dedupe(columnIds),
         widths: defaultWidths,
         pageSize: defaultPageSize,
       );

  final String tableId;
  final TablePreferencesStore _store;
  final TablePreferences _defaults;
  List<String> _columnIds;
  Set<String> _requiredColumnIds;
  TablePreferences _value;
  bool _disposed = false;
  Timer? _saveTimer;

  TablePreferences get value => _value;
  bool get isLoaded => _loaded;
  bool _loaded = false;

  static List<String> _dedupe(List<String> ids) {
    final seen = <String>{};
    return <String>[
      for (final id in ids)
        if (seen.add(id)) id,
    ];
  }

  Future<void> load() async {
    try {
      final raw = await _store.load(tableId);
      if (_disposed) {
        return;
      }
      _value = TablePreferences.sanitize(
        raw,
        columnIds: _columnIds,
        requiredColumnIds: _requiredColumnIds,
        fallback: _defaults,
      );
    } catch (error) {
      debugPrint('تعذّر تحميل تفضيلات الجدول $tableId: $error');
    } finally {
      _loaded = true;
      _notify();
    }
  }

  void syncColumns(List<String> columnIds, {Set<String>? requiredColumnIds}) {
    final deduped = _dedupe(columnIds);
    final required = requiredColumnIds ?? _requiredColumnIds;
    if (listEquals(deduped, _columnIds) &&
        setEquals(required, _requiredColumnIds)) {
      return;
    }
    _columnIds = List<String>.unmodifiable(deduped);
    _requiredColumnIds = Set<String>.unmodifiable(required);
    final sanitized = TablePreferences.sanitize(
      _value.toJson(),
      columnIds: _columnIds,
      requiredColumnIds: _requiredColumnIds,
      fallback: _defaults,
    );
    if (sanitized != _value) {
      _value = sanitized;
      _notify();
    }
  }

  void setVisible(String columnId, bool visible) {
    if (!_columnIds.contains(columnId)) {
      return;
    }
    if (!visible && _requiredColumnIds.contains(columnId)) {
      return;
    }
    final hidden = Set<String>.from(_value.hidden);
    if (visible) {
      hidden.remove(columnId);
    } else {
      if (hidden.length >= _columnIds.length - 1) {
        return;
      }
      hidden.add(columnId);
    }
    _update(
      TablePreferences(
        order: _value.order,
        hidden: Set<String>.unmodifiable(hidden),
        widths: _value.widths,
        pageSize: _value.pageSize,
        sortColumnId: _value.sortColumnId,
        sortAscending: _value.sortAscending,
      ),
    );
  }

  void setWidth(String columnId, double width) {
    if (!_columnIds.contains(columnId)) {
      return;
    }
    final widths = Map<String, double>.from(_value.widths);
    widths[columnId] = width.clamp(
      TablePreferences.minWidth,
      TablePreferences.maxWidth,
    );
    _update(
      TablePreferences(
        order: _value.order,
        hidden: _value.hidden,
        widths: Map<String, double>.unmodifiable(widths),
        pageSize: _value.pageSize,
        sortColumnId: _value.sortColumnId,
        sortAscending: _value.sortAscending,
      ),
    );
  }

  void move(String columnId, int delta) {
    final order = List<String>.from(_value.order);
    final index = order.indexOf(columnId);
    final target = index + delta;
    if (index < 0 || target < 0 || target >= order.length) {
      return;
    }
    order
      ..removeAt(index)
      ..insert(target, columnId);
    _update(
      TablePreferences(
        order: List<String>.unmodifiable(order),
        hidden: _value.hidden,
        widths: _value.widths,
        pageSize: _value.pageSize,
        sortColumnId: _value.sortColumnId,
        sortAscending: _value.sortAscending,
      ),
    );
  }

  /// Toggles sorting for [columnId]. Passing a different column starts
  /// ascending. Passing `null` clears sorting.
  void toggleSort(String? columnId, {bool? ascending}) {
    if (columnId != null && !_columnIds.contains(columnId)) {
      return;
    }
    final nextAscending =
        ascending ??
        (columnId != null && _value.sortColumnId == columnId
            ? !_value.sortAscending
            : true);
    _update(
      TablePreferences(
        order: _value.order,
        hidden: _value.hidden,
        widths: _value.widths,
        pageSize: _value.pageSize,
        sortColumnId: columnId,
        sortAscending: nextAscending,
      ),
    );
  }

  void setPageSize(int pageSize) {
    if (!TablePreferences.allowedPageSizes.contains(pageSize)) {
      return;
    }
    _update(
      TablePreferences(
        order: _value.order,
        hidden: _value.hidden,
        widths: _value.widths,
        pageSize: pageSize,
        sortColumnId: _value.sortColumnId,
        sortAscending: _value.sortAscending,
      ),
    );
  }

  void reset() {
    _saveTimer?.cancel();
    _saveTimer = null;
    _value = _defaults;
    _notify();
    unawaited(_clearStore());
  }

  void _update(TablePreferences next) {
    if (next == _value) {
      return;
    }
    _value = next;
    _notify();
    _schedulePersist();
  }

  void _schedulePersist() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 350), () {
      unawaited(_persist());
    });
  }

  Future<void> _persist() async {
    try {
      await _store.save(tableId, _value.toJson());
    } catch (error) {
      debugPrint('تعذّر حفظ تفضيلات الجدول $tableId: $error');
    }
  }

  Future<void> _clearStore() async {
    try {
      await _store.clear(tableId);
    } catch (error) {
      debugPrint('تعذّر مسح تفضيلات الجدول $tableId: $error');
    }
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _saveTimer?.cancel();
    _saveTimer = null;
    unawaited(_persist());
    super.dispose();
  }
}
