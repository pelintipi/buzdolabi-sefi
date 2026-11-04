import '../models/recipe.dart';
import 'recipe_matcher.dart';
import 'turkish_text.dart';

/// Kategorisi olmayan (videodan kaydedilen) tarifler için tahmin.
RecipeCategory guessCategory(Recipe r) {
  final title = TurkishText.fold(r.title);
  final ids = {for (final i in r.items) i.ingredientId};
  if (title.contains('corba')) return RecipeCategory.corba;
  if (r.tags.contains('kahvalti')) return RecipeCategory.kahvalti;
  if (r.tags.contains('tatli') ||
      RegExp(r'kek|tatli|kurabiye|helva|puding|muhallebi|sutlac|brownie|cheesecake')
          .hasMatch(title)) {
    return RecipeCategory.tatli;
  }
  if (RegExp(r'salata|cacik|meze|ezme|tarator').hasMatch(title)) {
    return RecipeCategory.salata;
  }
  if (RegExp(r'omlet|menemen|krep|pankek|tost').hasMatch(title) ||
      (ids.contains('yumurta') && r.minutes <= 15 && ids.length <= 5)) {
    return RecipeCategory.kahvalti;
  }
  if (RegExp(r'cips|kroket|atistirmalik|dip|cubuk').hasMatch(title)) {
    return RecipeCategory.atistirmalik;
  }
  return RecipeCategory.anaYemek;
}

RecipeCategory categoryOf(Recipe r) => r.category ?? guessCategory(r);

/// Kendiliğinden dolan koleksiyon: yemek türü ya da ölçülebilir bir özellik.
/// "Sağlıklı / sağlıksız" gibi yargı içeren etiket kullanılmaz; değerler
/// tahminidir.
class SmartCollection {
  const SmartCollection(
      this.id, this.title, this.emoji, this.description, this.test);

  final String id;
  final String title;
  final String emoji;
  final String description;
  final bool Function(Recipe r, RecipeFacts f) test;
}

final smartCollections = <SmartCollection>[
  for (final c in RecipeCategory.values)
    SmartCollection('kategori_${c.name}', c.label, c.emoji,
        '${c.label} tarifleri', (r, _) => categoryOf(r) == c),
  SmartCollection(
      'yuksek_protein',
      'Yüksek protein',
      '💪',
      'Porsiyonda 20 g ve üstü protein',
      (_, f) => f.perServing.protein >= QuickFilters.highProteinGrams),
  SmartCollection(
      'hafif',
      'Hafif',
      '🪶',
      'Porsiyonda 400 kcal altı',
      (r, f) =>
          f.perServing.kcal < 400 && categoryOf(r) != RecipeCategory.tatli),
  SmartCollection(
      'doyurucu',
      'Doyurucu',
      '🔥',
      'Porsiyonda 550 kcal ve üstü',
      (r, f) =>
          f.perServing.kcal >= 550 && categoryOf(r) != RecipeCategory.tatli),
  SmartCollection('hizli', '15 dakikada', '⏱', '15 dakika ve altı',
      (r, _) => r.minutes <= 15),
  SmartCollection(
      'ekonomik',
      'Ekonomik',
      '💰',
      'Porsiyonu yaklaşık ${QuickFilters.economicTl.round()} ₺ altı',
      (_, f) => f.costPerServing <= QuickFilters.economicTl),
  SmartCollection('vejetaryen', 'Vejetaryen', '🥦', 'Et ve balık yok',
      (_, f) => f.isVegetarian),
];

/// Kullanıcının kendi koleksiyonu ("Misafir menüsü", "Annemin tarifleri").
class UserCollection {
  const UserCollection(
      {required this.id,
      required this.name,
      required this.emoji,
      this.recipeIds = const []});

  final String id;
  final String name;
  final String emoji;

  /// Eklenme sırasıyla (en yeni sonda).
  final List<String> recipeIds;

  UserCollection copyWith(
          {String? name, String? emoji, List<String>? recipeIds}) =>
      UserCollection(
          id: id,
          name: name ?? this.name,
          emoji: emoji ?? this.emoji,
          recipeIds: recipeIds ?? this.recipeIds);

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'emoji': emoji, 'recipes': recipeIds};

  factory UserCollection.fromJson(Map<String, dynamic> j) => UserCollection(
        id: j['id'] as String,
        name: j['name'] as String,
        emoji: j['emoji'] as String? ?? '📁',
        recipeIds: [
          for (final r in (j['recipes'] as List? ?? const [])) r as String
        ],
      );
}

/// Koleksiyon oluştururken seçilebilen ikonlar (hepsinin 3D karşılığı var).
const collectionEmojis = [
  '⭐',
  '❤',
  '🎉',
  '🏠',
  '💪',
  '🪶',
  '🍰',
  '🍲',
  '🥗',
  '🍝',
  '🔥',
  '🌱'
];

/// "Yaptıklarım": bir tarifi kaç kez, en son ne zaman pişirdin.
class CookedSummary {
  const CookedSummary(
      {required this.recipe,
      required this.times,
      required this.last,
      this.bestRating,
      this.photoPath});

  final Recipe recipe;
  final int times;
  final DateTime last;
  final int? bestRating;
  final String? photoPath;
}
