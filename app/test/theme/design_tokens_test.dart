import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:accounting_app_flutter/theme/app_theme.dart';
import 'package:accounting_app_flutter/theme/design_tokens.dart';

void main() {
  group('ColorTokens', () {
    test('primary is the approved royal blue seed', () {
      expect(ColorTokens.primary, 0xFF2563EB);
      expect(ColorTokens.seed, ColorTokens.primary);
    });

    test('every color token has non-zero alpha', () {
      const colors = <int>[
        ColorTokens.primary, ColorTokens.onPrimary,
        ColorTokens.surface, ColorTokens.background,
        ColorTokens.textPrimary, ColorTokens.textSecondary,
        ColorTokens.sidebarBackground, ColorTokens.sidebarForeground,
        ColorTokens.sidebarAccent, ColorTokens.error, ColorTokens.success,
        ColorTokens.warning, ColorTokens.info,
        ColorTokens.darkBackground, ColorTokens.darkSurface,
        ColorTokens.darkTextPrimary, ColorTokens.darkSidebarBackground,
      ];
      for (final c in colors) {
        expect((c >> 24) & 0xFF, greaterThan(0),
            reason: '0x${c.toRadixString(16)} has zero alpha');
      }
    });

    test('text and surface are distinct', () {
      expect(ColorTokens.textPrimary, isNot(ColorTokens.surface));
      expect(ColorTokens.onPrimary, isNot(ColorTokens.primary));
    });
  });

  group('TypographyTokens', () {
    test('primary font is IBM Plex Sans Arabic', () {
      expect(TypographyTokens.fontFamily, 'IBM Plex Sans Arabic');
    });

    test('fallback chain keeps Cairo', () {
      expect(TypographyTokens.fontFamilyFallback, contains('Cairo'));
    });

    test('font weights stay in the 400-700 band', () {
      for (final w in [
        TypographyTokens.weightRegular,
        TypographyTokens.weightMedium,
        TypographyTokens.weightSemiBold,
        TypographyTokens.weightBold,
      ]) {
        expect(w, inInclusiveRange(400, 700));
      }
    });
  });

  group('SpacingTokens', () {
    test('scale is strictly increasing', () {
      final s = [
        SpacingTokens.xs, SpacingTokens.sm, SpacingTokens.md,
        SpacingTokens.lg, SpacingTokens.xl, SpacingTokens.xxl,
        SpacingTokens.xxxl,
      ];
      for (var i = 1; i < s.length; i++) {
        expect(s[i], greaterThan(s[i - 1]));
      }
    });
  });

  group('RadiusTokens', () {
    test('scale is strictly increasing up to pill', () {
      final r = [
        RadiusTokens.xs, RadiusTokens.sm, RadiusTokens.md,
        RadiusTokens.lg, RadiusTokens.xl, RadiusTokens.xxl,
      ];
      for (var i = 1; i < r.length; i++) {
        expect(r[i], greaterThan(r[i - 1]));
      }
      expect(RadiusTokens.pill, greaterThanOrEqualTo(RadiusTokens.xxl));
    });
  });

  group('DensityTokens', () {
    test('compact < comfortable < spacious (vertical)', () {
      expect(DensityTokens.compactVertical,
          lessThan(DensityTokens.comfortableVertical));
      expect(DensityTokens.comfortableVertical,
          lessThan(DensityTokens.spaciousVertical));
    });

    test('row heights grow with density', () {
      expect(DensityTokens.compactRowHeight,
          lessThan(DensityTokens.comfortableRowHeight));
      expect(DensityTokens.comfortableRowHeight,
          lessThan(DensityTokens.spaciousRowHeight));
    });
  });

  group('AppColors wiring', () {
    test('primary references the token', () {
      expect(AppColors.primary, const Color(ColorTokens.primary));
    });

    test('sidebar accent references the token', () {
      expect(AppColors.sidebarAccent, const Color(ColorTokens.sidebarAccent));
    });

    test('AppRadius values match RadiusTokens', () {
      expect(AppRadius.sm, RadiusTokens.sm);
      expect(AppRadius.md, RadiusTokens.md);
      expect(AppRadius.lg, RadiusTokens.lg);
      expect(AppRadius.xl, RadiusTokens.xl);
      expect(AppRadius.xxl, RadiusTokens.xxl);
      expect(AppRadius.pill, RadiusTokens.pill);
    });

    test('AppSpacing values match SpacingTokens', () {
      expect(AppSpacing.xs, SpacingTokens.xs);
      expect(AppSpacing.sm, SpacingTokens.sm);
      expect(AppSpacing.md, SpacingTokens.md);
      expect(AppSpacing.lg, SpacingTokens.lg);
      expect(AppSpacing.xl, SpacingTokens.xl);
      expect(AppSpacing.xxl, SpacingTokens.xxl);
    });
  });

  group('AppTheme wiring', () {
    test('light theme bodyMedium uses IBM Plex Sans Arabic', () {
      expect(AppTheme.light().textTheme.bodyMedium?.fontFamily,
          'IBM Plex Sans Arabic');
    });

    test('dark theme bodyMedium uses IBM Plex Sans Arabic', () {
      expect(AppTheme.dark().textTheme.bodyMedium?.fontFamily,
          'IBM Plex Sans Arabic');
    });

    test('light theme primary matches AppColors.primary', () {
      expect(AppTheme.light().colorScheme.primary, AppColors.primary);
    });

    test('dark theme primary matches AppColors.darkPrimary', () {
      expect(AppTheme.dark().colorScheme.primary, AppColors.darkPrimary);
    });

    test('light theme exposes AppSemanticColors extension', () {
      final ext = AppTheme.light().extension<AppSemanticColors>();
      expect(ext, isNotNull);
      expect(ext!.sidebarBackground, AppColors.sidebarBackground);
    });
  });
}