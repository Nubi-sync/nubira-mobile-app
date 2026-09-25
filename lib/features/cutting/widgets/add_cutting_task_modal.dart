import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/cutting_models.dart';
import '../providers/cutting_provider.dart';
import 'add_cutting_worker_modal.dart';

class AddCuttingTaskModal extends ConsumerStatefulWidget {
  const AddCuttingTaskModal({super.key});

  @override
  ConsumerState<AddCuttingTaskModal> createState() => _AddCuttingTaskModalState();
}

class _AddCuttingTaskModalState extends ConsumerState<AddCuttingTaskModal> {
  final _formKey = GlobalKey<FormState>();
  
  CuttingWorker? _selectedWorker;
  String _tableNumber = 'Table 01';
  final TextEditingController _piecesCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();
  double _allotedHours = 4.0;
  bool _isSubmitting = false;

  final List<String> _tables = [
    'Table 01',
    'Table 02',
    'Table 03',
    'Table 04',
    'Vacuum Table A',
    'Vacuum Table B',
    'Spreading Table 01',
    'Spreading Table 02',
  ];

  @override
  void initState() {
    super.initState();
    final state = ref.read(cuttingProvider);
    if (state.workers.isNotEmpty) {
      _selectedWorker = state.workers.first;
    }
  }

  @override
  void dispose() {
    _piecesCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitTask() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedWorker == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select or register a floor worker first',
            style: GoogleFonts.publicSans(fontSize: 13, color: Colors.white),
          ),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
      return;
    }

    final state = ref.read(cuttingProvider);
    final buyer = state.selectedBuyer;
    final pieces = int.tryParse(_piecesCtrl.text.trim()) ?? 0;

    final buyerId = buyer?.id ?? '';
    final buyerName = buyer?.buyerName ?? 'Direct Contract';
    final articleNumber = buyer?.linkedArticleNumber ?? (state.orders.isNotEmpty ? state.orders.first.styleRef : 'ART-01');
    final articleName = buyer?.linkedArticleName ?? (state.orders.isNotEmpty ? state.orders.first.styleName : 'Garment Style');

    setState(() => _isSubmitting = true);

    final dueTime = DateTime.now().add(Duration(hours: _allotedHours.toInt())).toIso8601String();

    final success = await ref.read(cuttingProvider.notifier).createTaskAllocation(
          buyerId: buyerId,
          buyerName: buyerName,
          articleNumber: articleNumber,
          articleName: articleName,
          workerId: _selectedWorker!.id,
          workerName: _selectedWorker!.workerName,
          workerPhone: _selectedWorker!.phoneNumber,
          tableNumber: _tableNumber,
          piecesToCut: pieces,
          allotedHours: _allotedHours,
          dueTime: dueTime,
          notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
        );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cutting task allocated to ${_selectedWorker!.workerName}',
              style: GoogleFonts.publicSans(fontSize: 13, color: Colors.white),
            ),
            backgroundColor: const Color(0xFF0F172A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to allocate task row. Please check connection.',
              style: GoogleFonts.publicSans(fontSize: 13, color: Colors.white),
            ),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cuttingProvider);
    final buyer = state.selectedBuyer;
    final articleCode = buyer?.linkedArticleNumber ?? (state.orders.isNotEmpty ? state.orders.first.styleRef : 'ART-01');
    final inHand = state.inHandPieces;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFFAF7F0),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                  ),
                  child: const Icon(Icons.assignment_add, color: Color(0xFF3A3564), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Allocate Cutting Task',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Assign piece quota & floor table to worker',
                        style: GoogleFonts.publicSans(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Color(0xFF64748B), size: 20),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Target Contract Preview Banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F0F7),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.business, size: 18, color: Color(0xFF3A3564)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  buyer?.buyerName ?? 'All Contracts',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Text(
                                      'Article: ',
                                      style: GoogleFonts.publicSans(fontSize: 11, color: const Color(0xFF64748B)),
                                    ),
                                    Text(
                                      articleCode,
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF3A3564),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAF7F0),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'In Hand',
                                  style: GoogleFonts.publicSans(fontSize: 9, color: const Color(0xFF64748B)),
                                ),
                                Text(
                                  '$inHand pcs',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF3A3564),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Worker Selector
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'ASSIGNED OPERATOR / WORKER',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF64748B),
                            letterSpacing: 0.5,
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => const AddCuttingWorkerModal(),
                            );
                          },
                          child: Text(
                            '+ New Worker',
                            style: GoogleFonts.publicSans(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF3A3564),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (state.workers.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'No registered floor workers found. Please register a worker first.',
                                style: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF92400E)),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<CuttingWorker>(
                            value: _selectedWorker ?? (state.workers.isNotEmpty ? state.workers.first : null),
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B)),
                            items: state.workers.map((w) {
                              return DropdownMenuItem<CuttingWorker>(
                                value: w,
                                child: Row(
                                  children: [
                                    Text(
                                      w.workerName,
                                      style: GoogleFonts.publicSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '(${w.phoneNumber})',
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 11,
                                        color: const Color(0xFF64748B),
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFAF7F0),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        w.roles.firstOrNull?.replaceAll('_', ' ') ?? 'Cutter',
                                        style: GoogleFonts.publicSans(
                                          fontSize: 10,
                                          color: const Color(0xFF3A3564),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedWorker = val);
                            },
                          ),
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Table & Quota Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Cutting Table
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TABLE STATION',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF64748B),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _tableNumber,
                                    isExpanded: true,
                                    icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B)),
                                    items: _tables.map((t) {
                                      return DropdownMenuItem<String>(
                                        value: t,
                                        child: Text(
                                          t,
                                          style: GoogleFonts.publicSans(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF0F172A),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) setState(() => _tableNumber = val);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Pieces To Cut
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PIECE QUOTA',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF64748B),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _piecesCtrl,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0F172A),
                                ),
                                decoration: InputDecoration(
                                  hintText: 'e.g. 500',
                                  hintStyle: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF94A3B8)),
                                  suffixText: 'pcs',
                                  suffixStyle: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF64748B)),
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Color(0xFF3A3564), width: 1.5),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) return 'Required';
                                  final numVal = int.tryParse(val.trim());
                                  if (numVal == null || numVal <= 0) return 'Must be > 0';
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Shift Target Duration
                    Text(
                      'SHIFT DEADLINE TARGET',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [2.0, 4.0, 6.0, 8.0].map((hrs) {
                        final isSelected = _allotedHours == hrs;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _allotedHours = hrs),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF3A3564) : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF3A3564) : Colors.black.withValues(alpha: 0.08),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '${hrs.toInt()} Hours',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.white : const Color(0xFF475569),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 16),

                    // Notes / Special Instructions
                    Text(
                      'SPECIAL INSTRUCTIONS / NOTES',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _notesCtrl,
                      maxLines: 2,
                      style: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        hintText: 'e.g. Check grain alignment for checks, 60 ply spread maximum...',
                        hintStyle: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF3A3564), width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isSubmitting ? null : _submitTask,
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.add_task, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Allocate Task Row',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
