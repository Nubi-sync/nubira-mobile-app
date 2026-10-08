import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/providers/auth_provider.dart';
import '../auth/screens/login_screen.dart';
import '../admin/widgets/admin_drawer.dart';
import '../../core/services/tenant_resolver_service.dart';
import 'widgets/delivery_challan_modal.dart';
import '../../../main.dart';

class QcDashboard extends ConsumerStatefulWidget {
  const QcDashboard({super.key});

  @override
  ConsumerState<QcDashboard> createState() => _QcDashboardState();
}

class _QcDashboardState extends ConsumerState<QcDashboard> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isLoading = true;
  bool _isSubmitting = false;
  int _selectedTabIndex = 0; // 0: Incoming Lots, 1: QC Checking, 2: Alterations, 3: Ready for Challan
  int _incomingFilterMode = 0; // 0: My Assigned Lots, 1: All Floor Lots
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Set<String> _expandedArticleGroups = {};

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

  // Recent QC workers
  List<String> _recentWorkerNames = [];

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

  // Safe helper to extract integers from dynamic types (Strings, num, ints)
  static int _parseQty(dynamic val, [int fallback = 0]) {
    if (val == null) return fallback;
    if (val is int) return val;
    if (val is num) return val.toInt();
    final str = val.toString().trim();
    if (str.isEmpty) return fallback;
    final direct = int.tryParse(str);
    if (direct != null) return direct;
    final match = RegExp(r'[-+]?\d+').firstMatch(str);
    if (match != null) {
      return int.tryParse(match.group(0) ?? '') ?? fallback;
    }
    return fallback;
  }

  // Safe helper to extract Map from dynamic types
  static Map<String, dynamic>? _asMap(dynamic val) {
    if (val == null) return null;
    if (val is Map<String, dynamic>) return val;
    if (val is Map) return Map<String, dynamic>.from(val);
    if (val is List && val.isNotEmpty && val.first is Map) {
      return Map<String, dynamic>.from(val.first as Map);
    }
    return null;
  }

  // Helper to calculate total pieces assigned to QC checkers for a specific variant
  int _getAssignedQtyForVariant(Map<String, dynamic> lot, Map<String, dynamic>? v) {
    if (v == null) return 0;
    final lotId = lot['id']?.toString();
    final articleId = lot['article_id']?.toString();
    final vSize = (v['size'] ?? '').toString().trim().toUpperCase();
    final vColor = (v['color'] ?? '').toString().trim().toUpperCase();

    int total = 0;
    for (var assign in _activeAssignments) {
      final aLotId = assign['allotment_id']?.toString();
      final aArtId = assign['article_id']?.toString();
      final bool matchesLot = (lotId != null && aLotId == lotId) ||
          (lotId == null && articleId != null && aArtId == articleId) ||
          (aLotId == null && articleId != null && aArtId == articleId);

      if (matchesLot) {
        final aSize = (assign['size'] ?? '').toString().trim().toUpperCase();
        final aColor = (assign['color'] ?? '').toString().trim().toUpperCase();

        final bool sizeMatch = aSize == vSize ||
            aSize.replaceAll(RegExp(r'[^A-Z0-9]'), '') == vSize.replaceAll(RegExp(r'[^A-Z0-9]'), '');

        final bool colorMatch = (vColor.isEmpty || vColor == '-' || vColor == 'DEFAULT') ||
            (aColor.isEmpty || aColor == '-' || aColor == 'DEFAULT') ||
            (aColor == vColor) ||
            (aColor.replaceAll(RegExp(r'[^A-Z0-9]'), '') == vColor.replaceAll(RegExp(r'[^A-Z0-9]'), ''));

        if (sizeMatch && colorMatch) {
          total += _parseQty(assign['assigned_qty']);
        }
      }
    }
    return total;
  }

  // Helper to calculate remaining unassigned pieces for a specific variant in QC
  int _getRemainingQtyForVariant(Map<String, dynamic> lot, Map<String, dynamic>? v) {
    if (v == null) return 0;
    final target = _parseQty(v['allotted_qty']) > 0
        ? _parseQty(v['allotted_qty'])
        : (_parseQty(v['quantity']) > 0
            ? _parseQty(v['quantity'])
            : _parseQty(v['mending_qty']));
    final assigned = _getAssignedQtyForVariant(lot, v);
    final rem = target - assigned;
    return rem > 0 ? rem : 0;
  }

  @override
  void initState() {
    super.initState();
    _loadRecentWorkers();
    _fetchQcData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
      final currentUser = supabase.auth.currentUser;
      if (currentUser != null) {
        try {
          final prof = await supabase
              .from('profiles')
              .select('id')
              .eq('id', currentUser.id)
              .maybeSingle();
          if (prof == null) {
            await ref.read(authProvider.notifier).logout();
            if (mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            }
            return;
          }
        } catch (_) {}
      }

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
              priority,
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
              challans ( id, challan_no, brand, fabric_type, vendor_id, vendor_name )
            ''')
            .or('mending_status.in.(QC_PENDING,COUNTING_VERIFIED),qc_status.in.(QC_PENDING,INCOMING_HANDOVER,INCOMING_FROM_MENDING,QC_IN_PROGRESS,COMPLETED)')
            .order('created_at', ascending: false)
            .limit(200)
            .timeout(const Duration(seconds: 4), onTimeout: () => []);
        allotmentList = allotmentsRes as List<dynamic>;
      } catch (e) {
        debugPrint('QC_DASHBOARD: Allotments join with vendor error: $e, trying standard join');
        try {
          final fallbackRes = await supabase
              .from('allotments')
              .select('''
                id,
                lot_no,
                challan_id,
                status,
                quantity,
                total_pcs,
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
              .or('mending_status.in.(QC_PENDING,COUNTING_VERIFIED),qc_status.in.(QC_PENDING,INCOMING_HANDOVER,INCOMING_FROM_MENDING,QC_IN_PROGRESS,COMPLETED)')
              .order('created_at', ascending: false)
              .limit(200)
              .timeout(const Duration(seconds: 4), onTimeout: () => []);
          allotmentList = fallbackRes as List<dynamic>;
        } catch (_) {
          try {
            final simpleRes = await supabase
                .from('allotments')
                .select('*')
                .or('mending_status.in.(QC_PENDING,COUNTING_VERIFIED),qc_status.in.(QC_PENDING,INCOMING_HANDOVER,INCOMING_FROM_MENDING,QC_IN_PROGRESS,COMPLETED)')
                .order('created_at', ascending: false)
                .limit(200)
                .timeout(const Duration(seconds: 3), onTimeout: () => []);
            allotmentList = simpleRes as List<dynamic>;
          } catch (_) {}
        }
      }

      // Tenant isolation filter
      ResolvedTenantProfile? tenant;
      if (currentUser != null) {
        try {
          tenant = await TenantResolverService.resolveUserTenant(currentUser);
        } catch (_) {}
      }
      final isPlatformSuper = tenant?.isPlatformAdmin == true || tenant?.role == 'PLATFORM_SUPERADMIN';
      final targetComp = (!isPlatformSuper && tenant != null && tenant.companyName.trim().isNotEmpty)
          ? tenant.companyName.trim().toLowerCase()
          : null;

      if (targetComp != null && targetComp.isNotEmpty) {
        allotmentList = allotmentList.where((al) {
          final ch = al['challans'] as Map?;
          final brand = (ch?['brand']?.toString() ?? '').toLowerCase();
          final comp = (al['company_name']?.toString() ?? '').toLowerCase();
          final art = al['article'] as Map?;
          final rates = art?['size_rates'];
          String rateComp = '';
          if (rates is Map) {
            rateComp = (rates['company_name']?.toString() ?? rates['_meta']?['company_name']?.toString() ?? '').toLowerCase();
          }
          return brand == targetComp || brand.contains(targetComp) || comp == targetComp || comp.contains(targetComp) || rateComp == targetComp || rateComp.contains(targetComp) || targetComp.contains('nubira');
        }).toList();
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

      // 3b. Fetch material notes to extract priority fallback if needed
      final Map<String, String> priorityMap = {};
      if (lotIds.isNotEmpty) {
        try {
          final matsRes = await supabase
              .from('allotment_materials')
              .select('allotment_id, notes')
              .inFilter('allotment_id', lotIds)
              .timeout(const Duration(seconds: 3), onTimeout: () => []);
          for (var m in matsRes) {
            final aId = m['allotment_id']?.toString() ?? '';
            if (m['notes'] != null && !priorityMap.containsKey(aId)) {
              try {
                final parsed = jsonDecode(m['notes'].toString());
                if (parsed['priority'] != null && parsed['priority'].toString().isNotEmpty) {
                  priorityMap[aId] = parsed['priority'].toString().toUpperCase();
                }
              } catch (_) {}
            }
          }
        } catch (_) {}
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
      final Map<String, Map<String, dynamic>> consolidatedIncoming = {};
      final Map<String, Map<String, dynamic>> consolidatedReady = {};

      for (var a in allotmentList) {
        final aId = a['id'].toString();
        final vars = variantsRes.where((v) => v['allotment_id'].toString() == aId).toList();
        final mendAssigns = mendingAssignmentsRes.where((m) => m['allotment_id'].toString() == aId).toList();

        vars.sort((x, y) => _naturalSizeCompare((x['size'] ?? '').toString(), (y['size'] ?? '').toString()));

        int adminTotal = _parseQty(a['target_qty']);
        if (adminTotal == 0) {
          for (var v in vars) {
            adminTotal += _parseQty(v['quantity']);
          }
        }

        int mendingTotal = _parseQty(a['mending_total_counted']);
        if (mendingTotal == 0 && mendAssigns.isNotEmpty) {
          for (var m in mendAssigns) {
            mendingTotal += _parseQty(m['completed_qty']);
          }
        }

        final int passedQty = _parseQty(a['qc_total_passed']);
        final int alterQty = _parseQty(a['qc_total_alter']);
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
        final List<Map<String, dynamic>> enrichedVars = [];

        for (var v in vars) {
          final sz = (v['size'] ?? '-').toString().trim();
          final clr = (v['color'] ?? '-').toString().trim();
          final allotQty = _parseQty(v['quantity']);

          final vSizeUpper = sz.toUpperCase();
          final vColorUpper = clr.toUpperCase();

          int mCount = 0;
          for (var m in mendAssigns) {
            final mSize = (m['size'] ?? '').toString().trim().toUpperCase();
            final mColor = (m['color'] ?? '').toString().trim().toUpperCase();

            final bool sizeMatch = mSize == vSizeUpper ||
                mSize.replaceAll(RegExp(r'[^A-Z0-9]'), '') == vSizeUpper.replaceAll(RegExp(r'[^A-Z0-9]'), '');

            final bool colorMatch = (vColorUpper.isEmpty || vColorUpper == '-' || vColorUpper == 'DEFAULT') ||
                (mColor.isEmpty || mColor == '-' || mColor == 'DEFAULT') ||
                (mColor == vColorUpper) ||
                (mColor.replaceAll(RegExp(r'[^A-Z0-9]'), '') == vColorUpper.replaceAll(RegExp(r'[^A-Z0-9]'), ''));

            if (sizeMatch && colorMatch) {
              mCount += _parseQty(m['completed_qty']);
            }
          }
          if (mCount == 0 && isHandedOverFromMending) {
            mCount = allotQty;
          }

          int qcPassCount = 0;
          for (var qc in activeAssignments) {
            if (qc['allotment_id']?.toString() == aId) {
              final qSize = (qc['size'] ?? '').toString().trim().toUpperCase();
              final qColor = (qc['color'] ?? '').toString().trim().toUpperCase();

              final bool sizeMatch = qSize == vSizeUpper ||
                  qSize.replaceAll(RegExp(r'[^A-Z0-9]'), '') == vSizeUpper.replaceAll(RegExp(r'[^A-Z0-9]'), '');

              final bool colorMatch = (vColorUpper.isEmpty || vColorUpper == '-' || vColorUpper == 'DEFAULT') ||
                  (qColor.isEmpty || qColor == '-' || qColor == 'DEFAULT') ||
                  (qColor == vColorUpper) ||
                  (qColor.replaceAll(RegExp(r'[^A-Z0-9]'), '') == vColorUpper.replaceAll(RegExp(r'[^A-Z0-9]'), ''));

              if (sizeMatch && colorMatch) {
                qcPassCount += _parseQty(qc['passed_qty']);
              }
            }
          }
          if (qcPassCount == 0 && vars.length == 1 && passedQty > 0) {
            qcPassCount = passedQty;
          }

          enrichedVars.add({
            ...Map<String, dynamic>.from(v),
            'size': sz,
            'color': clr,
            'order_qty': allotQty,
            'allotted_qty': allotQty,
            'mending_qty': mCount,
            'qc_passed_qty': qcPassCount,
          });
        }

        String lotPriority = (a['priority'] ?? '').toString().toUpperCase();
        if (lotPriority.isEmpty || lotPriority == 'NORMAL') {
          if (priorityMap.containsKey(aId)) {
            lotPriority = priorityMap[aId]!;
          }
        }
        if (lotPriority.isEmpty) lotPriority = 'NORMAL';

        final artMap = _asMap(a['article']) ?? _asMap(a['articles']);
        final chalMap = _asMap(a['challans']) ?? _asMap(a['challan']);
        final lineMap = _asMap(a['lineman']) ?? _asMap(a['profiles']);

        final artIdStr = a['article_id']?.toString() ?? artMap?['id']?.toString() ?? '';
        final artNoStr = artMap?['art_no']?.toString() ?? '';
        final groupKey = artIdStr.isNotEmpty ? artIdStr : (artNoStr.isNotEmpty ? artNoStr : aId);

        // Determine Stage
        final bool isReady = qStatus == 'QC_COMPLETED' || qStatus == 'READY_FOR_CHALLAN' || qStatus == 'PENDING_ADMIN_APPROVAL' || qStatus == 'APPROVED_FOR_STORE' || qStatus == 'READY_FOR_STORE' || (passedQty > 0 && passedQty >= (mendingTotal > 0 ? mendingTotal : adminTotal));

        if (!isReady && !isHandedOverFromMending) {
          continue;
        }

        final targetMap = isReady ? consolidatedReady : consolidatedIncoming;

        if (targetMap.containsKey(groupKey)) {
          final existing = targetMap[groupKey]!;
          final List<String> secIds = List<String>.from(existing['secondary_ids'] ?? []);
          if (!secIds.contains(aId)) secIds.add(aId);
          existing['secondary_ids'] = secIds;

          if (existing['challans'] == null && chalMap != null) existing['challans'] = chalMap;
          if (existing['lineman'] == null && lineMap != null) existing['lineman'] = lineMap;
          if (existing['handed_to_qc_by'] == null && a['handed_to_qc_by'] != null) existing['handed_to_qc_by'] = a['handed_to_qc_by'];
          if (existing['qc_handover_notes'] == null && a['qc_handover_notes'] != null) existing['qc_handover_notes'] = a['qc_handover_notes'];

          // Merge enriched variants
          final existingVars = List<Map<String, dynamic>>.from(existing['variants'] as List);
          for (var ev in enrichedVars) {
            final eColor = (ev['color'] ?? 'Default').toString().trim().toUpperCase();
            final eSize = (ev['size'] ?? 'Free').toString().trim().toUpperCase();
            final matchIdx = existingVars.indexWhere((x) {
              final xColor = (x['color'] ?? 'Default').toString().trim().toUpperCase();
              final xSize = (x['size'] ?? 'Free').toString().trim().toUpperCase();
              return xColor == eColor && xSize == eSize;
            });

            if (matchIdx != -1) {
              existingVars[matchIdx]['order_qty'] = _parseQty(existingVars[matchIdx]['order_qty']) + _parseQty(ev['order_qty']);
              existingVars[matchIdx]['allotted_qty'] = _parseQty(existingVars[matchIdx]['allotted_qty']) + _parseQty(ev['allotted_qty']);
              existingVars[matchIdx]['mending_qty'] = _parseQty(existingVars[matchIdx]['mending_qty']) + _parseQty(ev['mending_qty']);
              existingVars[matchIdx]['qc_passed_qty'] = _parseQty(existingVars[matchIdx]['qc_passed_qty']) + _parseQty(ev['qc_passed_qty']);
            } else {
              existingVars.add(Map<String, dynamic>.from(ev));
            }
          }
          existingVars.sort((x, y) => _naturalSizeCompare((x['size'] ?? '').toString(), (y['size'] ?? '').toString()));
          existing['variants'] = existingVars;

          int aggAdminTotal = 0;
          int aggMendingTotal = 0;
          int aggQcPass = 0;
          for (var ev in existingVars) {
            aggAdminTotal += _parseQty(ev['allotted_qty']);
            aggMendingTotal += _parseQty(ev['mending_qty']);
            aggQcPass += _parseQty(ev['qc_passed_qty']);
          }

          existing['size_matrix'] = existingVars.map((v) => {
            'size': v['size'],
            'color': v['color'],
            'allotted_qty': _parseQty(v['allotted_qty']),
            'mending_qty': _parseQty(v['mending_qty']),
            'qc_passed_qty': _parseQty(v['qc_passed_qty']),
            'diff': _parseQty(v['mending_qty']) - _parseQty(v['allotted_qty']),
          }).toList();

          existing['admin_total_qty'] = aggAdminTotal > 0 ? aggAdminTotal : (_parseQty(existing['admin_total_qty']) + adminTotal);
          existing['mending_received_qty'] = aggMendingTotal > 0 ? aggMendingTotal : (_parseQty(existing['mending_received_qty']) + mendingTotal);
          existing['qc_total_passed'] = aggQcPass > 0 ? aggQcPass : (_parseQty(existing['qc_total_passed']) + passedQty);
          existing['qc_total_alter'] = _parseQty(existing['qc_total_alter']) + alterQty;
          existing['variance'] = _parseQty(existing['mending_received_qty']) - _parseQty(existing['admin_total_qty']);

          if (lotPriority == 'CRITICAL' || (lotPriority == 'RUSH' && existing['priority'] != 'CRITICAL')) {
            existing['priority'] = lotPriority;
          }
        } else {
          final List<Map<String, dynamic>> sizeMatrix = enrichedVars.map((v) => {
            'size': v['size'],
            'color': v['color'],
            'allotted_qty': _parseQty(v['allotted_qty']),
            'mending_qty': _parseQty(v['mending_qty']),
            'qc_passed_qty': _parseQty(v['qc_passed_qty']),
            'diff': _parseQty(v['mending_qty']) - _parseQty(v['allotted_qty']),
          }).toList();

          int aggAdmin = 0;
          int aggMend = 0;
          for (var v in enrichedVars) {
            aggAdmin += _parseQty(v['allotted_qty']);
            aggMend += _parseQty(v['mending_qty']);
          }

          targetMap[groupKey] = {
            ...Map<String, dynamic>.from(a),
            'secondary_ids': <String>[],
            'priority': lotPriority,
            'article': artMap,
            'challans': chalMap,
            'lineman': lineMap,
            'variants': enrichedVars,
            'size_matrix': sizeMatrix,
            'admin_total_qty': aggAdmin > 0 ? aggAdmin : adminTotal,
            'mending_received_qty': aggMend > 0 ? aggMend : mendingTotal,
            'qc_total_passed': passedQty,
            'qc_total_alter': alterQty,
            'variance': (aggMend > 0 ? aggMend : mendingTotal) - (aggAdmin > 0 ? aggAdmin : adminTotal),
          };
        }
      }

      final List<Map<String, dynamic>> incoming = consolidatedIncoming.values.toList();
      final List<Map<String, dynamic>> readyForChallan = consolidatedReady.values.toList();
      int totalMendingReceived = incoming.fold(0, (sum, item) => sum + _parseQty(item['mending_received_qty']));

      // Universal Priority Queue Sorting: CRITICAL (Rank 0) -> RUSH (Rank 1) -> NORMAL (Rank 2)
      incoming.sort((a, b) {
        final pA = (a['priority'] ?? 'NORMAL').toString().toUpperCase();
        final pB = (b['priority'] ?? 'NORMAL').toString().toUpperCase();
        int rank(String p) => p == 'CRITICAL' ? 0 : (p == 'RUSH' ? 1 : 2);
        final comp = rank(pA).compareTo(rank(pB));
        if (comp != 0) return comp;
        return (b['created_at'] ?? '').toString().compareTo((a['created_at'] ?? '').toString());
      });

      // If ready for challan is empty but some allotments have passed counts, populate
      if (readyForChallan.isEmpty) {
        for (var a in allotmentList) {
          final passed = _parseQty(a['qc_total_passed']);
          if (passed > 0) {
            final aId = a['id'].toString();
            final vars = variantsRes.where((v) => v['allotment_id'].toString() == aId).toList();
            readyForChallan.add({
              ...Map<String, dynamic>.from(a),
              'variants': vars,
              'admin_total_qty': _parseQty(a['target_qty'], passed),
              'mending_received_qty': _parseQty(a['mending_total_counted'], passed),
              'qc_total_passed': passed,
              'qc_total_alter': _parseQty(a['qc_total_alter']),
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
        final qRej = _parseQty(log['qty_rejected']);
        final qPass = _parseQty(log['qty_passed']);
        final qRec = _parseQty(log['qty_received']);
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
          final assigned = _parseQty(assign['assigned_qty']);
          final checked = _parseQty(assign['checked_qty']);
          inCheckingPieces += (assigned - checked).clamp(0, assigned);
        }
      }

      int readyPieces = 0;
      for (var r in readyForChallan) {
        readyPieces += _parseQty(r['qc_total_passed'], _parseQty(r['mending_received_qty']));
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
  // MODAL: ASSIGN QC CHECKER / WORKER (INDUSTRIAL LUXURY)
  // ====================================================
  void _openAssignWorkerModal(Map<String, dynamic> lot) {
    final workerController = TextEditingController();
    final qtyController = TextEditingController();
    final notesController = TextEditingController();

    final rawSizeMatrix = lot['size_matrix'] as List<dynamic>? ?? [];
    final sizeMatrix = rawSizeMatrix.map((v) => Map<String, dynamic>.from(v as Map)).toList();

    // Auto-select the first variant that still has remaining unassigned pieces
    Map<String, dynamic>? selectedVariant;
    for (var v in sizeMatrix) {
      if (_getRemainingQtyForVariant(lot, v) > 0) {
        selectedVariant = v;
        break;
      }
    }
    selectedVariant ??= sizeMatrix.isNotEmpty ? sizeMatrix.first : null;

    final initialRem = selectedVariant != null
        ? _getRemainingQtyForVariant(lot, selectedVariant)
        : _parseQty(lot['mending_received_qty']);

    qtyController.text = initialRem > 0 ? initialRem.toString() : '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final art = _asMap(lot['article']) ?? _asMap(lot['articles']);
          final artNo = art?['art_no']?.toString() ?? lot['art_no']?.toString() ?? 'Article';
          final desc = art?['description']?.toString() ?? lot['description']?.toString() ?? '';

          final vRem = selectedVariant != null
              ? _getRemainingQtyForVariant(lot, selectedVariant)
              : _parseQty(lot['mending_received_qty']);
          final vTarget = selectedVariant != null
              ? (_parseQty(selectedVariant!['allotted_qty']) > 0
                  ? _parseQty(selectedVariant!['allotted_qty'])
                  : _parseQty(selectedVariant!['quantity']))
              : _parseQty(lot['admin_total_qty']);
          final vAssigned = selectedVariant != null
              ? _getAssignedQtyForVariant(lot, selectedVariant)
              : 0;

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. TOP HEADER (Warm Cream)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFAF7F0),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    border: Border(bottom: BorderSide(color: Color(0x14000000), width: 1)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0x26000000), width: 1),
                              ),
                              child: Text(
                                'QC WORKER ALLOCATION',
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
                              'Assign QC checker / worker',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Art #$artNo ${desc.isNotEmpty ? "· $desc" : ""}',
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

                // 2. FORM BODY
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Field 1: Checker Name *
                        Text(
                          'CHECKER NAME / WORKER *',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF334155),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: workerController,
                          textCapitalization: TextCapitalization.words,
                          onChanged: (_) => setModalState(() {}),
                          style: GoogleFonts.publicSans(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF0F172A),
                          ),
                          decoration: InputDecoration(
                            hintText: 'Enter checker name (e.g. Ramesh, Sunil)',
                            hintStyle: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF94A3B8)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF3A3564), width: 1.5)),
                          ),
                        ),

                        // Quick worker chips
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
                                        workerController.text = name;
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
                                        style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF3A3564)),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],

                        const SizedBox(height: 16),

                        // Field 2: Select Size / Color Variant
                        if (sizeMatrix.isNotEmpty) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'SELECT SIZE / COLOR VARIANT *',
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
                                value: selectedVariant,
                                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B), size: 20),
                                items: sizeMatrix.map((v) {
                                  final clr = (v['color'] ?? 'Standard').toString();
                                  final sz = (v['size'] ?? 'Free').toString();
                                  final target = _parseQty(v['allotted_qty']) > 0
                                      ? _parseQty(v['allotted_qty'])
                                      : (_parseQty(v['quantity']) > 0
                                          ? _parseQty(v['quantity'])
                                          : _parseQty(v['mending_qty']));
                                  final assigned = _getAssignedQtyForVariant(lot, v);
                                  final rem = target - assigned;
                                  final done = rem <= 0;

                                  return DropdownMenuItem<Map<String, dynamic>>(
                                    value: v,
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '$clr - Size: $sz (Target: $target pcs)',
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
                                      selectedVariant = newVal;
                                      final rem = _getRemainingQtyForVariant(lot, newVal);
                                      qtyController.text = rem > 0 ? rem.toString() : '';
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

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
                              // Target
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'LOT TARGET',
                                      style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.w700, color: const Color(0xFF64748B), letterSpacing: 0.5),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$vTarget pcs',
                                      style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
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
                                      'QC ASSIGNED',
                                      style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.w700, color: const Color(0xFF64748B), letterSpacing: 0.5),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$vAssigned pcs',
                                      style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
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
                                      style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.w700, color: const Color(0xFF64748B), letterSpacing: 0.5),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      vRem > 0 ? '$vRem pcs' : '0 pcs',
                                      style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w800, color: vRem > 0 ? const Color(0xFF047857) : const Color(0xFF0F172A)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Field 4: Assigned Qty to Check
                        Text(
                          'ASSIGNED PIECES TO CHECK *',
                          style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF334155), letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: qtyController,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setModalState(() {}),
                          style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w800, fontSize: 14, color: const Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            hintText: 'e.g. 50',
                            suffixText: 'pcs',
                            suffixStyle: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF3A3564), width: 1.5)),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Field 5: Notes / Instructions (Optional)
                        Text(
                          'INSPECTION NOTES / INSTRUCTIONS (OPTIONAL)',
                          style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF334155), letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: notesController,
                          style: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            hintText: 'e.g. Check stitching on collar, buttons, and hemline',
                            hintStyle: GoogleFonts.publicSans(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF3A3564), width: 1.5)),
                          ),
                        ),

                        const SizedBox(height: 22),

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3A3564),
                              foregroundColor: Colors.white,
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

                                    if (selectedVariant != null) {
                                      final rem = _getRemainingQtyForVariant(lot, selectedVariant);
                                      if (rem > 0 && qty > rem) {
                                        final proceed = await showDialog<bool>(
                                          context: ctx,
                                          builder: (dCtx) => AlertDialog(
                                            backgroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                            title: Text(
                                              'Exceeds Remaining Pieces',
                                              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16, color: const Color(0xFF0F172A)),
                                            ),
                                            content: Text(
                                              'Only $rem pcs remaining for ${selectedVariant?['size']} ${selectedVariant?['color'] != null && selectedVariant?['color'] != "-" ? "(${selectedVariant!['color']})" : ""}. You entered $qty pcs.\n\nDo you want to allocate $qty pcs anyway?',
                                              style: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF475569)),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(dCtx, false),
                                                child: Text('Cancel', style: GoogleFonts.publicSans(fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
                                              ),
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3A3564), elevation: 0),
                                                onPressed: () => Navigator.pop(dCtx, true),
                                                child: const Text('Proceed', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (proceed != true) return;
                                      }
                                    }

                                    if (!ctx.mounted) return;
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
                                    style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.w800, color: Colors.white),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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
      final secIds = (lot['secondary_ids'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
      final allTargetIds = [lot['id'].toString(), ...secIds];
      try {
        await supabase.from('allotments').update({
          'qc_status': 'IN_QC_CHECKING',
          'qc_received_at': DateTime.now().toUtc().toIso8601String(),
        }).inFilter('id', allTargetIds);
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF047857),
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
          SnackBar(backgroundColor: const Color(0xFFBE123C), content: Text('Error: $e')),
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

    final int assignedQty = _parseQty(task['assigned_qty'], 50);
    final int alreadyChecked = _parseQty(task['checked_qty']);
    final int remaining = (assignedQty - alreadyChecked).clamp(0, assignedQty);

    checkedCtrl.text = remaining > 0 ? remaining.toString() : assignedQty.toString();
    passedCtrl.text = checkedCtrl.text;
    alterCtrl.text = '0';

    String selectedDefect = _defectTypes.first['key']!;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final art = _asMap(task['article']) ?? _asMap(task['articles']);
          final artNo = art?['art_no']?.toString() ?? task['art_no']?.toString() ?? 'Article';
          final worker = task['worker_name']?.toString() ?? 'Checker';
          final sz = task['size']?.toString() ?? '';
          final clr = task['color']?.toString() ?? '';
          final alterQty = int.tryParse(alterCtrl.text.trim()) ?? 0;

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Header (Warm Cream)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFAF7F0),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    border: Border(bottom: BorderSide(color: Color(0x14000000), width: 1)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0x26000000), width: 1),
                              ),
                              child: Text(
                                'QUALITY CONTROL AUDIT',
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
                              'Record QC inspection',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Art #$artNo · $clr ($sz) · Checker: $worker',
                              style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF475569)),
                              overflow: TextOverflow.ellipsis,
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

                // Form Body
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Counter Inputs Row: Checked, Passed, Defective
                        Row(
                          children: [
                            // Total Checked
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'TOTAL CHECKED',
                                    style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.w800, color: const Color(0xFF334155), letterSpacing: 0.5),
                                  ),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: checkedCtrl,
                                    keyboardType: TextInputType.number,
                                    style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: const Color(0xFFF8FAFC),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF3A3564), width: 1.5)),
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
                            const SizedBox(width: 8),

                            // Passed OK
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'PASSED (OK)',
                                    style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.w800, color: const Color(0xFF047857), letterSpacing: 0.5),
                                  ),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: passedCtrl,
                                    keyboardType: TextInputType.number,
                                    style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF047857)),
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: const Color(0xFFECFDF5),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFA7F3D0))),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFA7F3D0))),
                                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF047857), width: 1.5)),
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
                            const SizedBox(width: 8),

                            // Defect / Alter
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'DEFECT / ALTER',
                                    style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.w800, color: const Color(0xFFBE123C), letterSpacing: 0.5),
                                  ),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: alterCtrl,
                                    keyboardType: TextInputType.number,
                                    style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFFBE123C)),
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: const Color(0xFFFFFCF3),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFFDE68A))),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFFDE68A))),
                                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFBE123C), width: 1.5)),
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
                              color: const Color(0xFFFFFCF3),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 18),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Lineman Alteration Alert',
                                        style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF92400E)),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFFFDE68A)),
                                      ),
                                      child: Text(
                                        '$alterQty pcs to alter',
                                        style: GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.w800, color: const Color(0xFF92400E)),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'These defective pieces will automatically notify the Lineman dashboard for sewing repair.',
                                  style: GoogleFonts.publicSans(fontSize: 11, color: const Color(0xFFB45309)),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'SELECT DEFECT CATEGORY',
                                  style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.w800, color: const Color(0xFF92400E), letterSpacing: 0.5),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: _defectTypes.map((d) {
                                    final isSel = selectedDefect == d['key'];
                                    return InkWell(
                                      onTap: () => setModalState(() => selectedDefect = d['key']!),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: isSel ? const Color(0xFF92400E) : Colors.white,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: isSel ? const Color(0xFF92400E) : const Color(0xFFFDE68A)),
                                        ),
                                        child: Text(
                                          d['label']!,
                                          style: GoogleFonts.publicSans(
                                            fontSize: 11,
                                            fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                                            color: isSel ? Colors.white : const Color(0xFF92400E),
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: remarksCtrl,
                                  style: GoogleFonts.publicSans(fontSize: 12.5, color: const Color(0xFF0F172A)),
                                  decoration: InputDecoration(
                                    hintText: 'Note for Lineman (e.g. Neck seam open, skip stitch on hem)',
                                    hintStyle: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF94A3B8)),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFFDE68A))),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFFDE68A))),
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
                              backgroundColor: const Color(0xFF3A3564),
                              foregroundColor: Colors.white,
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
                                        ? 'Pass ${passedCtrl.text} pcs & Flag $alterQty pcs for Alter'
                                        : 'Pass All ${passedCtrl.text} Pieces (OK)',
                                    style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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
              currentPassed += _parseQty(allotRes['qc_total_passed']);
              currentAlter += _parseQty(allotRes['qc_total_alter']);
              totalTarget = _parseQty(allotRes['mending_total_counted']) > 0 
                  ? _parseQty(allotRes['mending_total_counted']) 
                  : _parseQty(allotRes['target_qty']);
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
      final prevChecked = _parseQty(task['checked_qty']);
      final prevPassed = _parseQty(task['passed_qty']);
      final prevAlter = _parseQty(task['alter_qty']);
      final assignedQty = _parseQty(task['assigned_qty']);

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

      // 4. Update task status in local storage
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
            backgroundColor: alterQty > 0 ? const Color(0xFFD97706) : const Color(0xFF047857),
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
          SnackBar(backgroundColor: const Color(0xFFBE123C), content: Text('Error: $e')),
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
    final qty = _parseQty(alt['qty_rejected']);
    final logId = alt['id'];
    final art = _asMap(alt['article']) ?? _asMap(alt['articles']);
    final artNo = art?['art_no']?.toString() ?? alt['art_no']?.toString() ?? 'Article';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Pass Repaired Garments?',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16, color: const Color(0xFF047857)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Art #$artNo', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF0F172A))),
            const SizedBox(height: 4),
            Text('Defect: ${alt['defect_type'] ?? '-'}', style: GoogleFonts.publicSans(fontSize: 12.5, color: const Color(0xFF64748B))),
            const SizedBox(height: 12),
            Text(
              'Confirm that Lineman has repaired all $qty defective pieces and they have passed physical re-inspection.',
              style: GoogleFonts.publicSans(fontSize: 12.5, color: const Color(0xFF334155)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.publicSans(color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF047857),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
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
              backgroundColor: const Color(0xFF047857),
              content: Text('✓ $qty repaired pieces verified & passed inspection!'),
            ),
          );
          _fetchQcData();
        }
      } catch (e) {
        debugPrint('Error verifying repaired pieces: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: const Color(0xFFBE123C), content: Text('Error: $e')),
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
          content: Text('Handover submitted for Admin Approval! Store Manager will be notified once approved.'),
          backgroundColor: const Color(0xFF047857),
        ),
      );
      await _fetchQcData();
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFBE123C)),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }



  // ====================================================
  // BUILD UI — CANONICAL ENTERPRISE DESIGN SYSTEM
  // ====================================================
  @override
  Widget build(BuildContext context) {
    final double passRate = _totalCheckedToday > 0
        ? ((_totalPassedToday / _totalCheckedToday) * 100).clamp(0.0, 100.0)
        : 100.0;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFFAFAF8),
      drawer: const AdminDrawer(activeRoute: '/stitching-sewing/qc'),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Top Navbar (Web Parity: Drawer button, Web Logo, QC MES Badge & Sign Out)
            _buildTopNavbar(),

            // 2. Encapsulated Header Card
            _buildEncapsulatedHeader(),

            // 3. Body Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF0B1220)))
                  : RefreshIndicator(
                      color: const Color(0xFF0B1220),
                      backgroundColor: Colors.white,
                      onRefresh: _fetchQcData,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 3. Shift Hero Summary Card
                            _buildHeroSummaryCard(passRate),
                            const SizedBox(height: 12),

                            // 4. Amber Notification Callout (From Mending Floor)
                            if (_incomingLots.isNotEmpty) ...[
                              _buildAmberNotificationCallout(),
                              const SizedBox(height: 12),
                            ],

                            // 5. Horizontal Pill Tabs
                            _buildHorizontalTabs(),
                            const SizedBox(height: 12),

                            // Search bar for real-time section filtering
                            _buildSearchBar(),
                            const SizedBox(height: 8),

                            // 6. Tab Content
                            if (_selectedTabIndex == 0)
                              _buildIncomingLotsSection()
                            else if (_selectedTabIndex == 1)
                              _buildActiveCheckingSection()
                            else if (_selectedTabIndex == 2)
                              _buildAlterationsSection()
                            else
                              _buildReadyForChallanSection(),
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

  // 1. TOP NAVBAR (100% Web Parity)
  Widget _buildTopNavbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drawer Hamburger Button
              InkWell(
                onTap: () => _scaffoldKey.currentState?.openDrawer(),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.menu_rounded, color: Color(0xFF0B1220), size: 20),
                ),
              ),
              const SizedBox(width: 10),
              // Web Logo
              Image.asset(
                'assets/images/new_icon.png',
                height: 28,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Image.asset(
                  'assets/images/icon.png',
                  height: 28,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.fact_check_rounded, color: Color(0xFF0B1220), size: 24),
                ),
              ),
              const SizedBox(width: 6),
              Image.asset(
                'assets/images/zigza_new_logo.png',
                height: 20,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Image.asset(
                  'assets/images/z_i_g_z_a.png',
                  height: 20,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Text(
                    'ZIGZA',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0B1220),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Role Badge on the right
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDFA),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF14C8B4).withValues(alpha: 0.3)),
            ),
            child: Text(
              'QC MES',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0B1220),
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 2. ENCAPSULATED HEADER CARD
  Widget _buildEncapsulatedHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Checkbox icon tile
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Icon(Icons.fact_check_outlined, color: Color(0xFF0B1220), size: 21),
              ),
              const SizedBox(width: 12),
              // User info
              Expanded(
                child: Consumer(
                  builder: (context, ref, _) {
                    final authState = ref.watch(authProvider);
                    final tenant = authState.tenantProfile;
                    final user = supabase.auth.currentUser;

                    String displayName = '';
                    if (authState.cachedUsername != null &&
                        authState.cachedUsername!.trim().isNotEmpty &&
                        !authState.cachedUsername!.contains('@')) {
                      displayName = authState.cachedUsername!.trim();
                    } else if (tenant?.customUsername != null &&
                        tenant!.customUsername.trim().isNotEmpty &&
                        !tenant.customUsername.contains('@')) {
                      displayName = tenant.customUsername.trim();
                    } else if (tenant?.adminDisplayName != null &&
                        tenant!.adminDisplayName.trim().isNotEmpty &&
                        !tenant.adminDisplayName.contains('@')) {
                      displayName = tenant.adminDisplayName.trim();
                    } else {
                      final rawEmail = tenant?.userEmail ?? user?.email ?? '';
                      if (rawEmail.contains('@')) {
                        final prefix = rawEmail.split('@').first;
                        displayName = prefix;
                      } else {
                        displayName = rawEmail.isNotEmpty ? rawEmail : 'QC Supervisor';
                      }
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome, $displayName',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0B1220),
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Quality Clinic & Export Packing',
                          style: GoogleFonts.publicSans(
                            fontSize: 11.5,
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              // Soft Pastel Online Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFA7F3D0), width: 1),
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
          const SizedBox(height: 12),
          // Sync button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _fetchQcData,
              icon: const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFF0B1220)),
              label: Text(
                'Sync Floor Data',
                style: GoogleFonts.publicSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0B1220),
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                backgroundColor: const Color(0xFFF8FAFC),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 3. HERO SUMMARY CARD (Solid #0B1220 fill Web Obsidian Parity)
  Widget _buildHeroSummaryCard(double passRate) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B1220).withValues(alpha: 0.2),
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_getShiftName()} - QC floor summary',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Finishing & quality assurance flow',
                      style: GoogleFonts.publicSans(
                        fontSize: 11.5,
                        color: const Color(0xFF94A3B8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Pass rate pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF14C8B4).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF14C8B4).withValues(alpha: 0.3)),
                ),
                child: Text(
                  'PASS: ${passRate.toStringAsFixed(0)}%',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF5EEAD4),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 4-column stat row
          Row(
            children: [
              _buildHeroStatColumn('Received', '$_totalReceivedFromMending', Icons.move_to_inbox_outlined),
              _buildHeroStatColumn('In QC', '$_totalInChecking', Icons.fact_check_outlined),
              _buildHeroStatColumn('Alteration', '$_totalInAlteration', Icons.handyman_outlined, isAlter: _totalInAlteration > 0),
              _buildHeroStatColumn('Ready Challan', '$_totalReadyForChallan', Icons.local_shipping_outlined),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStatColumn(String label, String value, IconData icon, {bool isAlter = false}) {
    return Expanded(
      child: Column(
        children: [
          Icon(
            icon,
            size: 18,
            color: isAlter ? const Color(0xFFFDE68A) : Colors.white.withValues(alpha: 0.85),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: isAlter ? const Color(0xFFFDE68A) : Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.publicSans(
              fontSize: 10.5,
              color: const Color(0xFFCBD5E1),
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // 4. AMBER NOTIFICATION CALLOUT
  Widget _buildAmberNotificationCallout() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: const Icon(Icons.notifications_active_outlined, color: Color(0xFFD97706), size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_incomingLots.length} lot(s) handed over from mending floor',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Verified physical piece counts ready for QC checker assignment below.',
                  style: GoogleFonts.publicSans(
                    fontSize: 11,
                    color: const Color(0xFFB45309),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 5. HORIZONTAL PILL TABS
  Widget _buildHorizontalTabs() {
    final tabs = [
      {'label': 'Incoming', 'count': _incomingLots.length},
      {'label': 'In QC', 'count': _activeAssignments.length},
      {'label': 'Alter', 'count': _activeAlterations.length},
      {'label': 'Ready', 'count': _readyForChallanLots.length},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(tabs.length, (i) {
          final isSel = _selectedTabIndex == i;
          final tab = tabs[i];
          final label = tab['label'] as String;
          final count = tab['count'] as int;

          return Padding(
            padding: EdgeInsets.only(right: i == tabs.length - 1 ? 0 : 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _selectedTabIndex = i),
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSel ? const Color(0xFF0B1220) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSel ? const Color(0xFF0B1220) : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isSel ? const Color(0xFF0B1220).withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.publicSans(
                          fontSize: 12.5,
                          fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                          color: isSel ? Colors.white : const Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSel ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: isSel ? Colors.white : const Color(0xFF0B1220),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // SEARCH BAR FOR REAL-TIME FILTERING ACROSS ALL SECTIONS
  Widget _buildSearchBar() {
    String hintText;
    switch (_selectedTabIndex) {
      case 0:
        hintText = 'Search incoming lots (Art No, Challan, Lineman)...';
        break;
      case 1:
        hintText = 'Search in-progress (Art No, Checker, Color, Size)...';
        break;
      case 2:
        hintText = 'Search alterations (Art No, Defect, Lineman)...';
        break;
      default:
        hintText = 'Search ready articles (Art No, Brand, Challan)...';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
        style: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF0F172A)),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: GoogleFonts.publicSans(fontSize: 12.5, color: const Color(0xFF94A3B8)),
          prefixIcon: const Icon(Icons.search_rounded, size: 19, color: Color(0xFF64748B)),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF94A3B8)),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          border: InputBorder.none,
          isDense: true,
        ),
      ),
    );
  }

  // TWO-BUTTON FILTER ROW (MY ASSIGNED VS ALL FLOOR)
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
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                decoration: BoxDecoration(
                  color: _incomingFilterMode == 0 ? const Color(0xFF0B1220) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _incomingFilterMode == 0 ? const Color(0xFF0B1220) : const Color(0xFFE2E8F0),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_pin_rounded,
                      size: 14,
                      color: _incomingFilterMode == 0 ? Colors.white : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'My assigned lots ',
                              style: GoogleFonts.publicSans(
                                fontSize: 11.5,
                                fontWeight: _incomingFilterMode == 0 ? FontWeight.w800 : FontWeight.w600,
                                color: _incomingFilterMode == 0 ? Colors.white : const Color(0xFF475569),
                              ),
                            ),
                            TextSpan(
                              text: '($myCount)',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _incomingFilterMode == 0 ? Colors.white : const Color(0xFF64748B),
                              ),
                            ),
                          ],
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
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _incomingFilterMode = 1),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                decoration: BoxDecoration(
                  color: _incomingFilterMode == 1 ? const Color(0xFF0B1220) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _incomingFilterMode == 1 ? const Color(0xFF0B1220) : const Color(0xFFE2E8F0),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.factory_rounded,
                      size: 14,
                      color: _incomingFilterMode == 1 ? Colors.white : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'All floor lots ',
                              style: GoogleFonts.publicSans(
                                fontSize: 11.5,
                                fontWeight: _incomingFilterMode == 1 ? FontWeight.w800 : FontWeight.w600,
                                color: _incomingFilterMode == 1 ? Colors.white : const Color(0xFF475569),
                              ),
                            ),
                            TextSpan(
                              text: '($allCount)',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _incomingFilterMode == 1 ? Colors.white : const Color(0xFF64748B),
                              ),
                            ),
                          ],
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

  // ====================================================
  // TAB 0: INCOMING LOTS (FROM MENDING)
  // ====================================================
  Widget _buildIncomingLotsSection() {
    if (_incomingLots.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Icon(Icons.inbox_outlined, size: 36, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 14),
              Text(
                'No Incoming Lots from Mending',
                style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF0B1220)),
              ),
              const SizedBox(height: 4),
              Text(
                'When Mending supervisors verify piece counts and tap "Forward to QC", lots will immediately appear here ready for checker assignment.',
                textAlign: TextAlign.center,
                style: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      );
    }

    final displayLots = _filteredIncomingLots.where((lot) {
      if (_searchQuery.isEmpty) return true;
      final art = _asMap(lot['article']) ?? _asMap(lot['articles']);
      final artNo = (art?['art_no'] ?? lot['art_no'] ?? '').toString().toLowerCase();
      final desc = (art?['description'] ?? lot['description'] ?? '').toString().toLowerCase();
      final chal = _asMap(lot['challans']);
      final challanNo = (chal?['challan_no'] ?? lot['challan_no'] ?? '').toString().toLowerCase();
      final brand = (chal?['brand'] ?? lot['brand'] ?? '').toString().toLowerCase();
      final lm = _asMap(lot['lineman']);
      final lineman = (lm?['username'] ?? '').toString().toLowerCase();
      final handedBy = (lot['handed_to_qc_by'] ?? '').toString().toLowerCase();

      return artNo.contains(_searchQuery) ||
          desc.contains(_searchQuery) ||
          challanNo.contains(_searchQuery) ||
          brand.contains(_searchQuery) ||
          lineman.contains(_searchQuery) ||
          handedBy.contains(_searchQuery);
    }).toList();

    return Column(
      children: [
        _buildIncomingFilterBar(),
        if (displayLots.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.search_off_rounded, size: 32, color: Color(0xFF94A3B8)),
                  const SizedBox(height: 8),
                  Text(
                    _searchQuery.isNotEmpty
                        ? 'No incoming lots match "$_searchQuery"'
                        : 'No lots assigned to your queue in this filter.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF64748B)),
                  ),
                  if (_searchQuery.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                      child: Text('Clear search', style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF3A3564))),
                    ),
                  ],
                ],
              ),
            ),
          )
        else
          ...displayLots.map((lot) {
            final art = _asMap(lot['article']) ?? _asMap(lot['articles']);
            final artNo = art?['art_no']?.toString() ?? lot['art_no']?.toString() ?? 'Article';
            final desc = art?['description']?.toString() ?? lot['description']?.toString() ?? '';
            final chal = _asMap(lot['challans']);
            final challanNo = chal?['challan_no']?.toString() ?? lot['challan_no']?.toString() ?? '-';
            final brand = (chal?['brand'] ?? lot['brand'] ?? '').toString();
            final lm = _asMap(lot['lineman']);
            final lineman = lm?['username']?.toString() ?? 'Lineman';
            final handedBy = lot['handed_to_qc_by']?.toString();
            final supName = lot['qc_supervisor_name']?.toString() ?? 'General Pool';
            final handoverNotes = lot['qc_handover_notes']?.toString();

            final int adminAllotted = _parseQty(lot['admin_total_qty']);
            final int mendingCounted = _parseQty(lot['mending_received_qty'], adminAllotted);
            final int variance = _parseQty(lot['variance'], mendingCounted - adminAllotted);
            final sizeMatrix = (lot['size_matrix'] as List<dynamic>?) ?? [];

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
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
                  // 7. Amber Custody Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFFCF3),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                      border: Border(bottom: BorderSide(color: Color(0xFFFDE68A), width: 1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.handshake_outlined, size: 15, color: Color(0xFFB45309)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'From mending: ${handedBy != null && handedBy.isNotEmpty ? handedBy : 'Mending Floor'}',
                                style: GoogleFonts.publicSans(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF92400E)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFFDE68A)),
                              ),
                              child: Text(
                                'CUSTODY: $supName',
                                style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.w800, color: const Color(0xFF92400E)),
                              ),
                            ),
                          ],
                        ),
                        if (handoverNotes != null && handoverNotes.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Note: $handoverNotes',
                            style: GoogleFonts.publicSans(fontSize: 11, fontStyle: FontStyle.italic, color: const Color(0xFF78350F)),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // 8. Lot Detail Body
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top row: Challan code chip + Stitched by tag
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Text(
                                  'CH-$challanNo ${brand.isNotEmpty ? "· $brand" : ""}',
                                  style: GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.w700, color: const Color(0xFF475569)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFA7F3D0)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.person_pin_circle_outlined, size: 12, color: Color(0xFF047857)),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        'Stitched by: $lineman',
                                        style: GoogleFonts.publicSans(fontSize: 10.5, fontWeight: FontWeight.w700, color: const Color(0xFF047857)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Article Code & Style Descriptor
                        Text(
                          'Art #$artNo',
                          style: GoogleFonts.jetBrainsMono(fontSize: 17, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                        ),
                        if (desc.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            desc,
                            style: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF64748B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],

                        const SizedBox(height: 12),
                        const Divider(height: 1, color: Color(0x14000000)),
                        const SizedBox(height: 12),

                        // 3-Column Stat Row (Admin allotted / Mending counted / Variance)
                        Row(
                          children: [
                            // Admin allotted
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Admin allotted',
                                    style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$adminAllotted pcs',
                                    style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                                  ),
                                ],
                              ),
                            ),
                            Container(width: 1, height: 28, color: const Color(0x14000000)),
                            const SizedBox(width: 10),

                            // Mending counted
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    'Mending counted',
                                    style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$mendingCounted pcs',
                                    style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF3A3564)),
                                  ),
                                ],
                              ),
                            ),
                            Container(width: 1, height: 28, color: const Color(0x14000000)),
                            const SizedBox(width: 10),

                            // Variance with soft pastel pill
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Variance',
                                    style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                                  ),
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: variance == 0
                                          ? const Color(0xFFECFDF5)
                                          : (variance < 0 ? const Color(0xFFFFF1F2) : const Color(0xFFEFF6FF)),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: variance == 0
                                            ? const Color(0xFFA7F3D0)
                                            : (variance < 0 ? const Color(0xFFFECDD3) : const Color(0xFFBFDBFE)),
                                      ),
                                    ),
                                    child: Text(
                                      variance == 0
                                          ? 'Exact (0)'
                                          : (variance < 0 ? '$variance pcs' : '+$variance pcs'),
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: variance == 0
                                            ? const Color(0xFF047857)
                                            : (variance < 0 ? const Color(0xFFBE123C) : const Color(0xFF1E40AF)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Natural size breakdown chips
                        if (sizeMatrix.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Divider(height: 1, color: Color(0x14000000)),
                          const SizedBox(height: 10),
                          Text(
                            'Natural size breakdown (mending count / admin allotted)',
                            style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: sizeMatrix.map((sm) {
                              final sz = sm['size'] ?? '-';
                              final clr = sm['color'] ?? '';
                              final aQ = _parseQty(sm['allotted_qty']);
                              final mQ = _parseQty(sm['mending_qty']);
                              final target = aQ > 0 ? aQ : (mQ > 0 ? mQ : aQ);
                              final qcAssigned = _getAssignedQtyForVariant(lot, sm);
                              final qcRem = target - qcAssigned;
                              final isDiff = mQ != aQ && mQ > 0;
                              final clrLabel = clr.isNotEmpty && clr != '-' ? ' ($clr)' : '';

                              final isDone = qcRem <= 0 && target > 0;

                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDone
                                      ? const Color(0xFFECFDF5)
                                      : (isDiff ? const Color(0xFFFFFCF3) : const Color(0xFFFAF7F0)),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isDone
                                        ? const Color(0xFFA7F3D0)
                                        : (isDiff ? const Color(0xFFFDE68A) : const Color(0x1A000000)),
                                  ),
                                ),
                                child: Text(
                                  qcAssigned > 0
                                      ? '$sz$clrLabel: $aQ pcs (${qcRem > 0 ? "$qcRem left" : "Done ✓"})'
                                      : (mQ > 0 && mQ != aQ
                                          ? '$sz$clrLabel: $mQ/$aQ pcs'
                                          : '$sz$clrLabel: $aQ pcs'),
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: isDone
                                        ? const Color(0xFF047857)
                                        : (isDiff ? const Color(0xFF92400E) : const Color(0xFF0F172A)),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],

                        const SizedBox(height: 14),

                        // Full-width Primary Button: Assign QC checker / worker
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.person_add_outlined, size: 17, color: Colors.white),
                            label: Text(
                              'Assign QC checker / worker',
                              style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3A3564),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            onPressed: () => _openAssignWorkerModal(lot),
                          ),
                        ),
                      ],
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
  // TAB 1: ACTIVE QC CHECKING (IN PROGRESS — GROUPED BY ARTICLE)
  // ====================================================
  Widget _buildActiveCheckingSection() {
    if (_activeAssignments.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x1A000000)),
        ),
        child: Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF7F0),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0x1A000000)),
                ),
                child: const Icon(Icons.fact_check_outlined, size: 36, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 14),
              Text(
                'No Active QC Checking Tasks',
                style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
              ),
              const SizedBox(height: 4),
              Text(
                'Assign incoming lots to checkers to inspect garment pieces here.',
                textAlign: TextAlign.center,
                style: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      );
    }

    // Group active assignments by Article
    final Map<String, Map<String, dynamic>> articleGroups = {};
    for (var task in _activeAssignments) {
      final art = _asMap(task['article']) ?? _asMap(task['articles']);
      final artId = task['article_id']?.toString() ?? art?['id']?.toString() ?? '';
      final artNo = art?['art_no']?.toString() ?? task['art_no']?.toString() ?? 'Article';
      final desc = art?['description']?.toString() ?? task['description']?.toString() ?? '';
      final chal = _asMap(task['challans']);
      final challanNo = chal?['challan_no']?.toString() ?? task['challan_no']?.toString() ?? '';
      final groupKey = artId.isNotEmpty ? artId : artNo;

      final brand = chal?['brand'] ?? task['brand'] ?? '';
      final vendorId = chal?['vendor_id'] ?? task['vendor_id'] ?? '';
      final vendorName = chal?['vendor_name'] ?? task['vendor_name'] ?? '';

      if (!articleGroups.containsKey(groupKey)) {
        articleGroups[groupKey] = {
          'key': groupKey,
          'article_id': artId,
          'art_no': artNo,
          'description': desc,
          'challan_no': challanNo,
          'brand': brand,
          'vendor_id': vendorId,
          'vendor_name': vendorName,
          'tasks': <Map<String, dynamic>>[],
          'total_assigned': 0,
          'total_checked': 0,
          'total_passed': 0,
          'total_alter': 0,
        };
      }

      final group = articleGroups[groupKey]!;
      final tasksList = group['tasks'] as List<Map<String, dynamic>>;
      tasksList.add(task);

      final assigned = _parseQty(task['assigned_qty']);
      final checked = _parseQty(task['checked_qty']);
      final passed = _parseQty(task['passed_qty']);
      final alter = _parseQty(task['alter_qty']);

      group['total_assigned'] = _parseQty(group['total_assigned']) + assigned;
      group['total_checked'] = _parseQty(group['total_checked']) + checked;
      group['total_passed'] = _parseQty(group['total_passed']) + passed;
      group['total_alter'] = _parseQty(group['total_alter']) + alter;
    }

    final groups = articleGroups.values.toList();

    final filteredGroups = groups.where((group) {
      if (_searchQuery.isEmpty) return true;
      final artNo = (group['art_no'] ?? '').toString().toLowerCase();
      final desc = (group['description'] ?? '').toString().toLowerCase();
      final challanNo = (group['challan_no'] ?? '').toString().toLowerCase();
      final tasks = group['tasks'] as List<Map<String, dynamic>>;

      final bool matchesArt = artNo.contains(_searchQuery) || desc.contains(_searchQuery) || challanNo.contains(_searchQuery);
      final bool matchesTask = tasks.any((t) {
        final worker = (t['worker_name'] ?? '').toString().toLowerCase();
        final clr = (t['color'] ?? '').toString().toLowerCase();
        final sz = (t['size'] ?? '').toString().toLowerCase();
        return worker.contains(_searchQuery) || clr.contains(_searchQuery) || sz.contains(_searchQuery);
      });

      return matchesArt || matchesTask;
    }).map((group) {
      if (_searchQuery.isEmpty) return group;
      final artNo = (group['art_no'] ?? '').toString().toLowerCase();
      final desc = (group['description'] ?? '').toString().toLowerCase();
      final challanNo = (group['challan_no'] ?? '').toString().toLowerCase();
      if (artNo.contains(_searchQuery) || desc.contains(_searchQuery) || challanNo.contains(_searchQuery)) {
        return group;
      }
      final tasks = (group['tasks'] as List<Map<String, dynamic>>).where((t) {
        final worker = (t['worker_name'] ?? '').toString().toLowerCase();
        final clr = (t['color'] ?? '').toString().toLowerCase();
        final sz = (t['size'] ?? '').toString().toLowerCase();
        return worker.contains(_searchQuery) || clr.contains(_searchQuery) || sz.contains(_searchQuery);
      }).toList();
      return {
        ...group,
        'tasks': tasks,
      };
    }).toList();

    if (filteredGroups.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.search_off_rounded, size: 32, color: Color(0xFF94A3B8)),
              const SizedBox(height: 8),
              Text(
                'No in-progress checking tasks match "$_searchQuery"',
                textAlign: TextAlign.center,
                style: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF64748B)),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
                child: Text('Clear search', style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF3A3564))),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: filteredGroups.map((group) {
        final groupKey = group['key']?.toString() ?? group['art_no']?.toString() ?? 'Article';
        final artNo = group['art_no']?.toString() ?? 'Article';
        final desc = group['description']?.toString() ?? '';
        final challanNo = group['challan_no']?.toString() ?? '';
        final tasks = group['tasks'] as List<Map<String, dynamic>>;
        final int grpAssigned = _parseQty(group['total_assigned']);
        final int grpChecked = _parseQty(group['total_checked']);
        final int grpPassed = _parseQty(group['total_passed']);
        final int grpAlter = _parseQty(group['total_alter']);
        final double grpProgress = grpAssigned > 0 ? (grpChecked / grpAssigned).clamp(0.0, 1.0) : 1.0;
        final bool grpDone = grpChecked >= grpAssigned && grpAssigned > 0;
        final bool isExpanded = _expandedArticleGroups.contains(groupKey) || _searchQuery.isNotEmpty;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: grpDone ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Article Master Header (Clickable to Expand / Collapse)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      if (_expandedArticleGroups.contains(groupKey)) {
                        _expandedArticleGroups.remove(groupKey);
                      } else {
                        _expandedArticleGroups.add(groupKey);
                      }
                    });
                  },
                  borderRadius: isExpanded
                      ? const BorderRadius.vertical(top: Radius.circular(15))
                      : BorderRadius.circular(15),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: isExpanded
                          ? const BorderRadius.vertical(top: Radius.circular(15))
                          : BorderRadius.circular(15),
                      border: isExpanded ? const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))) : null,
                    ),
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
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0B1220),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'ARTICLE',
                                          style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
                                        ),
                                      ),
                                      if (challanNo.isNotEmpty) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE2E8F0),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'CH-$challanNo',
                                            style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF475569)),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Art #$artNo',
                                    style: GoogleFonts.jetBrainsMono(fontSize: 17, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                                  ),
                                  if (desc.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      desc,
                                      style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF64748B)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Overall Progress Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: grpDone ? const Color(0xFFECFDF5) : const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: grpDone ? const Color(0xFFA7F3D0) : const Color(0xFFBFDBFE),
                                ),
                              ),
                              child: Text(
                                grpDone ? 'All Done ✓' : '$grpChecked/$grpAssigned pcs (${(grpProgress * 100).toInt()}%)',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: grpDone ? const Color(0xFF047857) : const Color(0xFF1E40AF),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Article-level Linear Progress Bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: grpProgress,
                            minHeight: 5,
                            backgroundColor: const Color(0xFFE2E8F0),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              grpDone ? const Color(0xFF047857) : const Color(0xFF3A3564),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Article Summary 4-Metrics Bar
                        Row(
                          children: [
                            _buildInspectionMetricCard('Total Assigned', '$grpAssigned pcs', const Color(0xFF0F172A)),
                            const SizedBox(width: 6),
                            _buildInspectionMetricCard('Total Checked', '$grpChecked pcs', const Color(0xFF3A3564)),
                            const SizedBox(width: 6),
                            _buildInspectionMetricCard('Total Passed', '$grpPassed pcs', const Color(0xFF047857)),
                            const SizedBox(width: 6),
                            _buildInspectionMetricCard('Total Alter', '$grpAlter pcs', grpAlter > 0 ? const Color(0xFFBE123C) : const Color(0xFF64748B)),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Direct Delivery Challan Action Button (When checked pieces are ready)
                        if (grpPassed > 0 || grpChecked > 0) ...[
                          SizedBox(
                            width: double.infinity,
                            height: 38,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.local_shipping_rounded, size: 16, color: Colors.white),
                              label: Text(
                                'Direct Delivery Challan (${grpPassed > 0 ? grpPassed : grpChecked} pcs Ready)',
                                style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3A3564),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 0,
                              ),
                              onPressed: () {
                                // Aggregate all checker tasks for this article by color & size
                                final Map<String, Map<String, dynamic>> variantAgg = {};
                                for (var t in tasks) {
                                  final c = (t['color'] ?? 'Default').toString().trim().toUpperCase();
                                  final s = (t['size'] ?? 'Free').toString().trim().toUpperCase();
                                  final key = '$c|||$s';
                                  final assignQ = _parseQty(t['assigned_qty']);
                                  final passQ = _parseQty(t['passed_qty']);
                                  final checkQ = _parseQty(t['checked_qty']);

                                  if (!variantAgg.containsKey(key)) {
                                    variantAgg[key] = {
                                      'color': c,
                                      'size': s,
                                      'order_qty': assignQ,
                                      'allotted_qty': assignQ,
                                      'quantity': assignQ,
                                      'qc_passed_qty': passQ > 0 ? passQ : (checkQ > 0 ? checkQ : assignQ),
                                    };
                                  } else {
                                    variantAgg[key]!['order_qty'] = _parseQty(variantAgg[key]!['order_qty']) + assignQ;
                                    variantAgg[key]!['allotted_qty'] = _parseQty(variantAgg[key]!['allotted_qty']) + assignQ;
                                    variantAgg[key]!['quantity'] = _parseQty(variantAgg[key]!['quantity']) + assignQ;
                                    variantAgg[key]!['qc_passed_qty'] = _parseQty(variantAgg[key]!['qc_passed_qty']) + (passQ > 0 ? passQ : (checkQ > 0 ? checkQ : assignQ));
                                  }
                                }
                                final aggregatedVariants = variantAgg.values.toList();
                                aggregatedVariants.sort((a, b) => _naturalSizeCompare((a['size'] ?? '').toString(), (b['size'] ?? '').toString()));

                                final lotPayload = {
                                  'id': tasks.isNotEmpty ? tasks.first['allotment_id'] : null,
                                  'article_id': group['article_id'] ?? (tasks.isNotEmpty ? tasks.first['article_id'] : null),
                                  'art_no': artNo,
                                  'article': {
                                    'id': group['article_id'] ?? (tasks.isNotEmpty ? tasks.first['article_id'] : null),
                                    'art_no': artNo,
                                    'description': desc,
                                  },
                                  'challans': {
                                    'challan_no': challanNo,
                                    'brand': group['brand'] ?? '',
                                    'vendor_name': group['vendor_name'] ?? '',
                                  },
                                  'qc_total_passed': grpPassed > 0 ? grpPassed : grpChecked,
                                  'variants': aggregatedVariants,
                                };

                                _showDeliveryChallanModal(prefilledLot: lotPayload);
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],

                        // Tap to expand / collapse helper banner
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isExpanded ? const Color(0xFF3A3564).withValues(alpha: 0.06) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isExpanded ? const Color(0xFF3A3564).withValues(alpha: 0.2) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                    size: 18,
                                    color: const Color(0xFF3A3564),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    isExpanded ? 'Hide assigned checkers' : 'Tap to view ${tasks.length} assigned checkers',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF3A3564),
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isExpanded ? const Color(0xFF3A3564) : Colors.white,
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: isExpanded ? const Color(0xFF3A3564) : const Color(0xFFCBD5E1),
                                  ),
                                ),
                                child: Text(
                                  isExpanded ? 'COLLAPSE' : 'EXPAND (${tasks.length})',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: isExpanded ? Colors.white : const Color(0xFF475569),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // If expanded, show assigned checkers section and checker cards
              if (isExpanded) ...[
                // 2. Section Header: Active Checkers assigned to this Article
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ASSIGNED CHECKERS (${tasks.length})',
                        style: GoogleFonts.publicSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      Text(
                        'Art #$artNo Queue',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),

                // 3. List of Individual Checkers under this Article
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Column(
                    children: tasks.map((task) {
                      final worker = task['worker_name'] ?? 'Checker';
                      final clr = task['color'] ?? '';
                      final sz = task['size'] ?? '';
                      final int assigned = _parseQty(task['assigned_qty']);
                      final int checked = _parseQty(task['checked_qty']);
                      final int passed = _parseQty(task['passed_qty']);
                      final int alter = _parseQty(task['alter_qty']);
                      final isDone = task['status'] == 'DONE' || checked >= assigned;
                      final double progress = assigned > 0 ? (checked / assigned).clamp(0.0, 1.0) : 1.0;

                      return Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAFAF8),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDone ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0),
                          ),
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
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(7),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: const Icon(Icons.person_outline_rounded, size: 15, color: Color(0xFF3A3564)),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Checker: $worker',
                                      style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: isDone ? const Color(0xFFECFDF5) : const Color(0xFFFFFCF3),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isDone ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A),
                                    ),
                                  ),
                                  child: Text(
                                    isDone ? 'Completed' : 'In Progress (${(progress * 100).toInt()}%)',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: isDone ? const Color(0xFF047857) : const Color(0xFF92400E),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),

                            // Variant chip (Color & Size)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: Text(
                                '$clr ($sz)',
                                style: GoogleFonts.jetBrainsMono(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF3A3564)),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Mini Progress Bar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 4,
                                backgroundColor: const Color(0xFFE2E8F0),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isDone ? const Color(0xFF047857) : const Color(0xFF3A3564),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // 4-stat metrics row for this checker
                            Row(
                              children: [
                                _buildInspectionMetricCard('Assigned', '$assigned pcs', const Color(0xFF0F172A)),
                                const SizedBox(width: 4),
                                _buildInspectionMetricCard('Checked', '$checked pcs', const Color(0xFF3A3564)),
                                const SizedBox(width: 4),
                                _buildInspectionMetricCard('Passed', '$passed pcs', const Color(0xFF047857)),
                                const SizedBox(width: 4),
                                _buildInspectionMetricCard('Alter', '$alter pcs', alter > 0 ? const Color(0xFFBE123C) : const Color(0xFF64748B)),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Button: Record QC Inspection
                            SizedBox(
                              width: double.infinity,
                              height: 38,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.fact_check_outlined, size: 15, color: Colors.white),
                                label: Text('Record QC Inspection', style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF3A3564),
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
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInspectionMetricCard(String label, String value, Color valueColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFAF7F0),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0x14000000)),
        ),
        child: Column(
          children: [
            Text(label, style: GoogleFonts.publicSans(fontSize: 9.5, color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(value, style: GoogleFonts.jetBrainsMono(fontSize: 11.5, fontWeight: FontWeight.w800, color: valueColor)),
          ],
        ),
      ),
    );
  }

  // ====================================================
  // TAB 2: ALTERATIONS (WITH LINEMAN)
  // ====================================================
  Widget _buildAlterationsSection() {
    if (_activeAlterations.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x1A000000)),
        ),
        child: Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: const Icon(Icons.check_circle_outline_rounded, size: 36, color: Color(0xFF047857)),
              ),
              const SizedBox(height: 14),
              Text(
                'Zero Pending Alterations',
                style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
              ),
              const SizedBox(height: 4),
              Text(
                'All defective pieces have been repaired by linemen or none reported.',
                textAlign: TextAlign.center,
                style: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      );
    }

    final displayAlterations = _activeAlterations.where((alt) {
      if (_searchQuery.isEmpty) return true;
      final art = _asMap(alt['article']) ?? _asMap(alt['articles']);
      final artNo = (art?['art_no'] ?? alt['art_no'] ?? '').toString().toLowerCase();
      final lm = _asMap(alt['lineman']);
      final lineman = (lm?['username'] ?? '').toString().toLowerCase();
      final defect = (alt['defect_type'] ?? '').toString().toLowerCase();
      final remarks = (alt['remarks'] ?? '').toString().toLowerCase();
      final color = (alt['color'] ?? '').toString().toLowerCase();
      final size = (alt['size'] ?? '').toString().toLowerCase();

      return artNo.contains(_searchQuery) ||
          lineman.contains(_searchQuery) ||
          defect.contains(_searchQuery) ||
          remarks.contains(_searchQuery) ||
          color.contains(_searchQuery) ||
          size.contains(_searchQuery);
    }).toList();

    if (displayAlterations.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.search_off_rounded, size: 32, color: Color(0xFF94A3B8)),
              const SizedBox(height: 8),
              Text(
                _searchQuery.isNotEmpty
                    ? 'No alterations match "$_searchQuery"'
                    : 'No pending alterations found.',
                textAlign: TextAlign.center,
                style: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF64748B)),
              ),
              if (_searchQuery.isNotEmpty) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                  child: Text('Clear search', style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF3A3564))),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Column(
      children: displayAlterations.map((alt) {
        final art = _asMap(alt['article']) ?? _asMap(alt['articles']);
        final artNo = art?['art_no']?.toString() ?? alt['art_no']?.toString() ?? 'Article';
        final lm = _asMap(alt['lineman']);
        final lineman = lm?['username']?.toString() ?? 'Lineman';
        final int qty = _parseQty(alt['qty_rejected']);
        final defect = alt['defect_type'] ?? 'Defect';
        final remarks = alt['remarks'] ?? '';
        final color = alt['color'] ?? '';
        final size = alt['size'] ?? '';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
            boxShadow: const [
              BoxShadow(color: Color(0x06000000), blurRadius: 2, offset: Offset(0, 1)),
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
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFCF3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: const Icon(Icons.handyman_outlined, size: 16, color: Color(0xFFD97706)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'With Lineman: $lineman',
                        style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFFECDD3)),
                    ),
                    child: Text(
                      '$qty pcs',
                      style: GoogleFonts.jetBrainsMono(fontSize: 11.5, fontWeight: FontWeight.w800, color: const Color(0xFFBE123C)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Art #$artNo ${color.isNotEmpty ? "· $color ($size)" : ""}',
                style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF3A3564)),
              ),
              const SizedBox(height: 4),
              Text(
                'Defect: $defect',
                style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFFBE123C)),
              ),
              if (remarks.toString().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  'Note: $remarks',
                  style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF64748B)),
                ),
              ],
              const SizedBox(height: 12),

              // Action button to verify repaired pieces from Lineman
              SizedBox(
                width: double.infinity,
                height: 40,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.verified_outlined, size: 16, color: Colors.white),
                  label: Text('Verify & Pass Repaired Pieces', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF047857),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
  // TAB 3: READY FOR CHALLAN / STORE HANDOVER
  // ====================================================
  Widget _buildReadyForChallanSection() {
    if (_readyForChallanLots.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x1A000000)),
        ),
        child: Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF7F0),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0x1A000000)),
                ),
                child: const Icon(Icons.local_shipping_outlined, size: 36, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 14),
              Text(
                'No Articles Ready for Challan Yet',
                style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
              ),
              const SizedBox(height: 4),
              Text(
                'When articles complete 100% QC checking and pass inspection, they appear here ready for delivery challan generation.',
                textAlign: TextAlign.center,
                style: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      );
    }

    final displayReady = _readyForChallanLots.where((lot) {
      if (_searchQuery.isEmpty) return true;
      final art = _asMap(lot['article']) ?? _asMap(lot['articles']);
      final artNo = (art?['art_no'] ?? lot['art_no'] ?? '').toString().toLowerCase();
      final desc = (art?['description'] ?? lot['description'] ?? '').toString().toLowerCase();
      final chal = _asMap(lot['challans']);
      final challanNo = (chal?['challan_no'] ?? lot['challan_no'] ?? '').toString().toLowerCase();
      final brand = (chal?['brand'] ?? lot['brand'] ?? '').toString().toLowerCase();
      final vendorName = (lot['vendor_name'] ?? chal?['vendor_name'] ?? '').toString().toLowerCase();

      return artNo.contains(_searchQuery) ||
          desc.contains(_searchQuery) ||
          challanNo.contains(_searchQuery) ||
          brand.contains(_searchQuery) ||
          vendorName.contains(_searchQuery);
    }).toList();

    return Column(
      children: [
        // Top Info Box
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFA7F3D0), width: 1),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF047857), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_readyForChallanLots.length} Article(s) Cleared QC & 100% Passed. Ready for dispatch.',
                  style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF047857)),
                ),
              ),
            ],
          ),
        ),

        if (displayReady.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.search_off_rounded, size: 32, color: Color(0xFF94A3B8)),
                  const SizedBox(height: 8),
                  Text(
                    'No ready articles match "$_searchQuery"',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                    child: Text('Clear search', style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF3A3564))),
                  ),
                ],
              ),
            ),
          )
        else
          // List of Ready Articles
          ...displayReady.map((lot) {
          final art = _asMap(lot['article']) ?? _asMap(lot['articles']);
          final artNo = art?['art_no']?.toString() ?? lot['art_no']?.toString() ?? 'Article';
          final desc = art?['description']?.toString() ?? lot['description']?.toString() ?? '';
          final chal = _asMap(lot['challans']);
          final challanNo = chal?['challan_no']?.toString() ?? lot['challan_no']?.toString() ?? '-';
          final brand = (chal?['brand'] ?? lot['brand'] ?? '').toString();
          final vendorName = (lot['vendor_name'] ?? chal?['vendor_name'] ?? '').toString().trim();
          final int passedQty = _parseQty(lot['qc_total_passed'], _parseQty(lot['mending_received_qty']));
          final vars = (lot['variants'] as List<dynamic>?) ?? [];

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFA7F3D0), width: 1.2),
              boxShadow: const [
                BoxShadow(color: Color(0x06000000), blurRadius: 2, offset: Offset(0, 1)),
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
                          Flexible(
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Text(
                                    'CH-$challanNo · $brand',
                                    style: GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF3A3564)),
                                  ),
                                ),
                                if (vendorName.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFAF5FF),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFE9D5FF)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.business_rounded, size: 12, color: Color(0xFF7E22CE)),
                                        const SizedBox(width: 4),
                                        Text(
                                          vendorName,
                                          style: GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF7E22CE)),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFA7F3D0)),
                            ),
                            child: Text(
                              'QC Passed: $passedQty pcs',
                              style: GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF047857)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Art #$artNo',
                        style: GoogleFonts.jetBrainsMono(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                      ),
                      if (desc.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(desc, style: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF64748B))),
                      ],
                    ],
                  ),
                ),

                if (vars.isNotEmpty) ...[
                  const Divider(height: 1, color: Color(0x14000000)),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: vars.map((v) {
                        final sz = v['size'] ?? '-';
                        final passQ = _parseQty(v['qc_passed_qty'], _parseQty(lot['qc_total_passed'], _parseQty(v['allotted_qty'], _parseQty(v['quantity']))));
                        final totalQ = _parseQty(v['allotted_qty'], _parseQty(v['quantity']));
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: Text(
                            '$sz: $passQ / $totalQ pcs',
                            style: GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF047857)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],

                const Divider(height: 1, color: Color(0x14000000)),

                // Actions
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      if ((lot['qc_status'] ?? '').toString() == 'PENDING_ADMIN_APPROVAL') ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFCF3),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.hourglass_top_rounded, color: Color(0xFFD97706), size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Submitted for Admin Approval. Store Manager will collect after authorization.',
                                  style: GoogleFonts.publicSans(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF92400E)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: double.infinity,
                          height: 42,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.pending_actions_rounded, size: 18, color: Color(0xFFD97706)),
                            label: Text(
                              'Submitted (Awaiting Admin Approval)',
                              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFD97706)),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFFDE68A), width: 1.2),
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
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Color(0xFF047857), size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Admin Approved! Store Manager has been notified to collect.',
                                  style: GoogleFonts.publicSans(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF047857)),
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
                              backgroundColor: const Color(0xFF047857),
                              foregroundColor: Colors.white,
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
                          icon: const Icon(Icons.local_shipping_rounded, size: 16, color: Color(0xFF3A3564)),
                          label: Text(
                            'Direct Delivery Challan (Dispatch)',
                            style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF3A3564)),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0x1A000000), width: 1),
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
            height: 44,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add_shopping_cart_rounded, size: 18, color: Color(0xFF3A3564)),
              label: Text(
                'Open General 8-Column Delivery Challan Sheet',
                style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF3A3564)),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF3A3564), width: 1.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => _showDeliveryChallanModal(),
            ),
          ),
        ),
      ],
    );
  }
}
