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
