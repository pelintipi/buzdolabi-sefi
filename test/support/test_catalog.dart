import 'dart:io';

import 'package:buzdolabi_sefi/data/catalog.dart';

/// Testler uygulamanın kullandığı aynı JSON dosyalarını okur.
final testCatalog = Catalog.parse(
  File(Catalog.ingredientsAsset).readAsStringSync(),
  File(Catalog.recipesAsset).readAsStringSync(),
);

final ingredientCatalog = testCatalog.ingredients;
final recipeCatalog = testCatalog.recipes;
