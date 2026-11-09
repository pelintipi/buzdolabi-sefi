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
        {required Color color, double height = 1.4}) =>
    TextStyle(
      fontFamily: Fonts.body,
      fontSize: size,
      fontWeight: weight,
      height: height,
      color: color,
    );

TextStyle _display(double size,
        {FontWeight weight = FontWeight.w700, required Color color}) =>
    TextStyle(
      fontFamily: Fonts.display,
      fontSize: size,
      fontWeight: weight,
      height: 1.15,
      // Büyük başlıklar biraz sıkı (tasarımdaki gibi).
      letterSpacing: size >= 22 ? -0.4 : -0.1,
      color: color,
    );

/// Büyük başlıklar: serif, tek ağırlık (kalınlık taklit edilmesin diye w400).
TextStyle _serif(double size, {required Color color}) => TextStyle(
      fontFamily: Fonts.serif,
      fontSize: size,
      fontWeight: FontWeight.w400,
      height: 1.08,
      letterSpacing: -0.3,
      color: color,
    );

ThemeData buildAppTheme(Brightness brightness) {
  final c = BrandColors.forBrightness(brightness);
  final scheme = ColorScheme.fromSeed(
    seedColor: Palette.basil,
    brightness: brightness,
    primary: Palette.basil,
    onPrimary: Colors.white,
    primaryContainer: c.basilSoft,
    onPrimaryContainer:
        brightness == Brightness.dark ? c.ink : Palette.basilDeep,
    secondary: Palette.tomato,
    onSecondary: Colors.white,
    secondaryContainer: c.tomatoSoft,
    onSecondaryContainer:
        brightness == Brightness.dark ? c.ink : Palette.tomatoDeep,
    tertiary: Palette.butterDeep,
    tertiaryContainer: c.butterSoft,
    onTertiaryContainer: c.ink,
    error: Palette.tomatoDeep,
    errorContainer: c.tomatoSoft,
    onErrorContainer:
        brightness == Brightness.dark ? c.ink : Palette.tomatoDeep,
    surface: c.surface,
    onSurface: c.ink,
    onSurfaceVariant: c.inkSoft,
    outline: c.lineDeep,
    outlineVariant: c.line,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: Fonts.body,
    fontFamilyFallback: _emojiFallback,
  );

  final text = base.textTheme
      .apply(bodyColor: c.ink, displayColor: c.ink)
      .copyWith(
        displaySmall: _serif(42, color: c.ink),
        displayMedium: _serif(48, color: c.ink),
        headlineMedium: _serif(34, color: c.ink),
        headlineSmall: _serif(30, color: c.ink),
        titleLarge: _display(20, weight: FontWeight.w700, color: c.ink),
        titleMedium: _display(16.5, weight: FontWeight.w700, color: c.ink),
        titleSmall: _display(16, weight: FontWeight.w600, color: c.ink),
        bodyLarge: _body(17, FontWeight.w500, color: c.ink),
        bodyMedium: _body(15, FontWeight.w500, color: c.ink),
        bodySmall:
            _body(13, FontWeight.w500, color: c.inkSoft, height: 1.35),
        labelLarge: _body(15, FontWeight.w800, color: c.ink, height: 1.2),
        labelMedium: _body(13, FontWeight.w700, color: c.ink, height: 1.2),
        labelSmall:
            _body(12, FontWeight.w700, color: c.inkSoft, height: 1.2),
      );

  final rounded20 =
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(20));

  return base.copyWith(
    textTheme: text,
    scaffoldBackgroundColor: c.ground,
    appBarTheme: AppBarTheme(
      backgroundColor: c.ground,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      foregroundColor: c.ink,
      titleTextStyle: _serif(30, color: c.ink),
    ),
    cardTheme: CardThemeData(
      color: c.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: c.line, width: 1),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: c.surface,
      selectedColor: c.basilSoft,
      side: BorderSide(color: c.line, width: 1.5),
      shape: const StadiumBorder(),
      labelStyle: TextStyle(
          fontFamily: Fonts.body,
          fontWeight: FontWeight.w700,
          fontSize: 14,
          color: c.ink),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      showCheckmark: false,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: rounded20,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: _display(17, color: c.ink),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: brightness == Brightness.dark
            ? const Color(0xFF8FBF9F)
            : Palette.basil,
        textStyle: const TextStyle(
            fontFamily: Fonts.body, fontWeight: FontWeight.w800, fontSize: 15),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        side: WidgetStatePropertyAll(
            BorderSide(color: c.line, width: 1.5)),
        backgroundColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? c.basilSoft : c.surface),
        foregroundColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? (brightness == Brightness.dark
                    ? c.ink
                    : Palette.basilDeep)
                : c.ink),
        textStyle: const WidgetStatePropertyAll(TextStyle(
            fontFamily: Fonts.body, fontWeight: FontWeight.w800, fontSize: 14)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      hintStyle:
          TextStyle(color: c.inkSoft, fontWeight: FontWeight.w600),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: c.line, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: c.line, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Palette.basil, width: 2),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      titleTextStyle: _serif(28, color: c.ink),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: brightness == Brightness.dark ? c.sand : Palette.basilDeep,
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
          s.contains(WidgetState.selected) ? Palette.basil : c.line),
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
    listTileTheme: ListTileThemeData(
      titleTextStyle: TextStyle(
          fontFamily: Fonts.body,
          fontWeight: FontWeight.w700,
          fontSize: 16,
          color: c.ink),
      subtitleTextStyle: TextStyle(
          fontFamily: Fonts.body,
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: c.inkSoft),
    ),
    dividerTheme: DividerThemeData(color: c.line, thickness: 1.5),
  );
}
