import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Canonical Master Design Tokens (web_admin/docs_logic/design.md)
  static const Color brandSteel = Color(0xFF3A3564);
  static const Color brandSteelHover = Color(0xFF2A2649);
  static const Color brandMist = Color(0xFFFAF7F0); // Warm Canvas Background
  static const Color canvasCream = Color(0xFFFAF7F0);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color foregroundInk = Color(0xFF0F172A); // Dark Ink #0F172A / #09090B
  static const Color mutedInk = Color(0xFF475569); // Slate-600 Body & Subtitles
  static const Color faintInk = Color(0xFF94A3B8); // Slate-400 Labels & Breadcrumbs
  static const Color standardBorder = Color(0x1A000000); // border-black/10
  static const Color subtleDivider = Color(0xFFF1F5F9); // slate-100 / divide-slate-100

  // Status Badges & Tint System (design.md Section 2)
  static const Color badgeEmeraldBg = Color(0xFFECFDF5);
  static const Color badgeEmeraldText = Color(0xFF047857);
  static const Color badgeEmeraldBorder = Color(0xFFA7F3D0);

  static const Color badgeBlueBg = Color(0xFFEFF6FF);
  static const Color badgeBlueText = Color(0xFF1D4ED8);
  static const Color badgeBlueBorder = Color(0xFFBFDBFE);

  static const Color badgeAmberBg = Color(0xFFFEF3C7);
  static const Color badgeAmberText = Color(0xFFB45309);
  static const Color badgeAmberBorder = Color(0xFFFDE68A);

  static const Color badgeRoseBg = Color(0xFFFFF1F2);
  static const Color badgeRoseText = Color(0xFFBE123C);
  static const Color badgeRoseBorder = Color(0xFFFECDD3);

  static const Color badgeNeutralBg = Color(0xFFFAF7F0);
  static const Color badgeNeutralText = Color(0xFF3A3564);
  static const Color badgeNeutralBorder = Color(0x1A000000);

  // Backward compatibility aliases
  static const Color bg = canvasCream;
  static const Color card = cardWhite;
  static const Color ink = foregroundInk;
  static const Color inkSoft = mutedInk;
  static const Color inkFaint = faintInk;
  static const Color border = Color(0xFFE2E8F0);
  static const Color steel = brandSteel;
  static const Color steelDark = brandSteelHover;
  static const Color steelMist = Color(0xFFEDEAF6);
  static const Color steelTint = Color(0xFFE2DDF0);
  static const Color stitch = Color(0xFFC8802B);
  
  static const Color red = badgeRoseText;
  static const Color redMist = badgeRoseBg;
  static const Color green = badgeEmeraldText;
  static const Color greenMist = badgeEmeraldBg;
  static const Color amber = badgeAmberText;
  static const Color amberMist = badgeAmberBg;

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
