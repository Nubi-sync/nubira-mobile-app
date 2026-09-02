import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Nubira Brand Core Design Tokens (Midnight Violet & Warm Canvas)
  static const Color bg = Color(0xFFFAF7F0);
  static const Color card = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF0F172A);
  static const Color inkSoft = Color(0xFF475569);
  static const Color inkFaint = Color(0xFF94A3B8);
  static const Color border = Color(0xFFE2E8F0);
  static const Color steel = Color(0xFF3A3564);
  static const Color steelDark = Color(0xFF2A2649);
  static const Color steelMist = Color(0xFFEDEAF6);
  static const Color steelTint = Color(0xFFE2DDF0);
  static const Color stitch = Color(0xFFC8802B);
  
  static const Color red = Color(0xFFE11D48);
  static const Color redMist = Color(0xFFFFF1F2);
  static const Color green = Color(0xFF10B981);
  static const Color greenMist = Color(0xFFECFDF5);
  static const Color amber = Color(0xFFD97706);
  static const Color amberMist = Color(0xFFFEF3C7);

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
        displayLarge: GoogleFonts.plusJakartaSans(color: ink, fontWeight: FontWeight.bold),
        displayMedium: GoogleFonts.plusJakartaSans(color: ink, fontWeight: FontWeight.w700),
        titleLarge: GoogleFonts.plusJakartaSans(color: ink, fontWeight: FontWeight.w600),
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
        titleTextStyle: GoogleFonts.plusJakartaSans(
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
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          textStyle: GoogleFonts.publicSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: steel, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: red, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: red, width: 1.5),
        ),
        hintStyle: GoogleFonts.publicSans(color: inkFaint, fontSize: 13),
      ),
    );
  }
}
