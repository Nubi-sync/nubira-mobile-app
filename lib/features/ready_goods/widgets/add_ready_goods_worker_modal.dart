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
    return Material(
      color: Colors.transparent,
      child: Container(
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
                    Expanded(
                      child: Text(
                        'Add Quality & Packing Personnel',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Name
                Text('OPERATOR / AUDITOR NAME *', style: GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameCtrl,
                  style: GoogleFonts.publicSans(fontSize: 13),
                  decoration: _inputDecoration('e.g. Rahul Sharma'),
                  validator: (v) => v!.trim().isEmpty ? 'Please enter worker name' : null,
                ),
                const SizedBox(height: 12),

                // Phone
                Text('PHONE NUMBER', style: GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  style: GoogleFonts.publicSans(fontSize: 13),
                  decoration: _inputDecoration('e.g. +91 98765 43210'),
                ),
                const SizedBox(height: 12),

                // Role
                Text('FLOOR ROLE *', style: GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF7F0),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedRole,
                      isExpanded: true,
                      items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r, style: GoogleFonts.publicSans(fontSize: 12.5)))).toList(),
                      onChanged: (v) => setState(() => _selectedRole = v!),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Shift & Skill
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('SHIFT', style: GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAF7F0),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedShift,
                                isExpanded: true,
                                items: _shifts.map((s) => DropdownMenuItem(value: s, child: Text(s, style: GoogleFonts.publicSans(fontSize: 12)))).toList(),
                                onChanged: (v) => setState(() => _selectedShift = v!),
                              ),
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
                          Text('SKILL LEVEL', style: GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAF7F0),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedSkill,
                                isExpanded: true,
                                items: _skills.map((s) => DropdownMenuItem(value: s, child: Text(s, style: GoogleFonts.publicSans(fontSize: 12)))).toList(),
                                onChanged: (v) => setState(() => _selectedSkill = v!),
                              ),
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
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3A3564),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(
                            'Add Personnel to Floor',
                            style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
      filled: true,
      fillColor: const Color(0xFFFAF7F0),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF3A3564), width: 1.5),
      ),
    );
  }
}
