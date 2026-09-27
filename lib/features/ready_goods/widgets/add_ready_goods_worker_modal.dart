import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/ready_goods_provider.dart';

class AddReadyGoodsWorkerModal extends ConsumerStatefulWidget {
  const AddReadyGoodsWorkerModal({super.key});

  @override
  ConsumerState<AddReadyGoodsWorkerModal> createState() => _AddReadyGoodsWorkerModalState();
}

class _AddReadyGoodsWorkerModalState extends ConsumerState<AddReadyGoodsWorkerModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _selectedRole = 'Quality Auditor (AQL Specialist)';
  String _selectedSkill = 'Certified';
  String _selectedShift = 'SHIFT_1';
  bool _isSubmitting = false;

  final List<String> _roles = [
    'Quality Auditor (AQL Specialist)',
    'Alteration Tailor (Mending Specialist)',
    'Polybag & Barcode Tagging Incharge',
    'Master Carton Weighbridge Packer',
    'Finishing QC Supervisor',
  ];

  final List<String> _skills = ['Master', 'Senior', 'Certified'];
  final List<String> _shifts = ['SHIFT_1', 'SHIFT_2', 'NIGHT_SHIFT'];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      await ref.read(readyGoodsProvider.notifier).addWorker(
            workerName: _nameCtrl.text.trim(),
            phoneNumber: _phoneCtrl.text.trim(),
            role: _selectedRole,
            skillLevel: _selectedSkill,
            shift: _selectedShift,
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF16A34A),
            content: Text(
              '✓ Added ${_nameCtrl.text.trim()} to Quality & Packing roster!',
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
                    'Add Quality & Packing Personnel',
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

              // Full Name
              Text('Full Name *', style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameCtrl,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                decoration: InputDecoration(
                  hintText: 'e.g. Sunil Verma',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                ),
              ),
              const SizedBox(height: 14),

              // Phone Number
              Text('Mobile Number *', style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
              const SizedBox(height: 6),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                decoration: InputDecoration(
                  hintText: 'e.g. 9876543210',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                ),
              ),
              const SizedBox(height: 14),

              // Role
              Text('Division Role *', style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _selectedRole,
                items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r, style: GoogleFonts.publicSans(fontSize: 13)))).toList(),
                onChanged: (v) => setState(() => _selectedRole = v!),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                ),
              ),
              const SizedBox(height: 14),

              // Skill Level & Shift
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Skill Level', style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _selectedSkill,
                          items: _skills.map((s) => DropdownMenuItem(value: s, child: Text(s, style: GoogleFonts.publicSans(fontSize: 13)))).toList(),
                          onChanged: (v) => setState(() => _selectedSkill = v!),
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
                        Text('Assigned Shift', style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _selectedShift,
                          items: _shifts.map((s) => DropdownMenuItem(value: s, child: Text(s, style: GoogleFonts.publicSans(fontSize: 13)))).toList(),
                          onChanged: (v) => setState(() => _selectedShift = v!),
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
                      : Text('Confirm & Save Worker', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
