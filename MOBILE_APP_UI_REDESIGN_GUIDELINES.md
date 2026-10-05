# 📱 ZIGZA ANDROID / FLUTTER MOBILE APP — UI REDESIGN & BRAND THEME MIGRATION MANUAL

> **Target Audience**: Android / Flutter Engineering Team  
> **Repository Scope**: `c:\Users\shaws\NubiSync\nubira-mobile-app`  
> **Objective**: Comprehensive, non-destructive visual migration of the entire mobile app to the new **Zigza Brand Identity & Design System** (`#F8FAFC`, `#0B1220`, `#1D4ED8`, `#14C8B4`, `#FFFFFF`).  
> **Strict Directive**: **UI/Visual Overhaul ONLY**. Do **NOT** modify any Supabase backend queries, Riverpod providers, business logic, Bluetooth printer services, barcode scanning logic, or routing guards.

---

## 🎨 1. The New Zigza Brand Design System vs. Legacy Palette

The mobile app currently utilizes a legacy warm-cream and muted purple-steel theme (`#FAF7F0` canvas and `#3A3564` steel). The modern Zigza visual identity standardizes on a **crisp tech slate canvas (`#F8FAFC`)**, **deep obsidian (`#0B1220`)**, **deep royal blue (`#1D4ED8`)**, **electric mint (`#14C8B4`)**, and **pure white elevated surfaces (`#FFFFFF`)**.

### Color Mapping Master Table (Dart / Flutter)

| Category | Legacy App Token / Hex | New Zigza Brand Token | New Hex Code | Usage in Mobile App |
| :--- | :--- | :--- | :--- | :--- |
| **Canvas Background** | `canvasCream` / `brandMist` (`#FAF7F0`) | `AppTheme.bgCanvas` | `Color(0xFFF8FAFC)` | Primary scaffold background for all screens & lists |
| **Card Surface** | `cardWhite` (`#FFFFFF`) | `AppTheme.cardSurface` | `Color(0xFFFFFFFF)` | Surface background for cards, tiles, dialogs, bottom sheets |
| **Mint Accent Surface** | `steelMist` / `steelTint` (`#EDEAF6`) | `AppTheme.mintSurface` | `Color(0xFFF0FDFA)` | Highlight cards, active station pills, quick action badges |
| **Primary Headings** | `foregroundInk` (`#0F172A`) | `AppTheme.headingObsidian` | `Color(0xFF0B1220)` | Screen titles, H1/H2 headers, prominent KPI numbers |
| **Body & Subtitles** | `mutedInk` (`#475569`) | `AppTheme.bodyInk` | `Color(0xFF475569)` | Descriptions, list item text, dialog body copy |
| **Faint Labels / Meta** | `faintInk` (`#94A3B8`) | `AppTheme.faintInk` | `Color(0xFF64748B)` | Field labels, timestamps, breadcrumbs, counter tags |
| **Primary Heavy Action** | `brandSteel` (`#3A3564`) | `AppTheme.brandObsidian` | `Color(0xFF0B1220)` | Full-width bottom CTAs, major modal submit buttons |
| **Primary Blue Action** | `primaryBlue` (`#1D4ED8`) | `AppTheme.brandRoyalBlue` | `Color(0xFF1D4ED8)` | Interactive primary buttons, text links, highlighted terms |
| **Electric Mint Accent** | `badgeEmeraldBorder` (`#A7F3D0`) | `AppTheme.brandMint` | `Color(0xFF14C8B4)` | Underlines, checkmarks, active badges, status rings |
| **Standard Border** | `standardBorder` (`0x1A000000`) | `AppTheme.borderLight` | `Color(0xFFE2E8F0)` | 1px card outlines, input borders, divider lines |
| **Subtle Divider** | `subtleDivider` (`#F1F5F9`) | `AppTheme.divider` | `Color(0xFFF1F5F9)` | Horizontal separators between list items |

---

### Status Badges & Pill System

| Status / Role | Background Color | Text Color | Border Color | Example Usage |
| :--- | :--- | :--- | :--- | :--- |
| **Active / Verified** | `Color(0xFFECFDF5)` | `Color(0xFF047857)` | `Color(0xFFA7F3D0)` | "ACTIVE WORKSPACE", "INSPECTION PASSED", "DONE" |
| **Mint Brand Badge** | `Color(0xFFF0FDFA)` | `Color(0xFF0B1220)` | `Color(0x4D14C8B4)` (30% `#14C8B4`) | "ERP MES", "7-DAY TRIAL", "STATION ALLOTTED" |
| **Primary / Info** | `Color(0xFFEFF6FF)` | `Color(0xFF1D4ED8)` | `Color(0xFFBFDBFE)` | "IN TRANSIT", "CUTTING BATCH", "AI PROCESSED" |
| **Warning / Pending** | `Color(0xFFFEF3C7)` | `Color(0xFFB45309)` | `Color(0xFFFDE68A)` | "PENDING APPROVAL", "MACHINE QUEUED", "LOW STOCK" |
| **Danger / Alert** | `Color(0xFFFFF1F2)` | `Color(0xFFBE123C)` | `Color(0xFFFECDD3)` | "DEFECT DETECTED", "EXPIRED TRIAL", "REJECTED" |

---

## 🏗️ 2. Core Theme Implementation (`lib/core/theme/app_theme.dart`)

Replace the contents of [`lib/core/theme/app_theme.dart`](file:///c:/Users/shaws/NubiSync/nubira-mobile-app/lib/core/theme/app_theme.dart) with this canonical implementation. It preserves legacy token names as aliases to guarantee zero runtime compilation breaks while applying the new brand identity globally:

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ==========================================
  // CANONICAL ZIGZA BRAND DESIGN TOKENS (2026)
  // ==========================================
  static const Color bgCanvas = Color(0xFFF8FAFC);          // Crisp Tech Canvas Background (Slate-50)
  static const Color cardSurface = Color(0xFFFFFFFF);       // Pure Elevated Card White
  static const Color mintSurface = Color(0xFFF0FDFA);       // Zigza Mint Accent Surface (Emerald/Teal-50)
  static const Color headingObsidian = Color(0xFF0B1220);   // Deep Obsidian for Headlines & Heavy CTAs
  static const Color brandRoyalBlue = Color(0xFF1D4ED8);    // Deep Royal Blue for Primary Actions & Links
  static const Color brandRoyalBlueHover = Color(0xFF1E40AF);
  static const Color brandMint = Color(0xFF14C8B4);         // Electric Mint Brand Accent
  static const Color bodyInk = Color(0xFF475569);           // Slate-600 Body & Subtitle Text
  static const Color faintInk = Color(0xFF64748B);          // Slate-500 Labels & Breadcrumbs
  static const Color borderLight = Color(0xFFE2E8F0);       // Slate-200 Border
  static const Color divider = Color(0xFFF1F5F9);           // Slate-100 Divider

  // Status Badges & Pill System
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

  static const Color badgeMintBg = Color(0xFFF0FDFA);
  static const Color badgeMintText = Color(0xFF0B1220);
  static const Color badgeMintBorder = Color(0x4D14C8B4);

  // ==========================================
  // BACKWARDS COMPATIBILITY ALIASES
  // ==========================================
  static const Color brandSteel = headingObsidian;
  static const Color brandSteelHover = Color(0xFF1E293B);
  static const Color brandMist = bgCanvas;
  static const Color canvasCream = bgCanvas;
  static const Color cardWhite = cardSurface;
  static const Color foregroundInk = headingObsidian;
  static const Color mutedInk = bodyInk;
  static const Color standardBorder = borderLight;
  static const Color subtleDivider = divider;

  static const Color bg = bgCanvas;
  static const Color card = cardSurface;
  static const Color ink = headingObsidian;
  static const Color inkSoft = bodyInk;
  static const Color inkFaint = faintInk;
  static const Color border = borderLight;
  static const Color steel = headingObsidian;
  static const Color steelDark = brandSteelHover;
  static const Color steelMist = mintSurface;
  static const Color steelTint = Color(0xFFE6FFFA);
  static const Color primaryBlue = brandRoyalBlue;
  static const Color primaryBlueDark = brandRoyalBlueHover;
  static const Color red = badgeRoseText;
  static const Color redMist = badgeRoseBg;
  static const Color green = badgeEmeraldText;
  static const Color greenMist = badgeEmeraldBg;
  static const Color amber = badgeAmberText;
  static const Color amberMist = badgeAmberBg;

  // ==========================================
  // GLOBAL MATERIAL 3 LIGHT THEME
  // ==========================================
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        surface: bgCanvas,
        primary: brandRoyalBlue,
        onPrimary: Colors.white,
        secondary: headingObsidian,
        onSecondary: Colors.white,
        error: badgeRoseText,
        outline: borderLight,
      ),
      scaffoldBackgroundColor: bgCanvas,
      textTheme: GoogleFonts.publicSansTextTheme().copyWith(
        displayLarge: GoogleFonts.plusJakartaSans(
          color: headingObsidian,
          fontSize: 26,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        displayMedium: GoogleFonts.plusJakartaSans(
          color: headingObsidian,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        titleLarge: GoogleFonts.plusJakartaSans(
          color: headingObsidian,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: GoogleFonts.plusJakartaSans(
          color: headingObsidian,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: GoogleFonts.publicSans(
          color: headingObsidian,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.45,
        ),
        bodyMedium: GoogleFonts.publicSans(
          color: bodyInk,
          fontSize: 13,
          fontWeight: FontWeight.normal,
          height: 1.4,
        ),
        bodySmall: GoogleFonts.publicSans(
          color: faintInk,
          fontSize: 11.5,
          fontWeight: FontWeight.normal,
        ),
        labelSmall: GoogleFonts.jetBrainsMono(
          color: headingObsidian,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: cardSurface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: true,
        iconTheme: const IconThemeData(color: headingObsidian),
        shape: const Border(
          bottom: BorderSide(color: borderLight, width: 1),
        ),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: headingObsidian,
          fontSize: 17,
          fontWeight: FontWeight.bold,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: brandRoyalBlue,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 46),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 20),
          textStyle: GoogleFonts.publicSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
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
          borderSide: const BorderSide(color: brandRoyalBlue, width: 1.5),
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
```

---

## 📐 3. Typography & Text Hierarchy Rules

The mobile design system follows a clear typographic hierarchy across all Android screens:

1. **Brand Headlines & Screen Titles (`Plus Jakarta Sans`)**:
   - Page Header: `fontSize: 20-24, fontWeight: FontWeight.w800, color: Color(0xFF0B1220)`
   - Section / Group Header: `fontSize: 15-17, fontWeight: FontWeight.bold, color: Color(0xFF0B1220)`
   - Card Title: `fontSize: 14-15, fontWeight: FontWeight.w700, color: Color(0xFF0B1220)`
2. **Body & Descriptive Copy (`Public Sans`)**:
   - Primary Body: `fontSize: 13-14, fontWeight: FontWeight.w500, color: Color(0xFF0B1220)`
   - Subtitle / Instruction: `fontSize: 12-13, fontWeight: FontWeight.normal, color: Color(0xFF475569)`
   - Metadata / Counter: `fontSize: 11-12, fontWeight: FontWeight.w500, color: Color(0xFF64748B)`
3. **Operational Monospace Elements (`JetBrains Mono`)**:
   - KPI metrics, roll barcodes, bundle tags, OTP inputs, and lot numbers: `fontSize: 11-14, fontWeight: FontWeight.bold, color: Color(0xFF0B1220)`

---

## 🧩 4. Component-by-Component Redesign Blueprint

### A. Top App Bar (`lib/core/widgets/zigza_app_bar.dart`)
- **Background**: `#FFFFFF` with 1px bottom border `#E2E8F0`.
- **Hamburger Button**: 38×38 rounded-xl (`borderRadius: 10`), `#FFFFFF` background, border `#E2E8F0`, icon `#0B1220`.
- **Center Logo**: Zigza brand logomark (`h-7` / `height: 32`) centered cleanly.
- **Right Trailing ERP Badge**:
  ```dart
  Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFFF0FDFA),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0x4D14C8B4)),
    ),
    child: Text(
      'ERP MES',
      style: GoogleFonts.jetBrainsMono(
        fontSize: 9.5,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF0B1220),
        letterSpacing: 0.5,
      ),
    ),
  )
  ```

---

### B. Navigation Drawer (`lib/features/modules/widgets/workspace_hub_drawer.dart`)
- **Drawer Background**: `#FFFFFF` with `#E2E8F0` border.
- **Workspace Header Card**:
  - Background: `#F0FDFA` with border `#14C8B4`/30 (`Color(0x4D14C8B4)`).
  - Workspace Name: `text-sm font-extrabold text-[#0B1220]`.
  - Role Badge: `text-[10px] font-mono font-bold uppercase text-[#0B1220] bg-white border border-[#14C8B4]/40`.
- **Active Navigation Item**:
  - Background: `#E6FFFA` (mint tint).
  - Outline: 1px solid `Color(0x6614C8B4)`.
  - Icon Container: `bg-[#0B1220]` with `Colors.white` icon.
  - Label: `text-[13px] font-bold text-[#0B1220]`.
  - Right Chevron: `Color(0xFF0D9488)`.
- **Inactive Navigation Item**:
  - Background: `Colors.transparent` (hover `Colors.slate-50`).
  - Icon Container: `bg-[#F1F5F9]` with `Color(0xFF475569)` icon.
  - Label: `text-[13px] font-semibold text-[#475569]`.
- **Sign Out Button**:
  - `textColor: Color(0xFFBE123C)`, hover `Color(0xFFFFF1F2)`, icon `Icons.logout_rounded`.

---

### C. Standard Button System

```dart
// 1. Primary Full-Width Dark Action Button (Login, Launch, Assign)
ElevatedButton(
  style: ElevatedButton.styleFrom(
    backgroundColor: const Color(0xFF0B1220),
    foregroundColor: Colors.white,
    minimumSize: const Size(double.infinity, 48),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    elevation: 0,
  ),
  onPressed: () {},
  child: const Text('Confirm & Update', style: TextStyle(fontWeight: FontWeight.bold)),
);

// 2. Primary Royal Blue Action Button (Create, Add Worker, Inwards)
ElevatedButton(
  style: ElevatedButton.styleFrom(
    backgroundColor: const Color(0xFF1D4ED8),
    foregroundColor: Colors.white,
    minimumSize: const Size(double.infinity, 46),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    elevation: 0,
  ),
  onPressed: () {},
  child: const Text('Add Entry', style: TextStyle(fontWeight: FontWeight.bold)),
);

// 3. Secondary / Cancel Outline Button
OutlinedButton(
  style: OutlinedButton.styleFrom(
    backgroundColor: Colors.white,
    foregroundColor: const Color(0xFF0B1220),
    side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
    minimumSize: const Size(double.infinity, 46),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
  onPressed: () {},
  child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
);
```

---

### D. Station Tabs & Touch Switchers (Cutting / Sewing / QC / Pack)
- **Active Pill Tab**:
  - Background: `Color(0xFF0B1220)` with `Colors.white` text, OR `Color(0xFFE6FFFA)` with `Color(0xFF0B1220)` text & `Color(0xFF14C8B4)` border.
- **Inactive Pill Tab**:
  - Background: `Color(0xFFFFFFFF)` with `Color(0xFF64748B)` text & `Color(0xFFE2E8F0)` border.
- **Minimum Touch Target**: `44px` height across all Android viewports.

---

### E. Cards & Module Tiles (`enterprise_workspace_hub_screen.dart`)
- **Card Chassis**:
  - Surface: `Colors.white`
  - Border: 1px solid `Color(0xFFE2E8F0)`
  - Border Radius: `14px`
  - Shadow: `BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: Offset(0, 1))`
- **Division Icon Box**:
  - Background: `Color(0xFFF0FDFA)` with border `Color(0x3314C8B4)`.
  - Icon: `Color(0xFF0B1220)` (or division specific color).
- **Module Title**: `GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF0B1220))`.
- **Status Dot**:
  - Active: `Color(0xFF10B981)` green pulsating dot with `Color(0xFF047857)` text.
  - Locked / Unallocated: `Color(0xFF94A3B8)` grey dot with `Color(0xFF64748B)` text.

---

### F. Bottom Sheets & Form Dialogs
- **Top Corner Radius**: `24px` (`BorderRadius.vertical(top: Radius.circular(24))`).
- **Surface**: `Colors.white` with `#F8FAFC` inner grouping cards.
- **Drag Handle**: Centered bar (`width: 40, height: 4, borderRadius: 2, color: Color(0xFFE2E8F0)`).
- **Header Row**: Bold title in `#0B1220` with a circular close button (`Icons.close_rounded`, `#64748B`).

---

## 📱 5. Screen-by-Screen Redesign Checklist

| # | Screen Name & File | Required UI Updates |
| :- | :--- | :--- |
| **01** | **Auth / Login Screen**<br>`features/auth/screens/login_screen.dart` | • Change scaffold background from `#FAF7F0` to `#F8FAFC`.<br>• Change brand cards to pure white with `#E2E8F0` border.<br>• Update "Sign In" button to `#0B1220` (Obsidian) or `#1D4ED8`.<br>• Switch input focus borders to `#1D4ED8`.<br>• Replace `#3A3564` heading colors with `#0B1220`. |
| **02** | **Enterprise Workspace Hub**<br>`features/modules/screens/enterprise_workspace_hub_screen.dart` | • Update internal `DesignTokens` or delete local token class and reference `AppTheme`.<br>• Canvas background: `#F8FAFC`.<br>• Search bar: `#FFFFFF` fill with `#E2E8F0` border.<br>• Module cards: `#FFFFFF` with `#F0FDFA` icon badges.<br>• Allotment status: `#ECFDF5` active badge. |
| **03** | **Department Heads & Roles**<br>`features/modules/screens/department_heads_screen.dart`<br>`appoint_department_head_screen.dart` | • Header cards: `#FFFFFF` with `#E2E8F0` border.<br>• "Appoint Head" primary CTA: `#1D4ED8` (Royal Blue).<br>• Appointed staff list: `#0B1220` names, `#475569` roles.<br>• Role selection pills: `#0B1220` active vs `#FFFFFF` inactive. |
| **04** | **Supervisor Floor Stations**<br>`features/modules/screens/supervisor_floor_stations_screen.dart` | • Background: `#F8FAFC`.<br>• Station cards: `#FFFFFF` with `#0B1220` titles.<br>• Quick stat metrics: `#0B1220` bold text with `#14C8B4` accents. |
| **05** | **Cutting Lay Floor**<br>`features/cutting/screens/cutting_lay_floor_screen.dart` | • Fabric roll tags: JetBrains Mono `#0B1220` on `#F0FDFA` badge.<br>• Lay sheet status: `#ECFDF5` active, `#FEF3C7` laying.<br>• Confirm cut button: `#0B1220` full-width CTA. |
| **06** | **Sewing & Lineman Desk**<br>`features/dashboard/lineman_dashboard.dart` | • Active lot KPI card: `#FFFFFF` with `#0B1220` counter.<br>• Hourly piece tracker: JetBrains Mono bold text.<br>• "Log Bundle Complete" button: `#1D4ED8` with ripple effect. |
| **07** | **Quality Control (QC) Desk**<br>`features/dashboard/qc_dashboard.dart` | • Pass badge: `#ECFDF5` bg with `#047857` text.<br>• Reject/Alter badge: `#FFF1F2` bg with `#BE123C` text.<br>• Defect category chips: `#FFFFFF` with `#E2E8F0` border. |
| **08** | **Mending & Alteration Desk**<br>`features/dashboard/mending_dashboard.dart` | • Bundle queue cards: `#FFFFFF` surface.<br>• "Return to Line" button: `#1D4ED8`. |
| **09** | **Store & Warehouse Godown**<br>`features/store/screens/central_store_godown_screen.dart`<br>`features/dashboard/store_dashboard.dart` | • Replace `static const Color kPrimaryBrand = Color(0xFF3A3564);` with `AppTheme.brandRoyalBlue` (`#1D4ED8`) or `AppTheme.headingObsidian` (`#0B1220`).<br>• Stock level chips: `#F0FDFA` mint badges.<br>• Inwards/Outwards buttons: `#1D4ED8` and `#0B1220`. |
| **10** | **Washing & Ironing Floors**<br>`features/washing/screens/washing_floor_screen.dart`<br>`features/iron/screens/iron_floor_screen.dart` | • Machine run status pills: `#F0FDFA` active run.<br>• Recipe parameters: JetBrains Mono numbers. |
| **11** | **Dispatch & Ready Goods**<br>`features/dispatch/screens/dispatch_logistics_hub_screen.dart`<br>`features/ready_goods/screens/quality_clinic_floor_screen.dart` | • Carton barcoding view: `#FFFFFF` card with `#0B1220` font.<br>• Truck manifest button: `#0B1220` full-width CTA. |

---

## 🔒 6. Strict Engineering Safeguards ("DO NOT TOUCH" Rules)

To ensure zero regressions across app features, adhere strictly to these engineering boundaries:

1. **State Management & Providers**:
   - Do **NOT** rename or alter `authProvider`, `ref.watch()`, `ref.read()`, or Riverpod notifier methods.
   - Do **NOT** modify the state models (`AuthState`, `ModuleCardData`, `DepartmentHeadItem`).
2. **Supabase Client & Edge Functions**:
   - Do **NOT** alter Supabase table queries (`from('platform_tenant_factories')`, `from('cutting_workers')`, etc.).
   - Do **NOT** change authentication tokens, user metadata keys, or session handling logic.
3. **Hardware & Device Integrations**:
   - Preserve all camera scanner controllers (`mobile_scanner` / `qr_code_scanner`).
   - Preserve all ESC/POS Bluetooth thermal printer channels.
4. **Navigation & Routes**:
   - Keep all `Navigator.push()`, `MaterialPageRoute`, and named route parameters unchanged.

---

## ⚡ 7. Android Developer Quick-Find & Replace Reference

Use the following automated find & replace table in Android Studio / VS Code across `lib/`:

| Search Term / Hex | Replace With | Notes |
| :--- | :--- | :--- |
| `Color(0xFF3A3564)` | `AppTheme.headingObsidian` *(or `AppTheme.brandRoyalBlue` for buttons)* | Replaces old purple-steel with deep obsidian or royal blue |
| `Color(0xFF2A2649)` | `AppTheme.brandRoyalBlueHover` | Replaces old hover tone |
| `Color(0xFFFAF7F0)` | `AppTheme.bgCanvas` | Replaces warm cream with crisp tech canvas (`#F8FAFC`) |
| `Color(0xFFEDEAF6)` | `AppTheme.mintSurface` | Replaces old purple mist with Zigza mint surface (`#F0FDFA`) |
| `Color(0xFF0F172A)` | `AppTheme.headingObsidian` | Standardizes all ink text to `#0B1220` |
| `Color(0x1A000000)` | `AppTheme.borderLight` | Standardizes borders to `#E2E8F0` |

---

## ✅ 8. Verification & QA Checklist for Android Build

Before submitting the pull request or releasing the APK / AAB:
1. `flutter analyze` runs with **0 errors and 0 warnings**.
2. App runs on both **390px (Mobile standard)** and **768px (Tablet / Station tablet)** viewports.
3. Contrast ratio of all text elements against `#F8FAFC` and `#FFFFFF` is **>= 4.5:1 (WCAG AA compliant)**.
4. All touch targets (buttons, station tabs, hamburger icon) meet minimum **44×44px** dimensions.
5. All module launchers, barcode scanners, and printer operations execute flawlessly without drift.
