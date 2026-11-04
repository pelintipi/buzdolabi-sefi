import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'catalog.dart';

/// Tarifleri uygulama güncellemesi beklemeden yenilemek için.
///
/// [baseUrl] altında `ingredients.json` ve `recipes.json` (uygulamadakiyle aynı
/// biçim) aranır. Ücretsiz seçenek: GitHub deposundaki assets/data klasörünün
/// "raw" adresi. Derlerken verilir:
///   --dart-define=CATALOG_URL=https://raw.githubusercontent.com/<kullanıcı>/<depo>/main/assets/data
///
/// İndirilen katalog doğrulanır; sürümü uygulamadakinden eskiyse, bozuksa ya
/// da tariflerin onda birinden fazlası geçersizse kullanılmaz. Yeni katalog bir
/// sonraki açılışta devreye girer (açık ekranlar altından değişmesin diye).
class RemoteCatalog {
  RemoteCatalog({String? baseUrl, http.Client? client})
      : baseUrl = baseUrl ?? const String.fromEnvironment('CATALOG_URL'),
        _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  static const _ingKey = 'catalog_ingredients_v1';
  static const _recKey = 'catalog_recipes_v1';

  bool get configured => baseUrl.isNotEmpty;

  static int _version(String json) =>
      ((jsonDecode(json) as Map<String, dynamic>)['version'] as num?)
          ?.toInt() ??
      0;

  /// Önbellekteki katalog, paketteki katalogdan yeniyse onu döndürür.
  static Future<Catalog?> cachedNewerThan(String bundledRecipesJson) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ing = prefs.getString(_ingKey);
      final rec = prefs.getString(_recKey);
      if (ing == null || rec == null) return null;
      if (_version(rec) <= _version(bundledRecipesJson)) return null;
      final c = Catalog.parse(ing, rec);
      return c.recipes.isEmpty ? null : c;
    } catch (e) {
      debugPrint('Önbellekteki katalog okunamadı: $e');
      return null;
    }
  }

  /// Sunucudaki katalogu indirip doğrular ve önbelleğe yazar.
  /// Döndürdüğü değer: yeni bir sürüm kaydedildi mi?
  Future<bool> refresh({required String bundledRecipesJson}) async {
    if (!configured) return false;
    try {
      final responses = await Future.wait([
        _client.get(Uri.parse('$baseUrl/ingredients.json')),
        _client.get(Uri.parse('$baseUrl/recipes.json')),
      ]).timeout(const Duration(seconds: 15));
      if (responses.any((r) => r.statusCode != 200)) return false;
      final ing = utf8.decode(responses[0].bodyBytes);
      final rec = utf8.decode(responses[1].bodyBytes);
      if (_version(rec) <= _version(bundledRecipesJson)) return false;
      final parsed = Catalog.parse(ing, rec);
      final total = (jsonDecode(rec)['recipes'] as List).length;
      if (parsed.recipes.isEmpty || parsed.recipes.length < total * 0.9) {
        debugPrint('Sunucudaki katalog reddedildi: ${parsed.problems.take(5)}');
        return false;
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_ingKey, ing);
      await prefs.setString(_recKey, rec);
      return true;
    } catch (e) {
      debugPrint('Katalog güncellenemedi: $e');
      return false;
    }
  }
}
