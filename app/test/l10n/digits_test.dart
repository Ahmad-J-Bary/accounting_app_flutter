import 'package:flutter_test/flutter_test.dart';

import 'package:accounting_app_flutter/l10n/digits.dart';
import 'package:accounting_app_flutter/settings/settings_model.dart';

void main() {
  group('applyDigits', () {
    test('western passthrough', () {
      expect(applyDigits('1234.56', AppDigits.western), '1234.56');
    });

    test('converts 0-9 to eastern', () {
      expect(applyDigits('0123456789', AppDigits.eastern), '٠١٢٣٤٥٦٧٨٩');
    });

    test('preserves separators and letters', () {
      expect(applyDigits('1,234.56', AppDigits.eastern), '١,٢٣٤.٥٦');
      expect(applyDigits('abc123', AppDigits.eastern), 'abc١٢٣');
    });
  });

  group('formatWithDigits', () {
    test('western thousands separator', () {
      expect(formatWithDigits(1234.56, AppDigits.western), '1,234.56');
    });

    test('eastern thousands separator', () {
      expect(formatWithDigits(1234.56, AppDigits.eastern), '١,٢٣٤.٥٦');
    });

    test('small numbers', () {
      expect(formatWithDigits(12, AppDigits.western), '12');
      expect(formatWithDigits(12, AppDigits.eastern), '١٢');
    });

    test('millions', () {
      expect(formatWithDigits(1234567, AppDigits.western), '1,234,567');
    });
  });
}