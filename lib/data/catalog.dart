import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/ingredient.dart';
import '../models/recipe.dart';

/// Malzeme ve tarif kataloğu: assets/data/*.json dosyalarından okunur.
/// Hatalı bir tarif uygulamayı çökertmez; atlanır ve [problems]'a yazılır.
class Catalog {
  const Catalog({
    required this.ingredients,
    required this.recipes,
    this.problems = const [],
  });

  static const ingredientsAsset = 'assets/data/ingredients.json';
  static const recipesAsset = 'assets/data/recipes.json';

  final List<Ingredient> ingredients;
  final List<Recipe> recipes;
  final List<String> problems;

  static Future<Catalog> load(AssetBundle bundle) async => Catalog.parse(
        await bundle.loadString(ingredientsAsset),
        await bundle.loadString(recipesAsset),
      );

  factory Catalog.parse(String ingredientsJson, String recipesJson) {
    final problems = <String>[];

    final ingredients = <Ingredient>[];
    final ingredientIds = <String>{};
    final rawIngredients = (jsonDecode(ingredientsJson)
        as Map<String, dynamic>)['ingredients'] as List;
    for (final raw in rawIngredients) {
      final map = raw as Map<String, dynamic>;
      try {
        final ing = Ingredient.fromJson(map);
        if (!ingredientIds.add(ing.id)) {
          problems.add('Malzeme "${ing.id}" iki kez tanımlı');
          continue;
        }
        ingredients.add(ing);
      } catch (e) {
        problems.add('Malzeme "${map['id']}" okunamadı: $e');
      }
    }
    for (final ing in ingredients) {
      if (ing.parentId != null && !ingredientIds.contains(ing.parentId)) {
        problems.add('Malzeme "${ing.id}": üst kategori "${ing.parentId}" yok');
      }
    }

    final recipes = <Recipe>[];
    final recipeIds = <String>{};
    final rawRecipes =
        (jsonDecode(recipesJson) as Map<String, dynamic>)['recipes'] as List;
    for (final raw in rawRecipes) {
      final map = raw as Map<String, dynamic>;
      final Recipe recipe;
      try {
        recipe = Recipe.fromJson(map);
      } catch (e) {
        problems.add('Tarif "${map['id']}" okunamadı: $e');
        continue;
      }
      final errors = [
        if (!recipeIds.add(recipe.id)) 'iki kez tanımlı',
        if (recipe.servings <= 0) 'porsiyon 0',
        if (recipe.items.isEmpty) 'malzemesi yok',
        if (recipe.steps.isEmpty) 'adımı yok',
        for (final item in recipe.items) ...[
          if (!ingredientIds.contains(item.ingredientId))
            'bilinmeyen malzeme "${item.ingredientId}"',
          if (item.amount <= 0) '"${item.ingredientId}" miktarı 0',
          for (final s in item.substitutes)
            if (!ingredientIds.contains(s.ingredientId))
              'bilinmeyen alternatif "${s.ingredientId}"',
        ],
      ];
      if (errors.isNotEmpty) {
        problems.add('Tarif "${recipe.id}" atlandı: ${errors.join(', ')}');
        continue;
      }
      recipes.add(recipe);
    }

    return Catalog(
        ingredients: ingredients, recipes: recipes, problems: problems);
  }
}
