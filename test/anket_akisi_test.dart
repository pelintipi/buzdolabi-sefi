// Açılış anketini kullanıcı gibi doldurur, cevapların uygulamaya yansıdığını
// ve tarif ekranının üç parçasını, "Neler alabilirim?" önerilerini dener:
//   flutter test test/anket_akisi_test.dart
// Rapor: degisiklik_raporlari/2026-11-04_anket-ve-tarif-sekmeleri/rapor.html

import 'package:buzdolabi_sefi/app.dart';
import 'package:buzdolabi_sefi/models/recipe.dart';
import 'package:buzdolabi_sefi/models/user_profile.dart';
import 'package:buzdolabi_sefi/screens/recipe_detail_screen.dart';
import 'package:buzdolabi_sefi/screens/shopping_screen.dart';
import 'package:buzdolabi_sefi/services/recipe_matcher.dart';
import 'package:buzdolabi_sefi/services/ingredient_repository.dart';
import 'package:buzdolabi_sefi/services/storage_service.dart';
import 'package:buzdolabi_sefi/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/screenshot_report.dart';
import 'support/test_catalog.dart';

const _screen = Size(393, 852);

void main() {
  setUpAll(loadRealFonts);

  testWidgets(
      'anket → kişisel ana sayfa → tarifin üç parçası → neler alabilirim',
      (tester) async {
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
    final r = ScreenshotReport(
        'degisiklik_raporlari/2026-11-04_anket-ve-tarif-sekmeleri',
        'Açılış anketi ve tarifin üç parçası · Ekran testi');

    /// Tek seçimli soruda seçer, seçimi görüntüler, otomatik geçişi bekler.
    Future<void> pick(String label, String title, String result) async {
      await r.tap(tester, find.text(label), label);
      await tester.pump(const Duration(milliseconds: 200));
      await r.capture(tester,
          title: title,
          action: '"$label" seçeneğine dokundum.',
          result: result,
          settle: false);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
    }

    debugDisableShadows = false;
    try {
      await tester.pumpWidget(RepaintBoundary(
        key: screenshotKey,
        child: ChangeNotifierProvider.value(
            value: state, child: const BuzdolabiSefiApp()),
      ));

      await r.capture(tester,
          title: 'Hoş geldin',
          action: 'Uygulamayı ilk kez açtım.',
          result: 'Ana sayfadan önce kısa anket: "7 kısa soru, yarım dakika". '
              'İstemeyen "Şimdilik geç" diyebiliyor.');
      expect(find.text('Hoş geldin!'), findsOneWidget);

      // -------------------------------------------------------- 1 · Amaç
      await r.tap(tester, find.text('Başlayalım'), 'Başlayalım');
      await tester.pumpAndSettle();
      await tester.tap(find.text(Goal.waste.label));
      await tester.tap(find.text(Goal.videos.label));
      await tester.pumpAndSettle();
      await r.capture(tester,
          title: '1 · Seni buraya ne getirdi?',
          action: '"Başlayalım"a basıp iki amaç seçtim.',
          result: 'Birden çok seçilebiliyor; her sorunun altında cevabın neyi '
              'değiştireceği yazıyor.');
      expect(find.text('Devam (2)'), findsOneWidget);
      await r.tap(tester, find.text('Devam (2)'), 'Devam');
      await tester.pumpAndSettle();

      // -------------------------------------------------------- 2-3
      await pick('5-6 gün', '2 · Haftada kaç gün?',
          'Tek seçimli: dokununca işaretlenip kendiliğinden sonraki soruya geçiyor.');
      await pick(Household.couple.label, '3 · Kimin için?',
          'Tarifler 2 kişilik açılacak.');

      // -------------------------------------------------------- 4 · Aletler
      await r.capture(tester,
          title: '4 · Nelerle pişiriyorsun?',
          action: 'Aletler sorusuna geldim.',
          result:
              'Hiçbiri kendiliğinden işaretli değil; en az birini seçene kadar '
              'buton "En az birini seç" diyor ve kapalı.',
          ok: find.text('En az birini seç').evaluate().isNotEmpty);
      expect(find.text('En az birini seç'), findsOneWidget);
      await tester.tap(find.text(Appliance.ocak.label));
      await tester.tap(find.text(Appliance.airfryer.label));
      await tester.pumpAndSettle();
      await r.capture(tester,
          title: '4 · Aletleri seçtim',
          action: 'Ocak ve Airfryer\'ı seçtim (fırınım yok).',
          result: 'Fırın gerektiren tarifler gösterilmeyecek.');
      await r.tap(tester, find.text('Devam (2)'), 'Devam');
      await tester.pumpAndSettle();

      // -------------------------------------------------------- 5 · Beslenme
      await pick(EatingStyle.protein.label, '5 · Nasıl besleniyorsun?',
          'Sonuçlar "En çok protein" sırasıyla açılacak.');

      // -------------------------------------------------------- 6 · Saklama
      await tester.tap(find.text(RecipeHabit.social.label));
      await tester.pumpAndSettle();
      await r.capture(tester,
          title: '6 · Tariflerini nasıl saklıyorsun?',
          action: '"TikTok / Instagram\'da kaydediyorum"u seçtim.',
          result: 'TikTok\'tan kaydetme kartı ana sayfada en üste çıkacak.');
      await r.tap(tester, find.text('Devam (1)'), 'Devam');
      await tester.pumpAndSettle();

      // -------------------------------------------------------- 7 · Zaman
      await pick(PlanTime.evening.label, '7 · Ne zaman düşünürsün?',
          'Ana sayfanın karşılama cümlesi buna göre değişecek.');

      await r.capture(tester,
          title: 'Hazırsın',
          action: 'Son soruyu yanıtladım.',
          result: 'Cevapların uygulamada neyi değiştirdiği tek tek yazıyor.');
      expect(find.text('Haftalık hedefin: 5 pişirme'), findsOneWidget);
      expect(find.text('Tarifler 2 kişilik açılacak'), findsOneWidget);

      // -------------------------------------------------------- Ana sayfa
      await r.tap(tester, find.text('Mutfağa geç'), 'Mutfağa geç');
      await tester.pumpAndSettle();
      final p = state.profile;
      await r.capture(tester,
          title: 'Sana göre ana sayfa',
          action: '"Mutfağa geç"e bastım.',
          result: '"Eve varmadan ne pişireceğin belli olsun", TikTok kartı en '
              'üstte, yeşil kartta "Bozulmak üzere olanları önce kullanan '
              'tarifler", seri hedefi 0/5.',
          ok: p.onboarded &&
              p.cookDaysPerWeek == 5 &&
              p.household == Household.couple &&
              p.appliances.contains(Appliance.airfryer) &&
              p.eating == EatingStyle.protein &&
              p.planTime == PlanTime.evening);
      expect(find.text(PlanTime.evening.homeLine), findsOneWidget);
      final videoCard =
          tester.getTopLeft(find.text('TikTok\'tan tarif kaydet'));
      final hero = tester.getTopLeft(find.text('Ne pişirsem?'));
      expect(videoCard.dy, lessThan(hero.dy), reason: 'video kartı üstte');
      // Seri kartı sayfanın altında; kaydırıp bak, sonra başa dön.
      final scroll = find
          .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down)
          .first;
      await tester.scrollUntilVisible(find.text('Bu hafta 0/5 pişirme'), 300,
          scrollable: scroll);
      expect(find.text('Bu hafta 0/5 pişirme'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Ne pişirsem?'), -300,
          scrollable: scroll);
      await tester.pumpAndSettle();

      // -------------------------------------------------------- Tarif: 3 parça
      state.updateProfile(state.profile.copyWith(allergyAsked: true));
      state.upsertPantryAll([
        (ingredientId: 'yumurta', quantity: 6, level: null),
        (ingredientId: 'domates', quantity: 3, level: null),
        (ingredientId: 'sivri_biber', quantity: 2, level: null),
        (ingredientId: 'un', quantity: 500, level: null),
        (ingredientId: 'sut', quantity: 1000, level: null),
      ]);
      tester.state<NavigatorState>(find.byType(Navigator).first).push(
          MaterialPageRoute<void>(
              builder: (_) => const RecipeDetailScreen(recipeId: 'menemen')));
      await tester.pumpAndSettle();
      await r.capture(tester,
          title: 'Tarif · Malzemeler',
          action: 'Menemen tarifini açtım.',
          result: 'Başlıkta süre, kalori, protein. Altında üç sekme; ilki '
              'Malzemeler, ankete göre 2 kişilik açıldı.');
      expect(find.text('2 kişilik'), findsOneWidget);

      await r.tap(tester, find.textContaining('Adımlar ('), 'Adımlar');
      await tester.pumpAndSettle();
      await r.capture(tester,
          title: 'Tarif · Adımlar',
          action: '"Adımlar" sekmesine dokundum.',
          result: 'Numaralı adımlar ve zamanlayıcılar.');
      expect(find.text('Yapılışı'), findsOneWidget);

      await r.tap(tester, find.text('Besin değeri'), 'Besin değeri');
      await tester.pumpAndSettle();
      await r.capture(tester,
          title: 'Tarif · Besin değeri',
          action: '"Besin değeri" sekmesine dokundum.',
          result: 'Enerji, protein, karbonhidrat, yağ: 1 porsiyon ve 2 kişilik '
              'toplam, günlük ihtiyaca oranı çubukla.');
      expect(find.text('Karbonhidrat'), findsOneWidget);

      // -------------------------------------------------------- Neler alabilirim?
      r.mark(tester, find.byTooltip('Geri'), 'Geri');
      Navigator.of(tester.element(find.text('Karbonhidrat'))).pop();
      await tester.pumpAndSettle();
      await r.tap(tester, find.text('Liste'), 'Liste');
      await tester.pumpAndSettle();
      final suggestions = state.matcher
          .unlockSuggestions(state.matches(const QuickFilters()))
          .isNotEmpty;
      await r.capture(tester,
          title: 'Neler alabilirim?',
          action: 'Alt menüden "Liste"ye geçtim.',
          result:
              'Liste boşken bile öneri var: dolabındakilere tek bir malzeme '
              'eklersen kaç tarifin açılacağı ve hangileri olduğu.',
          ok: suggestions);
      expect(find.text('Neler alabilirim?'), findsOneWidget);

      final add = find
          .descendant(
              of: find.byType(ShoppingScreen), matching: find.text('Ekle'))
          .first;
      await r.tap(tester, add, 'Ekle');
      await tester.pumpAndSettle();
      await r.capture(tester,
          title: 'Öneri listede',
          action: 'İlk önerinin "Ekle" butonuna bastım.',
          result: 'Malzeme alışveriş listesine girdi, butonu "Listede" oldu.',
          ok: state.shoppingList.length == 1);
      expect(state.shoppingList, hasLength(1));
    } finally {
      debugDisableShadows = true;
      r.writeHtml();
      r.writePrototypeJson(_screen);
    }
  });
}
