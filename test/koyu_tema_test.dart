// Koyu temada ana ekranların görüntüsü (göz kontrolü için) ve okunabilirlik:
//   flutter test test/koyu_tema_test.dart
// Rapor: degisiklik_raporlari/2026-11-11_koyu-tema/rapor.html

import 'package:buzdolabi_sefi/app.dart';
import 'package:buzdolabi_sefi/models/user_profile.dart';
import 'package:buzdolabi_sefi/services/device_services.dart';
import 'package:buzdolabi_sefi/services/ingredient_repository.dart';
import 'package:buzdolabi_sefi/services/storage_service.dart';
import 'package:buzdolabi_sefi/state/app_state.dart';
import 'package:buzdolabi_sefi/screens/collections_screen.dart';
import 'package:buzdolabi_sefi/screens/cooked_screen.dart';
import 'package:buzdolabi_sefi/screens/cooking_mode_screen.dart';
import 'package:buzdolabi_sefi/screens/leftover_screen.dart';
import 'package:buzdolabi_sefi/screens/plan_screen.dart';
import 'package:buzdolabi_sefi/screens/progress_screen.dart';
import 'package:buzdolabi_sefi/screens/season_screen.dart';
import 'package:buzdolabi_sefi/screens/sef_plus_screen.dart';
import 'package:buzdolabi_sefi/theme/app_theme.dart';
import 'package:buzdolabi_sefi/theme/palette.dart';
import 'package:buzdolabi_sefi/widgets/share_card.dart';
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

/// WCAG kontrast oranı (metin için en az 4,5; büyük yazı/ikon için 3).
double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  setUpAll(loadRealFonts);

  test('yazı renkleri her iki temada zeminlerine karşı okunur', () {
    for (final b in [Brightness.light, Brightness.dark]) {
      Palette.apply(b);
      final name = b.name;
      for (final bg in [Palette.ground, Palette.surface]) {
        expect(_contrast(Palette.ink, bg), greaterThan(4.5), reason: name);
        expect(_contrast(Palette.inkSoft, bg), greaterThan(4.5), reason: name);
        expect(_contrast(Palette.accent, bg), greaterThan(4.5),
            reason: '$name yeşil yazı');
      }
      // Yumuşak rozet zeminlerindeki yazılar.
      expect(_contrast(Palette.accentDeep, Palette.basilSoft), greaterThan(4.5),
          reason: '$name yeşil rozet');
      expect(
          _contrast(Palette.tomatoText, Palette.tomatoSoft), greaterThan(4.5),
          reason: '$name kiremit rozet');
      expect(
          _contrast(Palette.butterText, Palette.butterSoft), greaterThan(4.5),
          reason: '$name hardal rozet');
    }
    Palette.apply(Brightness.light);
  });

  testWidgets('koyu tema: diğer ekranlar', (tester) async {
    tester.view.physicalSize = _screen * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final s = AppState(
      repo: IngredientRepository(ingredientCatalog),
      recipes: recipeCatalog,
      storage: StorageService(),
    );
    await s.load();
    s.updateProfile(s.profile.copyWith(
        onboarded: true,
        seenNavTour: true,
        allergyAsked: true,
        appliancesAsked: true,
        cookDaysPerWeek: 5,
        uiTheme: UiTheme.dark));
    s.upsertPantryAll([
      (ingredientId: 'kiyma', quantity: 500, level: null),
      (ingredientId: 'pirinc', quantity: 1000, level: null),
      (ingredientId: 'yumurta', quantity: 10, level: null),
      (ingredientId: 'domates', quantity: 4, level: null),
      (ingredientId: 'sogan', quantity: 3, level: null),
    ]);
    final menemen = recipeCatalog.firstWhere((r) => r.id == 'menemen');
    s.toggleFavorite('menemen');
    s.recordCook(menemen, 2, const {}, rating: 4, note: 'Az tuz');
    s.makePlan();
    final r = ScreenshotReport('degisiklik_raporlari/2026-11-11_koyu-tema-2',
        'Koyu tema · Diğer ekranlar');
    final nav = GlobalKey<NavigatorState>();

    Future<void> open(String title, Widget page) async {
      nav.currentState!.push(MaterialPageRoute<void>(builder: (_) => page));
      await tester.pumpAndSettle();
      await r.capture(tester, title: title, action: '', result: '');
      nav.currentState!.pop();
      await tester.pumpAndSettle();
    }

    debugDisableShadows = false;
    try {
      await tester.pumpWidget(RepaintBoundary(
        key: screenshotKey,
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: s),
            Provider.value(value: DeviceServices(cameraAvailable: false)),
          ],
          child: Builder(builder: (context) {
            Palette.apply(Brightness.dark);
            return MaterialApp(
              navigatorKey: nav,
              theme: buildAppTheme(Brightness.dark),
              builder: (context, child) {
                Palette.apply(Theme.of(context).brightness);
                return child!;
              },
              home: const Scaffold(),
            );
          }),
        ),
      ));
      await tester.pumpAndSettle();

      await open(
          'Pişirme modu',
          const CookingModeScreen(
              recipeId: 'menemen', servings: 2, initialStep: 1));
      await open(
          'Afiyet olsun', const CookedScreen(recipeId: 'menemen', servings: 2));
      await open('Haftalık plan', const PlanScreen());
      await open('Koleksiyonlar', const CollectionsScreen());
      await open('İlerleme', const ProgressScreen());
      await open('Şef+', const SefPlusScreen());
      await open('Mevsim', const SeasonScreen());
      await open('Dünden kalan', const LeftoverScreen());
      await open(
          'Paylaşım kartı',
          Scaffold(
              body: Center(
                  child: SizedBox(
                      width: 300,
                      child: AspectRatio(
                          aspectRatio: 9 / 16,
                          child: FittedBox(
                              child: SizedBox(
                                  width: 360,
                                  height: 640,
                                  child: ShareCard(recipe: menemen))))))));
    } finally {
      debugDisableShadows = true;
      r.writeHtml();
      r.writePrototypeJson(_screen);
    }
  });

  testWidgets('koyu tema: ana ekranlar', (tester) async {
    tester.view.physicalSize = _screen * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final s = AppState(
      repo: IngredientRepository(ingredientCatalog),
      recipes: recipeCatalog,
      storage: StorageService(),
    );
    await s.load();
    s.updateProfile(s.profile.copyWith(
        onboarded: true,
        seenNavTour: true,
        allergyAsked: true,
        appliancesAsked: true,
        uiTheme: UiTheme.dark));
    s.upsertPantryAll([
      (ingredientId: 'kiyma', quantity: 500, level: null),
      (ingredientId: 'pirinc', quantity: 1000, level: null),
      (ingredientId: 'yumurta', quantity: 10, level: null),
      (ingredientId: 'domates', quantity: 4, level: null),
      (ingredientId: 'sogan', quantity: 3, level: null),
      (ingredientId: 'patates', quantity: 4, level: null),
    ]);
    final kiyma = s.pantry.firstWhere((p) => p.ingredientId == 'kiyma');
    s.updatePantryItem(
        kiyma.copyWith(expiresAt: DateTime.now().add(const Duration(days: 1))));
    final r = ScreenshotReport(
        'degisiklik_raporlari/2026-11-11_koyu-tema', 'Koyu tema · Ekran testi');

    debugDisableShadows = false;
    try {
      await tester.pumpWidget(RepaintBoundary(
        key: screenshotKey,
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: s),
            Provider.value(value: DeviceServices(cameraAvailable: false)),
          ],
          child: const BuzdolabiSefiApp(),
        ),
      ));
      await tester.pumpAndSettle();
      await r.capture(tester,
          title: 'Ana sayfa', action: 'Koyu temada açtım.', result: '');

      await r.tap(tester, find.text('Ne pişirsem?').first, 'Ne pişirsem?');
      await tester.pumpAndSettle();
      await r.capture(tester, title: 'Sonuçlar', action: '', result: '');
      await tester.scrollUntilVisible(
          find.textContaining('Hemen yapabilirsin ('), 300,
          scrollable: _mainScroll);
      await tester.pumpAndSettle();
      await r.capture(tester, title: 'Sonuç kartları', action: '', result: '');

      await r.tap(tester, find.byType(RecipeCard).first, 'İlk tarif');
      await tester.pumpAndSettle();
      await r.capture(tester,
          title: 'Tarif · Malzemeler', action: '', result: '');
      await r.tap(tester, find.textContaining('Besin').first, 'Besin değeri');
      await tester.pumpAndSettle();
      await r.capture(tester, title: 'Tarif · Besin', action: '', result: '');
      final how = find.text('Bu değerler nasıl hesaplanıyor?');
      await tester.scrollUntilVisible(how, 300, scrollable: _mainScroll);
      await tester.pumpAndSettle();
      await tester.tap(how);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
          find.textContaining('En büyük fark porsiyondan'), 200,
          scrollable: _mainScroll);
      await tester.pumpAndSettle();
      await r.capture(tester,
          title: 'Nasıl hesaplanıyor?', action: '', result: '');
      expect(find.textContaining('USDA'), findsOneWidget);
      Navigator.of(tester.element(how)).pop();
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.text('Ne pişirsem?').first)).pop();
      await tester.pumpAndSettle();

      await r.tap(tester, find.text('Dolabım').last, 'Dolabım');
      await tester.pumpAndSettle();
      await r.capture(tester, title: 'Dolabım', action: '', result: '');

      await r.tap(tester, find.text('Liste').last, 'Liste');
      await tester.pumpAndSettle();
      await r.capture(tester, title: 'Liste', action: '', result: '');

      await r.tap(tester, find.text('Profil').last, 'Profil');
      await tester.pumpAndSettle();
      await r.capture(tester, title: 'Profil', action: '', result: '');
      await tester.scrollUntilVisible(find.text('Alerjiler'), 300,
          scrollable: _mainScroll);
      await tester.pumpAndSettle();
      await r.capture(tester, title: 'Profil · alt', action: '', result: '');
    } finally {
      debugDisableShadows = true;
      r.writeHtml();
      r.writePrototypeJson(_screen);
    }
  });
}
