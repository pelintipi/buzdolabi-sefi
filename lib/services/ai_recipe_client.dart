import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/recipe.dart';
import 'ingredient_repository.dart';

class AiRecipe {
  const AiRecipe(
      {required this.recipe, required this.unmatched, required this.cached});

  final Recipe recipe;
  final List<String> unmatched;

  /// Aynı video daha önce başka biri için çıkarılmıştı (yapay zeka çağrılmadı).
  final bool cached;
}

/// Şef+ "yapay zekayla video tarifi": kendi sunucumuzdaki
/// server/supabase/functions/extract-recipe fonksiyonunu çağırır. Yapay zeka
/// anahtarı uygulamada değil sunucudadır. Sunucu sonucu video adresine göre
/// saklar; aynı videoyu paylaşan sonraki herkes anında ve masrafsız alır.
///
/// Derlerken verilir:
///   --dart-define=EXTRACT_URL=https://<proje>.supabase.co/functions/v1/extract-recipe
///   --dart-define=SUPABASE_ANON_KEY=<anon anahtar>
/// Verilmezse [configured] false olur ve uygulama kural tabanlı çıkarmayla devam eder.
class AiRecipeClient {
  AiRecipeClient({String? endpoint, String? anonKey, http.Client? client})
      : endpoint = endpoint ?? const String.fromEnvironment('EXTRACT_URL'),
        anonKey = anonKey ?? const String.fromEnvironment('SUPABASE_ANON_KEY'),
        _client = client ?? http.Client();

  final String endpoint;
  final String anonKey;
  final http.Client _client;

  bool get configured => endpoint.isNotEmpty;

  Future<AiRecipe?> extract({
    required IngredientRepository repo,
    required String id,
    required RecipeSource source,
    String? caption,
    String? transcript,
  }) async {
    if (!configured) return null;
    try {
      final res = await _client
          .post(
            Uri.parse(endpoint),
            headers: {
              'Content-Type': 'application/json',
              if (anonKey.isNotEmpty) 'Authorization': 'Bearer $anonKey',
            },
            body: jsonEncode({
              'url': source.url,
              if (caption != null) 'caption': caption,
              if (transcript != null) 'transcript': transcript,
              // Sunucu yalnızca bu kimliklerle tarif yazar.
              'ingredients': [
                for (final i in repo.all) {'id': i.id, 'name': i.name}
              ],
            }),
          )
          .timeout(const Duration(seconds: 45));
      if (res.statusCode != 200) {
        debugPrint('Yapay zeka çıkarımı başarısız: ${res.statusCode}');
        return null;
      }
      final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final raw = Map<String, dynamic>.of(j['recipe'] as Map<String, dynamic>);
      // Sunucunun uydurduğu malzeme kimliklerini at, kullanıcıya göster.
      final unmatched = <String>[
        for (final u in (j['unmatched'] as List? ?? const [])) u.toString()
      ];
      final items = <Map<String, dynamic>>[];
      for (final item in (raw['items'] as List? ?? const [])) {
        final m = Map<String, dynamic>.of(item as Map<String, dynamic>);
        if (repo.tryById(m['ingredient'] as String? ?? '') == null) {
          unmatched.add(m['ingredient'].toString());
          continue;
        }
        m['substitutes'] = [
          for (final s in (m['substitutes'] as List? ?? const []))
            if (repo.tryById((s as Map)['ingredient'] as String? ?? '') != null)
              s
        ];
        items.add(m);
      }
      // İkon: sunucu göndermez, ana malzemenin 3D ikonundan alınır.
      final main = items.where((m) => m['role'] == 'main').firstOrNull ??
          items.firstOrNull;
      raw['emoji'] ??=
          main == null ? '🍽️' : repo.byId(main['ingredient'] as String).emoji;
      raw
        ..['id'] = id
        ..['items'] = items
        ..['tags'] = [...?(raw['tags'] as List?), 'videodan', 'yapay_zeka']
        ..['source'] = RecipeSource(
          url: source.url,
          platform: source.platform,
          author: source.author,
          thumbnailUrl: source.thumbnailUrl,
          caption: caption ?? transcript,
          unmatched: unmatched,
        ).toJson();
      final recipe = Recipe.fromJson(raw);
      if (recipe.items.length < 2 || recipe.steps.isEmpty) return null;
      return AiRecipe(
          recipe: recipe, unmatched: unmatched, cached: j['cached'] == true);
    } catch (e) {
      debugPrint('Yapay zeka çıkarımı okunamadı: $e');
      return null;
    }
  }
}
