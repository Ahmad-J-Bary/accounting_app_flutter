import 'package:flutter_test/flutter_test.dart';
import 'package:accounting_app_flutter/settings/settings.dart';

void main() {
  group('LabelOverrides', () {
    test('empty by default', () {
      final overrides = LabelOverrides.empty();
      expect(overrides.resolve(AllowedLabelKeys.pageCustomersTitle), isNull);
    });

    test('accepts allowed keys and trims values', () {
      final overrides = LabelOverrides.fromRaw({
        AllowedLabelKeys.pageCustomersTitle: '  العملاء  ',
      });
      expect(
        overrides.resolveOr(AllowedLabelKeys.pageCustomersTitle, 'Customers'),
        'العملاء',
      );
    });

    test('rejects unknown keys', () {
      expect(
        () => LabelOverrides.fromRaw({'not.allowed': 'x'}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects empty values', () {
      expect(
        () => LabelOverrides.fromRaw(
          {AllowedLabelKeys.pageCustomersTitle: '   '},
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('fallback used when override absent', () {
      final overrides = LabelOverrides.empty();
      expect(
        overrides.resolveOr(AllowedLabelKeys.pageCustomersTitle, 'Customers'),
        'Customers',
      );
    });

    test('round-trips through JSON', () {
      final original = LabelOverrides.fromRaw({
        AllowedLabelKeys.pageSuppliersTitle: 'الموردون',
      });
      final restored = LabelOverrides.fromJson(
        Map<String, dynamic>.from(original.toJson()),
      );
      expect(restored, equals(original));
    });

    test('fromJson silently drops invalid persisted entries', () {
      final restored = LabelOverrides.fromJson({
        'values': {'not.allowed': 'x'},
      });
      expect(restored.values, isEmpty);
    });
  });
}