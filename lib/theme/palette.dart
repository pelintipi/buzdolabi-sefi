import 'package:flutter/material.dart';

/// "Sıcak mutfak" paleti: krem zemin, şeftali ve kum tonlu kartlar, koyu
/// orman yeşili butonlar. Domates ve bal tonları yalnızca durum bildirir
/// ("Yok", "Az", uyarılar). Adlar eski paletle aynı kaldı, tüm ekranlar
/// buradan beslenir.
abstract final class Palette {
  /// Ana renk: koyu orman yeşili (butonlar, seçili öğeler, "Var").
  static const basil = Color(0xFF1F3B2D);
  static const basilDeep = Color(0xFF13261C);
  static const basilSoft = Color(0xFFE3EBE1);

  /// Uyarı: kiremit ("Yok", bozulacaklar).
  static const tomato = Color(0xFFC9553A);
  static const tomatoDeep = Color(0xFFA2402A);
  static const tomatoSoft = Color(0xFFF8E7DC);

  /// Vurgu: bal ("Az", rozetler, en iyi değer).
  static const butter = Color(0xFFE5B65E);
  static const butterDeep = Color(0xFFB58A35);
  static const butterSoft = Color(0xFFF6EDDF);

  static const ink = Color(0xFF1D2520);
  static const inkSoft = Color(0xFF656B66);
  static const line = Color(0xFFEDE4DB);
  static const lineDeep = Color(0xFFDCCFC3);

  /// Sayfa zemini: sıcak krem.
  static const ground = Color(0xFFFBF7F3);

  /// Kart zemini: hafif sıcak beyaz.
  static const surface = Color(0xFFFFFCF9);

  /// Tasarımdaki kart tonları.
  static const peach = Color(0xFFF8EADF);
  static const sand = Color(0xFFF3EBE5);
  static const blush = Color(0xFFF2E9E6);
}

abstract final class Fonts {
  /// Başlıklar ve butonlar.
  static const display = 'PlusJakarta';

  /// Metinler.
  static const body = 'PlusJakarta';
}
