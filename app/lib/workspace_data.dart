import 'ledger.dart';

/// Read model shared by the dashboard, journal and master-data pages.
class WorkspaceData {
  const WorkspaceData({
    required this.status,
    required this.snapshot,
    required this.customers,
    required this.suppliers,
    required this.materials,
    required this.categories,
    required this.currencies,
  });

  final LedgerStatus status;
  final LedgerSnapshot snapshot;
  final List<LedgerCustomer> customers;
  final List<LedgerSupplier> suppliers;
  final List<LedgerMaterial> materials;
  final List<LedgerCategory> categories;
  final List<CurrencyOption> currencies;

  String get baseCurrency => status.baseCurrencyCode;

  double get totalDebit => parseAmount(snapshot.totalDebit);

  double get totalCredit => parseAmount(snapshot.totalCredit);

  double get balanceDifference => totalDebit - totalCredit;

  bool get isBalanced => balanceDifference.abs() < 0.005;

  double get customerBalances => customers
      .map((customer) => parseAmount(customer.balance))
      .fold(0, (total, value) => total + value);

  double get supplierBalances => suppliers
      .map((supplier) => parseAmount(supplier.balance))
      .fold(0, (total, value) => total + value);

  double get inventoryValue => materials.fold(0, (total, material) {
    final available = parseAmount(material.totalAvailable);
    final cost = parseAmount(material.averageCost);
    return total + (available * cost);
  });

  List<LedgerMaterial> get lowStockMaterials {
    return materials
        .where((material) {
          final available = parseAmount(material.totalAvailable);
          final minimum = parseAmount(material.minimumStock);
          return minimum > 0 && available <= minimum;
        })
        .toList(growable: false);
  }

  Map<String, int> get materialCategoryCounts {
    final counts = <String, int>{};
    for (final material in materials) {
      if (material.categoryIds.isEmpty) {
        counts['غير مصنف'] = (counts['غير مصنف'] ?? 0) + 1;
        continue;
      }
      for (final id in material.categoryIds) {
        final category = categories
            .where((category) => category.id == id)
            .firstOrNull;
        final label = category?.name ?? 'غير مصنف';
        counts[label] = (counts[label] ?? 0) + 1;
      }
    }
    return counts;
  }

  String categoryName(String? id) {
    if (id == null || id.isEmpty) {
      return 'غير مصنف';
    }
    return categories
            .where((category) => category.id == id)
            .firstOrNull
            ?.name ??
        'غير مصنف';
  }

  static Future<WorkspaceData> load(LedgerGateway gateway) async {
    final results = await Future.wait<Object>([
      gateway.load(),
      gateway.loadCustomers(),
      gateway.loadSuppliers(),
      gateway.loadMaterials(),
      gateway.loadCategories(),
      gateway.availableCurrencies(),
    ]);

    final snapshot = results[0] as LedgerSnapshot;
    return WorkspaceData(
      status: snapshot.status,
      snapshot: snapshot,
      customers: results[1] as List<LedgerCustomer>,
      suppliers: results[2] as List<LedgerSupplier>,
      materials: results[3] as List<LedgerMaterial>,
      categories: results[4] as List<LedgerCategory>,
      currencies: results[5] as List<CurrencyOption>,
    );
  }
}

double parseAmount(String? raw) {
  if (raw == null) {
    return 0;
  }
  return double.tryParse(raw.trim()) ?? 0;
}

String formatMoney(String? raw, {String? currency, bool compact = false}) {
  final value = parseAmount(raw);
  final text = compact && value.abs() >= 1000000
      ? '${(value / 1000000).toStringAsFixed(2)} م'
      : compact && value.abs() >= 1000
      ? '${(value / 1000).toStringAsFixed(1)} ألف'
      : value.toStringAsFixed(2);
  final suffix = (currency ?? '').trim();
  return suffix.isEmpty ? text : '$text $suffix';
}

String formatNumberValue(num value, {int decimals = 2}) {
  final fixed = value.toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final integer = parts.first;
  final sign = integer.startsWith('-') ? '-' : '';
  final digits = sign.isEmpty ? integer : integer.substring(1);
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[index]);
  }
  final fraction = parts.length > 1 ? '.${parts[1]}' : '';
  return '$sign$buffer$fraction';
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) {
      return null;
    }
    return iterator.current;
  }
}
