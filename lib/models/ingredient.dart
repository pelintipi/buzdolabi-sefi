import 'json_helpers.dart';

/// Malzemenin dolapta hangi birimle tutulduğu.
enum BaseUnit { gram, ml, piece }

enum Allergen {
  milk('Süt', '🥛'),
  egg('Yumurta', '🥚'),
  gluten('Gluten', '🌾'),
  peanut('Yer fıstığı', '🥜'),
  treeNut('Kuruyemiş', '🌰'),
  fish('Balık', '🐟'),
  sesame('Susam', '🫙');

  const Allergen(this.label, this.emoji);

  final String label;
  final String emoji;
}

/// Diyet uygunluğunu (vejetaryen/vegan) belirleyen etiketler.
enum FoodTag { meat, fish, animalProduct }

class Nutrition {
  const Nutrition(this.kcal, this.protein, this.fat, this.carbs);

  static const zero = Nutrition(0, 0, 0, 0);

  final double kcal;
  final double protein;
  final double fat;
  final double carbs;

  Nutrition operator +(Nutrition o) => Nutrition(
      kcal + o.kcal, protein + o.protein, fat + o.fat, carbs + o.carbs);

  Nutrition scale(double f) =>
      Nutrition(kcal * f, protein * f, fat * f, carbs * f);

  Map<String, dynamic> toJson() => {
        'kcal': compactNum(kcal),
        'protein': compactNum(protein),
        'fat': compactNum(fat),
        'carbs': compactNum(carbs),
      };

  factory Nutrition.fromJson(Map<String, dynamic> j) => Nutrition(
        readDouble(j['kcal']),
        readDouble(j['protein']),
        readDouble(j['fat']),
        readDouble(j['carbs']),
      );
}

class Ingredient {
  const Ingredient({
    required this.id,
    required this.name,
    required this.emoji,
    required this.baseUnit,
    required this.packageAmount,
    required this.shelfLifeDays,
    required this.per100g,
    required this.pricePerKg,
    this.parentId,
    this.synonyms = const [],
    this.density = 1.0,
    this.pieceGrams = 100.0,
    this.pieceLabel = 'adet',
    this.allergens = const {},
    this.tags = const {},
    this.isStaple = false,
    this.season = const {},
    this.leftover = false,
  });

  final String id;
  final String name;
  final String emoji;

  /// Üst kategori. Örn. "kasar" → "peynir". Tarif "peynir" isterse kaşar da eşleşir.
  final String? parentId;
  final List<String> synonyms;
  final BaseUnit baseUnit;

  /// g/ml. Bardak ve kaşık ölçülerini grama çevirmek için.
  final double density;

  /// 1 adetin (diş, demet) gram karşılığı.
  final double pieceGrams;
  final String pieceLabel;

  /// Tipik paket miktarı (baseUnit cinsinden). "Bol/Biraz/Az" seçimleri buna göre hesaplanır.
  final double packageAmount;
  final int shelfLifeDays;

  /// Sadece bu malzemeye ait alerjenler. Üst kategorininkiler depo tarafından eklenir.
  final Set<Allergen> allergens;
  final Set<FoodTag> tags;
  final Nutrition per100g;

  /// Tahmini fiyat (₺/kg).
  final double pricePerKg;

  /// Tuz, yağ, salça gibi evde hep var sayılan malzemeler.
  final bool isStaple;

  /// Türkiye'de mevsiminde olduğu aylar (1-12); boşsa her mevsim bulunur.
  /// Yaklaşık değerlerdir, bölgeye göre değişir.
  final Set<int> season;

  /// "Dünden kalan" pişmiş yemek (pilav, haşlanmış makarna...).
  final bool leftover;

  bool inSeason(int month) => season.contains(month);

  /// Varsayılan değerler (yoğunluk 1, adet 100 g, boş listeler) yazılmaz.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        if (parentId != null) 'parent': parentId,
        if (synonyms.isNotEmpty) 'synonyms': synonyms,
        'baseUnit': baseUnit.name,
        if (density != 1.0) 'density': compactNum(density),
        if (pieceGrams != 100.0) 'pieceGrams': compactNum(pieceGrams),
        if (pieceLabel != 'adet') 'pieceLabel': pieceLabel,
        'packageAmount': compactNum(packageAmount),
        'shelfLifeDays': shelfLifeDays,
        if (allergens.isNotEmpty)
          'allergens': [for (final a in allergens) a.name],
        if (tags.isNotEmpty) 'tags': [for (final t in tags) t.name],
        'per100g': per100g.toJson(),
        'pricePerKg': compactNum(pricePerKg),
        if (isStaple) 'staple': true,
        if (season.isNotEmpty) 'season': (season.toList()..sort()),
        if (leftover) 'leftover': true,
      };

  factory Ingredient.fromJson(Map<String, dynamic> j) => Ingredient(
        id: j['id'] as String,
        name: j['name'] as String,
        emoji: j['emoji'] as String,
        parentId: j['parent'] as String?,
        synonyms: readStrings(j['synonyms']),
        baseUnit: BaseUnit.values.byName(j['baseUnit'] as String),
        density: readDouble(j['density'], 1.0),
        pieceGrams: readDouble(j['pieceGrams'], 100.0),
        pieceLabel: j['pieceLabel'] as String? ?? 'adet',
        packageAmount: readDouble(j['packageAmount']),
        shelfLifeDays: j['shelfLifeDays'] as int,
        allergens: {
          for (final a in readStrings(j['allergens'])) Allergen.values.byName(a)
        },
        tags: {
          for (final t in readStrings(j['tags'])) FoodTag.values.byName(t)
        },
        per100g: Nutrition.fromJson(j['per100g'] as Map<String, dynamic>),
        pricePerKg: readDouble(j['pricePerKg']),
        isStaple: j['staple'] as bool? ?? false,
        season: {
          for (final m in (j['season'] as List? ?? const [])) (m as num).toInt()
        },
        leftover: j['leftover'] as bool? ?? false,
      );
}
