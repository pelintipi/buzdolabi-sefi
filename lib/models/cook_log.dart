class CookLog {
  const CookLog({
    required this.recipeId,
    required this.cookedAt,
    required this.servings,
    this.rating,
    this.note,
    this.rescuedGrams = 0,
    this.portionsEaten = 1,
    this.photoPath,
  });

  final String recipeId;
  final DateTime cookedAt;
  final int servings;
  final int? rating;

  /// "Tuzu azalttım" gibi sonraki sefere hatırlatma.
  final String? note;

  /// Son kullanma tarihi yaklaşan ürünlerden kullanılan miktar.
  final double rescuedGrams;

  /// Kullanıcının kendisinin yediği porsiyon (günlük kalori/protein için).
  final double portionsEaten;

  /// "Yaptım" fotoğrafı (uygulama klasöründe).
  final String? photoPath;

  CookLog copyWith({
    double? portionsEaten,
    String? photoPath,
    int? rating,
    String? note,
    bool clearNote = false,
  }) =>
      CookLog(
        recipeId: recipeId,
        cookedAt: cookedAt,
        servings: servings,
        rating: rating ?? this.rating,
        note: clearNote ? null : (note ?? this.note),
        rescuedGrams: rescuedGrams,
        portionsEaten: portionsEaten ?? this.portionsEaten,
        photoPath: photoPath ?? this.photoPath,
      );

  Map<String, dynamic> toJson() => {
        'recipeId': recipeId,
        'cookedAt': cookedAt.toIso8601String(),
        'servings': servings,
        'rating': rating,
        if (note != null && note!.trim().isNotEmpty) 'note': note!.trim(),
        'rescuedGrams': rescuedGrams,
        'portionsEaten': portionsEaten,
        if (photoPath != null) 'photoPath': photoPath,
      };

  factory CookLog.fromJson(Map<String, dynamic> j) => CookLog(
        recipeId: j['recipeId'] as String,
        cookedAt: DateTime.parse(j['cookedAt'] as String),
        servings: j['servings'] as int,
        rating: j['rating'] as int?,
        note: (j['note'] as String?)?.trim(),
        rescuedGrams: (j['rescuedGrams'] as num?)?.toDouble() ?? 0,
        portionsEaten: (j['portionsEaten'] as num?)?.toDouble() ?? 1,
        photoPath: j['photoPath'] as String?,
      );
}
