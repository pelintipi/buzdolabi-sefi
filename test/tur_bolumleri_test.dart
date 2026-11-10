// Sonuç ekranında yemek, atıştırmalık ve tatlı ayrımı:
//   flutter test test/tur_bolumleri_test.dart
// Rapor: degisiklik_raporlari/2026-11-05_tatli-atistirmalik/rapor.html

import 'package:buzdolabi_sefi/app.dart';
import 'package:buzdolabi_sefi/models/recipe.dart';
import 'package:buzdolabi_sefi/services/collections.dart';
import 'package:buzdolabi_sefi/services/device_services.dart';
import 'package:buzdolabi_sefi/services/ingredient_repository.dart';
import 'package:buzdolabi_sefi/services/recipe_matcher.dart';
import 'package:buzdolabi_sefi/services/storage_service.dart';
import 'package:buzdolabi_sefi/state/app_state.dart';
import 'package:buzdolabi_sefi/widgets/recipe_card.dart';
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

  test('tür ayrımı ve filtre', () {
    Recipe byId(String id) => recipeCatalog.firstWhere((r) => r.id == id);
    expect(kindOf(byId('un_helvasi')), DishKind.dessert);
    expect(kindOf(byId('airfryer_patates')), DishKind.snack);
    expect(kindOf(byId('tavuk_durum')), DishKind.meal);
    expect(kindOf(byId('kiymali_pilav')), DishKind.meal);
    expect(const QuickFilters().withKind(DishKind.dessert).isEmpty, isFalse);
    expect(const QuickFilters(kind: DishKind.snack).withKind(null).isEmpty,
        isTrue);
  });

  testWidgets('sonuçlar: tatlı ve atıştırmalıklar ayrı bölümde',
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
      (ingredientId: 'kiyma', quantity: 500, level: null),
      (ingredientId: 'pirinc', quantity: 1000, level: null),
      (ingredientId: 'patates', quantity: 6, level: null),
      (ingredientId: 'yumurta', quantity: 10, level: null),
      (ingredientId: 'un', quantity: 1000, level: null),
      (ingredientId: 'seker', quantity: 1000, level: null),
      (ingredientId: 'sut', quantity: 1000, level: null),
      (ingredientId: 'kasar', quantity: 300, level: null),
      (ingredientId: 'sivi_yag', quantity: 1000, level: null),
    ]);
    final r = ScreenshotReport(
        'degisiklik_raporlari/2026-11-05_tatli-atistirmalik',
        'Tatlı ve atıştırmalık bölümleri · Ekran testi');

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
      await tester.pumpAndSettle();
      await r.tap(tester, find.text('Ne pişirsem?').first, 'Ne pişirsem?');
      await tester.pumpAndSettle();
      await r.capture(tester,
          title: 'Sonuçlar',
          action: 'Kıyma, pirinç, patates, yumurta, un, şeker, süt, kaşar ile '
              '"Ne pişirsem?"e dokundum.',
          result: 'Üstte yeni şerit: Hepsi · Yemek · Atıştırmalık · '
              'Tatlı.');
      expect(find.text('Tatlı'), findsOneWidget);

      // "Hemen yapabilirsin" altında tatlı ya da atıştırmalık yok.
      List<String> cardTitles() => [
            for (final c
                in tester.widgetList<RecipeCard>(find.byType(RecipeCard)))
              c.match.recipe.id
          ];
      final tatliTitle = find.textContaining(RegExp(r'^Tatlılar \('));
      await tester.scrollUntilVisible(tatliTitle, 300, scrollable: _mainScroll);
      await tester.pumpAndSettle();
      await r.capture(tester,
          title: 'Ayrı bölümler',
          action: 'Aşağı kaydırdım.',
          result: 'Yemeklerden sonra "Atıştırmalıklar" ve "Tatlılar" kendi '
              'bölümlerinde; her birinde en fazla 4 tarif.');

      // Tür filtresi: yalnızca tatlılar.
      await tester.scrollUntilVisible(find.text('Hepsi'), -300,
          scrollable: _mainScroll);
      await tester.pumpAndSettle();
      await _chip(tester, r, 'Tatlı');
      await tester.pumpAndSettle();
      await r.capture(tester,
          title: 'Yalnızca tatlılar',
          action: 'Üstteki "Tatlı" filtresine dokundum.',
          result: 'Liste yalnızca tatlılardan oluşuyor.');
      expect(find.text('Un Helvası'), findsWidgets);
      expect(find.text('Rafadan Yumurta'), findsNothing);
      expect(find.text('Kıymalı Pilav'), findsNothing);

      await _chip(tester, r, 'Atıştırmalık');
      await tester.pumpAndSettle();
      await r.capture(tester,
          title: 'Yalnızca atıştırmalıklar',
          action: '"Atıştırmalık" filtresine dokundum.',
          result:
              'Patates ve yağla yapılabilecek atıştırmalıklar listeleniyor; '
              'yemek ya da tatlı yok.');
      expect(find.text('Patates Kızartması'), findsWidgets);
      expect(find.text('Un Helvası'), findsNothing);
      expect(find.text('Kıymalı Pilav'), findsNothing);

      await _chip(tester, r, 'Yemek');
      await tester.pumpAndSettle();
      expect(find.text('Un Helvası'), findsNothing);
      await tester.scrollUntilVisible(
          find.textContaining('Hemen yapabilirsin ('), 300,
          scrollable: _mainScroll);
      await tester.pumpAndSettle();
      expect(cardTitles(), isNotEmpty);
      for (final id in cardTitles()) {
        expect(
            kindOf(recipeCatalog.firstWhere((x) => x.id == id)), DishKind.meal,
            reason: id);
      }
      await r.capture(tester,
          title: 'Yalnızca yemekler',
          action: '"Yemek" filtresine dokundum.',
          result: 'Tatlı ve atıştırmalık yok; yalnızca öğün yemekleri.');
    } finally {
      debugDisableShadows = true;
      r.writeHtml();
      r.writePrototypeJson(_screen);
    }
  });
}

/// Yatay şeritteki tür düğmesini görünür yapıp dokunur.
Future<void> _chip(
    WidgetTester tester, ScreenshotReport r, String label) async {
  await tester.scrollUntilVisible(find.text('Hepsi'), -300,
      scrollable: _mainScroll);
  await tester.pumpAndSettle();
  final f = find.widgetWithText(ChoiceChip, label);
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await r.tap(tester, f, label);
}
