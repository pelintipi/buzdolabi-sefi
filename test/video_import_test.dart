import 'dart:convert';

import 'package:buzdolabi_sefi/models/measure.dart';
import 'package:buzdolabi_sefi/models/recipe.dart';
import 'package:buzdolabi_sefi/services/caption_recipe_extractor.dart';
import 'package:buzdolabi_sefi/services/ingredient_repository.dart';
import 'package:buzdolabi_sefi/services/recipe_matcher.dart';
import 'package:buzdolabi_sefi/services/storage_service.dart';
import 'package:buzdolabi_sefi/services/video_import.dart';
import 'package:buzdolabi_sefi/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/test_catalog.dart';

const _src = RecipeSource(url: 'https://www.tiktok.com/@sef/video/1');

void main() {
  final repo = IngredientRepository(ingredientCatalog);
  final extractor = CaptionRecipeExtractor(repo);

  ExtractedRecipe run(String caption) =>
      extractor.extract(caption, id: 'video_test', source: _src);

  Map<String, RecipeItem> byId(Recipe r) =>
      {for (final i in r.items) i.ingredientId: i};

  test('başlıklı, emojili tipik TikTok açıklaması', () {
    final x = run('Kremalı mantarlı tavuk 🍗🍄 15 dakikada hazır!\n'
        'Malzemeler:\n'
        '🍗 500 gr tavuk göğsü\n'
        '🍄 200 gr mantar\n'
        '🥛 1 paket krema\n'
        '🧅 1 adet soğan\n'
        '🧂 Tuz, karabiber\n'
        'Yapılışı: Tavukları kuşbaşı doğrayıp tavada 10 dakika soteleyin. '
        'Soğan ve mantarı ekleyin. Kremayı ekleyip 5 dk pişirin. '
        '#tarif #kolaytarifler #yemek');
    final r = x.recipe;
    expect(r.title, 'Kremalı mantarlı tavuk',
        reason: '"15 dakikada hazır" başlıktan atılır');
    final items = byId(r);
    expect(
        items.keys,
        containsAll(
            ['tavuk_gogsu', 'mantar', 'krema', 'sogan', 'tuz', 'karabiber']));
    expect(items['tavuk_gogsu']!.amount, 500);
    expect(items['tavuk_gogsu']!.measure, Measure.gram);
    expect(items['krema']!.measure, Measure.paket);
    // En ağır iki temel malzeme ana malzemedir; tuz asla.
    expect(items['tavuk_gogsu']!.isMain, isTrue);
    expect(items['tuz']!.isMain, isFalse);
    expect(r.steps, hasLength(3));
    expect(r.steps.first.timerMinutes, 10);
    expect(r.minutes, 15, reason: '"15 dakikada hazır" yazıyor');
    expect(r.appliances, contains(Appliance.ocak));
    expect(r.techniques, contains(Technique.sote));
    expect(r.source!.caption, contains('Kremalı'));
    expect(x.isUsable, isTrue);
  });

  test('tek satır, virgüllü açıklama ve sözle yazılmış miktarlar', () {
    final x =
        run('Pankek tarifi: 2 yumurta, 1 su bardağı süt, 1,5 su bardağı un, '
            'yarım paket kabartma tozu ve arzuya göre bal. '
            'Hepsini çırpın, yağsız tavada iki yüzünü pişirin.');
    final items = byId(x.recipe);
    expect(items['yumurta']!.amount, 2);
    expect(items['sut']!.measure, Measure.suBardagi);
    expect(items['un']!.amount, 1.5);
    expect(items['kabartma_tozu']!.amount, 0.5);
    expect(items['bal']!.optional, isTrue, reason: '"arzuya göre"');
    expect(x.recipe.title, 'Pankek');
    expect(x.recipe.steps, isNotEmpty);
  });

  test('numaralı adımlar ve tanınmayan malzeme', () {
    final x = run('Fırında sebzeli makarna\n'
        'Malzemeler\n- 250 gr makarna\n- 2 kabak\n- 1 kutu mozzarella\n- 2 domates\n'
        'Hazırlanışı:\n1. Makarnayı haşlayın.\n2. Sebzeleri doğrayın.\n'
        '3. Fırında 180 derecede 20 dakika pişirin.');
    expect(byId(x.recipe).keys, containsAll(['makarna', 'kabak', 'domates']));
    expect(x.unmatched, contains('1 kutu mozzarella'),
        reason: 'kataloğumuzda yok, uydurmak yerine gösterilir');
    expect(x.recipe.steps.map((s) => s.text), [
      'Makarnayı haşlayın.',
      'Sebzeleri doğrayın.',
      'Fırında 180 derecede 20 dakika pişirin.',
    ]);
    expect(x.recipe.steps.last.timerMinutes, 20);
    expect(x.recipe.appliances, contains(Appliance.firin));
  });

  test('tarif yazmayan açıklama kullanılabilir sayılmaz', () {
    final x = run('Bu tarif çok tuttu 😍 denemeyen kalmasın #keşfet #fyp');
    expect(x.isUsable, isFalse);
  });

  test('paylaşılan metnin içinden link ayrılır', () {
    final p = SharedPayload.fromRaw(
        text: 'Şuna bak 😋 https://vm.tiktok.com/ZMabc123/');
    expect(p.url, 'https://vm.tiktok.com/ZMabc123/');
    expect(p.text, 'Şuna bak 😋');
    expect(p.isTikTok, isTrue);
    expect(
        SharedPayload.fromRaw(url: 'https://youtube.com/x').isTikTok, isFalse);
  });

  test('oEmbed yanıtından açıklama, hesap ve kapak okunur', () async {
    late Uri asked;
    final client = VideoInfoClient(
      client: MockClient((req) async {
        asked = req.url;
        return http.Response.bytes(
            utf8.encode(jsonEncode({
              'title': 'Menemen 🍳 Malzemeler: 3 yumurta, 2 domates',
              'author_unique_id': 'evdesef',
              'author_name': 'Evde Şef',
              'thumbnail_url': 'https://p16.tiktokcdn.com/kapak.jpg',
            })),
            200);
      }),
    );
    final info = await client.fetch('https://www.tiktok.com/@evdesef/video/7');
    expect(asked.host, 'www.tiktok.com');
    expect(asked.queryParameters['url'],
        'https://www.tiktok.com/@evdesef/video/7');
    expect(info!.author, 'evdesef');
    expect(info.caption, startsWith('Menemen'));

    final failing = VideoInfoClient(
        client: MockClient((_) async => http.Response('yok', 404)));
    expect(await failing.fetch('https://www.tiktok.com/x'), isNull);
  });

  test('kaydedilen tarif kalıcıdır, eşleşmeye girer ve silinebilir', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    final state =
        AppState(repo: repo, recipes: recipeCatalog, storage: storage);
    await state.load();
    final recipe = run(
            'Menemen\nMalzemeler: 3 yumurta, 2 domates, 2 sivri biber\n'
            'Yapılışı: Biberleri kavurun. Domatesi ekleyin. Yumurtayı kırın.')
        .recipe;
    state.saveImported(recipe);
    expect(state.recipes.first.id, 'video_test');
    expect(state.importedFromUrl(_src.url)?.id, 'video_test');

    // Aynı video tekrar kaydedilirse kopya oluşmaz.
    state.saveImported(Recipe.fromJson({...recipe.toJson(), 'id': 'video_2'}));
    expect(state.importedRecipes, hasLength(1));

    state.upsertPantry('yumurta', quantity: 6);
    state.upsertPantry('domates', quantity: 3);
    state.upsertPantry('sivri_biber', quantity: 4);
    final m = state
        .matches(const QuickFilters())
        .firstWhere((m) => m.recipe.isImported);
    expect(m.problems, isEmpty);

    await Future<void>.delayed(Duration.zero);
    final reloaded =
        AppState(repo: repo, recipes: recipeCatalog, storage: storage);
    await reloaded.load();
    expect(reloaded.importedRecipes.single.title, 'Menemen');
    expect(reloaded.importedRecipes.single.source!.url, _src.url);

    reloaded.deleteImported('video_2');
    expect(reloaded.importedRecipes, isEmpty);
    expect(reloaded.recipes, hasLength(recipeCatalog.length));
  });
}
