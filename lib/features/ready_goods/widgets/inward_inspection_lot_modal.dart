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
  final _lotNumberCtrl = TextEditingController();
  final _orderNumberCtrl = TextEditingController();
  final _styleNameCtrl = TextEditingController();
  final _colorCtrl = TextEditingController(text: 'Standard');
  final _piecesCtrl = TextEditingController();

  String _selectedBuyer = 'Zara International';
  String _selectedStage = 'POST_IRON';
  String _selectedPriority = 'NORMAL';
  bool _isSubmitting = false;

  final List<String> _stages = [
    'POST_WASH',
    'POST_IRON',
    'POST_PRINT',
    'POST_EMBROIDERY',
    'CUTTING_AUDIT',
  ];

  final List<String> _priorities = ['NORMAL', 'RUSH', 'CRITICAL'];

  @override
  void initState() {
    super.initState();
    final randomSuffix = DateTime.now().millisecondsSinceEpoch.toString().substring(9);
    _lotNumberCtrl.text = 'LOT-FIN-$randomSuffix';
    _orderNumberCtrl.text = 'PO-7715';
    _styleNameCtrl.text = 'Heavyweight Boxy Tee';
    _piecesCtrl.text = '500';
  }

  @override
  void dispose() {
    _lotNumberCtrl.dispose();
    _orderNumberCtrl.dispose();
    _styleNameCtrl.dispose();
    _colorCtrl.dispose();
    _piecesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      await ref.read(readyGoodsProvider.notifier).inwardLot(
            lotNumber: _lotNumberCtrl.text.trim(),
            orderNumber: _orderNumberCtrl.text.trim(),
            styleName: _styleNameCtrl.text.trim(),
            color: _colorCtrl.text.trim(),
            buyer: _selectedBuyer,
            stage: _selectedStage,
            piecesCount: int.tryParse(_piecesCtrl.text.trim()) ?? 0,
            priority: _selectedPriority,
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF16A34A),
            content: Text(
              '✓ Inwarded ${_piecesCtrl.text.trim()} pcs of ${_lotNumberCtrl.text.trim()} to Quality Clinic!',
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

    return Container(
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
                  Text(
                    'Inward Lot to Quality Clinic',
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

              // Buyer Selector
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

              // Lot # & Order #
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Lot Number *', style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _lotNumberCtrl,
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
                          controller: _orderNumberCtrl,
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
              const SizedBox(height: 14),

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
              const SizedBox(height: 14),

              // Stage & Quantity
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Inward From *', style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _selectedStage,
                          items: _stages.map((s) => DropdownMenuItem(value: s, child: Text(s.replaceAll('_', ' '), style: GoogleFonts.publicSans(fontSize: 12)))).toList(),
                          onChanged: (v) => setState(() => _selectedStage = v!),
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
                        Text('Pieces Count *', style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _piecesCtrl,
                          keyboardType: TextInputType.number,
                          validator: (v) => (v == null || int.tryParse(v) == null) ? 'Enter valid qty' : null,
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
