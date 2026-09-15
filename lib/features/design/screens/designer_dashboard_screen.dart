import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/design_brief_model.dart';
import '../providers/designer_provider.dart';
import 'design_brief_detail_screen.dart';

class DesignerDashboardScreen extends ConsumerWidget {
  const DesignerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(designerProvider);
    final authState = ref.watch(authProvider);

    final briefs = state.briefs;
    final activeCount = briefs.where((b) => b.status == 'ALLOCATED' || b.status == 'PH_REJECTED').length;
    final reviewCount = briefs.where((b) => b.status == 'SUBMITTED' || b.status == 'PH_APPROVED').length;
    final approvedCount = briefs.where((b) => b.status == 'SA_APPROVED' || b.status == 'TECH_PACK_CREATED').length;

    return Scaffold(
      backgroundColor: AppTheme.canvasCream,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Designer Workspace',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppTheme.foregroundInk,
              ),
            ),
            Text(
              authState.tenantProfile?.companyName ?? 'Nubira Creation',
              style: GoogleFonts.publicSans(
                fontSize: 11,
                color: AppTheme.mutedInk,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.brandSteel),
            onPressed: () => ref.read(designerProvider.notifier).fetchAllocatedBriefs(),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppTheme.mutedInk),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.brandSteel))
          : RefreshIndicator(
              color: AppTheme.brandSteel,
              onRefresh: () => ref.read(designerProvider.notifier).fetchAllocatedBriefs(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // KPI Summary Cards
                    Row(
                      children: [
                        _buildKpiCard(
                          title: 'Action Needed',
                          count: '$activeCount',
                          subtitle: 'Pending uploads',
                          color: AppTheme.brandSteel,
                        ),
                        const SizedBox(width: 8),
                        _buildKpiCard(
                          title: 'In Review',
                          count: '$reviewCount',
                          subtitle: 'PH / SA verification',
                          color: AppTheme.amber,
                        ),
                        const SizedBox(width: 8),
                        _buildKpiCard(
                          title: 'Approved',
                          count: '$approvedCount',
                          subtitle: 'Production ready',
                          color: AppTheme.green,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Section Heading
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Allocated Design Briefs',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppTheme.foregroundInk,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.badgeNeutralBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.badgeNeutralBorder),
                          ),
                          child: Text(
                            '${briefs.length} Briefs',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.brandSteel,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (briefs.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.standardBorder),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.palette_outlined, size: 40, color: AppTheme.faintInk),
                            const SizedBox(height: 10),
                            Text(
                              'No Design Briefs Assigned',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: AppTheme.foregroundInk,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Your Provisional Head has not assigned any briefs yet. Pull down to refresh.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.publicSans(fontSize: 12, color: AppTheme.mutedInk),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: briefs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final brief = briefs[index];
                          return _buildBriefCard(context, brief);
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String count,
    required String subtitle,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.standardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.publicSans(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppTheme.mutedInk,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              count,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.publicSans(
                fontSize: 9,
                color: AppTheme.faintInk,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBriefCard(BuildContext context, DesignBriefModel brief) {
    Color badgeBg = AppTheme.badgeNeutralBg;
    Color badgeText = AppTheme.brandSteel;
    Color badgeBorder = AppTheme.badgeNeutralBorder;

    if (brief.status == 'SUBMITTED') {
      badgeBg = AppTheme.badgeAmberBg;
      badgeText = AppTheme.badgeAmberText;
      badgeBorder = AppTheme.badgeAmberBorder;
    } else if (brief.status == 'PH_APPROVED' || brief.status == 'SA_APPROVED') {
      badgeBg = AppTheme.badgeEmeraldBg;
      badgeText = AppTheme.badgeEmeraldText;
      badgeBorder = AppTheme.badgeEmeraldBorder;
    } else if (brief.status == 'PH_REJECTED') {
      badgeBg = AppTheme.badgeRoseBg;
      badgeText = AppTheme.badgeRoseText;
      badgeBorder = AppTheme.badgeRoseBorder;
    }

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DesignBriefDetailScreen(brief: brief),
          ),
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.standardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  brief.garmentType,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppTheme.foregroundInk,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: badgeBorder),
                  ),
                  child: Text(
                    brief.status.replaceAll('_', ' '),
                    style: GoogleFonts.publicSans(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: badgeText,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  '${brief.category} Style',
                  style: GoogleFonts.publicSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.brandSteel,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '•  Max ${brief.maxColors} Colors',
                  style: GoogleFonts.publicSans(
                    fontSize: 12,
                    color: AppTheme.mutedInk,
                  ),
                ),
              ],
            ),
            if (brief.instructions != null && brief.instructions!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '“${brief.instructions}”',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.publicSans(
                  fontSize: 12,
                  color: AppTheme.mutedInk,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  brief.status == 'ALLOCATED' || brief.status == 'PH_REJECTED'
                      ? 'Upload Photos →'
                      : 'View Submission →',
                  style: GoogleFonts.publicSans(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.brandSteel,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
