import 'package:flutter/material.dart';

import 'palette.dart';

/// Emojiler için sistem fontları (3D ikonu olmayan nadir emojiler için yedek).
const _emojiFallback = [
  'Apple Color Emoji',
  'Noto Color Emoji',
  'Segoe UI Emoji'
];

/// Metin stili: font ailesi ve renk her zaman açıkça verilir, yoksa alt
/// widget'lar sistem fontuna ve renksiz (beyaz) metne düşer.
TextStyle _body(double size, FontWeight weight,
        {Color color = Palette.ink, double height = 1.4}) =>
    TextStyle(
      fontFamily: Fonts.body,
      fontSize: size,
      fontWeight: weight,
      height: height,
      color: color,
    );

TextStyle _display(double size, {FontWeight weight = FontWeight.w700}) =>
    TextStyle(
      fontFamily: Fonts.display,
      fontSize: size,
      fontWeight: weight,
      height: 1.15,
      // Büyük başlıklar biraz sıkı (tasarımdaki gibi).
      letterSpacing: size >= 22 ? -0.4 : -0.1,
      color: Palette.ink,
    );

/// Büyük başlıklar: serif, tek ağırlık (kalınlık taklit edilmesin diye w400).
TextStyle _serif(double size) => TextStyle(
      fontFamily: Fonts.serif,
      fontSize: size,
      fontWeight: FontWeight.w400,
      height: 1.08,
      letterSpacing: -0.3,
      color: Palette.ink,
    );

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Palette.basil,
    primary: Palette.basil,
    onPrimary: Colors.white,
    primaryContainer: Palette.basilSoft,
    onPrimaryContainer: Palette.basilDeep,
    secondary: Palette.tomato,
    onSecondary: Colors.white,
    secondaryContainer: Palette.tomatoSoft,
    onSecondaryContainer: Palette.tomatoDeep,
    tertiary: Palette.butterDeep,
    tertiaryContainer: Palette.butterSoft,
    onTertiaryContainer: Palette.ink,
    error: Palette.tomatoDeep,
    errorContainer: Palette.tomatoSoft,
    onErrorContainer: Palette.tomatoDeep,
    surface: Palette.surface,
    onSurface: Palette.ink,
    onSurfaceVariant: Palette.inkSoft,
    outline: Palette.lineDeep,
    outlineVariant: Palette.line,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: Fonts.body,
    fontFamilyFallback: _emojiFallback,
  );

  final text = base.textTheme
      .apply(bodyColor: Palette.ink, displayColor: Palette.ink)
      .copyWith(
        displaySmall: _serif(42),
        displayMedium: _serif(48),
        headlineMedium: _serif(34),
        headlineSmall: _serif(30),
        titleLarge: _display(20, weight: FontWeight.w700),
        titleMedium: _display(16.5, weight: FontWeight.w700),
        titleSmall: _display(16, weight: FontWeight.w600),
        bodyLarge: _body(17, FontWeight.w500),
        bodyMedium: _body(15, FontWeight.w500),
        bodySmall:
            _body(13, FontWeight.w500, color: Palette.inkSoft, height: 1.35),
        labelLarge: _body(15, FontWeight.w800, height: 1.2),
        labelMedium: _body(13, FontWeight.w700, height: 1.2),
        labelSmall:
            _body(12, FontWeight.w700, color: Palette.inkSoft, height: 1.2),
      );

  final rounded20 =
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(20));

  return base.copyWith(
    textTheme: text,
    scaffoldBackgroundColor: Palette.ground,
    appBarTheme: AppBarTheme(
      backgroundColor: Palette.ground,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      foregroundColor: Palette.ink,
      titleTextStyle: _serif(30),
    ),
    cardTheme: CardThemeData(
      color: Palette.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Palette.line, width: 1),
      ),
    ),
    chipTheme: const ChipThemeData(
      backgroundColor: Palette.surface,
      selectedColor: Palette.basilSoft,
      side: BorderSide(color: Palette.line, width: 1.5),
      shape: StadiumBorder(),
      labelStyle: TextStyle(
          fontFamily: Fonts.body,
          fontWeight: FontWeight.w700,
          fontSize: 14,
          color: Palette.ink),
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      showCheckmark: false,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: rounded20,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: _display(17),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Palette.basil,
        textStyle: const TextStyle(
            fontFamily: Fonts.body, fontWeight: FontWeight.w800, fontSize: 15),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        side: const WidgetStatePropertyAll(
            BorderSide(color: Palette.line, width: 1.5)),
        backgroundColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? Palette.basilSoft
                : Palette.surface),
        foregroundColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? Palette.basilDeep : Palette.ink),
        textStyle: const WidgetStatePropertyAll(TextStyle(
            fontFamily: Fonts.body, fontWeight: FontWeight.w800, fontSize: 14)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Palette.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      hintStyle:
          const TextStyle(color: Palette.inkSoft, fontWeight: FontWeight.w600),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Palette.line, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Palette.line, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Palette.basil, width: 2),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Palette.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      titleTextStyle: _serif(28),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Palette.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Palette.ink,
      actionTextColor: Palette.butter,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentTextStyle: const TextStyle(
          fontFamily: Fonts.body,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          fontSize: 15),
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? Palette.basil : Palette.line),
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected)
              ? Palette.basil
              : Colors.transparent),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
    listTileTheme: const ListTileThemeData(
      titleTextStyle: TextStyle(
          fontFamily: Fonts.body,
          fontWeight: FontWeight.w700,
          fontSize: 16,
          color: Palette.ink),
      subtitleTextStyle: TextStyle(
          fontFamily: Fonts.body,
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: Palette.inkSoft),
    ),
    dividerTheme: const DividerThemeData(color: Palette.line, thickness: 1.5),
  );
}
