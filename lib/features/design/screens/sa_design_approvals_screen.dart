import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/zigza_app_bar.dart';
import '../../../core/widgets/zigza_section_header.dart';
import '../../modules/widgets/workspace_hub_drawer.dart';
import '../models/design_brief_model.dart';
import '../providers/designer_provider.dart';
import 'create_production_tech_pack_wizard.dart';
import 'design_studio_screen.dart';

class SARowItem {
  final String key;
  final String submissionId;
  final String briefId;
  final int conceptNumber;
  final String artNumber;
  final String baseArtNumber;
  final String colorName;
  final ConceptColorwayModel colorway;
  final String garment;
  final String category;
  final String designerName;
  final String? designerPhone;
  final bool isPHApproved;
  final bool isPHRejected;
  final String saVerdict; // 'APPROVED' | 'SAVED_FOR_LATER' | 'REJECTED' | 'PENDING'
  final String status;
  final String? phFeedback;
  final String? saNotes;
  final String? designerNotes;
  final DateTime? submittedAt;
  final DesignBriefModel? brief;

  const SARowItem({
    required this.key,
    required this.submissionId,
    required this.briefId,
    required this.conceptNumber,
    required this.artNumber,
    required this.baseArtNumber,
    required this.colorName,
    required this.colorway,
    required this.garment,
    required this.category,
    required this.designerName,
    this.designerPhone,
    required this.isPHApproved,
    required this.isPHRejected,
    required this.saVerdict,
    required this.status,
    this.phFeedback,
    this.saNotes,
    this.designerNotes,
    this.submittedAt,
    this.brief,
  });
}

class SADesignApprovalsScreen extends ConsumerStatefulWidget {
  const SADesignApprovalsScreen({super.key});

  @override
  ConsumerState<SADesignApprovalsScreen> createState() => _SADesignApprovalsScreenState();
}

class _SADesignApprovalsScreenState extends ConsumerState<SADesignApprovalsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String _activeTab = 'ALL';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(designerProvider.notifier).fetchStudioData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getVariantArtNumber(String baseArtNo, int index, int totalCount) {
    if (baseArtNo.isEmpty) return '';
    if (totalCount <= 1) return baseArtNo;
    final suffix = (index + 1).toString().padLeft(2, '0');
    return '$baseArtNo-$suffix';
  }

  Color _getColorSwatchBg(String colorName) {
    final norm = colorName.trim().toLowerCase();
    if (norm.contains('black')) return const Color(0xFF111111);
    if (norm.contains('white')) return const Color(0xFFFFFFFF);
    if (norm.contains('navy')) return const Color(0xFF1B2A4A);
    if (norm.contains('olive')) return const Color(0xFF556B2F);
    if (norm.contains('grey') || norm.contains('gray')) return const Color(0xFF718096);
    if (norm.contains('red') || norm.contains('maroon') || norm.contains('crimson')) return const Color(0xFFC53030);
    if (norm.contains('beige') || norm.contains('cream') || norm.contains('khaki') || norm.contains('sand')) return const Color(0xFFF5F5DC);
    if (norm.contains('blue') || norm.contains('cyan') || norm.contains('sky')) return const Color(0xFF2B6CB0);
    if (norm.contains('green') || norm.contains('mint') || norm.contains('emerald')) return const Color(0xFF276749);
    if (norm.contains('yellow') || norm.contains('mustard') || norm.contains('gold')) return const Color(0xFFECC94B);
    if (norm.contains('pink') || norm.contains('rose') || norm.contains('fuchsia')) return const Color(0xFFD53F8C);
    if (norm.contains('orange') || norm.contains('coral') || norm.contains('rust')) return const Color(0xFFDD6B20);
    if (norm.contains('brown') || norm.contains('tan') || norm.contains('chocolate')) return const Color(0xFF7B341E);
    if (norm.contains('purple') || norm.contains('violet') || norm.contains('lavender')) return const Color(0xFF6B46C1);
    return const Color(0xFF332B6B);
  }

  List<SARowItem> _deriveSARows(DesignerState studioState) {
    final List<SARowItem> rows = [];
    final briefById = <String, DesignBriefModel>{
      for (final b in studioState.briefs) b.id: b,
    };

    // Combine direct PH-approved submissions (matching Web fetchDesignSubmissionsAction)
    // with any embedded brief submissions, deduplicated by submission id.
    final Map<String, DesignSubmissionModel> subMap = {};
    for (final s in studioState.approvedSubmissions) {
      if (s.id.isNotEmpty) subMap[s.id] = s;
    }
    for (final brief in studioState.briefs) {
      for (final s in brief.submissions) {
        if (s.id.isNotEmpty &&
            s.phVerdict.toUpperCase() == 'APPROVED' &&
            !subMap.containsKey(s.id)) {
          subMap[s.id] = s.copyWith(brief: s.brief ?? brief);
        }
      }
    }

    for (final sub in subMap.values) {
      final brief = sub.brief ?? briefById[sub.briefId];
      final instructedConcepts =
          brief?.safeDesignConceptsBrief ?? const <BriefDesignConceptRequirementModel>[];
      final subConcepts = sub.safeConcepts;
      final subSubmittedAt = DateTime.tryParse(sub.submittedAt);

      if (subConcepts.isNotEmpty) {
        for (int cIdx = 0; cIdx < subConcepts.length; cIdx++) {
          final concept = subConcepts[cIdx];
          final cNum = concept.conceptNumber ?? (cIdx + 1);
          final instructedReq =
              instructedConcepts.where((b) => b.conceptNumber == cNum).firstOrNull;

          final baseArtNo = concept.artNumber?.trim().isNotEmpty == true
              ? concept.artNumber!.trim()
              : (instructedReq?.artNumber?.trim().isNotEmpty == true
                  ? instructedReq!.artNumber!.trim()
                  : 'DEMO-10$cNum');

          final garmentMatch = RegExp(r'Garment:\s*([^|]+)', caseSensitive: false)
              .firstMatch(instructedReq?.notes ?? '');
          final rawBriefGarment = brief?.garmentType ?? '';
          final garmentParts = rawBriefGarment.split(',');
          final garment = garmentMatch?.group(1)?.trim() ??
              (garmentParts.length >= cNum && garmentParts[cNum - 1].trim().isNotEmpty
                  ? garmentParts[cNum - 1].trim()
                  : rawBriefGarment.trim());

          final category = concept.title.trim().isNotEmpty
              ? concept.title.trim()
              : (instructedReq?.categoryStyle?.trim().isNotEmpty == true
                  ? instructedReq!.categoryStyle!.trim()
                  : (brief != null && brief.category.trim().isNotEmpty
                      ? brief.category.trim()
                      : 'Casual'));

          final colorways = concept.safeColorways;

          if (colorways.isNotEmpty) {
            for (int cwIdx = 0; cwIdx < colorways.length; cwIdx++) {
              final cw = colorways[cwIdx];
              final variantArtNo = _getVariantArtNumber(baseArtNo, cwIdx, colorways.length);

              if (cw.status == 'REJECTED') continue;
              if (cw.status == null && concept.phVerdict == 'REJECTED') continue;
              if (cw.status == null &&
                  concept.phVerdict == null &&
                  sub.phVerdict == 'REJECTED') {
                continue;
              }
              if (cw.status == null &&
                  concept.phVerdict == null &&
                  sub.phVerdict != 'APPROVED') {
                continue;
              }

              final isPHApproved = cw.status == 'APPROVED' ||
                  (cw.status == null && concept.phVerdict == 'APPROVED') ||
                  sub.phVerdict == 'APPROVED';
              if (!isPHApproved) continue;

              final saVerdict =
                  (cw.saVerdict ?? concept.saVerdict ?? sub.saVerdict ?? 'PENDING')
                      .toUpperCase();
              final status = saVerdict == 'APPROVED'
                  ? 'SA_APPROVED'
                  : saVerdict == 'SAVED_FOR_LATER'
                      ? 'SA_SAVED_FOR_LATER'
                      : saVerdict == 'REJECTED'
                          ? 'PH_REJECTED'
                          : 'PH_APPROVED';

              rows.add(SARowItem(
                key: '${sub.id}-c-$cNum-cw-${cw.colorName}-$cwIdx',
                submissionId: sub.id,
                briefId: sub.briefId,
                conceptNumber: cNum,
                artNumber: variantArtNo,
                baseArtNumber: baseArtNo,
                colorName: cw.colorName,
                colorway: cw,
                garment: garment.isEmpty ? 'Apparel' : garment,
                category: category,
                designerName: sub.designerName ?? brief?.designerName ?? 'Designer',
                designerPhone: brief?.designerPhone,
                isPHApproved: true,
                isPHRejected: false,
                saVerdict: saVerdict,
                status: status,
                phFeedback: concept.phFeedback ?? sub.phFeedback,
                saNotes: cw.saNotes ?? concept.saNotes ?? sub.saNotes,
                designerNotes: concept.notes ?? sub.cleanDesignerNotes ?? sub.designerNotes,
                submittedAt: subSubmittedAt,
                brief: brief,
              ));
            }
          } else {
            if (concept.phVerdict == 'REJECTED' || sub.phVerdict == 'REJECTED') continue;
            final isPHApproved =
                concept.phVerdict == 'APPROVED' || sub.phVerdict == 'APPROVED';
            if (!isPHApproved) continue;

            final saVerdict =
                (concept.saVerdict ?? sub.saVerdict ?? 'PENDING').toUpperCase();
            final status = saVerdict == 'APPROVED'
                ? 'SA_APPROVED'
                : saVerdict == 'SAVED_FOR_LATER'
                    ? 'SA_SAVED_FOR_LATER'
                    : saVerdict == 'REJECTED'
                        ? 'PH_REJECTED'
                        : 'PH_APPROVED';

            rows.add(SARowItem(
              key: '${sub.id}-c-$cNum',
              submissionId: sub.id,
              briefId: sub.briefId,
              conceptNumber: cNum,
              artNumber: baseArtNo,
              baseArtNumber: baseArtNo,
              colorName: 'Standard',
              colorway: ConceptColorwayModel(
                colorName: 'Standard',
                photoFront: sub.photoUrl1,
                photoBack: sub.photoUrl2,
              ),
              garment: garment.isEmpty ? 'Apparel' : garment,
              category: category,
              designerName: sub.designerName ?? brief?.designerName ?? 'Designer',
              designerPhone: brief?.designerPhone,
              isPHApproved: true,
              isPHRejected: false,
              saVerdict: saVerdict,
              status: status,
              phFeedback: concept.phFeedback ?? sub.phFeedback,
              saNotes: concept.saNotes ?? sub.saNotes,
              designerNotes: concept.notes ?? sub.cleanDesignerNotes ?? sub.designerNotes,
              submittedAt: subSubmittedAt,
              brief: brief,
            ));
          }
        }
      } else if (sub.phVerdict == 'APPROVED') {
        final artNo =
            brief?.safeDesignConceptsBrief.firstOrNull?.artNumber ?? 'DEMO-101';
        final garment =
            (brief != null && brief.garmentType.isNotEmpty) ? brief.garmentType : 'Apparel';
        final category =
            (brief != null && brief.category.isNotEmpty) ? brief.category : 'Casual';
        final saVerdict = (sub.saVerdict ?? 'PENDING').toUpperCase();
        final defaultColor = (brief != null && brief.targetColors.isNotEmpty)
            ? brief.targetColors.first
            : 'Default';

        rows.add(SARowItem(
          key: '${sub.id}-c-1',
          submissionId: sub.id,
          briefId: sub.briefId,
          conceptNumber: 1,
          artNumber: artNo,
          baseArtNumber: artNo,
          colorName: defaultColor,
          colorway: ConceptColorwayModel(
            colorName: defaultColor,
            photoFront: sub.photoUrl1,
            photoBack: sub.photoUrl2,
          ),
          garment: garment,
          category: category,
          designerName: sub.designerName ?? brief?.designerName ?? 'Designer',
          designerPhone: brief?.designerPhone,
          isPHApproved: true,
          isPHRejected: false,
          saVerdict: saVerdict,
          status: saVerdict == 'APPROVED'
              ? 'SA_APPROVED'
              : saVerdict == 'SAVED_FOR_LATER'
                  ? 'SA_SAVED_FOR_LATER'
                  : 'PH_APPROVED',
          phFeedback: sub.phFeedback,
          saNotes: sub.saNotes,
          designerNotes: sub.cleanDesignerNotes ?? sub.designerNotes,
          submittedAt: subSubmittedAt,
          brief: brief,
        ));
      }
    }

    return rows;
  }

  void _showImageLightbox(BuildContext context, String imageUrl, String title) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 520, maxWidth: 500),
          decoration: BoxDecoration(
            color: AppTheme.cardSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderLight),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: zigzaHeadingStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: AppTheme.bodyInk),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Flexible(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Container(
                      height: 220,
                      color: AppTheme.bgCanvas,
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image_rounded, color: AppTheme.faintInk, size: 40),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMockupPreviewCard(
    BuildContext context, {
    required String? photoUrl,
    required String label,
    required String emptyLabel,
    required String lightboxTitle,
  }) {
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return InkWell(
        onTap: () => _showImageLightbox(context, photoUrl, lightboxTitle),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 155,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppTheme.bgCanvas,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderLight),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  photoUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(Icons.image_not_supported_outlined, color: AppTheme.faintInk),
                  ),
                ),
              ),
              Positioned(
                bottom: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.borderLight),
                  ),
                  child: Text(
                    label,
                    style: zigzaHeadingStyle(fontSize: 9.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Container(
      height: 155,
      decoration: BoxDecoration(
        color: AppTheme.bgCanvas,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderLight),
      ),
      alignment: Alignment.center,
      child: Text(
        emptyLabel,
        style: zigzaBodyStyle(fontSize: 11.5, color: AppTheme.faintInk),
      ),
    );
  }

  void _showDecisionSheet(BuildContext context, SARowItem item) {
    final notesController = TextEditingController(text: item.saNotes ?? '');
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final swColor = _getColorSwatchBg(item.colorName);

            Future<void> submitVerdict(String verdict) async {
              setModalState(() => isSaving = true);
              final success = await ref.read(designerProvider.notifier).saReviewDesignSubmission(
                    submissionId: item.submissionId,
                    briefId: item.briefId,
                    conceptNumber: item.conceptNumber,
                    colorwayName: item.colorName,
                    saVerdict: verdict,
                    saNotes: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
                  );

              if (ctx.mounted) {
                Navigator.pop(ctx);
                if (success) {
                  final msg = verdict == 'APPROVED'
                      ? 'Design ${item.artNumber} greenlit! Ready for Tech-Pack.'
                      : verdict == 'SAVED_FOR_LATER'
                          ? 'Design ${item.artNumber} saved in Archive.'
                          : 'Design ${item.artNumber} returned for revisions.';

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: verdict == 'APPROVED'
                          ? AppTheme.badgeEmeraldText
                          : AppTheme.brandRoyalBlue,
                      content: Row(
                        children: [
                          Icon(
                            verdict == 'APPROVED'
                                ? Icons.check_circle_outline
                                : Icons.bookmark_outline,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              msg,
                              style: zigzaBodyStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      action: verdict == 'APPROVED'
                          ? SnackBarAction(
                              label: 'Create Tech-Pack',
                              textColor: const Color(0xFFFDE047),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const CreateProductionTechPackWizard(),
                                  ),
                                );
                              },
                            )
                          : null,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppTheme.badgeRoseText,
                      content: Text(
                        'Failed to record decision. Please retry.',
                        style: zigzaBodyStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  );
                }
              }
            }

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(modalCtx).viewInsets.bottom),
              child: Container(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.fromLTRB(18, 16, 12, 14),
                        decoration: const BoxDecoration(
                          color: AppTheme.mintSurface,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                          border: Border(bottom: BorderSide(color: AppTheme.borderLight)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                        decoration: BoxDecoration(
                                          color: AppTheme.badgeEmeraldBg,
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: AppTheme.badgeEmeraldBorder),
                                        ),
                                        child: Text(
                                          'PH Approved',
                                          style: zigzaHeadingStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.badgeEmeraldText,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: AppTheme.borderLight),
                                        ),
                                        child: Text(
                                          'ART ${item.artNumber}',
                                          style: zigzaHeadingStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: AppTheme.headingObsidian,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${item.garment} (${item.category})',
                                    style: zigzaHeadingStyle(fontSize: 16, fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: swColor,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.black26),
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        item.colorName,
                                        style: zigzaHeadingStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          '• ${item.designerName}',
                                          style: zigzaBodyStyle(fontSize: 12, color: AppTheme.bodyInk),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: AppTheme.bodyInk),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                      ),

                      // Content Body
                      Flexible(
                        child: ListView(
                          shrinkWrap: true,
                          padding: const EdgeInsets.all(16),
                          children: [
                            Text(
                              'ARTWORK MOCKUPS',
                              style: zigzaHeadingStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.bodyInk,
                                letterSpacing: 0.4,
                              ),
                            ),
                            const SizedBox(height: 8),

                            Row(
                              children: [
                                Expanded(
                                  child: _buildMockupPreviewCard(
                                    context,
                                    photoUrl: item.colorway.photoFront,
                                    label: 'Front View',
                                    emptyLabel: 'No Front View',
                                    lightboxTitle: '${item.artNumber} - Front View',
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildMockupPreviewCard(
                                    context,
                                    photoUrl: item.colorway.photoBack,
                                    label: 'Back View',
                                    emptyLabel: 'No Back View',
                                    lightboxTitle: '${item.artNumber} - Back View',
                                  ),
                                ),
                              ],
                            ),

                            if (item.designerNotes != null && item.designerNotes!.trim().isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.bgCanvas,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppTheme.borderLight),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'DESIGNER NOTES',
                                      style: zigzaHeadingStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.bodyInk,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      item.designerNotes!,
                                      style: zigzaBodyStyle(fontSize: 12.5, color: AppTheme.headingObsidian),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            if (item.phFeedback != null && item.phFeedback!.trim().isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.badgeBlueBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppTheme.badgeBlueBorder),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'SUPERVISOR NOTES',
                                      style: zigzaHeadingStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.brandRoyalBlue,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      item.phFeedback!,
                                      style: zigzaBodyStyle(fontSize: 12.5, color: AppTheme.headingObsidian),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 14),
                            Text(
                              'DECISION NOTES',
                              style: zigzaHeadingStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.bodyInk,
                                letterSpacing: 0.4,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: notesController,
                              maxLines: 2,
                              decoration: InputDecoration(
                                hintText: 'Add review notes (optional)...',
                                hintStyle: zigzaBodyStyle(fontSize: 12.5, color: AppTheme.faintInk),
                                filled: true,
                                fillColor: AppTheme.bgCanvas,
                                contentPadding: const EdgeInsets.all(12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppTheme.borderLight),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppTheme.borderLight),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppTheme.headingObsidian, width: 1.3),
                                ),
                              ),
                              style: zigzaBodyStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.headingObsidian,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Footer Actions
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border(top: BorderSide(color: AppTheme.borderLight)),
                        ),
                        child: isSaving
                            ? const SizedBox(
                                height: 48,
                                child: Center(child: CircularProgressIndicator(color: AppTheme.brandRoyalBlue)),
                              )
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppTheme.badgeRoseText,
                                            backgroundColor: AppTheme.badgeRoseBg,
                                            side: const BorderSide(color: AppTheme.badgeRoseBorder),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                                            padding: const EdgeInsets.symmetric(vertical: 11),
                                          ),
                                          onPressed: () => submitVerdict('REJECTED'),
                                          icon: const Icon(Icons.cancel_outlined, size: 16),
                                          label: Text(
                                            'Revisions',
                                            style: zigzaHeadingStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w700,
                                              color: AppTheme.badgeRoseText,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppTheme.headingObsidian,
                                            backgroundColor: Colors.white,
                                            side: const BorderSide(color: AppTheme.borderLight),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                                            padding: const EdgeInsets.symmetric(vertical: 11),
                                          ),
                                          onPressed: () => submitVerdict('SAVED_FOR_LATER'),
                                          icon: const Icon(Icons.bookmark_border_rounded, size: 16, color: AppTheme.brandRoyalBlue),
                                          label: Text(
                                            'Save Later',
                                            style: zigzaHeadingStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w700,
                                              color: AppTheme.headingObsidian,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF059669),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        elevation: 0,
                                      ),
                                      onPressed: () => submitVerdict('APPROVED'),
                                      icon: const Icon(Icons.check_circle_rounded, size: 18),
                                      label: Text(
                                        'Greenlight for Tech-Pack',
                                        style: zigzaHeadingStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String label,
    required int count,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: AppTheme.bgCanvas,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: zigzaBodyStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.bodyInk,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: AppTheme.mintSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.badgeMintBorder),
                ),
                child: Icon(icon, color: const Color(0xFF0F766E), size: 13.5),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$count',
            style: zigzaHeadingStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppTheme.headingObsidian,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(designerProvider);
    final allRows = _deriveSARows(state);

    final pendingItems = allRows.where((r) => r.isPHApproved && (r.saVerdict == 'PENDING' || r.saVerdict.isEmpty)).toList();
    final approvedItems = allRows.where((r) => r.saVerdict == 'APPROVED').toList();
    final savedItems = allRows.where((r) => r.saVerdict == 'SAVED_FOR_LATER').toList();
    final rejectedItems = allRows.where((r) => r.saVerdict == 'REJECTED').toList();

    final filteredList = allRows.where((r) {
      if (_activeTab == 'PENDING') {
        if (!(r.isPHApproved && (r.saVerdict == 'PENDING' || r.saVerdict.isEmpty))) return false;
      } else if (_activeTab == 'APPROVED') {
        if (r.saVerdict != 'APPROVED') return false;
      } else if (_activeTab == 'SAVED_FOR_LATER') {
        if (r.saVerdict != 'SAVED_FOR_LATER') return false;
      } else if (_activeTab == 'REJECTED') {
        if (r.saVerdict != 'REJECTED') return false;
      }

      final q = _searchQuery.trim().toLowerCase();
      if (q.isEmpty) return true;

      final art = r.artNumber.toLowerCase();
      final garment = r.garment.toLowerCase();
      final cat = r.category.toLowerCase();
      final col = r.colorName.toLowerCase();
      final designer = r.designerName.toLowerCase();
      final notes = (r.designerNotes ?? '').toLowerCase();

      return art.contains(q) || garment.contains(q) || cat.contains(q) || col.contains(q) || designer.contains(q) || notes.contains(q);
    }).toList();

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppTheme.bgCanvas,
      appBar: ZigzaAppBar(
        onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      drawer: const WorkspaceHubDrawer(activeRoute: '/all-designs'),
      body: state.isLoading && allRows.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppTheme.headingObsidian))
          : RefreshIndicator(
              color: AppTheme.brandRoyalBlue,
              backgroundColor: Colors.white,
              onRefresh: () => ref.read(designerProvider.notifier).fetchStudioData(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                children: [
                  // 1. Compact Header Card
                  _buildSectionCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.mintSurface,
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(color: AppTheme.badgeMintBorder),
                          ),
                          child: const Icon(Icons.shield_outlined, color: Color(0xFF0F766E), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text.rich(
                                TextSpan(
                                  style: zigzaHeadingStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                  ),
                                  children: const [
                                    TextSpan(text: 'Approved '),
                                    TextSpan(
                                      text: 'Designs',
                                      style: TextStyle(color: AppTheme.brandRoyalBlue),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.mintSurface,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppTheme.badgeMintBorder),
                                ),
                                child: Text(
                                  '${pendingItems.length} Awaiting Decision',
                                  style: zigzaHeadingStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0F766E),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const DesignStudioScreen()),
                            );
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                              color: AppTheme.bgCanvas,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.borderLight),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.chevron_left_rounded, color: AppTheme.bodyInk, size: 16),
                                const SizedBox(width: 2),
                                Text(
                                  'Studio',
                                  style: zigzaHeadingStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.headingObsidian,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 2. Design Overview (2x2 Inset KPI Grid)
                  _buildSectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ZigzaSectionHeader(
                          icon: Icons.analytics_outlined,
                          title: 'Design',
                          accent: 'Overview',
                          badge: '${allRows.length} Total',
                        ),
                        const SizedBox(height: 12),
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 1.65,
                          children: [
                            _buildKpiCard(
                              label: 'TOTAL DESIGNS',
                              count: allRows.length,
                              icon: Icons.layers_outlined,
                            ),
                            _buildKpiCard(
                              label: 'AWAITING DECISION',
                              count: pendingItems.length,
                              icon: Icons.access_time_rounded,
                            ),
                            _buildKpiCard(
                              label: 'APPROVED',
                              count: approvedItems.length,
                              icon: Icons.check_circle_outline_rounded,
                            ),
                            _buildKpiCard(
                              label: 'ARCHIVE',
                              count: savedItems.length,
                              icon: Icons.bookmark_border_rounded,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 3. Design Ledger Container (Box-inside-Box)
                  _buildSectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ZigzaSectionHeader(
                          icon: Icons.checkroom_outlined,
                          title: 'Design',
                          accent: 'Ledger',
                          badge: '${filteredList.length}',
                        ),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildTabChip('ALL', 'All (${allRows.length})'),
                              const SizedBox(width: 7),
                              _buildTabChip('APPROVED', 'Approved (${approvedItems.length})'),
                              const SizedBox(width: 7),
                              _buildTabChip('REJECTED', 'Revisions (${rejectedItems.length})'),
                              if (pendingItems.isNotEmpty) ...[
                                const SizedBox(width: 7),
                                _buildTabChip('PENDING', 'Pending (${pendingItems.length})'),
                              ],
                              const SizedBox(width: 7),
                              _buildTabChip('SAVED_FOR_LATER', 'Archive (${savedItems.length})'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _searchController,
                          onChanged: (val) => setState(() => _searchQuery = val),
                          decoration: InputDecoration(
                            hintText: 'Search art no, color, garment...',
                            hintStyle: zigzaBodyStyle(fontSize: 12.5, color: AppTheme.faintInk),
                            prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppTheme.faintInk),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 16, color: AppTheme.bodyInk),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: AppTheme.bgCanvas,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppTheme.borderLight),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppTheme.borderLight),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppTheme.headingObsidian, width: 1.3),
                            ),
                          ),
                          style: zigzaBodyStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.headingObsidian,
                          ),
                        ),
                        const SizedBox(height: 12),

                        if (filteredList.isEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                            decoration: BoxDecoration(
                              color: AppTheme.bgCanvas,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppTheme.borderLight),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppTheme.mintSurface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppTheme.badgeMintBorder),
                                  ),
                                  child: const Icon(Icons.shield_outlined, color: Color(0xFF0F766E), size: 22),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No Designs Found',
                                  style: zigzaHeadingStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Supervisor-approved designs appear here for executive review.',
                                  style: zigzaBodyStyle(fontSize: 12, color: AppTheme.bodyInk),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filteredList.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (ctx, idx) => _buildApprovalCard(context, filteredList[idx]),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
    );
  }

  Widget _buildTabChip(String tabKey, String label) {
    final isActive = _activeTab == tabKey;
    return InkWell(
      onTap: () => setState(() => _activeTab = tabKey),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF14C8B4) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? const Color(0xFF14C8B4) : AppTheme.borderLight,
          ),
          boxShadow: isActive
              ? const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: zigzaHeadingStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
            color: isActive ? AppTheme.headingObsidian : AppTheme.bodyInk,
          ),
        ),
      ),
    );
  }

  Widget? _buildStatusPill({
    required bool isPendingSA,
    required bool isGreenlit,
    required bool isSaved,
    required bool isRejected,
  }) {
    late final Color bg;
    late final Color border;
    late final Color fg;
    late final String label;

    if (isPendingSA) {
      bg = const Color(0xFFFFFBEB);
      border = const Color(0xFFFDE68A);
      fg = const Color(0xFF92400E);
      label = 'Pending';
    } else if (isGreenlit) {
      bg = const Color(0xFFECFDF5);
      border = const Color(0xFFA7F3D0);
      fg = const Color(0xFF065F46);
      label = 'Greenlit';
    } else if (isSaved) {
      bg = AppTheme.mintSurface;
      border = AppTheme.badgeMintBorder;
      fg = const Color(0xFF0F766E);
      label = 'Archived';
    } else if (isRejected) {
      bg = const Color(0xFFFFF1F2);
      border = const Color(0xFFFECDD3);
      fg = const Color(0xFFBE123C);
      label = 'Revisions';
    } else {
      return null;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: zigzaHeadingStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildApprovalCard(BuildContext context, SARowItem item) {
    final isPendingSA = item.isPHApproved && (item.saVerdict == 'PENDING' || item.saVerdict.isEmpty);
    final isGreenlit = item.saVerdict == 'APPROVED';
    final isSaved = item.saVerdict == 'SAVED_FOR_LATER';
    final isRejected = item.saVerdict == 'REJECTED';

    final swColor = _getColorSwatchBg(item.colorName);
    final hasPhoto = item.colorway.photoFront != null && item.colorway.photoFront!.isNotEmpty;
    final notePreview = (item.saNotes != null && item.saNotes!.trim().isNotEmpty)
        ? item.saNotes!.trim()
        : (item.designerNotes != null && item.designerNotes!.trim().isNotEmpty)
            ? item.designerNotes!.trim()
            : null;
    final statusPill = _buildStatusPill(
      isPendingSA: isPendingSA,
      isGreenlit: isGreenlit,
      isSaved: isSaved,
      isRejected: isRejected,
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgCanvas,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Thumbnail + Art Number/Garment + Status Pill
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasPhoto)
                Padding(
                  padding: const EdgeInsets.only(right: 11),
                  child: InkWell(
                    onTap: () => _showImageLightbox(context, item.colorway.photoFront!, '${item.artNumber} - Front View'),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 48,
                      height: 48,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: AppTheme.cardSurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.borderLight),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: Image.network(
                          item.colorway.photoFront!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.broken_image_rounded,
                            size: 20,
                            color: AppTheme.faintInk,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.artNumber,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: zigzaHeadingStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.headingObsidian,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: AppTheme.cardSurface,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.borderLight),
                          ),
                          child: Text(
                            '#${item.conceptNumber}',
                            style: zigzaHeadingStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.bodyInk,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.garment,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: zigzaHeadingStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.headingObsidian,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      item.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: zigzaBodyStyle(
                        fontSize: 11.5,
                        color: AppTheme.bodyInk,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (statusPill != null) ...[
                const SizedBox(width: 8),
                statusPill,
              ],
            ],
          ),
          const SizedBox(height: 11),

          // Inner White Box: Designer & Colorway
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.cardSurface,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DESIGNER',
                        style: zigzaBodyStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.faintInk,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.designerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: zigzaBodyStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.headingObsidian,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'COLORWAY',
                        style: zigzaBodyStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.faintInk,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: swColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black26),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              item.colorName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: zigzaBodyStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.headingObsidian,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (notePreview != null) ...[
            const SizedBox(height: 8),
            Text(
              notePreview,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: zigzaBodyStyle(
                fontSize: 11.5,
                color: AppTheme.bodyInk,
              ),
            ),
          ],

          const SizedBox(height: 11),

          // Action Button: View & Decide
          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.brandRoyalBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              onPressed: () => _showDecisionSheet(context, item),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.visibility_outlined, size: 15.5),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      'View & Decide ${item.artNumber}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: zigzaHeadingStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
