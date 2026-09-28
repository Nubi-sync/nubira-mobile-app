import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/store_models.dart';
import '../providers/store_provider.dart';

class BookFabricModal extends ConsumerStatefulWidget {
  final CentralFabricInventoryModel fabric;

  const BookFabricModal({
    super.key,
    required this.fabric,
  });

  @override
  ConsumerState<BookFabricModal> createState() => _BookFabricModalState();
}

class _BookFabricModalState extends ConsumerState<BookFabricModal> {
  static const Color kCanvasColor = Color(0xFFFAF7F0);
  static const Color kCardBg = Color(0xFFFFFFFF);
  static const Color kPrimaryBrand = Color(0xFF3A3564);
  static const Color kBorderColor = Color(0xFFE7E1D6);
  static const Color kMutedText = Color(0xFF7A7488);
  static const Color kInkText = Color(0xFF232028);
  static const Color kInputBg = Color(0xFFF8FAFC);
  static const Color kInputBorder = Color(0xFFE2E8F0);

  final _formKey = GlobalKey<FormState>();
  final _articleNoCtrl = TextEditingController();
  final _metersCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.fabric.bookedForArticle != null && widget.fabric.bookedForArticle!.isNotEmpty) {
      _articleNoCtrl.text = widget.fabric.bookedForArticle!;
    }
  }

  @override
  void dispose() {
    _articleNoCtrl.dispose();
    _metersCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final meters = double.tryParse(_metersCtrl.text.trim()) ?? 0.0;
    if (meters > widget.fabric.availableMeters) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot book $meters m. Only ${widget.fabric.availableMeters.toStringAsFixed(0)} m available.'),
          backgroundColor: const Color(0xFFE11D48),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await ref.read(storeProvider.notifier).bookFabricForArticle(
            inventoryId: widget.fabric.id,
            articleNo: _articleNoCtrl.text.trim(),
            meters: meters,
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF047857),
            content: Text(
              '✓ Successfully booked ${meters.toStringAsFixed(0)} m of ${widget.fabric.fabricType} for Art #${_articleNoCtrl.text.trim()}!',
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
        constraints: const BoxConstraints(maxWidth: 480),
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
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: kCardBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: kBorderColor),
                    ),
                    child: const Icon(Icons.bookmark_border_rounded, color: kPrimaryBrand, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Book Fabric for Article',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: kInkText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Reserve raw fabric meters for style production',
                          style: GoogleFonts.publicSans(fontSize: 11, color: kMutedText),
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

            // Form Body
            Padding(
              padding: const EdgeInsets.all(18),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Selected Fabric Info Card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                widget.fabric.fabricType,
                                style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: kInkText),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: kBorderColor),
                                ),
                                child: Text(
                                  widget.fabric.rackLocation,
                                  style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.bold, color: kPrimaryBrand),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Color: ${widget.fabric.color} • In Stock: ${widget.fabric.totalMeters.toStringAsFixed(0)} m (${widget.fabric.totalRolls} rolls)',
                            style: GoogleFonts.publicSans(fontSize: 11.5, color: kMutedText),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Available: ${widget.fabric.availableMeters.toStringAsFixed(0)} m',
                                  style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF047857))),
                              Text('Booked: ${widget.fabric.bookedMeters.toStringAsFixed(0)} m',
                                  style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB))),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Article No
                    Text('TARGET ARTICLE MASTER STYLE *',
                        style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF334155), letterSpacing: 0.5)),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: _articleNoCtrl,
                      style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w700, color: kInkText),
                      decoration: InputDecoration(
                        hintText: 'e.g. 5225',
                        hintStyle: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: kInputBg,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kInputBorder)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kInputBorder)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kPrimaryBrand, width: 1.5)),
                      ),
                      validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),

                    // Meters to Book
                    Text('METERS TO BOOK / ALLOCATE *',
                        style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF334155), letterSpacing: 0.5)),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: _metersCtrl,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w800, color: kInkText),
                      decoration: InputDecoration(
                        hintText: 'e.g. 350',
                        hintStyle: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: kInputBg,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kInputBorder)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kInputBorder)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kPrimaryBrand, width: 1.5)),
                      ),
                      validator: (v) => (double.tryParse(v?.trim() ?? '') ?? 0) <= 0 ? 'Enter meters > 0' : null,
                    ),
                  ],
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
                          : Text('Confirm Booking', style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.w700)),
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
}
