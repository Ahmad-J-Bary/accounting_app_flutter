import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'ledger.dart';
import 'theme/app_theme.dart';
import 'ui/app_ui.dart';
import 'workspace_data.dart';

enum DashboardTarget {
  journal,
  salesInvoices,
  purchaseInvoices,
  receipts,
  expenses,
  customers,
  suppliers,
  materials,
  categories,
  openingBalances,
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({
    super.key,
    required this.data,
    required this.onRefresh,
    required this.onNavigate,
    this.refreshing = false,
  });

  final WorkspaceData data;
  final VoidCallback onRefresh;
  final ValueChanged<DashboardTarget> onNavigate;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = context.semanticColors;
    final difference = data.balanceDifference;
    final lowStock = data.lowStockMaterials;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppPageHeader(
            title: 'لوحة التحكم',
            subtitle:
                'نظرة شاملة على الوضع المالي والمخزون في ${data.status.companyName}.',
            icon: Icons.space_dashboard_outlined,
            badge: const AppBadge(
              label: 'جاهز',
              tone: AppBadgeTone.success,
              icon: Icons.check_circle_outline,
            ),
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
              FilledButton.icon(
                onPressed: () => onNavigate(DashboardTarget.journal),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('قيد جديد'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          AppInfoBanner(
            title: data.isBalanced
                ? 'الدفاتر متوازنة'
                : 'يوجد فرق في ميزان المراجعة',
            message: data.isBalanced
                ? 'إجمالي المدين يساوي إجمالي الدائن. يمكنك متابعة العمل على القيود.'
                : 'فرق قدره ${formatMoney(difference.toStringAsFixed(2), currency: data.baseCurrency)} يحتاج إلى مراجعة.',
            tone: data.isBalanced ? AppBadgeTone.success : AppBadgeTone.warning,
            icon: data.isBalanced
                ? Icons.verified_outlined
                : Icons.warning_amber_outlined,
            action: TextButton(
              onPressed: () => onNavigate(DashboardTarget.journal),
              child: const Text('فتح اليومية'),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _SectionHeading(
            title: 'المؤشرات المالية',
            subtitle: 'أرصدة ميزان المراجعة والعملاء والموردين',
            icon: Icons.query_stats_outlined,
            action: AppBadge(
              label: 'العملة: ${data.baseCurrency}',
              tone: AppBadgeTone.neutral,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _ResponsiveGrid(
            minItemWidth: 230,
            maxColumns: 4,
            children: [
              AppMetricCard(
                label: 'إجمالي المدين',
                value: formatMoney(
                  data.snapshot.totalDebit,
                  currency: data.baseCurrency,
                ),
                icon: Icons.south_west_outlined,
                tone: AppBadgeTone.success,
                hint: '${data.snapshot.rows.length} حساب في الميزان',
              ),
              AppMetricCard(
                label: 'إجمالي الدائن',
                value: formatMoney(
                  data.snapshot.totalCredit,
                  currency: data.baseCurrency,
                ),
                icon: Icons.north_east_outlined,
                tone: AppBadgeTone.info,
                hint: 'مطابق للمدين',
              ),
              AppMetricCard(
                label: 'صافي الرصيد',
                value: formatMoney(
                  difference.toStringAsFixed(2),
                  currency: data.baseCurrency,
                ),
                icon: Icons.balance_outlined,
                tone: data.isBalanced
                    ? AppBadgeTone.success
                    : AppBadgeTone.danger,
                hint: data.isBalanced ? 'متوازن' : 'يحتاج مراجعة',
                trend: data.isBalanced ? 'متوازن' : 'فرق',
              ),
              AppMetricCard(
                label: 'أرصدة العملاء',
                value: formatMoney(
                  data.customerBalances.toStringAsFixed(2),
                  currency: data.baseCurrency,
                ),
                icon: Icons.people_alt_outlined,
                tone: AppBadgeTone.warning,
                hint: '${data.customers.length} عميل',
                onTap: () => onNavigate(DashboardTarget.customers),
              ),
              AppMetricCard(
                label: 'أرصدة الموردين',
                value: formatMoney(
                  data.supplierBalances.toStringAsFixed(2),
                  currency: data.baseCurrency,
                ),
                icon: Icons.local_shipping_outlined,
                tone: AppBadgeTone.info,
                hint: '${data.suppliers.length} مورد',
                onTap: () => onNavigate(DashboardTarget.suppliers),
              ),
              AppMetricCard(
                label: 'المبيعات المرحّلة',
                value: formatMoney(
                  data.invoiceSalesTotal.toStringAsFixed(2),
                  currency: data.baseCurrency,
                ),
                icon: Icons.receipt_long_outlined,
                tone: AppBadgeTone.success,
                hint: '${data.salesInvoices.length} فاتورة بيع',
                onTap: () => onNavigate(DashboardTarget.salesInvoices),
              ),
              AppMetricCard(
                label: 'المشتريات المرحّلة',
                value: formatMoney(
                  data.invoicePurchaseTotal.toStringAsFixed(2),
                  currency: data.baseCurrency,
                ),
                icon: Icons.shopping_cart_checkout_outlined,
                tone: AppBadgeTone.info,
                hint: '${data.purchaseInvoices.length} فاتورة شراء',
                onTap: () => onNavigate(DashboardTarget.purchaseInvoices),
              ),
              AppMetricCard(
                label: 'المصاريف',
                value: formatMoney(
                  data.expenseTotal.toStringAsFixed(2),
                  currency: data.baseCurrency,
                ),
                icon: Icons.request_quote_outlined,
                tone: AppBadgeTone.warning,
                hint: '${data.expenseItems.length} بند مصروف',
                onTap: () => onNavigate(DashboardTarget.expenses),
              ),
              AppMetricCard(
                label: 'قيمة المخزون',
                value: formatMoney(
                  data.inventoryValue.toStringAsFixed(2),
                  currency: data.baseCurrency,
                  compact: true,
                ),
                icon: Icons.warehouse_outlined,
                tone: AppBadgeTone.primary,
                hint: 'بالتكلفة المتوسطة',
                onTap: () => onNavigate(DashboardTarget.materials),
              ),
              AppMetricCard(
                label: 'المواد',
                value: '${data.materials.length}',
                icon: Icons.inventory_2_outlined,
                tone: AppBadgeTone.primary,
                hint: '${data.categories.length} تصنيف',
                onTap: () => onNavigate(DashboardTarget.materials),
              ),
              AppMetricCard(
                label: 'تحت الحد الأدنى',
                value: '${lowStock.length}',
                icon: Icons.notification_important_outlined,
                tone: lowStock.isEmpty
                    ? AppBadgeTone.success
                    : AppBadgeTone.warning,
                hint: lowStock.isEmpty ? 'المخزون سليم' : 'تحتاج إعادة طلب',
                onTap: () => onNavigate(DashboardTarget.materials),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 980;
              final categoryCard = _CategoryDistributionCard(data: data);
              final lowStockCard = _LowStockCard(
                materials: lowStock,
                currency: data.baseCurrency,
                onOpenMaterials: () => onNavigate(DashboardTarget.materials),
              );
              if (!wide) {
                return Column(
                  children: [
                    categoryCard,
                    const SizedBox(height: AppSpacing.lg),
                    lowStockCard,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: categoryCard),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(flex: 7, child: lowStockCard),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.xl),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 980;
              final quickActions = _QuickActionsCard(
                onNavigate: onNavigate,
                theme: theme,
                semantic: semantic,
              );
              final recent = _RecentPartnersCard(data: data);
              if (!wide) {
                return Column(
                  children: [
                    quickActions,
                    const SizedBox(height: AppSpacing.lg),
                    recent,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: quickActions),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(flex: 7, child: recent),
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

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.icon,
    this.subtitle,
    this.action,
  });

  final String title;
  final IconData icon;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AppIconTile(icon: icon, size: 34, iconSize: 17),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              if (subtitle != null) ...[
                const SizedBox(height: 1),
                Text(subtitle!, style: theme.textTheme.bodySmall),
              ],
            ],
          ),
        ),
        ?action,
      ],
    );
  }
}

class _ResponsiveGrid extends StatelessWidget {
  const _ResponsiveGrid({
    required this.children,
    this.minItemWidth = 220,
    this.maxColumns = 4,
  });

  static const spacing = AppSpacing.md;

  final List<Widget> children;
  final double minItemWidth;
  final int maxColumns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / minItemWidth).floor().clamp(
          1,
          maxColumns,
        );
        final width =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

class _CategoryDistributionCard extends StatelessWidget {
  const _CategoryDistributionCard({required this.data});

  final WorkspaceData data;

  static const _palette = <Color>[
    Color(0xFF1F3A61),
    Color(0xFF1B9E6B),
    Color(0xFFF59E0B),
    Color(0xFF3B82F6),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFF14B8A6),
  ];

  @override
  Widget build(BuildContext context) {
    final counts = data.materialCategoryCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = counts.fold<int>(0, (sum, entry) => sum + entry.value);
    final theme = Theme.of(context);

    return AppCard(
      radius: AppRadius.xxl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CardTitle(
            title: 'توزيع المواد على التصنيفات',
            subtitle: 'نظرة سريعة على بنية المخزون',
            icon: Icons.donut_large_outlined,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (counts.isEmpty)
            const AppEmptyState(
              title: 'لا توجد مواد بعد',
              message: 'أضف مواد من شاشة المواد لتظهر هنا.',
              icon: Icons.inventory_2_outlined,
              compact: true,
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 440;
                final chart = SizedBox(
                  width: 148,
                  height: 148,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size.square(148),
                        painter: _DonutPainter(
                          values: counts
                              .map((e) => e.value.toDouble())
                              .toList(),
                          colors: [
                            for (var index = 0; index < counts.length; index++)
                              _palette[index % _palette.length],
                          ],
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('$total', style: theme.textTheme.headlineMedium),
                          Text('مادة', style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ],
                  ),
                );
                final legend = Column(
                  children: [
                    for (var index = 0; index < counts.length; index++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                color: _palette[index % _palette.length],
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                counts[index].key,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                            Text(
                              '${counts[index].value}',
                              style: theme.textTheme.labelMedium,
                            ),
                          ],
                        ),
                      ),
                  ],
                );
                if (narrow) {
                  return Column(
                    children: [
                      Center(child: chart),
                      const SizedBox(height: AppSpacing.md),
                      legend,
                    ],
                  );
                }
                return Row(
                  children: [
                    chart,
                    const SizedBox(width: AppSpacing.xl),
                    Expanded(child: legend),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _LowStockCard extends StatelessWidget {
  const _LowStockCard({
    required this.materials,
    required this.currency,
    required this.onOpenMaterials,
  });

  final List<LedgerMaterial> materials;
  final String currency;
  final VoidCallback onOpenMaterials;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = context.semanticColors;

    return AppCard(
      radius: AppRadius.xxl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardTitle(
            title: 'تنبيهات المخزون',
            subtitle: 'مواد وصلت إلى الحد الأدنى أو أقل',
            icon: Icons.warning_amber_outlined,
            action: TextButton(
              onPressed: onOpenMaterials,
              child: const Text('عرض المواد'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (materials.isEmpty)
            const AppEmptyState(
              title: 'المخزون ضمن الحدود الآمنة',
              message: 'لا توجد مواد بحاجة إلى إعادة طلب حالياً.',
              icon: Icons.check_circle_outline,
              compact: true,
            )
          else
            Column(
              children: [
                for (final material in materials.take(6))
                  _LowStockRow(material: material, currency: currency),
              ],
            ),
          if (materials.isEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(
                  Icons.verified_outlined,
                  size: 16,
                  color: semantic.success,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'يتم احتساب التنبيه عندما يكون المتاح أقل من أو يساوي الحد الأدنى.',
                    style: theme.textTheme.labelSmall,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _LowStockRow extends StatelessWidget {
  const _LowStockRow({required this.material, required this.currency});

  final LedgerMaterial material;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = context.semanticColors;
    final available = parseAmount(material.totalAvailable);
    final minimum = math.max(parseAmount(material.minimumStock), 1);
    final ratio = (available / minimum).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          AppIconTile(
            icon: Icons.inventory_2_outlined,
            size: 36,
            iconSize: 18,
            color: semantic.warning,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        material.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    Text(
                      '${formatNumberValue(available)} / ${formatNumberValue(minimum)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: semantic.warning,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 5,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      ratio <= 0.35
                          ? theme.colorScheme.error
                          : semantic.warning,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(material.unitName, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _QuickActionsCard extends StatelessWidget {
  const _QuickActionsCard({
    required this.onNavigate,
    required this.theme,
    required this.semantic,
  });

  final ValueChanged<DashboardTarget> onNavigate;
  final ThemeData theme;
  final AppSemanticColors semantic;

  @override
  Widget build(BuildContext context) {
    final actions = <_QuickAction>[
      _QuickAction(
        label: 'قيد يومية',
        hint: 'تسجيل حركة محاسبية',
        icon: Icons.post_add_outlined,
        color: theme.colorScheme.primary,
        target: DashboardTarget.journal,
      ),
      _QuickAction(
        label: 'فاتورة بيع',
        hint: 'إنشاء فاتورة وترحيلها',
        icon: Icons.receipt_long_outlined,
        color: semantic.success,
        target: DashboardTarget.salesInvoices,
      ),
      _QuickAction(
        label: 'فاتورة شراء',
        hint: 'تسجيل مشتريات المخزون',
        icon: Icons.shopping_cart_checkout_outlined,
        color: semantic.info,
        target: DashboardTarget.purchaseInvoices,
      ),
      _QuickAction(
        label: 'سند مصروف',
        hint: 'صرف من بند مصاريف',
        icon: Icons.request_quote_outlined,
        color: semantic.warning,
        target: DashboardTarget.expenses,
      ),
      _QuickAction(
        label: 'عميل جديد',
        hint: 'إدارة بيانات العملاء',
        icon: Icons.person_add_alt_1_outlined,
        color: semantic.warning,
        target: DashboardTarget.customers,
      ),
      _QuickAction(
        label: 'مورد جديد',
        hint: 'إدارة بيانات الموردين',
        icon: Icons.local_shipping_outlined,
        color: semantic.info,
        target: DashboardTarget.suppliers,
      ),
      _QuickAction(
        label: 'مادة جديدة',
        hint: 'إضافة إلى المخزون',
        icon: Icons.inventory_2_outlined,
        color: semantic.success,
        target: DashboardTarget.materials,
      ),
      _QuickAction(
        label: 'التصنيفات',
        hint: 'تنظيم شجرة المواد',
        icon: Icons.account_tree_outlined,
        color: const Color(0xFF8B5CF6),
        target: DashboardTarget.categories,
      ),
      _QuickAction(
        label: 'الأرصدة الافتتاحية',
        hint: 'مراجعة أرصدة البداية',
        icon: Icons.tune_outlined,
        color: const Color(0xFF14B8A6),
        target: DashboardTarget.openingBalances,
      ),
    ];

    return AppCard(
      radius: AppRadius.xxl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CardTitle(
            title: 'إجراءات سريعة',
            subtitle: 'اختصارات للمهام المتكررة',
            icon: Icons.bolt_outlined,
          ),
          const SizedBox(height: AppSpacing.lg),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 380 ? 2 : 1;
              final spacing = AppSpacing.sm;
              final width =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final action in actions)
                    SizedBox(
                      width: width,
                      child: _QuickActionTile(
                        action: action,
                        onTap: () => onNavigate(action.target),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _QuickAction {
  const _QuickAction({
    required this.label,
    required this.hint,
    required this.icon,
    required this.color,
    required this.target,
  });

  final String label;
  final String hint;
  final IconData icon;
  final Color color;
  final DashboardTarget target;
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.action, required this.onTap});

  final _QuickAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        hoverColor: action.color.withValues(alpha: 0.06),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: theme.colorScheme.outline),
          ),
          child: Row(
            children: [
              AppIconTile(
                icon: action.icon,
                size: 36,
                iconSize: 18,
                color: action.color,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge,
                    ),
                    Text(
                      action.hint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_left,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentPartnersCard extends StatelessWidget {
  const _RecentPartnersCard({required this.data});

  final WorkspaceData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = context.semanticColors;
    return AppCard(
      radius: AppRadius.xxl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CardTitle(
            title: 'أحدث العملاء والموردين',
            subtitle: 'آخر الجهات المسجلة في دليل الحسابات',
            icon: Icons.groups_2_outlined,
          ),
          const SizedBox(height: AppSpacing.lg),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 560;
              final customers = _PartnerList(
                title: 'العملاء',
                icon: Icons.people_alt_outlined,
                color: semantic.warning,
                entries: [
                  for (final customer in data.customers.take(4))
                    _PartnerEntry(
                      name: customer.name,
                      subtitle: customer.code,
                      balance: formatMoney(
                        customer.balance,
                        currency: customer.currency,
                      ),
                    ),
                ],
                emptyLabel: 'لا يوجد عملاء بعد',
              );
              final suppliers = _PartnerList(
                title: 'الموردون',
                icon: Icons.local_shipping_outlined,
                color: semantic.info,
                entries: [
                  for (final supplier in data.suppliers.take(4))
                    _PartnerEntry(
                      name: supplier.name,
                      subtitle: supplier.code,
                      balance: formatMoney(
                        supplier.balance,
                        currency: supplier.currency,
                      ),
                    ),
                ],
                emptyLabel: 'لا يوجد موردون بعد',
              );
              if (!wide) {
                return Column(
                  children: [
                    customers,
                    const SizedBox(height: AppSpacing.lg),
                    suppliers,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: customers),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(child: suppliers),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              'إجمالي ${data.customers.length} عميل و${data.suppliers.length} مورد',
              style: theme.textTheme.labelSmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _PartnerEntry {
  const _PartnerEntry({
    required this.name,
    required this.subtitle,
    required this.balance,
  });

  final String name;
  final String subtitle;
  final String balance;
}

class _PartnerList extends StatelessWidget {
  const _PartnerList({
    required this.title,
    required this.icon,
    required this.color,
    required this.entries,
    required this.emptyLabel,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<_PartnerEntry> entries;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            AppIconTile(icon: icon, size: 32, iconSize: 16, color: color),
            const SizedBox(width: AppSpacing.sm),
            Text(title, style: theme.textTheme.titleSmall),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Text(emptyLabel, style: theme.textTheme.bodySmall),
          )
        else
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  AppAvatar(name: entry.name, size: 32, color: color),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium,
                        ),
                        Text(entry.subtitle, style: theme.textTheme.labelSmall),
                      ],
                    ),
                  ),
                  Text(
                    entry.balance,
                    style: theme.textTheme.labelSmall?.copyWith(color: color),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.action,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppIconTile(icon: icon, size: 36, iconSize: 18),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(subtitle, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        ?action,
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.values, required this.colors});

  final List<double> values;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (sum, value) => sum + value);
    if (total <= 0) {
      return;
    }
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.width / 2,
    );
    final stroke = size.width * 0.16;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;
    var start = -math.pi / 2;
    const gap = 0.035;
    for (var index = 0; index < values.length; index++) {
      final sweep = (values[index] / total) * math.pi * 2;
      paint.color = colors[index % colors.length];
      canvas.drawArc(
        rect.deflate(stroke / 2),
        start + gap / 2,
        math.max(sweep - gap, 0.01),
        false,
        paint,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.colors != colors;
  }
}
