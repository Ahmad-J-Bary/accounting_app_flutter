import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ledger.dart';
import 'theme/app_theme.dart';
import 'ui/app_ui.dart';
import 'workspace_data.dart';

class JournalPage extends StatelessWidget {
  const JournalPage({
    super.key,
    required this.data,
    required this.onCreateEntry,
    required this.onRefresh,
    this.refreshing = false,
  });

  final WorkspaceData data;
  final Future<void> Function({
    required String debitAccountId,
    required String creditAccountId,
    required String amount,
    required String description,
    required String currency,
  })
  onCreateEntry;
  final VoidCallback onRefresh;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    final accounts = data.snapshot.accounts
        .where((account) => account.isActive && account.isFinal)
        .toList(growable: false);
    final difference = data.balanceDifference;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppPageHeader(
            title: 'قيود اليومية',
            subtitle: 'إنشاء القيود ومراجعة ميزان المراجعة في مكان واحد.',
            icon: Icons.menu_book_outlined,
            actions: [
              AppBadge(
                label: data.status.currencyLabel,
                tone: AppBadgeTone.primary,
                icon: Icons.payments_outlined,
              ),
              OutlinedButton.icon(
                onPressed: refreshing ? null : onRefresh,
                icon: refreshing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 18),
                label: const Text('تحديث'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          _JournalSummaryCards(
            data: data,
            difference: difference,
            accountsCount: accounts.length,
          ),
          const SizedBox(height: AppSpacing.xl),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 1120;
              final form = JournalEntryForm(
                accounts: accounts,
                baseCurrency: data.baseCurrency,
                onSubmit: onCreateEntry,
              );
              final table = _TrialBalanceCard(data: data);
              if (!wide) {
                return Column(
                  children: [
                    form,
                    const SizedBox(height: AppSpacing.lg),
                    table,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 4, child: form),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(flex: 8, child: table),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _JournalSummaryCards extends StatelessWidget {
  const _JournalSummaryCards({
    required this.data,
    required this.difference,
    required this.accountsCount,
  });

  final WorkspaceData data;
  final double difference;
  final int accountsCount;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1000
            ? 4
            : constraints.maxWidth >= 620
            ? 2
            : 1;
        const spacing = AppSpacing.md;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            SizedBox(
              width: width,
              child: AppMetricCard(
                label: 'إجمالي المدين',
                value: formatMoney(
                  data.snapshot.totalDebit,
                  currency: data.baseCurrency,
                ),
                icon: Icons.south_west_outlined,
                tone: AppBadgeTone.success,
                hint: 'مجموع الأرصدة المدينة',
              ),
            ),
            SizedBox(
              width: width,
              child: AppMetricCard(
                label: 'إجمالي الدائن',
                value: formatMoney(
                  data.snapshot.totalCredit,
                  currency: data.baseCurrency,
                ),
                icon: Icons.north_east_outlined,
                tone: AppBadgeTone.info,
                hint: 'مجموع الأرصدة الدائنة',
              ),
            ),
            SizedBox(
              width: width,
              child: AppMetricCard(
                label: 'حالة الميزان',
                value: data.isBalanced
                    ? 'متوازن'
                    : formatMoney(
                        difference.toStringAsFixed(2),
                        currency: data.baseCurrency,
                      ),
                icon: data.isBalanced
                    ? Icons.verified_outlined
                    : Icons.warning_amber_outlined,
                tone: data.isBalanced
                    ? AppBadgeTone.success
                    : AppBadgeTone.danger,
                hint: data.isBalanced
                    ? 'المدين = الدائن'
                    : 'يوجد فرق يحتاج مراجعة',
              ),
            ),
            SizedBox(
              width: width,
              child: AppMetricCard(
                label: 'الحسابات المتاحة',
                value: '$accountsCount',
                icon: Icons.account_balance_outlined,
                tone: AppBadgeTone.primary,
                hint: '${data.snapshot.rows.length} صف في الميزان',
              ),
            ),
          ],
        );
      },
    );
  }
}

class JournalEntryForm extends StatefulWidget {
  const JournalEntryForm({
    super.key,
    required this.accounts,
    required this.baseCurrency,
    required this.onSubmit,
  });

  final List<LedgerAccount> accounts;
  final String baseCurrency;
  final Future<void> Function({
    required String debitAccountId,
    required String creditAccountId,
    required String amount,
    required String description,
    required String currency,
  })
  onSubmit;

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
    final ids = widget.accounts.map((account) => account.id).toSet();
    if (_debitId != null && !ids.contains(_debitId)) {
      _debitId = null;
    }
    if (_creditId != null && !ids.contains(_creditId)) {
      _creditId = null;
    }
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: error
            ? Theme.of(context).colorScheme.error
            : context.semanticColors.success,
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
        currency: widget.baseCurrency.isEmpty ? 'SYP' : widget.baseCurrency,
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
    final theme = Theme.of(context);
    return AppCard(
      radius: AppRadius.xxl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const AppIconTile(
                icon: Icons.edit_note_outlined,
                size: 40,
                iconSize: 20,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('قيد يومية جديد', style: theme.textTheme.titleMedium),
                    Text(
                      'يُحفظ القيد مباشرة في قاعدة البيانات المحلية',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          DropdownButtonFormField<String>(
            initialValue: _debitId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'الحساب المدين',
              prefixIcon: Icon(Icons.south_west_outlined, size: 19),
            ),
            hint: const Text('اختر الحساب المدين'),
            items: widget.accounts
                .map(
                  (account) => DropdownMenuItem(
                    value: account.id,
                    child: Text(
                      '${account.code} — ${account.displayName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: _busy
                ? null
                : (value) => setState(() => _debitId = value),
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String>(
            initialValue: _creditId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'الحساب الدائن',
              prefixIcon: Icon(Icons.north_east_outlined, size: 19),
            ),
            hint: const Text('اختر الحساب الدائن'),
            items: widget.accounts
                .map(
                  (account) => DropdownMenuItem(
                    value: account.id,
                    child: Text(
                      '${account.code} — ${account.displayName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: _busy
                ? null
                : (value) => setState(() => _creditId = value),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _amountController,
            enabled: !_busy,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: InputDecoration(
              labelText: 'المبلغ',
              prefixIcon: const Icon(Icons.payments_outlined, size: 19),
              suffixText: widget.baseCurrency.isEmpty
                  ? null
                  : widget.baseCurrency,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _descriptionController,
            enabled: !_busy,
            decoration: const InputDecoration(
              labelText: 'البيان',
              prefixIcon: Icon(Icons.notes_outlined, size: 19),
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: _busy ? null : _submit,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_outlined, size: 18),
            label: Text(_busy ? 'جارٍ الحفظ…' : 'حفظ القيد'),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(
                Icons.lock_outline,
                size: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'يجب أن يختلف الحساب المدين عن الدائن، والمبلغ أكبر من صفر.',
                  style: theme.textTheme.labelSmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrialBalanceCard extends StatelessWidget {
  const _TrialBalanceCard({required this.data});

  final WorkspaceData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      radius: AppRadius.xxl,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Row(
              children: [
                const AppIconTile(
                  icon: Icons.table_chart_outlined,
                  size: 40,
                  iconSize: 20,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ميزان المراجعة',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${data.snapshot.rows.length} حساب • ${data.status.companyName}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                AppBadge(
                  label: data.isBalanced ? 'متوازن' : 'غير متوازن',
                  tone: data.isBalanced
                      ? AppBadgeTone.success
                      : AppBadgeTone.danger,
                  icon: data.isBalanced
                      ? Icons.check_circle_outline
                      : Icons.error_outline,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          AppDataTable<TrialBalanceRow>(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            minWidth: 620,
            columns: [
              AppTableColumn(
                label: 'الرمز',
                flex: 2,
                builder: (context, row) =>
                    Text(row.accountCode, style: theme.textTheme.labelMedium),
              ),
              AppTableColumn(
                label: 'الحساب',
                flex: 5,
                builder: (context, row) => Text(row.accountName),
              ),
              AppTableColumn(
                label: 'مدين',
                flex: 2,
                alignment: AlignmentDirectional.centerEnd,
                headerAlignment: AlignmentDirectional.centerEnd,
                builder: (context, row) => Text(
                  formatMoney(row.debit, currency: data.baseCurrency),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: context.semanticColors.success,
                  ),
                ),
              ),
              AppTableColumn(
                label: 'دائن',
                flex: 2,
                alignment: AlignmentDirectional.centerEnd,
                headerAlignment: AlignmentDirectional.centerEnd,
                builder: (context, row) => Text(
                  formatMoney(row.credit, currency: data.baseCurrency),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: context.semanticColors.info,
                  ),
                ),
              ),
            ],
            rows: data.snapshot.rows,
            emptyTitle: 'لا توجد قيود بعد',
            emptyMessage:
                'أنشئ أول قيد من النموذج المجاور ليظهر ميزان المراجعة.',
            emptyIcon: Icons.receipt_long_outlined,
            rowHeight: 52,
            footer: Row(
              children: [
                Text('الإجمالي', style: theme.textTheme.titleSmall),
                const Spacer(),
                Text(
                  formatMoney(
                    data.snapshot.totalDebit,
                    currency: data.baseCurrency,
                  ),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: context.semanticColors.success,
                  ),
                ),
                const SizedBox(width: AppSpacing.xl),
                Text(
                  formatMoney(
                    data.snapshot.totalCredit,
                    currency: data.baseCurrency,
                  ),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: context.semanticColors.info,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
