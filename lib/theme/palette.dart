import 'package:flutter/material.dart';

/// Açık / koyu yapısal renkler. Vurgu renkleri (basil/tomato/butter) sabit.
class BrandColors {
  const BrandColors({
    required this.ink,
    required this.inkSoft,
    required this.line,
    required this.lineDeep,
    required this.ground,
    required this.surface,
    required this.sand,
    required this.basilSoft,
    required this.tomatoSoft,
    required this.butterSoft,
    required this.accent,
    required this.accentDeep,
    required this.tomatoText,
    required this.butterText,
  });

  final Color ink;
  final Color inkSoft;
  final Color line;
  final Color lineDeep;
  final Color ground;
  final Color surface;
  final Color sand;
  final Color basilSoft;
  final Color tomatoSoft;
  final Color butterSoft;

  /// Metin / ikon yeşili (koyu temada açık nane; dolgu rengi [Palette.basil] kalır).
  final Color accent;
  final Color accentDeep;

  /// Kiremit ve hardal yazı (rozet, uyarı). Koyu temada açık ton.
  final Color tomatoText;
  final Color butterText;

  static const light = BrandColors(
    ink: Color(0xFF1A1A17),
    inkSoft: Color(0xFF6E6C66),
    line: Color(0xFFE9E5DE),
    lineDeep: Color(0xFFD8D2C8),
    ground: Color(0xFFF8F6F2),
    surface: Color(0xFFFFFFFF),
    sand: Color(0xFFF1EEE8),
    basilSoft: Color(0xFFE9EEE7),
    tomatoSoft: Color(0xFFF6ECE6),
    butterSoft: Color(0xFFF6F0E3),
    accent: Color(0xFF1F3B2D),
    accentDeep: Color(0xFF13261C),
    tomatoText: Color(0xFF8F3E21),
    butterText: Color(0xFF7A5A16),
  );

  static const dark = BrandColors(
    ink: Color(0xFFF2F0EB),
    inkSoft: Color(0xFFA8A59C),
    line: Color(0xFF2E322E),
    lineDeep: Color(0xFF3D423D),
    ground: Color(0xFF121411),
    surface: Color(0xFF1C1F1C),
    sand: Color(0xFF252825),
    basilSoft: Color(0xFF243D32),
    tomatoSoft: Color(0xFF2A1C18),
    butterSoft: Color(0xFF2A2418),
    accent: Color(0xFF9ED4AE),
    accentDeep: Color(0xFFB6E3C4),
    tomatoText: Color(0xFFF0A88C),
    butterText: Color(0xFFE6C47A),
  );

  static BrandColors forBrightness(Brightness b) =>
      b == Brightness.dark ? dark : light;
}

/// Sakin, "yemek dergisi" paleti. Yapısal renkler tema parlaklığına göre
/// değişir; [Palette.apply] MaterialApp builder'da çağrılır.
abstract final class Palette {
  static BrandColors _c = BrandColors.light;

  static void apply(Brightness brightness) {
    _c = BrandColors.forBrightness(brightness);
  }

  /// Ana renk: koyu orman yeşili (dolu buton zemini; koyu temada da dolgu).
  static const basil = Color(0xFF1F3B2D);
  static const basilDeep = Color(0xFF13261C);
  static Color get basilSoft => _c.basilSoft;

  /// Zemin üstü yeşil metin/ikon (koyu temada açık; soft buton, nav, link).
  static Color get accent => _c.accent;
  static Color get accentDeep => _c.accentDeep;

  /// Vurgu ve uyarı: kiremit ("Yok", bozulacaklar, tek vurgu öğesi).
  static const tomato = Color(0xFFB4532F);
  static const tomatoDeep = Color(0xFF8F3E21);
  static Color get tomatoSoft => _c.tomatoSoft;

  /// Zemin ya da soft rozet üstünde kiremit yazı (koyu temada açık).
  static Color get tomatoText => _c.tomatoText;

  /// Durum: aşı boyası ("Az", en iyi değer).
  static const butter = Color(0xFFC99A3C);
  static const butterDeep = Color(0xFF946E22);
  static Color get butterSoft => _c.butterSoft;

  /// Zemin ya da soft rozet üstünde hardal yazı (koyu temada açık).
  static Color get butterText => _c.butterText;

  static Color get ink => _c.ink;
  static Color get inkSoft => _c.inkSoft;
  static Color get line => _c.line;
  static Color get lineDeep => _c.lineDeep;

  /// Sayfa zemini.
  static Color get ground => _c.ground;

  /// Kart zemini.
  static Color get surface => _c.surface;

  /// Nötr dolgu (simge zemini, etiketler, ikincil butonlar).
  static Color get sand => _c.sand;

  /// Eski adlar: artık renkli blok yok, hepsi nötr.
  static Color get peach => sand;
  static Color get blush => sand;
}

abstract final class Fonts {
  /// Büyük başlıklar: zarif serif (tek ağırlık).
  static const serif = 'InstrumentSerif';

  /// Başlıklar, butonlar.
  static const display = 'PlusJakarta';

  /// Metinler.
  static const body = 'PlusJakarta';
}
