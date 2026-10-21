import 'package:flutter/material.dart';

import 'ledger.dart';
import 'theme/app_theme.dart';
import 'ui/app_ui.dart';
import 'ui/material_picker.dart';
import 'ui/unsaved_changes.dart';
import 'workspace_data.dart';

enum InvoiceListKind { sales, purchase }

/// Sales and purchase invoices. Both use the unified Rust invoice engine, so
/// stock, partner balances and the general ledger are posted together.
class InvoicesPage extends StatefulWidget {
  const InvoicesPage({
    super.key,
    required this.gateway,
    required this.data,
    required this.kind,
    required this.onChanged,
  });

  final LedgerGateway gateway;
  final WorkspaceData data;
  final InvoiceListKind kind;
  final Future<void> Function() onChanged;

  @override
  State<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends State<InvoicesPage> {
  final _searchController = TextEditingController();
  String _query = '';
  String _status = 'All';

  bool get _isSales => widget.kind == InvoiceListKind.sales;

  List<LedgerInvoice> get _invoices =>
      _isSales ? widget.data.salesInvoices : widget.data.purchaseInvoices;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(describeError(error)),
          duration: const Duration(seconds: 7),
        ),
      );
  }

  bool _matches(LedgerInvoice invoice) {
    if (_status != 'All' && invoice.status != _status) {
      return false;
    }
    if (_query.isEmpty) {
      return true;
    }
    final haystack =
        '${invoice.number} ${invoice.partyName} ${invoice.total} ${invoice.notes ?? ''}'
            .toLowerCase();
    return haystack.contains(_query);
  }

  Future<void> _openEditor([LedgerInvoice? invoice]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => InvoiceEditorPage(
          gateway: widget.gateway,
          data: widget.data,
          kind: widget.kind,
          invoice: invoice,
        ),
      ),
    );
    if (saved == true) {
      _showMessage(invoice == null ? 'تم حفظ الفاتورة.' : 'تم تحديث الفاتورة.');
      await widget.onChanged();
    }
  }

  Future<void> _post(LedgerInvoice invoice) async {
    final confirmed = await _confirm(
      title: 'ترحيل الفاتورة',
      message:
          'سيتم ترحيل الفاتورة إلى المخزون والقيود والحسابات.\n'
          'لا يمكن تعديل فاتورة مرحّلة؛ التصحيح يتم بعملية عكس.',
    );
    if (!confirmed) return;
    try {
      await widget.gateway.postInvoice(invoice.id);
      _showMessage('تم ترحيل الفاتورة ${invoice.number}.');
      await widget.onChanged();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _delete(LedgerInvoice invoice) async {
    final confirmed = await _confirm(
      title: 'حذف الفاتورة',
      message:
          'هل تريد حذف الفاتورة ${invoice.number}؟\n'
          'إذا كانت مرحّلة فسيتم عكس أثرها بالكامل قبل الحذف.',
    );
    if (!confirmed) return;
    try {
      await widget.gateway.deleteInvoice(invoice.id);
      _showMessage('تم حذف الفاتورة ${invoice.number}.');
      await widget.onChanged();
    } catch (error) {
      _showError(error);
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    final all = _invoices;
    final visible = all.where(_matches).toList();
    final posted = all.where((invoice) => invoice.isPosted);
    final total = posted
        .map((invoice) => parseAmount(invoice.total))
        .fold<double>(0, (a, b) => a + b);
    final paid = posted
        .map((invoice) => parseAmount(invoice.amountPaid))
        .fold<double>(0, (a, b) => a + b);
    final remaining = posted
        .map((invoice) => parseAmount(invoice.remaining))
        .fold<double>(0, (a, b) => a + b);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        AppPageHeader(
          title: _isSales ? 'فواتير البيع' : 'فواتير الشراء',
          subtitle: _isSales
              ? 'إصدار فواتير البيع وترحيلها إلى المخزون والقيود.'
              : 'تسجيل فواتير الشراء وتحديث المخزون وأرصدة الموردين.',
          icon: _isSales
              ? Icons.receipt_long_outlined
              : Icons.shopping_cart_checkout_outlined,
          actions: [
            OutlinedButton.icon(
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add, size: 18),
              label: Text(_isSales ? 'فاتورة بيع جديدة' : 'فاتورة شراء جديدة'),
            ),
            FilledButton.icon(
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add_card_outlined, size: 18),
              label: const Text('إنشاء'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        AppMetricGrid(
          children: [
            AppMetricCard(
              label: 'عدد الفواتير',
              value: formatNumberValue(all.length, decimals: 0),
              icon: Icons.description_outlined,
              hint: '${posted.length} مرحّلة',
            ),
            AppMetricCard(
              label: 'إجمالي الفواتير',
              value: formatMoney(
                total.toString(),
                currency: widget.data.baseCurrency,
              ),
              icon: Icons.summarize_outlined,
              tone: AppBadgeTone.info,
            ),
            AppMetricCard(
              label: 'المسدد',
              value: formatMoney(
                paid.toString(),
                currency: widget.data.baseCurrency,
              ),
              icon: Icons.payments_outlined,
              tone: AppBadgeTone.success,
            ),
            AppMetricCard(
              label: 'المتبقي',
              value: formatMoney(
                remaining.toString(),
                currency: widget.data.baseCurrency,
              ),
              icon: Icons.pending_actions_outlined,
              tone: remaining > 0 ? AppBadgeTone.warning : AppBadgeTone.success,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 320,
                child: AppSearchField(
                  controller: _searchController,
                  hintText: 'بحث برقم الفاتورة أو الطرف...',
                  onChanged: (value) =>
                      setState(() => _query = value.trim().toLowerCase()),
                ),
              ),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'All', label: Text('الكل')),
                  ButtonSegment(value: 'Draft', label: Text('مسودة')),
                  ButtonSegment(value: 'Posted', label: Text('مرحّلة')),
                ],
                selected: {_status},
                onSelectionChanged: (value) =>
                    setState(() => _status = value.first),
              ),
              AppBadge(
                label: '${visible.length} نتيجة',
                tone: AppBadgeTone.neutral,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppDataTable<LedgerInvoice>(
          tableId: _isSales ? 'sales-invoices' : 'purchase-invoices',
          rows: visible,
          minWidth: 1120,
          emptyTitle: 'لا توجد فواتير بعد',
          emptyMessage: 'ابدأ بإنشاء أول فاتورة؛ سيتم توليد رقمها تلقائيًا.',
          emptyIcon: Icons.receipt_long_outlined,
          emptyAction: FilledButton.icon(
            onPressed: () => _openEditor(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('إنشاء فاتورة'),
          ),
          onRowTap: (invoice) =>
              showInvoiceDetails(context, invoice, isSales: _isSales),
          columns: [
            AppTableColumn(
              id: 'number',
              label: 'الرقم',
              flex: 2,
              sortable: true,
              sortValue: (invoice) => invoice.number,
              builder: (context, invoice) => AppTableText(
                invoice.number,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            AppTableColumn(
              id: 'party',
              label: _isSales ? 'العميل' : 'المورد',
              flex: 3,
              sortable: true,
              sortValue: (invoice) => invoice.partyName,
              builder: (context, invoice) => AppTableText(
                invoice.partyName.isEmpty ? '—' : invoice.partyName,
              ),
            ),
            AppTableColumn(
              id: 'date',
              label: 'التاريخ',
              flex: 2,
              sortable: true,
              sortValue: (invoice) => invoice.issuedAt,
              builder: (context, invoice) =>
                  AppTableText(_formatDate(invoice.issuedAt)),
            ),
            AppTableColumn(
              id: 'payment',
              label: 'طريقة الدفع',
              flex: 2,
              builder: (context, invoice) =>
                  AppTableText(_paymentLabel(invoice.paymentMethod)),
            ),
            AppTableColumn(
              id: 'total',
              label: 'الإجمالي',
              flex: 2,
              sortable: true,
              sortValue: (invoice) => parseAmount(invoice.total),
              alignment: AlignmentDirectional.centerEnd,
              headerAlignment: AlignmentDirectional.centerEnd,
              builder: (context, invoice) => AppTableText(
                formatMoney(invoice.total, currency: invoice.currency),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            AppTableColumn(
              id: 'remaining',
              label: 'المتبقي',
              flex: 2,
              sortable: true,
              sortValue: (invoice) => parseAmount(invoice.remaining),
              alignment: AlignmentDirectional.centerEnd,
              headerAlignment: AlignmentDirectional.centerEnd,
              builder: (context, invoice) {
                final remaining = parseAmount(invoice.remaining);
                return AppTableText(
                  formatMoney(invoice.remaining, currency: invoice.currency),
                  style: TextStyle(
                    color: remaining > 0
                        ? context.semanticColors.warning
                        : context.semanticColors.success,
                    fontWeight: FontWeight.w700,
                  ),
                );
              },
            ),
            AppTableColumn(
              id: 'status',
              label: 'الحالة',
              flex: 2,
              sortable: true,
              sortValue: (invoice) => invoice.isPosted ? 1 : 0,
              builder: (context, invoice) => AppBadge(
                label: invoice.isPosted ? 'مرحّلة' : 'مسودة',
                tone: invoice.isPosted
                    ? AppBadgeTone.success
                    : AppBadgeTone.warning,
                compact: true,
              ),
            ),
            AppTableColumn(
              id: 'actions',
              label: 'إجراءات',
              width: 4 * AppTableActionButton.size + 24,
              canHide: false,
              canResize: false,
              alignment: AlignmentDirectional.centerEnd,
              headerAlignment: AlignmentDirectional.centerEnd,
              builder: (context, invoice) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppTableActionButton(
                    tooltip: 'عرض',
                    onPressed: () =>
                        showInvoiceDetails(context, invoice, isSales: _isSales),
                    icon: Icons.visibility_outlined,
                  ),
                  if (!invoice.isPosted)
                    AppTableActionButton(
                      tooltip: 'تعديل',
                      onPressed: () => _openEditor(invoice),
                      icon: Icons.edit_outlined,
                    ),
                  if (!invoice.isPosted)
                    AppTableActionButton(
                      tooltip: 'ترحيل',
                      onPressed: () => _post(invoice),
                      icon: Icons.play_circle_outline,
                    ),
                  // Posted invoices are audit history: the core rejects their
                  // deletion, so the action is not offered.
                  if (!invoice.isPosted)
                    AppTableActionButton(
                      tooltip: 'حذف',
                      onPressed: () => _delete(invoice),
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

class InvoiceEditorPage extends StatefulWidget {
  const InvoiceEditorPage({
    super.key,
    required this.gateway,
    required this.data,
    required this.kind,
    this.invoice,
  });

  final LedgerGateway gateway;
  final WorkspaceData data;
  final InvoiceListKind kind;
  final LedgerInvoice? invoice;

  @override
  State<InvoiceEditorPage> createState() => _InvoiceEditorPageState();
}

class _InvoiceEditorPageState extends State<InvoiceEditorPage> {
  final _notesController = TextEditingController();
  final _discountController = TextEditingController(text: '0');
  final _taxController = TextEditingController(text: '0');
  final _extraController = TextEditingController(text: '0');
  final _paidController = TextEditingController(text: '0');
  final _lines = <_InvoiceLineEditor>[];
  String? _partyId;
  String _paymentMethod = 'Cash';
  DateTime _date = DateTime.now();
  bool _saving = false;

  /// True once the user changed something that is not saved yet.
  bool _dirty = false;

  bool get _isSales => widget.kind == InvoiceListKind.sales;

  List<_PartyOption> get _parties => _isSales
      ? widget.data.customers
            .map(
              (customer) => _PartyOption(
                id: customer.id,
                name: customer.name,
                code: customer.code,
                balance: customer.balance,
              ),
            )
            .toList()
      : widget.data.suppliers
            .map(
              (supplier) => _PartyOption(
                id: supplier.id,
                name: supplier.name,
                code: supplier.code,
                balance: supplier.balance,
              ),
            )
            .toList();

  @override
  void initState() {
    super.initState();
    final invoice = widget.invoice;
    if (invoice != null) {
      _partyId = invoice.partyId;
      _paymentMethod = invoice.paymentMethod;
      _date = DateTime.tryParse(invoice.issuedAt)?.toLocal() ?? DateTime.now();
      _notesController.text = invoice.notes ?? '';
      _discountController.text = invoice.discountAmount;
      _taxController.text = invoice.taxAmount;
      _extraController.text = invoice.extraCosts;
      _paidController.text = invoice.amountPaid;
      for (final line in invoice.lines) {
        final material = widget.data.materials
            .where((material) => material.id == line.materialId)
            .firstOrNull;
        _lines.add(
          _InvoiceLineEditor(
            material: material,
            quantity: line.quantity,
            unitPrice: line.unitPrice,
            discount: line.discountPercent,
            unitId: line.unitId,
            conversionFactor: line.conversionFactor,
          ),
        );
      }
    }
    if (_lines.isEmpty) {
      _lines.add(_InvoiceLineEditor());
    }
    _lines.first.quantity.text = '1';
    for (final line in _lines) {
      line.quantity.text = line.quantity.text.isEmpty
          ? '1'
          : line.quantity.text;
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _discountController.dispose();
    _taxController.dispose();
    _extraController.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  double get _subtotal =>
      _lines.fold<double>(0, (total, line) => total + line.total);

  double get _total {
    final value =
        _subtotal -
        parseAmount(_discountController.text) +
        parseAmount(_taxController.text) +
        parseAmount(_extraController.text);
    return value < 0 ? 0 : value;
  }

  void _addLine() {
    setState(() {
      _lines.add(_InvoiceLineEditor());
      _dirty = true;
    });
  }

  void _removeLine(int index) {
    if (_lines.length == 1) return;
    setState(() {
      _lines.removeAt(index).dispose();
      _dirty = true;
    });
  }

  Future<void> _pickDate() async {
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
  }

  Future<void> _save({required bool post}) async {
    if (_partyId == null || _partyId!.isEmpty) {
      _showErrorText(_isSales ? 'اختر العميل أولًا.' : 'اختر المورد أولًا.');
      return;
    }
    final prepared = <LedgerInvoiceLine>[];
    for (final line in _lines) {
      final material = line.material;
      if (material == null) continue;
      final quantity = parseAmount(line.quantity.text);
      final price = parseAmount(line.unitPrice.text);
      if (quantity <= 0) {
        _showErrorText('الكمية يجب أن تكون أكبر من صفر.');
        return;
      }
      if (price < 0) {
        _showErrorText('السعر لا يمكن أن يكون سالبًا.');
        return;
      }
      prepared.add(
        LedgerInvoiceLine(
          materialId: material.id,
          materialName: material.name,
          quantity: quantity.toString(),
          unitPrice: price.toString(),
          unitId: line.unitId ?? _baseUnitId(material),
          conversionFactor: line.conversionFactor ?? '1',
          discountPercent: parseAmount(line.discount.text).toString(),
          lineTotal: line.total.toString(),
          code: material.code,
          barcode: material.barcode,
          notes: null,
        ),
      );
    }
    if (prepared.isEmpty) {
      _showErrorText('أضف بندًا واحدًا على الأقل.');
      return;
    }

    final party = _parties.where((party) => party.id == _partyId).firstOrNull;
    final total = _total;
    final amountPaid = switch (_paymentMethod) {
      'Cash' => total.toStringAsFixed(2),
      'Partial' => parseAmount(_paidController.text).clamp(0, total).toString(),
      _ => '0',
    };

    final draft = InvoiceDraft(
      invoiceType: _isSales ? 'Sales' : 'Purchase',
      partyId: _partyId!,
      partyName: party?.name ?? '',
      lines: prepared,
      paymentMethod: _paymentMethod,
      amountPaid: amountPaid,
      discountAmount: _discountController.text.trim().isEmpty
          ? '0'
          : _discountController.text.trim(),
      taxAmount: _taxController.text.trim().isEmpty
          ? '0'
          : _taxController.text.trim(),
      extraCosts: _extraController.text.trim().isEmpty
          ? '0'
          : _extraController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      currency: widget.data.baseCurrency,
      issuedAt: _date,
    );

    setState(() => _saving = true);
    try {
      final existing = widget.invoice;
      if (existing == null) {
        await widget.gateway.createInvoice(draft, post: post);
      } else {
        if (existing.isPosted) {
          throw StateError('لا يمكن تعديل فاتورة مرحّلة.');
        }
        await widget.gateway.updateInvoice(existing.id, draft);
        if (post) {
          await widget.gateway.postInvoice(existing.id);
        }
      }
      if (!mounted) return;
      _dirty = false;
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
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _showErrorText(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return UnsavedChangesGuard(
      hasUnsavedChanges: _dirty,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.invoice == null
                ? (_isSales ? 'فاتورة بيع جديدة' : 'فاتورة شراء جديدة')
                : 'تعديل الفاتورة ${widget.invoice!.number}',
          ),
          actions: [
            TextButton(
              onPressed: _saving ? null : () => _save(post: false),
              child: const Text('حفظ كمسودة'),
            ),
            const SizedBox(width: AppSpacing.sm),
            FilledButton.icon(
              onPressed: _saving ? null : () => _save(post: true),
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_circle_outline, size: 18),
              label: const Text('حفظ وترحيل'),
            ),
            const SizedBox(width: AppSpacing.lg),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1100;
            final editor = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppSectionCard(
                  title: 'بيانات الفاتورة',
                  subtitle: 'الطرف والتاريخ وطريقة الدفع.',
                  child: Wrap(
                    spacing: AppSpacing.lg,
                    runSpacing: AppSpacing.lg,
                    children: [
                      SizedBox(
                        width: 300,
                        child: DropdownButtonFormField<String>(
                          initialValue: _partyId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: _isSales ? 'العميل' : 'المورد',
                            prefixIcon: Icon(
                              _isSales
                                  ? Icons.person_outline
                                  : Icons.local_shipping_outlined,
                            ),
                          ),
                          items: _parties
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
                      SizedBox(
                        width: 190,
                        child: InkWell(
                          onTap: widget.invoice == null ? _pickDate : null,
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
                          initialValue: _paymentMethod,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'طريقة الدفع',
                            prefixIcon: Icon(Icons.payments_outlined),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Cash',
                              child: Text('نقدي'),
                            ),
                            DropdownMenuItem(
                              value: 'Deferred',
                              child: Text('آجل'),
                            ),
                            DropdownMenuItem(
                              value: 'Partial',
                              child: Text('دفعة جزئية'),
                            ),
                          ],
                          onChanged: widget.invoice == null
                              ? (value) => setState(() {
                                  _paymentMethod = value ?? 'Cash';
                                  _dirty = true;
                                })
                              : null,
                        ),
                      ),
                      if (_paymentMethod == 'Partial')
                        SizedBox(
                          width: 190,
                          child: TextField(
                            controller: _paidController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: (_) => setState(() => _dirty = true),
                            decoration: const InputDecoration(
                              labelText: 'المدفوع',
                              prefixIcon: Icon(Icons.south_west_outlined),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppSectionCard(
                  title: 'بنود الفاتورة',
                  subtitle: 'اختر المادة والوحدة والكمية والسعر.',
                  action: OutlinedButton.icon(
                    onPressed: _addLine,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('إضافة بند'),
                  ),
                  child: Column(
                    children: [
                      for (var index = 0; index < _lines.length; index++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: _InvoiceLineRow(
                            key: ObjectKey(_lines[index]),
                            line: _lines[index],
                            index: index,
                            materials: widget.data.materials,
                            baseCurrency: widget.data.baseCurrency,
                            isSales: _isSales,
                            canDelete: _lines.length > 1,
                            onChanged: () => setState(() => _dirty = true),
                            onDelete: () => _removeLine(index),
                          ),
                        ),
                      const SizedBox(height: AppSpacing.sm),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton.icon(
                          onPressed: _addLine,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('بند جديد'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppSectionCard(
                  title: 'ملاحظات',
                  child: TextField(
                    controller: _notesController,
                    minLines: 2,
                    maxLines: 4,
                    onChanged: (_) => setState(() => _dirty = true),
                    decoration: const InputDecoration(
                      hintText: 'ملاحظات تظهر على الفاتورة...',
                    ),
                  ),
                ),
              ],
            );

            final summary = _InvoiceSummary(
              subtotal: _subtotal,
              discountController: _discountController,
              taxController: _taxController,
              extraController: _extraController,
              total: _total,
              currency: widget.data.baseCurrency,
              onChanged: () => setState(() => _dirty = true),
            );

            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: editor,
                    ),
                  ),
                  Container(
                    width: 340,
                    margin: const EdgeInsets.fromLTRB(
                      0,
                      AppSpacing.xl,
                      AppSpacing.xl,
                      0,
                    ),
                    child: summary,
                  ),
                ],
              );
            }
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              children: [
                editor,
                const SizedBox(height: AppSpacing.xl),
                summary,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _InvoiceLineEditor {
  _InvoiceLineEditor({
    this.material,
    String quantity = '1',
    String unitPrice = '',
    String discount = '0',
    this.unitId,
    this.conversionFactor,
  }) : quantity = TextEditingController(text: quantity),
       unitPrice = TextEditingController(text: unitPrice),
       discount = TextEditingController(text: discount);

  LedgerMaterial? material;
  String? unitId;
  String? conversionFactor;
  final TextEditingController quantity;
  final TextEditingController unitPrice;
  final TextEditingController discount;

  double get total {
    final gross = parseAmount(quantity.text) * parseAmount(unitPrice.text);
    final percent = parseAmount(discount.text);
    return (gross * (1 - percent / 100)).clamp(0, double.infinity);
  }

  void dispose() {
    quantity.dispose();
    unitPrice.dispose();
    discount.dispose();
  }
}

class _InvoiceLineRow extends StatelessWidget {
  const _InvoiceLineRow({
    super.key,
    required this.line,
    required this.index,
    required this.materials,
    required this.baseCurrency,
    required this.isSales,
    required this.canDelete,
    required this.onChanged,
    required this.onDelete,
  });

  final _InvoiceLineEditor line;
  final int index;
  final List<LedgerMaterial> materials;
  final String baseCurrency;
  final bool isSales;
  final bool canDelete;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final units = line.material?.units ?? const <LedgerMaterialUnit>[];
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 780;
          final fields = <Widget>[
            SizedBox(
              width: compact ? constraints.maxWidth : 300,
              child: AppMaterialPicker(
                label: 'المادة ${index + 1}',
                materials: materials,
                selectedId: line.material?.id,
                isSales: isSales,
                onSelected: (material) {
                  line.material = material;
                  line.unitId = material == null ? null : _baseUnitId(material);
                  line.conversionFactor = '1';
                  final price = isSales
                      ? material?.salePrice ?? ''
                      : material?.purchasePrice ?? '';
                  if (parseAmount(line.unitPrice.text) == 0 &&
                      parseAmount(price) > 0) {
                    line.unitPrice.text = price;
                  }
                  onChanged();
                },
              ),
            ),
            SizedBox(
              width: 160,
              child: DropdownButtonFormField<String>(
                key: ValueKey('${line.material?.id}-unit'),
                initialValue: line.unitId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'الوحدة'),
                items: units
                    .map(
                      (unit) => DropdownMenuItem(
                        value: unit.id,
                        child: Text(
                          '${unit.name} (×${unit.conversionFactor})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (id) {
                  final unit = units.where((unit) => unit.id == id).firstOrNull;
                  line.unitId = id;
                  line.conversionFactor = unit?.conversionFactor ?? '1';
                  onChanged();
                },
              ),
            ),
            SizedBox(
              width: 110,
              child: TextField(
                controller: line.quantity,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => onChanged(),
                decoration: const InputDecoration(labelText: 'الكمية'),
              ),
            ),
            SizedBox(
              width: 130,
              child: TextField(
                controller: line.unitPrice,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => onChanged(),
                decoration: const InputDecoration(labelText: 'السعر'),
              ),
            ),
            SizedBox(
              width: 110,
              child: TextField(
                controller: line.discount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => onChanged(),
                decoration: const InputDecoration(labelText: 'خصم %'),
              ),
            ),
            SizedBox(
              width: 140,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'الإجمالي'),
                child: Text(
                  formatMoney(line.total.toString(), currency: baseCurrency),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            IconButton(
              tooltip: 'حذف البند',
              onPressed: canDelete ? onDelete : null,
              icon: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ];
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final field in fields)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: field,
                  ),
              ],
            );
          }
          return Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: fields,
          );
        },
      ),
    );
  }
}

class _InvoiceSummary extends StatelessWidget {
  const _InvoiceSummary({
    required this.subtotal,
    required this.discountController,
    required this.taxController,
    required this.extraController,
    required this.total,
    required this.currency,
    required this.onChanged,
  });

  final double subtotal;
  final TextEditingController discountController;
  final TextEditingController taxController;
  final TextEditingController extraController;
  final double total;
  final String currency;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('ملخص الفاتورة', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.lg),
          _SummaryRow(
            label: 'المجموع الفرعي',
            value: formatMoney(subtotal.toString(), currency: currency),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: discountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(labelText: 'خصم إجمالي'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: taxController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(labelText: 'ضريبة'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: extraController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(labelText: 'تكاليف إضافية'),
          ),
          const Divider(height: AppSpacing.xxl),
          _SummaryRow(
            label: 'الإجمالي',
            value: formatMoney(total.toString(), currency: currency),
            strong: true,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppInfoBanner(
            title: 'ترحيل متكامل',
            message:
                'الحفظ والترحيل يحدّث المخزون وأرصدة الطرف والقيود المحاسبية في عملية واحدة.',
            icon: Icons.verified_outlined,
            tone: AppBadgeTone.info,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final style = strong
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyMedium;
    return Row(
      children: [
        Expanded(
          child: Text(label, style: style, overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: style?.copyWith(
              fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _PartyOption {
  const _PartyOption({
    required this.id,
    required this.name,
    required this.code,
    required this.balance,
  });

  final String id;
  final String name;
  final String code;
  final String balance;
}

String? _baseUnitId(LedgerMaterial material) {
  return material.units
      .where((unit) => unit.isBase)
      .map((unit) => unit.id)
      .firstOrNull;
}

void showInvoiceDetails(
  BuildContext context,
  LedgerInvoice invoice, {
  required bool isSales,
}) {
  showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  AppIconTile(
                    icon: isSales
                        ? Icons.receipt_long_outlined
                        : Icons.shopping_cart_checkout_outlined,
                    size: 42,
                    iconSize: 21,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'فاتورة ${invoice.number}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          '${invoice.partyName} • ${_formatDate(invoice.issuedAt)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  AppBadge(
                    label: invoice.isPosted ? 'مرحّلة' : 'مسودة',
                    tone: invoice.isPosted
                        ? AppBadgeTone.success
                        : AppBadgeTone.warning,
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: ListView(
                  children: [
                    for (final line in invoice.lines)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: AppAvatar(name: line.materialName, size: 34),
                        title: Text(line.materialName),
                        subtitle: Text(
                          '${line.quantity} × ${formatMoney(line.unitPrice, currency: invoice.currency)}'
                          '${parseAmount(line.discountPercent) > 0 ? ' • خصم ${line.discountPercent}%' : ''}',
                        ),
                        trailing: Text(
                          formatMoney(
                            line.lineTotal,
                            currency: invoice.currency,
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(),
              _SummaryRow(
                label: 'المجموع الفرعي',
                value: formatMoney(
                  invoice.subtotal,
                  currency: invoice.currency,
                ),
              ),
              const SizedBox(height: 6),
              _SummaryRow(
                label: 'الخصم',
                value: formatMoney(
                  invoice.discountAmount,
                  currency: invoice.currency,
                ),
              ),
              const SizedBox(height: 6),
              _SummaryRow(
                label: 'الضريبة',
                value: formatMoney(
                  invoice.taxAmount,
                  currency: invoice.currency,
                ),
              ),
              const SizedBox(height: 6),
              _SummaryRow(
                label: 'الإجمالي',
                value: formatMoney(invoice.total, currency: invoice.currency),
                strong: true,
              ),
              const SizedBox(height: 6),
              _SummaryRow(
                label: 'المدفوع',
                value: formatMoney(
                  invoice.amountPaid,
                  currency: invoice.currency,
                ),
              ),
              const SizedBox(height: 6),
              _SummaryRow(
                label: 'المتبقي',
                value: formatMoney(
                  invoice.remaining,
                  currency: invoice.currency,
                ),
              ),
              if ((invoice.notes ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  invoice.notes!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

enum ReturnListKind { sales, purchase }

class ReturnsPage extends StatefulWidget {
  const ReturnsPage({
    super.key,
    required this.gateway,
    required this.data,
    required this.kind,
    required this.onChanged,
  });

  final LedgerGateway gateway;
  final WorkspaceData data;
  final ReturnListKind kind;
  final Future<void> Function() onChanged;

  @override
  State<ReturnsPage> createState() => _ReturnsPageState();
}

class _ReturnsPageState extends State<ReturnsPage> {
  final _searchController = TextEditingController();
  String _query = '';

  bool get _isSales => widget.kind == ReturnListKind.sales;

  List<LedgerReturn> get _returns =>
      _isSales ? widget.data.salesReturns : widget.data.purchaseReturns;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openEditor() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ReturnEditorPage(
          gateway: widget.gateway,
          data: widget.data,
          kind: widget.kind,
        ),
      ),
    );
    if (saved == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إنشاء المرتجع وترحيله.')),
      );
      await widget.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _returns.where((item) {
      if (_query.isEmpty) return true;
      return '${item.number} ${item.partyName} ${item.total}'
          .toLowerCase()
          .contains(_query);
    }).toList();
    final total = _returns
        .map((item) => parseAmount(item.total))
        .fold<double>(0, (a, b) => a + b);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        AppPageHeader(
          title: _isSales ? 'مرتجعات البيع' : 'مرتجعات الشراء',
          subtitle: _isSales
              ? 'إعادة مواد من العملاء مع عكس أثر البيع.'
              : 'إعادة مواد إلى الموردين مع تحديث المخزون والأرصدة.',
          icon: Icons.assignment_return_outlined,
          actions: [
            FilledButton.icon(
              onPressed: _openEditor,
              icon: const Icon(Icons.add, size: 18),
              label: Text(_isSales ? 'مرتجع بيع جديد' : 'مرتجع شراء جديد'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        AppMetricGrid(
          maxColumns: 3,
          children: [
            AppMetricCard(
              label: 'عدد المرتجعات',
              value: formatNumberValue(_returns.length, decimals: 0),
              icon: Icons.assignment_return_outlined,
            ),
            AppMetricCard(
              label: 'قيمة المرتجعات',
              value: formatMoney(
                total.toString(),
                currency: widget.data.baseCurrency,
              ),
              icon: Icons.summarize_outlined,
              tone: AppBadgeTone.warning,
            ),
            AppMetricCard(
              label: 'آخر مرتجع',
              value: _returns.isEmpty
                  ? '—'
                  : _formatDate(_returns.first.returnDate),
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
              hintText: 'بحث برقم المرتجع أو الطرف...',
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppDataTable<LedgerReturn>(
          tableId: _isSales ? 'sales-returns' : 'purchase-returns',
          rows: visible,
          minWidth: 900,
          emptyTitle: 'لا توجد مرتجعات',
          emptyMessage: 'أنشئ مرتجعًا جديدًا؛ سيتم ترحيله فورًا.',
          emptyIcon: Icons.assignment_return_outlined,
          columns: [
            AppTableColumn(
              id: 'number',
              label: 'الرقم',
              flex: 2,
              sortable: true,
              sortValue: (item) => item.number,
              builder: (context, item) => AppTableText(
                item.number,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            AppTableColumn(
              id: 'party',
              label: _isSales ? 'العميل' : 'المورد',
              flex: 3,
              sortable: true,
              sortValue: (item) => item.partyName,
              builder: (context, item) =>
                  AppTableText(item.partyName.isEmpty ? '—' : item.partyName),
            ),
            AppTableColumn(
              id: 'date',
              label: 'التاريخ',
              flex: 2,
              sortable: true,
              sortValue: (item) => item.returnDate,
              builder: (context, item) =>
                  AppTableText(_formatDate(item.returnDate)),
            ),
            AppTableColumn(
              id: 'lines',
              label: 'عدد البنود',
              flex: 2,
              sortable: true,
              sortValue: (item) => item.lines.length,
              builder: (context, item) => AppTableText('${item.lines.length}'),
            ),
            AppTableColumn(
              id: 'total',
              label: 'الإجمالي',
              flex: 2,
              sortable: true,
              sortValue: (item) => parseAmount(item.total),
              alignment: AlignmentDirectional.centerEnd,
              headerAlignment: AlignmentDirectional.centerEnd,
              builder: (context, item) => AppTableText(
                formatMoney(item.total, currency: widget.data.baseCurrency),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            AppTableColumn(
              id: 'status',
              label: 'الحالة',
              flex: 2,
              builder: (context, item) => const AppBadge(
                label: 'مرحّل',
                tone: AppBadgeTone.success,
                compact: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class ReturnEditorPage extends StatefulWidget {
  const ReturnEditorPage({
    super.key,
    required this.gateway,
    required this.data,
    required this.kind,
  });

  final LedgerGateway gateway;
  final WorkspaceData data;
  final ReturnListKind kind;

  @override
  State<ReturnEditorPage> createState() => _ReturnEditorPageState();
}

class _ReturnEditorPageState extends State<ReturnEditorPage> {
  final _notesController = TextEditingController();
  final _settlementAmountController = TextEditingController(text: '0');
  final _lines = <_InvoiceLineEditor>[];
  String? _partyId;
  String _settlementMode = 'deduct_from_debt';
  DateTime _date = DateTime.now();
  bool _saving = false;

  /// True once the user changed something that is not saved yet.
  bool _dirty = false;

  bool get _isSales => widget.kind == ReturnListKind.sales;

  @override
  void initState() {
    super.initState();
    _lines.add(_InvoiceLineEditor(quantity: '1'));
  }

  @override
  void dispose() {
    _notesController.dispose();
    _settlementAmountController.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  double get _total =>
      _lines.fold<double>(0, (total, line) => total + line.total);

  Future<void> _save() async {
    if (_partyId == null || _partyId!.isEmpty) {
      _showError('اختر ${_isSales ? 'العميل' : 'المورد'} أولًا.');
      return;
    }
    final lines = <LedgerReturnLine>[];
    for (final line in _lines) {
      final material = line.material;
      if (material == null) continue;
      final quantity = parseAmount(line.quantity.text);
      final price = parseAmount(line.unitPrice.text);
      if (quantity <= 0) {
        _showError('الكمية يجب أن تكون أكبر من صفر.');
        return;
      }
      lines.add(
        LedgerReturnLine(
          materialId: material.id,
          materialName: material.name,
          quantity: quantity.toString(),
          unitPrice: price.toString(),
          unitId: line.unitId ?? _baseUnitId(material),
          lineTotal: line.total.toString(),
        ),
      );
    }
    if (lines.isEmpty) {
      _showError('أضف بندًا واحدًا على الأقل.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد إنشاء المرتجع'),
        content: const Text(
          'سيتم ترحيل المرتجع فورًا وتحديث المخزون والأرصدة والقيود.\n'
          'لا يمكن تعديل مرتجع مرحّل؛ تأكد من البيانات قبل المتابعة.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('إنشاء وترحيل'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final draft = ReturnDraft(
      kind: _isSales ? 'Sales' : 'Purchase',
      partyId: _partyId!,
      lines: lines,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      settlementMode: _settlementMode,
      settlementAmount: _settlementMode == 'partial_settlement'
          ? _settlementAmountController.text.trim()
          : null,
      isPaid: _settlementMode == 'full_cash_return',
      returnDate: _date,
    );

    setState(() => _saving = true);
    try {
      if (_isSales) {
        await widget.gateway.createSalesReturn(draft);
      } else {
        await widget.gateway.createPurchaseReturn(draft);
      }
      if (!mounted) return;
      _dirty = false;
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
    final parties = _isSales
        ? widget.data.customers
              .map(
                (customer) => _PartyOption(
                  id: customer.id,
                  name: customer.name,
                  code: customer.code,
                  balance: customer.balance,
                ),
              )
              .toList()
        : widget.data.suppliers
              .map(
                (supplier) => _PartyOption(
                  id: supplier.id,
                  name: supplier.name,
                  code: supplier.code,
                  balance: supplier.balance,
                ),
              )
              .toList();

    return UnsavedChangesGuard(
      hasUnsavedChanges: _dirty,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isSales ? 'مرتجع بيع جديد' : 'مرتجع شراء جديد'),
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
              label: const Text('إنشاء وترحيل'),
            ),
            const SizedBox(width: AppSpacing.lg),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            AppSectionCard(
              title: 'بيانات المرتجع',
              subtitle: 'الطرف والتاريخ وطريقة التسوية.',
              child: Wrap(
                spacing: AppSpacing.lg,
                runSpacing: AppSpacing.lg,
                children: [
                  SizedBox(
                    width: 300,
                    child: DropdownButtonFormField<String>(
                      initialValue: _partyId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: _isSales ? 'العميل' : 'المورد',
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
                    width: 280,
                    child: DropdownButtonFormField<String>(
                      initialValue: _settlementMode,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'طريقة التسوية',
                        prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'deduct_from_debt',
                          child: Text('خصم من رصيد الطرف'),
                        ),
                        DropdownMenuItem(
                          value: 'full_cash_return',
                          child: Text('إرجاع نقدي كامل'),
                        ),
                        DropdownMenuItem(
                          value: 'partial_settlement',
                          child: Text('تسوية جزئية'),
                        ),
                      ],
                      onChanged: (value) => setState(() {
                        _settlementMode = value ?? 'deduct_from_debt';
                        _dirty = true;
                      }),
                    ),
                  ),
                  if (_settlementMode == 'partial_settlement')
                    SizedBox(
                      width: 190,
                      child: TextField(
                        controller: _settlementAmountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => setState(() => _dirty = true),
                        decoration: const InputDecoration(
                          labelText: 'المبلغ النقدي',
                          prefixIcon: Icon(Icons.payments_outlined),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppSectionCard(
              title: 'بنود المرتجع',
              action: OutlinedButton.icon(
                onPressed: () => setState(() {
                  _lines.add(_InvoiceLineEditor());
                  _dirty = true;
                }),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('إضافة بند'),
              ),
              child: Column(
                children: [
                  for (var index = 0; index < _lines.length; index++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _InvoiceLineRow(
                        key: ObjectKey(_lines[index]),
                        line: _lines[index],
                        index: index,
                        materials: widget.data.materials,
                        baseCurrency: widget.data.baseCurrency,
                        isSales: _isSales,
                        canDelete: _lines.length > 1,
                        onChanged: () => setState(() => _dirty = true),
                        onDelete: () => setState(() {
                          _lines.removeAt(index).dispose();
                          _dirty = true;
                        }),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _notesController,
                    minLines: 2,
                    maxLines: 4,
                    onChanged: (_) => setState(() => _dirty = true),
                    decoration: const InputDecoration(labelText: 'ملاحظات'),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _SummaryRow(
                    label: 'إجمالي المرتجع',
                    value: formatMoney(
                      _total.toString(),
                      currency: widget.data.baseCurrency,
                    ),
                    strong: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(String raw) {
  final value = DateTime.tryParse(raw)?.toLocal();
  if (value == null) return raw;
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}/$month/$day';
}

String _paymentLabel(String raw) {
  return switch (raw) {
    'Cash' => 'نقدي',
    'Deferred' => 'آجل',
    'Partial' => 'جزئي',
    _ => raw,
  };
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
