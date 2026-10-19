import 'dart:io';

import 'package:accounting_app_flutter_isolates/accounting_app_flutter_isolates.dart';
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

class LedgerSnapshot {
  const LedgerSnapshot({
    required this.accounts,
    required this.rows,
    required this.totalDebit,
    required this.totalCredit,
  });

  final List<LedgerAccount> accounts;
  final List<TrialBalanceRow> rows;
  final String totalDebit;
  final String totalCredit;
}

/// Boundary between the widget tree and the Rust core. Keeping this abstract
/// lets widget tests run without loading the native library.
abstract class LedgerGateway {
  Future<LedgerSnapshot> load();

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
      _rustInit ??= RustLib.init();
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
    await initApp(dbPath: dbPath);
    _databaseReady = true;
  }

  @override
  Future<LedgerSnapshot> load() async {
    await _ensureReady();

    final accounts = await listAccounts();
    final trial = await trialBalance();

    return LedgerSnapshot(
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
  Future<void> createEntry({
    required String debitAccountId,
    required String creditAccountId,
    required String amount,
    required String description,
    required String currency,
  }) async {
    await _ensureReady();

    final entry = await createJournalEntry(
      input: CreateJournalEntryInput(
        journalType: 'GeneralJournal',
        entryDate: DateTime.now().toUtc().toIso8601String(),
        description: description.isEmpty ? 'قيد يومية' : description,
        lines: [
          JournalLineInput(
            accountId: debitAccountId,
            currency: currency,
            fxRate: '1',
            debit: amount,
            credit: '0',
            description: description,
          ),
          JournalLineInput(
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

    await postJournalEntry(entryId: entry.id);
  }
}
