import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/store_provider.dart';

class AddFabricModal extends ConsumerStatefulWidget {
  const AddFabricModal({super.key});

  @override
  ConsumerState<AddFabricModal> createState() => _AddFabricModalState();
}

class _AddFabricModalState extends ConsumerState<AddFabricModal> {
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
  final _fabricTypeCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  final _supplierCtrl = TextEditingController();
  final _metersCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _rollsCtrl = TextEditingController();
  final _rackCtrl = TextEditingController(text: 'BAY_1_RACK_01');
  final _notesCtrl = TextEditingController();

  bool _isSubmitting = false;

  @override
  void dispose() {
    _fabricTypeCtrl.dispose();
    _colorCtrl.dispose();
    _supplierCtrl.dispose();
    _metersCtrl.dispose();
    _weightCtrl.dispose();
    _rollsCtrl.dispose();
    _rackCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      await ref.read(storeProvider.notifier).addFabricInventory(
            fabricType: _fabricTypeCtrl.text.trim(),
            color: _colorCtrl.text.trim(),
            supplierName: _supplierCtrl.text.trim().isEmpty ? null : _supplierCtrl.text.trim(),
            totalMeters: double.tryParse(_metersCtrl.text.trim()) ?? 0.0,
            totalWeightKg: double.tryParse(_weightCtrl.text.trim()) ?? 0.0,
            totalRolls: int.tryParse(_rollsCtrl.text.trim()) ?? 0,
            rackLocation: _rackCtrl.text.trim().isEmpty ? 'BAY_1_RACK_01' : _rackCtrl.text.trim(),
            notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF047857),
            content: Text(
              '✓ ${_fabricTypeCtrl.text.trim()} (${_colorCtrl.text.trim()}) logged into Central Fabric Godown!',
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
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Modal Header
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
                    child: const Icon(Icons.layers_outlined, color: kPrimaryBrand, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Inward Fabric to Godown',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: kInkText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Register new fabric rolls into Central Godown Bay 1-2',
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
                      // Fabric Type & Color
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildFormField(
                              label: 'FABRIC TYPE / WEAVE *',
                              child: TextFormField(
                                controller: _fabricTypeCtrl,
                                style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.w700, color: kInkText),
                                decoration: _inputDecoration('e.g. 100% Cotton 30s'),
                                validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildFormField(
                              label: 'COLOR / SHADE *',
                              child: TextFormField(
                                controller: _colorCtrl,
                                style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.w600, color: kInkText),
                                decoration: _inputDecoration('e.g. Navy Blue / Shade A'),
                                validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Supplier & Rack Location
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildFormField(
                              label: 'MILL / SUPPLIER NAME',
                              child: TextFormField(
                                controller: _supplierCtrl,
                                style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.w500, color: kInkText),
                                decoration: _inputDecoration('e.g. Vardhman Textiles'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildFormField(
                              label: 'GODOWN RACK LOCATION',
                              child: TextFormField(
                                controller: _rackCtrl,
                                style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.w700, color: kInkText),
                                decoration: _inputDecoration('e.g. BAY_1_RACK_04'),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Net Meters, Weight & Total Rolls (3-Column Row)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildFormField(
                              label: 'NET METERS *',
                              child: TextFormField(
                                controller: _metersCtrl,
                                keyboardType: TextInputType.number,
                                style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w800, color: kInkText),
                                decoration: _inputDecoration('e.g. 1200'),
                                validator: (v) => (double.tryParse(v?.trim() ?? '') ?? 0) <= 0 ? 'Enter > 0' : null,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildFormField(
                              label: 'GROSS WEIGHT (KG)',
                              child: TextFormField(
                                controller: _weightCtrl,
                                keyboardType: TextInputType.number,
                                style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w700, color: kInkText),
                                decoration: _inputDecoration('e.g. 350'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildFormField(
                              label: 'TOTAL ROLLS',
                              child: TextFormField(
                                controller: _rollsCtrl,
                                keyboardType: TextInputType.number,
                                style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w700, color: kInkText),
                                decoration: _inputDecoration('e.g. 12'),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Notes
                      _buildFormField(
                        label: 'INSPECTION & STORAGE NOTES',
                        child: TextFormField(
                          controller: _notesCtrl,
                          maxLines: 2,
                          style: GoogleFonts.publicSans(fontSize: 12.5, color: kInkText),
                          decoration: _inputDecoration('e.g. 4-point inspected, shrink test passed'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Modal Footer
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
                          : Text('Register Fabric to Godown', style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.w700)),
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
