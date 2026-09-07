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
    final rawList = (response as List);
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
  } catch (e) {
    return [];
  }
});

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
