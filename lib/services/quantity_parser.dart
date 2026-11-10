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
  static final splitter = RegExp(r'(?<!\d),|,(?!\d)|[;\n]+|\s+ve\s+|\s+and\s+');
  static final _leadingNumber = RegExp(r'^(\d+(?:[.,]\d+)?)\s*');

  /// "1/2", "1 1/2", "½" gibi kesirler (İngilizce tariflerde yaygın).
  static final _fraction = RegExp(r'^(?:(\d+)\s+)?(\d+)\s*/\s*(\d+)\s*');
  static const _unicodeFractions = {
    '½': 0.5,
    '¼': 0.25,
    '¾': 0.75,
    '⅓': 1 / 3,
    '⅔': 2 / 3,
  };

  /// İngilizce ölçüler: Türk ölçüsü ve çarpanı (1 cup ≈ 240 ml = 1,2 su
  /// bardağı; 1 oz ≈ 28 g).
  static const _englishMeasures = <String, (Measure, double)>{
    'cups': (Measure.suBardagi, 1.2),
    'cup': (Measure.suBardagi, 1.2),
    'c.': (Measure.suBardagi, 1.2),
    'tablespoons': (Measure.yemekKasigi, 1),
    'tablespoon': (Measure.yemekKasigi, 1),
    'tbsp.': (Measure.yemekKasigi, 1),
    'tbsp': (Measure.yemekKasigi, 1),
    'tbs': (Measure.yemekKasigi, 1),
    'teaspoons': (Measure.cayKasigi, 1),
    'teaspoon': (Measure.cayKasigi, 1),
    'tsp.': (Measure.cayKasigi, 1),
    'tsp': (Measure.cayKasigi, 1),
    'ounces': (Measure.gram, 28.35),
    'ounce': (Measure.gram, 28.35),
    'oz': (Measure.gram, 28.35),
    'pounds': (Measure.gram, 453.6),
    'pound': (Measure.gram, 453.6),
    'lbs': (Measure.gram, 453.6),
    'lb': (Measure.gram, 453.6),
    'grams': (Measure.gram, 1),
    'liters': (Measure.litre, 1),
    'pinch': (Measure.tutam, 1),
    'pinches': (Measure.tutam, 1),
    'cloves': (Measure.dis, 1),
    'clove': (Measure.dis, 1),
    'slices': (Measure.dilim, 1),
    'slice': (Measure.dilim, 1),
    'bunch': (Measure.demet, 1),
    'containers': (Measure.paket, 1),
    'container': (Measure.paket, 1),
    'packages': (Measure.paket, 1),
    'package': (Measure.paket, 1),
    'cans': (Measure.paket, 1),
    'can': (Measure.paket, 1),
  };

  static final _englishLongestFirst = _englishMeasures.entries.toList()
    ..sort((a, b) => b.key.length.compareTo(a.key.length));

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
    // İngilizce
    'half': 0.5,
    'a': 1.0,
    'an': 1.0,
    'one': 1.0,
    'two': 2.0,
    'three': 3.0,
    'four': 4.0,
    'five': 5.0,
    'six': 6.0,
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

    final fraction = _fraction.firstMatch(text);
    final number = fraction == null ? _leadingNumber.firstMatch(text) : null;
    final uni = text.isEmpty ? null : _unicodeFractions[text[0]];
    if (fraction != null) {
      amount = (double.tryParse(fraction.group(1) ?? '') ?? 0) +
          int.parse(fraction.group(2)!) / int.parse(fraction.group(3)!);
      text = text.substring(fraction.end);
    } else if (uni != null) {
      amount = uni;
      text = text.substring(1).trim();
    } else if (number != null) {
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

    // "2 ½ cups": tam sayıdan sonra gelen kesir.
    if (amount != null && text.isNotEmpty) {
      final more = _unicodeFractions[text[0]];
      if (more != null) {
        amount = amount + more;
        text = text.substring(1).trim();
      }
    }

    for (final entry in _measuresLongestFirst) {
      if (text.startsWith('${entry.key} ')) {
        measure = entry.value;
        text = text.substring(entry.key.length + 1);
        break;
      }
    }
    if (measure == null) {
      for (final entry in _englishLongestFirst) {
        if (text.startsWith('${entry.key} ')) {
          final (m, factor) = entry.value;
          measure = m;
          amount = (amount ?? 1) * factor;
          text = text.substring(entry.key.length + 1);
          break;
        }
      }
    }
    // "pinch of salt", "1 cup of milk"
    if (text.startsWith('of ')) text = text.substring(3);

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
