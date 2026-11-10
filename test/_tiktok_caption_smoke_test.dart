import 'dart:io';

import 'package:buzdolabi_sefi/services/caption_recipe_extractor.dart';
import 'package:buzdolabi_sefi/services/ingredient_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_catalog.dart';

void main() {
  test('sample tiktok caption extracts ingredients', () async {
    final caption = await File('tool/_sample_caption.txt').readAsString();
    final x = CaptionRecipeExtractor(IngredientRepository(ingredientCatalog))
        .extract(caption, id: 't');
    // ignore: avoid_print
    print(
        'ITEMS=${x.recipe.items.length} usable=${x.isUsable} title=${x.recipe.title}');
    for (final i in x.recipe.items.take(10)) {
      // ignore: avoid_print
      print('- ${i.ingredientId}');
    }
    expect(x.isUsable, isTrue);
  });
}
