// Videodaki giriş cümlesi ("…isteyenler bu tarifi…") yerine yemeğin adı.
import 'package:buzdolabi_sefi/models/recipe.dart';
import 'package:buzdolabi_sefi/services/caption_recipe_extractor.dart';
import 'package:buzdolabi_sefi/services/ingredient_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_catalog.dart';

void main() {
  final x = CaptionRecipeExtractor(IngredientRepository(ingredientCatalog));
  const src = RecipeSource(url: 'https://www.tiktok.com/@a/video/1');

  test('tıklama tuzağı cümle başlık sayılmaz', () {
    expect(CaptionRecipeExtractor.isClickbaitTitle(
        'Sevdiğini mutlu etmek isteyenler bu tarifi…'), isTrue);
    expect(CaptionRecipeExtractor.isClickbaitTitle(
        'Bunu denemeyen kalmasın'), isTrue);
    expect(CaptionRecipeExtractor.isClickbaitTitle('Kremalı tavuk'), isFalse);
    expect(CaptionRecipeExtractor.isClickbaitTitle('Tavuk tantuni'), isFalse);
    expect(CaptionRecipeExtractor.isClickbaitTitle('Tatlı spoonful'), isFalse);
  });

  test('ad malzemelerden kurulur; eski kayıt da düzelir', () {
    final r = x
        .extract(
            'Sevdiğini mutlu etmek isteyenler bu tarifi mutlaka denesin\n'
            'Malzemeler: 500 gr tavuk göğsü, 1 kutu krema, 1 kaşık salça\n'
            'Yapılışı: Tavukları soteleyin, kremayı ekleyin.',
            id: 't1',
            source: src)
        .recipe;
    expect(r.title, 'Kremalı tavuk göğsü');
    final old = Recipe.fromJson(
        {...r.toJson(), 'title': 'Sevdiğini mutlu etmek isteyenler bu tarifi…'});
    expect(x.repairedTitle(old), 'Kremalı tavuk göğsü');
  });
}
