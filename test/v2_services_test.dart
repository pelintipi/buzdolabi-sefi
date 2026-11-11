import 'dart:convert';

import 'package:buzdolabi_sefi/models/ingredient.dart';
import 'package:buzdolabi_sefi/models/user_profile.dart';
import 'package:buzdolabi_sefi/services/ingredient_repository.dart';
import 'package:buzdolabi_sefi/services/product_lookup.dart';
import 'package:buzdolabi_sefi/services/receipt_parser.dart';
import 'package:buzdolabi_sefi/services/recipe_matcher.dart';
import 'package:buzdolabi_sefi/services/storage_service.dart';
import 'package:buzdolabi_sefi/services/voice_commands.dart';
import 'package:buzdolabi_sefi/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/test_catalog.dart';

void main() {
  final repo = IngredientRepository(ingredientCatalog);

  Future<AppState> freshState() async {
    SharedPreferences.setMockInitialValues({});
    final s =
        AppState(repo: repo, recipes: recipeCatalog, storage: StorageService());
    await s.load();
    return s;
  }

  group('haftalık plan', () {
    test('ankete göre akşam sayısı, tekrarsız, kahvaltı/tatlı yok', () async {
      final s = await freshState();
      s.updateProfile(s.profile.copyWith(cookDaysPerWeek: 5, onboarded: true));
      s.upsertPantryAll([
        (ingredientId: 'tavuk_gogsu', quantity: 1000, level: null),
        (ingredientId: 'kiyma', quantity: 500, level: null),
        (ingredientId: 'pirinc', quantity: 1000, level: null),
        (ingredientId: 'makarna', quantity: 500, level: null),
        (ingredientId: 'domates', quantity: 6, level: null),
        (ingredientId: 'sogan', quantity: 5, level: null),
        (ingredientId: 'patates', quantity: 6, level: null),
        (ingredientId: 'mercimek', quantity: 500, level: null),
      ]);
      s.makePlan();
      final nights = s.planNights;
      expect(nights, hasLength(5));
      expect(nights.map((n) => n.recipe.id).toSet(), hasLength(5));
      for (final n in nights) {
        expect(n.recipe.tags.intersection({'kahvalti', 'tatli'}), isEmpty,
            reason: n.recipe.title);
      }
      // Dolap iyi doluyken çoğu akşam eksiksiz olmalı.
      expect(nights.where((n) => n.ready).length, greaterThanOrEqualTo(3));
    });

    test('aynı malzeme iki akşam birden "var" sayılmaz', () async {
      final s = await freshState();
      s.updateProfile(s.profile.copyWith(cookDaysPerWeek: 2, onboarded: true));
      // Domatesi ana malzeme olan iki akşam yemeği; dolapta tek tarifelik domates.
      final tomatoDishes = [
        for (final r in s.recipes)
          if (s.planner.isDinnerCandidate(r) &&
              r.items.any((i) => i.isMain && i.ingredientId == 'domates'))
            r
      ].take(2).toList();
      expect(tomatoDishes, hasLength(2));
      final need = s.matcher
          .evaluate(tomatoDishes.first, s.snapshot)
          .checks
          .firstWhere((c) => c.item.ingredientId == 'domates')
          .requiredGrams;
      s.upsertPantry('domates',
          quantity: need / s.repo.byId('domates').pieceGrams);
      final eval = s.planner.evaluate(
          recipeIds: [for (final r in tomatoDishes) r.id],
          recipes: s.recipes,
          pantry: s.snapshot,
          profile: s.profile);
      ItemState tomato(int night) => eval[night]
          .match
          .checks
          .firstWhere((c) => c.item.ingredientId == 'domates')
          .state;
      expect(tomato(0), ItemState.enough);
      // Domatesler ilk akşama gitti; ikinci akşamda yeniden "var" sayılmaz.
      expect(tomato(1), isNot(ItemState.enough));
    });

    test('bir akşamı değiştirmek diğerlerine dokunmaz', () async {
      final s = await freshState();
      s.updateProfile(s.profile.copyWith(cookDaysPerWeek: 3));
      s.makePlan();
      final before = s.planIds;
      s.swapPlanNight(1);
      expect(s.planIds[0], before[0]);
      expect(s.planIds[2], before[2]);
      expect(s.planIds[1], isNot(before[1]));
    });

    test('plan eksikleri dolap düşülerek alışveriş listesine eklenir', () async {
      final s = await freshState();
      s.updateProfile(s.profile.copyWith(cookDaysPerWeek: 3, onboarded: true));
      // Boş dolap → plandaki tariflerin malzemeleri eksik kalır.
      s.makePlan();
      final missing = s.planner.missing(s.planNights);
      expect(missing, isNotEmpty);
      expect(s.addToShopping(missing), missing.length);
      expect(s.shoppingList.toSet(), missing);
      expect(s.addToShopping(missing), 0, reason: 'ikinci kez eklenmez');
    });
  });

  group('fiş', () {
    final parser = ReceiptParser(repo);

    test('tipik market fişi', () {
      final r = parser.parse('''
MIGROS TICARET A.S.
TARIH: 04.11.2026  SAAT: 18:42
SUT TAM YAGLI 1 LT            *32,50
YUMURTA 10LU                  *89,90
DOMATES KG
1,250 X 29,90                 *37,38
PEYNIR BEYAZ 500 GR           *149,00
SOGAN KURU                    *12,40
BULASIK DETERJANI             *79,90
TOPLAM                       *401,08
KDV                           *20,05
KREDI KARTI                  *401,08
''');
      final byId = {for (final i in r.items) i.ingredient.id: i};
      expect(
          byId.keys, containsAll(['sut', 'yumurta', 'beyaz_peynir', 'sogan']));
      expect(byId['sut']!.quantity, closeTo(1000, 1), reason: '1 LT');
      expect(byId['yumurta']!.quantity, 10, reason: '10LU');
      expect(byId['beyaz_peynir']!.quantity, closeTo(500, 1));
      expect(byId.keys, isNot(contains('sivi_yag')),
          reason: '"TAM YAĞLI" yağ değildir');
      expect(r.unknown, contains('BULASIK DETERJANI             *79,90'));
      expect(r.items.any((i) => i.line.contains('TOPLAM')), isFalse);
    });

    test('kilo alt satırda (PIRASA KG / 1,150 X 24,90)', () {
      final r =
          parser.parse('PIRASA KG\n1,150 X 24,90  *28,64\nSUT 1 LT  *32,50');
      final pirasa = r.items.firstWhere((i) => i.ingredient.id == 'pirasa');
      // Pırasa adetle sayılır (250 g): 1150 g = 4,6 adet.
      expect(pirasa.quantity, closeTo(4.6, 0.01));
      expect(r.items.map((i) => i.ingredient.id), contains('sut'));
    });

    test('tartılan ürün satırı', () {
      final r = parser.parse('DOMATES 1,250 X 29,90 *37,38');
      expect(r.items.single.ingredient.id, 'domates');
    });
  });

  group('sesli komut', () {
    test('Türkçe komutlar', () {
      expect(parseVoiceCommand('sonraki adım'), VoiceCommand.next);
      expect(parseVoiceCommand('tamam devam'), VoiceCommand.next);
      expect(parseVoiceCommand('bir önceki'), VoiceCommand.previous);
      expect(parseVoiceCommand('tekrar oku'), VoiceCommand.repeat);
      expect(parseVoiceCommand('zamanlayıcıyı başlat'), VoiceCommand.timer);
      expect(parseVoiceCommand('bitti afiyet olsun'), VoiceCommand.finish);
      expect(parseVoiceCommand('geri yok yok sonraki'), VoiceCommand.next,
          reason: 'en son söylenen geçerli');
      expect(parseVoiceCommand('soğanları doğradım'), isNull);
    });
  });

  group('barkod', () {
    test('Open Food Facts yanıtından malzeme ve paket miktarı', () async {
      final lookup = ProductLookup(repo,
          client: MockClient((req) async => http.Response.bytes(
              utf8.encode(jsonEncode({
                'product': {
                  'product_name_tr': 'Pınar Tam Yağlı Süt',
                  'quantity': '1 L',
                }
              })),
              200)));
      final p = await lookup.byBarcode('8690000000000');
      expect(p.ingredient?.id, 'sut');
      expect(p.quantity, closeTo(1000, 1), reason: 'süt ml olarak saklanır');
    });

    test('bulunamayan ürün', () async {
      final lookup = ProductLookup(repo,
          client: MockClient((_) async => http.Response('{"status":0}', 404)));
      final p = await lookup.byBarcode('1');
      expect(p.ingredient, isNull);
    });
  });

  test('günlük kalori ve protein yenen porsiyona göre', () async {
    final s = await freshState();
    final r = s.recipeById('menemen');
    s.recordCook(r, 2, const {});
    final log = s.logs.last;
    s.updateLog(log.cookedAt, (l) => l.copyWith(portionsEaten: 1.5));
    final per = s.matcher.factsOf(r).perServing;
    final today = s.intakeOn(DateTime.now());
    expect(today.kcal, closeTo(per.kcal * 1.5, 0.01));
    expect(today.protein, closeTo(per.protein * 1.5, 0.01));
  });

  test('dünden kalan pilav, onu kullanan tariflerle eşleşir', () async {
    final s = await freshState();
    s.upsertPantry('pismis_pilav', quantity: 400);
    s.upsertPantry('yumurta', quantity: 4);
    s.upsertPantry('havuc', quantity: 2);
    s.upsertPantry('sogan', quantity: 2);
    expect(s.leftovers.single.ingredientId, 'pismis_pilav');
    final m = s.matcher.evaluate(s.recipeById('pilav_kavurmasi'), s.snapshot);
    expect(
        m.checks.firstWhere((c) => c.item.ingredientId == 'pismis_pilav').state,
        ItemState.enough);
    expect(m.group, isNot(MatchGroup.far));
    // Bayat ekmek, "ekmek" isteyen tariflerde de sayılır (alt tür).
    expect(repo.isSameOrDescendant('bayat_ekmek', 'ekmek'), isTrue);
  });

  test('mevsim: kasımda pırasa var, domates yok', () {
    expect(repo.byId('pirasa').inSeason(11), isTrue);
    expect(repo.byId('domates').inSeason(11), isFalse);
  });

  test('test sunucusu anketi sıfırlar: eski otomatik aletler işaretli gelmez',
      () {
    // Eski sürümün otomatik işaretlediği Ocak + Fırın "sorulmuş" kaydedilmişti.
    const old = UserProfile(
      onboarded: true,
      appliancesAsked: true,
      cookDaysPerWeek: 5,
      household: Household.couple,
      goals: {Goal.waste},
      allergies: {Allergen.milk},
      dailyProtein: 90,
    );
    final p = old.withoutSurvey();
    expect(p.onboarded, isFalse);
    expect(p.appliancesAsked, isFalse, reason: 'anket aletleri boş gösterir');
    expect(p.cookDaysPerWeek, isNull);
    expect(p.household, isNull);
    expect(p.goals, isEmpty);
    // Alerji / temel malzeme ankette yeniden sorulur; hedef ayarları kalır.
    expect(p.allergies, isEmpty);
    expect(p.missingStaples, isEmpty);
    expect(p.dailyProtein, 90);
  });

  test('anket profili yeni alanlarla saklanıp geri okunur', () {
    const p = UserProfile(remindersOn: true, dailyProtein: 90);
    final back = UserProfile.fromJson(jsonDecode(jsonEncode(p.toJson())));
    expect(back.remindersOn, isTrue);
    expect(back.dailyProtein, 90);
  });
}
