/// JSON'da 61.0 yerine 61 yazılsın diye tam sayıları int'e çevirir.
num compactNum(double v) => v == v.roundToDouble() ? v.toInt() : v;

double readDouble(Object? v, [double? fallback]) {
  if (v == null) {
    if (fallback != null) return fallback;
    throw const FormatException('Sayı bekleniyordu');
  }
  return (v as num).toDouble();
}

List<String> readStrings(Object? v) =>
    [for (final s in (v as List? ?? const [])) s as String];
