import 'package:flutter/material.dart';

enum AppDensity { compact, comfortable, spacious }
enum AppLanguage { arabic, english }
enum AppDigits { western, eastern }

T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  if (name is! String) return fallback;
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

@immutable
class AppearanceSettings {
  final ThemeMode themeMode;
  final AppDensity density;
  final double fontScale;

  const AppearanceSettings({
    this.themeMode = ThemeMode.system,
    this.density = AppDensity.compact,
    this.fontScale = 1.0,
  });

  static const double minFontScale = 0.8;
  static const double maxFontScale = 1.5;

  AppearanceSettings copyWith({
    ThemeMode? themeMode,
    AppDensity? density,
    double? fontScale,
  }) {
    return AppearanceSettings(
      themeMode: themeMode ?? this.themeMode,
      density: density ?? this.density,
      fontScale: fontScale ?? this.fontScale,
    );
  }

  Map<String, dynamic> toJson() => {
        'themeMode': themeMode.name,
        'density': density.name,
        'fontScale': fontScale,
      };

  static AppearanceSettings fromJson(Map<String, dynamic> json) {
    return AppearanceSettings(
      themeMode:
          _enumByName(ThemeMode.values, json['themeMode'], ThemeMode.system),
      density: _enumByName(AppDensity.values, json['density'], AppDensity.compact),
      fontScale: clampFontScale((json['fontScale'] as num?)?.toDouble() ?? 1.0),
    );
  }

  static AppearanceSettings sanitize(AppearanceSettings s) => AppearanceSettings(
        themeMode: s.themeMode,
        density: s.density,
        fontScale: clampFontScale(s.fontScale),
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
      other.fontScale == fontScale;

  @override
  int get hashCode => Object.hash(themeMode, density, fontScale);
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

  static const int currentSchemaVersion = 1;

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

  static AppSettings fromJson(Map<String, dynamic> json) {
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