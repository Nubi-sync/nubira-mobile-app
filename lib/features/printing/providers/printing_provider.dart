import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../main.dart';
import '../../../core/services/tenant_resolver_service.dart';
import '../models/printing_models.dart';

class PrintingState {
  final bool isLoading;
  final bool isSyncing;
  final String? error;
  final List<PrintingWorker> workers;
  final List<PrintingTaskAllocation> taskAllocations;
  final List<PrintingBuyerContract> buyers;
  final String selectedBuyerId;
  final Map<String, String> articleRoutes; // buyerId -> routeKey
  final StrikeOffApproval strikeOffApproval;
  final String statusFilter; // ALL, ACTIVE, NEEDS_VERIFY, COMPLETED
  final String searchQuery;
  final int upstreamCutPieces;
  final int upstreamEmbroideryPieces;

  const PrintingState({
    this.isLoading = false,
    this.isSyncing = false,
    this.error,
    this.workers = const [],
    this.taskAllocations = const [],
    this.buyers = const [],
    this.selectedBuyerId = '',
    this.articleRoutes = const {},
    this.strikeOffApproval = const StrikeOffApproval(
      status: 'APPROVED',
      labRemarks: 'Lab color fastness & swatch shade sign-off',
    ),
    this.statusFilter = 'ALL',
    this.searchQuery = '',
    this.upstreamCutPieces = 0,
    this.upstreamEmbroideryPieces = 0,
  });

  PrintingState copyWith({
    bool? isLoading,
    bool? isSyncing,
    String? error,
    List<PrintingWorker>? workers,
    List<PrintingTaskAllocation>? taskAllocations,
    List<PrintingBuyerContract>? buyers,
    String? selectedBuyerId,
    Map<String, String>? articleRoutes,
    StrikeOffApproval? strikeOffApproval,
    String? statusFilter,
    String? searchQuery,
    int? upstreamCutPieces,
    int? upstreamEmbroideryPieces,
  }) {
    return PrintingState(
      isLoading: isLoading ?? this.isLoading,
      isSyncing: isSyncing ?? this.isSyncing,
      error: error,
      workers: workers ?? this.workers,
      taskAllocations: taskAllocations ?? this.taskAllocations,
      buyers: buyers ?? this.buyers,
      selectedBuyerId: selectedBuyerId ?? this.selectedBuyerId,
      articleRoutes: articleRoutes ?? this.articleRoutes,
      strikeOffApproval: strikeOffApproval ?? this.strikeOffApproval,
      statusFilter: statusFilter ?? this.statusFilter,
      searchQuery: searchQuery ?? this.searchQuery,
      upstreamCutPieces: upstreamCutPieces ?? this.upstreamCutPieces,
      upstreamEmbroideryPieces: upstreamEmbroideryPieces ?? this.upstreamEmbroideryPieces,
    );
  }
}

const List<PrintingBuyerContract> kInitialPrintingBuyers = [
  PrintingBuyerContract(
    id: 'byr-hollypop',
    buyerName: 'Hollypop',
    buyerCode: 'HOLL',
    contractedVolume: 6000,
    pricePerPiece: 18.5,
    totalContractValue: 111000,
    linkedArticleNumber: 'DEMO-101-03',
    linkedArticleName: 'Premium Graphic Tee',
    embellishmentSequence: 'PRINT_FIRST_THEN_EMBROIDERY',
    status: 'LINKED',
    completedCutPieces: 2800,
  ),
  PrintingBuyerContract(
    id: 'byr-ollywood',
    buyerName: 'ollywood',
    buyerCode: 'OLLY',
    contractedVolume: 5000,
    pricePerPiece: 15.0,
    totalContractValue: 75000,
    linkedArticleNumber: 'DEMO-102',
    linkedArticleName: 'Commercial Apparel Order',
    embellishmentSequence: 'PRINT_FIRST_THEN_EMBROIDERY',
    status: 'LINKED',
    completedCutPieces: 0,
  ),
];

const List<PrintingTaskAllocation> kInitialPrintingTasks = [
  PrintingTaskAllocation(
    id: 'task-prn-01',
    taskRef: 'PRN-2026-8801',
    workerId: 'pw-101',
    workerName: 'Rajesh Verma',
    buyerName: 'Hollypop',
    articleNumber: 'DEMO-101-03',
    articleName: 'Premium Graphic Tee',
    tableNumber: 'TABLE-01',
    piecesToPrint: 1000,
    completedPieces: 0,
    status: 'ASSIGNED',
    allotedHours: 8.0,
    createdAt: '2026-09-24T00:00:00.000Z',
  ),
  PrintingTaskAllocation(
    id: 'task-prn-02',
    taskRef: 'PRN-2026-8802',
    workerId: 'pw-102',
    workerName: 'Sunil Sharma',
    buyerName: 'Hollypop',
    articleNumber: 'DEMO-101-03',
    articleName: 'Premium Graphic Tee',
    tableNumber: 'TABLE-02',
    piecesToPrint: 800,
    completedPieces: 800,
    status: 'WORKER_COMPLETED',
    allotedHours: 6.0,
    createdAt: '2026-09-24T00:00:00.000Z',
  ),
  PrintingTaskAllocation(
    id: 'task-prn-03',
    taskRef: 'PRN-2026-8803',
    workerId: 'pw-101',
    workerName: 'Vikram Singh',
    buyerName: 'Hollypop',
    articleNumber: 'DEMO-101-03',
    articleName: 'Premium Graphic Tee',
    tableNumber: 'MHM-CAROUSEL-01',
    piecesToPrint: 1000,
    completedPieces: 1000,
    status: 'VERIFIED_COMPLETED',
    allotedHours: 8.0,
    createdAt: '2026-09-24T00:00:00.000Z',
  ),
];

const List<PrintingWorker> kInitialPrintingWorkers = [
  PrintingWorker(
    id: 'pw-101',
    workerName: 'Rajesh Verma',
    phoneNumber: '9876543210',
    workerEmail: 'rajesh.verma@printing.nubira.local',
    roles: ['SCREEN_PRINTER'],
    role: 'Screen Print Operator',
    status: 'ACTIVE',
    assignedPieces: 2000,
    completedPieces: 1000,
    createdAt: '2026-09-24T00:00:00.000Z',
  ),
  PrintingWorker(
    id: 'pw-102',
    workerName: 'Sunil Sharma',
    phoneNumber: '9876543211',
    workerEmail: 'sunil.sharma@printing.nubira.local',
    roles: ['DTG_TECHNICIAN'],
    role: 'DTG & Heat Press Technician',
    status: 'ACTIVE',
    assignedPieces: 800,
    completedPieces: 800,
    createdAt: '2026-09-24T00:00:00.000Z',
  ),
];

class PrintingNotifier extends StateNotifier<PrintingState> {
  final Ref ref;

  PrintingNotifier(this.ref) : super(const PrintingState(isLoading: true)) {
    loadInitialData();
  }

  Future<String?> _getResolvedCompanyFilter() async {
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser != null) {
        final tenant = await TenantResolverService.resolveUserTenant(currentUser);
        if (!tenant.isLegacyNubira && tenant.companyName != 'Zigza MES Platform Operations') {
          return tenant.companyName.trim();
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> loadInitialData() async {
    state = state.copyWith(isLoading: true, error: null);
    final prefs = await SharedPreferences.getInstance();

    try {
      final cachedWorkers = prefs.getString('cached_printing_workers');
      final cachedTasks = prefs.getString('cached_printing_tasks');
      final cachedBuyers = prefs.getString('cached_printing_buyers');
      final cachedRoutes = prefs.getString('cached_printing_routes');
      final cachedStrikeOff = prefs.getString('cached_printing_strike_off');

      List<PrintingWorker> workers = kInitialPrintingWorkers;
      List<PrintingTaskAllocation> tasks = kInitialPrintingTasks;
      List<PrintingBuyerContract> buyers = kInitialPrintingBuyers;
      Map<String, String> routes = {};
      StrikeOffApproval strikeOff = const StrikeOffApproval(
        status: 'APPROVED',
        labRemarks: 'Lab color fastness & swatch shade sign-off',
      );

      if (cachedWorkers != null) {
        final decoded = jsonDecode(cachedWorkers) as List;
        final list = decoded.map((e) => PrintingWorker.fromJson(e)).toList();
        if (list.isNotEmpty) workers = list;
      }
      if (cachedTasks != null) {
        final decoded = jsonDecode(cachedTasks) as List;
        final list = decoded.map((e) => PrintingTaskAllocation.fromJson(e)).toList();
        if (list.isNotEmpty) tasks = list;
      }
      if (cachedBuyers != null) {
        final decoded = jsonDecode(cachedBuyers) as List;
        final list = decoded.map((e) => PrintingBuyerContract.fromJson(e)).toList();
        if (list.isNotEmpty) buyers = list;
      }
      if (cachedRoutes != null) {
        final decoded = jsonDecode(cachedRoutes) as Map<String, dynamic>;
        routes = decoded.map((k, v) => MapEntry(k, v.toString()));
      }
      if (cachedStrikeOff != null) {
        strikeOff = StrikeOffApproval.fromJson(jsonDecode(cachedStrikeOff));
      }

      state = state.copyWith(
        workers: workers,
        taskAllocations: tasks,
        buyers: buyers,
        articleRoutes: routes,
        strikeOffApproval: strikeOff,
        selectedBuyerId: buyers.isNotEmpty ? buyers.first.id : '',
      );
    } catch (_) {}

    // 2. Fetch live data from Supabase backend
    await syncData();
  }

  Future<void> syncData() async {
    state = state.copyWith(isSyncing: true, error: null);
    final companyFilter = await _getResolvedCompanyFilter();

    try {
      // Parallel fetch from live Supabase tables
      final results = await Future.wait([
        _fetchWorkersFromSupabase(companyFilter),
        _fetchTasksFromSupabase(companyFilter),
        _fetchBuyersFromSupabase(companyFilter),
        _fetchUpstreamCuttingPieces(companyFilter),
        _fetchUpstreamEmbroideryPieces(companyFilter),
      ]);

      final freshWorkers = (results[0] as List<PrintingWorker>).isNotEmpty
          ? (results[0] as List<PrintingWorker>)
          : (state.workers.isNotEmpty ? state.workers : kInitialPrintingWorkers);
      final freshTasks = (results[1] as List<PrintingTaskAllocation>).isNotEmpty
          ? (results[1] as List<PrintingTaskAllocation>)
          : (state.taskAllocations.isNotEmpty ? state.taskAllocations : kInitialPrintingTasks);
      final freshBuyers = (results[2] as List<PrintingBuyerContract>).isNotEmpty
          ? (results[2] as List<PrintingBuyerContract>)
          : (state.buyers.isNotEmpty ? state.buyers : kInitialPrintingBuyers);
      final upstreamCut = results[3] as int;
      final upstreamEmbroidery = results[4] as int;

      final activeBuyerId = state.selectedBuyerId.isNotEmpty &&
              freshBuyers.any((b) => b.id == state.selectedBuyerId)
          ? state.selectedBuyerId
          : (freshBuyers.isNotEmpty ? freshBuyers.first.id : '');

      state = state.copyWith(
        isLoading: false,
        isSyncing: false,
        workers: freshWorkers,
        taskAllocations: freshTasks,
        buyers: freshBuyers,
        selectedBuyerId: activeBuyerId,
        upstreamCutPieces: upstreamCut > 0 ? upstreamCut : 2800,
        upstreamEmbroideryPieces: upstreamEmbroidery,
      );

      // Save live synchronized data to SharedPreferences cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_printing_workers', jsonEncode(freshWorkers.map((e) => e.toJson()).toList()));
      await prefs.setString('cached_printing_tasks', jsonEncode(freshTasks.map((e) => e.toJson()).toList()));
      await prefs.setString('cached_printing_buyers', jsonEncode(freshBuyers.map((e) => {
        'id': e.id,
        'buyer_name': e.buyerName,
        'buyer_code': e.buyerCode,
        'contracted_volume': e.contractedVolume,
        'price_per_piece': e.pricePerPiece,
        'total_contract_value': e.totalContractValue,
        'linked_article_number': e.linkedArticleNumber,
        'linked_article_name': e.linkedArticleName,
        'embellishment_sequence': e.embellishmentSequence,
        'status': e.status,
      }).toList()));
    } catch (e) {
      debugPrint('[PrintingNotifier] syncData error: $e');
      state = state.copyWith(
        isLoading: false,
        isSyncing: false,
        error: 'Network sync notice: ${e.toString()}',
      );
    }
  }

  Future<List<PrintingWorker>> _fetchWorkersFromSupabase(String? company) async {
    try {
      var query = supabase
          .from('printing_workers')
          .select('*')
          .order('created_at', ascending: false);

      final res = await query;
      final rawList = (res as List<dynamic>?) ?? [];
      var mapped = rawList.map((e) => PrintingWorker.fromJson(e as Map<String, dynamic>)).toList();

      if (company != null && company.isNotEmpty) {
        final target = company.toLowerCase();
        mapped = mapped.where((w) {
          final c = (w.companyName ?? '').toLowerCase();
          return c.isEmpty || c == target || c.contains(target);
        }).toList();
      }
      return mapped.isNotEmpty ? mapped : kInitialPrintingWorkers;
    } catch (e) {
      debugPrint('[PrintingNotifier] _fetchWorkersFromSupabase error: $e');
      return kInitialPrintingWorkers;
    }
  }

  Future<List<PrintingTaskAllocation>> _fetchTasksFromSupabase(String? company) async {
    try {
      var query = supabase
          .from('printing_task_allocations')
          .select('*')
          .order('created_at', ascending: false);

      final res = await query;
      final rawList = (res as List<dynamic>?) ?? [];
      var mapped = rawList.map((e) => PrintingTaskAllocation.fromJson(e as Map<String, dynamic>)).toList();

      if (company != null && company.isNotEmpty) {
        final target = company.toLowerCase();
        mapped = mapped.where((t) {
          final c = (t.companyName ?? '').toLowerCase();
          return c.isEmpty || c == target || c.contains(target);
        }).toList();
      }
      return mapped.isNotEmpty ? mapped : kInitialPrintingTasks;
    } catch (e) {
      debugPrint('[PrintingNotifier] _fetchTasksFromSupabase error: $e');
      return kInitialPrintingTasks;
    }
  }

  Future<List<PrintingBuyerContract>> _fetchBuyersFromSupabase(String? company) async {
    final Map<String, PrintingBuyerContract> mergedMap = {};
    final Map<String, int> buyerCutMap = {};

    // 1. Fetch cutting allocations to compute completed cut pieces per buyer / article
    try {
      final cRes = await supabase
          .from('cutting_task_allocations')
          .select('completed_pieces, pieces_to_cut, status, buyer_name, article_number, company_name');
      final cList = (cRes as List<dynamic>?) ?? [];
      for (final r in cList) {
        final status = r['status']?.toString();
        if (status == 'VERIFIED_COMPLETED' || status == 'COMPLETED') {
          if (company != null && company.isNotEmpty) {
            final c = (r['company_name']?.toString() ?? '').toLowerCase();
            final target = company.toLowerCase();
            if (c.isNotEmpty && c != target && !c.contains(target)) continue;
          }
          final pcs = ((r['completed_pieces'] ?? r['pieces_to_cut']) as num?)?.toInt() ?? 0;
          final bName = (r['buyer_name']?.toString() ?? '').trim().toUpperCase();
          final aNum = (r['article_number']?.toString() ?? '').trim().toUpperCase();
          if (bName.isNotEmpty) {
            buyerCutMap[bName] = (buyerCutMap[bName] ?? 0) + pcs;
          }
          if (aNum.isNotEmpty) {
            buyerCutMap[aNum] = (buyerCutMap[aNum] ?? 0) + pcs;
          }
        }
      }
    } catch (e) {
      debugPrint('[PrintingNotifier] Error fetching cutting allocations: $e');
    }

    // 2. Fetch from merchandising_active_buyers
    try {
      final res = await supabase
          .from('merchandising_active_buyers')
          .select('*')
          .order('created_at', ascending: false);
      final raw = (res as List<dynamic>?) ?? [];
      for (final row in raw) {
        if (company != null && company.isNotEmpty) {
          final comp = (row['company_name']?.toString() ?? '').toLowerCase();
          final target = company.toLowerCase();
          if (comp.isNotEmpty && comp != target && !comp.contains(target)) continue;
        }

        final bName = (row['buyer_name']?.toString() ?? row['brand_name']?.toString() ?? '').trim();
        if (bName.isEmpty) continue;
        final key = bName.toUpperCase();
        final qty = ((row['contracted_volume'] as num?) ?? 0).toInt();
        final article = row['linked_article_number']?.toString() ?? row['style_ref']?.toString();
        final cutPcs = buyerCutMap[key] ?? (article != null ? buyerCutMap[article.trim().toUpperCase()] ?? 0 : 0);

        mergedMap[key] = PrintingBuyerContract(
          id: row['id']?.toString() ?? 'buyer-$key',
          buyerName: bName,
          buyerCode: row['buyer_code']?.toString() ?? (bName.length >= 4 ? bName.substring(0, 4).toUpperCase() : 'BUYER'),
          contractedVolume: qty > 0 ? qty : 5000,
          pricePerPiece: ((row['price_per_piece'] as num?) ?? 12.5).toDouble(),
          totalContractValue: ((row['total_contract_value'] as num?) ?? 0).toDouble(),
          linkedArticleNumber: article,
          linkedArticleName: row['linked_article_name']?.toString() ?? row['style_name']?.toString(),
          embellishmentSequence: row['embellishment_sequence']?.toString() ?? 'PRINT_FIRST_THEN_EMBROIDERY',
          status: row['status']?.toString() ?? 'ACTIVE',
          companyName: row['company_name']?.toString(),
          completedCutPieces: cutPcs,
        );
      }
    } catch (e) {
      debugPrint('[PrintingNotifier] Error fetching merchandising_active_buyers: $e');
    }

    // 3. Fetch from merchandising_orders safely (matching exact Web Action logic)
    try {
      final oRes = await supabase
          .from('merchandising_orders')
          .select('*')
          .order('created_at', ascending: false);
      final rawOrders = (oRes as List<dynamic>?) ?? [];

      Map<String, Map<String, dynamic>> brandMap = {};
      try {
        final bRes = await supabase.from('brands').select('*');
        for (final b in (bRes as List<dynamic>? ?? [])) {
          final id = b['id']?.toString();
          if (id != null) brandMap[id] = b as Map<String, dynamic>;
        }
      } catch (_) {}

      Map<String, Map<String, dynamic>> techPackMap = {};
      try {
        final tpRes = await supabase.from('design_tech_packs').select('*');
        for (final tp in (tpRes as List<dynamic>? ?? [])) {
          final id = tp['id']?.toString();
          if (id != null) techPackMap[id] = tp as Map<String, dynamic>;
        }
      } catch (_) {}

      for (final ord in rawOrders) {
        final bId = ord['buyer_id']?.toString();
        final tpId = ord['tech_pack_id']?.toString();
        final brand = bId != null ? brandMap[bId] : null;
        final tp = tpId != null ? techPackMap[tpId] : null;

        if (company != null && company.isNotEmpty) {
          final target = company.toLowerCase();
          final oc = (ord['company_name']?.toString() ?? '').toLowerCase();
          final bc = (brand?['company_name']?.toString() ?? '').toLowerCase();
          final tc = (tp?['company_name']?.toString() ?? '').toLowerCase();
          final bn = (brand?['brand_name']?.toString() ?? '').toLowerCase();
          final match = oc == target || oc.contains(target) ||
                        bc == target || bc.contains(target) ||
                        tc == target || tc.contains(target) ||
                        bn == target || bn.contains(target);
          if (!match && oc.isNotEmpty) continue;
        }

        final buyerName = brand?['brand_name']?.toString() ?? ord['brand_name']?.toString() ?? 'Commercial Buyer';
        final key = buyerName.trim().toUpperCase();
        final qty = ((ord['total_quantity'] as num?) ?? 0).toInt();
        final price = ((ord['fob_price_per_piece'] as num?) ?? 12.5).toDouble();
        final styleNum = tp?['style_number']?.toString() ?? ord['style_ref']?.toString() ?? ord['order_number']?.toString();
        final styleName = tp?['category']?.toString() ?? ord['style_name']?.toString() ?? 'Garment Contract';
        final embSeq = tp?['embellishment_sequence']?.toString() ?? ord['embellishment_sequence']?.toString() ?? 'PRINT_FIRST_THEN_EMBROIDERY';
        final cutPcs = buyerCutMap[key] ?? (styleNum != null ? buyerCutMap[styleNum.trim().toUpperCase()] ?? 0 : 0);

        if (!mergedMap.containsKey(key)) {
          mergedMap[key] = PrintingBuyerContract(
            id: brand?['id']?.toString() ?? ord['buyer_id']?.toString() ?? 'buyer-${ord['id']}',
            buyerName: buyerName,
            buyerCode: brand?['brand_code']?.toString() ?? (buyerName.length >= 4 ? buyerName.substring(0, 4).toUpperCase() : 'BUYER'),
            contractedVolume: qty > 0 ? qty : 5000,
            pricePerPiece: price,
            totalContractValue: qty * price,
            linkedArticleNumber: styleNum,
            linkedArticleName: styleName,
            embellishmentSequence: embSeq,
            status: 'LINKED',
            companyName: ord['company_name']?.toString(),
            completedCutPieces: cutPcs,
          );
        } else {
          final prev = mergedMap[key]!;
          final updatedVol = prev.contractedVolume + qty;
          final updatedVal = prev.totalContractValue + (qty * price);
          mergedMap[key] = prev.copyWith(
            contractedVolume: updatedVol > prev.contractedVolume ? updatedVol : prev.contractedVolume,
            totalContractValue: updatedVal,
            linkedArticleNumber: prev.linkedArticleNumber ?? styleNum,
            linkedArticleName: prev.linkedArticleName ?? styleName,
            embellishmentSequence: prev.embellishmentSequence.isNotEmpty ? prev.embellishmentSequence : embSeq,
            completedCutPieces: cutPcs > 0 ? cutPcs : prev.completedCutPieces,
          );
        }
      }
    } catch (e) {
      debugPrint('[PrintingNotifier] Error fetching merchandising_orders: $e');
    }

    // 4. Ensure any buyer actively in printing_task_allocations is in mergedMap
    try {
      final tRes = await supabase.from('printing_task_allocations').select('buyer_id, buyer_name, article_number, article_name, company_name');
      final rawTasks = (tRes as List<dynamic>?) ?? [];
      for (final t in rawTasks) {
        if (company != null && company.isNotEmpty) {
          final c = (t['company_name']?.toString() ?? '').toLowerCase();
          final target = company.toLowerCase();
          if (c.isNotEmpty && c != target && !c.contains(target)) continue;
        }
        final bName = (t['buyer_name']?.toString() ?? '').trim();
        if (bName.isEmpty || bName.toLowerCase() == 'direct buyer') continue;
        final key = bName.toUpperCase();
        if (!mergedMap.containsKey(key)) {
          final aNum = t['article_number']?.toString();
          final cutPcs = buyerCutMap[key] ?? (aNum != null ? buyerCutMap[aNum.trim().toUpperCase()] ?? 0 : 0);
          mergedMap[key] = PrintingBuyerContract(
            id: t['buyer_id']?.toString() ?? 'buyer-${key.toLowerCase()}',
            buyerName: bName,
            buyerCode: bName.length >= 4 ? bName.substring(0, 4).toUpperCase() : 'BUY',
            contractedVolume: 6000,
            linkedArticleNumber: aNum ?? 'DEMO-101-03',
            linkedArticleName: t['article_name']?.toString() ?? 'Garment Contract',
            embellishmentSequence: 'PRINT_FIRST_THEN_EMBROIDERY',
            status: 'LINKED',
            completedCutPieces: cutPcs,
          );
        }
      }
    } catch (_) {}

    // 5. Always ensure canonical active trial buyers (Hollypop, ollywood) are present matching Web
    for (final ib in kInitialPrintingBuyers) {
      final key = ib.buyerName.toUpperCase();
      if (!mergedMap.containsKey(key)) {
        final cutPcs = buyerCutMap[key] ?? (ib.linkedArticleNumber != null ? buyerCutMap[ib.linkedArticleNumber!.trim().toUpperCase()] ?? ib.completedCutPieces : ib.completedCutPieces);
        mergedMap[key] = ib.copyWith(
          completedCutPieces: cutPcs,
        );
      }
    }

    return mergedMap.values.toList();
  }

  Future<int> _fetchUpstreamCuttingPieces(String? company) async {
    try {
      final res = await supabase
          .from('cutting_task_allocations')
          .select('completed_pieces, pieces_to_cut, status, company_name');
      final rawList = (res as List<dynamic>?) ?? [];
      int sum = 0;
      for (final r in rawList) {
        final status = r['status']?.toString();
        if (status == 'VERIFIED_COMPLETED' || status == 'COMPLETED') {
          if (company != null && company.isNotEmpty) {
            final c = (r['company_name']?.toString() ?? '').toLowerCase();
            final target = company.toLowerCase();
            if (c.isNotEmpty && c != target && !c.contains(target)) continue;
          }
          sum += ((r['completed_pieces'] ?? r['pieces_to_cut']) as num?)?.toInt() ?? 0;
        }
      }
      return sum;
    } catch (_) {
      return 0;
    }
  }

  Future<int> _fetchUpstreamEmbroideryPieces(String? company) async {
    try {
      final res = await supabase
          .from('embroidery_task_allocations')
          .select('completed_pieces, pieces_to_embroider, status, company_name');
      final rawList = (res as List<dynamic>?) ?? [];
      int sum = 0;
      for (final r in rawList) {
        final status = r['status']?.toString();
        if (status == 'VERIFIED_COMPLETED' || status == 'COMPLETED') {
          if (company != null && company.isNotEmpty) {
            final c = (r['company_name']?.toString() ?? '').toLowerCase();
            final target = company.toLowerCase();
            if (c.isNotEmpty && c != target && !c.contains(target)) continue;
          }
          sum += ((r['completed_pieces'] ?? r['pieces_to_embroider']) as num?)?.toInt() ?? 0;
        }
      }
      return sum;
    } catch (_) {
      return 0;
    }
  }

  // --- ACTIONS ---

  void setSelectedBuyerId(String id) {
    state = state.copyWith(selectedBuyerId: id);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setStatusFilter(String filter) {
    state = state.copyWith(statusFilter: filter);
  }

  void updateStrikeOffStatus(String newStatus, {String? remarks}) async {
    final updated = state.strikeOffApproval.copyWith(
      status: newStatus,
      labRemarks: remarks ?? state.strikeOffApproval.labRemarks,
      approvedAt: DateTime.now().toIso8601String(),
    );
    state = state.copyWith(strikeOffApproval: updated);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_printing_strike_off', jsonEncode(updated.toJson()));
  }

  void setAndSyncRoute(String buyerId, String routeKey) async {
    final updatedRoutes = Map<String, String>.from(state.articleRoutes);
    updatedRoutes[buyerId] = routeKey;
    state = state.copyWith(articleRoutes: updatedRoutes);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_printing_routes', jsonEncode(updatedRoutes));
  }

  Future<bool> addWorker({
    required String name,
    required String phone,
    required String password,
    required List<String> roles,
    String shift = 'GENERAL',
  }) async {
    final company = await _getResolvedCompanyFilter() ?? 'Nubira Creation';
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final phone10 = cleanPhone.length >= 10 ? cleanPhone.substring(cleanPhone.length - 10) : cleanPhone;
    final internalEmail = '$phone10@printing.nubira.local';
    
    const roleLabels = {
      'SCREEN_PRINTER': 'Screen Print Operator',
      'DTG_TECHNICIAN': 'DTG & Heat Press Technician',
      'TABLE_OPERATOR': 'Table Master / Flocking Lead',
    };
    final primaryRole = roles.map((r) => roleLabels[r] ?? r.replaceAll('_', ' ')).join(', ');

    final newWorker = PrintingWorker(
      id: 'pw-${DateTime.now().millisecondsSinceEpoch}',
      workerName: name.trim(),
      phoneNumber: phone10,
      workerEmail: internalEmail,
      roles: roles,
      role: primaryRole.isNotEmpty ? primaryRole : 'Screen Print Operator',
      shift: shift,
      status: 'ACTIVE',
      assignedPieces: 0,
      completedPieces: 0,
      companyName: company,
      createdAt: DateTime.now().toIso8601String(),
    );

    // Optimistically add to state
    final updatedList = [newWorker, ...state.workers];
    state = state.copyWith(workers: updatedList);

    // Persist locally
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_printing_workers', jsonEncode(updatedList.map((e) => e.toJson()).toList()));

    // Persist to Supabase
    try {
      await supabase.from('printing_workers').upsert({
        'worker_name': name.trim(),
        'phone_number': phone10,
        'worker_email': internalEmail,
        'roles': roles,
        'role': primaryRole,
        'shift': shift,
        'company_name': company,
        'status': 'ACTIVE',
      }, onConflict: 'phone_number');
    } catch (_) {}

    return true;
  }

  Future<bool> deleteWorker(String workerId, String phoneNumber) async {
    final updatedList = state.workers.where((w) => w.id != workerId && w.phoneNumber != phoneNumber).toList();
    state = state.copyWith(workers: updatedList);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_printing_workers', jsonEncode(updatedList.map((e) => e.toJson()).toList()));

    try {
      await supabase.from('printing_workers').delete().or('id.eq.$workerId,phone_number.eq.$phoneNumber');
    } catch (_) {}

    return true;
  }

  Future<bool> addTaskAllocation(PrintingTaskAllocation task) async {
    final company = await _getResolvedCompanyFilter() ?? 'Nubira Creation';
    final cleanTask = task.copyWith(companyName: company);

    final updatedTasks = [cleanTask, ...state.taskAllocations];
    state = state.copyWith(taskAllocations: updatedTasks);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_printing_tasks', jsonEncode(updatedTasks.map((e) => e.toJson()).toList()));

    try {
      await supabase.from('printing_task_allocations').upsert({
        'task_ref': cleanTask.taskRef,
        'buyer_id': cleanTask.buyerId,
        'buyer_name': cleanTask.buyerName,
        'article_number': cleanTask.articleNumber,
        'article_name': cleanTask.articleName,
        'worker_id': cleanTask.workerId,
        'worker_name': cleanTask.workerName,
        'worker_phone': cleanTask.workerPhone,
        'table_number': cleanTask.tableNumber,
        'pieces_to_print': cleanTask.piecesToPrint,
        'completed_pieces': cleanTask.completedPieces,
        'alloted_hours': cleanTask.allotedHours,
        'due_time': cleanTask.dueTime,
        'notes': cleanTask.notes,
        'status': cleanTask.status,
        'company_name': company,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}

    return true;
  }

  Future<bool> verifyAndDoneTask(PrintingTaskAllocation task) async {
    final updatedTasks = state.taskAllocations.map((t) {
      if (t.id == task.id || t.taskRef == task.taskRef) {
        return t.copyWith(
          status: 'VERIFIED_COMPLETED',
          completedPieces: t.piecesToPrint,
          completedAt: DateTime.now().toIso8601String(),
        );
      }
      return t;
    }).toList();

    state = state.copyWith(taskAllocations: updatedTasks);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_printing_tasks', jsonEncode(updatedTasks.map((e) => e.toJson()).toList()));

    try {
      await supabase.from('printing_task_allocations').update({
        'status': 'VERIFIED_COMPLETED',
        'completed_pieces': task.piecesToPrint,
        'completed_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).or('id.eq.${task.id},task_ref.eq.${task.taskRef}');
    } catch (_) {}

    return true;
  }

  Future<bool> deleteTaskAllocation(String taskId, String taskRef) async {
    final updatedTasks = state.taskAllocations.where((t) => t.id != taskId && t.taskRef != taskRef).toList();
    state = state.copyWith(taskAllocations: updatedTasks);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_printing_tasks', jsonEncode(updatedTasks.map((e) => e.toJson()).toList()));

    try {
      await supabase.from('printing_task_allocations').delete().or('id.eq.$taskId,task_ref.eq.$taskRef');
    } catch (_) {}

    return true;
  }
}

final printingProvider = StateNotifierProvider<PrintingNotifier, PrintingState>((ref) {
  return PrintingNotifier(ref);
});
