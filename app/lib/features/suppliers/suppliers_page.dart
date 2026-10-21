import 'package:flutter/material.dart';

import '../../ledger.dart';
import '../../master_data_forms.dart';
import '../../theme/app_theme.dart';
import '../../ui/app_ui.dart';
import '../../workspace_data.dart';
import '../master_data/master_data_shared.dart';

/// Independent suppliers page.
class SuppliersPage extends StatefulWidget {
  const SuppliersPage({
    super.key,
    required this.gateway,
    required this.data,
    this.onChanged,
    this.onOpenOpeningBalances,
  });

  final LedgerGateway gateway;
  final WorkspaceData data;
  final Future<void> Function()? onChanged;
  final Future<void> Function()? onOpenOpeningBalances;

  @override
  State<SuppliersPage> createState() => _SuppliersPageState();
}

class _SuppliersPageState extends State<SuppliersPage> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _activeOnly = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<LedgerSupplier> get _suppliers {
    final query = _query.trim().toLowerCase();
    return widget.data.suppliers
        .where((supplier) {
          if (_activeOnly && !supplier.isActive) {
            return false;
          }
          if (query.isEmpty) {
            return true;
          }
          return '${supplier.code} ${supplier.name} ${supplier.phone ?? ''} '
                  '${supplier.address ?? ''}'
              .toLowerCase()
              .contains(query);
        })
        .toList(growable: false);
  }

  Future<void> _notifyChanged() async {
    await widget.onChanged?.call();
  }

  Future<void> _openForm({LedgerSupplier? supplier}) async {
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
    if (saved == true && mounted) {
      showMasterDataMessage(
        context,
        supplier == null ? 'تمت إضافة المورد.' : 'تم تحديث المورد.',
      );
      await _notifyChanged();
    }
  }

  Future<void> _openOpeningBalances() async {
    final callback = widget.onOpenOpeningBalances;
    if (callback == null) {
      return;
    }
    await callback();
  }

  Future<void> _delete(LedgerSupplier supplier) async {
    final confirmed = await confirmMasterDataDelete(
      context,
      title: 'حذف المورد',
      message:
          'هل تريد حذف المورد «${supplier.name}»؟\n'
          'سيُحذف الحساب المرتبط إن أمكن، ولن يُسمح بالحذف إذا كانت هناك قيود مرحلة.',
    );
    if (!confirmed || !mounted) {
      return;
    }
    try {
      await widget.gateway.deleteSupplier(supplier.id);
      if (!mounted) {
        return;
      }
      showMasterDataMessage(context, 'تم حذف المورد.');
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
    final suppliers = _suppliers;
    final active = widget.data.suppliers
        .where((supplier) => supplier.isActive)
        .length;
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
                title: 'الموردون',
                subtitle: 'إدارة بيانات الموردين والأرصدة مع بحث وتصفية فورية.',
                icon: Icons.local_shipping_outlined,
                actions: [
                  if (widget.onOpenOpeningBalances != null)
                    IconButton(
                      tooltip: 'الأرصدة الافتتاحية',
                      onPressed: _openOpeningBalances,
                      icon: const Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 20,
                      ),
                    ),
                  FilledButton.icon(
                    onPressed: _openForm,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('إضافة مورد'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              AppMetricGrid(
                maxColumns: 3,
                children: [
                  AppMetricCard(
                    label: 'إجمالي الموردين',
                    value: '${widget.data.suppliers.length}',
                    icon: Icons.local_shipping_outlined,
                    tone: AppBadgeTone.info,
                  ),
                  AppMetricCard(
                    label: 'الموردون النشطون',
                    value: '$active',
                    icon: Icons.verified_user_outlined,
                    tone: AppBadgeTone.success,
                  ),
                  AppMetricCard(
                    label: 'إجمالي الأرصدة',
                    value: formatMoney(
                      widget.data.supplierBalances.toStringAsFixed(2),
                      currency: widget.data.baseCurrency,
                    ),
                    icon: Icons.account_balance_wallet_outlined,
                    tone: AppBadgeTone.warning,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              MasterDataSearchBar(
                controller: _searchController,
                hintText: 'بحث بالاسم أو الرمز أو الهاتف…',
                onChanged: (value) =>
                    setState(() => _query = value.trim().toLowerCase()),
                resultCount: suppliers.length,
                filters: [
                  FilterChip(
                    label: const Text('النشطون فقط'),
                    selected: _activeOnly,
                    onSelected: (value) => setState(() => _activeOnly = value),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              0,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            child: AppDataTable<LedgerSupplier>(
              tableId: 'suppliers',
              columns: _columns(context),
              rows: suppliers,
              rowId: (supplier) => supplier.id,
              paginate: true,
              minWidth: 760,
              onRowTap: (supplier) => _openForm(supplier: supplier),
              emptyTitle: _query.isEmpty && !_activeOnly
                  ? 'لا يوجد موردون بعد'
                  : 'لا يوجد موردون مطابقون',
              emptyMessage: 'أضف مورداً جديداً أو عدّل البحث والتصفية.',
              emptyIcon: Icons.local_shipping_outlined,
              emptyAction: FilledButton.icon(
                onPressed: _openForm,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('إضافة مورد'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<AppTableColumn<LedgerSupplier>> _columns(BuildContext context) {
    final theme = Theme.of(context);
    return [
      AppTableColumn(
        id: 'code',
        label: 'الرمز',
        flex: 2,
        minWidth: 90,
        sortable: true,
        sortValue: (supplier) => supplier.code,
        builder: (context, supplier) =>
            Text(supplier.code, style: theme.textTheme.labelMedium),
      ),
      AppTableColumn(
        id: 'name',
        label: 'المورد',
        flex: 5,
        minWidth: 180,
        sortable: true,
        sortValue: (supplier) => supplier.name,
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
                mainAxisAlignment: MainAxisAlignment.center,
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      AppTableColumn(
        id: 'status',
        label: 'الحالة',
        flex: 2,
        minWidth: 100,
        sortable: true,
        sortValue: (supplier) => supplier.isActive ? 1 : 0,
        builder: (context, supplier) => AppBadge(
          label: supplier.isActive ? 'نشط' : 'غير نشط',
          tone: supplier.isActive ? AppBadgeTone.success : AppBadgeTone.neutral,
          compact: true,
        ),
      ),
      AppTableColumn(
        id: 'balance',
        label: 'الرصيد',
        flex: 3,
        minWidth: 120,
        alignment: AlignmentDirectional.centerEnd,
        headerAlignment: AlignmentDirectional.centerEnd,
        sortable: true,
        sortValue: (supplier) => parseAmount(supplier.balance),
        builder: (context, supplier) => Text(
          formatMoney(supplier.balance, currency: supplier.currency),
          style: theme.textTheme.labelLarge,
        ),
      ),
      AppTableColumn(
        id: 'actions',
        label: '',
        width: 56,
        canHide: false,
        canResize: false,
        alignment: AlignmentDirectional.center,
        builder: (context, supplier) => MasterDataRowActions(
          onEdit: () => _openForm(supplier: supplier),
          onDelete: () => _delete(supplier),
        ),
      ),
    ];
  }
}
