import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../theme/app_theme.dart';
import 'settings_model.dart';
import 'settings_service.dart';

// ─── Section ids ──────────────────────────────────────────────────
class _SecId {
  static const company = 'company';
  static const prefixes = 'prefixes';
  static const currencies = 'currencies';
  static const financial = 'financial';
  static const warehouses = 'warehouses';
  static const localization = 'localization';
  static const export = 'export';
  static const backups = 'backups';
  static const security = 'security';
  static const about = 'about';
  static const appearance = 'appearance';
  static const tables = 'tables';
  static const navbar = 'navbar';
  static const sidebarContent = 'sidebar-content';
  static const panel = 'panel';
  static const pageHeader = 'page-header';
  static const tabs = 'tabs';
}

class _Sec {
  const _Sec(this.id, this.label, this.icon);
  final String id;
  final String label;
  final IconData icon;
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _active = _SecId.company;
  bool _appearanceOpen = false;

  List<_Sec> _main(AppStrings s) => [
        _Sec(_SecId.company, s.settingsSectionCompany, Icons.business_outlined),
        _Sec(_SecId.prefixes, s.settingsSectionPrefixes, Icons.tag_outlined),
        _Sec(_SecId.currencies, s.settingsSectionCurrencies,
            Icons.attach_money_outlined),
        _Sec(_SecId.financial, s.settingsSectionFinancial, Icons.tune_outlined),
        _Sec(_SecId.warehouses, s.settingsSectionWarehouses,
            Icons.warehouse_outlined),
        _Sec(_SecId.localization, s.settingsSectionLocalization,
            Icons.language_outlined),
        _Sec(_SecId.export, s.settingsSectionExport, Icons.file_download_outlined),
        _Sec(_SecId.backups, s.settingsSectionBackups, Icons.storage_outlined),
        _Sec(_SecId.security, s.settingsSectionSecurity, Icons.shield_outlined),
        _Sec(_SecId.about, s.settingsSectionAbout, Icons.info_outline),
      ];

  List<_Sec> _appearance(AppStrings s) => [
        _Sec(_SecId.appearance, s.settingsSectionAppearance,
            Icons.palette_outlined),
        _Sec(_SecId.tables, s.settingsSectionTables, Icons.table_chart_outlined),
        _Sec(_SecId.navbar, s.settingsSectionNavbar, Icons.menu_outlined),
        _Sec(_SecId.sidebarContent, s.settingsSectionSidebarContent,
            Icons.list_alt_outlined),
        _Sec(_SecId.panel, s.settingsSectionPanel, Icons.article_outlined),
        _Sec(_SecId.pageHeader, s.settingsSectionPageHeader,
            Icons.web_asset_outlined),
        _Sec(_SecId.tabs, s.settingsSectionTabs, Icons.tab_outlined),
      ];

  void _select(String id) {
    setState(() {
      _active = id;
      final isAppearance = _appearance(context.strings).any((s) => s.id == id);
      if (isAppearance) _appearanceOpen = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<SettingsService>();
    final strings = service.locale.language.strings;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 940;
        return Column(
          children: [
            _buildTopRow(context, strings, compact: compact),
            const Divider(height: 1),
            Expanded(
              child: compact
                  ? _buildCompactBody(context, strings)
                  : _buildWideBody(context, strings),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTopRow(
    BuildContext context,
    AppStrings strings, {
    required bool compact,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              strings.settingsDescription,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (compact) ...[
            const SizedBox(width: AppSpacing.md),
            _compactTrigger(context, strings),
          ],
        ],
      ),
    );
  }

  Widget _compactTrigger(BuildContext context, AppStrings strings) {
    final all = [..._main(strings), ..._appearance(strings)];
    final current =
        all.firstWhere((s) => s.id == _active, orElse: () => all.first);
    return FilledButton.tonalIcon(
      icon: Icon(current.icon, size: 18),
      label: Text(current.label),
      onPressed: () => _openNavSheet(context, strings),
    );
  }

  void _openNavSheet(BuildContext context, AppStrings strings) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: _buildNavList(
            ctx,
            strings,
            onSelected: () => Navigator.of(ctx).pop(),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactBody(BuildContext context, AppStrings strings) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: _buildSectionContent(context, strings),
    );
  }

  Widget _buildWideBody(BuildContext context, AppStrings strings) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 260,
          child: Material(
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: _buildNavList(context, strings),
            ),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: _buildSectionContent(context, strings),
          ),
        ),
      ],
    );
  }

  Widget _buildNavList(
    BuildContext context,
    AppStrings strings, {
    VoidCallback? onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final s in _main(strings))
          _NavItem(
            icon: s.icon,
            label: s.label,
            active: _active == s.id,
            onTap: () {
              _select(s.id);
              onSelected?.call();
            },
          ),
        const SizedBox(height: AppSpacing.md),
        _NavGroup(
          icon: Icons.palette_outlined,
          label: strings.settingsAppearanceCategory,
          expanded: _appearanceOpen,
          onToggle: () =>
              setState(() => _appearanceOpen = !_appearanceOpen),
        ),
        if (_appearanceOpen)
          for (final s in _appearance(strings))
            _NavItem(
              icon: s.icon,
              label: s.label,
              active: _active == s.id,
              indent: true,
              onTap: () {
                _select(s.id);
                onSelected?.call();
              },
            ),
      ],
    );
  }

  Widget _buildSectionContent(BuildContext context, AppStrings strings) {
    switch (_active) {
      case _SecId.appearance:
        return const _AppearanceSection();
      case _SecId.localization:
        return const _LocalizationSection();
      case _SecId.company:
        return _ComingSoonSection(
          title: strings.settingsSectionCompany,
          message: strings.settingsCompanyComingSoon,
          actionLabel: strings.settingsOpenAppearanceNow,
          onAction: () => _select(_SecId.appearance),
        );
      default:
        return _ComingSoonSection(
          title: _currentLabel(strings),
          message: strings.settingsComingSoon,
          actionLabel: strings.settingsOpenAppearanceNow,
          onAction: () => _select(_SecId.appearance),
        );
    }
  }

  String _currentLabel(AppStrings strings) {
    final all = [..._main(strings), ..._appearance(strings)];
    return all
        .firstWhere((s) => s.id == _active, orElse: () => all.first)
        .label;
  }
}

// ─── Navigation widgets ───────────────────────────────────────────
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.indent = false,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final bool indent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: AppSpacing.sm + (indent ? AppSpacing.lg : 0),
        end: AppSpacing.sm,
        bottom: 2,
      ),
      child: Material(
        color: active
            ? theme.colorScheme.primaryContainer
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + 2,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: indent ? 16 : 20,
                  color: active
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: (indent
                            ? theme.textTheme.bodySmall
                            : theme.textTheme.bodyMedium)
                        ?.copyWith(
                      color: active
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurface,
                      fontWeight:
                          active ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavGroup extends StatelessWidget {
  const _NavGroup({
    required this.icon,
    required this.label,
    required this.expanded,
    required this.onToggle,
  });

  final IconData icon;
  final String label;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + 2,
            ),
            child: Row(
              children: [
                Icon(icon, size: 20,
                    color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Content: Appearance ──────────────────────────────────────────
class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context) {
    final service = context.watch<SettingsService>();
    final appearance = service.appearance;
    final locale = service.locale;
    final strings = context.strings;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionCard(
          title: strings.settingsSectionAppearance,
          children: [
            _ThemeModeRow(
              value: appearance.themeMode,
              strings: strings,
              onChanged: service.setThemeMode,
            ),
            const SizedBox(height: AppSpacing.lg),
            _DensityRow(
              value: appearance.density,
              strings: strings,
              onChanged: service.setDensity,
            ),
            const SizedBox(height: AppSpacing.lg),
            _FontScaleRow(
              value: appearance.fontScale,
              digits: locale.digits,
              strings: strings,
              onChanged: service.setFontScale,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.restart_alt),
            label: Text(strings.resetButton),
            onPressed: () => _confirmReset(context, service),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmReset(
    BuildContext context,
    SettingsService service,
  ) async {
    final strings = context.strings;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.resetConfirmTitle),
        content: Text(strings.resetConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(strings.resetCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(strings.resetConfirm),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await service.reset();
    }
  }
}

// ─── Content: Localization ────────────────────────────────────────
class _LocalizationSection extends StatelessWidget {
  const _LocalizationSection();

  @override
  Widget build(BuildContext context) {
    final service = context.watch<SettingsService>();
    final locale = service.locale;
    final strings = context.strings;
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return _SectionCard(
      title: strings.sectionLanguageRegion,
      children: [
        Text(
          strings.sectionLanguageRegionSubtitle,
          style: textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.xl),

        // ── Interface language ───────────────────────────────
        Row(
          children: [
            Icon(
              Icons.language_outlined,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              strings.labelInterfaceLanguage,
              style: textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _LanguagePill(
              label: strings.labelLanguageArabic,
              selected: locale.language == AppLanguage.arabic,
              onTap: () => service.updateLocale(
                locale.copyWith(language: AppLanguage.arabic),
              ),
            ),
            _LanguagePill(
              label: strings.labelLanguageEnglish,
              selected: locale.language == AppLanguage.english,
              onTap: () => service.updateLocale(
                locale.copyWith(language: AppLanguage.english),
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.xl),

        // ── Numerals ─────────────────────────────────────────
        Row(
          children: [
            Icon(
              Icons.numbers,
              size: 18,
              color: theme.colorScheme.tertiary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              strings.labelDigits,
              style: textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(strings.labelDigitsSubtitle, style: textTheme.bodySmall),
        const SizedBox(height: AppSpacing.md),

        LayoutBuilder(
          builder: (context, constraints) {
            final twoCols = constraints.maxWidth >= 480;
            final easternCard = _NumeralCard(
              selected: locale.digits == AppDigits.eastern,
              label: strings.labelDigitsArabic,
              preview: applyDigits('0123456789', AppDigits.eastern),
              example:
                  '${strings.examplePrefix}: ${formatWithDigits(1234.56, AppDigits.eastern)}',
              onTap: () => service.updateLocale(
                locale.copyWith(digits: AppDigits.eastern),
              ),
            );
            final westernCard = _NumeralCard(
              selected: locale.digits == AppDigits.western,
              label: strings.labelDigitsWestern,
              preview: '0123456789',
              example:
                  '${strings.examplePrefix}: ${formatWithDigits(1234.56, AppDigits.western)}',
              onTap: () => service.updateLocale(
                locale.copyWith(digits: AppDigits.western),
              ),
            );
            if (!twoCols) {
              return Column(
                children: [
                  easternCard,
                  const SizedBox(height: AppSpacing.md),
                  westernCard,
                ],
              );
            }
            return IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(child: easternCard), const SizedBox(width: AppSpacing.md), Expanded(child: westernCard)]));
          },
        ),
      ],
    );
  }
}

// ─── Content: Coming soon ─────────────────────────────────────────
class _ComingSoonSection extends StatelessWidget {
  const _ComingSoonSection({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _SectionCard(
      title: title,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.construction_outlined,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(message, style: theme.textTheme.bodyMedium),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilledButton.icon(
            icon: const Icon(Icons.palette_outlined),
            label: Text(actionLabel),
            onPressed: onAction,
          ),
        ),
      ],
    );
  }
}

// ─── Section card + rows (من الملف الحالي بلا تعديل) ──────────────
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.lg),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _LanguagePill extends StatelessWidget {
  const _LanguagePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? theme.colorScheme.primaryContainer
          : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: selected
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _NumeralCard extends StatelessWidget {
  const _NumeralCard({
    required this.selected,
    required this.label,
    required this.preview,
    required this.example,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final String preview;
  final String example;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    return Material(
      color: selected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
          : theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Stack(
            children: [
              if (selected)
                PositionedDirectional(
                  top: 0,
                  start: 0,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check,
                      size: 14,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.language_outlined,
                    size: 32,
                    color: selected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    label,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    preview,
                    textAlign: TextAlign.center,
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      color: selected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    example,
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall?.copyWith(
                      color: selected
                          ? theme.colorScheme.primary.withValues(alpha: 0.8)
                          : theme.colorScheme.onSurfaceVariant,
                    ),
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

class _ThemeModeRow extends StatelessWidget {
  const _ThemeModeRow({
    required this.value,
    required this.strings,
    required this.onChanged,
  });

  final ThemeMode value;
  final AppStrings strings;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(strings.labelThemeMode,
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        SegmentedButton<ThemeMode>(
          segments: [
            ButtonSegment(
              value: ThemeMode.system,
              label: Text(strings.labelThemeSystem),
              icon: const Icon(Icons.brightness_auto_outlined),
            ),
            ButtonSegment(
              value: ThemeMode.light,
              label: Text(strings.labelThemeLight),
              icon: const Icon(Icons.light_mode_outlined),
            ),
            ButtonSegment(
              value: ThemeMode.dark,
              label: Text(strings.labelThemeDark),
              icon: const Icon(Icons.dark_mode_outlined),
            ),
          ],
          selected: {value},
          onSelectionChanged: (s) => onChanged(s.first),
        ),
      ],
    );
  }
}

class _DensityRow extends StatelessWidget {
  const _DensityRow({
    required this.value,
    required this.strings,
    required this.onChanged,
  });

  final AppDensity value;
  final AppStrings strings;
  final ValueChanged<AppDensity> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(strings.labelDensity,
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        SegmentedButton<AppDensity>(
          segments: [
            ButtonSegment(
                value: AppDensity.compact,
                label: Text(strings.labelDensityCompact)),
            ButtonSegment(
                value: AppDensity.comfortable,
                label: Text(strings.labelDensityComfortable)),
            ButtonSegment(
                value: AppDensity.spacious,
                label: Text(strings.labelDensitySpacious)),
          ],
          selected: {value},
          onSelectionChanged: (s) => onChanged(s.first),
        ),
      ],
    );
  }
}

class _FontScaleRow extends StatelessWidget {
  const _FontScaleRow({
    required this.value,
    required this.digits,
    required this.strings,
    required this.onChanged,
  });

  final double value;
  final AppDigits digits;
  final AppStrings strings;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final displayNum = (value * 100).round();
    final displayStr = applyDigits(displayNum.toString(), digits);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(strings.labelFontScale,
                style: Theme.of(context).textTheme.titleSmall),
            Text('$displayStr%',
                style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
        Slider(
          value: value.clamp(0.8, 1.5),
          min: 0.8,
          max: 1.5,
          divisions: 7,
          label: '$displayStr%',
          onChanged: onChanged,
        ),
      ],
    );
  }
}