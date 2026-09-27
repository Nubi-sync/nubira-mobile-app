import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/ready_goods_provider.dart';

class InwardInspectionLotModal extends ConsumerStatefulWidget {
  const InwardInspectionLotModal({super.key});

  @override
  ConsumerState<InwardInspectionLotModal> createState() => _InwardInspectionLotModalState();
}

class _InwardInspectionLotModalState extends ConsumerState<InwardInspectionLotModal> {
  static const Color kCanvasColor = Color(0xFFFAF7F0);
  static const Color kCardBg = Color(0xFFFFFFFF);
  static const Color kPrimaryBrand = Color(0xFF3A3564);
  static const Color kBorderColor = Color(0xFFE7E1D6);
  static const Color kMutedText = Color(0xFF7A7488);
  static const Color kInkText = Color(0xFF232028);

  final _formKey = GlobalKey<FormState>();
  final _lotCodeCtrl = TextEditingController();
  final _poNumberCtrl = TextEditingController();
  final _styleNameCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  final _piecesCtrl = TextEditingController();
  final _washBatchCtrl = TextEditingController();
  final _ironStationCtrl = TextEditingController();
  final _summaryCtrl = TextEditingController();

  String _selectedBuyer = 'Zara International';
  String _selectedSize = 'M';
  bool _hasPrinting = true;
  bool _hasEmbroidery = false;
  String _selectedPriority = 'NORMAL';
  bool _isSubmitting = false;

  final List<String> _sizes = ['XS', 'S', 'M', 'L', 'XL', '2XL', '3XL', 'FREE'];
  final List<String> _priorities = ['NORMAL', 'RUSH', 'CRITICAL'];

  final List<Map<String, dynamic>> _presets = [
    {
      'label': 'T-Shirt (Screen Print)',
      'buyer': 'Zara International',
      'style': 'Heavyweight Boxy Drop-Shoulder Tee',
      'color': 'Onyx Black',
      'size': 'M',
      'pieces': 75,
      'washBatch': 'WB-084 (Bio-Polish Enzyme Wash)',
      'ironStation': 'Vacuum Table 01',
      'hasPrinting': true,
      'hasEmbroidery': false,
      'summary': 'Chest Graphic Screen Print'
    },
    {
      'label': 'Hoodie (Print & Embroidery)',
      'buyer': 'Urban Outfitters',
      'style': 'French Terry Relaxed Hoodie',
      'color': 'Vintage Mineral Wash',
      'size': 'L',
      'pieces': 50,
      'washBatch': 'WB-082 (Silicon Softener Wash)',
      'ironStation': 'Steam Press Board 03',
      'hasPrinting': true,
      'hasEmbroidery': true,
      'summary': 'Chest Embroidery + Back Screen Print'
    },
    {
      'label': 'Polo (Embroidery Only)',
      'buyer': 'Tommy Hilfiger',
      'style': 'Pique Heritage Polo',
      'color': 'Classic Navy',
      'size': 'S',
      'pieces': 60,
      'washBatch': 'WB-081 (Silicone Soft Wash)',
      'ironStation': 'Collar Crease Table 02',
      'hasPrinting': false,
      'hasEmbroidery': true,
      'summary': 'Crest Logo Multi-Head Embroidery'
    },
    {
      'label': 'Denim Overshirt (Plain)',
      'buyer': 'Levi Strauss Co',
      'style': 'Raw Denim Workwear Overshirt',
      'color': 'Indigo Rinse',
      'size': 'XL',
      'pieces': 40,
      'washBatch': 'WB-085 (Stone Wash & Tint)',
      'ironStation': 'Heavy Steam Press 04',
      'hasPrinting': false,
      'hasEmbroidery': false,
      'summary': 'Standard Denim Finish (No Print/Embroidery)'
    }
  ];

  @override
  void initState() {
    super.initState();
    _applyPreset(_presets[0]);
  }

  void _applyPreset(Map<String, dynamic> p) {
    final rng = Random().nextInt(9000) + 1000;
    _lotCodeCtrl.text = 'QC-$rng-01';
    _poNumberCtrl.text = 'PO-${Random().nextInt(1000) + 7000}';
    _selectedBuyer = p['buyer'];
    _styleNameCtrl.text = p['style'];
    _colorCtrl.text = p['color'];
    _selectedSize = p['size'];
    _piecesCtrl.text = p['pieces'].toString();
    _washBatchCtrl.text = p['washBatch'];
    _ironStationCtrl.text = p['ironStation'];
    _hasPrinting = p['hasPrinting'];
    _hasEmbroidery = p['hasEmbroidery'];
    _summaryCtrl.text = p['summary'];
    setState(() {});
  }

  @override
  void dispose() {
    _lotCodeCtrl.dispose();
    _poNumberCtrl.dispose();
    _styleNameCtrl.dispose();
    _colorCtrl.dispose();
    _piecesCtrl.dispose();
    _washBatchCtrl.dispose();
    _ironStationCtrl.dispose();
    _summaryCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      await ref.read(readyGoodsProvider.notifier).inwardLot(
            lotCode: _lotCodeCtrl.text.trim(),
            orderNumber: _poNumberCtrl.text.trim(),
            buyer: _selectedBuyer,
            styleName: _styleNameCtrl.text.trim(),
            color: _colorCtrl.text.trim(),
            size: _selectedSize,
            piecesCount: int.tryParse(_piecesCtrl.text.trim()) ?? 50,
            washBatchRef: _washBatchCtrl.text.trim(),
            ironStationRef: _ironStationCtrl.text.trim(),
            hasPrinting: _hasPrinting,
            hasEmbroidery: _hasEmbroidery,
            printEmbSummary: _summaryCtrl.text.trim(),
            priority: _selectedPriority,
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF16A34A),
            content: Text(
              '✓ Inwarded ${_piecesCtrl.text.trim()} pcs of ${_lotCodeCtrl.text.trim()} to Quality Clinic!',
              style: GoogleFonts.publicSans(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final buyers = ref.watch(readyGoodsProvider).buyers;

    return Dialog(
      backgroundColor: kCardBg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: kBorderColor),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: kCanvasColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                border: Border(bottom: BorderSide(color: kBorderColor)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: kCardBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: kBorderColor),
                    ),
                    child: const Icon(Icons.all_inbox_rounded, color: kPrimaryBrand, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Inward Quality Checking Lot',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: kInkText,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Receive washed & pressed garments for final QC clearance',
                          style: GoogleFonts.publicSans(
                            fontSize: 11,
                            color: kMutedText,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: kCardBg,
                        border: Border.all(color: kBorderColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.close, size: 16, color: kMutedText),
                    ),
                  ),
                ],
              ),
            ),

            // Form Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Quick Presets Selector
                      Text(
                        'QUICK STYLE PRESETS',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: kMutedText,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _presets.map((p) {
                            final isSel = _styleNameCtrl.text == p['style'];
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: InkWell(
                                onTap: () => _applyPreset(p),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isSel ? kPrimaryBrand : kCanvasColor,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: isSel ? kPrimaryBrand : kBorderColor),
                                  ),
                                  child: Text(
                                    p['label'],
                                    style: GoogleFonts.publicSans(
                                      fontSize: 11,
                                      fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                                      color: isSel ? Colors.white : kInkText,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Lot Code & Order Number
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'LOT / BATCH # *',
                                  style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w700, color: kMutedText),
                                ),
                                const SizedBox(height: 4),
                                TextFormField(
                                  controller: _lotCodeCtrl,
                                  style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: kInkText),
                                  decoration: _inputDecoration('e.g. QC-7715-01'),
                                  validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ORDER / PO # *',
                                  style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w700, color: kMutedText),
                                ),
                                const SizedBox(height: 4),
                                TextFormField(
                                  controller: _poNumberCtrl,
                                  style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: kInkText),
                                  decoration: _inputDecoration('e.g. PO-7715'),
                                  validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Buyer Dropdown
                      Text(
                        'BUYER / CLIENT *',
                        style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w700, color: kMutedText),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: kCardBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: kBorderColor),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: buyers.any((b) => b.buyerName == _selectedBuyer)
                                ? _selectedBuyer
                                : (buyers.isNotEmpty ? buyers.first.buyerName : null),
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down, size: 16, color: kPrimaryBrand),
                            items: buyers.map((b) {
                              return DropdownMenuItem(
                                value: b.buyerName,
                                child: Text(
                                  '${b.buyerName} (${b.buyerCode})',
                                  style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w600, color: kInkText),
                                ),
                              );
                            }).toList(),
                            onChanged: (v) {
                              if (v != null) setState(() => _selectedBuyer = v);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Style Name & Color
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('STYLE NAME *', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w700, color: kMutedText)),
                                const SizedBox(height: 4),
                                TextFormField(
                                  controller: _styleNameCtrl,
                                  style: GoogleFonts.publicSans(fontSize: 12, color: kInkText),
                                  decoration: _inputDecoration('e.g. Drop-Shoulder Tee'),
                                  validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('COLOR *', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w700, color: kMutedText)),
                                const SizedBox(height: 4),
                                TextFormField(
                                  controller: _colorCtrl,
                                  style: GoogleFonts.publicSans(fontSize: 12, color: kInkText),
                                  decoration: _inputDecoration('e.g. Onyx Black'),
                                  validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Size & Quantity (Pieces)
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('SIZE *', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w700, color: kMutedText)),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: kCardBg,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: kBorderColor),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedSize,
                                      isExpanded: true,
                                      icon: const Icon(Icons.keyboard_arrow_down, size: 16, color: kPrimaryBrand),
                                      items: _sizes.map((s) {
                                        return DropdownMenuItem(
                                          value: s,
                                          child: Text(s, style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: kInkText)),
                                        );
                                      }).toList(),
                                      onChanged: (v) => setState(() => _selectedSize = v!),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('PIECES (QTY) *', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w700, color: kMutedText)),
                                const SizedBox(height: 4),
                                TextFormField(
                                  controller: _piecesCtrl,
                                  keyboardType: TextInputType.number,
                                  style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: kInkText),
                                  decoration: _inputDecoration('e.g. 75'),
                                  validator: (v) {
                                    if (v!.trim().isEmpty) return 'Required';
                                    if (int.tryParse(v.trim()) == null) return 'Number only';
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Origin Details
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('WASH BATCH REF', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w700, color: kMutedText)),
                                const SizedBox(height: 4),
                                TextFormField(
                                  controller: _washBatchCtrl,
                                  style: GoogleFonts.publicSans(fontSize: 11, color: kInkText),
                                  decoration: _inputDecoration('WB-084'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('IRON TABLE REF', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w700, color: kMutedText)),
                                const SizedBox(height: 4),
                                TextFormField(
                                  controller: _ironStationCtrl,
                                  style: GoogleFonts.publicSans(fontSize: 11, color: kInkText),
                                  decoration: _inputDecoration('Vacuum Table 01'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Tech-Pack Criteria Checkboxes
                      Text('TECH-PACK PROCESS SPECIFICATION', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w700, color: kMutedText)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: kCanvasColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: kBorderColor),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: _hasPrinting,
                                    activeColor: kPrimaryBrand,
                                    onChanged: (v) => setState(() => _hasPrinting = v!),
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  Text('Has Printing', style: GoogleFonts.publicSans(fontSize: 11.5, fontWeight: FontWeight.w600, color: kInkText)),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: _hasEmbroidery,
                                    activeColor: kPrimaryBrand,
                                    onChanged: (v) => setState(() => _hasEmbroidery = v!),
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  Text('Has Embroidery', style: GoogleFonts.publicSans(fontSize: 11.5, fontWeight: FontWeight.w600, color: kInkText)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Priority Selection
                      Text('FLOOR PRIORITY', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w700, color: kMutedText)),
                      const SizedBox(height: 6),
                      Row(
                        children: _priorities.map((p) {
                          final isSel = _selectedPriority == p;
                          Color badgeColor = kPrimaryBrand;
                          if (p == 'RUSH') badgeColor = const Color(0xFFD97706);
                          if (p == 'CRITICAL') badgeColor = const Color(0xFFE11D48);

                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: InkWell(
                                onTap: () => setState(() => _selectedPriority = p),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSel ? badgeColor : kCardBg,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: isSel ? badgeColor : kBorderColor),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    p,
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: isSel ? Colors.white : kInkText,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: kCanvasColor,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
                border: Border(top: BorderSide(color: kBorderColor)),
              ),
              child: Row(
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: kBorderColor),
                      backgroundColor: kCardBg,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: Text('Cancel', style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w600, color: kMutedText)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submit,
                      icon: _isSubmitting
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('📦', style: TextStyle(fontSize: 14)),
                      label: Text(
                        _isSubmitting ? 'Inwarding...' : 'Inward Lot for QC Check',
                        style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryBrand,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
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

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.publicSans(fontSize: 11.5, color: kMutedText),
      filled: true,
      fillColor: kCardBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kBorderColor)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kBorderColor)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kPrimaryBrand)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE11D48))),
    );
  }
}
