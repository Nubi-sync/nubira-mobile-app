import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../models/module_card_model.dart';

class GenericDivisionScreen extends StatelessWidget {
  final ModuleCardData module;

  const GenericDivisionScreen({
    super.key,
    required this.module,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvasCream,
      appBar: AppBar(
        backgroundColor: AppTheme.cardWhite,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.foregroundInk),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          module.title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: AppTheme.foregroundInk,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.apps_rounded, color: AppTheme.brandSteel),
            tooltip: 'Workspace Hub',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Division Hero Header Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.cardWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.standardBorder),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x08000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppTheme.canvasCream,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.standardBorder),
                        ),
                        child: Icon(module.icon, color: AppTheme.brandSteel, size: 22),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.canvasCream,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.standardBorder),
                        ),
                        child: Text(
                          module.badge,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.brandSteel,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    module.title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.foregroundInk,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    module.subtitle,
                    style: GoogleFonts.publicSans(
                      fontSize: 12.5,
                      color: AppTheme.mutedInk,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Division Active Features
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.cardWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.standardBorder),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x08000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Operational Checkpoints',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.foregroundInk,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...module.features.map((feat) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: AppTheme.badgeEmeraldText, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              feat,
                              style: GoogleFonts.publicSans(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.foregroundInk,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Live Floor Sync Status
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.badgeEmeraldBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.badgeEmeraldBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cloud_done_rounded, color: AppTheme.badgeEmeraldText, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Live Floor Station Sync: CONNECTED',
                          style: GoogleFonts.publicSans(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.badgeEmeraldText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Workstation records synchronized with central MES plant inventory.',
                          style: GoogleFonts.publicSans(
                            fontSize: 11.5,
                            color: AppTheme.mutedInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
