import 'package:flutter/material.dart';

enum AppDensity { compact, comfortable, spacious }
enum AppLanguage { arabic, english }
enum AppDigits { western, eastern }

/// Central defaults and validation sets for the v2 appearance fields.
/// All values are kept as String (not enums) to match the React reference,
/// which uses ThemeId / primaryColor id / UIScale / MotionMode as strings.
class AppearanceDefaults {
  AppearanceDefaults._();

  static const String theme = 'system';
  static const String primaryColor = 'blue';
  static const String uiScale = 'default';
  static const String motion = 'standard';

  static const Set<String> validThemes = {
    'default-light', 'default-dark', 'system',
    'luxury', 'retro', 'arctic', 'nature', 'ember',
    'dracula', 'midnight',
  };

  static const Set<String> validPrimaryColors = {
    'blue', 'red', 'green', 'purple', 'orange', 'gold',
    'pink', 'indigo', 'cyan', 'emerald', 'amber', 'violet',
  };

  static const Set<String> validUiScales = {'small', 'default', 'large'};
  static const Set<String> validMotions = {'none', 'light', 'standard', 'high'};

  static const List<String> showKeys = [
    'sidebar', 'topBar', 'search', 'notifications', 'breadcrumbs', 'tabs',
  ];

  static Map<String, bool> defaultShow() {
    return {for (final k in showKeys) k: true};
  }
}

T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  if (name is! String) return fallback;
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

String _stringInSet(Object? v, Set<String> allowed, String fallback) {
  if (v is String && allowed.contains(v)) return v;
  return fallback;
}

Map<String, bool> _sanitizeShow(Object? v) {
  final defaults = AppearanceDefaults.defaultShow();
  if (v is Map) {
    for (final key in AppearanceDefaults.showKeys) {
      final val = v[key];
      if (val is bool) defaults[key] = val;
    }
  }
  return Map.unmodifiable(defaults);
}

@immutable
class AppearanceSettings {
  final ThemeMode themeMode;
  final AppDensity density;
  final double fontScale;
  // v2 additions — no visual consumer yet; stored for F3-ui-c/F3-ui-b-2.
  final String theme;
  final String primaryColor;
  final String uiScale;
  final String motion;
  final Map<String, bool> show;

  const AppearanceSettings({
    this.themeMode = ThemeMode.system,
    this.density = AppDensity.compact,
    this.fontScale = 1.0,
    this.theme = AppearanceDefaults.theme,
    this.primaryColor = AppearanceDefaults.primaryColor,
    this.uiScale = AppearanceDefaults.uiScale,
    this.motion = AppearanceDefaults.motion,
    this.show = const {
      'sidebar': true,
      'topBar': true,
      'search': true,
      'notifications': true,
      'breadcrumbs': true,
      'tabs': true,
    },
  });

  static const double minFontScale = 0.8;
  static const double maxFontScale = 1.5;

  AppearanceSettings copyWith({
    ThemeMode? themeMode,
    AppDensity? density,
    double? fontScale,
    String? theme,
    String? primaryColor,
    String? uiScale,
    String? motion,
    Map<String, bool>? show,
  }) {
    return AppearanceSettings(
      themeMode: themeMode ?? this.themeMode,
      density: density ?? this.density,
      fontScale: fontScale ?? this.fontScale,
      theme: theme ?? this.theme,
      primaryColor: primaryColor ?? this.primaryColor,
      uiScale: uiScale ?? this.uiScale,
      motion: motion ?? this.motion,
      show: show ?? this.show,
    );
  }

  Map<String, dynamic> toJson() => {
        'themeMode': themeMode.name,
        'density': density.name,
        'fontScale': fontScale,
        'theme': theme,
        'primaryColor': primaryColor,
        'uiScale': uiScale,
        'motion': motion,
        'show': show,
      };

  static AppearanceSettings fromJson(Map<String, dynamic> json) {
    return AppearanceSettings(
      themeMode:
          _enumByName(ThemeMode.values, json['themeMode'], ThemeMode.system),
      density:
          _enumByName(AppDensity.values, json['density'], AppDensity.compact),
      fontScale: clampFontScale((json['fontScale'] as num?)?.toDouble() ?? 1.0),
      theme: _stringInSet(
          json['theme'], AppearanceDefaults.validThemes, AppearanceDefaults.theme),
      primaryColor: _stringInSet(json['primaryColor'],
          AppearanceDefaults.validPrimaryColors, AppearanceDefaults.primaryColor),
      uiScale: _stringInSet(
          json['uiScale'], AppearanceDefaults.validUiScales, AppearanceDefaults.uiScale),
      motion: _stringInSet(
          json['motion'], AppearanceDefaults.validMotions, AppearanceDefaults.motion),
      show: _sanitizeShow(json['show']),
    );
  }

  static AppearanceSettings sanitize(AppearanceSettings s) => AppearanceSettings(
        themeMode: s.themeMode,
        density: s.density,
        fontScale: clampFontScale(s.fontScale),
        theme: AppearanceDefaults.validThemes.contains(s.theme)
            ? s.theme
            : AppearanceDefaults.theme,
        primaryColor: AppearanceDefaults.validPrimaryColors.contains(s.primaryColor)
            ? s.primaryColor
            : AppearanceDefaults.primaryColor,
        uiScale: AppearanceDefaults.validUiScales.contains(s.uiScale)
            ? s.uiScale
            : AppearanceDefaults.uiScale,
        motion: AppearanceDefaults.validMotions.contains(s.motion)
            ? s.motion
            : AppearanceDefaults.motion,
        show: s.show,
      );

  static double clampFontScale(double v) {
    if (v.isNaN || v.isInfinite) return 1.0;
    if (v < minFontScale) return minFontScale;
    if (v > maxFontScale) return maxFontScale;
    return v;
  }

  @override
  bool operator ==(Object other) =>
      other is AppearanceSettings &&
      other.themeMode == themeMode &&
      other.density == density &&
      other.fontScale == fontScale &&
      other.theme == theme &&
      other.primaryColor == primaryColor &&
      other.uiScale == uiScale &&
      other.motion == motion &&
      _mapsEqual(other.show, show);

  @override
  int get hashCode => Object.hash(
        themeMode,
        density,
        fontScale,
        theme,
        primaryColor,
        uiScale,
        motion,
        Object.hashAll(show.entries.map((e) => Object.hash(e.key, e.value))),
      );
}

@immutable
class LocaleSettings {
  final AppLanguage language;
  final AppDigits digits;

  const LocaleSettings({
    this.language = AppLanguage.arabic,
    this.digits = AppDigits.western,
  });

  LocaleSettings copyWith({AppLanguage? language, AppDigits? digits}) {
    return LocaleSettings(
      language: language ?? this.language,
      digits: digits ?? this.digits,
    );
  }

  Map<String, dynamic> toJson() => {
        'language': language.name,
        'digits': digits.name,
      };

  static LocaleSettings fromJson(Map<String, dynamic> json) {
    return LocaleSettings(
      language:
          _enumByName(AppLanguage.values, json['language'], AppLanguage.arabic),
      digits: _enumByName(AppDigits.values, json['digits'], AppDigits.western),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LocaleSettings &&
      other.language == language &&
      other.digits == digits;

  @override
  int get hashCode => Object.hash(language, digits);
}

@immutable
class AppSettings {
  final int schemaVersion;
  final AppearanceSettings appearance;
  final LocaleSettings locale;

  const AppSettings({
    this.schemaVersion = currentSchemaVersion,
    this.appearance = const AppearanceSettings(),
    this.locale = const LocaleSettings(),
  });

  static const int currentSchemaVersion = 2;

  AppSettings copyWith({
    int? schemaVersion,
    AppearanceSettings? appearance,
    LocaleSettings? locale,
  }) {
    return AppSettings(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      appearance: appearance ?? this.appearance,
      locale: locale ?? this.locale,
    );
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'appearance': appearance.toJson(),
        'locale': locale.toJson(),
      };

  /// Parses any supported historical schema (v0, v1) and upgrades it to the
  /// current version. v2-added fields receive their defaults via
  /// `AppearanceSettings.fromJson`. A future schema (version > current) throws
  /// — never silently corrupt.
  static AppSettings fromJson(Map<String, dynamic> json) {
    final version = json['schemaVersion'] as int? ?? 0;
    if (version > currentSchemaVersion) {
      throw StateError(
        'Unsupported settings schema version: $version '
        '(expected <= $currentSchemaVersion)',
      );
    }
    final app = json['appearance'];
    final loc = json['locale'];
    return AppSettings(
      appearance: app is Map
          ? AppearanceSettings.sanitize(
              AppearanceSettings.fromJson(Map<String, dynamic>.from(app)))
          : const AppearanceSettings(),
      locale: loc is Map
          ? LocaleSettings.fromJson(Map<String, dynamic>.from(loc))
          : const LocaleSettings(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.schemaVersion == schemaVersion &&
      other.appearance == appearance &&
      other.locale == locale;

  @override
  int get hashCode => Object.hash(schemaVersion, appearance, locale);
}

bool _mapsEqual(Map<String, bool> a, Map<String, bool> b) {
  if (a.length != b.length) return false;
  for (final key in a.keys) {
    if (!b.containsKey(key) || a[key] != b[key]) return false;
  }
  return true;
}
