import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/embroidery_provider.dart';

const List<Map<String, String>> kEmbroideryFloorRoles = [
  {'id': 'EMBROIDERY_OPERATOR', 'label': 'Multi-Head Machine Operator'},
  {'id': 'HOOPING_SPECIALIST', 'label': 'Hooping & Framing Specialist'},
  {'id': 'PUNCH_DIGITIZER', 'label': 'Punch Digitizer / Quality Inspector'},
];

class AddEmbroideryWorkerModal extends ConsumerStatefulWidget {
  const AddEmbroideryWorkerModal({super.key});

  @override
  ConsumerState<AddEmbroideryWorkerModal> createState() => _AddEmbroideryWorkerModalState();
}

class _AddEmbroideryWorkerModalState extends ConsumerState<AddEmbroideryWorkerModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _showPassword = false;

  final Set<String> _selectedRoles = {'EMBROIDERY_OPERATOR'};
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _toggleRole(String roleId) {
    setState(() {
      if (_selectedRoles.contains(roleId)) {
        if (_selectedRoles.length == 1) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Worker must have at least one floor role.')),
          );
          return;
        }
        _selectedRoles.remove(roleId);
      } else {
        _selectedRoles.add(roleId);
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRoles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one floor role.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await ref.read(embroideryProvider.notifier).addWorker(
            name: _nameCtrl.text.trim(),
            phone: _phoneCtrl.text.trim(),
            password: _passwordCtrl.text.trim(),
            roles: _selectedRoles.toList(),
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Worker "${_nameCtrl.text.trim()}" registered successfully!'),
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
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        margin: const EdgeInsets.only(top: 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          top: 10,
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
                // Top drag pill handle
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add Embroidery Floor Worker',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Create worker credentials for embroidery studio portal access',
                            style: GoogleFonts.publicSans(
                              fontSize: 11.5,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Worker Full Name Field
                Text(
                  'WORKER FULL NAME *',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameCtrl,
                  style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'e.g. Suresh Kumar',
                    hintStyle: GoogleFonts.publicSans(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.badge_outlined, size: 18, color: Color(0xFF3A3564)),
                    filled: true,
                    fillColor: const Color(0xFFFAF7F0),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF3A3564), width: 1.5),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Full name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Phone Number Field
                Text(
                  'PHONE NUMBER (10 DIGITS) *',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: '9876543210',
                    hintStyle: GoogleFonts.jetBrainsMono(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.phone_outlined, size: 18, color: Color(0xFF3A3564)),
                    prefixText: '+91 ',
                    prefixStyle: GoogleFonts.jetBrainsMono(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFFAF7F0),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF3A3564), width: 1.5),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Phone number is required';
                    }
                    final clean = val.replaceAll(RegExp(r'\D'), '');
                    if (clean.length != 10) {
                      return 'Enter exactly 10 digits';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Password Field
                Text(
                  'LOGIN PASSWORD *',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: !_showPassword,
                  style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'Min. 6 characters',
                    hintStyle: GoogleFonts.publicSans(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.lock_outline, size: 18, color: Color(0xFF3A3564)),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 18,
                        color: const Color(0xFF64748B),
                      ),
                      onPressed: () => setState(() => _showPassword = !_showPassword),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFFAF7F0),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF3A3564), width: 1.5),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Password is required';
                    }
                    if (val.length < 6) {
                      return 'Must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Assigned Floor Roles
                Text(
                  'EMBROIDERY STUDIO ROLES',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Column(
                  children: kEmbroideryFloorRoles.map((role) {
                    final isSelected = _selectedRoles.contains(role['id']);
                    return InkWell(
                      onTap: () => _toggleRole(role['id']!),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFFAF7F0) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF3A3564) : Colors.black.withValues(alpha: 0.1),
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF3A3564) : Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF3A3564) : const Color(0xFF94A3B8),
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                role['label']!,
                                style: GoogleFonts.publicSans(
                                  fontSize: 12.5,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF475569),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: Colors.black.withValues(alpha: 0.1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3A3564),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.check, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Register Worker',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
