import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/providers/auth_provider.dart';
import '../auth/screens/login_screen.dart';
import '../../core/theme/app_theme.dart';
import '../../../main.dart';

class LinemanDashboard extends ConsumerStatefulWidget {
  const LinemanDashboard({super.key});

  @override
  ConsumerState<LinemanDashboard> createState() => _LinemanDashboardState();
}

class _LinemanDashboardState extends ConsumerState<LinemanDashboard>
    with SingleTickerProviderStateMixin {
  // Named Constants
  static const int searchThreshold = 15;
  static const int overdueThresholdMinutes = 120;

  int _selectedTabIndex = 0; // 0: Live Floor, 1: Lot History

  bool _isLoading = true;
  List<dynamic> _activeMendingTasks = [];
  List<dynamic> _activeAllotments = [];
  List<dynamic> _completedAllotments = [];
  List<dynamic> _todayAssignments = [];
  List<String> _recentWorkerNames = [];
  int _totalTargetToday = 0;
  int _totalAssignedToday = 0;
  int _totalDoneToday = 0;

  // Search filters
  String _liveSearchQuery = '';
  String _historySearchQuery = '';
  final _liveSearchController = TextEditingController();
  final _historySearchController = TextEditingController();

  // First-time swipe hint state
  bool _showSwipeHint = true;

  // Shimmer animation controller
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController.unbounded(vsync: this)
      ..repeat(min: -0.5, max: 1.5, period: const Duration(milliseconds: 1200));

    _loadPreferences();
    _fetchDashboardData();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _liveSearchController.dispose();
    _historySearchController.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getBool('lineman_swipe_hint_dismissed') ?? false;
    if (mounted) {
      setState(() {
        _showSwipeHint = !dismissed;
      });
    }
  }

  Future<void> _dismissSwipeHint() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('lineman_swipe_hint_dismissed', true);
    if (mounted) {
      setState(() {
        _showSwipeHint = false;
      });
    }
  }

    Future<void> _fetchDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        final today = DateTime.now().toIso8601String().split('T')[0];
        final prefs = await SharedPreferences.getInstance();
        final List<String> archivedIds = prefs.getStringList('lineman_archived_lots') ?? [];

        // 1. Fetch ALL Allotments assigned to this lineman
        final allotmentsRes = await supabase
            .from('allotments')
            .select('''
              id,
              challan_id,
              target_qty,
              allotment_date,
              status,
              article_id,
              articles ( id, art_no, description, stitching_rate, size_rates ),
              challans ( id, challan_no, brand, fabric_type )
            ''')
            .eq('lineman_id', user.id)
            .order('allotment_date', ascending: false);

        final allAllotmentIds = allotmentsRes.map((a) => a['id'] as String).toList();

        // 2. Fetch variants for these allotments
        List<dynamic> variantsRes = [];
        if (allAllotmentIds.isNotEmpty) {
          try {
            variantsRes = await supabase
                .from('allotment_variants')
                .select('id, allotment_id, color, size, quantity, completed_qty')
                .inFilter('allotment_id', allAllotmentIds);
          } catch (e) {
            debugPrint('Variants fetch error: $e');
          }
        }

        // 3. Fetch materials checklist for allotments
        List<dynamic> materialsRes = [];
        if (allAllotmentIds.isNotEmpty) {
          try {
            materialsRes = await supabase
                .from('allotment_materials')
                .select('id, allotment_id, item_name, required_qty, admin_issued, lineman_received, lineman_received_at, notes')
                .inFilter('allotment_id', allAllotmentIds);
          } catch (e) {
            debugPrint('Materials fetch error: $e');
          }
        }

        // 4. Fetch all worker assignments for this lineman
        final allAssignmentsRes = await supabase
            .from('worker_assignments')
            .select('''
              id,
              allotment_id,
              worker_name,
              color,
              size,
              article_id,
              assigned_qty,
              completed_qty,
              status,
              notes,
              assigned_at,
              completed_at,
              entry_date,
              articles ( art_no, description )
            ''')
            .eq('lineman_id', user.id)
            .order('assigned_at', ascending: false);

        // Filter today's assignments for Live Floor
        final todayAssignments = allAssignmentsRes.where((a) => a['entry_date'] == today).toList();

        // Calculate Totals & Stats
        int assignedToday = 0;
        int doneToday = 0;
        final Map<String, int> assignedPerAllotment = {};
        final Map<String, int> donePerAllotment = {};
        final Set<String> distinctNames = {};

        for (var a in allAssignmentsRes) {
          final qty = (a['assigned_qty'] as int?) ?? 0;
          final allotId = a['allotment_id'] as String? ?? '';
          assignedPerAllotment[allotId] = (assignedPerAllotment[allotId] ?? 0) + qty;

          final name = a['worker_name'] as String?;
          if (name != null && name.trim().isNotEmpty) {
            distinctNames.add(name.trim());
          }

          if (a['status'] == 'DONE') {
            final cQty = (a['completed_qty'] as int?) ?? qty;
            donePerAllotment[allotId] = (donePerAllotment[allotId] ?? 0) + cQty;
          }
        }

        for (var a in todayAssignments) {
          final qty = (a['assigned_qty'] as int?) ?? 0;
          assignedToday += qty;
          if (a['status'] == 'DONE') {
            final cQty = (a['completed_qty'] as int?) ?? qty;
            doneToday += cQty;
          }
        }

        // Segregate Active vs Completed Allotments
        final List<dynamic> enrichedActive = [];
        final List<dynamic> enrichedCompleted = [];

        for (var a in allotmentsRes) {
          final aId = a['id'] as String;
          final status = (a['status'] as String? ?? '').toUpperCase();
          
          // Cancelled allotments are terminated by Admin/Manager and must NOT appear on the live sewing floor
          if (status == 'CANCELLED') {
            continue;
          }

          final assigned = assignedPerAllotment[aId] ?? 0;
          final done = donePerAllotment[aId] ?? 0;
          final isCompletedInDb = status == 'COMPLETED';
          final isArchivedLocally = archivedIds.contains(aId);

          final lotAssignments = allAssignmentsRes.where((ass) => ass['allotment_id'] == aId).toList();
          final lotVariants = variantsRes.where((v) => v['allotment_id'] == aId).toList();
          final lotMaterials = materialsRes.where((m) => m['allotment_id'] == aId).toList();

          final enriched = {
            ...a,
            'total_assigned': assigned,
            'total_done': done,
            'variants': lotVariants,
            'materials': lotMaterials,
            'assignments': lotAssignments,
          };

          if (isCompletedInDb || isArchivedLocally) {
            enrichedCompleted.add(enriched);
          } else {
            enrichedActive.add(enriched);
          }
        }

        // 5. Fetch active mending tasks assigned to this lineman from QC
        List<dynamic> activeMending = [];
        try {
          final mendingRes = await supabase
              .from('qc_logs')
              .select('''
                id,
                article_id,
                qty_rejected,
                defect_type,
                color,
                size,
                remarks,
                mending_status,
                entry_date,
                created_at,
                article:articles ( art_no, description )
              ''')
              .eq('from_lineman_id', user.id)
              .neq('mending_status', 'REPAIR_COMPLETED')
              .order('created_at', ascending: false);

          activeMending = mendingRes.where((m) => (m['qty_rejected'] as int? ?? 0) > 0).toList();
        } catch (e) {
          debugPrint('Mending fetch error: $e');
        }

        int totalTarget = 0;
        for (var a in enrichedActive) {
          totalTarget += (a['target_qty'] as int? ?? 0);
        }

        setState(() {
          _activeMendingTasks = activeMending;
          _activeAllotments = enrichedActive;
          _completedAllotments = enrichedCompleted;
          _todayAssignments = todayAssignments;
          _recentWorkerNames = distinctNames.toList();
          _totalTargetToday = totalTarget;
          _totalAssignedToday = assignedToday;
          _totalDoneToday = doneToday;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e'), backgroundColor: AppTheme.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ======= COMPLETE & ARCHIVE LOT TO HISTORY =======
  Future<void> _completeAllotment(dynamic allotment) async {
    final artNo = allotment['articles']?['art_no'] ?? 'Article';
    final target = allotment['target_qty'] ?? 0;
    final allotmentId = allotment['id'] as String;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.greenMist,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.check_circle_outline_rounded, color: AppTheme.green, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Handover to Mending Floor',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.ink),
              ),
            ),
          ],
        ),
        content: Text(
          'All $target pieces for Art: $artNo are stitched.\n\nWould you like to hand over this lot to Mending & Counting Floor?',
          style: GoogleFonts.publicSans(fontSize: 13, color: AppTheme.inkSoft, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Keep Active', style: GoogleFonts.publicSans(color: AppTheme.inkSoft, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Handover to Mending', style: GoogleFonts.publicSans(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Save to persistent archived list
        final prefs = await SharedPreferences.getInstance();
        final List<String> archived = prefs.getStringList('lineman_archived_lots') ?? [];
        if (!archived.contains(allotmentId)) {
          archived.add(allotmentId);
          await prefs.setStringList('lineman_archived_lots', archived);
        }

        // Also update Supabase database status and notify Mending
        try {
          await supabase
              .from('allotments')
              .update({
                'status': 'COMPLETED',
                'mending_status': 'PENDING_MENDING',
              })
              .eq('id', allotmentId);
        } catch (dbErr) {
          debugPrint('Supabase update status warning: $dbErr');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✓ Art: $artNo handed over to Mending Floor!'),
              backgroundColor: AppTheme.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          _fetchDashboardData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error archiving lot: $e'), backgroundColor: AppTheme.red),
          );
        }
      }
    }
  }

  
  // Helper to parse inspection notes
  Map<String, dynamic>? _parseInspectionNotes(dynamic notes) {
    if (notes == null) return null;
    try {
      final str = notes.toString();
      if (str.startsWith('{') && str.endsWith('}')) {
        // Extract fields via Regex
        String? receivedQty;
        String? status;
        String? shortageQty;
        String? challanNo;
        String? remarks;

        final mRec = RegExp(r'"received_qty":"(.*?)"').firstMatch(str);
        if (mRec != null) receivedQty = mRec.group(1);

        final mStat = RegExp(r'"status":"(.*?)"').firstMatch(str);
        if (mStat != null) status = mStat.group(1);

        final mShort = RegExp(r'"shortage_qty":"(.*?)"').firstMatch(str);
        if (mShort != null) shortageQty = mShort.group(1);

        final mChal = RegExp(r'"supplier_challan_no":"(.*?)"').firstMatch(str);
        if (mChal != null) challanNo = mChal.group(1);

        final mRem = RegExp(r'"store_remarks":"(.*?)"').firstMatch(str);
        if (mRem != null) remarks = mRem.group(1);

        return {
          'received_qty': receivedQty,
          'status': status ?? 'VERIFIED',
          'shortage_qty': shortageQty,
          'supplier_challan_no': challanNo,
          'store_remarks': remarks,
        };
      }
    } catch (_) {}
    return null;
  }


  void showSampleImageZoom(BuildContext context, String imageUrl, String tag) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: imageUrl.startsWith('http')
                    ? Image.network(imageUrl, fit: BoxFit.contain)
                    : (imageUrl.startsWith('data:image')
                        ? Image.memory(
                            const Base64Decoder().convert(imageUrl.split(',').last),
                            fit: BoxFit.contain,
                          )
                        : Image.network(imageUrl, fit: BoxFit.contain)),
              ),
            ),
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)),
                child: Text(tag, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ======= MATERIAL HANDOVER VERIFICATION =======
  Future<void> _confirmMaterialReceipt(dynamic allotment) async {
    final materials = (allotment['materials'] as List<dynamic>?) ?? [];
    if (materials.isEmpty) return;

    // Find supplier challan from notes if available
    String? challanNo;
    for (var m in materials) {
      final ins = _parseInspectionNotes(m['notes']);
      if (ins?['supplier_challan_no'] != null && (ins!['supplier_challan_no'] as String).isNotEmpty) {
        challanNo = ins['supplier_challan_no'];
        break;
      }
    }

    final confirm = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.greenMist,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.inventory_2_rounded, color: AppTheme.green, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Floor Material Handover Verification',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.ink,
                          ),
                        ),
                        Text(
                          'Article: ${allotment['articles']?['art_no'] ?? ''} • Target: ${allotment['target_qty']} pcs',
                          style: GoogleFonts.publicSans(fontSize: 12.5, color: AppTheme.inkFaint),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              if (challanNo != null && challanNo.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.receipt_long_rounded, size: 16, color: AppTheme.steelDark),
                      const SizedBox(width: 6),
                      Text(
                        'Supplier Challan / Bill #: $challanNo',
                        style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.steelDark),
                      ),
                    ],
                  ),
                ),

              Text(
                'Store Godown has inspected and issued the following raw materials. Please verify physical count on sewing floor:',
                style: GoogleFonts.publicSans(fontSize: 13, color: AppTheme.inkSoft, height: 1.4),
              ),
              const SizedBox(height: 14),

              // Materials List with Store Inspection details
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: materials.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.border),
                  itemBuilder: (_, idx) {
                    final mat = materials[idx];
                    final ins = _parseInspectionNotes(mat['notes']);
                    final isShortage = ins?['status'] == 'SHORTAGE' || ins?['status'] == 'DEFECTIVE';
                    final received = ins?['received_qty'] ?? mat['required_qty'];

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isShortage ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
                                color: isShortage ? AppTheme.amber : AppTheme.green,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  mat['item_name'] ?? 'Item',
                                  style: GoogleFonts.publicSans(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.ink),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isShortage ? const Color(0xFFFEF3C7) : AppTheme.steelMist,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Req: ${mat['required_qty']}',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isShortage ? const Color(0xFFB45309) : AppTheme.steelDark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (isShortage) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFFBEB),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFFDE68A)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFFD97706)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Store Count: $received ${ins?['shortage_qty'] != null ? "(${ins!['shortage_qty']})" : ""}',
                                      style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF92400E)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(ctx, true),
                  icon: const Icon(Icons.verified_rounded, size: 18),
                  label: const Text('Confirm & Acknowledge Material Received'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm == true) {
      try {
        final nowIso = DateTime.now().toUtc().toIso8601String();
        await supabase
            .from('allotment_materials')
            .update({
              'lineman_received': true,
              'lineman_received_at': nowIso,
            })
            .eq('allotment_id', allotment['id']);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Raw materials verified & acknowledged!'),
              backgroundColor: AppTheme.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          _fetchDashboardData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.red),
          );
        }
      }
    }
  }

  // ======= ASSIGN WORKER DIALOG =======
  void _showAssignWorkerDialog(dynamic allotment) {
    final materials = (allotment['materials'] as List<dynamic>?) ?? [];
    final hasMaterials = materials.isNotEmpty;
    final materialsConfirmed = hasMaterials && materials.every((m) => m['lineman_received'] == true);

    if (hasMaterials && !materialsConfirmed) {
      final isStoreIssued = materials.every((m) {
        final ins = _parseInspectionNotes(m['notes']);
        return m['admin_issued'] == true || ins?['store_verified'] == true;
      });

      if (isStoreIssued) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please verify & receive raw materials from Store first.'),
            backgroundColor: AppTheme.amber,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _confirmMaterialReceipt(allotment);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Raw materials have not been issued by Store Godown yet.'),
            backgroundColor: AppTheme.amber,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final workerNameController = TextEditingController();
    final qtyController = TextEditingController();
    final notesController = TextEditingController();

    final target = (allotment['target_qty'] as int?) ?? 0;
    final alreadyAssigned = (allotment['total_assigned'] as int?) ?? 0;
    final remaining = target - alreadyAssigned;

    final variants = (allotment['variants'] as List<dynamic>?) ?? [];
    final assignments = (allotment['assignments'] as List<dynamic>?) ?? [];

    final Set<String> colorSet = {};
    final Set<String> sizeSet = {};
    for (var v in variants) {
      final c = v['color']?.toString() ?? '';
      final s = v['size']?.toString() ?? '';
      if (c.isNotEmpty) colorSet.add(c);
      if (s.isNotEmpty) sizeSet.add(s);
    }

    final colorsList = colorSet.toList();
    final sizesList = sizeSet.toList();

    String selectedColor = colorsList.isNotEmpty ? colorsList.first : 'Default';
    String selectedSize = sizesList.isNotEmpty ? sizesList.first : 'Standard';
    String selectedMachineStation = 'OVERLOCK';
    bool isBorrowedWorker = false;
    String borrowedFromLine = 'Line 2 (Suman)';

    int getVariantTarget(String color, String size) {
      return variants
          .where((v) => (v['color']?.toString().toLowerCase().trim() == color.toLowerCase().trim()) &&
                        (v['size']?.toString().toLowerCase().trim() == size.toLowerCase().trim()))
          .fold<int>(0, (sum, v) => sum + ((v['quantity'] as int?) ?? 0));
    }

    int getVariantAssigned(String color, String size) {
      return assignments
          .where((a) => (a['color']?.toString().toLowerCase().trim() == color.toLowerCase().trim()) &&
                        (a['size']?.toString().toLowerCase().trim() == size.toLowerCase().trim()))
          .fold<int>(0, (sum, a) => sum + ((a['assigned_qty'] as int?) ?? 0));
    }

    int getVariantRemaining(String color, String size) {
      final t = getVariantTarget(color, size);
      final a = getVariantAssigned(color, size);
      return (t - a).clamp(0, t > 0 ? t : 99999);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final mediaQuery = MediaQuery.of(context);
          return Container(
            constraints: BoxConstraints(
              maxHeight: mediaQuery.size.height * 0.88,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              bottom: mediaQuery.viewInsets.bottom,
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Drag Handle & Title Bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
                    child: Column(
                      children: [
                        Center(
                          child: Container(
                            width: 38,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppTheme.border,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.steelMist,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.person_add_alt_1_rounded, color: AppTheme.steel, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Assign Batch',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16.5,
                                      color: AppTheme.ink,
                                    ),
                                  ),
                                  Text(
                                    'Art No: ${allotment['articles']?['art_no'] ?? ''}',
                                    style: GoogleFonts.publicSans(
                                      fontSize: 12,
                                      color: AppTheme.inkSoft,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(ctx),
                              icon: const Icon(Icons.close_rounded, color: AppTheme.inkSoft),
                              tooltip: 'Close',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1, color: AppTheme.border),

                  // Scrollable Form Fields
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Target & Remaining Info Card (Harmonious Brand Neutral)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: AppTheme.bg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'TOTAL TARGET',
                                        style: GoogleFonts.publicSans(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.8,
                                          color: AppTheme.inkFaint,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$target pcs',
                                        style: GoogleFonts.jetBrainsMono(
                                          color: AppTheme.ink,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(width: 1, height: 28, color: AppTheme.border),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'REMAINING',
                                        style: GoogleFonts.publicSans(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.8,
                                          color: AppTheme.inkFaint,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$remaining pcs',
                                        style: GoogleFonts.jetBrainsMono(
                                          color: remaining > 0 ? AppTheme.steel : AppTheme.green,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Worker Name Input (Simplified without redundant tag)
                          Autocomplete<String>(
                            optionsBuilder: (TextEditingValue textEditingValue) {
                              if (textEditingValue.text.isEmpty) return _recentWorkerNames;
                              return _recentWorkerNames.where((String option) => option.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                            },
                            onSelected: (String selection) => workerNameController.text = selection,
                            fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                              return TextField(
                                controller: textEditingController,
                                focusNode: focusNode,
                                decoration: const InputDecoration(
                                  hintText: 'Enter the name',
                                  prefixIcon: Icon(Icons.person_outline, size: 20, color: AppTheme.steel),
                                ),
                                onChanged: (val) => workerNameController.text = val,
                              );
                            },
                          ),
                          const SizedBox(height: 12),

                          // Borrow Worker from Another Line Toggle
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isBorrowedWorker ? AppTheme.steelMist : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isBorrowedWorker ? AppTheme.steelTint : AppTheme.border,
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.swap_horiz_rounded,
                                            size: 17,
                                            color: isBorrowedWorker ? AppTheme.steel : AppTheme.inkSoft,
                                          ),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Text(
                                              'Borrow Tailor from Other Line',
                                              style: GoogleFonts.publicSans(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: isBorrowedWorker ? AppTheme.steel : AppTheme.inkSoft,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Transform.scale(
                                      scale: 0.8,
                                      child: Switch(
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        value: isBorrowedWorker,
                                        activeColor: AppTheme.steel,
                                        onChanged: (val) => setDialogState(() => isBorrowedWorker = val),
                                      ),
                                    ),
                                  ],
                                ),
                                if (isBorrowedWorker) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Text(
                                        'Borrowed from: ',
                                        style: GoogleFonts.publicSans(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.steelDark),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: AppTheme.border),
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              value: borrowedFromLine,
                                              isExpanded: true,
                                              items: [
                                                'Line 1 (Om)',
                                                'Line 2 (Suman)',
                                                'Line 3 (Sachin)',
                                                'Line 4 (Sarthak)',
                                                'Outside Contract'
                                              ].map((l) => DropdownMenuItem(value: l, child: Text(l, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)))).toList(),
                                              onChanged: (v) {
                                                if (v != null) setDialogState(() => borrowedFromLine = v);
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),

                          const SizedBox(height: 14),

                          // Color Variant Picker
                          if (colorsList.isNotEmpty) ...[
                            Text('COLOR VARIANT', style: GoogleFonts.publicSans(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: AppTheme.inkSoft)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              value: selectedColor,
                              isExpanded: true,
                              decoration: const InputDecoration(prefixIcon: Icon(Icons.palette_outlined, size: 20, color: AppTheme.steel)),
                              items: colorsList.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontWeight: FontWeight.w600)))).toList(),
                              onChanged: (val) {
                                if (val != null) setDialogState(() => selectedColor = val);
                              },
                            ),
                            const SizedBox(height: 14),
                          ],

                          // Size Ratio Picker with Admin Target & Remaining breakdown
                          if (sizesList.isNotEmpty) ...[
                            Text('SIZE RATIO & TARGET', style: GoogleFonts.publicSans(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: AppTheme.inkSoft)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              value: selectedSize,
                              isExpanded: true,
                              decoration: const InputDecoration(prefixIcon: Icon(Icons.straighten_rounded, size: 20, color: AppTheme.steel)),
                              items: sizesList.map((s) {
                                final sTarget = getVariantTarget(selectedColor, s);
                                final sLeft = getVariantRemaining(selectedColor, s);
                                final label = sTarget > 0 ? '$s • $sLeft left (of $sTarget pcs)' : s;
                                return DropdownMenuItem(
                                  value: s,
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: sLeft == 0 && sTarget > 0 ? AppTheme.inkFaint : AppTheme.ink,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setDialogState(() => selectedSize = val);
                              },
                            ),
                            const SizedBox(height: 12),

                            // Dedicated Size Target Highlight Card (Calm Neutral Design)
                            () {
                              final curTarget = getVariantTarget(selectedColor, selectedSize);
                              final curAssigned = getVariantAssigned(selectedColor, selectedSize);
                              final curLeft = getVariantRemaining(selectedColor, selectedSize);

                              if (curTarget <= 0) return const SizedBox.shrink();

                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: AppTheme.bg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppTheme.border),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Admin Target: $selectedColor ($selectedSize)',
                                            style: GoogleFonts.publicSans(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.ink,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Target: $curTarget pcs • Assigned: $curAssigned pcs',
                                            style: GoogleFonts.publicSans(fontSize: 10, color: AppTheme.inkSoft),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: curLeft > 0 ? AppTheme.steelMist : AppTheme.greenMist,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: curLeft > 0 ? AppTheme.steelTint : AppTheme.green.withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Text(
                                        '$curLeft left',
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                          color: curLeft > 0 ? AppTheme.steel : AppTheme.green,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }(),
                          ],

                          // Quantity Input
                          Text('PIECES TO ASSIGN (QTY)', style: GoogleFonts.publicSans(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: AppTheme.inkSoft)),
                          const SizedBox(height: 6),
                          () {
                            final curTarget = getVariantTarget(selectedColor, selectedSize);
                            final curLeft = getVariantRemaining(selectedColor, selectedSize);
                            final maxLimit = curTarget > 0 ? curLeft : remaining;

                            return TextField(
                              controller: qtyController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: curTarget > 0 ? 'Max $maxLimit pcs (Size $selectedSize remaining)' : 'Max $remaining pcs',
                                prefixIcon: const Icon(Icons.format_list_numbered_rounded, size: 20, color: AppTheme.steel),
                              ),
                            );
                          }(),
                          const SizedBox(height: 14),

                          // Machine Operation / Station Selector (Harmonious Brand Design - No Rainbow!)
                          Text('MACHINE OPERATION / STITCHING STAGE', style: GoogleFonts.publicSans(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: AppTheme.inkSoft)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              {
                                'key': 'OVERLOCK',
                                'label': 'Overlock (4-Th)',
                                'icon': Icons.tune_rounded,
                              },
                              {
                                'key': 'FIVE_THREAD',
                                'label': '5-Thread Safety',
                                'icon': Icons.linear_scale_rounded,
                              },
                              {
                                'key': 'FLATLOCK',
                                'label': 'Flatlock / Rib',
                                'icon': Icons.view_headline_rounded,
                              },
                              {
                                'key': 'LOCKING',
                                'label': 'Locking / Single',
                                'icon': Icons.lock_outline_rounded,
                              },
                            ].map((st) {
                              final isSel = selectedMachineStation == st['key'];
                              return GestureDetector(
                                onTap: () => setDialogState(() => selectedMachineStation = st['key'] as String),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSel ? AppTheme.steelMist : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSel ? AppTheme.steel : AppTheme.border,
                                      width: isSel ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        st['icon'] as IconData,
                                        size: 14,
                                        color: isSel ? AppTheme.steel : AppTheme.inkFaint,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        st['label'] as String,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                          color: isSel ? AppTheme.steel : AppTheme.ink,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 14),

                          // Notes
                          Text('NOTES / INSTRUCTIONS (OPTIONAL)', style: GoogleFonts.publicSans(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: AppTheme.inkSoft)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: notesController,
                            decoration: const InputDecoration(
                              hintText: 'e.g. Collar stitch only',
                              prefixIcon: Icon(Icons.notes_rounded, size: 20, color: AppTheme.steel),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Pinned Bottom Action Bar (Never cut off or hidden)
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: AppTheme.border)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              side: const BorderSide(color: AppTheme.border),
                            ),
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.publicSans(color: AppTheme.inkSoft, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.steel,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            onPressed: () async {
                              final name = workerNameController.text.trim();
                              final qtyStr = qtyController.text.trim();
                              final qty = int.tryParse(qtyStr) ?? 0;

                              if (name.isEmpty || qty <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please enter a valid worker name and quantity (>0).'), backgroundColor: AppTheme.red),
                                );
                                return;
                              }

                              if (qty > remaining) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Quantity ($qty) exceeds remaining allotment target ($remaining pcs).'), backgroundColor: AppTheme.red),
                                );
                                return;
                              }

                              Navigator.pop(ctx);
                              final noteText = notesController.text.trim();
                              String fullNotes = '[$selectedMachineStation]';
                              if (isBorrowedWorker) {
                                fullNotes += ' [BORROWED: $borrowedFromLine]';
                              }
                              if (noteText.isNotEmpty) {
                                fullNotes += ' $noteText';
                              }
                              fullNotes = fullNotes.trim();
                              await _submitWorkerAssignment(
                                allotmentId: allotment['id'],
                                articleId: allotment['article_id'],
                                workerName: name,
                                qty: qty,
                                color: selectedColor,
                                size: selectedSize,
                                notes: fullNotes,
                              );
                            },
                            child: Text('Assign Batch', style: GoogleFonts.publicSans(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
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

  Future<void> _submitWorkerAssignment({
    required String allotmentId,
    required String articleId,
    required String workerName,
    required int qty,
    required String color,
    required String size,
    required String notes,
  }) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final today = DateTime.now().toIso8601String().split('T')[0];
      final nowIso = DateTime.now().toUtc().toIso8601String();

      await supabase.from('worker_assignments').insert({
        'allotment_id': allotmentId,
        'lineman_id': user.id,
        'article_id': articleId,
        'worker_name': workerName,
        'assigned_qty': qty,
        'color': color,
        'size': size,
        'status': 'PENDING',
        'notes': notes.isNotEmpty ? notes : null,
        'assigned_at': nowIso,
        'entry_date': today,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Assigned $qty pcs to $workerName'),
            backgroundColor: AppTheme.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _fetchDashboardData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error assigning worker: $e'), backgroundColor: AppTheme.red),
        );
      }
    }
  }

  // ======= MARK AS DONE (WITH UNDO SUPPORT) =======
  Future<void> _markAsDone(dynamic a) async {
    final assignmentId = a['id'];
    final workerName = a['worker_name'] ?? 'Worker';
    final qty = (a['assigned_qty'] as int?) ?? 0;

    // Permanently dismiss swipe hint on first swipe action
    if (_showSwipeHint) {
      _dismissSwipeHint();
    }

    try {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      await supabase.from('worker_assignments').update({
        'status': 'DONE',
        'completed_qty': qty,
        'completed_at': nowIso,
      }).eq('id', assignmentId);

      _fetchDashboardData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Marked $workerName's batch as done"),
            duration: const Duration(seconds: 4),
            backgroundColor: AppTheme.steelDark,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'UNDO',
              textColor: AppTheme.amber,
              onPressed: () async {
                try {
                  await supabase.from('worker_assignments').update({
                    'status': 'PENDING',
                    'completed_at': null,
                  }).eq('id', assignmentId);
                  _fetchDashboardData();
                } catch (err) {
                  debugPrint('Failed to undo: $err');
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating status: $e'), backgroundColor: AppTheme.red),
        );
      }
    }
  }

  // ======= EDIT ASSIGNMENT =======
  void _editAssignment(dynamic a) {
    final qtyController = TextEditingController(text: '${a['assigned_qty'] ?? 0}');
    final notesController = TextEditingController(text: a['notes'] ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        title: Text('Edit Assignment - ${a['worker_name']}', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ASSIGNED PIECES', style: GoogleFonts.publicSans(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppTheme.inkSoft)),
            const SizedBox(height: 6),
            TextField(
              controller: qtyController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.format_list_numbered_rounded, size: 20, color: AppTheme.steel)),
            ),
            const SizedBox(height: 14),
            Text('NOTES', style: GoogleFonts.publicSans(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppTheme.inkSoft)),
            const SizedBox(height: 6),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.notes_rounded, size: 20, color: AppTheme.steel)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.publicSans(color: AppTheme.inkSoft, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.steel, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () async {
              final newQty = int.tryParse(qtyController.text.trim()) ?? 0;
              if (newQty <= 0) return;
              Navigator.pop(ctx);
              try {
                await supabase.from('worker_assignments').update({
                  'assigned_qty': newQty,
                  'notes': notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
                }).eq('id', a['id']);
                _fetchDashboardData();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.red));
                }
              }
            },
            child: Text('Save Changes', style: GoogleFonts.publicSans(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ======= DELETE ASSIGNMENT =======
  void _deleteAssignment(dynamic a) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        title: Text('Delete Assignment?', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.red)),
        content: Text('Are you sure you want to remove the assignment for ${a['worker_name']} (${a['assigned_qty']} pcs)?', style: GoogleFonts.publicSans(fontSize: 13, color: AppTheme.inkSoft)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.publicSans(color: AppTheme.inkSoft))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await supabase.from('worker_assignments').delete().eq('id', a['id']);
                _fetchDashboardData();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.red));
                }
              }
            },
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ======= SHOW LOT HISTORY BREAKDOWN MODAL =======
  void _showLotHistoryDetailsSheet(dynamic lot) {
    final art = lot['articles'];
    final target = (lot['target_qty'] as int?) ?? 0;
    final lotAssignments = (lot['assignments'] as List<dynamic>?) ?? [];
    final allotmentDate = lot['allotment_date'] ?? '-';

    // Group worker pieces
    final Map<String, int> workerTotalPieces = {};
    final Map<String, List<dynamic>> workerEntries = {};

    for (var ass in lotAssignments) {
      final name = ass['worker_name'] ?? 'Worker';
      final qty = (ass['completed_qty'] as int?) ?? ((ass['assigned_qty'] as int?) ?? 0);
      workerTotalPieces[name] = (workerTotalPieces[name] ?? 0) + qty;
      workerEntries.putIfAbsent(name, () => []).add(ass);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.greenMist,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.inventory_rounded, color: AppTheme.green, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Art No: ${art?['art_no'] ?? '-'}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.ink,
                          ),
                        ),
                        Text(
                          art?['description'] ?? 'Garment Lot History',
                          style: GoogleFonts.publicSans(fontSize: 12.5, color: AppTheme.inkSoft),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.greenMist,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Completed',
                      style: GoogleFonts.publicSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.green,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Summary Stats Box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('TARGET PIECES', style: GoogleFonts.publicSans(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.inkSoft)),
                          const SizedBox(height: 2),
                          Text('$target pcs', style: GoogleFonts.jetBrainsMono(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.steelDark)),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 32, color: AppTheme.border),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('COMPLETED DATE', style: GoogleFonts.publicSans(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.inkSoft)),
                          const SizedBox(height: 2),
                          Text(allotmentDate, style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.ink)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Tailor Piece Contribution Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tailor Piece Contribution',
                    style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.ink),
                  ),
                  Text(
                    '${workerTotalPieces.length} tailors',
                    style: GoogleFonts.jetBrainsMono(fontSize: 11.5, color: AppTheme.inkFaint),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (workerTotalPieces.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.bg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text('No worker entries logged for this lot.', style: GoogleFonts.publicSans(fontSize: 12.5, color: AppTheme.inkSoft)),
                  ),
                )
              else
                ...workerTotalPieces.entries.map((w) {
                  final workerName = w.key;
                  final totalPieces = w.value;
                  final entries = workerEntries[workerName] ?? [];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: AppTheme.steelMist,
                              child: const Icon(Icons.person_rounded, color: AppTheme.steel, size: 16),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                workerName,
                                style: GoogleFonts.publicSans(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppTheme.ink),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.greenMist,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '$totalPieces pcs',
                                style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w700, fontSize: 12, color: AppTheme.green),
                              ),
                            ),
                          ],
                        ),
                        if (entries.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Divider(height: 1, color: AppTheme.border),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: entries.map((e) {
                              final col = e['color'] ?? '';
                              final sz = e['size'] ?? '';
                              final q = e['completed_qty'] ?? e['assigned_qty'] ?? 0;
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.bg,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '$col $sz: $q pcs',
                                  style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppTheme.inkSoft),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  // ======= OVERDUE TIME CALCULATION =======
  bool _isOverdue(String? assignedAt) {
    if (assignedAt == null) return false;
    try {
      final dt = DateTime.parse(assignedAt).toLocal();
      return DateTime.now().difference(dt).inMinutes >= overdueThresholdMinutes;
    } catch (_) {
      return false;
    }
  }

  Widget _buildTimeSinceAssigned(String? assignedAt, String status) {
    if (status == 'DONE') return const SizedBox.shrink();
    if (assignedAt == null) {
      return Text('-', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppTheme.inkFaint));
    }

    try {
      final dt = DateTime.parse(assignedAt).toLocal();
      final diff = DateTime.now().difference(dt);
      final minutes = diff.inMinutes;

      if (minutes < 60) {
        return Text(
          '${minutes}m ago',
          style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppTheme.inkFaint, fontWeight: FontWeight.w400),
        );
      } else if (minutes < overdueThresholdMinutes) {
        final h = minutes ~/ 60;
        final m = minutes % 60;
        return Text(
          '${h}h ${m}m ago',
          style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppTheme.amber, fontWeight: FontWeight.w600),
        );
      } else {
        final h = minutes ~/ 60;
        final m = minutes % 60;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.schedule_rounded, size: 12, color: AppTheme.red),
            const SizedBox(width: 3),
            Text(
              '${h}h ${m}m ago — overdue',
              style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppTheme.red, fontWeight: FontWeight.w700),
            ),
          ],
        );
      }
    } catch (_) {
      return Text('-', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppTheme.inkFaint));
    }
  }

  String _formatTime(String? isoTime) {
    if (isoTime == null) return '-';
    try {
      final dt = DateTime.parse(isoTime).toLocal();
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final amPm = dt.hour >= 12 ? 'PM' : 'AM';
      return '${hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $amPm';
    } catch (_) {
      return '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    final userName = user?.email?.split('@')[0] ?? 'Lineman';

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        toolbarHeight: 68,
        titleSpacing: 18,
        backgroundColor: AppTheme.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    'Welcome, $userName',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.ink,
                      letterSpacing: -0.4,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                const _WavingHandIcon(size: 20),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              'Line Supervisor • Active Floor Shift',
              style: GoogleFonts.publicSans(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.inkSoft,
              ),
            ),
          ],
        ),
        actions: [
          // Interactive Resync / Refresh button
          Tooltip(
            message: 'Resync Floor Data',
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _fetchDashboardData,
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.border),
                ),
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
          // Clean Logout Button
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
          ? _buildAnimatedSkeletonLoading()
          : RefreshIndicator(
              color: AppTheme.steel,
              onRefresh: _fetchDashboardData,
              child: _selectedTabIndex == 0 ? _buildLiveFloorTab() : _buildLotHistoryTab(),
            ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppTheme.border, width: 1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                // Tab 0: Live Floor
                Expanded(
                  child: _buildBottomNavButton(
                    index: 0,
                    icon: Icons.precision_manufacturing_rounded,
                    label: 'Live Floor',
                    badgeCount: _activeAllotments.length,
                  ),
                ),
                const SizedBox(width: 12),
                // Tab 1: Lot History
                Expanded(
                  child: _buildBottomNavButton(
                    index: 1,
                    icon: Icons.history_rounded,
                    label: 'Lot History',
                    badgeCount: _completedAllotments.length,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavButton({
    required int index,
    required IconData icon,
    required String label,
    int? badgeCount,
  }) {
    final isSelected = _selectedTabIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedTabIndex = index),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.steelMist : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: isSelected ? AppTheme.steel : AppTheme.inkFaint,
                ),
                if (badgeCount != null && badgeCount > 0)
                  Positioned(
                    right: -8,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.steel : AppTheme.inkSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$badgeCount',
                        style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.publicSans(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppTheme.steel : AppTheme.inkFaint,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // TAB 1: LIVE FLOOR (ACTIVE ALLOTMENTS & TODAY'S ASSIGNMENTS)
  // =========================================================================
  Widget _buildLiveFloorTab() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Stats (Today's Shift)
          _AnimatedFadeSlide(
            delayMs: 30,
            child: Row(
              children: [
                _buildStatCard(
                  'Floor Target',
                  '$_totalTargetToday',
                  Icons.assignment_rounded,
                  AppTheme.steel,
                  unit: 'pcs',
                  subtitle: '$_totalAssignedToday pcs with workers',
                ),
                const SizedBox(width: 12),
                _buildStatCard(
                  'Work Done Today',
                  '$_totalDoneToday',
                  Icons.check_circle_rounded,
                  AppTheme.green,
                  unit: 'pcs',
                  subtitle: '${_totalTargetToday > 0 ? ((_totalDoneToday / _totalTargetToday) * 100).toStringAsFixed(0) : 0}% completed',
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Mending & Repairs from QC (If Any)
          if (_activeMendingTasks.isNotEmpty) ...[
            _AnimatedFadeSlide(
              delayMs: 70,
              child: _buildMendingTasksSection(),
            ),
            const SizedBox(height: 24),
          ],

          // Active Allotments Section
          _AnimatedFadeSlide(
            delayMs: 100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Active Allotments',
                  style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.ink, letterSpacing: -0.3),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.greenMist,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.green.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppTheme.green, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text(
                        'Live Floor (${_activeAllotments.length})',
                        style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.green),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          if (_activeAllotments.isEmpty)
            _AnimatedFadeSlide(delayMs: 150, child: _buildNoAllotmentEmptyState())
          else
            ..._activeAllotments.map((a) => _AnimatedFadeSlide(delayMs: 160, child: _buildActiveAllotmentCard(a))),

          const SizedBox(height: 20),

          // Worker Assignments Section
          _AnimatedFadeSlide(
            delayMs: 200,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Today's Batches",
                  style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.ink),
                ),
                Text(
                  '${_todayAssignments.length} batches',
                  style: GoogleFonts.jetBrainsMono(fontSize: 11.5, color: AppTheme.inkFaint),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // First-time swipe hint
          if (_showSwipeHint && _todayAssignments.isNotEmpty) ...[
            _AnimatedFadeSlide(
              delayMs: 220,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppTheme.steelMist,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.steelTint),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.swipe_right_rounded, size: 16, color: AppTheme.steel),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tip: Swipe any worker card right to mark batch as done',
                        style: GoogleFonts.publicSans(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.steelDark),
                      ),
                    ),
                    GestureDetector(
                      onTap: _dismissSwipeHint,
                      child: const Icon(Icons.close_rounded, size: 16, color: AppTheme.inkFaint),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Conditional Search Bar
          if (_todayAssignments.length >= searchThreshold) ...[
            _AnimatedFadeSlide(
              delayMs: 240,
              child: TextField(
                controller: _liveSearchController,
                onChanged: (val) => setState(() => _liveSearchQuery = val.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search worker or article...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppTheme.steel),
                  suffixIcon: _liveSearchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18, color: AppTheme.inkFaint),
                          onPressed: () {
                            _liveSearchController.clear();
                            setState(() => _liveSearchQuery = '');
                          },
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Grouped Assignments
          _buildGroupedAssignmentLists(),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 2: LOT HISTORY (PAST COMPLETED LOTS & WORKER BREAKDOWN)
  // =========================================================================
  Widget _buildLotHistoryTab() {
    var historyList = _completedAllotments;
    if (_historySearchQuery.isNotEmpty) {
      historyList = historyList.where((lot) {
        final artNo = (lot['articles']?['art_no'] as String? ?? '').toLowerCase();
        final desc = (lot['articles']?['description'] as String? ?? '').toLowerCase();
        return artNo.contains(_historySearchQuery) || desc.contains(_historySearchQuery);
      }).toList();
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lot History',
                      style: GoogleFonts.plusJakartaSans(fontSize: 19, fontWeight: FontWeight.w700, color: AppTheme.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Completed allotments & worker hisab',
                      style: GoogleFonts.publicSans(fontSize: 12, color: AppTheme.inkSoft),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.steelMist,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.steelTint),
                ),
                child: Text(
                  '${_completedAllotments.length} Completed',
                  style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.steelDark),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Search Field
          TextField(
            controller: _historySearchController,
            onChanged: (val) => setState(() => _historySearchQuery = val.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Search by Art No or style...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppTheme.steel),
              suffixIcon: _historySearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18, color: AppTheme.inkFaint),
                      onPressed: () {
                        _historySearchController.clear();
                        setState(() => _historySearchQuery = '');
                      },
                    )
                  : null,
            ),
          ),

          const SizedBox(height: 16),

          if (historyList.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.bg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.history_toggle_off_rounded, size: 28, color: AppTheme.inkFaint),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No completed lots found',
                    style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.ink),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Completed allotments will appear here with full tailor breakdowns.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.publicSans(fontSize: 12.5, color: AppTheme.inkSoft),
                  ),
                ],
              ),
            )
          else
            ...historyList.map((lot) => _buildCompletedLotHistoryCard(lot)),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildCompletedLotHistoryCard(dynamic lot) {
    final art = lot['articles'];
    final target = lot['target_qty'] ?? 0;
    final date = lot['allotment_date'] ?? '-';
    final assignments = (lot['assignments'] as List<dynamic>?) ?? [];

    // Distinct worker names
    final Set<String> workers = {};
    for (var ass in assignments) {
      final name = ass['worker_name'] as String?;
      if (name != null && name.isNotEmpty) workers.add(name);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
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
                        'Art No: ${art?['art_no'] ?? '-'}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        art?['description'] ?? 'Garment Style',
                        style: GoogleFonts.publicSans(fontSize: 12, color: AppTheme.inkSoft),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.greenMist,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '100% Done',
                    style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.green),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppTheme.border),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 13, color: AppTheme.inkFaint),
                const SizedBox(width: 4),
                Text('Date: $date', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppTheme.inkFaint)),
                const SizedBox(width: 14),
                const Icon(Icons.layers_outlined, size: 13, color: AppTheme.inkFaint),
                const SizedBox(width: 4),
                Text('Target: $target pcs', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppTheme.inkFaint)),
              ],
            ),
            if (workers.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.people_outline_rounded, size: 14, color: AppTheme.steel),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Tailors: ${workers.join(', ')}',
                      style: GoogleFonts.publicSans(fontSize: 11.5, color: AppTheme.inkSoft, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 38,
              child: OutlinedButton.icon(
                onPressed: () => _showLotHistoryDetailsSheet(lot),
                icon: const Icon(Icons.visibility_outlined, size: 16, color: AppTheme.steel),
                label: Text(
                  'View Worker Piece Hisab',
                  style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.steel),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.steel, width: 1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }



  // Active Floor SOS Alerts by Allotment ID
  final Map<String, Map<String, String>> _activeFloorAlerts = {};

  String _selectedMachineStage = 'ALL';

  Widget buildMachineStationChip(String stageKey, String label, IconData icon, Color activeColor) {
    final isSelected = _selectedMachineStage == stageKey;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMachineStage = stageKey;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? activeColor : const Color(0xFFCBD5E1), width: isSelected ? 1.5 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: isSelected ? activeColor : const Color(0xFF64748B)),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? activeColor : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }


  // =========================================================================
  // 1-TAP FLOOR SOS / REPORT ISSUE BOTTOM SHEET
  // =========================================================================
  void _showFloorSosBottomSheet(dynamic a) {
    String selectedCategory = 'MACHINE_BREAKDOWN';
    String selectedStation = 'FIVE_THREAD';
    final noteController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 14,
                left: 20,
                right: 20,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.redMist,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFECDD3)),
                        ),
                        child: const Icon(Icons.warning_amber_rounded, color: AppTheme.red, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Report Line Stoppage / SOS',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 17.5,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Instant Alert to Production Manager Desk',
                              style: GoogleFonts.publicSans(fontSize: 12, color: AppTheme.inkSoft),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // 1-Tap Category Chips
                  Text(
                    'SELECT PROBLEM CATEGORY',
                    style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.0, color: AppTheme.inkSoft),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      {
                        'key': 'MACHINE_BREAKDOWN',
                        'label': 'Machine Breakdown',
                        'icon': Icons.build_rounded,
                      },
                      {
                        'key': 'MATERIAL_SHORTAGE',
                        'label': 'Material Shortage',
                        'icon': Icons.inventory_2_rounded,
                      },
                      {
                        'key': 'CUTTING_DEFECT',
                        'label': 'Cutting / Shade Defect',
                        'icon': Icons.content_cut_rounded,
                      },
                      {
                        'key': 'GENERAL_DELAY',
                        'label': 'General Floor Delay',
                        'icon': Icons.timer_off_rounded,
                      },
                    ].map((item) {
                      final isSel = selectedCategory == item['key'];
                      return GestureDetector(
                        onTap: () => setModalState(() => selectedCategory = item['key'] as String),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                          decoration: BoxDecoration(
                            color: isSel ? AppTheme.redMist : AppTheme.bg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSel ? AppTheme.red : AppTheme.border,
                              width: isSel ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                item['icon'] as IconData,
                                size: 15,
                                color: isSel ? AppTheme.red : AppTheme.inkSoft,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                item['label'] as String,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                                  color: isSel ? AppTheme.red : AppTheme.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // If Machine Breakdown, select Station
                  if (selectedCategory == 'MACHINE_BREAKDOWN') ...[
                    Text(
                      'AFFECTED MACHINE STATION',
                      style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.0, color: AppTheme.inkSoft),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        {'key': 'FIVE_THREAD', 'label': 'Five-Thread'},
                        {'key': 'OVERLOCK', 'label': 'Overlock (O/L)'},
                        {'key': 'FLATLOCK_RIB', 'label': 'Flatlock / Rib'},
                        {'key': 'LOCKING', 'label': 'Lockstitch (Plain)'},
                      ].map((st) {
                        final isStSel = selectedStation == st['key'];
                        return GestureDetector(
                          onTap: () => setModalState(() => selectedStation = st['key'] as String),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isStSel ? AppTheme.steelMist : AppTheme.bg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isStSel ? AppTheme.steel : AppTheme.border,
                                width: isStSel ? 1.5 : 1,
                              ),
                            ),
                            child: Text(
                              st['label'] as String,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isStSel ? FontWeight.bold : FontWeight.w600,
                                color: isStSel ? AppTheme.steel : AppTheme.ink,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Optional 1-line note
                  TextField(
                    controller: noteController,
                    decoration: InputDecoration(
                      hintText: 'Add details (e.g. Needle jammed, motor fuse)...',
                      hintStyle: GoogleFonts.publicSans(fontSize: 12.5, color: AppTheme.inkSoft),
                      filled: true,
                      fillColor: AppTheme.bg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.steel, width: 1.5)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 20),

                  // Send SOS Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final alotId = a['id'].toString();
                        setState(() {
                          _activeFloorAlerts[alotId] = {
                            'category': selectedCategory,
                            'station': selectedStation,
                            'note': noteController.text.trim(),
                            'time': 'Just now',
                          };
                        });
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Row(
                              children: [
                                Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                SizedBox(width: 8),
                                Text('Alert Sent to Production Manager!'),
                              ],
                            ),
                            backgroundColor: AppTheme.red,
                            duration: Duration(seconds: 4),
                          ),
                        );
                      },
                      icon: const Icon(Icons.send_rounded, size: 17, color: Colors.white),
                      label: Text(
                        'SEND ALERT TO MANAGER',
                        style: GoogleFonts.publicSans(fontSize: 13.5, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.red,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }


  double getArticlePieceRate(dynamic article, String size) {
    if (article == null) return 0.0;
    try {
      if (article['size_rates'] != null && article['size_rates'] is Map) {
        final sizeMap = article['size_rates'] as Map;
        if (sizeMap.containsKey(size) && sizeMap[size] != null) {
          return (sizeMap[size] as num).toDouble();
        }
      }
    } catch (_) {}
    return ((article['stitching_rate'] as num?)?.toDouble() ?? 0.0);
  }

  // ==========================================
  // ACTIVE ALLOTMENT CARD
  // ==========================================
  Widget _buildActiveAllotmentCard(dynamic a) {
    final art = a['articles'];
    final target = (a['target_qty'] as int?) ?? 1;
    final assigned = (a['total_assigned'] as int?) ?? 0;
    final done = (a['total_done'] as int?) ?? 0;
    final remaining = target - assigned;
    final progress = target > 0 ? (done / target).clamp(0.0, 1.0) : 0.0;
    final percent = (progress * 100).toInt();

    final isLotFullyFinished = done >= target && target > 0;

    final variants = (a['variants'] as List<dynamic>?) ?? [];
    final materials = (a['materials'] as List<dynamic>?) ?? [];
    final hasMaterials = materials.isNotEmpty;
    final materialsConfirmed = hasMaterials && materials.every((m) => m['lineman_received'] == true);
    
    // Check if Store has verified / issued
    final isStoreIssued = hasMaterials && materials.every((m) {
      final ins = _parseInspectionNotes(m['notes']);
      return m['admin_issued'] == true || ins?['store_verified'] == true;
    });

    final hasShortage = hasMaterials && materials.any((m) {
      final ins = _parseInspectionNotes(m['notes']);
      return ins?['status'] == 'SHORTAGE' || ins?['status'] == 'DEFECTIVE';
    });

    // Group variants by color
    final Map<String, List<dynamic>> colorGroups = {};
    for (var v in variants) {
      final c = (v['color'] as String?) ?? 'Default';
      colorGroups.putIfAbsent(c, () => []).add(v);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Material Handover Alert Banner (3-Way Handshake)
          if (hasMaterials)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: materialsConfirmed
                    ? AppTheme.greenMist
                    : isStoreIssued
                        ? (hasShortage ? AppTheme.amberMist : AppTheme.steelMist)
                        : AppTheme.bg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(
                  bottom: BorderSide(
                    color: materialsConfirmed
                        ? AppTheme.green.withValues(alpha: 0.3)
                        : isStoreIssued
                            ? (hasShortage ? AppTheme.amber.withValues(alpha: 0.3) : AppTheme.steelTint)
                            : AppTheme.border,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    materialsConfirmed
                        ? Icons.verified_rounded
                        : isStoreIssued
                            ? (hasShortage ? Icons.warning_amber_rounded : Icons.local_shipping_rounded)
                            : Icons.lock_clock_outlined,
                    color: materialsConfirmed
                        ? AppTheme.green
                        : isStoreIssued
                            ? (hasShortage ? AppTheme.amber : AppTheme.steel)
                            : AppTheme.amber,
                    size: 19,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      materialsConfirmed
                          ? 'Raw Materials Verified & Received on Floor (${materials.length} items)'
                          : isStoreIssued
                              ? (hasShortage
                                  ? 'Partial Materials Issued by Store (${materials.length} items) • Shortage Flagged'
                                  : 'Raw Materials Ready from Store (${materials.length} items)')
                              : 'Materials Awaiting Store Godown Inspection (${materials.length} items)',
                      style: GoogleFonts.publicSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: materialsConfirmed
                            ? AppTheme.green
                            : isStoreIssued
                                ? (hasShortage ? AppTheme.amber : AppTheme.steel)
                                : const Color(0xFF92400E),
                      ),
                    ),
                  ),
                  if (!materialsConfirmed && isStoreIssued)
                    _BouncyTap(
                      onTap: () => _confirmMaterialReceipt(a),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: hasShortage ? AppTheme.amber : AppTheme.steel,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Receive Materials', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // PO # Badge & Priority
                          () {
                            String poNo = (a['production_order_no'] ?? '').toString();
                            String priority = (a['priority'] ?? 'NORMAL').toString();
                            String dueDate = (a['due_date'] ?? '').toString();
                            String mgr = (a['manager_name'] ?? '').toString();

                            // Fallback from material notes
                            if (poNo.isEmpty) {
                              final mats = (a['materials'] as List<dynamic>?) ?? [];
                              for (var m in mats) {
                                if (m['notes'] != null) {
                                  try {
                                    final parsed = jsonDecode(m['notes'].toString());
                                    if (parsed['production_order_no'] != null && parsed['production_order_no'].toString().isNotEmpty) {
                                      poNo = parsed['production_order_no'].toString();
                                    }
                                    if (parsed['priority'] != null) priority = parsed['priority'].toString();
                                    if (parsed['due_date'] != null) dueDate = parsed['due_date'].toString();
                                    if (parsed['manager_name'] != null) mgr = parsed['manager_name'].toString();
                                    if (poNo.isNotEmpty) break;
                                  } catch (_) {}
                                }
                              }
                            }

                            if (poNo.isEmpty) {
                              poNo = 'PO-${a['id'].toString().substring(0, 6).toUpperCase()}';
                            }

                            return Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.bg,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppTheme.border),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.receipt_rounded, size: 13, color: AppTheme.steel),
                                      const SizedBox(width: 4),
                                      Text(
                                        poNo,
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.ink,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (priority == 'CRITICAL' || priority == 'RUSH')
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.redMist,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFFECDD3)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.local_fire_department_rounded, size: 13, color: AppTheme.red),
                                        const SizedBox(width: 3),
                                        Text(
                                          priority == 'CRITICAL' ? 'CRITICAL' : 'RUSH',
                                          style: GoogleFonts.publicSans(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.red,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (dueDate.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.bg,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppTheme.border),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.timer_outlined, size: 13, color: AppTheme.inkSoft),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Due: $dueDate',
                                          style: GoogleFonts.publicSans(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.inkSoft,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (mgr.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.bg,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppTheme.border),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.person_pin_rounded, size: 14, color: AppTheme.inkSoft),
                                        const SizedBox(width: 4),
                                        Text(
                                          'PM: $mgr',
                                          style: GoogleFonts.publicSans(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.inkSoft,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            );
                          }(),
                          const SizedBox(height: 6),
                          Text(
                            'Art No: ${art?['art_no'] ?? '-'}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.steelDark,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            art?['description'] ?? 'Garment Style',
                            style: GoogleFonts.publicSans(fontSize: 13.5, fontWeight: FontWeight.w500, color: AppTheme.inkSoft),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: percent >= 100 ? AppTheme.greenMist : AppTheme.bg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: percent >= 100 ? AppTheme.green.withValues(alpha: 0.3) : AppTheme.border,
                        ),
                      ),
                      child: Text(
                        '$percent%',
                        style: GoogleFonts.jetBrainsMono(
                          color: percent >= 100 ? AppTheme.green : AppTheme.ink,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Buyer Golden Sample Photos Gallery
                () {
                  List<String> photos = [];
                  if (a['sample_photos'] is List) {
                    photos = (a['sample_photos'] as List).map((p) => p.toString()).where((p) => p.isNotEmpty).toList();
                  }
                  if (photos.isEmpty && materials.isNotEmpty) {
                    for (var m in materials) {
                      if (m['notes'] != null) {
                        try {
                          final parsed = jsonDecode(m['notes'].toString());
                          if (parsed['sample_photos'] is List) {
                            photos = (parsed['sample_photos'] as List).map((p) => p.toString()).where((p) => p.isNotEmpty).toList();
                            if (photos.isNotEmpty) break;
                          }
                        } catch (_) {}
                      }
                    }
                  }

                  if (photos.isEmpty) return const SizedBox.shrink();

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.bg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.photo_library_rounded, size: 13, color: AppTheme.steel),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                'BUYER GOLDEN SAMPLE PHOTOS',
                                style: GoogleFonts.publicSans(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: AppTheme.inkSoft),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${photos.length} photos (Tap to zoom)',
                              style: GoogleFonts.publicSans(fontSize: 9.5, color: AppTheme.inkFaint),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 75,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: photos.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (ctx, pIdx) {
                              final pUrl = photos[pIdx];
                              final tag = pIdx == 0 ? 'Front' : pIdx == 1 ? 'Back' : pIdx == 2 ? 'Label' : 'Detail';
                              return GestureDetector(
                                onTap: () => showSampleImageZoom(context, pUrl, '$tag View'),
                                child: Container(
                                  width: 75,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppTheme.border),
                                    color: Colors.white,
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      pUrl.startsWith('http')
                                          ? Image.network(pUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 24, color: AppTheme.inkFaint))
                                          : (pUrl.startsWith('data:image')
                                              ? Image.memory(const Base64Decoder().convert(pUrl.split(',').last), fit: BoxFit.cover)
                                              : const Icon(Icons.image, size: 24, color: AppTheme.inkFaint)),
                                      Positioned(
                                        bottom: 2,
                                        left: 2,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                          decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
                                          child: Text(tag, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                }(),

                // Size & Color Matrix Chips (Visual Variant Design)
                if (colorGroups.isNotEmpty) ...[
                  Text(
                    'SIZE & COLOR RATIOS',
                    style: GoogleFonts.publicSans(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.9, color: AppTheme.inkSoft),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: colorGroups.entries.map((cg) {
                      final sizeBreakdown = cg.value.map((v) => '${v['size']}: ${v['quantity']}').join(' · ');
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppTheme.bg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppTheme.steel,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              cg.key,
                              style: GoogleFonts.publicSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.ink,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '($sizeBreakdown)',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.inkSoft,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],

                // Smooth Animated Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    tween: Tween<double>(begin: 0, end: progress),
                    builder: (context, val, _) {
                      return LinearProgressIndicator(
                        value: val,
                        minHeight: 8,
                        backgroundColor: AppTheme.bg,
                        valueColor: AlwaysStoppedAnimation<Color>(percent >= 100 ? AppTheme.green : AppTheme.steel),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),

                // Unified Telemetry Bar (Target / Assigned / Done / Left)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      _telemetryCell('Target', '$target', 'pcs', AppTheme.ink),
                      _cellDivider(),
                      _telemetryCell('Assigned', '$assigned', 'pcs', AppTheme.steel),
                      _cellDivider(),
                      _telemetryCell('Done', '$done', 'pcs', done > 0 ? AppTheme.green : AppTheme.inkSoft),
                      _cellDivider(),
                      _telemetryCell('Left', '$remaining', 'pcs', remaining > 0 ? AppTheme.amber : AppTheme.green),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Active SOS Alert Banner (If pending)
                () {
                  final alotId = a['id'].toString();
                  if (_activeFloorAlerts.containsKey(alotId)) {
                    final alt = _activeFloorAlerts[alotId]!;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 15, color: Color(0xFFDC2626)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Alert Sent: ${alt['category']?.replaceAll('_', ' ')} (${alt['station']})',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setState(() => _activeFloorAlerts.remove(alotId)),
                            child: const Icon(Icons.close_rounded, size: 15, color: Color(0xFF991B1B)),
                          ),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                }(),

                // Button Row with SOS Trigger
                Row(
                  children: [
                    // SOS 1-Tap Trigger Button
                    Container(
                      height: 48,
                      margin: const EdgeInsets.only(right: 10),
                      child: OutlinedButton(
                        onPressed: () => _showFloorSosBottomSheet(a),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFFECDD3), width: 1.2),
                          backgroundColor: const Color(0xFFFFF1F2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.warning_amber_rounded, size: 19, color: Color(0xFFE11D48)),
                            const SizedBox(width: 5),
                            Text(
                              'SOS',
                              style: GoogleFonts.publicSans(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFE11D48),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    Expanded(
                      child: isLotFullyFinished
                          ? _BouncyTap(
                              onTap: () => _completeAllotment(a),
                              child: Container(
                                height: 48,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: AppTheme.green,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.arrow_forward_rounded, size: 19, color: Colors.white),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        'Handover to Mending Floor',
                                        style: GoogleFonts.publicSans(fontSize: 13.5, fontWeight: FontWeight.w700, color: Colors.white),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : (hasMaterials && !materialsConfirmed)
                              ? _BouncyTap(
                                  onTap: () {
                                    if (isStoreIssued) {
                                      _confirmMaterialReceipt(a);
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Raw materials have not been issued by Store Godown yet.'),
                                          backgroundColor: AppTheme.amber,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  },
                                  child: Container(
                                    height: 48,
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    decoration: BoxDecoration(
                                      color: isStoreIssued ? const Color(0xFF4F46E5) : AppTheme.border,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          isStoreIssued ? Icons.inventory_2_rounded : Icons.lock_outline_rounded,
                                          size: 19,
                                          color: isStoreIssued ? Colors.white : AppTheme.inkFaint,
                                        ),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            isStoreIssued
                                                ? 'Receive Materials to Assign ($remaining left)'
                                                : 'Awaiting Store Issue ($remaining left)',
                                            style: GoogleFonts.publicSans(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: isStoreIssued ? Colors.white : AppTheme.inkFaint,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : _BouncyTap(
                                  onTap: remaining > 0 ? () => _showAssignWorkerDialog(a) : null,
                                  child: Container(
                                    height: 48,
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    decoration: BoxDecoration(
                                      color: remaining > 0 ? AppTheme.steel : AppTheme.border,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.person_add_alt_1_rounded, size: 19, color: remaining > 0 ? Colors.white : AppTheme.inkFaint),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            remaining > 0 ? 'Assign Batch ($remaining left)' : 'All Batches Assigned',
                                            style: GoogleFonts.publicSans(fontSize: 13.5, fontWeight: FontWeight.w700, color: remaining > 0 ? Colors.white : AppTheme.inkFaint),
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _telemetryCell(String label, String value, String unit, Color color) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: GoogleFonts.jetBrainsMono(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: color,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                unit,
                style: GoogleFonts.publicSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.inkSoft,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.publicSans(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: AppTheme.inkSoft,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cellDivider() {
    return Container(width: 1, height: 32, color: AppTheme.border);
  }

  // ==========================================
  // STATUS-GROUPED ASSIGNMENTS LIST (TAB 1)
  // ==========================================
  Widget _buildGroupedAssignmentLists() {
    if (_todayAssignments.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Center(
          child: Text(
            'No workers assigned today. Tap "Assign next batch" above to add one.',
            textAlign: TextAlign.center,
            style: GoogleFonts.publicSans(fontSize: 12.5, color: AppTheme.inkSoft, height: 1.4),
          ),
        ),
      );
    }

    // Filter by search query if any
    var list = _todayAssignments;
    if (_liveSearchQuery.isNotEmpty) {
      list = list.where((a) {
        final w = (a['worker_name'] as String? ?? '').toLowerCase();
        final art = (a['articles']?['art_no'] as String? ?? '').toLowerCase();
        return w.contains(_liveSearchQuery) || art.contains(_liveSearchQuery);
      }).toList();
    }

    final pending = list.where((a) => a['status'] == 'PENDING').toList();
    final inProgress = list.where((a) => a['status'] == 'IN_PROGRESS').toList();
    final done = list.where((a) => a['status'] == 'DONE').toList();

    final bool hasOverdue = pending.any((a) => _isOverdue(a['assigned_at']));

    int globalIndex = 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. PENDING GROUP
        if (pending.isNotEmpty) ...[
          _AnimatedFadeSlide(
            delayMs: 250,
            child: _buildGroupHeader(
              'Pending (${pending.length})',
              hasOverdue ? AppTheme.red : AppTheme.amber,
              hasOverdue ? Icons.warning_amber_rounded : Icons.pending_rounded,
            ),
          ),
          const SizedBox(height: 8),
          ...pending.map((a) {
            globalIndex++;
            return _AnimatedFadeSlide(
              delayMs: 250 + (globalIndex * 40),
              child: _buildDismissibleAssignmentCard(a),
            );
          }),
          const SizedBox(height: 16),
        ],

        // 2. IN PROGRESS GROUP
        if (inProgress.isNotEmpty) ...[
          _AnimatedFadeSlide(
            delayMs: 280,
            child: _buildGroupHeader(
              'In Progress (${inProgress.length})',
              AppTheme.steel,
              Icons.timelapse_rounded,
            ),
          ),
          const SizedBox(height: 8),
          ...inProgress.map((a) {
            globalIndex++;
            return _AnimatedFadeSlide(
              delayMs: 280 + (globalIndex * 40),
              child: _buildDismissibleAssignmentCard(a),
            );
          }),
          const SizedBox(height: 16),
        ],

        // 3. COMPLETED (DONE) GROUP - 70% OPACITY
        if (done.isNotEmpty) ...[
          _AnimatedFadeSlide(
            delayMs: 320,
            child: _buildGroupHeader(
              'Completed Today (${done.length})',
              AppTheme.green,
              Icons.check_circle_rounded,
            ),
          ),
          const SizedBox(height: 8),
          ...done.map((a) {
            globalIndex++;
            return _AnimatedFadeSlide(
              delayMs: 320 + (globalIndex * 40),
              child: Opacity(
                opacity: 0.7,
                child: _buildAssignmentCard(a),
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildGroupHeader(String title, Color color, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          title,
          style: GoogleFonts.publicSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // INTERACTIVE SWIPE-TO-COMPLETE CARD
  // ==========================================
  Widget _buildDismissibleAssignmentCard(dynamic a) {
    return _InteractiveSwipeCard(
      key: ValueKey('assignment_${a['id']}'),
      assignment: a,
      onComplete: (assignment) => _markAsDone(assignment),
      child: _buildAssignmentCard(a),
    );
  }

  Widget _buildAssignmentCard(dynamic a) {
    final workerName = a['worker_name'] ?? 'Worker';
    final artNo = a['articles']?['art_no'] ?? '-';
    final qty = (a['assigned_qty'] as int?) ?? 0;
    final status = a['status'] ?? 'PENDING';
    final assignedTime = _formatTime(a['assigned_at']);
    final doneTime = _formatTime(a['completed_at']);

    final color = a['color'] as String? ?? '';
    final size = a['size'] as String? ?? '';
    final hasVariant = (color.isNotEmpty && color != 'Default') || (size.isNotEmpty && size != 'Standard');
    final variantTag = hasVariant ? '$color • Size $size' : '';

    Color statusColor;
    switch (status) {
      case 'DONE':
        statusColor = AppTheme.green;
        break;
      case 'IN_PROGRESS':
        statusColor = AppTheme.steel;
        break;
      default:
        statusColor = AppTheme.amber;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: status == 'DONE' ? AppTheme.green.withValues(alpha: 0.3) : AppTheme.border,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: statusColor.withValues(alpha: 0.12),
                  child: Icon(
                    status == 'DONE' ? Icons.check_circle_rounded : Icons.person_rounded,
                    color: statusColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        workerName,
                        style: GoogleFonts.publicSans(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.ink),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasVariant ? 'Art: $artNo • $variantTag • $qty pcs' : 'Art: $artNo • $qty pcs',
                        style: GoogleFonts.publicSans(fontSize: 11.5, color: AppTheme.inkSoft, fontWeight: FontWeight.w500),
                      ),
                      () {
                        final notesStr = (a['notes'] ?? '').toString();
                        String? machineLabel;
                        Color? machineColor;
                        IconData? machineIcon;

                        if (notesStr.contains('[OVERLOCK]')) {
                          machineLabel = 'Overlock (4-Th)';
                          machineColor = const Color(0xFF2563EB);
                          machineIcon = Icons.tune_rounded;
                        } else if (notesStr.contains('[FIVE_THREAD]')) {
                          machineLabel = '5-Thread Safety';
                          machineColor = const Color(0xFF7C3AED);
                          machineIcon = Icons.linear_scale_rounded;
                        } else if (notesStr.contains('[FLATLOCK]')) {
                          machineLabel = 'Flatlock / Rib';
                          machineColor = const Color(0xFFD97706);
                          machineIcon = Icons.view_headline_rounded;
                        } else if (notesStr.contains('[LOCKING]')) {
                          machineLabel = 'Locking / Single';
                          machineColor = const Color(0xFF059669);
                          machineIcon = Icons.lock_outline_rounded;
                        } else {
                          // Default machine tag if unspecified
                          machineLabel = 'Overlock (4-Th)';
                          machineColor = const Color(0xFF2563EB);
                          machineIcon = Icons.tune_rounded;
                        }

                        String? borrowedLabel;
                        final borrowMatch = RegExp(r'\[BORROWED:\s*(.*?)\]').firstMatch(notesStr);
                        if (borrowMatch != null && borrowMatch.group(1) != null) {
                          borrowedLabel = borrowMatch.group(1);
                        }

                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Wrap(
                            spacing: 5,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: machineColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(color: machineColor.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(machineIcon, size: 10.5, color: machineColor),
                                    const SizedBox(width: 3),
                                    Text(
                                      machineLabel,
                                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: machineColor),
                                    ),
                                  ],
                                ),
                              ),
                              if (borrowedLabel != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFFBEB),
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(color: const Color(0xFFFDE68A)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.swap_horiz_rounded, size: 10.5, color: Color(0xFFD97706)),
                                      const SizedBox(width: 3),
                                      Text(
                                        'Borrowed: $borrowedLabel',
                                        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        );
                      }(),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    status == 'DONE' ? 'Done' : (status == 'IN_PROGRESS' ? 'In Progress' : 'Pending'),
                    style: GoogleFonts.publicSans(fontWeight: FontWeight.w700, fontSize: 11, color: statusColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: AppTheme.border),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 3,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.access_time_rounded, size: 12, color: AppTheme.inkFaint),
                          const SizedBox(width: 3),
                          Text(
                            'Given: $assignedTime',
                            style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppTheme.inkFaint),
                          ),
                        ],
                      ),
                      _buildTimeSinceAssigned(a['assigned_at'], status),
                      if (status == 'DONE')
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_outline, size: 12, color: AppTheme.green),
                            const SizedBox(width: 3),
                            Text(
                              'Done: $doneTime',
                              style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppTheme.green),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                if (status != 'DONE') ...[
                  const SizedBox(width: 6),
                  _BouncyTap(
                    onTap: () => _markAsDone(a),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.greenMist,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.green.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_rounded, size: 14, color: AppTheme.green),
                          const SizedBox(width: 3),
                          Text(
                            'Done',
                            style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.green),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.more_vert, size: 18, color: AppTheme.inkFaint),
                    onSelected: (val) {
                      if (val == 'edit') {
                        _editAssignment(a);
                      } else if (val == 'delete') {
                        _deleteAssignment(a);
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            const Icon(Icons.edit_outlined, size: 16, color: AppTheme.steel),
                            const SizedBox(width: 8),
                            Text('Edit', style: GoogleFonts.publicSans(fontSize: 13)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            const Icon(Icons.delete_outline_rounded, size: 16, color: AppTheme.red),
                            const SizedBox(width: 8),
                            Text('Delete', style: GoogleFonts.publicSans(fontSize: 13, color: AppTheme.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // MENDING & REPAIRS FROM QC BANNER
  // ==========================================
  Widget _buildMendingTasksSection() {
    int totalMendingPieces = 0;
    for (var m in _activeMendingTasks) {
      totalMendingPieces += (m['qty_rejected'] as int? ?? 0);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.amberMist,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.amber, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppTheme.amber.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
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
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppTheme.amber,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.build_rounded, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Mending Tasks from QC',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.ink,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.amber,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$totalMendingPieces pcs pending',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'QC has flagged the following pieces for floor repair/alteration. Please assign tailors to fix and return to QC desk.',
            style: GoogleFonts.publicSans(fontSize: 11.5, color: AppTheme.inkSoft),
          ),
          const SizedBox(height: 10),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _activeMendingTasks.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, idx) {
              final task = _activeMendingTasks[idx];
              final artNo = task['article']?['art_no'] ?? '-';
              final qty = task['qty_rejected'] ?? 0;
              final defect = task['defect_type'] ?? 'Defect';
              final color = task['color'] as String? ?? '';
              final size = task['size'] as String? ?? '';
              final variantStr = (color.isNotEmpty || size.isNotEmpty) ? ' • $color ($size)' : '';
              final remarks = task['remarks'] as String?;

              return Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Art: $artNo$variantStr',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppTheme.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Defect: $defect',
                            style: GoogleFonts.publicSans(
                              fontSize: 11.5,
                              color: AppTheme.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (remarks != null && remarks.isNotEmpty) ...[
                            const SizedBox(height: 1),
                            Text(
                              'Note: $remarks',
                              style: GoogleFonts.publicSans(
                                fontSize: 10.5,
                                color: AppTheme.inkSoft,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.amberMist,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.amber.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        '$qty pcs',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.amber,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SKELETON SHIMMER LOADING
  // ==========================================
  Widget _buildAnimatedSkeletonLoading() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildShimmerBox(height: 76, radius: 12),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildShimmerBox(height: 64, radius: 12)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildShimmerBox(height: 64, radius: 12)),
                ],
              ),
              const SizedBox(height: 20),
              _buildShimmerBox(height: 180, radius: 12),
              const SizedBox(height: 20),
              ...List.generate(3, (idx) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildShimmerBox(height: 76, radius: 12),
              )),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShimmerBox({required double height, required double radius}) {
    final shimmerPos = _shimmerController.value;
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment(shimmerPos - 1.0, 0),
          end: Alignment(shimmerPos, 0),
          colors: const [
            AppTheme.steelMist,
            Color(0xFFF6F8FB),
            AppTheme.steelMist,
          ],
        ),
      ),
    );
  }

  Widget _buildNoAllotmentEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.steelMist,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.steelTint),
            ),
            child: const Icon(Icons.assignment_outlined, size: 24, color: AppTheme.ink),
          ),
          const SizedBox(height: 12),
          Text(
            'No active allotments',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Check back once your supervisor assigns a new cutting target.",
            textAlign: TextAlign.center,
            style: GoogleFonts.publicSans(
              fontSize: 13,
              color: AppTheme.inkSoft,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, {String? unit, String? subtitle}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppTheme.steelMist,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.steelTint),
                  ),
                  child: Icon(icon, color: AppTheme.ink, size: 20),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      style: GoogleFonts.jetBrainsMono(
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        color: AppTheme.ink,
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (unit != null) ...[
                      const SizedBox(width: 3),
                      Text(
                        unit,
                        style: GoogleFonts.publicSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.inkSoft,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppTheme.ink,
              ),
              maxLines: 1,
              overflow: TextOverflow.visible,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: GoogleFonts.publicSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: color == AppTheme.green ? AppTheme.green : AppTheme.inkSoft,
                ),
                maxLines: 1,
                overflow: TextOverflow.visible,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ==========================================
// INTERACTIVE SWIPE-TO-COMPLETE WIDGET (DYNAMIC SPRING & COLOR PROGRESSION)
// ==========================================
class _InteractiveSwipeCard extends StatefulWidget {
  final dynamic assignment;
  final Widget child;
  final Future<void> Function(dynamic) onComplete;

  const _InteractiveSwipeCard({
    required Key key,
    required this.assignment,
    required this.child,
    required this.onComplete,
  }) : super(key: key);

  @override
  State<_InteractiveSwipeCard> createState() => _InteractiveSwipeCardState();
}

class _InteractiveSwipeCardState extends State<_InteractiveSwipeCard> {
  double _dragProgress = 0.0;
  bool _thresholdReached = false;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: widget.key!,
      direction: DismissDirection.startToEnd,
      dismissThresholds: const {DismissDirection.startToEnd: 0.35},
      onUpdate: (details) {
        final reached = details.progress >= 0.35;
        if (reached != _thresholdReached || (_dragProgress - details.progress).abs() > 0.04) {
          setState(() {
            _dragProgress = details.progress;
            _thresholdReached = reached;
          });
        }
      },
      confirmDismiss: (direction) async {
        await widget.onComplete(widget.assignment);
        return true;
      },
      background: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          gradient: _thresholdReached
              ? const LinearGradient(
                  colors: [Color(0xFF16804F), Color(0xFF1F9D63)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          color: _thresholdReached ? null : AppTheme.greenMist,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _thresholdReached ? const Color(0xFF16804F) : AppTheme.green.withValues(alpha: 0.35),
            width: 1.5,
          ),
          boxShadow: _thresholdReached
              ? [
                  BoxShadow(
                    color: AppTheme.green.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            // Left Action Badge
            AnimatedScale(
              scale: _thresholdReached ? 1.15 : (0.9 + (_dragProgress * 0.5)).clamp(0.9, 1.15),
              duration: const Duration(milliseconds: 200),
              curve: Curves.elasticOut,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _thresholdReached ? Colors.white : AppTheme.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _thresholdReached ? Colors.white : AppTheme.green.withValues(alpha: 0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: _thresholdReached ? 0.12 : 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    _thresholdReached ? Icons.task_alt_rounded : Icons.arrow_forward_rounded,
                    color: AppTheme.green,
                    size: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Text Label & Subtitle
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _thresholdReached ? 'STATUS UPDATE' : 'QUICK ACTION',
                    style: GoogleFonts.publicSans(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.3,
                      color: _thresholdReached ? Colors.white.withValues(alpha: 0.85) : AppTheme.green,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _thresholdReached ? 'Release to Mark as Done' : 'Swipe right to complete',
                    style: GoogleFonts.publicSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _thresholdReached ? Colors.white : AppTheme.ink,
                    ),
                  ),
                ],
              ),
            ),
            if (_thresholdReached) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.done_all_rounded, size: 14, color: Colors.white),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      child: widget.child,
    );
  }
}

// ==========================================
// SMOOTH STAGGERED FADE & SLIDE ANIMATION WIDGET
// ==========================================
class _AnimatedFadeSlide extends StatefulWidget {
  final Widget child;
  final int delayMs;
  const _AnimatedFadeSlide({required this.child, required this.delayMs});

  @override
  State<_AnimatedFadeSlide> createState() => _AnimatedFadeSlideState();
}

class _AnimatedFadeSlideState extends State<_AnimatedFadeSlide>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );

    _opacityAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    if (widget.delayMs == 0) {
      _controller.forward();
    } else {
      Future.delayed(Duration(milliseconds: widget.delayMs), () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: widget.child,
      ),
    );
  }
}

// ==========================================
// TACTILE BOUNCY TAP MICRO-INTERACTION
// ==========================================
class _BouncyTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _BouncyTap({required this.child, this.onTap});

  @override
  State<_BouncyTap> createState() => _BouncyTapState();
}

class _BouncyTapState extends State<_BouncyTap> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _isPressed = true),
      onTapUp: widget.onTap == null ? null : (_) => setState(() => _isPressed = false),
      onTapCancel: widget.onTap == null ? null : () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutQuad,
        child: widget.child,
      ),
    );
  }
}

// ==========================================
// LIVELY WAVING HAND ANIMATION WIDGET
// ==========================================
class _WavingHandIcon extends StatefulWidget {
  final double size;
  const _WavingHandIcon({this.size = 20});

  @override
  State<_WavingHandIcon> createState() => _WavingHandIconState();
}

class _WavingHandIconState extends State<_WavingHandIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _waveAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _waveAnim = TweenSequence<double>([
      // Wave right
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 0.28).chain(CurveTween(curve: Curves.easeInOut)), weight: 12),
      // Wave left
      TweenSequenceItem(tween: Tween<double>(begin: 0.28, end: -0.22).chain(CurveTween(curve: Curves.easeInOut)), weight: 16),
      // Wave right
      TweenSequenceItem(tween: Tween<double>(begin: -0.22, end: 0.24).chain(CurveTween(curve: Curves.easeInOut)), weight: 16),
      // Wave left
      TweenSequenceItem(tween: Tween<double>(begin: 0.24, end: -0.15).chain(CurveTween(curve: Curves.easeInOut)), weight: 14),
      // Settle back to center
      TweenSequenceItem(tween: Tween<double>(begin: -0.15, end: 0.0).chain(CurveTween(curve: Curves.easeOut)), weight: 12),
      // Pause
      TweenSequenceItem(tween: ConstantTween<double>(0.0), weight: 30),
    ]).animate(_controller);

    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _waveAnim,
      builder: (context, child) {
        return Transform.rotate(
          angle: _waveAnim.value,
          alignment: const Alignment(0.4, 0.9), // Wrist pivot
          child: child,
        );
      },
      child: Icon(
        Icons.waving_hand_outlined,
        color: AppTheme.steel,
        size: widget.size,
      ),
    );
  }
}
