import 'dart:convert';
import 'dart:io';

import 'package:buzdolabi_sefi/data/catalog.dart';
import 'package:buzdolabi_sefi/models/recipe.dart';
import 'package:buzdolabi_sefi/services/caption_recipe_extractor.dart';
import 'package:buzdolabi_sefi/services/ingredient_repository.dart';
import 'package:buzdolabi_sefi/services/video_import.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_catalog.dart';

void main() {
  test('YouTube linkinden video kimliği', () {
    expect(VideoInfoClient.youTubeId('https://youtu.be/TtdOXQhUpvo?si=x'),
        'TtdOXQhUpvo');
    expect(VideoInfoClient.youTubeId('https://www.youtube.com/watch?v=abc'),
        'abc');
    expect(VideoInfoClient.youTubeId('https://youtube.com/shorts/xyz'), 'xyz');
  });

  test('izleme sayfasından açıklama okunur', () {
    const html = r'x"shortDescription":"Malzemeler\n1 litre s\u00fct",y';
    expect(VideoInfoClient.parseYouTubeDescription(html),
        'Malzemeler\n1 litre süt');
  });

  test('YouTube video başlığından tarif adı', () {
    final e = CaptionRecipeExtractor(IngredientRepository(ingredientCatalog));
    expect(
        e.titleFromVideoTitle(
            'Viral Tatlı Spoonful Tarifi 🥄 Mutlaka Deneyin! ✅'),
        'Tatlı Spoonful Tarifi');
  });

  test('YouTube açıklamasındaki tarif (spoonful) çıkar', () {
    final desc = (jsonDecode(
            File('test/fixtures/youtube_spoonful.json').readAsStringSync())
        as Map)['description'] as String;
    final repo = IngredientRepository(ingredientCatalog);
    final x = CaptionRecipeExtractor(repo).extract(
        'Viral Tatlı Spoonful Tarifi 🥄 Mutlaka Deneyin! ✅\n\n$desc',
        id: 'yt',
        source: const RecipeSource(
            url: 'https://youtu.be/TtdOXQhUpvo', platform: 'YouTube'));
    final ids = {for (final i in x.recipe.items) i.ingredientId};
    // ignore: avoid_print
    print('${x.recipe.title} | ${x.recipe.emoji} | $ids | '
        '${x.recipe.steps.length} adım | eşleşmeyen: ${x.unmatched}');
    expect(ids, containsAll(['sut', 'un']));
    expect(x.recipe.steps, isNotEmpty);
    expect(x.recipe.title.toLowerCase(), isNot(contains('kişilik')));
  });
}
