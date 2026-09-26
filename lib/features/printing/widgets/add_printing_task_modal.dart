import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/printing_models.dart';
import '../providers/printing_provider.dart';
import 'add_printing_worker_modal.dart';

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
  final _hoursCtrl = TextEditingController(text: '4.0');
  final _notesCtrl = TextEditingController();
  final _newStationCtrl = TextEditingController();

  String? _selectedWorkerId;
  String _selectedStation = 'Print Table 01 (Manual Screen)';
  bool _isAddingStation = false;
  bool _isSubmitting = false;

  final List<String> _stationList = [
    'Print Table 01 (Manual Screen)',
    'Print Table 02 (Manual Screen)',
    'Carousel 01 (M&R 8-Color Auto)',
    'DTG Station 01 (Kornit Avalanche)',
  ];

  @override
  void initState() {
    super.initState();
    final initialPcs = widget.maxSuggestedPieces > 0 ? widget.maxSuggestedPieces : 500;
    _piecesCtrl.text = initialPcs.toString();
  }

  @override
  void dispose() {
    _piecesCtrl.dispose();
    _hoursCtrl.dispose();
    _notesCtrl.dispose();
    _newStationCtrl.dispose();
    super.dispose();
  }

  String _calculateDeadline() {
    final hours = double.tryParse(_hoursCtrl.text.trim()) ?? 4.0;
    final due = DateTime.now().add(Duration(minutes: (hours * 60).round()));
    final timeStr = DateFormat('hh:mm a').format(due);
    final dateStr = DateFormat('MMM d').format(due);
    return '$timeStr, $dateStr';
  }

  void _saveNewStation() {
    final text = _newStationCtrl.text.trim();
    if (text.isNotEmpty && !_stationList.contains(text)) {
      setState(() {
        _stationList.add(text);
        _selectedStation = text;
        _isAddingStation = false;
        _newStationCtrl.clear();
      });
    } else {
      setState(() {
        _isAddingStation = false;
        _newStationCtrl.clear();
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final state = ref.read(printingProvider);

    if (state.workers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please register a printing floor worker first.')),
      );
      return;
    }

    final selectedWorker = state.workers.firstWhere(
      (w) => w.id == _selectedWorkerId,
      orElse: () => state.workers.first,
    );

    final activeBuyerId = state.selectedBuyerId == 'ALL' || state.selectedBuyerId.isEmpty
        ? (state.buyers.isNotEmpty ? state.buyers.first.id : '')
        : state.selectedBuyerId;

    final selectedBuyer = state.buyers.firstWhere(
      (b) => b.id == activeBuyerId,
      orElse: () => state.buyers.isNotEmpty
          ? state.buyers.first
          : const PrintingBuyerContract(
              id: 'byr-hollypop',
              buyerName: 'Hollypop',
              buyerCode: 'HOLL',
              contractedVolume: 6000,
              linkedArticleNumber: 'DEMO-101-03',
            ),
    );

    final pcs = int.tryParse(_piecesCtrl.text.trim()) ?? 0;
    final hours = double.tryParse(_hoursCtrl.text.trim()) ?? 4.0;

    if (pcs <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please specify a valid pieces count of at least 1 piece.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final taskRef = 'PRN-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      final dueTimestamp = DateTime.now().add(Duration(minutes: (hours * 60).round())).toIso8601String();

      final newTask = PrintingTaskAllocation(
        id: 'task-$taskRef',
        taskRef: taskRef,
        buyerId: selectedBuyer.id,
        buyerName: selectedBuyer.buyerName,
        articleNumber: selectedBuyer.linkedArticleNumber ?? 'DEMO-101-03',
        articleName: selectedBuyer.linkedArticleName ?? '${selectedBuyer.linkedArticleNumber ?? "DEMO-101-03"} Garment Print Job',
        workerId: selectedWorker.id,
        workerName: selectedWorker.workerName,
        workerPhone: selectedWorker.phoneNumber,
        tableNumber: _selectedStation,
        piecesToPrint: pcs,
        completedPieces: 0,
        allotedHours: hours,
        dueTime: dueTimestamp,
        notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
        status: 'ASSIGNED',
        createdAt: DateTime.now().toIso8601String(),
      );

      await ref.read(printingProvider.notifier).addTaskAllocation(newTask);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Task #$taskRef allocated to ${selectedWorker.workerName} ($pcs Pcs)!'),
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

    final activeBuyerId = state.selectedBuyerId == 'ALL' || state.selectedBuyerId.isEmpty
        ? (state.buyers.isNotEmpty ? state.buyers.first.id : '')
        : state.selectedBuyerId;

    final selectedBuyer = state.buyers.firstWhere(
      (b) => b.id == activeBuyerId,
      orElse: () => state.buyers.isNotEmpty
          ? state.buyers.first
          : const PrintingBuyerContract(
              id: 'byr-hollypop',
              buyerName: 'Hollypop',
              buyerCode: 'HOLL',
              contractedVolume: 6000,
              linkedArticleNumber: 'DEMO-101-03',
            ),
    );

    if (_selectedWorkerId == null && state.workers.isNotEmpty) {
      _selectedWorkerId = state.workers.first.id;
    }

    final cutPieces = selectedBuyer.completedCutPieces > 0 ? selectedBuyer.completedCutPieces : 2800;
    final inHandPieces = widget.maxSuggestedPieces > 0 ? widget.maxSuggestedPieces : 500;

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
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF7F0),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                      ),
                      child: const Icon(Icons.table_chart_outlined, color: Color(0xFF3A3564), size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Assign Printing Task Row',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15.5,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        Text(
                          'Allocate article print pieces to worker with strict timeline & table assignment',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10.5,
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
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                      ),
                      child: const Icon(Icons.close, size: 16, color: Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Route & In Hand Status Banner (Matching Web)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF7F0),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.view_timeline_outlined, size: 18, color: Color(0xFF3A3564)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Routing: Print First → Embroidery (Step 1: Cutting → Printing)',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${NumberFormat('#,###').format(cutPieces)} cut pcs received from Cutting Floor',
                            style: GoogleFonts.publicSans(
                              fontSize: 11,
                              color: const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // SELECT FLOOR WORKER *
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'SELECT FLOOR WORKER *',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF334155),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        useSafeArea: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const AddPrintingWorkerModal(),
                      );
                    },
                    child: Text(
                      '+ Add New Worker',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF3A3564),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
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
                          '${w.workerName} — +91 ${w.phoneNumber} (${w.role})',
                          style: GoogleFonts.publicSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedWorkerId = val),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // ARTICLE STYLE REFERENCE (Read-Only / Contract Locked)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'ARTICLE STYLE REFERENCE',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF334155),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF7F0),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                    ),
                    child: Text(
                      'CONTRACT LOCKED',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF94A3B8),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF7F0),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                ),
                child: Text(
                  selectedBuyer.linkedArticleNumber ?? 'DEMO-101-03',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Contracted Buyer: ${selectedBuyer.buyerName}',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  color: const Color(0xFF64748B),
                ),
              ),

              const SizedBox(height: 14),

              // PIECES TO PRINT & TIME ALLOTED (HOURS)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pieces to Print
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PIECES TO PRINT *',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF334155),
                            letterSpacing: 0.5,
                          ),
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
                          style: GoogleFonts.jetBrainsMono(fontSize: 13.5, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            suffixText: 'Pcs',
                            suffixStyle: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
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
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'In Hand Queue: $inHandPieces Pcs available (Max limit)',
                          style: GoogleFonts.jetBrainsMono(fontSize: 10, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Time Alloted
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TIME ALLOTED (HOURS) *',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF334155),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _hoursCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => setState(() {}),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Hours required';
                            final h = double.tryParse(val.trim());
                            if (h == null || h <= 0) return 'Invalid hours';
                            return null;
                          },
                          style: GoogleFonts.jetBrainsMono(fontSize: 13.5, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            suffixText: 'Hrs',
                            suffixStyle: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
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
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Due: ${_calculateDeadline()}',
                          style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ASSIGNED PRINT TABLE / MACHINE STATION
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'ASSIGNED PRINT TABLE / MACHINE STATION',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF334155),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!_isAddingStation)
                    InkWell(
                      onTap: () => setState(() => _isAddingStation = true),
                      child: Text(
                        '+ Add Station',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF3A3564),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              if (_isAddingStation)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF7F0),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _newStationCtrl,
                          autofocus: true,
                          style: GoogleFonts.jetBrainsMono(fontSize: 12.5),
                          decoration: InputDecoration(
                            hintText: 'e.g. Print Table ${_stationList.length + 1}',
                            hintStyle: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF94A3B8)),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _saveNewStation,
                        child: Text('Save', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, color: const Color(0xFF3A3564))),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () => setState(() => _isAddingStation = false),
                      ),
                    ],
                  ),
                ),

              // Station Grid (2x2)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _stationList.map((st) {
                  final isSelected = _selectedStation == st;
                  return InkWell(
                    onTap: () => setState(() => _selectedStation = st),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF3A3564) : const Color(0xFFFAF7F0),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF3A3564) : Colors.black.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Text(
                        st,
                        style: GoogleFonts.publicSans(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.white : const Color(0xFF334155),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 14),

              // PRINT INSTRUCTIONS / COLOR NOTES (OPTIONAL)
              Text(
                'PRINT INSTRUCTIONS / COLOR NOTES (OPTIONAL)',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF334155),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 2,
                style: GoogleFonts.publicSans(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'e.g. 2-stroke plastisol white underbase, cure at 160°C',
                  hintStyle: GoogleFonts.publicSans(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
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
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),

              const SizedBox(height: 18),

              // Bottom Actions: Cancel & Allocate Task
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF334155),
                          side: BorderSide(color: Colors.black.withValues(alpha: 0.15)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3A3564),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isSubmitting ? null : _submit,
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.check_circle_outline, size: 16, color: Colors.white),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Allocate Task',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
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
