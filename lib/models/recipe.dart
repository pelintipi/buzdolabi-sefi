import 'json_helpers.dart';
import 'measure.dart';
import 'recipe_source.dart';

export 'recipe_source.dart';

enum Difficulty {
  kolay('Kolay'),
  orta('Orta'),
  zor('Zor');

  const Difficulty(this.label);

  final String label;
}

enum Appliance {
  ocak('Ocak', '🔥'),
  firin('Fırın', '♨️'),
  airfryer('Airfryer', '💨'),
  blender('Blender', '🌀');

  const Appliance(this.label, this.emoji);

  final String label;
  final String emoji;
}

/// Beceri ağacında takip edilen pişirme teknikleri.
enum Technique {
  cig('Çiğ hazırlık', '🔪'),
  haslama('Haşlama', '♨️'),
  sote('Sote', '🍳'),
  kizartma('Kızartma', '🍤'),
  firin('Fırında pişirme', '🔥'),
  karistirma('Karıştırma', '🥄');

  const Technique(this.label, this.emoji);

  final String label;
  final String emoji;
}

/// Yemeğin türü: koleksiyonlarda ve filtrelerde kullanılır.
enum RecipeCategory {
  kahvalti('Kahvaltı', '🍳'),
  corba('Çorba', '🍲'),
  anaYemek('Ana yemek', '🍽'),
  salata('Salata ve meze', '🥗'),
  atistirmalik('Atıştırmalık', '🥨'),
  tatli('Tatlı', '🍰');

  const RecipeCategory(this.label, this.emoji);

  final String label;
  final String emoji;
}

class Substitute {
  const Substitute(this.ingredientId, this.note);

  final String ingredientId;
  final String note;

  Map<String, dynamic> toJson() => {'ingredient': ingredientId, 'note': note};

  factory Substitute.fromJson(Map<String, dynamic> j) =>
      Substitute(j['ingredient'] as String, j['note'] as String);
}

class RecipeItem {
  const RecipeItem({
    required this.ingredientId,
    required this.amount,
    required this.measure,
    this.isMain = false,
    this.optional = false,
    this.substitutes = const [],
  });

  final String ingredientId;
  final double amount;
  final Measure measure;

  /// Ana malzemeler eşleşme puanında 3 kat ağırlık taşır.
  final bool isMain;
  final bool optional;
  final List<Substitute> substitutes;

  /// JSON'da "role": "main" (ana), "side" (yan) ya da "optional" (isteğe bağlı).
  Map<String, dynamic> toJson() => {
        'ingredient': ingredientId,
        'amount': compactNum(amount),
        'measure': measure.name,
        'role': optional ? 'optional' : (isMain ? 'main' : 'side'),
        if (substitutes.isNotEmpty)
          'substitutes': [for (final s in substitutes) s.toJson()],
      };

  factory RecipeItem.fromJson(Map<String, dynamic> j) {
    final role = j['role'] as String? ?? 'side';
    if (!const {'main', 'side', 'optional'}.contains(role)) {
      throw FormatException('Bilinmeyen rol: $role');
    }
    return RecipeItem(
      ingredientId: j['ingredient'] as String,
      amount: readDouble(j['amount']),
      measure: Measure.values.byName(j['measure'] as String),
      isMain: role == 'main',
      optional: role == 'optional',
      substitutes: [
        for (final s in (j['substitutes'] as List? ?? const []))
          Substitute.fromJson(s as Map<String, dynamic>)
      ],
    );
  }
}

class RecipeStep {
  const RecipeStep(this.text, {this.timerMinutes, this.timerLabel});

  final String text;
  final int? timerMinutes;
  final String? timerLabel;

  Map<String, dynamic> toJson() => {
        'text': text,
        if (timerMinutes != null) 'timerMinutes': timerMinutes,
        if (timerLabel != null) 'timerLabel': timerLabel,
      };

  factory RecipeStep.fromJson(Map<String, dynamic> j) => RecipeStep(
        j['text'] as String,
        timerMinutes: j['timerMinutes'] as int?,
        timerLabel: j['timerLabel'] as String?,
      );
}

class Recipe {
  const Recipe({
    required this.id,
    required this.title,
    required this.emoji,
    required this.minutes,
    required this.difficulty,
    required this.servings,
    required this.items,
    required this.steps,
    this.appliances = const {},
    this.techniques = const {},
    this.tags = const {},
    this.tip,
    this.source,
    this.category,
  });

  final String id;
  final String title;
  final String emoji;
  final int minutes;
  final Difficulty difficulty;
  final int servings;
  final List<RecipeItem> items;
  final List<RecipeStep> steps;
  final Set<Appliance> appliances;
  final Set<Technique> techniques;

  /// "kahvalti", "tek_kap" gibi serbest etiketler.
  final Set<String> tags;
  final String? tip;

  /// Videodan kaydedilen tariflerde kaynak; katalog tariflerinde null.
  final RecipeSource? source;

  bool get isImported => source != null;

  /// Katalog tariflerinde JSON'dan gelir; videodan kaydedilenlerde boş
  /// olabilir (o zaman lib/services/collections.dart tahmin eder).
  final RecipeCategory? category;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'emoji': emoji,
        'minutes': minutes,
        'difficulty': difficulty.name,
        'servings': servings,
        'appliances': [for (final a in appliances) a.name],
        'techniques': [for (final t in techniques) t.name],
        'tags': tags.toList(),
        'items': [for (final i in items) i.toJson()],
        'steps': [for (final s in steps) s.toJson()],
        if (tip != null) 'tip': tip,
        if (source != null) 'source': source!.toJson(),
        if (category != null) 'category': category!.name,
      };

  factory Recipe.fromJson(Map<String, dynamic> j) => Recipe(
        id: j['id'] as String,
        title: j['title'] as String,
        emoji: j['emoji'] as String,
        minutes: j['minutes'] as int,
        difficulty: Difficulty.values.byName(j['difficulty'] as String),
        servings: j['servings'] as int,
        appliances: {
          for (final a in readStrings(j['appliances']))
            Appliance.values.byName(a)
        },
        techniques: {
          for (final t in readStrings(j['techniques']))
            Technique.values.byName(t)
        },
        tags: readStrings(j['tags']).toSet(),
        items: [
          for (final i in j['items'] as List)
            RecipeItem.fromJson(i as Map<String, dynamic>)
        ],
        steps: [
          for (final s in j['steps'] as List)
            RecipeStep.fromJson(s as Map<String, dynamic>)
        ],
        tip: j['tip'] as String?,
        source: j['source'] == null
            ? null
            : RecipeSource.fromJson(j['source'] as Map<String, dynamic>),
        category: j['category'] == null
            ? null
            : RecipeCategory.values.byName(j['category'] as String),
      );
}
