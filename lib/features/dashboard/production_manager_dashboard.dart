import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/connectivity_indicator.dart';
import '../../core/utils/parser_utils.dart';
import '../../core/services/tenant_resolver_service.dart';
import '../auth/providers/auth_provider.dart';
import '../auth/screens/login_screen.dart';
import '../admin/widgets/admin_drawer.dart';
import '../admin/challans/challans_dashboard_screen.dart';
import '../admin/challans/widgets/create_job_work_challan_sheet.dart';
import '../admin/challans/challan_models.dart';
import '../admin/providers/admin_providers.dart';
import 'qc_dashboard.dart';
import 'mending_dashboard.dart';
import '../../../main.dart';

class ProductionManagerDashboard extends ConsumerStatefulWidget {
  const ProductionManagerDashboard({super.key});

  @override
  ConsumerState<ProductionManagerDashboard> createState() => _ProductionManagerDashboardState();
}

class _ProductionManagerDashboardState extends ConsumerState<ProductionManagerDashboard> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isLoading = true;

  // Floor KPI Metrics (6 Lifecycle Stages Synced with Web)
  int _totalActiveLots = 0;
  int _totalStocks = 0;
  int _unallottedStocks = 0;
  int _goodsInLine = 0;
  int _mendingChecking = 0;
  int _readyGoods = 0;
  int _rtoRejection = 0;
  int _readyDelivery = 0;
  int _totalTargetPieces = 0;
  int _totalStitchedPieces = 0;
  int _totalQcPassedPieces = 0;
  int _totalMendingPieces = 0;
  double _floorEfficiency = 0.0;

  // Data collections
  List<Map<String, dynamic>> _allotments = [];
  List<Map<String, dynamic>> _linemenSummary = [];
  List<Map<String, dynamic>> _bottlenecks = [];

  // Lineman & Search Filters
  String? _selectedLinemanId;
  String? _selectedLinemanName;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Dynamic user and company identity
  String _companyName = '';
  String _userName = '';

  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchFloorData();
    // Auto-refresh floor data every 45 seconds
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (mounted) _fetchFloorData(isSilent: true);
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  String _getShiftName() {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 14) {
      return 'Morning Shift';
    } else if (hour >= 14 && hour < 22) {
      return 'Evening Shift';
    } else {
      return 'Night Shift';
    }
  }

  Future<void> _fetchFloorData({bool isSilent = false}) async {
    if (!isSilent) {
      setState(() => _isLoading = true);
    }

    try {
      final currentUser = supabase.auth.currentUser;
      ResolvedTenantProfile? tenant;
      String compName = '';
      String usrName = '';
      if (currentUser != null) {
        try {
          tenant = await TenantResolverService.resolveUserTenant(currentUser);
        } catch (_) {}

        if (tenant != null && tenant.companyName.trim().isNotEmpty) {
          compName = tenant.companyName.trim();
        }

        // Direct database query for accurate user profile and company
        try {
          final prof = await supabase
              .from('profiles')
              .select('username, company_name, designation')
              .eq('id', currentUser.id)
              .maybeSingle();
          if (prof != null) {
            final c = (prof['company_name'] ?? '').toString().trim();
            if (c.isNotEmpty) compName = c;
            final u = (prof['username'] ?? '').toString().trim();
            if (u.isNotEmpty) usrName = u;
          }
        } catch (_) {}

        if (compName.isEmpty) {
          compName = (currentUser.userMetadata?['company_name'] ?? currentUser.userMetadata?['company'] ?? '').toString().trim();
        }

        if (usrName.isEmpty && tenant != null) {
          if (tenant.adminDisplayName.trim().isNotEmpty && !tenant.adminDisplayName.contains('@')) {
            usrName = tenant.adminDisplayName.trim();
          } else if (tenant.customUsername.trim().isNotEmpty && !tenant.customUsername.contains('@')) {
            usrName = tenant.customUsername.trim();
          }
        }
        if (usrName.isEmpty) {
          usrName = (currentUser.userMetadata?['full_name'] ?? currentUser.userMetadata?['username'] ?? currentUser.email?.split('@').first ?? '').toString().trim();
        }
      }
      final isPlatformSuper = tenant?.isPlatformAdmin == true || tenant?.role == 'PLATFORM_SUPERADMIN';
      final isCustomPlant = tenant?.isCustomStitching == true || (compName.isNotEmpty && compName.toLowerCase().contains('nubira'));
      final isProvisionedTenant = tenant?.isProvisionedTenant == true;
      final targetComp = compName.isNotEmpty ? compName.toLowerCase() : null;

      // 1. Concurrently fetch all floor orders, challans, and allotments data safely without fragile PostgREST FK join syntax
      List<ChallanGroupedOrder> groupedChallans = [];
      List<dynamic> allotmentsRaw = [];
      List<dynamic> challansRaw = [];
      List<dynamic> articlesRaw = [];
      List<dynamic> profilesRaw = [];
      List<dynamic> materialsRaw = [];
      List<dynamic> variantsRes = [];
      List<dynamic> assignmentsRes = [];
      List<dynamic> qcLogsRes = [];
      List<dynamic> storeRaw = [];
      List<dynamic> dispatchRaw = [];

      await Future.wait([
        (() async {
          try {
            groupedChallans = await ref.read(challanGroupedOrdersProvider.future);
          } catch (e) {
            debugPrint('Floor: groupedChallans error: $e');
          }
        })(),
        (() async {
          try {
            allotmentsRaw = await supabase.from('allotments').select('*').order('created_at', ascending: false).limit(200);
          } catch (e) {
            debugPrint('Floor: allotments error: $e');
          }
        })(),
        (() async {
          try {
            challansRaw = await supabase.from('challans').select('*').order('created_at', ascending: false).limit(200);
          } catch (e) {
            debugPrint('Floor: challans error: $e');
          }
        })(),
        (() async {
          try {
            articlesRaw = await supabase.from('articles').select('id, art_no, description, size_rates, stitching_rate');
          } catch (e) {
            debugPrint('Floor: articles error: $e');
          }
        })(),
        (() async {
          try {
            profilesRaw = await supabase.from('profiles').select('id, username, role, company_name');
          } catch (e) {
            debugPrint('Floor: profiles error: $e');
          }
        })(),
        (() async {
          try {
            materialsRaw = await supabase.from('allotment_materials').select('allotment_id, notes, item_name, required_qty');
          } catch (e) {
            debugPrint('Floor: materials error: $e');
          }
        })(),
        (() async {
          try {
            variantsRes = await supabase.from('allotment_variants').select('id, allotment_id, color, size, quantity, completed_qty');
          } catch (e) {
            debugPrint('Floor: variants error: $e');
          }
        })(),
        (() async {
          try {
            assignmentsRes = await supabase.from('worker_assignments').select('id, allotment_id, worker_name, assigned_qty, completed_qty, status');
          } catch (e) {
            debugPrint('Floor: assignments error: $e');
          }
        })(),
        (() async {
          try {
            qcLogsRes = await supabase.from('qc_logs').select('id, allotment_id, article_id, qty_received, qty_passed, qty_rejected, defect_type, created_at').order('created_at', ascending: false).limit(100);
          } catch (e) {
            debugPrint('Floor: qcLogs error: $e');
          }
        })(),
        (() async {
          try {
            storeRaw = await supabase.from('store_transactions').select('id, type, quantity').limit(300);
          } catch (e) {
            debugPrint('Floor: store error: $e');
          }
        })(),
        (() async {
          try {
            dispatchRaw = await supabase.from('delivery_challans').select('id, total_pieces, status').limit(200);
          } catch (e) {
            debugPrint('Floor: dispatch error: $e');
          }
        })(),
      ]);

      final Map<String, dynamic> articlesMap = {
        for (var a in articlesRaw)
          if (a['id'] != null) a['id'].toString(): a,
      };
      final Map<String, dynamic> profilesMap = {
        for (var p in profilesRaw)
          if (p['id'] != null) p['id'].toString(): p,
      };
      final Map<String, dynamic> challansMap = {
        for (var c in challansRaw)
          if (c['id'] != null) c['id'].toString(): c,
      };

      // Filter challans and allotments by tenant account if provisioned
      if (isProvisionedTenant && !isCustomPlant && !isPlatformSuper && targetComp != null && targetComp.isNotEmpty) {
        allotmentsRaw = allotmentsRaw.where((al) {
          final chId = al['challan_id']?.toString() ?? '';
          final ch = challansMap[chId];
          final brand = (ch?['brand']?.toString() ?? al['brand']?.toString() ?? '').toLowerCase();
          final comp = (ch?['company_name']?.toString() ?? al['company_name']?.toString() ?? '').toLowerCase();
          final notes = (ch?['notes']?.toString() ?? '').toLowerCase();
          return brand == targetComp || brand.contains(targetComp) || comp == targetComp || comp.contains(targetComp) || notes.contains(targetComp);
        }).toList();
      }

      // Build priority map from allotment_materials
      Map<String, String> priorityMap = {};
      for (var row in materialsRaw) {
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

      // Link article, lineman, challan to allotmentsRaw
      for (var a in allotmentsRaw) {
        final chId = a['challan_id']?.toString() ?? '';
        a['challan'] = challansMap[chId] ?? {};

        final artId = a['article_id']?.toString() ?? '';
        a['article'] = articlesMap[artId] ?? {};

        final lmId = a['lineman_id']?.toString() ?? '';
        a['lineman'] = profilesMap[lmId] ?? {};
      }

      // Merge active in-production challan lines from canonical groupedChallans (Consolidated by Style + Color + Lineman)
      final Map<String, Map<String, dynamic>> consolidatedChallanLots = {};
      for (var ch in groupedChallans) {
        if (ch.status == 'IN_PROGRESS' || ch.status == 'PARTIALLY_ALLOTTED' || ch.status == 'QC_PASSED') {
          for (var line in ch.articles) {
            final artCode = line.fullArtCode.trim().toUpperCase();
            final color = line.colorPattern.trim().toUpperCase();
            final lmId = line.assignedLinemanId ?? '';
            final lmName = (line.assignedLinemanName != null &&
                    line.assignedLinemanName!.isNotEmpty &&
                    !line.assignedLinemanName!.toLowerCase().contains('unassigned'))
                ? line.assignedLinemanName!
                : 'Active Line';

            // Check if this article + color is already present in allotmentsRaw from database
            final bool alreadyInDb = allotmentsRaw.any((al) {
              final alChId = al['challan_id']?.toString() ?? '';
              final alArtNo = (al['article']?['art_no']?.toString() ?? '').trim().toUpperCase();
              return (al['id']?.toString() == line.allotmentId) ||
                  (alChId == ch.id && (alArtNo == artCode || alArtNo == line.artNo.toUpperCase()));
            });

            if (alreadyInDb) continue;

            final groupKey = '${ch.id}__${artCode}__${color}__$lmId';
            if (consolidatedChallanLots.containsKey(groupKey)) {
              final existing = consolidatedChallanLots[groupKey]!;
              existing['target_qty'] = (existing['target_qty'] as int) + line.totalPcs;
              existing['completed_qty'] = (existing['completed_qty'] as int) + line.completedQty;
              final existingSizes = existing['sizes'] as List<String>;
              final newSize = line.sizeRange.trim();
              if (newSize.isNotEmpty && !existingSizes.contains(newSize)) {
                existingSizes.add(newSize);
              }
            } else {
              final newSize = line.sizeRange.trim();
              consolidatedChallanLots[groupKey] = {
                'id': line.allotmentId ?? 'ch_${ch.id}_${line.id}',
                'challan_id': ch.id,
                'challan': {
                  'id': ch.id,
                  'challan_no': ch.challanNo,
                  'brand': ch.brand,
                  'fabric_type': ch.fabricType,
                  'company_name': tenant?.companyName,
                },
                'article': {
                  'id': line.id,
                  'art_no': line.fullArtCode,
                  'description': line.description,
                },
                'lineman': {
                  'id': lmId.isNotEmpty ? lmId : 'lm_$lmName',
                  'username': lmName,
                },
                'target_qty': line.totalPcs,
                'completed_qty': line.completedQty,
                'status': line.status,
                'priority': 'NORMAL',
                'created_at': ch.createdAt.toIso8601String(),
                'color_pattern': line.colorPattern,
                'sizes': newSize.isNotEmpty ? [newSize] : <String>[],
              };
            }
          }
        }
      }

      for (var lot in consolidatedChallanLots.values) {
        final sizes = (lot['sizes'] as List<String>);
        final sizeStr = sizes.isNotEmpty
            ? (sizes.length > 3 ? '${sizes.first}-${sizes.last}' : sizes.join('/'))
            : 'All Sizes';
        lot['size_range'] = sizeStr;
        allotmentsRaw.add(lot);
      }

      final List<dynamic> rawAllotments = allotmentsRaw;

      // --- Calculations & Mapping ---
      final List<Map<String, dynamic>> enrichedAllotments = [];
      final Map<String, Map<String, dynamic>> linemenMap = {};
      final List<Map<String, dynamic>> alertBottlenecks = [];

      int sumTarget = 0;
      int sumStitched = 0;
      int sumPassed = 0;
      int sumMending = 0;

      for (var a in rawAllotments) {
        final aId = a['id'];
        final aStatus = (a['status']?.toString() ?? 'PENDING').toUpperCase();
        final mendingStatus = (a['mending_status']?.toString() ?? '').toUpperCase();
        final qcStatus = (a['qc_status']?.toString() ?? '').toUpperCase();
        final storeStatus = (a['store_inward_status']?.toString() ?? '').toUpperCase();

        final colPriority = (a['priority'] ?? '').toString().toUpperCase();
        final lotPriority = (colPriority == 'CRITICAL' || colPriority == 'RUSH' || colPriority == 'NORMAL')
            ? colPriority
            : (priorityMap[aId?.toString() ?? ''] ?? 'NORMAL');

        // 1. Target pieces: prefer variants sum, fallback to allotments.target_qty
        final vars = variantsRes
            .where((v) => v['allotment_id']?.toString() == aId?.toString())
            .toList();
        int targetQty = 0;
        for (var v in vars) {
          targetQty += parseQty(v['quantity']);
        }
        if (targetQty == 0 && a['target_qty'] != null) {
          targetQty = parseQty(a['target_qty']);
        }

        // 2. Stitched pieces: from worker assignments OR mending counted OR completed status
        final assigns = assignmentsRes
            .where((w) => w['allotment_id']?.toString() == aId?.toString())
            .toList();
        int workerStitched = 0;
        for (var w in assigns) {
          final wStatus = (w['status']?.toString() ?? '').toUpperCase();
          if (wStatus == 'DONE' || wStatus == 'COMPLETED') {
            workerStitched += parseQty(w['completed_qty'], parseQty(w['assigned_qty']));
          } else {
            workerStitched += parseQty(w['completed_qty']);
          }
        }

        int mendingCounted = parseQty(a['mending_total_counted']);
        int stitchedQty = workerStitched > 0 ? workerStitched : mendingCounted;
        if (stitchedQty == 0 && (aStatus == 'COMPLETED' || mendingStatus.contains('MENDING') || mendingStatus == 'QC_PENDING' || a['handed_to_mending_at'] != null)) {
          stitchedQty = targetQty;
        }

        // 3. QC Inspection summary: from qc_logs OR allotments aggregate
        final lotQcLogs = qcLogsRes
            .where((q) => q['allotment_id']?.toString() == aId?.toString())
            .toList();
        int logPassed = 0;
        int logRejected = 0;
        for (var q in lotQcLogs) {
          logPassed += parseQty(q['qty_passed'], parseQty(q['passed_qty']));
          logRejected += parseQty(q['qty_rejected'], parseQty(q['rejected_qty']));
        }
        int passedQty = logPassed > 0 ? logPassed : parseQty(a['qc_total_passed']);
        int rejectedQty = logRejected > 0 ? logRejected : parseQty(a['qc_total_alter']);

        sumTarget += targetQty;
        sumStitched += stitchedQty;
        sumPassed += passedQty;
        sumMending += rejectedQty;

        // 4. Live stage classification based on actual floor progression
        String currentStage = 'SEWING_LINES';
        if (storeStatus == 'RECEIVED' || aStatus == 'DISPATCHED' || (passedQty >= targetQty && targetQty > 0)) {
          currentStage = 'READY_TO_DISPATCH';
        } else if (qcStatus == 'QC_PENDING' || qcStatus == 'IN_PROGRESS' || qcStatus == 'RECEIVED' || passedQty > 0 || rejectedQty > 0 || a['handed_to_qc_at'] != null) {
          currentStage = 'QC_INSPECTION';
        } else if (mendingStatus.contains('MENDING') || mendingStatus == 'QC_PENDING' || a['handed_to_mending_at'] != null || (stitchedQty >= targetQty && targetQty > 0)) {
          currentStage = 'MENDING_COUNTING';
        } else {
          currentStage = 'SEWING_LINES';
        }

        // Extract real colors and size range from allotment variants
        final Set<String> colorSet = {};
        final List<String> sizeList = [];
        for (var v in vars) {
          final c = v['color']?.toString().trim();
          if (c != null && c.isNotEmpty && c.toUpperCase() != 'STANDARD') {
            colorSet.add(c);
          }
          final s = v['size']?.toString().trim();
          if (s != null && s.isNotEmpty && !sizeList.contains(s)) {
            sizeList.add(s);
          }
        }
        final desc = a['article']?['description']?.toString().trim() ?? '';
        final colorStr = colorSet.isNotEmpty
            ? colorSet.join(', ')
            : (desc.isNotEmpty ? desc : 'All Sizes');
        final sizeStr = sizeList.isNotEmpty
            ? (sizeList.length > 3 ? '${sizeList.first}-${sizeList.last}' : sizeList.join('/'))
            : '';

        final enriched = {
          'id': aId,
          'priority': lotPriority,
          'challan_id': a['challan_id'],
          'challan': a['challan'] ?? {},
          'article': a['article'] ?? {},
          'lineman': a['lineman'] ?? {},
          'color': colorStr,
          'size_range': sizeStr,
          'status': aStatus,
          'stage': currentStage,
          'target_qty': targetQty,
          'stitched_qty': stitchedQty,
          'passed_qty': passedQty,
          'rejected_qty': rejectedQty,
          'variants': vars,
          'created_at': a['created_at'],
          'mending_status': mendingStatus,
          'mending_total_counted': mendingCounted,
          'handed_to_mending_by': a['handed_to_mending_by'],
          'handed_to_mending_at': a['handed_to_mending_at'],
          'qc_status': qcStatus,
          'qc_total_passed': passedQty,
          'qc_total_alter': rejectedQty,
          'handed_to_qc_by': a['handed_to_qc_by'],
          'handed_to_qc_at': a['handed_to_qc_at'],
          'store_inward_status': storeStatus,
        };

        // Consolidate duplicate floor lots with same (challan + article + color + lineman)
        final challanObj = parseMap(a['challan']);
        final chNum = (challanObj['challan_no'] ?? a['challan_id'] ?? '').toString().trim().toUpperCase();
        final artObj = parseMap(a['article']);
        final artNum = (artObj['art_no'] ?? '').toString().trim().toUpperCase();
        final colStr = colorStr.trim().toUpperCase();
        final lmObj = parseMap(a['lineman']);
        final lmIdStr = (lmObj['id'] ?? lmObj['username'] ?? '').toString().trim();
        final dedupKey = '${chNum}__${artNum}__${colStr}__$lmIdStr';

        final existingIdx = enrichedAllotments.indexWhere((e) {
          final eChallan = parseMap(e['challan']);
          final eChNum = (eChallan['challan_no'] ?? e['challan_id'] ?? '').toString().trim().toUpperCase();
          final eArt = parseMap(e['article']);
          final eArtNum = (eArt['art_no'] ?? '').toString().trim().toUpperCase();
          final eCol = (e['color']?.toString() ?? '').trim().toUpperCase();
          final eLm = parseMap(e['lineman']);
          final eLmId = (eLm['id'] ?? eLm['username'] ?? '').toString().trim();
          return '${eChNum}__${eArtNum}__${eCol}__$eLmId' == dedupKey;
        });

        if (existingIdx >= 0) {
          final ex = enrichedAllotments[existingIdx];
          ex['target_qty'] = parseQty(ex['target_qty']) + targetQty;
          ex['stitched_qty'] = parseQty(ex['stitched_qty']) + stitchedQty;
          ex['passed_qty'] = parseQty(ex['passed_qty']) + passedQty;
          ex['rejected_qty'] = parseQty(ex['rejected_qty']) + rejectedQty;

          // Merge size ranges if different
          final exSize = (ex['size_range']?.toString() ?? '').trim();
          if (sizeStr.isNotEmpty && sizeStr != exSize && !exSize.contains(sizeStr)) {
            ex['size_range'] = exSize.isNotEmpty ? '$exSize, $sizeStr' : sizeStr;
          }
          continue;
        }

        enrichedAllotments.add(enriched);

        // Group by Lineman
        final linemanObj = a['lineman'];
        final linemanId = linemanObj != null ? linemanObj['id']?.toString() : null;
        final linemanName = linemanObj != null ? (linemanObj['username']?.toString() ?? 'Unassigned Line') : 'Unassigned Line';
        final lmKey = (linemanId != null && linemanId.isNotEmpty) ? linemanId : (linemanName != 'Unassigned Line' ? linemanName : null);

        if (lmKey != null) {
          if (!linemenMap.containsKey(lmKey)) {
            linemenMap[lmKey] = {
              'id': lmKey,
              'name': linemanName,
              'active_lots': 0,
              'target_pcs': 0,
              'stitched_pcs': 0,
              'passed_pcs': 0,
              'mending_pcs': 0,
              'articles': <String>{},
            };
          }
          linemenMap[lmKey]!['active_lots'] = parseQty(linemenMap[lmKey]!['active_lots']) + 1;
          linemenMap[lmKey]!['target_pcs'] = parseQty(linemenMap[lmKey]!['target_pcs']) + targetQty;
          linemenMap[lmKey]!['stitched_pcs'] = parseQty(linemenMap[lmKey]!['stitched_pcs']) + stitchedQty;
          linemenMap[lmKey]!['passed_pcs'] = parseQty(linemenMap[lmKey]!['passed_pcs']) + passedQty;
          linemenMap[lmKey]!['mending_pcs'] = parseQty(linemenMap[lmKey]!['mending_pcs']) + rejectedQty;
          if (a['article'] != null && a['article']['art_no'] != null) {
            (linemenMap[lmKey]!['articles'] as Set<String>).add(a['article']['art_no'].toString());
          }
        }

        // Bottleneck Detection (High alteration rate)
        if (rejectedQty > 0 && (rejectedQty / (targetQty > 0 ? targetQty : 1)) > 0.05) {
          alertBottlenecks.add({
            'type': 'HIGH_DEFECT_RATE',
            'severity': 'HIGH',
            'title': 'High Alteration Rate in Art ${a['article']?['art_no'] ?? ''}',
            'detail': '$rejectedQty pcs defective on Line $linemanName',
            'allotment': enriched,
          });
        }
      }

      // Sort floor allotments by priority queue: CRITICAL (0) -> RUSH (1) -> NORMAL (2)
      int priorityWeight(String p) {
        if (p == 'CRITICAL') return 0;
        if (p == 'RUSH') return 1;
        return 2;
      }

      enrichedAllotments.sort((x, y) {
        final pX = priorityWeight((x['priority'] ?? 'NORMAL').toString());
        final pY = priorityWeight((y['priority'] ?? 'NORMAL').toString());
        if (pX != pY) return pX.compareTo(pY);
        final dtX = DateTime.tryParse(x['created_at']?.toString() ?? '') ?? DateTime(2000);
        final dtY = DateTime.tryParse(y['created_at']?.toString() ?? '') ?? DateTime(2000);
        return dtY.compareTo(dtX);
      });

      final efficiency = sumTarget > 0 ? ((sumStitched / sumTarget) * 100).clamp(0.0, 100.0) : 0.0;

      // Calculate 6 Factory Floor Lifecycle Stages (100% Synced with Web Factory Flow)
      int totalChallanPcs = 0;
      if (groupedChallans.isNotEmpty) {
        for (var ch in groupedChallans) {
          totalChallanPcs += ch.totalPcs;
        }
      } else {
        for (var c in challansRaw) {
          totalChallanPcs += parseQty(c['total_pcs']);
        }
      }

      int totalStoreInward = 0;
      int totalStoreRto = 0;
      for (var s in storeRaw) {
        final t = (s['type'] ?? '').toString().toUpperCase();
        final q = parseQty(s['quantity']);
        if (t == 'INWARD') totalStoreInward += q;
        if (t == 'RTO' || t == 'REJECT' || t == 'RETURN') totalStoreRto += q;
      }

      int totalDispatched = 0;
      for (var d in dispatchRaw) {
        totalDispatched += parseQty(d['total_pieces']);
      }

      int activeLinemanAllotmentPcs = 0;
      int mendingFloorPcs = 0;

      for (var a in rawAllotments) {
        final aStatus = (a['status']?.toString() ?? '').toUpperCase();
        final mStatus = (a['mending_status']?.toString() ?? '').toUpperCase();
        final qcStatus = (a['qc_status']?.toString() ?? '').toUpperCase();
        final tQty = parseQty(a['target_qty']);

        if (aStatus != 'CANCELLED') {
          if ((mStatus.isEmpty || mStatus == 'PENDING_STITCHING') && aStatus != 'COMPLETED') {
            activeLinemanAllotmentPcs += tQty;
          }
          if (mStatus == 'PENDING_MENDING' || mStatus == 'IN_MENDING' || (aStatus == 'COMPLETED' && (qcStatus.isEmpty || qcStatus == 'PENDING_STITCHING'))) {
            mendingFloorPcs += tQty;
          }
        }
      }

      if (activeLinemanAllotmentPcs == 0 && sumTarget > 0) {
        activeLinemanAllotmentPcs = sumTarget;
      }

      final totalStocks = totalChallanPcs > 0 ? totalChallanPcs : (activeLinemanAllotmentPcs > 0 ? activeLinemanAllotmentPcs : sumTarget);

      // Stage 1: Unallotted Stocks (Pending Pipeline)
      final unallottedStocks = (totalStocks - activeLinemanAllotmentPcs) > 0
          ? (totalStocks - activeLinemanAllotmentPcs)
          : 0;

      // Stage 2: Goods in Line (Sewing WIP)
      final goodsInLine = activeLinemanAllotmentPcs > 0
          ? ((activeLinemanAllotmentPcs - sumPassed - totalDispatched - sumMending) > 0
              ? (activeLinemanAllotmentPcs - sumPassed - totalDispatched - sumMending)
              : 0)
          : 0;

      // Stage 3: Mending & Checking
      final mendingChecking = mendingFloorPcs + sumMending + ((sumStitched - sumPassed - totalDispatched) > 0 ? (sumStitched - sumPassed - totalDispatched) : 0);

      // Stage 4: Ready Goods
      final readyGoods = ((sumPassed - totalDispatched) > 0 ? (sumPassed - totalDispatched) : 0) + totalStoreInward;

      // Stage 5: RTO & Rejection
      final rtoRejection = totalStoreRto;

      // Stage 6: Ready for Delivery
      final readyDelivery = totalDispatched;

      if (mounted) {
        setState(() {
          if (compName.isNotEmpty) _companyName = compName;
          if (usrName.isNotEmpty) _userName = usrName;
          _allotments = enrichedAllotments;
          _linemenSummary = linemenMap.values.toList();
          _bottlenecks = alertBottlenecks;
          _totalActiveLots = enrichedAllotments.where((a) => a['status'] != 'DISPATCHED' && a['store_inward_status'] != 'RECEIVED').length;
          _totalStocks = totalStocks;
          _unallottedStocks = unallottedStocks;
          _goodsInLine = goodsInLine;
          _mendingChecking = mendingChecking;
          _readyGoods = readyGoods;
          _rtoRejection = rtoRejection;
          _readyDelivery = readyDelivery;
          _totalTargetPieces = sumTarget;
          _totalStitchedPieces = sumStitched;
          _totalQcPassedPieces = sumPassed;
          _totalMendingPieces = sumMending;
          _floorEfficiency = efficiency;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Floor data fetch error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showCreateChallanModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const CreateJobWorkChallanSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final tenant = authState.tenantProfile;
    final currentUser = supabase.auth.currentUser;

    // Dynamically resolve company name without hardcoded fallbacks
    final String companyName = _companyName.isNotEmpty
        ? _companyName
        : ((tenant?.companyName != null && tenant!.companyName.trim().isNotEmpty)
            ? tenant.companyName.trim()
            : (currentUser?.userMetadata?['company_name'] ??
               currentUser?.userMetadata?['company'] ??
               '').toString().trim());

    // Dynamically resolve manager user name
    final String userName = _userName.isNotEmpty
        ? _userName
        : ((authState.cachedUsername != null && authState.cachedUsername!.trim().isNotEmpty && !authState.cachedUsername!.contains('@'))
            ? authState.cachedUsername!.trim()
            : (tenant?.adminDisplayName != null && tenant!.adminDisplayName.trim().isNotEmpty && !tenant.adminDisplayName.contains('@')
                ? tenant.adminDisplayName.trim()
                : (tenant?.customUsername != null && tenant!.customUsername.trim().isNotEmpty && !tenant.customUsername.contains('@')
                    ? tenant.customUsername.trim()
                    : (currentUser?.userMetadata?['full_name'] ??
                       currentUser?.userMetadata?['username'] ??
                       currentUser?.email?.split('@').first ??
                       'Production Manager'))));

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppTheme.bg,
      drawer: const AdminDrawer(activeRoute: '/stitching-sewing/production-manager'),
      appBar: _buildTopBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.steel))
          : RefreshIndicator(
              onRefresh: () => _fetchFloorData(),
              color: AppTheme.steel,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ConnectivityIndicator(),
                    const SizedBox(height: 8),

                    // 1. Breadcrumbs Row
                    _buildBreadcrumbs(companyName),
                    const SizedBox(height: 10),

                    // 2. Welcome Hero Card (Main Landing Screen)
                    _buildHeroCard(companyName, userName),
                    const SizedBox(height: 14),

                    // 3. Floor Header & Shift Info
                    _buildShiftBanner(),
                    const SizedBox(height: 14),

                    // Industrial KPI Metrics Grid
                    _buildKpiMetrics(),
                    const SizedBox(height: 18),

                    // Production Pipeline Stage Tracker
                    _buildPipelineStageTracker(),
                    const SizedBox(height: 18),

                    // Bottleneck & Critical Floor Alerts
                    if (_bottlenecks.isNotEmpty) ...[
                      _buildBottlenecksSection(),
                      const SizedBox(height: 18),
                    ],

                    // Line-by-Line Lineman Live Tracking
                    _buildLinemenFloorSection(),
                    const SizedBox(height: 18),

                    // Active Allotments & Lot Breakdown Table
                    _buildActiveAllotmentsSection(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  PreferredSizeWidget _buildTopBar() {
    return AppBar(
      toolbarHeight: 64,
      titleSpacing: 0,
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: const Border(
        bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
      ),
      leadingWidth: 56,
      leading: Center(
        child: InkWell(
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
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/zigza_web_logo.png',
            height: 24,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Image.asset(
              'assets/images/zigza_new_logo.png',
              height: 24,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
      actions: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDFA),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF14C8B4).withValues(alpha: 0.3)),
          ),
          child: Text(
            'PROD MES',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0B1220),
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Floor Refresh',
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.cardSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: const Icon(Icons.sync_rounded, size: 18, color: AppTheme.headingObsidian),
          ),
          onPressed: () => _fetchFloorData(),
        ),
        PopupMenuButton<String>(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.cardSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: const Icon(Icons.more_vert_rounded, size: 18, color: AppTheme.headingObsidian),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onSelected: (val) async {
            if (val == 'PROD_CHART') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChallansDashboardScreen()),
              );
            } else if (val == 'NEW_CHALLAN') {
              _showCreateChallanModal();
            } else if (val == 'QC_VIEW') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const QcDashboard()),
              );
            } else if (val == 'MENDING_VIEW') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MendingDashboard()),
              );
            } else if (val == 'LOGOUT') {
              final nav = Navigator.of(context);
              await ref.read(authProvider.notifier).logout();
              if (mounted) {
                nav.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            }
          },
          itemBuilder: (ctx) => [
            PopupMenuItem(
              value: 'PROD_CHART',
              child: Row(
                children: [
                  const Icon(Icons.layers_outlined, size: 18, color: AppTheme.brandRoyalBlue),
                  const SizedBox(width: 10),
                  Text('Production Chart (Challans)', style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.headingObsidian)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'NEW_CHALLAN',
              child: Row(
                children: [
                  const Icon(Icons.add_circle_outline_rounded, size: 18, color: AppTheme.badgeEmeraldText),
                  const SizedBox(width: 10),
                  Text('+ New Delivery Challan', style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.headingObsidian)),
                ],
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'QC_VIEW',
              child: Row(
                children: [
                  const Icon(Icons.verified_rounded, size: 18, color: AppTheme.brandRoyalBlue),
                  const SizedBox(width: 10),
                  Text('Open QC Floor', style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.headingObsidian)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'MENDING_VIEW',
              child: Row(
                children: [
                  const Icon(Icons.table_view_rounded, size: 18, color: AppTheme.badgeAmberText),
                  const SizedBox(width: 10),
                  Text('Open Mending Counting', style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.headingObsidian)),
                ],
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'LOGOUT',
              child: Row(
                children: [
                  const Icon(Icons.logout_rounded, size: 18, color: AppTheme.badgeRoseText),
                  const SizedBox(width: 10),
                  Text('Logout', style: GoogleFonts.publicSans(fontSize: 13, color: AppTheme.badgeRoseText, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildBreadcrumbs(String companyName) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Workspace Hub / Sewing Operations / Floor Overview',
            style: GoogleFonts.publicSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.faintInk,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (companyName.trim().isNotEmpty) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
            decoration: BoxDecoration(
              color: AppTheme.mintSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.badgeMintBorder),
            ),
            child: Text(
              companyName.trim(),
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppTheme.headingObsidian,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHeroCard(String companyName, String userName) {
    final String displayName = companyName.trim().isNotEmpty
        ? companyName.trim()
        : (userName.trim().isNotEmpty ? userName.trim() : 'Production Floor');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.mintSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.badgeMintBorder),
                ),
                child: const Icon(
                  Icons.precision_manufacturing_outlined,
                  color: Color(0xFF0F766E),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Welcome, $displayName',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.headingObsidian,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.mintSurface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.badgeMintBorder),
                          ),
                          child: Text(
                            userName.trim().isNotEmpty && userName.trim() != displayName
                                ? userName.trim()
                                : 'MES Floor',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.headingObsidian,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      userName.trim().isNotEmpty && companyName.trim().isNotEmpty && userName.trim() != companyName.trim()
                          ? 'Signed in as $userName · Live floor tracking & supervisor shifts.'
                          : 'Live factory floor overview, line tracking, bottleneck alerts & supervisor shifts.',
                      style: GoogleFonts.publicSans(
                        fontSize: 11.5,
                        color: AppTheme.bodyInk,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShiftBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.mintSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.badgeMintBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.schedule_rounded, size: 13, color: AppTheme.headingObsidian),
                const SizedBox(width: 6),
                Text(
                  _getShiftName().toUpperCase(),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.headingObsidian,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.bgCanvas,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppTheme.badgeEmeraldText,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  '$_totalActiveLots Active Floor Lots',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.headingObsidian,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiMetrics() {
    final fmt = NumberFormat('#,###');
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.10,
      children: [
        // STAGE 01: TOTAL STOCKS
        _buildMetricCard(
          stageTag: 'STAGE 01',
          title: '1. TOTAL STOCKS',
          value: fmt.format(_unallottedStocks),
          unit: '',
          subtitle: 'Pending Allotment Balance',
          icon: Icons.warehouse_rounded,
          badgeText: 'UNALLOTTED',
          badgeBg: AppTheme.mintSurface,
          badgeBorder: AppTheme.badgeMintBorder,
          badgeTextCol: AppTheme.headingObsidian,
          footerRightText: '${fmt.format(_totalStocks)} total',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ChallansDashboardScreen()),
            );
          },
        ),

        // STAGE 02: GOODS IN LINE
        _buildMetricCard(
          stageTag: 'STAGE 02',
          title: '2. GOODS IN LINE',
          value: fmt.format(_goodsInLine),
          unit: '',
          subtitle: 'Sewing Machines WIP',
          icon: Icons.show_chart_rounded,
          badgeText: 'ON FLOOR',
          badgeBg: AppTheme.mintSurface,
          badgeBorder: AppTheme.badgeMintBorder,
          badgeTextCol: AppTheme.headingObsidian,
        ),

        // STAGE 03: MENDING & CHECKING
        _buildMetricCard(
          stageTag: 'STAGE 03',
          title: '3. MENDING & CHECKING',
          value: fmt.format(_mendingChecking),
          unit: '',
          subtitle: 'QC Inspection & Repairs',
          icon: Icons.warning_amber_rounded,
          badgeText: 'FINISHING TABLE',
          badgeBg: AppTheme.mintSurface,
          badgeBorder: AppTheme.badgeMintBorder,
          badgeTextCol: AppTheme.headingObsidian,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MendingDashboard()),
            );
          },
        ),

        // STAGE 04: READY GOODS
        _buildMetricCard(
          stageTag: 'STAGE 04',
          title: '4. READY GOODS',
          value: fmt.format(_readyGoods),
          unit: '',
          subtitle: 'QC Passed & Packed',
          icon: Icons.inventory_2_rounded,
          badgeText: 'IN GODOWN',
          badgeBg: AppTheme.mintSurface,
          badgeBorder: AppTheme.badgeMintBorder,
          badgeTextCol: AppTheme.headingObsidian,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const QcDashboard()),
            );
          },
        ),

        // STAGE 05: RTO & REJECTION
        _buildMetricCard(
          stageTag: 'STAGE 05',
          title: '5. RTO & REJECTION',
          value: fmt.format(_rtoRejection),
          unit: '',
          subtitle: 'Return to Origin',
          icon: Icons.replay_rounded,
          badgeText: 'DEFECT / REJECT',
          badgeBg: AppTheme.mintSurface,
          badgeBorder: AppTheme.badgeMintBorder,
          badgeTextCol: AppTheme.headingObsidian,
        ),

        // STAGE 06: READY FOR DELIVERY
        _buildMetricCard(
          stageTag: 'STAGE 06',
          title: '6. READY FOR DELIVERY',
          value: fmt.format(_readyDelivery),
          unit: '',
          subtitle: 'Gate Pass & Dispatched',
          icon: Icons.local_shipping_rounded,
          badgeText: 'DISPATCHED PCS',
          badgeBg: AppTheme.mintSurface,
          badgeBorder: AppTheme.badgeMintBorder,
          badgeTextCol: AppTheme.headingObsidian,
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String stageTag,
    required String title,
    required String value,
    required String unit,
    required String subtitle,
    required IconData icon,
    required String badgeText,
    required Color badgeBg,
    required Color badgeBorder,
    required Color badgeTextCol,
    String? footerRightText,
    VoidCallback? onTap,
  }) {
    final cardContent = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppTheme.mintSurface,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: AppTheme.badgeMintBorder),
                ),
                child: Icon(icon, size: 16, color: AppTheme.headingObsidian),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    stageTag,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.faintInk,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.north_east_rounded, size: 11, color: AppTheme.faintInk),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.headingObsidian,
                  letterSpacing: 0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                style: GoogleFonts.publicSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.faintInk,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.headingObsidian,
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: GoogleFonts.publicSans(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.faintInk,
                  ),
                ),
              ],
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: badgeBorder),
                ),
                child: Text(
                  badgeText,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: badgeTextCol,
                    letterSpacing: 0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (footerRightText != null && footerRightText.isNotEmpty)
                Text(
                  footerRightText,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.faintInk,
                  ),
                ),
            ],
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: cardContent,
      );
    }
    return cardContent;
  }

  Widget _buildPipelineStageTracker() {
    int sewingCount = _allotments.where((a) => a['stage'] == 'SEWING_LINES').length;
    int mendingCount = _allotments.where((a) => a['stage'] == 'MENDING_COUNTING').length;
    int qcCount = _allotments.where((a) => a['stage'] == 'QC_INSPECTION').length;
    int readyCount = _allotments.where((a) => a['stage'] == 'READY_TO_DISPATCH').length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
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
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppTheme.mintSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.badgeMintBorder),
                    ),
                    child: const Icon(Icons.trending_up_rounded, size: 16, color: AppTheme.headingObsidian),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LIVE FLOOR PIPELINE',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.headingObsidian,
                          letterSpacing: 0.3,
                        ),
                      ),
                      Text(
                        'Real-time Conversion Flow',
                        style: GoogleFonts.publicSans(
                          fontSize: 10,
                          color: AppTheme.bodyInk,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.bgCanvas,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.borderLight),
                ),
                child: Text(
                  '${_allotments.length} Total Lots',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.headingObsidian,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildPipelineNode('STAGE 1', 'Sewing', '$sewingCount Lots', AppTheme.brandRoyalBlue),
              _buildPipelineConnector(),
              _buildPipelineNode('STAGE 2', 'Counting', '$mendingCount Lots', AppTheme.badgeAmberText),
              _buildPipelineConnector(),
              _buildPipelineNode('STAGE 3', 'QC Floor', '$qcCount Lots', AppTheme.headingObsidian),
              _buildPipelineConnector(),
              _buildPipelineNode('STAGE 4', 'Dispatch', '$readyCount Lots', AppTheme.badgeEmeraldText),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPipelineNode(String stage, String title, String count, Color accent) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 5),
        decoration: BoxDecoration(
          color: AppTheme.bgCanvas,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.borderLight),
        ),
        child: Column(
          children: [
            Text(
              stage,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
                color: accent,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppTheme.headingObsidian,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              count,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: accent,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPipelineConnector() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 2),
      child: Icon(Icons.chevron_right_rounded, size: 14, color: AppTheme.faintInk),
    );
  }

  Widget _buildBottlenecksSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.badgeRoseBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.badgeRoseBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, size: 16, color: AppTheme.badgeRoseText),
              const SizedBox(width: 8),
              Text(
                'BOTTLENECK ALERTS',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.badgeRoseText,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._bottlenecks.map((b) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: AppTheme.badgeRoseText,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${b['title']} • ${b['detail']}',
                      style: GoogleFonts.publicSans(
                        fontSize: 11.5,
                        color: AppTheme.headingObsidian,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildLinemenFloorSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LINEMEN & LINE PERFORMANCE',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.headingObsidian,
                    letterSpacing: 0.3,
                  ),
                ),
                Text(
                  'Tap any line for complete history & floor filter',
                  style: GoogleFonts.publicSans(
                    fontSize: 10.5,
                    color: AppTheme.bodyInk,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.cardSurface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: Text(
                '${_linemenSummary.length} Active Lines',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.headingObsidian,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_linemenSummary.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.cardSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: Column(
              children: [
                const Icon(Icons.people_outline_rounded, size: 28, color: AppTheme.faintInk),
                const SizedBox(height: 8),
                Text(
                  'No active lines assigned at the moment.',
                  style: GoogleFonts.publicSans(fontSize: 12, color: AppTheme.bodyInk, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _linemenSummary.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final line = _linemenSummary[i];
              final lmId = line['id']?.toString();
              final isSelected = _selectedLinemanId == lmId;
              final target = parseQty(line['target_pcs']);
              final stitched = parseQty(line['stitched_pcs']);
              final mending = parseQty(line['mending_pcs']);
              final double progress = target > 0 ? (stitched / target).clamp(0.0, 1.0) : 0.0;
              final articles = ((line['articles'] as Set?)?.map((e) => e.toString()) ?? []).join(', ');

              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _showLinemanHistoryModal(line),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.mintSurface : AppTheme.cardSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? AppTheme.headingObsidian : AppTheme.borderLight,
                      width: isSelected ? 1.5 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isSelected ? AppTheme.headingObsidian : AppTheme.mintSurface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: isSelected ? AppTheme.headingObsidian : AppTheme.badgeMintBorder),
                            ),
                            child: Icon(
                              Icons.person_rounded,
                              size: 18,
                              color: isSelected ? Colors.white : AppTheme.headingObsidian,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        line['name'].toString().toUpperCase(),
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.headingObsidian,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                    if (isSelected) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppTheme.headingObsidian,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'FILTER ACTIVE',
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 8.5,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (articles.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Art: $articles',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 10.5,
                                      color: AppTheme.bodyInk,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '$stitched / $target pcs',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.headingObsidian,
                                ),
                              ),
                              if (mending > 0) ...[
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: AppTheme.badgeAmberBg,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: AppTheme.badgeAmberBorder),
                                  ),
                                  child: Text(
                                    '$mending pcs alter',
                                    style: GoogleFonts.publicSans(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.badgeAmberText,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: AppTheme.bgCanvas,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            progress >= 1.0 ? AppTheme.badgeEmeraldText : AppTheme.brandRoyalBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildActiveAllotmentsSection() {
    final filteredLots = _allotments.where((a) {
      if (_selectedLinemanId != null && a['lineman']?['id']?.toString() != _selectedLinemanId) {
        return false;
      }
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final artNo = (a['article']?['art_no']?.toString() ?? '').toLowerCase();
        final desc = (a['article']?['description']?.toString() ?? '').toLowerCase();
        final chNo = (a['challan']?['challan_no']?.toString() ?? a['challan_id']?.toString() ?? '').toLowerCase();
        final lmName = (a['lineman']?['username']?.toString() ?? '').toLowerCase();
        final color = (a['color']?.toString() ?? '').toLowerCase();
        final size = (a['size_range']?.toString() ?? '').toLowerCase();
        final stage = (a['stage']?.toString() ?? '').toLowerCase();
        final brand = (a['challan']?['brand']?.toString() ?? '').toLowerCase();

        final matches = artNo.contains(q) ||
            desc.contains(q) ||
            chNo.contains(q) ||
            lmName.contains(q) ||
            color.contains(q) ||
            size.contains(q) ||
            stage.contains(q) ||
            brand.contains(q);
        if (!matches) return false;
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ACTIVE FLOOR ALLOTMENTS',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: AppTheme.headingObsidian,
                letterSpacing: 0.3,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.cardSurface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: Text(
                (_selectedLinemanId != null || _searchQuery.isNotEmpty)
                    ? '${filteredLots.length} of ${_allotments.length} Lots'
                    : '${_allotments.length} Total Lots',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.headingObsidian,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Live Allotments Search Bar
        Container(
          decoration: BoxDecoration(
            color: AppTheme.cardSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderLight),
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
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
              });
            },
            style: GoogleFonts.publicSans(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.headingObsidian,
            ),
            decoration: InputDecoration(
              hintText: 'Search by Art No, Challan, Lineman, Pattern...',
              hintStyle: GoogleFonts.publicSans(
                fontSize: 12,
                color: AppTheme.faintInk,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppTheme.faintInk),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16, color: AppTheme.bodyInk),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Lineman Quick Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildFilterChip(
                label: 'All Lines',
                count: _allotments.length,
                isSelected: _selectedLinemanId == null,
                onTap: () {
                  setState(() {
                    _selectedLinemanId = null;
                    _selectedLinemanName = null;
                  });
                },
              ),
              const SizedBox(width: 8),
              ..._linemenSummary.map((line) {
                final lmId = line['id']?.toString();
                final isSel = _selectedLinemanId == lmId;
                final activeLots = parseQty(line['active_lots']);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildFilterChip(
                    label: line['name']?.toString().toUpperCase() ?? 'LINE',
                    count: activeLots,
                    isSelected: isSel,
                    onTap: () {
                      setState(() {
                        if (isSel) {
                          _selectedLinemanId = null;
                          _selectedLinemanName = null;
                        } else {
                          _selectedLinemanId = lmId;
                          _selectedLinemanName = line['name']?.toString();
                        }
                      });
                    },
                  ),
                );
              }),
            ],
          ),
        ),
        if (_selectedLinemanId != null || _searchQuery.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.mintSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.badgeMintBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.filter_alt_rounded, size: 16, color: AppTheme.brandRoyalBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedLinemanId != null && _searchQuery.isNotEmpty
                        ? 'Filter: ${_selectedLinemanName?.toUpperCase() ?? "Line"} • "$_searchQuery" (${filteredLots.length} lots)'
                        : _selectedLinemanId != null
                            ? 'Filtered by: ${_selectedLinemanName?.toUpperCase() ?? "Lineman"} (${filteredLots.length} lots)'
                            : 'Search: "$_searchQuery" (${filteredLots.length} lots)',
                    style: GoogleFonts.publicSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.headingObsidian,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                InkWell(
                  onTap: () {
                    _searchController.clear();
                    setState(() {
                      _selectedLinemanId = null;
                      _selectedLinemanName = null;
                      _searchQuery = '';
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.cardSurface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.borderLight),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.close, size: 12, color: AppTheme.bodyInk),
                        const SizedBox(width: 4),
                        Text(
                          'Clear',
                          style: GoogleFonts.publicSans(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.headingObsidian,
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
        const SizedBox(height: 10),
        if (filteredLots.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.cardSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: Column(
              children: [
                const Icon(Icons.assignment_late_outlined, size: 36, color: AppTheme.faintInk),
                const SizedBox(height: 8),
                Text(
                  'No allotments found',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.headingObsidian,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _selectedLinemanName != null && _searchQuery.isNotEmpty
                      ? 'No active lots match "$_searchQuery" for $_selectedLinemanName.'
                      : _searchQuery.isNotEmpty
                          ? 'No active lots match "$_searchQuery".'
                          : _selectedLinemanName != null
                              ? 'No active lots assigned to $_selectedLinemanName.'
                              : 'Floor allotments list is empty.',
                  style: GoogleFonts.publicSans(fontSize: 11, color: AppTheme.bodyInk),
                  textAlign: TextAlign.center,
                ),
                if (_selectedLinemanId != null || _searchQuery.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _selectedLinemanId = null;
                        _selectedLinemanName = null;
                        _searchQuery = '';
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.headingObsidian,
                      side: const BorderSide(color: AppTheme.borderLight),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(
                      'Clear Filter',
                      style: GoogleFonts.publicSans(fontSize: 12, color: AppTheme.headingObsidian, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredLots.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final lot = filteredLots[i];
              final article = parseMap(lot['article']);
              final artNo = article['art_no'] ?? 'N/A';
              final color = (lot['color']?.toString().trim().isNotEmpty == true) ? lot['color'].toString().trim() : (article['description']?.toString() ?? 'All Sizes');
              final sizeRange = lot['size_range']?.toString().trim() ?? '';
              final challan = parseMap(lot['challan']);
              final challanNo = challan['challan_no']?.toString();
              final target = parseQty(lot['target_qty']);
              final stitched = parseQty(lot['stitched_qty']);
              final passed = parseQty(lot['passed_qty']);
              final stage = lot['stage']?.toString() ?? 'SEWING_LINES';

              Color stageBg = AppTheme.badgeBlueBg;
              Color stageBorder = AppTheme.badgeBlueBorder;
              Color stageText = AppTheme.badgeBlueText;
              String stageLabel = '1. Sewing';

              if (stage == 'READY_TO_DISPATCH') {
                stageBg = AppTheme.badgeEmeraldBg;
                stageBorder = AppTheme.badgeEmeraldBorder;
                stageText = AppTheme.badgeEmeraldText;
                stageLabel = '4. Ready Gate';
              } else if (stage == 'QC_INSPECTION') {
                stageBg = AppTheme.mintSurface;
                stageBorder = AppTheme.badgeMintBorder;
                stageText = AppTheme.headingObsidian;
                stageLabel = '3. QC Floor';
              } else if (stage == 'MENDING_COUNTING') {
                stageBg = AppTheme.badgeAmberBg;
                stageBorder = AppTheme.badgeAmberBorder;
                stageText = AppTheme.badgeAmberText;
                stageLabel = '2. Counting';
              }

              final priority = (lot['priority'] ?? 'NORMAL').toString().toUpperCase();
              final isCritical = priority == 'CRITICAL';
              final isRush = priority == 'RUSH';

              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _showChallanBreakdownModal(lot),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isCritical
                        ? AppTheme.badgeRoseBg.withValues(alpha: 0.5)
                        : (isRush ? AppTheme.badgeAmberBg.withValues(alpha: 0.35) : AppTheme.cardSurface),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isCritical ? AppTheme.badgeRoseBorder : (isRush ? AppTheme.badgeAmberBorder : AppTheme.borderLight),
                      width: isCritical || isRush ? 1.5 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isCritical
                              ? AppTheme.badgeRoseBg
                              : (isRush ? AppTheme.badgeAmberBg : AppTheme.mintSurface),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isCritical
                                ? AppTheme.badgeRoseBorder
                                : (isRush ? AppTheme.badgeAmberBorder : AppTheme.badgeMintBorder),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'ART',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                color: isCritical
                                    ? AppTheme.badgeRoseText
                                    : (isRush ? AppTheme.badgeAmberText : AppTheme.faintInk),
                              ),
                            ),
                            Text(
                              '$artNo',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: isCritical
                                    ? AppTheme.badgeRoseText
                                    : (isRush ? AppTheme.badgeAmberText : AppTheme.headingObsidian),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    color,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.headingObsidian,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                                if (isCritical) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: AppTheme.badgeRoseBg,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: AppTheme.badgeRoseBorder),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.local_fire_department_rounded, size: 10, color: AppTheme.badgeRoseText),
                                        const SizedBox(width: 2),
                                        Text(
                                          'CRITICAL',
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 8.5,
                                            fontWeight: FontWeight.w900,
                                            color: AppTheme.badgeRoseText,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ] else if (isRush) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: AppTheme.badgeAmberBg,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: AppTheme.badgeAmberBorder),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.bolt_rounded, size: 10, color: AppTheme.badgeAmberText),
                                        const SizedBox(width: 2),
                                        Text(
                                          'RUSH',
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 8.5,
                                            fontWeight: FontWeight.w900,
                                            color: AppTheme.badgeAmberText,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                if (sizeRange.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: AppTheme.bgCanvas,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: AppTheme.borderLight),
                                    ),
                                    child: Text(
                                      sizeRange,
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 9.5,
                                        color: AppTheme.headingObsidian,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                                if (challanNo != null && challanNo.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: AppTheme.badgeBlueBg,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: AppTheme.badgeBlueBorder),
                                    ),
                                    child: Text(
                                      'DC #$challanNo',
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 9.5,
                                        color: AppTheme.brandRoyalBlue,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Lineman: ${lot['lineman']?['username'] ?? 'Unassigned'} • Stitched: $stitched / $target pcs (Passed: $passed)',
                              style: GoogleFonts.publicSans(fontSize: 11, color: AppTheme.bodyInk, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  lot['handed_to_mending_at'] != null ? Icons.check_circle_rounded : Icons.schedule_rounded,
                                  size: 13,
                                  color: lot['handed_to_mending_at'] != null ? AppTheme.badgeEmeraldText : AppTheme.brandRoyalBlue,
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    lot['handed_to_mending_at'] != null
                                        ? 'Handed to Mending: ${lot['handed_to_mending_by'] ?? 'Done'}${parseQty(lot['mending_total_counted']) > 0 ? " • Counted: ${lot['mending_total_counted']} pcs" : ""}'
                                        : 'On Stitching Line',
                                    style: GoogleFonts.publicSans(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: lot['handed_to_mending_at'] != null ? AppTheme.badgeEmeraldText : AppTheme.bodyInk,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: stageBg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: stageBorder),
                        ),
                        child: Text(
                          stageLabel,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: stageText,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  // Exact Challan Article Reference Sheet Modal
  void _showChallanBreakdownModal(Map<String, dynamic> lot) {
    final article = parseMap(lot['article']);
    final variants = parseList(lot['variants']);
    final artNo = article['art_no'] ?? 'N/A';
    final color = (lot['color']?.toString().trim().isNotEmpty == true) ? lot['color'].toString().trim() : (article['description']?.toString() ?? 'All Sizes');
    final sizeRange = lot['size_range']?.toString().trim() ?? '';
    final challan = parseMap(lot['challan']);
    final challanNo = challan['challan_no']?.toString();
    final target = parseQty(lot['target_qty']);
    final stitched = parseQty(lot['stitched_qty']);
    final passed = parseQty(lot['passed_qty']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: AppTheme.cardSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(color: AppTheme.borderLight, borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CHALLAN ARTICLE SHEET',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.headingObsidian,
                            letterSpacing: 0.3,
                          ),
                        ),
                        Text(
                          'Art: $artNo • $color${sizeRange.isNotEmpty ? " ($sizeRange)" : ""}${challanNo != null && challanNo.isNotEmpty ? " • DC #$challanNo" : ""}',
                          style: GoogleFonts.publicSans(fontSize: 11, color: AppTheme.bodyInk, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: AppTheme.bodyInk),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppTheme.borderLight),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    // Top Urgency Alert if CRITICAL or RUSH
                    if ((lot['priority'] ?? 'NORMAL').toString().toUpperCase() == 'CRITICAL' ||
                        (lot['priority'] ?? 'NORMAL').toString().toUpperCase() == 'RUSH') ...[
                      Builder(
                        builder: (_) {
                          final p = (lot['priority'] ?? 'NORMAL').toString().toUpperCase();
                          final isCrit = p == 'CRITICAL';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isCrit ? AppTheme.badgeRoseBg : AppTheme.badgeAmberBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: isCrit ? AppTheme.badgeRoseBorder : AppTheme.badgeAmberBorder, width: 1.2),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: isCrit ? AppTheme.badgeRoseBorder : AppTheme.badgeAmberBorder),
                                  ),
                                  child: Icon(
                                    isCrit ? Icons.local_fire_department_rounded : Icons.bolt_rounded,
                                    size: 16,
                                    color: isCrit ? AppTheme.badgeRoseText : AppTheme.badgeAmberText,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isCrit
                                            ? 'CRITICAL / EXPORT PRIORITY • सबसे पहले पूरा करो'
                                            : 'RUSH ORDER PRIORITY • उच्च प्राथमिकता',
                                        style: GoogleFonts.publicSans(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                          color: isCrit ? AppTheme.badgeRoseText : AppTheme.badgeAmberText,
                                        ),
                                      ),
                                      Text(
                                        isCrit
                                            ? 'Admin marked this lot as Highest Priority. Fast-track line, mending & QC.'
                                            : 'Rush production allotment. Prioritize for immediate completion.',
                                        style: GoogleFonts.publicSans(
                                          fontSize: 10,
                                          color: isCrit ? AppTheme.badgeRoseText.withValues(alpha: 0.8) : AppTheme.badgeAmberText.withValues(alpha: 0.8),
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

                    // Summary cards
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.bgCanvas,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.borderLight),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('TARGET PCS', style: GoogleFonts.publicSans(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppTheme.faintInk)),
                                Text('$target', style: GoogleFonts.jetBrainsMono(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.headingObsidian)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.bgCanvas,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.borderLight),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('STITCHED PCS', style: GoogleFonts.publicSans(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppTheme.faintInk)),
                                Text('$stitched', style: GoogleFonts.jetBrainsMono(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.brandRoyalBlue)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.bgCanvas,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.borderLight),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('QC PASSED', style: GoogleFonts.publicSans(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppTheme.faintInk)),
                                Text('$passed', style: GoogleFonts.jetBrainsMono(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.badgeEmeraldText)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    Text(
                      'COLOUR × SIZE BREAKDOWN',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.headingObsidian, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.cardSurface,
                        border: Border.all(color: AppTheme.borderLight),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Table(
                        border: TableBorder.symmetric(inside: const BorderSide(color: AppTheme.borderLight)),
                        children: [
                          TableRow(
                            decoration: const BoxDecoration(color: AppTheme.bgCanvas),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text('COLOUR', style: GoogleFonts.publicSans(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.bodyInk)),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text('SIZE', style: GoogleFonts.publicSans(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.bodyInk), textAlign: TextAlign.center),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text('TARGET PCS', style: GoogleFonts.publicSans(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.bodyInk), textAlign: TextAlign.right),
                              ),
                            ],
                          ),
                          if (variants.isEmpty)
                            TableRow(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text(color.isNotEmpty ? color : 'All Colors', style: GoogleFonts.publicSans(fontSize: 11.5, color: AppTheme.headingObsidian)),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text(sizeRange.isNotEmpty ? sizeRange : 'All Sizes', style: GoogleFonts.jetBrainsMono(fontSize: 11.5, color: AppTheme.headingObsidian), textAlign: TextAlign.center),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text('$target', style: GoogleFonts.jetBrainsMono(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.headingObsidian), textAlign: TextAlign.right),
                                ),
                              ],
                            )
                          else
                            ...variants.map((v) {
                              return TableRow(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Text('${v['color'] ?? 'Standard'}', style: GoogleFonts.publicSans(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.headingObsidian)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Text('${v['size'] ?? 'STD'}', style: GoogleFonts.jetBrainsMono(fontSize: 11.5, color: AppTheme.headingObsidian), textAlign: TextAlign.center),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Text('${v['quantity'] ?? 0}', style: GoogleFonts.jetBrainsMono(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.headingObsidian), textAlign: TextAlign.right),
                                  ),
                                ],
                              );
                            }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'FLOOR HANDOVER & CUSTODY',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.headingObsidian,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.cardSurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.borderLight),
                      ),
                      child: Column(
                        children: [
                          _buildHandoverRow(
                            step: '1',
                            title: 'Sewing Floor (Lineman)',
                            detail: 'Assigned to: ${lot['lineman']?['username'] ?? 'Unassigned'}',
                            badge: '$target pcs Allotted',
                            isDone: true,
                            badgeColor: AppTheme.brandRoyalBlue,
                          ),
                          const Divider(height: 16, color: AppTheme.borderLight),
                          _buildHandoverRow(
                            step: '2',
                            title: 'Mending / Counting Handover',
                            detail: lot['handed_to_mending_at'] != null
                                ? 'Handed by: ${lot['handed_to_mending_by'] ?? 'Lineman'}'
                                : 'In Stitching (Pending Handover)',
                            badge: parseQty(lot['mending_total_counted']) > 0
                                ? '${lot['mending_total_counted']} pcs Counted'
                                : (lot['handed_to_mending_at'] != null ? 'Handed Over' : 'Pending'),
                            isDone: lot['handed_to_mending_at'] != null || parseQty(lot['mending_total_counted']) > 0,
                            badgeColor: AppTheme.badgeAmberText,
                          ),
                          const Divider(height: 16, color: AppTheme.borderLight),
                          _buildHandoverRow(
                            step: '3',
                            title: 'QC Inspection Handover',
                            detail: lot['handed_to_qc_at'] != null
                                ? 'Supervisor: ${lot['qc_supervisor_name'] ?? lot['handed_to_qc_by'] ?? 'QC'}'
                                : 'Pending Counting Verification',
                            badge: passed > 0
                                ? '$passed Passed / ${lot['rejected_qty'] ?? 0} Alter'
                                : (lot['handed_to_qc_at'] != null ? 'In QC' : 'Pending'),
                            isDone: lot['handed_to_qc_at'] != null || passed > 0,
                            badgeColor: AppTheme.badgeEmeraldText,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHandoverRow({
    required String step,
    required String title,
    required String detail,
    required String badge,
    required bool isDone,
    required Color badgeColor,
  }) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDone ? badgeColor.withValues(alpha: 0.15) : AppTheme.bgCanvas,
            border: Border.all(color: isDone ? badgeColor : AppTheme.faintInk, width: 1.5),
          ),
          alignment: Alignment.center,
          child: Text(
            step,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: isDone ? badgeColor : AppTheme.faintInk,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.headingObsidian,
                ),
              ),
              Text(
                detail,
                style: GoogleFonts.publicSans(
                  fontSize: 10.5,
                  color: AppTheme.bodyInk,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: (isDone ? badgeColor : AppTheme.faintInk).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            badge,
            style: GoogleFonts.publicSans(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: isDone ? badgeColor : AppTheme.faintInk,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.headingObsidian : AppTheme.cardSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.headingObsidian : AppTheme.borderLight,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isSelected ? 0.08 : 0.02),
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
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                color: isSelected ? Colors.white : AppTheme.headingObsidian,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withValues(alpha: 0.2) : AppTheme.mintSurface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected ? Colors.transparent : AppTheme.badgeMintBorder,
                ),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : AppTheme.headingObsidian,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Lineman Performance & Lifetime Article History Modal
  void _showLinemanHistoryModal(Map<String, dynamic> line) {
    final lmId = line['id']?.toString();
    final lmName = line['name']?.toString().toUpperCase() ?? 'LINEMAN';
    final target = parseQty(line['target_pcs']);
    final stitched = parseQty(line['stitched_pcs']);
    final passed = parseQty(line['passed_pcs']);
    final mending = parseQty(line['mending_pcs']);
    final activeLotsCount = parseQty(line['active_lots']);
    final double passRate = stitched > 0 ? ((passed / stitched) * 100).clamp(0.0, 100.0) : 100.0;
    final double efficiency = target > 0 ? ((stitched / target) * 100).clamp(0.0, 100.0) : 0.0;

    // Filter allotments for this lineman
    final linemanLots = _allotments.where((a) => a['lineman']?['id']?.toString() == lmId).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isCurrentlySelected = _selectedLinemanId == lmId;

        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: AppTheme.cardSurface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(color: AppTheme.borderLight, borderRadius: BorderRadius.circular(2)),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: AppTheme.mintSurface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppTheme.badgeMintBorder),
                              ),
                              child: const Icon(Icons.person_rounded, size: 20, color: AppTheme.headingObsidian),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lmName,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.headingObsidian,
                                  ),
                                ),
                                Text(
                                  'SEWING FLOOR LINE OPERATOR',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.brandRoyalBlue,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20, color: AppTheme.bodyInk),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AppTheme.borderLight),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(18),
                      children: [
                        // KPI Performance Cards
                        Text(
                          'FLOOR PERFORMANCE & STATS',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.headingObsidian,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _buildMetricTile(
                                label: 'ACTIVE LOTS',
                                value: '$activeLotsCount',
                                subtext: 'Floor batches',
                                color: AppTheme.headingObsidian,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildMetricTile(
                                label: 'TARGET PCS',
                                value: '$target',
                                subtext: 'Total assigned',
                                color: AppTheme.brandRoyalBlue,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildMetricTile(
                                label: 'SEWN PCS',
                                value: '$stitched',
                                subtext: '${efficiency.toStringAsFixed(0)}% output',
                                color: AppTheme.badgeEmeraldText,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildMetricTile(
                                label: 'QC PASSED',
                                value: '$passed',
                                subtext: '${passRate.toStringAsFixed(0)}% pass rate',
                                color: AppTheme.badgeEmeraldText,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildMetricTile(
                                label: 'ALTERATIONS',
                                value: '$mending',
                                subtext: 'In mending/rework',
                                color: mending > 0 ? AppTheme.badgeAmberText : AppTheme.faintInk,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Articles / Lots History
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'ASSIGNED ARTICLES & LOTS (${linemanLots.length})',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.headingObsidian,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              'Realtime Synced',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.badgeEmeraldText,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (linemanLots.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppTheme.cardSurface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.borderLight),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'No active lots found for this lineman.',
                              style: GoogleFonts.publicSans(fontSize: 12, color: AppTheme.bodyInk),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: linemanLots.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, idx) {
                              final lot = linemanLots[idx];
                              final article = parseMap(lot['article']);
                              final artNo = article['art_no'] ?? 'N/A';
                              final color = (lot['color']?.toString().trim().isNotEmpty == true)
                                  ? lot['color'].toString().trim()
                                  : (article['description']?.toString() ?? 'All Sizes');
                              final sizeRange = lot['size_range']?.toString().trim() ?? '';
                              final challan = parseMap(lot['challan']);
                              final challanNo = challan['challan_no']?.toString();
                              final lotTarget = parseQty(lot['target_qty']);
                              final lotStitched = parseQty(lot['stitched_qty']);
                              final stage = lot['stage']?.toString() ?? 'SEWING_LINES';

                              Color stageBg = AppTheme.badgeBlueBg;
                              Color stageBorder = AppTheme.badgeBlueBorder;
                              Color stageText = AppTheme.badgeBlueText;
                              String stageTitle = 'Sewing';

                              if (stage == 'READY_TO_DISPATCH') {
                                stageBg = AppTheme.badgeEmeraldBg;
                                stageBorder = AppTheme.badgeEmeraldBorder;
                                stageText = AppTheme.badgeEmeraldText;
                                stageTitle = 'Ready';
                              } else if (stage == 'QC_INSPECTION') {
                                stageBg = AppTheme.mintSurface;
                                stageBorder = AppTheme.badgeMintBorder;
                                stageText = AppTheme.headingObsidian;
                                stageTitle = 'QC Floor';
                              } else if (stage == 'MENDING_COUNTING') {
                                stageBg = AppTheme.badgeAmberBg;
                                stageBorder = AppTheme.badgeAmberBorder;
                                stageText = AppTheme.badgeAmberText;
                                stageTitle = 'In Mending';
                              }

                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.cardSurface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppTheme.borderLight),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.02),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: AppTheme.mintSurface,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: AppTheme.badgeMintBorder),
                                      ),
                                      child: Text(
                                        'ART $artNo',
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.headingObsidian,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  color,
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppTheme.headingObsidian,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (sizeRange.isNotEmpty) ...[
                                                const SizedBox(width: 4),
                                                Text(
                                                  '($sizeRange)',
                                                  style: GoogleFonts.jetBrainsMono(fontSize: 10.5, color: AppTheme.bodyInk),
                                                ),
                                              ],
                                              if (challanNo != null) ...[
                                                const SizedBox(width: 4),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.badgeBlueBg,
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: AppTheme.badgeBlueBorder),
                                                  ),
                                                  child: Text(
                                                    'DC #$challanNo',
                                                    style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.w700, color: AppTheme.brandRoyalBlue),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            'Stitched: $lotStitched / $lotTarget pcs • Passed: ${lot['passed_qty'] ?? 0} pcs',
                                            style: GoogleFonts.publicSans(fontSize: 10.5, color: AppTheme.bodyInk),
                                          ),
                                          if (lot['handed_to_mending_at'] != null)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 2),
                                              child: Text(
                                                'Handed to Mending by ${lot['handed_to_mending_by'] ?? lmName}',
                                                style: GoogleFonts.publicSans(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppTheme.badgeEmeraldText,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: stageBg,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: stageBorder),
                                      ),
                                      child: Text(
                                        stageTitle,
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                          color: stageText,
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
                  ),
                  const Divider(height: 1, color: AppTheme.borderLight),
                  // Bottom Filter Action Buttons
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        if (isCurrentlySelected) ...[
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx);
                                setState(() {
                                  _selectedLinemanId = null;
                                  _selectedLinemanName = null;
                                });
                              },
                              icon: const Icon(Icons.close, size: 16),
                              label: const Text('Clear Filter'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.headingObsidian,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                side: const BorderSide(color: AppTheme.borderLight),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ] else ...[
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx);
                                setState(() {
                                  _selectedLinemanId = lmId;
                                  _selectedLinemanName = line['name']?.toString();
                                });
                              },
                              icon: const Icon(Icons.filter_alt_rounded, size: 16, color: Colors.white),
                              label: Text('Filter Floor to $lmName'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.headingObsidian,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ],
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

  Widget _buildMetricTile({
    required String label,
    required String value,
    required String subtext,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.bgCanvas,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.publicSans(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: AppTheme.faintInk,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtext,
            style: GoogleFonts.publicSans(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.bodyInk,
            ),
          ),
        ],
      ),
    );
  }
}
