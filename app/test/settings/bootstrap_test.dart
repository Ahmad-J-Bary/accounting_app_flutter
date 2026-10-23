import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:accounting_app_flutter/settings/settings.dart';

void main() {
  testWidgets('SettingsService is accessible via ChangeNotifierProvider.value',
      (tester) async {
    final service = SettingsService(InMemorySettingsRepository());
    await service.load();

    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsService>.value(
        value: service,
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              final svc = context.read<SettingsService>();
              return Text('loaded:${svc.isLoaded}');
            },
          ),
        ),
      ),
    );

    expect(find.text('loaded:true'), findsOneWidget);
  });

  testWidgets('SettingsService notifies dependents on update',
      (tester) async {
    final service = SettingsService(InMemorySettingsRepository());
    await service.load();

    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsService>.value(
        value: service,
        child: MaterialApp(
          home: Consumer<SettingsService>(
            builder: (context, svc, _) =>
                Text('mode:${svc.appPreferences.themeMode.name}'),
          ),
        ),
      ),
    );

    expect(find.text('mode:system'), findsOneWidget);

    await service.updateAppPreferences(
      const AppPreferences(themeMode: AppThemeMode.dark),
    );
    await tester.pump();

    expect(find.text('mode:dark'), findsOneWidget);
  });

  test('AppPreferences default density is compact', () {
    const prefs = AppPreferences();
    expect(prefs.density, AppDensity.compact);
  });
}