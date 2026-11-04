import 'dart:math' as math;

import '../models/ingredient.dart';
import '../models/measure.dart';
import '../models/pantry_item.dart';
import 'ingredient_repository.dart';
import 'turkish_text.dart';
import 'unit_converter.dart';

class ParsedEntry {
  const ParsedEntry({
    required this.raw,
    this.ingredient,
    this.quantity,
    this.level,
    this.amount,
    this.measure,
  });

  final String raw;
  final Ingredient? ingredient;

  /// Malzemenin baseUnit'i cinsinden.
  final double? quantity;
  final ApproxLevel? level;

  /// Yazıldığı haliyle sayı ve ölçü: "1,5 su bardağı" → 1.5 + suBardagi.
  /// Ölçü yazılmadıysa malzemeye uygun varsayılan ölçü.
  final double? amount;
  final Measure? measure;
}

/// Miktar belirtilmemiş bir malzeme için varsayılan: adetle sayılanlarda
/// paketin yarısı, diğerlerinde "Biraz".
({double? quantity, ApproxLevel? level}) defaultAmountFor(Ingredient ing) {
  if (ing.baseUnit == BaseUnit.piece) {
    return (
      quantity: math.max(1.0, (ing.packageAmount / 2).roundToDouble()),
      level: null,
    );
  }
  return (quantity: null, level: ApproxLevel.biraz);
}

/// "2 yumurta, yarım biber, 1 kase yoğurt, biraz peynir" gibi serbest
/// metni malzeme ve miktarlara ayırır.
class QuantityParser {
  QuantityParser(this.repo);

  final IngredientRepository repo;

  // Ondalık virgülü ("1,5 su bardağı") ayırıcı sayılmaz.
  static final splitter = RegExp(r'(?<!\d),|,(?!\d)|[;\n]+|\s+ve\s+');
  static final _leadingNumber = RegExp(r'^(\d+(?:[.,]\d+)?)\s*');

  static const _numberWords = {
    'yarım': 0.5,
    'bir': 1.0,
    'bi': 1.0,
    'iki': 2.0,
    'üç': 3.0,
    'dört': 4.0,
    'beş': 5.0,
    'altı': 6.0,
    'yedi': 7.0,
    'sekiz': 8.0,
    'dokuz': 9.0,
    'on': 10.0,
    'birkaç': 3.0,
  };

  static const _levelWords = {
    'biraz': ApproxLevel.biraz,
    'azıcık': ApproxLevel.az,
    'az': ApproxLevel.az,
    'bol': ApproxLevel.bol,
    'bolca': ApproxLevel.bol,
    'çok': ApproxLevel.bol,
  };

  static const _measureWords = {
    'su bardağı': Measure.suBardagi,
    'çay bardağı': Measure.cayBardagi,
    'yemek kaşığı': Measure.yemekKasigi,
    'tatlı kaşığı': Measure.tatliKasigi,
    'çay kaşığı': Measure.cayKasigi,
    'bardak': Measure.suBardagi,
    'kaşık': Measure.yemekKasigi,
    'kase': Measure.kase,
    'gram': Measure.gram,
    'gr': Measure.gram,
    'g': Measure.gram,
    'kilo': Measure.kilogram,
    'kg': Measure.kilogram,
    'ml': Measure.ml,
    'litre': Measure.litre,
    'lt': Measure.litre,
    'l': Measure.litre,
    'adet': Measure.adet,
    'tane': Measure.adet,
    'tutam': Measure.tutam,
    'paket': Measure.paket,
    'kutu': Measure.paket,
    'diş': Measure.dis,
    'demet': Measure.demet,
    'dilim': Measure.dilim,
  };

  static final _measuresLongestFirst = _measureWords.entries.toList()
    ..sort((a, b) => b.key.length.compareTo(a.key.length));

  List<ParsedEntry> parse(String input) => [
        for (final chunk in input.split(splitter))
          if (chunk.trim().isNotEmpty) parseChunk(chunk.trim()),
      ];

  ParsedEntry parseChunk(String chunk) {
    var text = TurkishText.lower(chunk).replaceAll(RegExp(r'\s+'), ' ').trim();
    double? amount;
    ApproxLevel? level;
    Measure? measure;

    final number = _leadingNumber.firstMatch(text);
    if (number != null) {
      amount = double.parse(number.group(1)!.replaceAll(',', '.'));
      text = text.substring(number.end);
    } else {
      final words = text.split(' ');
      final rest = words.skip(1).join(' ');
      if (rest.isNotEmpty) {
        if (_numberWords.containsKey(words.first)) {
          amount = _numberWords[words.first];
          text = rest;
        } else if (_levelWords.containsKey(words.first)) {
          level = _levelWords[words.first];
          text = rest;
        }
      }
    }

    if (amount != null && text.startsWith('buçuk ')) {
      amount = amount + 0.5;
      text = text.substring('buçuk '.length);
    }

    for (final entry in _measuresLongestFirst) {
      if (text.startsWith('${entry.key} ')) {
        measure = entry.value;
        text = text.substring(entry.key.length + 1);
        break;
      }
    }

    final ing = repo.findByName(text);
    if (ing == null) return ParsedEntry(raw: chunk);

    double? quantity;
    if (amount != null) {
      final m = measure ??= _defaultMeasure(ing, amount);
      quantity =
          UnitConverter.gramsToBase(ing, UnitConverter.toGrams(ing, amount, m));
    } else if (level == null) {
      final d = defaultAmountFor(ing);
      quantity = d.quantity;
      level = d.level;
    }
    return ParsedEntry(
        raw: chunk,
        ingredient: ing,
        quantity: quantity,
        level: level,
        amount: amount,
        measure: measure);
  }

  /// Birim yazılmadıysa: adetle sayılanlarda adet, büyük sayılarda gram/ml,
  /// küçük sayılarda paket ("1 süt" = 1 paket süt).
  Measure _defaultMeasure(Ingredient ing, double amount) {
    if (ing.baseUnit == BaseUnit.piece) return Measure.adet;
    if (amount >= 20) {
      return ing.baseUnit == BaseUnit.ml ? Measure.ml : Measure.gram;
    }
    return Measure.paket;
  }
}
