import '../models/ingredient.dart';
import '../models/measure.dart';

/// Bütün karşılaştırmalar gram üzerinden yapılır; her malzemenin yoğunluğu
/// ve adet ağırlığı kullanılarak bardak, kaşık ve adet grama çevrilir.
class UnitConverter {
  UnitConverter._();

  static double toGrams(Ingredient ing, double amount, Measure m) {
    final ml = m.mlFactor;
    if (ml != null) return amount * ml * ing.density;
    final g = m.gramFactor;
    if (g != null) return amount * g;
    if (m.isCount) return amount * ing.pieceGrams;
    // Measure.paket
    return baseToGrams(ing, amount * ing.packageAmount);
  }

  static double baseToGrams(Ingredient ing, double base) =>
      switch (ing.baseUnit) {
        BaseUnit.gram => base,
        BaseUnit.ml => base * ing.density,
        BaseUnit.piece => base * ing.pieceGrams,
      };

  static double gramsToBase(Ingredient ing, double grams) =>
      switch (ing.baseUnit) {
        BaseUnit.gram => grams,
        BaseUnit.ml => grams / ing.density,
        BaseUnit.piece => grams / ing.pieceGrams,
      };
}
