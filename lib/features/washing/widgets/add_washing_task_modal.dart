import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/washing_provider.dart';
import 'add_washing_worker_modal.dart';

class AddWashingTaskModal extends ConsumerStatefulWidget {
  const AddWashingTaskModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddWashingTaskModal(),
    );
  }

  @override
  ConsumerState<AddWashingTaskModal> createState() => _AddWashingTaskModalState();
}

class _AddWashingTaskModalState extends ConsumerState<AddWashingTaskModal> {
  final _formKey = GlobalKey<FormState>();
  final _piecesCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String? _selectedWorkerId;
  String? _selectedBuyerId;
  String _selectedMachine = 'Washer 01 (Industrial Tumbler)';
  String _selectedRecipe = 'Bio-Enzyme Wash 55°C';
  String _selectedShift = 'Shift A (08:00 - 16:30)';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final state = ref.read(washingProvider);
    if (state.buyers.isNotEmpty) {
      _selectedBuyerId = state.selectedBuyerId.isNotEmpty && state.selectedBuyerId != 'ALL'
          ? state.selectedBuyerId
          : state.buyers.first.id;
    }
    if (state.workers.isNotEmpty) {
      _selectedWorkerId = state.workers.first.id;
    }
  }

  @override
  void dispose() {
    _piecesCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    final state = ref.read(washingProvider);

    final buyer = state.buyers.firstWhere(
      (b) => b.id == _selectedBuyerId,
      orElse: () => state.buyers.first,
    );

    final worker = state.workers.firstWhere(
      (w) => w.id == _selectedWorkerId,
      orElse: () => state.workers.first,
    );

    final pcs = int.tryParse(_piecesCtrl.text.trim()) ?? 0;
    if (pcs <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid piece quantity > 0.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref.read(washingProvider.notifier).addTaskAllocation(
            buyer: buyer,
            worker: worker,
            pieces: pcs,
            machine: _selectedMachine,
            washRecipe: _selectedRecipe,
            shift: _selectedShift,
            notes: _notesCtrl.text.trim(),
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$pcs pcs of ${buyer.linkedArticleNumber} assigned to ${worker.workerName}!'),
            backgroundColor: const Color(0xFF047857),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to allocate task: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(washingProvider);

    if (state.workers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFFFAF7F0),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
              ),
              child: const Icon(Icons.people_outline_rounded, color: Color(0xFF3A3564), size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              'No Washers Registered',
              style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
            ),
            const SizedBox(height: 4),
            Text(
              'Please register at least one washing floor operator before allocating task batches.',
              textAlign: TextAlign.center,
              style: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3A3564),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: () {
                Navigator.pop(context);
                AddWashingWorkerModal.show(context);
              },
              child: const Text('+ Add Worker First'),
            ),
          ],
        ),
      );
    }

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
          // Header
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0x1A000000)),
                          ),
                          child: Text(
                            'TASK ALLOCATION',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF3A3564),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Allocate Washing Batch',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0x1A000000)),
                        ),
                        child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Body Form
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Buyer / Contract
                    _buildLabel('BUYER CONTRACT', isRequired: true),
                    const SizedBox(height: 6),
                    _buildDropdown(
                      value: _selectedBuyerId ?? state.buyers.first.id,
                      items: state.buyers.map((b) => b.id).toList(),
                      itemLabels: {for (var b in state.buyers) b.id: '${b.buyerName} (${b.linkedArticleNumber})'},
                      onChanged: (v) => setState(() => _selectedBuyerId = v),
                    ),
                    const SizedBox(height: 14),

                    // Washer Operator
                    _buildLabel('ASSIGN WASHER OPERATOR', isRequired: true),
                    const SizedBox(height: 6),
                    _buildDropdown(
                      value: _selectedWorkerId ?? state.workers.first.id,
                      items: state.workers.map((w) => w.id).toList(),
                      itemLabels: {for (var w in state.workers) w.id: '${w.workerName} (${w.machineNumber})'},
                      onChanged: (v) => setState(() => _selectedWorkerId = v),
                    ),
                    const SizedBox(height: 14),

                    // Target Pieces
                    _buildLabel('TARGET PIECES TO WASH', isRequired: true),
                    const SizedBox(height: 6),
                    _buildTextInput(
                      controller: _piecesCtrl,
                      hintText: 'e.g. 500',
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Enter piece quantity';
                        final n = int.tryParse(v.trim());
                        if (n == null || n <= 0) return 'Must be a number > 0';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Machine / Tumbler
                    _buildLabel('MACHINE / TUMBLER ASSIGNMENT'),
                    const SizedBox(height: 6),
                    _buildDropdown(
                      value: _selectedMachine,
                      items: state.availableMachines,
                      onChanged: (v) => setState(() => _selectedMachine = v!),
                    ),
                    const SizedBox(height: 14),

                    // Wash Recipe
                    _buildLabel('WASH RECIPE SPECIFICATION'),
                    const SizedBox(height: 6),
                    _buildDropdown(
                      value: _selectedRecipe,
                      items: state.availableRecipes,
                      onChanged: (v) => setState(() => _selectedRecipe = v!),
                    ),
                    const SizedBox(height: 14),

                    // Target Shift
                    _buildLabel('TARGET SHIFT'),
                    const SizedBox(height: 6),
                    _buildDropdown(
                      value: _selectedShift,
                      items: const [
                        'Shift A (08:00 - 16:30)',
                        'Shift B (16:30 - 01:00)',
                        'Shift C (01:00 - 08:00)',
                      ],
                      onChanged: (v) => setState(() => _selectedShift = v!),
                    ),
                    const SizedBox(height: 14),

                    // Notes
                    _buildLabel('BATCH INSTRUCTIONS / NOTES'),
                    const SizedBox(height: 6),
                    _buildTextInput(
                      controller: _notesCtrl,
                      hintText: 'e.g. 1:5.0 liquor ratio with neutral cellulase enzyme...',
                    ),
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
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3A3564),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isSubmitting ? null : _handleSave,
                  child: _isSubmitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('Allocate Batch', style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold)),
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
    Map<String, String>? itemLabels,
    required void Function(String?) onChanged,
  }) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
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
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(itemLabels != null ? (itemLabels[e] ?? e) : e))).toList(),
          onChanged: onChanged,
          style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.w500, color: const Color(0xFF0F172A)),
        ),
      ),
    );
  }
}
