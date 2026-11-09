import "package:flutter/material.dart";

import "app_tokens.dart";
import "status_bar.dart";

/// Bundled in assets/fonts with weights 400–800 (pubspec.yaml), so any
/// `fontWeight` picks the matching file.
const _fontFamily = "Nunito";
const _fontFallback = ["Noto Sans Georgian", "Noto Sans"];

TextStyle _nunito(TextStyle? base, {required double fontSize, required FontWeight fontWeight, Color? color}) {
  return (base ?? const TextStyle()).copyWith(
    fontFamily: _fontFamily,
    fontFamilyFallback: _fontFallback,
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
  );
}

/// The app's [ThemeData]. Colors come from [AppTokens], so screens that rely
/// on Material defaults match the redesigned ones:
///
/// * App bars: flat, page-colored, 18px bold title. Bottom-nav tab roots
///   (Search, Notifications) use 20px like the Profile tab.
/// * Filled buttons: [AppTokens.primary] with white text (passes 4.5:1), the
///   same green as Publish. FAB: [AppTokens.fill], like the nav's "+".
/// * Bottom sheets and dialogs: [AppTokens.sheet], 24px corners, [AppTokens.scrim]
///   barrier. Sheets that draw their own container use `sheetTopRadius` and
///   `SheetHandle` (widgets/common/app_bottom_sheet.dart).
/// * Snackbars float with rounded corners; ErrorUtils picks their colors.
ThemeData buildAppTheme(Brightness brightness) {
  final t = brightness == Brightness.dark ? AppTokens.dark : AppTokens.light;
  final scheme = t.roles(ColorScheme.fromSeed(seedColor: t.brand, brightness: brightness));
  final textTheme = ThemeData(brightness: brightness)
      .textTheme
      .apply(fontFamily: _fontFamily, fontFamilyFallback: _fontFallback, bodyColor: t.ink, displayColor: t.ink);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    textTheme: textTheme,
    fontFamily: _fontFamily,
    fontFamilyFallback: _fontFallback,
    chipTheme: const ChipThemeData(showCheckmark: false),
    pageTransitionsTheme: statusBarInsetPageTransitions,
    appBarTheme: AppBarTheme(
      backgroundColor: t.bg,
      foregroundColor: t.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: _nunito(textTheme.titleLarge, fontSize: 18, fontWeight: FontWeight.w700, color: t.ink),
    ),
    tabBarTheme: TabBarThemeData(
      indicatorColor: t.brand,
      labelColor: t.ink,
      unselectedLabelColor: t.ink2,
      dividerColor: t.line,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: t.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: _nunito(textTheme.labelLarge, fontSize: 14, fontWeight: FontWeight.w700),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: t.fill,
      foregroundColor: Colors.white,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: t.sheet,
      modalBackgroundColor: t.sheet,
      surfaceTintColor: Colors.transparent,
      modalBarrierColor: t.scrim,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      dragHandleColor: t.line,
      dragHandleSize: const Size(36, 4),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: t.sheet,
      surfaceTintColor: Colors.transparent,
      barrierColor: t.scrim,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: _nunito(textTheme.titleLarge, fontSize: 20, fontWeight: FontWeight.w700, color: t.ink),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
