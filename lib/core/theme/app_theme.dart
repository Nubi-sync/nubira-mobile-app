import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Canonical Master Zigza Brand Tokens (web_admin alignment)
  static const Color bgCanvas = Color(0xFFF8FAFC); // Crisp Tech Slate Canvas (#F8FAFC)
  static const Color cardSurface = Color(0xFFFFFFFF); // Pure Elevated White (#FFFFFF)
  static const Color mintSurface = Color(0xFFF0FDFA); // Mint / Teal-50 Accent Surface (#F0FDFA)
  static const Color headingObsidian = Color(0xFF0B1220); // Deep Obsidian Headings & Dark CTAs (#0B1220)
  static const Color brandRoyalBlue = Color(0xFF1D4ED8); // Deep Royal Blue Action & Links (#1D4ED8)
  static const Color brandMint = Color(0xFF14C8B4); // Electric Mint Brand Accent (#14C8B4)
  static const Color bodyInk = Color(0xFF475569); // Slate-600 Body & Subtitles (#475569)
  static const Color faintInk = Color(0xFF94A3B8); // Slate-400 Labels & Breadcrumbs (#94A3B8)
  static const Color borderLight = Color(0xFFE2E8F0); // Slate-200 1px Border (#E2E8F0)
  static const Color subtleDivider = Color(0xFFF1F5F9); // Slate-100 Divider (#F1F5F9)

  // Status Badges & 5-Tier Tint System
  static const Color badgeEmeraldBg = Color(0xFFECFDF5);
  static const Color badgeEmeraldText = Color(0xFF047857);
  static const Color badgeEmeraldBorder = Color(0xFFA7F3D0);

  static const Color badgeMintBg = Color(0xFFF0FDFA);
  static const Color badgeMintText = Color(0xFF0B1220);
  static const Color badgeMintBorder = Color(0x4D14C8B4);

  static const Color badgeBlueBg = Color(0xFFEFF6FF);
  static const Color badgeBlueText = Color(0xFF1D4ED8);
  static const Color badgeBlueBorder = Color(0xFFBFDBFE);

  static const Color badgeAmberBg = Color(0xFFFEF3C7);
  static const Color badgeAmberText = Color(0xFFB45309);
  static const Color badgeAmberBorder = Color(0xFFFDE68A);

  static const Color badgeRoseBg = Color(0xFFFFF1F2);
  static const Color badgeRoseText = Color(0xFFBE123C);
  static const Color badgeRoseBorder = Color(0xFFFECDD3);

  static const Color badgeNeutralBg = Color(0xFFF8FAFC);
  static const Color badgeNeutralText = Color(0xFF0B1220);
  static const Color badgeNeutralBorder = Color(0xFFE2E8F0);

  // Backward compatibility aliases to prevent compile breaks
  static const Color bg = bgCanvas;
  static const Color card = cardSurface;
  static const Color ink = headingObsidian;
  static const Color inkSoft = bodyInk;
  static const Color inkFaint = faintInk;
  static const Color border = borderLight;
  static const Color brandSteel = headingObsidian;
  static const Color brandSteelHover = headingObsidian;
  static const Color brandMist = bgCanvas;
  static const Color canvasCream = bgCanvas;
  static const Color cardWhite = cardSurface;
  static const Color foregroundInk = headingObsidian;
  static const Color mutedInk = bodyInk;
  static const Color standardBorder = borderLight;
  static const Color steel = headingObsidian;
  static const Color steelDark = headingObsidian;
  static const Color steelMist = mintSurface;
  static const Color steelTint = mintSurface;
  static const Color stitch = brandRoyalBlue;
  
  static const Color primaryBlue = brandRoyalBlue;
  static const Color primaryBlueDark = Color(0xFF1E40AF);
  static const Color red = badgeRoseText;
  static const Color redMist = badgeRoseBg;
  static const Color green = badgeEmeraldText;
  static const Color greenMist = badgeEmeraldBg;
  static const Color amber = badgeAmberText;
  static const Color amberMist = badgeAmberBg;
  static const Color successGreen = green;
  static const Color backgroundLight = bgCanvas;
  static const Color textDark = headingObsidian;
  static const Color textMuted = bodyInk;

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        surface: bgCanvas,
        primary: headingObsidian,
        onPrimary: Colors.white,
        secondary: brandRoyalBlue,
        error: badgeRoseText,
      ),
      scaffoldBackgroundColor: bgCanvas,
      textTheme: GoogleFonts.publicSansTextTheme().copyWith(
        displayLarge: GoogleFonts.plusJakartaSans(color: headingObsidian, fontWeight: FontWeight.bold),
        displayMedium: GoogleFonts.plusJakartaSans(color: headingObsidian, fontWeight: FontWeight.w700),
        titleLarge: GoogleFonts.plusJakartaSans(color: headingObsidian, fontWeight: FontWeight.w600),
        bodyLarge: GoogleFonts.publicSans(color: headingObsidian, fontWeight: FontWeight.w500),
        bodyMedium: GoogleFonts.publicSans(color: bodyInk),
        bodySmall: GoogleFonts.publicSans(color: faintInk),
        labelSmall: GoogleFonts.jetBrainsMono(color: faintInk, fontSize: 10),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: cardSurface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        iconTheme: const IconThemeData(color: headingObsidian),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: headingObsidian,
          fontSize: 19,
          fontWeight: FontWeight.bold,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: headingObsidian,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          textStyle: GoogleFonts.publicSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: cardSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: borderLight, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderLight, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderLight, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: headingObsidian, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: badgeRoseText, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: badgeRoseText, width: 1.5),
        ),
        hintStyle: GoogleFonts.publicSans(color: faintInk, fontSize: 13),
      ),
    );
  }
}
