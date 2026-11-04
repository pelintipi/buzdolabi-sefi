import '../models/ingredient.dart';
import 'turkish_text.dart';

/// Malzeme kataloğu: kimlikle erişim, hiyerarşi, alerjen kalıtımı ve isimle arama.
class IngredientRepository {
  IngredientRepository(List<Ingredient> items)
      : _byId = {for (final i in items) i.id: i} {
    for (final ing in items) {
      _index[TurkishText.fold(ing.name)] = ing;
      for (final s in ing.synonyms) {
        _index.putIfAbsent(TurkishText.fold(s), () => ing);
      }
    }
  }

  final Map<String, Ingredient> _byId;
  final Map<String, Ingredient> _index = {};

  Iterable<Ingredient> get all => _byId.values;

  List<Ingredient> get staples => [
        for (final i in _byId.values)
          if (i.isStaple) i
      ];

  Ingredient byId(String id) {
    final ing = _byId[id];
    if (ing == null) throw ArgumentError('Bilinmeyen malzeme: $id');
    return ing;
  }

  Ingredient? tryById(String id) => _byId[id];

  /// Malzemenin kendisi ve bütün üst kategorileri.
  Iterable<Ingredient> _chain(String id) sync* {
    String? current = id;
    while (current != null) {
      final ing = _byId[current];
      if (ing == null) return;
      yield ing;
      current = ing.parentId;
    }
  }

  /// "kasar", "peynir"in alt türü mü? Tarif "peynir" istiyorsa kaşar da sayılır.
  bool isSameOrDescendant(String candidateId, String ancestorId) =>
      _chain(candidateId).any((i) => i.id == ancestorId);

  Set<Allergen> allergensOf(String id) =>
      {for (final i in _chain(id)) ...i.allergens};

  Set<FoodTag> tagsOf(String id) => {for (final i in _chain(id)) ...i.tags};

  /// Serbest metinden malzeme bulur: "Domatesler", "beyaz peyniri", "sogan".
  Ingredient? findByName(String phrase) {
    final words = TurkishText.lower(phrase)
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return null;

    final direct = _index[TurkishText.fold(words.join(' '))];
    if (direct != null) return direct;

    if (words.length <= 3) {
      var combos = <String>[''];
      for (final w in words) {
        final stems = TurkishText.stems(w);
        combos = [
          for (final c in combos)
            for (final s in stems) c.isEmpty ? s : '$c $s'
        ];
      }
      for (final c in combos) {
        final hit = _index[TurkishText.fold(c)];
        if (hit != null) return hit;
      }
    }

    // "taze ıspanak" gibi sıfatlı girişler için son kelime denenir.
    if (words.length > 1) return findByName(words.last);
    return null;
  }

  /// Otomatik tamamlama için arama. Baştan eşleşenler önce gelir.
  List<Ingredient> search(String query, {int limit = 8}) {
    final q = TurkishText.fold(query);
    if (q.isEmpty) return const [];
    final scored = <(int, Ingredient)>[];
    for (final ing in _byId.values) {
      var best = 99;
      for (final name in [ing.name, ...ing.synonyms]) {
        final f = TurkishText.fold(name);
        final score = f.startsWith(q)
            ? 0
            : f.split(' ').any((w) => w.startsWith(q))
                ? 1
                : f.contains(q)
                    ? 2
                    : 99;
        if (score < best) best = score;
      }
      if (best < 99) scored.add((best, ing));
    }
    scored.sort((a, b) {
      final c = a.$1.compareTo(b.$1);
      return c != 0 ? c : a.$2.name.compareTo(b.$2.name);
    });
    return [for (final s in scored.take(limit)) s.$2];
  }
}
