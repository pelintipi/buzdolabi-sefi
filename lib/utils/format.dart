import 'dart:math' as math;

import '../models/ingredient.dart';
import '../models/measure.dart';

const _months = [
  'Oca',
  'Şub',
  'Mar',
  'Nis',
  'May',
  'Haz',
  'Tem',
  'Ağu',
  'Eyl',
  'Eki',
  'Kas',
  'Ara',
];

String formatNumber(double v, {int decimals = 1}) {
  final rounded = double.parse(v.toStringAsFixed(decimals));
  if (rounded == rounded.roundToDouble()) return rounded.toInt().toString();
  return rounded.toStringAsFixed(decimals).replaceAll('.', ',');
}

/// Mutfak kesirleri: 1½, ¾. En küçük değer bir adımdır.
String formatFraction(double v, {double step = 0.25}) {
  var q = (v / step).round() * step;
  if (q <= 0) q = step;
  final whole = q.floor();
  final rest = q - whole;
  final frac = rest == 0.25
      ? '¼'
      : rest == 0.5
          ? '½'
          : rest == 0.75
              ? '¾'
              : '';
  if (whole == 0) return frac;
  return '$whole$frac';
}

double _roundNice(double g) {
  if (g < 20) return g.roundToDouble();
  if (g < 100) return (g / 5).round() * 5.0;
  return (g / 10).round() * 10.0;
}

/// Tarif miktarı, porsiyona göre ölçeklenmiş ve akıllıca yuvarlanmış.
String formatMeasureAmount(double amount, Measure m) {
  final value = switch (m) {
    Measure.gram ||
    Measure.ml =>
      formatNumber(math.max(1.0, _roundNice(amount))),
    Measure.kilogram || Measure.litre => formatNumber(amount),
    Measure.tutam => '${math.max(1, amount.round())}',
    Measure.adet ||
    Measure.dis ||
    Measure.paket ||
    Measure.dilim =>
      formatFraction(amount, step: 0.5),
    _ => formatFraction(amount),
  };
  return '$value ${m.label}';
}

/// "1½ yumurta" yerine pratik öneri: "1 büyük ya da 2 küçük".
String? halfPieceHint(double amount, Measure m) {
  if (m != Measure.adet) return null;
  final q = (amount * 2).round() / 2;
  if (q < 1.5 || q == q.floorToDouble()) return null;
  return '${q.floor()} büyük ya da ${q.ceil()} küçük';
}

String formatBase(Ingredient ing, double base) {
  switch (ing.baseUnit) {
    case BaseUnit.piece:
      return '${formatFraction(base, step: 0.5)} ${ing.pieceLabel}';
    case BaseUnit.gram:
      return base >= 1000
          ? '${formatNumber(base / 1000)} kg'
          : '${formatNumber(math.max(1.0, _roundNice(base)))} g';
    case BaseUnit.ml:
      return base >= 1000
          ? '${formatNumber(base / 1000)} L'
          : '${formatNumber(math.max(1.0, _roundNice(base)))} ml';
  }
}

String formatGrams(double g) =>
    g >= 1000 ? '${formatNumber(g / 1000)} kg' : '${_roundNice(g).toInt()} g';

String formatMoney(double tl) => '~${tl.round()} ₺';

String formatTimer(Duration d) {
  final s = math.max(0, d.inSeconds);
  return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
}

String formatDate(DateTime d) => '${d.day} ${_months[d.month - 1]}';

/// Takvim günü farkı (UTC ile, yaz saati kaymasından etkilenmez).
int daysUntil(DateTime date, DateTime now) =>
    DateTime.utc(date.year, date.month, date.day)
        .difference(DateTime.utc(now.year, now.month, now.day))
        .inDays;

String expiryText(DateTime? date, DateTime now) {
  if (date == null) return '';
  final n = daysUntil(date, now);
  if (n < 0) return 'Tarihi geçti';
  if (n == 0) return 'Bugün bitiyor';
  return '$n gün kaldı';
}
