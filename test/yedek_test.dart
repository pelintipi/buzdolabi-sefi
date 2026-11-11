// Yedek: dosyaya al, geri yükle; bozuk dosya veriyi bozmaz.
//   flutter test test/yedek_test.dart
// Rapor: degisiklik_raporlari/2026-11-11_yedek/rapor.html

import 'dart:convert';

import 'package:buzdolabi_sefi/app.dart';
import 'package:buzdolabi_sefi/services/device_services.dart';
import 'package:buzdolabi_sefi/services/ingredient_repository.dart';
import 'package:buzdolabi_sefi/services/storage_service.dart';
import 'package:buzdolabi_sefi/state/app_state.dart';
import 'package:buzdolabi_sefi/widgets/backup_card.dart';
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

/// Paylaşım menüsü yerine dosyayı hafızada tutar; seçilecek dosyayı verir.
class _FakeShare extends ShareService {
  String? sharedName;
  String? sharedContent;
  String? toPick;

  @override
  Future<bool> shareTextFile(String name, String content) async {
    sharedName = name;
    sharedContent = content;
    return true;
  }

  @override
  Future<String?> pickTextFile() async => toPick;
}

void main() {
  setUpAll(loadRealFonts);

  test('yedek alınıp yeni telefona geri yüklenince her şey gelir', () async {
    final a = await _state();
    a.upsertPantry('yumurta', quantity: 6);
    a.toggleFavorite('menemen');
    a.addToShopping(['sut']);
    a.updateProfile(a.profile.copyWith(customAllergies: ['ceviz']));
    final menemen = recipeCatalog.firstWhere((r) => r.id == 'menemen');
    a.recordCook(menemen, 2, const {}, rating: 5, note: 'Az tuz');
    final file = a.exportBackup();
    expect(a.lastBackupAt, isNotNull);
    expect(jsonDecode(file)['app'], 'buzdolabi-sefi');

    // "Yeni telefon": boş uygulama.
    final b = await _state();
    expect(b.pantry, isEmpty);
    b.importBackup(file);
    expect(b.pantry.single.ingredientId, 'yumurta');
    expect(b.isFavorite('menemen'), isTrue);
    expect(b.shoppingList, ['sut']);
    expect(b.profile.customAllergies, ['ceviz']);
    expect(b.lastCookMemory('menemen')?.note, 'Az tuz');
  });

  test('bozuk ya da yabancı dosya mevcut veriye dokunmaz', () async {
    final s = await _state();
    s.upsertPantry('yumurta', quantity: 6);
    for (final bad in [
      'merhaba',
      '{"app":"baska-uygulama","backupVersion":1,"data":{}}',
      '{"app":"buzdolabi-sefi","backupVersion":99,"data":{}}',
      '{"app":"buzdolabi-sefi","backupVersion":1,"data":{"pantry":"bozuk"}}',
    ]) {
      expect(() => s.importBackup(bad), throwsFormatException, reason: bad);
      expect(s.pantry.single.ingredientId, 'yumurta', reason: bad);
    }
  });

  test('son yedek yazısı', () {
    final now = DateTime(2026, 11, 11, 12);
    expect(BackupCard.lastBackupText(null, now), 'Hiç yedek almadın.');
    expect(BackupCard.lastBackupText(DateTime(2026, 11, 11, 8), now),
        'Son yedek: bugün.');
    expect(BackupCard.lastBackupText(DateTime(2026, 11, 1), now),
        'Son yedek: 10 gün önce.');
    expect(BackupCard.isStale(DateTime(2026, 10, 1), now), isTrue);
    expect(BackupCard.fileName(now), 'buzdolabi-sefi-yedek-2026-11-11.json');
  });

  testWidgets('Profil → Yedek: kaydet ve geri yükle', (tester) async {
    tester.view.physicalSize = _screen * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final s = await _state();
    s.upsertPantry('yumurta', quantity: 6);
    final share = _FakeShare();
    final r = ScreenshotReport(
        'degisiklik_raporlari/2026-11-11_yedek', 'Yedek · Ekran testi');
    final scroll = find
        .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down)
        .first;

    debugDisableShadows = false;
    try {
      await tester.pumpWidget(RepaintBoundary(
        key: screenshotKey,
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: s),
            Provider.value(
                value: DeviceServices(cameraAvailable: false, share: share)),
          ],
          child: const BuzdolabiSefiApp(),
        ),
      ));
      await tester.pumpAndSettle();
      await r.tap(tester, find.text('Profil').last, 'Profil');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Yedekten geri yükle'), 300,
          scrollable: scroll);
      await tester.pumpAndSettle();
      await r.capture(tester,
          title: 'Yedek kartı',
          action: 'Profil\'in altına indim.',
          result: 'Verilerin yalnızca telefonda olduğu ve silinince '
              'kaybolacağı açıkça yazıyor; "Hiç yedek almadın" uyarısı.');
      expect(find.text('Hiç yedek almadın.'), findsOneWidget);

      await r.tap(tester, find.text('Yedeği kaydet'), 'Yedeği kaydet');
      await tester.pumpAndSettle();
      expect(share.sharedName, startsWith('buzdolabi-sefi-yedek-'));
      expect(find.text('Son yedek: bugün.'), findsOneWidget);
      await r.capture(tester,
          title: 'Yedek alındı',
          action: '"Yedeği kaydet"e bastım (paylaşım menüsü açılır).',
          result: '"Son yedek: bugün" oldu.');

      // Dolabı boşalt, sonra yedekten geri getir.
      s.removePantryItem(s.pantry.single.id);
      share.toPick = share.sharedContent;
      await tester.ensureVisible(find.text('Yedekten geri yükle'));
      await r.tap(tester, find.text('Yedekten geri yükle'), 'Geri yükle');
      await tester.pumpAndSettle();
      await r.capture(tester,
          title: 'Onay',
          action: '"Yedekten geri yükle"ye bastım.',
          result: 'Bu telefondaki verilerin yerine geçeceği soruluyor.');
      await r.tap(tester, find.text('Dosya seç'), 'Dosya seç');
      await tester.pumpAndSettle();
      expect(s.pantry.single.ingredientId, 'yumurta');
      expect(find.textContaining('Yedek geri yüklendi'), findsOneWidget);
    } finally {
      debugDisableShadows = true;
      r.writeHtml();
      r.writePrototypeJson(_screen);
    }
  });
}
