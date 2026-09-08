import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/admin_providers.dart';

/// Modal dialog for creating a new Multi-Article Job Work Delivery Challan
class CreateChallanModal extends ConsumerStatefulWidget {
  const CreateChallanModal({super.key});

  @override
  ConsumerState<CreateChallanModal> createState() => _CreateChallanModalState();
}

class _ArticleLineInput {
  final TextEditingController artNoController = TextEditingController();
  final TextEditingController subArtNoController = TextEditingController();
  final TextEditingController patternController = TextEditingController();
  final TextEditingController colorController = TextEditingController(text: '3 COLOUR');
  final TextEditingController sizeRangeController = TextEditingController(text: 'XS-XXL');
  final TextEditingController setsController = TextEditingController(text: '10');
  final TextEditingController pcsPerSetController = TextEditingController(text: '9');
  final TextEditingController stitchingRateController = TextEditingController(text: '20');

  int get sets => int.tryParse(setsController.text.trim()) ?? 1;
  int get pcsPerSet => int.tryParse(pcsPerSetController.text.trim()) ?? 9;
  int get totalPcs => sets * pcsPerSet;

  void dispose() {
    artNoController.dispose();
    subArtNoController.dispose();
    patternController.dispose();
    colorController.dispose();
    sizeRangeController.dispose();
    setsController.dispose();
    pcsPerSetController.dispose();
    stitchingRateController.dispose();
  }
}

class _BomItemInput {
  String materialType = 'FABRIC';
  final TextEditingController itemNameController = TextEditingController();
  final TextEditingController lotNoController = TextEditingController();
  final TextEditingController requiredQtyController = TextEditingController();

  void dispose() {
    itemNameController.dispose();
    lotNoController.dispose();
    requiredQtyController.dispose();
  }
}

class _CreateChallanModalState extends ConsumerState<CreateChallanModal> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final _challanNoController = TextEditingController();
  final _fabricTypeController = TextEditingController(text: '240 GSM BIOWASH 2 THREAD FLEECE');
  final _notesController = TextEditingController();

  String _selectedBrand = 'OLLYPOP';
  DateTime _challanDate = DateTime.now();
  DateTime? _deliveryDate;
  bool _sampleGiven = false;
  bool _isSubmitting = false;

  final List<_ArticleLineInput> _articleLines = [];
  final List<_BomItemInput> _bomItems = [];

  final List<String> _brands = [
    'OLLYPOP',
    'POKEMON',
    'SUPERMAN',
    'DISNEY',
    'ZIGZA',
    'NUBIRA',
    'CUSTOM',
  ];

  final List<String> _commonColors = [
    '3 COLOUR',
    'MUSHROOM, DUTCH BLUE, SCUBA',
    'MUSHROOM',
    'DUTCH BLUE',
    'SCUBA',
    'SUGAR ROSE',
    'CHARCOAL',
    'BLACK',
    'NAVY',
    'WHITE',
  ];

  final List<String> _commonSizeRanges = [
    'XS-XXL',
    'S-XL',
    '28-36',
    '30-40',
    'Free Size',
    'Kids 0-5Y',
    'Kids 6-12Y',
  ];

  @override
  void initState() {
    super.initState();
    // Default 1 article line
    _addArticleLine();
  }

  void _addArticleLine() {
    setState(() {
      final line = _ArticleLineInput();
      if (_articleLines.isNotEmpty) {
        // Copy color and sizes from previous line as convenience
        line.colorController.text = _articleLines.last.colorController.text;
        line.sizeRangeController.text = _articleLines.last.sizeRangeController.text;
        line.setsController.text = _articleLines.last.setsController.text;
        line.pcsPerSetController.text = _articleLines.last.pcsPerSetController.text;
      }
      _articleLines.add(line);
    });
  }

  void _removeArticleLine(int index) {
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

  void _addBomItem() {
    setState(() {
      _bomItems.add(_BomItemInput());
    });
  }

  void _removeBomItem(int index) {
    setState(() {
      _bomItems[index].dispose();
      _bomItems.removeAt(index);
    });
  }

  @override
  void dispose() {
    _challanNoController.dispose();
    _fabricTypeController.dispose();
    _notesController.dispose();
    for (var a in _articleLines) {
      a.dispose();
    }
    for (var b in _bomItems) {
      b.dispose();
    }
    super.dispose();
  }

  int get _grandTotalSets => _articleLines.fold(0, (sum, a) => sum + a.sets);
  int get _grandTotalPcs => _articleLines.fold(0, (sum, a) => sum + a.totalPcs);

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_articleLines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one article style line.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final articlePayload = _articleLines.map((line) {
        final artNo = line.artNoController.text.trim().toUpperCase();
        final subArt = line.subArtNoController.text.trim().toUpperCase();
        final pattern = line.patternController.text.trim().toUpperCase();
        final color = line.colorController.text.trim().toUpperCase();
        final size = line.sizeRangeController.text.trim();
        final rate = double.tryParse(line.stitchingRateController.text.trim()) ?? 20.0;

        return {
          'art_no': artNo,
          'sub_art_no': subArt.isNotEmpty ? subArt : null,
          'pattern_no': pattern.isNotEmpty ? pattern : null,
          'description': pattern.isNotEmpty ? '$artNo - $pattern' : '$artNo - $color ($size)',
          'color_pattern': color,
          'size_range': size,
          'sets': line.sets,
          'pcs_per_set': line.pcsPerSet,
          'total_pcs': line.totalPcs,
          'stitching_rate': rate,
        };
      }).toList();

      final bomPayload = _bomItems
          .where((b) => b.itemNameController.text.trim().isNotEmpty)
          .map((b) => {
                'material_type': b.materialType,
                'item_name': b.itemNameController.text.trim(),
                'lot_no': b.lotNoController.text.trim().isNotEmpty ? b.lotNoController.text.trim() : null,
                'required_qty': b.requiredQtyController.text.trim().isNotEmpty ? b.requiredQtyController.text.trim() : null,
                'status': 'PENDING',
              })
          .toList();

      final error = await createChallanInSupabase(
        challanNo: _challanNoController.text.trim().toUpperCase(),
        challanDate: DateFormat('yyyy-MM-dd').format(_challanDate),
        brand: _selectedBrand,
        deliveryDate: _deliveryDate != null ? DateFormat('yyyy-MM-dd').format(_deliveryDate!) : null,
        fabricType: _fabricTypeController.text.trim().isNotEmpty ? _fabricTypeController.text.trim() : null,
        sampleGiven: _sampleGiven,
        notes: _notesController.text.trim(),
        articleLines: articlePayload,
        bomItems: bomPayload,
      );

      if (!mounted) return;

      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error'), backgroundColor: Colors.red.shade800),
        );
        setState(() => _isSubmitting = false);
      } else {
        // Success
        ref.invalidate(challanGroupedOrdersProvider);
        ref.invalidate(adminDashboardProvider);
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Challan #${_challanNoController.text.trim().toUpperCase()} created successfully!'),
            backgroundColor: const Color(0xFF047857),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating challan: $e'), backgroundColor: Colors.red.shade800),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 780),
        child: Column(
          children: [
            // Dialog Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFFFAFAF8),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(bottom: BorderSide(color: Color(0xFFDAD9D3), width: 0.8)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDEAF6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.post_add_rounded, color: Color(0xFF332B6B), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'New Production Challan',
                          style: TextStyle(
                            color: Color(0xFF1C1C1A),
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Multi-article job work & cutting batch sheet',
                          style: TextStyle(
                            color: Color(0xFF6B6A65),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF6B6A65)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Scrollable Form Body
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    // SECTION 1: Challan Header Details
                    _buildSectionHeader('1. Challan Metadata', Icons.receipt_long_outlined),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _challanNoController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: _inputDecoration('Challan No *', 'e.g. 1044'),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return 'Required';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            value: _brands.contains(_selectedBrand) ? _selectedBrand : _brands.first,
                            decoration: _inputDecoration('Brand *', ''),
                            items: _brands.map((b) {
                              return DropdownMenuItem(value: b, child: Text(b, style: const TextStyle(fontSize: 13)));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedBrand = val);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _challanDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) setState(() => _challanDate = picked);
                            },
                            child: InputDecorator(
                              decoration: _inputDecoration('Challan Date', ''),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    DateFormat('dd MMM yyyy').format(_challanDate),
                                    style: const TextStyle(fontSize: 13, color: Color(0xFF1C1C1A)),
                                  ),
                                  const Icon(Icons.calendar_today, size: 16, color: Color(0xFF332B6B)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _deliveryDate ?? DateTime.now().add(const Duration(days: 7)),
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) setState(() => _deliveryDate = picked);
                            },
                            child: InputDecorator(
                              decoration: _inputDecoration('Delivery Date', 'Optional'),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _deliveryDate != null
                                        ? DateFormat('dd MMM yyyy').format(_deliveryDate!)
                                        : 'Select due date',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: _deliveryDate != null ? const Color(0xFF1C1C1A) : const Color(0xFF9B9A94),
                                    ),
                                  ),
                                  const Icon(Icons.event_available, size: 16, color: Color(0xFF6B6A65)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _fabricTypeController,
                      decoration: _inputDecoration('Fabric Description', 'e.g. 240 GSM BIOWASH 2 THREAD FLEECE'),
                    ),
                    const SizedBox(height: 12),

                    // Sample Given Switch
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFAF8),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFDAD9D3), width: 0.8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.checkroom_outlined, size: 18, color: Color(0xFF332B6B)),
                              SizedBox(width: 8),
                              Text(
                                'Physical Sample Provided to Lineman',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1C1C1A)),
                              ),
                            ],
                          ),
                          Switch.adaptive(
                            value: _sampleGiven,
                            activeColor: const Color(0xFF332B6B),
                            onChanged: (val) => setState(() => _sampleGiven = val),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // SECTION 2: Article Style Lines
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionHeader('2. Article Lines (${_articleLines.length})', Icons.style_outlined),
                        TextButton.icon(
                          onPressed: _addArticleLine,
                          icon: const Icon(Icons.add_circle_outline, size: 18, color: Color(0xFF332B6B)),
                          label: const Text(
                            '+ Add Article Style',
                            style: TextStyle(color: Color(0xFF332B6B), fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    ..._articleLines.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final line = entry.value;
                      return _buildArticleLineCard(idx, line);
                    }),
                    const SizedBox(height: 20),

                    // SECTION 3: BOM / Raw Material Lots (Optional)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionHeader('3. BOM Fabrics / Raw Materials (Optional)', Icons.inventory_2_outlined),
                        TextButton.icon(
                          onPressed: _addBomItem,
                          icon: const Icon(Icons.add, size: 18, color: Color(0xFF332B6B)),
                          label: const Text(
                            '+ Add Material Lot',
                            style: TextStyle(color: Color(0xFF332B6B), fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (_bomItems.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAFAF8),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFECECE8)),
                        ),
                        child: const Text(
                          'No specific raw material lot restrictions added. Standard fabric specs will apply.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF9B9A94)),
                        ),
                      )
                    else
                      ..._bomItems.asMap().entries.map((entry) => _buildBomItemCard(entry.key, entry.value)),

                    const SizedBox(height: 20),

                    // SECTION 4: Notes
                    _buildSectionHeader('4. Production Remarks', Icons.notes_outlined),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 2,
                      decoration: _inputDecoration('Internal Notes / Job Instructions', 'e.g. Wash before stitching...'),
                    ),
                    const SizedBox(height: 20),

                    // Grand Batch Summary Banner
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDEAF6),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF332B6B).withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildSummaryStat('Master Styles', '${_articleLines.length}'),
                          _buildSummaryStat('Grand Total Sets', '$_grandTotalSets Sets'),
                          _buildSummaryStat('Grand Total Pcs', '$_grandTotalPcs Pcs', isHighlight: true),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Dialog Footer Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFFFAFAF8),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(top: BorderSide(color: Color(0xFFDAD9D3), width: 0.8)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Color(0xFFDAD9D3)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B6A65), fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF332B6B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _isSubmitting ? null : _handleSubmit,
                      child: _isSubmitting
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Create Delivery Challan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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

  Widget _buildArticleLineCard(int index, _ArticleLineInput line) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAF8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDAD9D3), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Line #${index + 1}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF332B6B)),
              ),
              if (_articleLines.length > 1)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFE11D48)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _removeArticleLine(index),
                ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                flex: 4,
                child: TextFormField(
                  controller: line.artNoController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: _inputDecoration('Art No *', 'e.g. 5295'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: line.subArtNoController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: _inputDecoration('Suffix', 'e.g. A'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 5,
                child: TextFormField(
                  controller: line.patternController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: _inputDecoration('Pattern Name', 'e.g. HOODED'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: line.colorController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: _inputDecoration('Color / Shades *', 'e.g. 3 COLOUR'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: line.sizeRangeController,
                  decoration: _inputDecoration('Size Range *', 'e.g. XS-XXL'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Quick suggestions chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ..._commonColors.take(4).map((c) => Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: ActionChip(
                        label: Text(c, style: const TextStyle(fontSize: 9, color: Color(0xFF332B6B))),
                        backgroundColor: const Color(0xFFEDEAF6),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onPressed: () => setState(() => line.colorController.text = c),
                      ),
                    )),
                ..._commonSizeRanges.take(3).map((s) => Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: ActionChip(
                        label: Text(s, style: const TextStyle(fontSize: 9, color: Color(0xFF6B6A65))),
                        backgroundColor: const Color(0xFFFAFAF8),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onPressed: () => setState(() => line.sizeRangeController.text = s),
                      ),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: line.setsController,
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration('Sets', '10'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: line.pcsPerSetController,
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration('Pcs / Set', '9'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFDAD9D3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Pcs', style: TextStyle(fontSize: 10, color: Color(0xFF6B6A65))),
                      Text(
                        '${line.totalPcs} pcs',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF1C1C1A)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBomItemCard(int index, _BomItemInput bom) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAF8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDAD9D3), width: 0.8),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<String>(
              value: bom.materialType,
              decoration: _inputDecoration('Type', ''),
              items: const [
                DropdownMenuItem(value: 'FABRIC', child: Text('Fabric', style: TextStyle(fontSize: 12))),
                DropdownMenuItem(value: 'RIB', child: Text('Rib', style: TextStyle(fontSize: 12))),
                DropdownMenuItem(value: 'BUTTON', child: Text('Button', style: TextStyle(fontSize: 12))),
                DropdownMenuItem(value: 'LABEL', child: Text('Label', style: TextStyle(fontSize: 12))),
                DropdownMenuItem(value: 'ACCESSORY', child: Text('Accessory', style: TextStyle(fontSize: 12))),
              ],
              onChanged: (val) {
                if (val != null) setState(() => bom.materialType = val);
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: TextFormField(
              controller: bom.itemNameController,
              decoration: _inputDecoration('Item Name', 'e.g. Scuba Rib'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: bom.requiredQtyController,
              decoration: _inputDecoration('Qty', '100 kg'),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: Color(0xFF6B6A65)),
            onPressed: () => _removeBomItem(index),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF332B6B)),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1C1C1A),
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryStat(String label, String value, {bool isHighlight = false}) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: isHighlight ? const Color(0xFF332B6B) : const Color(0xFF1C1C1A),
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF6B6A65), fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint.isNotEmpty ? hint : null,
      labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF6B6A65)),
      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFFB6B4AC)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      isDense: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFDAD9D3), width: 0.8),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFDAD9D3), width: 0.8),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF332B6B), width: 1.5),
      ),
    );
  }
}
