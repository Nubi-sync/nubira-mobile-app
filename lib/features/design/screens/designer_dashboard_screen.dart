import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/design_brief_model.dart';
import '../providers/designer_provider.dart';
import 'design_brief_detail_screen.dart';

/// Clean line-art Waving Hand Outline Painter (stroke line-art, fill: none, no emoji)
class WavingHandOutlinePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  WavingHandOutlinePainter({
    this.color = const Color(0xFF1E293B),
    this.strokeWidth = 1.8,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    // Outer hand & fingers outline path
    final handPath = Path();
    // Pinky
    handPath.moveTo(w * 0.75, h * 0.46);
    handPath.lineTo(w * 0.75, h * 0.25);
    handPath.quadraticBezierTo(w * 0.75, h * 0.17, w * 0.67, h * 0.17);
    handPath.quadraticBezierTo(w * 0.58, h * 0.17, w * 0.58, h * 0.25);
    handPath.lineTo(w * 0.58, h * 0.42);

    // Ring finger
    handPath.moveTo(w * 0.58, h * 0.42);
    handPath.lineTo(w * 0.58, h * 0.17);
    handPath.quadraticBezierTo(w * 0.58, h * 0.08, w * 0.50, h * 0.08);
    handPath.quadraticBezierTo(w * 0.42, h * 0.08, w * 0.42, h * 0.17);
    handPath.lineTo(w * 0.42, h * 0.46);

    // Middle finger
    handPath.moveTo(w * 0.42, h * 0.44);
    handPath.lineTo(w * 0.42, h * 0.25);
    handPath.quadraticBezierTo(w * 0.42, h * 0.17, w * 0.33, h * 0.17);
    handPath.quadraticBezierTo(w * 0.25, h * 0.17, w * 0.25, h * 0.25);
    handPath.lineTo(w * 0.25, h * 0.58);

    // Thumb & Palm base
    handPath.moveTo(w * 0.75, h * 0.33);
    handPath.quadraticBezierTo(w * 0.92, h * 0.33, w * 0.92, h * 0.50);
    handPath.quadraticBezierTo(w * 0.92, h * 0.75, w * 0.58, h * 0.92);
    handPath.lineTo(w * 0.50, h * 0.92);
    handPath.quadraticBezierTo(w * 0.25, h * 0.92, w * 0.15, h * 0.65);
    handPath.lineTo(w * 0.15, h * 0.58);
    handPath.quadraticBezierTo(w * 0.21, h * 0.50, w * 0.25, h * 0.58);

    canvas.drawPath(handPath, paint);

    // Subtle motion wave arcs
    final wave1 = Path()
      ..moveTo(w * 0.17, h * 0.17)
      ..quadraticBezierTo(w * 0.25, h * 0.13, w * 0.33, h * 0.17);
    canvas.drawPath(wave1, paint);

    final wave2 = Path()
      ..moveTo(w * 0.08, h * 0.29)
      ..quadraticBezierTo(w * 0.21, h * 0.23, w * 0.31, h * 0.29);
    canvas.drawPath(wave2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class DesignerDashboardScreen extends ConsumerStatefulWidget {
  const DesignerDashboardScreen({super.key});

  @override
  ConsumerState<DesignerDashboardScreen> createState() => _DesignerDashboardScreenState();
}

class _DesignerDashboardScreenState extends ConsumerState<DesignerDashboardScreen> {
  int _selectedTab = 0; // 0: Active Assignments, 1: Submission History

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(designerProvider);
    final authState = ref.watch(authProvider);

    final briefs = state.briefs;
    
    // Active briefs to do: ALLOCATED or PH_REJECTED
    final activeBriefs = briefs.where((b) => b.status == 'ALLOCATED' || b.status == 'PH_REJECTED').toList();
    // History briefs: SUBMITTED, PH_APPROVED, SA_APPROVED, SA_SAVED_FOR_LATER, TECH_PACK_CREATED
    final historyBriefs = briefs.where((b) => b.status != 'ALLOCATED').toList();

    final displayName = authState.tenantProfile?.adminDisplayName ?? 
      authState.cachedUsername ?? 
      'Designer';

    final displayedBriefs = _selectedTab == 0 ? activeBriefs : historyBriefs;

    return Scaffold(
      backgroundColor: AppTheme.canvasCream,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Designer Desk',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: AppTheme.foregroundInk,
          ),
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
                    // Welcome Header Card with Line-Art Waving Hand
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.standardBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.canvasCream,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.standardBorder),
                            ),
                            child: CustomPaint(
                              painter: WavingHandOutlinePainter(
                                color: AppTheme.foregroundInk,
                                strokeWidth: 1.8,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Welcome, $displayName',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                    color: AppTheme.foregroundInk,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${activeBriefs.length} Active Assignments To Do',
                                  style: GoogleFonts.publicSans(
                                    fontSize: 12,
                                    color: AppTheme.brandSteel,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Tab Switcher: Active Assignments vs Submission History
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppTheme.canvasCream,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.standardBorder),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _selectedTab = 0),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _selectedTab == 0 ? AppTheme.brandSteel : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    'Active (${activeBriefs.length})',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: _selectedTab == 0 ? Colors.white : AppTheme.mutedInk,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _selectedTab = 1),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _selectedTab == 1 ? AppTheme.brandSteel : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    'History (${historyBriefs.length})',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: _selectedTab == 1 ? Colors.white : AppTheme.mutedInk,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Section Heading
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedTab == 0 ? 'Assigned Work to Complete' : 'Review & Decision History',
                          style: GoogleFonts.jetBrainsMono(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppTheme.foregroundInk,
                          ),
                        ),
                        Text(
                          '${displayedBriefs.length} items',
                          style: GoogleFonts.publicSans(
                            fontSize: 11,
                            color: AppTheme.faintInk,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (displayedBriefs.isEmpty)
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
                            Icon(
                              _selectedTab == 0 ? Icons.check_circle_outline : Icons.history,
                              size: 40,
                              color: AppTheme.faintInk,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _selectedTab == 0 ? 'All caught up!' : 'No submission history yet',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: AppTheme.foregroundInk,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _selectedTab == 0
                                  ? 'You have completed all active brief allotments.'
                                  : 'Completed submissions and approvals will appear here.',
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
                        itemCount: displayedBriefs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final brief = displayedBriefs[index];
                          return _buildBriefCard(context, brief);
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBriefCard(BuildContext context, DesignBriefModel brief) {
    Color badgeBg = AppTheme.badgeNeutralBg;
    Color badgeText = AppTheme.brandSteel;
    Color badgeBorder = AppTheme.badgeNeutralBorder;
    String statusLabel = brief.status.replaceAll('_', ' ');

    final isRejected = brief.status == 'PH_REJECTED';
    final isApproved = brief.status == 'PH_APPROVED' || brief.status == 'SA_APPROVED' || brief.status == 'TECH_PACK_CREATED';

    if (brief.status == 'SUBMITTED') {
      badgeBg = AppTheme.badgeAmberBg;
      badgeText = AppTheme.badgeAmberText;
      badgeBorder = AppTheme.badgeAmberBorder;
      statusLabel = 'In Review';
    } else if (isApproved) {
      badgeBg = AppTheme.badgeEmeraldBg;
      badgeText = AppTheme.badgeEmeraldText;
      badgeBorder = AppTheme.badgeEmeraldBorder;
      statusLabel = 'Approved';
    } else if (isRejected) {
      badgeBg = AppTheme.badgeRoseBg;
      badgeText = AppTheme.badgeRoseText;
      badgeBorder = AppTheme.badgeRoseBorder;
      statusLabel = 'Revisions Needed';
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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isRejected ? const Color(0xFFFECDD3) : AppTheme.standardBorder,
            width: isRejected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    brief.garmentType,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.foregroundInk,
                    ),
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
                    statusLabel.toUpperCase(),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9.5,
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
                  '•  ${brief.targetDesigns} Designs  •  ${brief.maxColors} Colors',
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
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.only(top: 10),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ID: ${brief.id.substring(0, brief.id.length > 6 ? 6 : brief.id.length)}',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      color: AppTheme.faintInk,
                    ),
                  ),
                  Row(
                    children: [
                      if (isRejected) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE11D48),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.refresh, size: 12, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(
                                'Redo Assignment',
                                style: GoogleFonts.publicSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        Text(
                          'Open Assignment',
                          style: GoogleFonts.publicSans(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.brandSteel,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_ios, size: 10, color: AppTheme.brandSteel),
                      ],
                    ],
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
