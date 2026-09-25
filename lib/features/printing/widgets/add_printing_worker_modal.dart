import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/printing_provider.dart';

class AddPrintingWorkerModal extends ConsumerStatefulWidget {
  const AddPrintingWorkerModal({super.key});

  @override
  ConsumerState<AddPrintingWorkerModal> createState() => _AddPrintingWorkerModalState();
}

class _AddPrintingWorkerModalState extends ConsumerState<AddPrintingWorkerModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController(text: '123456');

  final List<String> _availableRoles = [
    'SCREEN_PRINTER',
    'CAROUSEL_MASTER',
    'DTG_SPECIALIST',
    'CURING_OVEN_OPERATOR',
    'STRIKE_OFF_TESTER',
  ];

  final Set<String> _selectedRoles = {'SCREEN_PRINTER'};
  String _selectedShift = 'MORNING';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRoles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one worker skill role.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await ref.read(printingProvider.notifier).addWorker(
            name: _nameCtrl.text.trim(),
            phone: _phoneCtrl.text.trim(),
            password: _passwordCtrl.text.trim(),
            roles: _selectedRoles.toList(),
            shift: _selectedShift,
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Worker "${_nameCtrl.text.trim()}" successfully registered!'),
            backgroundColor: const Color(0xFF047857),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add worker: $e')),
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
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 20,
        left: 20,
        right: 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Modal Title & Close
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAF7F0),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                        ),
                        child: const Icon(Icons.person_add_alt_1, color: Color(0xFF3A3564), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Register Printing Worker',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Create an operational floor profile and mobile station credentials',
                style: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF64748B)),
              ),
              const Divider(height: 24),

              // Worker Full Name
              Text(
                'FULL NAME *',
                style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF475569)),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameCtrl,
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter worker name' : null,
                style: GoogleFonts.publicSans(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'e.g. Ramesh Kumar',
                  filled: true,
                  fillColor: const Color(0xFFFAF7F0),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),

              const SizedBox(height: 14),

              // 10-Digit Mobile Phone
              Text(
                '10-DIGIT MOBILE NUMBER *',
                style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF475569)),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Phone number required';
                  final digits = val.replaceAll(RegExp(r'\D'), '');
                  if (digits.length < 10) return 'Must be a valid 10-digit number';
                  return null;
                },
                style: GoogleFonts.jetBrainsMono(fontSize: 14),
                decoration: InputDecoration(
                  hintText: '9876543210',
                  prefixText: '+91 ',
                  prefixStyle: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF3A3564)),
                  filled: true,
                  fillColor: const Color(0xFFFAF7F0),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),

              const SizedBox(height: 14),

              // Station Password
              Text(
                'WORKSTATION PASSWORD *',
                style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF475569)),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _passwordCtrl,
                validator: (val) => (val == null || val.length < 6) ? 'Min 6 characters' : null,
                style: GoogleFonts.jetBrainsMono(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Default: 123456',
                  filled: true,
                  fillColor: const Color(0xFFFAF7F0),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),

              const SizedBox(height: 16),

              // Skill Roles Checklist
              Text(
                'PRINTING SKILL ROLES',
                style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF475569)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableRoles.map((role) {
                  final isSelected = _selectedRoles.contains(role);
                  final label = role.replaceAll('_', ' ');
                  return FilterChip(
                    label: Text(
                      label,
                      style: GoogleFonts.publicSans(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? Colors.white : const Color(0xFF3A3564),
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: const Color(0xFF3A3564),
                    backgroundColor: const Color(0xFFFAF7F0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: isSelected ? const Color(0xFF3A3564) : Colors.black.withValues(alpha: 0.1)),
                    ),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedRoles.add(role);
                        } else {
                          _selectedRoles.remove(role);
                        }
                      });
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              // Shift Selection
              Text(
                'ASSIGNED SHIFT',
                style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF475569)),
              ),
              const SizedBox(height: 8),
              Row(
                children: ['MORNING', 'EVENING', 'NIGHT'].map((s) {
                  final isSelected = _selectedShift == s;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: InkWell(
                        onTap: () => setState(() => _selectedShift = s),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF3A3564) : const Color(0xFFFAF7F0),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF3A3564) : Colors.black.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              s,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : const Color(0xFF475569),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

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
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(
                          'Save & Authorize Worker',
                          style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
