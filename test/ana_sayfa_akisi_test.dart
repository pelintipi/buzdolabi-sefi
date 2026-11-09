// Ana sayfanın boş ve dolu dolapla görünümü:
//   flutter test test/ana_sayfa_akisi_test.dart
// Rapor: degisiklik_raporlari/2026-11-04_ana-sayfa/rapor.html

import 'package:buzdolabi_sefi/app.dart';
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

final _mainScroll = find
    .byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down)
    .first;

void main() {
  setUpAll(loadRealFonts);

  testWidgets('ana sayfa: boş dolap, dolu dolap, alt bölümler', (tester) async {
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
        allergyAsked: true,
        appliancesAsked: true,
        seenNavTour: true));
    final r = ScreenshotReport(
        'degisiklik_raporlari/2026-11-04_ana-sayfa', 'Ana sayfa · Ekran testi');

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
      await r.capture(tester,
          title: 'Boş dolap',
          action: 'Uygulamayı ilk kez açtım (dolap boş).',
          result:
              'Tek belirgin buton "Ne pişirsem?"; altında "Dolabında ne var?" çağrısı.');
      expect(find.text('Dolabında ne var?'), findsOneWidget);

      state.upsertPantryAll([
        (ingredientId: 'yumurta', quantity: 10, level: null),
        (ingredientId: 'domates', quantity: 6, level: null),
        (ingredientId: 'sivri_biber', quantity: 4, level: null),
        (ingredientId: 'mercimek', quantity: 500, level: null),
        (ingredientId: 'sogan', quantity: 4, level: null),
        (ingredientId: 'havuc', quantity: 3, level: null),
        (ingredientId: 'sut', quantity: 1000, level: null),
        (ingredientId: 'un', quantity: 1000, level: null),
        (ingredientId: 'kiyma', quantity: 400, level: null),
      ]);
      // Kıyma yarın bozuluyor.
      final kiyma = state.pantry.firstWhere((p) => p.ingredientId == 'kiyma');
      state.updatePantryItem(kiyma.copyWith(
          expiresAt: DateTime.now().add(const Duration(days: 1))));
      await tester.pumpAndSettle();
      await r.capture(tester,
          title: 'Dolu dolap',
          action: 'Dolaba 9 malzeme ekledim.',
          result:
              '"Şu an yapabileceklerin" görselli kartlarla en üstte; kaç tarifin hazır '
              'olduğu yazıyor.');
      expect(find.text('Şu an yapabileceklerin'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Planla'), 250,
          scrollable: _mainScroll);
      await tester.pumpAndSettle();
      await r.capture(tester,
          title: 'Ekle ve Planla',
          action: 'Aşağı kaydırdım.',
          result:
              'Bozulacaklar tek satırda; ekleme yolları (malzeme, fiş-barkod, TikTok, '
              'dünden kalan) ve plan, mevsim, koleksiyonlar sade bir listede.');
      expect(find.text('Yakında bozulacaklar'), findsOneWidget);

      tester.state<ScrollableState>(_mainScroll).position.jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.textContaining('bu hafta'), findsNothing);
      await tester.scrollUntilVisible(
          find.text('Haftada kaç gün pişirirsin?'), 300,
          scrollable: _mainScroll);
      await tester.pumpAndSettle();
      await r.capture(tester,
          title: 'Kaç gün pişiriyorsun?',
          action: 'Alttaki hedef kartına geldim.',
          result: 'Seçmeden üstte sayı yok.');
      await r.tap(tester, find.text('5-6 gün'), '5-6 gün');
      await tester.pumpAndSettle();
      expect(state.weeklyGoal, 5);
      tester.state<ScrollableState>(_mainScroll).position.jumpTo(0);
      await tester.pumpAndSettle();
      await r.capture(tester,
          title: 'Haftalık hedef',
          action: '"5-6 gün"e dokundum, üste çıktım.',
          result: 'Üstte 0/5 bu hafta çıktı.');
      expect(find.text('0/5 bu hafta'), findsOneWidget);
    } finally {
      debugDisableShadows = true;
      r.writeHtml();
      r.writePrototypeJson(_screen);
    }
  });
}
