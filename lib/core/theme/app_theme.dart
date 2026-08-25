import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Nubira Creation Core Design Tokens
  static const Color bg = Color(0xFFEEF1F5);
  static const Color card = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF1C2733);
  static const Color inkSoft = Color(0xFF5B6B7C);
  static const Color inkFaint = Color(0xFF8B9AAB);
  static const Color border = Color(0xFFE2E8F0);
  static const Color steel = Color(0xFF2B4C7E);
  static const Color steelDark = Color(0xFF1F3A63);
  static const Color steelMist = Color(0xFFEEF3FA);
  static const Color steelTint = Color(0xFFDBE6F5);
  static const Color stitch = Color(0xFFC8802B);
  
  static const Color red = Color(0xFFC0392B);
  static const Color redMist = Color(0xFFFBEAE8);
  static const Color green = Color(0xFF1F9D63);
  static const Color greenMist = Color(0xFFE6F6EE);
  static const Color amber = Color(0xFFC8802B);
  static const Color amberMist = Color(0xFFFBF0E1);

  // Backward compatibility aliases
  static const Color primaryBlue = steel;
  static const Color primaryBlueDark = steelDark;
  static const Color successGreen = green;
  static const Color backgroundLight = bg;
  static const Color textDark = ink;
  static const Color textMuted = inkSoft;

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        surface: bg,
        primary: steel,
        onPrimary: Colors.white,
        secondary: steelDark,
        error: red,
      ),
      scaffoldBackgroundColor: bg,
      textTheme: GoogleFonts.publicSansTextTheme().copyWith(
        displayLarge: GoogleFonts.fraunces(color: ink, fontWeight: FontWeight.bold),
        displayMedium: GoogleFonts.fraunces(color: ink, fontWeight: FontWeight.w700),
        titleLarge: GoogleFonts.fraunces(color: ink, fontWeight: FontWeight.w600),
        bodyLarge: GoogleFonts.publicSans(color: ink, fontWeight: FontWeight.w500),
        bodyMedium: GoogleFonts.publicSans(color: inkSoft),
        bodySmall: GoogleFonts.publicSans(color: inkFaint),
        labelSmall: GoogleFonts.jetBrainsMono(color: inkFaint, fontSize: 10),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: card,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: ink),
        titleTextStyle: GoogleFonts.fraunces(
          color: ink,
          fontSize: 19,
          fontWeight: FontWeight.bold,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: steel,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          textStyle: GoogleFonts.publicSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      cardTheme: CardTheme(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(11),
          side: const BorderSide(color: border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: steel, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: red, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: red, width: 1.5),
        ),
        hintStyle: GoogleFonts.publicSans(color: inkFaint, fontSize: 13),
      ),
    );
  }
}
