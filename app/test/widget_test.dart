import 'package:accounting_app_flutter/ledger.dart';
import 'package:accounting_app_flutter/main.dart';
import 'package:flutter/material.dart';
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
          unitsCount: 1,
          hasExpiry: false,
        ),
      ];

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
}

void main() {
  testWidgets('shows the ready banner and trial balance from the gateway', (
    tester,
  ) async {
    await tester.pumpWidget(AccountingApp(gateway: _FakeGateway()));
    await tester.pumpAndSettle();

    expect(find.text('جاهز'), findsOneWidget);
    expect(find.textContaining('شركة الاختبار'), findsOneWidget);
    expect(find.text('إجمالي المدين'), findsOneWidget);
    expect(find.text('إجمالي الدائن'), findsOneWidget);
    expect(find.text('100.00'), findsWidgets);

    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();

    expect(find.text('ميزان المراجعة'), findsOneWidget);
    expect(find.text('الصندوق'), findsWidgets);
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
    await tester.pumpWidget(AccountingApp(gateway: _FakeGateway()));
    await tester.pumpAndSettle();

    final saveButton = find.widgetWithText(FilledButton, 'حفظ القيد');
    await tester.dragUntilVisible(
      saveButton,
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(find.text('اختر الحساب المدين والحساب الدائن.'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('opens the master-data tabs from the ready screen', (
    tester,
  ) async {
    await tester.pumpWidget(AccountingApp(gateway: _FakeGateway()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('البيانات الأساسية'));
    await tester.pumpAndSettle();

    expect(find.text('البيانات الأساسية'), findsOneWidget);
    expect(find.text('أحمد محمد'), findsOneWidget);
    expect(find.textContaining('العملاء (1)'), findsOneWidget);

    await tester.tap(find.textContaining('المواد (1)'));
    await tester.pumpAndSettle();

    expect(find.text('قمح'), findsOneWidget);
    expect(find.textContaining('متاح: 50'), findsOneWidget);
  });

  testWidgets('opens the customer form and validates the name', (tester) async {
    await tester.pumpWidget(AccountingApp(gateway: _FakeGateway()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('البيانات الأساسية'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(FloatingActionButton, 'إضافة عميل'),
    );
    await tester.pumpAndSettle();

    expect(find.text('اسم العميل'), findsOneWidget);
    expect(find.text('الرصيد الافتتاحي (مدين)'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'حفظ'));
    await tester.pumpAndSettle();

    expect(find.text('هذا الحقل مطلوب.'), findsOneWidget);
  });

  testWidgets('opens the customer editor with the read-only opening balance', (
    tester,
  ) async {
    await tester.pumpWidget(AccountingApp(gateway: _FakeGateway()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('البيانات الأساسية'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('أحمد محمد'));
    await tester.pumpAndSettle();

    expect(find.text('تعديل عميل'), findsOneWidget);
    expect(
      find.text(
        'لا يمكن تعديل الرصيد الافتتاحي من هنا؛ استخدم قيود التسوية.',
      ),
      findsOneWidget,
    );
    expect(find.text('نشط'), findsOneWidget);
  });

  testWidgets('asks for confirmation before deleting a customer', (
    tester,
  ) async {
    await tester.pumpWidget(AccountingApp(gateway: _FakeGateway()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('البيانات الأساسية'));
    await tester.pumpAndSettle();

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
}
