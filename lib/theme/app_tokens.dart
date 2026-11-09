import "package:flutter/material.dart";

/// Colors for the bottom nav, Home feed header, sort sheet and Profile tab
/// (see docs/navigation-redesign.md), and the create/edit recipe screen
/// (docs/create-recipe-redesign.md). The rest of the app still uses the
/// global [ThemeData]; these do not feed into it.
///
/// [brand] is too light for text (about 2.6:1 on white): use [brandInk] for
/// any green text or icon.
class AppTokens {
  const AppTokens._({
    required this.bg,
    required this.card,
    required this.sheet,
    required this.ink,
    required this.ink2,
    required this.line,
    required this.brandInk,
    required this.soft,
    required this.scrim,
    required this.field,
    required this.dashed,
  });

  final Color bg;
  final Color card;
  final Color sheet;
  final Color ink;
  final Color ink2;
  final Color line;
  final Color brandInk;
  final Color soft;
  final Color scrim;

  /// Text-field and stepper fill.
  final Color field;

  /// Dashed borders of "add" buttons and tiles.
  final Color dashed;

  /// Tab underline, active dot, radio, avatar ring. Never text.
  Color get brand => const Color(0xFF53B175);

  /// "+" button and completed streak day (white content on it).
  Color get fill => const Color(0xFF3F9E64);

  /// Primary button background, e.g. Publish. White text on it passes 4.5:1,
  /// which [fill] does not.
  Color get primary => const Color(0xFF2E7D4F);

  /// Notification count (white text on it).
  Color get badge => const Color(0xFFC93C3C);

  static const light = AppTokens._(
    bg: Color(0xFFF6F7F5),
    card: Color(0xFFFFFFFF),
    sheet: Color(0xFFFFFFFF),
    ink: Color(0xFF17211B),
    ink2: Color(0xFF5A665F),
    line: Color(0xFFE3E8E4),
    brandInk: Color(0xFF2C7A4B),
    soft: Color(0xFFE7F4EC),
    scrim: Color(0x73101612),
    field: Color(0xFFF1F3F0),
    dashed: Color(0xFFB9C4BD),
  );

  static const dark = AppTokens._(
    bg: Color(0xFF0F1311),
    card: Color(0xFF181D1A),
    sheet: Color(0xFF1C221E),
    ink: Color(0xFFEDF1EE),
    ink2: Color(0xFFA2ADA6),
    line: Color(0xFF2B332E),
    brandInk: Color(0xFF7ED19D),
    soft: Color(0xFF1C3125),
    scrim: Color(0x99000000),
    field: Color(0xFF222925),
    dashed: Color(0xFF3A4540),
  );

  static AppTokens of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}
