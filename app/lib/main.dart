import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ledger.dart';

void main() {
  runApp(AccountingApp(gateway: RustLedgerGateway()));
}

class AccountingApp extends StatelessWidget {
  const AccountingApp({super.key, required this.gateway});

  final LedgerGateway gateway;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'المحاسبة',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF00695C),
        useMaterial3: true,
      ),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: LedgerHomePage(gateway: gateway),
    );
  }
}

class LedgerHomePage extends StatefulWidget {
  const LedgerHomePage({super.key, required this.gateway});

  final LedgerGateway gateway;

  @override
  State<LedgerHomePage> createState() => _LedgerHomePageState();
}

class _LedgerHomePageState extends State<LedgerHomePage> {
  LedgerSnapshot? _data;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await widget.gateway.load();
      if (!mounted) {
        return;
      }
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _createEntry({
    required String debitAccountId,
    required String creditAccountId,
    required String amount,
    required String description,
    required String currency,
  }) async {
    await widget.gateway.createEntry(
      debitAccountId: debitAccountId,
      creditAccountId: creditAccountId,
      amount: amount,
      description: description,
      currency: currency,
    );
    if (!mounted) {
      return;
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;

    return Scaffold(
      appBar: AppBar(
        title: const Text('المحاسبة — ميزان المراجعة'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: data == null
          ? (_error != null
              ? _ErrorView(error: _error!, onRetry: _load)
              : const _LoadingView())
          : Column(
              children: [
                if (_loading) const LinearProgressIndicator(),
                if (_error != null)
                  MaterialBanner(
                    content: Text('تعذّر تحديث البيانات: $_error'),
                    actions: [
                      TextButton(
                        onPressed: _load,
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _TotalsCard(
                        totalDebit: data.totalDebit,
                        totalCredit: data.totalCredit,
                      ),
                      const SizedBox(height: 16),
                      JournalEntryForm(
                        accounts: data.accounts
                            .where((a) => a.isActive && a.isFinal)
                            .toList(),
                        onSubmit: _createEntry,
                      ),
                      const SizedBox(height: 16),
                      _TrialBalanceCard(rows: data.rows),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('جارٍ فتح قاعدة البيانات وتشغيل الترحيلات…'),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            const Text(
              'تعذّر فتح قاعدة البيانات',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SelectableText('$error', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.totalDebit, required this.totalCredit});

  final String totalDebit;
  final String totalCredit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: _AmountTile(
                label: 'إجمالي المدين',
                value: formatAmount(totalDebit),
                color: Colors.teal,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _AmountTile(
                label: 'إجمالي الدائن',
                value: formatAmount(totalCredit),
                color: Colors.indigo,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AmountTile extends StatelessWidget {
  const _AmountTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 6),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }
}

class JournalEntryForm extends StatefulWidget {
  const JournalEntryForm({
    super.key,
    required this.accounts,
    required this.onSubmit,
  });

  final List<LedgerAccount> accounts;
  final Future<void> Function({
    required String debitAccountId,
    required String creditAccountId,
    required String amount,
    required String description,
    required String currency,
  }) onSubmit;

  @override
  State<JournalEntryForm> createState() => _JournalEntryFormState();
}

class _JournalEntryFormState extends State<JournalEntryForm> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _debitId;
  String? _creditId;
  bool _busy = false;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant JournalEntryForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ids = widget.accounts.map((a) => a.id).toSet();
    if (_debitId != null && !ids.contains(_debitId)) {
      _debitId = null;
    }
    if (_creditId != null && !ids.contains(_creditId)) {
      _creditId = null;
    }
  }

  String _currencyFor(String? accountId) {
    for (final account in widget.accounts) {
      if (account.id == accountId) {
        return account.currency.isEmpty ? 'SYP' : account.currency;
      }
    }
    return 'SYP';
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red.shade700 : null,
      ),
    );
  }

  Future<void> _submit() async {
    if (_busy) {
      return;
    }

    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText);

    if (widget.accounts.isEmpty) {
      _showMessage('لا توجد حسابات نهائية نشطة لإنشاء قيد.', error: true);
      return;
    }
    if (_debitId == null || _creditId == null) {
      _showMessage('اختر الحساب المدين والحساب الدائن.', error: true);
      return;
    }
    if (_debitId == _creditId) {
      _showMessage('يجب أن يختلف الحساب المدين عن الحساب الدائن.', error: true);
      return;
    }
    if (amount == null || amount <= 0) {
      _showMessage('أدخل مبلغاً صحيحاً أكبر من صفر.', error: true);
      return;
    }

    setState(() => _busy = true);
    try {
      await widget.onSubmit(
        debitAccountId: _debitId!,
        creditAccountId: _creditId!,
        amount: amountText,
        description: _descriptionController.text.trim(),
        currency: _currencyFor(_debitId),
      );
      if (!mounted) {
        return;
      }
      _amountController.clear();
      _descriptionController.clear();
      _showMessage('تم إنشاء القيد بنجاح.');
    } catch (error) {
      if (mounted) {
        _showMessage('فشل إنشاء القيد: $error', error: true);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'قيد يومية جديد',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _debitId,
              decoration: const InputDecoration(
                labelText: 'الحساب المدين',
                border: OutlineInputBorder(),
              ),
              items: widget.accounts
                  .map(
                    (account) => DropdownMenuItem(
                      value: account.id,
                      child: Text('${account.code} — ${account.displayName}'),
                    ),
                  )
                  .toList(),
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _debitId = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _creditId,
              decoration: const InputDecoration(
                labelText: 'الحساب الدائن',
                border: OutlineInputBorder(),
              ),
              items: widget.accounts
                  .map(
                    (account) => DropdownMenuItem(
                      value: account.id,
                      child: Text('${account.code} — ${account.displayName}'),
                    ),
                  )
                  .toList(),
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _creditId = value),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              enabled: !_busy,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: const InputDecoration(
                labelText: 'المبلغ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              enabled: !_busy,
              decoration: const InputDecoration(
                labelText: 'البيان',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : _submit,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_busy ? 'جارٍ الحفظ…' : 'حفظ القيد'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrialBalanceCard extends StatelessWidget {
  const _TrialBalanceCard({required this.rows});

  final List<TrialBalanceRow> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'ميزان المراجعة',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'لا توجد قيود بعد. أنشئ أول قيد من النموذج أعلاه.',
                  textAlign: TextAlign.center,
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('الرمز')),
                    DataColumn(label: Text('الحساب')),
                    DataColumn(label: Text('مدين'), numeric: true),
                    DataColumn(label: Text('دائن'), numeric: true),
                  ],
                  rows: rows
                      .map(
                        (row) => DataRow(
                          cells: [
                            DataCell(Text(row.accountCode)),
                            DataCell(Text(row.accountName)),
                            DataCell(Text(formatAmount(row.debit))),
                            DataCell(Text(formatAmount(row.credit))),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String formatAmount(String raw) {
  final value = double.tryParse(raw);
  if (value == null) {
    return raw;
  }
  return value.toStringAsFixed(2);
}
