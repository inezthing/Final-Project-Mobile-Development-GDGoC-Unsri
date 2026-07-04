import 'package:flutter/material.dart';

class AppTheme {
  // Palet warna utama aplikasi (nuansa pink/blush)
  static const Color primary = Color(0xFFE91E8C);
  static const Color primaryLight = Color(0xFFF48FB1);
  static const Color primaryDark = Color(0xFFC2185B);
  static const Color accent = Color(0xFFFF6B9D);
  static const Color blush = Color(0xFFFCE4EC);
  static const Color rose = Color(0xFFF8BBD9);
  static const Color cream = Color(0xFFFFF8F9);

  // Tema terang (light mode)
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      primary: primary,
      secondary: accent,
      surface: cream,
      onPrimary: Colors.white,
    ),
    fontFamily: 'Nunito',
    // Styling AppBar: putih polos tanpa shadow
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      elevation: 0,
      foregroundColor: Color(0xFF2D1B2E),
      titleTextStyle: TextStyle(
        fontFamily: 'Nunito',
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: Color(0xFF2D1B2E),
      ),
    ),
    scaffoldBackgroundColor: cream,
    // Styling Card: rounded corner, flat (tanpa shadow)
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
    ),
    // Styling tombol utama (elevated button)
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontFamily: 'Nunito',
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    // Styling input field (textfield/form)
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
    ),
  );

  // Tema gelap (dark mode)
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
      primary: primaryLight,
      secondary: accent,
      surface: const Color(0xFF1A0D1A),
      onPrimary: Colors.white,
    ),
    fontFamily: 'Nunito',
    scaffoldBackgroundColor: const Color(0xFF1A0D1A),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1A0D1A),
      elevation: 0,
      foregroundColor: Colors.white,
      titleTextStyle: TextStyle(
        fontFamily: 'Nunito',
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: Colors.white,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: const Color(0xFF2D1B2E),
    ),
  );
}
