import 'package:buzdolabi_sefi/models/measure.dart';
import 'package:buzdolabi_sefi/models/recipe.dart';
import 'package:buzdolabi_sefi/services/collections.dart';
import 'package:buzdolabi_sefi/services/ingredient_repository.dart';
import 'package:buzdolabi_sefi/services/storage_service.dart';
import 'package:buzdolabi_sefi/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/test_catalog.dart';

void main() {
  final repo = IngredientRepository(ingredientCatalog);

  Future<AppState> freshState() async {
    SharedPreferences.setMockInitialValues({});
    final s =
        AppState(repo: repo, recipes: recipeCatalog, storage: StorageService());
    await s.load();
    return s;
  }

  test('katalogdaki her tarifin yemek türü var ve her türde yeterince tarif',
      () {
    final counts = <RecipeCategory, int>{};
    for (final r in recipeCatalog) {
      expect(r.category, isNotNull, reason: r.title);
      counts.update(r.category!, (v) => v + 1, ifAbsent: () => 1);
    }
    expect(counts[RecipeCategory.anaYemek], greaterThanOrEqualTo(30));
    expect(counts[RecipeCategory.kahvalti], greaterThanOrEqualTo(20));
    expect(counts[RecipeCategory.corba], greaterThanOrEqualTo(8));
    expect(counts[RecipeCategory.tatli], greaterThanOrEqualTo(5));
    expect(counts[RecipeCategory.atistirmalik], greaterThanOrEqualTo(5));
    expect(counts[RecipeCategory.salata], greaterThanOrEqualTo(8));
  });

  test('videodan gelen tarifin türü tahmin edilir', () {
    Recipe r(String title, {Set<String> tags = const {}}) => Recipe(
          id: 'x',
          title: title,
          emoji: '🍽️',
          minutes: 30,
          difficulty: Difficulty.kolay,
          servings: 2,
          items: const [
            RecipeItem(
                ingredientId: 'tavuk_gogsu',
                amount: 300,
                measure: Measure.gram),
            RecipeItem(ingredientId: 'sogan', amount: 1, measure: Measure.adet),
          ],
          steps: const [RecipeStep('Pişir.')],
          tags: tags,
        );
    expect(guessCategory(r('Kremalı mantarlı tavuk')), RecipeCategory.anaYemek);
    expect(guessCategory(r('Muzlu kek')), RecipeCategory.tatli);
    expect(guessCategory(r('Süzme mercimek çorbası')), RecipeCategory.corba);
    expect(guessCategory(r('Gavurdağı salatası')), RecipeCategory.salata);
  });

  test('hazır koleksiyonlar ölçüye uyar; tatlılar "hafif"e girmez', () async {
    final s = await freshState();
    SmartCollection get(String id) =>
        smartCollections.firstWhere((c) => c.id == id);
    final protein = s.recipesInSmart(get('yuksek_protein'));
    expect(protein, isNotEmpty);
    for (final r in protein) {
      expect(s.matcher.factsOf(r).perServing.protein, greaterThanOrEqualTo(20));
    }
    final light = s.recipesInSmart(get('hafif'));
    expect(light.any((r) => r.category == RecipeCategory.tatli), isFalse);
    expect(s.recipesInSmart(get('kategori_tatli')).map((r) => r.id),
        contains('sutlac'));
  });

  test('kendi koleksiyonu: oluştur, ekle-çıkar, yeniden adlandır, sakla, sil',
      () async {
    final s = await freshState();
    final c =
        s.createCollection('Misafir menüsü', '🎉', firstRecipe: 'karniyarik');
    s.toggleInCollection(c.id, 'sutlac');
    s.toggleInCollection(c.id, 'mercimek_corbasi');
    s.toggleInCollection(c.id, 'sutlac'); // çıkar
    expect(s.recipesIn(s.collectionById(c.id)!).map((r) => r.id),
        ['karniyarik', 'mercimek_corbasi']);
    s.renameCollection(c.id, 'Bayram sofrası', '⭐');

    await Future<void>.delayed(Duration.zero);
    final again =
        AppState(repo: repo, recipes: recipeCatalog, storage: StorageService());
    await again.load();
    final loaded = again.collections.single;
    expect(loaded.name, 'Bayram sofrası');
    expect(loaded.emoji, '⭐');
    expect(loaded.recipeIds, ['karniyarik', 'mercimek_corbasi']);

    again.deleteCollection(loaded.id);
    expect(again.collections, isEmpty);
  });

  test('Yaptıklarım: tarif başına kaç kez ve en yeni önde', () async {
    final s = await freshState();
    s.recordCook(s.recipeById('menemen'), 2, const {}, rating: 4);
    s.recordCook(s.recipeById('mercimek_corbasi'), 4, const {});
    s.recordCook(s.recipeById('menemen'), 2, const {}, rating: 5);
    final cooked = s.cookedSummaries;
    expect(cooked.map((c) => c.recipe.id), ['menemen', 'mercimek_corbasi']);
    expect(cooked.first.times, 2);
    expect(cooked.first.bestRating, 5);
  });
}
