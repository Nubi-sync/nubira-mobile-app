import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/iron_models.dart';
import '../providers/iron_provider.dart';
import 'add_iron_worker_modal.dart';

class AddIronTaskModal extends ConsumerStatefulWidget {
  final IronBuyerContract? selectedBuyer;
  final int inHandPieces;

  const AddIronTaskModal({
    super.key,
    this.selectedBuyer,
    this.inHandPieces = 5000,
  });

  @override
  ConsumerState<AddIronTaskModal> createState() => _AddIronTaskModalState();
}

class _AddIronTaskModalState extends ConsumerState<AddIronTaskModal> {
  final _formKey = GlobalKey<FormState>();
  final _articleController = TextEditingController();
  final _piecesController = TextEditingController();

  String? _selectedWorkerId;
  String _selectedTable = 'Table 01 (Vacuum Buck)';
  String _allotedHours = '4.0';
  String _shift = 'SHIFT_1';
  int _ironTempC = 150;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final article = widget.selectedBuyer?.linkedArticleNumber ?? 'IRON-201-08';
    _articleController.text = article;
    final defaultQty = widget.inHandPieces > 0 ? widget.inHandPieces.clamp(1, 1000).toString() : '500';
    _piecesController.text = defaultQty;

    final workers = ref.read(ironProvider).workers;
    if (workers.isNotEmpty) {
      _selectedWorkerId = workers.first.id;
    }
  }

  @override
  void dispose() {
    _articleController.dispose();
    _piecesController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final ironState = ref.read(ironProvider);
    final workers = ironState.workers;

    if (workers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enroll at least one presser first.')),
      );
      return;
    }

    final selectedWorker = workers.firstWhere(
      (w) => w.id == _selectedWorkerId,
      orElse: () => workers.first,
    );

    final pieces = int.tryParse(_piecesController.text.trim()) ?? 0;
    if (pieces <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid piece quantity greater than 0.')),
      );
      return;
    }

    final hours = double.tryParse(_allotedHours) ?? 4.0;
    final buyer = widget.selectedBuyer ??
        (ironState.buyers.isNotEmpty
            ? ironState.buyers.first
            : const IronBuyerContract(
                id: 'byr-ollywood',
                buyerName: 'ollywood',
                buyerCode: 'OLLY',
                contractedVolume: 5000,
                pricePerPiece: 2.20,
                totalContractValue: 11000,
                linkedArticleNumber: 'DEMO-102',
                linkedArticleName: 'Heavyweight Loopback Hoodie',
              ));

    setState(() => _isSubmitting = true);

    try {
      await ref.read(ironProvider.notifier).addTaskAllocation(
        buyer: buyer,
        worker: selectedWorker,
        pieces: pieces,
        articleNumber: _articleController.text.trim(),
        table: _selectedTable,
        allotedHours: hours,
        ironTempC: _ironTempC,
        shift: _shift,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1F8A5A),
            content: Text(
              'Task allocated! $pieces pcs assigned to ${selectedWorker.workerName}',
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
            content: Text('Failed to assign task: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ironState = ref.watch(ironProvider);
    final workers = ironState.workers;

    if (_selectedWorkerId == null && workers.isNotEmpty) {
      _selectedWorkerId = workers.first.id;
    }

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 720),
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
                    child: const Icon(Icons.table_chart_outlined, color: Color(0xFF3A3564), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Assign Steam Ironing Floor Task',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF232028),
                          ),
                        ),
                        Text(
                          'Allocate garment pressing quotas & set table assignment',
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
                      // Active Buyer Contract Banner
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAF7F0),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0x1A000000)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ACTIVE BUYER CONTRACT',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF7A7488),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.selectedBuyer?.buyerName ?? 'Direct Buyer Floor Queue',
                                  style: GoogleFonts.publicSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF232028),
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'IN HAND PIECES',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF7A7488),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${widget.inHandPieces} pcs',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF3A3564),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Designated Presser
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'DESIGNATED IRON PRESSER *',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF7A7488),
                            ),
                          ),
                          if (workers.isNotEmpty)
                            InkWell(
                              onTap: () {
                                Navigator.pop(context);
                                showDialog(
                                  context: context,
                                  builder: (_) => const AddIronWorkerModal(),
                                );
                              },
                              child: Text(
                                '+ Add New Presser',
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
                      if (workers.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309), size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'No iron pressers registered. Enroll a presser first.',
                                  style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFFB45309)),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  showDialog(
                                    context: context,
                                    builder: (_) => const AddIronWorkerModal(),
                                  );
                                },
                                child: const Text('Enroll Now'),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0x1A000000)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedWorkerId,
                              isExpanded: true,
                              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF7A7488)),
                              style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF232028)),
                              items: workers.map((w) {
                                return DropdownMenuItem(
                                  value: w.id,
                                  child: Text('${w.workerName} (+91 ${w.phoneNumber}) • ${w.assignedTable}'),
                                );
                              }).toList(),
                              onChanged: (v) {
                                if (v != null) setState(() => _selectedWorkerId = v);
                              },
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Article & Temperature Row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ARTICLE STYLE NO. *',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF7A7488),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _articleController,
                                  style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold),
                                  decoration: InputDecoration(
                                    hintText: 'e.g. IRON-201-08',
                                    filled: true,
                                    fillColor: const Color(0xFFFAF7F0).withValues(alpha: 0.5),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Article required' : null,
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
                                  'SOLEPLATE TEMP (°C)',
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
                                    child: DropdownButton<int>(
                                      value: _ironTempC,
                                      isExpanded: true,
                                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF7A7488)),
                                      style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF232028)),
                                      items: const [
                                        DropdownMenuItem(value: 130, child: Text('130°C (Blends)')),
                                        DropdownMenuItem(value: 150, child: Text('150°C (Cotton/Terry)')),
                                        DropdownMenuItem(value: 165, child: Text('165°C (Denim)')),
                                        DropdownMenuItem(value: 180, child: Text('180°C (Linen)')),
                                      ],
                                      onChanged: (v) {
                                        if (v != null) setState(() => _ironTempC = v);
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Pieces to Press & Alloted Hours Row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'PIECES TO PRESS *',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF7A7488),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _piecesController,
                                  keyboardType: TextInputType.number,
                                  style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.bold),
                                  decoration: InputDecoration(
                                    hintText: '500',
                                    filled: true,
                                    fillColor: const Color(0xFFFAF7F0).withValues(alpha: 0.5),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                                    if (v == null || v.trim().isEmpty) return 'Pieces required';
                                    final p = int.tryParse(v);
                                    if (p == null || p <= 0) return 'Must be > 0';
                                    return null;
                                  },
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
                                  'ALLOTED SHIFT HOURS *',
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
                                      value: _allotedHours,
                                      isExpanded: true,
                                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF7A7488)),
                                      style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF232028)),
                                      items: const [
                                        DropdownMenuItem(value: '2.0', child: Text('2.0 Hours')),
                                        DropdownMenuItem(value: '4.0', child: Text('4.0 Hours (Half Shift)')),
                                        DropdownMenuItem(value: '8.0', child: Text('8.0 Hours (Full Shift)')),
                                        DropdownMenuItem(value: '12.0', child: Text('12.0 Hours (Rush)')),
                                      ],
                                      onChanged: (v) {
                                        if (v != null) setState(() => _allotedHours = v);
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Vacuum Steam Table & Shift Row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'VACUUM STEAM TABLE',
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
                                      value: _shift,
                                      isExpanded: true,
                                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF7A7488)),
                                      style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF232028)),
                                      items: const [
                                        DropdownMenuItem(value: 'SHIFT_1', child: Text('Shift 1 (Day)')),
                                        DropdownMenuItem(value: 'SHIFT_2', child: Text('Shift 2 (Night)')),
                                        DropdownMenuItem(value: 'GENERAL', child: Text('General Shift')),
                                      ],
                                      onChanged: (v) {
                                        if (v != null) setState(() => _shift = v);
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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
                    onPressed: (_isSubmitting || workers.isEmpty) ? null : _handleSubmit,
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
                                'Assign Floor Task',
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
