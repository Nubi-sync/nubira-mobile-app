import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../main.dart';
import '../models/admin_models.dart';
import '../challans/challan_models.dart';

// ==========================================
// 1. FACTORY KPI & DASHBOARD OVERVIEW PROVIDER
// ==========================================

final adminDashboardProvider = FutureProvider.autoDispose<AdminFactoryKpi>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  
  try {
    // 1. Concurrently fetch all summary datasets from Supabase
    final results = await Future.wait([
      // 0: Challans count & recent with allotments join
      supabase.from('challans').select('''
        *,
        allotments (
          id, target_qty, status,
          articles ( id, art_no, description )
        )
      ''').order('created_at', ascending: false).limit(50),
      
      // 1: Allotments with Lineman & Article joins
      supabase.from('allotments').select('''
        id, challan_id, lineman_id, article_id, target_qty, status, allotment_date,
        mending_status, mending_total_counted, qc_status, qc_total_passed, qc_total_alter,
        created_at,
        profiles:lineman_id ( id, username ),
        articles:article_id ( id, art_no, description, size_rates, stitching_rate ),
        challans:challan_id ( id, challan_no, brand, fabric_type )
      ''').order('created_at', ascending: false).limit(50),
      
      // 2: Active Articles
      supabase.from('articles').select('id, art_no, description, stitching_rate, size_rates, is_active, created_at').eq('is_active', true),
      
      // 3: Profiles (Employees)
      supabase.from('profiles').select('id, username, role, is_active, created_at'),
      
      // 4: Production entries (daily_product)
      supabase.from('daily_product').select('quantity, created_at').order('created_at', ascending: false).limit(100),
      
      // 5: QC Logs
      supabase.from('qc_logs').select('qty_passed, qty_rejected, stage, created_at').order('created_at', ascending: false).limit(100),
      
      // 6: Store entries (store_transactions)
      supabase.from('store_transactions').select('''
        id, type, quantity, party_name, created_at,
        articles:article_id ( art_no, description )
      ''').order('created_at', ascending: false).limit(50),
      
      // 7: Dispatch entries
      supabase.from('delivery_challans').select('*').order('created_at', ascending: false).limit(50),
    ]);

    final challansData = (results[0] as List?) ?? [];
    final allotmentsData = (results[1] as List?) ?? [];
    final articlesData = (results[2] as List?) ?? [];
    final profilesData = (results[3] as List?) ?? [];
    final prodData = (results[4] as List?) ?? [];
    final qcData = (results[5] as List?) ?? [];
    final storeData = (results[6] as List?) ?? [];
    final dispatchData = (results[7] as List?) ?? [];

    // Parse records
    final challans = challansData.map((e) => AdminChallan.fromJson(e)).toList();
    final allotments = allotmentsData.map((e) => AdminAllotment.fromJson(e)).toList();
    final storeEntries = storeData.map((e) => AdminStoreEntry.fromJson(e)).toList();
    final dispatches = dispatchData.map((e) => AdminDispatchEntry.fromJson(e)).toList();

    // Calculate aggregated metrics
    int totalProd = 0;
    for (var p in prodData) {
      totalProd += (p['quantity'] as num?)?.toInt() ?? 0;
    }

    int totalQcPassed = 0;
    int totalQcAlter = 0;
    for (var q in qcData) {
      totalQcPassed += (q['qty_passed'] as num?)?.toInt() ?? 0;
      totalQcAlter += (q['qty_rejected'] as num?)?.toInt() ?? 0;
    }

    int storeInward = 0;
    for (var s in storeData) {
      if ((s['type']?.toString().toUpperCase() ?? '') == 'INWARD') {
        storeInward += (s['quantity'] as num?)?.toInt() ?? 0;
      }
    }

    int totalDispatched = 0;
    for (var d in dispatchData) {
      totalDispatched += (d['total_pieces'] as num?)?.toInt() ?? 0;
    }

    final kpi = AdminFactoryKpi(
      totalChallans: challans.length,
      totalAllotments: allotments.length,
      activeArticles: articlesData.length,
      activeEmployees: profilesData.where((p) => p['is_active'] != false).length,
      todayProductionQty: totalProd,
      todayQcPassedQty: totalQcPassed,
      todayQcAlterQty: totalQcAlter,
      totalStoreInwardQty: storeInward,
      totalDispatchedQty: totalDispatched,
      recentAllotments: allotments,
      recentChallans: challans,
      recentStoreEntries: storeEntries,
      recentDispatches: dispatches,
    );

    // Cache locally for offline viewing
    await prefs.setString('cached_admin_kpi_total_challans', kpi.totalChallans.toString());
    await prefs.setString('cached_admin_kpi_today_prod', kpi.todayProductionQty.toString());
    await prefs.setString('cached_admin_kpi_qc_passed', kpi.todayQcPassedQty.toString());
    await prefs.setString('cached_admin_kpi_store_inward', kpi.totalStoreInwardQty.toString());

    return kpi;
  } catch (e) {
    // Offline fallback
    final cachedChallans = int.tryParse(prefs.getString('cached_admin_kpi_total_challans') ?? '0') ?? 0;
    final cachedProd = int.tryParse(prefs.getString('cached_admin_kpi_today_prod') ?? '0') ?? 0;
    final cachedQc = int.tryParse(prefs.getString('cached_admin_kpi_qc_passed') ?? '0') ?? 0;
    final cachedStore = int.tryParse(prefs.getString('cached_admin_kpi_store_inward') ?? '0') ?? 0;

    return AdminFactoryKpi(
      totalChallans: cachedChallans,
      todayProductionQty: cachedProd,
      todayQcPassedQty: cachedQc,
      totalStoreInwardQty: cachedStore,
    );
  }
});

// ==========================================
// 2. CHALLANS PROVIDER WITH BRAND FILTER & SEARCH
// ==========================================

class ChallanFilterState {
  final String searchQuery;
  final String selectedBrand;
  final String selectedStatus; // 'ALL' | 'PENDING' | 'ALLOTTED'

  ChallanFilterState({
    this.searchQuery = '',
    this.selectedBrand = 'ALL',
    this.selectedStatus = 'PENDING',
  });

  ChallanFilterState copyWith({
    String? searchQuery,
    String? selectedBrand,
    String? selectedStatus,
  }) {
    return ChallanFilterState(
      searchQuery: searchQuery ?? this.searchQuery,
      selectedBrand: selectedBrand ?? this.selectedBrand,
      selectedStatus: selectedStatus ?? this.selectedStatus,
    );
  }
}

final challanFilterProvider = StateProvider<ChallanFilterState>((ref) {
  return ChallanFilterState();
});

/// Hierarchical grouped Challans provider matching Web's getProductionOrders()
final challanGroupedOrdersProvider = FutureProvider.autoDispose<List<ChallanGroupedOrder>>((ref) async {
  try {
    final results = await Future.wait([
      supabase.from('challans').select('*').order('created_at', ascending: false).limit(100),
      supabase.from('allotments').select('''
        id, challan_id, lineman_id, article_id, target_qty, status, allotment_date,
        profiles:lineman_id ( id, username ),
        articles:article_id ( id, art_no, description, size_rates, stitching_rate )
      ''').order('created_at', ascending: true),
      supabase.from('allotment_variants').select('allotment_id, color, size, quantity, completed_qty'),
    ]);

    final challansRaw = (results[0] as List?) ?? [];
    final allotmentsRaw = (results[1] as List?) ?? [];
    final variantsRaw = (results[2] as List?) ?? [];

    final List<ChallanGroupedOrder> groupedList = [];

    for (var chJson in challansRaw) {
      final chId = chJson['id']?.toString() ?? '';
      final chNo = chJson['challan_no']?.toString().trim().toUpperCase() ?? '';

      // Match allotments belonging to this challan by challan_id, production_order_no, or client_challan_no
      final chAllotments = allotmentsRaw.where((a) {
        final alChId = a['challan_id']?.toString();
        if (alChId == chId) return true;
        final alProdNo = a['production_order_no']?.toString().trim().toUpperCase() ?? '';
        final alClientNo = a['client_challan_no']?.toString().trim().toUpperCase() ?? '';
        if (chNo.isNotEmpty && (alProdNo == chNo || alClientNo == chNo || alClientNo == 'JOB-$chNo')) {
          return true;
        }
        return false;
      }).toList();

      final rawNotes = chJson['notes']?.toString();

      List<ChallanArticleLine> parsedLines = [];

      if (rawNotes != null && rawNotes.trim().isNotEmpty) {
        try {
          if (rawNotes.trim().startsWith('{') || rawNotes.trim().startsWith('[')) {
            final decoded = jsonDecode(rawNotes);
            List<dynamic> rawLineItems = [];
            if (decoded is Map && decoded['article_lines'] is List) {
              rawLineItems = decoded['article_lines'] as List;
            } else if (decoded is List) {
              rawLineItems = decoded;
            }

            for (var idx = 0; idx < rawLineItems.length; idx++) {
              final line = rawLineItems[idx];
              if (line is Map) {
                final cleanArtNo = line['art_no']?.toString().trim().toUpperCase() ?? 'Style';
                final cleanSubArt = line['sub_art_no']?.toString().trim().toUpperCase();
                final fullArtCode = cleanSubArt != null && cleanSubArt.isNotEmpty ? '$cleanArtNo$cleanSubArt' : cleanArtNo;
                final colorPattern = line['color_pattern']?.toString().trim() ?? 'Standard';
                final sizeRange = line['size_range']?.toString().trim() ?? 'Free Size';

                final linePcs = (line['total_pcs'] as num?)?.toInt() ??
                    (((line['sets'] as num?)?.toInt() ?? 1) * ((line['pcs_per_set'] as num?)?.toInt() ?? 9));
                final lineSets = (line['sets'] as num?)?.toInt() ?? 1;
                final lineRatio = (line['pcs_per_set'] as num?)?.toInt() ?? 9;

                // Match with active floor allotment for this article and color
                dynamic matchingAl;
                for (var al in chAllotments) {
                  final art = al['articles'] as Map?;
                  final alArtNo = art?['art_no']?.toString().trim().toUpperCase();
                  if (alArtNo == cleanArtNo || alArtNo == fullArtCode) {
                    matchingAl = al;
                    break;
                  }
                }

                // Global fallback matching if allotment was created with client_challan_no for this order
                if (matchingAl == null) {
                  for (var al in allotmentsRaw) {
                    final art = al['articles'] as Map?;
                    final alArtNo = art?['art_no']?.toString().trim().toUpperCase();
                    if (alArtNo == cleanArtNo || alArtNo == fullArtCode) {
                      final alProdNo = al['production_order_no']?.toString().trim().toUpperCase() ?? '';
                      final alClientNo = al['client_challan_no']?.toString().trim().toUpperCase() ?? '';
                      if (chNo.isNotEmpty && (alProdNo == chNo || alClientNo == chNo || alClientNo == 'JOB-$chNo')) {
                        matchingAl = al;
                        break;
                      }
                    }
                  }
                }

                String? linemanId;
                String? linemanName;
                String lineStatus = 'PENDING';
                String? allotmentId;
                int completedQty = 0;

                // Priority 1: Check if note line itself already has assigned lineman
                final rawLmId = line['assigned_lineman_id']?.toString().trim();
                final rawLmName = (line['assigned_lineman_name'] ?? line['lineman_name'])?.toString().trim();
                if (rawLmId != null && rawLmId.isNotEmpty) {
                  linemanId = rawLmId;
                  linemanName = (rawLmName != null && rawLmName.isNotEmpty) ? rawLmName : 'Lineman';
                  lineStatus = 'IN_PROGRESS';
                } else if (rawLmName != null && rawLmName.isNotEmpty && !rawLmName.toLowerCase().contains('unassigned')) {
                  linemanName = rawLmName;
                  lineStatus = 'IN_PROGRESS';
                }

                // Priority 2: Override / enrich from live child allotment record if matched
                if (matchingAl != null) {
                  allotmentId = matchingAl['id']?.toString();
                  if (matchingAl['lineman_id'] != null) {
                    linemanId = matchingAl['lineman_id']?.toString();
                    final prof = matchingAl['profiles'] as Map?;
                    linemanName = prof?['username']?.toString() ?? linemanName ?? 'Lineman';
                    lineStatus = matchingAl['status']?.toString().toUpperCase() ?? 'IN_PROGRESS';
                  }

                  // Find completed qty from variants
                  final alVars = variantsRaw.where((v) => v['allotment_id']?.toString() == allotmentId).toList();
                  for (var v in alVars) {
                    if ((v['color']?.toString().toUpperCase() ?? '') == colorPattern.toUpperCase()) {
                      completedQty += (v['completed_qty'] as num?)?.toInt() ?? 0;
                    }
                  }
                }

                parsedLines.add(
                  ChallanArticleLine(
                    id: '$chId-line-$idx',
                    allotmentId: allotmentId,
                    artNo: cleanArtNo,
                    subArtNo: cleanSubArt,
                    patternNo: line['pattern_no']?.toString(),
                    description: line['description']?.toString() ?? '$fullArtCode - $colorPattern ($sizeRange)',
                    colorPattern: colorPattern,
                    sizeRange: sizeRange,
                    sets: lineSets,
                    pcsPerSet: lineRatio,
                    totalPcs: linePcs,
                    completedQty: completedQty,
                    assignedLinemanId: linemanId,
                    assignedLinemanName: linemanName ?? 'Unassigned (Floor Order)',
                    pictureUrl: line['picture_url']?.toString(),
                    stitchingRate: (line['stitching_rate'] as num?)?.toDouble() ?? 20.0,
                    status: lineStatus,
                  ),
                );
              }
            }

            // Auto-heal / backfill missing floor allotments for legacy / imported challans with assigned linemen
            if (chAllotments.isEmpty && rawLineItems.isNotEmpty) {
              _syncMissingAllotmentsFromNotes(chJson, rawLineItems);
            }
          }
        } catch (_) {}
      }

      // Fallback if no structured lines in notes: construct from child allotments
      if (parsedLines.isEmpty && chAllotments.isNotEmpty) {
        for (var al in chAllotments) {
          final art = al['articles'] as Map?;
          final prof = al['profiles'] as Map?;
          final aId = al['id']?.toString() ?? '';
          final alVars = variantsRaw.where((v) => v['allotment_id']?.toString() == aId).toList();
          final firstVar = alVars.isNotEmpty ? alVars.first : null;
          final targetQty = (al['target_qty'] as num?)?.toInt() ?? 0;

          parsedLines.add(
            ChallanArticleLine(
              id: aId,
              allotmentId: aId,
              artNo: art?['art_no']?.toString() ?? 'Style',
              description: art?['description']?.toString(),
              colorPattern: firstVar?['color']?.toString() ?? 'Standard',
              sizeRange: firstVar?['size']?.toString() ?? 'Free Size',
              totalPcs: targetQty,
              assignedLinemanId: al['lineman_id']?.toString(),
              assignedLinemanName: prof?['username']?.toString() ?? 'Lineman',
              status: al['status']?.toString().toUpperCase() ?? 'PENDING',
            ),
          );
        }
      }

      final totalSets = parsedLines.fold(0, (sum, a) => sum + a.sets);
      final totalPcsCalculated = parsedLines.fold(0, (sum, a) => sum + a.totalPcs);
      final finalPcs = totalPcsCalculated > 0 ? totalPcsCalculated : ((chJson['total_pcs'] as num?)?.toInt() ?? 0);
      final finalSets = totalSets > 0 ? totalSets : ((chJson['total_sets'] as num?)?.toInt() ?? 1);

      // Parse BOM details
      List<ChallanBomItem> bomItems = [];
      if (chJson['bom_details'] != null) {
        try {
          final rawBom = chJson['bom_details'];
          final List<dynamic> bomList = rawBom is String ? jsonDecode(rawBom) : (rawBom is List ? rawBom : []);
          bomItems = bomList.map((b) => ChallanBomItem.fromJson(Map<String, dynamic>.from(b))).toList();
        } catch (_) {}
      }

      // Dynamic Status Calculation matching Web
      final totalLines = parsedLines.length;
      final allottedLines = parsedLines.where((a) {
        final hasLineman = (a.assignedLinemanId != null && a.assignedLinemanId!.isNotEmpty) ||
            (a.assignedLinemanName != null &&
                a.assignedLinemanName!.isNotEmpty &&
                !a.assignedLinemanName!.toLowerCase().contains('unassigned'));
        return hasLineman && a.status != 'PENDING';
      }).length;
      final completedLines = parsedLines.where((a) => a.status == 'QC_PASSED' || a.status == 'COMPLETED').length;
      final dispatchedLines = parsedLines.where((a) => a.status == 'DISPATCHED').length;

      String dynamicStatus = 'PENDING';
      final rawStatus = chJson['status']?.toString().toUpperCase() ?? 'PENDING';
      if (rawStatus == 'DISPATCHED' || (dispatchedLines == totalLines && totalLines > 0)) {
        dynamicStatus = 'DISPATCHED';
      } else if (rawStatus == 'QC_PASSED' || (completedLines == totalLines && totalLines > 0)) {
        dynamicStatus = 'QC_PASSED';
      } else if (allottedLines == totalLines && totalLines > 0) {
        dynamicStatus = 'IN_PROGRESS';
      } else if (allottedLines > 0) {
        dynamicStatus = 'PARTIALLY_ALLOTTED';
      } else if (rawStatus == 'IN_PROGRESS' || rawStatus == 'ALLOTTED') {
        dynamicStatus = 'IN_PROGRESS';
      } else {
        dynamicStatus = 'PENDING';
      }

      final groupedOrder = ChallanGroupedOrder(
        id: chId,
        challanNo: chJson['challan_no']?.toString() ?? 'CHALLAN',
        challanDate: chJson['challan_date']?.toString() ?? DateTime.now().toIso8601String().split('T')[0],
        brand: (chJson['brand']?.toString().trim().isNotEmpty == true) ? chJson['brand'].toString().trim() : 'OLLYPOP',
        deliveryDate: chJson['delivery_date']?.toString(),
        fabricType: chJson['fabric_type']?.toString(),
        sampleGiven: chJson['sample_given'] == true,
        notes: rawNotes ?? '',
        totalSets: finalSets,
        totalPcs: finalPcs,
        status: dynamicStatus,
        bomDetails: bomItems,
        articles: parsedLines,
        createdAt: chJson['created_at'] != null ? (DateTime.tryParse(chJson['created_at'].toString()) ?? DateTime.now()) : DateTime.now(),
      );

      groupedList.add(groupedOrder);
    }

    return groupedList;
  } catch (e, stack) {
    debugPrint('Error loading grouped challans: $e\n$stack');
    return [];
  }
});

/// Legacy provider alias for backward compatibility
final adminChallansListProvider = FutureProvider.autoDispose<List<AdminChallan>>((ref) async {
  final grouped = await ref.watch(challanGroupedOrdersProvider.future);
  return grouped.map((g) => AdminChallan(
    id: g.id,
    challanNo: g.challanNo,
    brand: g.brand,
    fabricType: g.fabricType,
    totalQty: g.totalPcs,
    status: g.status,
    createdAt: g.createdAt,
  )).toList();
});

// ==========================================
// CHALLAN DIRECT MUTATION ACTIONS (100% Web Parity)
// ==========================================

/// 1-Click Allot Entire Challan to a Single Lineman
Future<String?> allotFullChallanDirectlyInSupabase(String challanId, String linemanId) async {
  try {
    if (challanId.isEmpty || linemanId.isEmpty) {
      return 'Please select a valid Challan and Lineman.';
    }

    // 1. Fetch lineman profile username
    String linemanName = 'Lineman';
    final prof = await supabase.from('profiles').select('username').eq('id', linemanId).single();
    if (prof['username'] != null) linemanName = prof['username'].toString();

    // 2. Fetch challan details
    final ch = await supabase.from('challans').select('*').eq('id', challanId).single();

    final todayDate = DateTime.now().toIso8601String().split('T')[0];

    // 3. Update existing allotments for this challan
    final existingAllots = await supabase
        .from('allotments')
        .select('id, article_id')
        .eq('challan_id', challanId);

    final existingArtIds = <String>{};
    if (existingAllots.isNotEmpty) {
      final allIds = existingAllots.map((a) => a['id']?.toString()).where((id) => id != null).toList();
      await supabase.from('allotments').update({
        'lineman_id': linemanId,
        'status': 'IN_PROGRESS',
        'qc_status': 'PENDING_STITCHING',
        'mending_status': 'PENDING_STITCHING',
      }).inFilter('id', allIds);

      for (var a in existingAllots) {
        if (a['article_id'] != null) existingArtIds.add(a['article_id'].toString());
      }
    }

    // 4. Create missing allotments for planned lines in notes
    if (ch['notes'] != null) {
      try {
        final parsed = jsonDecode(ch['notes'].toString());
        final lines = parsed is Map ? (parsed['article_lines'] as List?) : (parsed is List ? parsed : null);

        if (lines != null) {
          for (var line in lines) {
            if (line is Map) {
              final cleanArtNo = line['art_no']?.toString().trim().toUpperCase() ?? 'Style';
              final linePcs = (line['total_pcs'] as num?)?.toInt() ?? 100;
              final color = line['color_pattern']?.toString().trim() ?? 'Standard';
              final size = line['size_range']?.toString().trim() ?? 'Free Size';

              // Ensure article exists in articles catalog
              var artRes = await supabase.from('articles').select('id').eq('art_no', cleanArtNo).limit(1).maybeSingle();
              String? artId = artRes?['id']?.toString();

              if (artId == null) {
                final newArt = await supabase.from('articles').insert({
                  'art_no': cleanArtNo,
                  'description': line['description']?.toString() ?? '$cleanArtNo - $color ($size)',
                  'stitching_rate': (line['stitching_rate'] as num?)?.toDouble() ?? 20.0,
                  'is_active': true,
                }).select('id').single();
                artId = newArt['id']?.toString();
              }

              if (artId != null && !existingArtIds.contains(artId)) {
                existingArtIds.add(artId);
                final newAl = await supabase.from('allotments').insert({
                  'challan_id': challanId,
                  'lineman_id': linemanId,
                  'article_id': artId,
                  'target_qty': linePcs,
                  'status': 'IN_PROGRESS',
                  'qc_status': 'PENDING_STITCHING',
                  'mending_status': 'PENDING_STITCHING',
                  'allotment_date': todayDate,
                }).select('id').single();

                final aId = newAl['id']?.toString();
                if (aId != null) {
                  await supabase.from('allotment_variants').insert({
                    'allotment_id': aId,
                    'color': color,
                    'size': size,
                    'quantity': linePcs,
                    'completed_qty': 0,
                  });

                  await supabase.from('allotment_materials').insert({
                    'allotment_id': aId,
                    'item_name': '${ch['fabric_type'] ?? "Fabric"} - $color',
                    'required_qty': '$linePcs pcs',
                    'admin_issued': true,
                    'notes': jsonEncode({
                      'lineman_name': linemanName,
                      'client_challan_no': ch['challan_no'],
                      'color_pattern': color,
                      'size_range': size,
                      'brand': ch['brand'],
                      'fabric': ch['fabric_type'],
                    }),
                  });
                }
              }
            }
          }
        }
      } catch (_) {}
    }

    // 5. Update challan status to IN_PROGRESS
    await supabase.from('challans').update({'status': 'IN_PROGRESS'}).eq('id', challanId);
    return null; // Success
  } catch (e) {
    debugPrint('Error in allotFullChallanDirectlyInSupabase: $e');
    return e.toString();
  }
}

/// 1-Click Allot Specific Color Line to a Lineman
Future<String?> allotColorGroupDirectlyInSupabase(String challanId, String colorName, String linemanId) async {
  try {
    if (challanId.isEmpty || colorName.isEmpty || linemanId.isEmpty) {
      return 'Please select a valid Challan, Color line, and Lineman.';
    }

    // 1. Fetch lineman profile
    String linemanName = 'Lineman';
    final prof = await supabase.from('profiles').select('username').eq('id', linemanId).single();
    if (prof['username'] != null) linemanName = prof['username'].toString();

    final ch = await supabase.from('challans').select('*').eq('id', challanId).single();
    final todayDate = DateTime.now().toIso8601String().split('T')[0];

    // 2. Parse lines matching color
    List<dynamic> targetLines = [];
    if (ch['notes'] != null) {
      try {
        final p = jsonDecode(ch['notes'].toString());
        final lines = p is Map ? (p['article_lines'] as List?) : (p is List ? p : null);
        if (lines != null) {
          targetLines = lines.where((line) {
            final c = (line['color_pattern']?.toString() ?? line['description']?.toString() ?? '').trim().toUpperCase();
            final target = colorName.trim().toUpperCase();
            return c == target || c.contains(target) || c.contains('3 COLOUR') || c.contains('3 COLOR') || target == 'ALL';
          }).toList();
        }
      } catch (_) {}
    }

    for (var line in targetLines) {
      final cleanArtNo = line['art_no']?.toString().trim().toUpperCase() ?? 'Style';
      final linePcs = (line['total_pcs'] as num?)?.toInt() ?? 100;
      final size = line['size_range']?.toString().trim() ?? 'Free Size';

      var artRes = await supabase.from('articles').select('id').eq('art_no', cleanArtNo).limit(1).maybeSingle();
      String? artId = artRes?['id']?.toString();

      if (artId == null) {
        final newArt = await supabase.from('articles').insert({
          'art_no': cleanArtNo,
          'description': line['description']?.toString() ?? '$cleanArtNo - $colorName',
          'stitching_rate': (line['stitching_rate'] as num?)?.toDouble() ?? 20.0,
          'is_active': true,
        }).select('id').single();
        artId = newArt['id']?.toString();
      }

      if (artId != null) {
        final newAl = await supabase.from('allotments').insert({
          'challan_id': challanId,
          'lineman_id': linemanId,
          'article_id': artId,
          'target_qty': linePcs,
          'status': 'IN_PROGRESS',
          'qc_status': 'PENDING_STITCHING',
          'mending_status': 'PENDING_STITCHING',
          'allotment_date': todayDate,
        }).select('id').single();

        final aId = newAl['id']?.toString();
        if (aId != null) {
          await supabase.from('allotment_variants').insert({
            'allotment_id': aId,
            'color': colorName,
            'size': size,
            'quantity': linePcs,
            'completed_qty': 0,
          });

          await supabase.from('allotment_materials').insert({
            'allotment_id': aId,
            'item_name': '${ch['fabric_type'] ?? "Fabric"} - $colorName',
            'required_qty': '$linePcs pcs',
            'admin_issued': true,
            'notes': jsonEncode({
              'lineman_name': linemanName,
              'client_challan_no': ch['challan_no'],
              'color_pattern': colorName,
              'size_range': size,
            }),
          });
        }
      }
    }

    await supabase.from('challans').update({'status': 'IN_PROGRESS'}).eq('id', challanId);
    return null;
  } catch (e) {
    debugPrint('Error in allotColorGroupDirectlyInSupabase: $e');
    return e.toString();
  }
}

/// Unallot / Recall Challan back to Pending Allotment
Future<bool> unallotChallanDirectlyInSupabase(String challanId) async {
  try {
    if (challanId.isEmpty) return false;

    // Delete floor allotments associated with this challan
    await supabase.from('allotments').delete().eq('challan_id', challanId);
    await supabase.from('challans').update({'status': 'PENDING'}).eq('id', challanId);
    return true;
  } catch (e) {
    debugPrint('Error in unallotChallanDirectlyInSupabase: $e');
    return false;
  }
}

/// Delete Challan and cascade its floor allotments
Future<bool> deleteChallanInSupabase(String challanId) async {
  try {
    if (challanId.isEmpty) return false;

    // 1. Find child allotments
    final childAllots = await supabase.from('allotments').select('id').eq('challan_id', challanId);
    if (childAllots.isNotEmpty) {
      final ids = childAllots.map((a) => a['id']?.toString()).where((id) => id != null).toList();
      try { await supabase.from('allotment_variants').delete().inFilter('allotment_id', ids); } catch (_) {}
      try { await supabase.from('allotment_materials').delete().inFilter('allotment_id', ids); } catch (_) {}
      try { await supabase.from('allotments').delete().eq('challan_id', challanId); } catch (_) {}
    }

    await supabase.from('challans').delete().eq('id', challanId);
    return true;
  } catch (e) {
    debugPrint('Error in deleteChallanInSupabase: $e');
    return false;
  }
}

class _GroupedAllotmentData {
  final Map<String, dynamic> artObj;
  final String resolvedLinemanId;
  final String resolvedLinemanName;
  int totalTargetQty;
  final String fullArtCode;
  final Map<String, Map<String, dynamic>> variantsMap;
  final Set<String> descriptions;

  _GroupedAllotmentData({
    required this.artObj,
    required this.resolvedLinemanId,
    required this.resolvedLinemanName,
    required this.totalTargetQty,
    required this.fullArtCode,
    required this.variantsMap,
    required this.descriptions,
  });
}

/// Auto-sync / backfill missing floor allotments for legacy / imported challans with assigned linemen
void _syncMissingAllotmentsFromNotes(Map<String, dynamic> chJson, List<dynamic> lines) async {
  try {
    final chId = chJson['id']?.toString();
    if (chId == null || chId.isEmpty) return;
    final chNo = chJson['challan_no']?.toString() ?? '';
    final chDate = chJson['challan_date']?.toString() ?? DateTime.now().toIso8601String().split('T')[0];
    final fabric = chJson['fabric_type']?.toString() ?? '';
    final brand = chJson['brand']?.toString() ?? 'OLLYPOP';

    final allProfiles = await supabase.from('profiles').select('id, username').eq('is_active', true);
    final Map<String, String> profileMap = {};
    for (var p in allProfiles) {
      final u = p['username']?.toString().trim().toLowerCase();
      final id = p['id']?.toString();
      if (u != null && id != null) profileMap[u] = id;
    }

    bool anyCreated = false;
    for (var line in lines) {
      if (line is! Map) continue;
      final rawLmId = line['assigned_lineman_id']?.toString().trim();
      final rawLmName = (line['assigned_lineman_name'] ?? line['lineman_name'])?.toString().trim();
      String? resolvedLmId = (rawLmId != null && rawLmId.isNotEmpty) ? rawLmId : null;
      if (resolvedLmId == null && rawLmName != null && rawLmName.isNotEmpty) {
        resolvedLmId = profileMap[rawLmName.toLowerCase()];
      }
      if (resolvedLmId == null || resolvedLmId.isEmpty) continue;

      final cleanArtNo = line['art_no']?.toString().trim().toUpperCase() ?? '';
      final fullArtCode = (line['full_art_code'] ?? cleanArtNo).toString().trim().toUpperCase();

      var artObj = await supabase.from('articles').select('id, description, art_no').eq('art_no', cleanArtNo).limit(1).maybeSingle();
      if (artObj == null && fullArtCode != cleanArtNo) {
        artObj = await supabase.from('articles').select('id, description, art_no').eq('art_no', fullArtCode).limit(1).maybeSingle();
      }
      if (artObj == null) {
        final newArt = await supabase.from('articles').insert({
          'art_no': cleanArtNo,
          'description': line['description']?.toString() ?? cleanArtNo,
          'stitching_rate': (line['stitching_rate'] as num?)?.toDouble() ?? 20.0,
          'is_active': true,
        }).select('id').single();
        artObj = newArt;
      }

      final artId = artObj['id'].toString();
      final linePcs = (line['total_pcs'] as num?)?.toInt() ?? 100;
      final color = line['color_pattern']?.toString().trim() ?? 'Standard';
      final size = line['size_range']?.toString().trim() ?? 'Free Size';

      final newAl = await supabase.from('allotments').insert({
        'challan_id': chId,
        'lineman_id': resolvedLmId,
        'article_id': artId,
        'target_qty': linePcs,
        'status': 'IN_PROGRESS',
        'qc_status': 'PENDING_STITCHING',
        'mending_status': 'PENDING_STITCHING',
        'allotment_date': chDate,
      }).select('id').single();

      final aId = newAl['id']?.toString();
      if (aId != null) {
        anyCreated = true;
        await supabase.from('allotment_variants').insert({
          'allotment_id': aId,
          'color': color,
          'size': size,
          'quantity': linePcs,
          'completed_qty': 0,
        });

        final matNote = jsonEncode({
          'lineman_id': resolvedLmId,
          'lineman_name': rawLmName ?? 'Lineman',
          'article_id': artId,
          'art_no': cleanArtNo,
          'article_description': line['description']?.toString() ?? '',
          'client_challan_no': chNo,
          'brand': brand,
          'fabric': fabric,
          'total_pcs': linePcs,
          'status': 'PENDING',
        });

        await supabase.from('allotment_materials').insert([
          {'allotment_id': aId, 'item_name': 'Main Fabric ($fabric)', 'required_qty': 'As per lot', 'admin_issued': false, 'notes': matNote},
          {'allotment_id': aId, 'item_name': 'Matching Sewing Thread', 'required_qty': '5 Cones', 'admin_issued': false, 'notes': matNote},
          {'allotment_id': aId, 'item_name': 'Main Brand Neck Tag', 'required_qty': '$linePcs pcs', 'admin_issued': false, 'notes': matNote},
          {'allotment_id': aId, 'item_name': 'Master Polybags', 'required_qty': '$linePcs pcs', 'admin_issued': false, 'notes': matNote},
        ]);
      }
    }

    if (anyCreated) {
      await supabase.from('challans').update({'status': 'IN_PROGRESS'}).eq('id', chId);
    }
  } catch (e) {
    debugPrint('Auto sync background error: $e');
  }
}

/// Create a Multi-Article Job Work Delivery Challan (100% Web Admin Parity)
Future<String?> createChallanInSupabase({
  required String challanNo,
  required String challanDate,
  required String brand,
  String? deliveryDate,
  String? fabricType,
  bool sampleGiven = false,
  String notes = '',
  required List<Map<String, dynamic>> articleLines,
  List<Map<String, dynamic>> bomItems = const [],
}) async {
  try {
    final cleanChallanNo = challanNo.trim().toUpperCase();
    if (cleanChallanNo.isEmpty) return 'Challan Number is required.';

    if (articleLines.isEmpty) return 'Please add at least one article line.';

    // 1. Duplicate check in Supabase
    final existingChallan = await supabase
        .from('challans')
        .select('id, challan_no')
        .ilike('challan_no', cleanChallanNo)
        .limit(1)
        .maybeSingle();

    if (existingChallan != null) {
      return 'Challan #$cleanChallanNo already exists in the system! Each delivery job challan must have a unique Challan Number.';
    }

    final grandTotalSets = articleLines.fold<int>(0, (sum, l) => sum + ((l['sets'] as num?)?.toInt() ?? 1));
    final grandTotalPcs = articleLines.fold<int>(0, (sum, l) => sum + ((l['total_pcs'] as num?)?.toInt() ?? 0));

    // 2. Fetch all profiles for username to id resolution
    final allProfiles = await supabase.from('profiles').select('id, username').eq('is_active', true);
    final Map<String, String> profileMap = {};
    final Map<String, String> profileIdToName = {};
    for (var p in allProfiles) {
      final u = p['username']?.toString().trim().toLowerCase();
      final id = p['id']?.toString();
      if (u != null && id != null) profileMap[u] = id;
      if (id != null && p['username'] != null) profileIdToName[id] = p['username'].toString();
    }

    // 3. Process and save article catalog styles with size_rates._meta
    final List<Map<String, dynamic>> processedLines = [];
    for (var line in articleLines) {
      final cleanArtNo = line['art_no']?.toString().trim().toUpperCase() ?? '';
      final cleanSubArt = (line['sub_art_no']?.toString() ?? '').trim().toUpperCase();
      final fullArtCode = cleanSubArt.isNotEmpty ? '$cleanArtNo$cleanSubArt' : cleanArtNo;
      final linePcs = (line['total_pcs'] as num?)?.toInt() ??
          (((line['sets'] as num?)?.toInt() ?? 1) * ((line['pcs_per_set'] as num?)?.toInt() ?? 9));
      final lineSets = (line['sets'] as num?)?.toInt() ?? 1;
      final lineRatio = (line['pcs_per_set'] as num?)?.toInt() ?? 9;

      final rawLmId = line['assigned_lineman_id']?.toString().trim();
      final rawLmName = (line['assigned_lineman_name'] ?? line['lineman_name'])?.toString().trim();
      String? resolvedLmId = (rawLmId != null && rawLmId.isNotEmpty) ? rawLmId : null;
      if (resolvedLmId == null && rawLmName != null && rawLmName.isNotEmpty) {
        resolvedLmId = profileMap[rawLmName.toLowerCase()];
      }
      final resolvedLmName = resolvedLmId != null
          ? (profileIdToName[resolvedLmId] ?? rawLmName ?? 'Lineman')
          : (rawLmName ?? '');

      if (fullArtCode.isNotEmpty) {
        final existing = await supabase.from('articles').select('id').eq('art_no', fullArtCode).limit(1).maybeSingle();
        if (existing == null) {
          await supabase.from('articles').insert({
            'art_no': fullArtCode,
            'description': line['description']?.toString() ?? '$fullArtCode - ${line['color_pattern'] ?? ""} (${line['size_range'] ?? ""})',
            'stitching_rate': (line['stitching_rate'] as num?)?.toDouble() ?? 20.0,
            'is_active': true,
            'size_rates': {
              '_meta': {
                'base_art': cleanArtNo,
                'sub_art': cleanSubArt,
                'pattern': line['product'] ?? line['pattern_no'] ?? '',
                'category': line['category'] ?? '',
                'fabric': fabricType?.trim() ?? '',
                'party': brand.trim().toUpperCase(),
                'size': line['size_range'] ?? '',
                'picture_url': line['picture_url'] ?? '',
              }
            }
          });
        }
      }

      processedLines.add({
        ...line,
        'art_no': cleanArtNo,
        'sub_art_no': cleanSubArt,
        'full_art_code': fullArtCode,
        'sets': lineSets,
        'pcs_per_set': lineRatio,
        'total_pcs': linePcs,
        'assigned_lineman_id': resolvedLmId,
        'assigned_lineman_name': resolvedLmName,
        'status': resolvedLmId != null ? 'IN_PROGRESS' : 'PENDING',
      });
    }

    // 4. Calculate Challan Status
    final assignedCount = processedLines.where((l) => l['assigned_lineman_id'] != null && l['assigned_lineman_id'].toString().isNotEmpty).length;
    String challanStatus = 'PENDING';
    if (assignedCount == processedLines.length && processedLines.isNotEmpty) {
      challanStatus = 'IN_PROGRESS';
    } else if (assignedCount > 0) {
      challanStatus = 'PARTIALLY_ALLOTTED';
    }

    // 5. Structured Challan Notes JSON
    final notesJson = jsonEncode({
      'user_notes': notes.trim(),
      'article_lines': processedLines,
    });

    // 6. Insert into `challans` table
    final newChallanRes = await supabase.from('challans').insert({
      'challan_no': cleanChallanNo,
      'challan_date': challanDate,
      'brand': brand.trim().toUpperCase(),
      'delivery_date': deliveryDate != null && deliveryDate.isNotEmpty ? deliveryDate : null,
      'fabric_type': fabricType?.trim(),
      'sample_given': sampleGiven,
      'notes': notesJson,
      'total_sets': grandTotalSets,
      'total_pcs': grandTotalPcs,
      'status': challanStatus,
      'bom_details': bomItems,
    }).select('id').single();

    final newChallanId = newChallanRes['id']?.toString();
    if (newChallanId == null) {
      return 'Failed to obtain new challan id from database.';
    }

    // 7. Auto-create Allotments for any article lines with assigned Lineman (100% Web Admin Parity)
    final Map<String, _GroupedAllotmentData> groupedAllotmentMap = {};

    for (var line in processedLines) {
      final resolvedLinemanId = line['assigned_lineman_id']?.toString();
      if (resolvedLinemanId == null || resolvedLinemanId.isEmpty) continue;

      final cleanArtNo = line['art_no']?.toString().trim().toUpperCase() ?? '';
      final fullArtCode = line['full_art_code']?.toString().trim().toUpperCase() ?? cleanArtNo;

      var artObj = await supabase.from('articles').select('id, description, art_no').eq('art_no', cleanArtNo).limit(1).maybeSingle();
      if (artObj == null && fullArtCode != cleanArtNo) {
        artObj = await supabase.from('articles').select('id, description, art_no').eq('art_no', fullArtCode).limit(1).maybeSingle();
      }

      if (artObj == null) continue;

      final artId = artObj['id'].toString();
      final key = '${artId}__$resolvedLinemanId';
      final linePcs = (line['total_pcs'] as num?)?.toInt() ?? 0;
      final resolvedLinemanName = line['assigned_lineman_name']?.toString() ?? 'Lineman';

      if (!groupedAllotmentMap.containsKey(key)) {
        groupedAllotmentMap[key] = _GroupedAllotmentData(
          artObj: artObj,
          resolvedLinemanId: resolvedLinemanId,
          resolvedLinemanName: resolvedLinemanName,
          totalTargetQty: 0,
          fullArtCode: cleanArtNo,
          variantsMap: {},
          descriptions: <String>{},
        );
      }

      final grp = groupedAllotmentMap[key]!;
      grp.totalTargetQty += linePcs;
      if (line['description'] != null) grp.descriptions.add(line['description'].toString());

      final color = (line['color_pattern']?.toString().trim().isNotEmpty == true) ? line['color_pattern'].toString().trim() : 'Standard';
      final sizeRange = (line['size_range']?.toString().trim().isNotEmpty == true) ? line['size_range'].toString().trim() : 'Free Size';
      final sizeList = sizeRange.split('/').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      final perSizeQty = (sizeList.isNotEmpty) ? (linePcs / sizeList.length).round() : linePcs;

      for (var sz in (sizeList.isNotEmpty ? sizeList : [sizeRange])) {
        final vKey = '${color.toUpperCase()}__${sz.toUpperCase()}';
        final curQty = grp.variantsMap[vKey]?['quantity'] ?? 0;
        grp.variantsMap[vKey] = {
          'color': color,
          'size': sz,
          'quantity': curQty + perSizeQty,
        };
      }
    }

    for (var grp in groupedAllotmentMap.values) {
      final newAl = await supabase.from('allotments').insert({
        'challan_id': newChallanId,
        'article_id': grp.artObj['id'],
        'lineman_id': grp.resolvedLinemanId,
        'target_qty': grp.totalTargetQty,
        'status': 'IN_PROGRESS',
        'qc_status': 'PENDING_STITCHING',
        'mending_status': 'PENDING_STITCHING',
        'allotment_date': challanDate,
      }).select('id').single();

      final alId = newAl['id']?.toString();
      if (alId != null) {
        final vars = grp.variantsMap.values.map((v) => {
          'allotment_id': alId,
          'color': v['color'] ?? 'Standard',
          'size': v['size'] ?? 'Free',
          'quantity': v['quantity'],
          'completed_qty': 0,
        }).toList();

        if (vars.isNotEmpty) {
          try {
            await supabase.from('allotment_variants').insert(vars);
          } catch (vErr) {
            debugPrint('Error inserting allotment_variants: $vErr');
          }
        }

        final matNote = jsonEncode({
          'lineman_id': grp.resolvedLinemanId,
          'lineman_name': grp.resolvedLinemanName,
          'article_id': grp.artObj['id'],
          'art_no': grp.fullArtCode,
          'article_description': grp.descriptions.isNotEmpty ? grp.descriptions.join(', ') : (grp.artObj['description'] ?? ''),
          'client_challan_no': cleanChallanNo,
          'brand': brand,
          'fabric': fabricType ?? '',
          'total_pcs': grp.totalTargetQty,
          'status': 'PENDING',
        });

        try {
          await supabase.from('allotment_materials').insert([
            {
              'allotment_id': alId,
              'item_name': 'Main Fabric (${fabricType ?? "Sinker"})',
              'required_qty': 'As per lot',
              'admin_issued': false,
              'notes': matNote,
            },
            {
              'allotment_id': alId,
              'item_name': 'Matching Sewing Thread',
              'required_qty': '5 Cones',
              'admin_issued': false,
              'notes': matNote,
            },
            {
              'allotment_id': alId,
              'item_name': 'Main Brand Neck Tag',
              'required_qty': '${grp.totalTargetQty} pcs',
              'admin_issued': false,
              'notes': matNote,
            },
            {
              'allotment_id': alId,
              'item_name': 'Master Polybags',
              'required_qty': '${grp.totalTargetQty} pcs',
              'admin_issued': false,
              'notes': matNote,
            },
          ]);
        } catch (mErr) {
          debugPrint('Error inserting allotment_materials: $mErr');
        }
      }
    }

    return null; // Success!
  } catch (e) {
    debugPrint('Error in createChallanInSupabase: $e');
    return e.toString();
  }
}

// ==========================================
// 3. ALLOTMENTS PROVIDER
// ==========================================

class AllotmentFilterState {
  final String searchQuery;
  final String selectedStatus;
  final String? selectedLinemanId;

  AllotmentFilterState({
    this.searchQuery = '',
    this.selectedStatus = 'ALL',
    this.selectedLinemanId,
  });

  AllotmentFilterState copyWith({
    String? searchQuery,
    String? selectedStatus,
    String? selectedLinemanId,
  }) {
    return AllotmentFilterState(
      searchQuery: searchQuery ?? this.searchQuery,
      selectedStatus: selectedStatus ?? this.selectedStatus,
      selectedLinemanId: selectedLinemanId ?? this.selectedLinemanId,
    );
  }
}

final allotmentFilterProvider = StateProvider<AllotmentFilterState>((ref) {
  return AllotmentFilterState();
});

final adminAllotmentsListProvider = FutureProvider.autoDispose<List<AdminAllotment>>((ref) async {
  final filter = ref.watch(allotmentFilterProvider);

  try {
    List<dynamic> rawList = [];
    try {
      var query = supabase.from('allotments').select('''
        id, challan_id, lineman_id, article_id, target_qty, status, allotment_date,
        mending_status, mending_total_counted, qc_status, qc_total_passed, qc_total_alter,
        created_at,
        profiles:lineman_id ( id, username ),
        articles:article_id ( id, art_no, description, size_rates, stitching_rate ),
        challans:challan_id ( id, challan_no, brand, fabric_type )
      ''');

      if (filter.selectedStatus != 'ALL') {
        query = query.eq('status', filter.selectedStatus);
      }
      if (filter.selectedLinemanId != null && filter.selectedLinemanId!.isNotEmpty) {
        query = query.eq('lineman_id', filter.selectedLinemanId!);
      }

      final response = await query.order('created_at', ascending: false).limit(100);
      rawList = (response as List);
    } catch (queryErr) {
      // Fallback query without challans join if foreign key relationship differs
      var fallbackQuery = supabase.from('allotments').select('''
        id, lineman_id, article_id, target_qty, status, allotment_date,
        mending_status, mending_total_counted, qc_status, qc_total_passed, qc_total_alter,
        created_at,
        profiles:lineman_id ( id, username ),
        articles:article_id ( id, art_no, description, size_rates, stitching_rate )
      ''');

      if (filter.selectedStatus != 'ALL') {
        fallbackQuery = fallbackQuery.eq('status', filter.selectedStatus);
      }
      if (filter.selectedLinemanId != null && filter.selectedLinemanId!.isNotEmpty) {
        fallbackQuery = fallbackQuery.eq('lineman_id', filter.selectedLinemanId!);
      }

      final fbResponse = await fallbackQuery.order('created_at', ascending: false).limit(100);
      rawList = (fbResponse as List);
    }

    final allotmentIds = rawList
        .map((e) => e['id']?.toString())
        .where((id) => id != null && id.isNotEmpty)
        .toList();

    List<dynamic> variantsRaw = [];
    List<dynamic> materialsRaw = [];

    if (allotmentIds.isNotEmpty) {
      try {
        final vRes = await supabase
            .from('allotment_variants')
            .select('*')
            .inFilter('allotment_id', allotmentIds);
        variantsRaw = (vRes as List?) ?? [];
      } catch (_) {}

      try {
        final mRes = await supabase
            .from('allotment_materials')
            .select('*')
            .inFilter('allotment_id', allotmentIds);
        materialsRaw = (mRes as List?) ?? [];
      } catch (_) {}
    }

    final list = rawList.map((json) {
      final aId = json['id']?.toString();
      final aVars = variantsRaw.where((v) => v['allotment_id']?.toString() == aId).toList();
      final aMats = materialsRaw.where((m) => m['allotment_id']?.toString() == aId).toList();

      final fullJson = Map<String, dynamic>.from(json);
      fullJson['allotment_variants'] = aVars;
      fullJson['allotment_materials'] = aMats;

      return AdminAllotment.fromJson(fullJson);
    }).toList();

    if (filter.searchQuery.trim().isEmpty) {
      return list;
    }

    final q = filter.searchQuery.trim().toLowerCase();
    return list.where((a) {
      return (a.challanNo?.toLowerCase().contains(q) ?? false) ||
          (a.articleNo?.toLowerCase().contains(q) ?? false) ||
          (a.linemanName?.toLowerCase().contains(q) ?? false) ||
          (a.brand?.toLowerCase().contains(q) ?? false);
    }).toList();
  } catch (e, stack) {
    debugPrint('Error loading allotments: $e\n$stack');
    return [];
  }
});

/// Create a detailed allotment record in Supabase with variants and materials
Future<String?> createDetailedAllotmentInSupabase({
  required String linemanId,
  required String? linemanName,
  required String articleId,
  required String? articleNo,
  required String? articleDesc,
  required int targetQty,
  String? managerName,
  String? challanId,
  String? challanNo,
  String? brand,
  String? fabricType,
  String priority = 'NORMAL',
  DateTime? dueDate,
  int targetHours = 16,
  String clientChallanNo = '',
  List<String> samplePhotos = const [],
  required List<Map<String, dynamic>> variants,
  required List<Map<String, dynamic>> materials,
}) async {
  try {
    final nowIso = DateTime.now().toIso8601String().split('T')[0];

    // Safely resolve article ID to ensure it is a valid UUID present in articles table
    final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    String resolvedArticleId = articleId.trim();

    if (!uuidRegex.hasMatch(resolvedArticleId)) {
      resolvedArticleId = '';
    }

    if (resolvedArticleId.isNotEmpty) {
      try {
        final checkArt = await supabase.from('articles').select('id').eq('id', resolvedArticleId).limit(1).maybeSingle();
        if (checkArt == null || checkArt['id'] == null) {
          resolvedArticleId = '';
        }
      } catch (_) {
        resolvedArticleId = '';
      }
    }

    if (resolvedArticleId.isEmpty) {
      final cleanArtNo = (articleNo ?? '').trim().isNotEmpty
          ? (articleNo ?? '').trim()
          : (challanNo ?? 'Standard');
      try {
        final found = await supabase.from('articles').select('id').eq('art_no', cleanArtNo).limit(1).maybeSingle();
        if (found != null && found['id'] != null) {
          resolvedArticleId = found['id'].toString();
        }
      } catch (_) {}

      if (resolvedArticleId.isEmpty) {
        try {
          final newArt = await supabase.from('articles').insert({
            'art_no': cleanArtNo,
            'description': articleDesc ?? 'Auto-created style for Allotment',
            'stitching_rate': 20.0,
            'is_active': true,
          }).select('id').single();
          if (newArt['id'] != null) {
            resolvedArticleId = newArt['id'].toString();
          }
        } catch (_) {}
      }

      if (resolvedArticleId.isEmpty) {
        try {
          final anyArt = await supabase.from('articles').select('id').limit(1).maybeSingle();
          if (anyArt != null && anyArt['id'] != null) {
            resolvedArticleId = anyArt['id'].toString();
          }
        } catch (_) {}
      }
    }

    if (resolvedArticleId.isEmpty) {
      return 'Could not resolve or create a valid Article ID for this allotment.';
    }

    // 1. Resolve Challan ID if passed as ID, challanNo, or clientChallanNo
    String? resolvedChallanId = challanId;
    if ((resolvedChallanId == null || resolvedChallanId.isEmpty) && challanNo != null && challanNo.isNotEmpty) {
      final cleanNo = challanNo.replaceAll('JOB-', '').trim();
      try {
        final ch = await supabase.from('challans').select('id').ilike('challan_no', cleanNo).limit(1).maybeSingle();
        if (ch != null && ch['id'] != null) {
          resolvedChallanId = ch['id'].toString();
        }
      } catch (_) {}
    }
    if ((resolvedChallanId == null || resolvedChallanId.isEmpty) && clientChallanNo.isNotEmpty) {
      final cleanNo = clientChallanNo.replaceAll('JOB-', '').trim();
      try {
        final ch = await supabase.from('challans').select('id').ilike('challan_no', cleanNo).limit(1).maybeSingle();
        if (ch != null && ch['id'] != null) {
          resolvedChallanId = ch['id'].toString();
        }
      } catch (_) {}
    }

    // 2. Insert into allotments
    final allotPayload = <String, dynamic>{
      'lineman_id': linemanId,
      'article_id': resolvedArticleId,
      'target_qty': targetQty,
      'status': 'IN_PROGRESS',
      'qc_status': 'PENDING_STITCHING',
      'mending_status': 'PENDING_STITCHING',
      'allotment_date': nowIso,
    };

    if (resolvedChallanId != null && resolvedChallanId.isNotEmpty) {
      allotPayload['challan_id'] = resolvedChallanId;
    }

    final res = await supabase.from('allotments').insert(allotPayload).select('id').single();
    final allotmentId = res['id']?.toString();

    if (allotmentId == null) {
      return 'Failed to create allotment in database.';
    }

    // 3. Update parent Challan status to IN_PROGRESS
    if (resolvedChallanId != null && resolvedChallanId.isNotEmpty) {
      try {
        await supabase.from('challans').update({'status': 'IN_PROGRESS'}).eq('id', resolvedChallanId);
      } catch (_) {}
    }

    // 4. Insert variants
    if (variants.isNotEmpty) {
      final validVariants = variants
          .where((v) => (v['quantity'] as num? ?? 0) > 0)
          .map((v) => {
                'allotment_id': allotmentId,
                'color': (v['color'] ?? 'Standard').toString().trim(),
                'size': (v['size'] ?? 'Free').toString().trim(),
                'quantity': (v['quantity'] as num).toInt(),
                'completed_qty': 0,
              })
          .toList();

      if (validVariants.isNotEmpty) {
        try {
          await supabase.from('allotment_variants').insert(validVariants);
        } catch (vErr) {
          debugPrint('Error inserting allotment_variants: $vErr');
        }
      }
    }

    // 5. Insert materials checklist with notes metadata
    final notesJson = jsonEncode({
      'lineman_name': linemanName ?? 'Lineman',
      'article_id': resolvedArticleId,
      'art_no': articleNo ?? '',
      'article_description': articleDesc ?? '',
      'lineman_id': linemanId,
      'production_order_no': challanNo ?? '',
      'manager_name': managerName ?? 'Production Manager',
      'due_date': dueDate != null ? dueDate.toIso8601String().split('T')[0] : '',
      'target_hours': targetHours,
      'priority': priority,
      'client_challan_no': clientChallanNo,
      'sample_photos': samplePhotos,
      'brand': brand ?? '',
      'fabric': fabricType ?? '',
      'total_pcs': targetQty,
      'status': 'PENDING',
    });

    final validMaterials = materials
        .where((m) => (m['item_name']?.toString().trim().isNotEmpty ?? false))
        .map((m) => {
              'allotment_id': allotmentId,
              'item_name': m['item_name'].toString().trim(),
              'required_qty': m['required_qty']?.toString().trim().isNotEmpty == true
                  ? m['required_qty'].toString().trim()
                  : 'As required',
              'admin_issued': m['admin_issued'] == true,
              'admin_issued_at': m['admin_issued'] == true ? DateTime.now().toIso8601String() : null,
              'lineman_received': false,
              'notes': notesJson,
            })
        .toList();

    final materialsToInsert = validMaterials.isNotEmpty
        ? validMaterials
        : [
            {
              'allotment_id': allotmentId,
              'item_name': 'Main Fabric - Cut Panels',
              'required_qty': '$targetQty pcs',
              'admin_issued': true,
              'admin_issued_at': DateTime.now().toIso8601String(),
              'lineman_received': false,
              'notes': notesJson,
            }
          ];

    try {
      await supabase.from('allotment_materials').insert(materialsToInsert);
    } catch (mErr) {
      debugPrint('Error inserting allotment_materials: $mErr');
    }

    return null; // Success!
  } catch (e) {
    debugPrint('Fatal error in createDetailedAllotmentInSupabase: $e');
    return e.toString();
  }
}

/// Update status of an existing allotment
Future<bool> updateAllotmentStatusInSupabase(String allotmentId, String newStatus) async {
  try {
    await supabase.from('allotments').update({'status': newStatus}).eq('id', allotmentId);
    return true;
  } catch (e) {
    debugPrint('Error updating allotment status: $e');
    return false;
  }
}

/// Delete allotment and cascade child variants/materials
Future<bool> deleteAllotmentInSupabase(String allotmentId) async {
  try {
    // Delete child records first for safety
    try {
      await supabase.from('allotment_variants').delete().eq('allotment_id', allotmentId);
    } catch (_) {}
    try {
      await supabase.from('allotment_materials').delete().eq('allotment_id', allotmentId);
    } catch (_) {}
    await supabase.from('allotments').delete().eq('id', allotmentId);
    return true;
  } catch (e) {
    debugPrint('Error deleting allotment: $e');
    return false;
  }
}

// ==========================================
// 4. ARTICLES CRUD PROVIDER
// ==========================================

final adminArticlesListProvider = FutureProvider.autoDispose<List<AdminArticle>>((ref) async {
  final response = await supabase
      .from('articles')
      .select('*')
      .order('art_no', ascending: true);

  return (response as List).map((json) => AdminArticle.fromJson(json)).toList();
});

// ==========================================
// 5. EMPLOYEES CRUD PROVIDER
// ==========================================

final adminEmployeesListProvider = FutureProvider.autoDispose<List<AdminEmployee>>((ref) async {
  final response = await supabase
      .from('profiles')
      .select('*')
      .order('created_at', ascending: false);

  return (response as List).map((json) => AdminEmployee.fromJson(json)).toList();
});

// ==========================================
// 6. GODOWN & INVENTORY PROVIDER
// ==========================================

final adminInventoryListProvider = FutureProvider.autoDispose<List<AdminStoreEntry>>((ref) async {
  final response = await supabase
      .from('store_transactions')
      .select('''
        id, type, quantity, color, size, party_name, challan_no, entry_date, created_at,
        articles:article_id ( art_no, description )
      ''')
      .order('created_at', ascending: false)
      .limit(100);

  return (response as List).map((json) => AdminStoreEntry.fromJson(json)).toList();
});

// ==========================================
// 7. DISPATCH CHALLANS PROVIDER
// ==========================================

final adminDispatchListProvider = FutureProvider.autoDispose<List<AdminDispatchEntry>>((ref) async {
  final response = await supabase
      .from('delivery_challans')
      .select('*')
      .order('created_at', ascending: false)
      .limit(100);

  return (response as List).map((json) => AdminDispatchEntry.fromJson(json)).toList();
});
