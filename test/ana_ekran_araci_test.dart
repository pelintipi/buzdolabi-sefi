// Ana ekran aracı: uygulamanın araca yazdığı veri ve araçtan gelen
// bağlantıların açtığı ekranlar.
//   flutter test test/ana_ekran_araci_test.dart

import 'package:buzdolabi_sefi/app.dart';
import 'package:buzdolabi_sefi/deep_links.dart';
import 'package:buzdolabi_sefi/screens/ingredient_input_screen.dart';
import 'package:buzdolabi_sefi/screens/pantry_screen.dart';
import 'package:buzdolabi_sefi/screens/results_screen.dart';
import 'package:buzdolabi_sefi/services/device_services.dart';
import 'package:buzdolabi_sefi/services/ingredient_repository.dart';
import 'package:buzdolabi_sefi/services/storage_service.dart';
import 'package:buzdolabi_sefi/state/app_state.dart';
import 'package:buzdolabi_sefi/state/digest.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/test_catalog.dart';

Future<AppState> _state({bool onboarded = true}) async {
  SharedPreferences.setMockInitialValues({});
  final s = AppState(
    repo: IngredientRepository(ingredientCatalog),
    recipes: recipeCatalog,
    storage: StorageService(),
  );
  await s.load();
  s.updateProfile(s.profile.copyWith(
      onboarded: onboarded,
      seenNavTour: true,
      allergyAsked: true,
      appliancesAsked: true));
  return s;
}

void _expireSoon(AppState s, String id, int days) {
  final item = s.pantry.firstWhere((p) => p.ingredientId == id);
  s.updatePantryItem(
      item.copyWith(expiresAt: DateTime.now().add(Duration(days: days))));
}

void main() {
  test('araç verisi: hazır tarifler, bozulacak sayısı ve değerlendirme önerisi',
      () async {
    final s = await _state();
    s.upsertPantryAll([
      (ingredientId: 'kiyma', quantity: 500, level: null),
      (ingredientId: 'pirinc', quantity: 1000, level: null),
      (ingredientId: 'ispanak', quantity: 400, level: null),
      (ingredientId: 'sogan', quantity: 4, level: null),
      (ingredientId: 'yumurta', quantity: 10, level: null),
    ]);
    _expireSoon(s, 'kiyma', 1);
    _expireSoon(s, 'ispanak', 2);

    final data = Digest(s, DateTime.now()).widgetData();
    expect(data['readyCount'], greaterThan(0));
    expect(data['expiringCount'], 2);
    final expiring = data['expiring'] as List;
    expect((expiring.first as Map)['name'], 'Kıyma',
        reason: 'en yakın tarihte bozulan önce');
    final useUp = data['useUp'] as Map;
    expect(useUp['ingredient'], 'Kıyma');
    final recipe = recipeCatalog.firstWhere((r) => r.title == useUp['title']);
    expect(recipe.items.any((i) => i.ingredientId == 'kiyma'), isTrue,
        reason: '${recipe.title} kıymayı değerlendirmeli');
  });

  test('bozulacak malzeme yoksa öneri ve sayı boş', () async {
    final s = await _state();
    s.upsertPantryAll([(ingredientId: 'yumurta', quantity: 6, level: null)]);
    final data = Digest(s, DateTime.now()).widgetData();
    expect(data['expiringCount'], 0);
    expect(data.containsKey('useUp'), isFalse);
  });

  test('bozulma bildiriminde tarif önerisi var', () async {
    final s = await _state();
    s.updateProfile(s.profile.copyWith(remindersOn: true));
    s.upsertPantryAll([
      (ingredientId: 'kiyma', quantity: 500, level: null),
      (ingredientId: 'pirinc', quantity: 1000, level: null),
      (ingredientId: 'sogan', quantity: 4, level: null),
    ]);
    final now = DateTime(2026, 11, 11, 12);
    final item = s.pantry.firstWhere((p) => p.ingredientId == 'kiyma');
    // 13'ünde bitiyor → uyarı 12'si sabah 10'da (yarın).
    s.updatePantryItem(item.copyWith(expiresAt: DateTime(2026, 11, 13)));

    final reminders = Digest(s, now).reminders();
    final warn =
        reminders.where((r) => r.title.contains('yarın bozuluyor')).toList();
    expect(warn, isNotEmpty);
    expect(warn.first.title, 'Kıyma yarın bozuluyor');
    expect(warn.first.body, contains('yapabilirsin'));
    final tipTitle = warn.first.body.split(': ').last;
    final tip = recipeCatalog.firstWhere((r) => r.title == tipTitle);
    expect(tip.items.any((i) => i.ingredientId == 'kiyma'), isTrue);
  });

  test('Siri metni var olana miktar ekler, bilinmeyeni döner', () async {
    final s = await _state();
    s.upsertPantry('yumurta', quantity: 2);
    expect(s.addPantryFromText('6 yumurta'), isEmpty);
    expect(s.pantry.singleWhere((p) => p.ingredientId == 'yumurta').quantity, 8);
    expect(s.addPantryFromText('3 xyzabc'), ['3 xyzabc']);
  });

  group('araçtan gelen bağlantılar', () {
    Future<void> pump(WidgetTester tester, AppState s) async {
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: s),
          Provider.value(value: DeviceServices(cameraAvailable: false)),
        ],
        child: const BuzdolabiSefiApp(),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('ne-pisirsem: dolap doluysa sonuçlar, boşsa malzeme girişi',
        (tester) async {
      final s = await _state();
      await pump(tester, s);
      await tester.binding.handlePushRoute(DeepLinks.whatToCook);
      await tester.pumpAndSettle();
      expect(find.byType(IngredientInputScreen), findsOneWidget,
          reason: 'dolap boş');

      Navigator.of(tester.element(find.byType(IngredientInputScreen))).pop();
      await tester.pumpAndSettle();
      s.upsertPantry('yumurta', quantity: 6);
      await tester.binding
          .handlePushRoute('buzdolabisefi://app${DeepLinks.whatToCook}');
      await tester.pumpAndSettle();
      expect(find.byType(ResultsScreen), findsOneWidget);
    });

    testWidgets('dolap bağlantısı Dolabım ekranını açar', (tester) async {
      final s = await _state();
      await pump(tester, s);
      await tester.binding.handlePushRoute(DeepLinks.pantry);
      await tester.pumpAndSettle();
      expect(find.byType(PantryScreen), findsWidgets);
      expect(find.byType(BackButton), findsOneWidget);
    });

    testWidgets('ekle bağlantısı malzemeyi dolaba ekler ve Dolabım açar',
        (tester) async {
      final s = await _state();
      s.upsertPantry('yumurta', quantity: 2);
      await pump(tester, s);
      await tester.binding
          .handlePushRoute('buzdolabisefi://app/ekle?metin=6%20yumurta');
      await tester.pumpAndSettle();
      expect(find.byType(PantryScreen), findsWidgets);
      final eggs =
          s.pantry.where((p) => p.ingredientId == 'yumurta').single;
      expect(eggs.quantity, 8, reason: 'var olan 2 + eklenen 6');
      expect(find.textContaining('Dolaba eklendi'), findsOneWidget);
    });

    testWidgets('bilinmeyen bağlantı hiçbir şey açmaz, çökmez', (tester) async {
      final s = await _state();
      await pump(tester, s);
      await tester.binding.handlePushRoute('/boyle-bir-ekran-yok');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(ResultsScreen), findsNothing);
    });

    testWidgets('anket bitmeden gelen bağlantı anketin önüne geçmez',
        (tester) async {
      final s = await _state(onboarded: false);
      await pump(tester, s);
      await tester.binding.handlePushRoute(DeepLinks.whatToCook);
      await tester.pumpAndSettle();
      expect(find.byType(IngredientInputScreen), findsNothing);
      expect(find.byType(ResultsScreen), findsNothing);
    });
  });
}
