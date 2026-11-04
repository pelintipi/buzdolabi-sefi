import 'package:flutter/material.dart';

/// Sakin, "yemek dergisi" paleti: kâğıt beyazı zemin, ince çizgili beyaz
/// kartlar, koyu orman yeşili ana renk ve az miktarda kiremit vurgu.
/// Renkli bloklar yerine boşluk ve tipografiyle hiyerarşi kurulur.
/// (Adlar eski paletle aynı kaldı; tüm ekranlar buradan beslenir.)
abstract final class Palette {
  /// Ana renk: koyu orman yeşili (butonlar, seçili öğeler, "Var").
  static const basil = Color(0xFF1F3B2D);
  static const basilDeep = Color(0xFF13261C);
  static const basilSoft = Color(0xFFE9EEE7);

  /// Vurgu ve uyarı: kiremit ("Yok", bozulacaklar, tek vurgu öğesi).
  static const tomato = Color(0xFFB4532F);
  static const tomatoDeep = Color(0xFF8F3E21);
  static const tomatoSoft = Color(0xFFF6ECE6);

  /// Durum: aşı boyası ("Az", en iyi değer).
  static const butter = Color(0xFFC99A3C);
  static const butterDeep = Color(0xFF946E22);
  static const butterSoft = Color(0xFFF6F0E3);

  static const ink = Color(0xFF1A1A17);
  static const inkSoft = Color(0xFF6E6C66);
  static const line = Color(0xFFE9E5DE);
  static const lineDeep = Color(0xFFD8D2C8);

  /// Sayfa zemini: kâğıt beyazı.
  static const ground = Color(0xFFF8F6F2);

  /// Kart zemini: beyaz.
  static const surface = Color(0xFFFFFFFF);

  /// Nötr dolgu (simge zemini, etiketler, ikincil butonlar).
  static const sand = Color(0xFFF1EEE8);

  /// Eski adlar: artık renkli blok yok, hepsi nötr.
  static const peach = sand;
  static const blush = sand;
}

abstract final class Fonts {
  /// Büyük başlıklar: zarif serif (tek ağırlık).
  static const serif = 'InstrumentSerif';

  /// Başlıklar, butonlar.
  static const display = 'PlusJakarta';

  /// Metinler.
  static const body = 'PlusJakarta';
}
