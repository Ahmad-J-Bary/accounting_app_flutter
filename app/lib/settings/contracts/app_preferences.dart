import 'package:flutter/foundation.dart';

enum AppThemeMode { system, light, dark }
enum AppDensity { compact, comfortable, spacious }
enum AppLanguage { arabic, english }

@immutable
class AppPreferences {
  final AppThemeMode themeMode;
  final AppDensity density;
  final AppLanguage language;
  final double fontScale;
  final bool reduceMotion;

  const AppPreferences({
    this.themeMode = AppThemeMode.system,
    this.density = AppDensity.compact,
    this.language = AppLanguage.arabic,
    this.fontScale = 1.0,
    this.reduceMotion = false,
  });

  AppPreferences copyWith({
    AppThemeMode? themeMode,
    AppDensity? density,
    AppLanguage? language,
    double? fontScale,
    bool? reduceMotion,
  }) {
    return AppPreferences(
      themeMode: themeMode ?? this.themeMode,
      density: density ?? this.density,
      language: language ?? this.language,
      fontScale: fontScale ?? this.fontScale,
      reduceMotion: reduceMotion ?? this.reduceMotion,
    );
  }

  Map<String, dynamic> toJson() => {
        'themeMode': themeMode.name,
        'density': density.name,
        'language': language.name,
        'fontScale': fontScale,
        'reduceMotion': reduceMotion,
      };

  static AppPreferences fromJson(Map<String, dynamic> json) {
    return AppPreferences(
      themeMode: _enumByName(AppThemeMode.values, json['themeMode'], AppThemeMode.system),
      density: _enumByName(AppDensity.values, json['density'], AppDensity.comfortable),
      language: _enumByName(AppLanguage.values, json['language'], AppLanguage.arabic),
      fontScale: (json['fontScale'] as num?)?.toDouble() ?? 1.0,
      reduceMotion: json['reduceMotion'] as bool? ?? false,
    );
  }

  static T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
    if (name is! String) return fallback;
    for (final v in values) {
      if (v.name == name) return v;
    }
    return fallback;
  }

  @override
  bool operator ==(Object other) =>
      other is AppPreferences &&
      other.themeMode == themeMode &&
      other.density == density &&
      other.language == language &&
      other.fontScale == fontScale &&
      other.reduceMotion == reduceMotion;

  @override
  int get hashCode => Object.hash(themeMode, density, language, fontScale, reduceMotion);

  @override
  String toString() =>
      'AppPreferences(themeMode: $themeMode, density: $density, language: $language, fontScale: $fontScale, reduceMotion: $reduceMotion)';
}