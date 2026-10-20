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
    this.purpose = '',
    this.parentId,
    this.category = '',
    this.level = 0,
    this.openingBalance = '0',
    this.debit = '0',
    this.credit = '0',
    this.notes,
    this.isDefault = false,
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
  final String purpose;
  final String? parentId;
  final String category;
  final int level;
  final String openingBalance;
  final String debit;
  final String credit;
  final String? notes;
  final bool isDefault;

  String get displayName => nameAr.isNotEmpty ? nameAr : nameEn;
}

class LedgerInvoiceLine {
  const LedgerInvoiceLine({
    required this.materialId,
    required this.materialName,
    required this.quantity,
    required this.unitPrice,
    this.unitId,
    this.unitName,
    this.conversionFactor,
    this.discountPercent = '0',
    this.lineTotal = '0',
    this.code = '',
    this.barcode = '',
    this.categoryName = '',
    this.notes,
  });

  final String materialId;
  final String materialName;
  final String quantity;
  final String unitPrice;
  final String? unitId;
  final String? unitName;
  final String? conversionFactor;
  final String discountPercent;
  final String lineTotal;
  final String code;
  final String barcode;
  final String categoryName;
  final String? notes;
}

class LedgerInvoice {
  const LedgerInvoice({
    required this.id,
    required this.number,
    required this.invoiceType,
    required this.partyName,
    required this.status,
    required this.lines,
    required this.taxAmount,
    required this.discountAmount,
    required this.extraCosts,
    required this.subtotal,
    required this.total,
    required this.amountPaid,
    required this.remaining,
    required this.paymentMethod,
    required this.issuedAt,
    required this.currency,
    this.partyId,
    this.notes,
  });

  final String id;
  final String number;
  final String invoiceType;
  final String partyName;
  final String status;
  final List<LedgerInvoiceLine> lines;
  final String taxAmount;
  final String discountAmount;
  final String extraCosts;
  final String subtotal;
  final String total;
  final String amountPaid;
  final String remaining;
  final String paymentMethod;
  final String issuedAt;
  final String currency;
  final String? partyId;
  final String? notes;

  bool get isPosted => status == 'Posted';
}

class InvoiceDraft {
  const InvoiceDraft({
    required this.invoiceType,
    required this.partyId,
    required this.partyName,
    required this.lines,
    this.paymentMethod = 'Cash',
    this.amountPaid = '0',
    this.discountAmount = '0',
    this.taxAmount = '0',
    this.extraCosts = '0',
    this.notes,
    this.currency = '',
    this.issuedAt,
  });

  final String invoiceType;
  final String partyId;
  final String partyName;
  final List<LedgerInvoiceLine> lines;
  final String paymentMethod;
  final String amountPaid;
  final String discountAmount;
  final String taxAmount;
  final String extraCosts;
  final String? notes;
  final String currency;
  final DateTime? issuedAt;
}

class LedgerReturnLine {
  const LedgerReturnLine({
    required this.materialId,
    required this.materialName,
    required this.quantity,
    required this.unitPrice,
    this.unitId,
    this.lineTotal = '0',
    this.notes,
  });

  final String materialId;
  final String materialName;
  final String quantity;
  final String unitPrice;
  final String? unitId;
  final String lineTotal;
  final String? notes;
}

class LedgerReturn {
  const LedgerReturn({
    required this.id,
    required this.number,
    required this.partyId,
    required this.partyName,
    required this.returnDate,
    required this.lines,
    required this.total,
    this.notes,
  });

  final String id;
  final String number;
  final String partyId;
  final String partyName;
  final String returnDate;
  final List<LedgerReturnLine> lines;
  final String total;
  final String? notes;
}

class ReturnDraft {
  const ReturnDraft({
    required this.kind,
    required this.partyId,
    required this.lines,
    this.notes,
    this.settlementMode,
    this.settlementAmount,
    this.isPaid = false,
    this.returnDate,
  });

  final String kind;
  final String partyId;
  final List<LedgerReturnLine> lines;
  final String? notes;
  final String? settlementMode;
  final String? settlementAmount;
  final bool isPaid;
  final DateTime? returnDate;
}

class LedgerPayment {
  const LedgerPayment({
    required this.id,
    required this.voucherNumber,
    required this.paymentType,
    required this.amount,
    required this.currency,
    required this.paymentDate,
    this.exchangeRate = '1',
    this.journalEntryNumber,
    this.customerId,
    this.customerName,
    this.supplierId,
    this.supplierName,
    this.reference,
    this.notes,
  });

  final String id;
  final String voucherNumber;
  final String paymentType;
  final String amount;
  final String currency;
  final String exchangeRate;
  final String paymentDate;
  final String? journalEntryNumber;
  final String? customerId;
  final String? customerName;
  final String? supplierId;
  final String? supplierName;
  final String? reference;
  final String? notes;

  String get partyName => customerName ?? supplierName ?? '';
}

class PaymentDraft {
  const PaymentDraft({
    required this.paymentType,
    required this.amount,
    required this.currency,
    this.exchangeRate = '1',
    this.customerId,
    this.supplierId,
    this.debitAccountId,
    this.creditAccountId,
    this.reference,
    this.notes,
    this.paymentDate,
  });

  final String paymentType;
  final String amount;
  final String currency;
  final String exchangeRate;
  final String? customerId;
  final String? supplierId;
  final String? debitAccountId;
  final String? creditAccountId;
  final String? reference;
  final String? notes;
  final DateTime? paymentDate;
}

class ExpenseItemDraft {
  const ExpenseItemDraft({
    required this.nameAr,
    required this.nameEn,
    required this.code,
    required this.currency,
    this.id,
    this.openingBalance = '0',
    this.debit = '0',
    this.credit = '0',
    this.exchangeRate = '1',
    this.notes,
  });

  final String? id;
  final String nameAr;
  final String nameEn;
  final String code;
  final String currency;
  final String openingBalance;
  final String debit;
  final String credit;
  final String exchangeRate;
  final String? notes;
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

  Future<List<LedgerInvoice>> loadInvoices() async => const [];

  Future<LedgerInvoice> createInvoice(
    InvoiceDraft draft, {
    bool post = false,
  }) async => throw UnimplementedError();

  Future<LedgerInvoice> updateInvoice(String id, InvoiceDraft draft) async =>
      throw UnimplementedError();

  Future<LedgerInvoice> postInvoice(String id) async =>
      throw UnimplementedError();

  Future<void> deleteInvoice(String id) async => throw UnimplementedError();

  Future<List<LedgerReturn>> loadSalesReturns() async => const [];

  Future<List<LedgerReturn>> loadPurchaseReturns() async => const [];

  Future<LedgerReturn> createSalesReturn(ReturnDraft draft) async =>
      throw UnimplementedError();

  Future<LedgerReturn> createPurchaseReturn(ReturnDraft draft) async =>
      throw UnimplementedError();

  Future<List<LedgerPayment>> loadPayments() async => const [];

  Future<LedgerPayment> createPayment(PaymentDraft draft) async =>
      throw UnimplementedError();

  Future<LedgerPayment> updatePayment(String id, PaymentDraft draft) async =>
      throw UnimplementedError();

  Future<void> deletePayment(String id) async => throw UnimplementedError();

  Future<List<LedgerAccount>> loadExpenseItems() async => const [];

  Future<void> createExpenseItem(ExpenseItemDraft draft) async =>
      throw UnimplementedError();

  Future<void> updateExpenseItem(ExpenseItemDraft draft) async =>
      throw UnimplementedError();

  Future<void> deleteExpenseItem(String id) async => throw UnimplementedError();
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
      accounts: accounts.map(_accountFromBridge).toList(),
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

  @override
  Future<List<LedgerInvoice>> loadInvoices() async {
    await _ensureReady();
    final sales = await rust.listInvoices(invoiceType: 'Sales');
    final purchases = await rust.listInvoices(invoiceType: 'Purchase');
    return [...sales, ...purchases].map(_invoiceFromBridge).toList();
  }

  @override
  Future<LedgerInvoice> createInvoice(
    InvoiceDraft draft, {
    bool post = false,
  }) async {
    await _ensureReady();
    final invoice = await rust.createInvoice(
      input: _invoiceInputFromDraft(draft),
      post: post,
    );
    return _invoiceFromBridge(invoice);
  }

  @override
  Future<LedgerInvoice> updateInvoice(String id, InvoiceDraft draft) async {
    await _ensureReady();
    final invoice = await rust.updateInvoice(
      id: id,
      input: _invoiceInputFromDraft(draft),
    );
    return _invoiceFromBridge(invoice);
  }

  @override
  Future<LedgerInvoice> postInvoice(String id) async {
    await _ensureReady();
    return _invoiceFromBridge(await rust.postInvoice(id: id));
  }

  @override
  Future<void> deleteInvoice(String id) async {
    await _ensureReady();
    await rust.deleteInvoice(id: id);
  }

  @override
  Future<List<LedgerReturn>> loadSalesReturns() async {
    await _ensureReady();
    final returns = await rust.listSalesReturns();
    return returns.map(_salesReturnFromBridge).toList();
  }

  @override
  Future<List<LedgerReturn>> loadPurchaseReturns() async {
    await _ensureReady();
    final returns = await rust.listPurchaseReturns();
    return returns.map(_purchaseReturnFromBridge).toList();
  }

  @override
  Future<LedgerReturn> createSalesReturn(ReturnDraft draft) async {
    await _ensureReady();
    final result = await rust.createSalesReturn(
      input: _returnInputFromDraft(draft),
    );
    return _salesReturnFromBridge(result);
  }

  @override
  Future<LedgerReturn> createPurchaseReturn(ReturnDraft draft) async {
    await _ensureReady();
    final result = await rust.createPurchaseReturn(
      input: _returnInputFromDraft(draft),
    );
    return _purchaseReturnFromBridge(result);
  }

  @override
  Future<List<LedgerPayment>> loadPayments() async {
    await _ensureReady();
    final payments = await rust.listPayments();
    return payments
        .map(
          (payment) => LedgerPayment(
            id: payment.id,
            voucherNumber: payment.voucherNumber,
            paymentType: payment.paymentType,
            amount: payment.amount,
            currency: payment.currencyCode,
            exchangeRate: payment.exchangeRate,
            paymentDate: payment.paymentDate,
            journalEntryNumber: payment.journalEntryNumber,
            customerId: payment.customerId,
            customerName: payment.customerName,
            supplierId: payment.supplierId,
            supplierName: payment.supplierName,
            reference: payment.reference,
            notes: payment.notes,
          ),
        )
        .toList();
  }

  @override
  Future<LedgerPayment> createPayment(PaymentDraft draft) async {
    await _ensureReady();
    final payment = await rust.createPayment(
      input: _paymentInputFromDraft(draft),
    );
    return _paymentFromBridge(payment);
  }

  @override
  Future<LedgerPayment> updatePayment(String id, PaymentDraft draft) async {
    await _ensureReady();
    final payment = await rust.updatePayment(
      id: id,
      input: _paymentInputFromDraft(draft),
    );
    return _paymentFromBridge(payment);
  }

  @override
  Future<void> deletePayment(String id) async {
    await _ensureReady();
    await rust.deletePayment(id: id);
  }

  @override
  Future<List<LedgerAccount>> loadExpenseItems() async {
    await _ensureReady();
    final items = await rust.listExpenseItems();
    return items.map(_accountFromBridge).toList();
  }

  @override
  Future<void> createExpenseItem(ExpenseItemDraft draft) async {
    await _ensureReady();
    await rust.createExpenseItem(input: _expenseItemInput(draft));
  }

  @override
  Future<void> updateExpenseItem(ExpenseItemDraft draft) async {
    await _ensureReady();
    await rust.updateExpenseItem(input: _expenseItemInput(draft));
  }

  @override
  Future<void> deleteExpenseItem(String id) async {
    await _ensureReady();
    await rust.deleteExpenseItem(id: id);
  }
}

LedgerAccount _accountFromBridge(rust.AccountItem account) {
  return LedgerAccount(
    id: account.id,
    code: account.code,
    nameAr: account.nameAr,
    nameEn: account.nameEn,
    accountType: account.accountType,
    currency: account.currency,
    balance: account.balance,
    isFinal: account.isFinal,
    isActive: account.isActive,
    purpose: account.purpose,
    parentId: account.parentId,
    category: account.category,
    level: account.level,
    openingBalance: account.openingBalance,
    debit: account.debit,
    credit: account.credit,
    notes: account.notes,
    isDefault: account.isDefault,
  );
}

LedgerInvoice _invoiceFromBridge(rust.InvoiceView invoice) {
  return LedgerInvoice(
    id: invoice.id,
    number: invoice.invoiceNumber,
    invoiceType: invoice.invoiceType,
    partyName: invoice.partyName,
    partyId: invoice.partyId,
    status: invoice.status,
    lines: invoice.lines
        .map(
          (line) => LedgerInvoiceLine(
            materialId: line.materialId,
            materialName: line.materialName,
            quantity: line.quantity,
            unitPrice: line.unitPrice,
            unitId: line.unitId,
            conversionFactor: line.conversionFactor,
            discountPercent: line.discountPercent,
            lineTotal: line.lineTotal,
            code: line.code,
            barcode: line.barcode,
            categoryName: line.categoryName,
            notes: line.notes,
          ),
        )
        .toList(),
    taxAmount: invoice.taxAmount,
    discountAmount: invoice.discountAmount,
    extraCosts: invoice.extraCosts,
    subtotal: invoice.subtotalAmount,
    total: invoice.totalAmount,
    amountPaid: invoice.amountPaid,
    remaining: invoice.remainingAmount,
    paymentMethod: invoice.paymentMethod,
    issuedAt: invoice.issuedAt,
    currency: invoice.currencyCode,
    notes: invoice.notes,
  );
}

LedgerReturn _salesReturnFromBridge(rust.ReturnView value) {
  return LedgerReturn(
    id: value.id,
    number: value.returnNumber,
    partyId: value.partyId,
    partyName: value.partyName,
    returnDate: value.returnDate,
    total: value.totalAmount,
    notes: value.notes,
    lines: value.lines
        .map(
          (line) => LedgerReturnLine(
            materialId: line.materialId,
            materialName: line.materialName,
            quantity: line.quantity,
            unitPrice: line.unitPrice,
            unitId: line.unitId,
            lineTotal: line.lineTotal,
          ),
        )
        .toList(),
  );
}

LedgerReturn _purchaseReturnFromBridge(rust.ReturnView value) {
  return _salesReturnFromBridge(value);
}

LedgerPayment _paymentFromBridge(rust.PaymentView payment) {
  return LedgerPayment(
    id: payment.id,
    voucherNumber: payment.voucherNumber,
    paymentType: payment.paymentType,
    amount: payment.amount,
    currency: payment.currencyCode,
    exchangeRate: payment.exchangeRate,
    paymentDate: payment.paymentDate,
    journalEntryNumber: payment.journalEntryNumber,
    customerId: payment.customerId,
    customerName: payment.customerName,
    supplierId: payment.supplierId,
    supplierName: payment.supplierName,
    reference: payment.reference,
    notes: payment.notes,
  );
}

rust.InvoiceInput _invoiceInputFromDraft(InvoiceDraft draft) {
  final isSales = draft.invoiceType == 'Sales';
  return rust.InvoiceInput(
    invoiceType: draft.invoiceType,
    customerId: isSales ? draft.partyId : null,
    customerName: isSales && draft.partyId.isEmpty ? draft.partyName : null,
    supplierId: isSales ? null : draft.partyId,
    supplierName: !isSales && draft.partyId.isEmpty ? draft.partyName : null,
    lines: draft.lines
        .map(
          (line) => rust.InvoiceLineInput(
            materialId: line.materialId,
            quantity: line.quantity,
            unitPrice: line.unitPrice,
            discountPercent: line.discountPercent,
            unitId: line.unitId,
            conversionFactor: line.conversionFactor,
            notes: line.notes,
          ),
        )
        .toList(),
    taxAmount: draft.taxAmount,
    discountAmount: draft.discountAmount,
    extraCosts: draft.extraCosts,
    paymentMethod: draft.paymentMethod,
    amountPaid: draft.amountPaid,
    issuedAt: (draft.issuedAt ?? DateTime.now()).toUtc().toIso8601String(),
    currencyCode: draft.currency,
    exchangeRate: '1',
    notes: draft.notes,
  );
}

rust.ReturnInput _returnInputFromDraft(ReturnDraft draft) {
  return rust.ReturnInput(
    partyId: draft.partyId,
    returnDate: (draft.returnDate ?? DateTime.now()).toUtc().toIso8601String(),
    lines: draft.lines
        .map(
          (line) => rust.ReturnLineInput(
            materialId: line.materialId,
            quantity: line.quantity,
            unitPrice: line.unitPrice,
            unitId: line.unitId,
            notes: line.notes,
          ),
        )
        .toList(),
    notes: draft.notes,
    settlementMode: draft.settlementMode,
    settlementAmount: draft.settlementAmount,
    isPaid: draft.isPaid,
  );
}

rust.PaymentInput _paymentInputFromDraft(PaymentDraft draft) {
  return rust.PaymentInput(
    paymentType: draft.paymentType,
    amount: draft.amount,
    currencyCode: draft.currency,
    exchangeRate: draft.exchangeRate,
    paymentDate: (draft.paymentDate ?? DateTime.now())
        .toUtc()
        .toIso8601String(),
    debitAccountId: draft.debitAccountId,
    creditAccountId: draft.creditAccountId,
    customerId: draft.customerId,
    supplierId: draft.supplierId,
    reference: draft.reference,
    notes: draft.notes,
  );
}

rust.ExpenseItemInput _expenseItemInput(ExpenseItemDraft draft) {
  return rust.ExpenseItemInput(
    id: draft.id,
    code: draft.code,
    nameAr: draft.nameAr,
    nameEn: draft.nameEn,
    openingBalance: draft.openingBalance,
    debit: draft.debit,
    credit: draft.credit,
    currency: draft.currency,
    exchangeRate: draft.exchangeRate,
    notes: draft.notes,
  );
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
