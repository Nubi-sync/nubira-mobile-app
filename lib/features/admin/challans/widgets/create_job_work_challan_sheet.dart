import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../providers/admin_providers.dart';
import '../utils/challan_excel_helper.dart';

class _ArticleLineItem {
  final TextEditingController artNoController = TextEditingController();
  final TextEditingController subArtNoController = TextEditingController();
  final TextEditingController patternController = TextEditingController();
  final TextEditingController categoryController = TextEditingController();
  final TextEditingController productController = TextEditingController();
  final TextEditingController colorController = TextEditingController(text: '3 COLOUR');
  final TextEditingController sizeRangeController = TextEditingController(text: 'XS-XXL');
  final TextEditingController orderQtyController = TextEditingController();
  final TextEditingController challanQtyController = TextEditingController(text: '90');
  String? assignedLinemanId;
  String? assignedLinemanName;
  bool isExpanded = true;

  int get orderQty => int.tryParse(orderQtyController.text.trim()) ?? 0;
  int get challanQty => int.tryParse(challanQtyController.text.trim()) ?? (orderQty > 0 ? orderQty : 0);

  void dispose() {
    artNoController.dispose();
    subArtNoController.dispose();
    patternController.dispose();
    categoryController.dispose();
    productController.dispose();
    colorController.dispose();
    sizeRangeController.dispose();
    orderQtyController.dispose();
    challanQtyController.dispose();
  }
}

class _BomLotItem {
  String materialType = 'FABRIC';
  final TextEditingController itemNameController = TextEditingController();
  final TextEditingController lotNoController = TextEditingController();
  final TextEditingController requiredQtyController = TextEditingController();
  String status = 'PENDING';

  void dispose() {
    itemNameController.dispose();
    lotNoController.dispose();
    requiredQtyController.dispose();
  }
}

class CreateJobWorkChallanSheet extends ConsumerStatefulWidget {
  const CreateJobWorkChallanSheet({super.key});

  @override
  ConsumerState<CreateJobWorkChallanSheet> createState() => _CreateJobWorkChallanSheetState();
}

class _CreateJobWorkChallanSheetState extends ConsumerState<CreateJobWorkChallanSheet> {
  final _formKey = GlobalKey<FormState>();

  // Colors according to specification
  static const Color brandIndigo = Color(0xFF332B6B);
  static const Color cardBg = Color(0xFFFAFAF8);
  static const Color cardBorder = Color(0xFFECECE8);
  static const Color inputBorder = Color(0xFFDAD9D3);
  static const Color labelColor = Color(0xFF9B9A94);
  static const Color placeholderColor = Color(0xFFB6B4AC);

  final _challanNoController = TextEditingController();
  final _fabricTypeController = TextEditingController(text: '240 GSM BIOWASH 2 THREAD FLEECE');
  final _notesController = TextEditingController();
  final _brandController = TextEditingController(text: 'OLLYPOP');

  DateTime _challanDate = DateTime.now();
  DateTime? _deliveryDate;
  bool _sampleGiven = false;
  bool _isSubmitting = false;
  bool _isDirty = false;
  String? _importBannerMessage;

  final List<_ArticleLineItem> _articleLines = [];
  final List<_BomLotItem> _bomLots = [];

  final List<String> _quickSizes = [
    'L/XXL',
    '22X26',
    '28X32',
    '16X20',
    'M/L/XL',
    'Free Size',
    'XS-XXL',
    '28-36',
    '30-40',
    'Kids 0-5Y',
    'Kids 6-12Y',
  ];

  final List<String> _masterBrands = [
    'OLLYPOP',
    'POKEMON',
    'SUPERMAN',
    'DISNEY',
    'ZIGZA',
    'NUBIRA',
    'CUSTOM',
  ];

  @override
  void initState() {
    super.initState();
    _addBlankArticleLine();
  }

  void _markDirty() {
    if (!_isDirty) {
      setState(() {
        _isDirty = true;
      });
    }
  }

  void _addBlankArticleLine([String? prefilledSize]) {
    _markDirty();
    setState(() {
      final line = _ArticleLineItem();
      if (_articleLines.isNotEmpty) {
        final last = _articleLines.last;
        line.colorController.text = last.colorController.text;
        line.sizeRangeController.text = prefilledSize ?? last.sizeRangeController.text;
        line.categoryController.text = last.categoryController.text;
        line.productController.text = last.productController.text;
      } else if (prefilledSize != null) {
        line.sizeRangeController.text = prefilledSize;
      }
      _articleLines.add(line);
    });
  }

  void _duplicateArticleLine(int index) {
    _markDirty();
    setState(() {
      final source = _articleLines[index];
      final line = _ArticleLineItem();
      line.artNoController.text = source.artNoController.text;
      line.subArtNoController.text = source.subArtNoController.text;
      line.patternController.text = source.patternController.text;
      line.categoryController.text = source.categoryController.text;
      line.productController.text = source.productController.text;
      line.colorController.text = source.colorController.text;
      line.sizeRangeController.text = source.sizeRangeController.text;
      line.orderQtyController.text = source.orderQtyController.text;
      line.challanQtyController.text = source.challanQtyController.text;
      line.assignedLinemanId = source.assignedLinemanId;
      line.assignedLinemanName = source.assignedLinemanName;
      _articleLines.insert(index + 1, line);
    });
  }

  void _removeArticleLine(int index) {
    _markDirty();
    if (_articleLines.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least 1 article line is required.')),
      );
      return;
    }
    setState(() {
      _articleLines[index].dispose();
      _articleLines.removeAt(index);
    });
  }

  void _addBomLot() {
    _markDirty();
    setState(() {
      _bomLots.add(_BomLotItem());
    });
  }

  void _removeBomLot(int index) {
    _markDirty();
    setState(() {
      _bomLots[index].dispose();
      _bomLots.removeAt(index);
    });
  }

  int get _totalArticleLinesCount => _articleLines.where((l) => l.artNoController.text.trim().isNotEmpty).length;

  int get _grandTotalPcs {
    return _articleLines.fold<int>(0, (sum, line) {
      final qty = int.tryParse(line.challanQtyController.text.trim());
      if (qty != null && qty > 0) return sum + qty;
      final oQty = int.tryParse(line.orderQtyController.text.trim());
      return sum + (oQty ?? 0);
    });
  }

  bool get _isFormValid {
    if (_challanNoController.text.trim().isEmpty) return false;
    if (_brandController.text.trim().isEmpty) return false;
    if (_articleLines.isEmpty) return false;
    for (var line in _articleLines) {
      if (line.artNoController.text.trim().isEmpty) return false;
      if (line.colorController.text.trim().isEmpty) return false;
      if (line.sizeRangeController.text.trim().isEmpty) return false;
    }
    return true;
  }

  Future<bool> _confirmDiscardChanges() async {
    if (!_isDirty) return true;
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Discard Unsaved Challan?',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 17, color: const Color(0xFF0F172A)),
        ),
        content: Text(
          'You have unsaved changes in this challan entry. Are you sure you want to close without saving?',
          style: GoogleFonts.publicSans(fontSize: 14, color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Keep Editing', style: GoogleFonts.publicSans(fontWeight: FontWeight.w600, color: brandIndigo)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Discard', style: GoogleFonts.publicSans(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    return res == true;
  }

  Future<void> _handleImportExcel() async {
    final parsed = await ChallanExcelHelper.pickAndParseExcel(context);
    if (parsed == null) return;

    _markDirty();
    setState(() {
      if (parsed.challanNo != null && parsed.challanNo!.isNotEmpty) {
        _challanNoController.text = parsed.challanNo!;
      }
      if (parsed.brand != null && parsed.brand!.isNotEmpty) {
        _brandController.text = parsed.brand!;
      }
      if (parsed.fabricType != null && parsed.fabricType!.isNotEmpty) {
        _fabricTypeController.text = parsed.fabricType!;
      }
      if (parsed.specialRemarks != null && parsed.specialRemarks!.isNotEmpty) {
        _notesController.text = parsed.specialRemarks!;
      }
      if (parsed.challanDate != null) {
        _challanDate = parsed.challanDate!;
      }
      if (parsed.deliveryDate != null) {
        _deliveryDate = parsed.deliveryDate!;
      }

      // Replace or populate article lines
      for (var l in _articleLines) {
        l.dispose();
      }
      _articleLines.clear();

      for (var pLine in parsed.articleLines) {
        final line = _ArticleLineItem();
        line.artNoController.text = pLine.artNo;
        line.subArtNoController.text = pLine.subArtNo ?? '';
        line.colorController.text = pLine.colorPattern ?? '3 COLOUR';
        line.categoryController.text = pLine.category ?? '';
        line.productController.text = pLine.product ?? '';
        line.sizeRangeController.text = pLine.sizeRange ?? 'Free Size';
        if (pLine.orderQty != null && pLine.orderQty! > 0) {
          line.orderQtyController.text = pLine.orderQty.toString();
        }
        line.challanQtyController.text = pLine.totalPcs.toString();
        line.assignedLinemanName = pLine.linemanName;
        _articleLines.add(line);
      }

      _importBannerMessage = 'Imported ${parsed.articleLines.length} article lines successfully from Excel!';
    });
  }

  Future<void> _handleSaveAndSendToFloor() async {
    if (!_isFormValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFE11D48),
          content: Text('Please fill all required fields marked with * before saving.'),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final articlePayload = _articleLines.map((line) {
        final pcs = line.challanQty > 0 ? line.challanQty : (line.orderQty > 0 ? line.orderQty : 10);
        return {
          'art_no': line.artNoController.text.trim().toUpperCase(),
          'sub_art_no': line.subArtNoController.text.trim().toUpperCase(),
          'pattern_no': line.productController.text.trim().isNotEmpty ? line.productController.text.trim() : line.patternController.text.trim(),
          'category': line.categoryController.text.trim(),
          'product': line.productController.text.trim(),
          'color_pattern': line.colorController.text.trim(),
          'size_range': line.sizeRangeController.text.trim(),
          'order_qty': line.orderQty > 0 ? line.orderQty : null,
          'sets': 1,
          'pcs_per_set': pcs,
          'total_pcs': pcs,
          'assigned_lineman_id': line.assignedLinemanId,
          'assigned_lineman_name': line.assignedLinemanName,
          'status': (line.assignedLinemanId != null && line.assignedLinemanId!.isNotEmpty) ? 'IN_PROGRESS' : 'PENDING',
        };
      }).toList();

      final bomPayload = _bomLots.where((b) => b.itemNameController.text.trim().isNotEmpty).map((b) {
        return {
          'material_type': b.materialType,
          'item_name': b.itemNameController.text.trim(),
          'lot_no': b.lotNoController.text.trim(),
          'required_qty': b.requiredQtyController.text.trim(),
          'status': b.status,
        };
      }).toList();

      final err = await createChallanInSupabase(
        challanNo: _challanNoController.text.trim(),
        challanDate: DateFormat('yyyy-MM-dd').format(_challanDate),
        brand: _brandController.text.trim(),
        deliveryDate: _deliveryDate != null ? DateFormat('yyyy-MM-dd').format(_deliveryDate!) : null,
        fabricType: _fabricTypeController.text.trim(),
        sampleGiven: _sampleGiven,
        notes: _notesController.text.trim(),
        articleLines: articlePayload,
        bomItems: bomPayload,
      );

      if (!mounted) return;

      if (err != null) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFE11D48),
            content: Text(err),
          ),
        );
      } else {
        // Invalidate providers for real-time instant sync
        ref.invalidate(challanGroupedOrdersProvider);
        ref.invalidate(adminDashboardProvider);

        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: brandIndigo,
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Challan #${_challanNoController.text.trim().toUpperCase()} created and sent to floor!',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFE11D48),
            content: Text('Failed to save challan: $e'),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _challanNoController.dispose();
    _fabricTypeController.dispose();
    _notesController.dispose();
    _brandController.dispose();
    for (var l in _articleLines) {
      l.dispose();
    }
    for (var b in _bomLots) {
      b.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final employeesAsync = ref.watch(adminEmployeesListProvider);
    final masterArticlesAsync = ref.watch(adminArticlesListProvider);

    final linemenList = employeesAsync.value
            ?.where((e) => e.role.toUpperCase() == 'LINEMAN' || e.role.toUpperCase() == 'OPERATOR')
            .toList() ??
        [];

    final knownArticleCodes = masterArticlesAsync.value?.map((a) => a.artNo).toSet().toList() ?? [];

    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldClose = await _confirmDiscardChanges();
        if (shouldClose && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Container(
        height: MediaQuery.of(context).size.height * 0.94,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // ==========================================
            // HEADER (STICKY TOP)
            // ==========================================
            _buildStickyHeader(),

            // Import Success Alert Banner
            if (_importBannerMessage != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Color(0xFF059669), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _importBannerMessage!,
                        style: GoogleFonts.publicSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF065F46),
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => _importBannerMessage = null),
                      child: const Icon(Icons.close, color: Color(0xFF059669), size: 16),
                    ),
                  ],
                ),
              ),

            // ==========================================
            // BODY (SCROLLABLE FORM)
            // ==========================================
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // SECTION 1: CHALLAN HEADER
                      _buildSection1ChallanHeader(),

                      const SizedBox(height: 20),

                      // SECTION 2: ARTICLE LINES MATRIX
                      _buildSection2ArticleMatrix(linemenList, knownArticleCodes),

                      const SizedBox(height: 20),

                      // SECTION 3: BOM / MATERIALS (OPTIONAL)
                      _buildSection3BomMaterials(),
                    ],
                  ),
                ),
              ),
            ),

            // ==========================================
            // FOOTER (STICKY BOTTOM)
            // ==========================================
            _buildStickyFooter(),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // HEADER WIDGET
  // ==========================================
  Widget _buildStickyHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: cardBorder, width: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF7F0),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cardBorder),
                ),
                child: const Icon(Icons.receipt_long_rounded, color: brandIndigo, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'New job work delivery challan',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Enter multi-article cutting lots, sizes, and BOM materials directly or import via Excel',
                      style: GoogleFonts.publicSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () async {
                  final shouldClose = await _confirmDiscardChanges();
                  if (shouldClose && mounted) {
                    Navigator.of(context).pop();
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.close, size: 18, color: Color(0xFF475569)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Action Button: Import Excel
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: brandIndigo,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
              ),
              onPressed: _handleImportExcel,
              icon: const Icon(Icons.cloud_upload_outlined, size: 17, color: Colors.white),
              label: Text(
                'Import from Excel (.xlsx / .xls)',
                style: GoogleFonts.publicSans(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SECTION 1: CHALLAN HEADER
  // ==========================================
  Widget _buildSection1ChallanHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section marker
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: brandIndigo,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '1. CHALLAN HEADER',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF334155),
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Two-column row: Challan No & Challan Date
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('JOB / CHALLAN NO. *'),
                    const SizedBox(height: 5),
                    _buildTextInput(
                      controller: _challanNoController,
                      placeholder: 'e.g. JOB-457',
                      onChanged: (val) => _markDirty(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('CHALLAN DATE *'),
                    const SizedBox(height: 5),
                    _buildDatePickerTrigger(
                      date: _challanDate,
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _challanDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                          builder: (context, child) {
                            return Theme(
                              data: ThemeData.light().copyWith(
                                colorScheme: const ColorScheme.light(primary: brandIndigo),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          _markDirty();
                          setState(() => _challanDate = picked);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Two-column row: Brand & Fabric Type
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('BRAND / PARTY *'),
                    const SizedBox(height: 5),
                    _buildBrandDropdownOrInput(),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('FABRIC TYPE'),
                    const SizedBox(height: 5),
                    _buildTextInput(
                      controller: _fabricTypeController,
                      placeholder: 'e.g. PRINTED SINKER',
                      onChanged: (val) => _markDirty(),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Expected Delivery Date
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('EXPECTED DELIVERY DATE'),
                    const SizedBox(height: 5),
                    _buildDatePickerTrigger(
                      date: _deliveryDate,
                      placeholder: 'Select due date',
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _deliveryDate ?? DateTime.now().add(const Duration(days: 7)),
                          firstDate: DateTime.now().subtract(const Duration(days: 30)),
                          lastDate: DateTime(2035),
                          builder: (context, child) {
                            return Theme(
                              data: ThemeData.light().copyWith(
                                colorScheme: const ColorScheme.light(primary: brandIndigo),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          _markDirty();
                          setState(() => _deliveryDate = picked);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Checkbox: Ready sample given
          InkWell(
            onTap: () {
              _markDirty();
              setState(() => _sampleGiven = !_sampleGiven);
            },
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                _buildCustomCheckbox(isChecked: _sampleGiven),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Ready sample given (approved by buyer)',
                    style: GoogleFonts.publicSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Special Notes / Remarks
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFieldLabel('SPECIAL NOTES / REMARKS'),
              const SizedBox(height: 5),
              _buildTextInput(
                controller: _notesController,
                placeholder: 'e.g. Body+Rib N.P, Ext=3x27, 2=18, 1=9...',
                maxLines: 2,
                onChanged: (val) => _markDirty(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SECTION 2: ARTICLE LINES MATRIX
  // ==========================================
  Widget _buildSection2ArticleMatrix(List<dynamic> linemen, List<String> masterArticleCodes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Marker + Live Count
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: brandIndigo,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '2. ARTICLE LINES MATRIX (${_articleLines.length} LINES)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF334155),
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            // Expand all / collapse all button
            if (_articleLines.length > 1)
              InkWell(
                onTap: () {
                  final allExp = _articleLines.every((l) => l.isExpanded);
                  setState(() {
                    for (var l in _articleLines) {
                      l.isExpanded = !allExp;
                    }
                  });
                },
                child: Text(
                  _articleLines.every((l) => l.isExpanded) ? 'Collapse all' : 'Expand all',
                  style: GoogleFonts.publicSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: brandIndigo,
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 10),

        // Horizontal Quick-Size chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              Text(
                'Quick sizes:',
                style: GoogleFonts.publicSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: labelColor,
                ),
              ),
              const SizedBox(width: 8),
              ..._quickSizes.map((sz) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: cardBorder, width: 0.8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    label: Text(
                      '+ $sz',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF334155),
                      ),
                    ),
                    onPressed: () {
                      _addBlankArticleLine(sz);
                    },
                  ),
                );
              }),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // List of Article Line Cards
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _articleLines.length,
          separatorBuilder: (ctx, i) => const SizedBox(height: 10),
          itemBuilder: (ctx, idx) {
            return _buildArticleLineCard(idx, _articleLines[idx], linemen, masterArticleCodes);
          },
        ),

        const SizedBox(height: 10),

        // Dashed "+ Add article line" button
        _buildDashedAddButton(
          label: '+ Add article line',
          onTap: () => _addBlankArticleLine(),
        ),
      ],
    );
  }

  Widget _buildArticleLineCard(
    int index,
    _ArticleLineItem line,
    List<dynamic> linemen,
    List<String> masterArticleCodes,
  ) {
    final artNoDisplay = line.artNoController.text.trim();
    final colorDisplay = line.colorController.text.trim();
    final sizeDisplay = line.sizeRangeController.text.trim();

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          InkWell(
            onTap: () => setState(() => line.isExpanded = !line.isExpanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: brandIndigo.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'LINE ${index + 1}',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: brandIndigo,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Row(
                      children: [
                        if (artNoDisplay.isNotEmpty)
                          Flexible(
                            child: Text(
                              artNoDisplay,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                        if (colorDisplay.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '• $colorDisplay',
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.publicSans(
                                fontSize: 11,
                                color: const Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                        if (sizeDisplay.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: cardBorder),
                            ),
                            child: Text(
                              sizeDisplay,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF334155),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Duplicate button
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 15, color: Color(0xFF64748B)),
                    onPressed: () => _duplicateArticleLine(index),
                    tooltip: 'Duplicate Line',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                  ),
                  // Delete button
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFE11D48)),
                    onPressed: () => _removeArticleLine(index),
                    tooltip: 'Delete Line',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                  ),
                  Icon(
                    line.isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 19,
                    color: const Color(0xFF64748B),
                  ),
                ],
              ),
            ),
          ),

          if (line.isExpanded) ...[
            const Divider(height: 1, color: cardBorder),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Art No * + Colour *
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel('ART NO *'),
                            const SizedBox(height: 5),
                            _buildTextInput(
                              controller: line.artNoController,
                              placeholder: 'e.g. 9437',
                              onChanged: (val) {
                                _markDirty();
                                setState(() {});
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel('COLOUR *'),
                            const SizedBox(height: 5),
                            _buildTextInput(
                              controller: line.colorController,
                              placeholder: 'e.g. ROBIN BLUE',
                              onChanged: (val) {
                                _markDirty();
                                setState(() {});
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Row 2: Category + Product
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel('CATEGORY'),
                            const SizedBox(height: 5),
                            _buildTextInput(
                              controller: line.categoryController,
                              placeholder: 'e.g. Suit',
                              onChanged: (val) => _markDirty(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel('PRODUCT'),
                            const SizedBox(height: 5),
                            _buildTextInput(
                              controller: line.productController,
                              placeholder: 'e.g. Pant',
                              onChanged: (val) => _markDirty(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Row 3: Size * + Order Qty
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel('SIZE *'),
                            const SizedBox(height: 5),
                            _buildTextInput(
                              controller: line.sizeRangeController,
                              placeholder: 'e.g. XS-XXL, 22',
                              onChanged: (val) {
                                _markDirty();
                                setState(() {});
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel('ORDER QTY'),
                            const SizedBox(height: 5),
                            _buildTextInput(
                              controller: line.orderQtyController,
                              placeholder: 'e.g. 384',
                              keyboardType: TextInputType.number,
                              onChanged: (val) {
                                _markDirty();
                                if (line.challanQtyController.text.trim().isEmpty || line.challanQtyController.text == '0') {
                                  line.challanQtyController.text = val;
                                }
                                setState(() {});
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Row 4: Challan Qty (Pcs) * + Assign Lineman
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel('CHALLAN QTY (PCS) *'),
                            const SizedBox(height: 5),
                            _buildTextInput(
                              controller: line.challanQtyController,
                              placeholder: 'e.g. 392',
                              keyboardType: TextInputType.number,
                              onChanged: (val) {
                                _markDirty();
                                setState(() {});
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel('ASSIGN LINEMAN'),
                            const SizedBox(height: 5),
                            _buildLinemanDropdown(line, linemen),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // SECTION 3: BOM / RAW MATERIALS (OPTIONAL)
  // ==========================================
  Widget _buildSection3BomMaterials() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: brandIndigo,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '3. BOM / MATERIALS (OPTIONAL)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF334155),
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          if (_bomLots.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cardBorder, style: BorderStyle.solid),
              ),
              child: Text(
                'No BOM material lots added yet. Tap \'+ Add material lot\' to specify fabric roll lots (e.g. Mushroom T-03) or brand labels.',
                textAlign: TextAlign.center,
                style: GoogleFonts.publicSans(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _bomLots.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 8),
              itemBuilder: (ctx, bIdx) {
                final bom = _bomLots[bIdx];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cardBorder),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextInput(
                              controller: bom.itemNameController,
                              placeholder: 'Material Name (e.g. Body Fabric)',
                              onChanged: (val) => _markDirty(),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Color(0xFFE11D48), size: 18),
                            onPressed: () => _removeBomLot(bIdx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextInput(
                              controller: bom.lotNoController,
                              placeholder: 'Lot # (e.g. T-03)',
                              onChanged: (val) => _markDirty(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildTextInput(
                              controller: bom.requiredQtyController,
                              placeholder: 'Qty / Rolls',
                              onChanged: (val) => _markDirty(),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),

          const SizedBox(height: 12),

          // Dashed "+ Add material lot" button
          _buildDashedAddButton(
            label: '+ Add material lot',
            onTap: _addBomLot,
          ),
        ],
      ),
    );
  }

  // ==========================================
  // FOOTER WIDGET
  // ==========================================
  Widget _buildStickyFooter() {
    final valid = _isFormValid;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: cardBorder, width: 0.8)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Live Summary Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'Total lines: ',
                    style: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '$_totalArticleLinesCount',
                    style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    'Challan qty: ',
                    style: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '$_grandTotalPcs pcs',
                    style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.w800, color: brandIndigo),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Buttons Row: Cancel & Save
          Row(
            children: [
              Expanded(
                flex: 2,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: cardBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  onPressed: () async {
                    final shouldClose = await _confirmDiscardChanges();
                    if (shouldClose && mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.publicSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF475569),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 4,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandIndigo,
                    disabledBackgroundColor: brandIndigo.withValues(alpha: 0.4),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  onPressed: (_isSubmitting || !valid) ? null : _handleSaveAndSendToFloor,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          'Save & send to floor',
                          style: GoogleFonts.publicSans(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // HELPER UI BUILDERS
  // ==========================================

  Widget _buildFieldLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 10,
        fontWeight: FontWeight.bold,
        color: labelColor,
        letterSpacing: 0.6,
      ),
    );
  }

  Widget _buildTextInput({
    required TextEditingController controller,
    required String placeholder,
    int maxLines = 1,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: inputBorder, width: 0.8),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        onChanged: onChanged,
        style: GoogleFonts.publicSans(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF0F172A),
        ),
        decoration: InputDecoration(
          isDense: true,
          hintText: placeholder,
          hintStyle: GoogleFonts.publicSans(fontSize: 12, color: placeholderColor),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: brandIndigo, width: 1.2),
          ),
        ),
      ),
    );
  }

  Widget _buildDatePickerTrigger({
    required DateTime? date,
    String placeholder = 'Select date',
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: inputBorder, width: 0.8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              date != null ? DateFormat('dd MMM yyyy').format(date) : placeholder,
              style: GoogleFonts.publicSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: date != null ? const Color(0xFF0F172A) : placeholderColor,
              ),
            ),
            const Icon(Icons.calendar_today_outlined, size: 15, color: Color(0xFF64748B)),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandDropdownOrInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: inputBorder, width: 0.8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Autocomplete<String>(
        initialValue: TextEditingValue(text: _brandController.text),
        optionsBuilder: (textEditingValue) {
          if (textEditingValue.text.isEmpty) {
            return _masterBrands;
          }
          return _masterBrands.where((b) => b.toLowerCase().contains(textEditingValue.text.toLowerCase()));
        },
        onSelected: (selection) {
          _markDirty();
          _brandController.text = selection;
        },
        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
          controller.addListener(() {
            _brandController.text = controller.text;
          });
          return TextField(
            controller: controller,
            focusNode: focusNode,
            style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'e.g. OLLYPOP',
              hintStyle: GoogleFonts.publicSans(fontSize: 12, color: placeholderColor),
              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              border: InputBorder.none,
            ),
          );
        },
      ),
    );
  }

  Widget _buildLinemanDropdown(_ArticleLineItem line, List<dynamic> linemen) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: inputBorder, width: 0.8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: line.assignedLinemanId,
          isExpanded: true,
          hint: Text(
            line.assignedLinemanName ?? 'Assign later...',
            style: GoogleFonts.publicSans(fontSize: 12, color: placeholderColor),
            overflow: TextOverflow.ellipsis,
          ),
          icon: const Icon(Icons.arrow_drop_down, size: 20, color: Color(0xFF64748B)),
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text(
                'Assign later...',
                style: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF64748B)),
              ),
            ),
            ...linemen.map((lm) {
              return DropdownMenuItem<String>(
                value: lm.id.toString(),
                child: Text(
                  lm.username.toString(),
                  style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                ),
              );
            }),
          ],
          onChanged: (val) {
            _markDirty();
            setState(() {
              line.assignedLinemanId = val;
              final matched = linemen.where((l) => l.id.toString() == val).firstOrNull;
              line.assignedLinemanName = matched?.username?.toString();
            });
          },
        ),
      ),
    );
  }

  Widget _buildCustomCheckbox({required bool isChecked}) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: isChecked ? brandIndigo : Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: isChecked ? brandIndigo : const Color(0xFFCBD5E1), width: 1.2),
      ),
      child: isChecked
          ? const Icon(Icons.check, size: 13, color: Colors.white)
          : null,
    );
  }

  Widget _buildDashedAddButton({required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFC7C6C0), style: BorderStyle.solid, width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_rounded, size: 16, color: brandIndigo),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.publicSans(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: brandIndigo,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
