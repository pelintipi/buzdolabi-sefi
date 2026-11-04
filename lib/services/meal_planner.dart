import 'dart:math' as math;

import '../models/recipe.dart';
import '../models/user_profile.dart';
import 'ingredient_repository.dart';
import 'recipe_matcher.dart';

/// Planın bir akşamı: tarif ve o güne kadar dolaptan harcananlara göre durumu.
class PlanNight {
  const PlanNight({required this.recipe, required this.match});

  final Recipe recipe;

  /// Önceki akşamların kullandığı malzemeler düşüldükten sonraki eşleşme.
  final RecipeMatch match;

  bool get ready => match.problems.isEmpty;
}

/// Haftalık plan: dolaptakileri akşamlara paylaştırır. Bir malzeme pazartesi
/// kullanıldıysa salı aynı malzemeyi tekrar "var" saymaz.
class MealPlanner {
  MealPlanner(this.matcher, this.repo);

  final RecipeMatcher matcher;
  final IngredientRepository repo;

  /// Akşam yemeğine uymayan etiketler.
  static const _notDinner = {'kahvalti', 'tatli'};

  bool isDinnerCandidate(Recipe r) => r.tags.intersection(_notDinner).isEmpty;

  /// [nights] akşamlık plan çıkarır. [keep]: kullanıcının sabitlediği akşamlar
  /// (indeks → tarif), [avoid]: önerilmeyecek tarifler.
  List<String> plan({
    required List<Recipe> recipes,
    required PantrySnapshot pantry,
    required UserProfile profile,
    required int nights,
    Map<int, String> keep = const {},
    Set<String> avoid = const {},
  }) {
    final candidates = [
      for (final r in recipes)
        if (isDinnerCandidate(r) && matcher.passesProfile(r, profile)) r
    ];
    final byId = {for (final r in recipes) r.id: r};
    final chosen = <String>[];
    var current = pantry;
    for (var night = 0; night < nights; night++) {
      final kept = keep[night];
      Recipe? pick = kept == null ? null : byId[kept];
      if (pick == null) {
        double bestScore = -1e9;
        for (final r in candidates) {
          if (chosen.contains(r.id) || avoid.contains(r.id)) continue;
          final s = _score(r, current, profile, chosen.map((id) => byId[id]!));
          if (s > bestScore) {
            bestScore = s;
            pick = r;
          }
        }
      }
      if (pick == null) break;
      chosen.add(pick.id);
      current = _consume(current,
          matcher.evaluate(pick, current, servings: _servings(pick, profile)));
    }
    return chosen;
  }

  /// Planı sırayla değerlendirir: her akşam, öncekilerin harcadıkları düşülmüş
  /// dolaba göre.
  List<PlanNight> evaluate({
    required List<String> recipeIds,
    required List<Recipe> recipes,
    required PantrySnapshot pantry,
    required UserProfile profile,
  }) {
    final byId = {for (final r in recipes) r.id: r};
    final out = <PlanNight>[];
    var current = pantry;
    for (final id in recipeIds) {
      final r = byId[id];
      if (r == null) continue;
      final m = matcher.evaluate(r, current, servings: _servings(r, profile));
      out.add(PlanNight(recipe: r, match: m));
      current = _consume(current, m);
    }
    return out;
  }

  /// Planın tamamı için alınması gerekenler (tekrarsız).
  Set<String> missing(List<PlanNight> nights) => {
        for (final n in nights)
          for (final c in n.match.problems) c.item.ingredientId
      };

  static bool _isSoup(Recipe r) => r.title.contains('Çorba');

  int _servings(Recipe r, UserProfile p) => p.household?.servings ?? r.servings;

  double _score(Recipe r, PantrySnapshot pantry, UserProfile profile,
      Iterable<Recipe> already) {
    final m = matcher.evaluate(r, pantry, servings: _servings(r, profile));
    var s = m.score * 10;
    s += switch (m.group) {
      MatchGroup.ready => 6,
      MatchGroup.substitute => 4,
      MatchGroup.almost => 1,
      MatchGroup.far => -4,
    };
    if (m.usesExpiring) s += 3;
    // Aynı ana malzeme üst üste gelmesin (her akşam tavuk olmasın).
    final mains = {
      for (final i in r.items)
        if (i.isMain) i.ingredientId
    };
    for (final prev in already) {
      final prevMains = {
        for (final i in prev.items)
          if (i.isMain) i.ingredientId
      };
      if (mains.intersection(prevMains).isNotEmpty) s -= 4;
      if (_isSoup(prev) && _isSoup(r)) s -= 2;
    }
    final facts = m.facts.perServing;
    if (profile.eating == EatingStyle.protein) {
      s += math.min(facts.protein, 40) / 10;
    }
    if (profile.eating == EatingStyle.light) {
      s -= math.max(0, facts.kcal - 450) / 150;
    }
    return s;
  }

  /// Eşleşmede "var" sayılan miktarları sanal dolaptan düşer.
  PantrySnapshot _consume(PantrySnapshot p, RecipeMatch m) {
    final grams = Map<String, double>.of(p.gramsById);
    void take(String ingredientId, double amount) {
      var left = amount;
      for (final id in grams.keys.toList()) {
        if (left <= 0) break;
        if (!repo.isSameOrDescendant(id, ingredientId)) continue;
        final used = math.min(grams[id]!, left);
        grams[id] = grams[id]! - used;
        left -= used;
        if (grams[id]! <= 0.5) grams.remove(id);
      }
    }

    for (final c in m.checks) {
      switch (c.state) {
        case ItemState.enough:
        case ItemState.short:
          take(c.item.ingredientId, c.requiredGrams);
        case ItemState.substituted:
          take(c.substitute!.ingredientId, c.requiredGrams);
        case ItemState.missing:
        case ItemState.staple:
          break;
      }
    }
    return PantrySnapshot(
        gramsById: grams, expiringIds: p.expiringIds, stapleIds: p.stapleIds);
  }
}
