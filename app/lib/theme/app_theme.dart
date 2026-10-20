import 'package:flutter/material.dart';

/// Design tokens mirrored from the React desktop workspace.
///
/// The React app stores its palette as HSL custom properties in
/// `apps/desktop/src/index.css`; the values below are the RGB equivalents so
/// Flutter and the web app stay visually aligned.
abstract final class AppColors {
  static const Color background = Color(0xFFF8FAFC);
  static const Color foreground = Color(0xFF0F172A);
  static const Color card = Color(0xFFFFFFFF);
  static const Color primary = Color(0xFF1F3A61);
  static const Color primaryForeground = Color(0xFFF8FAFC);
  static const Color secondary = Color(0xFFF1F5F9);
  static const Color secondaryForeground = Color(0xFF0F172A);
  static const Color muted = Color(0xFFF1F5F9);
  static const Color mutedForeground = Color(0xFF64748B);
  static const Color accent = Color(0xFFE9EEF5);
  static const Color accentForeground = Color(0xFF0F172A);
  static const Color destructive = Color(0xFFDC2626);
  static const Color destructiveForeground = Color(0xFFFFFFFF);
  static const Color success = Color(0xFF1B9E6B);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);
  static const Color border = Color(0xFFE2E8F0);
  static const Color input = Color(0xFFE2E8F0);
  static const Color ring = Color(0xFF1F3A61);

  static const Color sidebarBackground = Color(0xFF0B2442);
  static const Color sidebarForeground = Color(0xFFF1F5F9);
  static const Color sidebarMuted = Color(0xFFA8B8CC);
  static const Color sidebarAccent = Color(0xFF26405A);
  static const Color sidebarBorder = Color(0xFF32465A);

  static const Color darkBackground = Color(0xFF0B1220);
  static const Color darkCard = Color(0xFF0F172A);
  static const Color darkForeground = Color(0xFFF1F5F9);
  static const Color darkMuted = Color(0xFF1E293B);
  static const Color darkMutedForeground = Color(0xFF94A3B8);
  static const Color darkBorder = Color(0xFF263449);
  static const Color darkPrimary = Color(0xFF5B7FA8);
  static const Color darkSidebarBackground = Color(0xFF070D18);
}

abstract final class AppRadius {
  static const double sm = 6;
  static const double md = 8;
  static const double lg = 12;
  static const double xl = 16;
  static const double xxl = 24;
  static const double pill = 999;
}

abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.success,
    required this.warning,
    required this.info,
    required this.sidebarBackground,
    required this.sidebarForeground,
    required this.sidebarMuted,
    required this.sidebarAccent,
    required this.sidebarBorder,
    required this.overlay,
  });

  final Color success;
  final Color warning;
  final Color info;
  final Color sidebarBackground;
  final Color sidebarForeground;
  final Color sidebarMuted;
  final Color sidebarAccent;
  final Color sidebarBorder;
  final Color overlay;

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? warning,
    Color? info,
    Color? sidebarBackground,
    Color? sidebarForeground,
    Color? sidebarMuted,
    Color? sidebarAccent,
    Color? sidebarBorder,
    Color? overlay,
  }) {
    return AppSemanticColors(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      info: info ?? this.info,
      sidebarBackground: sidebarBackground ?? this.sidebarBackground,
      sidebarForeground: sidebarForeground ?? this.sidebarForeground,
      sidebarMuted: sidebarMuted ?? this.sidebarMuted,
      sidebarAccent: sidebarAccent ?? this.sidebarAccent,
      sidebarBorder: sidebarBorder ?? this.sidebarBorder,
      overlay: overlay ?? this.overlay,
    );
  }

  @override
  AppSemanticColors lerp(AppSemanticColors? other, double t) {
    if (other is! AppSemanticColors) {
      return this;
    }
    return AppSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      info: Color.lerp(info, other.info, t)!,
      sidebarBackground: Color.lerp(
        sidebarBackground,
        other.sidebarBackground,
        t,
      )!,
      sidebarForeground: Color.lerp(
        sidebarForeground,
        other.sidebarForeground,
        t,
      )!,
      sidebarMuted: Color.lerp(sidebarMuted, other.sidebarMuted, t)!,
      sidebarAccent: Color.lerp(sidebarAccent, other.sidebarAccent, t)!,
      sidebarBorder: Color.lerp(sidebarBorder, other.sidebarBorder, t)!,
      overlay: Color.lerp(overlay, other.overlay, t)!,
    );
  }
}

abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final foreground = isDark ? AppColors.darkForeground : AppColors.foreground;
    final mutedForeground = isDark
        ? AppColors.darkMutedForeground
        : AppColors.mutedForeground;
    final background = isDark ? AppColors.darkBackground : AppColors.background;
    final card = isDark ? AppColors.darkCard : AppColors.card;
    final border = isDark ? AppColors.darkBorder : AppColors.border;
    final primary = isDark ? AppColors.darkPrimary : AppColors.primary;
    final onPrimary = isDark
        ? AppColors.darkBackground
        : AppColors.primaryForeground;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: isDark
          ? const Color(0xFF243B57)
          : const Color(0xFFDCE7F5),
      onPrimaryContainer: isDark ? AppColors.darkForeground : AppColors.primary,
      secondary: isDark ? AppColors.darkMuted : AppColors.secondary,
      onSecondary: foreground,
      secondaryContainer: isDark
          ? const Color(0xFF243044)
          : const Color(0xFFE9EEF5),
      onSecondaryContainer: foreground,
      tertiary: isDark ? const Color(0xFFD7A85B) : AppColors.warning,
      onTertiary: isDark ? AppColors.darkBackground : Colors.white,
      error: isDark ? const Color(0xFFF87171) : AppColors.destructive,
      onError: isDark ? AppColors.darkBackground : Colors.white,
      surface: card,
      onSurface: foreground,
      surfaceContainerHighest: isDark ? AppColors.darkMuted : AppColors.muted,
      onSurfaceVariant: mutedForeground,
      outline: border,
      outlineVariant: border,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: foreground,
      onInverseSurface: card,
      inversePrimary: isDark ? AppColors.primary : const Color(0xFFA8BEDC),
      surfaceTint: Colors.transparent,
    );

    final baseText =
        Typography.material2021(
          platform: TargetPlatform.android,
          colorScheme: colorScheme,
        ).black.apply(
          bodyColor: foreground,
          displayColor: foreground,
          fontFamily: 'Cairo',
          fontFamilyFallback: const ['Tajawal', 'Segoe UI', 'Arial'],
        );

    final textTheme = baseText.copyWith(
      displayLarge: baseText.displayLarge?.copyWith(
        fontSize: 34,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
        height: 1.2,
      ),
      displayMedium: baseText.displayMedium?.copyWith(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
        height: 1.2,
      ),
      displaySmall: baseText.displaySmall?.copyWith(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        height: 1.25,
      ),
      headlineLarge: baseText.headlineLarge?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        height: 1.3,
      ),
      headlineMedium: baseText.headlineMedium?.copyWith(
        fontSize: 21,
        fontWeight: FontWeight.w800,
        height: 1.3,
      ),
      headlineSmall: baseText.headlineSmall?.copyWith(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        height: 1.35,
      ),
      titleLarge: baseText.titleLarge?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        height: 1.35,
      ),
      titleMedium: baseText.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        height: 1.4,
      ),
      titleSmall: baseText.titleSmall?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        height: 1.4,
      ),
      bodyLarge: baseText.bodyLarge?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.55,
      ),
      bodyMedium: baseText.bodyMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.55,
      ),
      bodySmall: baseText.bodySmall?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.5,
        color: mutedForeground,
      ),
      labelLarge: baseText.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      labelMedium: baseText.labelMedium?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      labelSmall: baseText.labelSmall?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
    );

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md + 2),
      borderSide: BorderSide(color: border),
    );

    final semantic = AppSemanticColors(
      success: AppColors.success,
      warning: AppColors.warning,
      info: AppColors.info,
      sidebarBackground: isDark
          ? AppColors.darkSidebarBackground
          : AppColors.sidebarBackground,
      sidebarForeground: AppColors.sidebarForeground,
      sidebarMuted: AppColors.sidebarMuted,
      sidebarAccent: AppColors.sidebarAccent,
      sidebarBorder: AppColors.sidebarBorder,
      overlay: Colors.black.withValues(alpha: 0.48),
    );

    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      fontFamily: 'Cairo',
      fontFamilyFallback: const ['Tajawal', 'Segoe UI', 'Arial'],
      textTheme: textTheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      cardColor: card,
      dividerColor: border,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      disabledColor: mutedForeground.withValues(alpha: 0.55),
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      extensions: <ThemeExtension<dynamic>>[semantic],
      appBarTheme: AppBarTheme(
        backgroundColor: card,
        foregroundColor: foreground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleMedium?.copyWith(color: foreground),
        iconTheme: IconThemeData(color: mutedForeground, size: 20),
        actionsIconTheme: IconThemeData(color: mutedForeground, size: 20),
      ),
      cardTheme: CardThemeData(
        color: card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          side: BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: background,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 13,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: mutedForeground),
        labelStyle: textTheme.bodyMedium?.copyWith(color: mutedForeground),
        floatingLabelStyle: textTheme.labelMedium?.copyWith(color: primary),
        border: inputBorder,
        enabledBorder: inputBorder,
        disabledBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: border.withValues(alpha: 0.6)),
        ),
        focusedBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: primary, width: 1.6),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: colorScheme.error, width: 1.6),
        ),
        prefixIconColor: mutedForeground,
        suffixIconColor: mutedForeground,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          shape: WidgetStatePropertyAll(buttonShape),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return primary.withValues(alpha: 0.45);
            }
            if (states.contains(WidgetState.hovered)) {
              return primary.withValues(alpha: 0.9);
            }
            return primary;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return onPrimary.withValues(alpha: 0.75);
            }
            return onPrimary;
          }),
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
          elevation: const WidgetStatePropertyAll(0),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          shape: WidgetStatePropertyAll(buttonShape),
          side: WidgetStatePropertyAll(BorderSide(color: border)),
          foregroundColor: WidgetStatePropertyAll(foreground),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered)) {
              return isDark ? AppColors.darkMuted : AppColors.accent;
            }
            return card;
          }),
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 36)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
          foregroundColor: WidgetStatePropertyAll(primary),
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm + 2),
            ),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered)) {
              return foreground;
            }
            return mutedForeground;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered)) {
              return isDark ? AppColors.darkMuted : AppColors.accent;
            }
            return Colors.transparent;
          }),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
        ),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      tabBarTheme: TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: mutedForeground,
        indicatorColor: primary,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: border,
        labelStyle: textTheme.labelLarge,
        unselectedLabelStyle: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        elevation: 18,
        shadowColor: Colors.black.withValues(alpha: 0.16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          side: BorderSide(color: border),
        ),
        titleTextStyle: textTheme.titleLarge?.copyWith(color: foreground),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: mutedForeground,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: card,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        textStyle: textTheme.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: border),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? AppColors.darkMuted : AppColors.foreground,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        actionTextColor: isDark ? primary : const Color(0xFF9EC1EA),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        insetPadding: const EdgeInsets.all(AppSpacing.lg),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkMuted : AppColors.foreground,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        textStyle: textTheme.labelSmall?.copyWith(color: Colors.white),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        waitDuration: const Duration(milliseconds: 450),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: mutedForeground,
        textColor: foreground,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(
          isDark ? AppColors.darkMuted : AppColors.muted.withValues(alpha: 0.7),
        ),
        headingTextStyle: textTheme.labelMedium?.copyWith(
          color: mutedForeground,
          fontWeight: FontWeight.w700,
        ),
        dataTextStyle: textTheme.bodyMedium?.copyWith(color: foreground),
        dividerThickness: 1,
        horizontalMargin: 16,
        columnSpacing: 24,
        dataRowMinHeight: 48,
        dataRowMaxHeight: 64,
        headingRowHeight: 44,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? AppColors.darkMuted : AppColors.muted,
        selectedColor: primary.withValues(alpha: 0.12),
        disabledColor: border,
        labelStyle: textTheme.labelMedium?.copyWith(color: foreground),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(color: primary),
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return onPrimary;
          }
          return mutedForeground;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primary;
          }
          return border;
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: border,
        circularTrackColor: border,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(
          mutedForeground.withValues(alpha: 0.32),
        ),
        thickness: const WidgetStatePropertyAll(7),
        radius: const Radius.circular(AppRadius.pill),
        interactive: true,
      ),
      navigationDrawerTheme: NavigationDrawerThemeData(
        backgroundColor: semantic.sidebarBackground,
        surfaceTintColor: Colors.transparent,
        indicatorColor: semantic.sidebarAccent,
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelLarge?.copyWith(color: semantic.sidebarForeground),
        ),
        iconTheme: WidgetStatePropertyAll(
          IconThemeData(color: semantic.sidebarMuted),
        ),
      ),
    );
  }
}

extension AppThemeContext on BuildContext {
  AppSemanticColors get semanticColors =>
      Theme.of(this).extension<AppSemanticColors>() ??
      const AppSemanticColors(
        success: AppColors.success,
        warning: AppColors.warning,
        info: AppColors.info,
        sidebarBackground: AppColors.sidebarBackground,
        sidebarForeground: AppColors.sidebarForeground,
        sidebarMuted: AppColors.sidebarMuted,
        sidebarAccent: AppColors.sidebarAccent,
        sidebarBorder: AppColors.sidebarBorder,
        overlay: Color(0x7A000000),
      );

  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

class AppThemeController extends ChangeNotifier {
  AppThemeController({ThemeMode initialMode = ThemeMode.light})
    : _mode = initialMode;

  ThemeMode _mode;

  ThemeMode get mode => _mode;

  bool get isDark => _mode == ThemeMode.dark;

  void toggle() {
    _mode = _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  void setMode(ThemeMode mode) {
    if (_mode == mode) {
      return;
    }
    _mode = mode;
    notifyListeners();
  }
}

class AppThemeScope extends InheritedNotifier<AppThemeController> {
  const AppThemeScope({
    super.key,
    required AppThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppThemeController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppThemeScope>();
    assert(scope != null, 'AppThemeScope is missing above this context');
    return scope!.notifier!;
  }
}
