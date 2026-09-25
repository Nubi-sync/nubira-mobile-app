import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/printing_models.dart';
import '../providers/printing_provider.dart';

class AddPrintingTaskModal extends ConsumerStatefulWidget {
  final int maxSuggestedPieces;
  const AddPrintingTaskModal({
    super.key,
    this.maxSuggestedPieces = 0,
  });

  @override
  ConsumerState<AddPrintingTaskModal> createState() => _AddPrintingTaskModalState();
}

class _AddPrintingTaskModalState extends ConsumerState<AddPrintingTaskModal> {
  final _formKey = GlobalKey<FormState>();
  final _piecesCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String? _selectedWorkerId;
  String? _selectedTable = 'Print Table 01 (Screen 4-Color)';
  double _allotedHours = 6.0;
  bool _isSubmitting = false;

  final List<String> _printingStations = [
    'Print Table 01 (Screen 4-Color)',
    'Print Table 02 (Screen 6-Color)',
    'Automatic Carousel A (6-Head)',
    'Automatic Carousel B (8-Head)',
    'DTG Digital Machine 01',
    'Sublimation Heat Press 01',
    'Industrial Curing Conveyor 01',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.maxSuggestedPieces > 0) {
      _piecesCtrl.text = widget.maxSuggestedPieces.toString();
    } else {
      _piecesCtrl.text = '250';
    }
  }

  @override
  void dispose() {
    _piecesCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final state = ref.read(printingProvider);

    if (state.workers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please register a printing worker first.')),
      );
      return;
    }

    final selectedWorker = state.workers.firstWhere(
      (w) => w.id == _selectedWorkerId,
      orElse: () => state.workers.first,
    );

    final selectedBuyer = state.buyers.firstWhere(
      (b) => b.id == state.selectedBuyerId,
      orElse: () => state.buyers.isNotEmpty
          ? state.buyers.first
          : const PrintingBuyerContract(
              id: 'byr-direct',
              buyerName: 'Direct Buyer',
              buyerCode: 'DIR',
              contractedVolume: 1000,
              linkedArticleNumber: 'ART-STD',
            ),
    );

    final pcs = int.tryParse(_piecesCtrl.text.trim()) ?? 0;
    if (pcs <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid print piece count.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final taskRef = 'PRN-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      final dueTime = DateTime.now().add(Duration(hours: _allotedHours.toInt())).toIso8601String();

      final newTask = PrintingTaskAllocation(
        id: 'task-$taskRef',
        taskRef: taskRef,
        buyerId: selectedBuyer.id,
        buyerName: selectedBuyer.buyerName,
        articleNumber: selectedBuyer.linkedArticleNumber ?? 'ART-PRINT',
        articleName: selectedBuyer.linkedArticleName,
        workerId: selectedWorker.id,
        workerName: selectedWorker.workerName,
        workerPhone: selectedWorker.phoneNumber,
        tableNumber: _selectedTable ?? 'Print Table 01',
        piecesToPrint: pcs,
        completedPieces: 0,
        allotedHours: _allotedHours,
        dueTime: dueTime,
        notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
        status: 'ASSIGNED',
        createdAt: DateTime.now().toIso8601String(),
      );

      await ref.read(printingProvider.notifier).addTaskAllocation(newTask);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Task #$taskRef successfully allocated to ${selectedWorker.workerName}!'),
            backgroundColor: const Color(0xFF047857),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to allocate task: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(printingProvider);

    final selectedBuyer = state.buyers.firstWhere(
      (b) => b.id == state.selectedBuyerId,
      orElse: () => state.buyers.isNotEmpty
          ? state.buyers.first
          : const PrintingBuyerContract(
              id: 'byr-direct',
              buyerName: 'Direct Buyer',
              buyerCode: 'DIR',
              contractedVolume: 1000,
              linkedArticleNumber: 'ART-STD',
            ),
    );

    if (_selectedWorkerId == null && state.workers.isNotEmpty) {
      _selectedWorkerId = state.workers.first.id;
    }

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
                        child: const Icon(Icons.add_task_rounded, color: Color(0xFF3A3564), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Allocate Printing Task',
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
                'Assign print quotas, print tables/carousels, and target shift deadlines',
                style: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF64748B)),
              ),
              const Divider(height: 24),

              // Buyer & Article Pill (Readonly / Scoped)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF7F0),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.business_outlined, size: 18, color: Color(0xFF3A3564)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selectedBuyer.buyerName,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Article: ${selectedBuyer.linkedArticleNumber ?? "ART-STD"}',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Select Worker
              Text(
                'ASSIGN PRINTING OPERATOR *',
                style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF475569)),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF7F0),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedWorkerId,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B)),
                    items: state.workers.map((w) {
                      return DropdownMenuItem<String>(
                        value: w.id,
                        child: Text(
                          '${w.workerName} (${w.role})',
                          style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedWorkerId = val),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Station / Machine Selection
              Text(
                'PRINT TABLE / STATION *',
                style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF475569)),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF7F0),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedTable,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B)),
                    items: _printingStations.map((st) {
                      return DropdownMenuItem<String>(
                        value: st,
                        child: Text(
                          st,
                          style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedTable = val),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Pieces to Print Quota
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PRINT QUOTA (PCS) *',
                          style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF475569)),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _piecesCtrl,
                          keyboardType: TextInputType.number,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Pieces required';
                            final n = int.tryParse(val.trim());
                            if (n == null || n <= 0) return 'Invalid count';
                            return null;
                          },
                          style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            hintText: 'e.g. 250',
                            filled: true,
                            fillColor: const Color(0xFFFAF7F0),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                          'SHIFT ALLOTED *',
                          style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF475569)),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAF7F0),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<double>(
                              value: _allotedHours,
                              isExpanded: true,
                              items: const [
                                DropdownMenuItem(value: 4.0, child: Text('4 Hours Shift')),
                                DropdownMenuItem(value: 6.0, child: Text('6 Hours Shift')),
                                DropdownMenuItem(value: 8.0, child: Text('8 Hours Full')),
                                DropdownMenuItem(value: 12.0, child: Text('12 Hours Shift')),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _allotedHours = val);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Notes / Technical Specs
              Text(
                'PRINTING & CURING SPECS (OPTIONAL)',
                style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF475569)),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 2,
                style: GoogleFonts.publicSans(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'e.g. Plastisol 4-color mesh 120, Oven 165°C dwell 2.5 min',
                  filled: true,
                  fillColor: const Color(0xFFFAF7F0),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.all(12),
                ),
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
                          'Allocate Task & Dispatch to Table',
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
