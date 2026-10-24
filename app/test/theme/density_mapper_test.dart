import 'package:flutter_test/flutter_test.dart';

import 'package:accounting_app_flutter/settings/settings_model.dart';
import 'package:accounting_app_flutter/theme/density_mapper.dart';

void main() {
  group('visualDensityFor', () {
    test('compact is negative', () {
      final v = visualDensityFor(AppDensity.compact);
      expect(v.vertical, lessThan(0));
      expect(v.horizontal, lessThan(0));
    });

    test('comfortable is zero', () {
      final v = visualDensityFor(AppDensity.comfortable);
      expect(v.vertical, 0);
      expect(v.horizontal, 0);
    });

    test('spacious is positive (F4-a-2 fix)', () {
      final v = visualDensityFor(AppDensity.spacious);
      expect(v.vertical, greaterThan(0));
      expect(v.horizontal, greaterThan(0));
    });

    test('order is monotonic compact < comfortable < spacious', () {
      final c = visualDensityFor(AppDensity.compact).vertical;
      final m = visualDensityFor(AppDensity.comfortable).vertical;
      final s = visualDensityFor(AppDensity.spacious).vertical;
      expect(c, lessThan(m));
      expect(m, lessThan(s));
    });
  });
}