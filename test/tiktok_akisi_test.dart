// TikTok → Paylaş → Buzdolabı Şefi akışını kullanıcı gibi dener ve her adımın
// ekran görüntüsünü alır:
//   flutter test test/tiktok_akisi_test.dart
// Rapor: degisiklik_raporlari/2026-11-04_tiktok-kaydet/rapor.html

import 'dart:convert';

import 'package:buzdolabi_sefi/app.dart';
import 'package:buzdolabi_sefi/services/ingredient_repository.dart';
import 'package:buzdolabi_sefi/services/storage_service.dart';
import 'package:buzdolabi_sefi/services/video_import.dart';
import 'package:buzdolabi_sefi/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/screenshot_report.dart';
import 'support/test_catalog.dart';

const _screen = Size(393, 852);
const _videoUrl = 'https://www.tiktok.com/@evdesef/video/7301';

const _caption = 'Kremalı mantarlı tavuk 🍗🍄 15 dakikada hazır!\n'
    'Malzemeler:\n'
    '🍗 500 gr tavuk göğsü\n'
    '🍄 200 gr mantar\n'
    '🥛 1 paket krema\n'
    '🧅 1 adet soğan\n'
    '🧀 1 kutu parmesan\n'
    '🧂 Tuz, karabiber\n'
    'Yapılışı: Tavukları kuşbaşı doğrayıp tavada 10 dakika soteleyin. '
    'Soğan ve mantarı ekleyip kavurun. Kremayı ekleyip 5 dk pişirin. '
    '#tarif #kolaytarifler #yemek';

/// iOS paylaşım eklentisinin bıraktığı tek bir TikTok linki.
class _FakeInbox extends ShareInbox {
  _FakeInbox(this.items);

  List<SharedPayload> items;

  @override
  Future<List<SharedPayload>> takePending() async {
    final out = items;
    items = const [];
    return out;
  }
}

final _mainScroll = find
    .byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down)
    .first;

void main() {
  setUpAll(loadRealFonts);

  testWidgets('TikTok videosunu paylaş → tarif kaydedilir', (tester) async {
    tester.view.physicalSize = _screen * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final state = AppState(
      repo: IngredientRepository(ingredientCatalog),
      recipes: recipeCatalog,
      storage: StorageService(),
    );
    await state.load();
    // Alerji sorusunu daha önce yanıtlamış bir kullanıcı.
    state.updateProfile(
        state.profile.copyWith(allergyAsked: true, onboarded: true));
    // Dolapta tavuk ve soğan var; mantar ve krema yok.
    state.upsertPantry('tavuk_gogsu', quantity: 600);
    state.upsertPantry('sogan', quantity: 3);

    // TikTok'un oEmbed servisi yerine aynı biçimde cevap veren sahte sunucu.
    final client = VideoInfoClient(
      client: MockClient((req) async => http.Response.bytes(
          utf8.encode(jsonEncode({
            'title': _caption,
            'author_unique_id': 'evdesef',
            'author_name': 'Evde Şef',
          })),
          200,
          headers: {'content-type': 'application/json'})),
    );
    final inbox = _FakeInbox(const []);
    final r = ScreenshotReport('degisiklik_raporlari/2026-11-04_tiktok-kaydet',
        'TikTok\'tan tarif kaydetme · Ekran testi');

    debugDisableShadows = false;
    try {
      await tester.pumpWidget(RepaintBoundary(
        key: screenshotKey,
        child: ChangeNotifierProvider.value(
          value: state,
          child: BuzdolabiSefiApp(shareInbox: inbox, videoClient: client),
        ),
      ));

      await r.capture(tester,
          title: 'Ana sayfa',
          action: 'Uygulamayı açtım.',
          result: '"Ekle" bölümünde "TikTok\'tan" kısayolu var.');
      expect(find.text("TikTok'tan"), findsOneWidget);

      // ------------------------------------------- Paylaş → Buzdolabı Şefi
      // Prototipte: karta dokununca "paylaşılmış" hali açılır.
      r.mark(tester, find.text("TikTok'tan"), "TikTok'ta Paylaş");
      // Eklenti linki kutuya bıraktı; kullanıcı uygulamaya döndü.
      inbox.items = [
        SharedPayload.fromRaw(text: 'Bu tarife bak! $_videoUrl'),
      ];
      final binding = tester.binding;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      final saved = state.importedFromUrl(_videoUrl);
      await r.capture(tester,
          title: 'Tarif kaydedildi',
          action: 'TikTok\'ta videoda Paylaş → Buzdolabı Şefi\'ne dokundum, '
              'sonra uygulamaya döndüm.',
          result:
              'Açıklamadaki tarif okundu ve kaydedildi: başlık, video sahibi '
              '(@evdesef), süre, kalori ve protein hazır.',
          ok: saved != null);
      expect(saved, isNotNull);
      expect(find.text('Buzdolabı Şefi\'ne kaydedildi'), findsOneWidget);
      expect(find.text('@evdesef'), findsOneWidget);

      r.mark(tester, find.text('@evdesef'), 'Aşağı kaydır');
      await tester.scrollUntilVisible(
          find.text('Tanıyamadığım malzemeler'), 200,
          scrollable: _mainScroll);
      await r.capture(tester,
          title: 'Uydurmuyor',
          action: 'Aşağı kaydırdım.',
          result: '"1 kutu parmesan" kataloğumuzda yok; tarife uydurma bir şey '
              'eklemek yerine "Tanıyamadığım malzemeler" altında gösteriliyor.',
          ok: saved!.source!.unmatched.contains('1 kutu parmesan'));

      r.mark(tester, find.text('Tanıyamadığım malzemeler'), 'Aşağı kaydır');
      await tester.scrollUntilVisible(
          find.textContaining('Eksikleri listeye ekle'), 200,
          scrollable: _mainScroll);
      await tester.pumpAndSettle();
      final missing = state.matcher
          .evaluate(saved, state.snapshot)
          .problems
          .map((c) => c.item.ingredientId)
          .toSet();
      await r.capture(tester,
          title: 'Dolabınla karşılaştırma',
          action: 'Malzemelere kaydırdım.',
          result:
              'Tavuk ve soğan "Var", mantar ve krema "Yok"; tuz ve karabiber '
              '"Evde var". Altında "Eksikleri listeye ekle (2)".',
          ok: missing.containsAll({'mantar', 'krema'}) && missing.length == 2);
      expect(missing, {'mantar', 'krema'});

      await r.tap(tester, find.textContaining('Eksikleri listeye ekle'),
          'Eksikleri listeye ekle');
      await tester.pumpAndSettle();
      await r.capture(tester,
          title: 'Eksikler listede',
          action: '"Eksikleri listeye ekle"ye bastım.',
          result: 'Mantar ve krema alışveriş listesine girdi.',
          ok: state.isOnShoppingList('mantar') &&
              state.isOnShoppingList('krema'));
      expect(state.shoppingList, containsAll(['mantar', 'krema']));

      final stepsTab = find.text('Adımlar (3)');
      await tester.scrollUntilVisible(stepsTab, -200, scrollable: _mainScroll);
      await tester.pumpAndSettle();
      await r.capture(tester,
          title: 'Üç parça',
          action: 'Yukarı kaydırdım.',
          result:
              'Tarif üç sekmeye ayrıldı: Malzemeler · Adımlar · Besin değeri.');
      await r.tap(tester, stepsTab, 'Adımlar');
      await r.capture(tester,
          title: 'Yapılışı',
          action: '"Adımlar" sekmesine dokundum.',
          result:
              '3 adım açıklamadan ayrıldı; "10 dakika" ve "5 dk" geçen adımlara '
              'zamanlayıcı kondu.',
          ok: saved.steps.length == 3);

      // ------------------------------------------- Ana sayfada kayıtlılar
      r.mark(tester, find.byTooltip('Geri'), 'Geri');
      ScaffoldMessenger.of(tester.element(find.text('Yapılışı')))
          .clearSnackBars();
      Navigator.of(tester.element(find.text('Yapılışı'))).pop();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
          find.textContaining('Videodan kaydettiklerin'), 300,
          scrollable: _mainScroll);
      await tester.pumpAndSettle();
      await r.capture(tester,
          title: 'Videodan kaydettiklerin',
          action: 'Ana sayfaya döndüm.',
          result:
              'Kaydedilen tarif "Videodan kaydettiklerin" şeridinde; altında '
              'dolaba göre durumu yazıyor.');
      expect(find.textContaining('Videodan kaydettiklerin'), findsOneWidget);
      await tester.scrollUntilVisible(find.text("TikTok'tan"), -300,
          scrollable: _mainScroll);
      await tester.pumpAndSettle();

      // ------------------------------------------- Elle link yapıştırma
      await r.tap(tester, find.text("TikTok'tan"), "TikTok'tan");
      await r.capture(tester,
          title: 'Link yapıştır',
          action: 'Ana sayfada "TikTok\'tan" kısayoluna bastım.',
          result: 'Paylaş menüsünün 3 adımda nasıl kullanılacağı anlatılıyor; '
              'istersen link ya da tarif metni yapıştırılabiliyor.');
      expect(find.text('TikTok\'tan tek dokunuşla'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(1),
          'Bu tarif çok tuttu, denemeyen kalmasın #keşfet');
      await tester.pump();
      await r.tap(tester, find.text('Tarifi kaydet'), 'Tarifi kaydet');
      await tester.pumpAndSettle();
      await r.capture(tester,
          title: 'Tarif yazmayan açıklama',
          action:
              'İçinde tarif olmayan bir açıklama yapıştırıp "Tarifi kaydet"e bastım.',
          result:
              'Boş tarif kaydetmek yerine "Bu metinde tarif bulamadım" diyor ve '
              'tarifi yazmamı istiyor.',
          ok: state.importedRecipes.length == 1);
      expect(find.text('Bu metinde tarif bulamadım'), findsOneWidget);
    } finally {
      debugDisableShadows = true;
      r.writeHtml();
      r.writePrototypeJson(_screen);
    }
  });
}
