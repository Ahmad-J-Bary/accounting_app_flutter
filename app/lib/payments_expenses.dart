import 'package:flutter/material.dart';

import 'ledger.dart';
import 'theme/app_theme.dart';
import 'ui/app_ui.dart';
import 'ui/unsaved_changes.dart';
import 'workspace_data.dart';

enum PaymentListKind { receipts, payments }

/// Receipt and payment vouchers. Each voucher posts a balanced journal entry
/// through the Rust payment use case, so partner balances stay in sync.
class PaymentsPage extends StatefulWidget {
  const PaymentsPage({
    super.key,
    required this.gateway,
    required this.data,
    required this.kind,
    required this.onChanged,
  });

  final LedgerGateway gateway;
  final WorkspaceData data;
  final PaymentListKind kind;
  final Future<void> Function() onChanged;

  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage> {
  final _searchController = TextEditingController();
  String _query = '';

  bool get _isReceipt => widget.kind == PaymentListKind.receipts;

  List<LedgerPayment> get _payments => widget.data.payments
      .where(
        (payment) =>
            payment.paymentType == (_isReceipt ? 'Receipt' : 'SupplierPayment'),
      )
      .toList();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openEditor([LedgerPayment? payment]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PaymentEditorPage(
          gateway: widget.gateway,
          data: widget.data,
          isReceipt: _isReceipt,
          payment: payment,
        ),
      ),
    );
    if (saved == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            payment == null ? 'تم إنشاء السند.' : 'تم تحديث السند.',
          ),
        ),
      );
      await widget.onChanged();
    }
  }

  Future<void> _delete(LedgerPayment payment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف السند'),
        content: Text(
          'هل تريد حذف المسودة ${payment.voucherNumber}؟\n'
          'السندات المرحّلة محفوظة كأثر تدقيقي ولا تُحذف.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.gateway.deletePayment(payment.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حذف السند.')));
      await widget.onChanged();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(describeError(error)),
          duration: const Duration(seconds: 7),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _payments.where((payment) {
      if (_query.isEmpty) return true;
      return '${payment.voucherNumber} ${payment.partyName} ${payment.amount} ${payment.notes ?? ''}'
          .toLowerCase()
          .contains(_query);
    }).toList();
    final total = _payments
        .map((payment) => parseAmount(payment.amount))
        .fold<double>(0, (a, b) => a + b);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        AppPageHeader(
          title: _isReceipt ? 'المقبوضات' : 'المدفوعات',
          subtitle: _isReceipt
              ? 'سندات قبض من العملاء مع تحديث الأرصدة والقيود.'
              : 'سندات دفع للموردين مع تحديث الأرصدة والقيود.',
          icon: _isReceipt
              ? Icons.call_received_outlined
              : Icons.call_made_outlined,
          actions: [
            FilledButton.icon(
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add, size: 18),
              label: Text(_isReceipt ? 'سند قبض جديد' : 'سند دفع جديد'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        AppMetricGrid(
          maxColumns: 3,
          children: [
            AppMetricCard(
              label: 'عدد السندات',
              value: formatNumberValue(_payments.length, decimals: 0),
              icon: Icons.receipt_outlined,
            ),
            AppMetricCard(
              label: 'إجمالي المبلغ',
              value: formatMoney(
                total.toString(),
                currency: widget.data.baseCurrency,
              ),
              icon: Icons.payments_outlined,
              tone: _isReceipt ? AppBadgeTone.success : AppBadgeTone.warning,
            ),
            AppMetricCard(
              label: 'آخر سند',
              value: _payments.isEmpty
                  ? '—'
                  : _formatDate(_payments.first.paymentDate),
              icon: Icons.schedule_outlined,
              tone: AppBadgeTone.info,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: SizedBox(
            width: 320,
            child: AppSearchField(
              controller: _searchController,
              hintText: 'بحث برقم السند أو الطرف...',
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppDataTable<LedgerPayment>(
          tableId: _isReceipt ? 'receipts' : 'payments',
          rows: visible,
          minWidth: 980,
          emptyTitle: 'لا توجد سندات',
          emptyMessage: _isReceipt
              ? 'أنشئ سند قبض جديدًا لتسجيل دفعة من عميل.'
              : 'أنشئ سند دفع جديدًا لتسجيل دفعة لمورد.',
          emptyIcon: Icons.receipt_long_outlined,
          emptyAction: FilledButton.icon(
            onPressed: () => _openEditor(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('إنشاء سند'),
          ),
          columns: [
            AppTableColumn(
              id: 'number',
              label: 'رقم السند',
              flex: 2,
              sortable: true,
              sortValue: (payment) => payment.voucherNumber,
              builder: (context, payment) => AppTableText(
                payment.voucherNumber,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            AppTableColumn(
              id: 'party',
              label: _isReceipt ? 'العميل' : 'المورد',
              flex: 3,
              sortable: true,
              sortValue: (payment) => payment.partyName,
              builder: (context, payment) => AppTableText(
                payment.partyName.isEmpty ? '—' : payment.partyName,
              ),
            ),
            AppTableColumn(
              id: 'date',
              label: 'التاريخ',
              flex: 2,
              sortable: true,
              sortValue: (payment) => payment.paymentDate,
              builder: (context, payment) =>
                  AppTableText(_formatDate(payment.paymentDate)),
            ),
            AppTableColumn(
              id: 'reference',
              label: 'المرجع',
              flex: 2,
              builder: (context, payment) =>
                  AppTableText(payment.reference ?? '—'),
            ),
            AppTableColumn(
              id: 'amount',
              label: 'المبلغ',
              flex: 2,
              sortable: true,
              sortValue: (payment) => parseAmount(payment.amount),
              alignment: AlignmentDirectional.centerEnd,
              headerAlignment: AlignmentDirectional.centerEnd,
              builder: (context, payment) => AppTableText(
                formatMoney(payment.amount, currency: payment.currency),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            AppTableColumn(
              id: 'entry',
              label: 'القيد',
              flex: 2,
              builder: (context, payment) =>
                  AppTableText(payment.journalEntryNumber ?? '—'),
            ),
            AppTableColumn(
              id: 'actions',
              label: 'إجراءات',
              width: 2 * AppTableActionButton.size + 24,
              canHide: false,
              canResize: false,
              alignment: AlignmentDirectional.centerEnd,
              headerAlignment: AlignmentDirectional.centerEnd,
              builder: (context, payment) {
                // Posted vouchers are audit history. The core intentionally
                // rejects direct update/delete, so only drafts expose actions.
                if (payment.journalEntryNumber != null) {
                  return const AppBadge(
                    label: 'مرحّل',
                    tone: AppBadgeTone.success,
                    compact: true,
                  );
                }
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppTableActionButton(
                      tooltip: 'تعديل',
                      onPressed: () => _openEditor(payment),
                      icon: Icons.edit_outlined,
                    ),
                    AppTableActionButton(
                      tooltip: 'حذف',
                      onPressed: () => _delete(payment),
                      icon: Icons.delete_outline,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

class PaymentEditorPage extends StatefulWidget {
  const PaymentEditorPage({
    super.key,
    required this.gateway,
    required this.data,
    required this.isReceipt,
    this.payment,
    this.expenseAccount,
  });

  final LedgerGateway gateway;
  final WorkspaceData data;
  final bool isReceipt;
  final LedgerPayment? payment;
  final LedgerAccount? expenseAccount;

  @override
  State<PaymentEditorPage> createState() => _PaymentEditorPageState();
}

class _PaymentEditorPageState extends State<PaymentEditorPage> {
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  final _notesController = TextEditingController();
  late String _currency = widget.data.baseCurrency;
  String? _partyId;
  DateTime _date = DateTime.now();
  bool _saving = false;

  /// True once the user changed something that is not saved yet.
  bool _dirty = false;

  String get _paymentType {
    if (widget.expenseAccount != null) return 'ExpenseVoucher';
    return widget.isReceipt ? 'Receipt' : 'SupplierPayment';
  }

  @override
  void initState() {
    super.initState();
    final payment = widget.payment;
    if (payment != null) {
      _amountController.text = payment.amount;
      _referenceController.text = payment.reference ?? '';
      _notesController.text = payment.notes ?? '';
      _currency = payment.currency;
      _partyId = payment.customerId ?? payment.supplierId;
      _date =
          DateTime.tryParse(payment.paymentDate)?.toLocal() ?? DateTime.now();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = parseAmount(_amountController.text);
    if (amount <= 0) {
      _showError('أدخل مبلغًا أكبر من صفر.');
      return;
    }
    if (_partyId == null && widget.expenseAccount == null) {
      _showError(widget.isReceipt ? 'اختر العميل.' : 'اختر المورد.');
      return;
    }

    final draft = PaymentDraft(
      paymentType: _paymentType,
      amount: amount.toString(),
      currency: _currency,
      customerId: widget.isReceipt ? _partyId : null,
      supplierId: widget.isReceipt ? null : _partyId,
      debitAccountId: widget.expenseAccount?.id,
      reference: _referenceController.text.trim().isEmpty
          ? null
          : _referenceController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      paymentDate: _date,
    );

    setState(() => _saving = true);
    try {
      final existing = widget.payment;
      if (existing == null) {
        await widget.gateway.createPayment(draft);
      } else {
        await widget.gateway.updatePayment(existing.id, draft);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      _showError(describeError(error));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 7)),
      );
  }

  @override
  Widget build(BuildContext context) {
    final parties = widget.isReceipt
        ? widget.data.customers
              .map(
                (customer) => _PartyChoice(
                  id: customer.id,
                  name: customer.name,
                  code: customer.code,
                ),
              )
              .toList()
        : widget.data.suppliers
              .map(
                (supplier) => _PartyChoice(
                  id: supplier.id,
                  name: supplier.name,
                  code: supplier.code,
                ),
              )
              .toList();

    return UnsavedChangesGuard(
      hasUnsavedChanges: _dirty,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.expenseAccount != null
                ? 'سند مصروف - ${widget.expenseAccount!.displayName}'
                : widget.isReceipt
                ? 'سند قبض'
                : 'سند دفع',
          ),
          actions: [
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check, size: 18),
              label: const Text('حفظ وترحيل'),
            ),
            const SizedBox(width: AppSpacing.lg),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            AppSectionCard(
              title: 'بيانات السند',
              child: Wrap(
                spacing: AppSpacing.lg,
                runSpacing: AppSpacing.lg,
                children: [
                  if (widget.expenseAccount == null)
                    SizedBox(
                      width: 300,
                      child: DropdownButtonFormField<String>(
                        initialValue: _partyId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: widget.isReceipt ? 'العميل' : 'المورد',
                          prefixIcon: const Icon(Icons.person_outline),
                        ),
                        items: parties
                            .map(
                              (party) => DropdownMenuItem(
                                value: party.id,
                                child: Text(
                                  '${party.name} (${party.code})',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(() {
                          _partyId = value;
                          _dirty = true;
                        }),
                      ),
                    ),
                  if (widget.expenseAccount != null)
                    SizedBox(
                      width: 300,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'بند المصروف',
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        child: Text(widget.expenseAccount!.displayName),
                      ),
                    ),
                  SizedBox(
                    width: 200,
                    child: TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => setState(() => _dirty = true),
                      decoration: const InputDecoration(
                        labelText: 'المبلغ',
                        prefixIcon: Icon(Icons.payments_outlined),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 190,
                    child: InkWell(
                      onTap: () async {
                        final value = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (value != null) {
                          setState(() {
                            _date = value;
                            _dirty = true;
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'التاريخ',
                          prefixIcon: Icon(Icons.event_outlined),
                        ),
                        child: Text(_formatDate(_date.toIso8601String())),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 190,
                    child: DropdownButtonFormField<String>(
                      initialValue: _currency,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'العملة',
                        prefixIcon: Icon(Icons.currency_exchange_outlined),
                      ),
                      items: widget.data.currencies
                          .map(
                            (currency) => DropdownMenuItem(
                              value: currency.code,
                              child: Text(currency.code),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() {
                        _currency = value ?? _currency;
                        _dirty = true;
                      }),
                    ),
                  ),
                  SizedBox(
                    width: 260,
                    child: TextField(
                      controller: _referenceController,
                      onChanged: (_) => setState(() => _dirty = true),
                      decoration: const InputDecoration(
                        labelText: 'المرجع',
                        prefixIcon: Icon(Icons.tag_outlined),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 360,
                    child: TextField(
                      controller: _notesController,
                      onChanged: (_) => setState(() => _dirty = true),
                      decoration: const InputDecoration(
                        labelText: 'ملاحظات',
                        prefixIcon: Icon(Icons.notes_outlined),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppInfoBanner(
              title: 'ترحيل تلقائي',
              message:
                  'عند الحفظ يُنشئ النظام قيدًا متوازنًا: النقدية مقابل حساب الطرف أو بند المصروف.',
              icon: Icons.verified_outlined,
            ),
          ],
        ),
      ),
    );
  }
}

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({
    super.key,
    required this.gateway,
    required this.data,
    required this.onChanged,
  });

  final LedgerGateway gateway;
  final WorkspaceData data;
  final Future<void> Function() onChanged;

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  final _searchController = TextEditingController();
  String _query = '';

  List<LedgerAccount> get _items => widget.data.expenseItems;

  List<LedgerPayment> get _vouchers => widget.data.payments
      .where((payment) => payment.paymentType == 'ExpenseVoucher')
      .toList();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openItemForm([LedgerAccount? item]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ExpenseItemFormPage(
          gateway: widget.gateway,
          data: widget.data,
          item: item,
        ),
      ),
    );
    if (saved == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(item == null ? 'تم إنشاء البند.' : 'تم تحديث البند.'),
        ),
      );
      await widget.onChanged();
    }
  }

  Future<void> _openVoucher([LedgerAccount? item]) async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('أضف بند مصروف أولًا.')));
      return;
    }
    final account = item ?? _items.first;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PaymentEditorPage(
          gateway: widget.gateway,
          data: widget.data,
          isReceipt: false,
          expenseAccount: account,
        ),
      ),
    );
    if (saved == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم إنشاء سند المصروف.')));
      await widget.onChanged();
    }
  }

  Future<void> _deleteItem(LedgerAccount item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف بند المصروف'),
        content: Text(
          'هل تريد حذف «${item.displayName}»؟\n'
          'لا يمكن حذف بند مرتبط بقيود مرحّلة.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.gateway.deleteExpenseItem(item.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حذف بند المصروف.')));
      await widget.onChanged();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(describeError(error)),
          duration: const Duration(seconds: 7),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _items.where((item) {
      if (_query.isEmpty) return true;
      return '${item.code} ${item.displayName} ${item.nameEn}'
          .toLowerCase()
          .contains(_query);
    }).toList();
    final voucherTotal = _vouchers
        .map((payment) => parseAmount(payment.amount))
        .fold<double>(0, (a, b) => a + b);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        AppPageHeader(
          title: 'بنود المصاريف',
          subtitle: 'إدارة بنود المصاريف وإصدار سندات الصرف.',
          icon: Icons.request_quote_outlined,
          actions: [
            OutlinedButton.icon(
              onPressed: _items.isEmpty ? null : () => _openVoucher(),
              icon: const Icon(Icons.receipt_long_outlined, size: 18),
              label: const Text('سند مصروف'),
            ),
            FilledButton.icon(
              onPressed: () => _openItemForm(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('بند جديد'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        AppMetricGrid(
          maxColumns: 3,
          children: [
            AppMetricCard(
              label: 'عدد البنود',
              value: formatNumberValue(_items.length, decimals: 0),
              icon: Icons.category_outlined,
            ),
            AppMetricCard(
              label: 'عدد سندات المصروف',
              value: formatNumberValue(_vouchers.length, decimals: 0),
              icon: Icons.receipt_long_outlined,
              tone: AppBadgeTone.info,
            ),
            AppMetricCard(
              label: 'إجمالي المصاريف',
              value: formatMoney(
                voucherTotal.toString(),
                currency: widget.data.baseCurrency,
              ),
              icon: Icons.trending_down_outlined,
              tone: AppBadgeTone.warning,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: SizedBox(
            width: 320,
            child: AppSearchField(
              controller: _searchController,
              hintText: 'بحث باسم أو كود البند...',
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppDataTable<LedgerAccount>(
          tableId: 'expense-items',
          rows: visible,
          minWidth: 860,
          emptyTitle: 'لا توجد بنود مصاريف',
          emptyMessage: 'أضف بندًا ليظهر في سندات المصروف.',
          emptyIcon: Icons.request_quote_outlined,
          emptyAction: FilledButton.icon(
            onPressed: () => _openItemForm(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('إضافة بند'),
          ),
          columns: [
            AppTableColumn(
              id: 'code',
              label: 'الكود',
              flex: 2,
              sortable: true,
              sortValue: (item) => item.code,
              builder: (context, item) => AppTableText(item.code),
            ),
            AppTableColumn(
              id: 'name',
              label: 'البند',
              flex: 4,
              sortable: true,
              sortValue: (item) => item.displayName,
              builder: (context, item) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppTableText(
                    item.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (item.nameEn.trim().isNotEmpty)
                    AppTableText(
                      item.nameEn,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            AppTableColumn(
              id: 'balance',
              label: 'الرصيد',
              flex: 2,
              sortable: true,
              sortValue: (item) => parseAmount(item.balance),
              alignment: AlignmentDirectional.centerEnd,
              headerAlignment: AlignmentDirectional.centerEnd,
              builder: (context, item) => AppTableText(
                formatMoney(item.balance, currency: item.currency),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            AppTableColumn(
              id: 'status',
              label: 'الحالة',
              flex: 2,
              sortable: true,
              sortValue: (item) => item.isActive ? 1 : 0,
              builder: (context, item) => AppBadge(
                label: item.isActive ? 'نشط' : 'موقوف',
                tone: item.isActive
                    ? AppBadgeTone.success
                    : AppBadgeTone.neutral,
                compact: true,
              ),
            ),
            AppTableColumn(
              id: 'actions',
              label: 'إجراءات',
              width: 3 * AppTableActionButton.size + 24,
              canHide: false,
              canResize: false,
              alignment: AlignmentDirectional.centerEnd,
              headerAlignment: AlignmentDirectional.centerEnd,
              builder: (context, item) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppTableActionButton(
                    tooltip: 'سند مصروف',
                    onPressed: () => _openVoucher(item),
                    icon: Icons.receipt_long_outlined,
                  ),
                  AppTableActionButton(
                    tooltip: 'تعديل',
                    onPressed: () => _openItemForm(item),
                    icon: Icons.edit_outlined,
                  ),
                  AppTableActionButton(
                    tooltip: 'حذف',
                    onPressed: () => _deleteItem(item),
                    icon: Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class ExpenseItemFormPage extends StatefulWidget {
  const ExpenseItemFormPage({
    super.key,
    required this.gateway,
    required this.data,
    this.item,
  });

  final LedgerGateway gateway;
  final WorkspaceData data;
  final LedgerAccount? item;

  @override
  State<ExpenseItemFormPage> createState() => _ExpenseItemFormPageState();
}

class _ExpenseItemFormPageState extends State<ExpenseItemFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameAr = TextEditingController();
  final _nameEn = TextEditingController();
  final _code = TextEditingController();
  final _notes = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    if (item != null) {
      _nameAr.text = item.nameAr;
      _nameEn.text = item.nameEn;
      _code.text = item.code;
      _notes.text = item.notes ?? '';
    }
  }

  @override
  void dispose() {
    _nameAr.dispose();
    _nameEn.dispose();
    _code.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final draft = ExpenseItemDraft(
      id: widget.item?.id,
      nameAr: _nameAr.text.trim(),
      nameEn: _nameEn.text.trim(),
      code: _code.text.trim(),
      currency: widget.item?.currency ?? widget.data.baseCurrency,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    );
    setState(() => _saving = true);
    try {
      if (widget.item == null) {
        await widget.gateway.createExpenseItem(draft);
      } else {
        await widget.gateway.updateExpenseItem(draft);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(describeError(error)),
          duration: const Duration(seconds: 7),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.item == null ? 'بند مصروف جديد' : 'تعديل بند المصروف',
        ),
        actions: [
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check, size: 18),
            label: const Text('حفظ'),
          ),
          const SizedBox(width: AppSpacing.lg),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Form(
              key: _formKey,
              child: Wrap(
                spacing: AppSpacing.lg,
                runSpacing: AppSpacing.lg,
                children: [
                  SizedBox(
                    width: 320,
                    child: TextFormField(
                      controller: _nameAr,
                      decoration: const InputDecoration(
                        labelText: 'الاسم بالعربية',
                        prefixIcon: Icon(Icons.label_outline),
                      ),
                      validator: (value) =>
                          (value ?? '').trim().isEmpty ? 'الاسم مطلوب.' : null,
                    ),
                  ),
                  SizedBox(
                    width: 320,
                    child: TextFormField(
                      controller: _nameEn,
                      decoration: const InputDecoration(
                        labelText: 'الاسم بالإنجليزية',
                        prefixIcon: Icon(Icons.translate_outlined),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 200,
                    child: TextFormField(
                      controller: _code,
                      decoration: const InputDecoration(
                        labelText: 'الكود (اختياري)',
                        prefixIcon: Icon(Icons.tag_outlined),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 420,
                    child: TextFormField(
                      controller: _notes,
                      decoration: const InputDecoration(
                        labelText: 'ملاحظات',
                        prefixIcon: Icon(Icons.notes_outlined),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PartyChoice {
  const _PartyChoice({
    required this.id,
    required this.name,
    required this.code,
  });

  final String id;
  final String name;
  final String code;
}

String _formatDate(String raw) {
  final value = DateTime.tryParse(raw)?.toLocal();
  if (value == null) return raw;
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}/$month/$day';
}
