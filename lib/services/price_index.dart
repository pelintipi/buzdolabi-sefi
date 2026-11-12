/// Malzeme fiyatları (ingredients.json → pricePerKg) Kasım 2026 market
/// ortalamasıdır. Uygulama güncellenmese de maliyet zamanla eskimesin diye
/// geçen her ay için gıda enflasyonu kadar artırılır.
abstract final class PriceIndex {
  /// Fiyat listesinin kontrol edildiği ay.
  static final base = DateTime(2026, 11);

  /// Aylık tahmini gıda fiyat artışı (~%2,3 → yılda ~%31).
  static const monthlyRate = 0.023;

  /// Testler için "bugün" değiştirilebilir.
  static DateTime Function() now = DateTime.now;

  /// Bugünkü fiyat çarpanı (liste tarihinden önce 1).
  static double factor() {
    final n = now();
    final months = (n.year - base.year) * 12 + n.month - base.month;
    if (months <= 0) return 1;
    var f = 1.0;
    for (var i = 0; i < months; i++) {
      f *= 1 + monthlyRate;
    }
    return f;
  }
}
