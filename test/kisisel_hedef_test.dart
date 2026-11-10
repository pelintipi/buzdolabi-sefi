// Günlük kalori/protein hedefini kişiye göre hesaplama:
//   flutter test test/kisisel_hedef_test.dart
// Rapor: degisiklik_raporlari/2026-11-12_kisisel-hedef/rapor.html

import 'package:buzdolabi_sefi/app.dart';
import 'package:buzdolabi_sefi/models/user_profile.dart';
import 'package:buzdolabi_sefi/services/device_services.dart';
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

  testWidgets('profil: bana göre hesapla → hedefler güncellenir',
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
    expect(state.profile.dailyKcal, 2000);
    final r = ScreenshotReport('degisiklik_raporlari/2026-11-12_kisisel-hedef',
        'Kişiye göre günlük hedef · Ekran testi');

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
      await r.tap(tester, find.text('Profil').last, 'Profil');
      await tester.pumpAndSettle();
      final calc = find.text('Bana göre hesapla');
      await tester.scrollUntilVisible(calc, 250,
          scrollable: find
              .byWidgetPredicate((w) =>
                  w is Scrollable && w.axisDirection == AxisDirection.down)
              .first);
      await tester.pumpAndSettle();
      await r.capture(tester,
          title: 'Günlük hedefler',
          action: 'Profil\'de "Günlük hedefler"e indim.',
          result:
              'Genel değer olduğu yazıyor; "Bana göre hesapla" düğmesi var.');

      await r.tap(tester, calc, 'Bana göre hesapla');
      await tester.pumpAndSettle();
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '30');
      await tester.enterText(fields.at(1), '165');
      await tester.enterText(fields.at(2), '65');
      await tester.pumpAndSettle();
      await r.tap(tester, find.text('Kilo vermek'), 'Kilo vermek');
      await tester.pumpAndSettle();
      await r.capture(tester,
          title: 'Bilgilerimi yazdım',
          action: 'Kadın, 30 yaş, 165 cm, 65 kg, biraz hareketli, kilo vermek.',
          result: 'Önerilen 1500 kcal ve 80 g protein, nedeniyle birlikte.');
      expect(find.text('1500 kcal'), findsOneWidget);
      expect(find.text('80 g protein'), findsOneWidget);
      expect(find.text('21 g lif'), findsOneWidget);

      final save = find.text('Hedefim bu olsun');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await r.tap(tester, save, 'Hedefim bu olsun');
      await tester.pumpAndSettle();
      await r.capture(tester,
          title: 'Hedef kaydedildi',
          action: '"Hedefim bu olsun"a bastım.',
          result:
              'Kalori 1500, protein 80 g oldu; neye göre hesaplandığı yazıyor.');
      expect(state.profile.dailyKcal, 1500);
      expect(state.profile.dailyProtein, 80);
      expect(state.profile.dailyFiber, 21);
      expect(state.profile.body?.goal, WeightGoal.lose);
      expect(
          find.textContaining('kilo vermek için hesaplandı'), findsOneWidget);
    } finally {
      debugDisableShadows = true;
      r.writeHtml();
      r.writePrototypeJson(_screen);
    }
  });
}
