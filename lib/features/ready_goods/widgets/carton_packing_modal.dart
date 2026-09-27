import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/ready_goods_provider.dart';

class CartonPackingModal extends ConsumerStatefulWidget {
  const CartonPackingModal({super.key});

  @override
  ConsumerState<CartonPackingModal> createState() => _CartonPackingModalState();
}

class _CartonPackingModalState extends ConsumerState<CartonPackingModal> {
  final _cartonNoCtrl = TextEditingController();
  final _orderNoCtrl = TextEditingController();
  final _styleNameCtrl = TextEditingController();
  final _colorCtrl = TextEditingController(text: 'Standard');
  final _piecesCtrl = TextEditingController(text: '50');
  final _weightCtrl = TextEditingController(text: '15.2');

  String _selectedBuyer = 'Zara International';
  String _selectedBay = 'BAY_3';
  String _selectedPacker = 'Vikram Singh';
  bool _isSubmitting = false;

  final List<String> _bays = ['BAY_3', 'BAY_4', 'BAY_5'];

  @override
  void initState() {
    super.initState();
    final randomSuffix = DateTime.now().millisecondsSinceEpoch.toString().substring(8);
    _cartonNoCtrl.text = 'CTN-EXP-$randomSuffix';
    _orderNoCtrl.text = 'PO-7715';
    _styleNameCtrl.text = 'Heavyweight Boxy Tee';
    final workers = ref.read(readyGoodsProvider).workers;
    if (workers.isNotEmpty) {
      _selectedPacker = workers.first.workerName;
    }
  }

  @override
  void dispose() {
    _cartonNoCtrl.dispose();
    _orderNoCtrl.dispose();
    _styleNameCtrl.dispose();
    _colorCtrl.dispose();
    _piecesCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    try {
      await ref.read(readyGoodsProvider.notifier).packCarton(
            cartonNumber: _cartonNoCtrl.text.trim(),
            orderNumber: _orderNoCtrl.text.trim(),
            buyer: _selectedBuyer,
            styleName: _styleNameCtrl.text.trim(),
            color: _colorCtrl.text.trim(),
            totalPieces: int.tryParse(_piecesCtrl.text.trim()) ?? 50,
            measuredWeightKg: double.tryParse(_weightCtrl.text.trim()) ?? 15.0,
            godownBay: _selectedBay,
            sealedBy: _selectedPacker,
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF16A34A),
            content: Text(
              '✓ Packed ${_cartonNoCtrl.text.trim()} (${_piecesCtrl.text.trim()} pcs) into $_selectedBay!',
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
    final state = ref.watch(readyGoodsProvider);
    final buyers = state.buyers;
    final workers = state.workers;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
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
                Text(
                  'Pack Master Export Carton',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Buyer
            Text('Buyer / Brand *', style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
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
            const SizedBox(height: 14),

            // Carton # & PO #
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Carton Barcode / Manifest *', style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _cartonNoCtrl,
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
                      Text('PO / Order Number *', style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _orderNoCtrl,
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
            const SizedBox(height: 14),

            // Pieces & Weight
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pieces in Carton *', style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _piecesCtrl,
                        keyboardType: TextInputType.number,
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
                      Text('Gross Weight (Kg) *', style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _weightCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
            const SizedBox(height: 14),

            // Godown Bay & Packer
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Godown Storage Bay', style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _selectedBay,
                        items: _bays.map((b) => DropdownMenuItem(value: b, child: Text(b, style: GoogleFonts.publicSans(fontSize: 13)))).toList(),
                        onChanged: (v) => setState(() => _selectedBay = v!),
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
                      Text('Sealed By', style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: workers.any((w) => w.workerName == _selectedPacker) ? _selectedPacker : (workers.isNotEmpty ? workers.first.workerName : null),
                        items: workers.map((w) => DropdownMenuItem(value: w.workerName, child: Text(w.workerName, style: GoogleFonts.publicSans(fontSize: 12)))).toList(),
                        onChanged: (v) => setState(() => _selectedPacker = v!),
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
            const SizedBox(height: 20),

            // Submit
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
                    : Text('Seal Carton & Generate Manifest', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
