import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/design_brief_model.dart';
import '../providers/designer_provider.dart';

class ConceptReviewScreen extends ConsumerStatefulWidget {
  final DesignBriefModel brief;
  final int initialConceptNumber;

  const ConceptReviewScreen({
    super.key,
    required this.brief,
    this.initialConceptNumber = 1,
  });

  @override
  ConsumerState<ConceptReviewScreen> createState() => _ConceptReviewScreenState();
}

class _ConceptReviewScreenState extends ConsumerState<ConceptReviewScreen> {
  late int _activeConceptNumber;
  final TextEditingController _feedbackController = TextEditingController();

  // Colorway Decisions: color_name -> 'APPROVED' | 'REJECTED'
  final Map<String, String> _colorwayDecisions = {};
  bool _hasInitialEdits = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _activeConceptNumber = widget.initialConceptNumber > 0 ? widget.initialConceptNumber : 1;
    _initConceptState();
  }

  void _initConceptState() {
    final sub = widget.brief.latestSubmission;
    final concepts = sub?.safeConcepts ?? [];

    DesignConceptItemModel? currentConcept;
    if (concepts.isNotEmpty) {
      currentConcept = concepts.firstWhere(
        (c) => c.safeConceptNumber == _activeConceptNumber,
        orElse: () => concepts.first,
      );
      _activeConceptNumber = currentConcept.safeConceptNumber;
    }

    _colorwayDecisions.clear();
    if (currentConcept != null) {
      for (final cw in currentConcept.safeColorways) {
        _colorwayDecisions[cw.colorName] = cw.status == 'REJECTED' ? 'REJECTED' : 'APPROVED';
      }
      _feedbackController.text = currentConcept.phFeedback ?? sub?.phFeedback ?? '';
    } else if (sub != null) {
      _feedbackController.text = sub.phFeedback ?? '';
    }
    _hasInitialEdits = false;
  }

  String _formatColorwayName(String raw) {
    if (raw.trim().isEmpty) return 'Colorway';
    final words = raw.trim().split(RegExp(r'\s+'));
    final formatted = words.map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}' : '').join(' ');
    if (formatted.toLowerCase().endsWith('colorway')) {
      return formatted;
    }
    return '$formatted Colorway';
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
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

  String _getVariantArtNumber(String baseArtNo, int index, int total) {
    if (baseArtNo.isEmpty) return '';
    if (total <= 1) return baseArtNo;
    final suffix = (index + 1).toString().padLeft(2, '0');
    return '$baseArtNo-$suffix';
  }

  Future<bool> _confirmClose() async {
    if (!_hasInitialEdits) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Discard Review Changes?',
          style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'You have unsubmitted review verdicts. Are you sure you want to close without syncing?',
          style: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Keep Editing', style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC23838),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Discard', style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  Future<void> _submitReview(String verdict) async {
    final sub = widget.brief.latestSubmission;
    if (sub == null) return;

    if (verdict == 'REJECTED' && _feedbackController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide review notes / feedback when requesting revisions.'),
          backgroundColor: Color(0xFFC23838),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    final ok = await ref.read(designerProvider.notifier).reviewSubmissionColorways(
      submissionId: sub.id,
      briefId: widget.brief.id,
      conceptNumber: _activeConceptNumber,
      phVerdict: verdict,
      phFeedback: _feedbackController.text.trim().isNotEmpty ? _feedbackController.text.trim() : null,
      colorwayVerdicts: _colorwayDecisions,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (ok) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            verdict == 'APPROVED'
                ? 'Review updated! Approved designs synced to Super Admin.'
                : 'Design returned to designer with revision feedback.',
          ),
          backgroundColor: verdict == 'APPROVED' ? const Color(0xFF047857) : const Color(0xFFC23838),
        ),
      );
      nav.pop(true);
    } else {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Failed to update review. Please try again.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
    }
  }

  Future<void> _confirmDeleteDesign() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete this design concept?',
          style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete Concept #$_activeConceptNumber and all its colorways? This action cannot be undone.',
          style: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC23838),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isSubmitting = true);

      final ok = await ref.read(designerProvider.notifier).deleteBrief(
        widget.brief.id,
        conceptNumber: _activeConceptNumber,
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Design concept deleted successfully.'),
            backgroundColor: Color(0xFF047857),
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete design.'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  void _openLightbox(String imageUrl, String label) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black.withValues(alpha: 0.92),
        insetPadding: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.8,
              maxScale: 4.0,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                },
                errorBuilder: (_, __, ___) => const Center(
                  child: Text('Failed to load image', style: TextStyle(color: Colors.white70)),
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  label,
                  style: GoogleFonts.jetBrainsMono(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brief = widget.brief;
    final sub = brief.latestSubmission;
    final concepts = sub?.safeConcepts ?? [];

    final reqs = brief.safeDesignConceptsBrief;
    final instructedReq = reqs.isNotEmpty
        ? reqs.firstWhere((r) => r.conceptNumber == _activeConceptNumber, orElse: () => reqs.first)
        : null;

    final currentArtNo = instructedReq?.artNumber ?? brief.briefCode;
    final currentGarment = instructedReq?.notes?.contains('Garment:') == true
        ? (RegExp(r'Garment:\s*([^|]+)', caseSensitive: false).firstMatch(instructedReq!.notes!)?.group(1)?.trim() ?? brief.garmentType)
        : brief.garmentType;
    final currentCategory = instructedReq?.categoryStyle ?? brief.category;

    DesignConceptItemModel? currentConcept;
    if (concepts.isNotEmpty) {
      currentConcept = concepts.firstWhere(
        (c) => c.safeConceptNumber == _activeConceptNumber,
        orElse: () => concepts.first,
      );
    }

    final colorways = currentConcept?.safeColorways ?? [];

    final status = brief.status.toUpperCase();
    final bool isApproved = status == 'PH_APPROVED' || status == 'SA_APPROVED';
    final bool isRejected = status == 'PH_REJECTED' || status == 'REVISE_FIT';

    final Color statusBg = isApproved
        ? const Color(0xFFE9F7EE)
        : (isRejected ? const Color(0xFFFBE4E4) : const Color(0xFFFEF3C7));
    final Color statusText = isApproved
        ? const Color(0xFF047857)
        : (isRejected ? const Color(0xFFBE123C) : const Color(0xFFB45309));
    final Color statusBorder = isApproved
        ? const Color(0xFFA7F3D0)
        : (isRejected ? const Color(0xFFFECDD3) : const Color(0xFFFDE68A));
    final String statusLabel = isApproved
        ? 'PH APPROVED'
        : (isRejected ? 'REVISIONS NEEDED' : (status == 'SUBMITTED' ? 'IN REVIEW' : 'ALLOCATED'));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _confirmClose();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              // ==========================================
              // 1. MODAL HEADER (Matching Web #FAF7F0 Header)
              // ==========================================
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
                decoration: const BoxDecoration(
                  color: Color(0xFFFAF7F0),
                  border: Border(bottom: BorderSide(color: Color(0x1A000000))),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Status Badge + ART NO
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: statusBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: statusBorder),
                                ),
                                child: Text(
                                  statusLabel,
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: statusText,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'ART NO: $currentArtNo',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),

                          // Garment Title
                          Text(
                            '$currentGarment ($currentCategory Style)',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 3),

                          // Designer Line
                          RichText(
                            text: TextSpan(
                              style: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF64748B)),
                              children: [
                                const TextSpan(text: 'Designer: '),
                                TextSpan(
                                  text: brief.designerName ?? 'Unassigned',
                                  style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                                ),
                                if (brief.designerPhone != null && brief.designerPhone!.isNotEmpty)
                                  TextSpan(text: ' • +91 ${brief.designerPhone}'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Close (X) button
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 22, color: Color(0xFF64748B)),
                      onPressed: () async {
                        final shouldClose = await _confirmClose();
                        if (shouldClose && context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                  ],
                ),
              ),

              // ==========================================
              // 2. SCROLLABLE BODY: PER-COLORWAY REVIEWS
              // ==========================================
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (colorways.isNotEmpty) ...[
                        ...colorways.asMap().entries.map((entry) {
                          final cwIdx = entry.key;
                          final cw = entry.value;
                          final variantArtNo = _getVariantArtNumber(currentArtNo, cwIdx, colorways.length);
                          final swColor = _getColorSwatchBg(cw.colorName);
                          final currentVerdict = _colorwayDecisions[cw.colorName] ?? (cw.status == 'REJECTED' ? 'REJECTED' : 'APPROVED');
                          final isAccepted = currentVerdict == 'APPROVED';
                          final isRejectedCW = currentVerdict == 'REJECTED';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Colorway Header Bar (Matching Web Flex Row with Variant Chip & Compact Segmented Toggle)
                                Container(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  decoration: const BoxDecoration(
                                    border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      // Colorway Name with Dot
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 13,
                                              height: 13,
                                              decoration: BoxDecoration(
                                                color: swColor,
                                                shape: BoxShape.circle,
                                                border: Border.all(color: const Color(0x33000000)),
                                              ),
                                            ),
                                            const SizedBox(width: 7),
                                            Flexible(
                                              child: Text(
                                                _formatColorwayName(cw.colorName),
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  color: const Color(0xFF0F172A),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Variant Code Chip + Segmented Accept/Reject Toggle
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (variantArtNo.isNotEmpty) ...[
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFAF7F0),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: const Color(0x1A000000)),
                                              ),
                                              child: Text(
                                                variantArtNo,
                                                style: GoogleFonts.jetBrainsMono(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                  color: const Color(0xFF0F172A),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                          ],

                                          // Segmented Accept / Reject Controls (Compact Web Style)
                                          Container(
                                            padding: const EdgeInsets.all(2.5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFAF7F0),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: const Color(0x1A000000)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                // Accept Toggle
                                                InkWell(
                                                  onTap: () {
                                                    setState(() {
                                                      _colorwayDecisions[cw.colorName] = 'APPROVED';
                                                      _hasInitialEdits = true;
                                                    });
                                                  },
                                                  borderRadius: BorderRadius.circular(7),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: isAccepted ? const Color(0xFF047857) : Colors.transparent,
                                                      borderRadius: BorderRadius.circular(7),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          Icons.check_circle_rounded,
                                                          size: 13,
                                                          color: isAccepted ? Colors.white : const Color(0xFF64748B),
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          'Accept',
                                                          style: GoogleFonts.plusJakartaSans(
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.w700,
                                                            color: isAccepted ? Colors.white : const Color(0xFF64748B),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 2),

                                                // Reject Toggle
                                                InkWell(
                                                  onTap: () {
                                                    setState(() {
                                                      _colorwayDecisions[cw.colorName] = 'REJECTED';
                                                      _hasInitialEdits = true;
                                                    });
                                                  },
                                                  borderRadius: BorderRadius.circular(7),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: isRejectedCW ? const Color(0xFFDC2626) : Colors.transparent,
                                                      borderRadius: BorderRadius.circular(7),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          Icons.cancel_rounded,
                                                          size: 13,
                                                          color: isRejectedCW ? Colors.white : const Color(0xFF64748B),
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          'Reject',
                                                          style: GoogleFonts.plusJakartaSans(
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.w700,
                                                            color: isRejectedCW ? Colors.white : const Color(0xFF64748B),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
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
                                const SizedBox(height: 12),

                                // Large Front View Mockup Container
                                if (cw.photoFront != null && cw.photoFront!.isNotEmpty) ...[
                                  _buildArtworkContainer(
                                    label: 'Front view',
                                    imageUrl: cw.photoFront!,
                                    colorName: cw.colorName,
                                  ),
                                  const SizedBox(height: 12),
                                ],

                                // Large Back View Mockup Container
                                if (cw.photoBack != null && cw.photoBack!.isNotEmpty) ...[
                                  _buildArtworkContainer(
                                    label: 'Back view',
                                    imageUrl: cw.photoBack!,
                                    colorName: cw.colorName,
                                  ),
                                ],
                              ],
                            ),
                          );
                        }),
                      ] else if (sub != null && sub.photoUrl1.isNotEmpty) ...[
                        // Legacy Single Mockup Fallback
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Submitted Mockup Artwork',
                              style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 12),
                            _buildArtworkContainer(
                              label: 'Front view',
                              imageUrl: sub.photoUrl1,
                              colorName: 'Primary',
                            ),
                            if (sub.photoUrl2 != null && sub.photoUrl2!.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              _buildArtworkContainer(
                                label: 'Back view',
                                imageUrl: sub.photoUrl2!,
                                colorName: 'Primary',
                              ),
                            ],
                          ],
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAF7F0),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0x1A000000)),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.palette_outlined, color: Color(0xFF94A3B8), size: 36),
                              const SizedBox(height: 10),
                              Text(
                                'No artwork submitted yet for this concept.',
                                style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),

                      // ==========================================
                      // 4. DESIGNER NOTES (Amber Callout)
                      // ==========================================
                      if (sub?.cleanDesignerNotes != null && sub!.cleanDesignerNotes!.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAF7F0),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0x1A000000)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'DESIGNER NOTES:',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF94A3B8),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '“${sub.cleanDesignerNotes}”',
                                style: GoogleFonts.publicSans(
                                  fontSize: 12.5,
                                  fontStyle: FontStyle.italic,
                                  color: const Color(0xFF334155),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ==========================================
                      // 5. PROVISIONAL HEAD REVIEW NOTES / FEEDBACK
                      // ==========================================
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PROVISIONAL HEAD REVIEW NOTES / FEEDBACK:',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _feedbackController,
                            onChanged: (_) => _hasInitialEdits = true,
                            maxLines: 3,
                            style: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF0F172A), fontWeight: FontWeight.w500),
                            decoration: InputDecoration(
                              hintText: 'Optional feedback for designer (required if requesting revisions)...',
                              hintStyle: GoogleFonts.publicSans(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0x1A000000))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0x1A000000))),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF332B6B), width: 1.5)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // ==========================================
              // 6. STICKY FOOTER ACTIONS (Matching Web Actions)
              // ==========================================
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: const BoxDecoration(
                  color: Color(0xFFFAF7F0),
                  border: Border(top: BorderSide(color: Color(0x1A000000))),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Row: Delete Design + Close
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isSubmitting ? null : _confirmDeleteDesign,
                            icon: const Icon(Icons.delete_outline_rounded, size: 15, color: Color(0xFF64748B)),
                            label: Text(
                              'Delete Design',
                              style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)),
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(38),
                              side: const BorderSide(color: Color(0x1A000000)),
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isSubmitting
                                ? null
                                : () async {
                                    final shouldClose = await _confirmClose();
                                    if (shouldClose && context.mounted) {
                                      Navigator.pop(context);
                                    }
                                  },
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(38),
                              side: const BorderSide(color: Color(0x1A000000)),
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Text(
                              'Close',
                              style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF334155)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Row: Request revisions + Update review & sync
                    Row(
                      children: [
                        // Request Revisions (Rose Pill)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isSubmitting ? null : () => _submitReview('REJECTED'),
                            icon: const Icon(Icons.cancel_outlined, size: 15, color: Color(0xFFBE123C)),
                            label: Text(
                              'Request revisions',
                              style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFFBE123C)),
                            ),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(40),
                              backgroundColor: const Color(0xFFFFF1F2),
                              foregroundColor: const Color(0xFFBE123C),
                              elevation: 0,
                              side: const BorderSide(color: Color(0xFFFECDD3)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Update Review & Sync (Brand Indigo Pill)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isSubmitting ? null : () => _submitReview('APPROVED'),
                            icon: _isSubmitting
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.check_circle_outline_rounded, size: 15, color: Colors.white),
                            label: Text(
                              'Update & Sync',
                              style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(40),
                              backgroundColor: const Color(0xFF332B6B),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
      ),
    );
  }

  // Artwork Image Container matching Web's .aspect-square .bg-[#FAF7F0] container with bottom-left overlay pill
  Widget _buildArtworkContainer({
    required String label,
    required String imageUrl,
    required String colorName,
  }) {
    return InkWell(
      onTap: () => _openLightbox(imageUrl, '$colorName - $label'),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 310,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFFAF7F0),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x1A000000)),
        ),
        padding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF332B6B)));
                  },
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(Icons.broken_image_rounded, color: Color(0xFF94A3B8), size: 36),
                  ),
                ),
              ),
            ),

            // Bottom-Left Label Pill (Matching Web: text-[10px] font-mono font-bold bg-white/95)
            Positioned(
              bottom: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0x1A000000)),
                  boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 3)],
                ),
                child: Text(
                  label,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
