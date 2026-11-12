// Hikâye kartı koyu temada da okunur ve "Hikâyede paylaş" gerçekten PNG üretip
// paylaşım servisine verir.
import 'dart:io';
import 'dart:typed_data';

import 'package:buzdolabi_sefi/models/user_profile.dart';
import 'package:buzdolabi_sefi/services/device_services.dart';
import 'package:buzdolabi_sefi/services/ingredient_repository.dart';
import 'package:buzdolabi_sefi/services/storage_service.dart';
import 'package:buzdolabi_sefi/state/app_state.dart';
import 'package:buzdolabi_sefi/theme/app_theme.dart';
import 'package:buzdolabi_sefi/theme/palette.dart';
import 'package:buzdolabi_sefi/widgets/share_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/screenshot_report.dart';
import 'support/test_catalog.dart';

class _FakeShare extends ShareService {
  Uint8List? got;
  @override
  Future<bool> shareImage(Uint8List png, {String? text}) async {
    got = png;
    return true;
  }
}

void main() {
  setUpAll(loadRealFonts);

  testWidgets('hikâye kartı: koyu temada okunur, paylaş PNG üretir',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final state = AppState(
      repo: IngredientRepository(ingredientCatalog),
      recipes: recipeCatalog,
      storage: StorageService(),
    );
    await state.load();
    state.updateProfile(state.profile.copyWith(uiTheme: UiTheme.dark));
    Palette.apply(Brightness.dark);
    final recipe = state.recipeById('menemen');
    final share = _FakeShare();

    final r = ScreenshotReport(
        'degisiklik_raporlari/2026-11-12_hikaye_karti', 'Hikâye kartı');
    debugDisableShadows = false;
    try {
      await tester.pumpWidget(RepaintBoundary(
        key: screenshotKey,
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: state),
            Provider.value(
                value: DeviceServices(cameraAvailable: false, share: share)),
          ],
          child: MaterialApp(
            theme: buildAppTheme(Brightness.dark),
            home: Builder(
              builder: (c) => Scaffold(
                body: Center(
                  child: TextButton(
                      onPressed: () => showShareCard(c, recipe),
                      child: const Text('aç')),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();
      await r.capture(tester, title: 'Kart (koyu)', action: '', result: '');

      // Rozet yazıları beyaz zemin üstünde koyu olmalı.
      final kcal = tester.widget<Text>(find.textContaining('kcal'));
      expect(kcal.style!.color!.computeLuminance(), lessThan(0.1));

      await tester.runAsync(() async {
        await tester.tap(find.text('Hikâyede paylaş'));
        for (var i = 0; i < 50 && share.got == null; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        }
      });
      expect(share.got, isNotNull);
      expect(share.got!.sublist(1, 4), 'PNG'.codeUnits);
      File('degisiklik_raporlari/2026-11-12_hikaye_karti/paylasilan.png')
          .writeAsBytesSync(share.got!);
    } finally {
      debugDisableShadows = true;
      r.writeHtml();
    }
  });
}
