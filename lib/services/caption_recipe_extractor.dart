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

  /// TikTok açıklamasında satır sonları kaybolur: "Ingredients: - 2 cups …
  /// - 1 tsp …" → her " - " yeni madde ("5-6" gibi boşluksuz tire değil).
  static final _inlineBullet = RegExp(r'\s+[-–•▪]\s+(?=\S)');
  // Başlık sayılması için ardından ":" ya da satır sonu gelmeli; yoksa
  // "malzemeleri karıştırın" cümlesi de başlık sanılır.
  static final _ingredientsHeader = RegExp(
      r'(malzemeler|malzeme listesi|gerekli malzemeler|ihtiyacınız olanlar|'
      r'ihtiyacınız olan her şey|[iı]ngredients?|what you.?ll need|you.?ll need|'
      r'everything you need)\s*(?:[:：|]|(?=\n)|$)');
  static final _stepsHeader = RegExp(
      r'(yapılışı|yapılış|hazırlanışı|hazırlanış|nasıl yapılır|yapımı|[iı]nstructions?|directions?|method|steps|how to make|preparation)\s*(?:[:：]|(?=\n))');

  /// "Pankek tarifi: 2 yumurta, ..." → başlık "Pankek".
  static final _titleMarker = RegExp(r'^\s*([^\n:]{2,60}?)\s+tarifi\s*[:：]');

  /// Emir ya da bağlaç fiil ekleri: "çırpın", "pişirip", "karıştırarak".
  static final _verbEnding = RegExp(
      // "ekliyorum, döküyorum, kavurdum, pişireceğim" gibi kendi
      // mutfağını anlatan videolar da adım sayılır.
      r'(in|un|yin|yun|iniz|unuz|ip|up|yip|yup|erek|arak|yoruz|yorum|iyor|uyor|dik|duk|tik|tuk|dim|dum|tim|tum|ecegim|acagim|ecegiz|acagiz|elim|alim|iriz|eriz|ariz|urum|irim|erim|arim)$');
  static final _numberedStep = RegExp(r'(?:^|\s)\d{1,2}\s*[.)]\s+(?=\D)');
  static final _sentenceEnd = RegExp(r'(?<=[.!?])\s+');
  static final _timer = RegExp(r'(\d+)\s*(?:-\s*(\d+)\s*)?(dakika|dk|saat)');
  static final _readyIn =
      RegExp(r'(\d+)\s*(dakika|dk)(da|de)\s*(hazır|bitiyor)');
  static final _servingsRe = RegExp(
      r'(\d+)\s*kişilik|servings?\s*[:：]?\s*(\d+)|serves\s*(\d+)|(\d+)\s*servings');

  /// İngilizce başlık önündeki porsiyon yazısı: "Servings: 5-6".
  static final _servingsNoise = RegExp(
      r'servings?\s*[:：]?\s*[\d\s\-–]+|serves\s*[\d\s\-–]+',
      caseSensitive: false);

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
    // Çift dil satırları: "300 gr kıyma | 300 g lean beef" → Türkçe taraf.
    var text = caption
        .replaceAll(RegExp(r'[\u2028\u2029]'), '\n')
        .replaceAllMapped(
            RegExp(r'([^|\n]{2,160}?)\s*\|\s*([^|\n]{2,160})'), (m) => m[1]!)
        .replaceAll(_hashtag, ' ')
        .replaceAll(_emoji, '\n')
        .replaceAll('\r', '\n');
    // "köfte için:" / "for the meatballs:" bölüm başlıkları ayraçtır.
    text = text.replaceAllMapped(
        RegExp(r'(^|\n)\s*([^:\n|]{2,40}?)\s+için\s*[:：]?\s*',
            caseSensitive: false),
        (m) => '${m[1]}\n');
    text = text.replaceAllMapped(_bullet, (m) => '${m.group(1)}\n');
    if (_inlineBullet.allMatches(text).length >= 2) {
      text = text.replaceAll(_inlineBullet, '\n');
    }
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
    // "...takip etmeyi unutmayın TAVUK TANTUNİ (2 kişilik) 400 gr tavuğu..."
    // Büyük harfle yazılmış ad, giriş cümlesinden daha iyi bir başlıktır.
    final caps = marker == null && ingMatch == null ? _capsTitle(text) : null;
    // Açıklamanın kendisi yedek başlık olarak verildiyse kullanılmaz; yoksa
    // "Servings: 5-6 Ingredients: - 2 cups…" başlık olur.
    final fallback = fallbackTitle == null ||
            TurkishText.fold(fallbackTitle) == TurkishText.fold(caption)
        ? null
        : fallbackTitle;
    final foundTitle = _acceptableTitle(
        (caps != null ? _cleanTitle(_titleCase(caps)) : null) ??
            _cleanTitle(rawTitle) ??
            _cleanTitle(fallback ?? ''));

    String withoutCaps(String part) => caps == null
        ? part
        : part.replaceFirst(
            RegExp('${RegExp.escape(caps)}\\s*(\\(\\s*\\d+\\s*kişilik\\s*\\))?',
                caseSensitive: false),
            '\n');

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
      ingredientPart = withoutCaps(base.substring(titleEnd));
      stepPart = '';
    }

    final items = <String, _Item>{};
    final unmatched = <String>[];
    final leftover = <String>[];
    // Cümle cümle bakılır: "Hepsini çırpın, tavada pişirin." bir adımdır,
    // "2 yumurta, 1 su bardağı süt." ise malzeme listesi.
    for (final sentence in ingredientPart.split(RegExp(r'\n+|(?<=[.!?])\s+'))) {
      // "Tavuğu doğrayıp, tuz ekliyorum" virgülle bölünse de tek adımdır:
      // parçalardan biri fiille bitiyorsa cümlenin tamamı adım sayılır.
      if (_looksLikeStep(sentence) ||
          _ingredientChunks(sentence).any(_chunkIsVerbPhrase)) {
        leftover.add(sentence.trim());
        // Malzeme listesi yazılmamışsa malzemeler adım cümlelerinden bulunur.
        if (ingMatch == null) {
          for (final ing in _mentionedIngredients(sentence)) {
            final (amount, measure) = _defaultAmount(ing);
            items.putIfAbsent(ing.id, () => _Item(ing, amount, measure, false));
          }
        }
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
    final roled = _withRoles(items.values.toList());
    final title = foundTitle ?? _titleFromItems(roled) ?? 'Videodan tarif';
    final dessert = _isDessert(all, items.keys.toSet());
    final recipe = Recipe(
      id: id,
      title: title,
      emoji: dessert
          ? (items.keys.any(const {'cikolata', 'kakao'}.contains) ? '🍫' : '🍰')
          : _emojiFor(items.values),
      minutes: _minutes(lower, steps),
      difficulty: steps.length <= 4
          ? Difficulty.kolay
          : steps.length <= 8
              ? Difficulty.orta
              : Difficulty.zor,
      servings: int.tryParse(_servingsGroup(_servingsRe.firstMatch(lower)))
              ?.clamp(1, 12) ??
          2,
      items: roled,
      steps: steps,
      appliances: _appliances(all),
      techniques: _techniques(all),
      tags: {'videodan', if (dessert) 'tatli'},
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
    // "3 tablespoons maple syrup" de (4 kelime) malzemedir.
    if (words.length <= 5 && RegExp(r'^\d').hasMatch(words.first)) return false;
    final last = words.last;
    if (repo.findByName(last) != null) return false;
    return _verbEnding.hasMatch(last);
  }

  /// Büyük harfle yazılmış 2-5 kelimelik ad: "TAVUK TANTUNİ".
  static final _capsRun = RegExp(
      r'(?<![\p{L}])\p{Lu}{2,}(?:[ \t]+\p{Lu}{2,}){1,4}(?![\p{L}])',
      unicode: true);

  String? _capsTitle(String text) {
    for (final m in _capsRun.allMatches(text)) {
      final s = m.group(0)!;
      // "500 GR" ya da tek kelimelik vurgu ("ÇOK") başlık değildir.
      if (s.replaceAll(' ', '').length >= 6) return s;
    }
    return null;
  }

  static String _titleCase(String s) => s
      .split(RegExp(r'\s+'))
      .map((w) => _capitalize(TurkishText.lower(w)))
      .join(' ');

  /// "dilimleyip", "tuz ekliyorum": son kelimesi fiil olan virgüllü parça.
  bool _chunkIsVerbPhrase(String chunk) {
    final words = TurkishText.fold(chunk)
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return false;
    final last = words.last;
    // "3 tablespoons maple syrup": sayıyla başlayan kısa parça malzemedir
    // ("syrup" sonundaki -up Türkçe fiil eki sanılmasın).
    if (RegExp(r'^\d').hasMatch(words.first) && words.length <= 6) return false;
    if (last.length < 5 || repo.findByName(last) != null) return false;
    return _verbEnding.hasMatch(last);
  }

  /// Adım cümlesinde geçen katalog malzemeleri: "tavukları doğrayıp tuz
  /// ekliyorum" → tavuk, tuz. Önce iki kelimelik adlar ("domates salçası").
  List<Ingredient> _mentionedIngredients(String sentence) {
    final words = TurkishText.lower(sentence)
        .replaceAll(RegExp(r'[^\p{L}\s]', unicode: true), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 2)
        .toList();
    final found = <Ingredient>[];
    var i = 0;
    while (i < words.length) {
      Ingredient? hit;
      var used = 1;
      if (i + 1 < words.length) {
        final pair = _index2(words[i], words[i + 1]);
        if (pair != null) {
          hit = pair;
          used = 2;
        }
      }
      if (hit == null && !_verbEnding.hasMatch(TurkishText.fold(words[i]))) {
        hit = _exact(words[i]);
      }
      if (hit != null && !found.contains(hit)) found.add(hit);
      i += used;
    }
    return found;
  }

  /// Tek kelime için yalnızca kelimenin kendisi ya da ekleri atılmış hâli
  /// ("tavukları" → tavuk); "sosundan" gibi tahminlere gidilmez.
  Ingredient? _exact(String word) {
    for (final stem in TurkishText.stems(word)) {
      if (stem.length < 2) continue;
      final hit = repo.findByName(stem);
      if (hit != null && TurkishText.fold(hit.name).split(' ').length == 1) {
        return hit;
      }
    }
    return null;
  }

  Ingredient? _index2(String a, String b) {
    final hit = repo.findByName('$a $b');
    if (hit == null) return null;
    // findByName son kelimeye düşebilir; gerçekten iki kelimelik ad olmalı.
    return TurkishText.fold(hit.name).contains(' ') ? hit : null;
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
      r'\s*[!.]*\s*(mutlaka|hemen|siz de|kesinlikle)\s+(deneyin|yapın|deneyiniz)\S*|'
      r'^\s*(viral|trend|efsane)\s+|'
      r'\s+(tarifi|çok kolay|kolay|pratik|nefis)\s*$',
      caseSensitive: false);

  static String _servingsGroup(RegExpMatch? m) {
    if (m == null) return '';
    for (var i = 1; i <= m.groupCount; i++) {
      if (m.group(i) != null) return m.group(i)!;
    }
    return '';
  }

  /// Başlık yalnızca malzeme adlarından oluşmasın ("Yoğurt ve süt").
  static const _stapleTitleIds = {
    'sut',
    'su',
    'tuz',
    'karabiber',
    'zeytinyagi',
    'tereyagi',
    'un',
  };

  /// Bilinen malzeme çiftleri → tanıdık yemek adı.
  static const _comboTitles = <String, String>{
    'chia|sut': 'Chia puding',
    'chia|yogurt': 'Chia puding',
    'yumurta|sut|un': 'Pankek',
    'kiyma|pirinc': 'Kıymalı pilav',
  };

  /// Eski kayıtlarda "Yoğurt ve süt" gibi başlıklar zayıf sayılır.
  bool titleIsIngredientList(String title) => _isIngredientListTitle(title);

  /// "Yoğurt ve süt" gibi salt malzeme listesini başlık sayma.
  String? _acceptableTitle(String? title) {
    if (title == null || title.isEmpty) return null;
    if (_isIngredientListTitle(title)) return null;
    if (_isMetaLine(title)) return null;
    return title;
  }

  /// "6-8 kişilik Hazırlama: 20 Dakika Pişirme: 15 dakika", "Servings: 4",
  /// "Süre: 30 dk" gibi porsiyon/süre satırları yemek adı değildir.
  static final _metaLine = RegExp(
      r'^\s*(\d+\s*[-–]?\s*\d*\s*(kişilik|porsiyon)|hazırlama|hazırlık|pişirme|'
      r'süre|porsiyon|servings?|serves|prep|cook(ing)? time|total time)\b|'
      r'(hazırlama|hazırlık|pişirme)\s*(süresi)?\s*[:：]',
      caseSensitive: false);

  static bool _isMetaLine(String title) =>
      _metaLine.hasMatch(TurkishText.lower(title));

  bool _isIngredientListTitle(String title) {
    final cleaned = title
        .replaceAll(RegExp(r'\s+tarifi$', caseSensitive: false), '')
        .trim();
    final parts = cleaned
        .split(RegExp(r'\s*(?:ve|and|&|/|,|\+)\s*', caseSensitive: false))
        .map((p) => p.trim())
        .where((p) => p.length >= 2)
        .toList();
    if (parts.isEmpty) return false;
    // Tek kelime / tek parça: tam malzeme adıyla aynıysa zayıf başlık.
    if (parts.length == 1) {
      final hit = repo.findByName(parts.first);
      return hit != null &&
          TurkishText.fold(hit.name) == TurkishText.fold(parts.first);
    }
    var hits = 0;
    for (final p in parts) {
      if (repo.findByName(p) != null) hits++;
    }
    return hits >= parts.length;
  }

  /// Başlık yoksa: bilinen kombo, yoksa tek belirgin ana malzeme + "tarifi".
  /// "A ve B" biçimi kullanılmaz (kullanıcı düzeltmek zorunda kalıyordu).
  String? _titleFromItems(List<RecipeItem> items) {
    final mains = [
      for (final i in items)
        if (i.isMain) repo.byId(i.ingredientId)
    ];
    if (mains.isEmpty) return null;
    final ids = [for (final m in mains) m.id]..sort();
    final key = ids.join('|');
    for (final entry in _comboTitles.entries) {
      final need = entry.key.split('|')..sort();
      if (need.every(ids.contains)) return entry.value;
    }
    final distinctive = [
      for (final m in mains)
        if (!_stapleTitleIds.contains(m.id)) m
    ];
    // En ağır belirgin ana malzeme (roller ağırlığa göre verilir):
    // "Tavuk göğsü tarifi".
    if (distinctive.isNotEmpty) {
      return '${distinctive.first.name} tarifi';
    }
    return null;
  }

  /// Kayıtlı tarifin başlığı bozuksa ("6-8 kişilik Hazırlama: 20…",
  /// "Videodan tarif", malzeme listesi) malzemelerden yenisi; iyiyse null.
  String? repairedTitle(Recipe r) {
    final t = r.title.trim();
    final bad = t.isEmpty ||
        t == 'Videodan tarif' ||
        _isMetaLine(t) ||
        _isIngredientListTitle(t);
    if (!bad) return null;
    final better = _titleFromItems(r.items);
    return better == null || better == t ? null : better;
  }

  /// Kayıtlı tarifin görseli süt/su gibi sıradan bir malzemeyse, başlıktaki
  /// belirgin ana malzemenin görseli; iyiyse null.
  /// Videonun kendi başlığından tarif adı: "Viral Tatlı Spoonful Tarifi 🥄
  /// Mutlaka Deneyin! ✅" → "Tatlı Spoonful". Kullanılamazsa null.
  String? titleFromVideoTitle(String raw) {
    final noEmoji = raw.replaceAll(_emoji, ' ').replaceAll(_hashtag, ' ');
    final t = _cleanTitle(noEmoji.split(RegExp(r'\s+[|–-]\s+')).first);
    return t == null ? null : _acceptableTitle(t);
  }

  String? repairedEmoji(Recipe r) {
    final ids = {for (final i in r.items) i.ingredientId};
    if (r.source != null &&
        (r.tags.contains('tatli') ||
            _isDessert(TurkishText.fold(r.title), ids))) {
      final want = ids.any(const {'cikolata', 'kakao'}.contains) ? '🍫' : '🍰';
      return r.emoji == want ? null : want;
    }
    final mains = [
      for (final i in r.items)
        if (i.isMain &&
            !_stapleTitleIds.contains(i.ingredientId) &&
            repo.tryById(i.ingredientId) != null)
          repo.byId(i.ingredientId)
    ];
    if (mains.isEmpty) return null;
    final current = [
      for (final i in r.items)
        if (repo.tryById(i.ingredientId)?.emoji == r.emoji) i.ingredientId
    ];
    final bland = r.emoji == '🍽️' || current.every(_stapleTitleIds.contains);
    if (!bland || mains.first.emoji == r.emoji) return null;
    return mains.first.emoji;
  }

  String? _cleanTitle(String raw) {
    var t = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    t = t.replaceAll(_servingsNoise, '').trim();
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

  /// Miktarı yazılmamış malzemeye 2 kişilik tipik miktar. Önceden salça ve
  /// yağ bile "1 tutam" (yarım gram) sayılıyor, tarifin kalori ve maliyeti
  /// neredeyse sıfır çıkıyordu.
  /// Eski sürümün "1 tutam" saydığı salça/yağ gibi malzemeleri 2 yemek
  /// kaşığına çevirir; değişiklik yoksa null.
  List<Map<String, dynamic>>? repairedItems(Recipe r) {
    var changed = false;
    final out = <Map<String, dynamic>>[];
    for (final i in r.items) {
      final j = i.toJson();
      final ing = repo.tryById(i.ingredientId);
      if (ing != null &&
          i.measure == Measure.tutam &&
          i.amount <= 1 &&
          _spoonful.contains(ing.id)) {
        j['amount'] = 2;
        j['measure'] = Measure.yemekKasigi.name;
        changed = true;
      }
      out.add(j);
    }
    return changed ? out : null;
  }

  static const _spoonful = {
    'salca',
    'zeytinyagi',
    'sivi_yag',
    'tereyagi',
    'bal',
    'pekmez',
    'tahin',
    'soya_sosu',
    'hardal',
    'krema',
    'fistik_ezmesi',
    'un',
    'seker',
    'nisasta',
    'kakao',
    'yogurt',
  };

  (double, Measure) _defaultAmount(Ingredient ing) {
    if (_spoonful.contains(ing.id)) return (2, Measure.yemekKasigi);
    final tags = repo.tagsOf(ing.id);
    // Et, tavuk, balık: kişi başı ~150 g.
    if (tags.contains(FoodTag.meat) || tags.contains(FoodTag.fish)) {
      return (300, Measure.gram);
    }
    if (ing.isStaple) return (1, Measure.tutam);
    if (ing.baseUnit == BaseUnit.piece) return (2, Measure.adet);
    if (ing.baseUnit == BaseUnit.ml) return (200, Measure.ml);
    return (200, Measure.gram);
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

  /// "Tatlı", "muhallebi" gibi sözcükler ya da şeker + un/nişasta +
  /// çikolata/krema bileşimi: tatlı.
  static bool _isDessert(String folded, Set<String> ids) {
    if (RegExp(r'\b(tatli|tatlisi|tatlilar\w*|muhallebi\w*|puding|pasta|kek|'
            r'spoonful|cheesecake|brownie|kurabiye|sutlac|helva|tiramisu)\b')
        .hasMatch(folded)) {
      return true;
    }
    return ids.contains('seker') &&
        (ids.contains('un') || ids.contains('nisasta')) &&
        ids.any(const {'cikolata', 'kakao', 'krema'}.contains);
  }

  String _emojiFor(Iterable<_Item> items) {
    final main = items
        .where((i) =>
            !i.ingredient.isStaple &&
            !_stapleTitleIds.contains(i.ingredient.id))
        .toList()
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
