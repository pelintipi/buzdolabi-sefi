// Dünden kalan: porsiyonla girilir, bitince dolaptan kalkar; haftalık hedef
// aşılınca "+2".
//   flutter test test/artik_porsiyon_test.dart
// Rapor: degisiklik_raporlari/2026-11-12_artik-porsiyon/rapor.html

import 'package:buzdolabi_sefi/screens/leftover_screen.dart';
import 'package:buzdolabi_sefi/screens/pantry_screen.dart';
import 'package:buzdolabi_sefi/services/device_services.dart';
import 'package:buzdolabi_sefi/services/ingredient_repository.dart';
import 'package:buzdolabi_sefi/services/storage_service.dart';
import 'package:buzdolabi_sefi/state/app_state.dart';
import 'package:buzdolabi_sefi/theme/app_theme.dart';
import 'package:buzdolabi_sefi/theme/palette.dart';
import 'package:buzdolabi_sefi/widgets/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/screenshot_report.dart';
import 'support/test_catalog.dart';

const _screen = Size(393, 852);

Future<AppState> _state() async {
  SharedPreferences.setMockInitialValues({});
  final s = AppState(
    repo: IngredientRepository(ingredientCatalog),
    recipes: recipeCatalog,
    storage: StorageService(),
  );
  await s.load();
  s.updateProfile(s.profile.copyWith(onboarded: true, seenNavTour: true));
  return s;
}

void main() {
  setUpAll(loadRealFonts);

  test('porsiyon girilir, pişirince düşer, bitince kalkar', () async {
    final s = await _state();
    s.setLeftoverPortions('pismis_makarna', 2);
    expect(s.leftoverPortions('pismis_makarna'), closeTo(2, 0.01));
    final ing = s.repo.byId('pismis_makarna');
    expect(pantryAmountText(s.pantry.single, ing), '2 porsiyon');

    // Tarif 2 kişilik, 2 porsiyonu (300 g) kullanır: dolaptan tamamen gider.
    final r = recipeCatalog
        .firstWhere((x) => x.id == 'kremali_tavuklu_makarna_artik');
    s.recordCook(r, 2, {'pismis_makarna': 300});
    expect(s.leftovers, isEmpty);

    // 2 porsiyondan 1,6 porsiyon kullanılırsa kalan 0,4 porsiyon (60 g)
    // "bitti" sayılır, dolapta birkaç kaşık takılı kalmaz.
    s.setLeftoverPortions('pismis_makarna', 2);
    s.recordCook(r, 2, {'pismis_makarna': 240});
    expect(s.leftovers, isEmpty);

    // Yarısı kullanılırsa 1 porsiyon kalır.
    s.setLeftoverPortions('pismis_makarna', 2);
    s.recordCook(r, 1, {'pismis_makarna': 150});
    expect(s.leftoverPortions('pismis_makarna'), closeTo(1, 0.01));

    s.setLeftoverPortions('pismis_makarna', 0);
    expect(s.leftovers, isEmpty);
  });

  testWidgets('hedef aşılınca "+2" rozeti', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Center(child: WeeklySlots(done: 5, goal: 3)))));
    expect(find.text('+2'), findsOneWidget);
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Center(child: WeeklySlots(done: 3, goal: 3)))));
    expect(find.textContaining('+'), findsNothing);
  });

  testWidgets('Dünden kalan: dokunmak eklemez, porsiyon seçince eklenir',
      (tester) async {
    tester.view.physicalSize = _screen * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final s = await _state();
    final r = ScreenshotReport('degisiklik_raporlari/2026-11-12_artik-porsiyon',
        'Dünden kalan · Ekran testi');
    debugDisableShadows = false;
    try {
      await tester.pumpWidget(RepaintBoundary(
        key: screenshotKey,
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: s),
            Provider.value(value: DeviceServices(cameraAvailable: false)),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(Brightness.light),
            builder: (context, child) {
              Palette.apply(Theme.of(context).brightness);
              return child!;
            },
            home: const LeftoverScreen(),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await r.tap(tester, find.text('Haşlanmış makarna'), 'Haşlanmış makarna');
      await tester.pumpAndSettle();
      expect(s.leftovers, isEmpty, reason: 'göz atmak dolaba eklememeli');
      await r.capture(tester,
          title: 'Seçtim, eklenmedi',
          action: '"Haşlanmış makarna"ya dokundum.',
          result: 'Tarifler görünüyor; "Ne kadar kaldı?" porsiyonla soruluyor. '
              'Dolaba henüz eklenmedi.');

      await r.tap(tester, find.text('1 porsiyon'), '1 porsiyon');
      await tester.pumpAndSettle();
      expect(s.leftoverPortions('pismis_makarna'), closeTo(1, 0.01));
      expect(find.text('1 porsiyon var'), findsOneWidget);
      await r.capture(tester,
          title: '1 porsiyon',
          action: '"1 porsiyon"a dokundum.',
          result: 'Kutuda "1 porsiyon var"; yanında "Bitti" çıktı.');

      await r.tap(tester, find.text('Bitti'), 'Bitti');
      await tester.pumpAndSettle();
      expect(s.leftovers, isEmpty);
      expect(find.textContaining('porsiyon var'), findsNothing);
    } finally {
      debugDisableShadows = true;
      r.writeHtml();
      r.writePrototypeJson(_screen);
    }
  });
}
