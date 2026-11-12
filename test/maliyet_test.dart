// Videodan gelen tarifte miktar yazmasa da kalori ve maliyet gerçekçi çıkar.
import 'package:buzdolabi_sefi/models/measure.dart';
import 'package:buzdolabi_sefi/models/recipe.dart';
import 'package:buzdolabi_sefi/services/caption_recipe_extractor.dart';
import 'package:buzdolabi_sefi/services/ingredient_repository.dart';
import 'package:buzdolabi_sefi/services/recipe_matcher.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_catalog.dart';

void main() {
  final repo = IngredientRepository(ingredientCatalog);
  final extractor = CaptionRecipeExtractor(repo);
  const src = RecipeSource(url: 'https://www.tiktok.com/@a/video/1');

  test('miktarsız malzemeler: kişi başı makul kalori ve maliyet', () {
    final r = extractor
        .extract(
            'Fırında tavuk\nMalzemeler: tavuk göğsü, patates, salça, soğan, '
            'zeytinyağı\nYapılışı: Salçayı kavurun. Fırına verin.',
            id: 'm1',
            source: src)
        .recipe;
    final f = RecipeMatcher(repo).factsOf(r);
    expect(f.perServing.kcal, inInclusiveRange(300, 900));
    expect(f.perServing.protein, greaterThan(20));
    expect(f.costPerServing, inInclusiveRange(30, 200));
  });

  test('eski kayıtta "1 tutam salça" 2 yemek kaşığına döner', () {
    final r = Recipe.fromJson({
      ...extractor
          .extract('Malzemeler: 300 gr tavuk göğsü, salça',
              id: 'm2', source: src)
          .recipe
          .toJson(),
    });
    final old = Recipe.fromJson({
      ...r.toJson(),
      'items': [
        for (final i in r.items)
          {
            ...i.toJson(),
            if (i.ingredientId == 'salca') ...{
              'amount': 1,
              'measure': Measure.tutam.name
            },
          }
      ],
    });
    final fixed = extractor.repairedItems(old)!;
    final salca = fixed.firstWhere((j) => j['ingredient'] == 'salca');
    expect(salca['measure'], Measure.yemekKasigi.name);
    expect(
        extractor
            .repairedItems(Recipe.fromJson({...old.toJson(), 'items': fixed})),
        isNull);
  });
}
