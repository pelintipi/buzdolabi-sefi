import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/ingredient.dart';
import 'ingredient_repository.dart';
import 'product_words.dart';
import 'unit_converter.dart';

/// Barkoddan bulunan ürün.
class ScannedProduct {
  const ScannedProduct(
      {required this.barcode, this.name, this.ingredient, this.quantity});

  final String barcode;
  final String? name;

  /// Kataloğumuzda eşleşen malzeme (bulunamazsa kullanıcı seçer).
  final Ingredient? ingredient;

  /// Paketteki miktar, malzemenin baseUnit'i cinsinden.
  final double? quantity;
}

/// Barkod → ürün adı: Open Food Facts (ücretsiz, herkese açık ürün veritabanı).
/// Türkiye'deki ürünlerin hepsi orada yok; bulunamazsa kullanıcı malzemeyi
/// kendisi seçer.
class ProductLookup {
  ProductLookup(this.repo, {http.Client? client})
      : _client = client ?? http.Client();

  final IngredientRepository repo;
  final http.Client _client;

  Future<ScannedProduct> byBarcode(String code) async {
    final uri =
        Uri.https('world.openfoodfacts.org', '/api/v2/product/$code.json', {
      'fields':
          'product_name,product_name_tr,generic_name_tr,quantity,categories_tags'
    });
    try {
      final res = await _client.get(uri, headers: {
        'User-Agent': 'BuzdolabiSefi/0.1 (iOS)'
      }).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return ScannedProduct(barcode: code);
      final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final p = j['product'] as Map<String, dynamic>?;
      if (p == null) return ScannedProduct(barcode: code);
      String? str(String k) {
        final v = p[k];
        return v is String && v.trim().isNotEmpty ? v.trim() : null;
      }

      final name = str('product_name_tr') ??
          str('product_name') ??
          str('generic_name_tr');
      final categories = [
        for (final c in (p['categories_tags'] as List? ?? const []))
          if (c is String && c.startsWith('tr:'))
            c.substring(3).replaceAll('-', ' ')
      ];
      final ing = match([if (name != null) name, ...categories]);
      return ScannedProduct(
        barcode: code,
        name: name,
        ingredient: ing,
        quantity: ing == null ? null : parsePackage(str('quantity'), ing),
      );
    } catch (e) {
      debugPrint('Barkod sorgulanamadı: $e');
      return ScannedProduct(barcode: code);
    }
  }

  /// Ürün adı ya da kategorilerden katalog malzemesi.
  Ingredient? match(List<String> texts) {
    for (final t in texts) {
      final hit = matchProductName(repo, t);
      if (hit != null) return hit;
    }
    return null;
  }

  /// "1 L", "500 g", "10 adet" → baseUnit cinsinden miktar.
  static double? parsePackage(String? quantity, Ingredient ing) {
    if (quantity == null) return null;
    final m = RegExp(r'(\d+(?:[.,]\d+)?)\s*(kg|g|gr|l|lt|ml|cl|adet)',
            caseSensitive: false)
        .firstMatch(quantity);
    if (m == null) return null;
    final n = double.parse(m.group(1)!.replaceAll(',', '.'));
    final unit = m.group(2)!.toLowerCase();
    if (unit == 'adet') return ing.baseUnit == BaseUnit.piece ? n : null;
    final grams = switch (unit) {
      'kg' => n * 1000,
      'g' || 'gr' => n,
      'l' || 'lt' => n * 1000 * ing.density,
      'ml' => n * ing.density,
      _ => n * 10 * ing.density,
    };
    return UnitConverter.gramsToBase(ing, grams);
  }
}
