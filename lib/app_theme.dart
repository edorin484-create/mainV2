import 'package:flutter/material.dart';

class AppTheme {
  // Palette principale
  static const Color primaryBlue = Color(0xFF1A6FE8);
  static const Color accentTeal = Color(0xFF00C6AE);
  static const Color warningAmber = Color(0xFFFFB830);
  static const Color errorRed = Color(0xFFFF4757);
  static const Color successGreen = Color(0xFF2ED573);

  // Dark palette
  static const Color darkBg = Color(0xFF0F1923);
  static const Color darkSurface = Color(0xFF1A2535);
  static const Color darkCard = Color(0xFF243044);
  static const Color darkBorder = Color(0xFF2E3D52);
  static const Color darkText = Color(0xFFF0F4FF);
  static const Color darkSubtext = Color(0xFF8A9BB5);

  // Light palette
  static const Color lightBg = Color(0xFFF4F7FD);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFEEF2FA);
  static const Color lightBorder = Color(0xFFDDE3F0);
  static const Color lightText = Color(0xFF1A2535);
  static const Color lightSubtext = Color(0xFF6B7A99);

  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: darkBg,
    colorScheme: const ColorScheme.dark(
      primary: primaryBlue,
      secondary: accentTeal,
      surface: darkSurface,
      error: errorRed,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: darkText,
    ),
    fontFamily: 'Nunito',
    textTheme: _buildTextTheme(darkText, darkSubtext),
    cardTheme: CardTheme(
      color: darkCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: darkBorder, width: 1),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(
          fontFamily: 'Nunito',
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: darkBg,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'Nunito',
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: darkText,
      ),
      iconTheme: IconThemeData(color: darkText),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: darkSurface,
      selectedItemColor: primaryBlue,
      unselectedItemColor: darkSubtext,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
  );

  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: lightBg,
    colorScheme: const ColorScheme.light(
      primary: primaryBlue,
      secondary: accentTeal,
      surface: lightSurface,
      error: errorRed,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: lightText,
    ),
    fontFamily: 'Nunito',
    textTheme: _buildTextTheme(lightText, lightSubtext),
    cardTheme: CardTheme(
      color: lightSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: lightBorder, width: 1),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(
          fontFamily: 'Nunito',
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: lightBg,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'Nunito',
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: lightText,
      ),
      iconTheme: IconThemeData(color: lightText),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: lightSurface,
      selectedItemColor: primaryBlue,
      unselectedItemColor: lightSubtext,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
  );

  static TextTheme _buildTextTheme(Color primary, Color secondary) => TextTheme(
    displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: primary),
    displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: primary),
    headlineLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: primary),
    headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: primary),
    titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: primary),
    titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: primary),
    bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: primary),
    bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: secondary),
    labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: primary),
  );
}