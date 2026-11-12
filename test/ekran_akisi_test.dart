// Kullanıcı gibi tıklayarak uygulamayı baştan sona dener ve her adımın ekran
// görüntüsünü alır. Çalıştırınca test_raporu/ altında rapor.html ve
// oynatılabilir prototip için prototip.json oluşur:
//   flutter test test/ekran_akisi_test.dart

import 'package:buzdolabi_sefi/app.dart';
import 'package:buzdolabi_sefi/services/ingredient_repository.dart';
import 'package:buzdolabi_sefi/services/storage_service.dart';
import 'package:buzdolabi_sefi/state/app_state.dart';
import 'package:buzdolabi_sefi/widgets/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/screenshot_report.dart';
import 'support/test_catalog.dart';

const _screen = Size(393, 852);

/// Sayfanın dikey kaydırması (yatay filtre şeridi değil).
final _mainScroll = find
    .byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down)
    .first;

bool _enabled(WidgetTester tester, String label) {
  final button =
      find.ancestor(of: find.text(label), matching: find.byType(ChunkyButton));
  return tester.widget<ChunkyButton>(button.first).onPressed != null;
}

/// Kuyruktaki bildirimlerin (SnackBar) süresinin dolmasını bekler.
Future<void> _clearSnackBars(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(seconds: 11));
    await tester.pumpAndSettle();
  }
}

void main() {
  setUpAll(loadRealFonts);

  testWidgets('kullanıcı akışı: malzeme seç → seçenekleri karşılaştır → pişir',
      (tester) async {
    // iPhone 15 ekranı
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
    // Açılış anketini daha önce doldurmuş kullanıcı (anket: anket_akisi_test).
    state.updateProfile(
        state.profile.copyWith(onboarded: true, seenNavTour: true));
    final r = ScreenshotReport('test_raporu', 'Buzdolabı Şefi · Ekran testi');

    // Testler gölgeyi siyah çerçeve olarak çizer; görüntüler gerçeğe benzesin.
    debugDisableShadows = false;
    try {
      await tester.pumpWidget(RepaintBoundary(
        key: screenshotKey,
        child: ChangeNotifierProvider.value(
            value: state, child: const BuzdolabiSefiApp()),
      ));

      // ------------------------------------------------ Yumurta + un + süt
      await r.capture(tester,
          title: 'Ana sayfa',
          action: 'Uygulamayı ilk kez açtım.',
          result:
              'Dolap boş. Yeşil kartta büyük sarı "Ne pişirsem?" butonu var.');
      expect(find.text('Ne pişirsem?'), findsOneWidget);

      await r.tap(tester, find.text('Ne pişirsem?'), 'Ne pişirsem?');
      await r.capture(tester,
          title: 'Malzeme seçimi',
          action: '"Ne pişirsem?" butonuna bastım.',
          result:
              'Dolap boş olduğu için malzeme ekranı açıldı; en sık 20 malzeme kutu kutu duruyor.');
      expect(find.text('Dolabında ne var?'), findsOneWidget);

      await r.tap(tester, find.text('Yumurta'), 'Yumurta');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Un'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Süt'));
      final canShow = _enabled(tester, 'Tarifleri göster');
      await r.capture(tester,
          title: 'Yumurta, un, süt',
          action: 'Hızlı ekle kutularından Yumurta, Un ve Süt\'e dokundum.',
          result:
              'Üçü "Eklenecekler" listesine geldi; yumurta adetle, süt "Biraz" olarak. '
              '"Tarifleri göster" aktif.',
          ok: canShow);
      expect(find.text('Eklenecekler (3)'), findsOneWidget);

      await r.tap(tester, find.text('Tarifleri göster'), 'Tarifleri göster');
      await tester.pumpAndSettle();
      final hasCompare =
          find.text('Seçeneklerini karşılaştır').evaluate().isNotEmpty;
      await r.capture(tester,
          title: 'Seçenekler',
          action: '"Tarifleri göster" butonuna bastım.',
          result: hasCompare
              ? 'Krep, rafadan yumurta, pankek gibi seçenekler çıktı. Karşılaştırma tablosu '
                  'dakika, protein ve kaloriyi yan yana gösteriyor; her sütunun en iyisi sarı.'
              : 'Karşılaştırma tablosu çıkmadı.',
          ok: hasCompare);
      expect(hasCompare, isTrue);
      expect(find.text('Pankek'), findsWidgets);
      expect(find.text('Krep'), findsWidgets);

      final sortChip = find.text('En çok protein');
      r.mark(tester, find.text('Seçeneklerini karşılaştır'), 'Aşağı kaydır');
      await tester.scrollUntilVisible(sortChip, 200, scrollable: _mainScroll);
      await tester.pumpAndSettle();
      await r.capture(tester,
          title: 'Rozetler ve sıralama',
          action: 'Aşağı kaydırdım.',
          result:
              '"Sadece … alırsan" önerisi, sıralama seçenekleri ve yapılabilen tariflerin '
              'kartlarında "En hızlı / En dengeli / En proteinli" gibi rozetler var; rozet yalnızca hak edene veriliyor.');

      await r.tap(tester, sortChip, 'En çok protein');
      await tester.pumpAndSettle();
      await r.capture(tester,
          title: 'En çok protein önce',
          action: '"En çok protein" sıralamasını seçtim.',
          result: 'Yapılabilenler protein miktarına göre çoktan aza dizildi; '
              'eksiği olanlar arkadan geliyor.');
      expect(find.textContaining('En çok protein önce'), findsOneWidget);

      final listButton = find.text('Listeye ekle');
      await tester.scrollUntilVisible(listButton, -200,
          scrollable: _mainScroll);
      await tester.pumpAndSettle();
      await r.tap(tester, listButton, 'Listeye ekle');
      await tester.pumpAndSettle();
      await r.capture(tester,
          title: 'Listeye ekle',
          action: 'Öneri kartında "Listeye ekle"ye bastım.',
          result:
              'Eksik malzeme alışveriş listesine eklendi; alt menüde "Liste" sekmesinde sayı belirdi.',
          ok: state.shoppingList.isNotEmpty);
      expect(state.shoppingList, isNotEmpty);
      await _clearSnackBars(tester);

      await tester.scrollUntilVisible(find.text('Pankek').last, 200,
          scrollable: _mainScroll);
      await tester.pumpAndSettle();
      await r.tap(tester, find.text('Pankek').last, 'Pankek');
      await r.capture(tester,
          title: 'Alerji sorusu',
          action: 'Pankek kartına dokundum.',
          result: 'İlk tarifte bir kereye mahsus alerji soruluyor.');
      expect(find.text('Alerjin var mı?'), findsOneWidget);

      await r.tap(tester, find.text('Alerjim yok'), 'Alerjim yok');
      await r.capture(tester,
          title: 'Pankek',
          action: '"Alerjim yok" dedim.',
          result:
              'Kalori, protein, yağ ve maliyet kutuları; tereyağı yoksa sıvı yağ alternatifi.');
      expect(find.text('Pişirmeye başla'), findsOneWidget);

      // ------------------------------------------------ Menemen pişirme
      r.mark(tester, find.byType(BackButton).last, 'Geri dön, malzeme ekle');
      Navigator.of(tester.element(find.text('Pişirmeye başla'))).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Malzemeleri düzenle'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byType(TextField), '3 yumurta, 3 domates, 3 sivri biber');
      await tester.pumpAndSettle();
      await r.capture(tester,
          title: 'Yazarak ekleme',
          action:
              'Sonuçlarda "Malzemeleri düzenle"ye basıp "3 yumurta, 3 domates, 3 sivri biber" yazdım.',
          result:
              'Yazdıkça eşleşen malzemeler öneri olarak çıkıyor; + basmadan da kaydedilebiliyor.',
          ok: _enabled(tester, 'Dolaba ekle'));

      await r.tap(tester, find.text('Dolaba ekle'), 'Dolaba ekle');
      await tester.pumpAndSettle();
      await _clearSnackBars(tester);
      await tester.scrollUntilVisible(find.text('Menemen').last, 200,
          scrollable: _mainScroll);
      await tester.pumpAndSettle();
      await r.capture(tester,
          title: 'Menemen de hazır',
          action: '"Dolaba ekle"ye bastım.',
          result: 'Domates ve biber gelince Menemen de seçeneklere katıldı; '
              'liste hâlâ "En çok protein" sırasında.');
      expect(find.text('Menemen'), findsWidgets);

      await r.tap(tester, find.text('Menemen').last, 'Menemen');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pişirmeye başla'));
      await r.capture(tester,
          title: 'Pişirme modu',
          action: 'Menemen\'i açıp "Pişirmeye başla"ya bastım.',
          result:
              'Büyük yazıyla 1. adım, üstte adım çubukları, sarı zamanlayıcı butonu.');
      expect(find.text('Adım 1/5'), findsOneWidget);

      await r.tap(
          tester, find.textContaining('dk başlat'), 'Zamanlayıcıyı başlat');
      await r.capture(tester,
          settle: false,
          title: 'Zamanlayıcı',
          action: 'Zamanlayıcıyı başlattım.',
          result: 'Üstte geri sayan "Biberler 04:00" çipi belirdi.');
      expect(find.textContaining('Biberler'), findsWidgets);
      await tester.tap(find.byTooltip('Zamanlayıcıyı kapat'));
      await tester.pumpAndSettle();

      r.mark(tester, find.text('Sonraki'), 'Sonraki');
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.text('Sonraki'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Bitir'));
      await r.capture(tester,
          title: 'Afiyet olsun',
          action: '"Sonraki" ile 5 adımı geçip "Bitir"e bastım.',
          result: 'Kutlama ekranı ve kırmızı "Pişirdim!" butonu.');
      expect(find.text('Pişirdim!'), findsOneWidget);

      await r.tap(tester, find.text('Pişirdim!'), 'Pişirdim!');
      await r.capture(tester,
          title: 'Dolaptan düşme',
          action: '"Pişirdim!" butonuna bastım.',
          result:
              'Kullanılan yumurta, domates ve biber listeleniyor; tamamı/yarısı/düzenle seçilebiliyor.');
      expect(find.textContaining('Yumurta'), findsWidgets);

      await tester.ensureVisible(find.text('Kaydet'));
      await tester.pumpAndSettle();
      await r.tap(tester, find.text('Kaydet'), 'Kaydet');
      await r.capture(tester,
          title: 'Mutfak aletleri',
          action: '"Kaydet"e bastım.',
          result: 'İlk pişirmeden sonra hangi aletlerim olduğu soruluyor.');
      expect(find.text('Mutfağında neler var?'), findsOneWidget);

      await r.tap(tester, find.text('Kaydet'), 'Kaydet');
      await r.capture(tester,
          title: 'Ödül',
          action: 'Aletleri kaydettim.',
          result:
              'Haftalık hedefte ilk yuva doldu, "Sote +1" beceri puanı geldi.');
      expect(find.textContaining('1/3'), findsWidgets);

      // ------------------------------------------------ Liste ve dolap
      await r.tap(tester, find.text('Ana sayfaya dön'), 'Ana sayfaya dön');
      await tester.pumpAndSettle();
      await _clearSnackBars(tester);
      await r.capture(tester,
          title: 'Ana sayfa',
          action: '"Ana sayfaya dön"e bastım.',
          result:
              'Haftalık seri kartında ilk yuva dolu; alt menüde listede 1 malzeme var.');

      await r.tap(tester, find.text('Liste'), 'Liste');
      await r.capture(tester,
          title: 'Alışveriş listesi',
          action: 'Alt menüden "Liste"ye geçtim.',
          result:
              'Önerideki eksik malzeme burada; "Aldım" deyince dolaba geçiyor.');
      expect(find.text('Aldım'), findsOneWidget);

      final bought = state.shoppingList.first;
      await r.tap(tester, find.text('Aldım'), 'Aldım');
      await tester.pumpAndSettle();
      await _clearSnackBars(tester);
      await r.capture(tester,
          title: 'Liste boşaldı',
          action: '"Aldım"a bastım.',
          result: 'Malzeme listeden çıkıp dolaba eklendi.',
          ok: state.pantry.any((p) => p.ingredientId == bought));
      expect(state.pantry.any((p) => p.ingredientId == bought), isTrue);

      await r.tap(tester, find.text('Dolabım'), 'Dolabım');
      await tester.pumpAndSettle();
      final eggGone = !state.pantry.any((p) => p.ingredientId == 'yumurta');
      await r.capture(tester,
          title: 'Dolabım',
          action: 'Alt menüden "Dolabım"a geçtim.',
          result: eggGone
              ? 'Menemende yumurtalar, domatesler ve biberler kullanıldığı için listeden düştü; '
                  'süt, un ve listeden alınan malzeme duruyor.'
              : 'Yumurta hâlâ dolapta; düşme beklendiği gibi çalışmadı.',
          ok: eggGone);
      expect(eggGone, isTrue);

      await r.tap(tester, find.text('Malzeme ekle'), 'Malzeme ekle');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField),
          '500 gr kıyma, 4 patates, 2 soğan, biraz yoğurt');
      await tester.tap(find.byTooltip('Ekle'));
      await r.capture(tester,
          title: 'Miktarlı malzeme listesi',
          action:
              '"Malzeme ekle" ile "500 gr kıyma, 4 patates, 2 soğan, biraz yoğurt" yazıp + butonuna bastım.',
          result:
              'Cümle malzemelere ayrıldı: kıyma 500 g, patates ve soğan adetle, yoğurt "Biraz".');
      expect(find.text('Eklenecekler (4)'), findsOneWidget);

      await r.tap(tester, find.text('Dolaba ekle'), 'Dolaba ekle');
      await tester.pumpAndSettle();
      final readyNote = find.textContaining('tarifi hemen yapabilirsin');
      await r.capture(tester,
          title: 'Dolu dolap',
          action: '"Dolaba ekle"ye bastım.',
          result:
              'Kıyma 2 gün içinde bozulacağı için en üstte; bildirim kaç tarifin hazır olduğunu söylüyor.',
          ok: readyNote.evaluate().isNotEmpty);
      expect(readyNote, findsOneWidget);

      await r.tap(tester, find.text('Kıyma'), 'Kıyma');
      await r.capture(tester,
          title: 'Malzeme düzenleme',
          action: 'Kıyma\'ya dokundum.',
          result:
              'Miktar, kesin gram ve son kullanma tarihi değiştirilebiliyor; silinebiliyor.');
      expect(find.text('Sil'), findsOneWidget);
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();
      await _clearSnackBars(tester);

      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('İlerlemem'));
      await tester.pumpAndSettle();
      r.mark(tester, find.text('İlerleme'), 'İlerlemem');
      await r.capture(tester,
          title: 'İlerleme',
          action: 'Profil\x27de "İlerlemem"e dokundum.',
          result:
              'Haftalık seri, toplam pişirme, beceri ağacı ve son pişirilen Menemen.');
      await tester.scrollUntilVisible(find.textContaining('Sote').first, 300,
          scrollable: _mainScroll);
      await tester.pumpAndSettle();
      expect(find.textContaining('Sote'), findsWidgets);
      Navigator.of(tester.element(find.textContaining('Sote').first)).pop();
      await tester.pumpAndSettle();

      await r.tap(tester, find.text('Profil'), 'Profil');
      await r.capture(tester,
          title: 'Profil',
          action: '"Profil" sekmesine geçtim.',
          result:
              'Anket cevapları, hatırlatmalar, günlük kalori-protein hedefleri, '
              'Şef+ ve gizlilik; altında diyet, alerjiler ve mutfak aletleri.');
      expect(find.text('Hatırlatmalar'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Alerjiler'), 300,
          scrollable: _mainScroll);
      expect(find.text('Alerjiler'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Seni tanıyalım'), -300,
          scrollable: _mainScroll);

      await r.tap(tester, find.text('Ana sayfa'), 'Ana sayfa');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Yakında bozulacaklar'), 300,
          scrollable: _mainScroll);
      await r.capture(tester,
          title: 'Ana sayfa (dolu dolap)',
          action: '"Ana sayfa" sekmesine döndüm.',
          result:
              'Bozulmak üzere olan kıyma için sarı uyarı kartı ve tarif önerisi.');
      expect(find.text('Yakında bozulacaklar'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Ne pişirsem?'), -300,
          scrollable: _mainScroll);
      await tester.pumpAndSettle();

      await r.tap(tester, find.text('Ne pişirsem?'), 'Ne pişirsem?');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yüksek protein'));
      await r.capture(tester,
          title: 'Hızlı filtre',
          action: 'Tarif sonuçlarında "Yüksek protein" filtresini açtım.',
          result:
              'Yalnızca porsiyonda 20 g ve üstü protein içerenler kaldı; özet "Bu malzemeler ve filtrelerle" diyor.');
      expect(
          find.textContaining('Bu malzemeler ve filtrelerle'), findsOneWidget);

      await _clearSnackBars(tester);
    } finally {
      debugDisableShadows = true;
      r.writeHtml();
      r.writePrototypeJson(_screen);
    }
  });
}
