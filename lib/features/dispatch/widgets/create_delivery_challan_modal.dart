import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/dispatch_provider.dart';

class CreateDeliveryChallanModal extends ConsumerStatefulWidget {
  const CreateDeliveryChallanModal({super.key});

  @override
  ConsumerState<CreateDeliveryChallanModal> createState() => _CreateDeliveryChallanModalState();
}

class _CreateDeliveryChallanModalState extends ConsumerState<CreateDeliveryChallanModal> {
  static const Color kCanvasColor = Color(0xFFFAF7F0);
  static const Color kCardBg = Color(0xFFFFFFFF);
  static const Color kPrimaryBrand = Color(0xFF3A3564);
  static const Color kBorderColor = Color(0xFFE7E1D6);
  static const Color kMutedText = Color(0xFF7A7488);
  static const Color kInkText = Color(0xFF232028);

  final _formKey = GlobalKey<FormState>();
  final _challanNoCtrl = TextEditingController();
  final _buyerNameCtrl = TextEditingController();
  final _destinationCtrl = TextEditingController();
  final _vehicleNoCtrl = TextEditingController();
  final _driverNameCtrl = TextEditingController();
  final _driverPhoneCtrl = TextEditingController();

  List<Map<String, dynamic>> _itemRows = [];
  bool _isSubmitting = false;

  final List<String> _sizes = ['XS', 'S', 'M', 'L', 'XL', '2XL', '3XL', 'Free Size'];

  @override
  void initState() {
    super.initState();
    final year = DateTime.now().year;
    final rng = Random().nextInt(9000) + 1000;
    _challanNoCtrl.text = 'CH-$year-$rng';

    final articles = ref.read(dispatchProvider).articles;
    _itemRows = [
      {
        'article_id': articles.isNotEmpty ? articles.first.id : '',
        'color': 'Navy Blue',
        'size': 'L',
        'quantity': 100,
      }
    ];
  }

  @override
  void dispose() {
    _challanNoCtrl.dispose();
    _buyerNameCtrl.dispose();
    _destinationCtrl.dispose();
    _vehicleNoCtrl.dispose();
    _driverNameCtrl.dispose();
    _driverPhoneCtrl.dispose();
    super.dispose();
  }

  void _addRow() {
    final articles = ref.read(dispatchProvider).articles;
    setState(() {
      _itemRows.add({
        'article_id': articles.isNotEmpty ? articles.first.id : '',
        'color': '',
        'size': 'M',
        'quantity': 50,
      });
    });
  }

  void _removeRow(int index) {
    if (_itemRows.length > 1) {
      setState(() {
        _itemRows.removeAt(index);
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      await ref.read(dispatchProvider.notifier).createDeliveryChallan(
            challanNo: _challanNoCtrl.text.trim(),
            buyerName: _buyerNameCtrl.text.trim(),
            destination: _destinationCtrl.text.trim(),
            vehicleNo: _vehicleNoCtrl.text.trim(),
            driverName: _driverNameCtrl.text.trim(),
            driverPhone: _driverPhoneCtrl.text.trim(),
            items: _itemRows,
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            content: Text(
              '✓ Delivery Challan #${_challanNoCtrl.text.trim()} issued successfully!',
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
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 740),
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
                    child: const Icon(Icons.local_shipping_outlined, color: kPrimaryBrand, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'New Delivery Challan',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: kInkText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Issue official dispatch challan for transport loading',
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

            // Form Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Challan No & Buyer
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('CHALLAN NO *', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w700, color: kMutedText)),
                                const SizedBox(height: 4),
                                TextFormField(
                                  controller: _challanNoCtrl,
                                  style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w700, color: kInkText),
                                  decoration: _inputDecoration('e.g. CH-2026-001'),
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
                                Text('BUYER / CONSIGNEE *', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w700, color: kMutedText)),
                                const SizedBox(height: 4),
                                TextFormField(
                                  controller: _buyerNameCtrl,
                                  style: GoogleFonts.publicSans(fontSize: 12, color: kInkText),
                                  decoration: _inputDecoration('e.g. Zara Logistics'),
                                  validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Destination & Vehicle No
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('DESTINATION / CITY', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w700, color: kMutedText)),
                                const SizedBox(height: 4),
                                TextFormField(
                                  controller: _destinationCtrl,
                                  style: GoogleFonts.publicSans(fontSize: 12, color: kInkText),
                                  decoration: _inputDecoration('e.g. Mumbai CFS Hub'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('VEHICLE / TRUCK NO', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w700, color: kMutedText)),
                                const SizedBox(height: 4),
                                TextFormField(
                                  controller: _vehicleNoCtrl,
                                  style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w600, color: kInkText),
                                  decoration: _inputDecoration('MH-04-EB-1234'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Driver Name & Phone
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('DRIVER NAME', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w700, color: kMutedText)),
                                const SizedBox(height: 4),
                                TextFormField(
                                  controller: _driverNameCtrl,
                                  style: GoogleFonts.publicSans(fontSize: 12, color: kInkText),
                                  decoration: _inputDecoration('e.g. Ramesh Kumar'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('DRIVER PHONE', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w700, color: kMutedText)),
                                const SizedBox(height: 4),
                                TextFormField(
                                  controller: _driverPhoneCtrl,
                                  keyboardType: TextInputType.phone,
                                  style: GoogleFonts.jetBrainsMono(fontSize: 12, color: kInkText),
                                  decoration: _inputDecoration('+91 98765 43210'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Multi-Row Items Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('DISPATCH ARTICLE ITEMS', style: GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.w800, color: kInkText)),
                          TextButton.icon(
                            onPressed: _addRow,
                            icon: const Icon(Icons.add, size: 14, color: kPrimaryBrand),
                            label: Text('+ Add Item', style: GoogleFonts.publicSans(fontSize: 11.5, fontWeight: FontWeight.w700, color: kPrimaryBrand)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      ..._itemRows.asMap().entries.map((entry) {
                        final index = entry.key;
                        final row = entry.value;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: kBorderColor),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  // Article Selector
                                  Expanded(
                                    flex: 4,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      decoration: BoxDecoration(
                                        color: kCardBg,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: kBorderColor),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: articles.any((a) => a.id == row['article_id'])
                                              ? row['article_id']
                                              : (articles.isNotEmpty ? articles.first.id : ''),
                                          isExpanded: true,
                                          items: articles.map((a) {
                                            return DropdownMenuItem(
                                              value: a.id,
                                              child: Text(
                                                a.artNo,
                                                style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: kInkText),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: (v) {
                                            setState(() => row['article_id'] = v ?? '');
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),

                                  // Size
                                  Expanded(
                                    flex: 2,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6),
                                      decoration: BoxDecoration(
                                        color: kCardBg,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: kBorderColor),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: _sizes.contains(row['size']) ? row['size'] : 'M',
                                          isExpanded: true,
                                          items: _sizes.map((s) {
                                            return DropdownMenuItem(
                                              value: s,
                                              child: Text(s, style: GoogleFonts.jetBrainsMono(fontSize: 11, color: kInkText)),
                                            );
                                          }).toList(),
                                          onChanged: (v) {
                                            setState(() => row['size'] = v ?? 'M');
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),

                                  // Quantity
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      initialValue: row['quantity'].toString(),
                                      keyboardType: TextInputType.number,
                                      style: GoogleFonts.jetBrainsMono(fontSize: 11.5, fontWeight: FontWeight.bold, color: kInkText),
                                      decoration: _inputDecoration('Qty'),
                                      onChanged: (v) {
                                        row['quantity'] = int.tryParse(v.trim()) ?? 0;
                                      },
                                    ),
                                  ),

                                  if (_itemRows.length > 1) ...[
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFE11D48)),
                                      onPressed: () => _removeRow(index),
                                    ),
                                  ],
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
                          : const Icon(Icons.add, size: 16),
                      label: Text(
                        _isSubmitting ? 'Issuing Challan...' : 'Issue Delivery Challan',
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
