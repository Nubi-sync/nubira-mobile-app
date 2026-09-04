import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/connectivity_indicator.dart';
import '../auth/providers/auth_provider.dart';
import '../auth/screens/login_screen.dart';
import 'widgets/delivery_challan_modal.dart';
import '../../../main.dart';

class QcDashboard extends ConsumerStatefulWidget {
  const QcDashboard({super.key});

  @override
  ConsumerState<QcDashboard> createState() => _QcDashboardState();
}

class _QcDashboardState extends ConsumerState<QcDashboard> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  int _selectedTabIndex = 0; // 0: Incoming Lots, 1: QC Checking, 2: Alterations, 3: Ready for Challan
  int _incomingFilterMode = 0; // 0: My Assigned Lots, 1: All Floor Lots

  // Filtered incoming lots based on supervisor custody
  List<Map<String, dynamic>> get _filteredIncomingLots {
    final currentUserId = supabase.auth.currentUser?.id;
    if (_incomingFilterMode == 0) {
      return _incomingLots.where((lot) {
        final supId = lot['qc_supervisor_id']?.toString();
        // If assigned to me OR general unassigned pool, show in My Assigned Lots
        return supId == null || supId.isEmpty || supId == currentUserId;
      }).toList();
    }
    return _incomingLots;
  }

  // Live floor data
  List<Map<String, dynamic>> _incomingLots = [];
  List<Map<String, dynamic>> _activeAssignments = [];
  List<Map<String, dynamic>> _activeAlterations = [];
  List<Map<String, dynamic>> _readyForChallanLots = [];

  // Floor stats
  int _totalReceivedFromMending = 0;
  int _totalInChecking = 0;
  int _totalInAlteration = 0;
  int _totalReadyForChallan = 0;
  int _totalPassedToday = 0;
  int _totalCheckedToday = 0;

  // Recent QC workers for 1-tap chip recommendations
  List<String> _recentWorkerNames = ['Sunil Kumar', 'Ramesh', 'Pooja', 'Anita', 'Vikas'];

  // Defect types
  final List<Map<String, String>> _defectTypes = [
    {'key': 'STITCHING_ALTER', 'label': 'Stitching Alter / Seam Open'},
    {'key': 'BROKEN_STITCH', 'label': 'Broken Stitch / Thread Cut'},
    {'key': 'SKIP_STITCH', 'label': 'Skip Stitch / Seam Miss'},
    {'key': 'UNEVEN_HEM', 'label': 'Uneven Hem / Alignment'},
    {'key': 'FABRIC_STAIN', 'label': 'Fabric Stain / Oil Spot'},
    {'key': 'SIZING_ISSUE', 'label': 'Sizing / Measurement Off'},
    {'key': 'FABRIC_CUT', 'label': 'Fabric Cut / Needle Hole'},
    {'key': 'OTHER', 'label': 'Other Floor Defect'},
  ];

  // Natural size ordering helper
  static const List<String> _alphaSizeOrder = [
    'XS', 'S', 'M', 'L', 'XL', '2XL', 'XXL', '3XL', 'XXXL', '4XL', '5XL', 'FREE', 'FS'
  ];

  int _naturalSizeCompare(String a, String b) {
    final aUpper = a.trim().toUpperCase();
    final bUpper = b.trim().toUpperCase();

    final aIdx = _alphaSizeOrder.indexOf(aUpper);
    final bIdx = _alphaSizeOrder.indexOf(bUpper);

    if (aIdx != -1 && bIdx != -1) return aIdx.compareTo(bIdx);
    if (aIdx != -1) return -1;
    if (bIdx != -1) return 1;

    final aNum = int.tryParse(aUpper);
    final bNum = int.tryParse(bUpper);
    if (aNum != null && bNum != null) return aNum.compareTo(bNum);

    return aUpper.compareTo(bUpper);
  }

  @override
  void initState() {
    super.initState();
    _loadRecentWorkers();
    _fetchQcData();
  }

  Future<void> _loadRecentWorkers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('qc_recent_workers');
      if (list != null && list.isNotEmpty && mounted) {
        setState(() => _recentWorkerNames = list);
      }
    } catch (_) {}
  }

  Future<void> _saveRecentWorker(String name) async {
    final clean = name.trim();
    if (clean.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final set = _recentWorkerNames.toSet();
      set.remove(clean);
      final updated = [clean, ...set].take(10).toList();
      await prefs.setStringList('qc_recent_workers', updated);
      if (mounted) setState(() => _recentWorkerNames = updated);
    } catch (_) {}
  }

  String _getShiftName() {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 14) {
      return 'Morning shift';
    } else if (hour >= 14 && hour < 22) {
      return 'Evening shift';
    } else {
      return 'Night shift';
    }
  }

  // Load local assignments fallback
  Future<List<Map<String, dynamic>>> _loadLocalAssignments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString('qc_active_assignments_v2');
      if (str != null) {
        final List decoded = jsonDecode(str);
        return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> _saveLocalAssignments(List<Map<String, dynamic>> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('qc_active_assignments_v2', jsonEncode(list));
    } catch (_) {}
  }

  // ====================================================
  // DATA FETCHING: UNIFIED MENDING -> QC -> LINEMAN FLOW
  // ====================================================
  Future<void> _fetchQcData() async {
    debugPrint('=== QC_DASHBOARD: _fetchQcData starting ===');
    setState(() => _isLoading = true);
    try {
      // 1. Fetch Allotments enriched with Articles, Linemen, Challans
      List<dynamic> allotmentList = [];
      try {
        final allotmentsRes = await supabase
            .from('allotments')
            .select('''
              id,
              challan_id,
              article_id,
              lineman_id,
              status,
              mending_status,
              qc_status,
              target_qty,
              mending_total_counted,
              mending_verified_at,
              qc_total_passed,
              qc_total_alter,
              qc_supervisor_id,
              qc_supervisor_name,
              handed_to_qc_by,
              handed_to_qc_at,
              qc_handover_notes,
              created_at,
              article:articles ( id, art_no, description ),
              lineman:profiles!allotments_lineman_id_fkey ( id, username ),
              challans ( id, challan_no, brand, fabric_type )
            ''')
            .order('created_at', ascending: false)
            .limit(60)
            .timeout(const Duration(seconds: 4), onTimeout: () => []);
        allotmentList = allotmentsRes as List<dynamic>;
      } catch (e) {
        debugPrint('QC_DASHBOARD: Allotments join error: $e, trying simple select');
        try {
          final simpleRes = await supabase
              .from('allotments')
              .select('*')
              .order('created_at', ascending: false)
              .limit(60)
              .timeout(const Duration(seconds: 3), onTimeout: () => []);
          allotmentList = simpleRes as List<dynamic>;
        } catch (_) {}
      }

      final List<String> lotIds = allotmentList.map((a) => a['id'].toString()).toList();

      // 2. Fetch variants for these allotments
      List<dynamic> variantsRes = [];
      if (lotIds.isNotEmpty) {
        try {
          variantsRes = await supabase
              .from('allotment_variants')
              .select('id, allotment_id, color, size, quantity')
              .inFilter('allotment_id', lotIds)
              .timeout(const Duration(seconds: 4), onTimeout: () => []);
        } catch (e) {
          debugPrint('Allotment variants fetch error: $e');
        }
      }

      // 3. Fetch mending assignments for physical counts
      List<dynamic> mendingAssignmentsRes = [];
      if (lotIds.isNotEmpty) {
        try {
          mendingAssignmentsRes = await supabase
              .from('mending_assignments')
              .select('*')
              .inFilter('allotment_id', lotIds)
              .timeout(const Duration(seconds: 4), onTimeout: () => []);
        } catch (e) {
          debugPrint('Mending assignments fetch error: $e');
        }
      }

      // 4. Fetch QC Assignments
      List<Map<String, dynamic>> activeAssignments = [];
      try {
        final qcAssignRes = await supabase
            .from('qc_assignments')
            .select('''
              id,
              allotment_id,
              qc_supervisor_id,
              worker_name,
              article_id,
              color,
              size,
              assigned_qty,
              checked_qty,
              passed_qty,
              alter_qty,
              status,
              notes,
              assigned_at,
              entry_date,
              article:articles ( id, art_no, description )
            ''')
            .order('assigned_at', ascending: false)
            .timeout(const Duration(seconds: 4), onTimeout: () => []);
        activeAssignments = (qcAssignRes as List).map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (_) {
        activeAssignments = await _loadLocalAssignments();
      }

      // Enrich activeAssignments with matching article from allotmentList if missing
      for (var assign in activeAssignments) {
        if (assign['article'] == null && allotmentList.isNotEmpty) {
          final match = allotmentList.firstWhere(
            (a) => a['id'].toString() == assign['allotment_id']?.toString() || a['article_id']?.toString() == assign['article_id']?.toString(),
            orElse: () => null,
          );
          if (match != null && match['article'] != null) {
            assign['article'] = match['article'];
          }
        }
      }

      // 5. Fetch Alterations & QC Logs
      List<dynamic> qcLogsRes = [];
      try {
        qcLogsRes = await supabase
            .from('qc_logs')
            .select('''
              id,
              article_id,
              from_lineman_id,
              qty_received,
              qty_passed,
              qty_rejected,
              defect_type,
              remarks,
              entry_date,
              created_at,
              color,
              size,
              mending_status,
              article:articles ( id, art_no, description ),
              lineman:profiles!qc_logs_from_lineman_id_fkey ( id, username )
            ''')
            .order('created_at', ascending: false)
            .limit(60)
            .timeout(const Duration(seconds: 4), onTimeout: () => []);
      } catch (e) {
        debugPrint('QC logs fetch error: $e');
      }

      // ----------------------------------------------------
      // PROCESS INCOMING LOTS (From Mending Floor) & READY FOR CHALLAN
      // ----------------------------------------------------
      final List<Map<String, dynamic>> incoming = [];
      final List<Map<String, dynamic>> readyForChallan = [];
      int totalMendingReceived = 0;

      for (var a in allotmentList) {
        final aId = a['id'].toString();
        final vars = variantsRes.where((v) => v['allotment_id'].toString() == aId).toList();
        final mendAssigns = mendingAssignmentsRes.where((m) => m['allotment_id'].toString() == aId).toList();

        vars.sort((x, y) => _naturalSizeCompare((x['size'] ?? '').toString(), (y['size'] ?? '').toString()));

        int adminTotal = (a['target_qty'] as int?) ?? 0;
        if (adminTotal == 0) {
          for (var v in vars) {
            adminTotal += (v['quantity'] as int? ?? 0);
          }
        }

        int mendingTotal = (a['mending_total_counted'] as int?) ?? 0;
        if (mendingTotal == 0 && mendAssigns.isNotEmpty) {
          for (var m in mendAssigns) {
            mendingTotal += (m['completed_qty'] as int? ?? 0);
          }
        }

        final int passedQty = (a['qc_total_passed'] as int?) ?? 0;
        final int alterQty = (a['qc_total_alter'] as int?) ?? 0;
        final mStatus = (a['mending_status'] ?? '').toString();
        final qStatus = (a['qc_status'] ?? '').toString();

        final bool isHandedOverFromMending = mStatus == 'QC_PENDING' || 
                                             mStatus == 'COUNTING_VERIFIED' || 
                                             qStatus == 'QC_PENDING' || 
                                             qStatus == 'INCOMING_HANDOVER' ||
                                             qStatus == 'INCOMING_FROM_MENDING';

        if (mendingTotal == 0 && isHandedOverFromMending) {
          mendingTotal = adminTotal;
        }

        // Build Size Audit Breakdown (Admin Allotted vs Mending Counted vs QC Passed)
        final List<Map<String, dynamic>> sizeMatrix = [];
        final List<Map<String, dynamic>> enrichedVars = [];

        for (var v in vars) {
          final sz = v['size']?.toString() ?? '-';
          final clr = v['color']?.toString() ?? '-';
          final allotQty = (v['quantity'] as int?) ?? 0;

          int mCount = 0;
          for (var m in mendAssigns) {
            if ((m['size']?.toString() ?? '') == sz) {
              mCount += (m['completed_qty'] as int? ?? 0);
            }
          }
          if (mCount == 0 && isHandedOverFromMending) {
            mCount = allotQty;
          }

          int qcPassCount = 0;
          for (var qc in activeAssignments) {
            if (qc['allotment_id']?.toString() == aId && (qc['size']?.toString() ?? '') == sz) {
              qcPassCount += (qc['passed_qty'] as int? ?? 0);
            }
          }
          if (qcPassCount == 0 && vars.length == 1 && passedQty > 0) {
            qcPassCount = passedQty;
          }

          sizeMatrix.add({
            'size': sz,
            'color': clr,
            'allotted_qty': allotQty,
            'mending_qty': mCount,
            'qc_passed_qty': qcPassCount,
            'diff': mCount - allotQty,
          });

          enrichedVars.add({
            ...Map<String, dynamic>.from(v),
            'order_qty': allotQty,
            'allotted_qty': allotQty,
            'qc_passed_qty': qcPassCount,
          });
        }

        final lotData = {
          ...Map<String, dynamic>.from(a),
          'variants': enrichedVars,
          'size_matrix': sizeMatrix,
          'admin_total_qty': adminTotal,
          'mending_received_qty': mendingTotal,
          'qc_total_passed': passedQty,
          'qc_total_alter': alterQty,
          'variance': mendingTotal - adminTotal,
        };

        // Determine Stage:
        // 1. Ready for Challan: If QC checking is completed, pending admin approval, approved for store, or passed pieces >= target_qty
        if (qStatus == 'QC_COMPLETED' || qStatus == 'READY_FOR_CHALLAN' || qStatus == 'PENDING_ADMIN_APPROVAL' || qStatus == 'APPROVED_FOR_STORE' || qStatus == 'READY_FOR_STORE' || (passedQty > 0 && passedQty >= (mendingTotal > 0 ? mendingTotal : adminTotal))) {
          readyForChallan.add(lotData);
        }
        // 2. Incoming from Mending Floor: ONLY if explicitly verified & handed over from Mending
        else if (isHandedOverFromMending) {
          incoming.add(lotData);
          totalMendingReceived += mendingTotal;
        }
        // Otherwise: Still with Lineman / in stitching / pending mending -> DO NOT show in QC!
      }

      // If ready for challan is empty but some allotments have passed counts, populate
      if (readyForChallan.isEmpty) {
        for (var a in allotmentList) {
          final passed = (a['qc_total_passed'] as int?) ?? 0;
          if (passed > 0) {
            final aId = a['id'].toString();
            final vars = variantsRes.where((v) => v['allotment_id'].toString() == aId).toList();
            readyForChallan.add({
              ...Map<String, dynamic>.from(a),
              'variants': vars,
              'admin_total_qty': (a['target_qty'] as int?) ?? passed,
              'mending_received_qty': (a['mending_total_counted'] as int?) ?? passed,
              'qc_total_passed': passed,
              'qc_total_alter': (a['qc_total_alter'] as int?) ?? 0,
            });
          }
        }
      }

      // ----------------------------------------------------
      // PROCESS ALTERATIONS & ACTIVE CHECKING METRICS
      // ----------------------------------------------------
      final List<Map<String, dynamic>> alterations = [];
      int inAlteration = 0;
      int checkedToday = 0;
      int passedToday = 0;

      for (var log in qcLogsRes) {
        final qRej = (log['qty_rejected'] as int?) ?? 0;
        final qPass = (log['qty_passed'] as int?) ?? 0;
        final qRec = (log['qty_received'] as int?) ?? 0;
        final mStatus = (log['mending_status'] ?? '').toString();

        final c = (qPass + qRej > 0) ? (qPass + qRej) : qRec;
        checkedToday += c;
        passedToday += qPass;

        if (qRej > 0 && mStatus != 'REPAIR_COMPLETED') {
          alterations.add(Map<String, dynamic>.from(log));
          inAlteration += qRej;
        }
      }

      int inCheckingPieces = 0;
      for (var assign in activeAssignments) {
        if (assign['status'] != 'DONE') {
          final assigned = (assign['assigned_qty'] as int?) ?? 0;
          final checked = (assign['checked_qty'] as int?) ?? 0;
          inCheckingPieces += (assigned - checked).clamp(0, assigned);
        }
      }

      int readyPieces = 0;
      for (var r in readyForChallan) {
        readyPieces += ((r['qc_total_passed'] as int?) ?? (r['mending_received_qty'] as int?) ?? 0);
      }

      if (mounted) {
        setState(() {
          _incomingLots = incoming;
          _activeAssignments = activeAssignments;
          _activeAlterations = alterations;
          _readyForChallanLots = readyForChallan;

          _totalReceivedFromMending = totalMendingReceived;
          _totalInChecking = inCheckingPieces;
          _totalInAlteration = inAlteration;
          _totalReadyForChallan = readyPieces;
          _totalCheckedToday = checkedToday;
          _totalPassedToday = passedToday;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('QC Dashboard fetch error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ====================================================
  // MODAL: ASSIGN QC CHECKER / WORKER
  // ====================================================
  void _openAssignWorkerModal(Map<String, dynamic> lot) {
    final workerController = TextEditingController();
    final qtyController = TextEditingController();
    final notesController = TextEditingController();

    final sizeMatrix = lot['size_matrix'] as List<dynamic>? ?? [];
    Map<String, dynamic>? selectedVariant = sizeMatrix.isNotEmpty ? sizeMatrix.first : null;

    int defaultQty = selectedVariant != null
        ? (selectedVariant['mending_qty'] as int? ?? selectedVariant['allotted_qty'] as int? ?? 50)
        : (lot['mending_received_qty'] as int? ?? 100);

    qtyController.text = defaultQty.toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final artNo = lot['article']?['art_no'] ?? lot['art_no'] ?? 'Article';
          final desc = lot['article']?['description'] ?? lot['description'] ?? '';

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Assign QC Checker',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.steel,
                            ),
                          ),
                          Text(
                            'Art #$artNo · $desc',
                            style: GoogleFonts.publicSans(fontSize: 12, color: AppTheme.inkSoft),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppTheme.inkSoft),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Text(
                    'Checker Name / Worker',
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.ink),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: workerController,
                    decoration: InputDecoration(
                      hintText: 'Worker name (e.g. Ramesh, Sunil)',
                      prefixIcon: const Icon(Icons.person_outline_rounded, color: AppTheme.steel),
                      filled: true,
                      fillColor: AppTheme.steelMist.withValues(alpha: 0.3),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
                    ),
                    onChanged: (_) => setModalState(() {}),
                  ),
                  const SizedBox(height: 16),

                  // Variant / Size Selector
                  if (sizeMatrix.isNotEmpty) ...[
                    Text(
                      'Select Size / Color Variant',
                      style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.ink),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: sizeMatrix.map((v) {
                        final isSel = selectedVariant == v;
                        final sz = v['size'] ?? '-';
                        final clr = v['color'] ?? '';
                        final mQty = v['mending_qty'] ?? v['allotted_qty'] ?? 0;
                        return InkWell(
                          onTap: () {
                            setModalState(() {
                              selectedVariant = v;
                              qtyController.text = mQty.toString();
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSel ? AppTheme.steel : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isSel ? AppTheme.steel : AppTheme.border),
                            ),
                            child: Text(
                              '$sz ${clr.isNotEmpty ? "($clr)" : ""} · $mQty pcs',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11.5,
                                fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                                color: isSel ? Colors.white : AppTheme.ink,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Assigned Quantity Input
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Assigned Qty to Check',
                              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.ink),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: qtyController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                suffixText: 'pcs',
                                filled: true,
                                fillColor: AppTheme.steelMist.withValues(alpha: 0.3),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Notes Input
                  Text(
                    'Notes / Instructions (Optional)',
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.ink),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: notesController,
                    decoration: InputDecoration(
                      hintText: 'e.g. Check stitching on collar and buttons',
                      filled: true,
                      fillColor: AppTheme.steelMist.withValues(alpha: 0.3),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.steel,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: _isSubmitting
                          ? null
                          : () async {
                              final worker = workerController.text.trim();
                              final qty = int.tryParse(qtyController.text.trim()) ?? 0;
                              if (worker.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please enter or select a checker name')),
                                );
                                return;
                              }
                              if (qty <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please enter a valid quantity')),
                                );
                                return;
                              }

                              Navigator.pop(ctx);
                              await _submitWorkerAssignment(
                                lot: lot,
                                workerName: worker,
                                variant: selectedVariant,
                                assignedQty: qty,
                                notes: notesController.text.trim(),
                              );
                            },
                      child: _isSubmitting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(
                              'Confirm Assignment & Start QC',
                              style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // SUBMIT WORKER ASSIGNMENT
  Future<void> _submitWorkerAssignment({
    required Map<String, dynamic> lot,
    required String workerName,
    required Map<String, dynamic>? variant,
    required int assignedQty,
    required String notes,
  }) async {
    setState(() => _isSubmitting = true);
    try {
      await _saveRecentWorker(workerName);

      final user = supabase.auth.currentUser;
      final newAssignment = {
        'id': 'qc-assign-${DateTime.now().millisecondsSinceEpoch}',
        'allotment_id': lot['id'],
        'qc_supervisor_id': user?.id,
        'worker_name': workerName,
        'article_id': lot['article_id'],
        'color': variant?['color'] ?? 'Default',
        'size': variant?['size'] ?? 'Free',
        'assigned_qty': assignedQty,
        'checked_qty': 0,
        'passed_qty': 0,
        'alter_qty': 0,
        'status': 'ASSIGNED',
        'notes': notes,
        'assigned_at': DateTime.now().toUtc().toIso8601String(),
        'entry_date': DateTime.now().toIso8601String().split('T')[0],
        'article': lot['article'] ?? {'art_no': lot['art_no'] ?? 'Art', 'description': ''},
        'lineman_id': lot['lineman_id'],
        'lineman': lot['lineman'],
      };

      // 1. Try insert into qc_assignments table
      try {
        await supabase.from('qc_assignments').insert({
          'allotment_id': lot['id'],
          'qc_supervisor_id': user?.id,
          'worker_name': workerName,
          'article_id': lot['article_id'],
          'color': variant?['color'] ?? 'Default',
          'size': variant?['size'] ?? 'Free',
          'assigned_qty': assignedQty,
          'checked_qty': 0,
          'passed_qty': 0,
          'alter_qty': 0,
          'status': 'ASSIGNED',
          'notes': notes,
          'entry_date': DateTime.now().toIso8601String().split('T')[0],
        });
      } catch (e) {
        debugPrint('qc_assignments table insert fallback: $e');
      }

      // 2. Persist locally to guarantee zero downtime
      final currentList = await _loadLocalAssignments();
      currentList.insert(0, newAssignment);
      await _saveLocalAssignments(currentList);

      // 3. Update allotment status to IN_QC_CHECKING
      try {
        await supabase.from('allotments').update({
          'qc_status': 'IN_QC_CHECKING',
          'qc_received_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', lot['id']);
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.green,
            content: Text(
              '✓ Assigned $assignedQty pcs to $workerName for checking!',
              style: GoogleFonts.publicSans(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        );
        setState(() => _selectedTabIndex = 1); // switch to checking tab
        _fetchQcData();
      }
    } catch (e) {
      debugPrint('Error assigning worker: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppTheme.red, content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ====================================================
  // MODAL: RECORD QC INSPECTION (PASS / ALTER CHECK)
  // ====================================================
  void _openRecordInspectionModal(Map<String, dynamic> task) {
    final checkedCtrl = TextEditingController();
    final passedCtrl = TextEditingController();
    final alterCtrl = TextEditingController();
    final remarksCtrl = TextEditingController();

    final int assignedQty = task['assigned_qty'] as int? ?? 50;
    final int alreadyChecked = task['checked_qty'] as int? ?? 0;
    final int remaining = (assignedQty - alreadyChecked).clamp(0, assignedQty);

    checkedCtrl.text = remaining > 0 ? remaining.toString() : assignedQty.toString();
    passedCtrl.text = checkedCtrl.text;
    alterCtrl.text = '0';

    String selectedDefect = _defectTypes.first['key']!;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final artNo = task['article']?['art_no'] ?? 'Article';
          final worker = task['worker_name'] ?? 'Checker';
          final sz = task['size'] ?? '';
          final clr = task['color'] ?? '';
          final alterQty = int.tryParse(alterCtrl.text.trim()) ?? 0;

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Record QC Inspection',
                              style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.steel),
                            ),
                            Text(
                              'Art #$artNo · $clr ($sz) · Checker: $worker',
                              style: GoogleFonts.publicSans(fontSize: 12, color: AppTheme.inkSoft),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppTheme.inkSoft),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Counter Inputs Row: Checked, Passed, Defective
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Total Checked', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.ink)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: checkedCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: AppTheme.steelMist.withValues(alpha: 0.3),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
                              ),
                              onChanged: (val) {
                                final total = int.tryParse(val.trim()) ?? 0;
                                final alt = int.tryParse(alterCtrl.text.trim()) ?? 0;
                                setModalState(() {
                                  passedCtrl.text = (total - alt).clamp(0, total).toString();
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Passed (OK)', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.green)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: passedCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: AppTheme.greenMist,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.green)),
                              ),
                              onChanged: (val) {
                                final pass = int.tryParse(val.trim()) ?? 0;
                                final total = int.tryParse(checkedCtrl.text.trim()) ?? 0;
                                setModalState(() {
                                  alterCtrl.text = (total - pass).clamp(0, total).toString();
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Defect / Alter', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.red)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: alterCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: AppTheme.amberMist,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.amber)),
                              ),
                              onChanged: (val) {
                                final alt = int.tryParse(val.trim()) ?? 0;
                                final total = int.tryParse(checkedCtrl.text.trim()) ?? 0;
                                setModalState(() {
                                  passedCtrl.text = (total - alt).clamp(0, total).toString();
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // If Defects Exist: Show Defect Reason & Lineman Alteration Box
                  if (alterQty > 0) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.amberMist,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.amber, width: 1.2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.notification_important_rounded, color: AppTheme.amber, size: 18),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Lineman Alteration Alert',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.ink,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppTheme.amber),
                                ),
                                child: Text(
                                  '$alterQty pcs to alter',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.amber,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'These defective pieces will automatically notify the Lineman dashboard for sewing repair.',
                            style: GoogleFonts.publicSans(fontSize: 11.5, color: AppTheme.inkSoft),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Select Defect Category',
                            style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.ink),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _defectTypes.map((d) {
                              final isSel = selectedDefect == d['key'];
                              return InkWell(
                                onTap: () => setModalState(() => selectedDefect = d['key']!),
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: isSel ? AppTheme.amber : Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: isSel ? AppTheme.amber : AppTheme.border),
                                  ),
                                  child: Text(
                                    d['label']!,
                                    style: GoogleFonts.publicSans(
                                      fontSize: 11,
                                      fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                                      color: isSel ? Colors.white : AppTheme.ink,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: remarksCtrl,
                            decoration: InputDecoration(
                              hintText: 'Note for Lineman (e.g. Neck seam open, skip stitch on hem)',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Submit Inspection Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.steel,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: _isSubmitting
                          ? null
                          : () async {
                              final total = int.tryParse(checkedCtrl.text.trim()) ?? 0;
                              final pass = int.tryParse(passedCtrl.text.trim()) ?? 0;
                              final alt = int.tryParse(alterCtrl.text.trim()) ?? 0;

                              if (total <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please enter valid checked count')),
                                );
                                return;
                              }

                              Navigator.pop(ctx);
                              await _submitQcInspection(
                                task: task,
                                checkedQty: total,
                                passedQty: pass,
                                alterQty: alt,
                                defectType: selectedDefect,
                                remarks: remarksCtrl.text.trim(),
                              );
                            },
                      child: _isSubmitting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(
                              alterQty > 0
                                  ? 'Pass ${passedCtrl.text} pcs & Notify Lineman for $alterQty pcs'
                                  : 'Pass All ${passedCtrl.text} Pieces (OK)',
                              style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // SUBMIT QC INSPECTION & NOTIFY LINEMAN FOR ALTERATION
  Future<void> _submitQcInspection({
    required Map<String, dynamic> task,
    required int checkedQty,
    required int passedQty,
    required int alterQty,
    required String defectType,
    required String remarks,
  }) async {
    setState(() => _isSubmitting = true);
    try {
      final articleId = task['article_id'];
      final linemanId = task['lineman_id'] ?? task['from_lineman_id'];
      final allotmentId = task['allotment_id'];
      final color = task['color'] ?? '';
      final size = task['size'] ?? '';
      final worker = task['worker_name'] ?? 'Checker';
      final assignId = task['id'];

      // 1. Insert audit record into qc_logs
      // (This immediately triggers the Lineman Dashboard alert banner!)
      final todayStr = DateTime.now().toIso8601String().split('T')[0];
      await supabase.from('qc_logs').insert({
        if (allotmentId != null) 'allotment_id': allotmentId,
        'article_id': articleId,
        'from_lineman_id': linemanId,
        'stage': 'CHECKING',
        'qty_received': checkedQty,
        'qty_passed': passedQty,
        'qty_rejected': alterQty,
        'defect_type': alterQty > 0 ? defectType : 'NONE',
        'remarks': alterQty > 0
            ? 'Flagged by QC Checker ($worker): $remarks'
            : 'Checked & Passed by QC Checker ($worker)',
        'mending_status': alterQty > 0 ? 'WITH_LINEMAN_FOR_REPAIR' : 'NONE',
        'color': color,
        'size': size,
        'entry_date': todayStr,
      });

      // 2. Update allotment counters
      if (allotmentId != null) {
        try {
          int currentPassed = passedQty;
          int currentAlter = alterQty;
          int totalTarget = 0;
          try {
            final allotRes = await supabase.from('allotments').select('qc_total_passed, qc_total_alter, target_qty, mending_total_counted').eq('id', allotmentId).maybeSingle();
            if (allotRes != null) {
              currentPassed += (allotRes['qc_total_passed'] as int? ?? 0);
              currentAlter += (allotRes['qc_total_alter'] as int? ?? 0);
              totalTarget = (allotRes['mending_total_counted'] as int?) ?? (allotRes['target_qty'] as int? ?? 0);
            }
          } catch (_) {}

          final bool isLotFullyInspected = totalTarget > 0 && (currentPassed + currentAlter) >= totalTarget;

          await supabase.from('allotments').update({
            'qc_total_passed': currentPassed,
            'qc_total_alter': currentAlter,
            'qc_status': isLotFullyInspected && alterQty == 0 ? 'QC_COMPLETED' : 'IN_QC_CHECKING',
            if (alterQty > 0) 'mending_status': 'WITH_LINEMAN_FOR_REPAIR',
          }).eq('id', allotmentId);
        } catch (_) {}
      }

      // 3. Update task in qc_assignments table in Supabase
      final prevChecked = (task['checked_qty'] as int? ?? 0);
      final prevPassed = (task['passed_qty'] as int? ?? 0);
      final prevAlter = (task['alter_qty'] as int? ?? 0);
      final assignedQty = (task['assigned_qty'] as int? ?? 0);

      final newChecked = prevChecked + checkedQty;
      final newPassed = prevPassed + passedQty;
      final newAlter = prevAlter + alterQty;
      final isDone = newChecked >= assignedQty;

      if (assignId != null && !assignId.toString().startsWith('qc-assign-')) {
        try {
          await supabase.from('qc_assignments').update({
            'checked_qty': newChecked,
            'passed_qty': newPassed,
            'alter_qty': newAlter,
            'status': isDone ? 'DONE' : 'IN_PROGRESS',
            'completed_at': isDone ? DateTime.now().toUtc().toIso8601String() : null,
          }).eq('id', assignId);
        } catch (e) {
          debugPrint('qc_assignments update error: $e');
        }
      }

      // 4. Update task status in local storage / table
      final currentList = await _loadLocalAssignments();
      for (var a in currentList) {
        if (a['id'] == task['id'] || (a['allotment_id'] == allotmentId && a['worker_name'] == worker)) {
          a['checked_qty'] = newChecked;
          a['passed_qty'] = newPassed;
          a['alter_qty'] = newAlter;
          a['status'] = isDone ? 'DONE' : 'IN_PROGRESS';
        }
      }
      await _saveLocalAssignments(currentList);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: alterQty > 0 ? AppTheme.amber : AppTheme.green,
            content: Text(
              alterQty > 0
                  ? '✓ $passedQty passed. $alterQty pcs flagged for alteration & notified to Lineman!'
                  : '✓ All $passedQty pieces passed inspection!',
              style: GoogleFonts.publicSans(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        );
        _fetchQcData();
      }
    } catch (e) {
      debugPrint('Error recording inspection: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppTheme.red, content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ====================================================
  // VERIFY & PASS REPAIRED ALTERATION PIECES FROM LINEMAN
  // ====================================================
  Future<void> _verifyAndPassRepairedPieces(Map<String, dynamic> alt) async {
    final qty = (alt['qty_rejected'] as int?) ?? 0;
    final logId = alt['id'];
    final artNo = alt['article']?['art_no'] ?? 'Article';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Pass Repaired Garments?',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.green),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Art #$artNo', style: GoogleFonts.publicSans(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            Text('Defect: ${alt['defect_type'] ?? '-'}', style: GoogleFonts.publicSans(fontSize: 13, color: AppTheme.inkSoft)),
            const SizedBox(height: 12),
            Text(
              'Confirm that Lineman has repaired all $qty defective pieces and they have passed physical re-inspection.',
              style: GoogleFonts.publicSans(fontSize: 12.5, color: AppTheme.ink),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.publicSans(color: AppTheme.inkSoft)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm & Pass (OK)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isSubmitting = true);
      try {
        if (logId != null) {
          await supabase.from('qc_logs').update({
            'mending_status': 'REPAIR_COMPLETED',
            'qty_passed': qty,
            'remarks': 'Repaired by Lineman & Passed by QC',
          }).eq('id', logId);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.green,
              content: Text('✓ $qty repaired pieces verified & passed inspection!'),
            ),
          );
          _fetchQcData();
        }
      } catch (e) {
        debugPrint('Error verifying repaired pieces: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: AppTheme.red, content: Text('Error: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
    }
  }

  // SHOW DELIVERY CHALLAN DISPATCH MODAL
  void _showDeliveryChallanModal({Map<String, dynamic>? prefilledLot}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DeliveryChallanModal(
        prefilledLot: prefilledLot,
        onSubmitted: () {
          _fetchQcData();
        },
      ),
    ).then((_) => _fetchQcData());
  }

  // ====================================================
  // BUILD UI
  // ====================================================
  @override
  Widget build(BuildContext context) {
    final double passRate = _totalCheckedToday > 0
        ? ((_totalPassedToday / _totalCheckedToday) * 100).clamp(0.0, 100.0)
        : 100.0;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F0),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Consumer(
              builder: (context, ref, _) {
                final authState = ref.watch(authProvider);
                final user = supabase.auth.currentUser;
                final name = authState.cachedUsername ?? user?.userMetadata?['username'] ?? user?.email?.split('@')[0] ?? 'User';
                return Text(
                  'Welcome, $name',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.ink,
                  ),
                );
              },
            ),
            Text(
              'QC & Finishing Floor',
              style: GoogleFonts.publicSans(
                fontSize: 12,
                color: AppTheme.inkSoft,
              ),
            ),
          ],
        ),
        actions: [
          const ConnectivityIndicator(),
          const SizedBox(width: 8),
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _fetchQcData,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.sync_rounded, size: 16, color: AppTheme.steel),
                    const SizedBox(width: 5),
                    Text(
                      'Sync',
                      style: GoogleFonts.publicSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.steel,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
            ),
            child: IconButton(
              icon: const Icon(Icons.logout_rounded, color: AppTheme.inkSoft, size: 18),
              tooltip: 'Logout',
              padding: EdgeInsets.zero,
              onPressed: () async {
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
                }
              },
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 28),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 36,
                      height: 36,
                      child: CircularProgressIndicator(color: AppTheme.steel, strokeWidth: 3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Loading QC Shift Data...',
                      style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.ink),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Connecting to factory records',
                      style: GoogleFonts.publicSans(fontSize: 12, color: AppTheme.inkSoft),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              color: AppTheme.steel,
              onRefresh: _fetchQcData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ====================================================
                    // 1. SOLID STEEL SUMMARY CARD (4 FLOOR LIFECYCLE STATS)
                    // ====================================================
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppTheme.steel,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.steelDark.withValues(alpha: 0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${_getShiftName()} · QC Floor Summary',
                                      style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Finishing & Quality Assurance Flow',
                                      style: GoogleFonts.publicSans(color: Colors.white.withValues(alpha: 0.85), fontSize: 11.5),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Pass: ${passRate.toStringAsFixed(0)}%',
                                  style: GoogleFonts.jetBrainsMono(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              _buildSummaryStat('Received', '$_totalReceivedFromMending', Icons.move_to_inbox_outlined),
                              _buildSummaryStat('In QC', '$_totalInChecking', Icons.fact_check_outlined),
                              _buildSummaryStat('Alteration', '$_totalInAlteration', Icons.handyman_outlined, isAlert: _totalInAlteration > 0),
                              _buildSummaryStat('Ready Challan', '$_totalReadyForChallan', Icons.local_shipping_outlined),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ====================================================
                    // 2. LIVE INWARD NOTIFICATION BANNER (IF LOTS WAITING)
                    // ====================================================
                    if (_incomingLots.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFF59E0B), width: 1.2),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: const Color(0xFFD97706), borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${_incomingLots.length} Lot(s) Handed Over from Mending Floor',
                                    style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppTheme.ink),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Verified physical piece counts ready for QC Checker assignment below.',
                                    style: GoogleFonts.publicSans(fontSize: 11.5, color: AppTheme.inkSoft),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    // ====================================================
                    // 3. 4-STAGE PIPELINE TAB CONTROLLER
                    // ====================================================
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          _buildTabButton(0, 'Incoming (${_incomingLots.length})', Icons.inbox_rounded),
                          _buildTabButton(1, 'In QC (${_activeAssignments.length})', Icons.fact_check_rounded),
                          _buildTabButton(2, 'Alter (${_activeAlterations.length})', Icons.handyman_rounded),
                          _buildTabButton(3, 'Ready (${_readyForChallanLots.length})', Icons.local_shipping_rounded),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ====================================================
                    // 4. TAB CONTENT
                    // ====================================================
                    if (_selectedTabIndex == 0)
                      _buildIncomingLotsSection()
                    else if (_selectedTabIndex == 1)
                      _buildActiveCheckingSection()
                    else if (_selectedTabIndex == 2)
                      _buildAlterationsSection()
                    else
                      _buildReadyForChallanSection(),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }

  // ====================================================
  // TAB BUTTON
  // ====================================================
  Widget _buildTabButton(int index, String label, IconData icon) {
    final isSel = _selectedTabIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTabIndex = index),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSel ? AppTheme.steel : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 13, color: isSel ? Colors.white : AppTheme.inkSoft),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: isSel ? FontWeight.w700 : FontWeight.w600,
                    color: isSel ? Colors.white : AppTheme.ink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ====================================================
  // TAB 0: INCOMING LOTS (FROM MENDING FLOOR) WITH ADMIN COMPARISON
  // ====================================================
  Widget _buildIncomingFilterBar() {
    final currentUserId = supabase.auth.currentUser?.id;
    final myCount = _incomingLots.where((l) {
      final supId = l['qc_supervisor_id']?.toString();
      return supId == null || supId.isEmpty || supId == currentUserId;
    }).length;
    final allCount = _incomingLots.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _incomingFilterMode = 0),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                decoration: BoxDecoration(
                  color: _incomingFilterMode == 0 ? AppTheme.steel : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _incomingFilterMode == 0 ? AppTheme.steel : AppTheme.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_pin_rounded, size: 14, color: _incomingFilterMode == 0 ? Colors.white : AppTheme.inkSoft),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'My Assigned Lots ($myCount)',
                        style: GoogleFonts.publicSans(
                          fontSize: 11.5,
                          fontWeight: _incomingFilterMode == 0 ? FontWeight.w700 : FontWeight.w600,
                          color: _incomingFilterMode == 0 ? Colors.white : AppTheme.inkSoft,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _incomingFilterMode = 1),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                decoration: BoxDecoration(
                  color: _incomingFilterMode == 1 ? AppTheme.steel : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _incomingFilterMode == 1 ? AppTheme.steel : AppTheme.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.factory_rounded, size: 14, color: _incomingFilterMode == 1 ? Colors.white : AppTheme.inkSoft),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'All Floor Lots ($allCount)',
                        style: GoogleFonts.publicSans(
                          fontSize: 11.5,
                          fontWeight: _incomingFilterMode == 1 ? FontWeight.w700 : FontWeight.w600,
                          color: _incomingFilterMode == 1 ? Colors.white : AppTheme.inkSoft,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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

  Widget _buildIncomingLotsSection() {
    if (_incomingLots.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.done_all_rounded, size: 48, color: AppTheme.inkSoft.withValues(alpha: 0.5)),
              const SizedBox(height: 12),
              Text(
                'No Incoming Lots Right Now',
                style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.ink),
              ),
              const SizedBox(height: 4),
              Text(
                'When Mending Floor forwards physically counted lots, they appear here automatically with Admin allotted comparisons.',
                textAlign: TextAlign.center,
                style: GoogleFonts.publicSans(fontSize: 12, color: AppTheme.inkSoft),
              ),
            ],
          ),
        ),
      );
    }

    final displayLots = _filteredIncomingLots;

    return Column(
      children: [
        _buildIncomingFilterBar(),
        if (displayLots.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Center(
              child: Text(
                'No lots assigned to your queue in this filter.',
                style: GoogleFonts.publicSans(fontSize: 13, color: AppTheme.inkSoft),
              ),
            ),
          )
        else
          ...displayLots.map((lot) {
            final artNo = lot['article']?['art_no'] ?? lot['art_no'] ?? 'Article';
            final desc = lot['article']?['description'] ?? lot['description'] ?? '';
            final challanNo = lot['challans']?['challan_no'] ?? '-';
            final brand = lot['challans']?['brand'] ?? 'OLLYPOP';
            final lineman = lot['lineman']?['username'] ?? 'Lineman';
            final handedBy = lot['handed_to_qc_by']?.toString();
            final supName = lot['qc_supervisor_name']?.toString() ?? 'General Pool';
            final handoverNotes = lot['qc_handover_notes']?.toString();

            final int adminAllotted = lot['admin_total_qty'] as int? ?? 0;
            final int mendingCounted = lot['mending_received_qty'] as int? ?? adminAllotted;
            final int variance = lot['variance'] as int? ?? (mendingCounted - adminAllotted);
            final sizeMatrix = lot['size_matrix'] as List<dynamic>? ?? [];

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Custody & Handover Header Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
                      border: Border(bottom: BorderSide(color: Color(0xFFFDE68A))),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.handshake_rounded, size: 15, color: Color(0xFFB45309)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'From Mending: ${handedBy != null && handedBy.isNotEmpty ? handedBy : 'Mending Floor'}',
                                style: GoogleFonts.publicSans(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF92400E)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(color: const Color(0xFFFDE68A)),
                              ),
                              child: Text(
                                'Custody: $supName',
                                style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFFB45309)),
                              ),
                            ),
                          ],
                        ),
                        if (handoverNotes != null && handoverNotes.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            '📝 Note: $handoverNotes',
                            style: GoogleFonts.publicSans(fontSize: 11, fontStyle: FontStyle.italic, color: const Color(0xFF78350F)),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Header with Article, Brand, Lineman
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: AppTheme.steelMist, borderRadius: BorderRadius.circular(6)),
                              child: Text(
                                'CH-$challanNo · $brand',
                                style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.steel),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: AppTheme.greenMist, borderRadius: BorderRadius.circular(6)),
                              child: Text(
                                'Stitched by: $lineman',
                                style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.green),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Art #$artNo',
                          style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.ink),
                        ),
                        if (desc.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(desc, style: GoogleFonts.publicSans(fontSize: 12, color: AppTheme.inkSoft)),
                        ],
                      ],
                    ),
                  ),

              const Divider(height: 1, color: AppTheme.border),

              // Admin Allotted vs Mending Counted Comparison Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Admin Allotted', style: GoogleFonts.publicSans(fontSize: 11, color: AppTheme.inkSoft)),
                          const SizedBox(height: 2),
                          Text('$adminAllotted pcs', style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.ink)),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 32, color: AppTheme.border),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Mending Counted', style: GoogleFonts.publicSans(fontSize: 11, color: AppTheme.inkSoft)),
                          const SizedBox(height: 2),
                          Text('$mendingCounted pcs', style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.steel)),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 32, color: AppTheme.border),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Variance', style: GoogleFonts.publicSans(fontSize: 11, color: AppTheme.inkSoft)),
                          const SizedBox(height: 2),
                          Text(
                            variance == 0
                                ? 'Exact (0)'
                                : variance < 0
                                    ? '$variance pcs'
                                    : '+$variance pcs',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: variance == 0 ? AppTheme.green : (variance < 0 ? AppTheme.red : Colors.blue),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Natural Size Matrix Chips
              if (sizeMatrix.isNotEmpty) ...[
                const Divider(height: 1, color: AppTheme.border),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Natural Size Breakdown (Mending Count / Admin Allotted):', style: GoogleFonts.publicSans(fontSize: 11, color: AppTheme.inkSoft)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: sizeMatrix.map((sm) {
                          final sz = sm['size'] ?? '-';
                          final aQ = sm['allotted_qty'] ?? 0;
                          final mQ = sm['mending_qty'] ?? 0;
                          final isDiff = mQ != aQ;
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDiff ? AppTheme.amberMist : AppTheme.steelMist,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: isDiff ? AppTheme.amber : AppTheme.border),
                            ),
                            child: Text(
                              '$sz: $mQ/$aQ pcs',
                              style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.ink),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],

              const Divider(height: 1, color: AppTheme.border),

              // ACTION BUTTON: ASSIGN WORKER
              Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 18, color: Colors.white),
                    label: Text(
                      'Assign QC Checker / Worker',
                      style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.steel,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    onPressed: () => _openAssignWorkerModal(lot),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    ],
  );
}

  // ====================================================
  // TAB 1: ACTIVE QC CHECKING (ASSIGNED WORKERS)
  // ====================================================
  Widget _buildActiveCheckingSection() {
    if (_activeAssignments.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.fact_check_outlined, size: 48, color: AppTheme.inkSoft.withValues(alpha: 0.5)),
              const SizedBox(height: 12),
              Text('No Active QC Checking Tasks', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.ink)),
              const SizedBox(height: 4),
              Text('Assign incoming lots to checkers to inspect garment pieces here.', style: GoogleFonts.publicSans(fontSize: 12, color: AppTheme.inkSoft)),
            ],
          ),
        ),
      );
    }

    return Column(
      children: _activeAssignments.map((task) {
        final worker = task['worker_name'] ?? 'Checker';
        final artNo = task['article']?['art_no'] ?? 'Article';
        final clr = task['color'] ?? '';
        final sz = task['size'] ?? '';
        final int assigned = task['assigned_qty'] as int? ?? 0;
        final int checked = task['checked_qty'] as int? ?? 0;
        final int passed = task['passed_qty'] as int? ?? 0;
        final int alter = task['alter_qty'] as int? ?? 0;
        final isDone = task['status'] == 'DONE' || checked >= assigned;

        final double progress = assigned > 0 ? (checked / assigned).clamp(0.0, 1.0) : 1.0;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDone ? AppTheme.green : AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: AppTheme.steelMist, borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.person_rounded, size: 16, color: AppTheme.steel),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Checker: $worker',
                        style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.ink),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDone ? AppTheme.greenMist : AppTheme.amberMist,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isDone ? 'Completed' : 'In Progress (${(progress * 100).toInt()}%)',
                      style: GoogleFonts.publicSans(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDone ? AppTheme.green : AppTheme.amber,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Art #$artNo · $clr ($sz)',
                style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.steel),
              ),
              const SizedBox(height: 10),

              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: AppTheme.steelMist,
                  valueColor: AlwaysStoppedAnimation<Color>(isDone ? AppTheme.green : AppTheme.steel),
                ),
              ),

              const SizedBox(height: 12),

              // Inspection Metrics row
              Row(
                children: [
                  _buildMiniStat('Assigned', '$assigned pcs', AppTheme.ink),
                  _buildMiniStat('Checked', '$checked pcs', AppTheme.steel),
                  _buildMiniStat('Passed', '$passed pcs', AppTheme.green),
                  _buildMiniStat('Alteration', '$alter pcs', alter > 0 ? AppTheme.red : AppTheme.inkSoft),
                ],
              ),

              const SizedBox(height: 12),

              // Button to Record QC Check
              SizedBox(
                width: double.infinity,
                height: 40,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.fact_check_outlined, size: 16, color: Colors.white),
                  label: Text('Record QC Inspection / Check', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.steel,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  onPressed: () => _openRecordInspectionModal(task),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ====================================================
  // TAB 2: ALTERATIONS WITH LINEMAN
  // ====================================================
  Widget _buildAlterationsSection() {
    if (_activeAlterations.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.check_circle_outline_rounded, size: 48, color: AppTheme.green),
              const SizedBox(height: 12),
              Text('Zero Pending Alterations', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.ink)),
              const SizedBox(height: 4),
              Text('All defective pieces have been repaired by linemen or none reported.', style: GoogleFonts.publicSans(fontSize: 12, color: AppTheme.inkSoft)),
            ],
          ),
        ),
      );
    }

    return Column(
      children: _activeAlterations.map((alt) {
        final artNo = alt['article']?['art_no'] ?? 'Article';
        final lineman = alt['lineman']?['username'] ?? 'Lineman';
        final int qty = alt['qty_rejected'] as int? ?? 0;
        final defect = alt['defect_type'] ?? 'Defect';
        final remarks = alt['remarks'] ?? '';
        final color = alt['color'] ?? '';
        final size = alt['size'] ?? '';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.amber, width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: AppTheme.amberMist, borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.handyman_rounded, size: 16, color: AppTheme.amber),
                      ),
                      const SizedBox(width: 8),
                      Text('With Lineman: $lineman', style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppTheme.ink)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: AppTheme.amber, borderRadius: BorderRadius.circular(6)),
                    child: Text(
                      '$qty pcs',
                      style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Art #$artNo ${color.isNotEmpty ? "· $color ($size)" : ""}', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.steel)),
              const SizedBox(height: 4),
              Text('Defect: $defect', style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.red)),
              if (remarks.toString().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text('Note: $remarks', style: GoogleFonts.publicSans(fontSize: 11.5, color: AppTheme.inkSoft)),
              ],
              const SizedBox(height: 12),

              // Action button to verify repaired pieces from Lineman
              SizedBox(
                width: double.infinity,
                height: 38,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.verified_outlined, size: 16, color: Colors.white),
                  label: Text('Verify & Pass Repaired Pieces', style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.green,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  onPressed: () => _verifyAndPassRepairedPieces(alt),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ====================================================
  // TAB 3: READY FOR CHALLAN (DISPATCH GATE READY)
  // ====================================================
  Widget _buildReadyForChallanSection() {
    if (_readyForChallanLots.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.local_shipping_outlined, size: 48, color: AppTheme.inkSoft.withValues(alpha: 0.5)),
              const SizedBox(height: 12),
              Text('No Articles Ready for Challan Yet', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.ink)),
              const SizedBox(height: 4),
              Text('When articles complete 100% QC checking and pass inspection, they appear here ready for delivery challan generation.', textAlign: TextAlign.center, style: GoogleFonts.publicSans(fontSize: 12, color: AppTheme.inkSoft)),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Top Info Box
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.greenMist,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.green, width: 1.2),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppTheme.green, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${_readyForChallanLots.length} Article(s) Cleared QC & 100% Passed. Ready to generate Ollypop Delivery Challan.',
                  style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.ink),
                ),
              ),
            ],
          ),
        ),

        // List of Ready Articles
        ..._readyForChallanLots.map((lot) {
          final artNo = lot['article']?['art_no'] ?? lot['art_no'] ?? 'Article';
          final desc = lot['article']?['description'] ?? lot['description'] ?? '';
          final challanNo = lot['challans']?['challan_no'] ?? '-';
          final brand = lot['challans']?['brand'] ?? 'OLLYPOP';
          final int passedQty = (lot['qc_total_passed'] as int?) ?? (lot['mending_received_qty'] as int?) ?? 0;
          final vars = lot['variants'] as List<dynamic>? ?? [];

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.green, width: 1.5),
              boxShadow: [
                BoxShadow(color: AppTheme.green.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 3)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: AppTheme.steelMist, borderRadius: BorderRadius.circular(6)),
                            child: Text(
                              'CH-$challanNo · $brand',
                              style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.steel),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: AppTheme.greenMist, borderRadius: BorderRadius.circular(6)),
                            child: Row(
                              children: [
                                const Icon(Icons.verified_rounded, size: 14, color: AppTheme.green),
                                const SizedBox(width: 4),
                                Text(
                                  'QC Passed: $passedQty pcs',
                                  style: GoogleFonts.jetBrainsMono(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.green),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Art #$artNo',
                        style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.ink),
                      ),
                      if (desc.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(desc, style: GoogleFonts.publicSans(fontSize: 12, color: AppTheme.inkSoft)),
                      ],
                    ],
                  ),
                ),

                if (vars.isNotEmpty) ...[
                  const Divider(height: 1, color: AppTheme.border),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: vars.map((v) {
                        final sz = v['size'] ?? '-';
                        final passQ = (v['qc_passed_qty'] as int?) ?? (lot['qc_total_passed'] as int?) ?? (v['allotted_qty'] as int? ?? (v['quantity'] as int? ?? 0));
                        final totalQ = (v['allotted_qty'] as int?) ?? (v['quantity'] as int? ?? 0);
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: AppTheme.greenMist, borderRadius: BorderRadius.circular(6)),
                          child: Text(
                            '$sz: $passQ / $totalQ pcs',
                            style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.green),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],

                const Divider(height: 1, color: AppTheme.border),

                // HANDOVER TO GODOWN (STORE INWARD) & CREATE DELIVERY CHALLAN BUTTONS
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      if ((lot['qc_status'] ?? '').toString() == 'PENDING_ADMIN_APPROVAL') ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.amberMist,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.amber.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.hourglass_top_rounded, color: AppTheme.amber, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Submitted for Admin Approval. Store Manager will collect after Admin authorizes.',
                                  style: GoogleFonts.publicSans(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.ink),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: double.infinity,
                          height: 42,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.pending_actions_rounded, size: 18, color: AppTheme.amber),
                            label: Text(
                              'Submitted (Awaiting Admin Approval)',
                              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.amber),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppTheme.amber, width: 1.2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: null,
                          ),
                        ),
                      ] else if ((lot['qc_status'] ?? '').toString() == 'APPROVED_FOR_STORE') ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.greenMist,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.green.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: AppTheme.green, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Admin Approved! Store Manager has been notified to collect.',
                                  style: GoogleFonts.publicSans(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.green),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.warehouse_rounded, size: 18, color: Colors.white),
                            label: Text(
                              'Handover to Godown (Store Inward Ready)',
                              style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.green,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                            onPressed: _isSubmitting ? null : () => _handoverToStore(lot),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 38,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.local_shipping_rounded, size: 16, color: AppTheme.steel),
                          label: Text(
                            'Direct Delivery Challan (Dispatch)',
                            style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.steel),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.steel, width: 1.1),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => _showDeliveryChallanModal(prefilledLot: lot),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),

        // Create General Delivery Challan Modal Action
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add_shopping_cart_rounded, size: 18, color: AppTheme.steel),
              label: Text(
                'Open General 8-Column Delivery Challan Sheet',
                style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.steel),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.steel, width: 1.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => _showDeliveryChallanModal(),
            ),
          ),
        ),
      ],
    );
  }

  // Handover finished lot to Godown Store Manager (Pending Admin Approval)
  Future<void> _handoverToStore(Map<String, dynamic> lot) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final authState = ref.read(authProvider);
    final qcUserName = authState.cachedUsername?.trim().isNotEmpty == true 
        ? authState.cachedUsername! 
        : (supabase.auth.currentUser?.email?.split('@').first ?? 'QC Supervisor');

    final aId = lot['id']?.toString();
    if (aId == null || aId.isEmpty) return;

    setState(() => _isSubmitting = true);
    try {
      await supabase.from('allotments').update({
        'qc_status': 'PENDING_ADMIN_APPROVAL',
        'store_inward_status': 'PENDING',
        'qc_supervisor_name': qcUserName,
        'qc_passed_at': DateTime.now().toIso8601String(),
      }).eq('id', aId);

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Handover submitted for Admin Approval! Once approved by Admin, Store Manager will be notified to collect ${lot['qc_total_passed'] ?? lot['target_qty']} pcs.'),
          backgroundColor: AppTheme.green,
        ),
      );
      await _fetchQcData();
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ====================================================
  // HELPER METRICS CARDS
  // ====================================================
  Widget _buildSummaryStat(String label, String value, IconData icon, {bool isAlert = false}) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: isAlert ? AppTheme.amber : Colors.white.withValues(alpha: 0.9)),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isAlert ? AppTheme.amber : Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.publicSans(fontSize: 10, color: Colors.white.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String val, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(6)),
        child: Column(
          children: [
            Text(label, style: GoogleFonts.publicSans(fontSize: 10, color: AppTheme.inkSoft)),
            const SizedBox(height: 2),
            Text(val, style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}
