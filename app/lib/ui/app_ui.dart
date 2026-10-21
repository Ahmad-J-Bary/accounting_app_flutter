import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'table/table_preferences.dart';
import 'table/table_preferences_store.dart';

export 'table/table_preferences.dart' show TableDensity;

/// A bordered surface matching the React `Card` primitive.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
    this.radius = AppRadius.xl,
    this.color,
    this.borderColor,
    this.onTap,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final border = borderColor ?? theme.colorScheme.outline;

    final content = Container(
      decoration: BoxDecoration(
        color: color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border),
      ),
      clipBehavior: clipBehavior,
      child: padding == EdgeInsets.zero
          ? child
          : Padding(padding: padding, child: child),
    );

    if (onTap == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: clipBehavior,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        hoverColor: theme.colorScheme.primary.withValues(alpha: 0.035),
        child: content,
      ),
    );
  }
}

class AppSectionCard extends StatelessWidget {
  const AppSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.icon,
    this.action,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
    this.contentPadding = EdgeInsets.zero,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? action;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry contentPadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                AppIconTile(icon: icon!, size: 38, iconSize: 19),
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(subtitle!, style: theme.textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
              if (action != null) ...[
                const SizedBox(width: AppSpacing.md),
                action!,
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Padding(padding: contentPadding, child: child),
        ],
      ),
    );
  }
}

class AppIconTile extends StatelessWidget {
  const AppIconTile({
    super.key,
    required this.icon,
    this.size = 44,
    this.iconSize = 22,
    this.color,
    this.background,
    this.radius = AppRadius.lg,
  });

  final IconData icon;
  final double size;
  final double iconSize;
  final Color? color;
  final Color? background;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = color ?? theme.colorScheme.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? foreground.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: iconSize, color: foreground),
    );
  }
}

class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.actions = const [],
    this.breadcrumbs = const [],
    this.badge,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final List<Widget> actions;
  final List<Widget> breadcrumbs;
  final Widget? badge;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        final heading = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              AppIconTile(icon: icon!, size: 46, iconSize: 23),
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (breadcrumbs.isNotEmpty) ...[
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: breadcrumbs,
                    ),
                    const SizedBox(height: 6),
                  ],
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(title, style: theme.textTheme.headlineLarge),
                      ?badge,
                    ],
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.md),
              trailing!,
            ],
          ],
        );

        final actionRow = Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: actions,
        );

        if (compact && actions.isNotEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              heading,
              const SizedBox(height: AppSpacing.lg),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: actionRow,
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: heading),
            if (actions.isNotEmpty) ...[
              const SizedBox(width: AppSpacing.lg),
              Flexible(
                flex: 2,
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: actionRow,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class AppSearchField extends StatefulWidget {
  const AppSearchField({
    super.key,
    this.controller,
    this.onChanged,
    this.hintText = 'بحث…',
    this.autofocus = false,
    this.onSubmitted,
  });

  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String hintText;
  final bool autofocus;

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  late final TextEditingController _controller =
      widget.controller ?? TextEditingController();
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller.addListener(_changed);
  }

  void _changed() {
    setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_changed);
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      autofocus: widget.autofocus,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'مسح البحث',
                onPressed: () {
                  _controller.clear();
                  widget.onChanged?.call('');
                },
                icon: const Icon(Icons.close, size: 18),
              ),
      ),
    );
  }
}

enum AppBadgeTone { neutral, primary, success, warning, danger, info }

class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    this.tone = AppBadgeTone.neutral,
    this.icon,
    this.compact = false,
  });

  final String label;
  final AppBadgeTone tone;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semanticColors;
    final theme = Theme.of(context);
    final (foreground, background) = switch (tone) {
      AppBadgeTone.neutral => (
        theme.colorScheme.onSurfaceVariant,
        theme.colorScheme.surfaceContainerHighest,
      ),
      AppBadgeTone.primary => (
        theme.colorScheme.primary,
        theme.colorScheme.primary.withValues(alpha: 0.1),
      ),
      AppBadgeTone.success => (
        semantic.success,
        semantic.success.withValues(alpha: 0.12),
      ),
      AppBadgeTone.warning => (
        semantic.warning,
        semantic.warning.withValues(alpha: 0.14),
      ),
      AppBadgeTone.danger => (
        theme.colorScheme.error,
        theme.colorScheme.error.withValues(alpha: 0.11),
      ),
      AppBadgeTone.info => (
        semantic.info,
        semantic.info.withValues(alpha: 0.11),
      ),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 9,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: compact ? 11 : 13, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class AppInfoBanner extends StatelessWidget {
  const AppInfoBanner({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.info_outline,
    this.tone = AppBadgeTone.info,
    this.action,
  });

  final String title;
  final String? message;
  final IconData icon;
  final AppBadgeTone tone;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semanticColors;
    final theme = Theme.of(context);
    final color = switch (tone) {
      AppBadgeTone.success => semantic.success,
      AppBadgeTone.warning => semantic.warning,
      AppBadgeTone.danger => theme.colorScheme.error,
      _ => semantic.info,
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(color: color),
                ),
                if (message != null) ...[
                  const SizedBox(height: 3),
                  Text(message!, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: AppSpacing.sm),
            action!,
          ],
        ],
      ),
    );
  }
}

class AppMetricCard extends StatelessWidget {
  const AppMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.hint,
    this.tone = AppBadgeTone.primary,
    this.trend,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? hint;
  final AppBadgeTone tone;
  final String? trend;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantics = context.semanticColors;
    final color = switch (tone) {
      AppBadgeTone.success => semantics.success,
      AppBadgeTone.warning => semantics.warning,
      AppBadgeTone.danger => theme.colorScheme.error,
      AppBadgeTone.info => semantics.info,
      _ => theme.colorScheme.primary,
    };

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIconTile(icon: icon, size: 38, iconSize: 19, color: color),
              const Spacer(),
              if (trend != null)
                AppBadge(label: trend!, tone: tone, compact: true),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontSize: 23,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: theme.textTheme.bodySmall),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(
              hint!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(color: color),
            ),
          ],
        ],
      ),
    );
  }
}

class AppAvatar extends StatelessWidget {
  const AppAvatar({super.key, required this.name, this.size = 36, this.color});

  final String name;
  final double size;
  final Color? color;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) {
      return '؟';
    }
    if (parts.length == 1) {
      final value = parts.first;
      return value.length <= 2 ? value : value.substring(0, 2);
    }
    return '${parts.first.substring(0, 1)}${parts[1].substring(0, 1)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = color ?? theme.colorScheme.primary;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: foreground.withValues(alpha: 0.1),
        shape: BoxShape.circle,
        border: Border.all(color: foreground.withValues(alpha: 0.12)),
      ),
      child: Text(
        _initials,
        style: theme.textTheme.labelMedium?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
    this.compact = false,
  });

  final String title;
  final String? message;
  final IconData icon;
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: compact ? AppSpacing.xl : 44,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 48 : 58,
            height: compact ? 48 : 58,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: compact ? 22 : 26,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(title, style: theme.textTheme.titleMedium),
          if (message != null) ...[
            const SizedBox(height: 4),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: AppSpacing.lg),
            action!,
          ],
        ],
      ),
    );
  }
}

class AppLoadingState extends StatelessWidget {
  const AppLoadingState({
    super.key,
    this.message = 'جارٍ تحميل البيانات…',
    this.compact = false,
  });

  final String message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? AppSpacing.xl : 56),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(message, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    required this.message,
    this.onRetry,
    this.title = 'تعذّر تحميل البيانات',
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 34, color: theme.colorScheme.error),
          const SizedBox(height: AppSpacing.md),
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ],
      ),
    );
  }
}

/// A single-line table cell value.
///
/// Cells live in fixed-height rows, so every plain text value must be clamped
/// to one line. Long values are ellipsised instead of wrapping into a vertical
/// overflow; the full value stays available through the row detail/form.
class AppTableText extends StatelessWidget {
  const AppTableText(this.value, {super.key, this.style, this.textAlign});

  final String value;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: textAlign,
      style: style,
    );
  }
}

/// A compact icon button for the action cell of a table row.
///
/// Table rows have a fixed height and a narrow action column, so the button
/// uses a smaller tap area than the Material default. Without it a row with
/// three or four actions overflows its column.
class AppTableActionButton extends StatelessWidget {
  const AppTableActionButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.color,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;

  /// Width and height of the button in logical pixels.
  static const double size = 36;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: color),
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        fixedSize: const Size(size, size),
        minimumSize: const Size(size, size),
        maximumSize: const Size(size, size),
        padding: EdgeInsets.zero,
      ),
    );
  }
}

class AppTableColumn<T> {
  const AppTableColumn({
    this.id,
    required this.label,
    required this.builder,
    this.flex = 1,
    this.alignment = AlignmentDirectional.centerStart,
    this.headerAlignment,
    this.width,
    this.minWidth = 72,
    this.sortable = false,
    this.sortValue,
    this.searchText,
    this.summary,
    this.visibleByDefault = true,
    this.canHide = true,
    this.canResize = true,
  });

  /// Stable identifier used by preferences and tests. New tables should always
  /// provide one; older call sites fall back to the label.
  final String? id;
  final String label;
  final Widget Function(BuildContext context, T row) builder;
  final int flex;
  final AlignmentGeometry alignment;
  final AlignmentGeometry? headerAlignment;
  final double? width;
  final double minWidth;
  final bool sortable;

  /// Value used for client-side sorting. Null values sort last.
  final Object? Function(T row)? sortValue;

  /// Value used for search/filter helpers built on top of the table.
  final String Function(T row)? searchText;

  /// Total for this column, shown in the summary row under the body.
  ///
  /// The callback receives the rows the table currently displays (the current
  /// page when [AppDataTable.paginate] is on). A page that already knows the
  /// authoritative total may ignore the argument.
  final String? Function(List<T> rows)? summary;
  final bool visibleByDefault;
  final bool canHide;
  final bool canResize;
}

/// Data table with optional column preferences, sorting, pagination, selection,
/// loading/error/empty states and RTL-aware layout.
///
/// The widget intentionally keeps filtering outside: pages pass the already
/// filtered rows, which keeps the table usable for both client-side and
/// server-side data sources.
class AppDataTable<T> extends StatefulWidget {
  const AppDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.emptyTitle = 'لا توجد بيانات',
    this.emptyMessage,
    this.emptyIcon = Icons.inbox_outlined,
    this.emptyAction,
    this.onRowTap,
    this.rowKey,
    this.rowId,
    this.footer,
    this.toolbar,
    this.minWidth = 760,
    this.rowHeight,
    this.headerHeight,
    this.density,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.tableId,
    this.preferencesStore,
    this.loading = false,
    this.error,
    this.onRetry,
    this.paginate = false,
    this.pageSize = 25,
    this.enableSelection = false,
    this.onSelectionChanged,
    this.showColumnMenu = true,
    this.initialSortColumnId,
    this.initialSortAscending = true,
    this.summaryLabel = 'الإجمالي',
  }) : assert(
         !enableSelection || rowId != null,
         'enableSelection requires rowId so selection survives sorting.',
       );

  final List<AppTableColumn<T>> columns;
  final List<T> rows;
  final String emptyTitle;
  final String? emptyMessage;
  final IconData emptyIcon;
  final Widget? emptyAction;
  final ValueChanged<T>? onRowTap;
  final Key Function(T row)? rowKey;

  /// Stable row identity, required when [enableSelection] is true.
  final Object Function(T row)? rowId;
  final Widget? footer;
  final Widget? toolbar;
  final double minWidth;

  /// Overrides the row height of the active density when set.
  final double? rowHeight;

  /// Overrides the header height of the active density when set.
  final double? headerHeight;

  /// Default row density. A stored preference for the same table wins, so the
  /// user keeps the density they chose; this value applies to tables without
  /// stored preferences.
  final TableDensity? density;
  final EdgeInsetsGeometry padding;

  /// Enables persistence of column order, visibility, widths, page size and
  /// sorting under this key.
  final String? tableId;
  final TablePreferencesStore? preferencesStore;
  final bool loading;
  final String? error;
  final VoidCallback? onRetry;
  final bool paginate;
  final int pageSize;
  final bool enableSelection;
  final ValueChanged<Set<Object>>? onSelectionChanged;
  final bool showColumnMenu;
  final String? initialSortColumnId;
  final bool initialSortAscending;

  /// Label shown in the first column of the summary row.
  final String summaryLabel;

  @override
  State<AppDataTable<T>> createState() => _AppDataTableState<T>();
}

class _AppDataTableState<T> extends State<AppDataTable<T>> {
  TablePreferencesController? _preferences;
  final Set<Object> _selected = <Object>{};
  final Map<String, double> _localWidths = <String, double>{};
  final FocusNode _tableFocus = FocusNode(debugLabel: 'AppDataTable');
  final ScrollController _verticalScroll = ScrollController();
  final ScrollController _horizontalScroll = ScrollController();
  String? _sortColumnId;
  bool _sortAscending = true;
  bool _adoptedPreferences = false;
  int _page = 0;
  int _localPageSize = 25;
  int? _focusedRow;

  /// Drives the row highlight without rebuilding the table.
  ///
  /// The cursor lives in a [ValueNotifier] so an arrow key only repaints the
  /// row that loses the highlight and the row that gains it; calling `setState`
  /// here would rebuild every visible row on each key repeat.
  final ValueNotifier<int?> _focusedRowNotifier = ValueNotifier<int?>(null);
  List<T>? _sortedCache;
  List<T>? _sortedSource;
  String? _sortedKey;
  List<Object?>? _sortKeys;
  List<T>? _sortKeysSource;
  String? _sortKeysColumnId;
  List<String> _columnIds = const <String>[];

  @override
  void initState() {
    super.initState();
    _sortColumnId = widget.initialSortColumnId;
    _sortAscending = widget.initialSortAscending;
    _localPageSize = widget.pageSize;
    _columnIds = _resolveColumnIds(widget.columns);
    _createPreferences();
  }

  @override
  void didUpdateWidget(covariant AppDataTable<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ids = _resolveColumnIds(widget.columns);
    if (!listEquals(ids, _columnIds)) {
      _columnIds = ids;
      _preferences?.syncColumns(ids, requiredColumnIds: _requiredColumnIds);
    }
    if (oldWidget.tableId != widget.tableId ||
        oldWidget.preferencesStore != widget.preferencesStore) {
      _preferences?.dispose();
      _createPreferences();
    }
    if (widget.rowId != null) {
      final valid = widget.rows.map(widget.rowId!).toSet();
      final before = _selected.length;
      _selected.removeWhere((id) => !valid.contains(id));
      if (_selected.length != before) {
        _notifySelection();
      }
    }
    if (oldWidget.rows.length != widget.rows.length ||
        oldWidget.pageSize != widget.pageSize) {
      _page = 0;
      _focusedRow = null;
      // Deferred while the tree is building; see [_setCursor].
      _setCursor(null);
    }
  }

  @override
  void dispose() {
    _preferences?.removeListener(_onPreferencesChanged);
    _preferences?.dispose();
    _tableFocus.dispose();
    _focusedRowNotifier.dispose();
    _verticalScroll.dispose();
    _horizontalScroll.dispose();
    super.dispose();
  }

  static List<String> _resolveColumnIds(List<AppTableColumn<dynamic>> columns) {
    return <String>[
      for (var index = 0; index < columns.length; index++)
        columns[index].id ??
            (columns[index].label.isEmpty
                ? 'column_$index'
                : columns[index].label),
    ];
  }

  Set<String> get _requiredColumnIds => <String>{
    for (var index = 0; index < widget.columns.length; index++)
      if (!widget.columns[index].canHide) _columnIds[index],
  };

  void _createPreferences() {
    // A new controller may hold a different saved sort/page size, so the
    // adoption step must run again for this table.
    _adoptedPreferences = false;
    final tableId = widget.tableId;
    if (tableId == null) {
      _preferences = null;
      return;
    }
    assert(() {
      if (_columnIds.toSet().length != _columnIds.length) {
        throw FlutterError(
          'AppDataTable "$tableId" has duplicate column ids: $_columnIds. '
          'Give each column a unique id.',
        );
      }
      return true;
    }());
    final controller = TablePreferencesController(
      tableId: tableId,
      columnIds: _columnIds,
      requiredColumnIds: _requiredColumnIds,
      store: widget.preferencesStore ?? createDefaultTablePreferencesStore(),
      defaultPageSize: widget.pageSize,
      defaultDensity: widget.density ?? TableDensity.comfortable,
    );
    controller.addListener(_onPreferencesChanged);
    _preferences = controller;
    controller.load();
  }

  void _onPreferencesChanged() {
    final preferences = _preferences;
    if (preferences == null || !mounted) {
      return;
    }
    if (!_adoptedPreferences && preferences.isLoaded) {
      _adoptedPreferences = true;
      final value = preferences.value;
      _sortColumnId = value.sortColumnId;
      _sortAscending = value.sortAscending;
      if (_localPageSize != value.pageSize) {
        _localPageSize = value.pageSize;
        _page = 0;
      }
    }
    setState(() {});
  }

  String _idAt(int index) => _columnIds[index];

  /// Active row density: the caller's default unless the table has a stored
  /// preference.
  TableDensity get _density =>
      widget.density ?? TableDensity.fromId(_preferences?.value.density);

  double get _rowHeight => widget.rowHeight ?? _density.rowHeight;

  double get _headerHeight => widget.headerHeight ?? _density.headerHeight;

  int get _pageSize => _preferences?.value.pageSize ?? _localPageSize;

  void _setPageSize(int pageSize) {
    if (_preferences != null) {
      _preferences!.setPageSize(pageSize);
    } else {
      setState(() {
        _localPageSize = pageSize;
        _resetFocus();
      });
    }
  }

  void _toggleSort(String id) {
    final ascending = _sortColumnId == id ? !_sortAscending : true;
    setState(() {
      _sortColumnId = id;
      _sortAscending = ascending;
      _resetFocus();
    });
    _preferences?.toggleSort(id, ascending: ascending);
  }

  void _setWidth(String id, double width) {
    final preferences = _preferences;
    if (preferences != null) {
      preferences.setWidth(id, width);
    } else {
      setState(() {
        _localWidths[id] = width.clamp(
          TablePreferences.minWidth,
          TablePreferences.maxWidth,
        );
      });
    }
  }

  /// Drops the manual width of a column so it returns to its automatic share
  /// of the table width.
  void _resetColumnWidth(String id) {
    final preferences = _preferences;
    if (preferences != null) {
      preferences.clearWidth(id);
      return;
    }
    setState(() => _localWidths.remove(id));
  }

  List<AppTableColumn<T>> _orderedColumns() {
    final preferences = _preferences;
    if (preferences == null) {
      return widget.columns;
    }
    final byId = <String, AppTableColumn<T>>{
      for (var index = 0; index < widget.columns.length; index++)
        _idAt(index): widget.columns[index],
    };
    final hidden = preferences.value.hidden;
    return <AppTableColumn<T>>[
      for (final id in preferences.value.order)
        if (!hidden.contains(id) && byId[id] != null) byId[id]!,
    ];
  }

  List<T> _sortedRows() {
    final id = _sortColumnId;
    final sortValue = _sortValueFor(id);
    if (sortValue == null) {
      return widget.rows;
    }
    final rows = widget.rows;
    final ascending = _sortAscending;
    final key = '${id}_$ascending';
    if (identical(_sortedSource, rows) &&
        _sortedKey == key &&
        _sortedCache != null) {
      return _sortedCache!;
    }
    // Extract each sort key once instead of once per comparison: a comparator
    // that calls `sortValue` runs it O(n log n) times, which is visible on long
    // lists and on sort values that parse or format a value (amounts, dates).
    List<Object?> keys;
    if (identical(_sortKeysSource, rows) &&
        _sortKeysColumnId == id &&
        _sortKeys != null) {
      keys = _sortKeys!;
    } else {
      keys = List<Object?>.generate(
        rows.length,
        (index) => sortValue(rows[index]),
        growable: false,
      );
      _sortKeys = keys;
      _sortKeysSource = rows;
      _sortKeysColumnId = id;
    }
    final order = List<int>.generate(rows.length, (index) => index);
    order.sort((a, b) {
      final left = keys[a];
      final right = keys[b];
      final int comparison;
      if (left == null && right == null) {
        comparison = 0;
      } else if (left == null) {
        // Null values stay last in both directions.
        comparison = 1;
      } else if (right == null) {
        comparison = -1;
      } else {
        final value = _compareValues(left, right);
        comparison = ascending ? value : -value;
      }
      // Equal keys keep their source order: sorting must not reshuffle rows
      // between pages when many rows share a value (same date, same party…).
      return comparison != 0 ? comparison : a.compareTo(b);
    });
    final sorted = <T>[for (final index in order) rows[index]];
    _sortedSource = rows;
    _sortedKey = key;
    _sortedCache = sorted;
    return sorted;
  }

  Object? Function(T)? _sortValueFor(String? id) {
    if (id == null) {
      return null;
    }
    final index = _columnIds.indexOf(id);
    if (index < 0) {
      return null;
    }
    final column = widget.columns[index];
    if (!column.sortable) {
      return null;
    }
    return column.sortValue;
  }

  int _compareValues(Object left, Object right) {
    if (left is num && right is num) {
      return left.compareTo(right);
    }
    if (left is DateTime && right is DateTime) {
      return left.compareTo(right);
    }
    return left.toString().toLowerCase().compareTo(
      right.toString().toLowerCase(),
    );
  }

  void _notifySelection() {
    widget.onSelectionChanged?.call(Set<Object>.unmodifiable(_selected));
  }

  void _toggleRow(Object id, bool selected) {
    setState(() {
      if (selected) {
        _selected.add(id);
      } else {
        _selected.remove(id);
      }
    });
    _notifySelection();
  }

  void _togglePage(List<Object> ids, bool selected) {
    setState(() {
      if (selected) {
        _selected.addAll(ids);
      } else {
        _selected.removeAll(ids);
      }
    });
    _notifySelection();
  }

  int get _keyboardPageStep {
    if (_verticalScroll.hasClients) {
      final visible = (_verticalScroll.position.viewportDimension / _rowHeight)
          .floor();
      if (visible > 2) {
        return visible - 1;
      }
    }
    return 10;
  }

  /// Keyboard access for desktop users: arrows move a row cursor, Enter opens
  /// the row, Space toggles selection and Home/End/PageUp/PageDown jump.
  KeyEventResult _handleKeyEvent(KeyEvent event, List<T> rows) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (rows.isEmpty) {
      return KeyEventResult.ignored;
    }
    final current = _focusedRow?.clamp(0, rows.length - 1);
    final count = rows.length;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowDown) {
      _focusRow(current == null ? 0 : current + 1, count);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _focusRow(current == null ? count - 1 : current - 1, count);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.home) {
      _focusRow(0, count);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.end) {
      _focusRow(count - 1, count);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.pageDown) {
      _focusRow((current ?? 0) + _keyboardPageStep, count);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.pageUp) {
      _focusRow((current ?? count - 1) - _keyboardPageStep, count);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      final onRowTap = widget.onRowTap;
      if (current == null || onRowTap == null) {
        return KeyEventResult.ignored;
      }
      onRowTap(rows[current]);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.space && widget.enableSelection) {
      final rowId = widget.rowId;
      if (current == null || rowId == null) {
        return KeyEventResult.ignored;
      }
      final id = rowId(rows[current]);
      _toggleRow(id, !_selected.contains(id));
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _focusRow(int index, int count) {
    if (count == 0) {
      return;
    }
    final next = index.clamp(0, count - 1);
    _focusedRow = next;
    // No `setState`: the rows themselves listen to the cursor, so holding an
    // arrow key repaints two rows instead of the whole viewport.
    _setCursor(next);
    _tableFocus.requestFocus();
    final controller = _verticalScroll;
    if (!controller.hasClients) {
      return;
    }
    final position = controller.position;
    final top = next * _rowHeight;
    final bottom = top + _rowHeight;
    final offset = position.pixels;
    final viewport = position.viewportDimension;
    double? target;
    if (top < offset) {
      target = top;
    } else if (bottom > offset + viewport) {
      target = bottom - viewport;
    }
    if (target == null) {
      return;
    }
    controller.animateTo(
      target.clamp(0.0, position.maxScrollExtent),
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
    );
  }

  void _resetFocus([int page = 0]) {
    _focusedRow = null;
    _setCursor(null);
    _page = page;
    if (_verticalScroll.hasClients) {
      _verticalScroll.jumpTo(0);
    }
  }

  /// Moves the keyboard cursor and notifies the rows that listen to it.
  ///
  /// Writing the notifier while the tree is building would rebuild rows that
  /// are already being built, so the change is deferred to the end of the
  /// frame in that case.
  void _setCursor(int? index) {
    if (_focusedRowNotifier.value == index) {
      return;
    }
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusedRowNotifier.value = index;
        }
      });
      return;
    }
    _focusedRowNotifier.value = index;
  }

  void _resetPreferences() {
    final preferences = _preferences;
    if (preferences == null) {
      return;
    }
    preferences.reset();
    setState(() {
      _sortColumnId = null;
      _sortAscending = true;
      _page = 0;
      _localWidths.clear();
    });
  }

  Future<void> _openColumnSettings() async {
    final preferences = _preferences;
    if (preferences == null) {
      return;
    }
    final theme = Theme.of(context);
    final labels = <String, String>{
      for (var index = 0; index < widget.columns.length; index++)
        _idAt(index): widget.columns[index].label,
    };
    final hideable = <String, bool>{
      for (var index = 0; index < widget.columns.length; index++)
        _idAt(index): widget.columns[index].canHide,
    };
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AnimatedBuilder(
          animation: preferences,
          builder: (context, _) {
            final value = preferences.value;
            return AlertDialog(
              title: const Text('أعمدة الجدول'),
              content: SizedBox(
                width: 380,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'كثافة العرض',
                            style: theme.textTheme.labelLarge,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          SegmentedButton<TableDensity>(
                            segments: const [
                              ButtonSegment<TableDensity>(
                                value: TableDensity.compact,
                                label: Text('مدمج'),
                              ),
                              ButtonSegment<TableDensity>(
                                value: TableDensity.comfortable,
                                label: Text('مريح'),
                              ),
                              ButtonSegment<TableDensity>(
                                value: TableDensity.spacious,
                                label: Text('واسع'),
                              ),
                            ],
                            selected: {TableDensity.fromId(value.density)},
                            showSelectedIcon: false,
                            style: const ButtonStyle(
                              visualDensity: VisualDensity.compact,
                            ),
                            onSelectionChanged: (selection) =>
                                preferences.setDensity(selection.first),
                          ),
                        ],
                      ),
                    ),
                    for (var index = 0; index < value.order.length; index++)
                      _ColumnSettingsRow(
                        label: labels[value.order[index]] ?? value.order[index],
                        visible: !value.hidden.contains(value.order[index]),
                        canHide: hideable[value.order[index]] ?? true,
                        canMoveUp: index > 0,
                        canMoveDown: index < value.order.length - 1,
                        onVisibleChanged: (visible) =>
                            preferences.setVisible(value.order[index], visible),
                        onMoveUp: () =>
                            preferences.move(value.order[index], -1),
                        onMoveDown: () =>
                            preferences.move(value.order[index], 1),
                      ),
                  ],
                ),
              ),
              actions: [
                if (value.hidden.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      for (final id in value.hidden.toList()) {
                        preferences.setVisible(id, true);
                      }
                    },
                    child: const Text('إظهار الكل'),
                  ),
                TextButton(
                  onPressed: _resetPreferences,
                  child: const Text('إعادة الضبط'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('تم'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return const AppLoadingState(
        message: 'جارٍ تحميل البيانات…',
        compact: true,
      );
    }
    final error = widget.error;
    if (error != null) {
      return AppErrorState(message: error, onRetry: widget.onRetry);
    }

    final columns = _orderedColumns();
    final sorted = _sortedRows();
    final pageSize = _pageSize;
    final pageCount = sorted.isEmpty
        ? 1
        : ((sorted.length + pageSize - 1) ~/ pageSize);
    final page = _page.clamp(0, pageCount - 1);
    final start = page * pageSize;
    final end = math.min(start + pageSize, sorted.length);
    final pageRows = widget.paginate ? sorted.sublist(start, end) : sorted;
    final pageIds = <Object>[
      if (widget.rowId != null)
        for (final row in pageRows) widget.rowId!(row),
    ];

    return AppCard(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bounded = constraints.hasBoundedHeight;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
            children: [
              if (widget.toolbar != null || _preferences != null)
                _toolbar(context),
              if (sorted.isEmpty)
                AppEmptyState(
                  title: widget.emptyTitle,
                  message: widget.emptyMessage,
                  icon: widget.emptyIcon,
                  action: widget.emptyAction,
                  compact: true,
                )
              else if (bounded)
                Expanded(
                  child: _tableBody(
                    context,
                    columns: columns,
                    rows: pageRows,
                    pageIds: pageIds,
                  ),
                )
              else
                _tableBody(
                  context,
                  columns: columns,
                  rows: pageRows,
                  pageIds: pageIds,
                ),
              if (sorted.isNotEmpty && widget.footer != null)
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.35),
                    border: Border(
                      top: BorderSide(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  child: LayoutBuilder(
                    builder: (context, footerConstraints) {
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: math.max(
                            footerConstraints.maxWidth,
                            widget.minWidth,
                          ),
                          child: widget.footer,
                        ),
                      );
                    },
                  ),
                ),
              if (widget.paginate && sorted.isNotEmpty)
                _paginationBar(
                  context,
                  page: page,
                  pageCount: pageCount,
                  start: start,
                  end: end,
                  total: sorted.length,
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _toolbar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).colorScheme.outline),
        ),
      ),
      child: Row(
        children: [
          if (widget.toolbar != null)
            Expanded(child: widget.toolbar!)
          else
            const Spacer(),
          if (_preferences != null && widget.showColumnMenu)
            IconButton(
              tooltip: 'إعدادات الأعمدة',
              onPressed: _openColumnSettings,
              icon: Badge.count(
                count: _preferences!.value.hidden.length,
                isLabelVisible: _preferences!.value.hidden.isNotEmpty,
                child: const Icon(Icons.view_column_outlined, size: 20),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tableBody(
    BuildContext context, {
    required List<AppTableColumn<T>> columns,
    required List<T> rows,
    required List<Object> pageIds,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final selectionWidth = widget.enableSelection ? 44.0 : 0.0;
        final available = math.max(constraints.maxWidth, widget.minWidth);
        // Only visible columns occupy width. Resolve each visible column back to
        // its stable id once instead of an O(n) indexOf per header/row cell.
        final idByColumn = <AppTableColumn<T>, String>{
          for (var index = 0; index < widget.columns.length; index++)
            widget.columns[index]: _idAt(index),
        };
        final widths = <String, double>{};
        var fixedWidth = selectionWidth;
        final flexible = <String, int>{};
        for (final column in columns) {
          final id = idByColumn[column]!;
          final override = _preferences?.value.widths[id] ?? _localWidths[id];
          if (override != null) {
            widths[id] = override;
            fixedWidth += override;
          } else if (column.width != null) {
            widths[id] = column.width!;
            fixedWidth += column.width!;
          } else {
            flexible[id] = column.flex;
          }
        }
        var minimumFlex = 0.0;
        for (final column in columns) {
          if (flexible.containsKey(idByColumn[column])) {
            minimumFlex += column.minWidth;
          }
        }
        final baseWidth = math.max(available, fixedWidth + minimumFlex);
        final flexSpace = math.max(0.0, baseWidth - fixedWidth);
        final flexTotal = flexible.values.fold<int>(
          0,
          (sum, value) => sum + value,
        );
        for (final column in columns) {
          final id = idByColumn[column]!;
          final flex = flexible[id];
          if (flex != null) {
            widths[id] = math.max(
              column.minWidth,
              flexSpace * flex / (flexTotal == 0 ? 1 : flexTotal),
            );
          }
        }
        final tableWidth = math.max(
          available,
          widths.values.fold<double>(0, (sum, width) => sum + width),
        );

        final header = _header(
          context,
          columns: columns,
          widths: widths,
          idByColumn: idByColumn,
          pageIds: pageIds,
        );
        final hasSummary = columns.any((column) => column.summary != null);
        final content = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            if (constraints.hasBoundedHeight)
              Expanded(
                child: ListView.builder(
                  controller: _verticalScroll,
                  itemCount: rows.length,
                  // Every row is exactly [_rowHeight] tall, so the scroll
                  // view can compute its extents without laying each child out.
                  itemExtent: _rowHeight,
                  // Rows hold no state worth keeping off-screen, so skip the
                  // keep-alive element that `ListView.builder` adds per child.
                  addAutomaticKeepAlives: false,
                  itemBuilder: (context, index) => _focusAwareRow(
                    context,
                    rows[index],
                    index,
                    isLast: index == rows.length - 1,
                    columns: columns,
                    widths: widths,
                    idByColumn: idByColumn,
                  ),
                ),
              )
            else
              for (var index = 0; index < rows.length; index++)
                _focusAwareRow(
                  context,
                  rows[index],
                  index,
                  isLast: index == rows.length - 1,
                  columns: columns,
                  widths: widths,
                  idByColumn: idByColumn,
                ),
            if (hasSummary)
              _summaryRow(
                context,
                columns: columns,
                rows: rows,
                widths: widths,
                idByColumn: idByColumn,
              ),
          ],
        );

        return Focus(
          focusNode: _tableFocus,
          onKeyEvent: (node, event) => _handleKeyEvent(event, rows),
          child: Listener(
            onPointerDown: (_) => _tableFocus.requestFocus(),
            child: Scrollbar(
              controller: _horizontalScroll,
              scrollbarOrientation: ScrollbarOrientation.bottom,
              child: SingleChildScrollView(
                controller: _horizontalScroll,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: tableWidth,
                  height: constraints.hasBoundedHeight
                      ? constraints.maxHeight
                      : null,
                  child: content,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _header(
    BuildContext context, {
    required List<AppTableColumn<T>> columns,
    required Map<String, double> widths,
    required Map<AppTableColumn<T>, String> idByColumn,
    required List<Object> pageIds,
  }) {
    final theme = Theme.of(context);
    final allSelected = pageIds.isNotEmpty && pageIds.every(_selected.contains);
    final someSelected = pageIds.any(_selected.contains);
    return Container(
      height: _headerHeight,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.65,
        ),
        border: Border(bottom: BorderSide(color: theme.colorScheme.outline)),
      ),
      child: Row(
        children: [
          if (widget.enableSelection)
            SizedBox(
              width: 44,
              child: Center(
                child: Semantics(
                  label: 'تحديد كل الصفوف في هذه الصفحة',
                  child: Checkbox(
                    value: allSelected ? true : (someSelected ? null : false),
                    tristate: true,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (value) => _togglePage(pageIds, value ?? false),
                  ),
                ),
              ),
            ),
          for (final column in columns)
            _headerCell(context, column, idByColumn[column]!, widths),
        ],
      ),
    );
  }

  Widget _headerCell(
    BuildContext context,
    AppTableColumn<T> column,
    String id,
    Map<String, double> widths,
  ) {
    final theme = Theme.of(context);
    final width = widths[id] ?? column.width ?? column.minWidth;
    final sorted = _sortColumnId == id;
    final canSort = column.sortable && column.sortValue != null;
    final alignment = column.headerAlignment ?? column.alignment;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return SizedBox(
      width: width,
      child: Stack(
        children: [
          Positioned.fill(
            child: Semantics(
              button: canSort,
              child: InkWell(
                onTap: canSort ? () => _toggleSort(id) : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Align(
                    alignment: alignment,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            column.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (sorted) ...[
                          const SizedBox(width: 4),
                          Icon(
                            _sortAscending
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            size: 13,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (column.canResize)
            PositionedDirectional(
              end: 0,
              top: 0,
              bottom: 0,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeLeftRight,
                child: Tooltip(
                  message: 'اسحب لتغيير العرض، وانقر مرتين لإعادة العرض',
                  child: GestureDetector(
                    key: ValueKey<String>('app-table-resize-$id'),
                    behavior: HitTestBehavior.translucent,
                    onDoubleTap: () => _resetColumnWidth(id),
                    onHorizontalDragUpdate: (details) {
                      final direction = rtl ? -1 : 1;
                      _setWidth(id, width + details.delta.dx * direction);
                    },
                    child: SizedBox(
                      width: 8,
                      child: Center(
                        child: Container(
                          width: 1,
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Builds one row inside a focus scope so the keyboard cursor repaints only
  /// the two rows involved instead of every row in the viewport.
  Widget _focusAwareRow(
    BuildContext context,
    T row,
    int index, {
    required bool isLast,
    required List<AppTableColumn<T>> columns,
    required Map<String, double> widths,
    required Map<AppTableColumn<T>, String> idByColumn,
  }) {
    return _RowFocusScope(
      index: index,
      notifier: _focusedRowNotifier,
      builder: (context, focused) => _row(
        context,
        row,
        index,
        isLast: isLast,
        focused: focused,
        columns: columns,
        widths: widths,
        idByColumn: idByColumn,
      ),
    );
  }

  /// Totals row aligned with the columns, pinned under the body.
  ///
  /// The React table aligned its summary with the grid; the Flutter table
  /// keeps the same alignment by reusing the resolved column widths.
  Widget _summaryRow(
    BuildContext context, {
    required List<AppTableColumn<T>> columns,
    required List<T> rows,
    required Map<String, double> widths,
    required Map<AppTableColumn<T>, String> idByColumn,
  }) {
    final theme = Theme.of(context);
    return Container(
      height: _rowHeight,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.45,
        ),
        border: Border(top: BorderSide(color: theme.colorScheme.outline)),
      ),
      child: Row(
        children: [
          for (var index = 0; index < columns.length; index++)
            SizedBox(
              width: widths[idByColumn[columns[index]]!] ?? 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Align(
                  alignment: columns[index].alignment,
                  child: AppTableText(
                    columns[index].summary?.call(rows) ??
                        (index == 0 ? widget.summaryLabel : ''),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    T row,
    int index, {
    required bool isLast,
    required bool focused,
    required List<AppTableColumn<T>> columns,
    required Map<String, double> widths,
    required Map<AppTableColumn<T>, String> idByColumn,
  }) {
    final theme = Theme.of(context);
    final id = widget.rowId?.call(row);
    final selected = id != null && _selected.contains(id);
    final content = Container(
      height: _rowHeight,
      foregroundDecoration: focused
          ? BoxDecoration(
              border: Border.all(color: theme.colorScheme.primary, width: 1.5),
            )
          : null,
      decoration: BoxDecoration(
        color: selected
            ? theme.colorScheme.primary.withValues(alpha: 0.06)
            : null,
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.65),
                ),
              ),
      ),
      child: Row(
        children: [
          if (widget.enableSelection)
            SizedBox(
              width: 44,
              child: Center(
                child: Checkbox(
                  value: selected,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: id == null
                      ? null
                      : (value) => _toggleRow(id, value ?? false),
                ),
              ),
            ),
          for (final column in columns)
            _cell(
              context,
              column,
              column.builder(context, row),
              width: widths[idByColumn[column]!] ?? 0,
            ),
        ],
      ),
    );

    final key =
        widget.rowKey?.call(row) ?? (id == null ? null : ValueKey<Object>(id));
    if (widget.onRowTap == null) {
      return KeyedSubtree(key: key, child: content);
    }
    return Material(
      key: key,
      color: Colors.transparent,
      child: InkWell(
        onTap: () => widget.onRowTap!(row),
        hoverColor: theme.colorScheme.primary.withValues(alpha: 0.035),
        child: content,
      ),
    );
  }

  Widget _cell(
    BuildContext context,
    AppTableColumn<T> column,
    Widget child, {
    required double width,
  }) {
    return SizedBox(
      width: width,
      child: Align(
        alignment: column.alignment,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: child,
        ),
      ),
    );
  }

  Widget _paginationBar(
    BuildContext context, {
    required int page,
    required int pageCount,
    required int start,
    required int end,
    required int total,
  }) {
    final theme = Theme.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final previousIcon = rtl ? Icons.chevron_right : Icons.chevron_left;
    final nextIcon = rtl ? Icons.chevron_left : Icons.chevron_right;
    final range = Text(
      'عرض ${start + 1}–$end من $total',
      style: theme.textTheme.labelSmall,
    );
    final pageSizeControl = DropdownButtonHideUnderline(
      child: DropdownButton<int>(
        value: _pageSize,
        isDense: true,
        items: [
          for (final size in TablePreferences.allowedPageSizes)
            DropdownMenuItem<int>(value: size, child: Text('$size / صفحة')),
        ],
        onChanged: (value) {
          if (value != null) {
            _setPageSize(value);
            setState(() => _resetFocus());
          }
        },
      ),
    );
    final navigation = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'الصفحة السابقة',
          onPressed: page > 0
              ? () => setState(() => _resetFocus(page - 1))
              : null,
          icon: Icon(previousIcon, size: 20),
        ),
        Text('${page + 1} / $pageCount', style: theme.textTheme.labelSmall),
        IconButton(
          tooltip: 'الصفحة التالية',
          onPressed: page + 1 < pageCount
              ? () => setState(() => _resetFocus(page + 1))
              : null,
          icon: Icon(nextIcon, size: 20),
        ),
      ],
    );
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.colorScheme.outline)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // The full bar does not fit on phone widths; stack the controls
          // instead of letting the row overflow.
          if (constraints.maxWidth < 520) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: range),
                    pageSizeControl,
                  ],
                ),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: navigation,
                ),
              ],
            );
          }
          return Row(
            children: [
              range,
              const Spacer(),
              pageSizeControl,
              const SizedBox(width: AppSpacing.sm),
              navigation,
            ],
          );
        },
      ),
    );
  }
}

/// Rebuilds a single row when *its* focus state changes.
///
/// `AppDataTable` keeps the keyboard cursor in a [ValueNotifier] instead of
/// calling `setState`. Listening here means an arrow key repaints the row that
/// loses the highlight and the row that gains it; without this, every visible
/// row rebuilds on each key repeat.
class _RowFocusScope extends StatefulWidget {
  const _RowFocusScope({
    required this.index,
    required this.notifier,
    required this.builder,
  });

  final int index;
  final ValueListenable<int?> notifier;
  final Widget Function(BuildContext context, bool focused) builder;

  @override
  State<_RowFocusScope> createState() => _RowFocusScopeState();
}

class _RowFocusScopeState extends State<_RowFocusScope> {
  late bool _focused = widget.notifier.value == widget.index;

  @override
  void initState() {
    super.initState();
    widget.notifier.addListener(_onCursorChanged);
  }

  @override
  void didUpdateWidget(covariant _RowFocusScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.notifier, widget.notifier)) {
      oldWidget.notifier.removeListener(_onCursorChanged);
      widget.notifier.addListener(_onCursorChanged);
    }
    // The parent rebuild may have moved the cursor or re-indexed this row, so
    // resync before the build that follows this call.
    _focused = widget.notifier.value == widget.index;
  }

  @override
  void dispose() {
    widget.notifier.removeListener(_onCursorChanged);
    super.dispose();
  }

  void _onCursorChanged() {
    final focused = widget.notifier.value == widget.index;
    if (focused != _focused && mounted) {
      setState(() => _focused = focused);
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _focused);
}

class _ColumnSettingsRow extends StatelessWidget {
  const _ColumnSettingsRow({
    required this.label,
    required this.visible,
    required this.canHide,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onVisibleChanged,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final String label;
  final bool visible;
  final bool canHide;
  final bool canMoveUp;
  final bool canMoveDown;
  final ValueChanged<bool> onVisibleChanged;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Checkbox(
          value: visible,
          onChanged: canHide
              ? (value) => onVisibleChanged(value ?? true)
              : null,
        ),
        Expanded(
          child: Text(
            label.isEmpty ? 'إجراءات' : label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          tooltip: 'تقديم',
          onPressed: canMoveUp ? onMoveUp : null,
          icon: const Icon(Icons.arrow_upward, size: 17),
        ),
        IconButton(
          tooltip: 'تأخير',
          onPressed: canMoveDown ? onMoveDown : null,
          icon: const Icon(Icons.arrow_downward, size: 17),
        ),
      ],
    );
  }
}

class AppSectionTitle extends StatelessWidget {
  const AppSectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
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

/// A responsive, intrinsic-height grid for [AppMetricCard]s. Using a Wrap
/// instead of a fixed-aspect-ratio GridView keeps the cards readable at every
/// window width and avoids vertical overflow in compact layouts.
class AppMetricGrid extends StatelessWidget {
  const AppMetricGrid({
    super.key,
    required this.children,
    this.minItemWidth = 230,
    this.maxColumns = 4,
  });

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
            (constraints.maxWidth - (AppSpacing.md * (columns - 1))) / columns;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

String formatCompactAmount(String raw) {
  final value = double.tryParse(raw);
  if (value == null) {
    return raw;
  }
  final negative = value < 0;
  final absolute = value.abs();
  final formatted = absolute >= 1000000
      ? '${(absolute / 1000000).toStringAsFixed(2)} م'
      : absolute >= 1000
      ? '${(absolute / 1000).toStringAsFixed(1)} ألف'
      : absolute.toStringAsFixed(2);
  return negative ? '-$formatted' : formatted;
}
