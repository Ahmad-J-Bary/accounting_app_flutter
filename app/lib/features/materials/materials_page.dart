import 'package:flutter/material.dart';

import '../../categories.dart';
import '../../ledger.dart';
import '../../master_data_forms.dart';
import '../../material_units.dart';
import '../../theme/app_theme.dart';
import '../../ui/app_ui.dart';
import '../../ui/table/row_filter_cache.dart';
import '../../workspace_data.dart';
import '../master_data/master_data_shared.dart';

/// Independent materials page with category and stock filters.
class MaterialsPage extends StatefulWidget {
  const MaterialsPage({
    super.key,
    required this.gateway,
    required this.data,
    this.onChanged,
    this.onOpenCategories,
    this.onOpenOpeningBalances,
  });

  final LedgerGateway gateway;
  final WorkspaceData data;
  final Future<void> Function()? onChanged;
  final Future<void> Function()? onOpenCategories;
  final Future<void> Function()? onOpenOpeningBalances;

  @override
  State<MaterialsPage> createState() => _MaterialsPageState();
}

class _MaterialsPageState extends State<MaterialsPage> {
  final _searchController = TextEditingController();
  final _filteredMaterials = RowFilterCache<LedgerMaterial>();
  String _query = '';
  String? _categoryId;
  bool _lowStockOnly = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Map<String, String> get _categoryNames => {
    for (final category in widget.data.categories)
      category.id: categoryLabel(category, widget.data.categories),
  };

  List<LedgerMaterial> get _materials {
    final source = widget.data.materials;
    return _filteredMaterials.resolve(
      (_query, _categoryId, _lowStockOnly, source),
      () {
        final query = _query.trim().toLowerCase();
        return source
            .where((material) {
              if (_categoryId != null &&
                  !material.categoryIds.contains(_categoryId)) {
                return false;
              }
              if (_lowStockOnly) {
                final available = parseAmount(material.totalAvailable);
                final minimum = parseAmount(material.minimumStock);
                if (minimum <= 0 || available > minimum) {
                  return false;
                }
              }
              if (query.isEmpty) {
                return true;
              }
              return '${material.code} ${material.name} ${material.nameEn} '
                      '${material.barcode}'
                  .toLowerCase()
                  .contains(query);
            })
            .toList(growable: false);
      },
    );
  }

  Future<void> _notifyChanged() async {
    await widget.onChanged?.call();
  }

  Future<void> _openForm({LedgerMaterial? material}) async {
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
    if (saved == true && mounted) {
      showMasterDataMessage(
        context,
        material == null ? 'تمت إضافة المادة.' : 'تم تحديث المادة.',
      );
      await _notifyChanged();
    }
  }

  Future<void> _openUnits(LedgerMaterial material) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            MaterialUnitsPage(gateway: widget.gateway, material: material),
      ),
    );
    await _notifyChanged();
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
    }
  }

  Future<void> _delete(LedgerMaterial material) async {
    final confirmed = await confirmMasterDataDelete(
      context,
      title: 'حذف المادة',
      message:
          'هل تريد حذف المادة «${material.name}»؟\n'
          'لن يُسمح بالحذف إذا كانت للمادة حركات مخزنية.',
    );
    if (!confirmed || !mounted) {
      return;
    }
    try {
      await widget.gateway.deleteMaterial(material.id);
      if (!mounted) {
        return;
      }
      showMasterDataMessage(context, 'تم حذف المادة.');
      await _notifyChanged();
    } catch (error) {
      if (!mounted) {
        return;
      }
      showMasterDataError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final materials = _materials;
    final lowStock = widget.data.lowStockMaterials.length;
    return MasterDataPageLayout(
      header: AppPageHeader(
        title: 'المواد',
        subtitle:
            'إدارة الأصناف والتصنيفات والوحدات والأسعار مع تنبيه نقص المخزون.',
        icon: Icons.inventory_2_outlined,
        actions: [
          IconButton(
            tooltip: 'تصنيفات المواد',
            onPressed: _openCategories,
            icon: const Icon(Icons.category_outlined, size: 20),
          ),
          if (widget.onOpenOpeningBalances != null)
            IconButton(
              tooltip: 'الأرصدة الافتتاحية',
              onPressed: _openOpeningBalances,
              icon: const Icon(Icons.account_balance_wallet_outlined, size: 20),
            ),
          FilledButton.icon(
            onPressed: _openForm,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('إضافة مادة'),
          ),
        ],
      ),
      metrics: [
        AppMetricCard(
          label: 'إجمالي المواد',
          value: '${widget.data.materials.length}',
          icon: Icons.inventory_2_outlined,
          tone: AppBadgeTone.success,
        ),
        AppMetricCard(
          label: 'مواد تحت الحد الأدنى',
          value: '$lowStock',
          icon: Icons.warning_amber_outlined,
          tone: AppBadgeTone.warning,
        ),
        AppMetricCard(
          label: 'قيمة المخزون',
          value: formatMoney(
            widget.data.inventoryValue.toStringAsFixed(2),
            currency: widget.data.baseCurrency,
          ),
          icon: Icons.account_balance_wallet_outlined,
          tone: AppBadgeTone.info,
        ),
      ],
      search: MasterDataSearchBar(
        controller: _searchController,
        hintText: 'بحث بالاسم أو الرمز أو الباركود…',
        onChanged: (value) =>
            setState(() => _query = value.trim().toLowerCase()),
        resultCount: materials.length,
        filters: [
          _CategoryFilter(
            categories: widget.data.categories,
            value: _categoryId,
            onChanged: (value) => setState(() => _categoryId = value),
          ),
          FilterChip(
            label: const Text('تحت الحد الأدنى'),
            selected: _lowStockOnly,
            onSelected: (value) => setState(() => _lowStockOnly = value),
          ),
        ],
      ),
      table: AppDataTable<LedgerMaterial>(
        tableId: 'materials',
        columns: _columns(context),
        rows: materials,
        rowId: (material) => material.id,
        paginate: true,
        minWidth: 1040,
        rowHeight: 64,
        onRowTap: (material) => _openForm(material: material),
        emptyTitle: _query.isEmpty && _categoryId == null && !_lowStockOnly
            ? 'لا توجد مواد بعد'
            : 'لا توجد مواد مطابقة',
        emptyMessage: 'أضف مادة جديدة أو عدّل البحث والتصفية.',
        emptyIcon: Icons.inventory_2_outlined,
        emptyAction: FilledButton.icon(
          onPressed: _openForm,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('إضافة مادة'),
        ),
      ),
    );
  }

  List<AppTableColumn<LedgerMaterial>> _columns(BuildContext context) {
    final theme = Theme.of(context);
    final categoryNames = _categoryNames;
    return [
      AppTableColumn(
        id: 'code',
        label: 'الرمز',
        flex: 2,
        minWidth: 90,
        sortable: true,
        sortValue: (material) => material.code,
        builder: (context, material) =>
            AppTableText(material.code, style: theme.textTheme.labelMedium),
      ),
      AppTableColumn(
        id: 'name',
        label: 'المادة',
        flex: 4,
        minWidth: 190,
        sortable: true,
        sortValue: (material) => material.name,
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
        id: 'category',
        label: 'التصنيف',
        flex: 3,
        minWidth: 140,
        sortable: true,
        sortValue: (material) => material.categoryIds
            .map((id) => categoryNames[id])
            .whereType<String>()
            .join('، '),
        builder: (context, material) {
          final labels = material.categoryIds
              .map((id) => categoryNames[id])
              .whereType<String>()
              .toList();
          return AppBadge(
            label: labels.isEmpty ? 'غير مصنف' : labels.join('، '),
            tone: labels.isEmpty ? AppBadgeTone.neutral : AppBadgeTone.primary,
            compact: true,
          );
        },
      ),
      AppTableColumn(
        id: 'unit',
        label: 'الوحدة',
        flex: 2,
        minWidth: 90,
        builder: (context, material) => AppTableText(
          material.unitName.isEmpty ? '—' : material.unitName,
          style: theme.textTheme.bodySmall,
        ),
      ),
      AppTableColumn(
        id: 'available',
        label: 'المتاح',
        flex: 2,
        minWidth: 110,
        alignment: AlignmentDirectional.centerEnd,
        headerAlignment: AlignmentDirectional.centerEnd,
        sortable: true,
        sortValue: (material) => parseAmount(material.totalAvailable),
        builder: (context, material) => AppTableText(
          '${material.totalAvailable} ${material.unitName}',
          style: theme.textTheme.labelMedium,
        ),
      ),
      AppTableColumn(
        id: 'minimum',
        label: 'الحد الأدنى',
        flex: 2,
        minWidth: 110,
        alignment: AlignmentDirectional.centerEnd,
        headerAlignment: AlignmentDirectional.centerEnd,
        sortable: true,
        sortValue: (material) => parseAmount(material.minimumStock),
        builder: (context, material) => AppTableText(
          material.minimumStock,
          style: theme.textTheme.labelMedium?.copyWith(
            color: context.semanticColors.warning,
          ),
        ),
      ),
      AppTableColumn(
        id: 'prices',
        label: 'الأسعار',
        flex: 3,
        minWidth: 190,
        builder: (context, material) => AppTableText(
          'شراء ${material.purchasePrice.isEmpty ? '—' : material.purchasePrice} • بيع ${material.salePrice.isEmpty ? '—' : material.salePrice}',
          style: theme.textTheme.labelSmall,
        ),
      ),
      AppTableColumn(
        id: 'actions',
        label: '',
        width: 56,
        canHide: false,
        canResize: false,
        alignment: AlignmentDirectional.center,
        builder: (context, material) => MasterDataRowActions(
          onEdit: () => _openForm(material: material),
          onDelete: () => _delete(material),
          onUnits: () => _openUnits(material),
        ),
      ),
    ];
  }
}

class _CategoryFilter extends StatelessWidget {
  const _CategoryFilter({
    required this.categories,
    required this.value,
    required this.onChanged,
  });

  final List<LedgerCategory> categories;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value ?? '',
          isDense: true,
          items: [
            const DropdownMenuItem(value: '', child: Text('كل التصنيفات')),
            for (final category in categories)
              DropdownMenuItem(
                value: category.id,
                child: Text(
                  categoryLabel(category, categories),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (selected) =>
              onChanged(selected == null || selected.isEmpty ? null : selected),
        ),
      ),
    );
  }
}
