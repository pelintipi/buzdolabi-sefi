// Koleksiyonları kullanıcı gibi dener ve ekran görüntüsü alır:
//   flutter test test/koleksiyon_akisi_test.dart
// Rapor: degisiklik_raporlari/2026-11-04_koleksiyonlar/rapor.html

import 'package:buzdolabi_sefi/app.dart';
import 'package:buzdolabi_sefi/screens/recipe_detail_screen.dart';
import 'package:buzdolabi_sefi/services/device_services.dart';
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

final _mainScroll = find
    .byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down)
    .first;

void main() {
  setUpAll(loadRealFonts);

  testWidgets('koleksiyonlar: hazır, kendi koleksiyonum, yaptıklarım',
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
    state.updateProfile(state.profile.copyWith(
        onboarded: true,
        seenNavTour: true,
        allergyAsked: true,
        appliancesAsked: true));
    state.upsertPantryAll([
      (ingredientId: 'yumurta', quantity: 10, level: null),
      (ingredientId: 'domates', quantity: 6, level: null),
      (ingredientId: 'sivri_biber', quantity: 4, level: null),
      (ingredientId: 'tavuk_gogsu', quantity: 800, level: null),
      (ingredientId: 'mercimek', quantity: 500, level: null),
      (ingredientId: 'sut', quantity: 1000, level: null),
      (ingredientId: 'pirinc', quantity: 500, level: null),
      (ingredientId: 'sogan', quantity: 4, level: null),
      (ingredientId: 'havuc', quantity: 3, level: null),
      (ingredientId: 'yogurt', quantity: 500, level: null),
    ]);
    // Geçmiş: menemen iki kez, mercimek çorbası bir kez.
    state.recordCook(state.recipeById('menemen'), 2, const {}, rating: 5);
    state.recordCook(state.recipeById('mercimek_corbasi'), 4, const {},
        rating: 4);
    state.recordCook(state.recipeById('menemen'), 2, const {}, rating: 4);
    state.toggleFavorite('sutlac');

    final r = ScreenshotReport('degisiklik_raporlari/2026-11-04_koleksiyonlar',
        'Koleksiyonlar · Ekran testi');
    debugDisableShadows = false;
    try {
      await tester.pumpWidget(RepaintBoundary(
        key: screenshotKey,
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: state),
            Provider.value(value: DeviceServices(cameraAvailable: false)),
          ],
          child: const BuzdolabiSefiApp(),
        ),
      ));

      await tester.scrollUntilVisible(find.text('Koleksiyonlar'), 200,
          scrollable: _mainScroll);
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(tester.element(find.text('Koleksiyonlar')),
          alignment: 0.3);
      await tester.pumpAndSettle();
      await r.capture(tester,
          title: 'Ana sayfada koleksiyonlar',
          action: 'Ana sayfada biraz kaydırdım.',
          result:
              '"Planla" listesinde "Koleksiyonlar" satırı: yaptıkların, favoriler, hazır listeler.');
      expect(
          find.text('Yaptıklarım, favoriler, hazır listeler'), findsOneWidget);

      await r.tap(tester, find.text('Koleksiyonlar'), 'Koleksiyonlar');
      await tester.pumpAndSettle();
      await r.capture(tester,
          title: 'Koleksiyonlar',
          action: '"Koleksiyonlar"a bastım.',
          result:
              'Üstte pişirdikçe dolan "Yaptıklarım", altında kendi koleksiyonların '
              '(şimdilik Favoriler), en altta hazır koleksiyonlar.');

      await tester.scrollUntilVisible(find.text('Yüksek protein'), 200,
          scrollable: _mainScroll);
      await tester.pumpAndSettle();
      await r.capture(tester,
          title: 'Hazır koleksiyonlar',
          action: 'Aşağı kaydırdım.',
          result: 'Yemek türleri (kahvaltı, çorba, ana yemek, salata ve meze, '
              'atıştırmalık, tatlı) ve ölçülebilir olanlar (yüksek protein, hafif, '
              'doyurucu, 15 dakikada, ekonomik, vejetaryen). Her birinde kaç tanesinin '
              'şu an yapılabildiği yazıyor.');

      await r.tap(tester, find.text('Yüksek protein'), 'Yüksek protein');
      await tester.pumpAndSettle();
      await r.capture(tester,
          title: 'Yüksek protein',
          action: '"Yüksek protein" koleksiyonunu açtım.',
          result:
              'Porsiyonda 20 g ve üstü protein olanlar; dolabındakilerle yapılabilenler önde.');
      expect(
          find.textContaining('tanesini şimdi yapabilirsin'), findsOneWidget);
      Navigator.of(tester.element(find.textContaining('tanesini şimdi'))).pop();
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.text('Hazır koleksiyonlar'))).pop();
      await tester.pumpAndSettle();

      // ------------------------------------------------ Kendi koleksiyonum
      tester.state<NavigatorState>(find.byType(Navigator).first).push(
          MaterialPageRoute<void>(
              builder: (_) =>
                  const RecipeDetailScreen(recipeId: 'karniyarik')));
      await tester.pumpAndSettle();
      await r.tap(
          tester, find.byTooltip('Koleksiyona ekle'), 'Koleksiyona ekle');
      await tester.pumpAndSettle();
      await r.capture(tester,
          title: 'Koleksiyona ekle',
          action: 'Karnıyarık tarifinde kitap ayracına dokundum.',
          result:
              'Favoriler ve kendi koleksiyonların işaretlenebiliyor; "Yeni koleksiyon" var.');

      await r.tap(tester, find.text('Yeni koleksiyon'), 'Yeni koleksiyon');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Misafir menüsü');
      await tester.tap(find.descendant(
          of: find.byType(AlertDialog),
          matching:
              find.byWidgetPredicate((w) => w is Sym && w.emoji == '🎉')));
      await tester.pumpAndSettle();
      await r.capture(tester,
          title: 'Yeni koleksiyon',
          action:
              '"Yeni koleksiyon"a basıp adını "Misafir menüsü" yazdım, 🎉 ikonunu seçtim.',
          result: 'Ad ve ikon seçiliyor.');
      await r.tap(tester, find.text('Oluştur'), 'Oluştur');
      await tester.pumpAndSettle();
      final mine = state.collections.single;
      await r.capture(tester,
          title: 'Eklendi',
          action: '"Oluştur"a bastım.',
          result: 'Koleksiyon oluştu ve Karnıyarık içine eklendi (işaretli).',
          ok: mine.recipeIds.contains('karniyarik') && mine.emoji == '🎉');
      expect(mine.name, 'Misafir menüsü');
      expect(mine.recipeIds, ['karniyarik']);
      Navigator.of(tester.element(find.text('Yeni koleksiyon'))).pop();
      await tester.pumpAndSettle();
      state.toggleInCollection(mine.id, 'sutlac');
      state.toggleInCollection(mine.id, 'mercimek_corbasi');
      Navigator.of(tester.element(find.text('Karnıyarık').first)).pop();
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Koleksiyonlar'), 200,
          scrollable: _mainScroll);
      await r.tap(tester, find.text('Koleksiyonlar'), 'Koleksiyonlar');
      await tester.pumpAndSettle();
      await r.tap(tester, find.text('Misafir menüsü'), 'Misafir menüsü');
      await tester.pumpAndSettle();
      await r.capture(tester,
          title: 'Misafir menüsü',
          action:
              'Koleksiyonlar\'dan "Misafir menüsü"nü açtım (sütlaç ve mercimek çorbasını da ekledim).',
          result:
              'Üç tarif; kaçının şu an yapılabildiği yazıyor. Sağ üstten ad/ikon '
              'değişiyor, silinebiliyor; tarif sola kaydırılınca çıkıyor.');
      expect(find.text('Misafir menüsü'), findsOneWidget);
      Navigator.of(tester.element(find.text('Misafir menüsü'))).pop();
      await tester.pumpAndSettle();

      // ------------------------------------------------ Yaptıklarım
      await r.tap(tester, find.text('Yaptıklarım'), 'Yaptıklarım');
      await tester.pumpAndSettle();
      await r.capture(tester,
          title: 'Yaptıklarım',
          action: '"Yaptıklarım"a dokundum.',
          result:
              'Pişirdiklerim kendiliğinden burada: Menemen 2 kez (en iyi puan 5), '
              'Mercimek Çorbası 1 kez; her birinde "Tekrar yap".',
          ok: state.cookedSummaries.first.times == 2);
      expect(find.text('En çok yaptıkların'), findsOneWidget);
    } finally {
      debugDisableShadows = true;
      r.writeHtml();
      r.writePrototypeJson(_screen);
    }
  });
}
