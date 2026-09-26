import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/washing_provider.dart';

class AddWashingWorkerModal extends ConsumerStatefulWidget {
  const AddWashingWorkerModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddWashingWorkerModal(),
    );
  }

  @override
  ConsumerState<AddWashingWorkerModal> createState() => _AddWashingWorkerModalState();
}

class _AddWashingWorkerModalState extends ConsumerState<AddWashingWorkerModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;

  String _assignedMachine = 'Washer 01 (Tumbler 600kg)';
  String _shift = 'Morning (08:00 AM - 04:00 PM)';
  final List<String> _selectedRoles = ['WASH_MASTER'];
  bool _isSaving = false;

  final List<Map<String, String>> _availableRoles = const [
    {'id': 'WASH_MASTER', 'label': 'Washing Master / Head Chemist'},
    {'id': 'HYDRO_EXTRACTOR', 'label': 'Hydro Extraction Operator'},
    {'id': 'TUMBLER_OPERATOR', 'label': 'Industrial Tumbler Dryer Operator'},
    {'id': 'CHEMICAL_MIXER', 'label': 'Chemical & Enzyme Dosing Specialist'},
    {'id': 'SHRINKAGE_INSPECTOR', 'label': 'Shrinkage & Shade QC Inspector'},
    {'id': 'FINISHING_LOADER', 'label': 'Wet Goods Conveyor & Loader'},
  ];

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

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedRoles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one floor role.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final primaryRoleLabel = _selectedRoles.map((r) {
        final match = _availableRoles.firstWhere((ar) => ar['id'] == r, orElse: () => {'label': r});
        return match['label']!;
      }).join(', ');

      await ref.read(washingProvider.notifier).addWorker(
            name: _nameCtrl.text.trim(),
            phone: _phoneCtrl.text.trim(),
            machineNumber: _assignedMachine,
            specialization: primaryRoleLabel,
            shift: _shift,
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Washing Operator "${_nameCtrl.text.trim()}" registered successfully!'),
            backgroundColor: const Color(0xFF047857),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add worker: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header matching Web exactly
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
            decoration: const BoxDecoration(
              color: Color(0xFFFAF7F0),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(bottom: BorderSide(color: Color(0x1A000000))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                          ),
                          child: const Icon(Icons.person_add_alt_1_outlined, color: Color(0xFF3A3564), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Register Washing Operator',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              'Create operator profile and floor access login',
                              style: GoogleFonts.publicSans(
                                fontSize: 11,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0x1A000000)),
                        ),
                        child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Scrollable Form Body
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Operator Full Name
                    _buildLabel('OPERATOR FULL NAME', isRequired: true),
                    const SizedBox(height: 6),
                    _buildTextInput(
                      controller: _nameCtrl,
                      hintText: 'e.g. Ramesh Mondal',
                      validator: (v) => v == null || v.trim().isEmpty ? 'Enter operator full name' : null,
                    ),

                    const SizedBox(height: 14),

                    // 2. Mobile Phone Number
                    _buildLabel('MOBILE PHONE NUMBER (LOGIN ID)', isRequired: true),
                    const SizedBox(height: 6),
                    Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            alignment: Alignment.center,
                            child: Text(
                              '+91',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                          Expanded(
                            child: TextFormField(
                              controller: _phoneCtrl,
                              keyboardType: TextInputType.phone,
                              maxLength: 10,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
                              ),
                              decoration: InputDecoration(
                                hintText: '9876543210',
                                hintStyle: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF94A3B8)),
                                border: InputBorder.none,
                                counterText: '',
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              validator: (v) => v == null || v.trim().length != 10 ? 'Enter valid 10-digit number' : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Used as operator phone login credential',
                      style: GoogleFonts.publicSans(fontSize: 10.5, color: const Color(0xFF94A3B8)),
                    ),

                    const SizedBox(height: 14),

                    // 3. Workstation Password
                    _buildLabel('WORKSTATION PASSWORD', isRequired: true),
                    const SizedBox(height: 6),
                    Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: TextFormField(
                        controller: _passwordCtrl,
                        obscureText: _obscurePassword,
                        style: GoogleFonts.publicSans(fontSize: 12.5, color: const Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          hintText: 'Min 6 characters (e.g. wash@123)',
                          hintStyle: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF94A3B8)),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              size: 18,
                              color: const Color(0xFF94A3B8),
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: (v) => v == null || v.trim().length < 6 ? 'Password must be at least 6 characters' : null,
                      ),
                    ),

                    const SizedBox(height: 14),

                    // 4. Primary Machine & Floor Shift (2-Column Grid)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('PRIMARY MACHINE'),
                              const SizedBox(height: 6),
                              _buildDropdown(
                                value: _assignedMachine,
                                items: const [
                                  'Washer 01 (Tumbler 600kg)',
                                  'Washer 02 (Hydro 400kg)',
                                  'Washer 03 (Front Load 300kg)',
                                  'Dryer 01 (Steam Tumbler)',
                                  'Dryer 02 (Electric Tumbler)',
                                ],
                                onChanged: (v) => setState(() => _assignedMachine = v!),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('FLOOR SHIFT'),
                              const SizedBox(height: 6),
                              _buildDropdown(
                                value: _shift,
                                items: const [
                                  'Morning (08:00 AM - 04:00 PM)',
                                  'Evening (04:00 PM - 12:00 AM)',
                                  'Night (12:00 AM - 08:00 AM)',
                                ],
                                onChanged: (v) => setState(() => _shift = v!),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // 5. Floor Roles & Skill Competencies
                    _buildLabel('FLOOR ROLES & SKILL COMPETENCIES', isRequired: true),
                    const SizedBox(height: 8),
                    ..._availableRoles.map((role) {
                      final isSelected = _selectedRoles.contains(role['id']);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFFAF7F0) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF3A3564) : Colors.black.withValues(alpha: 0.1),
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: InkWell(
                          onTap: () => _toggleRole(role['id']!),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    role['label']!,
                                    style: GoogleFonts.publicSans(
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected ? const Color(0xFF3A3564) : const Color(0xFF475569),
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFF3A3564) : Colors.white,
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(
                                      color: isSelected ? const Color(0xFF3A3564) : const Color(0xFFCBD5E1),
                                    ),
                                  ),
                                  child: isSelected
                                      ? const Icon(Icons.check, size: 13, color: Colors.white)
                                      : null,
                                ),
                              ],
                            ),
                          ),
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFFFAF7F0),
              border: Border(top: BorderSide(color: Color(0x1A000000))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF475569),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3A3564),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isSaving ? null : _handleSave,
                  icon: _isSaving
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle_outline_rounded, size: 16),
                  label: Text('Register Operator', style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text, {bool isRequired = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          style: GoogleFonts.publicSans(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF475569),
            letterSpacing: 0.4,
          ),
        ),
        if (isRequired) ...[
          const SizedBox(width: 3),
          const Text('*', style: TextStyle(color: Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ],
    );
  }

  Widget _buildTextInput({
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.w500, color: const Color(0xFF0F172A)),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF94A3B8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: InputBorder.none,
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: Color(0xFF64748B)),
          items: items.map((e) => DropdownMenuItem(
            value: e,
            child: Text(
              e,
              style: GoogleFonts.publicSans(fontSize: 11.5, fontWeight: FontWeight.w500, color: const Color(0xFF0F172A)),
              overflow: TextOverflow.ellipsis,
            ),
          )).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
