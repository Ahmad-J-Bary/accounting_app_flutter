import 'dart:io';

import 'package:accounting_app_flutter_isolates/accounting_app_flutter_isolates.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Dart -> Rust: open SQLite, create a balanced entry, read trial balance',
      (tester) async {
    await RustLib.init();

    final tempDir = await Directory.systemTemp.createTemp('accounting_fr_');
    final dbPath = '${tempDir.path}${Platform.pathSeparator}ledger.db';

    await initApp(dbPath: dbPath);

    final accounts = await listAccounts();
    expect(accounts, isNotEmpty, reason: 'migrations must seed the chart of accounts');

    final leaves = accounts.where((a) => a.isActive && a.isFinal).toList();
    expect(leaves.length, greaterThanOrEqualTo(2));

    final debitAccount = leaves[0];
    final creditAccount = leaves[1];

    final entry = await createJournalEntry(
      input: CreateJournalEntryInput(
        journalType: 'GeneralJournal',
        entryDate: DateTime.now().toUtc().toIso8601String(),
        description: 'قيد اختبار الجسر',
        lines: [
          JournalLineInput(
            accountId: debitAccount.id,
            currency: debitAccount.currency,
            fxRate: '1',
            debit: '125.50',
            credit: '0',
            description: 'اختبار',
          ),
          JournalLineInput(
            accountId: creditAccount.id,
            currency: creditAccount.currency,
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

    // The Rust side keeps the SQLite pool open for the app lifetime, so
    // deleting the temp directory is best-effort on Windows.
    try {
      await tempDir.delete(recursive: true);
    } on FileSystemException {
      // Ignore locked WAL/SHM files.
    }
  });
}
