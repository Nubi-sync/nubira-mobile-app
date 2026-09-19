import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/merchandising_models.dart';
import '../providers/merchandising_provider.dart';

class CreateOrderModal extends ConsumerStatefulWidget {
  const CreateOrderModal({super.key});

  @override
  ConsumerState<CreateOrderModal> createState() => _CreateOrderModalState();
}

class _CreateOrderModalState extends ConsumerState<CreateOrderModal> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _poController;
  late TextEditingController _brandController;
  late TextEditingController _styleRefController;
  late TextEditingController _quantityController;
  late TextEditingController _priceController;
  late TextEditingController _dateController;

  String _currency = 'INR';
  String? _selectedTechPackId;
  DateTime _exFactoryDate = DateTime.now().add(const Duration(days: 25));

  final List<String> _sizes = ['XS', 'S', 'M', 'L', 'XL'];
  final Map<String, int> _sizeQuantities = {
    'XS': 50,
    'S': 200,
    'M': 400,
    'L': 250,
    'XL': 100,
  };

  @override
  void initState() {
    super.initState();
    final rand = 1000 + Random().nextInt(9000);
    final yr = DateTime.now().year;
    _poController = TextEditingController(text: 'PO-$yr-$rand');
    _brandController = TextEditingController();
    _styleRefController = TextEditingController();
    _quantityController = TextEditingController(text: '1000');
    _priceController = TextEditingController(text: '1450.00');
    _dateController = TextEditingController(
      text: _exFactoryDate.toIso8601String().split('T')[0],
    );
  }

  @override
  void dispose() {
    _poController.dispose;
    _brandController.dispose();
    _styleRefController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  void _recalculateSizes(int total) {
    if (total <= 0) return;
    final ratios = {'XS': 0.05, 'S': 0.20, 'M': 0.40, 'L': 0.25, 'XL': 0.10};
    int allocated = 0;
    for (int i = 0; i < _sizes.length; i++) {
      final s = _sizes[i];
      if (i == _sizes.length - 1) {
        _sizeQuantities[s] = max(0, total - allocated);
      } else {
        final q = (total * (ratios[s] ?? 0.2)).round();
        _sizeQuantities[s] = q;
        allocated += q;
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final totalQty = int.tryParse(_quantityController.text) ?? 1000;
    final price = double.tryParse(_priceController.text) ?? 1450.0;

    final colorMatrix = [
      ColorSizeMatrixItem(
        color: 'Standard Colorway',
        sizes: Map<String, int>.from(_sizeQuantities),
        total: totalQty,
      ),
    ];

    final success = await ref.read(merchandisingProvider.notifier).createBuyerOrder(
          poNumber: _poController.text.trim(),
          brandName: _brandController.text.trim().isNotEmpty ? _brandController.text.trim() : 'Direct Buyer',
          styleRef: _styleRefController.text.trim().isNotEmpty ? _styleRefController.text.trim() : 'STYLE-01',
          totalQuantity: totalQty,
          unitFobPrice: price,
          currency: _currency,
          exFactoryDate: _dateController.text.trim(),
          colorMatrix: colorMatrix,
          techPackId: _selectedTechPackId,
        );

    if (!mounted) return;

    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'PO ${_poController.text.trim()} booked successfully!',
            style: GoogleFonts.publicSans(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFF1B7A43),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to create PO. Please check inputs and try again.',
            style: GoogleFonts.publicSans(color: Colors.white),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(merchandisingProvider);
    final buyers = state.buyers;
    final techPacks = state.techPackArticles;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 16,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Modal Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAF7F0),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0x1A000000)),
                        ),
                        child: const Icon(Icons.work_outline, color: Color(0xFF332B6B), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Book New Buyer PO',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1C1C1A),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF6B6A65)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Create a commercial purchase order contract and schedule T&A critical path milestones.',
                style: GoogleFonts.publicSans(
                  fontSize: 12.5,
                  color: const Color(0xFF6B6A65),
                ),
              ),
              const Divider(height: 28, color: Color(0xFFF1F5F9)),

              // PO NUMBER & CURRENCY
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PO NUMBER', style: _labelStyle),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _poController,
                          style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF332B6B)),
                          decoration: _inputDecoration(hint: 'e.g. PO-2026-8921'),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('CURRENCY', style: _labelStyle),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _currency,
                          items: const [
                            DropdownMenuItem(value: 'INR', child: Text('₹ INR')),
                            DropdownMenuItem(value: 'USD', child: Text('\$ USD')),
                            DropdownMenuItem(value: 'EUR', child: Text('€ EUR')),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _currency = v);
                          },
                          decoration: _inputDecoration(hint: ''),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // BUYER / BRAND NAME
              Text('BUYER / BRAND NAME', style: _labelStyle),
              const SizedBox(height: 6),
              if (buyers.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: buyers.take(6).map((b) {
                        final isSelected = _brandController.text.toLowerCase() == b.buyerName.toLowerCase();
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(b.buyerName, style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.bold)),
                            selected: isSelected,
                            selectedColor: const Color(0xFF332B6B),
                            labelStyle: TextStyle(color: isSelected ? Colors.white : const Color(0xFF1C1C1A)),
                            backgroundColor: const Color(0xFFFAFAF8),
                            side: BorderSide(color: isSelected ? const Color(0xFF332B6B) : const Color(0x1A000000)),
                            onSelected: (val) {
                              if (val) {
                                setState(() {
                                  _brandController.text = b.buyerName;
                                  if (b.linkedArticleNumber != null && b.linkedArticleNumber!.isNotEmpty) {
                                    _styleRefController.text = b.linkedArticleNumber!;
                                  }
                                  if (b.pricePerPiece > 0) {
                                    _priceController.text = b.pricePerPiece.toStringAsFixed(2);
                                  }
                                });
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              TextFormField(
                controller: _brandController,
                style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.w600),
                decoration: _inputDecoration(hint: 'e.g. Zara Home, H&M, Direct Export Buyer'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter buyer/brand name' : null,
              ),
              const SizedBox(height: 16),

              // ARTICLE / STYLE REFERENCE
              Text('ARTICLE / STYLE NUMBER', style: _labelStyle),
              const SizedBox(height: 6),
              if (techPacks.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: techPacks.take(6).map((tp) {
                        final isSelected = _styleRefController.text == tp.styleNumber;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(tp.styleNumber, style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold)),
                            selected: isSelected,
                            selectedColor: const Color(0xFF332B6B),
                            labelStyle: TextStyle(color: isSelected ? Colors.white : const Color(0xFF1C1C1A)),
                            backgroundColor: const Color(0xFFFAFAF8),
                            side: BorderSide(color: isSelected ? const Color(0xFF332B6B) : const Color(0x1A000000)),
                            onSelected: (val) {
                              if (val) {
                                setState(() {
                                  _selectedTechPackId = tp.id;
                                  _styleRefController.text = tp.styleNumber;
                                  if (tp.brandName != null && tp.brandName!.isNotEmpty && _brandController.text.isEmpty) {
                                    _brandController.text = tp.brandName!;
                                  }
                                });
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              TextFormField(
                controller: _styleRefController,
                style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w600),
                decoration: _inputDecoration(hint: 'e.g. ART-HD-8921, ST-501'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter style/article number' : null,
              ),
              const SizedBox(height: 16),

              // QUANTITY & FOB PRICE
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('TOTAL VOLUME (PCS)', style: _labelStyle),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _quantityController,
                          keyboardType: TextInputType.number,
                          style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold),
                          decoration: _inputDecoration(hint: '1000'),
                          onChanged: (v) {
                            final total = int.tryParse(v) ?? 0;
                            setState(() => _recalculateSizes(total));
                          },
                          validator: (v) {
                            final n = int.tryParse(v ?? '');
                            if (n == null || n <= 0) return 'Invalid';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('UNIT FOB PRICE', style: _labelStyle),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _priceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold),
                          decoration: _inputDecoration(hint: '1450.00'),
                          validator: (v) {
                            final d = double.tryParse(v ?? '');
                            if (d == null || d <= 0) return 'Invalid';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // EX-FACTORY TARGET DATE
              Text('EX-FACTORY SHIPMENT DATE', style: _labelStyle),
              const SizedBox(height: 6),
              TextFormField(
                controller: _dateController,
                readOnly: true,
                style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w600),
                decoration: _inputDecoration(
                  hint: 'YYYY-MM-DD',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFF332B6B)),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _exFactoryDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() {
                          _exFactoryDate = picked;
                          _dateController.text = picked.toIso8601String().split('T')[0];
                        });
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // SIZE BREAKDOWN CARD
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAF8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x1A000000)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Size Ratio Distribution',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1C1C1A),
                          ),
                        ),
                        Text(
                          'Standard Apparel Curve',
                          style: GoogleFonts.publicSans(
                            fontSize: 10,
                            color: const Color(0xFF6B6A65),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: _sizes.map((s) {
                        final qty = _sizeQuantities[s] ?? 0;
                        return Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0x1A000000)),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  s,
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF332B6B),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$qty',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF1C1C1A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // SUBMIT BUTTON
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF332B6B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: state.isSubmitting ? null : _submit,
                child: state.isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_outline, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Confirm & Book PO Contract',
                            style: GoogleFonts.publicSans(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle get _labelStyle => GoogleFonts.jetBrainsMono(
        fontSize: 10.5,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF6B6A65),
        letterSpacing: 0.5,
      );

  InputDecoration _inputDecoration({required String hint, Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.publicSans(fontSize: 12.5, color: const Color(0xFFB6B4AC)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      filled: true,
      fillColor: const Color(0xFFFAFAF8),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0x1A000000)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0x1A000000)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF332B6B), width: 1.5),
      ),
    );
  }
}
