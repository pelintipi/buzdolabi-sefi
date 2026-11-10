import '../models/ingredient.dart';
import '../models/recipe.dart';

/// Değerlendirmenin genel tonu (renk ve sıralama için).
enum ReviewTone { good, ok, caution }

/// Bir porsiyonun diyetisyen gözüyle değerlendirmesi: enerjinin ne kadarı
/// proteinden, karbonhidrattan ve yağdan geliyor, bu ne anlama geliyor ve
/// öğünü dengelemek için ne eklenebilir.
///
/// Eşikler genel beslenme önerilerine dayanır: yetişkinler için enerjinin
/// yaklaşık %10-35'i protein, %45-65'i karbonhidrat, %20-35'i yağdan
/// gelmesi önerilir. Bir öğünün "protein kaynağı" sayılması için hem
/// enerjinin en az %12'si proteinden gelmeli hem de porsiyonda en az 12 g
/// protein olmalı; "yüksek protein" için %20 ve 20 g aranır.
/// Tıbbi tavsiye değildir.
class NutritionReview {
  const NutritionReview._({
    required this.nutrition,
    required this.proteinPct,
    required this.carbPct,
    required this.fatPct,
    required this.verdict,
    required this.tone,
    required this.summary,
    required this.tips,
    required this.balanceScore,
  });

  final Nutrition nutrition;

  /// Enerjinin yüzde kaçı bu besin öğesinden geliyor (toplamı 100).
  final int proteinPct;
  final int carbPct;
  final int fatPct;

  /// Kısa hüküm: "Dengeli öğün", "Karbonhidrat ağırlıklı"...
  final String verdict;
  final ReviewTone tone;

  /// Tek cümlelik açıklama.
  final String summary;

  /// Öğünü dengelemek için öneriler.
  final List<String> tips;

  /// 0-100: önerilen dağılıma ne kadar yakın ve proteini ne kadar yeterli.
  final int balanceScore;

  static const proteinSourceGrams = 12.0;
  static const highProteinGrams = 20.0;

  bool get isProteinSource =>
      nutrition.protein >= proteinSourceGrams && proteinPct >= 12;

  bool get isHighProtein =>
      nutrition.protein >= highProteinGrams && proteinPct >= 20;

  /// "En hafif" denebilmesi için: düşük kalorili ve yalnızca karbonhidrat
  /// ya da yağdan ibaret değil.
  bool get isLight =>
      nutrition.kcal <= 400 && verdict != 'Yağ oranı yüksek' && carbPct < 65;

  factory NutritionReview.of(Nutrition n, {RecipeCategory? category}) {
    final p = n.protein * 4, c = n.carbs * 4, f = n.fat * 9;
    final total = p + c + f;
    if (total <= 0) {
      return NutritionReview._(
        nutrition: n,
        proteinPct: 0,
        carbPct: 0,
        fatPct: 0,
        verdict: 'Besin değeri yok',
        tone: ReviewTone.ok,
        summary: 'Bu tarif için besin değeri hesaplanamadı.',
        tips: const [],
        balanceScore: 0,
      );
    }
    final pp = (p / total * 100).round();
    final fp = (f / total * 100).round();
    final cp = 100 - pp - fp;

    final sweet = category == RecipeCategory.tatli;
    final snack = category == RecipeCategory.atistirmalik;
    final side = category == RecipeCategory.salata || snack;
    final soup = category == RecipeCategory.corba;

    final highProtein = n.protein >= highProteinGrams && pp >= 20;
    final proteinSource = n.protein >= proteinSourceGrams && pp >= 12;
    // Yüzde tek başına yanıltır: zeytinyağlı bir salatanın ya da haşlanmış
    // yumurtanın enerjisinin çoğu yağdan gelir ama toplam yağ azdır.
    // Porsiyonda gerçekten çok yağ varsa "yüksek" denir.
    final fatHeavy = fp >= 50 && (n.fat >= 25 || n.kcal >= 500);
    final carbHeavy = cp >= 65;
    final balancedRatio =
        pp >= 15 && cp >= 30 && cp <= 65 && fp >= 15 && fp <= 40;
    // Oranlar iyi olsa da 6 g proteinli bir çorba "dengeli öğün" değildir.
    final balanced = balancedRatio && n.protein >= proteinSourceGrams;

    final String verdict;
    final ReviewTone tone;
    final String summary;
    if (sweet) {
      verdict = 'Tatlı · ara sıra';
      tone = ReviewTone.caution;
      summary = 'Enerjinin çoğu şeker ve karbonhidrattan geliyor; '
          'öğün yerine değil, küçük bir porsiyon tatlı olarak düşün.';
    } else if (highProtein && balanced) {
      verdict = 'Dengeli · bol proteinli';
      tone = ReviewTone.good;
      summary = 'Protein, karbonhidrat ve yağ önerilen aralıkta; '
          'protein de bol. Tok tutan, dengeli bir öğün.';
    } else if (highProtein) {
      verdict = 'Bol proteinli';
      tone = ReviewTone.good;
      summary = fatHeavy
          ? 'Protein bol ama enerjinin yarıdan fazlası yağdan geliyor.'
          : 'Porsiyonda ${n.protein.round()} g protein var; tok tutar, '
              'kasların için iyi bir öğün.';
    } else if (fatHeavy) {
      verdict = 'Yağ oranı yüksek';
      tone = ReviewTone.caution;
      summary = 'Enerjinin %$fp\'i yağdan geliyor (önerilen %20-35).';
    } else if (carbHeavy) {
      verdict = 'Karbonhidrat ağırlıklı';
      tone = ReviewTone.caution;
      summary = 'Enerjinin %$cp\'i karbonhidrattan, yalnızca %$pp\'i '
          'proteinden geliyor. Tek başına çabuk acıktırır; '
          '${side ? 'yan yemek olarak' : 'proteinle birlikte'} daha iyi.';
    } else if (balanced) {
      verdict = 'Dengeli öğün';
      tone = ReviewTone.good;
      summary = 'Protein, karbonhidrat ve yağ önerilen aralıkta; '
          'porsiyonda ${n.protein.round()} g protein var.';
    } else if (proteinSource) {
      verdict = 'Protein kaynağı';
      tone = ReviewTone.ok;
      summary = 'Porsiyonda ${n.protein.round()} g protein var.'
          '${fp >= 50 ? ' Enerjinin %$fp\'i yağdan geliyor; yağı az kullanmak iyi olur.' : ''}';
    } else if (soup) {
      verdict = 'Hafif çorba';
      tone = ReviewTone.ok;
      summary = 'Porsiyonda ${n.protein.round()} g protein, '
          '${n.kcal.round()} kcal var; öğünün başında ya da yanında iyi gider.';
    } else if (side) {
      verdict = snack ? 'Hafif ara öğün' : 'Hafif yan yemek';
      tone = ReviewTone.ok;
      summary = 'Porsiyonda ${n.protein.round()} g protein var; '
          '${snack ? 'öğün arasında iyi gider.' : 'ana yemeğin yanında iyi gider.'}';
    } else {
      verdict = 'Proteini düşük';
      tone = ReviewTone.caution;
      summary = 'Porsiyonda yalnızca ${n.protein.round()} g protein var; '
          'tek başına doyurucu bir öğün olmaz.';
    }

    final tips = <String>[
      if (!proteinSource && !sweet)
        'Proteini artırmak için yanına yoğurt, cacık, yumurta, tavuk ya da '
            'nohut gibi bir baklagil ekle.',
      if (carbHeavy && !sweet)
        'Yanına bol yeşillikli bir salata ekle; lif ve sebze öğünü dengeler.',
      if (fatHeavy) 'Tarifteki yağı yarıya indirerek kaloriyi azaltabilirsin.',
      // Lif: günlük 25 g'ın yaklaşık üçte biri bir öğünden gelirse iyi.
      if (!sweet && !soup && n.kcal >= 200 && n.fiber < 3)
        'Lifi az (${n.fiber.toStringAsFixed(1)} g). Yanına salata, bulgur, '
            'tam buğday ekmek ya da bir baklagil ekle; lif tok tutar.',
      if (!sweet && n.fiber >= 8)
        'Lif açısından zengin (${n.fiber.round()} g); günlük ihtiyacın '
            'üçte biri bu tabakta.',
      if (n.kcal >= 700)
        'Porsiyon oldukça doyurucu (${n.kcal.round()} kcal); günün diğer '
            'öğünlerini hafif tutabilirsin.',
      if (n.kcal < 200 && !side && !sweet && !soup)
        'Kalorisi düşük; ana öğün olarak yetmeyebilir, yanına ekmek ya da '
            'bir kase yoğurt ekleyebilirsin.',
    ];

    // Puan: protein yeterliliği (40), enerjinin önerilen aralıkta
    // dağılması (40) ve öğün için uygun kalori (20).
    final proteinScore = n.protein.clamp(0, 30) / 30 * 40;
    final penalty = (pp < 15 ? (15 - pp) * 2 : 0) +
        (cp > 60 ? (cp - 60) * 1.5 : 0) +
        (fp > 40 ? (fp - 40) * 1.5 : 0);
    final distributionScore = (40 - penalty).clamp(0, 40);
    final kcal = n.kcal;
    final energyScore = kcal >= 300 && kcal <= 700
        ? 20.0
        : kcal < 300
            ? kcal / 300 * 20
            : (20 - (kcal - 700) / 20).clamp(0, 20);
    final score = (proteinScore + distributionScore + energyScore).round();

    return NutritionReview._(
      nutrition: n,
      proteinPct: pp,
      carbPct: cp,
      fatPct: fp,
      verdict: verdict,
      tone: tone,
      summary: summary,
      tips: tips,
      balanceScore: sweet ? (score * 0.5).round() : score.clamp(0, 100),
    );
  }
}
