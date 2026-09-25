import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/merchandising_models.dart';
import '../providers/merchandising_provider.dart';

class UpdateTnaMilestoneModal extends ConsumerStatefulWidget {
  final TnaMilestone milestone;

  const UpdateTnaMilestoneModal({
    super.key,
    required this.milestone,
  });

  @override
  ConsumerState<UpdateTnaMilestoneModal> createState() => _UpdateTnaMilestoneModalState();
}

class _UpdateTnaMilestoneModalState extends ConsumerState<UpdateTnaMilestoneModal> {
  late String _status;
  late TextEditingController _plannedDateController;
  late TextEditingController _actualDateController;
  late TextEditingController _delayReasonController;
  late TextEditingController _mitigationNotesController;

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _status = widget.milestone.status;
    _plannedDateController = TextEditingController(text: widget.milestone.targetDate);
    _actualDateController = TextEditingController(text: widget.milestone.actualDate ?? '');
    _delayReasonController = TextEditingController(text: widget.milestone.delayReason ?? '');
    _mitigationNotesController = TextEditingController(text: widget.milestone.mitigationNotes ?? '');
  }

  @override
  void dispose() {
    _plannedDateController.dispose();
    _actualDateController.dispose();
    _delayReasonController.dispose();
    _mitigationNotesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    DateTime initial = DateTime.tryParse(controller.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF3A3564),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final formatted = picked.toIso8601String().split('T')[0];
      controller.text = formatted;
    }
  }

  Future<void> _handleSave() async {
    setState(() {
      _errorMessage = null;
    });

    if (_status == 'DELAYED' && _delayReasonController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please provide a delay reason when marking a milestone as DELAYED';
      });
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final actualVal = _actualDateController.text.trim().isNotEmpty
        ? _actualDateController.text.trim()
        : (_status == 'COMPLETED' ? DateTime.now().toIso8601String().split('T')[0] : null);

    final success = await ref.read(merchandisingProvider.notifier).updateTnaMilestone(
          id: widget.milestone.id,
          status: _status,
          plannedDate: _plannedDateController.text.trim(),
          actualDate: actualVal,
          delayReason: _delayReasonController.text.trim().isNotEmpty ? _delayReasonController.text.trim() : null,
          mitigationNotes: _mitigationNotesController.text.trim().isNotEmpty ? _mitigationNotesController.text.trim() : null,
        );

    if (mounted) {
      setState(() {
        _isSaving = false;
      });
      if (success) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gate "${widget.milestone.milestoneName}" updated successfully.'),
            backgroundColor: const Color(0xFF15803D),
          ),
        );
      } else {
        setState(() {
          _errorMessage = 'Failed to update milestone gate. Please check your network.';
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
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: SingleChildScrollView(
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

            // Header Container
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF7F0),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x1A000000)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3A3564).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'FORM 3 • MILESTONE GATE CALIBRATION',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF3A3564),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Update T&A Milestone Gate',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.milestone.poNumber} • ${widget.milestone.milestoneName}',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
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
                      child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF475569)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Error Banner if present
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFECDD3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 16, color: Color(0xFFE11D48)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: GoogleFonts.publicSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF9F1239),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // 1. Critical Path Status Dropdown
            Text(
              'MILESTONE CRITICAL PATH STATUS *',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF334155),
                letterSpacing: 0.5,
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
                  value: _status,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF3A3564)),
                  items: const [
                    DropdownMenuItem(
                      value: 'ON_SCHEDULE',
                      child: Text('ON_SCHEDULE — Within Critical Path SLA'),
                    ),
                    DropdownMenuItem(
                      value: 'DELAYED',
                      child: Text('DELAYED — Milestone Breached Target Date'),
                    ),
                    DropdownMenuItem(
                      value: 'COMPLETED',
                      child: Text('COMPLETED — Milestone Sign-Off Complete'),
                    ),
                    DropdownMenuItem(
                      value: 'ESCALATED',
                      child: Text('ESCALATED — Senior Management Escalation'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _status = val;
                        if (val == 'COMPLETED' && _actualDateController.text.isEmpty) {
                          _actualDateController.text = DateTime.now().toIso8601String().split('T')[0];
                        }
                      });
                    }
                  },
                  style: GoogleFonts.publicSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 2. Dates Row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PLANNED DATE *',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () => _selectDate(context, _plannedDateController),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0x1A000000)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_outlined, size: 15, color: Color(0xFF3A3564)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _plannedDateController.text.isNotEmpty ? _plannedDateController.text : 'Select Date',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                            ],
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
                        'ACTUAL COMPLETED DATE',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () => _selectDate(context, _actualDateController),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0x1A000000)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_outline_rounded, size: 15, color: Color(0xFF15803D)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _actualDateController.text.isNotEmpty ? _actualDateController.text : 'Not Signed Off',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: _actualDateController.text.isNotEmpty
                                        ? const Color(0xFF0F172A)
                                        : const Color(0xFF94A3B8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 3. Delay Reason
            Text(
              'DELAY REASON / ROOT CAUSE (IF BREACHED)',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _delayReasonController,
              decoration: InputDecoration(
                hintText: 'e.g. Dyeing house lab dip shade mismatch re-dip in progress',
                hintStyle: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF94A3B8)),
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
              ),
              style: GoogleFonts.publicSans(fontSize: 12.5, color: const Color(0xFF0F172A)),
            ),
            const SizedBox(height: 14),

            // 4. Mitigation Plan
            Text(
              'RECOVERY MITIGATION ACTION PLAN',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _mitigationNotesController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'e.g. Expedited air express dispatch arranged to recover 3 days',
                hintStyle: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF94A3B8)),
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
              ),
              style: GoogleFonts.publicSans(fontSize: 12.5, color: const Color(0xFF0F172A)),
            ),
            const SizedBox(height: 20),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isSaving ? null : () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.publicSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF475569),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _handleSave,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle_rounded, size: 16),
                  label: Text(
                    _isSaving ? 'Saving...' : 'Save Milestone Gate',
                    style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3A3564),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
