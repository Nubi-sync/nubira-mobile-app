import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/widgets/zigza_app_bar.dart';
import '../../modules/widgets/workspace_hub_drawer.dart';
import '../models/design_brief_model.dart';
import '../providers/designer_provider.dart';
import 'create_production_tech_pack_wizard.dart';

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
  final DesignBriefModel brief;

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
    required this.brief,
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

  List<SARowItem> _deriveSARows(List<DesignBriefModel> briefs) {
    final List<SARowItem> rows = [];

    for (final brief in briefs) {
      final subs = brief.submissions;
      if (subs.isEmpty) continue;

      for (final sub in subs) {
        final instructedConcepts = brief.safeDesignConceptsBrief;
        final subConcepts = sub.safeConcepts;
        final subSubmittedAt = DateTime.tryParse(sub.submittedAt);

        if (subConcepts.isNotEmpty) {
          for (int cIdx = 0; cIdx < subConcepts.length; cIdx++) {
            final concept = subConcepts[cIdx];
            final cNum = concept.conceptNumber ?? (cIdx + 1);
            final instructedReq = instructedConcepts.where((b) => b.conceptNumber == cNum).firstOrNull;

            final baseArtNo = concept.artNumber?.trim().isNotEmpty == true
                ? concept.artNumber!.trim()
                : (instructedReq?.artNumber?.trim().isNotEmpty == true
                    ? instructedReq!.artNumber!.trim()
                    : 'DEMO-10$cNum');

            final garmentMatch = RegExp(r'Garment:\s*([^|]+)', caseSensitive: false).firstMatch(instructedReq?.notes ?? '');
            final garment = garmentMatch?.group(1)?.trim() ??
                (brief.garmentType.split(',').length >= cNum
                    ? brief.garmentType.split(',')[cNum - 1].trim()
                    : brief.garmentType);

            final category = concept.title.trim().isNotEmpty == true
                ? concept.title.trim()
                : (instructedReq?.categoryStyle?.trim().isNotEmpty == true
                    ? instructedReq!.categoryStyle!.trim()
                    : (brief.category.trim().isNotEmpty ? brief.category.trim() : 'Casual'));

            final colorways = concept.safeColorways;

            if (colorways.isNotEmpty) {
              for (int cwIdx = 0; cwIdx < colorways.length; cwIdx++) {
                final cw = colorways[cwIdx];
                final variantArtNo = _getVariantArtNumber(baseArtNo, cwIdx, colorways.length);

                if (cw.status == 'REJECTED') continue;
                if (cw.status == null && concept.phVerdict == 'REJECTED') continue;
                if (cw.status == null && concept.phVerdict == null && sub.phVerdict == 'REJECTED') continue;
                if (cw.status == null && concept.phVerdict == null && sub.phVerdict != 'APPROVED') continue;

                final isPHApproved = cw.status == 'APPROVED' ||
                    (cw.status == null && concept.phVerdict == 'APPROVED') ||
                    sub.phVerdict == 'APPROVED';
                if (!isPHApproved) continue;

                final saVerdict = (cw.saVerdict ?? concept.saVerdict ?? sub.saVerdict ?? 'PENDING').toUpperCase();
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
                  designerName: sub.designerName ?? brief.designerName ?? 'Designer',
                  designerPhone: brief.designerPhone,
                  isPHApproved: true,
                  isPHRejected: false,
                  saVerdict: saVerdict,
                  status: status,
                  phFeedback: concept.phFeedback ?? sub.phFeedback,
                  saNotes: cw.saNotes ?? concept.saNotes ?? sub.saNotes,
                  designerNotes: concept.notes ?? sub.designerNotes,
                  submittedAt: subSubmittedAt,
                  brief: brief,
                ));
              }
            } else {
              // Fallback without sub-colorways
              if (concept.phVerdict == 'REJECTED' || sub.phVerdict == 'REJECTED') continue;
              final isPHApproved = concept.phVerdict == 'APPROVED' || sub.phVerdict == 'APPROVED';
              if (!isPHApproved) continue;

              final saVerdict = (concept.saVerdict ?? sub.saVerdict ?? 'PENDING').toUpperCase();
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
                designerName: sub.designerName ?? brief.designerName ?? 'Designer',
                designerPhone: brief.designerPhone,
                isPHApproved: true,
                isPHRejected: false,
                saVerdict: saVerdict,
                status: status,
                phFeedback: concept.phFeedback ?? sub.phFeedback,
                saNotes: concept.saNotes ?? sub.saNotes,
                designerNotes: concept.notes ?? sub.designerNotes,
                submittedAt: subSubmittedAt,
                brief: brief,
              ));
            }
          }
        } else if (sub.phVerdict == 'APPROVED') {
          final artNo = brief.safeDesignConceptsBrief.firstOrNull?.artNumber ?? 'DEMO-101';
          final garment = brief.garmentType.isNotEmpty ? brief.garmentType : 'Apparel';
          final category = brief.category.isNotEmpty ? brief.category : 'Casual';
          final saVerdict = (sub.saVerdict ?? 'PENDING').toUpperCase();

          rows.add(SARowItem(
            key: '${sub.id}-c-1',
            submissionId: sub.id,
            briefId: sub.briefId,
            conceptNumber: 1,
            artNumber: artNo,
            baseArtNumber: artNo,
            colorName: brief.targetColors.isNotEmpty ? brief.targetColors.first : 'Default',
            colorway: ConceptColorwayModel(
              colorName: brief.targetColors.isNotEmpty ? brief.targetColors.first : 'Default',
              photoFront: sub.photoUrl1,
              photoBack: sub.photoUrl2,
            ),
            garment: garment,
            category: category,
            designerName: sub.designerName ?? brief.designerName ?? 'Designer',
            designerPhone: brief.designerPhone,
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
            designerNotes: sub.designerNotes,
            submittedAt: subSubmittedAt,
            brief: brief,
          ));
        }
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
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              constraints: const BoxConstraints(maxHeight: 520, maxWidth: 500),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black12),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Container(
                          height: 220,
                          color: const Color(0xFFFAF7F0),
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image_rounded, color: Colors.grey, size: 40),
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
                      ? 'Design ${item.artNumber} greenlit! Ready for Tech-Pack creation.'
                      : verdict == 'SAVED_FOR_LATER'
                          ? 'Design ${item.artNumber} saved in Seasonal Archive.'
                          : 'Design ${item.artNumber} returned for revisions.';

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: verdict == 'APPROVED' ? const Color(0xFF059669) : const Color(0xFF332B6B),
                      content: Row(
                        children: [
                          Icon(
                            verdict == 'APPROVED' ? Icons.check_circle_outline : Icons.bookmark_outline,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              msg,
                              style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
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
                    const SnackBar(
                      backgroundColor: Color(0xFFE11D48),
                      content: Text('Failed to record SA decision. Please retry.'),
                    ),
                  );
                }
              }
            }

            return Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFAFAF8),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                      border: Border(bottom: BorderSide(color: Color(0x1A000000))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFECFDF5),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFA7F3D0)),
                                    ),
                                    child: Text(
                                      'PH Approved',
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF065F46),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0x1A000000)),
                                    ),
                                    child: Text(
                                      'ART NO: ${item.artNumber}',
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${item.garment} (${item.category})',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
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
                                  const SizedBox(width: 4),
                                  Text(
                                    item.colorName,
                                    style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF334155)),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '• Designer: ${item.designerName}',
                                    style: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),

                  // Content Body
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        Text(
                          'ARTWORK MOCKUPS (${item.artNumber})',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF475569),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Front and Back images
                        Row(
                          children: [
                            // Front View
                            Expanded(
                              child: item.colorway.photoFront != null && item.colorway.photoFront!.isNotEmpty
                                  ? InkWell(
                                      onTap: () => _showImageLightbox(context, item.colorway.photoFront!, '${item.artNumber} - Front View'),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        height: 160,
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFAF7F0),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: const Color(0x1A000000)),
                                        ),
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: Image.network(
                                                item.colorway.photoFront!,
                                                fit: BoxFit.contain,
                                                errorBuilder: (_, __, ___) => const Center(
                                                  child: Icon(Icons.image_not_supported_outlined, color: Colors.grey),
                                                ),
                                              ),
                                            ),
                                            Positioned(
                                              bottom: 4,
                                              left: 4,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withValues(alpha: 0.9),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: const Color(0x1A000000)),
                                                ),
                                                child: Text(
                                                  'Front View',
                                                  style: GoogleFonts.jetBrainsMono(fontSize: 8.5, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  : Container(
                                      height: 160,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0x1A000000)),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        'No Front View',
                                        style: GoogleFonts.publicSans(fontSize: 11, color: const Color(0xFF94A3B8)),
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 10),

                            // Back View
                            Expanded(
                              child: item.colorway.photoBack != null && item.colorway.photoBack!.isNotEmpty
                                  ? InkWell(
                                      onTap: () => _showImageLightbox(context, item.colorway.photoBack!, '${item.artNumber} - Back View'),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        height: 160,
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFAF7F0),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: const Color(0x1A000000)),
                                        ),
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: Image.network(
                                                item.colorway.photoBack!,
                                                fit: BoxFit.contain,
                                                errorBuilder: (_, __, ___) => const Center(
                                                  child: Icon(Icons.image_not_supported_outlined, color: Colors.grey),
                                                ),
                                              ),
                                            ),
                                            Positioned(
                                              bottom: 4,
                                              left: 4,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withValues(alpha: 0.9),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: const Color(0x1A000000)),
                                                ),
                                                child: Text(
                                                  'Back View',
                                                  style: GoogleFonts.jetBrainsMono(fontSize: 8.5, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  : Container(
                                      height: 160,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0x1A000000)),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        'No Back View',
                                        style: GoogleFonts.publicSans(fontSize: 11, color: const Color(0xFF94A3B8)),
                                      ),
                                    ),
                            ),
                          ],
                        ),

                        // Designer notes
                        if (item.designerNotes != null && item.designerNotes!.trim().isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0x1A000000)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'DESIGNER NOTES',
                                  style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.designerNotes!,
                                  style: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF334155), fontStyle: FontStyle.italic),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // PH Feedback
                        if (item.phFeedback != null && item.phFeedback!.trim().isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F9FF),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFBAE6FD)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'PROVISIONAL HEAD NOTES',
                                  style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF0369A1)),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.phFeedback!,
                                  style: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF075985), fontStyle: FontStyle.italic),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 16),
                        Text(
                          'SUPER ADMIN DECISION NOTES',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF475569),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: notesController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            hintText: 'e.g. Greenlit for Summer Drop / Saved in seasonal library...',
                            hintStyle: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF94A3B8)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.all(12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0x1A000000)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0x1A000000)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF332B6B), width: 1.5),
                            ),
                          ),
                          style: GoogleFonts.publicSans(fontSize: 12.5, color: const Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                  ),

                  // Footer Actions
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFAFAF8),
                      border: Border(top: BorderSide(color: Color(0x1A000000))),
                    ),
                    child: isSaving
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFF332B6B)))
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  // Request Revisions (Reject)
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFFBE123C),
                                        backgroundColor: const Color(0xFFFFF1F2),
                                        side: const BorderSide(color: Color(0xFFFECDD3)),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                      onPressed: () => submitVerdict('REJECTED'),
                                      icon: const Icon(Icons.cancel_outlined, size: 16),
                                      label: Text(
                                        'Revisions',
                                        style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Save for Later
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFF332B6B),
                                        backgroundColor: Colors.white,
                                        side: const BorderSide(color: Color(0x26000000)),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                      onPressed: () => submitVerdict('SAVED_FOR_LATER'),
                                      icon: const Icon(Icons.bookmark_border_rounded, size: 16),
                                      label: Text(
                                        'Save Later',
                                        style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Greenlight Primary Button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF059669),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(vertical: 13),
                                    elevation: 0,
                                  ),
                                  onPressed: () => submitVerdict('APPROVED'),
                                  icon: const Icon(Icons.check_circle_rounded, size: 18),
                                  label: Text(
                                    'Greenlight for Tech-Pack',
                                    style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildKpiBox({
    required String tag,
    required String label,
    required int count,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x1A000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF7F0),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0x1A000000)),
                ),
                child: Text(
                  tag,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF7F0),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0x1A000000)),
                ),
                child: Icon(icon, color: const Color(0xFF332B6B), size: 15),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$count',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(designerProvider);
    final allRows = _deriveSARows(state.briefs);

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
      backgroundColor: Colors.white,
      appBar: ZigzaAppBar(
        onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      drawer: const WorkspaceHubDrawer(activeRoute: '/design/sa-approvals'),
      body: RefreshIndicator(
        color: const Color(0xFF332B6B),
        onRefresh: () => ref.read(designerProvider.notifier).fetchStudioData(),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          children: [
            // Breadcrumbs
            Row(
              children: [
                InkWell(
                  onTap: () => Navigator.pop(context),
                  child: Text(
                    'Workspace Hub',
                    style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                  ),
                ),
                const SizedBox(width: 6),
                const Text('/', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 11)),
                const SizedBox(width: 6),
                Text(
                  'Approvals',
                  style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                ),
                const SizedBox(width: 6),
                const Text('/', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 11)),
                const SizedBox(width: 6),
                Text(
                  'SA Design Approvals',
                  style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Header Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAF8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x1A000000)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAF7F0),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0x1A000000)),
                        ),
                        child: const Icon(Icons.shield_outlined, color: Color(0xFF332B6B), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'SA Design Approvals',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFEBFB),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0x26332B6B)),
                                  ),
                                  child: Text(
                                    '${pendingItems.length} Awaiting',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF332B6B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Executive sign-off on Provisional Head-approved designs before tech-pack greenlight.',
                              style: GoogleFonts.publicSans(
                                fontSize: 11.5,
                                color: const Color(0xFF64748B),
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 4-Box KPI Grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.5,
              children: [
                _buildKpiBox(
                  tag: 'PIPELINE',
                  label: 'Total Designs',
                  count: allRows.length,
                  icon: Icons.layers_outlined,
                ),
                _buildKpiBox(
                  tag: 'DECISION',
                  label: 'Awaiting Decision',
                  count: pendingItems.length,
                  icon: Icons.access_time_rounded,
                ),
                _buildKpiBox(
                  tag: 'GREENLIT',
                  label: 'SA Greenlit',
                  count: approvedItems.length,
                  icon: Icons.check_circle_outline_rounded,
                ),
                _buildKpiBox(
                  tag: 'ARCHIVE',
                  label: 'Seasonal Archive',
                  count: savedItems.length,
                  icon: Icons.bookmark_border_rounded,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search Bar
            TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search art no, colors, garment...',
                hintStyle: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16, color: Color(0xFF94A3B8)),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0x1A000000)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0x1A000000)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF332B6B), width: 1.5),
                ),
              ),
              style: GoogleFonts.publicSans(fontSize: 12.5, color: const Color(0xFF0F172A)),
            ),
            const SizedBox(height: 12),

            // Filter Tabs (Scrollable)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTabChip('ALL', 'All (${allRows.length})'),
                  const SizedBox(width: 8),
                  _buildTabChip('PENDING', 'Awaiting Decision (${pendingItems.length})'),
                  const SizedBox(width: 8),
                  _buildTabChip('APPROVED', 'Greenlit (${approvedItems.length})'),
                  const SizedBox(width: 8),
                  _buildTabChip('SAVED_FOR_LATER', 'Saved Later (${savedItems.length})'),
                  if (rejectedItems.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    _buildTabChip('REJECTED', 'Revisions (${rejectedItems.length})'),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Main List of Items
            if (filteredList.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAF8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0x1A000000)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.shield_outlined, size: 40, color: Color(0xFF94A3B8)),
                    const SizedBox(height: 12),
                    Text(
                      'No designs found in this filter',
                      style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'When Provisional Heads approve designer submissions, individual colorways appear here for Super Admin executive review.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              )
            else
              ...filteredList.map((item) => _buildApprovalCard(context, item)),
          ],
        ),
      ),
    );
  }

  Widget _buildTabChip(String tabKey, String label) {
    final isActive = _activeTab == tabKey;
    return InkWell(
      onTap: () => setState(() => _activeTab = tabKey),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF332B6B) : const Color(0xFFFAF7F0),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? const Color(0xFF332B6B) : const Color(0x1A000000),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.publicSans(
            fontSize: 11.5,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
            color: isActive ? Colors.white : const Color(0xFF475569),
          ),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1A000000)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            offset: Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Art Number + Concept Tag + Verdict Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    item.artNumber,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0x1A000000)),
                    ),
                    child: Text(
                      '#${item.conceptNumber}',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9.5,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (isPendingSA)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Text(
                    'Awaiting Decision',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF92400E),
                    ),
                  ),
                ),
              if (isGreenlit)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Text(
                    'SA Greenlit',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF065F46),
                    ),
                  ),
                ),
              if (isSaved)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF7F0),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0x26000000)),
                  ),
                  child: Text(
                    'Archived',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF332B6B),
                    ),
                  ),
                ),
              if (isRejected)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFECDD3)),
                  ),
                  child: Text(
                    'Revisions',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFBE123C),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),

          // Garment & Category
          Text(
            item.garment,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
            ),
          ),
          Text(
            item.category,
            style: GoogleFonts.publicSans(
              fontSize: 11.5,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 10),

          // Designer & Colorway Row with Thumbnail
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAF8),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0x1A000000)),
            ),
            child: Row(
              children: [
                // Mini Thumbnail
                if (item.colorway.photoFront != null && item.colorway.photoFront!.isNotEmpty)
                  InkWell(
                    onTap: () => _showImageLightbox(context, item.colorway.photoFront!, '${item.artNumber} - Front View'),
                    child: Container(
                      width: 44,
                      height: 44,
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0x1A000000)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          item.colorway.photoFront!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_rounded, size: 20, color: Colors.grey),
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
                          const Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF059669)),
                          const SizedBox(width: 4),
                          Text(
                            'PH Approved • Designer: ${item.designerName}',
                            style: GoogleFonts.publicSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: swColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black26),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Colorway: ${item.colorName}',
                            style: GoogleFonts.publicSans(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF475569),
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
          const SizedBox(height: 10),

          // Action Button: View & Decide
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF332B6B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                elevation: 0,
              ),
              onPressed: () => _showDecisionSheet(context, item),
              icon: const Icon(Icons.visibility_outlined, size: 16),
              label: Text(
                'View & Decide ${item.artNumber}',
                style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
