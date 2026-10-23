import 'package:accounting_app_flutter/ledger.dart';
import 'package:accounting_app_flutter/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeGateway implements LedgerGateway {
  _FakeGateway({this.setupComplete = true});

  final bool setupComplete;

  late final LedgerStatus _status = LedgerStatus(
    setupComplete: setupComplete,
    companyName: 'شركة الاختبار',
    baseCurrencyCode: setupComplete ? 'SYP' : '',
    currencySymbol: setupComplete ? 'ل.س' : '',
    fiscalYearStartMonth: 1,
    accountingStartMode: 'ExistingCompanyMigration',
  );

  @override
  Future<LedgerStatus> loadStatus() async => _status;

  @override
  Future<List<CurrencyOption>> availableCurrencies() async => const [
    CurrencyOption(
      code: 'SYP',
      nameAr: 'ليرة سورية',
      nameEn: 'Syrian Pound',
      symbol: 'ل.س',
      decimals: 2,
    ),
    CurrencyOption(
      code: 'USD',
      nameAr: 'دولار أمريكي',
      nameEn: 'US Dollar',
      symbol: r'$',
      decimals: 2,
    ),
  ];

  @override
  Future<void> setupCompany({
    required String companyName,
    required String baseCurrencyCode,
    String? secondaryCurrencyCode,
    required int fiscalYearStartMonth,
    String? accountingStartMode,
  }) async {}

  @override
  Future<List<LedgerCustomer>> loadCustomers() async => const [
    LedgerCustomer(
      id: 'c1',
      code: 'C001',
      name: 'أحمد محمد',
      phone: '0999999999',
      address: 'دمشق',
      notes: null,
      openingBalance: '150.00',
      balance: '150.00',
      currency: 'SYP',
      isActive: true,
    ),
  ];

  @override
  Future<List<LedgerSupplier>> loadSuppliers() async => const [
    LedgerSupplier(
      id: 's1',
      code: 'S001',
      name: 'مورد النور',
      phone: '0888888888',
      address: 'حلب',
      notes: null,
      openingBalance: '75.00',
      balance: '75.00',
      currency: 'SYP',
      isActive: true,
    ),
  ];

  @override
  Future<List<LedgerMaterial>> loadMaterials() async => const [
    LedgerMaterial(
      id: 'm1',
      code: 'M001',
      name: 'قمح',
      nameEn: 'Wheat',
      barcode: '123456',
      totalAvailable: '50',
      minimumStock: '10',
      averageCost: '12.50',
      purchasePrice: '12.50',
      salePrice: '15.00',
      currency: 'SYP',
      notes: null,
      unitName: 'كغ',
      conversionFactor: '1',
      expiryAlertBeforeDays: 30,
      unitsCount: 2,
      hasExpiry: false,
      categoryIds: ['cat-default'],
      units: [
        LedgerMaterialUnit(
          id: 'u1',
          name: 'كغ',
          conversionFactor: '1',
          barcode: null,
          isBase: true,
        ),
        LedgerMaterialUnit(
          id: 'u2',
          name: 'كرتونة',
          conversionFactor: '12',
          barcode: '789',
          isBase: false,
        ),
      ],
    ),
  ];

  @override
  Future<List<LedgerCategory>> loadCategories() async => const [
    LedgerCategory(
      id: 'cat-default',
      name: 'غير مصنف',
      parentId: null,
      codePrefix: null,
      isActive: true,
      materialCount: 1,
      systemKey: 'inventory.category.uncategorized',
    ),
    LedgerCategory(
      id: 'cat-food',
      name: 'غذائية',
      parentId: null,
      codePrefix: null,
      isActive: true,
      materialCount: 0,
      systemKey: null,
    ),
  ];

  @override
  Future<void> createCategory({
    required String name,
    String? parentId,
    String? codePrefix,
  }) async {}

  @override
  Future<void> updateCategory({
    required String id,
    required String name,
    String? parentId,
    required bool isActive,
    String? codePrefix,
  }) async {}

  @override
  Future<CategoryDeleteSummary> deleteCategory(String id) async =>
      const CategoryDeleteSummary(materialsReassigned: 0, subsDeleted: 0);

  @override
  Future<List<LedgerMaterialUnit>> loadMaterialUnits(String materialId) async =>
      const [
        LedgerMaterialUnit(
          id: 'u1',
          name: 'كغ',
          conversionFactor: '1',
          barcode: null,
          isBase: true,
        ),
        LedgerMaterialUnit(
          id: 'u2',
          name: 'كرتونة',
          conversionFactor: '12',
          barcode: '789',
          isBase: false,
        ),
      ];

  @override
  Future<List<LedgerMaterialUnit>> addMaterialUnit({
    required String materialId,
    required String name,
    required String conversionFactor,
    String? barcode,
  }) async => loadMaterialUnits(materialId);

  @override
  Future<List<LedgerMaterialUnit>> deleteMaterialUnit({
    required String materialId,
    required String unitId,
  }) async => loadMaterialUnits(materialId);

  @override
  Future<LedgerSnapshot> load() async {
    return LedgerSnapshot(
      status: _status,
      accounts: const [
        LedgerAccount(
          id: 'a1',
          code: '1101',
          nameAr: 'الصندوق',
          nameEn: 'Cash',
          accountType: 'Assets',
          currency: 'SYP',
          balance: '0',
          isFinal: true,
          isActive: true,
        ),
        LedgerAccount(
          id: 'a2',
          code: '3101',
          nameAr: 'رأس المال',
          nameEn: 'Capital',
          accountType: 'Equity',
          currency: 'SYP',
          balance: '0',
          isFinal: true,
          isActive: true,
        ),
      ],
      rows: const [
        TrialBalanceRow(
          accountCode: '1101',
          accountName: 'الصندوق',
          accountType: 'Assets',
          debit: '100',
          credit: '0',
        ),
      ],
      totalDebit: '100',
      totalCredit: '100',
    );
  }

  @override
  Future<void> createCustomer({
    required String name,
    String? phone,
    String? address,
    String? notes,
    required String currency,
    required String openingBalance,
  }) async {}

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
  }) async {}

  @override
  Future<void> deleteCustomer(String id) async {}

  @override
  Future<void> createSupplier({
    required String name,
    String? phone,
    String? address,
    String? notes,
    required String currency,
    required String openingBalance,
  }) async {}

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
  }) async {}

  @override
  Future<void> deleteSupplier(String id) async {}

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
  }) async {}

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
  }) async {}

  @override
  Future<void> deleteMaterial(String id) async {}

  @override
  Future<void> createEntry({
    required String debitAccountId,
    required String creditAccountId,
    required String amount,
    required String description,
    required String currency,
  }) async {}

  @override
  Future<List<LedgerInvoice>> loadInvoices() async => const [];

  @override
  Future<LedgerInvoice> createInvoice(
    InvoiceDraft draft, {
    bool post = false,
  }) async => throw UnimplementedError();

  @override
  Future<LedgerInvoice> updateInvoice(String id, InvoiceDraft draft) async =>
      throw UnimplementedError();

  @override
  Future<LedgerInvoice> postInvoice(String id) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteInvoice(String id) async {}

  @override
  Future<List<LedgerReturn>> loadSalesReturns() async => const [];

  @override
  Future<List<LedgerReturn>> loadPurchaseReturns() async => const [];

  @override
  Future<LedgerReturn> createSalesReturn(ReturnDraft draft) async =>
      throw UnimplementedError();

  @override
  Future<LedgerReturn> createPurchaseReturn(ReturnDraft draft) async =>
      throw UnimplementedError();

  @override
  Future<List<LedgerPayment>> loadPayments() async => const [];

  @override
  Future<LedgerPayment> createPayment(PaymentDraft draft) async =>
      throw UnimplementedError();

  @override
  Future<LedgerPayment> updatePayment(String id, PaymentDraft draft) async =>
      throw UnimplementedError();

  @override
  Future<void> deletePayment(String id) async {}

  @override
  Future<List<LedgerAccount>> loadExpenseItems() async => const [];

  @override
  Future<void> createExpenseItem(ExpenseItemDraft draft) async {}

  @override
  Future<void> updateExpenseItem(ExpenseItemDraft draft) async {}

  @override
  Future<void> deleteExpenseItem(String id) async {}
}

/// A gateway that returns one sales invoice, so the invoice table can be
/// exercised with a row.
class _InvoiceGateway extends _FakeGateway {
  _InvoiceGateway();

  @override
  Future<List<LedgerInvoice>> loadInvoices() async => const [
    LedgerInvoice(
      id: 'inv-1',
      number: 'INV-001',
      invoiceType: 'Sales',
      partyName: 'عميل الاختبار',
      status: 'Draft',
      lines: [],
      taxAmount: '0',
      discountAmount: '0',
      extraCosts: '0',
      subtotal: '100',
      total: '100',
      amountPaid: '0',
      remaining: '100',
      paymentMethod: 'Cash',
      issuedAt: '2026-01-05',
      currency: 'SYP',
    ),
  ];
}

Future<void> _pumpWorkspace(
  WidgetTester tester, {
  bool setupComplete = true,
  LedgerGateway? gateway,
}) async {
  tester.view.physicalSize = const Size(1440, 1024);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    AccountingApp(
      gateway: gateway ?? _FakeGateway(setupComplete: setupComplete),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openCustomers(WidgetTester tester) async {
  await tester.tap(find.text('العملاء').first);
  await tester.pumpAndSettle();
}

Future<void> _openMaterials(WidgetTester tester) async {
  await tester.tap(find.text('المواد').first);
  await tester.pumpAndSettle();
}

Future<void> _openJournal(WidgetTester tester) async {
  await tester.tap(find.text('قيود اليومية'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the dashboard metrics and journal from the gateway', (
    tester,
  ) async {
    await _pumpWorkspace(tester);

    expect(find.text('جاهز'), findsOneWidget);
    expect(find.textContaining('شركة الاختبار'), findsWidgets);
    expect(find.text('إجمالي المدين'), findsOneWidget);
    expect(find.text('إجمالي الدائن'), findsOneWidget);
    expect(find.textContaining('100.00'), findsWidgets);

    await _openJournal(tester);

    expect(find.text('ميزان المراجعة'), findsOneWidget);
    expect(find.text('الصندوق'), findsWidgets);
    // The trial balance totals sit in a column-aligned summary row.
    expect(find.text('الإجمالي'), findsOneWidget);
  });

  testWidgets('shows the setup wizard when setup is incomplete', (
    tester,
  ) async {
    await tester.pumpWidget(
      AccountingApp(gateway: _FakeGateway(setupComplete: false)),
    );
    await tester.pumpAndSettle();

    expect(find.text('إعداد الشركة'), findsOneWidget);
    expect(find.text('مرحباً بك'), findsOneWidget);
    expect(find.text('بدء الاستخدام'), findsOneWidget);
    expect(find.text('العملة الأساسية'), findsOneWidget);
    expect(find.text('شهر بداية السنة المالية'), findsOneWidget);
  });

  testWidgets('validates that both accounts are selected', (tester) async {
    await _pumpWorkspace(tester);
    await _openJournal(tester);

    final saveButton = find.widgetWithText(FilledButton, 'حفظ القيد');
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(find.text('اختر الحساب المدين والحساب الدائن.'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('opens customers, suppliers and materials as independent pages', (
    tester,
  ) async {
    await _pumpWorkspace(tester);
    await _openCustomers(tester);

    expect(find.text('العملاء'), findsWidgets);
    expect(find.text('أحمد محمد'), findsOneWidget);

    await tester.tap(find.text('الموردون').first);
    await tester.pumpAndSettle();

    expect(find.text('الموردون'), findsWidgets);
    expect(find.text('مورد النور'), findsOneWidget);
    expect(find.text('أحمد محمد'), findsNothing);

    await _openMaterials(tester);

    expect(find.text('قمح'), findsOneWidget);
    expect(find.textContaining('متاح: 50'), findsOneWidget);
  });

  testWidgets('opens trade documents and expense items from the sidebar', (
    tester,
  ) async {
    await _pumpWorkspace(tester);

    await tester.tap(find.text('فواتير البيع').first);
    await tester.pumpAndSettle();
    expect(
      find.text('إصدار فواتير البيع وترحيلها إلى المخزون والقيود.'),
      findsOneWidget,
    );
    expect(find.text('لا توجد فواتير بعد'), findsOneWidget);

    await tester.tap(find.text('بنود المصاريف').first);
    await tester.pumpAndSettle();
    expect(
      find.text('إدارة بنود المصاريف وإصدار سندات الصرف.'),
      findsOneWidget,
    );
    expect(find.text('لا توجد بنود مصاريف'), findsOneWidget);
  });

  testWidgets('opens the invoice details when a table row is tapped', (
    tester,
  ) async {
    await _pumpWorkspace(tester, gateway: _InvoiceGateway());
    await tester.tap(find.text('فواتير البيع').first);
    await tester.pumpAndSettle();

    expect(find.text('INV-001'), findsOneWidget);
    await tester.tap(find.text('INV-001'));
    await tester.pumpAndSettle();

    expect(find.text('فاتورة INV-001'), findsOneWidget);
    // The action buttons of the invoice row must fit their column.
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens the sales invoice editor and validates the party', (
    tester,
  ) async {
    await _pumpWorkspace(tester);
    await tester.tap(find.text('فواتير البيع').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('إنشاء فاتورة'));
    await tester.pumpAndSettle();

    expect(find.text('فاتورة بيع جديدة'), findsOneWidget);
    expect(find.text('بيانات الفاتورة'), findsOneWidget);
    expect(find.text('بنود الفاتورة'), findsOneWidget);
    expect(find.text('العميل'), findsOneWidget);

    await tester.tap(find.text('حفظ كمسودة'));
    await tester.pumpAndSettle();

    expect(find.text('اختر العميل أولًا.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the returns page summary and empty state', (tester) async {
    await _pumpWorkspace(tester);
    await tester.tap(find.text('مرتجعات البيع').first);
    await tester.pumpAndSettle();

    expect(find.text('عدد المرتجعات'), findsOneWidget);
    expect(find.text('قيمة المرتجعات'), findsOneWidget);
    expect(find.text('لا توجد مرتجعات'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the receipts page summary and empty state', (
    tester,
  ) async {
    await _pumpWorkspace(tester);
    await tester.tap(find.text('المقبوضات').first);
    await tester.pumpAndSettle();

    expect(find.text('عدد السندات'), findsOneWidget);
    expect(find.text('إجمالي المبلغ'), findsOneWidget);
    expect(find.text('لا توجد سندات'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens category management from the materials page', (
    tester,
  ) async {
    await _pumpWorkspace(tester);
    await _openMaterials(tester);
    await tester.tap(find.byTooltip('تصنيفات المواد'));
    await tester.pumpAndSettle();

    expect(find.text('تصنيفات المواد'), findsOneWidget);
    expect(find.text('غير مصنف'), findsOneWidget);
    expect(find.text('غذائية'), findsOneWidget);
    expect(find.textContaining('تصنيف نظامي'), findsOneWidget);

    await tester.tap(find.text('تصنيف جديد'));
    await tester.pumpAndSettle();

    expect(find.text('اسم التصنيف'), findsOneWidget);
    expect(find.text('التصنيف الأب'), findsOneWidget);
  });

  testWidgets('opens the opening-balance screen and edits a customer', (
    tester,
  ) async {
    await _pumpWorkspace(tester);
    await _openCustomers(tester);
    await tester.tap(find.byTooltip('الأرصدة الافتتاحية'));
    await tester.pumpAndSettle();

    expect(find.text('الأرصدة الافتتاحية'), findsOneWidget);
    expect(find.text('العملاء'), findsOneWidget);
    expect(find.text('الموردون'), findsOneWidget);
    expect(find.textContaining('الافتتاحي: 150.00'), findsOneWidget);

    await tester.tap(find.byTooltip('تعديل الرصيد الافتتاحي').first);
    await tester.pumpAndSettle();

    expect(find.text('الرصيد الافتتاحي — أحمد محمد'), findsOneWidget);
    expect(find.text('المبلغ (SYP)'), findsOneWidget);
  });

  testWidgets('opens material units from the material row actions', (
    tester,
  ) async {
    await _pumpWorkspace(tester);
    await _openMaterials(tester);

    await tester.tap(find.byTooltip('إجراءات').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('الوحدات'));
    await tester.pumpAndSettle();

    expect(find.text('وحدات: قمح'), findsOneWidget);
    expect(find.text('كغ'), findsOneWidget);
    expect(find.text('كرتونة'), findsOneWidget);
    expect(find.text('أساسية'), findsOneWidget);
  });

  testWidgets('shows categories and extra units in the material form', (
    tester,
  ) async {
    await _pumpWorkspace(tester);
    await _openMaterials(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'إضافة مادة'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('التصنيفات'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('غذائية'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('وحدات إضافية'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('إضافة وحدة'), findsOneWidget);
  });

  testWidgets('opens the customer form and validates the name', (tester) async {
    await _pumpWorkspace(tester);
    await _openCustomers(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'إضافة عميل'));
    await tester.pumpAndSettle();

    expect(find.text('اسم العميل'), findsOneWidget);
    expect(find.text('الرصيد الافتتاحي (مدين)'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'حفظ'));
    await tester.pumpAndSettle();

    expect(find.text('هذا الحقل مطلوب.'), findsOneWidget);
  });

  testWidgets('opens the customer editor with the opening-balance hint', (
    tester,
  ) async {
    await _pumpWorkspace(tester);
    await _openCustomers(tester);

    await tester.tap(find.text('أحمد محمد'));
    await tester.pumpAndSettle();

    expect(find.text('تعديل عميل'), findsOneWidget);
    expect(
      find.text('يمكن تعديل الرصيد الافتتاحي من شاشة «الأرصدة الافتتاحية».'),
      findsOneWidget,
    );
    expect(find.text('نشط'), findsOneWidget);
  });

  testWidgets('asks for confirmation before deleting a customer', (
    tester,
  ) async {
    await _pumpWorkspace(tester);
    await _openCustomers(tester);

    await tester.tap(find.byTooltip('إجراءات').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف').last);
    await tester.pumpAndSettle();

    expect(find.text('حذف العميل'), findsOneWidget);
    expect(find.textContaining('أحمد محمد'), findsWidgets);

    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    expect(find.text('حذف العميل'), findsNothing);
  });

  testWidgets('toggles the dark theme from the top bar', (tester) async {
    await _pumpWorkspace(tester);

    expect(find.byTooltip('الوضع الداكن'), findsOneWidget);

    // B1-b: default themeMode is `system`. First tap: system → light.
    await tester.tap(find.byTooltip('الوضع الداكن'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('الوضع الداكن'), findsOneWidget);

    // Second tap: light → dark.
    await tester.tap(find.byTooltip('الوضع الداكن'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('الوضع الفاتح'), findsOneWidget);
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
  });

  testWidgets('opens the command palette and runs a command', (tester) async {
    await _pumpWorkspace(tester);

    await tester.tap(find.text('بحث شامل…'));
    await tester.pumpAndSettle();

    expect(find.text('ابحث عن صفحة أو إجراء…'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'تحديث');
    await tester.pumpAndSettle();

    expect(find.text('تحديث البيانات'), findsOneWidget);
    await tester.tap(find.text('تحديث البيانات'));
    await tester.pumpAndSettle();

    expect(find.text('ابحث عن صفحة أو إجراء…'), findsNothing);
    expect(find.text('لوحة التحكم'), findsWidgets);
  });

  testWidgets('uses a drawer and keeps pages usable on narrow screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(AccountingApp(gateway: _FakeGateway()));
    await tester.pumpAndSettle();

    expect(find.byTooltip('القائمة'), findsOneWidget);
    expect(find.text('لوحة التحكم'), findsWidgets);

    await tester.tap(find.byTooltip('القائمة'));
    await tester.pumpAndSettle();
    expect(find.text('البيانات الأساسية'), findsWidgets);

    await tester.tap(find.text('قيود اليومية').last);
    await tester.pumpAndSettle();

    expect(find.text('ميزان المراجعة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the customers table usable on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(AccountingApp(gateway: _FakeGateway()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('القائمة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('العملاء').last);
    await tester.pumpAndSettle();

    expect(find.text('العملاء'), findsWidgets);
    expect(find.text('أحمد محمد'), findsOneWidget);
    expect(find.byTooltip('إعدادات الأعمدة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('returns to the previous section with the back button', (
    tester,
  ) async {
    await _pumpWorkspace(tester);
    await _openCustomers(tester);
    await tester.tap(find.text('الموردون').first);
    await tester.pumpAndSettle();
    expect(find.text('مورد النور'), findsOneWidget);

    await tester.tap(find.byTooltip('رجوع'));
    await tester.pumpAndSettle();

    expect(find.text('أحمد محمد'), findsOneWidget);
    expect(find.text('مورد النور'), findsNothing);
  });

  testWidgets('handles the system back button between sections', (
    tester,
  ) async {
    await _pumpWorkspace(tester);
    await _openCustomers(tester);
    await tester.tap(find.text('الموردون').first);
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('أحمد محمد'), findsOneWidget);
    expect(find.text('مورد النور'), findsNothing);
  });

  testWidgets('navigates back with Alt+Left and Escape', (tester) async {
    await _pumpWorkspace(tester);
    await _openCustomers(tester);
    await tester.tap(find.text('الموردون').first);
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pumpAndSettle();

    expect(find.text('أحمد محمد'), findsOneWidget);

    await tester.tap(find.text('الموردون').first);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('أحمد محمد'), findsOneWidget);
  });

  testWidgets('closes the form after a successful save without a warning', (
    tester,
  ) async {
    await _pumpWorkspace(tester);
    await _openCustomers(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'إضافة عميل'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'عميل جديد');
    await tester.pumpAndSettle();
    final saveButton = find.widgetWithText(FilledButton, 'حفظ');
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(find.text('تغييرات غير محفوظة'), findsNothing);
    expect(find.widgetWithText(AppBar, 'إضافة عميل'), findsNothing);
    expect(find.text('تمت إضافة العميل.'), findsOneWidget);
  });

  testWidgets('warns before discarding unsaved form changes', (tester) async {
    await _pumpWorkspace(tester);
    await _openCustomers(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'إضافة عميل'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'عميل جديد');
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('تغييرات غير محفوظة'), findsOneWidget);

    await tester.tap(find.text('البقاء'));
    await tester.pumpAndSettle();
    expect(find.text('إضافة عميل'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('مغادرة دون حفظ'));
    await tester.pumpAndSettle();

    expect(find.text('أحمد محمد'), findsOneWidget);
  });
}
