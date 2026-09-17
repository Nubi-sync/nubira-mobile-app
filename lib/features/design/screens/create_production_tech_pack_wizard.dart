import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/design_brief_model.dart';
import '../providers/designer_provider.dart';

class CreateProductionTechPackWizard extends ConsumerStatefulWidget {
  final bool isEditing;
  final TechPackSummaryModel? initialPack;

  const CreateProductionTechPackWizard({
    super.key,
    this.isEditing = false,
    this.initialPack,
  });

  @override
  ConsumerState<CreateProductionTechPackWizard> createState() => _CreateProductionTechPackWizardState();
}

class _CreateProductionTechPackWizardState extends ConsumerState<CreateProductionTechPackWizard> {
  final PageController _pageController = PageController();
  int _currentStep = 1;

  // ==========================================
  // STEP 1 FORM CONTROLLERS & STATE
  // ==========================================
  String? _selectedArticleId;
  late TextEditingController _styleNumberCtrl;
  late TextEditingController _styleNameCtrl;
  late TextEditingController _fabricCtrl;
  late TextEditingController _gsmCtrl;
  late TextEditingController _instructionsCtrl;

  String _selectedGarmentType = 'Hoodie';
  String _selectedBrand = 'CANDY POP';

  // BOM Form Controllers (4 input fields)
  String _bomComponentType = 'FABRIC';
  final TextEditingController _bomItemNameCtrl = TextEditingController();
  final TextEditingController _bomConsumptionCtrl = TextEditingController();
  final TextEditingController _bomPlacementCtrl = TextEditingController();
  List<TechPackBomItemModel> _bomItems = [];

  // ==========================================
  // STEP 2 FORM CONTROLLERS & STATE
  // ==========================================
  String _selectedEmbellishment = 'NONE';
  String _selectedSizeSystem = 'ALPHA_ADULT';
  late TextEditingController _baseSizeCtrl;
  late TextEditingController _spiCtrl;
  String _selectedSeamClass = 'ISO 4915 Class 504 (Overlock)';
  late DateTime _targetCutDate;

  // Step 1 & 2 Error tracking
  String? _styleNumberError;
  String? _styleNameError;
  String? _fabricError;
  String? _gsmError;
  String? _spiError;

  // Static options
  final List<String> _garmentTypes = [
    'Hoodie',
    'T-Shirt',
    'Polo',
    'Jogger',
    'Jacket',
    'Kids Romper',
    'Suit',
    'Pant',
    'Ethnic',
  ];

  final List<String> _brandsList = [
    'CANDY POP',
    'DIRECT CLIENT',
    'PRIVATE LABEL',
    'GLOBAL BRAND',
    'INHOUSE',
  ];

  final List<Map<String, String>> _sizeSystems = [
    {'value': 'ALPHA_ADULT', 'label': 'Adult Unisex Alpha (XS–3XL)', 'defaultBase': 'M'},
    {'value': 'KIDS_AGE', 'label': 'Toddler & Kids (2T–14)', 'defaultBase': '4T'},
    {'value': 'NUMERIC_WAIST', 'label': 'Numeric Waist Jeans/Trousers (28–42)', 'defaultBase': '32'},
    {'value': 'PLUS_SIZE', 'label': 'Plus Size Silhouette (1X–5X)', 'defaultBase': '2X'},
  ];

  final List<String> _seamClasses = [
    'ISO 4915 Class 401 (Chainstitch)',
    'ISO 4915 Class 504 (Overlock)',
    'ISO 4915 Class 607 (Flatlock)',
  ];

  final List<Map<String, String>> _embellishmentOptions = [
    {
      'value': 'NONE',
      'label': 'No embroidery, no printing',
      'desc': 'Direct cut bundle to sewing line',
    },
    {
      'value': 'PRINT_ONLY',
      'label': 'Only printing',
      'desc': 'Screen / rotary printing before cut bundle joins line',
    },
    {
      'value': 'EMB_ONLY',
      'label': 'Only embroidery',
      'desc': 'Direct hooped embroidery before panel assembly',
    },
    {
      'value': 'EMB_THEN_PRINT',
      'label': 'Embroidery first, then printing',
      'desc': 'Hooped embroidery before screen curing',
    },
    {
      'value': 'PRINT_THEN_EMB',
      'label': 'Printing first, then embroidery',
      'desc': 'Rotary/screen print before chest embroidery',
    },
  ];

  final List<String> _bomComponentTypes = [
    'FABRIC',
    'TRIM',
    'THREAD',
    'LABEL',
    'PACKAGING',
    'ZIPPER',
    'BUTTON',
    'ELASTIC',
  ];

  final Map<String, Map<String, dynamic>> _garmentDefaults = {
    'T-Shirt': {
      'gsm': 180,
      'fabric': '100% Combed Cotton Single Jersey',
      'seam': 'ISO 4915 Class 504 (Overlock)',
      'base': 'M',
      'system': 'ALPHA_ADULT',
    },
    'Hoodie': {
      'gsm': 360,
      'fabric': '3-End French Terry 360 GSM Brushed Inside',
      'seam': 'ISO 4915 Class 504 (Overlock)',
      'base': 'M',
      'system': 'ALPHA_ADULT',
    },
    'Polo': {
      'gsm': 220,
      'fabric': '100% Cotton Pique Double Knit',
      'seam': 'ISO 4915 Class 401 (Chainstitch)',
      'base': 'M',
      'system': 'ALPHA_ADULT',
    },
    'Suit': {
      'gsm': 260,
      'fabric': 'Super 120s Wool Worsted',
      'seam': 'ISO 4915 Class 401 (Chainstitch)',
      'base': 'M',
      'system': 'ALPHA_ADULT',
    },
    'Pant': {
      'gsm': 280,
      'fabric': '98% Cotton 2% Elastane Twill',
      'seam': 'ISO 4915 Class 401 (Chainstitch)',
      'base': '32',
      'system': 'NUMERIC_WAIST',
    },
    'Jogger': {
      'gsm': 320,
      'fabric': 'Cotton Elastane Loopback Fleece',
      'seam': 'ISO 4915 Class 504 (Overlock)',
      'base': 'M',
      'system': 'ALPHA_ADULT',
    },
    'Jacket': {
      'gsm': 300,
      'fabric': 'Polyester Shell with Quilted Lining',
      'seam': 'ISO 4915 Class 401 (Chainstitch)',
      'base': 'L',
      'system': 'ALPHA_ADULT',
    },
    'Kids Romper': {
      'gsm': 160,
      'fabric': '100% Organic Interlock Cotton',
      'seam': 'ISO 4915 Class 607 (Flatlock)',
      'base': '4T',
      'system': 'KIDS_AGE',
    },
    'Ethnic': {
      'gsm': 200,
      'fabric': 'Pure Raw Silk / Chanderi Cotton Blend',
      'seam': 'ISO 4915 Class 401 (Chainstitch)',
      'base': 'M',
      'system': 'ALPHA_ADULT',
    },
  };

  @override
  void initState() {
    super.initState();
    final p = widget.initialPack;

    _styleNumberCtrl = TextEditingController(text: p?.styleNumber ?? '');
    _styleNameCtrl = TextEditingController(text: p?.styleName ?? '');
    _fabricCtrl = TextEditingController(text: p?.cleanFabricComposition ?? '3-End French Terry 360 GSM Brushed Inside');
    _gsmCtrl = TextEditingController(text: (p?.targetGsm ?? 360).toString());
    _instructionsCtrl = TextEditingController(text: p?.cleanInstructions ?? '');
    _baseSizeCtrl = TextEditingController(text: p?.baseSize ?? 'M');
    _spiCtrl = TextEditingController(text: (p?.spi ?? 12).toString());

    _targetCutDate = DateTime.now().add(const Duration(days: 14));
    if (p?.targetCutDate != null && p!.targetCutDate!.isNotEmpty) {
      final parsed = DateTime.tryParse(p.targetCutDate!);
      if (parsed != null) _targetCutDate = parsed;
    }

    if (p != null) {
      _selectedGarmentType = _normalizeGarmentType(p.category);
      _selectedBrand = p.brandName;
      _selectedSizeSystem = p.sizeSystem;
      _selectedEmbellishment = _normalizeEmbellishment(p.embellishmentSequence);
      _selectedSeamClass = p.seamClass;
      _bomItems = List.from(p.bomItems);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _styleNumberCtrl.dispose();
    _styleNameCtrl.dispose();
    _fabricCtrl.dispose();
    _gsmCtrl.dispose();
    _instructionsCtrl.dispose();
    _baseSizeCtrl.dispose();
    _spiCtrl.dispose();
    _bomItemNameCtrl.dispose();
    _bomConsumptionCtrl.dispose();
    _bomPlacementCtrl.dispose();
    super.dispose();
  }

  String _normalizeGarmentType(String raw) {
    for (final t in _garmentTypes) {
      if (raw.toLowerCase().contains(t.toLowerCase())) return t;
    }
    return 'Hoodie';
  }

  String _normalizeEmbellishment(String raw) {
    final norm = raw.trim().toUpperCase();
    if (norm == 'NONE') return 'NONE';
    if (norm.contains('PRINT') && norm.contains('EMB')) {
      if (norm.indexOf('EMB') < norm.indexOf('PRINT')) {
        return 'EMB_THEN_PRINT';
      }
      return 'PRINT_THEN_EMB';
    }
    if (norm.contains('PRINT')) return 'PRINT_ONLY';
    if (norm.contains('EMB')) return 'EMB_ONLY';
    return 'NONE';
  }

  void _onGarmentTypeChanged(String newType) {
    setState(() {
      _selectedGarmentType = newType;
      final def = _garmentDefaults[newType];
      if (def != null) {
        _gsmCtrl.text = def['gsm'].toString();
        _fabricCtrl.text = def['fabric'] as String;
        _selectedSeamClass = def['seam'] as String;
        _baseSizeCtrl.text = def['base'] as String;
        _selectedSizeSystem = def['system'] as String;
      }
      if (_styleNameCtrl.text.isEmpty || _styleNameCtrl.text.contains('Style')) {
        _styleNameCtrl.text = '$newType Style ${_styleNumberCtrl.text.trim()}'.trim();
      }
    });
  }

  void _onArticleSelected(DesignBriefModel brief) {
    setState(() {
      _selectedArticleId = brief.id;
      final gType = _normalizeGarmentType(brief.garmentType);
      _selectedGarmentType = gType;
      _styleNumberCtrl.text = 'ART-${brief.id.substring(0, brief.id.length > 6 ? 6 : brief.id.length).toUpperCase()}';
      _styleNameCtrl.text = '${brief.garmentType} ${brief.category}'.trim();
      _onGarmentTypeChanged(gType);
    });
  }

  void _addBomItem() {
    final itemName = _bomItemNameCtrl.text.trim();
    if (itemName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an item description for the BOM component.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    final consumption = _bomConsumptionCtrl.text.trim().isNotEmpty ? _bomConsumptionCtrl.text.trim() : '1 PC';
    final placement = _bomPlacementCtrl.text.trim().isNotEmpty ? _bomPlacementCtrl.text.trim() : 'Standard';

    setState(() {
      _bomItems.add(TechPackBomItemModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        componentType: _bomComponentType,
        itemName: itemName,
        specification: 'Standard',
        consumption: consumption,
        placement: placement,
      ));

      // Clear the 4 fields for rapid entry
      _bomItemNameCtrl.clear();
      _bomConsumptionCtrl.clear();
      _bomPlacementCtrl.clear();
    });
  }

  bool _validateStep1() {
    bool valid = true;
    setState(() {
      if (_styleNumberCtrl.text.trim().isEmpty) {
        _styleNumberError = 'Style / Art number is required';
        valid = false;
      } else {
        _styleNumberError = null;
      }

      if (_styleNameCtrl.text.trim().isEmpty) {
        _styleNameError = 'Style description is required';
        valid = false;
      } else {
        _styleNameError = null;
      }

      if (_fabricCtrl.text.trim().isEmpty) {
        _fabricError = 'Shell fabric composition is required';
        valid = false;
      } else {
        _fabricError = null;
      }

      final gsmVal = int.tryParse(_gsmCtrl.text.trim());
      if (gsmVal == null || gsmVal < 50 || gsmVal > 800) {
        _gsmError = 'Valid GSM between 50 and 800 required';
        valid = false;
      } else {
        _gsmError = null;
      }
    });
    return valid;
  }

  bool _validateStep2() {
    bool valid = true;
    setState(() {
      final spiVal = int.tryParse(_spiCtrl.text.trim());
      if (spiVal == null || spiVal < 6 || spiVal > 24) {
        _spiError = 'Stitches per inch must be between 6 and 24';
        valid = false;
      } else {
        _spiError = null;
      }
    });
    return valid;
  }

  Future<void> _handleSaveTechPack() async {
    if (!_validateStep1() || !_validateStep2()) {
      if (!_validateStep1()) {
        _goToStep(1);
      }
      return;
    }

    final stNo = _styleNumberCtrl.text.trim().toUpperCase();
    final stName = _styleNameCtrl.text.trim();
    final gsm = int.tryParse(_gsmCtrl.text.trim()) ?? 240;
    final spi = int.tryParse(_spiCtrl.text.trim()) ?? 12;

    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    bool ok = false;
    if (widget.isEditing && widget.initialPack != null) {
      ok = await ref.read(designerProvider.notifier).updateTechPack(
        id: widget.initialPack!.id,
        styleNumber: stNo,
        category: _selectedGarmentType,
        baseSize: _baseSizeCtrl.text.trim(),
        fabricComposition: _fabricCtrl.text.trim(),
        targetGsm: gsm,
        sizeSystem: _selectedSizeSystem,
        embellishmentSequence: _selectedEmbellishment,
        spi: spi,
        seamClass: _selectedSeamClass,
        status: 'APPROVED_BULK',
        instructions: _instructionsCtrl.text.trim(),
        bomItems: _bomItems,
      );
    } else {
      ok = await ref.read(designerProvider.notifier).createTechPack(
        styleNumber: stNo,
        styleName: stName,
        brandName: _selectedBrand,
        category: _selectedGarmentType,
        baseSize: _baseSizeCtrl.text.trim(),
        fabricComposition: _fabricCtrl.text.trim(),
        targetGsm: gsm,
        sizeSystem: _selectedSizeSystem,
        embellishmentSequence: _selectedEmbellishment,
        spi: spi,
        seamClass: _selectedSeamClass,
        instructions: _instructionsCtrl.text.trim(),
        bomItems: _bomItems,
        status: 'APPROVED_BULK',
      );
    }

    if (ok) {
      nav.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Tech-Pack $stNo created & published to Master Catalog!'),
          backgroundColor: const Color(0xFF047857),
        ),
      );
    } else {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Failed to save tech-pack to Supabase.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
    }
  }

  void _goToStep(int step) {
    setState(() => _currentStep = step);
    _pageController.animateToPage(
      step - 1,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  Future<bool> _confirmClose() async {
    final hasChanges = _styleNumberCtrl.text.isNotEmpty ||
        _styleNameCtrl.text.isNotEmpty ||
        _bomItems.isNotEmpty;

    if (!hasChanges) return true;

    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Discard Unsaved Tech-Pack?',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
        content: Text(
          'You have filled specifications in progress. Closing now will discard this draft.',
          style: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Keep Editing',
              style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
            ),
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(designerProvider);

    // Filter approved briefs for article selector
    final approvedBriefs = state.briefs.where((b) {
      final st = b.status.toUpperCase();
      return st == 'PH_APPROVED' || st == 'SA_APPROVED' || st == 'TECH_PACK_CREATED' || st == 'SUBMITTED';
    }).toList();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _confirmClose();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Container(
        height: MediaQuery.of(context).size.height * 0.94,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // ==========================================
            // MODAL HEADER
            // ==========================================
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAF7F0),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0x1A000000)),
                          ),
                          child: const Icon(Icons.assignment_turned_in_outlined, color: Color(0xFF332B6B), size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      widget.isEditing ? 'Edit production tech-pack' : 'Create production tech-pack',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFAF7F0),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0x26332B6B)),
                                    ),
                                    child: Text(
                                      'V1.0',
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF332B6B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Generate production specification with BOM, trims, stitches & CAD coordinates',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.publicSans(
                                  fontSize: 11.5,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
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
            // STEP PROGRESS INDICATOR
            // ==========================================
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFFFAFAF8),
                border: Border(
                  top: BorderSide(color: Color(0xFFF1F5F9)),
                  bottom: BorderSide(color: Color(0xFFF1F5F9)),
                ),
              ),
              child: Row(
                children: [
                  // Step 1 Circle & Label
                  InkWell(
                    onTap: () => _goToStep(1),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: Color(0xFF332B6B),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: _currentStep > 1
                                ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                                : Text(
                                    '1',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '1. Article & BOM',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: _currentStep == 1 ? FontWeight.w800 : FontWeight.w600,
                            color: _currentStep == 1 ? const Color(0xFF332B6B) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Progress Line
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      color: _currentStep == 2 ? const Color(0xFF332B6B) : const Color(0xFFE2E8F0),
                    ),
                  ),

                  // Step 2 Circle & Label
                  InkWell(
                    onTap: () {
                      if (_validateStep1()) _goToStep(2);
                    },
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: _currentStep == 2 ? const Color(0xFF332B6B) : const Color(0xFFE2E8F0),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '2',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: _currentStep == 2 ? Colors.white : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '2. CAD & Seams',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: _currentStep == 2 ? FontWeight.w800 : FontWeight.w600,
                            color: _currentStep == 2 ? const Color(0xFF332B6B) : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ==========================================
            // WIZARD BODY (PAGE VIEW)
            // ==========================================
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep1(approvedBriefs),
                  _buildStep2(),
                ],
              ),
            ),

            // ==========================================
            // WIZARD FOOTER (BOTTOM BAR)
            // ==========================================
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFFAFAF8),
                border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentStep == 2)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _goToStep(1),
                      icon: const Icon(Icons.arrow_back_rounded, size: 16, color: Color(0xFF332B6B)),
                      label: Text('Back', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF332B6B))),
                    )
                  else
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () async {
                        final shouldClose = await _confirmClose();
                        if (shouldClose && context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                      child: Text('Cancel', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
                    ),

                  if (_currentStep == 1)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF332B6B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        if (_validateStep1()) {
                          _goToStep(2);
                        }
                      },
                      child: Row(
                        children: [
                          Text('Continue to Step 2', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward_rounded, size: 16),
                        ],
                      ),
                    )
                  else
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF332B6B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      onPressed: state.isSubmitting ? null : _handleSaveTechPack,
                      child: state.isSubmitting
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Row(
                              children: [
                                const Icon(Icons.check_rounded, size: 16),
                                const SizedBox(width: 6),
                                Text('Save Tech-Pack Specification', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold)),
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

  // ===========================================================================
  // STEP 1 — Article Selection, BOM & Instructions
  // ===========================================================================
  Widget _buildStep1(List<DesignBriefModel> approvedBriefs) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // 1. Highlighted Block: Article Selector Dropdown
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFDF6E7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF0E3C0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'SELECT APPROVED ARTICLE NUMBER (ART #) *',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF8A6D2F),
                      letterSpacing: 0.3,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF0E3C0)),
                    ),
                    child: Text(
                      '${approvedBriefs.length} available',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF8A6D2F),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF0E3C0)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedArticleId,
                    hint: Text('Choose greenlit article from Design Studio...', style: GoogleFonts.publicSans(fontSize: 12.5, color: const Color(0xFF94A3B8))),
                    isExpanded: true,
                    items: [
                      DropdownMenuItem<String>(
                        value: null,
                        child: Text('Custom / New Spec Entry (No linked article)', style: GoogleFonts.publicSans(fontSize: 12.5, color: const Color(0xFF64748B))),
                      ),
                      ...approvedBriefs.map((b) {
                        return DropdownMenuItem<String>(
                          value: b.id,
                          child: Text(
                            'ART-${b.id.substring(0, b.id.length > 6 ? 6 : b.id.length).toUpperCase()} (${b.garmentType} - ${b.category})',
                            style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                          ),
                        );
                      }),
                    ],
                    onChanged: (v) {
                      if (v == null) {
                        setState(() => _selectedArticleId = null);
                      } else {
                        final found = approvedBriefs.firstWhere((b) => b.id == v);
                        _onArticleSelected(found);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2 & 3: Style Number & Garment Product Type
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildInputField(
                label: 'STYLE / ART NUMBER *',
                controller: _styleNumberCtrl,
                hint: 'e.g. DEMO-102',
                errorText: _styleNumberError,
                onChanged: (v) {
                  if (_styleNameCtrl.text.isEmpty || _styleNameCtrl.text.contains('Style')) {
                    _styleNameCtrl.text = '$_selectedGarmentType Style ${v.trim()}'.trim();
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GARMENT PRODUCT TYPE *',
                    style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF475569)),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFDAD9D3)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedGarmentType,
                        isExpanded: true,
                        items: _garmentTypes.map((c) => DropdownMenuItem(value: c, child: Text(c, style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.w600)))).toList(),
                        onChanged: (v) {
                          if (v != null) _onGarmentTypeChanged(v);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 4 & 5: Buyer Brand Client & Style Description
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BUYER / BRAND CLIENT *',
                    style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF475569)),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFDAD9D3)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _brandsList.contains(_selectedBrand) ? _selectedBrand : _brandsList.first,
                        isExpanded: true,
                        items: _brandsList.map((b) => DropdownMenuItem(value: b, child: Text(b, style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.w600)))).toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _selectedBrand = v);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInputField(
                label: 'STYLE DESCRIPTION *',
                controller: _styleNameCtrl,
                hint: 'e.g. Pant Style DEMO-102',
                errorText: _styleNameError,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 6: Two-Column Row: Shell Fabric & Target Weight
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: _buildInputField(
                label: 'SHELL FABRIC COMPOSITION *',
                controller: _fabricCtrl,
                hint: 'e.g. 98% Cotton 2% Elastane Twill',
                errorText: _fabricError,
                maxLines: 2,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TARGET WEIGHT *',
                    style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF475569)),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _gsmError != null ? const Color(0xFFDC2626) : const Color(0xFFDAD9D3)),
                    ),
                    child: TextField(
                      controller: _gsmCtrl,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        hintText: '280',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        suffixIcon: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          margin: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAFAF8),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Text(
                            'GSM',
                            style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_gsmError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(_gsmError!, style: GoogleFonts.publicSans(fontSize: 11, color: const Color(0xFFDC2626))),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // 7: BILL OF MATERIALS (BOM) & TRIMS
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'BILL OF MATERIALS (BOM) & TRIMS',
              style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF332B6B)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF7F0),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0x1A000000)),
              ),
              child: Text(
                '${_bomItems.length} items',
                style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF332B6B)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Highlighted 4-Field BOM Entry Box
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFDF6E7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF0E3C0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('TYPE', style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF8A6D2F))),
                        const SizedBox(height: 4),
                        Container(
                          height: 38,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFF0E3C0)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _bomComponentType,
                              isExpanded: true,
                              items: _bomComponentTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold)))).toList(),
                              onChanged: (v) {
                                if (v != null) setState(() => _bomComponentType = v);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('DESCRIPTION / SPEC', style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF8A6D2F))),
                        const SizedBox(height: 4),
                        Container(
                          height: 38,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFF0E3C0)),
                          ),
                          child: TextField(
                            controller: _bomItemNameCtrl,
                            style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w600),
                            decoration: const InputDecoration(
                              hintText: 'e.g. YKK Metal Zipper',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('CONSUMPTION', style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF8A6D2F))),
                        const SizedBox(height: 4),
                        Container(
                          height: 38,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFF0E3C0)),
                          ),
                          child: TextField(
                            controller: _bomConsumptionCtrl,
                            style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w600),
                            decoration: const InputDecoration(
                              hintText: 'e.g. 1 PC',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PLACEMENT', style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF8A6D2F))),
                        const SizedBox(height: 4),
                        Container(
                          height: 38,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFF0E3C0)),
                          ),
                          child: TextField(
                            controller: _bomPlacementCtrl,
                            style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w600),
                            decoration: const InputDecoration(
                              hintText: 'e.g. Center Front',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF332B6B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                onPressed: _addBomItem,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text('+ Add Material to BOM', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Added BOM List
        if (_bomItems.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAF8),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0), style: BorderStyle.solid),
            ),
            child: Text(
              'No materials added yet. Fill the 4 boxes above and tap "+ Add" to add them to this table.',
              textAlign: TextAlign.center,
              style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF94A3B8)),
            ),
          )
        else
          Column(
            children: _bomItems.asMap().entries.map((e) {
              final idx = e.key;
              final b = e.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF7F0),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0x1A000000)),
                      ),
                      child: Text(b.componentType, style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF332B6B))),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${b.itemName} (${b.consumption}) • ${b.placement}',
                        style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                      onPressed: () => setState(() => _bomItems.removeAt(idx)),
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        const SizedBox(height: 14),

        // 8: Additional Instructions
        _buildInputField(
          label: 'ADDITIONAL CONSTRUCTION & PACKAGING INSTRUCTIONS',
          controller: _instructionsCtrl,
          hint: 'e.g. Double needle hem stitch, polybag warning print...',
          maxLines: 2,
        ),
      ],
    );
  }

  // ===========================================================================
  // STEP 2 — CAD Grading & Seam Engineering (Exact field order)
  // ===========================================================================
  Widget _buildStep2() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // 1. Embellishment Routing Rule * (5 selectable radio-cards)
        Text(
          'EMBELLISHMENT ROUTING RULE *',
          style: GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.w800, color: const Color(0xFF332B6B)),
        ),
        const SizedBox(height: 8),
        Column(
          children: _embellishmentOptions.map((opt) {
            final isSel = _selectedEmbellishment == opt['value'];
            return InkWell(
              onTap: () => setState(() => _selectedEmbellishment = opt['value']!),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isSel ? const Color(0xFFFAFAF8) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSel ? const Color(0xFF332B6B) : const Color(0xFFDAD9D3),
                    width: isSel ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: isSel ? const Color(0xFF332B6B) : const Color(0xFF94A3B8), width: 1.5),
                      ),
                      child: isSel
                          ? Center(
                              child: Container(
                                width: 9,
                                height: 9,
                                decoration: const BoxDecoration(color: Color(0xFF332B6B), shape: BoxShape.circle),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(opt['label']!, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                          Text(opt['desc']!, style: GoogleFonts.publicSans(fontSize: 11, color: const Color(0xFF64748B))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),

        // 2 & 3: Size Grading System & Base Golden Sample Size
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SIZE GRADING SYSTEM *',
                    style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF475569)),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFDAD9D3)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedSizeSystem,
                        isExpanded: true,
                        items: _sizeSystems.map((s) {
                          return DropdownMenuItem<String>(
                            value: s['value'],
                            child: Text(s['label']!, style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w600)),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setState(() {
                              _selectedSizeSystem = v;
                              final found = _sizeSystems.firstWhere((s) => s['value'] == v);
                              _baseSizeCtrl.text = found['defaultBase']!;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: _buildInputField(
                label: 'BASE GOLDEN SIZE *',
                controller: _baseSizeCtrl,
                hint: 'e.g. M',
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 4 & 5: SPI & Seam Construction Class
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInputField(
                    label: 'STITCHES / INCH (SPI) *',
                    controller: _spiCtrl,
                    hint: '12',
                    keyboardType: TextInputType.number,
                    errorText: _spiError,
                  ),
                  Text('Default 12 SPI', style: GoogleFonts.publicSans(fontSize: 10.5, color: const Color(0xFF94A3B8))),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SEAM CONSTRUCTION CLASS *',
                    style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF475569)),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFDAD9D3)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedSeamClass,
                        isExpanded: true,
                        items: _seamClasses.map((sc) {
                          return DropdownMenuItem<String>(
                            value: sc,
                            child: Text(sc, style: GoogleFonts.publicSans(fontSize: 11.5, fontWeight: FontWeight.w600)),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _selectedSeamClass = v);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 6: Target Cut Date
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TARGET CUT DATE *',
              style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF475569)),
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _targetCutDate,
                  firstDate: DateTime.now().subtract(const Duration(days: 30)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) {
                  setState(() => _targetCutDate = picked);
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFDAD9D3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _targetCutDate.toIso8601String().split('T').first,
                      style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                    ),
                    const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF332B6B)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // 7: CAD Specifications Ready (Amber Summary Card)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFDF6E7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF0E3C0)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF0E3C0)),
                ),
                child: const Icon(Icons.content_cut_rounded, size: 20, color: Color(0xFF8A6D2F)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CAD SPECIFICATIONS READY',
                      style: GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.w800, color: const Color(0xFF8A6D2F)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Standard $_selectedGarmentType pattern POMs linked to size ${_baseSizeCtrl.text.trim().isNotEmpty ? _baseSizeCtrl.text.trim() : "M"}.',
                      style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_bomItems.length} BOM components and $_selectedSeamClass mapped for production handover.',
                      style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    String? hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? errorText,
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF475569)),
        ),
        const SizedBox(height: 6),
        Container(
          height: maxLines == 1 ? 42 : null,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: errorText != null ? const Color(0xFFDC2626) : const Color(0xFFDAD9D3)),
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            onChanged: onChanged,
            style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.publicSans(fontSize: 12.5, color: const Color(0xFF94A3B8)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(errorText, style: GoogleFonts.publicSans(fontSize: 11, color: const Color(0xFFDC2626))),
          ),
      ],
    );
  }
}
