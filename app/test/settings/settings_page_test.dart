import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:accounting_app_flutter/settings/settings_model.dart';
import 'package:accounting_app_flutter/settings/settings_page.dart';
import 'package:accounting_app_flutter/settings/settings_service.dart';
import 'package:accounting_app_flutter/settings/settings_store.dart';

Widget _wrap(SettingsService service) {
  return ChangeNotifierProvider<SettingsService>.value(
    value: service,
    child: MaterialApp(
      home: const SettingsPage(),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
    ),
  );
}

void main() {
  group('SettingsPage', () {
    testWidgets('renders all three appearance controls', (tester) async {
      final service = SettingsService(InMemorySettingsStore());
      await service.load();
      await tester.pumpWidget(_wrap(service));
      await tester.pumpAndSettle();

      expect(find.text('نمط المظهر'), findsOneWidget);
      expect(find.text('كثافة العرض'), findsOneWidget);
      expect(find.text('حجم الخط'), findsOneWidget);
      expect(find.text('إعادة ضبط الإعدادات'), findsOneWidget);
    });

    testWidgets('selecting dark mode updates the service', (tester) async {
      final service = SettingsService(InMemorySettingsStore());
      await service.load();
      await tester.pumpWidget(_wrap(service));
      await tester.pumpAndSettle();

      await tester.tap(find.text('داكن'));
      await tester.pumpAndSettle();

      expect(service.appearance.themeMode, ThemeMode.dark);
    });

    testWidgets('selecting spacious updates density', (tester) async {
      final service = SettingsService(InMemorySettingsStore());
      await service.load();
      await tester.pumpWidget(_wrap(service));
      await tester.pumpAndSettle();

      await tester.tap(find.text('مريح'));
      await tester.pumpAndSettle();

      expect(service.appearance.density, AppDensity.spacious);
    });

    testWidgets('font slider raises fontScale above 1.0', (tester) async {
      final service = SettingsService(InMemorySettingsStore());
      await service.load();
      await tester.pumpWidget(_wrap(service));
      await tester.pumpAndSettle();

      final slider = find.byType(Slider);
      // RTL: drag left increases value; drag right decreases.
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
      await tester.pumpWidget(_wrap(service));
      await tester.pumpAndSettle();

      await tester.tap(find.text('إعادة ضبط الإعدادات'));
      await tester.pumpAndSettle();
      expect(find.text('إعادة ضبط الإعدادات؟'), findsOneWidget);

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
      await tester.pumpWidget(_wrap(service));
      await tester.pumpAndSettle();

      await tester.tap(find.text('إعادة ضبط الإعدادات'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();

      expect(service.appearance.themeMode, ThemeMode.dark);
    });
  });
}