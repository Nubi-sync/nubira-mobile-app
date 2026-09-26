import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/embroidery_models.dart';
import '../providers/embroidery_provider.dart';
import 'add_embroidery_worker_modal.dart';

class AddEmbroideryTaskModal extends ConsumerStatefulWidget {
  final int maxSuggestedPieces;

  const AddEmbroideryTaskModal({
    super.key,
    this.maxSuggestedPieces = 0,
  });

  @override
  ConsumerState<AddEmbroideryTaskModal> createState() => _AddEmbroideryTaskModalState();
}

class _AddEmbroideryTaskModalState extends ConsumerState<AddEmbroideryTaskModal> {
  final _formKey = GlobalKey<FormState>();
  final _articleCtrl = TextEditingController();
  final _piecesCtrl = TextEditingController();
  final _hoursCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _newMachineCtrl = TextEditingController();

  String? _selectedWorkerId;
  String _selectedMachine = 'Machine 01 (Tajima 20-Head)';
  bool _isAddingCustomMachine = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final state = ref.read(embroideryProvider);
    final selectedBuyer = state.buyers.firstWhere(
      (b) => b.id == state.selectedBuyerId,
      orElse: () => state.buyers.isNotEmpty
          ? state.buyers.first
          : const EmbroideryBuyerContract(id: '', buyerName: 'Direct Buyer'),
    );

    _articleCtrl.text = selectedBuyer.linkedArticleNumber ?? 'DEMO-101-03';

    final routeDetails = ref.read(embroideryProvider.notifier).getRouteDetails(selectedBuyer.id);
    final inHand = routeDetails.inHandPieces;

    int defaultQty = inHand > 0 ? (inHand >= 500 ? 500 : inHand) : 500;
    _piecesCtrl.text = defaultQty.toString();
    _hoursCtrl.text = '4.0';

    if (state.workers.isNotEmpty) {
      _selectedWorkerId = state.workers.first.id;
    }
    if (state.availableMachines.isNotEmpty) {
      _selectedMachine = state.availableMachines.first;
    }
  }

  @override
  void dispose() {
    _articleCtrl.dispose();
    _piecesCtrl.dispose();
    _hoursCtrl.dispose();
    _notesCtrl.dispose();
    _newMachineCtrl.dispose();
    super.dispose();
  }

  String _calculateDeadlinePreview() {
    final hours = double.tryParse(_hoursCtrl.text.trim()) ?? 4.0;
    final due = DateTime.now().add(Duration(minutes: (hours * 60).round()));
    return DateFormat('hh:mm a, MMM dd').format(due);
  }

  void _handleAddCustomMachine() {
    final customName = _newMachineCtrl.text.trim();
    if (customName.isNotEmpty) {
      ref.read(embroideryProvider.notifier).addCustomMachine(customName);
      setState(() {
        _selectedMachine = customName;
        _isAddingCustomMachine = false;
        _newMachineCtrl.clear();
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final state = ref.read(embroideryProvider);
    final selectedBuyer = state.buyers.firstWhere(
      (b) => b.id == state.selectedBuyerId,
      orElse: () => state.buyers.isNotEmpty
          ? state.buyers.first
          : const EmbroideryBuyerContract(id: '', buyerName: 'Direct Buyer'),
    );

    final routeDetails = ref.read(embroideryProvider.notifier).getRouteDetails(selectedBuyer.id);
    final inHand = routeDetails.inHandPieces;
    final pieces = int.tryParse(_piecesCtrl.text.trim()) ?? 0;
    final hours = double.tryParse(_hoursCtrl.text.trim()) ?? 4.0;

    if (inHand <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot allocate: 0 pieces available In Hand for this process route.'),
          backgroundColor: Color(0xFFE11D48),
        ),
      );
      return;
    }

    if (pieces > inHand) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Allocation ($pieces pcs) exceeds In Hand quota ($inHand pcs).'),
          backgroundColor: const Color(0xFFE11D48),
        ),
      );
      return;
    }

    final worker = state.workers.firstWhere(
      (w) => w.id == _selectedWorkerId,
      orElse: () => state.workers.isNotEmpty ? state.workers.first : const EmbroideryWorker(id: '', workerName: 'Operator', phoneNumber: '', createdAt: ''),
    );

    setState(() => _isSubmitting = true);

    try {
      await ref.read(embroideryProvider.notifier).addTaskAllocation(
            buyerId: selectedBuyer.id,
            buyerName: selectedBuyer.buyerName,
            articleNumber: _articleCtrl.text.trim(),
            articleName: selectedBuyer.linkedArticleName ?? '${_articleCtrl.text.trim()} Embroidery Job',
            workerId: worker.id,
            workerName: worker.workerName,
            workerPhone: worker.phoneNumber,
            tableNumber: _selectedMachine,
            piecesToEmbroider: pieces,
            allotedHours: hours,
            notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Task assigned to ${worker.workerName} ($pieces pcs on $_selectedMachine)!'),
            backgroundColor: const Color(0xFF047857),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to assign task: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(embroideryProvider);
    final selectedBuyer = state.buyers.firstWhere(
      (b) => b.id == state.selectedBuyerId,
      orElse: () => state.buyers.isNotEmpty
          ? state.buyers.first
          : const EmbroideryBuyerContract(id: '', buyerName: 'Direct Buyer'),
    );

    final routeDetails = ref.read(embroideryProvider.notifier).getRouteDetails(selectedBuyer.id);
    final inHand = routeDetails.inHandPieces;

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
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
                      child: const Icon(Icons.table_chart_outlined, color: Color(0xFF3A3564), size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Assign Embroidery Task Row',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Allocate piece quota to multi-head machine with shift targets',
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
                const SizedBox(height: 14),

                // Active Routing & In Hand Banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF7F0),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                        ),
                        child: const Icon(Icons.alt_route_rounded, size: 16, color: Color(0xFF3A3564)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${selectedBuyer.buyerName} • ${selectedBuyer.linkedArticleNumber ?? "DEMO-101-03"}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              '${routeDetails.stepText} (${routeDetails.badgeLabel})',
                              style: GoogleFonts.publicSans(
                                fontSize: 10.5,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: inHand > 0 ? const Color(0xFFECFDF5) : const Color(0xFFFFF1F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: inHand > 0 ? const Color(0xFFA7F3D0) : const Color(0xFFFECDD3),
                          ),
                        ),
                        child: Text(
                          '$inHand In Hand',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: inHand > 0 ? const Color(0xFF047857) : const Color(0xFFE11D48),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Worker Selection Dropdown
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ASSIGNED WORKER *',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          useSafeArea: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => const AddEmbroideryWorkerModal(),
                        );
                      },
                      child: Text(
                        '+ Add New Worker',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF3A3564),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF7F0),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedWorkerId,
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF3A3564)),
                      hint: Text(
                        'Select an embroidery worker',
                        style: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF94A3B8)),
                      ),
                      items: state.workers.map((w) {
                        return DropdownMenuItem<String>(
                          value: w.id,
                          child: Row(
                            children: [
                              const Icon(Icons.person_outline, size: 16, color: Color(0xFF3A3564)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${w.workerName} (+91 ${w.phoneNumber}) • ${w.role}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.publicSans(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedWorkerId = val),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Machine / Station Picker
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'MACHINE / FRAME STATION *',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => _isAddingCustomMachine = !_isAddingCustomMachine),
                      child: Text(
                        _isAddingCustomMachine ? 'Select from list' : '+ Add Machine Station',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF3A3564),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (_isAddingCustomMachine) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _newMachineCtrl,
                          style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            hintText: 'e.g. Machine 05 (Tajima 24-Head)',
                            hintStyle: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF94A3B8)),
                            filled: true,
                            fillColor: const Color(0xFFFAF7F0),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
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
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _handleAddCustomMachine,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3A3564),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: Text(
                          'Add',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF7F0),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: state.availableMachines.contains(_selectedMachine) ? _selectedMachine : state.availableMachines.firstOrNull,
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF3A3564)),
                        items: state.availableMachines.map((m) {
                          return DropdownMenuItem<String>(
                            value: m,
                            child: Row(
                              children: [
                                const Icon(Icons.precision_manufacturing_outlined, size: 16, color: Color(0xFF3A3564)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    m,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.publicSans(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedMachine = val);
                        },
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),

                // Article Number Style
                Text(
                  'ARTICLE STYLE REF *',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _articleCtrl,
                  style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: 'e.g. DEMO-101-03',
                    prefixIcon: const Icon(Icons.style_outlined, size: 18, color: Color(0xFF3A3564)),
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
                    if (val == null || val.trim().isEmpty) return 'Article style is required';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Pieces to Embroider & Quick Pills
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'PIECES TO EMBROIDER *',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'Max: $inHand pcs',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF3A3564),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _piecesCtrl,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: '500',
                    prefixIcon: const Icon(Icons.tag, size: 18, color: Color(0xFF3A3564)),
                    suffixText: 'pcs',
                    suffixStyle: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF64748B),
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
                    if (val == null || val.trim().isEmpty) return 'Pieces count is required';
                    final numVal = int.tryParse(val.trim());
                    if (numVal == null || numVal <= 0) return 'Must be at least 1 piece';
                    return null;
                  },
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [100, 250, 500, 1000].map((qty) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          label: Text('$qty pcs', style: GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.bold)),
                          backgroundColor: const Color(0xFFFAF7F0),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          side: BorderSide(color: Colors.black.withValues(alpha: 0.1)),
                          onPressed: () => setState(() => _piecesCtrl.text = qty.toString()),
                        ),
                      );
                    }).toList()
                      ..add(
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            label: Text('Max In Hand ($inHand)', style: GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF3A3564))),
                            backgroundColor: const Color(0xFFFAF7F0),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            side: BorderSide(color: const Color(0xFF3A3564).withValues(alpha: 0.3)),
                            onPressed: () => setState(() => _piecesCtrl.text = inHand.toString()),
                          ),
                        ),
                      ),
                  ),
                ),
                const SizedBox(height: 14),

                // Alloted Hours & Deadline Preview
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ALLOTED SHIFT HOURS *',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'Due: ${_calculateDeadlinePreview()}',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF047857),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _hoursCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: '4.0',
                    prefixIcon: const Icon(Icons.timer_outlined, size: 18, color: Color(0xFF3A3564)),
                    suffixText: 'hours',
                    suffixStyle: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF64748B),
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
                    if (val == null || val.trim().isEmpty) return 'Hours are required';
                    final h = double.tryParse(val.trim());
                    if (h == null || h <= 0) return 'Must be positive hours';
                    return null;
                  },
                ),
                const SizedBox(height: 6),
                Row(
                  children: [2.0, 4.0, 8.0, 12.0].map((h) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        label: Text('${h.toStringAsFixed(1)}h', style: GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.bold)),
                        backgroundColor: const Color(0xFFFAF7F0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        side: BorderSide(color: Colors.black.withValues(alpha: 0.1)),
                        onPressed: () {
                          setState(() {
                            _hoursCtrl.text = h.toStringAsFixed(1);
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // Notes / Instructions
                Text(
                  'SHIFT NOTES & THREAD INSTRUCTIONS',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  style: GoogleFonts.publicSans(fontSize: 12.5),
                  decoration: InputDecoration(
                    hintText: 'e.g. Madeira Polyneon 40wt thread, Tear-Away backing',
                    hintStyle: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: const Color(0xFFFAF7F0),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                ),
                const SizedBox(height: 20),

                // Submit Row
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
                                  const Icon(Icons.add_task, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Assign Task Row',
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
