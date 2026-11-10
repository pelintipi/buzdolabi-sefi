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

  test('"ekliyorum, döküyorum" diye anlatılan açıklama adımlara bölünür', () {
    final x = run('İş çıkışı yemek hazırlığı (tek tabak) 20 dakika\n'
        'Tavuk göğsünü kuşbaşı doğrayıp tavaya alıyorum. Tuz ekliyorum, '
        'karabiber ekliyorum. Domates salçası ekleyip karıştırıyorum. '
        '200 ml su da ekleyip tıkırdayana kadar pişiriyorum. Patatesleri '
        'dilimleyip, fırında pişiriyorum. Yoğurdu tabağa alıp, tavuğun '
        'sosundan döküyorum. #yemek #tarif');
    expect(x.unmatched, isEmpty,
        reason: 'fiilli parçalar malzeme sanılmamalı: ${x.unmatched}');
    expect(x.recipe.steps.length, 6,
        reason: '${x.recipe.steps.map((s) => s.text)}');
    expect(x.recipe.steps.first.text,
        'Tavuk göğsünü kuşbaşı doğrayıp tavaya alıyorum.');
    expect(byId(x.recipe).keys,
        containsAll(['tuz', 'karabiber', 'salca', 'patates', 'yogurt']));
  });

  test('gerçek açıklama: büyük harfli ad başlık olur, adımlar tam çıkar', () {
    final x = run('İş çıkışı tek tabak yemek önerileri Part 2  Diğer tarifler '
        'için profilimi ziyaret edip , takip etmeyi unutmayın 🥹💙 TAVUK '
        'TANTUNİ (2 kişilik) 400 gr küçük küçük doğranmış tavuğu kızgın tava '
        'da hafif kızarana kadar pişiriyorum.  İçerisine kırmızı toz biber , '
        'kekik , pul biber, karabiber ve tuz ekliyorum.  200 ml su da ekleyip '
        'tıkırdayana kadar pişiriyorum.  Hazır tortillaları ben tantuniye çok '
        'yakıştırıyorum. O yüzden ben onları kullanıyorum lavaş seçimi size '
        'kalmış🫶🏼 İçerisine videodaki gibi sumaklı soğan , domates ve tavuk '
        'koyup dürüm yapıyorum.  Dilimleyip , üzerine sarımsaklı yoğurt ve '
        'tavuğun sosundan döküyorum.  Bu ölçülerle 4 tane dürüm çıkıyor '
        'bilginize🫶🏼 #işçıkışı #pratikyemek');
    expect(x.recipe.title, 'Tavuk Tantuni');
    expect(x.recipe.servings, 2);
    expect(x.unmatched, isEmpty);
    expect(x.recipe.steps.length, greaterThanOrEqualTo(5));
    expect(x.recipe.steps.first.text,
        startsWith('400 gr küçük küçük doğranmış tavuğu'));
    expect(
        x.recipe.steps.map((s) => s.text),
        contains(
            'Dilimleyip , üzerine sarımsaklı yoğurt ve tavuğun sosundan döküyorum.'));
    expect(
        byId(x.recipe).keys,
        containsAll(
            ['tavuk', 'kekik', 'karabiber', 'tuz', 'domates', 'yogurt']));
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

  test('link kutusuna url + malzemeler yapıştırılırsa metin kaybolmaz', () {
    final p = SharedPayload.fromRaw(
        url:
            'https://vm.tiktok.com/ZMabc123/ Malzemeler: 2 yumurta, 1 su bardağı süt');
    expect(p.url, 'https://vm.tiktok.com/ZMabc123/');
    expect(p.text, contains('2 yumurta'));
  });

  test('link adresinden platform anlaşılır', () {
    SocialPlatform of(String u) => SharedPayload.fromRaw(url: u).platform;
    expect(
        of('https://www.instagram.com/reel/Cabc/'), SocialPlatform.instagram);
    expect(of('https://youtu.be/abc'), SocialPlatform.youtube);
    expect(of('https://m.youtube.com/shorts/abc'), SocialPlatform.youtube);
    expect(of('https://vm.tiktok.com/x'), SocialPlatform.tiktok);
    expect(of('https://example.com/v'), SocialPlatform.other);
    expect(SocialPlatform.fromLabel('Video'), SocialPlatform.other);
  });

  test('Instagram linki için dışarıya istek atılmaz', () async {
    var calls = 0;
    final client = VideoInfoClient(client: MockClient((_) async {
      calls++;
      return http.Response('{}', 200);
    }));
    expect(await client.fetch('https://www.instagram.com/reel/x/'), isNull);
    expect(calls, 0);
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

  test('aynı video farklı linkle kaydedilince kopya oluşmaz', () async {
    expect(AppState.videoKey('https://www.tiktok.com/@a/video/123?_r=1&x=2'),
        AppState.videoKey('https://m.tiktok.com/@a/video/123'));
    expect(AppState.videoKey('https://youtube.com/watch?v=abc&t=10'),
        AppState.videoKey('https://www.youtube.com/watch?v=abc'));

    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    final state =
        AppState(repo: repo, recipes: recipeCatalog, storage: storage);
    await state.load();
    const caption = 'Menemen\nMalzemeler: 3 yumurta, 2 domates\n'
        'Yapılışı: Domatesi kavurun. Yumurtayı kırın.';
    Recipe save(String id, String url, {bool weak = false}) {
      final r = extractor
          .extract(caption,
              id: id, source: RecipeSource(url: url, caption: caption))
          .recipe;
      return weak
          ? Recipe.fromJson({
              ...r.toJson(),
              'steps': [r.steps.first.toJson()]
            })
          : r;
    }

    // Kısa link ile kaydedilmiş, sonra uzun linkle yeniden kaydedilmiş.
    state.saveImported(save('v1', 'https://vm.tiktok.com/ZMabc/', weak: true));
    state.saveImported(save('v2', 'https://www.tiktok.com/@a/video/9?_r=1'));
    expect(state.importedRecipes, hasLength(1),
        reason: 'açıklama aynı: aynı video');
    expect(
        state
            .importedSameAs(const RecipeSource(
                url: 'https://www.tiktok.com/@a/video/9', caption: caption))
            ?.id,
        'v2');
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
