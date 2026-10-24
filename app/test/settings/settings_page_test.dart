import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:accounting_app_flutter/settings/settings_model.dart';
import 'package:accounting_app_flutter/settings/settings_page.dart';
import 'package:accounting_app_flutter/settings/settings_service.dart';
import 'package:accounting_app_flutter/settings/settings_store.dart';

Widget _wrap(SettingsService service, WidgetTester tester) {
  // Settings page exceeds 800x600 after the Language & Region section.
  // Use a realistic desktop viewport for all settings tests.
  tester.view.physicalSize = const Size(1440, 1024);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  return ChangeNotifierProvider<SettingsService>.value(
    value: service,
    child: MaterialApp(
      home: const SettingsPage(),
      builder: (context, child) {
        final isRtl = service.locale.language == AppLanguage.arabic;
        return Directionality(
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: child ?? const SizedBox.shrink(),
        );
      },
    ),
  );
}

void main() {
  group('SettingsPage', () {
    testWidgets('renders both language section and appearance section',
        (tester) async {
      final service = SettingsService(InMemorySettingsStore());
      await service.load();
      await tester.pumpWidget(_wrap(service, tester));
      await tester.pumpAndSettle();

      expect(find.text('اللغة والمنطقة'), findsOneWidget);
      expect(find.text('المظهر'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(find.text('أرقام عربية'), findsOneWidget);
      expect(find.text('أرقام أجنبية'), findsOneWidget);
    });

    testWidgets('language switch flips Directionality to LTR', (tester) async {
      final service = SettingsService(InMemorySettingsStore());
      await service.load();
      await tester.pumpWidget(_wrap(service, tester));
      await tester.pumpAndSettle();

      expect(service.locale.language, AppLanguage.arabic);
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      expect(service.locale.language, AppLanguage.english);

      final dir = tester.widget<Directionality>(
        find.byType(Directionality).first,
      );
      expect(dir.textDirection, TextDirection.ltr);
    });

    testWidgets('digits toggle updates locale', (tester) async {
      final service = SettingsService(InMemorySettingsStore());
      await service.load();
      await tester.pumpWidget(_wrap(service, tester));
      await tester.pumpAndSettle();

      expect(service.locale.digits, AppDigits.western);
      await tester.tap(find.text('أرقام عربية'));
      await tester.pumpAndSettle();
      expect(service.locale.digits, AppDigits.eastern);
    });

    testWidgets('digits preview shows the chosen format', (tester) async {
      final service = SettingsService(InMemorySettingsStore(
        const AppSettings(
          locale: LocaleSettings(digits: AppDigits.eastern),
        ),
      ));
      await service.load();
      await tester.pumpWidget(_wrap(service, tester));
      await tester.pumpAndSettle();

      expect(find.textContaining('١,٢٣٤.٥٦'), findsOneWidget);
    });

    testWidgets('theme mode tap updates service', (tester) async {
      final service = SettingsService(InMemorySettingsStore());
      await service.load();
      await tester.pumpWidget(_wrap(service, tester));
      await tester.pumpAndSettle();

      await tester.tap(find.text('داكن'));
      await tester.pumpAndSettle();
      expect(service.appearance.themeMode, ThemeMode.dark);
    });

    testWidgets('font slider increases fontScale (RTL drag left)',
        (tester) async {
      final service = SettingsService(InMemorySettingsStore());
      await service.load();
      await tester.pumpWidget(_wrap(service, tester));
      await tester.pumpAndSettle();

      final slider = find.byType(Slider);
      await tester.ensureVisible(slider);
      await tester.pumpAndSettle();

      // RTL: dragging left raises the value; right lowers it.
      await tester.drag(slider, const Offset(-400, 0));
      await tester.pumpAndSettle();

      expect(service.appearance.fontScale, greaterThan(1.0));
    });

    testWidgets('reset confirms then reverts to defaults', (tester) async {
      final service = SettingsService(InMemorySettingsStore(
        const AppSettings(
          appearance: AppearanceSettings(themeMode: ThemeMode.dark),
        ),
      ));
      await service.load();
      await tester.pumpWidget(_wrap(service, tester));
      await tester.pumpAndSettle();

      final resetBtn = find.text('إعادة ضبط الإعدادات');
      await tester.ensureVisible(resetBtn);
      await tester.pumpAndSettle();
      await tester.tap(resetBtn);
      await tester.pumpAndSettle();

      await tester.tap(find.text('إعادة الضبط'));
      await tester.pumpAndSettle();
      expect(service.appearance.themeMode, ThemeMode.system);
    });

    testWidgets('reset cancel leaves settings untouched', (tester) async {
      final service = SettingsService(InMemorySettingsStore(
        const AppSettings(
          appearance: AppearanceSettings(themeMode: ThemeMode.dark),
        ),
      ));
      await service.load();
      await tester.pumpWidget(_wrap(service, tester));
      await tester.pumpAndSettle();

      final resetBtn = find.text('إعادة ضبط الإعدادات');
      await tester.ensureVisible(resetBtn);
      await tester.pumpAndSettle();
      await tester.tap(resetBtn);
      await tester.pumpAndSettle();

      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      expect(service.appearance.themeMode, ThemeMode.dark);
    });
  });
}