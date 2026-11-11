import 'package:buzdolabi_sefi/models/cook_log.dart';
import 'package:buzdolabi_sefi/services/ingredient_repository.dart';
import 'package:buzdolabi_sefi/services/storage_service.dart';
import 'package:buzdolabi_sefi/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/test_catalog.dart';

Future<AppState> _state() async {
  SharedPreferences.setMockInitialValues({});
  final s = AppState(
    repo: IngredientRepository(ingredientCatalog),
    recipes: recipeCatalog,
    storage: StorageService(),
  );
  await s.load();
  return s;
}

void main() {
  test('CookLog not JSON gidiş dönüş', () {
    final log = CookLog(
      recipeId: 'menemen',
      cookedAt: DateTime(2026, 11, 11, 18),
      servings: 2,
      rating: 4,
      note: '  Tuzu azalttım  ',
    );
    final back = CookLog.fromJson(log.toJson());
    expect(back.note, 'Tuzu azalttım');
    expect(back.rating, 4);
    expect(CookLog.fromJson(CookLog(
      recipeId: 'x',
      cookedAt: DateTime(2026, 1, 1),
      servings: 1,
    ).toJson())
        .note, isNull);
  });

  test('pişirme notu sonraki sefere hatırlatılır', () async {
    final s = await _state();
    final recipe = s.recipeById('menemen');
    expect(s.lastCookMemory(recipe.id), isNull);

    s.recordCook(recipe, 2, const {}, rating: 5, note: 'Tuzu azalttım');
    final memory = s.lastCookMemory(recipe.id);
    expect(memory?.note, 'Tuzu azalttım');
    expect(memory?.rating, 5);

    // Yeni pişirmede not yoksa eski not, yeni puan kullanılır.
    s.recordCook(recipe, 2, const {}, rating: 3);
    final again = s.lastCookMemory(recipe.id)!;
    expect(again.note, 'Tuzu azalttım');
    expect(again.rating, 3);
  });
}
