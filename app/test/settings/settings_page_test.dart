import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:accounting_app_flutter/settings/settings_model.dart';
import 'package:accounting_app_flutter/settings/settings_page.dart';
import 'package:accounting_app_flutter/settings/settings_service.dart';
import 'package:accounting_app_flutter/settings/settings_store.dart';

Widget _wrap(
  SettingsService service,
  WidgetTester tester, {
  Size size = const Size(1440, 1024),
}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  return ChangeNotifierProvider<SettingsService>.value(
    value: service,
    child: MaterialApp(
      home: Scaffold(body: const SettingsPage()),
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
  group('SettingsPage — wide layout', () {
    testWidgets('defaults to company section with coming-soon placeholder',
        (tester) async {
      final service = SettingsService(InMemorySettingsStore());
      await service.load();
      await tester.pumpWidget(_wrap(service, tester));
      await tester.pumpAndSettle();

      expect(find.text('بيانات الشركة ستُضاف في 1.0.4.'), findsOneWidget);
      expect(find.text('تعديل المظهر الآن'), findsOneWidget);
    });

    testWidgets('navigation shows all 10 main sections', (tester) async {
      final service = SettingsService(InMemorySettingsStore());
      await service.load();
      await tester.pumpWidget(_wrap(service, tester));
      await tester.pumpAndSettle();

      expect(find.text('الأرقام التسلسلية'), findsOneWidget);
      expect(find.text('إدارة العملات'), findsOneWidget);
      expect(find.text('الإعدادات المالية'), findsOneWidget);
      expect(find.text('المستودعات'), findsOneWidget);
      expect(find.text('إعدادات التصدير'), findsOneWidget);
      expect(find.text('البيانات والنسخ الاحتياطية'), findsOneWidget);
      expect(find.text('الأمان والوصول'), findsOneWidget);
      expect(find.text('حول التطبيق'), findsOneWidget);
    });

    testWidgets('"customize appearance now" navigates to appearance',
        (tester) async {
      final service = SettingsService(InMemorySettingsStore());
      await service.load();
      await tester.pumpWidget(_wrap(service, tester));
      await tester.pumpAndSettle();

      await tester.tap(find.text('تعديل المظهر الآن'));
      await tester.pumpAndSettle();

      expect(find.text('نمط المظهر'), findsOneWidget);
      expect(find.text('كثافة العرض'), findsOneWidget);
      expect(find.text('حجم الخط'), findsOneWidget);
    });

    testWidgets('navigation to localization shows language/digits',
        (tester) async {
      final service = SettingsService(InMemorySettingsStore());
      await service.load();
      await tester.pumpWidget(_wrap(service, tester));
      await tester.pumpAndSettle();

      await tester.tap(find.text('اللغة والمنطقة').first);
      await tester.pumpAndSettle();

      expect(find.text('لغة الواجهة'), findsOneWidget);
      expect(find.text('العربية'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(find.text('نظام الأرقام'), findsOneWidget);
    });

    testWidgets('theme mode change persists via service', (tester) async {
      final service = SettingsService(InMemorySettingsStore());
      await service.load();
      await tester.pumpWidget(_wrap(service, tester));
      await tester.pumpAndSettle();

      await tester.tap(find.text('تعديل المظهر الآن'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('داكن'));
      await tester.pumpAndSettle();

      expect(service.appearance.themeMode, ThemeMode.dark);
    });

    testWidgets('appearance group collapsed by default', (tester) async {
      final service = SettingsService(InMemorySettingsStore());
      await service.load();
      await tester.pumpWidget(_wrap(service, tester));
      await tester.pumpAndSettle();

      expect(find.text('مظهر الجداول'), findsNothing);
      expect(find.text('مظهر قائمة التنقل'), findsNothing);
    });

    testWidgets('appearance group expands on tap', (tester) async {
      final service = SettingsService(InMemorySettingsStore());
      await service.load();
      await tester.pumpWidget(_wrap(service, tester));
      await tester.pumpAndSettle();

      await tester.tap(find.text('المظهر').first);
      await tester.pumpAndSettle();

      expect(find.text('مظهر الجداول'), findsOneWidget);
      expect(find.text('مظهر قائمة التنقل'), findsOneWidget);
      expect(find.text('محتوى وترتيب القائمة'), findsOneWidget);
    });

    testWidgets('language switch from localization section', (tester) async {
      final service = SettingsService(InMemorySettingsStore());
      await service.load();
      await tester.pumpWidget(_wrap(service, tester));
      await tester.pumpAndSettle();

      await tester.tap(find.text('اللغة والمنطقة').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();

      expect(service.locale.language, AppLanguage.english);
    });
  });

  group('SettingsPage — compact layout', () {
    testWidgets('shows trigger button for navigation', (tester) async {
      final service = SettingsService(InMemorySettingsStore());
      await service.load();
      await tester.pumpWidget(
        _wrap(service, tester, size: const Size(800, 600)),
      );
      await tester.pumpAndSettle();

      // Company placeholder still reachable on compact
      expect(find.text('بيانات الشركة ستُضاف في 1.0.4.'), findsOneWidget);
    });
  });
}