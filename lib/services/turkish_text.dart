/// Türkçe metin yardımcıları: doğru küçük harf, karşılaştırma anahtarı ve basit ek atma.
class TurkishText {
  TurkishText._();

  /// Dart'ın toLowerCase'i "İ" ve "I" harflerini Türkçeye uygun çevirmez.
  static String lower(String s) =>
      s.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();

  static const _foldMap = {
    'ç': 'c',
    'ğ': 'g',
    'ı': 'i',
    'ö': 'o',
    'ş': 's',
    'ü': 'u',
    'â': 'a',
    'î': 'i',
    'û': 'u',
  };

  /// Karşılaştırma anahtarı: "Soğanı" → "sogani". Klavyede Türkçe karakter
  /// kullanmayanlar da ("sogan") eşleşsin diye.
  static String fold(String s) {
    final buffer = StringBuffer();
    for (final ch in lower(s).trim().split('')) {
      buffer.write(_foldMap[ch] ?? ch);
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ');
  }

  static const _suffixes = [
    'ları',
    'leri',
    'lar',
    'ler',
    'nın',
    'nin',
    'nun',
    'nün',
    'lı',
    'li',
    'lu',
    'lü',
    'yı',
    'yi',
    'yu',
    'yü',
    'sı',
    'si',
    'su',
    'sü',
    'ı',
    'i',
    'u',
    'ü',
  ];

  static const _hardening = {'ğ': 'k', 'b': 'p', 'c': 'ç', 'd': 't'};

  /// Kelimenin olası kökleri: "domatesler" → "domates", "ekmeği" → "ekmek".
  /// Kelimenin kendisi her zaman ilk sıradadır.
  static List<String> stems(String word) {
    final result = <String>{word};
    var frontier = {word};
    for (var round = 0; round < 2; round++) {
      final next = <String>{};
      for (final w in frontier) {
        for (final suffix in _suffixes) {
          if (w.endsWith(suffix) && w.length - suffix.length >= 3) {
            next.add(w.substring(0, w.length - suffix.length));
          }
        }
      }
      result.addAll(next);
      frontier = next;
    }
    // Ünsüz yumuşaması geri alınır: "ekmeğ" → "ekmek".
    for (final w in result.toList()) {
      final hard = _hardening[w[w.length - 1]];
      if (hard != null) result.add(w.substring(0, w.length - 1) + hard);
    }
    return result.toList();
  }
}
