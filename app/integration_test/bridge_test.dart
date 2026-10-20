import 'dart:io';

import 'package:accounting_app_flutter_isolates/accounting_app_flutter_isolates.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Dart -> Rust: open SQLite, create a balanced entry, read trial balance',
    (tester) async {
      await RustLib.init();

      final tempDir = await Directory.systemTemp.createTemp('accounting_fr_');
      final dbPath = '${tempDir.path}${Platform.pathSeparator}ledger.db';

      await initApp(dbPath: dbPath);

      expect(
        await isSetupComplete(),
        isFalse,
        reason: 'a fresh database must start in the setup state',
      );

      final setup = await setupCompany(
        input: SetupCompanyInput(
          companyName: 'شركة الاختبار',
          baseCurrencyCode: 'SYP',
          secondaryCurrencyCode: 'USD',
          fiscalYearStartMonth: 1,
          accountingStartMode: null,
        ),
      );
      expect(setup.setupComplete, isTrue);
      expect(setup.companyName, 'شركة الاختبار');
      expect(setup.baseCurrencyCode, 'SYP');
      expect(await isSetupComplete(), isTrue);

      final status = await getSetupStatus();
      expect(status.setupComplete, isTrue);
      expect(status.companyName, 'شركة الاختبار');
      expect(status.baseCurrencyCode, 'SYP');

      final accounts = await listAccounts();
      expect(
        accounts,
        isNotEmpty,
        reason: 'migrations must seed the chart of accounts',
      );

      final customers = await listCustomers();
      expect(
        customers.any((customer) => customer.code == '0'),
        isTrue,
        reason: 'migrations must seed the cash customer',
      );

      final suppliers = await listSuppliers();
      expect(
        suppliers.any((supplier) => supplier.code == '0'),
        isTrue,
        reason: 'migrations must seed the cash supplier',
      );

      expect(await listMaterials(), isEmpty);

      final leaves = accounts.where((a) => a.isActive && a.isFinal).toList();
      expect(leaves.length, greaterThanOrEqualTo(2));

      final debitAccount = leaves[0];
      final creditAccount = leaves[1];
      final currency = setup.baseCurrencyCode;

      // Prove that the unified ApiError crosses the FFI boundary as a typed
      // object, not as an opaque string.
      try {
        await createJournalEntry(
          input: CreateJournalEntryInput(
            journalType: 'GeneralJournal',
            entryDate: DateTime.now().toUtc().toIso8601String(),
            description: 'قيد غير صالح',
            lines: [
              JournalLineInput(
                accountId: 'not-a-uuid',
                currency: currency,
                fxRate: '1',
                debit: '1',
                credit: '0',
                description: 'حساب غير صالح',
              ),
              JournalLineInput(
                accountId: creditAccount.id,
                currency: currency,
                fxRate: '1',
                debit: '0',
                credit: '1',
                description: 'حساب غير صالح',
              ),
            ],
          ),
        );
        fail('expected an ApiError for the invalid account id');
      } on ApiError catch (error) {
        expect(error.code, isNotEmpty);
        expect(error.message, isNotEmpty);
      }

      final entry = await createJournalEntry(
        input: CreateJournalEntryInput(
          journalType: 'GeneralJournal',
          entryDate: DateTime.now().toUtc().toIso8601String(),
          description: 'قيد اختبار الجسر',
          lines: [
            JournalLineInput(
              accountId: debitAccount.id,
              currency: currency,
              fxRate: '1',
              debit: '125.50',
              credit: '0',
              description: 'اختبار',
            ),
            JournalLineInput(
              accountId: creditAccount.id,
              currency: currency,
              fxRate: '1',
              debit: '0',
              credit: '125.50',
              description: 'اختبار',
            ),
          ],
        ),
      );

      expect(entry.entryNumber, isNotEmpty);
      expect(double.parse(entry.totalDebit), 125.50);
      expect(double.parse(entry.totalCredit), 125.50);

      final posted = await postJournalEntry(entryId: entry.id);
      expect(posted.status, 'Posted');

      final trial = await trialBalance();
      expect(trial.lines, isNotEmpty);
      expect(double.parse(trial.totalDebit), double.parse(trial.totalCredit));
      expect(double.parse(trial.totalDebit), greaterThanOrEqualTo(125.50));

      // Customer CRUD: create, list, update and delete through the bridge.
      final customer = await createCustomer(
        input: CustomerCreateInput(
          name: 'عميل اختبار الجسر',
          phone: '0990000000',
          address: 'دمشق',
          notes: 'أُنشئ من اختبار التكامل',
          currency: currency,
          openingBalance: '0',
        ),
      );
      expect(customer.id, isNotEmpty);
      expect(customer.code, isNotEmpty);
      expect(
        (await listCustomers()).any((item) => item.id == customer.id),
        isTrue,
      );

      final updatedCustomer = await updateCustomer(
        input: CustomerUpdateInput(
          id: customer.id,
          code: customer.code,
          name: 'عميل اختبار الجسر (محدّث)',
          phone: customer.phone,
          address: customer.address,
          notes: customer.notes,
          isActive: true,
        ),
      );
      expect(updatedCustomer.name, contains('محدّث'));

      await deleteCustomer(id: customer.id);
      expect(
        (await listCustomers()).any((item) => item.id == customer.id),
        isFalse,
      );

      // Supplier CRUD follows the same bridge path.
      final supplier = await createSupplier(
        input: SupplierCreateInput(
          name: 'مورد اختبار الجسر',
          phone: '0980000000',
          address: 'حلب',
          notes: null,
          currency: currency,
          openingBalance: '0',
        ),
      );
      expect(supplier.code, isNotEmpty);

      final updatedSupplier = await updateSupplier(
        input: SupplierUpdateInput(
          id: supplier.id,
          code: supplier.code,
          name: 'مورد اختبار الجسر (محدّث)',
          phone: supplier.phone,
          address: supplier.address,
          notes: supplier.notes,
          isActive: false,
        ),
      );
      expect(updatedSupplier.name, contains('محدّث'));
      expect(updatedSupplier.isActive, isFalse);

      final reactivatedSupplier = await updateSupplier(
        input: SupplierUpdateInput(
          id: supplier.id,
          code: supplier.code,
          name: updatedSupplier.name,
          phone: updatedSupplier.phone,
          address: updatedSupplier.address,
          notes: updatedSupplier.notes,
          isActive: true,
        ),
      );
      expect(reactivatedSupplier.isActive, isTrue);

      await deleteSupplier(id: supplier.id);
      expect(
        (await listSuppliers()).any((item) => item.id == supplier.id),
        isFalse,
      );

      // Category CRUD is the first half of the inventory metadata slice.
      final category = await createCategory(
        input: CategoryCreateInput(
          name: 'تصنيف اختبار الجسر',
          parentId: null,
          codePrefix: null,
        ),
      );
      expect(category.id, isNotEmpty);
      expect(
        (await listCategories()).any((item) => item.id == category.id),
        isTrue,
      );
      final updatedCategory = await updateCategory(
        input: CategoryUpdateInput(
          id: category.id,
          name: 'تصنيف اختبار الجسر (محدّث)',
          parentId: null,
          isActive: true,
          codePrefix: null,
        ),
      );
      expect(updatedCategory.name, contains('محدّث'));

      // Material CRUD, including categories, a second unit at creation time,
      // automatic code generation and price updates.
      final material = await createMaterial(
        input: MaterialCreateInput(
          name: 'مادة اختبار الجسر',
          nameEn: 'Bridge test material',
          barcode: 'BRIDGE-001',
          code: null,
          minimumStock: '5',
          unitName: 'كغ',
          conversionFactor: '1',
          extraUnits: [
            MaterialUnitInput(
              name: 'كرتونة',
              conversionFactor: '12',
              barcode: 'BRIDGE-BOX',
            ),
          ],
          categoryIds: [category.id],
          purchasePrice: '10',
          salePrice: '12',
          currency: currency,
          notes: null,
          hasExpiry: false,
          expiryAlertBeforeDays: 30,
        ),
      );
      expect(material.id, isNotEmpty);
      expect(material.code, isNotEmpty);
      expect(material.code, isNot('AUTO'));
      expect(material.unitName, 'كغ');
      expect(material.categoryIds, contains(category.id));
      expect(material.units.length, 2);
      expect(material.units.where((unit) => unit.isBase).length, 1);

      final unitsAfterLoad = await listMaterialUnits(materialId: material.id);
      expect(unitsAfterLoad.length, 2);

      final unitsAfterAdd = await addMaterialUnit(
        input: MaterialUnitCreateInput(
          materialId: material.id,
          name: 'كيس',
          conversionFactor: '5',
          barcode: 'BRIDGE-BAG',
        ),
      );
      expect(unitsAfterAdd.length, 3);
      final addedUnit = unitsAfterAdd.firstWhere((unit) => unit.name == 'كيس');

      try {
        await addMaterialUnit(
          input: MaterialUnitCreateInput(
            materialId: material.id,
            name: 'كيس',
            conversionFactor: '5',
            barcode: null,
          ),
        );
        fail('expected duplicate unit rejection');
      } on ApiError catch (error) {
        expect(error.code, 'duplicate_unit');
      }

      final unitsAfterDelete = await deleteMaterialUnit(
        materialId: material.id,
        unitId: addedUnit.id,
      );
      expect(unitsAfterDelete.length, 2);

      final baseUnit = unitsAfterDelete.firstWhere((unit) => unit.isBase);
      try {
        await deleteMaterialUnit(materialId: material.id, unitId: baseUnit.id);
        fail('expected base unit deletion to be rejected');
      } on ApiError catch (error) {
        expect(error.code, 'base_unit_locked');
      }

      final updatedMaterial = await updateMaterial(
        input: MaterialUpdateInput(
          id: material.id,
          name: 'مادة اختبار الجسر (محدّثة)',
          nameEn: material.nameEn,
          barcode: material.barcode,
          code: material.code,
          minimumStock: '8',
          categoryIds: [category.id],
          notes: 'تحديث من اختبار التكامل',
          purchasePrice: '11',
          salePrice: '13',
          currency: currency,
          hasExpiry: false,
          expiryAlertBeforeDays: 30,
        ),
      );
      expect(updatedMaterial.name, contains('محدّثة'));
      expect(updatedMaterial.minimumStock, '8');
      expect(updatedMaterial.categoryIds, contains(category.id));

      await deleteMaterial(id: material.id);
      expect(
        (await listMaterials()).any((item) => item.id == material.id),
        isFalse,
      );

      final deletedCategory = await deleteCategory(id: category.id);
      expect(deletedCategory.materialsReassigned, 0);
      expect(
        (await listCategories()).any((item) => item.id == category.id),
        isFalse,
      );

      // Opening balances are updated through the dedicated update path. A
      // positive customer amount is a debit, a positive supplier amount is a
      // credit. These rows are intentionally not deleted: the adjustment journal
      // makes them part of the ledger history.
      final openingCustomer = await createCustomer(
        input: CustomerCreateInput(
          name: 'عميل افتتاحي للاختبار',
          phone: null,
          address: null,
          notes: null,
          currency: currency,
          openingBalance: '0',
        ),
      );
      final customerWithOpening = await updateCustomer(
        input: CustomerUpdateInput(
          id: openingCustomer.id,
          code: openingCustomer.code,
          name: openingCustomer.name,
          phone: openingCustomer.phone,
          address: openingCustomer.address,
          notes: openingCustomer.notes,
          openingBalance: '125',
          isActive: true,
        ),
      );
      expect(double.parse(customerWithOpening.openingBalance), 125);
      expect(double.parse(customerWithOpening.balance), 125);

      final openingSupplier = await createSupplier(
        input: SupplierCreateInput(
          name: 'مورد افتتاحي للاختبار',
          phone: null,
          address: null,
          notes: null,
          currency: currency,
          openingBalance: '0',
        ),
      );
      final supplierWithOpening = await updateSupplier(
        input: SupplierUpdateInput(
          id: openingSupplier.id,
          code: openingSupplier.code,
          name: openingSupplier.name,
          phone: openingSupplier.phone,
          address: openingSupplier.address,
          notes: openingSupplier.notes,
          openingBalance: '50',
          isActive: true,
        ),
      );
      expect(double.parse(supplierWithOpening.openingBalance), 50);
      expect(double.parse(supplierWithOpening.balance), 50);

      // Trade documents: a sales invoice, a sales return, a purchase invoice
      // and a purchase return all go through the same bridge that the UI uses.
      final tradeMaterial = await createMaterial(
        input: MaterialCreateInput(
          name: 'مادة الفواتير',
          nameEn: 'Invoice material',
          barcode: 'BRIDGE-INVOICE-001',
          code: null,
          minimumStock: '0',
          unitName: 'قطعة',
          conversionFactor: '1',
          extraUnits: [],
          categoryIds: [],
          purchasePrice: '10',
          salePrice: '20',
          currency: currency,
          notes: null,
          hasExpiry: false,
          expiryAlertBeforeDays: 30,
        ),
      );
      final baseTradeUnit = tradeMaterial.units.firstWhere(
        (unit) => unit.isBase,
      );

      // Sales invoices require available stock. Receive an initial purchase
      // first, then exercise the sales path against real inventory lots.
      final openingStock = await createInvoice(
        input: InvoiceInput(
          invoiceType: 'Purchase',
          customerId: null,
          customerName: null,
          supplierId: openingSupplier.id,
          supplierName: null,
          lines: [
            InvoiceLineInput(
              materialId: tradeMaterial.id,
              quantity: '10',
              unitPrice: '10',
              discountPercent: '0',
              unitId: baseTradeUnit.id,
              conversionFactor: '1',
              warehouseId: null,
              notes: null,
            ),
          ],
          taxAmount: '0',
          discountAmount: '0',
          extraCosts: '0',
          paymentMethod: 'Deferred',
          amountPaid: '0',
          issuedAt: DateTime.now().toUtc().toIso8601String(),
          currencyCode: currency,
          exchangeRate: '1',
          notes: 'رصيد افتتاحي للمخزون',
        ),
        post: true,
      );
      expect(openingStock.status, 'Posted');

      final salesInvoice = await createInvoice(
        input: InvoiceInput(
          invoiceType: 'Sales',
          customerId: openingCustomer.id,
          customerName: null,
          supplierId: null,
          supplierName: null,
          lines: [
            InvoiceLineInput(
              materialId: tradeMaterial.id,
              quantity: '2',
              unitPrice: '20',
              discountPercent: '0',
              unitId: baseTradeUnit.id,
              conversionFactor: '1',
              warehouseId: null,
              notes: null,
            ),
          ],
          taxAmount: '0',
          discountAmount: '0',
          extraCosts: '0',
          paymentMethod: 'Deferred',
          amountPaid: '0',
          issuedAt: DateTime.now().toUtc().toIso8601String(),
          currencyCode: currency,
          exchangeRate: '1',
          notes: 'فاتورة اختبار',
        ),
        post: false,
      );
      expect(salesInvoice.status, 'Draft');
      expect(double.parse(salesInvoice.totalAmount), 40);
      expect(salesInvoice.invoiceNumber, isNotEmpty);

      final postedSales = await postInvoice(id: salesInvoice.id).catchError((
        Object error,
      ) {
        if (error is ApiError) {
          // ignore: avoid_print
          print('postInvoice failed: ${error.code}: ${error.message}');
        }
        throw error;
      });
      expect(postedSales.status, 'Posted');
      expect(postedSales.lines, hasLength(1));
      expect(
        (await listInvoices(
          invoiceType: 'Sales',
        )).any((invoice) => invoice.id == salesInvoice.id),
        isTrue,
      );

      // The Flutter editor defaults to Cash; verify the core settles the
      // invoice and reports no remaining balance for that path too.
      final cashSale = await createInvoice(
        input: InvoiceInput(
          invoiceType: 'Sales',
          customerId: openingCustomer.id,
          customerName: null,
          supplierId: null,
          supplierName: null,
          lines: [
            InvoiceLineInput(
              materialId: tradeMaterial.id,
              quantity: '1',
              unitPrice: '20',
              discountPercent: '0',
              unitId: baseTradeUnit.id,
              conversionFactor: '1',
              warehouseId: null,
              notes: null,
            ),
          ],
          taxAmount: '0',
          discountAmount: '0',
          extraCosts: '0',
          paymentMethod: 'Cash',
          amountPaid: '20',
          issuedAt: DateTime.now().toUtc().toIso8601String(),
          currencyCode: currency,
          exchangeRate: '1',
          notes: 'بيع نقدي',
        ),
        post: true,
      );
      expect(cashSale.status, 'Posted');
      expect(double.parse(cashSale.totalAmount), 20);
      expect(double.parse(cashSale.amountPaid), 20);
      expect(double.parse(cashSale.remainingAmount), 0);

      final salesReturn = await createSalesReturn(
        input: ReturnInput(
          partyId: openingCustomer.id,
          returnDate: DateTime.now().toUtc().toIso8601String(),
          lines: [
            ReturnLineInput(
              materialId: tradeMaterial.id,
              quantity: '1',
              unitPrice: '20',
              unitId: baseTradeUnit.id,
              notes: null,
              invoiceLineId: null,
            ),
          ],
          notes: 'مرتجع اختبار',
          settlementMode: 'deduct_from_debt',
          settlementAmount: null,
          isPaid: false,
        ),
      );
      expect(salesReturn.returnNumber, isNotEmpty);
      expect(double.parse(salesReturn.totalAmount), 20);
      expect(
        (await listSalesReturns()).any((item) => item.id == salesReturn.id),
        isTrue,
      );

      final purchaseInvoice = await createInvoice(
        input: InvoiceInput(
          invoiceType: 'Purchase',
          customerId: null,
          customerName: null,
          supplierId: openingSupplier.id,
          supplierName: null,
          lines: [
            InvoiceLineInput(
              materialId: tradeMaterial.id,
              quantity: '3',
              unitPrice: '10',
              discountPercent: '0',
              unitId: baseTradeUnit.id,
              conversionFactor: '1',
              warehouseId: null,
              notes: null,
            ),
          ],
          taxAmount: '0',
          discountAmount: '0',
          extraCosts: '0',
          paymentMethod: 'Deferred',
          amountPaid: '0',
          issuedAt: DateTime.now().toUtc().toIso8601String(),
          currencyCode: currency,
          exchangeRate: '1',
          notes: null,
        ),
        post: true,
      );
      expect(purchaseInvoice.status, 'Posted');
      expect(double.parse(purchaseInvoice.totalAmount), 30);
      expect(
        (await listInvoices(
          invoiceType: 'Purchase',
        )).any((invoice) => invoice.id == purchaseInvoice.id),
        isTrue,
      );

      final purchaseReturn = await createPurchaseReturn(
        input: ReturnInput(
          partyId: openingSupplier.id,
          returnDate: DateTime.now().toUtc().toIso8601String(),
          lines: [
            ReturnLineInput(
              materialId: tradeMaterial.id,
              quantity: '1',
              unitPrice: '10',
              unitId: baseTradeUnit.id,
              notes: null,
              invoiceLineId: null,
            ),
          ],
          notes: null,
          settlementMode: 'deduct_from_debt',
          settlementAmount: null,
          isPaid: false,
        ),
      );
      expect(double.parse(purchaseReturn.totalAmount), 10);
      expect(
        (await listPurchaseReturns()).any(
          (item) => item.id == purchaseReturn.id,
        ),
        isTrue,
      );

      // Receipts, payments and expense vouchers share the payment bridge.
      final receipt = await createPayment(
        input: PaymentInput(
          paymentType: 'Receipt',
          amount: '5',
          currencyCode: currency,
          exchangeRate: '1',
          paymentDate: DateTime.now().toUtc().toIso8601String(),
          debitAccountId: null,
          creditAccountId: null,
          customerId: openingCustomer.id,
          supplierId: null,
          reference: 'BRIDGE-RCV-1',
          notes: null,
        ),
      );
      expect(receipt.voucherNumber, startsWith('RCV'));
      expect(receipt.journalEntryNumber, isNotNull);
      expect(
        (await listPayments()).any((payment) => payment.id == receipt.id),
        isTrue,
      );
      try {
        await deletePayment(id: receipt.id);
        fail('posted receipts must not be deleted directly');
      } on ApiError catch (error) {
        expect(error.code, 'forbidden');
      }
      expect(
        (await listPayments()).any((payment) => payment.id == receipt.id),
        isTrue,
      );

      final expenseItem = await createExpenseItem(
        input: ExpenseItemInput(
          code: '',
          nameAr: 'كهرباء اختبار',
          nameEn: 'Bridge electricity',
          openingBalance: '0',
          debit: '0',
          credit: '0',
          currency: currency,
          exchangeRate: '1',
          notes: null,
        ),
      );
      expect(expenseItem.code, isNotEmpty);
      expect(expenseItem.parentId, isNotNull);
      expect(
        (await listExpenseItems()).any((item) => item.id == expenseItem.id),
        isTrue,
      );

      final expenseVoucher = await createPayment(
        input: PaymentInput(
          paymentType: 'ExpenseVoucher',
          amount: '7',
          currencyCode: currency,
          exchangeRate: '1',
          paymentDate: DateTime.now().toUtc().toIso8601String(),
          debitAccountId: expenseItem.id,
          creditAccountId: null,
          customerId: null,
          supplierId: null,
          reference: 'BRIDGE-EXP-1',
          notes: 'سند مصروف اختبار',
        ),
      );
      expect(expenseVoucher.voucherNumber, startsWith('EXP'));
      expect(expenseVoucher.journalEntryNumber, isNotNull);

      final updatedExpense = await updateExpenseItem(
        input: ExpenseItemInput(
          id: expenseItem.id,
          code: expenseItem.code,
          nameAr: 'كهرباء اختبار محدثة',
          nameEn: 'Bridge electricity updated',
          openingBalance: '0',
          debit: '0',
          credit: '0',
          currency: currency,
          exchangeRate: '1',
          notes: 'updated',
        ),
      );
      expect(updatedExpense.nameAr, contains('محدثة'));
      expect(updatedExpense.code, expenseItem.code);

      // A clean item can be deleted; the one used by a posted voucher is kept
      // as audit history and is not removed by this test.
      final cleanExpense = await createExpenseItem(
        input: ExpenseItemInput(
          code: '',
          nameAr: 'بند قابل للحذف',
          nameEn: 'Deletable item',
          openingBalance: '0',
          debit: '0',
          credit: '0',
          currency: currency,
          exchangeRate: '1',
          notes: null,
        ),
      );
      await deleteExpenseItem(id: cleanExpense.id);
      expect(
        (await listExpenseItems()).any((item) => item.id == cleanExpense.id),
        isFalse,
      );

      // The Rust side keeps the SQLite pool open for the app lifetime, so
      // deleting the temp directory is best-effort on Windows.
      try {
        await tempDir.delete(recursive: true);
      } on FileSystemException {
        // Ignore locked WAL/SHM files.
      }
    },
  );
}
