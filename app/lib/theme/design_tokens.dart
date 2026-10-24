// app/lib/theme/design_tokens.dart
//
// Pure-data design tokens. No Flutter, no material.dart, no dart:ui.
// All values are Dart primitives:
//   - Colors as int (ARGB, 0xAARRGGBB)
//   - Sizes / spacing / radii as double
//   - Font weights as int (hundreds: 400, 500, 600, 700)
//   - Line-height multipliers and letter-spacing as double
//
// Consumer: app_theme.dart maps these primitives to Flutter types
// (Color, TextStyle, FontWeight, VisualDensity, ThemeData).
//
// Design direction: "Modern Fintech" royal-blue seed #2563EB (AD-019).
// This file is the single source of truth for visual values; no other
// file should hard-code hex colors or font sizes.

// ─── Colors ─────────────────────────────────────────────────────
class ColorTokens {
  ColorTokens._();

  // Seed / primary palette
  static const int seed                 = 0xFF2563EB;
  static const int primary              = 0xFF2563EB;
  static const int primaryHover         = 0xFF1D4ED8;
  static const int primaryPressed       = 0xFF1E40AF;
  static const int primaryContainer     = 0xFFDBEAFE;
  static const int onPrimary            = 0xFFFFFFFF;
  static const int onPrimaryContainer   = 0xFF1E3A8A;

  // Secondary accent (light indigo — used sparingly per AD-019)
  static const int secondary            = 0xFF6366F1;
  static const int secondaryContainer   = 0xFFE0E7FF;
  static const int onSecondary          = 0xFFFFFFFF;

  // Surfaces (light theme)
  static const int surface              = 0xFFFFFFFF;
  static const int surfaceVariant       = 0xFFF1F5F9;
  static const int surfaceContainer     = 0xFFF8FAFC;
  static const int background           = 0xFFF8FAFC;
  static const int outline              = 0xFFCBD5E1;
  static const int outlineVariant       = 0xFFE2E8F0;

  // Text (light theme)
  static const int textPrimary          = 0xFF0F172A;
  static const int textSecondary        = 0xFF475569;
  static const int textDisabled         = 0xFF94A3B8;
  static const int onSurface            = 0xFF0F172A;
  static const int onSurfaceVariant     = 0xFF475569;

  // Status colors
  static const int success              = 0xFF16A34A;
  static const int successContainer     = 0xFFDCFCE7;
  static const int warning              = 0xFFF59E0B;
  static const int warningContainer     = 0xFFFEF3C7;
  static const int info                 = 0xFF0EA5E9;
  static const int infoContainer        = 0xFFE0F2FE;
  static const int error                = 0xFFDC2626;
  static const int errorContainer       = 0xFFFEE2E2;
  static const int onError              = 0xFFFFFFFF;

  // Sidebar (light theme — dark navy)
  static const int sidebarBackground    = 0xFF0F172A;
  static const int sidebarForeground    = 0xFFF1F5F9;
  static const int sidebarMuted         = 0xFF94A3B8;
  static const int sidebarAccent        = 0xFF2563EB;
  static const int sidebarBorder        = 0xFF1E293B;

  // Overlays
  static const int overlay              = 0x7A000000;
  static const int scrim                = 0x52000000;

  // Dark theme surfaces
  static const int darkSurface          = 0xFF0F172A;
  static const int darkSurfaceVariant   = 0xFF1E293B;
  static const int darkSurfaceContainer = 0xFF1E293B;
  static const int darkBackground       = 0xFF0B1220;
  static const int darkOutline          = 0xFF334155;
  static const int darkOutlineVariant   = 0xFF1E293B;

  // Dark theme text
  static const int darkTextPrimary      = 0xFFF1F5F9;
  static const int darkTextSecondary    = 0xFF94A3B8;
  static const int darkTextDisabled     = 0xFF64748B;
  static const int darkOnSurface        = 0xFFF1F5F9;
  static const int darkOnSurfaceVariant = 0xFF94A3B8;

  // Dark sidebar
  static const int darkSidebarBackground = 0xFF020617;
  static const int darkSidebarForeground = 0xFFF1F5F9;
  static const int darkSidebarMuted      = 0xFF64748B;
  static const int darkSidebarAccent     = 0xFF3B82F6;
  static const int darkSidebarBorder     = 0xFF1E293B;

  // Primary CTA gradient (light indigo accent per AD-019)
  static const int gradientStart        = 0xFF2563EB;
  static const int gradientEnd          = 0xFF6366F1;
}

// ─── Typography ─────────────────────────────────────────────────
class TypographyTokens {
  TypographyTokens._();

  static const String fontFamily = 'IBM Plex Sans Arabic';
  static const List<String> fontFamilyFallback = <String>[
    'Cairo',
    'Tajawal',
    'Segoe UI',
    'Arial',
  ];

  // Font sizes (logical pixels)
  static const double displayLarge    = 32.0;
  static const double displayMedium   = 28.0;
  static const double displaySmall    = 24.0;
  static const double headlineLarge   = 22.0;
  static const double headlineMedium  = 20.0;
  static const double headlineSmall   = 18.0;
  static const double titleLarge      = 18.0;
  static const double titleMedium     = 16.0;
  static const double titleSmall      = 14.0;
  static const double bodyLarge       = 16.0;
  static const double bodyMedium      = 14.0;
  static const double bodySmall       = 12.0;
  static const double labelLarge      = 14.0;
  static const double labelMedium     = 12.0;
  static const double labelSmall      = 11.0;

  // Font weights (hundreds)
  static const int weightRegular  = 400;
  static const int weightMedium   = 500;
  static const int weightSemiBold = 600;
  static const int weightBold     = 700;

  // Line-height multipliers (applied to fontSize)
  static const double displayHeight  = 1.2;
  static const double headlineHeight = 1.3;
  static const double titleHeight    = 1.4;
  static const double bodyHeight     = 1.6;
  static const double labelHeight    = 1.4;

  // Letter spacing
  static const double tightSpacing  = -0.2;
  static const double normalSpacing = 0.0;
  static const double looseSpacing  = 0.3;
}

// ─── Spacing ────────────────────────────────────────────────────
class SpacingTokens {
  SpacingTokens._();
  static const double xs   = 4.0;
  static const double sm   = 8.0;
  static const double md   = 12.0;
  static const double lg   = 16.0;
  static const double xl   = 24.0;
  static const double xxl  = 32.0;
  static const double xxxl = 48.0;
}

// ─── Radius ─────────────────────────────────────────────────────
class RadiusTokens {
  RadiusTokens._();
  static const double xs   = 4.0;
  static const double sm   = 6.0;
  static const double md   = 8.0;
  static const double lg   = 12.0;
  static const double xl   = 16.0;
  static const double xxl  = 24.0;
  static const double pill = 999.0;
}

// ─── Density ────────────────────────────────────────────────────
// Numeric only. app_theme.dart maps these to VisualDensity and row heights.
class DensityTokens {
  DensityTokens._();

  // compact
  static const double compactVertical       = -2.0;
  static const double compactHorizontal     = -2.0;
  static const double compactRowHeight      = 36.0;

  // comfortable
  static const double comfortableVertical   = 0.0;
  static const double comfortableHorizontal = 0.0;
  static const double comfortableRowHeight  = 44.0;

  // spacious
  static const double spaciousVertical      = 2.0;
  static const double spaciousHorizontal    = 2.0;
  static const double spaciousRowHeight     = 52.0;
}