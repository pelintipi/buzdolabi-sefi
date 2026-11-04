import '../models/ingredient.dart';
import 'ingredient_repository.dart';
import 'turkish_text.dart';

/// Ürün adlarında malzeme olmayan sıfatlar: "TAM YAĞLI SÜT" yağ değil süttür.
const _adjectives = {
  'yagli',
  'yagsiz',
  'yarim',
  'tam',
  'light',
  'organik',
  'koy',
  'dogal',
  'klasik',
  'sade',
  'extra',
  'ekstra',
  'pastorize',
  'uht',
  'yerli',
  'dilimli',
  'rende',
  'rendelenmis',
  'paket',
  'kutu',
  'sise',
  'buyuk',
  'kucuk',
  'boy',
  'aile',
  'ekonomik',
  'avantaj',
  'firsat',
  'li',
  'lu',
  'lik',
  'luk',
};

/// Market ürün adından ("Pınar Tam Yağlı Süt 1 L", "SUT TAM YAGLI 1LT")
/// katalog malzemesini bulur. Önce iki kelimelik adlar (taze soğan, tavuk
/// göğsü), sonra tek kelimeler; sıfatlar atlanır.
Ingredient? matchProductName(IngredientRepository repo, String name) {
  final words = TurkishText.fold(name)
      .replaceAll(RegExp(r'[^a-z ]'), ' ')
      .split(' ')
      .where((w) => w.length >= 2)
      .toList();
  // Fişler ters sırayla yazar: "PEYNIR BEYAZ" = beyaz peynir.
  for (var i = 0; i + 1 < words.length; i++) {
    final hit = repo.findByName('${words[i + 1]} ${words[i]}');
    if (hit != null &&
        !hit.leftover &&
        hit.id != repo.findByName(words[i])?.id) {
      return hit;
    }
  }
  for (var i = 0; i + 1 < words.length; i++) {
    final hit = repo.findByName('${words[i]} ${words[i + 1]}');
    // findByName iki kelimede son kelimeye düşebilir ("tam yağlı" → "yağ");
    // sonuç yalnızca son kelimeden geliyorsa iki kelimelik eşleşme sayılmaz.
    if (hit != null &&
        !hit.leftover &&
        hit.id != repo.findByName(words[i + 1])?.id) {
      return hit;
    }
  }
  for (final w in words) {
    if (_adjectives.contains(w)) continue;
    final hit = repo.findByName(w);
    if (hit != null && !hit.leftover) return hit;
  }
  return null;
}
