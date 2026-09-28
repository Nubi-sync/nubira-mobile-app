import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/dispatch_provider.dart';

class ChallanFormItemRow {
  String articleId;
  final TextEditingController colorCtrl;
  final TextEditingController sizeCtrl;
  final TextEditingController quantityCtrl;

  ChallanFormItemRow({
    required this.articleId,
    required String color,
    required String size,
    required int quantity,
  })  : colorCtrl = TextEditingController(text: color),
        sizeCtrl = TextEditingController(text: size),
        quantityCtrl = TextEditingController(text: quantity > 0 ? quantity.toString() : '');

  int get quantity => int.tryParse(quantityCtrl.text.trim()) ?? 0;

  void dispose() {
    colorCtrl.dispose();
    sizeCtrl.dispose();
    quantityCtrl.dispose();
  }
}

class CreateDeliveryChallanModal extends ConsumerStatefulWidget {
  const CreateDeliveryChallanModal({super.key});

  @override
  ConsumerState<CreateDeliveryChallanModal> createState() => _CreateDeliveryChallanModalState();
}

class _CreateDeliveryChallanModalState extends ConsumerState<CreateDeliveryChallanModal> {
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
  final _challanNoCtrl = TextEditingController();
  final _buyerNameCtrl = TextEditingController();
  final _vendorNameCtrl = TextEditingController();
  final _destinationCtrl = TextEditingController();
  final _vehicleNoCtrl = TextEditingController();
  final _driverPhoneCtrl = TextEditingController();

  final List<ChallanFormItemRow> _itemRows = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final year = DateTime.now().year;
    final rng = Random().nextInt(9000) + 1000;
    _challanNoCtrl.text = 'CH-$year-$rng';

    final articles = ref.read(dispatchProvider).articles;
    _itemRows.add(
      ChallanFormItemRow(
        articleId: articles.isNotEmpty ? articles.first.id : '',
        color: 'Navy Blue',
        size: 'L / 32',
        quantity: 100,
      ),
    );
  }

  @override
  void dispose() {
    _challanNoCtrl.dispose();
    _buyerNameCtrl.dispose();
    _vendorNameCtrl.dispose();
    _destinationCtrl.dispose();
    _vehicleNoCtrl.dispose();
    _driverPhoneCtrl.dispose();
    for (var r in _itemRows) {
      r.dispose();
    }
    super.dispose();
  }

  int _calculateTotalPieces() {
    return _itemRows.fold<int>(0, (sum, r) => sum + r.quantity);
  }

  void _addRow() {
    final articles = ref.read(dispatchProvider).articles;
    setState(() {
      _itemRows.add(
        ChallanFormItemRow(
          articleId: articles.isNotEmpty ? articles.first.id : '',
          color: 'Standard',
          size: 'L',
          quantity: 100,
        ),
      );
    });
  }

  void _removeRow(int index) {
    if (_itemRows.length > 1) {
      setState(() {
        final removed = _itemRows.removeAt(index);
        removed.dispose();
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final formattedItems = _itemRows.map((r) {
      return {
        'article_id': r.articleId,
        'color': r.colorCtrl.text.trim(),
        'size': r.sizeCtrl.text.trim(),
        'quantity': r.quantity,
      };
    }).toList();

    if (formattedItems.every((it) => (it['quantity'] as int) <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid quantity for at least one garment line.'),
          backgroundColor: Color(0xFFE11D48),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await ref.read(dispatchProvider.notifier).createDeliveryChallan(
            challanNo: _challanNoCtrl.text.trim(),
            buyerName: _buyerNameCtrl.text.trim(),
            vendorName: _vendorNameCtrl.text.trim().isEmpty ? null : _vendorNameCtrl.text.trim(),
            destination: _destinationCtrl.text.trim().isEmpty ? null : _destinationCtrl.text.trim(),
            vehicleNo: _vehicleNoCtrl.text.trim().isEmpty ? null : _vehicleNoCtrl.text.trim(),
            driverPhone: _driverPhoneCtrl.text.trim().isEmpty ? null : _driverPhoneCtrl.text.trim(),
            items: formattedItems,
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF047857),
            content: Text(
              '✓ Delivery Challan #${_challanNoCtrl.text.trim()} issued and logged into master register.',
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
    final totalPieces = _calculateTotalPieces();

    return Dialog(
      backgroundColor: kCardBg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: kBorderColor),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 820),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ==========================================
            // Modal Header (Exact Web Match)
            // ==========================================
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
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.local_shipping_outlined, color: kPrimaryBrand, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Generate Delivery Challan',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: kInkText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Create official goods delivery pass for buyer gate-out',
                          style: GoogleFonts.publicSans(
                            fontSize: 11.5,
                            color: kMutedText,
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
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.close, size: 18, color: kMutedText),
                    ),
                  ),
                ],
              ),
            ),

            // ==========================================
            // Scrollable Form Body
            // ==========================================
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ----------------------------------------------------
                      // Section 1: Basic Identifiers (3 Fields)
                      // ----------------------------------------------------
                      LayoutBuilder(
                        builder: (ctx, constraints) {
                          final isNarrow = constraints.maxWidth < 480;
                          if (isNarrow) {
                            return Column(
                              children: [
                                _buildFormField(
                                  label: 'CHALLAN NUMBER *',
                                  child: TextFormField(
                                    controller: _challanNoCtrl,
                                    style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w800, color: kInkText),
                                    decoration: _inputDecoration('CH-2026-XXXX'),
                                    validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _buildFormField(
                                  label: 'BUYER / CONSIGNEE NAME *',
                                  child: TextFormField(
                                    controller: _buyerNameCtrl,
                                    style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.w600, color: kInkText),
                                    decoration: _inputDecoration('Enter Buyer / Consignee Name'),
                                    validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _buildFormField(
                                  label: 'MANUFACTURING VENDOR / UNIT',
                                  child: TextFormField(
                                    controller: _vendorNameCtrl,
                                    style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.w500, color: kInkText),
                                    decoration: _inputDecoration('Enter Vendor / Unit Name'),
                                  ),
                                ),
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _buildFormField(
                                  label: 'CHALLAN NUMBER *',
                                  child: TextFormField(
                                    controller: _challanNoCtrl,
                                    style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w800, color: kInkText),
                                    decoration: _inputDecoration('CH-2026-XXXX'),
                                    validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildFormField(
                                  label: 'BUYER / CONSIGNEE NAME *',
                                  child: TextFormField(
                                    controller: _buyerNameCtrl,
                                    style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.w600, color: kInkText),
                                    decoration: _inputDecoration('Enter Buyer / Consignee Name'),
                                    validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildFormField(
                                  label: 'MANUFACTURING VENDOR / UNIT',
                                  child: TextFormField(
                                    controller: _vendorNameCtrl,
                                    style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.w500, color: kInkText),
                                    decoration: _inputDecoration('Enter Vendor / Unit Name'),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 14),

                      // ----------------------------------------------------
                      // Section 2: Logistics Parameters (3 Fields)
                      // ----------------------------------------------------
                      LayoutBuilder(
                        builder: (ctx, constraints) {
                          final isNarrow = constraints.maxWidth < 480;
                          if (isNarrow) {
                            return Column(
                              children: [
                                _buildFormField(
                                  label: 'DESTINATION CITY',
                                  child: TextFormField(
                                    controller: _destinationCtrl,
                                    style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.w500, color: kInkText),
                                    decoration: _inputDecoration('Bhiwandi Godown'),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _buildFormField(
                                  label: 'VEHICLE / TRUCK NO',
                                  child: TextFormField(
                                    controller: _vehicleNoCtrl,
                                    style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w700, color: kInkText),
                                    decoration: _inputDecoration('WB-04-AB-1234'),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _buildFormField(
                                  label: 'DRIVER PHONE',
                                  child: TextFormField(
                                    controller: _driverPhoneCtrl,
                                    keyboardType: TextInputType.phone,
                                    style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w500, color: kInkText),
                                    decoration: _inputDecoration('9876543210'),
                                  ),
                                ),
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _buildFormField(
                                  label: 'DESTINATION CITY',
                                  child: TextFormField(
                                    controller: _destinationCtrl,
                                    style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.w500, color: kInkText),
                                    decoration: _inputDecoration('Bhiwandi Godown'),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildFormField(
                                  label: 'VEHICLE / TRUCK NO',
                                  child: TextFormField(
                                    controller: _vehicleNoCtrl,
                                    style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w700, color: kInkText),
                                    decoration: _inputDecoration('WB-04-AB-1234'),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildFormField(
                                  label: 'DRIVER PHONE',
                                  child: TextFormField(
                                    controller: _driverPhoneCtrl,
                                    keyboardType: TextInputType.phone,
                                    style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w500, color: kInkText),
                                    decoration: _inputDecoration('9876543210'),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 18),

                      // ----------------------------------------------------
                      // Section 3: Multi-Item Garment Lines Cards
                      // ----------------------------------------------------
                      const Divider(height: 1, color: kBorderColor),
                      const SizedBox(height: 14),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CHALLAN GARMENT LINES',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: kInkText,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              RichText(
                                text: TextSpan(
                                  style: GoogleFonts.publicSans(fontSize: 11.5, color: kMutedText),
                                  children: [
                                    const TextSpan(text: 'Total: '),
                                    TextSpan(
                                      text: '$totalPieces pcs',
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: kInkText,
                                      ),
                                    ),
                                    TextSpan(text: ' across ${_itemRows.length} ${_itemRows.length == 1 ? 'line' : 'lines'}'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          InkWell(
                            onTap: _addRow,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: kCanvasColor,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: kBorderColor),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.add, size: 14, color: kPrimaryBrand),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Add Article Line',
                                    style: GoogleFonts.publicSans(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: kPrimaryBrand,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // List of Garment Item Cards
                      ..._itemRows.asMap().entries.map((entry) {
                        final index = entry.key;
                        final row = entry.value;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Line Header: Article Selector + Trash Button
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'ARTICLE MASTER STYLE *',
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF64748B),
                                            letterSpacing: 0.4,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: const Color(0xFFCBD5E1)),
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              value: articles.any((a) => a.id == row.articleId)
                                                  ? row.articleId
                                                  : (articles.isNotEmpty ? articles.first.id : ''),
                                              isExpanded: true,
                                              items: articles.map((a) {
                                                final desc = (a.description != null && a.description!.isNotEmpty) ? ' • ${a.description}' : '';
                                                return DropdownMenuItem(
                                                  value: a.id,
                                                  child: Text(
                                                    'Art #${a.artNo}$desc',
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 12.5,
                                                      fontWeight: FontWeight.w700,
                                                      color: kInkText,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                );
                                              }).toList(),
                                              onChanged: (v) {
                                                setState(() => row.articleId = v ?? '');
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_itemRows.length > 1) ...[
                                    const SizedBox(width: 8),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 18),
                                      child: InkWell(
                                        onTap: () => _removeRow(index),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFE4E6),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFBE123C)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Line Details: Color, Size, Quantity in 3 Columns
                              Row(
                                children: [
                                  // Color / Pattern
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'COLOR / PATTERN',
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF64748B),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        TextFormField(
                                          controller: row.colorCtrl,
                                          style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.w500, color: kInkText),
                                          decoration: _itemInputDecoration('e.g. Navy Blue'),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Size
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Text(
                                          'SIZE',
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF64748B),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        TextFormField(
                                          controller: row.sizeCtrl,
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.w700, color: kInkText),
                                          decoration: _itemInputDecoration('L / 32'),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Quantity (pcs) *
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'QUANTITY (PCS) *',
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF64748B),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        TextFormField(
                                          controller: row.quantityCtrl,
                                          keyboardType: TextInputType.number,
                                          textAlign: TextAlign.right,
                                          onChanged: (_) => setState(() {}),
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w900,
                                            color: kInkText,
                                          ),
                                          decoration: _itemInputDecoration('0'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),

            // ==========================================
            // Modal Footer (Exact Web Match)
            // ==========================================
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(17)),
                border: Border(top: BorderSide(color: kBorderColor)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Ready for Dispatch Registration',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      color: kMutedText,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: kInputBorder),
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: const Color(0xFF475569)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimaryBrand,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(
                                'Generate & Issue Delivery Challan',
                                style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.w700),
                              ),
                      ),
                    ],
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

  InputDecoration _itemInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF94A3B8)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kInputBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kInputBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kPrimaryBrand, width: 1.5)),
    );
  }
}
