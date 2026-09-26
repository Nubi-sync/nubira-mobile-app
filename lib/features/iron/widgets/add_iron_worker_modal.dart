import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/iron_provider.dart';

class AddIronWorkerModal extends ConsumerStatefulWidget {
  const AddIronWorkerModal({super.key});

  @override
  ConsumerState<AddIronWorkerModal> createState() => _AddIronWorkerModalState();
}

class _AddIronWorkerModalState extends ConsumerState<AddIronWorkerModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String _selectedTable = 'Table 01 (Vacuum Buck)';
  String _selectedShift = 'SHIFT_1';
  bool _isSubmitting = false;

  final List<Map<String, String>> _availableRoles = [
    {'id': 'FINISHING_PRESSER', 'label': 'Finishing Presser (Steam Table)'},
    {'id': 'STEAM_OPERATOR', 'label': 'Steam Generator & Boiler Operator'},
    {'id': 'VACUUM_TABLE_PRESSER', 'label': 'Vacuum Buck Table Presser'},
    {'id': 'PACKING_PRESSER', 'label': 'Pre-Packing Final Touch Presser'},
    {'id': 'HEAD_PRESSER', 'label': 'Head Presser & Quality Verifier'},
    {'id': 'QUALITY_PRESSER', 'label': 'Thermal Shine & Glaze QC Auditor'},
  ];

  final Set<String> _selectedRoles = {'FINISHING_PRESSER'};

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _toggleRole(String roleId) {
    setState(() {
      if (_selectedRoles.contains(roleId)) {
        if (_selectedRoles.length > 1) {
          _selectedRoles.remove(roleId);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Presser must have at least one floor role.')),
          );
        }
      } else {
        _selectedRoles.add(roleId);
      }
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRoles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one floor role.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await ref.read(ironProvider.notifier).addWorker(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        password: _passwordController.text.trim(),
        roles: _selectedRoles.toList(),
        assignedTable: _selectedTable,
        shift: _selectedShift,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1F8A5A),
            content: Text(
              'Iron Presser "${_nameController.text.trim()}" enrolled successfully!',
              style: GoogleFonts.publicSans(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text('Failed to save presser: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFFAF7F0),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(bottom: BorderSide(color: Color(0x1A000000))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x1A000000)),
                    ),
                    child: const Icon(Icons.person_add_outlined, color: Color(0xFF3A3564), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Register Ironing Presser',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF232028),
                          ),
                        ),
                        Text(
                          'Create presser profile and floor access login',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            color: const Color(0xFF7A7488),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF7A7488), size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Form Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Presser Name
                      Text(
                        'PRESSER FULL NAME *',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF7A7488),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameController,
                        style: GoogleFonts.publicSans(fontSize: 14, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          hintText: 'e.g. Rajesh Halder',
                          hintStyle: GoogleFonts.publicSans(color: const Color(0xFFA09BAA), fontSize: 13),
                          filled: true,
                          fillColor: const Color(0xFFFAF7F0).withValues(alpha: 0.5),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0x1A000000)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0x1A000000)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF3A3564), width: 1.5),
                          ),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter presser name' : null,
                      ),
                      const SizedBox(height: 16),

                      // Mobile Phone
                      Text(
                        'MOBILE PHONE NUMBER (LOGIN ID) *',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF7A7488),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          prefixIcon: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            child: Text(
                              '+91',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF7A7488),
                              ),
                            ),
                          ),
                          hintText: '9876543210',
                          hintStyle: GoogleFonts.jetBrainsMono(color: const Color(0xFFA09BAA), fontSize: 13),
                          filled: true,
                          fillColor: const Color(0xFFFAF7F0).withValues(alpha: 0.5),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0x1A000000)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0x1A000000)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF3A3564), width: 1.5),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Phone number required';
                          final clean = v.replaceAll(RegExp(r'\D'), '');
                          if (clean.length < 10) return 'Must be 10 digits';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Password
                      Text(
                        'WORKSTATION PASSWORD *',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF7A7488),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: GoogleFonts.jetBrainsMono(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Min 6 characters (e.g. iron@123)',
                          hintStyle: GoogleFonts.jetBrainsMono(color: const Color(0xFFA09BAA), fontSize: 13),
                          filled: true,
                          fillColor: const Color(0xFFFAF7F0).withValues(alpha: 0.5),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              color: const Color(0xFF7A7488),
                              size: 18,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0x1A000000)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0x1A000000)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF3A3564), width: 1.5),
                          ),
                        ),
                        validator: (v) => (v == null || v.trim().length < 6) ? 'Password must be >= 6 characters' : null,
                      ),
                      const SizedBox(height: 16),

                      // Primary Table & Shift Row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'PRIMARY STEAM TABLE',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF7A7488),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0x1A000000)),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedTable,
                                      isExpanded: true,
                                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF7A7488)),
                                      style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF232028)),
                                      items: const [
                                        DropdownMenuItem(value: 'Table 01 (Vacuum Buck)', child: Text('Table 01 (Vacuum Buck)')),
                                        DropdownMenuItem(value: 'Table 02 (Heated Utility)', child: Text('Table 02 (Heated Utility)')),
                                        DropdownMenuItem(value: 'Table 03 (Collar/Cuff Press)', child: Text('Table 03 (Collar/Cuff Press)')),
                                        DropdownMenuItem(value: 'Table 04 (Form Finisher)', child: Text('Table 04 (Form Finisher)')),
                                        DropdownMenuItem(value: 'Table 05 (Steam Tunnel)', child: Text('Table 05 (Steam Tunnel)')),
                                      ],
                                      onChanged: (v) {
                                        if (v != null) setState(() => _selectedTable = v);
                                      },
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
                                Text(
                                  'FLOOR SHIFT',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF7A7488),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0x1A000000)),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedShift,
                                      isExpanded: true,
                                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF7A7488)),
                                      style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF232028)),
                                      items: const [
                                        DropdownMenuItem(value: 'SHIFT_1', child: Text('Shift 1 (Day)')),
                                        DropdownMenuItem(value: 'SHIFT_2', child: Text('Shift 2 (Night)')),
                                        DropdownMenuItem(value: 'GENERAL', child: Text('General Shift')),
                                      ],
                                      onChanged: (v) {
                                        if (v != null) setState(() => _selectedShift = v);
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Floor Roles Checkbox List
                      Text(
                        'FLOOR ROLES & CERTIFICATIONS *',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF7A7488),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._availableRoles.map((role) {
                        final isChecked = _selectedRoles.contains(role['id']);
                        return InkWell(
                          onTap: () => _toggleRole(role['id']!),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: isChecked ? const Color(0xFFE5EDF9) : const Color(0xFFFAF7F0).withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isChecked ? const Color(0xFF2E5AA8).withValues(alpha: 0.3) : const Color(0x1A000000),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isChecked ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                                  size: 18,
                                  color: isChecked ? const Color(0xFF2E5AA8) : const Color(0xFF7A7488),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    role['label']!,
                                    style: GoogleFonts.publicSans(
                                      fontSize: 12.5,
                                      fontWeight: isChecked ? FontWeight.bold : FontWeight.w500,
                                      color: isChecked ? const Color(0xFF2E5AA8) : const Color(0xFF232028),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),

            // Footer Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
                border: Border(top: BorderSide(color: Color(0x1A000000))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.publicSans(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF7A7488),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3A3564),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isSubmitting ? null : _handleSubmit,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle_outline, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'Enroll Presser',
                                style: GoogleFonts.publicSans(fontWeight: FontWeight.bold),
                              ),
                            ],
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
}
