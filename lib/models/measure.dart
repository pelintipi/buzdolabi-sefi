/// Tariflerde ve malzeme girişinde kullanılan ölçü birimleri.
enum Measure {
  gram('g'),
  kilogram('kg'),
  ml('ml'),
  litre('L'),
  adet('adet'),
  suBardagi('su bardağı'),
  cayBardagi('çay bardağı'),
  yemekKasigi('yemek kaşığı'),
  tatliKasigi('tatlı kaşığı'),
  cayKasigi('çay kaşığı'),
  kase('kase'),
  tutam('tutam'),
  paket('paket'),
  dis('diş'),
  demet('demet'),
  dilim('dilim');

  const Measure(this.label);

  final String label;

  /// Hacim ölçüsüyse ml karşılığı.
  double? get mlFactor => switch (this) {
        Measure.ml => 1.0,
        Measure.litre => 1000.0,
        Measure.suBardagi => 200.0,
        Measure.cayBardagi => 100.0,
        Measure.yemekKasigi => 15.0,
        Measure.tatliKasigi => 10.0,
        Measure.cayKasigi => 5.0,
        Measure.kase => 250.0,
        _ => null,
      };

  /// Ağırlık ölçüsüyse gram karşılığı.
  double? get gramFactor => switch (this) {
        Measure.gram => 1.0,
        Measure.kilogram => 1000.0,
        Measure.tutam => 0.5,
        Measure.dilim => 25.0,
        _ => null,
      };

  /// Adetle sayılan ölçüler (malzemenin kendi adet ağırlığı kullanılır).
  bool get isCount =>
      this == Measure.adet || this == Measure.dis || this == Measure.demet;
}
