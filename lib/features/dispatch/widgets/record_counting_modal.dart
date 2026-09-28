import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/dispatch_provider.dart';

class RecordCountingModal extends ConsumerStatefulWidget {
  const RecordCountingModal({super.key});

  @override
  ConsumerState<RecordCountingModal> createState() => _RecordCountingModalState();
}

class _RecordCountingModalState extends ConsumerState<RecordCountingModal> {
  static const Color kCanvasColor = Color(0xFFFAF7F0);
  static const Color kCardBg = Color(0xFFFFFFFF);
  static const Color kPrimaryBrand = Color(0xFF3A3564);
  static const Color kBorderColor = Color(0xFFE7E1D6);
  static const Color kMutedText = Color(0xFF7A7488);
  static const Color kInkText = Color(0xFF232028);

  final _formKey = GlobalKey<FormState>();
  final _colorCtrl = TextEditingController(text: 'Navy Blue');
  final _countedQtyCtrl = TextEditingController(text: '100');
  final _expectedQtyCtrl = TextEditingController(text: '100');
  final _remarksCtrl = TextEditingController();

  String _selectedArticleId = '';
  String _selectedSize = 'L';
  bool _isSubmitting = false;

  final List<String> _sizes = ['XS', 'S', 'M', 'L', 'XL', '2XL', '3XL', 'Free Size'];

  @override
  void initState() {
    super.initState();
    final articles = ref.read(dispatchProvider).articles;
    if (articles.isNotEmpty) {
      _selectedArticleId = articles.first.id;
    }
  }

  @override
  void dispose() {
    _colorCtrl.dispose();
    _countedQtyCtrl.dispose();
    _expectedQtyCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      final counted = int.tryParse(_countedQtyCtrl.text.trim()) ?? 0;
      final expected = int.tryParse(_expectedQtyCtrl.text.trim()) ?? 0;

      await ref.read(dispatchProvider.notifier).recordCounting(
            articleId: _selectedArticleId,
            color: _colorCtrl.text.trim(),
            size: _selectedSize,
            countedQty: counted,
            expectedQty: expected,
            remarks: _remarksCtrl.text.trim(),
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            content: Text(
              '✓ Physical Counting Audit ($counted pcs) recorded successfully!',
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
    final articles = ref.watch(dispatchProvider).articles;

    return Dialog(
      backgroundColor: kCardBg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: kBorderColor),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 660),
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
                    child: const Icon(Icons.assignment_turned_in_outlined, color: kPrimaryBrand, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Record Counting Audit',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: kInkText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tally & record pre-loading physical garment piece count',
                          style: GoogleFonts.publicSans(
                            fontSize: 11,
                            color: kMutedText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.pop(context),
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

            // Form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Article Selection
                      Text(
                        'ARTICLE / STYLE *',
                        style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w700, color: kMutedText),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        decoration: BoxDecoration(
                          color: kCardBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: kBorderColor),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: articles.any((a) => a.id == _selectedArticleId)
                                ? _selectedArticleId
                                : (articles.isNotEmpty ? articles.first.id : null),
                            isExpanded: true,
                            hint: Text('Select Article...', style: GoogleFonts.publicSans(fontSize: 12, color: kMutedText)),
                            items: articles.map((a) {
                              return DropdownMenuItem(
                                value: a.id,
                                child: Text(
                                  '${a.artNo} ${a.description != null ? '• ${a.description}' : ''}',
                                  style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.w600, color: kInkText),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (v) {
                              if (v != null) setState(() => _selectedArticleId = v);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Color & Size
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('COLOR', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w700, color: kMutedText)),
                                const SizedBox(height: 4),
                                TextFormField(
                                  controller: _colorCtrl,
                                  style: GoogleFonts.publicSans(fontSize: 12, color: kInkText),
                                  decoration: _inputDecoration('e.g. Navy Blue'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('SIZE', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w700, color: kMutedText)),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: kCardBg,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: kBorderColor),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedSize,
                                      isExpanded: true,
                                      items: _sizes.map((s) {
                                        return DropdownMenuItem(
                                          value: s,
                                          child: Text(s, style: GoogleFonts.jetBrainsMono(fontSize: 12, color: kInkText)),
                                        );
                                      }).toList(),
                                      onChanged: (v) {
                                        if (v != null) setState(() => _selectedSize = v);
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Counted Qty vs Expected Qty
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('COUNTED QTY (PCS) *', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w700, color: kMutedText)),
                                const SizedBox(height: 4),
                                TextFormField(
                                  controller: _countedQtyCtrl,
                                  keyboardType: TextInputType.number,
                                  style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w800, color: kInkText),
                                  decoration: _inputDecoration('100'),
                                  validator: (v) {
                                    if (v!.trim().isEmpty) return 'Required';
                                    if (int.tryParse(v.trim()) == null || int.parse(v.trim()) <= 0) return 'Min 1';
                                    return null;
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
                                Text('EXPECTED / PO QTY', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w700, color: kMutedText)),
                                const SizedBox(height: 4),
                                TextFormField(
                                  controller: _expectedQtyCtrl,
                                  keyboardType: TextInputType.number,
                                  style: GoogleFonts.jetBrainsMono(fontSize: 13, color: kInkText),
                                  decoration: _inputDecoration('100'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Remarks / Notes
                      Text('REMARKS / OBSERVATIONS', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w700, color: kMutedText)),
                      const SizedBox(height: 4),
                      TextFormField(
                        controller: _remarksCtrl,
                        maxLines: 2,
                        style: GoogleFonts.publicSans(fontSize: 12, color: kInkText),
                        decoration: _inputDecoration('e.g. Master Carton #1 to #5 audited, all polybags barcoded.'),
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
                          : const Icon(Icons.check, size: 16),
                      label: Text(
                        _isSubmitting ? 'Recording...' : 'Record Counting Audit',
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
