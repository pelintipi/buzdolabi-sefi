import 'dart:convert';

import 'package:buzdolabi_sefi/data/catalog.dart';
import 'package:buzdolabi_sefi/models/ingredient.dart';
import 'package:buzdolabi_sefi/models/measure.dart';
import 'package:buzdolabi_sefi/models/recipe.dart';
import 'package:buzdolabi_sefi/models/user_profile.dart';
import 'package:buzdolabi_sefi/services/ingredient_repository.dart';
import 'package:buzdolabi_sefi/services/recipe_matcher.dart';
import 'package:buzdolabi_sefi/services/unit_converter.dart';
import 'package:buzdolabi_sefi/widgets/ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_catalog.dart';

void main() {
  final repo = IngredientRepository(ingredientCatalog);
  final matcher = RecipeMatcher(repo);
  final allStaples = {for (final s in repo.staples) s.id};
  const allAppliances = UserProfile(appliances: {
    Appliance.ocak,
    Appliance.firin,
    Appliance.airfryer,
    Appliance.blender,
  });

  Recipe recipe(String id) => recipeCatalog.firstWhere((r) => r.id == id);

  /// [base]: malzeme → baseUnit cinsinden miktar (adet, g, ml).
  PantrySnapshot pantry(Map<String, double> base) => PantrySnapshot(
        gramsById: {
          for (final e in base.entries)
            e.key: UnitConverter.baseToGrams(repo.byId(e.key), e.value)
        },
        stapleIds: allStaples,
      );

  test('JSON kataloğu hatasız okunur', () {
    expect(testCatalog.problems, isEmpty);
    expect(recipeCatalog, hasLength(109));
    expect(ingredientCatalog, hasLength(119));
  });

  test('tarif kalitesi: ana malzeme, adım, süre, benzersiz ad, 3D ikon', () {
    final titles = <String>{};
    for (final r in recipeCatalog) {
      expect(titles.add(r.title), isTrue, reason: 'Aynı ad: ${r.title}');
      expect(r.items.where((i) => i.isMain), isNotEmpty,
          reason: '${r.id}: ana malzeme yok');
      expect(r.minutes, greaterThan(0), reason: r.id);
      expect(r.steps.length, greaterThanOrEqualTo(2),
          reason: '${r.id}: en az 2 adım');
      for (final s in r.steps) {
        if (s.timerMinutes != null) {
          expect(s.timerMinutes, greaterThan(0), reason: r.id);
          expect(s.timerMinutes, lessThanOrEqualTo(r.minutes + 60),
              reason: r.id);
        }
      }
      expect(iconAssetFor(r.emoji), isNotNull,
          reason: '${r.id}: ${r.emoji} ikonu yok');
      final facts = matcher.factsOf(r);
      expect(facts.perServing.kcal, inInclusiveRange(20, 1500),
          reason: '${r.id} kalori');
    }
    for (final i in ingredientCatalog) {
      expect(iconAssetFor(i.emoji), isNotNull,
          reason: '${i.id}: ${i.emoji} ikonu yok');
    }
  });

  test('lif: her malzemede var, baklagil yemeği lifli, omlet değil', () {
    final m = RecipeMatcher(IngredientRepository(ingredientCatalog));
    Recipe r(String id) => recipeCatalog.firstWhere((x) => x.id == id);
    final beans = m.factsOf(r('kuru_fasulye'));
    final omelet = m.factsOf(r('peynirli_omlet'));
    expect(beans.perServing.fiber, greaterThan(8));
    expect(omelet.perServing.fiber, lessThan(1));
    expect(beans.review.tips.join(' '), contains('Lif açısından zengin'));
    expect(omelet.review.tips.join(' '), contains('Lifi az'));
    // JSON'a yazılıp okununca lif kaybolmaz.
    const n = Nutrition(100, 5, 3, 12, fiber: 4.5);
    expect(Nutrition.fromJson(n.toJson()).fiber, 4.5);
    expect((n + n).fiber, 9);
    expect(n.scale(2).fiber, 9);
  });

  test('"Diğer" alerjiler malzeme listesinde karşılık bulur', () {
    final m = RecipeMatcher(IngredientRepository(ingredientCatalog));
    const expected = {
      'çilek': 'cilek',
      'Çilekler': 'cilek',
      'karides': 'karides',
      'kivi': 'kivi',
      'midye': 'midye',
      'kalamar': 'kalamar',
      'fındık': 'findik',
      'badem': 'badem',
      'antep fıstığı': 'antep_fistigi',
      'fıstık': 'yer_fistigi',
      'yer fıstığı': 'yer_fistigi',
      'kaju': 'kaju',
      'susam': 'susam',
      'soya': 'soya',
      'hardal': 'hardal',
      'kereviz': 'kereviz',
      'şeftali': 'seftali',
      'kayısı': 'kayisi',
      'ananas': 'ananas',
      'portakal': 'portakal',
      'domates': 'domates',
      'yumurta': 'yumurta',
    };
    expected.forEach((text, id) {
      expect(m.allergyIngredient(text)?.id, id, reason: text);
    });
    // Kuruyemiş kutusu yeni kuruyemişleri de kapsar.
    for (final id in ['findik', 'badem', 'antep_fistigi', 'kaju', 'ceviz']) {
      expect(m.repo.byId(id).allergens, contains(Allergen.treeNut), reason: id);
    }
  });

  test('her kategoriden yeterli seçenek var', () {
    int count(bool Function(Recipe r) f) => recipeCatalog.where(f).length;
    expect(count((r) => r.tags.contains('kahvalti')), greaterThanOrEqualTo(20));
    expect(count((r) => r.tags.contains('tatli')), greaterThanOrEqualTo(8));
    expect(count((r) => r.title.contains('Çorba')), greaterThanOrEqualTo(10));
    expect(count((r) => matcher.factsOf(r).isVegan), greaterThanOrEqualTo(15));
    expect(
        count((r) =>
            matcher.factsOf(r).perServing.protein >=
            QuickFilters.highProteinGrams),
        greaterThanOrEqualTo(15));
    expect(count((r) => r.minutes <= 15), greaterThanOrEqualTo(20));
  });

  test('bozuk tarif uygulamayı çökertmez, atlanır', () {
    const ingredients =
        '{"ingredients":[{"id":"yumurta","name":"Yumurta","emoji":"🥚",'
        '"baseUnit":"piece","packageAmount":10,"shelfLifeDays":21,'
        '"per100g":{"kcal":143,"protein":12.6,"fat":9.5,"carbs":0.7},"pricePerKg":130}]}';
    const recipes = '{"recipes":['
        '{"id":"iyi","title":"Rafadan","emoji":"🥚","minutes":8,"difficulty":"kolay","servings":1,'
        '"items":[{"ingredient":"yumurta","amount":2,"measure":"adet","role":"main"}],'
        '"steps":[{"text":"Haşla."}]},'
        '{"id":"eksik","title":"X","emoji":"🥚","minutes":5,"difficulty":"kolay","servings":1,'
        '"items":[{"ingredient":"ejderha_yumurtasi","amount":1,"measure":"adet"}],'
        '"steps":[{"text":"?"}]},'
        '{"id":"bozuk","title":"Y","difficulty":"cok_zor"}]}';
    final c = Catalog.parse(ingredients, recipes);
    expect(c.recipes.map((r) => r.id), ['iyi']);
    expect(c.problems, hasLength(2));
    expect(c.problems.join(), contains('ejderha_yumurtasi'));
  });

  test('tarif JSON\'a yazılıp geri okununca aynı kalır', () {
    for (final r in recipeCatalog) {
      expect(jsonEncode(Recipe.fromJson(r.toJson()).toJson()),
          jsonEncode(r.toJson()),
          reason: r.id);
    }
  });

  test('bütün tarif malzemeleri katalogda var', () {
    for (final r in recipeCatalog) {
      for (final item in r.items) {
        expect(repo.tryById(item.ingredientId), isNotNull,
            reason: '${r.id} → ${item.ingredientId}');
        for (final s in item.substitutes) {
          expect(repo.tryById(s.ingredientId), isNotNull,
              reason: '${r.id} → ${s.ingredientId}');
        }
      }
    }
  });

  test('miktar az ama bir porsiyona yetiyorsa daha az porsiyonla yapılır', () {
    // Menemen 2 kişilik, 3 yumurta istiyor; dolapta 2 var → 1 porsiyon.
    final m = matcher.evaluate(recipe('menemen'),
        pantry({'yumurta': 2, 'domates': 3, 'sivri_biber': 3}));
    expect(m.group, MatchGroup.ready);
    expect(m.problems, isEmpty);
    expect(m.checks.firstWhere((c) => c.item.ingredientId == 'yumurta').state,
        ItemState.short);
    expect(m.maxServings, 1.0);
  });

  test('bir porsiyona bile yetmiyorsa "hemen yapabilirsin" demez', () {
    // 1 yumurta, 1 porsiyon için gereken 1,5 yumurtadan az.
    final m = matcher.evaluate(recipe('menemen'),
        pantry({'yumurta': 1, 'domates': 3, 'sivri_biber': 3}));
    expect(m.group, MatchGroup.almost);
    expect(m.blocking!.item.ingredientId, 'yumurta');
    expect(m.blocking!.state, ItemState.short);
  });

  test('kıyma ve pirinçle köfte ve pilav tarifleri çıkar', () {
    final results = matcher.rank(
        recipeCatalog,
        pantry({'kiyma': 250, 'pirinc': 500}),
        allAppliances,
        const QuickFilters());
    MatchGroup groupOf(String id) =>
        results.firstWhere((m) => m.recipe.id == id).group;
    // Kıymalı pilav: tereyağı yerine sıvı yağ.
    expect(groupOf('kiymali_pilav'), isNot(MatchGroup.far));
    expect(groupOf('pilav_ustu_kofte'), isNot(MatchGroup.far));
    // 250 g kıyma 4 kişilik köftenin 2 porsiyonuna yeter; ekmek yerine un.
    final kofte = results.firstWhere((m) => m.recipe.id == 'tava_kofte');
    expect(kofte.group, MatchGroup.substitute);
    expect(kofte.maxServings, 2.0);
  });

  test('diyetisyen değerlendirmesi: patates karbonhidrat, köfte protein', () {
    final patates = matcher.factsOf(recipe('airfryer_patates')).review;
    expect(patates.verdict, 'Karbonhidrat ağırlıklı');
    expect(patates.isProteinSource, isFalse);
    expect(patates.tips, isNotEmpty);
    final tavuk = matcher.factsOf(recipe('airfryer_tavuk')).review;
    expect(tavuk.isHighProtein, isTrue);
    expect(tavuk.proteinPct + tavuk.carbPct + tavuk.fatPct, 100);
    expect(tavuk.balanceScore, greaterThan(patates.balanceScore));
  });

  test('5 g proteinli tarif en yüksek olsa bile "En proteinli" olmaz', () {
    final options = [
      for (final id in ['airfryer_patates', 'firinda_karnabahar'])
        matcher.evaluate(recipe(id), pantry({'patates': 5, 'karnabahar': 2}))
    ];
    final h = highlightsFor(options).values.expand((s) => s).toSet();
    expect(h, isNot(contains(Highlight.protein)));
  });

  test('miktar yeterliyse hazır', () {
    final m = matcher.evaluate(recipe('menemen'),
        pantry({'yumurta': 3, 'domates': 3, 'sivri_biber': 3}));
    expect(m.group, MatchGroup.ready);
    expect(m.score, 1.0);
  });

  test('porsiyon artınca gereken miktar da artar', () {
    final p = pantry({'yumurta': 3, 'domates': 3, 'sivri_biber': 3});
    final m = matcher.evaluate(recipe('menemen'), p, servings: 4);
    expect(m.group, MatchGroup.far);
    expect(m.maxServings, 2.0);
  });

  test('üst kategori eşleşir: kaşar, "peynir" isteyen tarifi karşılar', () {
    final m = matcher.evaluate(
        recipe('peynirli_omlet'), pantry({'yumurta': 3, 'kasar': 100}));
    final peynir = m.checks.firstWhere((c) => c.item.ingredientId == 'peynir');
    expect(peynir.state, ItemState.enough);
  });

  test('alternatif malzeme: sivri biber yerine kapya', () {
    final m = matcher.evaluate(recipe('menemen'),
        pantry({'yumurta': 3, 'domates': 3, 'kapya_biber': 1}));
    expect(m.group, MatchGroup.substitute);
    final biber =
        m.checks.firstWhere((c) => c.item.ingredientId == 'sivri_biber');
    expect(biber.substitute!.ingredientId, 'kapya_biber');
  });

  test(
      'ana malzemelerin hepsi yalnızca alternatifle karşılanıyorsa tarif yapılabilir sayılmaz',
      () {
    const recipe = Recipe(
      id: 'deneme_corba',
      title: 'Deneme Çorbası',
      emoji: '🍲',
      minutes: 20,
      difficulty: Difficulty.kolay,
      servings: 2,
      items: [
        RecipeItem(
            ingredientId: 'domates',
            amount: 5,
            measure: Measure.adet,
            isMain: true,
            substitutes: [Substitute('salca', 'Salçayla.')]),
      ],
      steps: [RecipeStep('Pişir.'), RecipeStep('Servis et.')],
    );
    expect(matcher.evaluate(recipe, pantry({})).group, MatchGroup.far);
    expect(matcher.evaluate(recipe, pantry({'domates': 5})).group,
        MatchGroup.ready);
  });

  test('temel malzeme kapatılırsa eksik sayılır', () {
    final p = PantrySnapshot(
      gramsById: {
        'mercimek': 1000,
        'sogan': 110,
        'havuc': 70,
        'tereyagi': 250,
      },
      stapleIds: allStaples.difference({'salca'}),
    );
    final m = matcher.evaluate(recipe('mercimek_corbasi'), p);
    expect(m.blocking?.item.ingredientId, 'salca');
  });

  test('süt alerjisinde süt ürünü içeren hiçbir tarif çıkmaz', () {
    final profile = allAppliances.copyWith(allergies: {Allergen.milk});
    final results =
        matcher.rank(recipeCatalog, pantry({}), profile, const QuickFilters());
    expect(results, isNotEmpty);
    for (final m in results) {
      expect(m.facts.allergens, isNot(contains(Allergen.milk)),
          reason: m.recipe.id);
    }
    final ids = results.map((m) => m.recipe.id);
    expect(ids, isNot(contains('peynirli_omlet')));
    // Tereyağı da süt ürünüdür.
    expect(ids, isNot(contains('mercimek_corbasi')));
  });

  test('vegan profilde hayvansal ürün yok', () {
    final profile = allAppliances.copyWith(diet: Diet.vegan);
    final results =
        matcher.rank(recipeCatalog, pantry({}), profile, const QuickFilters());
    for (final m in results) {
      expect(m.facts.isVegan, isTrue, reason: m.recipe.id);
    }
    expect(results.map((m) => m.recipe.id), contains('coban_salatasi'));
  });

  test('sahip olunmayan aleti gerektiren tarif gizlenir', () {
    const profile = UserProfile(appliances: {Appliance.ocak});
    final results =
        matcher.rank(recipeCatalog, pantry({}), profile, const QuickFilters());
    for (final m in results) {
      expect({Appliance.ocak}.containsAll(m.recipe.appliances), isTrue,
          reason: m.recipe.id);
    }
  });

  test('hızlı filtreler uygulanır', () {
    final results = matcher.rank(recipeCatalog, pantry({}), allAppliances,
        const QuickFilters(quick: true, highProtein: true));
    expect(results, isNotEmpty);
    for (final m in results) {
      expect(m.recipe.minutes, lessThanOrEqualTo(15));
      expect(m.facts.perServing.protein,
          greaterThanOrEqualTo(QuickFilters.highProteinGrams));
    }
  });

  test('"sadece X alırsan" önerisi tek eksiği gösterir', () {
    final results = matcher.rank(
        recipeCatalog,
        pantry({'domates': 3, 'sivri_biber': 3}),
        allAppliances,
        const QuickFilters());
    final suggestions = matcher.unlockSuggestions(results);
    expect(suggestions.map((s) => s.ingredient.id), contains('yumurta'));
  });

  test('yumurta + un + süt: pankek, krep ve rafadan seçenek olarak çıkar', () {
    // Un temel malzeme; seçilmese de var sayılır.
    final results = matcher.rank(
        recipeCatalog,
        pantry({'yumurta': 4, 'sut': 500}),
        allAppliances,
        const QuickFilters());
    MatchGroup groupOf(String id) =>
        results.firstWhere((m) => m.recipe.id == id).group;
    expect(groupOf('krep'), MatchGroup.ready);
    expect(groupOf('haslanmis_yumurta'), MatchGroup.ready);
    // Tereyağı yok → sıvı yağ alternatifiyle.
    expect(groupOf('pankek'), MatchGroup.substitute);
  });

  test('seçenekler protein, süre ve kaloriye göre sıralanır ve rozetlenir', () {
    final options = matcher
        .rank(
            recipeCatalog,
            pantry({'yumurta': 4, 'sut': 500, 'yulaf': 200, 'yogurt': 500}),
            allAppliances,
            const QuickFilters())
        .where((m) => m.group != MatchGroup.far)
        .toList();
    final byProtein = sortOptions(options, SortMode.protein);
    for (var i = 1; i < byProtein.length; i++) {
      expect(byProtein[i - 1].facts.perServing.protein,
          greaterThanOrEqualTo(byProtein[i].facts.perServing.protein));
    }
    final byTime = sortOptions(options, SortMode.fastest);
    expect(byTime.first.recipe.minutes,
        lessThanOrEqualTo(byTime.last.recipe.minutes));

    final h = highlightsFor(options);
    expect(h.values.expand((s) => s).toSet(),
        containsAll([Highlight.fastest, Highlight.protein]));
    expect(h[byProtein.first.recipe.id], contains(Highlight.protein));
  });

  test('kahvaltılık filtresi yalnızca kahvaltı tariflerini bırakır', () {
    final results = matcher.rank(recipeCatalog, pantry({}), allAppliances,
        const QuickFilters(breakfast: true));
    expect(results, isNotEmpty);
    for (final m in results) {
      expect(m.recipe.tags, contains('kahvalti'), reason: m.recipe.id);
    }
  });

  test('sıralama: hazır tarifler önce gelir', () {
    final results = matcher.rank(
        recipeCatalog,
        pantry({'yumurta': 3, 'domates': 3, 'sivri_biber': 3}),
        allAppliances,
        const QuickFilters());
    expect(results.first.group, MatchGroup.ready);
    for (var i = 1; i < results.length; i++) {
      expect(results[i - 1].group.index,
          lessThanOrEqualTo(results[i].group.index));
    }
  });
}
