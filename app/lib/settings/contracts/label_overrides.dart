import 'package:flutter/foundation.dart';

/// The set of keys the user is allowed to override.
/// Deliberately narrow at first; extend only via owner-approved cycles.
class AllowedLabelKeys {
  static const pageCustomersTitle = 'page.customers.title';
  static const pageSuppliersTitle = 'page.suppliers.title';
  static const pageMaterialsTitle = 'page.materials.title';
  static const tableCustomersHeaderName = 'table.customers.header.name';
  static const tableMaterialsHeaderName = 'table.materials.header.name';

  static const all = <String>{
    pageCustomersTitle,
    pageSuppliersTitle,
    pageMaterialsTitle,
    tableCustomersHeaderName,
    tableMaterialsHeaderName,
  };
}

@immutable
class LabelOverrides {
  final Map<String, String> values;

  const LabelOverrides._(this.values);

  factory LabelOverrides.empty() =>
      const LabelOverrides._(<String, String>{});

  /// Constructs from a raw map. Unknown keys and empty values are rejected.
  factory LabelOverrides.fromRaw(Map<String, String> raw) {
    final cleaned = <String, String>{};
    for (final entry in raw.entries) {
      if (!AllowedLabelKeys.all.contains(entry.key)) {
        throw ArgumentError.value(
            entry.key, 'key', 'Label override key not allowed');
      }
      final trimmed = entry.value.trim();
      if (trimmed.isEmpty) {
        throw ArgumentError.value(
            entry.value, 'value', 'Label override value must not be empty');
      }
      cleaned[entry.key] = trimmed;
    }
    return LabelOverrides._(Map.unmodifiable(cleaned));
  }

  String? resolve(String key) => values[key];

  /// Returns the override for [key], or [fallback] if absent.
  String resolveOr(String key, String fallback) => values[key] ?? fallback;

  Map<String, dynamic> toJson() => {'values': values};

  static LabelOverrides fromJson(Map<String, dynamic> json) {
    final raw = json['values'];
    if (raw is Map) {
      final stringMap = <String, String>{};
      raw.forEach((k, v) {
        if (k is String && v is String) stringMap[k] = v;
      });
      try {
        return LabelOverrides.fromRaw(stringMap);
      } on ArgumentError {
        // Silently drop invalid persisted overrides instead of corrupting state.
        return LabelOverrides.empty();
      }
    }
    return LabelOverrides.empty();
  }

  @override
  bool operator ==(Object other) =>
      other is LabelOverrides && mapEquals(other.values, values);

  @override
  int get hashCode =>
      Object.hashAll(values.entries.map((e) => Object.hash(e.key, e.value)));
}