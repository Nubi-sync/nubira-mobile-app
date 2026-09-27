import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/ready_goods_models.dart';
import '../providers/ready_goods_provider.dart';

class InspectLotModal extends ConsumerStatefulWidget {
  final FinishingInspectionTask task;

  const InspectLotModal({
    super.key,
    required this.task,
  });

  @override
  ConsumerState<InspectLotModal> createState() => _InspectLotModalState();
}

class _InspectLotModalState extends ConsumerState<InspectLotModal> {
  static const Color kCanvasColor = Color(0xFFFAF7F0);
  static const Color kCardBg = Color(0xFFFFFFFF);
  static const Color kPrimaryBrand = Color(0xFF3A3564);
  static const Color kBorderColor = Color(0xFFE7E1D6);
  static const Color kMutedText = Color(0xFF7A7488);
  static const Color kInkText = Color(0xFF232028);

  late InspectionChecklist _checklist;
  String? _selectedWorkerId;
  bool _isDefectMode = false;
  String _defectReason = 'OPEN_SEAM';
  String _defectStation = 'Mending Station 01';
  final TextEditingController _defectNotesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checklist = widget.task.checklist;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(readyGoodsProvider);
      final workers = state.workers;
      if (widget.task.checkedByWorkerId != null &&
          workers.any((w) => w.id == widget.task.checkedByWorkerId)) {
        setState(() {
          _selectedWorkerId = widget.task.checkedByWorkerId;
        });
      } else {
        final checker = workers.where((w) => w.role == 'CHECKER' || w.role == 'BOTH').firstOrNull;
        if (checker != null) {
          setState(() {
            _selectedWorkerId = checker.id;
          });
        } else if (workers.isNotEmpty) {
          setState(() {
            _selectedWorkerId = workers.first.id;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _defectNotesController.dispose();
    super.dispose();
  }

  bool _canApprove() {
    if (!_checklist.cuttingDoneRight) return false;
    if (widget.task.hasPrinting && !_checklist.printingDoneRight) return false;
    if (widget.task.hasEmbroidery && !_checklist.embroideryDoneRight) return false;
    if (!_checklist.washingDoneRight) return false;
    if (!_checklist.ironDoneRight) return false;
    return true;
  }

  void _handleApprove() {
    final state = ref.read(readyGoodsProvider);
    final worker = state.workers.where((w) => w.id == _selectedWorkerId).firstOrNull;

    if (worker == null && state.workers.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an assigned inspector.')),
      );
      return;
    }

    final workerId = worker?.id ?? 'ANON-CHK';
    final workerName = worker?.workerName ?? 'Floor Quality Inspector';

    ref.read(readyGoodsProvider.notifier).submitInspectionResult(
      taskId: widget.task.id,
      workerId: workerId,
      workerName: workerName,
      checklist: _checklist,
      isDefectMode: false,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Lot #${widget.task.taskCode} approved! Passed to Packing line.'),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
    Navigator.of(context).pop();
  }

  void _handleReject() {
    final state = ref.read(readyGoodsProvider);
    final worker = state.workers.where((w) => w.id == _selectedWorkerId).firstOrNull;

    final workerId = worker?.id ?? 'ANON-CHK';
    final workerName = worker?.workerName ?? 'Floor Quality Inspector';

    final notes = _defectNotesController.text.trim().isNotEmpty
        ? _defectNotesController.text.trim()
        : 'Flagged at $_defectStation: $_defectReason';

    ref.read(readyGoodsProvider.notifier).submitInspectionResult(
      taskId: widget.task.id,
      workerId: workerId,
      workerName: workerName,
      checklist: _checklist,
      isDefectMode: true,
      defectReason: _defectReason,
      defectNotes: notes,
      defectStation: _defectStation,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Lot #${widget.task.taskCode} routed to Alteration Clinic ($_defectReason).'),
        backgroundColor: const Color(0xFFE11D48),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(readyGoodsProvider);
    final workers = state.workers;

    return Dialog(
      backgroundColor: kCardBg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: kBorderColor),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: kCanvasColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                border: Border(bottom: BorderSide(color: kBorderColor)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: kCardBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: kBorderColor),
                    ),
                    child: const Icon(Icons.shield_outlined, size: 20, color: kPrimaryBrand),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Quality Inspection Check',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: kInkText,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: kPrimaryBrand,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '#${widget.task.taskCode}',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.task.buyer} • ${widget.task.styleName} (${widget.task.piecesCount} pcs • Size ${widget.task.size})',
                          style: GoogleFonts.publicSans(
                            fontSize: 12,
                            color: kMutedText,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: kCardBg,
                        border: Border.all(color: kBorderColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.close, size: 16, color: kMutedText),
                    ),
                  ),
                ],
              ),
            ),

            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Origin Context
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: kBorderColor),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          RichText(
                            text: TextSpan(
                              style: GoogleFonts.jetBrainsMono(fontSize: 11, color: kMutedText),
                              children: [
                                const TextSpan(text: 'WASH BATCH: '),
                                TextSpan(
                                  text: widget.task.washBatchRef,
                                  style: const TextStyle(fontWeight: FontWeight.w700, color: kInkText),
                                ),
                              ],
                            ),
                          ),
                          RichText(
                            text: TextSpan(
                              style: GoogleFonts.jetBrainsMono(fontSize: 11, color: kMutedText),
                              children: [
                                const TextSpan(text: 'IRON TABLE: '),
                                TextSpan(
                                  text: widget.task.ironStationRef,
                                  style: const TextStyle(fontWeight: FontWeight.w700, color: kInkText),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Inspector Selection
                    Text(
                      'ASSIGNED QUALITY CHECKER',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: kMutedText,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      decoration: BoxDecoration(
                        color: kCardBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: kBorderColor),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: workers.any((w) => w.id == _selectedWorkerId) ? _selectedWorkerId : null,
                          hint: Text(
                            workers.isEmpty
                                ? 'No registered floor workers (Register via + Add Worker)'
                                : 'Select quality inspector...',
                            style: GoogleFonts.publicSans(fontSize: 12, color: kMutedText),
                          ),
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down, size: 16, color: kPrimaryBrand),
                          items: workers.map((w) {
                            return DropdownMenuItem<String>(
                              value: w.id,
                              child: Text(
                                '${w.workerName} (${w.role}) • ${w.shift}',
                                style: GoogleFonts.publicSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: kInkText,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedWorkerId = val;
                            });
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    if (!_isDefectMode) ...[
                      // Verification criteria
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'VERIFICATION CRITERIA',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: kMutedText,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            'Tick to verify and approve',
                            style: GoogleFonts.publicSans(
                              fontSize: 11,
                              color: kMutedText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // 1. Cutting
                      _buildChecklistTile(
                        icon: Icons.content_cut,
                        iconColor: kInkText,
                        title: 'Cutting Done Right',
                        tag: 'Mandatory',
                        tagBg: const Color(0xFFD1FAE5),
                        tagColor: const Color(0xFF047857),
                        subtitle: 'Pattern symmetry, panel alignment, notches matching, and balanced grain line.',
                        value: _checklist.cuttingDoneRight,
                        onChanged: (val) {
                          setState(() {
                            _checklist = _checklist.copyWith(cuttingDoneRight: val ?? false);
                          });
                        },
                      ),
                      const SizedBox(height: 8),

                      // 2. Printing
                      if (widget.task.hasPrinting) ...[
                        _buildChecklistTile(
                          icon: Icons.print_outlined,
                          iconColor: const Color(0xFF2563EB),
                          title: 'Printing Done Right',
                          tag: 'Per Tech-Pack',
                          tagBg: const Color(0xFFDBEAFE),
                          tagColor: const Color(0xFF1D4ED8),
                          subtitle: 'Color strike-off matched, screen registration aligned, no bleed or smudges.',
                          value: _checklist.printingDoneRight,
                          onChanged: (val) {
                            setState(() {
                              _checklist = _checklist.copyWith(printingDoneRight: val ?? false);
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                      ],

                      // 3. Embroidery
                      if (widget.task.hasEmbroidery) ...[
                        _buildChecklistTile(
                          icon: Icons.auto_awesome,
                          iconColor: const Color(0xFFD97706),
                          title: 'Embroidery Done Right',
                          tag: 'Per Tech-Pack',
                          tagBg: const Color(0xFFFEF3C7),
                          tagColor: const Color(0xFFB45309),
                          subtitle: 'DST stitch placement accurate, correct thread tension, clean jump thread trims.',
                          value: _checklist.embroideryDoneRight,
                          onChanged: (val) {
                            setState(() {
                              _checklist = _checklist.copyWith(embroideryDoneRight: val ?? false);
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                      ],

                      // 4. Washing
                      _buildChecklistTile(
                        icon: Icons.water_drop_outlined,
                        iconColor: const Color(0xFF0284C7),
                        title: 'Washing Done Right',
                        tag: 'Mandatory',
                        tagBg: const Color(0xFFD1FAE5),
                        tagColor: const Color(0xFF047857),
                        subtitle: 'Softener hand feel verified, shade clearance approved, zero residual odor.',
                        value: _checklist.washingDoneRight,
                        onChanged: (val) {
                          setState(() {
                            _checklist = _checklist.copyWith(washingDoneRight: val ?? false);
                          });
                        },
                      ),
                      const SizedBox(height: 8),

                      // 5. Ironing
                      _buildChecklistTile(
                        icon: Icons.local_fire_department_outlined,
                        iconColor: const Color(0xFFEA580C),
                        title: 'Ironing Done Right',
                        tag: 'Mandatory',
                        tagBg: const Color(0xFFD1FAE5),
                        tagColor: const Color(0xFF047857),
                        subtitle: 'Seams pressed flat, zero shine marks or glazing, collars and hems crisp.',
                        value: _checklist.ironDoneRight,
                        onChanged: (val) {
                          setState(() {
                            _checklist = _checklist.copyWith(ironDoneRight: val ?? false);
                          });
                        },
                      ),
                    ] else ...[
                      // Defect mode
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFECDD3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFBE123C)),
                                const SizedBox(width: 8),
                                Text(
                                  'Flag Defect for Alteration Clinic',
                                  style: GoogleFonts.publicSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF9F1239),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            Text(
                              'DEFECT REASON',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: kInkText,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: kCardBg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: kBorderColor),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _defectReason,
                                  isExpanded: true,
                                  icon: const Icon(Icons.keyboard_arrow_down, size: 14, color: kPrimaryBrand),
                                  items: const [
                                    DropdownMenuItem(value: 'OPEN_SEAM', child: Text('Open Seam / Skipped Stitch')),
                                    DropdownMenuItem(value: 'PRINT_SMUDGE', child: Text('Print Misalignment / Curing Smudge')),
                                    DropdownMenuItem(value: 'EMB_THREAD_BREAK', child: Text('Embroidery Thread Pull / Frays')),
                                    DropdownMenuItem(value: 'WASH_STAIN', child: Text('Washing Oil / Water Spot')),
                                    DropdownMenuItem(value: 'IRON_SHINE', child: Text('Iron Shine / Thermal Glaze')),
                                    DropdownMenuItem(value: 'ASYMMETRY', child: Text('Panel Sizing / Asymmetry')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) setState(() => _defectReason = val);
                                  },
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            Text(
                              'TARGET REPAIR STATION',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: kInkText,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: kCardBg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: kBorderColor),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _defectStation,
                                  isExpanded: true,
                                  icon: const Icon(Icons.keyboard_arrow_down, size: 14, color: kPrimaryBrand),
                                  items: const [
                                    DropdownMenuItem(value: 'Mending Station 01', child: Text('Mending Station 01 (Seam & Stitch)')),
                                    DropdownMenuItem(value: 'Spot Cleaning Table 02', child: Text('Spot Cleaning Table 02 (Chemical)')),
                                    DropdownMenuItem(value: 'Touchup Press 03', child: Text('Touchup Press 03 (Re-Ironing)')),
                                    DropdownMenuItem(value: 'Alteration Master Desk', child: Text('Alteration Master Desk')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) setState(() => _defectStation = val);
                                  },
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            Text(
                              'DEFECT NOTES / INSTRUCTIONS',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: kInkText,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _defectNotesController,
                              maxLines: 2,
                              style: GoogleFonts.publicSans(fontSize: 12, color: kInkText),
                              decoration: InputDecoration(
                                hintText: 'Specify defect location (e.g. left armhole open seam)...',
                                hintStyle: GoogleFonts.publicSans(fontSize: 12, color: kMutedText),
                                filled: true,
                                fillColor: kCardBg,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: kBorderColor),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: kBorderColor),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Footer actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: kCanvasColor,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
                border: Border(top: BorderSide(color: kBorderColor)),
              ),
              child: !_isDefectMode
                  ? Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() => _isDefectMode = true);
                          },
                          icon: const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFE11D48)),
                          label: Text(
                            'Flag Defect',
                            style: GoogleFonts.publicSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFE11D48),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFFDA4AF)),
                            backgroundColor: kCardBg,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _canApprove() ? _handleApprove : null,
                            icon: const Icon(Icons.check_circle_outline, size: 16),
                            label: Text(
                              'Approve & Pass',
                              style: GoogleFonts.publicSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kPrimaryBrand,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: kPrimaryBrand.withValues(alpha: 0.35),
                              disabledForegroundColor: Colors.white70,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        OutlinedButton(
                          onPressed: () {
                            setState(() => _isDefectMode = false);
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: kBorderColor),
                            backgroundColor: kCardBg,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          child: Text(
                            'Back',
                            style: GoogleFonts.publicSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: kInkText,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _handleReject,
                            icon: const Icon(Icons.warning_amber_rounded, size: 16),
                            label: Text(
                              'Send to Alteration',
                              style: GoogleFonts.publicSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE11D48),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
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

  Widget _buildChecklistTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String tag,
    required Color tagBg,
    required Color tagColor,
    required String subtitle,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    final isChecked = value;
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isChecked ? const Color(0xFFECFDF5) : kCardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isChecked ? const Color(0xFF10B981) : kBorderColor,
            width: isChecked ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: value,
              onChanged: onChanged,
              activeColor: kPrimaryBrand,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 14, color: iconColor),
                      const SizedBox(width: 6),
                      Text(
                        title,
                        style: GoogleFonts.publicSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: kInkText,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: tagBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          tag,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: tagColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.publicSans(
                      fontSize: 11,
                      color: kMutedText,
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
