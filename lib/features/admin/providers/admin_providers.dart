import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../main.dart';
import '../models/admin_models.dart';

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
  final String selectedStatus;

  ChallanFilterState({
    this.searchQuery = '',
    this.selectedBrand = 'ALL',
    this.selectedStatus = 'ALL',
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

final adminChallansListProvider = FutureProvider.autoDispose<List<AdminChallan>>((ref) async {
  final filter = ref.watch(challanFilterProvider);

  var query = supabase.from('challans').select('''
    *,
    allotments (
      id,
      target_qty,
      status,
      articles ( id, art_no, description )
    )
  ''');

  if (filter.selectedBrand != 'ALL') {
    query = query.eq('brand', filter.selectedBrand);
  }

  if (filter.selectedStatus != 'ALL') {
    query = query.eq('status', filter.selectedStatus);
  }

  final response = await query.order('created_at', ascending: false).limit(100);
  final list = (response as List).map((json) => AdminChallan.fromJson(json)).toList();

  if (filter.searchQuery.trim().isEmpty) {
    return list;
  }

  final q = filter.searchQuery.trim().toLowerCase();
  return list.where((c) {
    return c.challanNo.toLowerCase().contains(q) ||
        c.brand.toLowerCase().contains(q) ||
        (c.fabricType?.toLowerCase().contains(q) ?? false) ||
        (c.description?.toLowerCase().contains(q) ?? false);
  }).toList();
});

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

    // 1. Insert into allotments
    final allotPayload = <String, dynamic>{
      'lineman_id': linemanId,
      'article_id': articleId,
      'target_qty': targetQty,
      'status': 'IN_PROGRESS',
      'qc_status': 'PENDING_STITCHING',
      'mending_status': 'PENDING_STITCHING',
      'allotment_date': nowIso,
    };

    if (managerName != null && managerName.isNotEmpty) {
      allotPayload['manager_name'] = managerName;
    }
    if (challanNo != null && challanNo.isNotEmpty) {
      allotPayload['production_order_no'] = challanNo;
    }
    if (dueDate != null) {
      allotPayload['due_date'] = dueDate.toIso8601String().split('T')[0];
    }
    allotPayload['target_hours'] = targetHours;
    allotPayload['priority'] = priority;
    if (clientChallanNo.isNotEmpty) {
      allotPayload['client_challan_no'] = clientChallanNo;
    }
    if (samplePhotos.isNotEmpty) {
      allotPayload['sample_photos'] = samplePhotos;
    }
    if (challanId != null && challanId.isNotEmpty) {
      allotPayload['challan_id'] = challanId;
    }

    Map<String, dynamic>? allotment;
    try {
      final res = await supabase.from('allotments').insert(allotPayload).select('id').single();
      allotment = res;
    } catch (err) {
      // Fallback if optional schema columns not present
      final fallbackPayload = <String, dynamic>{
        'lineman_id': linemanId,
        'article_id': articleId,
        'target_qty': targetQty,
        'status': 'IN_PROGRESS',
        'qc_status': 'PENDING_STITCHING',
        'mending_status': 'PENDING_STITCHING',
        'allotment_date': nowIso,
      };
      if (challanId != null && challanId.isNotEmpty) {
        try {
          final withChallan = Map<String, dynamic>.from(fallbackPayload);
          withChallan['challan_id'] = challanId;
          allotment = await supabase.from('allotments').insert(withChallan).select('id').single();
        } catch (_) {
          allotment = await supabase.from('allotments').insert(fallbackPayload).select('id').single();
        }
      } else {
        allotment = await supabase.from('allotments').insert(fallbackPayload).select('id').single();
      }
    }

    if (allotment['id'] == null) {
      return 'Failed to create allotment in database.';
    }

    final allotmentId = allotment['id'].toString();

    // 2. Insert variants
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

    // 3. Insert materials checklist with notes metadata
    if (materials.isNotEmpty) {
      final notesJson = jsonEncode({
        'lineman_name': linemanName ?? 'Lineman',
        'article_id': articleId,
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

      if (validMaterials.isNotEmpty) {
        try {
          await supabase.from('allotment_materials').insert(validMaterials);
        } catch (mErr) {
          debugPrint('Error inserting allotment_materials: $mErr');
        }
      }
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
