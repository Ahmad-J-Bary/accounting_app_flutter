/// Caches a filtered row list between rebuilds.
///
/// Pages rebuild for reasons that do not change their rows: a theme switch, a
/// snackbar, a parent `setState`. Recomputing the filter on every one of those
/// builds allocates a fresh list, and a fresh list also invalidates
/// `AppDataTable`'s sort cache, so the table would re-extract every sort key on
/// each build. Reusing the previous result while the key is unchanged avoids
/// both costs.
///
/// [key] must change whenever the result can change. Include the search text,
/// the active filters and the identity of the source list, for example:
///
/// ```dart
/// _filtered.resolve((_query, _activeOnly, data.customers), () => ...);
/// ```
class RowFilterCache<T> {
  Object? _key;
  List<T>? _rows;

  /// Number of times [resolve] had to compute a new list. Useful in tests and
  /// in debug overlays; not part of the caching contract.
  int computeCount = 0;

  /// Returns the rows cached for [key], or computes and caches them.
  List<T> resolve(Object key, List<T> Function() compute) {
    final cached = _rows;
    if (cached != null && _key == key) {
      return cached;
    }
    final rows = compute();
    computeCount++;
    _key = key;
    _rows = rows;
    return rows;
  }

  /// Returns true when [key] still describes the cached rows.
  bool matches(Object key) => _rows != null && _key == key;

  /// Drops the cached rows, for example after a write changed the source data.
  void clear() {
    _key = null;
    _rows = null;
  }
}
