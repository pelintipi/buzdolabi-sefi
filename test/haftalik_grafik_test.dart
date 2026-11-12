// İlerleme: son 7 gün grafiği kalori, protein ve lif için.
//   flutter test test/haftalik_grafik_test.dart
// Rapor: degisiklik_raporlari/2026-11-12_haftalik-grafik/rapor.html

import 'package:buzdolabi_sefi/models/cook_log.dart';
import 'package:buzdolabi_sefi/screens/progress_screen.dart';
import 'package:buzdolabi_sefi/services/device_services.dart';
import 'package:buzdolabi_sefi/services/ingredient_repository.dart';
import 'package:buzdolabi_sefi/services/storage_service.dart';
import 'package:buzdolabi_sefi/state/app_state.dart';
import 'package:buzdolabi_sefi/theme/app_theme.dart';
import 'package:buzdolabi_sefi/theme/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/screenshot_report.dart';
import 'support/test_catalog.dart';

const _screen = Size(393, 852);

void main() {
  setUpAll(loadRealFonts);

  testWidgets('İlerleme: Kalori / Protein / Lif grafiği', (tester) async {
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
    s.updateProfile(s.profile.copyWith(onboarded: true, seenNavTour: true));
    // Son günlere farklı yemekler: kuru fasulye lifli, omlet proteinli.
    final now = DateTime.now();
    for (final (daysAgo, id) in const [
      (0, 'kuru_fasulye'),
      (0, 'peynirli_omlet'),
      (1, 'menemen'),
      (2, 'nohut_yemegi'),
      (4, 'tavuk_sote'),
    ]) {
      final r = recipeCatalog.firstWhere((x) => x.id == id);
      s.recordCook(r, 1, const {});
      s.updateLog(
          s.logs.last.cookedAt,
          (l) => CookLog.fromJson({
                ...l.toJson(),
                'cookedAt':
                    now.subtract(Duration(days: daysAgo)).toIso8601String(),
              }));
    }
    final r = ScreenshotReport(
        'degisiklik_raporlari/2026-11-12_haftalik-grafik',
        'Haftalık grafik · Ekran testi');

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
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: buildAppTheme(Brightness.light),
              builder: (context, child) {
                Palette.apply(Theme.of(context).brightness);
                return child!;
              },
              home: const ProgressScreen(),
            );
          }),
        ),
      ));
      await tester.pumpAndSettle();
      await r.capture(tester,
          title: 'Kalori',
          action: 'İlerleme ekranını açtım.',
          result: 'Grafikte kalori; kesikli çizgi günlük hedef.');
      expect(find.textContaining('günlük hedefin (2000 kcal)'), findsOneWidget);

      await r.tap(tester, find.text('Protein'), 'Protein');
      await tester.pumpAndSettle();
      await r.capture(tester,
          title: 'Protein',
          action: '"Protein"e dokundum.',
          result: 'Aynı grafik protein için, protein çubuğunun renginde.');
      expect(find.textContaining('günlük hedefin (50 g)'), findsOneWidget);

      await r.tap(tester, find.text('Lif'), 'Lif');
      await tester.pumpAndSettle();
      await r.capture(tester,
          title: 'Lif',
          action: '"Lif"e dokundum.',
          result: 'Lif günlük; kuru fasulyeli gün hedefe yaklaşıyor.');
      expect(find.textContaining('günlük hedefin (25 g)'), findsOneWidget);
    } finally {
      debugDisableShadows = true;
      r.writeHtml();
      r.writePrototypeJson(_screen);
    }
  });
}
