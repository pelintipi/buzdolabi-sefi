// Dolap kontrolü: bir haftadır dokunulmayan malzemeler "Hâlâ var / Azaldı /
// Bitti" ile hızlıca güncellenir.
//   flutter test test/dolap_kontrolu_test.dart
// Rapor: degisiklik_raporlari/2026-11-11_dolap-kontrolu/rapor.html

import 'package:buzdolabi_sefi/app.dart';
import 'package:buzdolabi_sefi/models/pantry_item.dart';
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

Future<AppState> _state() async {
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
      appliancesAsked: true));
  return s;
}

PantryItem _item(String id, String ing, int daysAgo,
        {double? quantity, ApproxLevel? level}) =>
    PantryItem(
      id: id,
      ingredientId: ing,
      quantity: quantity,
      level: level,
      addedAt: DateTime.now().subtract(Duration(days: daysAgo)),
      expiresAt: DateTime.now().add(const Duration(days: 30)),
    );

void main() {
  setUpAll(loadRealFonts);

  test('bir haftadır dokunulmayanlar listelenir; cevaplar dolabı günceller',
      () async {
    final s = await _state();
    s.restorePantry([
      _item('a', 'pirinc', 10, quantity: 1000),
      _item('b', 'un', 9, level: ApproxLevel.bol),
      _item('c', 'yumurta', 8, quantity: 6),
      _item('d', 'sut', 1, quantity: 1000), // yeni: sorulmaz
    ]);
    expect([for (final p in s.staleItems) p.id], ['a', 'b', 'c'],
        reason: 'en eskisi önce, yeni eklenen yok');

    s.confirmPantryItem('a');
    s.reducePantryItem('b');
    s.removePantryItem('c');
    expect(s.staleItems, isEmpty);
    expect(s.pantry.firstWhere((p) => p.id == 'b').level, ApproxLevel.biraz);
    expect(s.pantry.any((p) => p.id == 'c'), isFalse);

    // Kesin miktar "Azaldı" deyince yarıya iner.
    s.restorePantry([_item('e', 'pirinc', 10, quantity: 1000)]);
    s.reducePantryItem('e');
    expect(s.pantry.single.quantity, 500);
  });

  test('elle düzeltme ve pişirmede düşme de "kontrol edildi" sayılır',
      () async {
    final s = await _state();
    s.restorePantry([_item('a', 'yumurta', 10, quantity: 6)]);
    s.upsertPantry('yumurta', quantity: 4);
    expect(s.staleItems, isEmpty);

    s.restorePantry([_item('b', 'yumurta', 10, quantity: 6)]);
    final menemen = recipeCatalog.firstWhere((r) => r.id == 'menemen');
    s.recordCook(menemen, 1, {'yumurta': 110});
    expect(s.staleItems, isEmpty);
  });

  test('son kontrol tarihi kaydedilip geri okunur', () {
    final p = _item('a', 'un', 10, level: ApproxLevel.az)
        .copyWith(checkedAt: DateTime(2026, 11, 1));
    final back = PantryItem.fromJson(p.toJson());
    expect(back.checkedAt, DateTime(2026, 11, 1));
    expect(PantryItem.fromJson(_item('b', 'un', 1).toJson()).checkedAt, isNull);
  });

  testWidgets('Dolabım → kontrol kartı → Hâlâ var / Azaldı / Bitti → Geri al',
      (tester) async {
    tester.view.physicalSize = _screen * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final s = await _state();
    s.restorePantry([
      _item('a', 'pirinc', 12, quantity: 1000),
      _item('b', 'un', 9, level: ApproxLevel.bol),
      _item('c', 'yumurta', 8, quantity: 6),
      _item('d', 'sut', 1, quantity: 1000),
    ]);
    final r = ScreenshotReport('degisiklik_raporlari/2026-11-11_dolap-kontrolu',
        'Dolap kontrolü · Ekran testi');

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
      await r.tap(tester, find.text('Dolabım').last, 'Dolabım');
      await tester.pumpAndSettle();
      await r.capture(tester,
          title: 'Dolabım',
          action: 'Dolabım sekmesine geçtim.',
          result: 'En üstte "Dolabını kontrol et" kartı: 3 malzemeye bir '
              'haftadır bakılmamış (dün eklenen süt sorulmuyor).');
      expect(find.textContaining('3 malzemeye bir haftadır'), findsOneWidget);

      await r.tap(tester, find.text('Dolabını kontrol et'), 'Kontrol et');
      await tester.pumpAndSettle();
      await r.capture(tester,
          title: 'Dolap kontrolü',
          action: 'Karta dokundum.',
          result: 'Her malzeme için tek dokunuş: Hâlâ var / Azaldı / Bitti.');

      await r.tap(tester, find.text('Hâlâ var').first, 'Hâlâ var');
      await tester.pumpAndSettle();
      await r.tap(tester, find.text('Azaldı').first, 'Azaldı');
      await tester.pumpAndSettle();
      await r.tap(tester, find.text('Bitti').first, 'Bitti');
      await tester.pumpAndSettle();
      await r.capture(tester,
          title: 'Hepsi güncel',
          action: 'Pirinç: Hâlâ var, Un: Azaldı, Yumurta: Bitti dedim.',
          result: 'Cevaplananlar soluklaştı, un "Biraz" oldu, yumurta '
              'çıkarıldı; altta "Geri al" çıktı.');
      expect(find.textContaining('Hepsi güncel'), findsOneWidget);
      expect(s.pantry.any((p) => p.ingredientId == 'yumurta'), isFalse);

      await tester.tap(find.text('Geri al'));
      await tester.pumpAndSettle();
      expect(s.pantry.any((p) => p.ingredientId == 'yumurta'), isTrue,
          reason: 'Geri al yumurtayı geri getirir');
    } finally {
      debugDisableShadows = true;
      r.writeHtml();
      r.writePrototypeJson(_screen);
    }
  });
}
