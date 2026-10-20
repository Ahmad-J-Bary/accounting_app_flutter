import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ledger.dart';

class _OpeningBalancesData {
  const _OpeningBalancesData({
    required this.customers,
    required this.suppliers,
  });

  final List<LedgerCustomer> customers;
  final List<LedgerSupplier> suppliers;
}

class OpeningBalancesPage extends StatefulWidget {
  const OpeningBalancesPage({super.key, required this.gateway});

  final LedgerGateway gateway;

  @override
  State<OpeningBalancesPage> createState() => _OpeningBalancesPageState();
}

class _OpeningBalancesPageState extends State<OpeningBalancesPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late Future<_OpeningBalancesData> _future;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _future = _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<_OpeningBalancesData> _load() async {
    final customers = await widget.gateway.loadCustomers();
    final suppliers = await widget.gateway.loadSuppliers();
    return _OpeningBalancesData(customers: customers, suppliers: suppliers);
  }

  void _refresh() {
    setState(() {
      _future = _load();
    });
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _showError(Object error) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(describeError(error)),
          duration: const Duration(seconds: 6),
        ),
      );
  }

  Future<void> _editCustomer(LedgerCustomer customer) async {
    final value = await showDialog<String>(
      context: context,
      builder: (_) => _OpeningBalanceDialog(
        title: 'الرصيد الافتتاحي — ${customer.name}',
        helperText:
            'أدخل صافي الرصيد المدين للعميل. القيمة الموجبة تعني أن العميل مدين لنا.',
        initialValue: customer.openingBalance,
        currency: customer.currency,
      ),
    );
    if (value == null) {
      return;
    }

    try {
      await widget.gateway.updateCustomer(
        id: customer.id,
        code: customer.code,
        name: customer.name,
        phone: customer.phone,
        address: customer.address,
        notes: customer.notes,
        openingBalance: value,
        isActive: customer.isActive,
      );
      _showMessage('تم تحديث الرصيد الافتتاحي للعميل.');
      _refresh();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _editSupplier(LedgerSupplier supplier) async {
    final value = await showDialog<String>(
      context: context,
      builder: (_) => _OpeningBalanceDialog(
        title: 'الرصيد الافتتاحي — ${supplier.name}',
        helperText:
            'أدخل صافي الرصيد الدائن للمورد. القيمة الموجبة تعني أن المورد دائن لنا.',
        initialValue: supplier.openingBalance,
        currency: supplier.currency,
      ),
    );
    if (value == null) {
      return;
    }

    try {
      await widget.gateway.updateSupplier(
        id: supplier.id,
        code: supplier.code,
        name: supplier.name,
        phone: supplier.phone,
        address: supplier.address,
        notes: supplier.notes,
        openingBalance: value,
        isActive: supplier.isActive,
      );
      _showMessage('تم تحديث الرصيد الافتتاحي للمورد.');
      _refresh();
    } catch (error) {
      _showError(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الأرصدة الافتتاحية'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'العملاء'),
            Tab(text: 'الموردون'),
          ],
        ),
      ),
      body: FutureBuilder<_OpeningBalancesData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'تعذّر تحميل الأرصدة الافتتاحية.\n${describeError(snapshot.error!)}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _refresh,
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data!;
          return Column(
            children: [
              const _OpeningBalanceNotice(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _CustomerBalances(
                      customers: data.customers,
                      onEdit: _editCustomer,
                    ),
                    _SupplierBalances(
                      suppliers: data.suppliers,
                      onEdit: _editSupplier,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OpeningBalanceNotice extends StatelessWidget {
  const _OpeningBalanceNotice();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: scheme.onSecondaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'تعديل الرصيد الافتتاحي قد يُنشئ قيد تسوية تلقائيًا في دفتر اليومية. '
              'إذا كانت نافذة ترحيل الأرصدة الافتتاحية مفتوحة، فسيُدرج الفرق ضمن الترحيل بدلًا من قيد منفصل. '
              'راجع الأثر المحاسبي قبل الحفظ.',
              style: TextStyle(color: scheme.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerBalances extends StatelessWidget {
  const _CustomerBalances({required this.customers, required this.onEdit});

  final List<LedgerCustomer> customers;
  final ValueChanged<LedgerCustomer> onEdit;

  @override
  Widget build(BuildContext context) {
    if (customers.isEmpty) {
      return const Center(child: Text('لا يوجد عملاء بعد.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: customers.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final customer = customers[index];
        return ListTile(
          onTap: () => onEdit(customer),
          leading: CircleAvatar(
            child: Text(customer.code.isEmpty ? '?' : customer.code),
          ),
          title: Text(customer.name),
          subtitle: Text(
            'الافتتاحي: ${customer.openingBalance} ${customer.currency} • '
            'الرصيد الحالي: ${customer.balance} ${customer.currency}'
            '${customer.isActive ? '' : ' • غير نشط'}',
          ),
          trailing: IconButton(
            tooltip: 'تعديل الرصيد الافتتاحي',
            onPressed: () => onEdit(customer),
            icon: const Icon(Icons.edit_outlined),
          ),
        );
      },
    );
  }
}

class _SupplierBalances extends StatelessWidget {
  const _SupplierBalances({required this.suppliers, required this.onEdit});

  final List<LedgerSupplier> suppliers;
  final ValueChanged<LedgerSupplier> onEdit;

  @override
  Widget build(BuildContext context) {
    if (suppliers.isEmpty) {
      return const Center(child: Text('لا يوجد موردون بعد.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: suppliers.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final supplier = suppliers[index];
        return ListTile(
          onTap: () => onEdit(supplier),
          leading: CircleAvatar(
            child: Text(supplier.code.isEmpty ? '?' : supplier.code),
          ),
          title: Text(supplier.name),
          subtitle: Text(
            'الافتتاحي: ${supplier.openingBalance} ${supplier.currency} • '
            'الرصيد الحالي: ${supplier.balance} ${supplier.currency}'
            '${supplier.isActive ? '' : ' • غير نشط'}',
          ),
          trailing: IconButton(
            tooltip: 'تعديل الرصيد الافتتاحي',
            onPressed: () => onEdit(supplier),
            icon: const Icon(Icons.edit_outlined),
          ),
        );
      },
    );
  }
}

class _OpeningBalanceDialog extends StatefulWidget {
  const _OpeningBalanceDialog({
    required this.title,
    required this.helperText,
    required this.initialValue,
    required this.currency,
  });

  final String title;
  final String helperText;
  final String initialValue;
  final String currency;

  @override
  State<_OpeningBalanceDialog> createState() => _OpeningBalanceDialogState();
}

class _OpeningBalanceDialogState extends State<_OpeningBalanceDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(
      text: widget.initialValue.trim().isEmpty ? '0' : widget.initialValue,
    );
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    Navigator.of(context).pop(_amount.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.helperText,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amount,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: InputDecoration(
                  labelText: 'المبلغ (${widget.currency})',
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) {
                    return 'يجب إدخال المبلغ.';
                  }
                  final parsed = double.tryParse(text);
                  if (parsed == null) {
                    return 'أدخل مبلغًا صحيحًا.';
                  }
                  if (parsed < 0) {
                    return 'لا يمكن أن يكون المبلغ سالبًا.';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _save(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(onPressed: _save, child: const Text('حفظ')),
      ],
    );
  }
}
