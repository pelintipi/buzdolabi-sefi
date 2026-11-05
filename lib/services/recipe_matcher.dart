import 'dart:math' as math;

import '../models/ingredient.dart';
import '../models/recipe.dart';
import '../models/user_profile.dart';
import 'collections.dart';
import 'ingredient_repository.dart';
import 'nutrition_review.dart';

export 'nutrition_review.dart';
import 'unit_converter.dart';

/// Dolabın eşleştirme için gram cinsinden anlık görüntüsü.
class PantrySnapshot {
  const PantrySnapshot({
    required this.gramsById,
    this.expiringIds = const {},
    this.stapleIds = const {},
  });

  final Map<String, double> gramsById;

  /// Son kullanma tarihi 2 gün içinde dolanlar.
  final Set<String> expiringIds;

  /// Evde var sayılan temel malzemeler (sınırsız kabul edilir).
  final Set<String> stapleIds;

  /// Tarifin istediği malzeme için kullanılabilecek toplam miktar.
  /// Alt türler de sayılır: "peynir" için kaşar + beyaz peynir.
  double availableFor(String ingredientId, IngredientRepository repo) {
    if (stapleIds.contains(ingredientId)) return double.infinity;
    var total = 0.0;
    gramsById.forEach((id, grams) {
      if (repo.isSameOrDescendant(id, ingredientId)) total += grams;
    });
    return total;
  }

  bool usesExpiring(String ingredientId, IngredientRepository repo) =>
      expiringIds.any((id) => repo.isSameOrDescendant(id, ingredientId));
}

class RecipeFacts {
  const RecipeFacts({
    required this.perServing,
    required this.costPerServing,
    required this.allergens,
    required this.isVegetarian,
    required this.isVegan,
    required this.review,
  });

  final Nutrition perServing;
  final double costPerServing;

  /// İsteğe bağlı malzemeler dahil (güvenlik için).
  final Set<Allergen> allergens;
  final bool isVegetarian;
  final bool isVegan;

  /// Porsiyonun protein, karbonhidrat ve yağ dengesine göre değerlendirmesi.
  final NutritionReview review;
}

enum ItemState { enough, short, missing, substituted, staple }

class ItemCheck {
  const ItemCheck({
    required this.item,
    required this.requiredGrams,
    required this.availableGrams,
    required this.state,
    this.substitute,
    bool? blocks,
  }) : blocks =
            blocks ?? (state == ItemState.short || state == ItemState.missing);

  final RecipeItem item;
  final double requiredGrams;
  final double availableGrams;
  final ItemState state;
  final Substitute? substitute;

  /// Tarifi yapmayı engelliyor mu? Az ama en az bir porsiyona yetiyorsa
  /// engellemez (daha az porsiyon çıkar).
  final bool blocks;

  double get sufficiency =>
      requiredGrams <= 0 ? 1.0 : math.min(availableGrams / requiredGrams, 1.0);

  bool get isProblem => blocks;

  /// Pişirince dolaptan düşülecek malzeme (alternatif kullanıldıysa o).
  String get usedIngredientId => substitute?.ingredientId ?? item.ingredientId;
}

/// Sıralama önceliği de bu sıradır.
enum MatchGroup { ready, substitute, almost, far }

class RecipeMatch {
  const RecipeMatch({
    required this.recipe,
    required this.facts,
    required this.checks,
    required this.score,
    required this.group,
    required this.maxServings,
    required this.usesExpiring,
  });

  final Recipe recipe;
  final RecipeFacts facts;
  final List<ItemCheck> checks;

  /// 0-1 arası, ana malzemeler 3 kat ağırlıklı.
  final double score;
  final MatchGroup group;

  /// Eldeki miktarlarla yapılabilecek porsiyon (yarım porsiyon adımlarıyla).
  final double maxServings;
  final bool usesExpiring;

  List<ItemCheck> get problems => [
        for (final c in checks)
          if (!c.item.optional && c.isProblem) c
      ];

  /// "Az kaldı" grubundaki tek eksik/yetersiz malzeme.
  ItemCheck? get blocking {
    final p = problems;
    return p.length == 1 ? p.first : null;
  }
}

class QuickFilters {
  const QuickFilters({
    this.quick = false,
    this.highProtein = false,
    this.vegetarian = false,
    this.economic = false,
    this.onePot = false,
    this.breakfast = false,
    this.kind,
  });

  static const highProteinGrams = 20.0;
  static const economicTl = 60.0;

  final bool quick;
  final bool highProtein;
  final bool vegetarian;
  final bool economic;
  final bool onePot;
  final bool breakfast;

  /// Yalnızca yemekler, atıştırmalıklar ya da tatlılar; null ise hepsi.
  final DishKind? kind;

  bool get isEmpty =>
      kind == null &&
      !quick &&
      !highProtein &&
      !vegetarian &&
      !economic &&
      !onePot &&
      !breakfast;

  QuickFilters copyWith({
    bool? quick,
    bool? highProtein,
    bool? vegetarian,
    bool? economic,
    bool? onePot,
    bool? breakfast,
  }) =>
      QuickFilters(
        quick: quick ?? this.quick,
        highProtein: highProtein ?? this.highProtein,
        vegetarian: vegetarian ?? this.vegetarian,
        economic: economic ?? this.economic,
        onePot: onePot ?? this.onePot,
        breakfast: breakfast ?? this.breakfast,
        kind: kind,
      );

  QuickFilters withKind(DishKind? kind) => QuickFilters(
        quick: quick,
        highProtein: highProtein,
        vegetarian: vegetarian,
        economic: economic,
        onePot: onePot,
        breakfast: breakfast,
        kind: kind,
      );

  bool accepts(Recipe r, RecipeFacts f) =>
      (kind == null || kindOf(r) == kind) &&
      (!quick || r.minutes <= 15) &&
      (!highProtein || f.perServing.protein >= highProteinGrams) &&
      (!vegetarian || f.isVegetarian) &&
      (!economic || f.costPerServing <= economicTl) &&
      (!onePot || r.tags.contains('tek_kap')) &&
      (!breakfast || r.tags.contains('kahvalti'));
}

/// Sonuçları sıralama ölçütü. [recommended] eşleşme grubuna göre sıralar.
enum SortMode {
  recommended('Önerilen', '✨'),
  fastest('En hızlı', '⚡'),
  balanced('En dengeli', '⚖'),
  protein('En çok protein', '💪'),
  light('En hafif', '🪶');

  const SortMode(this.label, this.icon);

  final String label;
  final String icon;
}

/// Yapılabilir seçenekler arasında öne çıkanlar (kartlardaki rozetler için).
enum Highlight {
  fastest('En hızlı', '⚡'),
  balanced('En dengeli', '⚖'),
  protein('En proteinli', '💪'),
  light('En hafif', '🪶');

  const Highlight(this.label, this.icon);

  final String label;
  final String icon;
}

/// [options] içinde her ölçütte birinci olan tarif. Tek seçenek varsa rozet yok.
/// Besinle ilgili rozetler yalnızca hak edene verilir: 5 g proteinli bir
/// tarif, diğerlerinden fazla olsa bile "En proteinli" olmaz.
Map<String, Set<Highlight>> highlightsFor(List<RecipeMatch> options) {
  if (options.length < 2) return const {};
  final result = <String, Set<Highlight>>{};
  void mark(RecipeMatch best, Highlight h) =>
      result.putIfAbsent(best.recipe.id, () => {}).add(h);
  RecipeMatch pick(int Function(RecipeMatch a, RecipeMatch b) better) =>
      options.reduce((a, b) => better(a, b) <= 0 ? a : b);

  mark(pick((a, b) => a.recipe.minutes.compareTo(b.recipe.minutes)),
      Highlight.fastest);
  final balanced = pick((a, b) =>
      b.facts.review.balanceScore.compareTo(a.facts.review.balanceScore));
  if (balanced.facts.review.tone == ReviewTone.good) {
    mark(balanced, Highlight.balanced);
  }
  final protein = pick((a, b) =>
      b.facts.perServing.protein.compareTo(a.facts.perServing.protein));
  if (protein.facts.review.isProteinSource) mark(protein, Highlight.protein);
  final light = pick(
      (a, b) => a.facts.perServing.kcal.compareTo(b.facts.perServing.kcal));
  if (light.facts.review.isLight) mark(light, Highlight.light);
  return result;
}

/// Seçenekleri ölçüte göre sıralar (yerinde değil, yeni liste döner).
List<RecipeMatch> sortOptions(List<RecipeMatch> options, SortMode mode) {
  final list = List.of(options);
  switch (mode) {
    case SortMode.recommended:
      break;
    case SortMode.fastest:
      list.sort((a, b) => a.recipe.minutes.compareTo(b.recipe.minutes));
    case SortMode.protein:
      list.sort((a, b) =>
          b.facts.perServing.protein.compareTo(a.facts.perServing.protein));
    case SortMode.balanced:
      list.sort((a, b) =>
          b.facts.review.balanceScore.compareTo(a.facts.review.balanceScore));
    case SortMode.light:
      list.sort(
          (a, b) => a.facts.perServing.kcal.compareTo(b.facts.perServing.kcal));
  }
  return list;
}

class UnlockSuggestion {
  const UnlockSuggestion(this.ingredient, this.recipeCount);

  final Ingredient ingredient;
  final int recipeCount;
}

class RecipeMatcher {
  RecipeMatcher(this.repo);

  final IngredientRepository repo;
  final _factsCache = <String, RecipeFacts>{};

  RecipeFacts factsOf(Recipe r) =>
      _factsCache.putIfAbsent(r.id, () => _analyze(r));

  /// Tarif değiştiyse (videodan kaydedilen tarif düzenlendi) önbellekten çıkarır.
  void forget(String recipeId) => _factsCache.remove(recipeId);

  RecipeFacts _analyze(Recipe r) {
    var nutrition = Nutrition.zero;
    var cost = 0.0;
    final allergens = <Allergen>{};
    final tags = <FoodTag>{};
    for (final item in r.items) {
      final ing = repo.byId(item.ingredientId);
      allergens.addAll(repo.allergensOf(ing.id));
      tags.addAll(repo.tagsOf(ing.id));
      if (item.optional) continue;
      final grams = UnitConverter.toGrams(ing, item.amount, item.measure);
      nutrition = nutrition + ing.per100g.scale(grams / 100);
      cost += ing.pricePerKg * grams / 1000;
    }
    return RecipeFacts(
      perServing: nutrition.scale(1 / r.servings),
      costPerServing: cost / r.servings,
      allergens: allergens,
      isVegetarian:
          !tags.contains(FoodTag.meat) && !tags.contains(FoodTag.fish),
      isVegan: tags.isEmpty,
      review: NutritionReview.of(nutrition.scale(1 / r.servings),
          category: categoryOf(r)),
    );
  }

  /// Profil kuralları (alerji, diyet, mutfak aletleri) her aramada uygulanır.
  bool passesProfile(Recipe r, UserProfile profile) {
    final facts = factsOf(r);
    if (facts.allergens.any(profile.allergies.contains)) return false;
    if (profile.diet == Diet.vegan && !facts.isVegan) return false;
    if (profile.diet == Diet.vegetarian && !facts.isVegetarian) return false;
    if (!profile.appliances.containsAll(r.appliances)) return false;
    return true;
  }

  RecipeMatch evaluate(Recipe r, PantrySnapshot pantry, {int? servings}) {
    final s = servings ?? r.servings;
    final scale = s / r.servings;
    final checks = <ItemCheck>[];
    var weighted = 0.0;
    var totalWeight = 0.0;
    var minRatio = double.infinity;
    var expiring = false;

    for (final item in r.items) {
      final ing = repo.byId(item.ingredientId);
      final needed =
          UnitConverter.toGrams(ing, item.amount * scale, item.measure);

      if (pantry.stapleIds.contains(ing.id)) {
        checks.add(ItemCheck(
            item: item,
            requiredGrams: needed,
            availableGrams: double.infinity,
            state: ItemState.staple));
        continue;
      }

      final available = pantry.availableFor(ing.id, repo);
      if (available > 0 && pantry.usesExpiring(ing.id, repo)) expiring = true;

      var state = available >= needed * 0.999
          ? ItemState.enough
          : available > 0
              ? ItemState.short
              : ItemState.missing;
      Substitute? substitute;
      if (state != ItemState.enough) {
        for (final candidate in item.substitutes) {
          if (pantry.availableFor(candidate.ingredientId, repo) >=
              needed * 0.999) {
            substitute = candidate;
            state = ItemState.substituted;
            break;
          }
        }
      }

      final check = ItemCheck(
          item: item,
          requiredGrams: needed,
          availableGrams: available,
          state: state,
          substitute: substitute,
          // Tarifin kendi porsiyonunda bir porsiyonluk malzeme varsa az
          // olması tarifi engellemez (daha az porsiyon çıkar). Kişi sayısı
          // elle seçildiyse o kadarı için yetmesi gerekir.
          blocks: state == ItemState.missing ||
              (state == ItemState.short &&
                  (servings != null || available < needed / s * 0.999)));
      checks.add(check);

      if (item.optional) continue;
      final weight = item.isMain ? 3.0 : 1.0;
      totalWeight += weight;
      weighted +=
          weight * (state == ItemState.substituted ? 1.0 : check.sufficiency);
      if (state != ItemState.substituted && needed > 0) {
        minRatio = math.min(minRatio, available / needed);
      }
    }

    final problemCount =
        checks.where((c) => !c.item.optional && c.isProblem).length;
    final usedSubstitute =
        checks.any((c) => !c.item.optional && c.state == ItemState.substituted);
    // Ana malzemelerin hiçbiri elde yoksa, yalnızca alternatiflerle tarif
    // "yapılabilir" sayılmaz (domatessiz domates çorbası olmaz).
    final hasRealMain = checks.any((c) =>
        c.item.isMain &&
        (c.state == ItemState.enough ||
            c.state == ItemState.staple ||
            (c.state == ItemState.short && !c.blocks)));
    final group = problemCount == 0
        ? (usedSubstitute
            ? (hasRealMain ? MatchGroup.substitute : MatchGroup.far)
            : MatchGroup.ready)
        : problemCount == 1
            ? MatchGroup.almost
            : MatchGroup.far;
    final ratio = minRatio == double.infinity ? 1.0 : minRatio;

    return RecipeMatch(
      recipe: r,
      facts: factsOf(r),
      checks: checks,
      score: totalWeight == 0 ? 1.0 : weighted / totalWeight,
      group: group,
      maxServings: (s * ratio * 2).floor() / 2,
      usesExpiring: expiring,
    );
  }

  List<RecipeMatch> rank(
    List<Recipe> recipes,
    PantrySnapshot pantry,
    UserProfile profile,
    QuickFilters filters,
  ) {
    final result = [
      for (final r in recipes)
        if (passesProfile(r, profile) && filters.accepts(r, factsOf(r)))
          evaluate(r, pantry),
    ];
    // Bozulmak üzere olan malzemeyi kullanan tarifler öne çıkar.
    double sortScore(RecipeMatch m) => m.score + (m.usesExpiring ? 0.1 : 0);
    result.sort((a, b) {
      final g = a.group.index.compareTo(b.group.index);
      if (g != 0) return g;
      final sc = sortScore(b).compareTo(sortScore(a));
      if (sc != 0) return sc;
      return a.recipe.minutes.compareTo(b.recipe.minutes);
    });
    return result;
  }

  /// "Sadece süt alırsan 3 tarif açılır": tek eksiği olan tarifleri,
  /// eksik malzemeye göre sayar.
  List<UnlockSuggestion> unlockSuggestions(List<RecipeMatch> matches) {
    final counts = <String, int>{};
    for (final m in matches) {
      final b = m.blocking;
      if (m.group != MatchGroup.almost || b == null) continue;
      counts.update(b.item.ingredientId, (v) => v + 1, ifAbsent: () => 1);
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [
      for (final e in sorted) UnlockSuggestion(repo.byId(e.key), e.value)
    ];
  }
}
