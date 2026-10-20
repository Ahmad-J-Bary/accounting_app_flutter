import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'categories.dart';
import 'dashboard.dart';
import 'directory.dart';
import 'journal.dart';
import 'ledger.dart';
import 'opening_balances.dart';
import 'theme/app_theme.dart';
import 'ui/app_ui.dart';
import 'workspace_data.dart';

enum WorkspaceSection { dashboard, journal, customers, suppliers, materials }

class WorkspaceShell extends StatefulWidget {
  const WorkspaceShell({super.key, required this.gateway});

  final LedgerGateway gateway;

  @override
  State<WorkspaceShell> createState() => _WorkspaceShellState();
}

class _WorkspaceShellState extends State<WorkspaceShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  WorkspaceData? _data;
  Object? _error;
  bool _loading = true;
  bool _refreshing = false;
  bool _sidebarCollapsed = false;
  WorkspaceSection _section = WorkspaceSection.dashboard;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool showRefreshing = false}) async {
    setState(() {
      if (showRefreshing) {
        _refreshing = true;
      } else {
        _loading = true;
      }
      _error = null;
    });

    try {
      final data = await WorkspaceData.load(widget.gateway);
      if (!mounted) {
        return;
      }
      setState(() {
        _data = data;
        _loading = false;
        _refreshing = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error;
        _loading = false;
        _refreshing = false;
      });
      if (_data != null) {
        _showSnack('تعذّر تحديث البيانات: ${describeError(error)}');
      }
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
    await _load(showRefreshing: true);
  }

  void _showSnack(String message, {bool error = false}) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  void _select(WorkspaceSection section) {
    setState(() => _section = section);
  }

  Future<void> _openCategories() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CategoriesPage(gateway: widget.gateway),
      ),
    );
    if (mounted) {
      await _load(showRefreshing: true);
    }
  }

  Future<void> _openOpeningBalances() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => OpeningBalancesPage(gateway: widget.gateway),
      ),
    );
    if (mounted) {
      await _load(showRefreshing: true);
    }
  }

  void _handleDashboardTarget(DashboardTarget target) {
    switch (target) {
      case DashboardTarget.journal:
        _select(WorkspaceSection.journal);
        break;
      case DashboardTarget.customers:
        _select(WorkspaceSection.customers);
        break;
      case DashboardTarget.suppliers:
        _select(WorkspaceSection.suppliers);
        break;
      case DashboardTarget.materials:
        _select(WorkspaceSection.materials);
        break;
      case DashboardTarget.categories:
        _openCategories();
        break;
      case DashboardTarget.openingBalances:
        _openOpeningBalances();
        break;
    }
  }

  String _sectionLabel(WorkspaceSection section) {
    return switch (section) {
      WorkspaceSection.dashboard => 'لوحة التحكم',
      WorkspaceSection.journal => 'قيود اليومية',
      WorkspaceSection.customers => 'العملاء',
      WorkspaceSection.suppliers => 'الموردون',
      WorkspaceSection.materials => 'المواد',
    };
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            _openCommandPalette,
      },
      child: Focus(
        autofocus: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 940;
            return Scaffold(
              key: _scaffoldKey,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              drawer: compact
                  ? Drawer(
                      width: 286,
                      backgroundColor: context.semanticColors.sidebarBackground,
                      child: SafeArea(
                        child: _Sidebar(
                          collapsed: false,
                          selected: _section,
                          companyName: _data?.status.companyName ?? 'المحاسبة',
                          currencyLabel:
                              _data?.status.currencyLabel ?? 'جارٍ التحميل',
                          onSelect: (section) {
                            Navigator.of(context).pop();
                            _select(section);
                          },
                          onCategories: () {
                            Navigator.of(context).pop();
                            _openCategories();
                          },
                          onOpeningBalances: () {
                            Navigator.of(context).pop();
                            _openOpeningBalances();
                          },
                          onToggleCollapse: null,
                        ),
                      ),
                    )
                  : null,
              body: Row(
                children: [
                  if (!compact)
                    _Sidebar(
                      collapsed: _sidebarCollapsed,
                      selected: _section,
                      companyName: _data?.status.companyName ?? 'المحاسبة',
                      currencyLabel:
                          _data?.status.currencyLabel ?? 'جارٍ التحميل',
                      onSelect: _select,
                      onCategories: _openCategories,
                      onOpeningBalances: _openOpeningBalances,
                      onToggleCollapse: () {
                        setState(() => _sidebarCollapsed = !_sidebarCollapsed);
                      },
                    ),
                  Expanded(
                    child: Column(
                      children: [
                        _TopBar(
                          compact: compact,
                          title: _sectionLabel(_section),
                          companyName: _data?.status.companyName ?? '',
                          refreshing: _refreshing,
                          onMenu: compact
                              ? () => _scaffoldKey.currentState?.openDrawer()
                              : null,
                          onRefresh: () => _load(showRefreshing: true),
                          onSearch: _openCommandPalette,
                          onToggleTheme: () {
                            AppThemeScope.of(context).toggle();
                          },
                          onNavigate: (section) => _select(section),
                          onNotifications: _openNotifications,
                          onCategories: _openCategories,
                          onOpeningBalances: _openOpeningBalances,
                        ),
                        const Divider(height: 1),
                        Expanded(child: _content()),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _content() {
    final data = _data;

    if (data == null) {
      if (_loading) {
        return const AppLoadingState(
          message: 'جارٍ فتح قاعدة البيانات وتشغيل الترحيلات…',
        );
      }
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: AppErrorState(
              title: 'تعذّر فتح قاعدة البيانات',
              message: _error == null
                  ? 'حدث خطأ غير متوقع.'
                  : describeError(_error!),
              onRetry: _load,
            ),
          ),
        ),
      );
    }

    final page = switch (_section) {
      WorkspaceSection.dashboard => DashboardPage(
        data: data,
        refreshing: _refreshing,
        onRefresh: () => _load(showRefreshing: true),
        onNavigate: _handleDashboardTarget,
      ),
      WorkspaceSection.journal => JournalPage(
        data: data,
        refreshing: _refreshing,
        onRefresh: () => _load(showRefreshing: true),
        onCreateEntry: _createEntry,
      ),
      WorkspaceSection.customers => DirectoryPage(
        gateway: widget.gateway,
        data: data,
        initialTab: DirectoryTab.customers,
        onChanged: () => _load(showRefreshing: true),
        onOpenCategories: _openCategories,
        onOpenOpeningBalances: _openOpeningBalances,
      ),
      WorkspaceSection.suppliers => DirectoryPage(
        gateway: widget.gateway,
        data: data,
        initialTab: DirectoryTab.suppliers,
        onChanged: () => _load(showRefreshing: true),
        onOpenCategories: _openCategories,
        onOpenOpeningBalances: _openOpeningBalances,
      ),
      WorkspaceSection.materials => DirectoryPage(
        gateway: widget.gateway,
        data: data,
        initialTab: DirectoryTab.materials,
        onChanged: () => _load(showRefreshing: true),
        onOpenCategories: _openCategories,
        onOpenOpeningBalances: _openOpeningBalances,
      ),
    };

    return KeyedSubtree(key: ValueKey(_section), child: page);
  }

  Future<void> _openCommandPalette() async {
    final command = await showDialog<_Command>(
      context: context,
      builder: (context) =>
          _CommandPalette(onRefresh: () => _load(showRefreshing: true)),
    );
    if (!mounted || command == null) {
      return;
    }
    switch (command.action) {
      case _CommandAction.dashboard:
        _select(WorkspaceSection.dashboard);
        break;
      case _CommandAction.journal:
        _select(WorkspaceSection.journal);
        break;
      case _CommandAction.customers:
        _select(WorkspaceSection.customers);
        break;
      case _CommandAction.suppliers:
        _select(WorkspaceSection.suppliers);
        break;
      case _CommandAction.materials:
        _select(WorkspaceSection.materials);
        break;
      case _CommandAction.categories:
        await _openCategories();
        break;
      case _CommandAction.openingBalances:
        await _openOpeningBalances();
        break;
      case _CommandAction.refresh:
        await _load(showRefreshing: true);
        break;
    }
  }

  Future<void> _openNotifications() async {
    final data = _data;
    if (data == null) {
      return;
    }
    final lowStock = data.lowStockMaterials;
    await showDialog<void>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const AppIconTile(
                        icon: Icons.notifications_none_outlined,
                        size: 42,
                        iconSize: 21,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'الإشعارات',
                              style: theme.textTheme.titleLarge,
                            ),
                            Text(
                              '${lowStock.length} تنبيه مخزون',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'إغلاق',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, size: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (lowStock.isEmpty)
                    const AppEmptyState(
                      title: 'لا توجد إشعارات جديدة',
                      message: 'المخزون ضمن الحدود الآمنة والدفاتر متوازنة.',
                      icon: Icons.notifications_off_outlined,
                      compact: true,
                    )
                  else
                    for (final material in lowStock.take(6))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: AppIconTile(
                          icon: Icons.inventory_2_outlined,
                          size: 36,
                          iconSize: 18,
                          color: context.semanticColors.warning,
                        ),
                        title: Text(material.name),
                        subtitle: Text(
                          'المتاح ${formatNumberValue(parseAmount(material.totalAvailable))} ${material.unitName} • الحد الأدنى ${formatNumberValue(parseAmount(material.minimumStock))}',
                        ),
                        trailing: AppBadge(
                          label: 'إعادة طلب',
                          tone: AppBadgeTone.warning,
                          compact: true,
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                          _select(WorkspaceSection.materials);
                        },
                      ),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _select(WorkspaceSection.materials);
                    },
                    child: const Text('فتح المواد'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.collapsed,
    required this.selected,
    required this.companyName,
    required this.currencyLabel,
    required this.onSelect,
    required this.onCategories,
    required this.onOpeningBalances,
    this.onToggleCollapse,
  });

  final bool collapsed;
  final WorkspaceSection selected;
  final String companyName;
  final String currencyLabel;
  final ValueChanged<WorkspaceSection> onSelect;
  final VoidCallback onCategories;
  final VoidCallback onOpeningBalances;
  final VoidCallback? onToggleCollapse;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semanticColors;
    final width = collapsed ? 76.0 : 256.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: width,
      color: semantic.sidebarBackground,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                collapsed ? 14 : AppSpacing.lg,
                AppSpacing.lg,
                collapsed ? 14 : AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Row(
                mainAxisAlignment: collapsed
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: [Color(0xFF3B6EA5), Color(0xFF1F3A61)],
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  if (!collapsed) ...[
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'المحاسبة',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: semantic.sidebarForeground,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          Text(
                            'مساحة العمل المالية',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: semantic.sidebarMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: collapsed ? 14 : AppSpacing.lg,
              ),
              child: Divider(color: semantic.sidebarBorder, height: 1),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(
                  horizontal: collapsed ? 10 : AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                children: [
                  if (!collapsed) const _SidebarGroupLabel(label: 'الرئيسية'),
                  _SidebarItem(
                    icon: Icons.space_dashboard_outlined,
                    label: 'لوحة التحكم',
                    collapsed: collapsed,
                    active: selected == WorkspaceSection.dashboard,
                    onTap: () => onSelect(WorkspaceSection.dashboard),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (!collapsed) const _SidebarGroupLabel(label: 'المحاسبة'),
                  _SidebarItem(
                    icon: Icons.menu_book_outlined,
                    label: 'قيود اليومية',
                    collapsed: collapsed,
                    active: selected == WorkspaceSection.journal,
                    onTap: () => onSelect(WorkspaceSection.journal),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (!collapsed)
                    const _SidebarGroupLabel(label: 'البيانات الأساسية'),
                  _SidebarItem(
                    icon: Icons.people_alt_outlined,
                    label: 'العملاء',
                    collapsed: collapsed,
                    active: selected == WorkspaceSection.customers,
                    onTap: () => onSelect(WorkspaceSection.customers),
                  ),
                  _SidebarItem(
                    icon: Icons.local_shipping_outlined,
                    label: 'الموردون',
                    collapsed: collapsed,
                    active: selected == WorkspaceSection.suppliers,
                    onTap: () => onSelect(WorkspaceSection.suppliers),
                  ),
                  _SidebarItem(
                    icon: Icons.inventory_2_outlined,
                    label: 'المواد',
                    collapsed: collapsed,
                    active: selected == WorkspaceSection.materials,
                    onTap: () => onSelect(WorkspaceSection.materials),
                  ),
                  _SidebarItem(
                    icon: Icons.account_tree_outlined,
                    label: 'التصنيفات',
                    collapsed: collapsed,
                    active: false,
                    onTap: onCategories,
                  ),
                  _SidebarItem(
                    icon: Icons.tune_outlined,
                    label: 'الأرصدة الافتتاحية',
                    collapsed: collapsed,
                    active: false,
                    onTap: onOpeningBalances,
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: collapsed ? 10 : AppSpacing.md,
              ),
              child: Divider(color: semantic.sidebarBorder, height: 1),
            ),
            Padding(
              padding: EdgeInsets.all(collapsed ? 10 : AppSpacing.md),
              child: collapsed
                  ? Center(child: AppAvatar(name: companyName, size: 36))
                  : Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: semantic.sidebarAccent.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: semantic.sidebarBorder),
                      ),
                      child: Row(
                        children: [
                          AppAvatar(name: companyName, size: 34),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  companyName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(
                                        color: semantic.sidebarForeground,
                                      ),
                                ),
                                Text(
                                  currencyLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(color: semantic.sidebarMuted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            if (onToggleCollapse != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: TextButton(
                  onPressed: onToggleCollapse,
                  style: TextButton.styleFrom(
                    foregroundColor: semantic.sidebarMuted,
                    minimumSize: const Size(0, 34),
                  ),
                  child: Icon(
                    collapsed
                        ? Icons.keyboard_double_arrow_left
                        : Icons.keyboard_double_arrow_right,
                    size: 18,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SidebarGroupLabel extends StatelessWidget {
  const _SidebarGroupLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: context.semanticColors.sidebarMuted,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.collapsed,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool collapsed;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semanticColors;
    final theme = Theme.of(context);
    final content = Material(
      color: active ? semantic.sidebarAccent : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        hoverColor: semantic.sidebarAccent.withValues(alpha: 0.55),
        child: Container(
          height: 42,
          padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 11),
          child: Row(
            mainAxisAlignment: collapsed
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 19,
                color: active
                    ? semantic.sidebarForeground
                    : semantic.sidebarMuted,
              ),
              if (!collapsed) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: active
                          ? semantic.sidebarForeground
                          : semantic.sidebarMuted,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (active)
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: semantic.sidebarForeground,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );

    if (collapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Tooltip(message: label, child: content),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: content,
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.compact,
    required this.title,
    required this.companyName,
    required this.refreshing,
    required this.onMenu,
    required this.onRefresh,
    required this.onSearch,
    required this.onToggleTheme,
    required this.onNavigate,
    required this.onNotifications,
    required this.onCategories,
    required this.onOpeningBalances,
  });

  final bool compact;
  final String title;
  final String companyName;
  final bool refreshing;
  final VoidCallback? onMenu;
  final VoidCallback onRefresh;
  final VoidCallback onSearch;
  final VoidCallback onToggleTheme;
  final ValueChanged<WorkspaceSection> onNavigate;
  final VoidCallback onNotifications;
  final VoidCallback onCategories;
  final VoidCallback onOpeningBalances;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = context.semanticColors;
    return Container(
      height: 68,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.md : AppSpacing.xl,
      ),
      color: theme.colorScheme.surface,
      child: Row(
        children: [
          if (compact) ...[
            IconButton(
              tooltip: 'القائمة',
              onPressed: onMenu,
              icon: const Icon(Icons.menu),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
                if (!compact && companyName.isNotEmpty)
                  Text(
                    companyName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall,
                  ),
              ],
            ),
          ),
          if (!compact)
            Flexible(
              flex: 2,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Material(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.55,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.md + 2),
                  child: InkWell(
                    onTap: onSearch,
                    borderRadius: BorderRadius.circular(AppRadius.md + 2),
                    child: Container(
                      height: 38,
                      width: 310,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search,
                            size: 18,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'بحث شامل…',
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                            child: Text(
                              'Ctrl K',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(width: AppSpacing.sm),
          if (!compact)
            PopupMenuButton<WorkspaceSection>(
              tooltip: 'إجراء سريع',
              position: PopupMenuPosition.under,
              icon: const Icon(Icons.add_circle_outline, size: 21),
              onSelected: onNavigate,
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: WorkspaceSection.journal,
                  child: _MenuRow(
                    icon: Icons.post_add_outlined,
                    label: 'قيد يومية',
                  ),
                ),
                PopupMenuItem(
                  value: WorkspaceSection.customers,
                  child: _MenuRow(
                    icon: Icons.person_add_alt_1_outlined,
                    label: 'عميل جديد',
                  ),
                ),
                PopupMenuItem(
                  value: WorkspaceSection.suppliers,
                  child: _MenuRow(
                    icon: Icons.local_shipping_outlined,
                    label: 'مورد جديد',
                  ),
                ),
                PopupMenuItem(
                  value: WorkspaceSection.materials,
                  child: _MenuRow(
                    icon: Icons.inventory_2_outlined,
                    label: 'مادة جديدة',
                  ),
                ),
              ],
            ),
          IconButton(
            tooltip: 'تحديث',
            onPressed: refreshing ? null : onRefresh,
            icon: refreshing
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh, size: 20),
          ),
          IconButton(
            tooltip: 'الإشعارات',
            onPressed: onNotifications,
            icon: Badge(
              isLabelVisible: true,
              smallSize: 7,
              backgroundColor: semantic.warning,
              child: const Icon(Icons.notifications_none_outlined, size: 21),
            ),
          ),
          IconButton(
            tooltip: theme.brightness == Brightness.dark
                ? 'الوضع الفاتح'
                : 'الوضع الداكن',
            onPressed: onToggleTheme,
            icon: Icon(
              theme.brightness == Brightness.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
              size: 20,
            ),
          ),
          if (!compact) ...[
            const SizedBox(width: AppSpacing.xs),
            PopupMenuButton<String>(
              tooltip: 'حساب الشركة',
              position: PopupMenuPosition.under,
              onSelected: (value) {
                switch (value) {
                  case 'categories':
                    onCategories();
                    break;
                  case 'opening':
                    onOpeningBalances();
                    break;
                  case 'refresh':
                    onRefresh();
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  enabled: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(companyName, style: theme.textTheme.labelLarge),
                      Text(
                        'مساحة عمل محلية',
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'categories',
                  child: _MenuRow(
                    icon: Icons.account_tree_outlined,
                    label: 'التصنيفات',
                  ),
                ),
                const PopupMenuItem(
                  value: 'opening',
                  child: _MenuRow(
                    icon: Icons.tune_outlined,
                    label: 'الأرصدة الافتتاحية',
                  ),
                ),
                const PopupMenuItem(
                  value: 'refresh',
                  child: _MenuRow(icon: Icons.refresh, label: 'تحديث البيانات'),
                ),
              ],
              child: Row(
                children: [
                  AppAvatar(name: companyName, size: 34),
                  const SizedBox(width: 7),
                  Icon(
                    Icons.keyboard_arrow_down,
                    size: 17,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [Icon(icon, size: 17), const SizedBox(width: 9), Text(label)],
    );
  }
}

enum _CommandAction {
  dashboard,
  journal,
  customers,
  suppliers,
  materials,
  categories,
  openingBalances,
  refresh,
}

class _Command {
  const _Command({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.action,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final _CommandAction action;
}

class _CommandPalette extends StatefulWidget {
  const _CommandPalette({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  State<_CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<_CommandPalette> {
  final _controller = TextEditingController();
  String _query = '';

  static const _commands = <_Command>[
    _Command(
      title: 'لوحة التحكم',
      subtitle: 'المؤشرات المالية والمخزون',
      icon: Icons.space_dashboard_outlined,
      action: _CommandAction.dashboard,
    ),
    _Command(
      title: 'قيود اليومية',
      subtitle: 'إنشاء قيد وميزان المراجعة',
      icon: Icons.menu_book_outlined,
      action: _CommandAction.journal,
    ),
    _Command(
      title: 'العملاء',
      subtitle: 'إدارة بيانات العملاء',
      icon: Icons.people_alt_outlined,
      action: _CommandAction.customers,
    ),
    _Command(
      title: 'الموردون',
      subtitle: 'إدارة بيانات الموردين',
      icon: Icons.local_shipping_outlined,
      action: _CommandAction.suppliers,
    ),
    _Command(
      title: 'المواد',
      subtitle: 'المخزون والأسعار والوحدات',
      icon: Icons.inventory_2_outlined,
      action: _CommandAction.materials,
    ),
    _Command(
      title: 'التصنيفات',
      subtitle: 'شجرة تصنيفات المواد',
      icon: Icons.account_tree_outlined,
      action: _CommandAction.categories,
    ),
    _Command(
      title: 'الأرصدة الافتتاحية',
      subtitle: 'أرصدة العملاء والموردين',
      icon: Icons.tune_outlined,
      action: _CommandAction.openingBalances,
    ),
    _Command(
      title: 'تحديث البيانات',
      subtitle: 'إعادة تحميل كل الصفحات',
      icon: Icons.refresh,
      action: _CommandAction.refresh,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _query.trim().toLowerCase();
    final results = query.isEmpty
        ? _commands
        : _commands
              .where(
                (command) =>
                    command.title.toLowerCase().contains(query) ||
                    command.subtitle.toLowerCase().contains(query),
              )
              .toList();

    return Dialog(
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.only(top: 84, left: 20, right: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppSearchField(
                controller: _controller,
                autofocus: true,
                hintText: 'ابحث عن صفحة أو إجراء…',
                onChanged: (value) => setState(() => _query = value),
                onSubmitted: (_) {
                  if (results.isNotEmpty) {
                    Navigator.of(context).pop(results.first);
                  }
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              if (results.isEmpty)
                const AppEmptyState(
                  title: 'لا توجد نتائج',
                  message: 'جرّب البحث عن «عميل» أو «قيود» أو «مواد».',
                  icon: Icons.search_off_outlined,
                  compact: true,
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 420),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final command = results[index];
                      return ListTile(
                        leading: AppIconTile(
                          icon: command.icon,
                          size: 36,
                          iconSize: 18,
                        ),
                        title: Text(command.title),
                        subtitle: Text(command.subtitle),
                        trailing: Text(
                          '↵',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        onTap: () => Navigator.of(context).pop(command),
                      );
                    },
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Text('Ctrl + K', style: theme.textTheme.labelSmall),
                  const SizedBox(width: 6),
                  Text('للبحث في أي وقت', style: theme.textTheme.labelSmall),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onRefresh();
                    },
                    child: const Text('تحديث'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
