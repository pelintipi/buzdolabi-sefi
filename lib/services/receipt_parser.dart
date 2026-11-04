import '../models/ingredient.dart';
import 'ingredient_repository.dart';
import 'product_words.dart';
import 'quantity_parser.dart';
import 'turkish_text.dart';
import 'unit_converter.dart';

/// Fişte bulunan bir ürün.
class ReceiptItem {
  const ReceiptItem(
      {required this.line, required this.ingredient, this.quantity});

  /// Fişteki satır ("SUT TAM YAGLI 1 LT  32,50").
  final String line;
  final Ingredient ingredient;

  /// Malzemenin baseUnit'i cinsinden; null ise paket varsayılanı.
  final double? quantity;
}

class ReceiptResult {
  const ReceiptResult({required this.items, required this.unknown});

  final List<ReceiptItem> items;

  /// Ürün gibi duran ama tanınamayan satırlar (deterjan, peçete...).
  final List<String> unknown;
}

/// Market fişi metnini (fotoğraftan okunmuş ya da e-fişten kopyalanmış)
/// malzemelere çevirir. Fişler büyük harfli, Türkçe karaktersiz ve kısaltmalı
/// olur: "DOMATES KG 1,234 X 29,90", "YUMURTA 10LU", "SUT 1LT".
class ReceiptParser {
  ReceiptParser(this.repo);

  final IngredientRepository repo;

  static final _skip = RegExp(
      r'toplam|ara top|kdv|topkdv|nakit|kredi|kart|para ustu|fis|tarih|saat|'
      r'kasiyer|magaza|vergi|tesekkur|indirim|puan|odeme|tutar|adres|tel|www|'
      r'ettn|fatura|no:|z no|eku');
  static final _price = RegExp(r'[*x×]?\s*\d+[.,]\d{2}\s*(tl|₺)?\s*$');
  static final _weighed =
      RegExp(r'(\d+[.,]\d{1,3})\s*(kg)?\s*[x×*]\s*\d+[.,]\d{2}');
  static final _amountUnit =
      RegExp(r'(\d+(?:[.,]\d+)?)\s*(kg|gr|g|lt|l|ml|cl|li|lu|lü|lı|adet|ad)\b');

  ReceiptResult parse(String text) {
    final items = <String, ReceiptItem>{};
    final unknown = <String>[];
    // Tartılan ürünlerde kilo çoğu fişte alt satırdadır:
    //   PIRASA KG
    //   1,150 X 24,90     *28,64
    String? awaitingWeight;
    for (final raw in text.split(RegExp(r'[\r\n]+'))) {
      final line = raw.trim();
      if (line.length < 3) continue;
      final folded = TurkishText.fold(line);
      if (_skip.hasMatch(folded)) continue;
      // Sadece sayı/fiyat olan satırlar: bir önceki ürünün kilosu olabilir.
      if (!RegExp(r'[a-z]{3,}').hasMatch(folded)) {
        final w = _weighed.firstMatch(folded);
        final prev = awaitingWeight == null ? null : items[awaitingWeight];
        if (w != null && prev != null) {
          final kg = double.parse(w.group(1)!.replaceAll(',', '.'));
          items[prev.ingredient.id] = ReceiptItem(
              line: '${prev.line} $line',
              ingredient: prev.ingredient,
              quantity: UnitConverter.gramsToBase(prev.ingredient, kg * 1000));
        }
        awaitingWeight = null;
        continue;
      }

      final ing = _findIngredient(folded);
      awaitingWeight = null;
      if (ing == null) {
        if (_price.hasMatch(folded)) unknown.add(line);
        continue;
      }
      // "KG" yazıp fiyatı olmayan satır: kilo alt satırda gelecek.
      if (RegExp(r'\bkg\b').hasMatch(folded) &&
          !_price.hasMatch(folded) &&
          _weighed.firstMatch(folded) == null) {
        awaitingWeight = ing.id;
      }
      final qty = _quantity(folded, ing);
      final prev = items[ing.id];
      final sum = (prev?.quantity ?? 0) + (qty ?? 0);
      items[ing.id] = ReceiptItem(
          line: line,
          ingredient: ing,
          quantity: (prev?.quantity == null && qty == null) ? null : sum);
    }
    return ReceiptResult(items: items.values.toList(), unknown: unknown);
  }

  Ingredient? _findIngredient(String folded) =>
      matchProductName(repo, folded.replaceAll(_price, ' '));

  double? _quantity(String folded, Ingredient ing) {
    final weighed = _weighed.firstMatch(folded);
    if (weighed != null) {
      final kg = double.parse(weighed.group(1)!.replaceAll(',', '.'));
      return UnitConverter.gramsToBase(ing, kg * 1000);
    }
    final m = _amountUnit.firstMatch(folded.replaceAll(_price, ''));
    if (m == null) return defaultAmountFor(ing).quantity;
    final n = double.parse(m.group(1)!.replaceAll(',', '.'));
    final grams = switch (m.group(2)) {
      'kg' => n * 1000,
      'gr' || 'g' => n,
      'lt' || 'l' => n * 1000 * ing.density,
      'ml' => n * ing.density,
      'cl' => n * 10 * ing.density,
      // "10LU yumurta", "6 ADET"
      _ => null,
    };
    if (grams == null) {
      return ing.baseUnit == BaseUnit.piece
          ? n
          : defaultAmountFor(ing).quantity;
    }
    return UnitConverter.gramsToBase(ing, grams);
  }
}
