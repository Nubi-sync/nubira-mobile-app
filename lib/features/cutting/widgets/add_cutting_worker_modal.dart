import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/cutting_provider.dart';

class AddCuttingWorkerModal extends ConsumerStatefulWidget {
  const AddCuttingWorkerModal({super.key});

  @override
  ConsumerState<AddCuttingWorkerModal> createState() => _AddCuttingWorkerModalState();
}

class _AddCuttingWorkerModalState extends ConsumerState<AddCuttingWorkerModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  final List<String> _selectedRoles = ['KNIFE_CUTTER'];
  bool _isSaving = false;
  String? _errorMessage;

  static const List<Map<String, String>> _availableRoles = [
    {'key': 'CUTTING_MASTER', 'label': 'Cutting Master', 'desc': 'CAD marker verification & lay sign-off'},
    {'key': 'SPREADING_OPERATOR', 'label': 'Spreading Operator', 'desc': 'Fabric ply spreading & tension control'},
    {'key': 'KNIFE_CUTTER', 'label': 'Knife Cutter / Auto-Cutter', 'desc': 'Vacuum knife execution & panel bundling'},
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRoles.isEmpty) {
      setState(() {
        _errorMessage = 'Please select at least one primary role for this worker.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final success = await ref.read(cuttingProvider.notifier).registerWorker(
          workerName: _nameController.text.trim(),
          phoneNumber: _phoneController.text.trim(),
          password: _passwordController.text.trim(),
          roles: _selectedRoles,
        );

    if (mounted) {
      setState(() {
        _isSaving = false;
      });
      if (success) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Worker "${_nameController.text.trim()}" registered successfully.'),
            backgroundColor: const Color(0xFF15803D),
          ),
        );
      } else {
        setState(() {
          _errorMessage = 'Failed to register worker. Please check phone number and connection.';
        });
      }
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
        left: 20,
        right: 20,
        top: 14,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Modal Header Container
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF7F0),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0x1A000000)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0x1A000000)),
                      ),
                      child: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF3A3564), size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Register Cutting Worker',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Provision floor credential & workstation role',
                            style: GoogleFonts.publicSans(
                              fontSize: 11,
                              color: const Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0x1A000000)),
                        ),
                        child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF475569)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFECDD3)),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF9F1239), fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // 1. Worker Full Name
              Text(
                'WORKER FULL NAME *',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameController,
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter worker name' : null,
                decoration: _inputDecoration('e.g. Ramesh Patel'),
                style: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF0F172A)),
              ),
              const SizedBox(height: 14),

              // 2. Phone Number
              Text(
                'PHONE NUMBER (10 DIGITS) *',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                validator: (val) {
                  final raw = (val ?? '').replaceAll(RegExp(r'\D'), '');
                  if (raw.length < 10) return 'Enter a valid 10-digit phone number';
                  return null;
                },
                decoration: _inputDecoration('e.g. 9876543210'),
                style: GoogleFonts.jetBrainsMono(fontSize: 13, color: const Color(0xFF0F172A)),
              ),
              const SizedBox(height: 14),

              // 3. Password
              Text(
                'PORTAL LOGIN PASSWORD *',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                validator: (val) => (val == null || val.length < 6) ? 'Password must be at least 6 characters' : null,
                decoration: _inputDecoration('Min 6 characters (e.g. cut12345)'),
                style: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF0F172A)),
              ),
              const SizedBox(height: 14),

              // 4. Primary Floor Roles Multi-Select
              Text(
                'FLOOR SKILL ROLES *',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 8),
              ..._availableRoles.map((role) {
                final isSelected = _selectedRoles.contains(role['key']);
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFFAF7F0) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF3A3564) : const Color(0x1A000000),
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: CheckboxListTile(
                    value: isSelected,
                    activeColor: const Color(0xFF3A3564),
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    title: Text(
                      role['label']!,
                      style: GoogleFonts.publicSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    subtitle: Text(
                      role['desc']!,
                      style: GoogleFonts.publicSans(fontSize: 11, color: const Color(0xFF64748B)),
                    ),
                    onChanged: (checked) {
                      setState(() {
                        if (checked == true) {
                          _selectedRoles.add(role['key']!);
                        } else {
                          _selectedRoles.remove(role['key']!);
                        }
                      });
                    },
                  ),
                );
              }),
              const SizedBox(height: 16),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.publicSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _handleSave,
                    icon: _isSaving
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_rounded, size: 16),
                    label: Text(
                      _isSaving ? 'Registering...' : 'Register Worker',
                      style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3A3564),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.publicSans(fontSize: 12.5, color: const Color(0xFF94A3B8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      filled: true,
      fillColor: Colors.white,
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
    );
  }
}
