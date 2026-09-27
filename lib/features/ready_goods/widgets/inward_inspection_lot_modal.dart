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

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAF7F0),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                        ),
                        child: const Icon(Icons.all_inbox_rounded, color: Color(0xFF3A3564), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Inward Quality Checking Lot',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Receive washed & pressed garments for final QC clearance',
                            style: GoogleFonts.publicSans(fontSize: 11, color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Quick Presets Selector
              Text('QUICK STYLE PRESETS', style: GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
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
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSel ? const Color(0xFF3A3564) : const Color(0xFFFAF7F0),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isSel ? const Color(0xFF3A3564) : const Color(0xFFE2E8F0)),
                          ),
                          child: Text(
                            p['label'],
                            style: GoogleFonts.publicSans(
                              fontSize: 11,
                              fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                              color: isSel ? Colors.white : const Color(0xFF334155),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 14),

              // Buyer Selector
              Text('Buyer Contract *', style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: buyers.any((b) => b.buyerName == _selectedBuyer) ? _selectedBuyer : (buyers.isNotEmpty ? buyers.first.buyerName : null),
                items: buyers.map((b) => DropdownMenuItem(value: b.buyerName, child: Text(b.buyerName, style: GoogleFonts.publicSans(fontSize: 13)))).toList(),
                onChanged: (v) => setState(() => _selectedBuyer = v!),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                ),
              ),
              const SizedBox(height: 12),

              // Lot # & PO #
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('QC Lot Number *', style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _lotCodeCtrl,
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PO / Order # *', style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _poNumberCtrl,
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Style Name
              Text('Article Style Name *', style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
              const SizedBox(height: 6),
              TextFormField(
                controller: _styleNameCtrl,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                ),
              ),
              const SizedBox(height: 12),

              // Color, Size, Pieces
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Color', style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _colorCtrl,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
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
                        Text('Size', style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _selectedSize,
                          items: _sizes.map((s) => DropdownMenuItem(value: s, child: Text(s, style: GoogleFonts.publicSans(fontSize: 12)))).toList(),
                          onChanged: (v) => setState(() => _selectedSize = v!),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
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
                        Text('Pieces *', style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _piecesCtrl,
                          keyboardType: TextInputType.number,
                          validator: (v) => (v == null || int.tryParse(v) == null) ? 'Required' : null,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Wash Batch & Iron Origin
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Wash Batch Origin', style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _washBatchCtrl,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Pressing Station Origin', style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _ironStationCtrl,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Tech Pack Flags (Printing & Embroidery)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF7F0),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TECH-PACK ROUTING CRITERIA', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('Requires Print Check', style: GoogleFonts.publicSans(fontSize: 11.5, fontWeight: FontWeight.bold)),
                            value: _hasPrinting,
                            onChanged: (v) => setState(() => _hasPrinting = v ?? false),
                            controlAffinity: ListTileControlAffinity.leading,
                            dense: true,
                          ),
                        ),
                        Expanded(
                          child: CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('Requires Embroidery Check', style: GoogleFonts.publicSans(fontSize: 11.5, fontWeight: FontWeight.bold)),
                            value: _hasEmbroidery,
                            onChanged: (v) => setState(() => _hasEmbroidery = v ?? false),
                            controlAffinity: ListTileControlAffinity.leading,
                            dense: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Priority
              Text('Floor Priority', style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _selectedPriority,
                items: _priorities.map((p) => DropdownMenuItem(value: p, child: Text(p, style: GoogleFonts.publicSans(fontSize: 13)))).toList(),
                onChanged: (v) => setState(() => _selectedPriority = v!),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                ),
              ),
              const SizedBox(height: 20),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3A3564),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      : Text('Confirm Lot Inward', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
