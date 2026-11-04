/// Ücretsiz / Şef+ ayrımı.
///
/// İlk sürüm tamamen ücretsizdir ([firstReleaseFree]). Şef+ özellikleri
/// uygulamada "Şef+" rozetiyle işaretlenir ama herkes kullanabilir. İleride
/// abonelik açıldığında yalnızca [firstReleaseFree] false yapılır ve
/// [Premium.subscribed] App Store satın alımına (StoreKit) bağlanır.
///
/// Kural: Dolaba göre tarif bulma ve masrafsız (telefonda çalışan) her şey
/// her zaman ücretsiz kalır. Şef+'ta yalnızca bize sunucu/yapay zeka masrafı
/// çıkaran özellikler vardır.
library;

const firstReleaseFree = true;

enum PremiumFeature {
  aiVideo('Yapay zekayla video tarifi', '🎬',
      'Açıklaması dağınık videolarda bile tarifi doğru çıkarır.',
      freeMonthly: 5),
  sharedPantry('Ortak dolap', '🏠',
      'Evdekilerle aynı dolap ve aynı alışveriş listesi, anında güncel.');

  const PremiumFeature(this.label, this.emoji, this.description,
      {this.freeMonthly = 0});

  final String label;
  final String emoji;
  final String description;

  /// Abonelik açıldığında ücretsiz kullanıcının aylık hakkı (0: yok).
  final int freeMonthly;
}

class Premium {
  const Premium({this.subscribed = false});

  /// App Store aboneliği (şimdilik hep false; StoreKit bağlanınca dolacak).
  final bool subscribed;

  bool canUse(PremiumFeature f) => firstReleaseFree || subscribed;
}
