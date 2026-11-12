// Ekrandaki her yazının, hemen arkasındaki zemine karşı okunur olup
// olmadığını tarar (iki temada). Açık temadayken koyuya geçilince açık
// sayfaların eski renkte kalmaması da denenir.
//   flutter test test/belirginlik_test.dart
// Rapor: degisiklik_raporlari/2026-11-12_belirginlik/rapor.html

import 'package:buzdolabi_sefi/app.dart';
import 'package:buzdolabi_sefi/models/user_profile.dart';
import 'package:buzdolabi_sefi/screens/cooking_mode_screen.dart';
import 'package:buzdolabi_sefi/services/device_services.dart';
import 'package:buzdolabi_sefi/services/ingredient_repository.dart';
import 'package:buzdolabi_sefi/services/storage_service.dart';
import 'package:buzdolabi_sefi/state/app_state.dart';
import 'package:buzdolabi_sefi/theme/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/screenshot_report.dart';
import 'support/test_catalog.dart';

const _screen = Size(393, 852);

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

Color? _spanColor(InlineSpan span) {
  Color? found;
  span.visitChildren((s) {
    final c = s.style?.color;
    if (c != null) {
      found = c;
      return false;
    }
    return true;
  });
  return found;
}

/// Yazının hemen arkasındaki opak zemin.
Color _backgroundOf(RenderObject node) {
  RenderObject? p = node.parent;
  while (p != null) {
    Color? c;
    if (p is RenderDecoratedBox) {
      final d = p.decoration;
      if (d is BoxDecoration) c = d.color;
    } else if (p is RenderPhysicalShape) {
      c = p.color;
    } else if (p is RenderPhysicalModel) {
      c = p.color;
    }
    if (c != null && c.a > 0.85) return c;
    p = p.parent;
  }
  return Palette.ground;
}

/// Görünen, okunması zor yazılar: "yazı (oran)".
List<String> _faint(WidgetTester tester) {
  final bad = <String>[];
  void visit(RenderObject o) {
    if (o is RenderParagraph && o.hasSize && o.attached) {
      final text = o.text.toPlainText().trim();
      final color = _spanColor(o.text);
      // Bilerek soluk (pasif) bırakılan yazılar ve emojiler atlanır.
      if (text.length > 1 && color != null && color.a > 0.9) {
        final bg = _backgroundOf(o);
        final ratio = _contrast(color.withValues(alpha: 1), bg);
        if (ratio < 3) bad.add('"$text" (${ratio.toStringAsFixed(1)})');
      }
    }
    o.visitChildren(visit);
  }

  visit(tester.binding.renderViews.first);
  return bad;
}

void main() {
  setUpAll(loadRealFonts);

  testWidgets('iki temada da her yazı belirgin; tema değişince sayfa güncel',
      (tester) async {
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
        uiTheme: UiTheme.light));
    s.upsertPantryAll([
      (ingredientId: 'tavuk_gogsu', quantity: 180, level: null),
      (ingredientId: 'pirinc', quantity: 940, level: null),
      (ingredientId: 'domates', quantity: 4, level: null),
    ]);
    final r = ScreenshotReport('degisiklik_raporlari/2026-11-12_belirginlik',
        'Belirginlik · koyu ve açık tema');
    final problems = <String>[];

    Future<void> check(String where) async {
      await tester.pumpAndSettle();
      final bad = _faint(tester);
      await r.capture(tester,
          title: where,
          action: '',
          result: bad.isEmpty ? 'Hepsi okunur' : 'Soluk: ${bad.join(', ')}');
      problems.addAll(bad.map((b) => '$where: $b'));
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
          child: const BuzdolabiSefiApp(),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Dolabım').last);
      await check('Dolabım · açık');

      // Sayfa açıkken koyuya geçiş (telefondaki durum).
      s.updateProfile(s.profile.copyWith(uiTheme: UiTheme.dark));
      await check('Dolabım · koyuya geçince');

      for (final tab in ['Ana sayfa', 'Sosyal', 'Liste', 'Profil']) {
        await tester.tap(find.text(tab).last);
        await check('$tab · koyu');
      }

      Navigator.of(tester.element(find.text('Profil').last)).push(
          MaterialPageRoute<void>(
              builder: (_) => const CookingModeScreen(
                  recipeId: 'menemen', servings: 2, initialStep: 3)));
      await check('Pişirme modu · koyu');
      Navigator.of(tester.element(find.text('Sonraki').last)).pop();
      await tester.pumpAndSettle();

      s.updateProfile(s.profile.copyWith(uiTheme: UiTheme.light));
      for (final tab in ['Ana sayfa', 'Dolabım', 'Profil']) {
        await tester.tap(find.text(tab).last);
        await check('$tab · açık');
      }
    } finally {
      debugDisableShadows = true;
      r.writeHtml();
      r.writePrototypeJson(_screen);
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });
}
