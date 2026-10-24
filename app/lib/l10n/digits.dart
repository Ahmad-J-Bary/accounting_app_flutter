import '../settings/settings_model.dart';

const Map<String, String> _toEastern = {
  '0': '٠', '1': '١', '2': '٢', '3': '٣', '4': '٤',
  '5': '٥', '6': '٦', '7': '٧', '8': '٨', '9': '٩',
};

/// Converts the digits 0-9 inside [input] to the requested system.
/// Other characters (comma, dot, letters) are preserved unchanged.
String applyDigits(String input, AppDigits digits) {
  if (digits == AppDigits.western) return input;
  final buf = StringBuffer();
  for (var i = 0; i < input.length; i++) {
    buf.write(_toEastern[input[i]] ?? input[i]);
  }
  return buf.toString();
}

/// Formats [number] with thousands separators, then applies [digits].
/// Preview-only helper for the settings page. Full number formatting
/// across the app arrives in F2-b.
String formatWithDigits(num number, AppDigits digits) {
  final parts = number.toString().split('.');
  final intPart = parts[0];
  final buf = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(',');
    buf.write(intPart[i]);
  }
  if (parts.length > 1) {
    buf.write('.');
    buf.write(parts[1]);
  }
  return applyDigits(buf.toString(), digits);
}