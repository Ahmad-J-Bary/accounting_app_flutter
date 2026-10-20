import 'package:flutter/material.dart';

import 'categories.dart';
import 'ledger.dart';
import 'master_data_forms.dart';
import 'material_units.dart';
import 'opening_balances.dart';

class _DirectoryData {
  const _DirectoryData({
    required this.customers,
    required this.suppliers,
    required this.materials,
    required this.categories,
    required this.currencies,
    required this.baseCurrency,
  });

  final List<LedgerCustomer> customers;
  final List<LedgerSupplier> suppliers;
  final List<LedgerMaterial> materials;
  final List<LedgerCategory> categories;
  final List<CurrencyOption> currencies;
  final String baseCurrency;
}

enum _RowAction { edit, delete, units }

/// Master-data browser with create, edit and delete for customers, suppliers
/// and materials. Every write goes through the Rust core; the page only
/// refreshes after the bridge confirms success.
class DirectoryPage extends StatefulWidget {
  const DirectoryPage({super.key, required this.gateway});

  final LedgerGateway gateway;

  @override
  State<DirectoryPage> createState() => _DirectoryPageState();
}

class _DirectoryPageState extends State<DirectoryPage>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  late final TabController _tabController;
  late Future<_DirectoryData> _future;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _future = _load();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      setState(() {});
    }
  }

  Future<_DirectoryData> _load() async {
    final status = await widget.gateway.loadStatus();
    final currencies = await widget.gateway.availableCurrencies();
    final customers = await widget.gateway.loadCustomers();
    final suppliers = await widget.gateway.loadSuppliers();
    final materials = await widget.gateway.loadMaterials();
    final categories = await widget.gateway.loadCategories();
    return _DirectoryData(
      customers: customers,
      suppliers: suppliers,
      materials: materials,
      categories: categories,
      currencies: currencies,
      baseCurrency: status.baseCurrencyCode,
    );
  }

  void _refresh() {
    setState(() {
      _future = _load();
    });
  }

  bool _matches(String value) {
    if (_query.isEmpty) {
      return true;
    }
    return value.toLowerCase().contains(_query);
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

  Future<bool> _confirmDelete({
    required String title,
    required String message,
  }) async {
    final confirmed = await showDialog<bool>(
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
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _openCustomerForm(
    _DirectoryData data, {
    LedgerCustomer? customer,
  }) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CustomerFormPage(
          gateway: widget.gateway,
          currencies: data.currencies,
          baseCurrency: data.baseCurrency,
          customer: customer,
        ),
      ),
    );
    if (saved == true) {
      _showMessage(customer == null ? 'تمت إضافة العميل.' : 'تم تحديث العميل.');
      _refresh();
    }
  }

  Future<void> _openSupplierForm(
    _DirectoryData data, {
    LedgerSupplier? supplier,
  }) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SupplierFormPage(
          gateway: widget.gateway,
          currencies: data.currencies,
          baseCurrency: data.baseCurrency,
          supplier: supplier,
        ),
      ),
    );
    if (saved == true) {
      _showMessage(supplier == null ? 'تمت إضافة المورد.' : 'تم تحديث المورد.');
      _refresh();
    }
  }

  Future<void> _openMaterialForm(
    _DirectoryData data, {
    LedgerMaterial? material,
  }) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MaterialFormPage(
          gateway: widget.gateway,
          currencies: data.currencies,
          baseCurrency: data.baseCurrency,
          categories: data.categories,
          material: material,
        ),
      ),
    );
    if (saved == true) {
      _showMessage(material == null ? 'تمت إضافة المادة.' : 'تم تحديث المادة.');
      _refresh();
    }
  }

  Future<void> _openCategories() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CategoriesPage(gateway: widget.gateway),
      ),
    );
    _refresh();
  }

  Future<void> _openOpeningBalances() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => OpeningBalancesPage(gateway: widget.gateway),
      ),
    );
    _refresh();
  }

  Future<void> _openMaterialUnits(LedgerMaterial material) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            MaterialUnitsPage(gateway: widget.gateway, material: material),
      ),
    );
    _refresh();
  }

  Future<void> _deleteCustomer(LedgerCustomer customer) async {
    final confirmed = await _confirmDelete(
      title: 'حذف العميل',
      message:
          'هل تريد حذف العميل «${customer.name}»؟\n'
          'سيُحذف الحساب المرتبط إن أمكن، ولن يُسمح بالحذف إذا كانت هناك قيود مرحلة.',
    );
    if (!confirmed) {
      return;
    }
    try {
      await widget.gateway.deleteCustomer(customer.id);
      _showMessage('تم حذف العميل.');
      _refresh();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _deleteSupplier(LedgerSupplier supplier) async {
    final confirmed = await _confirmDelete(
      title: 'حذف المورد',
      message:
          'هل تريد حذف المورد «${supplier.name}»؟\n'
          'سيُحذف الحساب المرتبط إن أمكن، ولن يُسمح بالحذف إذا كانت هناك قيود مرحلة.',
    );
    if (!confirmed) {
      return;
    }
    try {
      await widget.gateway.deleteSupplier(supplier.id);
      _showMessage('تم حذف المورد.');
      _refresh();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _deleteMaterial(LedgerMaterial material) async {
    final confirmed = await _confirmDelete(
      title: 'حذف المادة',
      message:
          'هل تريد حذف المادة «${material.name}»؟\n'
          'لن يُسمح بالحذف إذا كانت للمادة حركات مخزنية.',
    );
    if (!confirmed) {
      return;
    }
    try {
      await widget.gateway.deleteMaterial(material.id);
      _showMessage('تم حذف المادة.');
      _refresh();
    } catch (error) {
      _showError(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DirectoryData>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        return Scaffold(
          appBar: AppBar(
            title: const Text('البيانات الأساسية'),
            actions: [
              IconButton(
                tooltip: 'تصنيفات المواد',
                onPressed: _openCategories,
                icon: const Icon(Icons.category_outlined),
              ),
              IconButton(
                tooltip: 'الأرصدة الافتتاحية',
                onPressed: _openOpeningBalances,
                icon: const Icon(Icons.account_balance_wallet_outlined),
              ),
              IconButton(
                tooltip: 'تحديث',
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: _buildBody(snapshot),
          floatingActionButton: data == null ? null : _buildFab(data),
        );
      },
    );
  }

  Widget _buildBody(AsyncSnapshot<_DirectoryData> snapshot) {
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
                'تعذّر تحميل البيانات الأساسية.\n${describeError(snapshot.error!)}',
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
    final customers = data.customers
        .where((c) => _matches('${c.code} ${c.name} ${c.phone ?? ''}'))
        .toList();
    final suppliers = data.suppliers
        .where((s) => _matches('${s.code} ${s.name} ${s.phone ?? ''}'))
        .toList();
    final materials = data.materials
        .where((m) => _matches('${m.code} ${m.name} ${m.nameEn} ${m.barcode}'))
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'بحث بالاسم أو الرمز أو الباركود',
              border: const OutlineInputBorder(),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'مسح البحث',
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.clear),
                    ),
            ),
            onChanged: (value) {
              setState(() => _query = value.trim().toLowerCase());
            },
          ),
        ),
        TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'العملاء (${customers.length})'),
            Tab(text: 'الموردون (${suppliers.length})'),
            Tab(text: 'المواد (${materials.length})'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _CustomerList(
                customers: customers,
                onEdit: (customer) =>
                    _openCustomerForm(data, customer: customer),
                onDelete: _deleteCustomer,
                onCreate: () => _openCustomerForm(data),
              ),
              _SupplierList(
                suppliers: suppliers,
                onEdit: (supplier) =>
                    _openSupplierForm(data, supplier: supplier),
                onDelete: _deleteSupplier,
                onCreate: () => _openSupplierForm(data),
              ),
              _MaterialList(
                materials: materials,
                categoryNames: {
                  for (final category in data.categories)
                    category.id: categoryLabel(category, data.categories),
                },
                onEdit: (material) =>
                    _openMaterialForm(data, material: material),
                onDelete: _deleteMaterial,
                onUnits: _openMaterialUnits,
                onCreate: () => _openMaterialForm(data),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFab(_DirectoryData data) {
    switch (_tabController.index) {
      case 0:
        return FloatingActionButton.extended(
          onPressed: () => _openCustomerForm(data),
          icon: const Icon(Icons.person_add_alt_1_outlined),
          label: const Text('إضافة عميل'),
        );
      case 1:
        return FloatingActionButton.extended(
          onPressed: () => _openSupplierForm(data),
          icon: const Icon(Icons.local_shipping_outlined),
          label: const Text('إضافة مورد'),
        );
      default:
        return FloatingActionButton.extended(
          onPressed: () => _openMaterialForm(data),
          icon: const Icon(Icons.add_box_outlined),
          label: const Text('إضافة مادة'),
        );
    }
  }
}

class _CustomerList extends StatelessWidget {
  const _CustomerList({
    required this.customers,
    required this.onEdit,
    required this.onDelete,
    required this.onCreate,
  });

  final List<LedgerCustomer> customers;
  final ValueChanged<LedgerCustomer> onEdit;
  final ValueChanged<LedgerCustomer> onDelete;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    if (customers.isEmpty) {
      return _EmptyList(
        message: 'لا يوجد عملاء مطابقون.',
        onCreate: onCreate,
        createLabel: 'إضافة عميل',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
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
            [
              customer.code,
              if (customer.phone != null && customer.phone!.isNotEmpty)
                customer.phone!,
              if (!customer.isActive) 'غير نشط',
            ].join(' • '),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 110),
                child: Text(
                  '${customer.balance} ${customer.currency}',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              _RowActions(
                onEdit: () => onEdit(customer),
                onDelete: () => onDelete(customer),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SupplierList extends StatelessWidget {
  const _SupplierList({
    required this.suppliers,
    required this.onEdit,
    required this.onDelete,
    required this.onCreate,
  });

  final List<LedgerSupplier> suppliers;
  final ValueChanged<LedgerSupplier> onEdit;
  final ValueChanged<LedgerSupplier> onDelete;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    if (suppliers.isEmpty) {
      return _EmptyList(
        message: 'لا يوجد موردون مطابقون.',
        onCreate: onCreate,
        createLabel: 'إضافة مورد',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
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
            [
              supplier.code,
              if (supplier.phone != null && supplier.phone!.isNotEmpty)
                supplier.phone!,
              if (!supplier.isActive) 'غير نشط',
            ].join(' • '),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 110),
                child: Text(
                  '${supplier.balance} ${supplier.currency}',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              _RowActions(
                onEdit: () => onEdit(supplier),
                onDelete: () => onDelete(supplier),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MaterialList extends StatelessWidget {
  const _MaterialList({
    required this.materials,
    required this.categoryNames,
    required this.onEdit,
    required this.onDelete,
    required this.onUnits,
    required this.onCreate,
  });

  final List<LedgerMaterial> materials;
  final Map<String, String> categoryNames;
  final ValueChanged<LedgerMaterial> onEdit;
  final ValueChanged<LedgerMaterial> onDelete;
  final ValueChanged<LedgerMaterial> onUnits;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    if (materials.isEmpty) {
      return _EmptyList(
        message: 'لا توجد مواد مطابقة.',
        onCreate: onCreate,
        createLabel: 'إضافة مادة',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
      itemCount: materials.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final material = materials[index];
        final labels = material.categoryIds
            .map((id) => categoryNames[id])
            .whereType<String>()
            .toList();
        return ListTile(
          onTap: () => onEdit(material),
          leading: Icon(
            material.hasExpiry
                ? Icons.event_available_outlined
                : Icons.inventory_2_outlined,
          ),
          title: Text(material.name),
          subtitle: Text(
            [
              material.code,
              if (material.barcode.isNotEmpty) 'باركود: ${material.barcode}',
              if (labels.isNotEmpty) 'التصنيف: ${labels.join('، ')}',
              if (material.unitName.isNotEmpty) 'الوحدة: ${material.unitName}',
              if (material.unitsCount > 1) 'الوحدات: ${material.unitsCount}',
              'متاح: ${material.totalAvailable}',
              'حد أدنى: ${material.minimumStock}',
            ].join(' • '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (material.purchasePrice.isNotEmpty ||
                  material.salePrice.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 110),
                  child: Text(
                    'شراء ${material.purchasePrice} • بيع ${material.salePrice}',
                    textAlign: TextAlign.end,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              _RowActions(
                onEdit: () => onEdit(material),
                onDelete: () => onDelete(material),
                onUnits: () => onUnits(material),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RowActions extends StatelessWidget {
  const _RowActions({
    required this.onEdit,
    required this.onDelete,
    this.onUnits,
  });

  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onUnits;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_RowAction>(
      tooltip: 'إجراءات',
      onSelected: (action) {
        switch (action) {
          case _RowAction.edit:
            onEdit();
          case _RowAction.delete:
            onDelete();
          case _RowAction.units:
            onUnits?.call();
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: _RowAction.edit,
          child: Row(
            children: [
              Icon(Icons.edit_outlined),
              SizedBox(width: 8),
              Text('تعديل'),
            ],
          ),
        ),
        if (onUnits != null)
          const PopupMenuItem(
            value: _RowAction.units,
            child: Row(
              children: [
                Icon(Icons.straighten),
                SizedBox(width: 8),
                Text('الوحدات'),
              ],
            ),
          ),
        const PopupMenuItem(
          value: _RowAction.delete,
          child: Row(
            children: [
              Icon(Icons.delete_outline),
              SizedBox(width: 8),
              Text('حذف'),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyList extends StatelessWidget {
  const _EmptyList({
    required this.message,
    required this.onCreate,
    required this.createLabel,
  });

  final String message;
  final VoidCallback onCreate;
  final String createLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inbox_outlined, size: 48),
          const SizedBox(height: 8),
          Text(message),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: Text(createLabel),
          ),
        ],
      ),
    );
  }
}
