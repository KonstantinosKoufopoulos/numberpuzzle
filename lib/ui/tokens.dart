/// Non-colour design tokens from docs/design/visual/tokens.json.
/// Colours live in theme.dart (`GamePalette` + `ColorScheme`).
abstract final class Tk {
  // spacing
  static const double xs = 4, s = 8, m = 12, l = 16, xl = 24, xxl = 32;
  // radius
  static const double rCell = 8, rButton = 12, rCard = 16, rSheet = 20, rPill = 999;
  // size
  static const double cell = 38, cellGap = 2, tapTargetMin = 44, tapSlop = 6, button = 48, booster = 56;
  static const int gridCols = 9;
  // motion
  static const Duration select = Duration(milliseconds: 120);
  static const Duration clear = Duration(milliseconds: 220);
  static const Duration collapse = Duration(milliseconds: 260);
  static const Duration shake = Duration(milliseconds: 280);
  static const double shakeAmp = 6;
  // font scale: cellDigit 20/700 at cell 38
  static const double cellDigitSize = 20;
}
