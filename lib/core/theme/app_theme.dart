import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum VisualStyle { classic, cyber }

/// Hard HUD palette from Theme B mock.
abstract final class CyberPalette {
  static const black = Color(0xFF000000);
  static const panel = Color(0xFF050A08);
  static const mint = Color(0xFF00FF9C);
  static const mintSoft = Color(0xFFB9FFE0);
  static const mintBorder = Color(0x5500FF9C);
  static const mintDim = Color(0x9900FF9C);
  static const danger = Color(0xFFFF3B5C);
}

@immutable
class StatThemeExtension extends ThemeExtension<StatThemeExtension> {
  const StatThemeExtension({
    required this.style,
    required this.panelRadius,
    required this.panelBorderWidth,
    required this.panelBorderColor,
    required this.accentGlow,
    required this.mono,
    required this.useHudChrome,
  });

  final VisualStyle style;
  final double panelRadius;
  final double panelBorderWidth;
  final Color panelBorderColor;
  final Color accentGlow;
  final TextStyle mono;
  final bool useHudChrome;

  bool get isCyber => style == VisualStyle.cyber;

  static StatThemeExtension of(BuildContext context) {
    return Theme.of(context).extension<StatThemeExtension>() ??
        StatThemeExtension.classic(Theme.of(context).colorScheme);
  }

  factory StatThemeExtension.classic(ColorScheme scheme) {
    return StatThemeExtension(
      style: VisualStyle.classic,
      panelRadius: 16,
      panelBorderWidth: 1,
      panelBorderColor: scheme.outlineVariant,
      accentGlow: scheme.primary.withValues(alpha: 0.0),
      mono: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
      useHudChrome: false,
    );
  }

  factory StatThemeExtension.cyber() {
    return StatThemeExtension(
      style: VisualStyle.cyber,
      panelRadius: 0,
      panelBorderWidth: 1,
      panelBorderColor: CyberPalette.mintBorder,
      accentGlow: CyberPalette.mint.withValues(alpha: 0.45),
      mono: GoogleFonts.jetBrainsMono(
        color: CyberPalette.mintSoft,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      useHudChrome: true,
    );
  }

  @override
  StatThemeExtension copyWith({
    VisualStyle? style,
    double? panelRadius,
    double? panelBorderWidth,
    Color? panelBorderColor,
    Color? accentGlow,
    TextStyle? mono,
    bool? useHudChrome,
  }) {
    return StatThemeExtension(
      style: style ?? this.style,
      panelRadius: panelRadius ?? this.panelRadius,
      panelBorderWidth: panelBorderWidth ?? this.panelBorderWidth,
      panelBorderColor: panelBorderColor ?? this.panelBorderColor,
      accentGlow: accentGlow ?? this.accentGlow,
      mono: mono ?? this.mono,
      useHudChrome: useHudChrome ?? this.useHudChrome,
    );
  }

  @override
  StatThemeExtension lerp(ThemeExtension<StatThemeExtension>? other, double t) {
    if (other is! StatThemeExtension) return this;
    return t < 0.5 ? this : other;
  }
}

class AppTheme {
  static const _classicSeed = Color(0xFF1B6B4A);

  static ThemeData classicLight() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _classicSeed,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      extensions: [StatThemeExtension.classic(scheme)],
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
      ),
    );
  }

  static ThemeData classicDark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _classicSeed,
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      extensions: [StatThemeExtension.classic(scheme)],
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
      ),
    );
  }

  static ThemeData light() => classicLight();
  static ThemeData dark() => classicDark();

  static ThemeData cyber() {
    final mono = GoogleFonts.jetBrainsMonoTextTheme(
      ThemeData(brightness: Brightness.dark).textTheme.apply(
            bodyColor: CyberPalette.mintSoft,
            displayColor: CyberPalette.mintSoft,
          ),
    );

    final scheme = const ColorScheme.dark(
      primary: CyberPalette.mint,
      onPrimary: CyberPalette.black,
      secondary: CyberPalette.mint,
      onSecondary: CyberPalette.black,
      tertiary: CyberPalette.mintSoft,
      error: CyberPalette.danger,
      onError: CyberPalette.black,
      surface: CyberPalette.panel,
      onSurface: CyberPalette.mintSoft,
      surfaceContainerHighest: CyberPalette.panel,
      outline: CyberPalette.mintBorder,
      outlineVariant: CyberPalette.mintBorder,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: CyberPalette.black,
      canvasColor: CyberPalette.black,
      extensions: [StatThemeExtension.cyber()],
      textTheme: mono.copyWith(
        titleLarge: mono.titleLarge?.copyWith(
          letterSpacing: 0.8,
          fontWeight: FontWeight.w700,
          color: CyberPalette.mintSoft,
        ),
        titleMedium: mono.titleMedium?.copyWith(
          letterSpacing: 0.6,
          fontWeight: FontWeight.w700,
        ),
        bodySmall: mono.bodySmall?.copyWith(
          color: CyberPalette.mintDim,
          letterSpacing: 0.4,
        ),
        labelMedium: mono.labelMedium?.copyWith(
          color: CyberPalette.mintDim,
          letterSpacing: 1.2,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: CyberPalette.black,
        foregroundColor: CyberPalette.mintSoft,
        elevation: 0,
        titleTextStyle: GoogleFonts.jetBrainsMono(
          color: CyberPalette.mintSoft,
          fontWeight: FontWeight.w700,
          fontSize: 18,
          letterSpacing: 1.4,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: CyberPalette.mint,
        unselectedLabelColor: CyberPalette.mintDim,
        indicatorColor: CyberPalette.mint,
        labelStyle: GoogleFonts.jetBrainsMono(
          letterSpacing: 1.2,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        unselectedLabelStyle: GoogleFonts.jetBrainsMono(
          letterSpacing: 1.0,
          fontSize: 12,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: CyberPalette.black,
        indicatorColor: CyberPalette.mint.withValues(alpha: 0.12),
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.jetBrainsMono(
            fontSize: 10,
            letterSpacing: 1.0,
            fontWeight: FontWeight.w700,
            color: selected ? CyberPalette.mint : CyberPalette.mintDim,
            shadows: selected
                ? const [
                    Shadow(color: Color(0x8800FF9C), blurRadius: 10),
                  ]
                : null,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? CyberPalette.mint : CyberPalette.mintDim,
            shadows: selected
                ? const [
                    Shadow(color: Color(0x8800FF9C), blurRadius: 10),
                  ]
                : null,
          );
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: CyberPalette.mint,
          foregroundColor: CyberPalette.black,
          elevation: 0,
          shadowColor: CyberPalette.mint,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          textStyle: GoogleFonts.jetBrainsMono(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ).copyWith(
          elevation: const WidgetStatePropertyAll(0),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: CyberPalette.mintDim,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          textStyle: GoogleFonts.jetBrainsMono(letterSpacing: 1.0),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: CyberPalette.mint,
        foregroundColor: CyberPalette.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        elevation: 0,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: CyberPalette.black,
        selectedColor: CyberPalette.mint.withValues(alpha: 0.15),
        side: const BorderSide(color: CyberPalette.mint),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        labelStyle: GoogleFonts.jetBrainsMono(
          color: CyberPalette.mint,
          letterSpacing: 1.0,
          fontSize: 11,
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: CyberPalette.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: CyberPalette.mintBorder),
        ),
      ),
      cardTheme: const CardThemeData(
        color: CyberPalette.panel,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: CyberPalette.mintBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: CyberPalette.panel,
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: CyberPalette.mintBorder),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: CyberPalette.mintBorder),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: CyberPalette.mint, width: 1.4),
        ),
        labelStyle: GoogleFonts.jetBrainsMono(color: CyberPalette.mintDim),
      ),
      dividerColor: CyberPalette.mintBorder,
    );
  }
}
