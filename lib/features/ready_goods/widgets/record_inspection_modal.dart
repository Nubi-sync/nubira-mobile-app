import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/ready_goods_models.dart';
import '../providers/ready_goods_provider.dart';

class RecordInspectionModal extends ConsumerStatefulWidget {
  final FinishingInspectionTask task;

  const RecordInspectionModal({super.key, required this.task});

  @override
  ConsumerState<RecordInspectionModal> createState() => _RecordInspectionModalState();
}

class _RecordInspectionModalState extends ConsumerState<RecordInspectionModal> {
  final _passedCtrl = TextEditingController();
  final _alterCtrl = TextEditingController(text: '0');
  final _remarksCtrl = TextEditingController();

  String _selectedChecker = '';
  String _selectedDefect = 'Seam Open / Uneven Hem';
  bool _isSubmitting = false;

  final List<String> _defects = [
    'Seam Open / Uneven Hem',
    'Broken Stitch / Thread Cut',
    'Skip Stitch / Needle Hole',
    'Measurement / Size Grading Off',
    'Oil Spot / Wash Stain',
    'Fabric Cut / Shading Variance',
    'Print / Embroidery Misalignment',
    'Other Finishing Defect',
  ];

  @override
  void initState() {
    super.initState();
    _passedCtrl.text = widget.task.piecesCount.toString();
    final workers = ref.read(readyGoodsProvider).workers;
    if (workers.isNotEmpty) {
      _selectedChecker = widget.task.checkerName ?? workers.first.workerName;
    }
  }

  @override
  void dispose() {
    _passedCtrl.dispose();
    _alterCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  void _onPassedChanged(String val) {
    final passed = int.tryParse(val) ?? 0;
    final total = widget.task.piecesCount;
    final alter = (total - passed).clamp(0, total);
    _alterCtrl.text = alter.toString();
  }

  void _onAlterChanged(String val) {
    final alter = int.tryParse(val) ?? 0;
    final total = widget.task.piecesCount;
    final passed = (total - alter).clamp(0, total);
    _passedCtrl.text = passed.toString();
  }

  Future<void> _submit() async {
    final passed = int.tryParse(_passedCtrl.text.trim()) ?? 0;
    final alter = int.tryParse(_alterCtrl.text.trim()) ?? 0;
    setState(() => _isSubmitting = true);

    try {
      await ref.read(readyGoodsProvider.notifier).recordInspectionResult(
            taskId: widget.task.id,
            passedPieces: passed,
            alterationPieces: alter,
            checkerName: _selectedChecker.isNotEmpty ? _selectedChecker : 'Quality Auditor',
            defectCategory: alter > 0 ? _selectedDefect : null,
            remarks: _remarksCtrl.text.trim(),
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: alter > 0 ? const Color(0xFFD97706) : const Color(0xFF16A34A),
            content: Text(
              alter > 0
                  ? '⚠️ $passed pcs passed to packing. $alter pcs sent to Alteration Clinic!'
                  : '✓ 100% Passed! $passed pcs ready for export packing.',
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
    final workers = ref.watch(readyGoodsProvider).workers;

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
                      'Quality Inspection & Alteration Triage',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Lot #${widget.task.lotNumber} • ${widget.task.piecesCount} total pcs',
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

            // Assigned Auditor
            Text('Assigned QC Auditor *', style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: workers.any((w) => w.workerName == _selectedChecker) ? _selectedChecker : (workers.isNotEmpty ? workers.first.workerName : null),
              items: workers.map((w) => DropdownMenuItem(value: w.workerName, child: Text('${w.workerName} (${w.role})', style: GoogleFonts.publicSans(fontSize: 12.5)))).toList(),
              onChanged: (v) => setState(() => _selectedChecker = v!),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              ),
            ),
            const SizedBox(height: 14),

            // Passed vs Alteration Qty Strip
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF16A34A)),
                            const SizedBox(width: 6),
                            Text('Passed to Packing', style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF15803D))),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _passedCtrl,
                          keyboardType: TextInputType.number,
                          onChanged: _onPassedChanged,
                          style: GoogleFonts.jetBrainsMono(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF15803D)),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF86EFAC))),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.build_rounded, size: 16, color: Color(0xFFD97706)),
                            const SizedBox(width: 6),
                            Text('Alteration Clinic', style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFB45309))),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _alterCtrl,
                          keyboardType: TextInputType.number,
                          onChanged: _onAlterChanged,
                          style: GoogleFonts.jetBrainsMono(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFFB45309)),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFFCD34D))),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Defect Tagging if Alteration > 0
            Text('Defect Root-Cause Category', style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _selectedDefect,
              items: _defects.map((d) => DropdownMenuItem(value: d, child: Text(d, style: GoogleFonts.publicSans(fontSize: 12)))).toList(),
              onChanged: (v) => setState(() => _selectedDefect = v!),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              ),
            ),
            const SizedBox(height: 14),

            // Remarks
            Text('Auditor Notes & Mending Instructions', style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
            const SizedBox(height: 6),
            TextFormField(
              controller: _remarksCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'e.g. Broken stitch at side seam, tailor assigned to repair',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              ),
            ),
            const SizedBox(height: 20),

            // Confirm Button
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
                    : Text('Save Quality Clearance Log', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
