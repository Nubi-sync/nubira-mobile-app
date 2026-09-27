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
  final _styleNameCtrl = TextEditingController(text: 'French Terry Relaxed Hoodie');
  final _piecesCtrl = TextEditingController(text: '50');
  final _colorCtrl = TextEditingController(text: 'Vintage Mineral Wash');
  final _washBatchCtrl = TextEditingController(text: 'WB-082 (Silicon Softener Wash)');
  final _ironStationCtrl = TextEditingController(text: 'Steam Press Board 03');

  String _lotCode = 'QC-7720-01';
  String _poNumber = 'PO-7720';
  final String _buyer = 'Urban Outfitters';
  String _size = 'L';
  bool _hasPrinting = true;
  bool _hasEmbroidery = true;
  String? _assignedWorkerId;
  bool _isSubmitting = false;

  final List<String> _sizes = ['XS', 'S', 'M', 'L', 'XL', '2XL', '3XL', 'Free Size'];

  @override
  void initState() {
    super.initState();
    final rng1 = Random().nextInt(9000) + 1000;
    final rng2 = Random().nextInt(1000) + 7000;
    _lotCode = 'QC-$rng1-01';
    _poNumber = 'PO-$rng2';
  }

  @override
  void dispose() {
    _styleNameCtrl.dispose();
    _piecesCtrl.dispose();
    _colorCtrl.dispose();
    _washBatchCtrl.dispose();
    _ironStationCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      final pieces = int.tryParse(_piecesCtrl.text.trim()) ?? 50;
      final state = ref.read(readyGoodsProvider);
      final assignedWorker = state.workers.where((w) => w.id == _assignedWorkerId).firstOrNull;

      await ref.read(readyGoodsProvider.notifier).inwardLot(
            lotCode: _lotCode,
            orderNumber: _poNumber,
            buyer: _buyer,
            styleName: _styleNameCtrl.text.trim(),
            color: _colorCtrl.text.trim().isNotEmpty ? _colorCtrl.text.trim() : 'Standard',
            size: _size,
            piecesCount: pieces,
            washBatchRef: _washBatchCtrl.text.trim().isNotEmpty ? _washBatchCtrl.text.trim() : 'Washing Batch #01',
            ironStationRef: _ironStationCtrl.text.trim().isNotEmpty ? _ironStationCtrl.text.trim() : 'Steam Iron Line 01',
            hasPrinting: _hasPrinting,
            hasEmbroidery: _hasEmbroidery,
            printEmbSummary: _hasPrinting && _hasEmbroidery
                ? 'Printing & Embroidery Required'
                : _hasPrinting
                    ? 'Screen Printing Required'
                    : _hasEmbroidery
                        ? 'Embroidery Required'
                        : 'Plain Finish (No Print/Embroidery)',
            priority: 'NORMAL',
            assignedWorkerId: assignedWorker?.id,
            assignedWorkerName: assignedWorker?.workerName,
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            content: Text(
              'Lot #$_lotCode successfully inwarded to Quality Clinic!',
              style: GoogleFonts.publicSans(fontWeight: FontWeight.w700, color: Colors.white),
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
    final state = ref.watch(readyGoodsProvider);
    final availableCheckers = state.workers.where((w) => w.role == 'CHECKER' || w.role == 'BOTH').toList();

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
            // Header (Exact Web Mirror)
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
                          'Inward Garments for Quality Clinic',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: kInkText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Record incoming lot arriving from washing & steam iron to inspect and assign',
                          style: GoogleFonts.publicSans(
                            fontSize: 11,
                            color: kMutedText,
                            fontWeight: FontWeight.w500,
                          ),
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

            // Form Body (Exact Web Order & Fields)
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ARTICLE / STYLE NAME *
                      Text(
                        'ARTICLE / STYLE NAME *',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: kMutedText,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _styleNameCtrl,
                        style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.w600, color: kInkText),
                        decoration: _inputDecoration('e.g. French Terry Relaxed Hoodie'),
                        validator: (v) => v!.trim().isEmpty ? 'Please enter style name' : null,
                      ),
                      const SizedBox(height: 12),

                      // Row: PIECES COUNT * | SIZE | COLOR
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Pieces Count
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'PIECES COUNT *',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: kMutedText,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _piecesCtrl,
                                  keyboardType: TextInputType.number,
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: kInkText,
                                  ),
                                  decoration: _inputDecoration('50'),
                                  validator: (v) {
                                    if (v!.trim().isEmpty) return 'Required';
                                    if (int.tryParse(v.trim()) == null || int.parse(v.trim()) <= 0) return 'Min 1';
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Size
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'SIZE',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: kMutedText,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: kCardBg,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: kBorderColor),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _size,
                                      isExpanded: true,
                                      icon: const Icon(Icons.keyboard_arrow_down, size: 16, color: kPrimaryBrand),
                                      items: _sizes.map((s) {
                                        return DropdownMenuItem(
                                          value: s,
                                          child: Text(
                                            s,
                                            style: GoogleFonts.jetBrainsMono(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: kInkText,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (v) {
                                        if (v != null) setState(() => _size = v);
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Color
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'COLOR',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: kMutedText,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _colorCtrl,
                                  style: GoogleFonts.publicSans(fontSize: 12, color: kInkText),
                                  decoration: _inputDecoration('e.g. Onyx Black'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Box 1: Wash Batch Origin & Steam Iron Station
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: kBorderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'WASH BATCH ORIGIN',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: kMutedText,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            TextFormField(
                              controller: _washBatchCtrl,
                              style: GoogleFonts.publicSans(fontSize: 11.5, color: kInkText),
                              decoration: _inputDecoration('e.g. WB-082 (Silicon Softener Wash)'),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'STEAM IRON STATION',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: kMutedText,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            TextFormField(
                              controller: _ironStationCtrl,
                              style: GoogleFonts.publicSans(fontSize: 11.5, color: kInkText),
                              decoration: _inputDecoration('e.g. Steam Press Board 03'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Box 2: Tech Pack Criteria Configuration (Exact Web Mirror)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: kCardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: kBorderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TECH PACK CRITERIA CONFIGURATION',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: kInkText,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Only enabled criteria will be required on the checker\'s verification checklist. (Cutting, Washing, and Ironing are always verified).',
                              style: GoogleFonts.publicSans(
                                fontSize: 11,
                                color: kMutedText,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Checkbox 1: Undergoes Printing
                            InkWell(
                              onTap: () => setState(() => _hasPrinting = !_hasPrinting),
                              borderRadius: BorderRadius.circular(10),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: _hasPrinting ? kPrimaryBrand.withValues(alpha: 0.05) : kCardBg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _hasPrinting ? kPrimaryBrand : kBorderColor,
                                    width: _hasPrinting ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 18,
                                      height: 18,
                                      decoration: BoxDecoration(
                                        color: _hasPrinting ? const Color(0xFF2563EB) : Colors.transparent,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: _hasPrinting ? const Color(0xFF2563EB) : kBorderColor,
                                        ),
                                      ),
                                      child: _hasPrinting
                                          ? const Icon(Icons.check, size: 13, color: Colors.white)
                                          : null,
                                    ),
                                    const SizedBox(width: 10),
                                    const Icon(Icons.print_outlined, size: 16, color: Color(0xFF2563EB)),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Undergoes Printing (Screen/DTF)',
                                      style: GoogleFonts.publicSans(
                                        fontSize: 12,
                                        fontWeight: _hasPrinting ? FontWeight.w700 : FontWeight.w500,
                                        color: kInkText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Checkbox 2: Undergoes Embroidery
                            InkWell(
                              onTap: () => setState(() => _hasEmbroidery = !_hasEmbroidery),
                              borderRadius: BorderRadius.circular(10),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: _hasEmbroidery ? kPrimaryBrand.withValues(alpha: 0.05) : kCardBg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _hasEmbroidery ? kPrimaryBrand : kBorderColor,
                                    width: _hasEmbroidery ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 18,
                                      height: 18,
                                      decoration: BoxDecoration(
                                        color: _hasEmbroidery ? const Color(0xFF2563EB) : Colors.transparent,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: _hasEmbroidery ? const Color(0xFF2563EB) : kBorderColor,
                                        ),
                                      ),
                                      child: _hasEmbroidery
                                          ? const Icon(Icons.check, size: 13, color: Colors.white)
                                          : null,
                                    ),
                                    const SizedBox(width: 10),
                                    const Icon(Icons.auto_awesome, size: 16, color: Color(0xFFD97706)),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Undergoes Embroidery',
                                      style: GoogleFonts.publicSans(
                                        fontSize: 12,
                                        fontWeight: _hasEmbroidery ? FontWeight.w700 : FontWeight.w500,
                                        color: kInkText,
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

                      // Assign Quality Checker (Optional)
                      Text(
                        'ASSIGN QUALITY CHECKER (OPTIONAL)',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: kMutedText,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        decoration: BoxDecoration(
                          color: kCardBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: kBorderColor),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: availableCheckers.any((w) => w.id == _assignedWorkerId) ? _assignedWorkerId : '',
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down, size: 16, color: kPrimaryBrand),
                            items: [
                              DropdownMenuItem<String>(
                                value: '',
                                child: Text(
                                  'Unassigned (Queue in Incoming Pool)',
                                  style: GoogleFonts.publicSans(fontSize: 12, color: kInkText),
                                ),
                              ),
                              ...availableCheckers.map((w) {
                                final roleLabel = w.role == 'BOTH' ? 'Checker & Packer' : 'Checker';
                                return DropdownMenuItem<String>(
                                  value: w.id,
                                  child: Text(
                                    '${w.workerName} ($roleLabel) • ${w.shift}',
                                    style: GoogleFonts.publicSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: kInkText,
                                    ),
                                  ),
                                );
                              }),
                            ],
                            onChanged: (v) {
                              setState(() => _assignedWorkerId = v);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tip: You can add workers with the "+ Add Worker" button and assign them to this lot anytime!',
                        style: GoogleFonts.publicSans(
                          fontSize: 11,
                          color: const Color(0xFFC2410C), // Amber/Orange tip matching web
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer (Cancel & Inward Lot for Inspection)
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
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w600, color: kInkText),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submit,
                      icon: _isSubmitting
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.all_inbox_rounded, size: 16),
                      label: Text(
                        _isSubmitting ? 'Inwarding...' : 'Inward Lot for Inspection',
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
