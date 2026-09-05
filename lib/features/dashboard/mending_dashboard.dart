import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/connectivity_indicator.dart';
import '../auth/providers/auth_provider.dart';
import '../auth/screens/login_screen.dart';
import '../../../main.dart';

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
      // 1. Fetch Allotments (Both handed over to mending and in-progress)
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

      final List<dynamic> allotmentList = res as List<dynamic>;
      final List<String> lotIds = allotmentList.map((a) => a['id'].toString()).toList();

      // 2. Fetch variants for these allotments
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

      // 3. Fetch mending worker assignments
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

        lots.add({
          ...a,
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          // Keep _selectedVariantForAssignment referencing an item from `vars`
          final currentSelected = vars.firstWhere(
            (v) => (v['id'] != null && v['id'] == _selectedVariantForAssignment?['id']) ||
                   (v['color'] == _selectedVariantForAssignment?['color'] && v['size'] == _selectedVariantForAssignment?['size']),
            orElse: () => vars.first,
          );
          _selectedVariantForAssignment = currentSelected;

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
                              'Assign Mending Worker',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.steel,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Allocate piece bundle for thread trimming & counting',
                              style: GoogleFonts.publicSans(fontSize: 12, color: AppTheme.inkSoft),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppTheme.inkFaint),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Worker Name Input
                  Text(
                    'WORKER / COUNTER NAME *',
                    style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.inkSoft),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _workerNameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      hintText: 'Enter worker name (e.g. Ramesh)',
                      filled: true,
                      fillColor: AppTheme.bg,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Select Color & Size Variant
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'SELECT BUNDLE VARIANT *',
                        style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.inkSoft),
                      ),
                      if (_selectedVariantForAssignment != null)
                        Text(
                          '${_getRemainingQtyForVariant(_selectedVariantForAssignment!)} pcs remaining',
                          style: GoogleFonts.publicSans(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _getRemainingQtyForVariant(_selectedVariantForAssignment!) > 0 ? AppTheme.green : AppTheme.red,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.bg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<Map<String, dynamic>>(
                        isExpanded: true,
                        value: _selectedVariantForAssignment,
                        items: vars.map((v) {
                          final color = v['color'] ?? 'Standard';
                          final size = v['size'] ?? 'Free';
                          final target = _parseQty(v['quantity']);
                          final assigned = _getAssignedQtyForVariant(v);
                          final rem = target - assigned;
                          final isDone = rem <= 0;

                          return DropdownMenuItem<Map<String, dynamic>>(
                            value: v,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    isDone
                                        ? '$color • Size: $size (Target: $target pcs)'
                                        : '$color • Size: $size (Target: $target pcs)',
                                    style: GoogleFonts.publicSans(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: isDone ? AppTheme.inkSoft : AppTheme.ink,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isDone ? AppTheme.greenMist : const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: isDone ? AppTheme.green.withValues(alpha: 0.3) : const Color(0xFFFDE68A)),
                                  ),
                                  child: Text(
                                    isDone ? 'Fully Assigned ✓' : '$rem pcs left',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isDone ? AppTheme.green : const Color(0xFFB45309),
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

                  // Live Allocation stats card
                  if (_selectedVariantForAssignment != null) ...[
                    const SizedBox(height: 8),
                    Builder(
                      builder: (_) {
                        final selVar = _selectedVariantForAssignment!;
                        final vTarget = _parseQty(selVar['quantity']);
                        final vAssigned = _getAssignedQtyForVariant(selVar);
                        final vRem = vTarget - vAssigned;

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: vRem > 0 ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: vRem > 0 ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Lot Target', style: TextStyle(fontSize: 10, color: AppTheme.inkSoft, fontWeight: FontWeight.w500)),
                                    const SizedBox(height: 2),
                                    Text('$vTarget pcs', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.ink)),
                                  ],
                                ),
                              ),
                              Container(width: 1, height: 24, color: (vRem > 0 ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA))),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    const Text('Assigned', style: TextStyle(fontSize: 10, color: AppTheme.inkSoft, fontWeight: FontWeight.w500)),
                                    const SizedBox(height: 2),
                                    Text('$vAssigned pcs', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.steel)),
                                  ],
                                ),
                              ),
                              Container(width: 1, height: 24, color: (vRem > 0 ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA))),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text('Remaining', style: TextStyle(fontSize: 10, color: AppTheme.inkSoft, fontWeight: FontWeight.w500)),
                                    const SizedBox(height: 2),
                                    Text(
                                      vRem > 0 ? '$vRem pcs' : 'Done ✓',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: vRem > 0 ? AppTheme.green : AppTheme.red,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Quantity to Assign
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PIECES TO COUNT *',
                              style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.inkSoft),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _qtyController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: 'e.g. 50',
                                filled: true,
                                fillColor: AppTheme.bg,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: AppTheme.border),
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
                              style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.inkSoft),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _notesController,
                              decoration: InputDecoration(
                                hintText: 'Table 2',
                                filled: true,
                                fillColor: AppTheme.bg,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: AppTheme.border),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Submit Assignment
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.steel,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () async {
                        final name = _workerNameController.text.trim();
                        final qty = int.tryParse(_qtyController.text.trim()) ?? 0;
                        if (name.isEmpty || qty <= 0) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Please enter valid worker name and quantity.')),
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
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                title: Row(
                                  children: [
                                    const Icon(Icons.warning_amber_rounded, color: AppTheme.amber, size: 22),
                                    const SizedBox(width: 8),
                                    Text('Exceeds Remaining', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.steel)),
                                  ],
                                ),
                                content: Text(
                                  'Only $rem pcs are remaining for ${_selectedVariantForAssignment!['color']} (Size: ${_selectedVariantForAssignment!['size']}). You entered $qty pcs.\n\nDo you want to allocate $qty pcs anyway?',
                                  style: GoogleFonts.publicSans(fontSize: 13, color: AppTheme.ink),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(dCtx, false),
                                    child: const Text('Cancel / Edit Qty'),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.steel),
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
                      child: Text(
                        'Assign Worker & Start Counting',
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
            backgroundColor: AppTheme.green,
            content: Text('Assigned $qty pcs ($color, Size $size) to $workerName'),
          ),
        );
        _fetchMendingLots();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppTheme.red, content: Text('Assignment error: $e')),
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
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.steel),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Worker: $workerName',
              style: GoogleFonts.publicSans(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.ink),
            ),
            const SizedBox(height: 4),
            Text(
              'Bundle: ${assignment['color']} • Size: ${assignment['size']}',
              style: GoogleFonts.publicSans(fontSize: 13, color: AppTheme.inkSoft),
            ),
            Text(
              'Assigned Pieces: $assignedQty pcs',
              style: GoogleFonts.publicSans(fontSize: 13, color: AppTheme.steel, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Text(
              'PHYSICAL COUNTED PIECES *',
              style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.inkSoft),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: countController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppTheme.bg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.publicSans(color: AppTheme.inkSoft)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.green,
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
                    SnackBar(backgroundColor: AppTheme.red, content: Text('Error updating count: $e')),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Remove Assignment?', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: AppTheme.red)),
        content: Text('Remove mending assignment for $workerName?', style: GoogleFonts.publicSans(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
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
    await _fetchQcSupervisors();
    if (!mounted) return;

    final lot = _selectedLot!;
    final totalCounted = _parseQty(lot['total_counted']);
    final targetQty = _parseQty(lot['target_qty']);
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
                                color: AppTheme.steel,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Reconciled piece bundle & chain-of-custody transfer',
                              style: GoogleFonts.publicSans(fontSize: 12, color: AppTheme.inkSoft),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppTheme.inkFaint),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Lot Summary Info Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.bg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Art: $artNo',
                              style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.steel),
                            ),
                            Text(
                              challanNo,
                              style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.inkSoft),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Physical Counted: $totalCounted pcs',
                              style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.green),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: variance == 0 ? AppTheme.greenMist : (variance < 0 ? AppTheme.amberMist : const Color(0xFFDBEAFE)),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                variance == 0 ? '100% Match' : (variance < 0 ? '$variance pcs Shortage' : '+$variance pcs Excess'),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: variance == 0 ? AppTheme.green : (variance < 0 ? AppTheme.amber : const Color(0xFF1D4ED8)),
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
                    style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.inkSoft),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.bg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        isExpanded: true,
                        value: selectedSupervisorId,
                        hint: Text('General QC Pool (Unassigned)', style: GoogleFonts.publicSans(fontSize: 13, color: AppTheme.steel)),
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Row(
                              children: [
                                const Icon(Icons.group_outlined, size: 16, color: AppTheme.inkSoft),
                                const SizedBox(width: 8),
                                Text(
                                  'General QC Pool (Any available checker)',
                                  style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.inkSoft),
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
                                  const Icon(Icons.person_outline, size: 16, color: AppTheme.green),
                                  const SizedBox(width: 8),
                                  Text(
                                    '$name (QC Supervisor)',
                                    style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.steel),
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
                    style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.inkSoft),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: notesController,
                    decoration: InputDecoration(
                      hintText: 'e.g. Table 2, 500 pcs counted, zero shortage',
                      filled: true,
                      fillColor: AppTheme.bg,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.border),
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
                        backgroundColor: AppTheme.green,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
            backgroundColor: AppTheme.green,
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
          SnackBar(backgroundColor: AppTheme.red, content: Text('QC Handover Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.card,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.calculate_rounded, color: Color(0xFFD97706), size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MENDING & COUNTING',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.steel,
                    ),
                  ),
                  Text(
                    'Floor Inward & Worker Piece Verification',
                    style: GoogleFonts.publicSans(fontSize: 11, color: AppTheme.inkSoft),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.steel),
            onPressed: _fetchMendingLots,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppTheme.red),
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(24),
          child: Padding(
            padding: EdgeInsets.only(left: 16, bottom: 8),
            child: ConnectivityIndicator(),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _lots.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    // Top Filter Bar (My Assigned vs All Floor Lots)
                    _buildFilterBar(),

                    // Top Lot Selector Carousel
                    _buildLotSelector(),

                    // Two Tabs (Worker Assignments vs Natural Matrix)
                    _buildTabBar(),

                    // Tab Body
                    Expanded(
                      child: _selectedLot == null
                          ? const Center(child: Text('Select an allotment above'))
                          : _selectedTabIndex == 0
                              ? _buildWorkerAssignmentsTab()
                              : _buildNaturalMatrixTab(),
                    ),
                  ],
                ),
    );
  }

  // ======= FILTER BAR =======
  Widget _buildFilterBar() {
    final currentUserId = supabase.auth.currentUser?.id;
    final myCount = _lots.where((l) {
      final supId = l['mending_supervisor_id']?.toString();
      return supId == null || supId.isEmpty || supId == currentUserId;
    }).length;
    final allCount = _lots.length;

    return Container(
      color: AppTheme.card,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: _buildFilterChip(
              index: 0,
              label: 'My Assigned Lots ($myCount)',
              icon: Icons.person_pin_rounded,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildFilterChip(
              index: 1,
              label: 'All Floor Lots ($allCount)',
              icon: Icons.factory_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({required int index, required String label, required IconData icon}) {
    final isSelected = _filterMode == index;
    return InkWell(
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
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.steel : AppTheme.bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? AppTheme.steel : AppTheme.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.white : AppTheme.inkSoft),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.publicSans(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? Colors.white : AppTheme.inkSoft,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ======= EMPTY STATE =======
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppTheme.card, shape: BoxShape.circle, border: Border.all(color: AppTheme.border)),
              child: const Icon(Icons.inbox_rounded, size: 48, color: AppTheme.inkFaint),
            ),
            const SizedBox(height: 16),
            Text(
              'No Lots Pending in Mending',
              style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.steel),
            ),
            const SizedBox(height: 6),
            Text(
              'When the Lineman finishes stitching and taps "Handover to Mending", lots will immediately appear here for worker assignment and counting.',
              textAlign: TextAlign.center,
              style: GoogleFonts.publicSans(fontSize: 12.5, color: AppTheme.inkSoft),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.steel,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

  // ======= TOP LOT SELECTOR =======
  Widget _buildLotSelector() {
    final displayLots = _filteredLots;

    if (displayLots.isEmpty) {
      return Container(
        color: AppTheme.card,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Center(
          child: Text(
            'No lots found in this filter.',
            style: GoogleFonts.publicSans(fontSize: 12, color: AppTheme.inkFaint),
          ),
        ),
      );
    }

    return Container(
      color: AppTheme.card,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SizedBox(
        height: 84,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          itemCount: displayLots.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (ctx, idx) {
            final lot = displayLots[idx];
            final isSelected = _selectedLot?['id'] == lot['id'];
            final art = _asMap(lot['article']) ?? _asMap(lot['articles']);
            final artNo = art?['art_no']?.toString() ?? 'N/A';
            final challan = _asMap(lot['challans']) ?? _asMap(lot['challan']);
            final challanNo = challan?['challan_no']?.toString() ?? 'CH-${lot['id'].toString().substring(0, 4)}';
            final target = _parseQty(lot['target_qty']);
            final counted = _parseQty(lot['total_counted']);
            final supName = lot['mending_supervisor_name']?.toString() ?? 'General Pool';

            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedLot = lot;
                });
              },
              child: Container(
                width: 190,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.steel : AppTheme.bg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? AppTheme.steel : AppTheme.border,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Art: $artNo',
                          style: GoogleFonts.publicSans(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : AppTheme.steel,
                          ),
                        ),
                        Text(
                          '$counted/$target pcs',
                          style: GoogleFonts.publicSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? const Color(0xFF6EE7B7) : AppTheme.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      challanNo,
                      style: GoogleFonts.publicSans(
                        fontSize: 10.5,
                        color: isSelected ? Colors.white70 : AppTheme.inkSoft,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline_rounded,
                          size: 11,
                          color: isSelected ? const Color(0xFFFDE68A) : AppTheme.steel,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            supName,
                            style: GoogleFonts.publicSans(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? const Color(0xFFFDE68A) : AppTheme.steel,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ======= TAB BAR =======
  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.card,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _selectedTabIndex = 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: _selectedTabIndex == 0 ? AppTheme.steel : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
                child: Center(
                  child: Text(
                    'Worker Assignments',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: _selectedTabIndex == 0 ? FontWeight.bold : FontWeight.w500,
                      color: _selectedTabIndex == 0 ? AppTheme.steel : AppTheme.inkSoft,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _selectedTabIndex = 1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: _selectedTabIndex == 1 ? AppTheme.steel : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
                child: Center(
                  child: Text(
                    'Challan Matrix & QC',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: _selectedTabIndex == 1 ? FontWeight.bold : FontWeight.w500,
                      color: _selectedTabIndex == 1 ? AppTheme.steel : AppTheme.inkSoft,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ======= TAB 1: WORKER ASSIGNMENTS =======
  Widget _buildWorkerAssignmentsTab() {
    final lot = _selectedLot;
    if (lot == null) {
      return Center(
        child: Text(
          'Select an allotment above',
          style: GoogleFonts.publicSans(fontSize: 13, color: AppTheme.inkSoft),
        ),
      );
    }

    final assigns = (lot['assignments'] as List<dynamic>?) ?? [];
    final target = _parseQty(lot['target_qty']);
    final assigned = _parseQty(lot['total_assigned']);
    final counted = _parseQty(lot['total_counted']);

    final handedBy = lot['handed_to_mending_by']?.toString();
    final linemanName = (handedBy != null && handedBy.isNotEmpty)
        ? handedBy
        : (_asMap(lot['lineman'])?['username']?.toString() ?? 'Lineman');
    final supName = lot['mending_supervisor_name']?.toString() ?? 'General Pool';
    final notes = lot['mending_handover_notes']?.toString();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Custody & Handover Details Header Card
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.handshake_rounded, size: 16, color: Color(0xFFB45309)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'From Lineman: $linemanName',
                      style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF92400E)),
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
                      style: GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFFB45309)),
                    ),
                  ),
                ],
              ),
              if (notes != null && notes.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Note: $notes',
                  style: GoogleFonts.publicSans(fontSize: 11.5, fontStyle: FontStyle.italic, color: const Color(0xFF78350F)),
                ),
              ],
            ],
          ),
        ),

        // Summary & Action Bar
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'COUNTING PROGRESS',
                          style: GoogleFonts.publicSans(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.inkFaint),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$counted of $target Pieces Verified',
                          style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.steel),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.steel,
                      minimumSize: const Size(0, 36),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    onPressed: _openAssignWorkerModal,
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 16, color: Colors.white),
                    label: const Text(
                      'Assign Worker',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: target > 0 ? (counted / target).clamp(0.0, 1.0) : 0.0,
                  minHeight: 7,
                  backgroundColor: AppTheme.bg,
                  valueColor: AlwaysStoppedAnimation<Color>(counted >= target ? AppTheme.green : AppTheme.steel),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Target: $target pcs', style: const TextStyle(fontSize: 11, color: AppTheme.inkSoft)),
                  Text('Assigned: $assigned pcs', style: const TextStyle(fontSize: 11, color: AppTheme.steel, fontWeight: FontWeight.bold)),
                  Text('Counted: $counted pcs', style: const TextStyle(fontSize: 11, color: AppTheme.green, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        Text(
          'ASSIGNED MENDING & COUNTING STAFF (${assigns.length})',
          style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: AppTheme.inkSoft),
        ),
        const SizedBox(height: 8),

        if (assigns.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.border)),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.group_off_rounded, size: 36, color: AppTheme.inkFaint),
                  const SizedBox(height: 8),
                  Text('No Workers Assigned Yet', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.steel)),
                  const SizedBox(height: 4),
                  Text('Tap "+ Assign Worker" to distribute bundle counting to your staff.', style: GoogleFonts.publicSans(fontSize: 11.5, color: AppTheme.inkSoft)),
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
    final isDone = ass['status']?.toString() == 'DONE';
    final notes = ass['notes']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDone ? AppTheme.green.withValues(alpha: 0.4) : AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDone ? AppTheme.greenMist : AppTheme.bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isDone ? Icons.check_circle_rounded : Icons.person_rounded,
              color: isDone ? AppTheme.green : AppTheme.steel,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      workerName,
                      style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.ink),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDone ? AppTheme.greenMist : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isDone ? 'COUNTED' : 'PENDING',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: isDone ? AppTheme.green : const Color(0xFFD97706),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '$color  •  Size: $size  ${notes != null && notes.isNotEmpty ? '• $notes' : ''}',
                  style: GoogleFonts.publicSans(fontSize: 11.5, color: AppTheme.inkSoft),
                ),
                const SizedBox(height: 4),
                Text(
                  'Assigned: $assignedQty pcs  |  Physical Count: $completedQty pcs',
                  style: GoogleFonts.publicSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isDone ? AppTheme.green : AppTheme.steel,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              IconButton(
                icon: const Icon(Icons.edit_note_rounded, color: AppTheme.steel, size: 22),
                tooltip: 'Enter Physical Count',
                onPressed: () => _openRecordCountDialog(Map<String, dynamic>.from(ass)),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.red, size: 18),
                tooltip: 'Remove',
                onPressed: () => _deleteAssignment(ass['id'].toString(), workerName),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ======= TAB 2: NATURAL MATRIX & QC HANDOVER =======
  Widget _buildNaturalMatrixTab() {
    final lot = _selectedLot;
    if (lot == null) {
      return Center(
        child: Text(
          'Select an allotment above',
          style: GoogleFonts.publicSans(fontSize: 13, color: AppTheme.inkSoft),
        ),
      );
    }
    final vars = (lot['variants'] as List<dynamic>?) ?? [];
    final assigns = (lot['assignments'] as List<dynamic>?) ?? [];
    final art = _asMap(lot['article']) ?? _asMap(lot['articles']);
    final artNo = art?['art_no']?.toString() ?? 'N/A';
    final desc = art?['description']?.toString() ?? '';

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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Article Header
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ARTICLE: $artNo',
                    style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.steel),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.greenMist,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'NATURAL SIZE MATRIX',
                      style: GoogleFonts.publicSans(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.green),
                    ),
                  ),
                ],
              ),
              if (desc.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(desc, style: GoogleFonts.publicSans(fontSize: 12, color: AppTheme.inkSoft)),
              ],
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Natural Size Grid Table
        Container(
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(
                  color: AppTheme.bg,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
                ),
                child: Row(
                  children: [
                    Expanded(flex: 3, child: Text('COLOR / SIZE', style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.inkSoft))),
                    Expanded(flex: 2, child: Text('TARGET', textAlign: TextAlign.center, style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.inkSoft))),
                    Expanded(flex: 2, child: Text('COUNTED', textAlign: TextAlign.center, style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.inkSoft))),
                    Expanded(flex: 2, child: Text('VARIANCE', textAlign: TextAlign.right, style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.inkSoft))),
                  ],
                ),
              ),

              if (vars.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'No variant details recorded for this article.',
                      style: GoogleFonts.publicSans(fontSize: 12, color: AppTheme.inkSoft),
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
                      border: Border(top: BorderSide(color: AppTheme.border)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(color, style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.ink)),
                              Text('Size: $size • Assigned: $assigned/$target pcs', style: GoogleFonts.publicSans(fontSize: 10.5, color: AppTheme.inkSoft)),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            '$target pcs',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.ink),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            '$counted pcs',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.steel),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            diff == 0
                                ? 'MATCH'
                                : diff < 0
                                    ? '$diff pcs'
                                    : '+$diff pcs',
                            textAlign: TextAlign.right,
                            style: GoogleFonts.publicSans(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: diff == 0
                                  ? AppTheme.green
                                  : diff < 0
                                      ? AppTheme.amber
                                      : const Color(0xFF2563EB),
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
                  color: AppTheme.bg,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(11)),
                  border: Border(top: BorderSide(color: AppTheme.border, width: 1.5)),
                ),
                child: Row(
                  children: [
                    Expanded(flex: 3, child: Text('TOTAL PIECES', style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.steel))),
                    Expanded(flex: 2, child: Text('$grandTarget', textAlign: TextAlign.center, style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.steel))),
                    Expanded(flex: 2, child: Text('$grandCounted', textAlign: TextAlign.center, style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.green))),
                    Expanded(
                      flex: 2,
                      child: Text(
                        grandCounted == grandTarget
                            ? 'MATCH'
                            : '${grandCounted - grandTarget} pcs',
                        textAlign: TextAlign.right,
                        style: GoogleFonts.publicSans(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: grandCounted == grandTarget ? AppTheme.green : AppTheme.amber,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Handover to QC Floor Button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _isSubmitting ? null : _openHandoverToQcModal,
            icon: _isSubmitting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
            label: Text(
              _isSubmitting ? 'Forwarding to QC...' : 'Forward Reconciled Lot to QC Floor',
              style: GoogleFonts.publicSans(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
