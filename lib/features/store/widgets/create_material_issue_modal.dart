import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/store_provider.dart';

class CreateMaterialIssueModal extends ConsumerStatefulWidget {
  final String? initialFabricType;
  final String? initialColor;
  final String? initialArticleNo;
  final double? initialQuantity;
  final int? initialRolls;

  const CreateMaterialIssueModal({
    super.key,
    this.initialFabricType,
    this.initialColor,
    this.initialArticleNo,
    this.initialQuantity,
    this.initialRolls,
  });

  @override
  ConsumerState<CreateMaterialIssueModal> createState() => _CreateMaterialIssueModalState();
}

class _CreateMaterialIssueModalState extends ConsumerState<CreateMaterialIssueModal> {
  // Industrial Luxury Design Tokens
  static const Color kCanvasColor = Color(0xFFFAF7F0);
  static const Color kCardBg = Color(0xFFFFFFFF);
  static const Color kPrimaryBrand = Color(0xFF3A3564);
  static const Color kBorderColor = Color(0xFFE7E1D6);
  static const Color kMutedText = Color(0xFF7A7488);
  static const Color kInkText = Color(0xFF232028);
  static const Color kInputBg = Color(0xFFF8FAFC);
  static const Color kInputBorder = Color(0xFFE2E8F0);

  final _formKey = GlobalKey<FormState>();
  String _fromDivision = 'MERCHANDISE';
  String _toDivision = 'CUTTING';
  final _articleNoCtrl = TextEditingController();
  final _buyerNameCtrl = TextEditingController();
  final _fabricTypeCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController();
  String _unit = 'meters';
  final _rollsCountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  bool _isSubmitting = false;

  final List<String> _divisions = [
    'MERCHANDISE',
    'STORE',
    'CUTTING',
    'PRINTING',
    'EMBROIDERY',
    'SEWING',
    'WASHING',
    'IRONING',
    'PACKING',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialFabricType != null) _fabricTypeCtrl.text = widget.initialFabricType!;
    if (widget.initialColor != null) _colorCtrl.text = widget.initialColor!;
    if (widget.initialArticleNo != null) _articleNoCtrl.text = widget.initialArticleNo!;
    if (widget.initialQuantity != null && widget.initialQuantity! > 0) {
      _quantityCtrl.text = widget.initialQuantity!.toStringAsFixed(0);
    }
    if (widget.initialRolls != null && widget.initialRolls! > 0) {
      _rollsCountCtrl.text = widget.initialRolls!.toString();
    }
  }

  @override
  void dispose() {
    _articleNoCtrl.dispose();
    _buyerNameCtrl.dispose();
    _fabricTypeCtrl.dispose();
    _colorCtrl.dispose();
    _quantityCtrl.dispose();
    _rollsCountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      await ref.read(storeProvider.notifier).createMaterialIssue(
            fromDivision: _fromDivision,
            toDivision: _toDivision,
            articleNo: _articleNoCtrl.text.trim().isEmpty ? null : _articleNoCtrl.text.trim(),
            buyerName: _buyerNameCtrl.text.trim().isEmpty ? null : _buyerNameCtrl.text.trim(),
            fabricType: _fabricTypeCtrl.text.trim().isEmpty ? null : _fabricTypeCtrl.text.trim(),
            color: _colorCtrl.text.trim().isEmpty ? null : _colorCtrl.text.trim(),
            quantity: double.tryParse(_quantityCtrl.text.trim()) ?? 0.0,
            unit: _unit,
            rollsCount: int.tryParse(_rollsCountCtrl.text.trim()) ?? 0,
            notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF047857),
            content: Text(
              '✓ Material Issue Challan dispatched to $_toDivision Floor!',
              style: GoogleFonts.publicSans(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: const Color(0xFFE11D48), content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: kCardBg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: kBorderColor),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 760),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: const BoxDecoration(
                color: kCanvasColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(17)),
                border: Border(bottom: BorderSide(color: kBorderColor)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: kCardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kBorderColor),
                    ),
                    child: const Icon(Icons.outbound_outlined, color: kPrimaryBrand, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Issue Material Challan',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: kInkText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Dispatch fabrics, threads & trims to production lines',
                          style: GoogleFonts.publicSans(fontSize: 11.5, color: kMutedText),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.close, size: 18, color: kMutedText),
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Form Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // From Division -> To Division
                      Row(
                        children: [
                          Expanded(
                            child: _buildFormField(
                              label: 'SOURCE / ISSUED FROM *',
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: kInputBg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: kInputBorder),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _fromDivision,
                                    isExpanded: true,
                                    items: _divisions.map((d) {
                                      return DropdownMenuItem(
                                        value: d,
                                        child: Text(d, style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: kInkText)),
                                      );
                                    }).toList(),
                                    onChanged: (v) => setState(() => _fromDivision = v ?? 'MERCHANDISE'),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildFormField(
                              label: 'DESTINATION FLOOR *',
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: kInputBg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: kInputBorder),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _toDivision,
                                    isExpanded: true,
                                    items: _divisions.map((d) {
                                      return DropdownMenuItem(
                                        value: d,
                                        child: Text(d, style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: kPrimaryBrand)),
                                      );
                                    }).toList(),
                                    onChanged: (v) => setState(() => _toDivision = v ?? 'CUTTING'),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Target Article & Buyer Name
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildFormField(
                              label: 'TARGET ARTICLE NO',
                              child: TextFormField(
                                controller: _articleNoCtrl,
                                style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.w700, color: kInkText),
                                decoration: _inputDecoration('e.g. 5225'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildFormField(
                              label: 'BUYER / BRAND NAME',
                              child: TextFormField(
                                controller: _buyerNameCtrl,
                                style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.w600, color: kInkText),
                                decoration: _inputDecoration('e.g. Zara / H&M'),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Fabric Type & Color
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildFormField(
                              label: 'FABRIC TYPE / MATERIAL',
                              child: TextFormField(
                                controller: _fabricTypeCtrl,
                                style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.w600, color: kInkText),
                                decoration: _inputDecoration('e.g. Cotton French Terry'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildFormField(
                              label: 'COLOR / SHADE',
                              child: TextFormField(
                                controller: _colorCtrl,
                                style: GoogleFonts.publicSans(fontSize: 12.5, color: kInkText),
                                decoration: _inputDecoration('e.g. Black / Navy'),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Quantity, Unit & Rolls Count (3-Column Row)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: _buildFormField(
                              label: 'QUANTITY TO ISSUE *',
                              child: TextFormField(
                                controller: _quantityCtrl,
                                keyboardType: TextInputType.number,
                                style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w800, color: kInkText),
                                decoration: _inputDecoration('e.g. 500'),
                                validator: (v) => (double.tryParse(v?.trim() ?? '') ?? 0) <= 0 ? 'Enter > 0' : null,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: _buildFormField(
                              label: 'UNIT',
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  color: kInputBg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: kInputBorder),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _unit,
                                    isExpanded: true,
                                    items: const [
                                      DropdownMenuItem(value: 'meters', child: Text('meters')),
                                      DropdownMenuItem(value: 'kg', child: Text('kg')),
                                      DropdownMenuItem(value: 'rolls', child: Text('rolls')),
                                      DropdownMenuItem(value: 'pcs', child: Text('pcs')),
                                    ],
                                    onChanged: (v) => setState(() => _unit = v ?? 'meters'),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: _buildFormField(
                              label: 'ROLLS COUNT',
                              child: TextFormField(
                                controller: _rollsCountCtrl,
                                keyboardType: TextInputType.number,
                                style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w700, color: kInkText),
                                decoration: _inputDecoration('e.g. 5'),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Notes
                      _buildFormField(
                        label: 'ISSUANCE INSTRUCTIONS & NOTES',
                        child: TextFormField(
                          controller: _notesCtrl,
                          maxLines: 2,
                          style: GoogleFonts.publicSans(fontSize: 12.5, color: kInkText),
                          decoration: _inputDecoration('e.g. For Lay #1 cutting batch'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(17)),
                border: Border(top: BorderSide(color: kBorderColor)),
              ),
              child: Row(
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: kInputBorder),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    ),
                    child: Text('Cancel', style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: const Color(0xFF475569))),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryBrand,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text('Dispatch Issue Challan', style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.w700)),
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

  Widget _buildFormField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF334155),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF94A3B8)),
      filled: true,
      fillColor: kInputBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kInputBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kInputBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kPrimaryBrand, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE11D48))),
    );
  }
}
