import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models/cook_log.dart';
import '../models/pantry_item.dart';
import '../models/recipe.dart';
import '../models/user_profile.dart';
import '../services/caption_recipe_extractor.dart';
import '../services/collections.dart';
import '../services/ingredient_repository.dart';
import '../services/meal_planner.dart';
import '../services/quantity_parser.dart';
import '../services/recipe_matcher.dart';
import '../services/storage_service.dart';
import '../services/unit_converter.dart';
import '../utils/format.dart';

typedef PantryInput = ({
  String ingredientId,
  double? quantity,
  ApproxLevel? level
});

/// Yarım kalan pişirme; uygulama kapansa bile kaldığı adımdan devam edilir.
class ActiveCooking {
  const ActiveCooking(
      {required this.recipeId, required this.servings, required this.step});

  final String recipeId;
  final int servings;
  final int step;

  Map<String, dynamic> toJson() =>
      {'recipeId': recipeId, 'servings': servings, 'step': step};

  factory ActiveCooking.fromJson(Map<String, dynamic> j) => ActiveCooking(
      recipeId: j['recipeId'] as String,
      servings: j['servings'] as int,
      step: j['step'] as int);
}

class CookOutcome {
  const CookOutcome({
    required this.previousPantry,
    required this.rescuedGrams,
    required this.weeklyStreak,
    required this.cooksThisWeek,
  });

  /// "Geri al" için pişirmeden önceki dolap.
  final List<PantryItem> previousPantry;
  final double rescuedGrams;
  final int weeklyStreak;
  final int cooksThisWeek;
}

class AppState extends ChangeNotifier {
  AppState({
    required this.repo,
    required List<Recipe> recipes,
    required StorageService storage,
  })  : _catalog = List.unmodifiable(recipes),
        _storage = storage,
        matcher = RecipeMatcher(repo);

  /// Haftalık seri için gereken pişirme sayısı.
  static const cooksPerWeekForStreak = 3;

  /// Ankette "haftada kaç gün" cevabı; yoksa varsayılan.
  int get weeklyGoal => _profile.cookDaysPerWeek ?? cooksPerWeekForStreak;

  /// Bu kadar gün içinde bozulacak ürünler "yakında bozulacak" sayılır.
  static const expiringDays = 2;

  final IngredientRepository repo;
  final List<Recipe> _catalog;
  List<Recipe> _imported = [];
  List<Recipe>? _allRecipes;
  final RecipeMatcher matcher;
  final StorageService _storage;

  List<PantryItem> _pantry = [];
  UserProfile _profile = const UserProfile();
  List<CookLog> _logs = [];
  Set<String> _favorites = {};
  List<String> _shopping = [];
  ActiveCooking? _active;
  List<UserCollection> _collections = [];
  List<String> _plan = [];
  DateTime? _planStart;
  int _idCounter = 0;

  /// Katalog + videodan kaydedilenler (en yeni kayıt başta).
  List<Recipe> get recipes =>
      _allRecipes ??= [..._imported.reversed, ..._catalog];

  List<Recipe> get importedRecipes => List.unmodifiable(_imported.reversed);

  List<PantryItem> get pantry => List.unmodifiable(_pantry);
  UserProfile get profile => _profile;
  ActiveCooking? get activeCooking =>
      _active != null && tryRecipe(_active!.recipeId) != null ? _active : null;

  Recipe recipeById(String id) => recipes.firstWhere((r) => r.id == id);

  Recipe? tryRecipe(String id) {
    for (final r in recipes) {
      if (r.id == id) return r;
    }
    return null;
  }

  // ---------------------------------------------------------------- Kayıt

  Future<void> load() async {
    final data = await _storage.load();
    if (data == null) return;
    try {
      _apply(data);
    } catch (e) {
      debugPrint('Kayıtlı veri bozuk, sıfırdan başlanıyor: $e');
      _pantry = [];
      _profile = const UserProfile();
      _logs = [];
      _favorites = {};
      _shopping = [];
      _active = null;
      _imported = [];
      _allRecipes = null;
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------- Yedek
  //
  // Hesap ve sunucu yok: veriler yalnızca telefonda. Uygulama silinir ya da
  // telefon değişirse kaybolmasın diye kullanıcı yedek dosyası alır (iCloud
  // Drive'a, Dosyalar'a kaydeder ya da kendine gönderir) ve geri yükler.

  static const backupApp = 'buzdolabi-sefi';
  static const backupVersion = 1;

  DateTime? _lastBackupAt;

  /// En son yedek alınan an (hiç alınmadıysa null).
  DateTime? get lastBackupAt => _lastBackupAt;

  /// Yedek dosyasının içeriği. Fotoğraflar dahil değildir (telefonda kalır).
  String exportBackup() {
    _lastBackupAt = DateTime.now();
    _changed();
    return const JsonEncoder.withIndent(' ').convert({
      'app': backupApp,
      'backupVersion': backupVersion,
      'exportedAt': _lastBackupAt!.toIso8601String(),
      'data': _toJson(),
    });
  }

  /// Yedek dosyasını geri yükler; bu telefondaki verilerin yerine geçer.
  /// Dosya bu uygulamanın değilse ya da bozuksa hiçbir şey değişmez ve
  /// [FormatException] atılır.
  void importBackup(String content) {
    final Object? decoded;
    try {
      decoded = jsonDecode(content);
    } catch (_) {
      throw const FormatException('Bu bir yedek dosyası değil.');
    }
    if (decoded is! Map || decoded['app'] != backupApp) {
      throw const FormatException('Bu dosya Buzdolabı Şefi yedeği değil.');
    }
    final version = decoded['backupVersion'];
    if (version is! int || version > backupVersion) {
      throw const FormatException(
          'Bu yedek uygulamanın daha yeni bir sürümünden; önce güncelle.');
    }
    final data = decoded['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Yedek dosyası eksik.');
    }
    final before = _toJson();
    try {
      _apply(data);
    } catch (e) {
      _apply(before); // bozuk yedek mevcut veriyi bozmasın
      throw const FormatException('Yedek dosyası bozuk; verilerin korundu.');
    }
    _changed();
  }

  void _apply(Map<String, dynamic> data) {
    {
      _pantry = [
        for (final j in (data['pantry'] as List? ?? const []))
          PantryItem.fromJson(j as Map<String, dynamic>)
      ].where((p) => repo.tryById(p.ingredientId) != null).toList();
      if (data['profile'] != null) {
        _profile =
            UserProfile.fromJson(data['profile'] as Map<String, dynamic>);
      }
      _logs = [
        for (final j in (data['logs'] as List? ?? const []))
          CookLog.fromJson(j as Map<String, dynamic>)
      ];
      _favorites = {
        for (final f in (data['favorites'] as List? ?? const [])) f as String
      };
      _shopping = [
        for (final s in (data['shopping'] as List? ?? const []))
          if (repo.tryById(s as String) != null) s
      ];
      _active = data['active'] == null
          ? null
          : ActiveCooking.fromJson(data['active'] as Map<String, dynamic>);
      _imported = _loadImported(data['imported']);
      _collections = [
        for (final c in (data['collections'] as List? ?? const []))
          UserCollection.fromJson(c as Map<String, dynamic>)
      ];
      final plan = data['plan'] as Map<String, dynamic>?;
      _plan = [
        for (final id in (plan?['ids'] as List? ?? const [])) id as String
      ];
      _planStart = plan?['start'] == null
          ? null
          : DateTime.parse(plan!['start'] as String);
      _lastBackupAt = data['lastBackupAt'] == null
          ? null
          : DateTime.parse(data['lastBackupAt'] as String);
      _allRecipes = null;
      matcher.clearCache();
    }
  }

  /// Bozuk ya da artık kataloğumuzda olmayan malzemeli kayıtlar atlanır.
  List<Recipe> _loadImported(Object? raw) {
    final result = <Recipe>[];
    for (final j in (raw as List? ?? const [])) {
      try {
        final r = Recipe.fromJson(j as Map<String, dynamic>);
        if (r.items.every((i) => repo.tryById(i.ingredientId) != null)) {
          result.add(r);
        }
      } catch (e) {
        debugPrint('Kaydedilen tarif okunamadı: $e');
      }
    }
    // Eski sürümlerin bıraktığı bozuk başlıklar ("6-8 kişilik Hazırlama:
    // 20…", "Videodan tarif") malzemelerden düzeltilir: "Tavuk göğsü tarifi".
    final extractor = CaptionRecipeExtractor(repo);
    for (var i = 0; i < result.length; i++) {
      final better = extractor.repairedTitle(result[i]);
      if (better != null) {
        result[i] = Recipe.fromJson({...result[i].toJson(), 'title': better});
      }
    }
    // Eski sürümlerde aynı video farklı linkle iki kez kaydedilebiliyordu;
    // daha çok adımı olan (eşitse sonraki) kayıt kalır.
    final unique = <Recipe>[];
    for (final r in result) {
      final i = unique.indexWhere((u) =>
          u.source != null &&
          r.source != null &&
          sameVideo(u.source!, r.source!));
      if (i < 0) {
        unique.add(r);
      } else if (r.steps.length >= unique[i].steps.length) {
        // Silinen kopya favorideyse kalan kayıt favoride olur.
        if (_favorites.remove(unique[i].id)) _favorites.add(r.id);
        unique[i] = r;
      }
    }
    return unique;
  }

  Map<String, dynamic> _toJson() => {
        'pantry': [for (final p in _pantry) p.toJson()],
        'profile': _profile.toJson(),
        'logs': [for (final l in _logs) l.toJson()],
        'favorites': _favorites.toList(),
        'shopping': _shopping,
        'active': _active?.toJson(),
        'imported': [for (final r in _imported) r.toJson()],
        'collections': [for (final c in _collections) c.toJson()],
        if (_plan.isNotEmpty)
          'plan': {'start': _planStart?.toIso8601String(), 'ids': _plan},
        if (_lastBackupAt != null)
          'lastBackupAt': _lastBackupAt!.toIso8601String(),
      };

  void _changed() {
    _storage.save(_toJson());
    notifyListeners();
  }

  // ---------------------------------------------------------------- Dolap

  String _newId() => '${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}';

  /// Aynı malzeme zaten varsa miktarı yenisiyle değiştirilir
  /// (kullanıcı "dolabımda şu an bu kadar var" diyor).
  void _upsert(String ingredientId, double? quantity, ApproxLevel? level) {
    final ing = repo.byId(ingredientId);
    final idx = _pantry.indexWhere((p) => p.ingredientId == ingredientId);
    if (idx >= 0) {
      _pantry[idx] = _pantry[idx].copyWith(
        quantity: quantity,
        level: level,
        clearQuantity: quantity == null,
        clearLevel: level == null,
        checkedAt: DateTime.now(),
      );
    } else {
      final now = DateTime.now();
      _pantry.add(PantryItem(
        id: _newId(),
        ingredientId: ingredientId,
        quantity: quantity,
        level: level,
        addedAt: now,
        expiresAt: now.add(Duration(days: ing.shelfLifeDays)),
      ));
    }
  }

  void upsertPantry(String ingredientId,
      {double? quantity, ApproxLevel? level}) {
    _upsert(ingredientId, quantity, level);
    _changed();
  }

  void upsertPantryAll(Iterable<PantryInput> inputs) {
    for (final i in inputs) {
      _upsert(i.ingredientId, i.quantity, i.level);
    }
    _changed();
  }

  /// Var olana miktar ekler ("6 yumurta ekle"); yoksa yeni satır açar.
  void addToPantry(String ingredientId,
      {double? quantity, ApproxLevel? level}) {
    final ing = repo.byId(ingredientId);
    final idx = _pantry.indexWhere((p) => p.ingredientId == ingredientId);
    if (idx < 0) {
      _upsert(ingredientId, quantity, level);
    } else {
      final added =
          quantity ?? (level ?? ApproxLevel.biraz).fraction * ing.packageAmount;
      _upsert(ingredientId, _pantry[idx].baseAmount(ing) + added, null);
    }
    _changed();
  }

  /// Siri / derin bağlantı: "6 yumurta" metnini dolaba ekler.
  /// Tanınmayan parçaların ham metnini döner.
  List<String> addPantryFromText(String text) {
    final unknown = <String>[];
    for (final e in QuantityParser(repo).parse(text)) {
      final ing = e.ingredient;
      if (ing == null) {
        if (e.raw.trim().isNotEmpty) unknown.add(e.raw.trim());
        continue;
      }
      addToPantry(ing.id, quantity: e.quantity, level: e.level);
    }
    return unknown;
  }

  void updatePantryItem(PantryItem item) {
    final idx = _pantry.indexWhere((p) => p.id == item.id);
    if (idx < 0) return;
    // Kullanıcı elle düzelttiyse bu malzeme "kontrol edilmiş" sayılır.
    _pantry[idx] = item.copyWith(checkedAt: DateTime.now());
    _changed();
  }

  // ---------------------------------------------------------------- Dolap kontrolü
  //
  // İnsanlar yemeklerin çoğunu uygulamayı açmadan pişirir; dolap zamanla
  // gerçekten uzaklaşır. Bir haftadır dokunulmayan malzemeler tek dokunuşla
  // "Hâlâ var / Azaldı / Bitti" diye sorulur.

  static const staleAfter = Duration(days: 7);

  /// Bir haftadır kontrol edilmeyen malzemeler, en eskisi önce.
  List<PantryItem> get staleItems {
    final now = DateTime.now();
    return [
      for (final p in _pantry)
        if (now.difference(p.lastSeen) >= staleAfter) p
    ]..sort((a, b) => a.lastSeen.compareTo(b.lastSeen));
  }

  void confirmPantryItem(String id) {
    final idx = _pantry.indexWhere((p) => p.id == id);
    if (idx < 0) return;
    _pantry[idx] = _pantry[idx].copyWith(checkedAt: DateTime.now());
    _changed();
  }

  /// "Azaldı": kesin miktar yarıya iner; yaklaşık seviye bir basamak düşer
  /// (bol → biraz → az). Zaten "az" ise az kalır.
  void reducePantryItem(String id) {
    final idx = _pantry.indexWhere((p) => p.id == id);
    if (idx < 0) return;
    final p = _pantry[idx];
    final now = DateTime.now();
    if (p.quantity != null) {
      _pantry[idx] = p.copyWith(quantity: p.quantity! / 2, checkedAt: now);
    } else {
      final next = switch (p.level ?? ApproxLevel.biraz) {
        ApproxLevel.bol => ApproxLevel.biraz,
        _ => ApproxLevel.az,
      };
      _pantry[idx] = p.copyWith(level: next, checkedAt: now);
    }
    _changed();
  }

  void removePantryItem(String id) {
    _pantry.removeWhere((p) => p.id == id);
    _changed();
  }

  void restorePantry(List<PantryItem> items) {
    _pantry = List.of(items);
    _changed();
  }

  /// Yalnızca yerel test sunucusunda: dolabı ve pişirme geçmişini (haftalık
  /// sayaç, seri, ilerleme) boşaltır; uygulama ilk kez açılmış gibi olur.
  void resetForTesting() {
    _pantry = [];
    _logs = [];
    _changed();
  }

  bool _isExpiring(PantryItem p, DateTime now) =>
      p.expiresAt != null && daysUntil(p.expiresAt!, now) <= expiringDays;

  List<PantryItem> get expiringItems {
    final now = DateTime.now();
    return [
      for (final p in _pantry)
        if (_isExpiring(p, now)) p
    ]..sort((a, b) => a.expiresAt!.compareTo(b.expiresAt!));
  }

  // Ekranlar her yeniden çizimde (animasyonlarda saniyede onlarca kez) tüm
  // tarifleri eşleştiriyordu. Sonuç, veri değişene ya da bir dakika
  // geçene kadar (bozulma tarihleri için) saklanır.
  final _matchCache = <QuickFilters, List<RecipeMatch>>{};
  PantrySnapshot? _snapshotCache;
  DateTime? _cacheTime;

  bool get _cacheFresh =>
      _cacheTime != null &&
      DateTime.now().difference(_cacheTime!) < const Duration(minutes: 1);

  @override
  void notifyListeners() {
    _matchCache.clear();
    _snapshotCache = null;
    _cacheTime = null;
    super.notifyListeners();
  }

  PantrySnapshot get snapshot {
    if (_snapshotCache != null && _cacheFresh) return _snapshotCache!;
    if (!_cacheFresh) _matchCache.clear();
    _cacheTime = DateTime.now();
    return _snapshotCache = _buildSnapshot();
  }

  PantrySnapshot _buildSnapshot() {
    final now = DateTime.now();
    final grams = <String, double>{};
    final expiring = <String>{};
    for (final p in _pantry) {
      final ing = repo.tryById(p.ingredientId);
      if (ing == null) continue;
      grams[p.ingredientId] = (grams[p.ingredientId] ?? 0) +
          UnitConverter.baseToGrams(ing, p.baseAmount(ing));
      if (_isExpiring(p, now)) expiring.add(p.ingredientId);
    }
    return PantrySnapshot(
      gramsById: grams,
      expiringIds: expiring,
      stapleIds: {
        for (final s in repo.staples)
          if (!_profile.missingStaples.contains(s.id)) s.id
      },
    );
  }

  bool isStapleAvailable(String ingredientId) =>
      (repo.tryById(ingredientId)?.isStaple ?? false) &&
      !_profile.missingStaples.contains(ingredientId);

  List<RecipeMatch> matches(QuickFilters filters) {
    final snap = snapshot; // süresi dolduysa önbelleği de temizler
    return _matchCache[filters] ??=
        List.unmodifiable(matcher.rank(recipes, snap, _profile, filters));
  }

  // ---------------------------------------------------------------- Alışveriş listesi

  List<String> get shoppingList => List.unmodifiable(_shopping);

  bool isOnShoppingList(String ingredientId) =>
      _shopping.contains(ingredientId);

  /// Listede olmayanları ekler; eklenen sayıyı döndürür.
  int addToShopping(Iterable<String> ingredientIds) {
    var added = 0;
    for (final id in ingredientIds) {
      if (repo.tryById(id) == null || _shopping.contains(id)) continue;
      _shopping.add(id);
      added++;
    }
    if (added > 0) _changed();
    return added;
  }

  void removeFromShopping(String ingredientId) {
    if (_shopping.remove(ingredientId)) _changed();
  }

  /// "Aldım": listeden çıkar, dolaba tipik paket miktarıyla ekler.
  void buyFromShopping(String ingredientId) {
    _shopping.remove(ingredientId);
    _upsert(ingredientId, null, ApproxLevel.bol);
    _changed();
  }

  // ---------------------------------------------------------------- Pişirme

  void setActiveCooking(ActiveCooking? active) {
    _active = active;
    _changed();
  }

  /// Kullanılan malzemeleri dolaptan düşer ve pişirmeyi kaydeder.
  /// [gramsByIngredient]: dolaptan düşülecek malzemeler (gram).
  CookOutcome recordCook(
    Recipe recipe,
    int servings,
    Map<String, double> gramsByIngredient, {
    int? rating,
    String? note,
  }) {
    final previous = List<PantryItem>.of(_pantry);
    var rescued = 0.0;
    gramsByIngredient.forEach((id, grams) => rescued += _deduct(id, grams));
    final trimmed = note?.trim();
    _logs.add(CookLog(
      recipeId: recipe.id,
      cookedAt: DateTime.now(),
      servings: servings,
      rating: rating,
      note: (trimmed == null || trimmed.isEmpty) ? null : trimmed,
      rescuedGrams: rescued,
    ));
    if (_active?.recipeId == recipe.id) _active = null;
    _changed();
    return CookOutcome(
      previousPantry: previous,
      rescuedGrams: rescued,
      weeklyStreak: weeklyStreak,
      cooksThisWeek: cooksThisWeek,
    );
  }

  /// Bu tarifte en son yazılan not ve en son puan (sonraki sefere hatırlatma).
  ({int? rating, String? note})? lastCookMemory(String recipeId) {
    int? rating;
    String? note;
    for (final l in _logs.reversed) {
      if (l.recipeId != recipeId) continue;
      rating ??= l.rating;
      final n = l.note?.trim();
      if (note == null && n != null && n.isNotEmpty) note = n;
      if (rating != null && note != null) break;
    }
    if (rating == null && note == null) return null;
    return (rating: rating, note: note);
  }

  /// Önce tam eşleşen, sonra en erken bozulacak ürünlerden düşer.
  /// Bozulmak üzere olan üründen kullanılan miktarı döndürür.
  double _deduct(String ingredientId, double grams) {
    final now = DateTime.now();
    final candidates = _pantry
        .where((p) => repo.isSameOrDescendant(p.ingredientId, ingredientId))
        .toList()
      ..sort((a, b) {
        final exactA = a.ingredientId == ingredientId ? 0 : 1;
        final exactB = b.ingredientId == ingredientId ? 0 : 1;
        if (exactA != exactB) return exactA.compareTo(exactB);
        final ea = a.expiresAt ?? DateTime(9999);
        final eb = b.expiresAt ?? DateTime(9999);
        return ea.compareTo(eb);
      });

    var remaining = grams;
    var rescued = 0.0;
    for (final item in candidates) {
      if (remaining <= 0) break;
      final ing = repo.byId(item.ingredientId);
      final have = UnitConverter.baseToGrams(ing, item.baseAmount(ing));
      final take = math.min(have, remaining);
      remaining -= take;
      if (item.expiresAt != null && daysUntil(item.expiresAt!, now) <= 3) {
        rescued += take;
      }
      final left = have - take;
      final idx = _pantry.indexWhere((p) => p.id == item.id);
      // Artıktan yarım porsiyondan az kaldıysa "bitti" sayılır; dolapta
      // birkaç gramlık pilav takılı kalmasın.
      final leftoverCrumbs =
          ing.leftover && left < leftoverPortionGrams(ing.id) / 2;
      if (left < 1 || left <= have * 0.02 || leftoverCrumbs) {
        _pantry.removeAt(idx);
      } else {
        _pantry[idx] = item.copyWith(
            quantity: UnitConverter.gramsToBase(ing, left),
            clearLevel: true,
            checkedAt: now);
      }
    }
    return rescued;
  }

  // ---------------------------------------------------------------- İlerleme

  static DateTime _weekStart(DateTime d) =>
      DateTime.utc(d.year, d.month, d.day - (d.weekday - 1));

  Map<DateTime, int> get _cooksPerWeek {
    final counts = <DateTime, int>{};
    for (final l in _logs) {
      final w = _weekStart(l.cookedAt);
      counts[w] = (counts[w] ?? 0) + 1;
    }
    return counts;
  }

  int get cooksThisWeek => _cooksPerWeek[_weekStart(DateTime.now())] ?? 0;

  /// Haftada en az 3 pişirme yapılan ardışık haftalar. İçinde bulunulan hafta
  /// henüz tamamlanmadıysa seri bozulmuş sayılmaz.
  int get weeklyStreak {
    final counts = _cooksPerWeek;
    var week = _weekStart(DateTime.now());
    var streak = 0;
    if ((counts[week] ?? 0) >= weeklyGoal) streak++;
    week = DateTime.utc(week.year, week.month, week.day - 7);
    while ((counts[week] ?? 0) >= weeklyGoal) {
      streak++;
      week = DateTime.utc(week.year, week.month, week.day - 7);
    }
    return streak;
  }

  int get totalCooks => _logs.length;

  double get totalRescuedGrams =>
      _logs.fold(0.0, (sum, l) => sum + l.rescuedGrams);

  Map<Technique, int> get techniqueCounts {
    final counts = {for (final t in Technique.values) t: 0};
    for (final l in _logs) {
      final r = tryRecipe(l.recipeId);
      if (r == null) continue;
      for (final t in r.techniques) {
        counts[t] = counts[t]! + 1;
      }
    }
    return counts;
  }

  List<CookLog> get recentLogs => _logs.reversed.take(10).toList();

  // ---------------------------------------------------------------- Haftalık plan

  late final planner = MealPlanner(matcher, repo);

  List<String> get planIds => List.unmodifiable(_plan);
  DateTime? get planStart => _planStart;

  /// Plandaki akşam sayısı: ankette "haftada kaç gün" cevabı.
  int get planLength => weeklyGoal.clamp(1, 7);

  /// Dolaptakilere göre yeni plan çıkarır.
  void makePlan() {
    _plan = planner.plan(
        recipes: recipes,
        pantry: snapshot,
        profile: _profile,
        nights: planLength);
    final now = DateTime.now();
    _planStart = DateTime(now.year, now.month, now.day);
    _changed();
  }

  /// Bir akşamı başka bir tarifle değiştirir; diğer akşamlar yerinde kalır.
  void swapPlanNight(int index, {Set<String> alsoAvoid = const {}}) {
    if (index < 0 || index >= _plan.length) return;
    _plan = planner.plan(
      recipes: recipes,
      pantry: snapshot,
      profile: _profile,
      nights: _plan.length,
      keep: {
        for (var i = 0; i < _plan.length; i++)
          if (i != index) i: _plan[i]
      },
      avoid: {_plan[index], ...alsoAvoid},
    );
    _changed();
  }

  void clearPlan() {
    _plan = [];
    _planStart = null;
    _changed();
  }

  List<PlanNight> get planNights => planner.evaluate(
      recipeIds: _plan, recipes: recipes, pantry: snapshot, profile: _profile);

  // ---------------------------------------------------------------- Günlük takip

  List<CookLog> get logs => List.unmodifiable(_logs);

  /// Pişirme kaydını günceller (yenen porsiyon, fotoğraf, puan, not).
  void updateLog(DateTime cookedAt, CookLog Function(CookLog) change) {
    final i = _logs.indexWhere((l) => l.cookedAt == cookedAt);
    if (i < 0) return;
    _logs[i] = change(_logs[i]);
    _changed();
  }

  /// O gün yenenlerin toplam kalorisi ve proteini (kullanıcının porsiyonu).
  ({double kcal, double protein, double fiber, List<CookLog> logs}) intakeOn(
      DateTime day) {
    var kcal = 0.0, protein = 0.0, fiber = 0.0;
    final list = <CookLog>[];
    for (final l in _logs) {
      final d = l.cookedAt;
      if (d.year != day.year || d.month != day.month || d.day != day.day) {
        continue;
      }
      final r = tryRecipe(l.recipeId);
      if (r == null) continue;
      final n = matcher.factsOf(r).perServing;
      kcal += n.kcal * l.portionsEaten;
      protein += n.protein * l.portionsEaten;
      fiber += n.fiber * l.portionsEaten;
      list.add(l);
    }
    return (kcal: kcal, protein: protein, fiber: fiber, logs: list);
  }

  /// Fotoğrafı olan pişirmeler, en yeni başta (yemek günlüğü).
  List<CookLog> get photoLogs => [
        for (final l in _logs.reversed)
          if (l.photoPath != null) l
      ];

  // ---------------------------------------------------------------- Dünden kalan

  List<PantryItem> get leftovers => [
        for (final p in _pantry)
          if (repo.tryById(p.ingredientId)?.leftover ?? false) p
      ];

  /// Artıklar "kaç porsiyon kaldı" diye girilir; bir porsiyonun gramı
  /// (tariflerdeki kişi başı kullanıma göre).
  static const _leftoverPortionGrams = {
    'pismis_pilav': 150.0,
    'pismis_makarna': 150.0,
    'pismis_tavuk': 100.0,
    'haslanmis_patates': 150.0,
    'bayat_ekmek': 50.0, // yaklaşık 2 dilim
  };

  static double leftoverPortionGrams(String ingredientId) =>
      _leftoverPortionGrams[ingredientId] ?? 150;

  /// Dolaptaki artığın kaç porsiyon olduğu (dolapta yoksa 0).
  double leftoverPortions(String ingredientId) {
    var grams = 0.0;
    for (final p in _pantry) {
      if (p.ingredientId != ingredientId) continue;
      final ing = repo.byId(ingredientId);
      grams += UnitConverter.baseToGrams(ing, p.baseAmount(ing));
    }
    return grams / leftoverPortionGrams(ingredientId);
  }

  /// "2 porsiyon kaldı" → dolapta tam o kadar; 0 → artık dolaptan çıkar.
  void setLeftoverPortions(String ingredientId, int portions) {
    if (portions <= 0) {
      _pantry.removeWhere((p) => p.ingredientId == ingredientId);
      _changed();
      return;
    }
    final ing = repo.byId(ingredientId);
    _upsert(
        ingredientId,
        UnitConverter.gramsToBase(
            ing, portions * leftoverPortionGrams(ingredientId)),
        null);
    _changed();
  }

  // ---------------------------------------------------------------- Koleksiyonlar

  List<UserCollection> get collections => List.unmodifiable(_collections);

  UserCollection? collectionById(String id) {
    for (final c in _collections) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Yeni koleksiyon; [firstRecipe] verilirse içine eklenir.
  UserCollection createCollection(String name, String emoji,
      {String? firstRecipe}) {
    final c = UserCollection(
      id: 'kol_${_newId()}',
      name: name.trim(),
      emoji: emoji,
      recipeIds: [if (firstRecipe != null) firstRecipe],
    );
    _collections.add(c);
    _changed();
    return c;
  }

  void renameCollection(String id, String name, String emoji) {
    final i = _collections.indexWhere((c) => c.id == id);
    if (i < 0) return;
    _collections[i] = _collections[i].copyWith(name: name.trim(), emoji: emoji);
    _changed();
  }

  void deleteCollection(String id) {
    _collections.removeWhere((c) => c.id == id);
    _changed();
  }

  /// Tarif koleksiyondaysa çıkarır, değilse ekler.
  void toggleInCollection(String collectionId, String recipeId) {
    final i = _collections.indexWhere((c) => c.id == collectionId);
    if (i < 0) return;
    final ids = List<String>.of(_collections[i].recipeIds);
    if (!ids.remove(recipeId)) ids.add(recipeId);
    _collections[i] = _collections[i].copyWith(recipeIds: ids);
    _changed();
  }

  List<Recipe> recipesIn(UserCollection c) => [
        for (final id in c.recipeIds)
          if (tryRecipe(id) != null) tryRecipe(id)!
      ];

  /// Hazır koleksiyondaki tarifler (profile uymayanlar dahil değil).
  List<Recipe> recipesInSmart(SmartCollection s) => [
        for (final r in recipes)
          if (matcher.passesProfile(r, _profile) &&
              s.test(r, matcher.factsOf(r)))
            r
      ];

  /// "Yaptıklarım": pişirilen her tarif bir kez, en son pişirilen başta.
  List<CookedSummary> get cookedSummaries {
    final byRecipe = <String, List<CookLog>>{};
    for (final l in _logs) {
      byRecipe.putIfAbsent(l.recipeId, () => []).add(l);
    }
    final out = <CookedSummary>[];
    byRecipe.forEach((id, logs) {
      final r = tryRecipe(id);
      if (r == null) return;
      logs.sort((a, b) => b.cookedAt.compareTo(a.cookedAt));
      final ratings = [
        for (final l in logs)
          if (l.rating != null) l.rating!
      ];
      out.add(CookedSummary(
        recipe: r,
        times: logs.length,
        last: logs.first.cookedAt,
        bestRating:
            ratings.isEmpty ? null : ratings.reduce((a, b) => a > b ? a : b),
        photoPath: logs.map((l) => l.photoPath).whereType<String>().firstOrNull,
      ));
    });
    out.sort((a, b) => b.last.compareTo(a.last));
    return out;
  }

  // ---------------------------------------------------------------- Videodan kaydedilenler

  /// Aynı video daha önce kaydedildiyse o tarif.
  Recipe? importedFromUrl(String url) {
    final key = videoKey(url);
    for (final r in _imported) {
      final s = r.source;
      if (s != null && videoKey(s.url) == key) return r;
    }
    return null;
  }

  /// Aynı videodan kaydedilmiş tarif: link (kısa/uzun, ekli/eksiz) ya da
  /// açıklama metni aynıysa.
  Recipe? importedSameAs(RecipeSource source) {
    for (final r in _imported) {
      final s = r.source;
      if (s != null && sameVideo(s, source)) return r;
    }
    return null;
  }

  /// "https://www.tiktok.com/@a/video/123?_r=1" ile ".../video/123" aynıdır.
  static String videoKey(String url) {
    final tiktok = RegExp(r'tiktok\.com/.*?/video/(\d+)').firstMatch(url);
    if (tiktok != null) return 'tiktok:${tiktok.group(1)}';
    final u = Uri.tryParse(url.trim());
    if (u == null || u.host.isEmpty) return url.trim();
    final host = u.host.toLowerCase().replaceFirst(RegExp(r'^(www|m)\.'), '');
    final path = u.path.replaceFirst(RegExp(r'/+$'), '');
    // YouTube'da video kimliği sorgudadır (?v=...).
    final v = u.queryParameters['v'];
    return '$host$path${v == null ? '' : '?v=$v'}';
  }

  static bool sameVideo(RecipeSource a, RecipeSource b) {
    if (videoKey(a.url) == videoKey(b.url)) return true;
    final ca = a.caption?.trim(), cb = b.caption?.trim();
    return ca != null && ca.length >= 20 && ca == cb;
  }

  /// Yeni tarifi kaydeder; aynı kimlik ya da aynı video varsa üzerine yazar.
  void saveImported(Recipe recipe) {
    _imported.removeWhere((r) =>
        r.id == recipe.id ||
        (recipe.source != null &&
            r.source != null &&
            sameVideo(r.source!, recipe.source!)));
    _imported.add(recipe);
    matcher.forget(recipe.id);
    _allRecipes = null;
    _changed();
  }

  void deleteImported(String id) {
    _imported.removeWhere((r) => r.id == id);
    _favorites.remove(id);
    if (_active?.recipeId == id) _active = null;
    matcher.forget(id);
    _allRecipes = null;
    _changed();
  }

  // ---------------------------------------------------------------- Profil

  void updateProfile(UserProfile profile) {
    _profile = profile;
    _changed();
  }

  bool isFavorite(String recipeId) => _favorites.contains(recipeId);

  void toggleFavorite(String recipeId) {
    if (!_favorites.remove(recipeId)) _favorites.add(recipeId);
    _changed();
  }

  List<Recipe> get favorites => [
        for (final id in _favorites)
          if (tryRecipe(id) != null) tryRecipe(id)!
      ];

  Future<void> resetAll() async {
    _pantry = [];
    _profile = const UserProfile();
    _logs = [];
    _favorites = {};
    _shopping = [];
    _active = null;
    _collections = [];
    _plan = [];
    _planStart = null;
    _imported = [];
    _allRecipes = null;
    await _storage.clear();
    notifyListeners();
  }
}
