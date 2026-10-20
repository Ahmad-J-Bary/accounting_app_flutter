import 'dart:io';

import 'package:accounting_app_flutter_isolates/accounting_app_flutter_isolates.dart'
    as rust;
import 'package:path_provider/path_provider.dart';

/// UI-facing account model (decoupled from the generated FRB types).
class LedgerAccount {
  const LedgerAccount({
    required this.id,
    required this.code,
    required this.nameAr,
    required this.nameEn,
    required this.accountType,
    required this.currency,
    required this.balance,
    required this.isFinal,
    required this.isActive,
  });

  final String id;
  final String code;
  final String nameAr;
  final String nameEn;
  final String accountType;
  final String currency;
  final String balance;
  final bool isFinal;
  final bool isActive;

  String get displayName => nameAr.isNotEmpty ? nameAr : nameEn;
}

class TrialBalanceRow {
  const TrialBalanceRow({
    required this.accountCode,
    required this.accountName,
    required this.accountType,
    required this.debit,
    required this.credit,
  });

  final String accountCode;
  final String accountName;
  final String accountType;
  final String debit;
  final String credit;
}

class LedgerCustomer {
  const LedgerCustomer({
    required this.id,
    required this.code,
    required this.name,
    required this.phone,
    required this.address,
    required this.notes,
    required this.openingBalance,
    required this.balance,
    required this.currency,
    required this.isActive,
  });

  final String id;
  final String code;
  final String name;
  final String? phone;
  final String? address;
  final String? notes;
  final String openingBalance;
  final String balance;
  final String currency;
  final bool isActive;
}

class LedgerSupplier {
  const LedgerSupplier({
    required this.id,
    required this.code,
    required this.name,
    required this.phone,
    required this.address,
    required this.notes,
    required this.openingBalance,
    required this.balance,
    required this.currency,
    required this.isActive,
  });

  final String id;
  final String code;
  final String name;
  final String? phone;
  final String? address;
  final String? notes;
  final String openingBalance;
  final String balance;
  final String currency;
  final bool isActive;
}

class LedgerMaterialUnit {
  const LedgerMaterialUnit({
    required this.id,
    required this.name,
    required this.conversionFactor,
    required this.barcode,
    required this.isBase,
  });

  final String id;
  final String name;
  final String conversionFactor;
  final String? barcode;
  final bool isBase;
}

class LedgerMaterial {
  const LedgerMaterial({
    required this.id,
    required this.code,
    required this.name,
    required this.nameEn,
    required this.barcode,
    required this.totalAvailable,
    required this.minimumStock,
    required this.averageCost,
    required this.purchasePrice,
    required this.salePrice,
    required this.currency,
    required this.notes,
    required this.unitName,
    required this.conversionFactor,
    required this.expiryAlertBeforeDays,
    required this.unitsCount,
    required this.hasExpiry,
    this.categoryIds = const [],
    this.units = const [],
  });

  final String id;
  final String code;
  final String name;
  final String nameEn;
  final String barcode;
  final String totalAvailable;
  final String minimumStock;
  final String averageCost;
  final String purchasePrice;
  final String salePrice;
  final String currency;
  final String? notes;
  final String unitName;
  final String conversionFactor;
  final int expiryAlertBeforeDays;
  final int unitsCount;
  final bool hasExpiry;
  final List<String> categoryIds;
  final List<LedgerMaterialUnit> units;
}

class LedgerCategory {
  const LedgerCategory({
    required this.id,
    required this.name,
    required this.parentId,
    required this.codePrefix,
    required this.isActive,
    required this.materialCount,
    required this.systemKey,
  });

  final String id;
  final String name;
  final String? parentId;
  final String? codePrefix;
  final bool isActive;
  final int materialCount;
  final String? systemKey;

  bool get isSystem => systemKey == 'inventory.category.uncategorized';
}

class CategoryDeleteSummary {
  const CategoryDeleteSummary({
    required this.materialsReassigned,
    required this.subsDeleted,
  });

  final int materialsReassigned;
  final int subsDeleted;
}

class MaterialUnitDraft {
  const MaterialUnitDraft({
    required this.name,
    required this.conversionFactor,
    this.barcode,
  });

  final String name;
  final String conversionFactor;
  final String? barcode;
}

/// Company identity and setup state returned by the Rust core.
class LedgerStatus {
  const LedgerStatus({
    required this.setupComplete,
    required this.companyName,
    required this.baseCurrencyCode,
    required this.currencySymbol,
    required this.fiscalYearStartMonth,
    required this.accountingStartMode,
  });

  final bool setupComplete;
  final String companyName;
  final String baseCurrencyCode;
  final String currencySymbol;
  final int fiscalYearStartMonth;
  final String accountingStartMode;

  String get currencyLabel {
    final code = baseCurrencyCode.trim();
    final symbol = currencySymbol.trim();
    if (code.isEmpty) {
      return 'غير محددة';
    }
    return symbol.isEmpty ? code : '$code ($symbol)';
  }
}

class LedgerSnapshot {
  const LedgerSnapshot({
    required this.status,
    required this.accounts,
    required this.rows,
    required this.totalDebit,
    required this.totalCredit,
  });

  final LedgerStatus status;
  final List<LedgerAccount> accounts;
  final List<TrialBalanceRow> rows;
  final String totalDebit;
  final String totalCredit;
}

/// A currency offered by the Rust catalogue.
class CurrencyOption {
  const CurrencyOption({
    required this.code,
    required this.nameAr,
    required this.nameEn,
    required this.symbol,
    required this.decimals,
  });

  final String code;
  final String nameAr;
  final String nameEn;
  final String symbol;
  final int decimals;

  String get displayName {
    final hasArabic = RegExp(r'[\u0600-\u06FF]').hasMatch(nameAr);
    return hasArabic ? nameAr : nameEn;
  }
}

/// Boundary between the widget tree and the Rust core. Keeping this abstract
/// lets widget tests run without loading the native library.
abstract class LedgerGateway {
  Future<LedgerStatus> loadStatus();

  Future<LedgerSnapshot> load();

  Future<List<LedgerCustomer>> loadCustomers();

  Future<List<LedgerSupplier>> loadSuppliers();

  Future<List<LedgerMaterial>> loadMaterials();

  Future<List<LedgerCategory>> loadCategories();

  Future<void> createCategory({
    required String name,
    String? parentId,
    String? codePrefix,
  });

  Future<void> updateCategory({
    required String id,
    required String name,
    String? parentId,
    required bool isActive,
    String? codePrefix,
  });

  Future<CategoryDeleteSummary> deleteCategory(String id);

  Future<List<LedgerMaterialUnit>> loadMaterialUnits(String materialId);

  Future<List<LedgerMaterialUnit>> addMaterialUnit({
    required String materialId,
    required String name,
    required String conversionFactor,
    String? barcode,
  });

  Future<List<LedgerMaterialUnit>> deleteMaterialUnit({
    required String materialId,
    required String unitId,
  });

  Future<void> createCustomer({
    required String name,
    String? phone,
    String? address,
    String? notes,
    required String currency,
    required String openingBalance,
  });

  Future<void> updateCustomer({
    required String id,
    required String code,
    required String name,
    String? phone,
    String? address,
    String? notes,
    String? openingBalance,
    required bool isActive,
  });

  Future<void> deleteCustomer(String id);

  Future<void> createSupplier({
    required String name,
    String? phone,
    String? address,
    String? notes,
    required String currency,
    required String openingBalance,
  });

  Future<void> updateSupplier({
    required String id,
    required String code,
    required String name,
    String? phone,
    String? address,
    String? notes,
    String? openingBalance,
    required bool isActive,
  });

  Future<void> deleteSupplier(String id);

  Future<void> createMaterial({
    required String name,
    String? nameEn,
    String? barcode,
    String? code,
    required String minimumStock,
    required String unitName,
    required String conversionFactor,
    List<MaterialUnitDraft> extraUnits = const [],
    List<String> categoryIds = const [],
    String? purchasePrice,
    String? salePrice,
    required String currency,
    String? notes,
    required bool hasExpiry,
    required int expiryAlertBeforeDays,
  });

  Future<void> updateMaterial({
    required String id,
    required String name,
    required String nameEn,
    required String barcode,
    required String code,
    required String minimumStock,
    List<String> categoryIds = const [],
    String? notes,
    String? purchasePrice,
    String? salePrice,
    String? currency,
    required bool hasExpiry,
    required int expiryAlertBeforeDays,
  });

  Future<void> deleteMaterial(String id);

  Future<List<CurrencyOption>> availableCurrencies();

  Future<void> setupCompany({
    required String companyName,
    required String baseCurrencyCode,
    String? secondaryCurrencyCode,
    required int fiscalYearStartMonth,
    String? accountingStartMode,
  });

  Future<void> createEntry({
    required String debitAccountId,
    required String creditAccountId,
    required String amount,
    required String description,
    required String currency,
  });
}

class RustLedgerGateway implements LedgerGateway {
  Future<void>? _rustInit;
  bool _databaseReady = false;

  Future<void> _ensureReady() async {
    try {
      _rustInit ??= rust.RustLib.init();
      await _rustInit;
    } catch (error) {
      // Allow a later retry if loading the native library failed.
      _rustInit = null;
      rethrow;
    }

    if (_databaseReady) {
      return;
    }

    final supportDir = await getApplicationSupportDirectory();
    final dbPath = '${supportDir.path}${Platform.pathSeparator}accounting.db';
    await rust.initApp(dbPath: dbPath);
    _databaseReady = true;
  }

  @override
  Future<LedgerStatus> loadStatus() async {
    await _ensureReady();
    return _statusFromBridge(await rust.getSetupStatus());
  }

  @override
  Future<List<CurrencyOption>> availableCurrencies() async {
    await _ensureReady();
    final currencies = await rust.worldCurrencies();
    return currencies
        .map(
          (currency) => CurrencyOption(
            code: currency.code,
            nameAr: currency.nameAr,
            nameEn: currency.nameEn,
            symbol: currency.symbol,
            decimals: currency.decimals,
          ),
        )
        .toList();
  }

  @override
  Future<void> setupCompany({
    required String companyName,
    required String baseCurrencyCode,
    String? secondaryCurrencyCode,
    required int fiscalYearStartMonth,
    String? accountingStartMode,
  }) async {
    await _ensureReady();
    await rust.setupCompany(
      input: rust.SetupCompanyInput(
        companyName: companyName,
        baseCurrencyCode: baseCurrencyCode,
        secondaryCurrencyCode: secondaryCurrencyCode,
        fiscalYearStartMonth: fiscalYearStartMonth,
        accountingStartMode: accountingStartMode,
      ),
    );
  }

  @override
  Future<LedgerSnapshot> load() async {
    await _ensureReady();

    final status = _statusFromBridge(await rust.getSetupStatus());
    final accounts = await rust.listAccounts();
    final trial = await rust.trialBalance();

    return LedgerSnapshot(
      status: status,
      accounts: accounts
          .map(
            (account) => LedgerAccount(
              id: account.id,
              code: account.code,
              nameAr: account.nameAr,
              nameEn: account.nameEn,
              accountType: account.accountType,
              currency: account.currency,
              balance: account.balance,
              isFinal: account.isFinal,
              isActive: account.isActive,
            ),
          )
          .toList(),
      rows: trial.lines
          .map(
            (line) => TrialBalanceRow(
              accountCode: line.accountCode,
              accountName: line.accountName,
              accountType: line.accountType,
              debit: line.debitTotal,
              credit: line.creditTotal,
            ),
          )
          .toList(),
      totalDebit: trial.totalDebit,
      totalCredit: trial.totalCredit,
    );
  }

  @override
  Future<List<LedgerCustomer>> loadCustomers() async {
    await _ensureReady();
    final customers = await rust.listCustomers();
    return customers
        .map(
          (customer) => LedgerCustomer(
            id: customer.id,
            code: customer.code,
            name: customer.name,
            phone: customer.phone,
            address: customer.address,
            notes: customer.notes,
            openingBalance: customer.openingBalance,
            balance: customer.balance,
            currency: customer.currency,
            isActive: customer.isActive,
          ),
        )
        .toList();
  }

  @override
  Future<List<LedgerSupplier>> loadSuppliers() async {
    await _ensureReady();
    final suppliers = await rust.listSuppliers();
    return suppliers
        .map(
          (supplier) => LedgerSupplier(
            id: supplier.id,
            code: supplier.code,
            name: supplier.name,
            phone: supplier.phone,
            address: supplier.address,
            notes: supplier.notes,
            openingBalance: supplier.openingBalance,
            balance: supplier.balance,
            currency: supplier.currency,
            isActive: supplier.isActive,
          ),
        )
        .toList();
  }

  @override
  Future<List<LedgerMaterial>> loadMaterials() async {
    await _ensureReady();
    final materials = await rust.listMaterials();
    return materials
        .map(
          (material) => LedgerMaterial(
            id: material.id,
            code: material.code,
            name: material.name,
            nameEn: material.nameEn,
            barcode: material.barcode,
            totalAvailable: material.totalAvailable,
            minimumStock: material.minimumStock,
            averageCost: material.averageCost,
            purchasePrice: material.purchasePrice,
            salePrice: material.salePrice,
            currency: material.currency,
            notes: material.notes,
            unitName: material.unitName,
            conversionFactor: material.conversionFactor,
            expiryAlertBeforeDays: material.expiryAlertBeforeDays,
            unitsCount: material.unitsCount,
            hasExpiry: material.hasExpiry,
            categoryIds: material.categoryIds,
            units: material.units.map(_materialUnitFromBridge).toList(),
          ),
        )
        .toList();
  }

  @override
  Future<List<LedgerCategory>> loadCategories() async {
    await _ensureReady();
    final categories = await rust.listCategories();
    return categories
        .map(
          (category) => LedgerCategory(
            id: category.id,
            name: category.name,
            parentId: category.parentId,
            codePrefix: category.codePrefix,
            isActive: category.isActive,
            materialCount: category.materialCount,
            systemKey: category.systemKey,
          ),
        )
        .toList();
  }

  @override
  Future<void> createCategory({
    required String name,
    String? parentId,
    String? codePrefix,
  }) async {
    await _ensureReady();
    await rust.createCategory(
      input: rust.CategoryCreateInput(
        name: name,
        parentId: parentId,
        codePrefix: codePrefix,
      ),
    );
  }

  @override
  Future<void> updateCategory({
    required String id,
    required String name,
    String? parentId,
    required bool isActive,
    String? codePrefix,
  }) async {
    await _ensureReady();
    await rust.updateCategory(
      input: rust.CategoryUpdateInput(
        id: id,
        name: name,
        parentId: parentId,
        isActive: isActive,
        codePrefix: codePrefix,
      ),
    );
  }

  @override
  Future<CategoryDeleteSummary> deleteCategory(String id) async {
    await _ensureReady();
    final result = await rust.deleteCategory(id: id);
    return CategoryDeleteSummary(
      materialsReassigned: result.materialsReassigned,
      subsDeleted: result.subsDeleted,
    );
  }

  @override
  Future<List<LedgerMaterialUnit>> loadMaterialUnits(String materialId) async {
    await _ensureReady();
    final units = await rust.listMaterialUnits(materialId: materialId);
    return units.map(_materialUnitFromBridge).toList();
  }

  @override
  Future<List<LedgerMaterialUnit>> addMaterialUnit({
    required String materialId,
    required String name,
    required String conversionFactor,
    String? barcode,
  }) async {
    await _ensureReady();
    final units = await rust.addMaterialUnit(
      input: rust.MaterialUnitCreateInput(
        materialId: materialId,
        name: name,
        conversionFactor: conversionFactor,
        barcode: barcode,
      ),
    );
    return units.map(_materialUnitFromBridge).toList();
  }

  @override
  Future<List<LedgerMaterialUnit>> deleteMaterialUnit({
    required String materialId,
    required String unitId,
  }) async {
    await _ensureReady();
    final units = await rust.deleteMaterialUnit(
      materialId: materialId,
      unitId: unitId,
    );
    return units.map(_materialUnitFromBridge).toList();
  }

  @override
  Future<void> createCustomer({
    required String name,
    String? phone,
    String? address,
    String? notes,
    required String currency,
    required String openingBalance,
  }) async {
    await _ensureReady();
    await rust.createCustomer(
      input: rust.CustomerCreateInput(
        name: name,
        phone: phone,
        address: address,
        notes: notes,
        currency: currency,
        openingBalance: openingBalance,
      ),
    );
  }

  @override
  Future<void> updateCustomer({
    required String id,
    required String code,
    required String name,
    String? phone,
    String? address,
    String? notes,
    String? openingBalance,
    required bool isActive,
  }) async {
    await _ensureReady();
    await rust.updateCustomer(
      input: rust.CustomerUpdateInput(
        id: id,
        code: code,
        name: name,
        phone: phone,
        address: address,
        notes: notes,
        openingBalance: openingBalance,
        isActive: isActive,
      ),
    );
  }

  @override
  Future<void> deleteCustomer(String id) async {
    await _ensureReady();
    await rust.deleteCustomer(id: id);
  }

  @override
  Future<void> createSupplier({
    required String name,
    String? phone,
    String? address,
    String? notes,
    required String currency,
    required String openingBalance,
  }) async {
    await _ensureReady();
    await rust.createSupplier(
      input: rust.SupplierCreateInput(
        name: name,
        phone: phone,
        address: address,
        notes: notes,
        currency: currency,
        openingBalance: openingBalance,
      ),
    );
  }

  @override
  Future<void> updateSupplier({
    required String id,
    required String code,
    required String name,
    String? phone,
    String? address,
    String? notes,
    String? openingBalance,
    required bool isActive,
  }) async {
    await _ensureReady();
    await rust.updateSupplier(
      input: rust.SupplierUpdateInput(
        id: id,
        code: code,
        name: name,
        phone: phone,
        address: address,
        notes: notes,
        openingBalance: openingBalance,
        isActive: isActive,
      ),
    );
  }

  @override
  Future<void> deleteSupplier(String id) async {
    await _ensureReady();
    await rust.deleteSupplier(id: id);
  }

  @override
  Future<void> createMaterial({
    required String name,
    String? nameEn,
    String? barcode,
    String? code,
    required String minimumStock,
    required String unitName,
    required String conversionFactor,
    List<MaterialUnitDraft> extraUnits = const [],
    List<String> categoryIds = const [],
    String? purchasePrice,
    String? salePrice,
    required String currency,
    String? notes,
    required bool hasExpiry,
    required int expiryAlertBeforeDays,
  }) async {
    await _ensureReady();
    await rust.createMaterial(
      input: rust.MaterialCreateInput(
        name: name,
        nameEn: nameEn,
        barcode: barcode,
        code: code,
        minimumStock: minimumStock,
        unitName: unitName,
        conversionFactor: conversionFactor,
        extraUnits: extraUnits
            .map(
              (unit) => rust.MaterialUnitInput(
                name: unit.name,
                conversionFactor: unit.conversionFactor,
                barcode: unit.barcode,
              ),
            )
            .toList(),
        categoryIds: categoryIds,
        purchasePrice: purchasePrice,
        salePrice: salePrice,
        currency: currency,
        notes: notes,
        hasExpiry: hasExpiry,
        expiryAlertBeforeDays: expiryAlertBeforeDays,
      ),
    );
  }

  @override
  Future<void> updateMaterial({
    required String id,
    required String name,
    required String nameEn,
    required String barcode,
    required String code,
    required String minimumStock,
    List<String> categoryIds = const [],
    String? notes,
    String? purchasePrice,
    String? salePrice,
    String? currency,
    required bool hasExpiry,
    required int expiryAlertBeforeDays,
  }) async {
    await _ensureReady();
    await rust.updateMaterial(
      input: rust.MaterialUpdateInput(
        id: id,
        name: name,
        nameEn: nameEn,
        barcode: barcode,
        code: code,
        minimumStock: minimumStock,
        categoryIds: categoryIds,
        notes: notes,
        purchasePrice: purchasePrice,
        salePrice: salePrice,
        currency: currency,
        hasExpiry: hasExpiry,
        expiryAlertBeforeDays: expiryAlertBeforeDays,
      ),
    );
  }

  @override
  Future<void> deleteMaterial(String id) async {
    await _ensureReady();
    await rust.deleteMaterial(id: id);
  }

  @override
  Future<void> createEntry({
    required String debitAccountId,
    required String creditAccountId,
    required String amount,
    required String description,
    required String currency,
  }) async {
    await _ensureReady();

    final entry = await rust.createJournalEntry(
      input: rust.CreateJournalEntryInput(
        journalType: 'GeneralJournal',
        entryDate: DateTime.now().toUtc().toIso8601String(),
        description: description.isEmpty ? 'قيد يومية' : description,
        lines: [
          rust.JournalLineInput(
            accountId: debitAccountId,
            currency: currency,
            fxRate: '1',
            debit: amount,
            credit: '0',
            description: description,
          ),
          rust.JournalLineInput(
            accountId: creditAccountId,
            currency: currency,
            fxRate: '1',
            debit: '0',
            credit: amount,
            description: description,
          ),
        ],
      ),
    );

    await rust.postJournalEntry(entryId: entry.id);
  }
}

LedgerMaterialUnit _materialUnitFromBridge(rust.MaterialUnitItem unit) {
  return LedgerMaterialUnit(
    id: unit.id,
    name: unit.name,
    conversionFactor: unit.conversionFactor,
    barcode: unit.barcode,
    isBase: unit.isBase,
  );
}

LedgerStatus _statusFromBridge(rust.SetupStatusView status) {
  return LedgerStatus(
    setupComplete: status.setupComplete,
    companyName: status.companyName,
    baseCurrencyCode: status.baseCurrencyCode,
    currencySymbol: status.currencySymbol,
    fiscalYearStartMonth: status.fiscalYearStartMonth,
    accountingStartMode: status.accountingStartMode,
  );
}

/// Readable Arabic-first error text for the UI.
String describeError(Object error) {
  if (error is rust.ApiError) {
    final details = error.details?.trim();
    if (details != null && details.isNotEmpty) {
      return '${error.message}\n$details';
    }
    return error.message;
  }
  return error.toString();
}
