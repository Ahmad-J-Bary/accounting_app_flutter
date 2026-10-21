import 'package:flutter/material.dart';

import '../../ledger.dart';
import '../../master_data_forms.dart';
import '../../theme/app_theme.dart';
import '../../ui/app_ui.dart';
import '../../ui/table/row_filter_cache.dart';
import '../../workspace_data.dart';
import '../master_data/master_data_shared.dart';

/// Independent customers page. Every write goes through the Rust core; the
/// page only refreshes after the bridge confirms success.
class CustomersPage extends StatefulWidget {
  const CustomersPage({
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
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  final _searchController = TextEditingController();
  final _filteredCustomers = RowFilterCache<LedgerCustomer>();
  String _query = '';
  bool _activeOnly = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<LedgerCustomer> get _customers {
    final source = widget.data.customers;
    return _filteredCustomers.resolve((_query, _activeOnly, source), () {
      final query = _query.trim().toLowerCase();
      return source
          .where((customer) {
            if (_activeOnly && !customer.isActive) {
              return false;
            }
            if (query.isEmpty) {
              return true;
            }
            return '${customer.code} ${customer.name} ${customer.phone ?? ''} '
                    '${customer.address ?? ''}'
                .toLowerCase()
                .contains(query);
          })
          .toList(growable: false);
    });
  }

  Future<void> _notifyChanged() async {
    await widget.onChanged?.call();
  }

  Future<void> _openForm({LedgerCustomer? customer}) async {
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
    if (saved == true && mounted) {
      showMasterDataMessage(
        context,
        customer == null ? 'تمت إضافة العميل.' : 'تم تحديث العميل.',
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

  Future<void> _delete(LedgerCustomer customer) async {
    final confirmed = await confirmMasterDataDelete(
      context,
      title: 'حذف العميل',
      message:
          'هل تريد حذف العميل «${customer.name}»؟\n'
          'سيُحذف الحساب المرتبط إن أمكن، ولن يُسمح بالحذف إذا كانت هناك قيود مرحلة.',
    );
    if (!confirmed || !mounted) {
      return;
    }
    try {
      await widget.gateway.deleteCustomer(customer.id);
      if (!mounted) {
        return;
      }
      showMasterDataMessage(context, 'تم حذف العميل.');
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
    final customers = _customers;
    final active = widget.data.customers
        .where((customer) => customer.isActive)
        .length;
    return MasterDataPageLayout(
      header: AppPageHeader(
        title: 'العملاء',
        subtitle: 'إدارة بيانات العملاء والأرصدة مع بحث وتصفية فورية.',
        icon: Icons.people_alt_outlined,
        actions: [
          if (widget.onOpenOpeningBalances != null)
            IconButton(
              tooltip: 'الأرصدة الافتتاحية',
              onPressed: _openOpeningBalances,
              icon: const Icon(Icons.account_balance_wallet_outlined, size: 20),
            ),
          FilledButton.icon(
            onPressed: _openForm,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('إضافة عميل'),
          ),
        ],
      ),
      metrics: [
        AppMetricCard(
          label: 'إجمالي العملاء',
          value: '${widget.data.customers.length}',
          icon: Icons.people_alt_outlined,
          tone: AppBadgeTone.warning,
        ),
        AppMetricCard(
          label: 'العملاء النشطون',
          value: '$active',
          icon: Icons.verified_user_outlined,
          tone: AppBadgeTone.success,
        ),
        AppMetricCard(
          label: 'إجمالي الأرصدة',
          value: formatMoney(
            widget.data.customerBalances.toStringAsFixed(2),
            currency: widget.data.baseCurrency,
          ),
          icon: Icons.account_balance_wallet_outlined,
          tone: AppBadgeTone.info,
        ),
      ],
      search: MasterDataSearchBar(
        controller: _searchController,
        hintText: 'بحث بالاسم أو الرمز أو الهاتف…',
        onChanged: (value) =>
            setState(() => _query = value.trim().toLowerCase()),
        resultCount: customers.length,
        filters: [
          FilterChip(
            label: const Text('النشطون فقط'),
            selected: _activeOnly,
            onSelected: (value) => setState(() => _activeOnly = value),
          ),
        ],
      ),
      table: AppDataTable<LedgerCustomer>(
        tableId: 'customers',
        columns: _columns(context),
        rows: customers,
        rowId: (customer) => customer.id,
        paginate: true,
        minWidth: 760,
        onRowTap: (customer) => _openForm(customer: customer),
        emptyTitle: _query.isEmpty && !_activeOnly
            ? 'لا يوجد عملاء بعد'
            : 'لا يوجد عملاء مطابقون',
        emptyMessage: 'أضف عميلاً جديداً أو عدّل البحث والتصفية.',
        emptyIcon: Icons.people_alt_outlined,
        emptyAction: FilledButton.icon(
          onPressed: _openForm,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('إضافة عميل'),
        ),
      ),
    );
  }

  List<AppTableColumn<LedgerCustomer>> _columns(BuildContext context) {
    final theme = Theme.of(context);
    return [
      AppTableColumn(
        id: 'code',
        label: 'الرمز',
        flex: 2,
        minWidth: 90,
        sortable: true,
        sortValue: (customer) => customer.code,
        builder: (context, customer) =>
            AppTableText(customer.code, style: theme.textTheme.labelMedium),
      ),
      AppTableColumn(
        id: 'name',
        label: 'العميل',
        flex: 5,
        minWidth: 180,
        sortable: true,
        sortValue: (customer) => customer.name,
        builder: (context, customer) => Row(
          children: [
            AppAvatar(name: customer.name, size: 34),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
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
        sortValue: (customer) => customer.isActive ? 1 : 0,
        builder: (context, customer) => AppBadge(
          label: customer.isActive ? 'نشط' : 'غير نشط',
          tone: customer.isActive ? AppBadgeTone.success : AppBadgeTone.neutral,
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
        sortValue: (customer) => parseAmount(customer.balance),
        builder: (context, customer) => AppTableText(
          formatMoney(customer.balance, currency: customer.currency),
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
        builder: (context, customer) => MasterDataRowActions(
          onEdit: () => _openForm(customer: customer),
          onDelete: () => _delete(customer),
        ),
      ),
    ];
  }
}
