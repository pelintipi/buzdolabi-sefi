import 'package:buzdolabi_sefi/app.dart';
import 'package:buzdolabi_sefi/data/catalog.dart';
import 'package:buzdolabi_sefi/services/ingredient_repository.dart';
import 'package:buzdolabi_sefi/services/storage_service.dart';
import 'package:buzdolabi_sefi/state/app_state.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/test_catalog.dart';

void main() {
  testWidgets('katalog uygulama paketinden okunur (pubspec assets)',
      (tester) async {
    final catalog = await tester.runAsync(() => Catalog.load(rootBundle));
    expect(catalog!.problems, isEmpty);
    expect(catalog.recipes, hasLength(recipeCatalog.length));
    expect(catalog.ingredients, hasLength(ingredientCatalog.length));
  });

  testWidgets('boş dolapta "Ne pişirsem?" malzeme girişine götürür',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState(
      repo: IngredientRepository(ingredientCatalog),
      recipes: recipeCatalog,
      storage: StorageService(),
    );
    await state.load();
    // Açılış anketini daha önce doldurmuş kullanıcı (anket: anket_akisi_test).
    state.updateProfile(state.profile.copyWith(onboarded: true));

    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: state,
      child: const BuzdolabiSefiApp(),
    ));

    expect(find.text('Ne pişirsem?'), findsOneWidget);
    await tester.tap(find.text('Ne pişirsem?'));
    await tester.pumpAndSettle();
    expect(find.text('Dolabında ne var?'), findsOneWidget);
  });
}
