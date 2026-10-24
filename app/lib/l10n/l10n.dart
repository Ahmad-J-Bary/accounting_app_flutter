import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../settings/settings_model.dart';
import '../settings/settings_service.dart';
import 'app_strings.dart';

export 'app_strings.dart';
export 'digits.dart';

extension L10nContext on BuildContext {
  /// Reads the current language from SettingsService without subscribing.
  /// Safe because the root AnimatedBuilder rebuilds the whole tree when
  /// the service changes.
  AppStrings get strings {
    try {
      final service = Provider.of<SettingsService>(this, listen: false);
      return service.locale.language.strings;
    } catch (_) {
      return const ArStrings();
    }
  }

  AppDigits get digits {
    try {
      final service = Provider.of<SettingsService>(this, listen: false);
      return service.locale.digits;
    } catch (_) {
      return AppDigits.western;
    }
  }
}