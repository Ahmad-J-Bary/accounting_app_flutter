import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../theme/app_theme.dart';
import 'settings_model.dart';
import 'settings_service.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<SettingsService>();
    final appearance = service.appearance;
    final locale = service.locale;
    final strings = context.strings;

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.settingsTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          _SectionCard(
            title: strings.sectionLanguageRegion,
            children: [
              Text(
                strings.sectionLanguageRegionSubtitle,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.lg),
              _LanguageRow(
                value: locale.language,
                strings: strings,
                onChanged: (lang) => service.updateLocale(
                  locale.copyWith(language: lang),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _DigitsRow(
                value: locale.digits,
                strings: strings,
                onChanged: (d) => service.updateLocale(
                  locale.copyWith(digits: d),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionCard(
            title: strings.sectionAppearance,
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
      ),
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

class _LanguageRow extends StatelessWidget {
  const _LanguageRow({
    required this.value,
    required this.strings,
    required this.onChanged,
  });

  final AppLanguage value;
  final AppStrings strings;
  final ValueChanged<AppLanguage> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.labelInterfaceLanguage,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        SegmentedButton<AppLanguage>(
          segments: [
            ButtonSegment(
              value: AppLanguage.arabic,
              label: Text(strings.labelLanguageArabic),
            ),
            ButtonSegment(
              value: AppLanguage.english,
              label: Text(strings.labelLanguageEnglish),
            ),
          ],
          selected: {value},
          onSelectionChanged: (s) => onChanged(s.first),
        ),
      ],
    );
  }
}

class _DigitsRow extends StatelessWidget {
  const _DigitsRow({
    required this.value,
    required this.strings,
    required this.onChanged,
  });

  final AppDigits value;
  final AppStrings strings;
  final ValueChanged<AppDigits> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(strings.labelDigits, style: textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(strings.labelDigitsSubtitle, style: textTheme.bodySmall),
        const SizedBox(height: AppSpacing.sm),
        SegmentedButton<AppDigits>(
          segments: [
            ButtonSegment(
              value: AppDigits.eastern,
              label: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(strings.labelDigitsArabic),
                  Text('٠١٢٣٤٥٦٧٨٩', style: textTheme.labelSmall),
                ],
              ),
            ),
            ButtonSegment(
              value: AppDigits.western,
              label: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(strings.labelDigitsWestern),
                  Text('0123456789', style: textTheme.labelSmall),
                ],
              ),
            ),
          ],
          selected: {value},
          onSelectionChanged: (s) => onChanged(s.first),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '${strings.examplePrefix}: ${formatWithDigits(1234.56, value)}',
          style: textTheme.bodySmall,
        ),
      ],
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
        Text(
          strings.labelThemeMode,
          style: Theme.of(context).textTheme.titleSmall,
        ),
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
        Text(
          strings.labelDensity,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        SegmentedButton<AppDensity>(
          segments: [
            ButtonSegment(
              value: AppDensity.compact,
              label: Text(strings.labelDensityCompact),
            ),
            ButtonSegment(
              value: AppDensity.comfortable,
              label: Text(strings.labelDensityComfortable),
            ),
            ButtonSegment(
              value: AppDensity.spacious,
              label: Text(strings.labelDensitySpacious),
            ),
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
            Text(
              strings.labelFontScale,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(
              '$displayStr%',
              style: Theme.of(context).textTheme.labelLarge,
            ),
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