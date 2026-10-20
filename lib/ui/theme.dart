import 'package:flutter/material.dart';

/// Game palette from the designer tokens (numberpuzzle-ux/visual/tokens.json).
@immutable
class GamePalette extends ThemeExtension<GamePalette> {
  const GamePalette({
    required this.cell,
    required this.cellBorder,
    required this.selected,
    required this.line,
    required this.hint,
    required this.hintBorder,
    required this.cleared,
    required this.star,
    required this.stone,
    required this.ice,
    required this.grass,
    required this.slime,
    required this.textMuted,
  });

  final Color cell, cellBorder, selected, line, hint, hintBorder, cleared;
  final Color star, stone, ice, grass, slime, textMuted;

  static const light = GamePalette(
    cell: Color(0xFFFFFFFF),
    cellBorder: Color(0xFFD9D4CA),
    selected: Color(0xFF3D6B8C),
    line: Color(0xFF7FA7C2),
    hint: Color(0xFFE3EFE6),
    hintBorder: Color(0xFF5E9C76),
    cleared: Color(0xFFECE8E0),
    star: Color(0xFFE2A93B),
    stone: Color(0xFF8A8780),
    ice: Color(0xFFCFE3F0),
    grass: Color(0xFFCFE6C4),
    slime: Color(0xFF9C7FC4),
    textMuted: Color(0xFF6B7280),
  );

  static const dark = GamePalette(
    cell: Color(0xFF242A33),
    cellBorder: Color(0xFF353D48),
    selected: Color(0xFF7FB0D3),
    line: Color(0xFF4F7C9B),
    hint: Color(0xFF22382B),
    hintBorder: Color(0xFF7CC196),
    cleared: Color(0xFF1A1E24),
    star: Color(0xFFF0BE5A),
    stone: Color(0xFF5D6168),
    ice: Color(0xFF2D4A5E),
    grass: Color(0xFF2E4A2A),
    slime: Color(0xFF6E559A),
    textMuted: Color(0xFF9AA3AE),
  );

  @override
  GamePalette copyWith() => this;

  @override
  GamePalette lerp(GamePalette? other, double t) => t < 0.5 ? this : (other ?? this);
}

ThemeData _build(Brightness b) {
  final isLight = b == Brightness.light;
  final scheme = ColorScheme(
    brightness: b,
    primary: Color(isLight ? 0xFF3D6B8C : 0xFF7FB0D3),
    onPrimary: Color(isLight ? 0xFFFFFFFF : 0xFF0E1A24),
    secondary: Color(isLight ? 0xFF5E9C76 : 0xFF7CC196),
    onSecondary: Color(isLight ? 0xFFFFFFFF : 0xFF0E1A24),
    error: Color(isLight ? 0xFFC2554B : 0xFFE07A70),
    onError: const Color(0xFFFFFFFF),
    surface: Color(isLight ? 0xFFFFFFFF : 0xFF1E232A),
    onSurface: Color(isLight ? 0xFF1F2430 : 0xFFECEEF1),
  );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: Color(isLight ? 0xFFF7F5F0 : 0xFF14171C),
    // TODO(M3): fontFamily: 'Manrope' once bundled (OFL).
    textTheme: const TextTheme(
      displaySmall: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
      bodyMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      bodySmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
    ),
    extensions: [isLight ? GamePalette.light : GamePalette.dark],
  );
}

final ThemeData lightTheme = _build(Brightness.light);
final ThemeData darkTheme = _build(Brightness.dark);
