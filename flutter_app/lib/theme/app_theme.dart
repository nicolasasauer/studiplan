import 'package:flutter/material.dart';

/// Light and dark theme, in the style of Focus Flow: indigo seed, Inter,
/// rounded surfaces. Widgets take their colours from the [ColorScheme]
/// (and [Tones] for the status colours), never from fixed values, so both
/// modes stay readable.
abstract final class AppTheme {
  static const Color seed = Color(0xFF4F46E5);

  /// Bundled in assets/fonts (SIL Open Font License), so nothing is fetched
  /// at runtime.
  static const String fontFamily = 'Inter';

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: fontFamily,
    );

    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 2,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        // Phone-sized dialogs; on a wide desktop window they would
        // otherwise stretch across the whole screen.
        constraints: const BoxConstraints(minWidth: 280, maxWidth: 560),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      dividerColor: scheme.outlineVariant,
    );
  }
}

/// Status colours (ECTS blue, passed green, grade purple, WS/SS, warnings)
/// in a shade that reads on the current background: the bright tone on
/// dark surfaces, a deeper one on light surfaces.
abstract final class Tones {
  static Color of(BuildContext context, MaterialColor color) =>
      Theme.of(context).brightness == Brightness.dark
          ? color
          : color.shade800;
}

/// Short access to the theme colours from any widget.
extension ThemeColors on BuildContext {
  ColorScheme get cs => Theme.of(this).colorScheme;

  /// See [Tones.of].
  Color tone(MaterialColor color) => Tones.of(this, color);
}
