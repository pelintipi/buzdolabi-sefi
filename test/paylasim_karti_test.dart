import 'package:buzdolabi_sefi/services/device_services.dart';
import 'package:buzdolabi_sefi/services/ingredient_repository.dart';
import 'package:buzdolabi_sefi/services/storage_service.dart';
import 'package:buzdolabi_sefi/state/app_state.dart';
import 'package:buzdolabi_sefi/widgets/share_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/test_catalog.dart';

void main() {
  testWidgets('hikâye kartında tarif, besin ve uygulama adı vardır',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState(
      repo: IngredientRepository(ingredientCatalog),
      recipes: recipeCatalog,
      storage: StorageService(),
    );
    await state.load();
    final recipe = state.recipeById('menemen');

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: state),
        Provider.value(value: DeviceServices(cameraAvailable: false)),
      ],
      child: MaterialApp(
        home: Scaffold(body: Center(child: ShareCard(recipe: recipe))),
      ),
    ));

    expect(find.text('Dolabımdan bu çıktı'), findsOneWidget);
    expect(find.text(recipe.title), findsOneWidget);
    expect(find.text('Buzdolabı Şefi'), findsOneWidget);
    expect(find.textContaining('App Store'), findsOneWidget);
    expect(find.textContaining('kcal'), findsOneWidget);
  });
}
