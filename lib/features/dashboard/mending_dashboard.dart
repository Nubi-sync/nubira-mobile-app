import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/providers/auth_provider.dart';
import '../auth/screens/login_screen.dart';
import '../../../main.dart';
import 'widgets/lot_selector_strip.dart';

class MendingDashboard extends ConsumerStatefulWidget {
  const MendingDashboard({super.key});

  @override
  ConsumerState<MendingDashboard> createState() => _MendingDashboardState();
}

class _MendingDashboardState extends ConsumerState<MendingDashboard>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<Map<String, dynamic>> _lots = [];
  Map<String, dynamic>? _selectedLot;
  int _selectedTabIndex = 0; // 0: Worker Assignments, 1: Natural Size Matrix & QC
  int _filterMode = 0; // 0: My Assigned Lots, 1: All Floor Lots
  bool _isSubmitting = false;

  // Filtered lots based on selected filter mode
  List<Map<String, dynamic>> get _filteredLots {
    final currentUserId = supabase.auth.currentUser?.id;
    if (_filterMode == 0) {
      return _lots.where((lot) {
        final supId = lot['mending_supervisor_id']?.toString();
        // If assigned to me OR unassigned pool, show in My Assigned Lots
        return supId == null || supId.isEmpty || supId == currentUserId;
      }).toList();
    }
    return _lots;
  }

  // Live QC Supervisors for Floor Handover
  List<Map<String, dynamic>> _qcSupervisors = [];

  // Recent mending worker names for quick chip recommendations
  List<String> _recentWorkerNames = [];

  // Controllers for Worker Assignment Modal
  final _workerNameController = TextEditingController();
  final _qtyController = TextEditingController();
  final _notesController = TextEditingController();
  Map<String, dynamic>? _selectedVariantForAssignment;

  // Natural size ordering helper
  static const List<String> _alphaSizeOrder = [
    'XS', 'S', 'M', 'L', 'XL', '2XL', 'XXL', '3XL', 'XXXL', '4XL', '5XL', 'FREE', 'FS'
  ];

  // Safe helper to extract Map from potentially dynamic/List values
  static Map<String, dynamic>? _asMap(dynamic val) {
    if (val == null) return null;
    if (val is Map<String, dynamic>) return val;
    if (val is Map) return Map<String, dynamic>.from(val);
    if (val is List && val.isNotEmpty && val.first is Map) {
      return Map<String, dynamic>.from(val.first as Map);
    }
    return null;
  }

  // Safe helper to extract integers from dynamic types (Strings, num, ints)
  static int _parseQty(dynamic val) {
    if (val == null) return 0;
    if (val is int) return val;
    if (val is num) return val.toInt();
    final str = val.toString().trim();
    final direct = int.tryParse(str);
    if (direct != null) return direct;
    final match = RegExp(r'[-+]?\d+').firstMatch(str);
    if (match != null) {
      return int.tryParse(match.group(0) ?? '') ?? 0;
    }
    return 0;
  }

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

  // Get total already assigned pieces for a specific variant (by color & size)
  int _getAssignedQtyForVariant(Map<String, dynamic>? v) {
    if (v == null || _selectedLot == null) return 0;
    final assigns = (_selectedLot!['assignments'] as List<dynamic>?) ?? [];
    final vColor = (v['color'] ?? 'Standard').toString().trim().toUpperCase();
    final vSize = (v['size'] ?? 'Free').toString().trim().toUpperCase();

    int totalAssigned = 0;
    for (var a in assigns) {
      if (a is Map) {
        final aColor = (a['color'] ?? 'Standard').toString().trim().toUpperCase();
        final aSize = (a['size'] ?? 'Free').toString().trim().toUpperCase();
        if (aColor == vColor && aSize == vSize) {
          totalAssigned += _parseQty(a['assigned_qty']);
        }
      }
    }
    return totalAssigned;
  }

  // Get remaining unassigned pieces for a specific variant
  int _getRemainingQtyForVariant(Map<String, dynamic>? v) {
    if (v == null) return 0;
    final target = _parseQty(v['quantity']);
    final assigned = _getAssignedQtyForVariant(v);
    final rem = target - assigned;
    return rem > 0 ? rem : 0;
  }

  @override
  void initState() {
    super.initState();
    _loadRecentWorkers();
    _fetchQcSupervisors();
    _fetchMendingLots();
  }

  Future<void> _fetchQcSupervisors() async {
    try {
      final res = await supabase
          .from('profiles')
          .select('id, username, role, is_active')
          .inFilter('role', ['PRODUCTION', 'QC', 'PRODUCTION_QC'])
          .order('username', ascending: true);
      if (mounted) {
        setState(() {
          _qcSupervisors = List<Map<String, dynamic>>.from(res as List)
              .where((u) => u['is_active'] != false)
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Fetch QC supervisors error: $e');
    }
  }

  @override
  void dispose() {
    _workerNameController.dispose();
    _qtyController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentWorkers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('mending_recent_workers') ?? [];
      if (mounted) setState(() => _recentWorkerNames = list);
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
      await prefs.setStringList('mending_recent_workers', updated);
      if (mounted) setState(() => _recentWorkerNames = updated);
    } catch (_) {}
  }

  Future<void> _fetchMendingLots() async {
    setState(() => _isLoading = true);
    try {
      List<dynamic> allotmentList = [];
      try {
        final res = await supabase
            .from('allotments')
            .select('''
              id,
              challan_id,
              article_id,
              lineman_id,
              status,
              priority,
              mending_status,
              target_qty,
              mending_supervisor_id,
              mending_supervisor_name,
              handed_to_mending_by,
              handed_to_mending_at,
              mending_handover_notes,
              created_at,
              article:articles ( id, art_no, description ),
              lineman:profiles!allotments_lineman_id_fkey ( id, username ),
              challans ( id, challan_no, brand, fabric_type )
            ''')
            .order('created_at', ascending: false)
            .limit(50);
        allotmentList = res as List<dynamic>;
      } catch (e) {
        debugPrint('Mending lots priority query fallback: $e');
        final res = await supabase
            .from('allotments')
            .select('''
              id,
              challan_id,
              article_id,
              lineman_id,
              status,
              mending_status,
              target_qty,
              mending_supervisor_id,
              mending_supervisor_name,
              handed_to_mending_by,
              handed_to_mending_at,
              mending_handover_notes,
              created_at,
              article:articles ( id, art_no, description ),
              lineman:profiles!allotments_lineman_id_fkey ( id, username ),
              challans ( id, challan_no, brand, fabric_type )
            ''')
            .order('created_at', ascending: false)
            .limit(50);
        allotmentList = res as List<dynamic>;
      }

      final List<String> lotIds = allotmentList.map((a) => a['id'].toString()).toList();

      // Fetch variants for these allotments
      List<dynamic> variantsRes = [];
      if (lotIds.isNotEmpty) {
        try {
          variantsRes = await supabase
              .from('allotment_variants')
              .select('id, allotment_id, color, size, quantity')
              .inFilter('allotment_id', lotIds);
        } catch (e) {
          debugPrint('Allotment variants fetch error: $e');
        }
      }

      // Fetch mending worker assignments
      List<dynamic> assignmentsRes = [];
      if (lotIds.isNotEmpty) {
        try {
          assignmentsRes = await supabase
              .from('mending_assignments')
              .select('*')
              .inFilter('allotment_id', lotIds)
              .order('assigned_at', ascending: false);
        } catch (e) {
          debugPrint('Mending assignments fetch error: $e');
        }
      }

      // Fetch fallback priority from allotment_materials if priority column wasn't populated
      Map<String, String> priorityMap = {};
      if (lotIds.isNotEmpty) {
        try {
          final matRes = await supabase
              .from('allotment_materials')
              .select('allotment_id, notes')
              .inFilter('allotment_id', lotIds);
          for (var row in (matRes as List<dynamic>)) {
            final aId = row['allotment_id']?.toString() ?? '';
            final notesRaw = row['notes'];
            if (notesRaw is String && notesRaw.contains('"priority"')) {
              try {
                final parsed = jsonDecode(notesRaw);
                if (parsed is Map && parsed['priority'] != null) {
                  final p = parsed['priority'].toString().toUpperCase();
                  if (p == 'CRITICAL' || p == 'RUSH' || p == 'NORMAL') {
                    priorityMap[aId] = p;
                  }
                }
              } catch (_) {}
            }
          }
        } catch (e) {
          debugPrint('Mending: Allotment materials priority fetch error: $e');
        }
      }

      final List<Map<String, dynamic>> lots = [];
      for (var a in allotmentList) {
        final aId = a['id'].toString();
        final status = (a['status'] ?? '').toString().toUpperCase();
        final mStatus = (a['mending_status'] ?? '').toString();

        // STRICT FILTER: Only show lots handed over from Lineman to Mending Floor
        final bool isHandedOverToMending = mStatus == 'PENDING_MENDING' || 
                                           mStatus == 'MENDING_IN_PROGRESS' || 
                                           mStatus == 'MENDING_RECEIVED' || 
                                           (status == 'COMPLETED' && mStatus != 'QC_PENDING' && mStatus != 'COUNTING_VERIFIED');

        if (!isHandedOverToMending) {
          continue; // Still on sewing floor with Lineman
        }

        final vars = (variantsRes)
            .where((v) => v['allotment_id'].toString() == aId)
            .map((v) => Map<String, dynamic>.from(v as Map))
            .toList();
        final assigns = (assignmentsRes)
            .where((m) => m['allotment_id'].toString() == aId)
            .map((m) => Map<String, dynamic>.from(m as Map))
            .toList();

        // Sort variants naturally by size
        vars.sort((x, y) => _naturalSizeCompare((x['size'] ?? '').toString(), (y['size'] ?? '').toString()));

        int totalTarget = 0;
        for (var v in vars) {
          totalTarget += _parseQty(v['quantity']);
        }

        int totalAssigned = 0;
        int totalCounted = 0;
        for (var m in assigns) {
          totalAssigned += _parseQty(m['assigned_qty']);
          final c = _parseQty(m['completed_qty']);
          totalCounted += c;
        }

        final artMap = _asMap(a['article']) ?? _asMap(a['articles']);
        final chalMap = _asMap(a['challans']) ?? _asMap(a['challan']);
        final lineMap = _asMap(a['lineman']) ?? _asMap(a['profiles']);

        final colPriority = (a['priority'] ?? '').toString().toUpperCase();
        final lotPriority = (colPriority == 'CRITICAL' || colPriority == 'RUSH' || colPriority == 'NORMAL')
            ? colPriority
            : (priorityMap[aId] ?? 'NORMAL');

        lots.add({
          ...a,
          'priority': lotPriority,
          'article': artMap,
          'challans': chalMap,
          'lineman': lineMap,
          'variants': vars,
          'assignments': assigns,
          'target_qty': totalTarget > 0 ? totalTarget : _parseQty(a['target_qty']),
          'total_assigned': totalAssigned,
          'total_counted': totalCounted,
        });
      }

      // Sort by production priority queue: CRITICAL (0) -> RUSH (1) -> NORMAL (2)
      int priorityWeight(String p) {
        if (p == 'CRITICAL') return 0;
        if (p == 'RUSH') return 1;
        return 2;
      }

      lots.sort((x, y) {
        final pX = priorityWeight((x['priority'] ?? 'NORMAL').toString());
        final pY = priorityWeight((y['priority'] ?? 'NORMAL').toString());
        if (pX != pY) return pX.compareTo(pY);
        final dtX = DateTime.tryParse(x['created_at']?.toString() ?? '') ?? DateTime(2000);
        final dtY = DateTime.tryParse(y['created_at']?.toString() ?? '') ?? DateTime(2000);
        return dtY.compareTo(dtX);
      });

      if (mounted) {
        setState(() {
          _lots = lots;
          _isLoading = false;

          // Retain selected lot or pick first from filtered/lots
          final fLots = _filteredLots;
          if (_selectedLot != null) {
            final match = lots.firstWhere(
              (l) => l['id'] == _selectedLot!['id'],
              orElse: () => fLots.isNotEmpty ? fLots.first : (lots.isNotEmpty ? lots.first : <String, dynamic>{}),
            );
            _selectedLot = match.isNotEmpty ? match : (fLots.isNotEmpty ? fLots.first : (lots.isNotEmpty ? lots.first : null));
          } else if (fLots.isNotEmpty) {
            _selectedLot = fLots.first;
          } else if (lots.isNotEmpty) {
            _selectedLot = lots.first;
          } else {
            _selectedLot = null;
          }
        });
      }
    } catch (e) {
      debugPrint('Mending lots fetch error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ======= ASSIGN MENDING WORKER =======
  void _openAssignWorkerModal() {
    if (_selectedLot == null) return;
    final rawVars = _selectedLot!['variants'] as List<dynamic>? ?? [];
    if (rawVars.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No color/size variants found for this article.')),
      );
      return;
    }

    final vars = rawVars.map((v) => Map<String, dynamic>.from(v as Map)).toList();

    _workerNameController.clear();
    _qtyController.clear();
    _notesController.clear();

    // Pick first variant that still has remaining unassigned pieces
    final initialVar = vars.firstWhere(
      (v) => _getRemainingQtyForVariant(v) > 0,
      orElse: () => vars.first,
    );

    _selectedVariantForAssignment = initialVar;
    final initialRem = _getRemainingQtyForVariant(initialVar);
    _qtyController.text = initialRem > 0 ? initialRem.toString() : '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final currentSelected = vars.firstWhere(
            (v) => (v['id'] != null && v['id'] == _selectedVariantForAssignment?['id']) ||
                   (v['color'] == _selectedVariantForAssignment?['color'] && v['size'] == _selectedVariantForAssignment?['size']),
            orElse: () => vars.first,
          );
          _selectedVariantForAssignment = currentSelected;

          final selVar = _selectedVariantForAssignment!;
          final vTarget = _parseQty(selVar['quantity']);
          final vAssigned = _getAssignedQtyForVariant(selVar);
          final vRem = vTarget - vAssigned;

          final workerName = _workerNameController.text.trim();
          final parsedQty = int.tryParse(_qtyController.text.trim()) ?? 0;
          final isFormValid = workerName.isNotEmpty && parsedQty > 0;

          return Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 512),
              margin: EdgeInsets.only(
                left: 12,
                right: 12,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                top: 24,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: const Color(0x1A000000), width: 1),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 28,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. HEADER BLOCK (#FAF7F0 cream, bottom border rgba(0,0,0,0.08))
                    Container(
                      padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFAF7F0),
                        border: Border(bottom: BorderSide(color: Color(0x14000000), width: 1)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Category Pill
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: const Color(0x26000000), width: 1),
                                  ),
                                  child: Text(
                                    'WORKER ALLOCATION',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF3A3564),
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Assign mending worker',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0F172A),
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Allocate piece bundle for thread trimming & counting',
                                  style: GoogleFonts.publicSans(
                                    fontSize: 11.5,
                                    color: const Color(0xFF475569),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => Navigator.pop(ctx),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0x1A000000)),
                                ),
                                child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF475569)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 2. SCROLLABLE FORM BODY (White background, padding ~16px)
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Field 1: Worker / Counter Name *
                            Text(
                              'WORKER / COUNTER NAME *',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF334155),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _workerNameController,
                              textCapitalization: TextCapitalization.words,
                              onChanged: (_) => setModalState(() {}),
                              style: GoogleFonts.publicSans(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF0F172A),
                              ),
                              decoration: InputDecoration(
                                hintText: 'Enter worker name (e.g. Ramesh)',
                                hintStyle: GoogleFonts.publicSans(
                                  fontSize: 13,
                                  color: const Color(0xFF94A3B8),
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFF3A3564), width: 1.5),
                                ),
                              ),
                            ),

                            // Quick recommendation chips
                            if (_recentWorkerNames.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: _recentWorkerNames.take(5).map((name) {
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: InkWell(
                                        onTap: () {
                                          setModalState(() {
                                            _workerNameController.text = name;
                                          });
                                        },
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFAF7F0),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: const Color(0x1A000000)),
                                          ),
                                          child: Text(
                                            '+ $name',
                                            style: GoogleFonts.publicSans(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF3A3564),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],

                            const SizedBox(height: 16),

                            // Field 2: Select Bundle Variant *
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'SELECT BUNDLE VARIANT *',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF334155),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  '${vRem > 0 ? vRem : 0} PCS REMAINING',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: vRem > 0 ? const Color(0xFF047857) : const Color(0xFFBE123C),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<Map<String, dynamic>>(
                                  isExpanded: true,
                                  value: _selectedVariantForAssignment,
                                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B), size: 20),
                                  items: vars.map((v) {
                                    final color = v['color'] ?? 'Standard';
                                    final size = v['size'] ?? 'Free';
                                    final target = _parseQty(v['quantity']);
                                    final assigned = _getAssignedQtyForVariant(v);
                                    final rem = target - assigned;
                                    final done = rem <= 0;

                                    return DropdownMenuItem<Map<String, dynamic>>(
                                      value: v,
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '$color - Size: $size (Target: $target pcs)',
                                              style: GoogleFonts.publicSans(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w600,
                                                color: done ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: done ? const Color(0xFFECFDF5) : const Color(0xFFFFFCF3),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: done ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A),
                                                width: 1,
                                              ),
                                            ),
                                            child: Text(
                                              done ? '0 PCS LEFT' : '$rem PCS LEFT',
                                              style: GoogleFonts.jetBrainsMono(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w800,
                                                color: done ? const Color(0xFF047857) : const Color(0xFF92400E),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (newVal) {
                                    if (newVal != null) {
                                      setModalState(() {
                                        _selectedVariantForAssignment = newVal;
                                        final rem = _getRemainingQtyForVariant(newVal);
                                        _qtyController.text = rem > 0 ? rem.toString() : '';
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            // Field 3: Lot Stat Strip
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFAF7F0),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0x14000000)),
                              ),
                              child: Row(
                                children: [
                                  // Lot Target
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'LOT TARGET',
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF64748B),
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '$vTarget pcs',
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF0F172A),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(width: 1, height: 26, color: const Color(0x14000000)),
                                  const SizedBox(width: 12),

                                  // Assigned
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Text(
                                          'ASSIGNED',
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF64748B),
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '$vAssigned pcs',
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF0F172A),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(width: 1, height: 26, color: const Color(0x14000000)),
                                  const SizedBox(width: 12),

                                  // Remaining
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'REMAINING',
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF64748B),
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          vRem > 0 ? '$vRem pcs' : '0 pcs',
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: vRem > 0 ? const Color(0xFF047857) : const Color(0xFF0F172A),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Field 4: Two-column row (Pieces to count * & Table / location)
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'PIECES TO COUNT *',
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF334155),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      TextField(
                                        controller: _qtyController,
                                        keyboardType: TextInputType.number,
                                        onChanged: (_) => setModalState(() {}),
                                        style: GoogleFonts.jetBrainsMono(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                          color: const Color(0xFF0F172A),
                                        ),
                                        decoration: InputDecoration(
                                          hintText: 'e.g. 50',
                                          hintStyle: GoogleFonts.jetBrainsMono(
                                            fontSize: 13,
                                            color: const Color(0xFF94A3B8),
                                          ),
                                          filled: true,
                                          fillColor: const Color(0xFFF8FAFC),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: const BorderSide(color: Color(0xFF3A3564), width: 1.5),
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
                                        'TABLE / LOCATION',
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF334155),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      TextField(
                                        controller: _notesController,
                                        style: GoogleFonts.publicSans(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF0F172A),
                                        ),
                                        decoration: InputDecoration(
                                          hintText: 'Table 2',
                                          hintStyle: GoogleFonts.publicSans(
                                            fontSize: 13,
                                            color: const Color(0xFF94A3B8),
                                          ),
                                          filled: true,
                                          fillColor: const Color(0xFFF8FAFC),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: const BorderSide(color: Color(0xFF3A3564), width: 1.5),
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

                    // 3. FOOTER BLOCK (#FAF7F0 cream, top border rgba(0,0,0,0.08), padding ~14-16px)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFAF7F0),
                        border: Border(top: BorderSide(color: Color(0x14000000), width: 1)),
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isFormValid ? const Color(0xFF3A3564) : const Color(0xFF94A3B8),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          onPressed: () async {
                            final name = _workerNameController.text.trim();
                            final qty = int.tryParse(_qtyController.text.trim()) ?? 0;
                            if (name.isEmpty || qty <= 0) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(content: Text('Please enter valid worker name and pieces to count.')),
                              );
                              return;
                            }

                            // Check if qty exceeds remaining
                            if (_selectedVariantForAssignment != null) {
                              final rem = _getRemainingQtyForVariant(_selectedVariantForAssignment!);
                              if (rem > 0 && qty > rem) {
                                final proceed = await showDialog<bool>(
                                  context: ctx,
                                  builder: (dCtx) => AlertDialog(
                                    backgroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    title: Row(
                                      children: [
                                        const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 22),
                                        const SizedBox(width: 8),
                                        Text('Exceeds Remaining', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF0F172A))),
                                      ],
                                    ),
                                    content: Text(
                                      'Only $rem pcs are remaining for ${_selectedVariantForAssignment!['color']} (Size: ${_selectedVariantForAssignment!['size']}). You entered $qty pcs.\n\nDo you want to allocate $qty pcs anyway?',
                                      style: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF0F172A)),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(dCtx, false),
                                        child: Text('Cancel / Edit Qty', style: GoogleFonts.publicSans(color: const Color(0xFF64748B))),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3A3564)),
                                        onPressed: () => Navigator.pop(dCtx, true),
                                        child: const Text('Proceed Anyway', style: TextStyle(color: Colors.white)),
                                      ),
                                    ],
                                  ),
                                );
                                if (proceed != true) return;
                              }
                            }

                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                            await _saveRecentWorker(name);
                            await _submitWorkerAssignment(name, qty);
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.play_arrow_rounded, size: 18, color: Colors.white),
                              const SizedBox(width: 6),
                              Text(
                                'Assign worker & start counting',
                                style: GoogleFonts.publicSans(
                                  fontSize: 13.5,
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
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _submitWorkerAssignment(String workerName, int qty) async {
    if (_selectedLot == null || _selectedVariantForAssignment == null) return;
    final lotId = _selectedLot!['id'].toString();
    final articleId = _selectedLot!['article_id'];
    final color = _selectedVariantForAssignment!['color']?.toString();
    final size = _selectedVariantForAssignment!['size']?.toString();
    final notes = _notesController.text.trim();
    final user = supabase.auth.currentUser;

    try {
      await supabase.from('mending_assignments').insert({
        'allotment_id': lotId,
        'mending_supervisor_id': user?.id,
        'article_id': articleId,
        'worker_name': workerName,
        'color': color,
        'size': size,
        'assigned_qty': qty,
        'completed_qty': 0,
        'status': 'PENDING',
        'notes': notes.isNotEmpty ? notes : null,
        'assigned_at': DateTime.now().toUtc().toIso8601String(),
        'entry_date': DateTime.now().toIso8601String().split('T')[0],
      });

      // Update allotment mending status to in-progress
      try {
        await supabase.from('allotments').update({
          'mending_status': 'MENDING_IN_PROGRESS',
        }).eq('id', lotId);
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF047857),
            content: Text('Assigned $qty pcs ($color, Size $size) to $workerName'),
          ),
        );
        _fetchMendingLots();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: const Color(0xFFBE123C), content: Text('Assignment error: $e')),
        );
      }
    }
  }

  // ======= RECORD WORKER PHYSICAL COUNT =======
  void _openRecordCountDialog(Map<String, dynamic> assignment) {
    final assignedQty = _parseQty(assignment['assigned_qty']);
    final currentDone = _parseQty(assignment['completed_qty']);
    final workerName = assignment['worker_name']?.toString() ?? 'Worker';
    final countController = TextEditingController(text: currentDone > 0 ? currentDone.toString() : assignedQty.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Record Physical Count',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF0F172A)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Worker: $workerName',
              style: GoogleFonts.publicSans(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF0F172A)),
            ),
            const SizedBox(height: 4),
            Text(
              'Bundle: ${assignment['color']} • Size: ${assignment['size']}',
              style: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Text(
                  'Assigned Pieces: ',
                  style: GoogleFonts.publicSans(fontSize: 12.5, color: const Color(0xFF64748B)),
                ),
                Text(
                  '$assignedQty pcs',
                  style: GoogleFonts.jetBrainsMono(fontSize: 13, color: const Color(0xFF3A3564), fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'PHYSICAL COUNTED PIECES *',
              style: GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: countController,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: GoogleFonts.jetBrainsMono(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFFAF7F0),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0x1A000000)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0x1A000000)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF3A3564), width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.publicSans(color: const Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF047857),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final counted = int.tryParse(countController.text.trim()) ?? 0;
              Navigator.pop(ctx);
              try {
                await supabase.from('mending_assignments').update({
                  'completed_qty': counted,
                  'status': 'DONE',
                  'completed_at': DateTime.now().toUtc().toIso8601String(),
                }).eq('id', assignment['id']);

                _fetchMendingLots();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(backgroundColor: const Color(0xFFBE123C), content: Text('Error updating count: $e')),
                  );
                }
              }
            },
            child: const Text('Save Count', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ======= DELETE MENDING ASSIGNMENT =======
  Future<void> _deleteAssignment(String id, String workerName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Remove Assignment?', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: const Color(0xFFBE123C))),
        content: Text('Are you sure you want to remove the mending assignment for $workerName?', style: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF0F172A))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: GoogleFonts.publicSans(color: const Color(0xFF64748B)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFBE123C)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await supabase.from('mending_assignments').delete().eq('id', id);
        _fetchMendingLots();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  // ======= HANDOVER TO QC FLOOR MODAL =======
  Future<void> _openHandoverToQcModal() async {
    if (_selectedLot == null) return;
    
    final lot = _selectedLot!;
    final assigns = (lot['assignments'] as List<dynamic>?) ?? [];
    int totalCounted = 0;
    for (var a in assigns) {
      if (a is Map) {
        totalCounted += _parseQty(a['completed_qty']);
      }
    }
    if (totalCounted == 0) {
      totalCounted = _parseQty(lot['total_counted']);
    }
    final targetQty = _parseQty(lot['target_qty']);

    if (targetQty > 0 && totalCounted < targetQty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ Cannot forward: Only $totalCounted of $targetQty pcs counted. Please complete count verification first.'),
          backgroundColor: const Color(0xFFB45309),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    await _fetchQcSupervisors();
    if (!mounted) return;

    final art = _asMap(lot['article']) ?? _asMap(lot['articles']);
    final artNo = art?['art_no']?.toString() ?? 'N/A';
    final challan = _asMap(lot['challans']) ?? _asMap(lot['challan']);
    final challanNo = challan?['challan_no']?.toString() ?? 'CH-${lot['id'].toString().substring(0, 4)}';
    final variance = totalCounted - targetQty;

    String? selectedSupervisorId;
    String selectedSupervisorName = 'General QC Pool';
    final notesController = TextEditingController(text: 'Table 2, Counted $totalCounted pcs');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Handover Lot to QC Floor',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Reconciled piece bundle & chain-of-custody transfer',
                              style: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Lot Summary Info Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF7F0),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0x1A000000)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'ART $artNo',
                              style: GoogleFonts.jetBrainsMono(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                            ),
                            Text(
                              challanNo,
                              style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Physical Counted: $totalCounted pcs',
                              style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF047857)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: variance == 0 ? const Color(0xFFECFDF5) : (variance < 0 ? const Color(0xFFFEF3C7) : const Color(0xFFEFF6FF)),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: variance == 0 ? const Color(0xFFA7F3D0) : (variance < 0 ? const Color(0xFFFDE68A) : const Color(0xFFBFDBFE)),
                                ),
                              ),
                              child: Text(
                                variance == 0 ? '100% Match' : (variance < 0 ? '$variance pcs Shortage' : '+$variance pcs Excess'),
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: variance == 0 ? const Color(0xFF047857) : (variance < 0 ? const Color(0xFFB45309) : const Color(0xFF1D4ED8)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Select QC Supervisor
                  Text(
                    'SELECT RECEIVING QC SUPERVISOR *',
                    style: GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF7F0),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0x1A000000)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        isExpanded: true,
                        value: selectedSupervisorId,
                        hint: Text('General QC Pool (Unassigned)', style: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF3A3564))),
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Row(
                              children: [
                                const Icon(Icons.group_outlined, size: 16, color: Color(0xFF64748B)),
                                const SizedBox(width: 8),
                                Text(
                                  'General QC Pool (Any available checker)',
                                  style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          ..._qcSupervisors.map((sup) {
                            final name = (sup['username'] as String?)?.isNotEmpty == true
                                ? sup['username']
                                : 'QC Supervisor';
                            return DropdownMenuItem<String?>(
                              value: sup['id'].toString(),
                              child: Row(
                                children: [
                                  const Icon(Icons.person_outline, size: 16, color: Color(0xFF047857)),
                                  const SizedBox(width: 8),
                                  Text(
                                    '$name (QC Supervisor)',
                                    style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF3A3564)),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          setModalState(() {
                            selectedSupervisorId = val;
                            if (val == null) {
                              selectedSupervisorName = 'General QC Pool';
                            } else {
                              final found = _qcSupervisors.firstWhere((s) => s['id'].toString() == val, orElse: () => {});
                              selectedSupervisorName = found['username'] ?? 'QC Supervisor';
                            }
                          });
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Handover Notes / Location
                  Text(
                    'HANDOVER REMARKS / TABLE LOCATION',
                    style: GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: notesController,
                    decoration: InputDecoration(
                      hintText: 'e.g. Table 2, 500 pcs counted, zero shortage',
                      filled: true,
                      fillColor: const Color(0xFFFAF7F0),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0x1A000000)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0x1A000000)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF3A3564), width: 1.5),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Confirm Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF047857),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        final notes = notesController.text.trim();
                        Navigator.pop(ctx);
                        _submitHandoverToQc(
                          supervisorId: selectedSupervisorId,
                          supervisorName: selectedSupervisorName,
                          notes: notes,
                        );
                      },
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                      label: Text(
                        'Confirm Handover to $selectedSupervisorName',
                        style: GoogleFonts.publicSans(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
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

  Future<void> _submitHandoverToQc({
    required String? supervisorId,
    required String supervisorName,
    required String notes,
  }) async {
    if (_selectedLot == null) return;
    setState(() => _isSubmitting = true);

    try {
      final lotId = _selectedLot!['id'].toString();
      final articleId = _selectedLot!['article_id'];
      final linemanId = _selectedLot!['lineman_id'];
      final totalCounted = _parseQty(_selectedLot!['total_counted']);
      final targetQty = _parseQty(_selectedLot!['target_qty']);
      final variance = totalCounted - targetQty;

      final user = supabase.auth.currentUser;
      final profileRes = await supabase.from('profiles').select('username').eq('id', user?.id ?? '').maybeSingle();
      final senderName = profileRes?['username'] ?? user?.email?.split('@').first ?? 'Mending Supervisor';

      final varianceRemark = variance == 0
          ? 'Exact 100% Match (Zero Shortage)'
          : variance < 0
              ? 'Shortage: $variance pcs from Stitching floor'
              : 'Excess: +$variance pcs';

      // 1. Insert audit record into qc_logs
      final todayStr = DateTime.now().toIso8601String().split('T')[0];
      await supabase.from('qc_logs').insert({
        'allotment_id': lotId,
        'article_id': articleId,
        'from_lineman_id': linemanId,
        'stage': 'RECEIVING',
        'qty_received': totalCounted,
        'qty_passed': totalCounted,
        'qty_rejected': 0,
        'defect_type': 'NONE',
        'remarks': 'Mending Floor Physical Count Verified ($totalCounted pcs). $varianceRemark${notes.isNotEmpty ? " • Note: $notes" : ""}',
        'mending_status': 'COUNTING_VERIFIED',
        'entry_date': todayStr,
      });

      // 2. Update allotment status to QC_PENDING with QC supervisor custody metadata
      await supabase.from('allotments').update({
        'mending_status': 'QC_PENDING',
        'qc_status': 'QC_PENDING',
        'mending_verified_at': DateTime.now().toUtc().toIso8601String(),
        'mending_total_counted': totalCounted,
        'qc_supervisor_id': supervisorId,
        'qc_supervisor_name': supervisorName,
        'handed_to_qc_by': senderName,
        'handed_to_qc_at': DateTime.now().toUtc().toIso8601String(),
        'qc_handover_notes': notes.isNotEmpty ? notes : null,
      }).eq('id', lotId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF047857),
            content: Text(
              'Lot verified! $totalCounted pcs handed over to $supervisorName on QC Floor.',
              style: GoogleFonts.publicSans(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        );
        _fetchMendingLots();
      }
    } catch (e) {
      debugPrint('Handover to QC error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: const Color(0xFFBE123C), content: Text('QC Handover Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _showSignOutDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.logout_rounded, color: Color(0xFFE11D48), size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              'Sign Out',
              style: GoogleFonts.publicSans(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to end your current session and sign out of Zigza MES?',
          style: GoogleFonts.publicSans(
            fontSize: 13,
            color: const Color(0xFF475569),
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.publicSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF475569),
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Sign Out',
              style: GoogleFonts.publicSans(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(authProvider.notifier).logout();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F0), // Warm cream canvas
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar with Zigza. branding and Sign Out button
            _buildTopNavbar(),

            // Encapsulated Top Header Card
            _buildEncapsulatedHeader(),

            // Body Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF3A3564)))
                  : _lots.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          color: const Color(0xFF3A3564),
                          backgroundColor: Colors.white,
                          onRefresh: _fetchMendingLots,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 1. Two-Button Filter Row (My Assigned vs All Floor)
                                _buildFilterBar(),
                                const SizedBox(height: 12),

                                // 2. Lot Selector Strip (Horizontal Cards with Scrollbar Controls)
                                LotSelectorStrip(
                                  lots: _filteredLots,
                                  selectedLot: _selectedLot,
                                  onLotSelected: (lot) {
                                    setState(() {
                                      _selectedLot = lot;
                                    });
                                  },
                                ),

                                // Priority Alert Banner if CRITICAL or RUSH
                                if (_selectedLot != null &&
                                    ((_selectedLot!['priority'] ?? 'NORMAL').toString().toUpperCase() == 'CRITICAL' ||
                                     (_selectedLot!['priority'] ?? 'NORMAL').toString().toUpperCase() == 'RUSH')) ...[
                                  _buildSelectedLotPriorityBanner((_selectedLot!['priority'] ?? 'NORMAL').toString().toUpperCase()),
                                  const SizedBox(height: 12),
                                ],

                                // 3. Tab Pair (Pill-style)
                                _buildTabPills(),
                                const SizedBox(height: 12),

                                // Tab Content
                                if (_selectedLot == null)
                                  Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: const Color(0x1A000000)),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'No lots found in this filter.',
                                        style: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF64748B)),
                                      ),
                                    ),
                                  )
                                else if (_selectedTabIndex == 0)
                                  _buildWorkerAssignmentsSection()
                                else
                                  _buildNaturalMatrixSection(),
                              ],
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // Top App Bar with Zigza branding and Sign Out button
  Widget _buildTopNavbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF3A3564),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  'Zigza.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0x2A000000)),
                ),
                child: Text(
                  'ERP MES',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF3A3564),
                  ),
                ),
              ),
            ],
          ),

          // Sign Out Action Button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showSignOutDialog(context),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFECDD3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.logout_rounded,
                      size: 14,
                      color: Color(0xFFE11D48),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Sign Out',
                      style: GoogleFonts.publicSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFE11D48),
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

  // Encapsulated Top Header Card ("Mending & counting")
  Widget _buildEncapsulatedHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1A000000)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFFAF7F0),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x1A000000)),
            ),
            child: const Icon(
              Icons.format_list_bulleted_rounded,
              color: Color(0xFF3A3564),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Mending & counting',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Floor inward & worker piece verification',
                  style: GoogleFonts.publicSans(
                    fontSize: 11.5,
                    color: const Color(0xFF64748B),
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF047857),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  'ONLINE',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF047857),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Two-Button Filter Row
  Widget _buildFilterBar() {
    final currentUserId = supabase.auth.currentUser?.id;
    final myCount = _lots.where((l) {
      final supId = l['mending_supervisor_id']?.toString();
      return supId == null || supId.isEmpty || supId == currentUserId;
    }).length;
    final allCount = _lots.length;

    return Row(
      children: [
        Expanded(
          child: _buildFilterButton(
            index: 0,
            title: 'My assigned',
            count: myCount,
            icon: Icons.person_outline_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildFilterButton(
            index: 1,
            title: 'All floor lots',
            count: allCount,
            icon: Icons.inventory_2_outlined,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterButton({
    required int index,
    required String title,
    required int count,
    IconData? icon,
  }) {
    final isSelected = _filterMode == index;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _filterMode = index;
            final fLots = _filteredLots;
            if (fLots.isNotEmpty) {
              if (_selectedLot == null || !fLots.any((l) => l['id'] == _selectedLot!['id'])) {
                _selectedLot = fLots.first;
              }
            } else {
              _selectedLot = null;
            }
          });
        },
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF3A3564) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? const Color(0xFF3A3564) : const Color(0x1A000000),
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF3A3564).withValues(alpha: 0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : const [
                    BoxShadow(
                      color: Color(0x06000000),
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 15,
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                ),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: Text(
                  title,
                  style: GoogleFonts.publicSans(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                '($count)',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? const Color(0xFFA5B4FC) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Tab Pair (Pill-style, separated capsules)
  Widget _buildTabPills() {
    return Row(
      children: [
        Expanded(
          child: _buildTabPillItem(
            index: 0,
            label: 'Worker assignments',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildTabPillItem(
            index: 1,
            label: 'Challan matrix & QC',
          ),
        ),
      ],
    );
  }

  Widget _buildTabPillItem({
    required int index,
    required String label,
  }) {
    final isSelected = _selectedTabIndex == index;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedTabIndex = index),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF3A3564) : const Color(0xFFFAF7F0),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFF3A3564) : const Color(0x2A000000),
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF3A3564).withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.publicSans(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF1E293B),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }

  // Lineman Custody Callout
  Widget _buildLinemanCallout(Map<String, dynamic> lot) {
    final handedBy = lot['handed_to_mending_by']?.toString();
    final linemanName = (handedBy != null && handedBy.isNotEmpty)
        ? handedBy
        : (_asMap(lot['lineman'])?['username']?.toString() ?? 'Lineman');
    final supName = lot['mending_supervisor_name']?.toString() ?? 'General Pool';
    final notes = lot['mending_handover_notes']?.toString();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEFCE8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE047)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.south_east_rounded, size: 16, color: Color(0xFFB45309)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'From lineman: $linemanName',
                  style: GoogleFonts.publicSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF92400E),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Text(
                  'CUSTODY: $supName',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF92400E),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (notes != null && notes.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              'Handover Note: "$notes"',
              style: GoogleFonts.publicSans(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: const Color(0xFF78350F),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Counting Progress Card
  Widget _buildCountingProgressCard(Map<String, dynamic> lot) {
    final target = _parseQty(lot['target_qty']);
    final assigned = _parseQty(lot['total_assigned']);
    final counted = _parseQty(lot['total_counted']);

    final art = _asMap(lot['article']) ?? _asMap(lot['articles']);
    final artNo = art?['art_no']?.toString() ?? '4225';
    final progress = target > 0 ? (counted / target).clamp(0.0, 1.0) : 0.0;
    final isComplete = target > 0 && counted >= target;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1A000000)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'COUNTING PROGRESS - SELECTED LOT',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF64748B),
                  letterSpacing: 0.6,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF7F0),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0x1A000000)),
                ),
                child: Text(
                  'ART  $artNo',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF3A3564),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$counted',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isComplete ? const Color(0xFF047857) : const Color(0xFF0F172A),
                  ),
                ),
                TextSpan(
                  text: ' of ',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
                TextSpan(
                  text: '$target',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                TextSpan(
                  text: ' pieces verified',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Horizontal thin progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation<Color>(
                isComplete ? const Color(0xFF047857) : const Color(0xFF3A3564),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Inline 3-stat row: Target: 567 pcs    Assigned: 0 pcs    Counted: 0 pcs
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'Target: ',
                      style: GoogleFonts.publicSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    TextSpan(
                      text: '$target pcs',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'Assigned: ',
                      style: GoogleFonts.publicSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    TextSpan(
                      text: '$assigned pcs',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'Counted: ',
                      style: GoogleFonts.publicSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    TextSpan(
                      text: '$counted pcs',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: counted > 0 ? const Color(0xFF047857) : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Full-width Assign worker button
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _openAssignWorkerModal,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3A3564),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.person_add_outlined, size: 17, color: Colors.white),
              label: Text(
                'Assign worker',
                style: GoogleFonts.publicSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Priority Alert Banner
  Widget _buildSelectedLotPriorityBanner(String priority) {
    final isCritical = priority == 'CRITICAL';
    final bgColor = isCritical ? const Color(0xFFFFF1F2) : const Color(0xFFFFFBEB);
    final borderColor = isCritical ? const Color(0xFFFECDD3) : const Color(0xFFFDE68A);
    final textColor = isCritical ? const Color(0xFFBE123C) : const Color(0xFF92400E);
    final subtextColor = isCritical ? const Color(0xFF9F1239) : const Color(0xFFB45309);
    final icon = isCritical ? Icons.local_fire_department_rounded : Icons.bolt_rounded;
    final iconColor = isCritical ? const Color(0xFFE11D48) : const Color(0xFFD97706);
    final label = isCritical
        ? 'CRITICAL EXPORT PRIORITY (DO THIS FIRST)'
        : 'RUSH ORDER PRIORITY (HIGH URGENCY)';
    final desc = isCritical
        ? 'Prioritize thread trimming and piece verification for this lot.'
        : 'Rush production allotment. Expedite worker assignment & counting.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: borderColor),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  desc,
                  style: GoogleFonts.publicSans(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: subtextColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // TAB 1: Worker Assignments Section
  Widget _buildWorkerAssignmentsSection() {
    final lot = _selectedLot!;
    final assigns = (lot['assignments'] as List<dynamic>?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 6. Amber Lineman Callout
        _buildLinemanCallout(lot),
        const SizedBox(height: 12),

        // 7. Counting Progress Card
        _buildCountingProgressCard(lot),
        const SizedBox(height: 18),

        // 8. Assigned Staff Section Label
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ASSIGNED MENDING & COUNTING STAFF',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: const Color(0xFF475569),
              ),
            ),
            Text(
              '(${assigns.length})',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF3A3564),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // 9. Staff list or empty state
        if (assigns.isEmpty)
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x1A000000)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x08000000),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Center(
              child: Column(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF7F0),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0x1A000000)),
                    ),
                    child: const Icon(
                      Icons.people_outline_rounded,
                      size: 26,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No workers assigned yet',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap "+ Assign worker" to distribute bundle counting to your staff.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.publicSans(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...assigns.map((ass) => _buildWorkerAssignmentCard(ass)),
      ],
    );
  }

  Widget _buildWorkerAssignmentCard(dynamic ass) {
    if (ass is! Map) return const SizedBox.shrink();
    final workerName = ass['worker_name']?.toString() ?? 'Worker';
    final color = ass['color']?.toString() ?? 'Standard';
    final size = ass['size']?.toString() ?? 'Free';
    final assignedQty = _parseQty(ass['assigned_qty']);
    final completedQty = _parseQty(ass['completed_qty']);
    final isDone = ass['status']?.toString() == 'DONE' || (completedQty >= assignedQty && assignedQty > 0);
    final notes = ass['notes']?.toString();
    final remainingQty = (assignedQty - completedQty).clamp(0, assignedQty);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDone ? const Color(0xFFA7F3D0) : const Color(0x1A000000),
          width: isDone ? 1.5 : 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 4,
            offset: Offset(0, 1.5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Avatar + Name + Variant Tag + Status + Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
            child: Row(
              children: [
                // Worker Avatar
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isDone ? const Color(0xFFECFDF5) : const Color(0xFFFAF7F0),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDone ? const Color(0xFFA7F3D0) : const Color(0x1A000000),
                    ),
                  ),
                  child: Icon(
                    isDone ? Icons.check_circle_rounded : Icons.person_rounded,
                    color: isDone ? const Color(0xFF047857) : const Color(0xFF3A3564),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                // Worker Name + Color & Size tags
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        workerName,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: Text(
                              color,
                              style: GoogleFonts.publicSans(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1D4ED8),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAF5FF),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: const Color(0xFFE9D5FF)),
                            ),
                            child: Text(
                              'Size: $size',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF6B21A8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Status Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: isDone ? const Color(0xFFECFDF5) : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isDone ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A),
                    ),
                  ),
                  child: Text(
                    isDone ? 'COUNTED' : 'PENDING',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: isDone ? const Color(0xFF047857) : const Color(0xFFB45309),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Action: Delete
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFF94A3B8), size: 18),
                  tooltip: 'Remove assignment',
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  padding: const EdgeInsets.all(4),
                  onPressed: () => _deleteAssignment(ass['id'].toString(), workerName),
                ),
              ],
            ),
          ),

          // Optional Note
          if (notes != null && notes.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 14, right: 14, bottom: 8),
              child: Text(
                'Note: "$notes"',
                style: GoogleFonts.publicSans(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: const Color(0xFF64748B),
                ),
              ),
            ),

          // Bottom Stats Bar & Record Count CTA
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDone ? const Color(0xFFF0FDF4) : const Color(0xFFFAF7F0),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15)),
              border: Border(
                top: BorderSide(color: isDone ? const Color(0xFFA7F3D0) : const Color(0x14000000)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Assigned / Counted Metrics
                Expanded(
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ASSIGNED',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF64748B),
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            '$assignedQty pcs',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'COUNTED',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF64748B),
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            '$completedQty pcs',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDone ? const Color(0xFF047857) : const Color(0xFF3A3564),
                            ),
                          ),
                        ],
                      ),
                      if (!isDone && remainingQty > 0) ...[
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'REMAINING',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFB45309),
                                letterSpacing: 0.4,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              '$remainingQty pcs',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFB45309),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                // Enter Count Button
                ElevatedButton.icon(
                  onPressed: () => _openRecordCountDialog(Map<String, dynamic>.from(ass)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDone ? const Color(0xFF047857) : const Color(0xFF3A3564),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    minimumSize: const Size(0, 32),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: Icon(isDone ? Icons.edit_rounded : Icons.check_rounded, size: 14, color: Colors.white),
                  label: Text(
                    isDone ? 'Edit Count' : 'Enter Count',
                    style: GoogleFonts.publicSans(fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // TAB 2: Natural Matrix & QC Handover Section
  Widget _buildNaturalMatrixSection() {
    final lot = _selectedLot!;
    final rawVars = (lot['variants'] as List<dynamic>?) ?? [];
    // Only consider variants that have quantity > 0
    final vars = rawVars.where((v) => v is Map && _parseQty(v['quantity']) > 0).toList();
    final assigns = (lot['assignments'] as List<dynamic>?) ?? [];
    final art = _asMap(lot['article']) ?? _asMap(lot['articles']);
    final artNo = art?['art_no']?.toString() ?? 'N/A';
    
    final lineman = _asMap(lot['lineman']);
    final linemanName = lineman?['username']?.toString() ?? 'Lineman';
    final chal = _asMap(lot['challans']);
    final chalNo = chal?['challan_no']?.toString() ?? '';
    final brand = chal?['brand']?.toString() ?? '';
    final fabric = chal?['fabric_type']?.toString() ?? '';

    // Collect distinct colors and distinct sizes present in this specific lineman allotment
    final List<String> lotColors = [];
    final List<String> lotSizes = [];
    for (var v in (vars.isNotEmpty ? vars : rawVars)) {
      if (v is Map) {
        final c = (v['color'] ?? 'Standard').toString().trim();
        final s = (v['size'] ?? 'Free').toString().trim();
        if (c.isNotEmpty && !lotColors.contains(c)) lotColors.add(c);
        if (s.isNotEmpty && !lotSizes.contains(s)) lotSizes.add(s);
      }
    }

    final String colorsText = lotColors.isNotEmpty ? lotColors.join(', ') : 'Standard';
    final String sizesText = lotSizes.isNotEmpty ? lotSizes.join(' / ') : 'All Sizes';

    // Group assigned and completed counts by "Color_Size"
    final Map<String, int> assignedMap = {};
    final Map<String, int> countedMap = {};
    for (var a in assigns) {
      if (a is Map) {
        final key = '${(a['color'] ?? 'Standard').toString().trim().toUpperCase()}_${(a['size'] ?? 'Free').toString().trim().toUpperCase()}';
        assignedMap[key] = (assignedMap[key] ?? 0) + _parseQty(a['assigned_qty']);
        countedMap[key] = (countedMap[key] ?? 0) + _parseQty(a['completed_qty']);
      }
    }

    int grandTarget = 0;
    for (var v in vars) {
      if (v is Map) {
        grandTarget += _parseQty(v['quantity']);
      }
    }

    int grandCounted = 0;
    for (var a in assigns) {
      if (a is Map) {
        grandCounted += _parseQty(a['completed_qty']);
      }
    }

    if (grandTarget == 0) {
      grandTarget = _parseQty(lot['target_qty']);
    }

    final isCompleted = grandTarget > 0 && grandCounted >= grandTarget;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Article Header
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x1A000000)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x08000000),
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ARTICLE: $artNo',
                    style: GoogleFonts.jetBrainsMono(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Text(
                      'NATURAL SIZE MATRIX',
                      style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF047857)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Dynamic Lot Specs (Lineman, Color, Size, Challan)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person_pin_circle_outlined, size: 12, color: Color(0xFF475569)),
                        const SizedBox(width: 4),
                        Text(
                          'Lineman: $linemanName',
                          style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.palette_outlined, size: 12, color: Color(0xFF1D4ED8)),
                        const SizedBox(width: 4),
                        Text(
                          'Color: $colorsText',
                          style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF1E40AF)),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF5FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE9D5FF)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.straighten_rounded, size: 12, color: Color(0xFF7E22CE)),
                        const SizedBox(width: 4),
                        Text(
                          'Sizes: $sizesText',
                          style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF6B21A8)),
                        ),
                      ],
                    ),
                  ),
                  if (brand.isNotEmpty || chalNo.isNotEmpty || fabric.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        '${brand.isNotEmpty ? brand : ''}${brand.isNotEmpty && chalNo.isNotEmpty ? ' • ' : ''}${chalNo.isNotEmpty ? 'Challan: $chalNo' : ''}${fabric.isNotEmpty ? ' ($fabric)' : ''}',
                        style: GoogleFonts.publicSans(fontSize: 11, color: const Color(0xFF64748B)),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Natural Size Grid Table
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x1A000000)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x08000000),
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFFFAF7F0),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                ),
                child: Row(
                  children: [
                    Expanded(flex: 7, child: Text('COLOR / SIZE', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)))),
                    Expanded(flex: 4, child: Text('TARGET', textAlign: TextAlign.center, style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)))),
                    Expanded(flex: 4, child: Text('COUNTED', textAlign: TextAlign.center, style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)))),
                    Expanded(flex: 4, child: Text('VARIANCE', textAlign: TextAlign.right, style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)))),
                  ],
                ),
              ),

              if (vars.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'No variant details recorded for this article.',
                      style: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                  ),
                )
              else
                ...vars.map((v) {
                  final color = v['color']?.toString() ?? 'Standard';
                  final size = v['size']?.toString() ?? 'Free';
                  final target = _parseQty(v['quantity']);
                  final key = '${color.trim().toUpperCase()}_${size.trim().toUpperCase()}';
                  final assigned = assignedMap[key] ?? 0;
                  final counted = countedMap[key] ?? 0;
                  final diff = counted - target;

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Color(0x1A000000))),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 7,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                color,
                                style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 1),
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(text: 'Size: ', style: GoogleFonts.publicSans(fontSize: 10.5, color: const Color(0xFF64748B))),
                                    TextSpan(text: size, style: GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF3A3564))),
                                    TextSpan(text: ' • Asg: ', style: GoogleFonts.publicSans(fontSize: 10.5, color: const Color(0xFF64748B))),
                                    TextSpan(text: '$assigned/$target', style: GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 4,
                          child: Text(
                            '$target pcs',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.jetBrainsMono(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                          ),
                        ),
                        Expanded(
                          flex: 4,
                          child: Text(
                            '$counted pcs',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.jetBrainsMono(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFF3A3564)),
                          ),
                        ),
                        Expanded(
                          flex: 4,
                          child: Text(
                            diff == 0
                                ? 'MATCH'
                                : diff < 0
                                    ? '$diff pcs'
                                    : '+$diff pcs',
                            textAlign: TextAlign.right,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: diff == 0
                                  ? const Color(0xFF047857)
                                  : diff < 0
                                      ? const Color(0xFFB45309)
                                      : const Color(0xFF1D4ED8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

              // Grand Total Row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFFFAF7F0),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
                  border: Border(top: BorderSide(color: Color(0x1A000000), width: 1.5)),
                ),
                child: Row(
                  children: [
                    Expanded(flex: 7, child: Text('TOTAL PIECES', style: GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF3A3564)))),
                    Expanded(flex: 4, child: Text('$grandTarget', textAlign: TextAlign.center, style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF3A3564)))),
                    Expanded(flex: 4, child: Text('$grandCounted', textAlign: TextAlign.center, style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF047857)))),
                    Expanded(
                      flex: 4,
                      child: Text(
                        grandCounted == grandTarget
                            ? 'MATCH'
                            : '${grandCounted - grandTarget} pcs',
                        textAlign: TextAlign.right,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: grandCounted == grandTarget ? const Color(0xFF047857) : const Color(0xFFB45309),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // Locked / Incomplete warning banner
        if (!isCompleted)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_clock_outlined, size: 18, color: Color(0xFFD97706)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Counting Incomplete ($grandCounted / $grandTarget pcs verified). Forwarding to QC is locked until 100% physical count is completed.',
                    style: GoogleFonts.publicSans(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF92400E)),
                  ),
                ),
              ],
            ),
          ),

        // Handover to QC Floor Button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: isCompleted ? const Color(0xFF047857) : const Color(0xFFE2E8F0),
              foregroundColor: isCompleted ? Colors.white : const Color(0xFF94A3B8),
              elevation: isCompleted ? 2 : 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: (_isSubmitting || !isCompleted)
                ? () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('⚠️ Cannot forward: $grandCounted of $grandTarget pcs counted. Please complete count verification in "Worker Assignments" tab.'),
                        backgroundColor: const Color(0xFFB45309),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                : _openHandoverToQcModal,
            icon: _isSubmitting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Icon(
                    isCompleted ? Icons.send_rounded : Icons.lock_outline_rounded,
                    color: isCompleted ? Colors.white : const Color(0xFF94A3B8),
                    size: 18,
                  ),
            label: Text(
              _isSubmitting
                  ? 'Forwarding to QC...'
                  : isCompleted
                      ? 'Forward Reconciled Lot to QC Floor'
                      : 'Locked: Count Incomplete ($grandCounted/$grandTarget pcs)',
              style: GoogleFonts.publicSans(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: isCompleted ? Colors.white : const Color(0xFF64748B),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Empty State
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0x1A000000)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x08000000),
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: const Icon(Icons.inbox_outlined, size: 44, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 16),
            Text(
              'No Lots Pending in Mending',
              style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
            ),
            const SizedBox(height: 6),
            Text(
              'When the Lineman finishes stitching and taps "Handover to Mending", lots will immediately appear here for worker assignment and counting.',
              textAlign: TextAlign.center,
              style: GoogleFonts.publicSans(fontSize: 12.5, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3A3564),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _fetchMendingLots,
              icon: const Icon(Icons.refresh, size: 16, color: Colors.white),
              label: const Text('Refresh Floor Queue', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
