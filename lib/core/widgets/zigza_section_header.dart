import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

/// Shared Dashboard heading typography (`Plus Jakarta Sans` + tabular numerals).
TextStyle zigzaHeadingStyle({
  double fontSize = 15,
  FontWeight fontWeight = FontWeight.w700,
  Color color = AppTheme.headingObsidian,
  double? letterSpacing,
  double? height,
  TextDecoration? decoration,
}) {
  return GoogleFonts.plusJakartaSans(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
    decoration: decoration,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

/// Shared Dashboard body/label typography (`Public Sans` + tabular numerals).
TextStyle zigzaBodyStyle({
  double fontSize = 13,
  FontWeight fontWeight = FontWeight.w500,
  Color color = AppTheme.bodyInk,
  double? letterSpacing,
  double? height,
  TextDecoration? decoration,
}) {
  return GoogleFonts.publicSans(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
    decoration: decoration,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

/// Shared Dashboard-style section header matching `PlantOperationsDashboardScreen`
/// and web `DashboardSectionHeader`.
class ZigzaSectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String accent;
  final String? badge;
  final Widget? action;
  final Color iconColor;
  final Color iconBgColor;
  final Color? accentColor;
  final bool withDivider;
  final EdgeInsetsGeometry padding;

  const ZigzaSectionHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.accent,
    this.badge,
    this.action,
    this.iconColor = const Color(0xFF0F766E),
    this.iconBgColor = AppTheme.mintSurface,
    this.accentColor,
    this.withDivider = true,
    this.padding = const EdgeInsets.only(bottom: 10),
  });

  @override
  Widget build(BuildContext context) {
    final resolvedAccent = accentColor ?? AppTheme.brandRoyalBlue;

    return Container(
      padding: padding,
      decoration: withDivider
          ? const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppTheme.borderLight, width: 1),
              ),
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: iconColor.withValues(alpha: 0.14),
                width: 1,
              ),
            ),
            child: Icon(icon, size: 17, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text.rich(
                    TextSpan(
                      style: zigzaHeadingStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.25,
                      ),
                      children: [
                        TextSpan(text: title),
                        if (accent.isNotEmpty) ...[
                          const TextSpan(text: ' '),
                          TextSpan(
                            text: accent,
                            style: TextStyle(color: resolvedAccent),
                          ),
                        ],
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (badge != null && badge!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.borderLight),
                    ),
                    child: Text(
                      badge!,
                      style: zigzaHeadingStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.bodyInk,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: 8),
            action!,
          ],
        ],
      ),
    );
  }
}

