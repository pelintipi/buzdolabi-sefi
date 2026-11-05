import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import '../models/recipe.dart';
import '../services/collections.dart';
import 'ui.dart';

/// Tarif fotoğrafları: `assets/photos/<tarif kimliği>.jpg` (ya da .png/.webp).
/// Uygulama açılırken hangi fotoğrafların olduğu bir kez okunur; fotoğrafı
/// olmayan tarifte sakin bir yer tutucu çizilir. Fotoğraf eklemek için dosyayı
/// klasöre koymak yeterli.
abstract final class RecipePhotos {
  static Map<String, String> _byId = const {};

  static Future<void> init([AssetBundle? bundle]) async {
    try {
      final manifest =
          await AssetManifest.loadFromAssetBundle(bundle ?? rootBundle);
      final out = <String, String>{};
      for (final path in manifest.listAssets()) {
        final m = RegExp(r'^assets/photos/([a-z0-9_]+)\.(jpe?g|png|webp)$')
            .firstMatch(path);
        if (m != null) out[m.group(1)!] = path;
      }
      _byId = out;
    } catch (_) {
      _byId = const {};
    }
  }

  static String? pathFor(String recipeId) => _byId[recipeId];
}

/// Yemek türüne göre yer tutucu tonları (fotoğraf yokken).
Color _tint(RecipeCategory c) => switch (c) {
      RecipeCategory.kahvalti => const Color(0xFFF3EEDF),
      RecipeCategory.corba => const Color(0xFFF2E8DE),
      RecipeCategory.anaYemek => const Color(0xFFEEEAE2),
      RecipeCategory.salata => const Color(0xFFE8EEE4),
      RecipeCategory.atistirmalik => const Color(0xFFF1EBE1),
      RecipeCategory.tatli => const Color(0xFFF2E8E7),
    };

/// Fotoğraf yokken türün ince çizgi ikonu (3D emoji yerine; tutarlı ve sade).
IconData _iconFor(RecipeCategory c) => switch (c) {
      RecipeCategory.kahvalti => Icons.egg_alt_outlined,
      RecipeCategory.corba => Icons.soup_kitchen_outlined,
      RecipeCategory.anaYemek => Icons.dinner_dining_outlined,
      RecipeCategory.salata => Icons.eco_outlined,
      RecipeCategory.atistirmalik => Icons.bakery_dining_outlined,
      RecipeCategory.tatli => Icons.cake_outlined,
    };

/// Tarifin görseli: fotoğrafı varsa fotoğraf, yoksa türüne göre tonlu zemin
/// üzerinde yemeğin 3D ikonu (ikonu yoksa türün çizgi ikonu).
class RecipeImage extends StatelessWidget {
  const RecipeImage(this.recipe,
      {super.key, this.width = 72, this.height, this.radius = 18});

  final Recipe recipe;
  final double width;

  /// Verilmezse kare.
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final h = height ?? width;
    final photo = RecipePhotos.pathFor(recipe.id);
    final shortest = width < h ? width : h;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: h,
        child: photo != null
            ? Image.asset(photo, fit: BoxFit.cover)
            : DecoratedBox(
                decoration: BoxDecoration(color: _tint(categoryOf(recipe))),
                child: Center(
                  child: iconAssetFor(recipe.emoji) != null
                      ? FoodIcon(recipe.emoji, size: shortest * 0.62)
                      : Icon(_iconFor(categoryOf(recipe)),
                          size: shortest * 0.34,
                          color: const Color(0x591A1A17)),
                ),
              ),
      ),
    );
  }
}
