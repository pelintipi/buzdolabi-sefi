import 'ingredient.dart';

/// Kesin miktar bilinmediğinde kullanılan yaklaşık seviye (paketin oranı).
enum ApproxLevel {
  bol('Bol', 1.0),
  biraz('Biraz', 0.5),
  az('Az', 0.2);

  const ApproxLevel(this.label, this.fraction);

  final String label;
  final double fraction;
}

class PantryItem {
  const PantryItem({
    required this.id,
    required this.ingredientId,
    required this.addedAt,
    this.quantity,
    this.level,
    this.expiresAt,
    this.checkedAt,
  });

  final String id;
  final String ingredientId;

  /// Malzemenin baseUnit'i cinsinden kesin miktar. Yoksa [level] kullanılır.
  final double? quantity;
  final ApproxLevel? level;
  final DateTime? expiresAt;
  final DateTime addedAt;

  /// Kullanıcının bu malzemeyi en son gördüğü/düzelttiği an (dolap kontrolü,
  /// miktar değişikliği, pişirmede düşme). Yoksa eklenme anı sayılır.
  final DateTime? checkedAt;

  DateTime get lastSeen => checkedAt ?? addedAt;

  double baseAmount(Ingredient ing) =>
      quantity ?? (level ?? ApproxLevel.biraz).fraction * ing.packageAmount;

  PantryItem copyWith({
    double? quantity,
    ApproxLevel? level,
    DateTime? expiresAt,
    DateTime? checkedAt,
    bool clearQuantity = false,
    bool clearLevel = false,
  }) =>
      PantryItem(
        id: id,
        ingredientId: ingredientId,
        addedAt: addedAt,
        quantity: clearQuantity ? null : (quantity ?? this.quantity),
        level: clearLevel ? null : (level ?? this.level),
        expiresAt: expiresAt ?? this.expiresAt,
        checkedAt: checkedAt ?? this.checkedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'ingredientId': ingredientId,
        'quantity': quantity,
        'level': level?.name,
        'expiresAt': expiresAt?.toIso8601String(),
        'addedAt': addedAt.toIso8601String(),
        if (checkedAt != null) 'checkedAt': checkedAt!.toIso8601String(),
      };

  factory PantryItem.fromJson(Map<String, dynamic> j) => PantryItem(
        id: j['id'] as String,
        ingredientId: j['ingredientId'] as String,
        quantity: (j['quantity'] as num?)?.toDouble(),
        level: j['level'] == null
            ? null
            : ApproxLevel.values.byName(j['level'] as String),
        expiresAt: j['expiresAt'] == null
            ? null
            : DateTime.parse(j['expiresAt'] as String),
        addedAt: DateTime.parse(j['addedAt'] as String),
        checkedAt: j['checkedAt'] == null
            ? null
            : DateTime.parse(j['checkedAt'] as String),
      );
}
