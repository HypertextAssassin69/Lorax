import 'package:flutter/material.dart';

class AppTheme {
  // Tactical Mission Control Color Palette
  static const Color obsidianBg = Color(0xFF0B0F17);
  static const Color slateCard = Color(0xFF151C28);
  static const Color slateBorder = Color(0xFF232F42);
  static const Color cyberCyan = Color(0xFF00F0FF);
  static const Color emeraldGreen = Color(0xFF10B981);
  static const Color crimsonRed = Color(0xFFEF4444);
  static const Color tacticalAmber = Color(0xFFF59E0B);
  static const Color offlineSlate = Color(0xFF94A3B8);

  // Semantic Aliases
  static const Color primaryNavy = obsidianBg;
  static const Color secondaryColor = cyberCyan;
  static const Color safeColor = emeraldGreen;
  static const Color warningColor = tacticalAmber;
  static const Color emergencyRed = crimsonRed;
  static const Color criticalColor = crimsonRed;
  static const Color offlineColor = offlineSlate;

  static ThemeData get light => dark; // Tactical dark mode by default for SAR operations

  static ThemeData get dark {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: cyberCyan,
      onPrimary: obsidianBg,
      primaryContainer: slateCard,
      onPrimaryContainer: Colors.white,
      secondary: emeraldGreen,
      onSecondary: Colors.black,
      secondaryContainer: Color(0xFF162338),
      onSecondaryContainer: cyberCyan,
      tertiary: crimsonRed,
      onTertiary: Colors.white,
      error: crimsonRed,
      onError: Colors.white,
      surface: slateCard,
      onSurface: Colors.white,
      onSurfaceVariant: Color(0xFF94A3B8),
      outline: slateBorder,
      outlineVariant: Color(0xFF232F42),
    );
    return _buildTheme(colorScheme);
  }

  static ThemeData _buildTheme(ColorScheme cs) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: obsidianBg,
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: slateBorder, width: 1),
        ),
        color: slateCard,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: obsidianBg,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 1,
      ),
        foregroundColor: cs.onSurface,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: cs.surface,
        indicatorColor: cs.secondaryContainer,
        height: 64,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: cs.surface,
        indicatorColor: cs.secondaryContainer,
      ),
      dividerTheme: DividerThemeData(
        color: cs.outlineVariant.withValues(alpha: 0.3),
        thickness: 1,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: cs.onSurface),
        displayMedium: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: cs.onSurface),
        displaySmall: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: cs.onSurface),
        headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: cs.onSurface),
        headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: cs.onSurface),
        headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: cs.onSurface),
        titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: cs.onSurface),
        titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: cs.onSurface),
        titleSmall: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: cs.onSurface),
        bodyLarge: TextStyle(fontSize: 17, fontWeight: FontWeight.w400, color: cs.onSurface),
        bodyMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: cs.onSurface),
        bodySmall: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: cs.onSurfaceVariant),
        labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: cs.onSurface),
        labelMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface),
        labelSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant),
      ),
      fontFamily: 'Roboto',
    );
  }

  const AppTheme._();
}
