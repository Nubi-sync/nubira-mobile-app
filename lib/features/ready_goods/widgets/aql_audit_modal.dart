import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/ready_goods_provider.dart';

class AqlAuditModal extends ConsumerStatefulWidget {
  const AqlAuditModal({super.key});

  @override
  ConsumerState<AqlAuditModal> createState() => _AqlAuditModalState();
}

class _AqlAuditModalState extends ConsumerState<AqlAuditModal> {
  final _sampleSizeCtrl = TextEditingController(text: '32');
  final _critCtrl = TextEditingController(text: '0');
  final _majCtrl = TextEditingController(text: '0');
  final _minCtrl = TextEditingController(text: '0');
  final _remarksCtrl = TextEditingController(text: 'ISO 2859-1 Level II normal sample audit verified. 100% compliant.');

  String _selectedCarton = '';
  String _selectedDecision = 'PASS';
  String _selectedInspector = 'Sunil Verma';
  bool _isSubmitting = false;

  final List<String> _decisions = ['PASS', 'RE_AUDIT', 'REJECT_QUARANTINE'];

  @override
  void initState() {
    super.initState();
    final cartons = ref.read(readyGoodsProvider).cartons;
    if (cartons.isNotEmpty) {
      _selectedCarton = cartons.first.cartonNumber;
    }
    final workers = ref.read(readyGoodsProvider).workers;
    if (workers.isNotEmpty) {
      _selectedInspector = workers.first.workerName;
    }
  }

  @override
  void dispose() {
    _sampleSizeCtrl.dispose();
    _critCtrl.dispose();
    _majCtrl.dispose();
    _minCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    final state = ref.read(readyGoodsProvider);
    final carton = state.cartons.firstWhere(
      (c) => c.cartonNumber == _selectedCarton,
      orElse: () => state.cartons.isNotEmpty ? state.cartons.first : state.cartons.first,
    );

    try {
      await ref.read(readyGoodsProvider.notifier).recordAqlAudit(
            cartonNumber: _selectedCarton,
            orderNumber: carton.orderNumber,
            sampleSize: int.tryParse(_sampleSizeCtrl.text.trim()) ?? 32,
            criticalDefects: int.tryParse(_critCtrl.text.trim()) ?? 0,
            majorDefects: int.tryParse(_majCtrl.text.trim()) ?? 0,
            minorDefects: int.tryParse(_minCtrl.text.trim()) ?? 0,
            decision: _selectedDecision,
            inspectorName: _selectedInspector,
            remarks: _remarksCtrl.text.trim(),
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _selectedDecision == 'PASS' ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
            content: Text(
              _selectedDecision == 'PASS'
                  ? '✓ AQL 2.5 Audit Passed for $_selectedCarton!'
                  : '⚠️ AQL Audit Failed / Quarantined for $_selectedCarton!',
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
    final cartons = state.cartons;
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ISO 2859-1 AQL 2.5 Final Audit',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Master carton quality compliance inspection',
                      style: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Select Carton
            Text('Target Carton *', style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: cartons.any((c) => c.cartonNumber == _selectedCarton) ? _selectedCarton : (cartons.isNotEmpty ? cartons.first.cartonNumber : null),
              items: cartons.map((c) => DropdownMenuItem(value: c.cartonNumber, child: Text('${c.cartonNumber} • ${c.buyer} (${c.totalPieces} pcs)', style: GoogleFonts.publicSans(fontSize: 12.5)))).toList(),
              onChanged: (v) => setState(() => _selectedCarton = v!),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              ),
            ),
            const SizedBox(height: 14),

            // Sample Size & Inspector
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sample Size (pcs)', style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _sampleSizeCtrl,
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
                      Text('Chief Inspector', style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: workers.any((w) => w.workerName == _selectedInspector) ? _selectedInspector : (workers.isNotEmpty ? workers.first.workerName : null),
                        items: workers.map((w) => DropdownMenuItem(value: w.workerName, child: Text(w.workerName, style: GoogleFonts.publicSans(fontSize: 12.5)))).toList(),
                        onChanged: (v) => setState(() => _selectedInspector = v!),
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

            // Defect Counts Strip
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Critical (Max 0)', style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFDC2626))),
                      const SizedBox(height: 4),
                      TextFormField(
                        controller: _critCtrl,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, color: const Color(0xFFDC2626)),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFFFEF2F2),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFFECACA))),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Major (AQL 2.5)', style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFD97706))),
                      const SizedBox(height: 4),
                      TextFormField(
                        controller: _majCtrl,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, color: const Color(0xFFD97706)),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFFFFFBEB),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFFDE68A))),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Minor (AQL 4.0)', style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB))),
                      const SizedBox(height: 4),
                      TextFormField(
                        controller: _minCtrl,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, color: const Color(0xFF2563EB)),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFFEFF6FF),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFBFDBFE))),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Audit Decision
            Text('Audit Clearance Verdict *', style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _selectedDecision,
              items: _decisions.map((d) => DropdownMenuItem(value: d, child: Text(d.replaceAll('_', ' '), style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.bold)))).toList(),
              onChanged: (v) => setState(() => _selectedDecision = v!),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              ),
            ),
            const SizedBox(height: 14),

            // Remarks
            Text('Auditor Comments & Seal Tagging', style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
            const SizedBox(height: 6),
            TextFormField(
              controller: _remarksCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              ),
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
                    : Text('Submit AQL Certificate', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
