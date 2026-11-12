import 'package:buzdolabi_sefi/services/price_index.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => PriceIndex.now = DateTime.now);

  test('liste ayında çarpan 1, bir yıl sonra ~%31 artar', () {
    PriceIndex.now = () => DateTime(2026, 11, 20);
    expect(PriceIndex.factor(), 1);
    PriceIndex.now = () => DateTime(2027, 11, 1);
    expect(PriceIndex.factor(), closeTo(1.31, 0.01));
  });
}
