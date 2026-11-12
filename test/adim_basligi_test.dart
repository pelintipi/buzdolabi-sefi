// "Sos için:" gibi bölüm başlıkları tek başına adım olmaz.
import 'package:buzdolabi_sefi/models/recipe.dart';
import 'package:buzdolabi_sefi/services/caption_recipe_extractor.dart';
import 'package:buzdolabi_sefi/services/ingredient_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_catalog.dart';

void main() {
  final x = CaptionRecipeExtractor(IngredientRepository(ingredientCatalog));
  const src = RecipeSource(url: 'https://www.tiktok.com/@a/video/1');

  test('başlık sonraki adıma katılır; eski kayıt da düzelir', () {
    final r = x
        .extract(
            'Havuçlu kek\nMalzemeler: 3 yumurta, 1 su bardağı şeker, 2 havuç\n'
            'Yapılışı:\nSos için:\nKremayı ve şekeri karıştırın.\n'
            'Kek için:\nYumurtayı çırpın. Havucu ekleyin. Fırında 40 dakika pişirin.',
            id: 'k1',
            source: src)
        .recipe;
    final texts = [for (final s in r.steps) s.text];
    expect(texts.any((t) => RegExp(r':\s*\.?$').hasMatch(t)), isFalse);

    final old = Recipe.fromJson({
      ...r.toJson(),
      'steps': [
        const RecipeStep('Sos için:.').toJson(),
        const RecipeStep('Kremayı karıştırın.').toJson(),
      ],
    });
    final fixed = x.repairedSteps(old)!;
    expect(fixed.length, 1);
    expect(fixed.first['text'], 'Sos için: kremayı karıştırın.');
  });
}
