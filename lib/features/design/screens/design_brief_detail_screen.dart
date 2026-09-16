import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../models/design_brief_model.dart';
import '../providers/designer_provider.dart';

class DesignBriefDetailScreen extends ConsumerStatefulWidget {
  final DesignBriefModel brief;

  const DesignBriefDetailScreen({super.key, required this.brief});

  @override
  ConsumerState<DesignBriefDetailScreen> createState() => _DesignBriefDetailScreenState();
}

class _ConceptFormState {
  String title;
  String notes;
  Map<String, _ColorwayFormState> colorways;

  _ConceptFormState({
    required this.title,
    this.notes = '',
    required this.colorways,
  });
}

class _ColorwayFormState {
  String photoFront;
  String photoBack;

  _ColorwayFormState({
    this.photoFront = '',
    this.photoBack = '',
  });
}

class _DesignBriefDetailScreenState extends ConsumerState<DesignBriefDetailScreen> {
  final _picker = ImagePicker();

  late int _targetDesignsCount;
  late List<String> _targetColorsList;

  // Multi-concept form state indexed by concept number (1-based)
  final Map<int, _ConceptFormState> _conceptsState = {};
  int _activeConceptTab = 1;
  late String _activeColorwayTab;

  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _initFormState();
  }

  void _initFormState() {
    final brief = widget.brief;
    _targetDesignsCount = brief.safeTargetDesigns;
    _targetColorsList = brief.targetColors.isNotEmpty ? brief.targetColors : ['Default Colorway'];
    _activeColorwayTab = _targetColorsList.first;

    // Prepopulate from latest submission if available
    final sub = brief.latestSubmission;
    if (sub != null && sub.safeConcepts.isNotEmpty) {
      for (final c in sub.safeConcepts) {
        final cwMap = <String, _ColorwayFormState>{};
        for (final cw in c.safeColorways) {
          cwMap[cw.colorName] = _ColorwayFormState(
            photoFront: cw.photoFront ?? '',
            photoBack: cw.photoBack ?? '',
          );
        }
        _conceptsState[c.safeConceptNumber] = _ConceptFormState(
          title: c.title.isNotEmpty ? c.title : 'Design Concept #${c.safeConceptNumber}',
          notes: c.notes ?? '',
          colorways: cwMap,
        );
      }
    } else if (sub != null && sub.photoUrl1.isNotEmpty) {
      // Legacy single/flat submission fallback
      _conceptsState[1] = _ConceptFormState(
        title: 'Design Concept #1',
        notes: sub.cleanDesignerNotes ?? '',
        colorways: {
          _targetColorsList.first: _ColorwayFormState(
            photoFront: sub.photoUrl1,
            photoBack: sub.photoUrl2 ?? '',
          ),
        },
      );
    }

    // Ensure all target concepts and colorway slots exist
    for (int i = 1; i <= _targetDesignsCount; i++) {
      if (!_conceptsState.containsKey(i)) {
        _conceptsState[i] = _ConceptFormState(
          title: 'Design Concept #$i',
          notes: '',
          colorways: {},
        );
      }
      for (final col in _targetColorsList) {
        if (!_conceptsState[i]!.colorways.containsKey(col)) {
          _conceptsState[i]!.colorways[col] = _ColorwayFormState();
        }
      }
    }
  }

  Color _getColorFromName(String name) {
    final norm = name.trim().toLowerCase();
    if (norm.contains('black')) return const Color(0xFF111111);
    if (norm.contains('white')) return const Color(0xFFFFFFFF);
    if (norm.contains('navy')) return const Color(0xFF1B2A4A);
    if (norm.contains('olive')) return const Color(0xFF556B2F);
    if (norm.contains('grey') || norm.contains('gray')) return const Color(0xFF718096);
    if (norm.contains('red') || norm.contains('maroon')) return const Color(0xFFC53030);
    if (norm.contains('beige') || norm.contains('cream') || norm.contains('sand')) return const Color(0xFFF5F5DC);
    if (norm.contains('blue') || norm.contains('sky')) return const Color(0xFF2B6CB0);
    if (norm.contains('green')) return const Color(0xFF276749);
    if (norm.contains('yellow')) return const Color(0xFFECC94B);
    if (norm.contains('pink')) return const Color(0xFFD53F8C);
    if (norm.contains('orange')) return const Color(0xFFDD6B20);
    if (norm.contains('brown')) return const Color(0xFF7B341E);
    if (norm.contains('purple')) return const Color(0xFF6B46C1);
    return const Color(0xFF3A3564);
  }

  void _openImageDialog(String src, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 25,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppTheme.foregroundInk,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 420),
                  padding: const EdgeInsets.all(12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _buildArtworkWidget(src),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArtworkWidget(String? src) {
    if (src == null || src.isEmpty) {
      return const Center(child: Icon(Icons.image_not_supported, color: Colors.grey, size: 28));
    }
    if (src.startsWith('data:image') || src.contains(';base64,')) {
      try {
        final base64Str = src.split(',').last;
        final bytes = base64Decode(base64Str);
        return Image.memory(bytes, fit: BoxFit.contain);
      } catch (_) {
        return const Center(child: Icon(Icons.broken_image, color: Colors.grey));
      }
    } else if (src.startsWith('http://') || src.startsWith('https://')) {
      return Image.network(
        src,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
      );
    } else {
      try {
        final bytes = base64Decode(src);
        return Image.memory(bytes, fit: BoxFit.contain);
      } catch (_) {
        return const Center(child: Icon(Icons.broken_image, color: Colors.grey));
      }
    }
  }

  Future<void> _pickArtwork(int conceptNum, String colorName, String slot, ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 85);
      if (picked != null) {
        setState(() => _isUploading = true);
        final file = File(picked.path);
        final url = await ref.read(designerProvider.notifier).uploadPhotoFile(file);
        setState(() {
          _isUploading = false;
          if (url != null) {
            final c = _conceptsState[conceptNum];
            if (c != null) {
              final cw = c.colorways[colorName] ?? _ColorwayFormState();
              if (slot == 'front') {
                cw.photoFront = url;
              } else {
                cw.photoBack = url;
              }
              c.colorways[colorName] = cw;
            }
          }
        });
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading image: $e')),
        );
      }
    }
  }

  void _showPasteUrlDialog(int conceptNum, String colorName, String slot) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Paste Image URL ($slot)',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: TextField(
          controller: textController,
          decoration: InputDecoration(
            hintText: 'https://example.com/artwork.png',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          keyboardType: TextInputType.url,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.brandSteel,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              final url = textController.text.trim();
              if (url.isNotEmpty) {
                setState(() {
                  final c = _conceptsState[conceptNum];
                  if (c != null) {
                    final cw = c.colorways[colorName] ?? _ColorwayFormState();
                    if (slot == 'front') {
                      cw.photoFront = url;
                    } else {
                      cw.photoBack = url;
                    }
                    c.colorways[colorName] = cw;
                  }
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('Apply', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showImageOptionsSheet(int conceptNum, String colorName, String slot) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Attach $slot Mockup ($colorName)',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppTheme.foregroundInk,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: AppTheme.brandSteel),
                title: const Text('Take Photo with Camera'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickArtwork(conceptNum, colorName, slot, ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppTheme.brandSteel),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickArtwork(conceptNum, colorName, slot, ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.link, color: AppTheme.brandSteel),
                title: const Text('Paste Public Image URL'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showPasteUrlDialog(conceptNum, colorName, slot);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    final conceptsList = <DesignConceptItemModel>[];

    for (int i = 1; i <= _targetDesignsCount; i++) {
      final cData = _conceptsState[i];
      if (cData == null) continue;

      final colorwaysList = <ConceptColorwayModel>[];
      for (final col in _targetColorsList) {
        final cw = cData.colorways[col];
        if (cw != null && cw.photoFront.trim().isNotEmpty) {
          colorwaysList.add(ConceptColorwayModel(
            colorName: col,
            photoFront: cw.photoFront.trim(),
            photoBack: cw.photoBack.trim().isNotEmpty ? cw.photoBack.trim() : null,
          ));
        }
      }

      if (colorwaysList.isNotEmpty || cData.title.trim().isNotEmpty || cData.notes.trim().isNotEmpty) {
        conceptsList.add(DesignConceptItemModel(
          conceptNumber: i,
          title: cData.title.trim().isNotEmpty ? cData.title.trim() : 'Design Concept #$i',
          notes: cData.notes.trim().isNotEmpty ? cData.notes.trim() : null,
          colorways: colorwaysList,
        ));
      }
    }

    if (conceptsList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please attach at least 1 design artwork mockup before submitting.')),
      );
      return;
    }

    final success = await ref.read(designerProvider.notifier).submitDesignConcepts(
      briefId: widget.brief.id,
      designerMemberId: widget.brief.designerMemberId,
      concepts: conceptsList,
      generalNotes: _conceptsState[1]?.notes,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Artwork Deck submitted successfully for Provisional Head review!'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brief = widget.brief;
    final isFinalApproved = brief.status == 'SA_APPROVED' || brief.status == 'TECH_PACK_CREATED';
    final isEditable = !isFinalApproved;
    final isRejected = brief.status == 'PH_REJECTED';

    final totalSlots = _targetDesignsCount * _targetColorsList.length;
    int readySlotsCount = 0;
    for (int i = 1; i <= _targetDesignsCount; i++) {
      final cData = _conceptsState[i];
      if (cData != null) {
        for (final col in _targetColorsList) {
          if (cData.colorways[col]?.photoFront.trim().isNotEmpty ?? false) {
            readySlotsCount++;
          }
        }
      }
    }

    final currentConcept = _conceptsState[_activeConceptTab] ?? _ConceptFormState(
      title: 'Design Concept #$_activeConceptTab',
      colorways: {},
    );
    final currentColorway = currentConcept.colorways[_activeColorwayTab] ?? _ColorwayFormState();

    return Scaffold(
      backgroundColor: AppTheme.canvasCream,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.foregroundInk),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              brief.garmentType,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppTheme.foregroundInk,
              ),
            ),
            Text(
              'Assignments / ${brief.garmentType} / #${brief.id.substring(0, brief.id.length > 6 ? 6 : brief.id.length)}',
              style: GoogleFonts.publicSans(
                fontSize: 11,
                color: AppTheme.mutedInk,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header Summary Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.standardBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${brief.garmentType} (${brief.category})',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: AppTheme.foregroundInk,
                          ),
                        ),
                      ),
                      _buildStatusBadge(brief.status),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Target: $_targetDesignsCount Designs × ${_targetColorsList.length} Colors = $totalSlots Mockups',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.brandSteel,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Assigned Colors & Guidelines Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.standardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Assigned Colors (${_targetColorsList.length}): ',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.mutedInk,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: _targetColorsList.map((col) {
                            final colColor = _getColorFromName(col);
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.canvasCream,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.standardBorder),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: colColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.black26),
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    col,
                                    style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                  if (brief.instructions != null && brief.instructions!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.canvasCream,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.standardBorder),
                      ),
                      child: Text(
                        '“${brief.instructions}”',
                        style: GoogleFonts.publicSans(
                          fontSize: 12,
                          color: AppTheme.foregroundInk,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                  if (isRejected && brief.latestSubmission?.phFeedback != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFECDD3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.cancel, size: 14, color: Color(0xFFE11D48)),
                              const SizedBox(width: 6),
                              Text(
                                'Head Revision Notes (Action Required):',
                                style: GoogleFonts.jetBrainsMono(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: const Color(0xFF9F1239),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '“${brief.latestSubmission!.phFeedback!}”',
                            style: GoogleFonts.publicSans(
                              fontSize: 12,
                              color: const Color(0xFF881337),
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Multi-Concept Workspace Deck
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.standardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.layers_outlined, size: 18, color: AppTheme.brandSteel),
                          const SizedBox(width: 8),
                          Text(
                            'Design Concepts Deck ($_targetDesignsCount Required)',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppTheme.foregroundInk,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Concept $_activeConceptTab of $_targetDesignsCount',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.mutedInk,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Concept Tab Switcher
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(_targetDesignsCount, (index) {
                        final cNum = index + 1;
                        final isTabActive = _activeConceptTab == cNum;
                        final cData = _conceptsState[cNum];
                        final readyCount = _targetColorsList.where((col) => cData?.colorways[col]?.photoFront.trim().isNotEmpty ?? false).length;
                        final isFullyDone = readyCount >= _targetColorsList.length;

                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _activeConceptTab = cNum;
                                _activeColorwayTab = _targetColorsList.first;
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isTabActive
                                    ? AppTheme.brandSteel
                                    : (isFullyDone ? const Color(0xFFECFDF5) : AppTheme.canvasCream),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isTabActive
                                      ? AppTheme.brandSteel
                                      : (isFullyDone ? const Color(0xFFA7F3D0) : AppTheme.standardBorder),
                                ),
                              ),
                              child: Row(
                                children: [
                                  if (isFullyDone)
                                    const Icon(Icons.check_circle, size: 14, color: Color(0xFF10B981))
                                  else
                                    Container(
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: isTabActive ? Colors.white24 : Colors.black12,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          '$cNum',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: isTabActive ? Colors.white : AppTheme.foregroundInk,
                                          ),
                                        ),
                                      ),
                                    ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Design #$cNum',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isTabActive
                                          ? Colors.white
                                          : (isFullyDone ? const Color(0xFF065F46) : AppTheme.foregroundInk),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: isTabActive ? Colors.white24 : Colors.black.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '$readyCount/${_targetColorsList.length}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isTabActive ? Colors.white : AppTheme.mutedInk,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Concept Detail Card (Active Concept Workspace)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.canvasCream,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.standardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Concept Title Input
                        Text(
                          'Design Concept #$_activeConceptTab Title / Theme',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.foregroundInk,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          enabled: isEditable,
                          initialValue: currentConcept.title,
                          onChanged: (val) => currentConcept.title = val,
                          decoration: InputDecoration(
                            hintText: 'e.g. Graphic Variant #$_activeConceptTab',
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppTheme.standardBorder),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppTheme.standardBorder),
                            ),
                          ),
                          style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 14),

                        // Fabric Colorway Selector
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Fabric Colorway',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.foregroundInk,
                              ),
                            ),
                            Text(
                              'Select color to attach artwork',
                              style: GoogleFonts.publicSans(fontSize: 10, color: AppTheme.mutedInk),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _targetColorsList.map((colName) {
                            final swColor = _getColorFromName(colName);
                            final isColorSelected = _activeColorwayTab == colName;
                            final hasPhoto = currentConcept.colorways[colName]?.photoFront.trim().isNotEmpty ?? false;

                            return InkWell(
                              onTap: () => setState(() => _activeColorwayTab = colName),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isColorSelected ? Colors.white : (hasPhoto ? const Color(0xFFF0FDF4) : Colors.white),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isColorSelected
                                        ? AppTheme.brandSteel
                                        : (hasPhoto ? const Color(0xFFBBF7D0) : AppTheme.standardBorder),
                                    width: isColorSelected ? 1.8 : 1.0,
                                  ),
                                ),
                                child: Row(
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
                                    const SizedBox(width: 6),
                                    Text(
                                      colName,
                                      style: GoogleFonts.publicSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isColorSelected ? AppTheme.brandSteel : AppTheme.foregroundInk,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    if (hasPhoto)
                                      const Icon(Icons.check_circle, size: 12, color: Color(0xFF16A34A))
                                    else
                                      Text(
                                        'Pending',
                                        style: GoogleFonts.jetBrainsMono(fontSize: 9, color: AppTheme.faintInk),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),

                        // Dropzones for active colorway
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.standardBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Mockups for [$_activeColorwayTab Base ${brief.garmentType}]',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.foregroundInk,
                                    ),
                                  ),
                                  if (currentColorway.photoFront.isNotEmpty)
                                    Row(
                                      children: [
                                        const Icon(Icons.check_circle, size: 12, color: Color(0xFF16A34A)),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Ready',
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF16A34A),
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Front & Back mockups row
                              Row(
                                children: [
                                  // Front Mockup
                                  Expanded(
                                    child: _buildMockupCard(
                                      label: 'Front Artwork *',
                                      photoUrl: currentColorway.photoFront,
                                      isEditable: isEditable,
                                      onAttach: () => _showImageOptionsSheet(_activeConceptTab, _activeColorwayTab, 'front'),
                                      onZoom: () => _openImageDialog(currentColorway.photoFront, '$_activeColorwayTab - Front'),
                                      onRemove: () => setState(() => currentColorway.photoFront = ''),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  // Back Mockup
                                  Expanded(
                                    child: _buildMockupCard(
                                      label: 'Back View (Optional)',
                                      photoUrl: currentColorway.photoBack,
                                      isEditable: isEditable,
                                      onAttach: () => _showImageOptionsSheet(_activeConceptTab, _activeColorwayTab, 'back'),
                                      onZoom: () => _openImageDialog(currentColorway.photoBack, '$_activeColorwayTab - Back'),
                                      onRemove: () => setState(() => currentColorway.photoBack = ''),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Concept Notes
                        Text(
                          'Fabric & Print Notes (Optional)',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.foregroundInk,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          enabled: isEditable,
                          initialValue: currentConcept.notes,
                          onChanged: (val) => currentConcept.notes = val,
                          maxLines: 2,
                          decoration: InputDecoration(
                            hintText: 'e.g. High-density screen print, oversized fit...',
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppTheme.standardBorder),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppTheme.standardBorder),
                            ),
                          ),
                          style: GoogleFonts.publicSans(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Submit Action Button
                  if (isEditable)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: readySlotsCount >= totalSlots
                              ? const Color(0xFF16A34A)
                              : AppTheme.brandSteel,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: (_isUploading || readySlotsCount == 0) ? null : _handleSubmit,
                        child: _isUploading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.cloud_upload_outlined, size: 18, color: Colors.white),
                                  const SizedBox(width: 8),
                                  Text(
                                    isRejected
                                        ? 'Resubmit Revised Work ($readySlotsCount/$totalSlots)'
                                        : 'Submit Work ($readySlotsCount/$totalSlots) for Head Review',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.verified, size: 16, color: Color(0xFF10B981)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'This design concept has been officially greenlit by Super Admin.',
                              style: GoogleFonts.publicSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF065F46),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildMockupCard({
    required String label,
    required String photoUrl,
    required bool isEditable,
    required VoidCallback onAttach,
    required VoidCallback onZoom,
    required VoidCallback onRemove,
  }) {
    final hasPhoto = photoUrl.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
            color: AppTheme.mutedInk,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 120,
          width: double.infinity,
          decoration: BoxDecoration(
            color: hasPhoto ? Colors.white : AppTheme.canvasCream,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: hasPhoto ? AppTheme.standardBorder : AppTheme.standardBorder,
              style: hasPhoto ? BorderStyle.solid : BorderStyle.solid,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: hasPhoto
              ? Stack(
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: onZoom,
                        child: _buildArtworkWidget(photoUrl),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: onZoom,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.zoom_in, color: Colors.white, size: 14),
                            ),
                          ),
                          if (isEditable) ...[
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: onRemove,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE11D48),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(Icons.close, color: Colors.white, size: 14),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                )
              : InkWell(
                  onTap: isEditable ? onAttach : null,
                  borderRadius: BorderRadius.circular(10),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 26,
                          color: isEditable ? AppTheme.brandSteel : AppTheme.faintInk,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isEditable ? 'Tap to Upload' : 'No Artwork',
                          style: GoogleFonts.publicSans(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isEditable ? AppTheme.brandSteel : AppTheme.faintInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg = AppTheme.badgeNeutralBg;
    Color text = AppTheme.brandSteel;
    Color border = AppTheme.badgeNeutralBorder;
    String label = status.replaceAll('_', ' ');

    final isApproved = status == 'PH_APPROVED' || status == 'SA_APPROVED' || status == 'TECH_PACK_CREATED' || status == 'SA_SAVED_FOR_LATER';
    final isRejected = status == 'PH_REJECTED';

    if (status == 'SUBMITTED') {
      bg = AppTheme.badgeAmberBg;
      text = AppTheme.badgeAmberText;
      border = AppTheme.badgeAmberBorder;
      label = 'In Review';
    } else if (isApproved) {
      bg = AppTheme.badgeEmeraldBg;
      text = AppTheme.badgeEmeraldText;
      border = AppTheme.badgeEmeraldBorder;
      label = 'Approved';
    } else if (isRejected) {
      bg = AppTheme.badgeRoseBg;
      text = AppTheme.badgeRoseText;
      border = AppTheme.badgeRoseBorder;
      label = 'Revisions Needed';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.jetBrainsMono(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: text,
        ),
      ),
    );
  }
}
