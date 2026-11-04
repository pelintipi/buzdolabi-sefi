import 'dart:math' as math;

import '../models/ingredient.dart';
import '../models/measure.dart';
import '../models/recipe.dart';
import 'ingredient_repository.dart';
import 'quantity_parser.dart';
import 'turkish_text.dart';
import 'unit_converter.dart';

/// Açıklamadan çıkarılan tarif ve tanınamayan satırlar.
class ExtractedRecipe {
  const ExtractedRecipe({
    required this.recipe,
    required this.unmatched,
    required this.foundIngredientSection,
    required this.foundStepSection,
  });

  final Recipe recipe;

  /// Malzeme gibi duran ama kataloğumuzda karşılığı olmayan satırlar.
  final List<String> unmatched;
  final bool foundIngredientSection;
  final bool foundStepSection;

  /// En az iki malzeme bulunduysa tarif kullanılabilir sayılır.
  bool get isUsable => recipe.items.length >= 2;
}

/// TikTok/Reels açıklamasındaki serbest metinden tarif çıkarır:
///
///     Kremalı mantarlı tavuk 🍗
///     Malzemeler: 500 gr tavuk göğsü, 200 gr mantar, 1 paket krema, tuz
///     Yapılışı: Tavukları kuşbaşı doğrayıp 10 dakika soteleyin. ...
///
/// Kural tabanlıdır (sunucu gerekmez). Bulamadığını uydurmaz: tanımadığı
/// malzemeler [ExtractedRecipe.unmatched] listesinde kullanıcıya gösterilir.
class CaptionRecipeExtractor {
  CaptionRecipeExtractor(this.repo) : _parser = QuantityParser(repo);

  final IngredientRepository repo;
  final QuantityParser _parser;

  static final _hashtag = RegExp(r'[#@][^\s#@]+');
  static final _emoji = RegExp(
      r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}\u{2190}-\u{21FF}\u{2300}-\u{23FF}]'
      r'[\u{FE0F}\u{200D}\u{1F3FB}-\u{1F3FF}]*',
      unicode: true);
  static final _bullet = RegExp(r'(^|\n)\s*[-–•▪·*✓✔]\s*');
  // Başlık sayılması için ardından ":" ya da satır sonu gelmeli; yoksa
  // "malzemeleri karıştırın" cümlesi de başlık sanılır.
  static final _ingredientsHeader = RegExp(
      r'(malzemeler|malzeme listesi|gerekli malzemeler|ihtiyacınız olanlar)\s*(?:[:：]|(?=\n))');
  static final _stepsHeader = RegExp(
      r'(yapılışı|yapılış|hazırlanışı|hazırlanış|nasıl yapılır|yapımı)\s*(?:[:：]|(?=\n))');

  /// "Pankek tarifi: 2 yumurta, ..." → başlık "Pankek".
  static final _titleMarker = RegExp(r'^\s*([^\n:]{2,60}?)\s+tarifi\s*[:：]');

  /// Emir ya da bağlaç fiil ekleri: "çırpın", "pişirip", "karıştırarak".
  static final _verbEnding = RegExp(
      r'(in|un|yin|yun|iniz|unuz|ip|up|yip|yup|erek|arak|yoruz|dik|duk|tik|tuk|elim|alim)$');
  static final _numberedStep = RegExp(r'(?:^|\s)\d{1,2}\s*[.)]\s+(?=\D)');
  static final _sentenceEnd = RegExp(r'(?<=[.!?])\s+');
  static final _timer = RegExp(r'(\d+)\s*(?:-\s*(\d+)\s*)?(dakika|dk|saat)');
  static final _readyIn =
      RegExp(r'(\d+)\s*(dakika|dk)(da|de)\s*(hazır|bitiyor)');
  static final _servingsRe = RegExp(r'(\d+)\s*kişilik');

  /// "arzuya göre pul biber" → "pul biber" (isteğe bağlı)
  static final _optionalPhrase = RegExp(
      r'^(arzuya göre|isteğe göre|isteğe bağlı|isteğe bağlı olarak|opsiyonel|varsa)\s+|\s+\((isteğe bağlı|opsiyonel)\)$');
  static final _fillerPhrase = RegExp(
      r'^(yeteri kadar|yeterince|bir miktar|göz kararı|kızartmak için|üzeri için|üzerine|servis için)\s+|\s+(yeteri kadar|bir miktar)$');

  ExtractedRecipe extract(
    String caption, {
    required String id,
    String? fallbackTitle,
    RecipeSource? source,
  }) {
    // Hashtag ve emojiler ayraç gibi davranır: "🥚 2 yumurta 🥛 süt".
    var text = caption
        .replaceAll(_hashtag, ' ')
        .replaceAll(_emoji, '\n')
        .replaceAll('\r', '\n');
    text = text.replaceAllMapped(_bullet, (m) => '${m.group(1)}\n');
    final lower = TurkishText.lower(text);
    // Konumlar küçük harfli metinde bulunup aynı konumlar orijinale uygulanır.
    final positions = lower.length == text.length;
    final base = positions ? text : lower;

    final ingMatch = _ingredientsHeader.firstMatch(lower);
    final stepsMatch = _stepsHeader
        .allMatches(lower)
        .where((m) => ingMatch == null || m.start > ingMatch.end)
        .firstOrNull;

    final marker = ingMatch == null ? _titleMarker.firstMatch(lower) : null;
    final titleEnd = ingMatch?.start ??
        (marker != null ? marker.start + marker.group(0)!.length : null) ??
        stepsMatch?.start ??
        _firstBreak(base);
    final rawTitle = marker != null
        ? base
            .substring(marker.start, marker.end)
            .replaceFirst(RegExp(r'\s+\S+\s*[:：]\s*$'), '')
        : base.substring(0, titleEnd);
    final title = _cleanTitle(rawTitle) ??
        _cleanTitle(fallbackTitle ?? '') ??
        'Videodan tarif';

    final String ingredientPart;
    final String stepPart;
    if (ingMatch != null) {
      ingredientPart =
          base.substring(ingMatch.end, stepsMatch?.start ?? base.length);
      stepPart = stepsMatch == null ? '' : base.substring(stepsMatch.end);
    } else if (stepsMatch != null && stepsMatch.start >= titleEnd) {
      ingredientPart = base.substring(titleEnd, stepsMatch.start);
      stepPart = base.substring(stepsMatch.end);
    } else {
      ingredientPart = base.substring(titleEnd);
      stepPart = '';
    }

    final items = <String, _Item>{};
    final unmatched = <String>[];
    final leftover = <String>[];
    // Cümle cümle bakılır: "Hepsini çırpın, tavada pişirin." bir adımdır,
    // "2 yumurta, 1 su bardağı süt." ise malzeme listesi.
    for (final sentence in ingredientPart.split(RegExp(r'\n+|(?<=[.!?])\s+'))) {
      if (_looksLikeStep(sentence)) {
        leftover.add(sentence.trim());
        continue;
      }
      for (final chunk in _ingredientChunks(sentence)) {
        final parsed = _parseIngredient(chunk);
        if (parsed == null) {
          // Uzun ifadeler malzeme değil, büyük ihtimalle adımdır.
          if (chunk.split(' ').length <= 5) {
            unmatched.add(chunk);
          } else {
            leftover.add(chunk);
          }
          continue;
        }
        items.putIfAbsent(parsed.ingredient.id, () => parsed);
      }
    }

    var steps = _steps(stepPart);
    if (steps.isEmpty && leftover.isNotEmpty) {
      steps = _steps(leftover.join('\n'));
    }
    if (steps.isEmpty && source != null) {
      steps = [
        const RecipeStep(
            'Adımlar videoda anlatılıyor. Videoyu izleyerek ilerle.')
      ];
    }

    final all = TurkishText.fold(caption);
    final recipe = Recipe(
      id: id,
      title: title,
      emoji: _emojiFor(items.values),
      minutes: _minutes(lower, steps),
      difficulty: steps.length <= 4
          ? Difficulty.kolay
          : steps.length <= 8
              ? Difficulty.orta
              : Difficulty.zor,
      servings: int.tryParse(_servingsRe.firstMatch(lower)?.group(1) ?? '')
              ?.clamp(1, 12) ??
          2,
      items: _withRoles(items.values.toList()),
      steps: steps,
      appliances: _appliances(all),
      techniques: _techniques(all),
      tags: const {'videodan'},
      source: source == null
          ? null
          : RecipeSource(
              url: source.url,
              platform: source.platform,
              author: source.author,
              thumbnailUrl: source.thumbnailUrl,
              caption: caption,
              unmatched: unmatched,
            ),
    );
    return ExtractedRecipe(
      recipe: recipe,
      unmatched: unmatched,
      foundIngredientSection: ingMatch != null,
      foundStepSection: stepsMatch != null,
    );
  }

  /// Son kelimesi fiil olan ("çırpın", "pişirip") ve malzeme olmayan cümle.
  bool _looksLikeStep(String sentence) {
    final words = TurkishText.fold(sentence)
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.length < 2) return false;
    // "1 paket vanilin" gibi kısa, sayıyla başlayan satır malzemedir.
    if (words.length <= 3 && RegExp(r'^\d').hasMatch(words.first)) return false;
    final last = words.last;
    if (repo.findByName(last) != null) return false;
    return _verbEnding.hasMatch(last);
  }

  /// Başlık sayılacak ilk satırın sonu; tek satırlık metinde başlık yoktur.
  int _firstBreak(String s) {
    final start = s.length - s.trimLeft().length;
    final nl = s.indexOf('\n', start);
    return nl > 0 ? nl : 0;
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    final first = s[0] == 'i' ? 'İ' : s[0].toUpperCase();
    return first + s.substring(1);
  }

  /// Başlığa karışan reklam cümleleri: "15 dakikada hazır!", "çok kolay".
  static final _titleNoise = RegExp(
      r'\s*\d+\s*(dakikada|dk.?da)\s*(hazır|bitiyor|tamam)\S*|'
      r'\s+(tarifi|çok kolay|kolay|pratik|nefis)\s*$',
      caseSensitive: false);

  String? _cleanTitle(String raw) {
    var t = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    t = t.replaceAll(_titleNoise, '').trim();
    t = t.replaceAll(RegExp(r'^[^\p{L}\d]+|[^\p{L}\d)]+$', unicode: true), '');
    if (t.isEmpty) return null;
    if (t.length > 48) {
      final cut = t.substring(0, 48);
      final space = cut.lastIndexOf(' ');
      t = '${cut.substring(0, space > 20 ? space : 48)}…';
    }
    // İlk harf büyük: "kremalı tavuk" → "Kremalı tavuk".
    return _capitalize(t);
  }

  Iterable<String> _ingredientChunks(String part) sync* {
    for (final line in part.split(QuantityParser.splitter)) {
      final chunk = line
          .replaceAll(RegExp(r'\([^)]*\)'), ' ')
          .replaceAll(RegExp(r'[.!:;]+$'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (chunk.isNotEmpty && chunk.length <= 80) yield chunk;
    }
  }

  _Item? _parseIngredient(String chunk) {
    var text = TurkishText.lower(chunk);
    var optional = false;
    text = text.replaceAllMapped(_optionalPhrase, (_) {
      optional = true;
      return '';
    }).trim();
    text = text.replaceAll(_fillerPhrase, '').trim();
    if (text.isEmpty) return null;

    var entry = _parser.parseChunk(text);
    // "500 gr tavuk göğsü doğranmış" gibi sondaki tarif kelimeleri.
    if (entry.ingredient == null && text.split(' ').length > 2) {
      final words = text.split(' ');
      for (var n = words.length - 1; n >= 2 && entry.ingredient == null; n--) {
        final shorter = _parser.parseChunk(words.take(n).join(' '));
        if (shorter.ingredient != null) entry = shorter;
      }
    }
    final ing = entry.ingredient;
    if (ing == null) return null;

    var amount = entry.amount;
    var measure = entry.measure;
    if (amount == null || measure == null) {
      // Miktar yazmıyorsa ("tuz, karabiber") küçük bir varsayılan.
      (amount, measure) = _defaultAmount(ing);
    }
    return _Item(ing, amount, measure, optional);
  }

  (double, Measure) _defaultAmount(Ingredient ing) {
    if (ing.isStaple) return (1, Measure.tutam);
    if (ing.baseUnit == BaseUnit.piece) return (1, Measure.adet);
    return (100, ing.baseUnit == BaseUnit.ml ? Measure.ml : Measure.gram);
  }

  /// En ağır iki temel (dolapta hep bulunmayan) malzeme "ana" malzemedir.
  List<RecipeItem> _withRoles(List<_Item> items) {
    double grams(_Item i) =>
        UnitConverter.toGrams(i.ingredient, i.amount, i.measure);
    final core = items
        .where((i) => !i.ingredient.isStaple && !i.optional)
        .toList()
      ..sort((a, b) => grams(b).compareTo(grams(a)));
    final mainIds = {for (final i in core.take(2)) i.ingredient.id};
    if (mainIds.isEmpty && items.isNotEmpty) {
      mainIds.add(items.first.ingredient.id);
    }
    return [
      for (final i in items)
        RecipeItem(
          ingredientId: i.ingredient.id,
          amount: i.amount,
          measure: i.measure,
          isMain: mainIds.contains(i.ingredient.id),
          optional: i.optional && !mainIds.contains(i.ingredient.id),
        ),
    ];
  }

  List<RecipeStep> _steps(String part) {
    var text = part.replaceAll(RegExp(r'[ \t]+'), ' ').trim();
    if (text.isEmpty) return const [];
    text = text.replaceAll(_numberedStep, '\n');
    final pieces = <String>[
      for (final line in text.split('\n'))
        for (final sentence in line.split(_sentenceEnd)) sentence.trim(),
    ].where((s) =>
        s.replaceAll(RegExp(r'[^\p{L}]', unicode: true), '').length >= 6);

    final steps = <RecipeStep>[];
    for (final p in pieces.take(12)) {
      var s = p.replaceAll(RegExp(r'^[^\p{L}\d]+', unicode: true), '');
      s = _capitalize(s);
      if (!RegExp(r'[.!?]$').hasMatch(s)) s = '$s.';
      final timer = _timer.firstMatch(TurkishText.lower(s));
      int? minutes;
      if (timer != null) {
        final n = int.parse(timer.group(2) ?? timer.group(1)!);
        minutes = timer.group(3) == 'saat' ? n * 60 : n;
        if (minutes <= 0 || minutes > 240) minutes = null;
      }
      steps.add(RecipeStep(s,
          timerMinutes: minutes,
          timerLabel: minutes == null ? null : 'Zamanlayıcı'));
    }
    return steps;
  }

  /// "15 dakikada hazır" yazıyorsa o; yoksa zamanlayıcılar + adım başına 3 dk.
  int _minutes(String lower, List<RecipeStep> steps) {
    final ready = _readyIn.firstMatch(lower);
    if (ready != null) return int.parse(ready.group(1)!).clamp(5, 300);
    final timers = steps.fold<int>(0, (s, st) => s + (st.timerMinutes ?? 0));
    final total = timers + steps.length * 3 + 5;
    return math.max(10, (total / 5).round() * 5);
  }

  String _emojiFor(Iterable<_Item> items) {
    final main = items.where((i) => !i.ingredient.isStaple).toList()
      ..sort((a, b) => UnitConverter.toGrams(b.ingredient, b.amount, b.measure)
          .compareTo(UnitConverter.toGrams(a.ingredient, a.amount, a.measure)));
    return main.isEmpty ? '🍽️' : main.first.ingredient.emoji;
  }

  Set<Appliance> _appliances(String folded) => {
        if (folded.contains('firin')) Appliance.firin,
        if (folded.contains('airfryer') || folded.contains('air fryer'))
          Appliance.airfryer,
        if (folded.contains('blender') || folded.contains('rondo'))
          Appliance.blender,
        if (RegExp(r'tava|tencere|ocak|kaynat|haslay|kavur|sotele')
            .hasMatch(folded))
          Appliance.ocak,
      };

  Set<Technique> _techniques(String folded) {
    final t = <Technique>{
      if (RegExp(r'kizart').hasMatch(folded)) Technique.kizartma,
      if (RegExp(r'hasla|kaynat').hasMatch(folded)) Technique.haslama,
      if (RegExp(r'sotele|kavur|sote').hasMatch(folded)) Technique.sote,
      if (folded.contains('firin')) Technique.firin,
      if (RegExp(r'karistir|cirp').hasMatch(folded)) Technique.karistirma,
    };
    return t.isEmpty ? {Technique.cig} : t;
  }
}

class _Item {
  _Item(this.ingredient, this.amount, this.measure, this.optional);

  final Ingredient ingredient;
  final double amount;
  final Measure measure;
  final bool optional;
}
