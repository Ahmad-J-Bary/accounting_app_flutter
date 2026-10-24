import 'package:flutter_test/flutter_test.dart';

import 'package:accounting_app_flutter/l10n/l10n.dart';
import 'package:accounting_app_flutter/settings/settings_model.dart';

void main() {
  group('AppStrings', () {
    for (final language in AppLanguage.values) {
      final s = language.strings;
      test('${language.name}: no empty string getters', () {
        final values = <String>[
          s.appName, s.appTitle, s.bootstrapLoading, s.errorOpenDatabase,
          s.navDashboard, s.navJournal, s.navSalesInvoices,
          s.navPurchaseInvoices, s.navSalesReturns, s.navPurchaseReturns,
          s.navReceipts, s.navPayments, s.navExpenses,
          s.navCustomers, s.navSuppliers, s.navMaterials,
          s.settingsTitle, s.sectionLanguageRegion,
          s.sectionLanguageRegionSubtitle, s.labelInterfaceLanguage,
          s.labelLanguageArabic, s.labelLanguageEnglish,
          s.labelDigits, s.labelDigitsSubtitle,
          s.labelDigitsArabic, s.labelDigitsWestern, s.examplePrefix,
          s.sectionAppearance, s.labelThemeMode,
          s.labelThemeSystem, s.labelThemeLight, s.labelThemeDark,
          s.labelDensity, s.labelDensityCompact,
          s.labelDensityComfortable, s.labelDensitySpacious,
          s.labelFontScale, s.resetButton, s.resetConfirmTitle,
          s.resetConfirmBody, s.resetCancel, s.resetConfirm, s.loading,
        ];
        for (final v in values) {
          expect(v, isNotEmpty);
        }
      });
    }

    test('Arabic nav labels differ from English', () {
      const ar = ArStrings();
      const en = EnStrings();
      expect(ar.navCustomers, isNot(en.navCustomers));
      expect(ar.navDashboard, isNot(en.navDashboard));
    });

    test('English label for Arabic is localized', () {
      const en = EnStrings();
      expect(en.labelLanguageArabic, 'العربية');
    });
  });
}