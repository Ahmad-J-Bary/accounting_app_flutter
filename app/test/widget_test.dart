import 'package:accounting_app_flutter/ledger.dart';
import 'package:accounting_app_flutter/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeGateway implements LedgerGateway {
  @override
  Future<LedgerSnapshot> load() async {
    return const LedgerSnapshot(
      accounts: [
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
      rows: [
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
  Future<void> createEntry({
    required String debitAccountId,
    required String creditAccountId,
    required String amount,
    required String description,
    required String currency,
  }) async {}
}

void main() {
  testWidgets('shows trial balance totals from the gateway', (tester) async {
    await tester.pumpWidget(AccountingApp(gateway: _FakeGateway()));
    await tester.pumpAndSettle();

    expect(find.text('إجمالي المدين'), findsOneWidget);
    expect(find.text('إجمالي الدائن'), findsOneWidget);
    expect(find.text('100.00'), findsWidgets);

    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();

    expect(find.text('ميزان المراجعة'), findsOneWidget);
    expect(find.text('الصندوق'), findsWidgets);
  });

  testWidgets('validates that both accounts are selected', (tester) async {
    await tester.pumpWidget(AccountingApp(gateway: _FakeGateway()));
    await tester.pumpAndSettle();

    final saveButton = find.widgetWithText(FilledButton, 'حفظ القيد');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(find.text('اختر الحساب المدين والحساب الدائن.'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });
}
