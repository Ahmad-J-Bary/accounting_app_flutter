import 'package:flutter/material.dart';

import 'categories.dart';
import 'ledger.dart';
import 'master_data_forms.dart';
import 'material_units.dart';
import 'opening_balances.dart';
import 'theme/app_theme.dart';
import 'ui/app_ui.dart';
import 'workspace_data.dart';

enum DirectoryTab { customers, suppliers, materials }

enum _RowAction { edit, delete, units }

/// Master-data browser with create, edit and delete for customers, suppliers
/// and materials. Every write goes through the Rust core; the page only
/// refreshes after the bridge confirms success.
class DirectoryPage extends StatefulWidget {
  const DirectoryPage({
    super.key,
    required this.gateway,
    required this.data,
    this.initialTab = DirectoryTab.customers,
    this.onChanged,
    this.onOpenCategories,
    this.onOpenOpeningBalances,
  });

  final LedgerGateway gateway;
  final WorkspaceData data;
  final DirectoryTab initialTab;
  final Future<void> Function()? onChanged;
  final Future<void> Function()? onOpenCategories;
  final Future<void> Function()? onOpenOpeningBalances;

  @override
  State<DirectoryPage> createState() => _DirectoryPageState();
}

class _DirectoryPageState extends State<DirectoryPage>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  late final TabController _tabController;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.index,
    );
    _tabController.addListener(_onTabChanged);
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
      setState(() => _query = '');
      _searchController.clear();
    }
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

  Future<void> _notifyChanged() async {
    await widget.onChanged?.call();
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

  Future<void> _openCustomerForm({LedgerCustomer? customer}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CustomerFormPage(
          gateway: widget.gateway,
          currencies: widget.data.currencies,
          baseCurrency: widget.data.baseCurrency,
          customer: customer,
        ),
      ),
    );
    if (saved == true) {
      _showMessage(customer == null ? 'تمت إضافة العميل.' : 'تم تحديث العميل.');
      await _notifyChanged();
    }
  }

  Future<void> _openSupplierForm({LedgerSupplier? supplier}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SupplierFormPage(
          gateway: widget.gateway,
          currencies: widget.data.currencies,
          baseCurrency: widget.data.baseCurrency,
          supplier: supplier,
        ),
      ),
    );
    if (saved == true) {
      _showMessage(supplier == null ? 'تمت إضافة المورد.' : 'تم تحديث المورد.');
      await _notifyChanged();
    }
  }

  Future<void> _openMaterialForm({LedgerMaterial? material}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MaterialFormPage(
          gateway: widget.gateway,
          currencies: widget.data.currencies,
          baseCurrency: widget.data.baseCurrency,
          categories: widget.data.categories,
          material: material,
        ),
      ),
    );
    if (saved == true) {
      _showMessage(material == null ? 'تمت إضافة المادة.' : 'تم تحديث المادة.');
      await _notifyChanged();
    }
  }

  Future<void> _openCategories() async {
    final callback = widget.onOpenCategories;
    if (callback != null) {
      await callback();
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CategoriesPage(gateway: widget.gateway),
      ),
    );
    await _notifyChanged();
  }

  Future<void> _openOpeningBalances() async {
    final callback = widget.onOpenOpeningBalances;
    if (callback != null) {
      await callback();
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => OpeningBalancesPage(gateway: widget.gateway),
      ),
    );
    await _notifyChanged();
  }

  Future<void> _openMaterialUnits(LedgerMaterial material) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            MaterialUnitsPage(gateway: widget.gateway, material: material),
      ),
    );
    await _notifyChanged();
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
      await _notifyChanged();
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
      await _notifyChanged();
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
      await _notifyChanged();
    } catch (error) {
      _showError(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final customers = widget.data.customers
        .where((c) => _matches('${c.code} ${c.name} ${c.phone ?? ''}'))
        .toList(growable: false);
    final suppliers = widget.data.suppliers
        .where((s) => _matches('${s.code} ${s.name} ${s.phone ?? ''}'))
        .toList(growable: false);
    final materials = widget.data.materials
        .where((m) => _matches('${m.code} ${m.name} ${m.nameEn} ${m.barcode}'))
        .toList(growable: false);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.xl,
            AppSpacing.xl,
            AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppPageHeader(
                title: 'البيانات الأساسية',
                subtitle:
                    'إدارة العملاء والموردين والمواد مع بحث فوري وإجراءات سريعة.',
                icon: Icons.folder_shared_outlined,
                actions: [
                  IconButton(
                    tooltip: 'تصنيفات المواد',
                    onPressed: _openCategories,
                    icon: const Icon(Icons.category_outlined, size: 20),
                  ),
                  IconButton(
                    tooltip: 'الأرصدة الافتتاحية',
                    onPressed: _openOpeningBalances,
                    icon: const Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 20,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _createCurrent,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(_createLabel),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              AppMetricGrid(
                maxColumns: 3,
                children: [
                  AppMetricCard(
                    label: 'العملاء',
                    value: '${widget.data.customers.length}',
                    icon: Icons.people_alt_outlined,
                    tone: AppBadgeTone.warning,
                    hint: formatMoney(
                      widget.data.customerBalances.toStringAsFixed(2),
                      currency: widget.data.baseCurrency,
                    ),
                  ),
                  AppMetricCard(
                    label: 'الموردون',
                    value: '${widget.data.suppliers.length}',
                    icon: Icons.local_shipping_outlined,
                    tone: AppBadgeTone.info,
                    hint: formatMoney(
                      widget.data.supplierBalances.toStringAsFixed(2),
                      currency: widget.data.baseCurrency,
                    ),
                  ),
                  AppMetricCard(
                    label: 'المواد',
                    value: '${widget.data.materials.length}',
                    icon: Icons.inventory_2_outlined,
                    tone: AppBadgeTone.success,
                    hint: formatMoney(
                      widget.data.inventoryValue.toStringAsFixed(2),
                      currency: widget.data.baseCurrency,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final search = AppSearchField(
                      controller: _searchController,
                      hintText: 'بحث بالاسم أو الرمز أو الباركود…',
                      onChanged: (value) {
                        setState(() => _query = value.trim().toLowerCase());
                      },
                    );
                    final count = AppBadge(
                      label:
                          '${customers.length + suppliers.length + materials.length} نتيجة',
                      tone: AppBadgeTone.neutral,
                      icon: Icons.filter_alt_outlined,
                    );
                    if (constraints.maxWidth < 480) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          search,
                          const SizedBox(height: AppSpacing.sm),
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: count,
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: search),
                        const SizedBox(width: AppSpacing.md),
                        count,
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'العملاء (${customers.length})'),
              Tab(text: 'الموردون (${suppliers.length})'),
              Tab(text: 'المواد (${materials.length})'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _customerTable(customers),
              _supplierTable(suppliers),
              _materialTable(materials),
            ],
          ),
        ),
      ],
    );
  }

  String get _createLabel {
    return switch (_tabController.index) {
      1 => 'إضافة مورد',
      2 => 'إضافة مادة',
      _ => 'إضافة عميل',
    };
  }

  void _createCurrent() {
    switch (_tabController.index) {
      case 1:
        _openSupplierForm();
        break;
      case 2:
        _openMaterialForm();
        break;
      default:
        _openCustomerForm();
    }
  }

  Widget _customerTable(List<LedgerCustomer> customers) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: AppDataTable<LedgerCustomer>(
        minWidth: 720,
        columns: [
          AppTableColumn(
            label: 'الرمز',
            flex: 2,
            builder: (context, customer) =>
                Text(customer.code, style: theme.textTheme.labelMedium),
          ),
          AppTableColumn(
            label: 'العميل',
            flex: 5,
            builder: (context, customer) => Row(
              children: [
                AppAvatar(name: customer.name, size: 34),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(
                        customer.phone?.isNotEmpty == true
                            ? customer.phone!
                            : 'لا يوجد هاتف',
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          AppTableColumn(
            label: 'الحالة',
            flex: 2,
            builder: (context, customer) => AppBadge(
              label: customer.isActive ? 'نشط' : 'غير نشط',
              tone: customer.isActive
                  ? AppBadgeTone.success
                  : AppBadgeTone.neutral,
              compact: true,
            ),
          ),
          AppTableColumn(
            label: 'الرصيد',
            flex: 3,
            alignment: AlignmentDirectional.centerEnd,
            headerAlignment: AlignmentDirectional.centerEnd,
            builder: (context, customer) => Text(
              formatMoney(customer.balance, currency: customer.currency),
              style: theme.textTheme.labelLarge,
            ),
          ),
          AppTableColumn(
            label: '',
            width: 56,
            alignment: AlignmentDirectional.center,
            builder: (context, customer) => _RowActions(
              onEdit: () => _openCustomerForm(customer: customer),
              onDelete: () => _deleteCustomer(customer),
            ),
          ),
        ],
        rows: customers,
        onRowTap: (customer) => _openCustomerForm(customer: customer),
        emptyTitle: 'لا يوجد عملاء مطابقون',
        emptyMessage: 'أضف عميلاً جديداً أو عدّل كلمة البحث.',
        emptyIcon: Icons.people_alt_outlined,
        emptyAction: FilledButton.icon(
          onPressed: _openCustomerForm,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('إضافة عميل'),
        ),
      ),
    );
  }

  Widget _supplierTable(List<LedgerSupplier> suppliers) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: AppDataTable<LedgerSupplier>(
        minWidth: 720,
        columns: [
          AppTableColumn(
            label: 'الرمز',
            flex: 2,
            builder: (context, supplier) =>
                Text(supplier.code, style: theme.textTheme.labelMedium),
          ),
          AppTableColumn(
            label: 'المورد',
            flex: 5,
            builder: (context, supplier) => Row(
              children: [
                AppAvatar(
                  name: supplier.name,
                  size: 34,
                  color: context.semanticColors.info,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        supplier.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(
                        supplier.phone?.isNotEmpty == true
                            ? supplier.phone!
                            : 'لا يوجد هاتف',
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          AppTableColumn(
            label: 'الحالة',
            flex: 2,
            builder: (context, supplier) => AppBadge(
              label: supplier.isActive ? 'نشط' : 'غير نشط',
              tone: supplier.isActive
                  ? AppBadgeTone.success
                  : AppBadgeTone.neutral,
              compact: true,
            ),
          ),
          AppTableColumn(
            label: 'الرصيد',
            flex: 3,
            alignment: AlignmentDirectional.centerEnd,
            headerAlignment: AlignmentDirectional.centerEnd,
            builder: (context, supplier) => Text(
              formatMoney(supplier.balance, currency: supplier.currency),
              style: theme.textTheme.labelLarge,
            ),
          ),
          AppTableColumn(
            label: '',
            width: 56,
            alignment: AlignmentDirectional.center,
            builder: (context, supplier) => _RowActions(
              onEdit: () => _openSupplierForm(supplier: supplier),
              onDelete: () => _deleteSupplier(supplier),
            ),
          ),
        ],
        rows: suppliers,
        onRowTap: (supplier) => _openSupplierForm(supplier: supplier),
        emptyTitle: 'لا يوجد موردون مطابقون',
        emptyMessage: 'أضف مورداً جديداً أو عدّل كلمة البحث.',
        emptyIcon: Icons.local_shipping_outlined,
        emptyAction: FilledButton.icon(
          onPressed: _openSupplierForm,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('إضافة مورد'),
        ),
      ),
    );
  }

  Widget _materialTable(List<LedgerMaterial> materials) {
    final theme = Theme.of(context);
    final categoryNames = {
      for (final category in widget.data.categories)
        category.id: categoryLabel(category, widget.data.categories),
    };
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: AppDataTable<LedgerMaterial>(
        minWidth: 1040,
        columns: [
          AppTableColumn(
            label: 'الرمز',
            flex: 2,
            builder: (context, material) =>
                Text(material.code, style: theme.textTheme.labelMedium),
          ),
          AppTableColumn(
            label: 'المادة',
            flex: 4,
            builder: (context, material) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  material.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                Text(
                  material.barcode.isNotEmpty
                      ? 'باركود: ${material.barcode} • متاح: ${material.totalAvailable}'
                      : 'متاح: ${material.totalAvailable}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),
          AppTableColumn(
            label: 'التصنيف',
            flex: 3,
            builder: (context, material) {
              final labels = material.categoryIds
                  .map((id) => categoryNames[id])
                  .whereType<String>()
                  .toList();
              return AppBadge(
                label: labels.isEmpty ? 'غير مصنف' : labels.join('، '),
                tone: labels.isEmpty
                    ? AppBadgeTone.neutral
                    : AppBadgeTone.primary,
                compact: true,
              );
            },
          ),
          AppTableColumn(
            label: 'الوحدة',
            flex: 2,
            builder: (context, material) => Text(
              material.unitName.isEmpty ? '—' : material.unitName,
              style: theme.textTheme.bodySmall,
            ),
          ),
          AppTableColumn(
            label: 'المتاح',
            flex: 2,
            alignment: AlignmentDirectional.centerEnd,
            headerAlignment: AlignmentDirectional.centerEnd,
            builder: (context, material) => Text(
              '${material.totalAvailable} ${material.unitName}',
              style: theme.textTheme.labelMedium,
            ),
          ),
          AppTableColumn(
            label: 'الحد الأدنى',
            flex: 2,
            alignment: AlignmentDirectional.centerEnd,
            headerAlignment: AlignmentDirectional.centerEnd,
            builder: (context, material) => Text(
              material.minimumStock,
              style: theme.textTheme.labelMedium?.copyWith(
                color: context.semanticColors.warning,
              ),
            ),
          ),
          AppTableColumn(
            label: 'الأسعار',
            flex: 3,
            builder: (context, material) => Text(
              'شراء ${material.purchasePrice.isEmpty ? '—' : material.purchasePrice} • بيع ${material.salePrice.isEmpty ? '—' : material.salePrice}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall,
            ),
          ),
          AppTableColumn(
            label: '',
            width: 56,
            alignment: AlignmentDirectional.center,
            builder: (context, material) => _RowActions(
              onEdit: () => _openMaterialForm(material: material),
              onDelete: () => _deleteMaterial(material),
              onUnits: () => _openMaterialUnits(material),
            ),
          ),
        ],
        rows: materials,
        rowHeight: 64,
        onRowTap: (material) => _openMaterialForm(material: material),
        emptyTitle: 'لا توجد مواد مطابقة',
        emptyMessage: 'أضف مادة جديدة أو عدّل كلمة البحث.',
        emptyIcon: Icons.inventory_2_outlined,
        emptyAction: FilledButton.icon(
          onPressed: _openMaterialForm,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('إضافة مادة'),
        ),
      ),
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
      icon: const Icon(Icons.more_horiz, size: 19),
      onSelected: (action) {
        switch (action) {
          case _RowAction.edit:
            onEdit();
            break;
          case _RowAction.delete:
            onDelete();
            break;
          case _RowAction.units:
            onUnits?.call();
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: _RowAction.edit,
          child: _ActionRow(icon: Icons.edit_outlined, label: 'تعديل'),
        ),
        if (onUnits != null)
          const PopupMenuItem(
            value: _RowAction.units,
            child: _ActionRow(icon: Icons.straighten, label: 'الوحدات'),
          ),
        const PopupMenuItem(
          value: _RowAction.delete,
          child: _ActionRow(icon: Icons.delete_outline, label: 'حذف'),
        ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [Icon(icon, size: 17), const SizedBox(width: 8), Text(label)],
    );
  }
}
