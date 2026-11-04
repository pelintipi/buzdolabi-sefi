import 'package:buzdolabi_sefi/models/measure.dart';
import 'package:buzdolabi_sefi/models/pantry_item.dart';
import 'package:buzdolabi_sefi/services/ingredient_repository.dart';
import 'package:buzdolabi_sefi/services/quantity_parser.dart';
import 'package:buzdolabi_sefi/services/unit_converter.dart';
import 'package:buzdolabi_sefi/utils/format.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_catalog.dart';

void main() {
  final repo = IngredientRepository(ingredientCatalog);
  final parser = QuantityParser(repo);

  test('virgülle ayrılmış cümleyi miktarlarıyla ayırır', () {
    final e = parser.parse('2 yumurta, yarım biber, 1 kase yoğurt');
    expect(e, hasLength(3));
    expect(e[0].ingredient!.id, 'yumurta');
    expect(e[0].quantity, 2);
    expect(e[1].ingredient!.id, 'biber');
    expect(e[1].quantity, 0.5);
    expect(e[2].ingredient!.id, 'yogurt');
    expect(e[2].quantity, closeTo(262.5, 0.01)); // 250 ml × 1,05 g/ml
  });

  test('gram ve ondalık virgül', () {
    expect(parser.parseChunk('500 gr kıyma').quantity, 500);
    final sut = parser.parse('1,5 su bardağı süt');
    expect(sut, hasLength(1));
    expect(sut.single.ingredient!.id, 'sut');
    expect(sut.single.quantity, closeTo(300, 0.01));
  });

  test('"ve" ile ayırma ve "bi tutam"', () {
    final e = parser.parse('bi tutam tuz ve 3 domates');
    expect(e.map((x) => x.ingredient?.id), ['tuz', 'domates']);
    expect(e[0].quantity, closeTo(0.5, 0.001));
  });

  test('miktar kelimeleri yaklaşık seviyeye dönüşür', () {
    final e = parser.parseChunk('biraz peynir');
    expect(e.ingredient!.id, 'peynir');
    expect(e.quantity, isNull);
    expect(e.level, ApproxLevel.biraz);
  });

  test('Türkçe ekler ve Türkçe karaktersiz yazım', () {
    expect(repo.findByName('domatesler')?.id, 'domates');
    expect(repo.findByName('ekmeği')?.id, 'ekmek');
    expect(repo.findByName('sogan')?.id, 'sogan');
    expect(repo.findByName('beyaz peynirler')?.id, 'beyaz_peynir');
    expect(repo.findByName('KIYMA')?.id, 'kiyma');
    expect(repo.findByName('İspanak')?.id, 'ispanak');
  });

  test('tanınmayan malzeme işaretlenir', () {
    final e = parser.parseChunk('uçan halı');
    expect(e.ingredient, isNull);
  });

  test('otomatik tamamlama baştan eşleşeni öne alır', () {
    final r = repo.search('yum');
    expect(r.first.id, 'yumurta');
  });

  test('birim dönüşümü', () {
    final pirinc = repo.byId('pirinc');
    expect(UnitConverter.toGrams(pirinc, 1, Measure.suBardagi),
        closeTo(170, 0.01));
    final yumurta = repo.byId('yumurta');
    expect(UnitConverter.toGrams(yumurta, 2, Measure.adet), 110);
  });

  test('akıllı yuvarlama', () {
    expect(formatMeasureAmount(1.5, Measure.adet), '1½ adet');
    expect(formatMeasureAmount(0.5, Measure.suBardagi), '½ su bardağı');
    expect(formatMeasureAmount(333, Measure.gram), '330 g');
    expect(halfPieceHint(1.5, Measure.adet), '1 büyük ya da 2 küçük');
  });
}
