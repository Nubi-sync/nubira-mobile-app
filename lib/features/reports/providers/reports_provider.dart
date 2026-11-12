import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/tenant_resolver_service.dart';
import '../../../main.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/reports_models.dart';

class WorkerLedgerSummaryStats {
  final int activeWorkers;
  final int totalCompleted;
  final int totalRejected;
  final double defectRatePct;
  final String topWorkerName;
  final int topWorkerPieces;

  const WorkerLedgerSummaryStats({
    this.activeWorkers = 0,
    this.totalCompleted = 0,
    this.totalRejected = 0,
    this.defectRatePct = 0.0,
    this.topWorkerName = 'None',
    this.topWorkerPieces = 0,
  });
}

class ReportsState {
  final bool isLoading;
  final String? error;
  final String companyName;
  final ReportsData data;
  final String activeTab; // 'articles' | 'workers' | 'audit'
  final String dateFilter; // 'today' | '7days' | '30days' | 'all'
  final String articleSearch;
  final String stageFilter;
  final String workerSearch;
  final String divisionFilter;
  final String workerStatusFilter;
  final Set<String> expandedArticleIds;

  const ReportsState({
    this.isLoading = false,
    this.error,
    this.companyName = 'Apparel Factory',
    this.data = const ReportsData(),
    this.activeTab = 'articles',
    this.dateFilter = '30days',
    this.articleSearch = '',
    this.stageFilter = 'ALL',
    this.workerSearch = '',
    this.divisionFilter = 'ALL',
    this.workerStatusFilter = 'ALL',
    this.expandedArticleIds = const {},
  });

  List<ArticleReportRow> get filteredArticles {
    var list = data.articlesReport;
    final q = articleSearch.toLowerCase().trim();
    if (q.isNotEmpty) {
      list = list.where((a) {
        return a.artNo.toLowerCase().contains(q) ||
            a.description.toLowerCase().contains(q) ||
            a.buyerName.toLowerCase().contains(q) ||
            a.poNumber.toLowerCase().contains(q);
      }).toList();
    }
    if (stageFilter != 'ALL') {
      final target = stageFilter.toLowerCase();
      list = list.where((a) => a.stageStatus.toLowerCase() == target).toList();
    }
    return list;
  }

  List<WorkerPieceLedgerItem> get filteredWorkerLedger {
    var list = data.workerLedger;
    final q = workerSearch.toLowerCase().trim();
    if (q.isNotEmpty) {
      list = list.where((w) {
        return w.workerName.toLowerCase().contains(q) ||
            (w.workerPhone ?? '').contains(q) ||
            w.articleNo.toLowerCase().contains(q) ||
            w.operationName.toLowerCase().contains(q);
      }).toList();
    }
    if (divisionFilter != 'ALL') {
      final target = divisionFilter.toLowerCase();
      list = list.where((w) => w.division.toLowerCase() == target).toList();
    }
    if (workerStatusFilter != 'ALL') {
      final target = workerStatusFilter.toLowerCase();
      list = list.where((w) => w.status.toLowerCase() == target).toList();
    }
    return list;
  }

  WorkerLedgerSummaryStats get workerStats {
    final list = filteredWorkerLedger;
    final activeNames = <String>{};
    int totalCompleted = 0;
    int totalRejected = 0;
    final workerTotals = <String, int>{};

    for (final w in list) {
      if (w.workerName.isNotEmpty) activeNames.add(w.workerName);
      totalCompleted += w.completedPieces;
      totalRejected += w.rejectedPieces;
      workerTotals[w.workerName] = (workerTotals[w.workerName] ?? 0) + w.completedPieces;
    }

    final totalProcessed = totalCompleted + totalRejected;
    final defectRatePct = totalProcessed > 0
        ? double.parse(((totalRejected / totalProcessed) * 100).toStringAsFixed(1))
        : 0.0;

    String topName = 'None';
    int topPieces = 0;
    workerTotals.forEach((name, pieces) {
      if (pieces > topPieces) {
        topPieces = pieces;
        topName = name;
      }
    });

    return WorkerLedgerSummaryStats(
      activeWorkers: activeNames.length,
      totalCompleted: totalCompleted,
      totalRejected: totalRejected,
      defectRatePct: defectRatePct,
      topWorkerName: topName,
      topWorkerPieces: topPieces,
    );
  }

  List<String> get uniqueDivisions {
    final set = <String>{};
    for (final w in data.workerLedger) {
      if (w.division.isNotEmpty) set.add(w.division);
    }
    return ['ALL', ...set];
  }

  bool get isAllArticlesExpanded {
    final cur = filteredArticles;
    return cur.isNotEmpty && expandedArticleIds.length == cur.length;
  }

  ReportsState copyWith({
    bool? isLoading,
    String? error,
    bool clearError = false,
    String? companyName,
    ReportsData? data,
    String? activeTab,
    String? dateFilter,
    String? articleSearch,
    String? stageFilter,
    String? workerSearch,
    String? divisionFilter,
    String? workerStatusFilter,
    Set<String>? expandedArticleIds,
  }) {
    return ReportsState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      companyName: companyName ?? this.companyName,
      data: data ?? this.data,
      activeTab: activeTab ?? this.activeTab,
      dateFilter: dateFilter ?? this.dateFilter,
      articleSearch: articleSearch ?? this.articleSearch,
      stageFilter: stageFilter ?? this.stageFilter,
      workerSearch: workerSearch ?? this.workerSearch,
      divisionFilter: divisionFilter ?? this.divisionFilter,
      workerStatusFilter: workerStatusFilter ?? this.workerStatusFilter,
      expandedArticleIds: expandedArticleIds ?? this.expandedArticleIds,
    );
  }
}

class ReportsNotifier extends StateNotifier<ReportsState> {
  final Ref _ref;

  ReportsNotifier(this._ref) : super(const ReportsState()) {
    fetchReports();
  }

  void setActiveTab(String tab) {
    state = state.copyWith(activeTab: tab);
  }

  void setDateFilter(String filter) {
    state = state.copyWith(dateFilter: filter);
  }

  void setArticleSearch(String query) {
    state = state.copyWith(articleSearch: query);
  }

  void setStageFilter(String stage) {
    state = state.copyWith(stageFilter: stage);
  }

  void setWorkerSearch(String query) {
    state = state.copyWith(workerSearch: query);
  }

  void setDivisionFilter(String div) {
    state = state.copyWith(divisionFilter: div);
  }

  void setWorkerStatusFilter(String status) {
    state = state.copyWith(workerStatusFilter: status);
  }

  void toggleArticleExpand(String id) {
    final next = Set<String>.from(state.expandedArticleIds);
    if (next.contains(id)) {
      next.remove(id);
    } else {
      next.add(id);
    }
    state = state.copyWith(expandedArticleIds: next);
  }

  void toggleExpandAll() {
    if (state.isAllArticlesExpanded) {
      state = state.copyWith(expandedArticleIds: const {});
    } else {
      final allIds = state.filteredArticles.map((a) => a.id).toSet();
      state = state.copyWith(expandedArticleIds: allIds);
    }
  }

  Future<void> fetchReports() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final authState = _ref.read(authProvider);
      final currentUser = supabase.auth.currentUser;
      final resolvedTenant = authState.tenantProfile ??
          (currentUser != null ? await TenantResolverService.resolveUserTenant(currentUser) : null);

      final companyName = (resolvedTenant?.companyName ?? '').trim();
      final isLegacy = resolvedTenant != null
          ? resolvedTenant.isLegacyNubira
          : companyName.toLowerCase().contains('nubira');

      final targetComp = companyName.toLowerCase();

      // Safe helper for Supabase foreign relations
      String getBrandName(dynamic brandObj) {
        if (brandObj == null) return '';
        if (brandObj is List && brandObj.isNotEmpty) {
          final first = brandObj[0];
          return (first is Map && first['brand_name'] != null) ? first['brand_name'].toString() : '';
        }
        if (brandObj is Map && brandObj['brand_name'] != null) {
          return brandObj['brand_name'].toString();
        }
        return '';
      }

      // Safe query helper
      Future<List<Map<String, dynamic>>> safeQuery(Future<dynamic> query) async {
        try {
          final res = await query;
          if (res is List) {
            return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          }
          return [];
        } catch (_) {
          return [];
        }
      }

      // 1. Design tech packs
      dynamic techPacksQ = supabase
          .from('design_tech_packs')
          .select('id, style_number, category, company_name, fabric_composition, target_gsm, embellishment_sequence, cad_front_url, approval_status, created_at')
          .order('created_at', ascending: false)
          .limit(200);
      if (!isLegacy && companyName.isNotEmpty) {
        techPacksQ = techPacksQ.ilike('company_name', companyName);
      }

      // 2. Merchandising orders
      dynamic merchOrdersQ = supabase
          .from('merchandising_orders')
          .select('id, order_number, total_quantity, order_date, delivery_date, status, company_name, style_number, brands ( id, brand_name, brand_code )')
          .order('created_at', ascending: false)
          .limit(200);
      if (!isLegacy && companyName.isNotEmpty) {
        merchOrdersQ = merchOrdersQ.ilike('company_name', companyName);
      }

      // 3. Articles (legacy)
      dynamic legacyArticlesQ = supabase
          .from('articles')
          .select('id, art_no, description, is_active, size_rates')
          .order('art_no', ascending: true)
          .limit(200);
      if (!isLegacy && companyName.isNotEmpty) {
        legacyArticlesQ = legacyArticlesQ.or(
          'size_rates->>company_name.ilike.%$targetComp%,size_rates->_meta->>company_name.ilike.%$targetComp%,description.ilike.%$targetComp%',
        );
      }

      // 4. Allotments
      final allotmentsQ = supabase.from('allotments').select('id, target_qty, article_id').limit(500);

      // Execute primary catalog queries
      final primaryResults = await Future.wait([
        safeQuery(techPacksQ),
        safeQuery(merchOrdersQ),
        safeQuery(legacyArticlesQ),
        safeQuery(allotmentsQ),
      ]);

      final rawTechPacks = primaryResults[0];
      final rawMerch = primaryResults[1];
      final rawLegacyArticles = primaryResults[2];
      final rawAllotments = primaryResults[3];

      // 5. Floor Allocations
      final cuttingQ = supabase
          .from('cutting_task_allocations')
          .select('id, task_ref, buyer_name, article_number, article_name, worker_name, worker_phone, table_number, pieces_to_cut, completed_pieces, alloted_hours, due_time, status, created_at')
          .order('created_at', ascending: false)
          .limit(300);

      dynamic stitchingQ = supabase
          .from('stitching_task_allocations')
          .select('id, task_ref, lot_number, po_number, buyer_name, article_name, style_number, source_department, operation_type, machine_type, target_quantity, completed_quantity, rejected_quantity, worker_name, worker_phone, priority, status, company_name, started_at, completed_at, created_at')
          .order('created_at', ascending: false)
          .limit(300);
      if (!isLegacy && companyName.isNotEmpty) {
        stitchingQ = stitchingQ.ilike('company_name', companyName);
      }

      final printingQ = supabase
          .from('printing_task_allocations')
          .select('id, task_ref, buyer_name, article_number, article_name, worker_name, worker_phone, table_number, pieces_to_print, completed_pieces, alloted_hours, status, created_at')
          .order('created_at', ascending: false)
          .limit(300);

      final embroideryQ = supabase
          .from('embroidery_task_allocations')
          .select('id, task_ref, buyer_name, article_number, article_name, worker_name, worker_phone, machine_number, pieces_to_embroider, completed_pieces, alloted_hours, status, created_at')
          .order('created_at', ascending: false)
          .limit(300);

      dynamic washingQ = supabase
          .from('washing_task_allocations')
          .select('id, task_ref, buyer_name, article_number, article_name, worker_name, worker_phone, table_number, machine_number, pieces_to_wash, completed_pieces, wash_recipe, status, company_name, created_at')
          .order('created_at', ascending: false)
          .limit(300);
      if (!isLegacy && companyName.isNotEmpty) {
        washingQ = washingQ.ilike('company_name', companyName);
      }

      dynamic ironQ = supabase
          .from('iron_task_allocations')
          .select('id, task_ref, buyer_name, article_number, article_name, worker_name, worker_phone, table_number, pieces_to_iron, completed_pieces, iron_temp_c, status, company_name, created_at')
          .order('created_at', ascending: false)
          .limit(300);
      if (!isLegacy && companyName.isNotEmpty) {
        ironQ = ironQ.ilike('company_name', companyName);
      }

      // 6. Legacy logs & challans
      final legacyArticleIds = rawLegacyArticles.map((a) => a['id']?.toString()).whereType<String>().toList();

      dynamic dailyProdQ;
      dynamic qcQ;
      dynamic storeQ;
      dynamic dispatchQ;

      if (isLegacy) {
        dailyProdQ = supabase
            .from('daily_product')
            .select('id, quantity, entry_date, created_at, article_id, lineman:profiles!daily_product_lineman_id_fkey(username, phone), article:articles(art_no, description)')
            .order('entry_date', ascending: false)
            .limit(800);
        qcQ = supabase
            .from('qc_logs')
            .select('id, qty_passed, qty_rejected, defect_type, entry_date, created_at, article_id, lineman:profiles!qc_logs_from_lineman_id_fkey(username, phone), article:articles(art_no, description)')
            .order('entry_date', ascending: false)
            .limit(800);
        storeQ = supabase
            .from('store_transactions')
            .select('id, type, quantity, entry_date, created_at, party_name, article_id, article:articles(art_no, description)')
            .order('created_at', ascending: false)
            .limit(800);
        dispatchQ = supabase
            .from('delivery_challans')
            .select('id, challan_no, buyer_name, total_pieces, destination, status, created_at')
            .order('created_at', ascending: false)
            .limit(300);
      } else {
        if (legacyArticleIds.isNotEmpty) {
          dailyProdQ = supabase
              .from('daily_product')
              .select('id, quantity, entry_date, created_at, article_id, lineman:profiles!daily_product_lineman_id_fkey(username, phone), article:articles(art_no, description)')
              .inFilter('article_id', legacyArticleIds)
              .order('entry_date', ascending: false)
              .limit(800);
          qcQ = supabase
              .from('qc_logs')
              .select('id, qty_passed, qty_rejected, defect_type, entry_date, created_at, article_id, lineman:profiles!qc_logs_from_lineman_id_fkey(username, phone), article:articles(art_no, description)')
              .inFilter('article_id', legacyArticleIds)
              .order('entry_date', ascending: false)
              .limit(800);
          storeQ = supabase
              .from('store_transactions')
              .select('id, type, quantity, entry_date, created_at, party_name, article_id, article:articles(art_no, description)')
              .inFilter('article_id', legacyArticleIds)
              .order('created_at', ascending: false)
              .limit(800);
        } else {
          dailyProdQ = Future.value(<Map<String, dynamic>>[]);
          qcQ = Future.value(<Map<String, dynamic>>[]);
          storeQ = Future.value(<Map<String, dynamic>>[]);
        }
        dispatchQ = supabase
            .from('delivery_challans')
            .select('id, challan_no, buyer_name, total_pieces, destination, status, created_at')
            .ilike('buyer_name', '%$targetComp%')
            .order('created_at', ascending: false)
            .limit(300);
      }

      // Execute floor & log queries in parallel
      final secondaryResults = await Future.wait([
        safeQuery(cuttingQ),
        safeQuery(stitchingQ),
        safeQuery(printingQ),
        safeQuery(embroideryQ),
        safeQuery(washingQ),
        safeQuery(ironQ),
        safeQuery(dailyProdQ),
        safeQuery(qcQ),
        safeQuery(storeQ),
        safeQuery(dispatchQ),
      ]);

      final rawCutting = secondaryResults[0];
      final rawStitching = secondaryResults[1];
      final rawPrinting = secondaryResults[2];
      final rawEmbroidery = secondaryResults[3];
      final rawWashing = secondaryResults[4];
      final rawIron = secondaryResults[5];
      final rawProd = secondaryResults[6];
      final rawQc = secondaryResults[7];
      final rawStore = secondaryResults[8];
      final rawDispatch = secondaryResults[9];

      // 7. Consolidate Worker Piece Ledger
      final workerLedger = <WorkerPieceLedgerItem>[];

      for (final c in rawCutting) {
        workerLedger.add(WorkerPieceLedgerItem(
          id: 'cut-${c['id']}',
          workerName: c['worker_name']?.toString() ?? 'Knife Cutter',
          workerPhone: c['worker_phone']?.toString(),
          role: 'Knife Cutter',
          division: 'Cutting Floor',
          divisionRoute: '/cutting',
          articleNo: c['article_number']?.toString() ?? 'Style',
          articleName: c['article_name']?.toString() ?? c['article_number']?.toString() ?? 'Garment Component',
          buyerName: c['buyer_name']?.toString(),
          operationName: 'Lay Cutting (${c['task_ref'] ?? 'Ref'})',
          workstationRef: c['table_number']?.toString() ?? 'Cutting Table 01',
          targetPieces: (c['pieces_to_cut'] as num?)?.toInt() ?? 0,
          completedPieces: (c['completed_pieces'] as num?)?.toInt() ?? 0,
          rejectedPieces: 0,
          status: c['status']?.toString() ?? 'ASSIGNED',
          date: (c['created_at']?.toString() ?? '').split('T').first,
        ));
      }

      for (final s in rawStitching) {
        workerLedger.add(WorkerPieceLedgerItem(
          id: 'stitch-${s['id']}',
          workerName: s['worker_name']?.toString() ?? 'Tailor',
          workerPhone: s['worker_phone']?.toString(),
          role: 'Tailor Specialist',
          division: 'Stitching & Sewing',
          divisionRoute: '/stitching-sewing',
          articleNo: s['style_number']?.toString() ?? s['article_name']?.toString() ?? 'Style',
          articleName: s['article_name']?.toString() ?? s['style_number']?.toString() ?? 'Garment Assembly',
          buyerName: s['buyer_name']?.toString(),
          operationName: s['operation_type']?.toString() ?? 'Full Garment Assembly',
          workstationRef: s['machine_type']?.toString() ?? 'Lockstitch (SNLS)',
          targetPieces: (s['target_quantity'] as num?)?.toInt() ?? 0,
          completedPieces: (s['completed_quantity'] as num?)?.toInt() ?? 0,
          rejectedPieces: (s['rejected_quantity'] as num?)?.toInt() ?? 0,
          status: s['status']?.toString() ?? 'ASSIGNED',
          date: (s['created_at']?.toString() ?? '').split('T').first,
        ));
      }

      for (final p in rawPrinting) {
        workerLedger.add(WorkerPieceLedgerItem(
          id: 'print-${p['id']}',
          workerName: p['worker_name']?.toString() ?? 'Screen Printer',
          workerPhone: p['worker_phone']?.toString(),
          role: 'Screen Print Master',
          division: 'Printing Unit',
          divisionRoute: '/printing',
          articleNo: p['article_number']?.toString() ?? 'Style',
          articleName: p['article_name']?.toString() ?? 'Printed Panel',
          buyerName: p['buyer_name']?.toString(),
          operationName: 'Screen & Placement Print',
          workstationRef: p['table_number']?.toString() ?? 'Print Table 01',
          targetPieces: (p['pieces_to_print'] as num?)?.toInt() ?? 0,
          completedPieces: (p['completed_pieces'] as num?)?.toInt() ?? 0,
          rejectedPieces: 0,
          status: p['status']?.toString() ?? 'ASSIGNED',
          date: (p['created_at']?.toString() ?? '').split('T').first,
        ));
      }

      for (final e in rawEmbroidery) {
        workerLedger.add(WorkerPieceLedgerItem(
          id: 'emb-${e['id']}',
          workerName: e['worker_name']?.toString() ?? 'Embroidery Operator',
          workerPhone: e['worker_phone']?.toString(),
          role: 'Machine Operator',
          division: 'Embroidery Unit',
          divisionRoute: '/embroidery',
          articleNo: e['article_number']?.toString() ?? 'Style',
          articleName: e['article_name']?.toString() ?? 'Embroidered Artwork',
          buyerName: e['buyer_name']?.toString(),
          operationName: 'Multi-Head Embroidery Run',
          workstationRef: e['machine_number']?.toString() ?? 'Embroidery Machine 01',
          targetPieces: (e['pieces_to_embroider'] as num?)?.toInt() ?? 0,
          completedPieces: (e['completed_pieces'] as num?)?.toInt() ?? 0,
          rejectedPieces: 0,
          status: e['status']?.toString() ?? 'ASSIGNED',
          date: (e['created_at']?.toString() ?? '').split('T').first,
        ));
      }

      for (final w in rawWashing) {
        workerLedger.add(WorkerPieceLedgerItem(
          id: 'wash-${w['id']}',
          workerName: w['worker_name']?.toString() ?? 'Wash Master',
          workerPhone: w['worker_phone']?.toString(),
          role: 'Wash Master',
          division: 'Washing Plant',
          divisionRoute: '/washing',
          articleNo: w['article_number']?.toString() ?? 'Style',
          articleName: w['article_name']?.toString() ?? 'Wash Batch',
          buyerName: w['buyer_name']?.toString(),
          operationName: w['wash_recipe']?.toString() ?? 'Enzyme Wash',
          workstationRef: w['machine_number']?.toString() ?? w['table_number']?.toString() ?? 'Tumbler Washer 01',
          targetPieces: (w['pieces_to_wash'] as num?)?.toInt() ?? 0,
          completedPieces: (w['completed_pieces'] as num?)?.toInt() ?? 0,
          rejectedPieces: 0,
          status: w['status']?.toString() ?? 'ASSIGNED',
          date: (w['created_at']?.toString() ?? '').split('T').first,
        ));
      }

      for (final i in rawIron) {
        workerLedger.add(WorkerPieceLedgerItem(
          id: 'iron-${i['id']}',
          workerName: i['worker_name']?.toString() ?? 'Steam Ironer',
          workerPhone: i['worker_phone']?.toString(),
          role: 'Steam Press Operator',
          division: 'Ironing & Finishing',
          divisionRoute: '/iron',
          articleNo: i['article_number']?.toString() ?? 'Style',
          articleName: i['article_name']?.toString() ?? 'Steam Pressed Unit',
          buyerName: i['buyer_name']?.toString(),
          operationName: 'Steam Press & Fold (${i['iron_temp_c'] ?? 150}C)',
          workstationRef: i['table_number']?.toString() ?? 'Vacuum Table 01',
          targetPieces: (i['pieces_to_iron'] as num?)?.toInt() ?? 0,
          completedPieces: (i['completed_pieces'] as num?)?.toInt() ?? 0,
          rejectedPieces: 0,
          status: i['status']?.toString() ?? 'ASSIGNED',
          date: (i['created_at']?.toString() ?? '').split('T').first,
        ));
      }

      for (final p in rawProd) {
        final lineman = p['lineman'] is Map ? p['lineman'] as Map : null;
        final art = p['article'] is Map ? p['article'] as Map : null;
        final qty = (p['quantity'] as num?)?.toInt() ?? 0;
        final dStr = (p['entry_date']?.toString() ?? p['created_at']?.toString() ?? '').split('T').first;

        workerLedger.add(WorkerPieceLedgerItem(
          id: 'prod-${p['id']}',
          workerName: lineman?['username']?.toString() ?? 'Tailor',
          workerPhone: lineman?['phone']?.toString(),
          role: 'Floor Tailor',
          division: 'Stitching & Sewing',
          divisionRoute: '/stitching-sewing',
          articleNo: art?['art_no']?.toString() ?? 'Art',
          articleName: art?['description']?.toString() ?? 'Garment Style',
          buyerName: null,
          operationName: 'Line Assembly Unit',
          workstationRef: 'Floor Line 01',
          targetPieces: qty,
          completedPieces: qty,
          rejectedPieces: 0,
          status: 'COMPLETED',
          date: dStr.isNotEmpty ? dStr : 'Today',
        ));
      }

      workerLedger.sort((a, b) => b.date.compareTo(a.date));

      // 8. Build Article Catalog & Pipeline
      final articlesMap = <String, Map<String, dynamic>>{};

      for (final tp in rawTechPacks) {
        final sn = tp['style_number']?.toString().trim();
        if (sn == null || sn.isEmpty) continue;
        final key = sn.toUpperCase();
        articlesMap[key] = {
          'id': tp['id']?.toString() ?? '',
          'artNo': sn,
          'description': tp['category']?.toString() ?? 'Tech-Pack Garment',
          'buyerName': '',
          'poNumber': '',
          'targetPcs': 0,
        };
      }

      for (final mo in rawMerch) {
        final sn = (mo['style_number']?.toString() ?? mo['order_number']?.toString() ?? '').trim();
        if (sn.isEmpty) continue;
        final key = sn.toUpperCase();
        final buyer = getBrandName(mo['brands']);
        final buyerName = buyer.isNotEmpty ? buyer : 'Direct Buyer';
        final poNumber = mo['order_number']?.toString() ?? 'PO';
        final qty = (mo['total_quantity'] as num?)?.toInt() ?? 0;

        if (articlesMap.containsKey(key)) {
          final cur = articlesMap[key]!;
          cur['buyerName'] = buyerName;
          cur['poNumber'] = poNumber;
          cur['targetPcs'] = ((cur['targetPcs'] as int?) ?? 0) > qty ? cur['targetPcs'] : qty;
        } else {
          articlesMap[key] = {
            'id': mo['id']?.toString() ?? '',
            'artNo': sn,
            'description': '$buyerName Order',
            'buyerName': buyerName,
            'poNumber': poNumber,
            'targetPcs': qty,
          };
        }
      }

      for (final art in rawLegacyArticles) {
        final artNo = art['art_no']?.toString().trim();
        if (artNo == null || artNo.isEmpty) continue;
        final key = artNo.toUpperCase();
        final artId = art['id']?.toString();

        final allotmentTarget = rawAllotments
            .where((a) => a['article_id']?.toString() == artId)
            .fold<int>(0, (s, a) => s + ((a['target_qty'] as num?)?.toInt() ?? 0));

        if (!articlesMap.containsKey(key)) {
          articlesMap[key] = {
            'id': artId ?? '',
            'artNo': artNo,
            'description': art['description']?.toString() ?? 'Legacy Article',
            'buyerName': 'Direct Buyer',
            'poNumber': 'PO-$artNo',
            'targetPcs': allotmentTarget,
          };
        }
      }

      final articlesReport = <ArticleReportRow>[];

      for (final meta in articlesMap.values) {
        final artId = meta['id'] as String;
        final artNo = meta['artNo'] as String;
        final artNoLower = artNo.toLowerCase();

        final matchedAllocations = workerLedger.where((item) {
          final wArt = item.articleNo.toLowerCase();
          final wName = item.articleName.toLowerCase();
          return wArt == artNoLower || wName.contains(artNoLower);
        }).toList();

        final cutPcs = matchedAllocations
            .where((a) => a.divisionRoute == '/cutting')
            .fold<int>(0, (s, a) => s + a.completedPieces);

        final printEmbPcs = matchedAllocations
            .where((a) => a.divisionRoute == '/printing' || a.divisionRoute == '/embroidery')
            .fold<int>(0, (s, a) => s + a.completedPieces);

        int stitchedPcs = matchedAllocations
            .where((a) => a.divisionRoute == '/stitching-sewing')
            .fold<int>(0, (s, a) => s + a.completedPieces);

        if (stitchedPcs == 0) {
          stitchedPcs = rawProd.where((p) {
            final art = p['article'] is Map ? p['article'] as Map : null;
            return (art?['art_no']?.toString() ?? '').toLowerCase() == artNoLower ||
                p['article_id']?.toString() == artId;
          }).fold<int>(0, (s, p) => s + ((p['quantity'] as num?)?.toInt() ?? 0));
        }

        final washedPcs = matchedAllocations
            .where((a) => a.divisionRoute == '/washing')
            .fold<int>(0, (s, a) => s + a.completedPieces);

        final ironedPcs = matchedAllocations
            .where((a) => a.divisionRoute == '/iron')
            .fold<int>(0, (s, a) => s + a.completedPieces);

        // QC inspection
        final artQc = rawQc.where((q) {
          final art = q['article'] is Map ? q['article'] as Map : null;
          return (art?['art_no']?.toString() ?? '').toLowerCase() == artNoLower ||
              q['article_id']?.toString() == artId;
        }).toList();

        final qcPassedPcs = artQc.fold<int>(0, (s, q) => s + ((q['qty_passed'] as num?)?.toInt() ?? 0));
        final qcFailedPcs = artQc.fold<int>(0, (s, q) => s + ((q['qty_rejected'] as num?)?.toInt() ?? 0));
        final totalQc = qcPassedPcs + qcFailedPcs;
        final qcRejectRatePct =
            totalQc > 0 ? double.parse(((qcFailedPcs / totalQc) * 100).toStringAsFixed(1)) : 0.0;

        // Warehouse Stock
        final artStore = rawStore.where((tx) {
          final art = tx['article'] is Map ? tx['article'] as Map : null;
          return (art?['art_no']?.toString() ?? '').toLowerCase() == artNoLower ||
              tx['article_id']?.toString() == artId;
        }).toList();

        int godownPcs = 0;
        for (final tx in artStore) {
          final q = (tx['quantity'] as num?)?.toInt() ?? 0;
          if (tx['type'] == 'INWARD') godownPcs += q;
          if (tx['type'] == 'OUTWARD') godownPcs -= q;
        }
        if (godownPcs < 0) godownPcs = 0;

        // Dispatches
        final buyerLower = (meta['buyerName'] as String? ?? '').toLowerCase();
        final dispatchedPcs = rawDispatch
            .where((d) => (d['buyer_name']?.toString() ?? '').toLowerCase() == buyerLower)
            .fold<int>(0, (s, d) => s + ((d['total_pieces'] as num?)?.toInt() ?? 0));

        final target = (meta['targetPcs'] as int?) ?? 0;
        final effectiveTarget = target > 0 ? target : [cutPcs, stitchedPcs, qcPassedPcs, 100].reduce((a, b) => a > b ? a : b);
        final maxStage = [cutPcs, stitchedPcs, qcPassedPcs, ironedPcs, godownPcs].reduce((a, b) => a > b ? a : b);
        final progressPct = effectiveTarget > 0 ? ((maxStage / effectiveTarget) * 100).round().clamp(0, 100) : 0;

        String stageStatus = 'Scheduled';
        if (dispatchedPcs >= effectiveTarget && effectiveTarget > 0) {
          stageStatus = 'Dispatched';
        } else if (godownPcs > 0) {
          stageStatus = 'In Godown';
        } else if (qcPassedPcs > 0) {
          stageStatus = 'QC Passed';
        } else if (ironedPcs > 0) {
          stageStatus = 'In Ironing';
        } else if (washedPcs > 0) {
          stageStatus = 'In Washing';
        } else if (stitchedPcs > 0) {
          stageStatus = 'In Stitching';
        } else if (printEmbPcs > 0) {
          stageStatus = 'In Embellishment';
        } else if (cutPcs > 0) {
          stageStatus = 'In Cutting';
        }

        final operations = matchedAllocations.map((a) {
          return ArticleWorkerOperation(
            id: a.id,
            division: a.division,
            divisionRoute: a.divisionRoute,
            workerName: a.workerName,
            workerPhone: a.workerPhone,
            operation: a.operationName,
            workstation: a.workstationRef,
            targetPcs: a.targetPieces,
            completedPcs: a.completedPieces,
            rejectedPcs: a.rejectedPieces,
            status: a.status,
            timestamp: a.date,
          );
        }).toList();

        articlesReport.add(ArticleReportRow(
          id: artId,
          artNo: artNo,
          description: meta['description'] as String,
          buyerName: meta['buyerName'] as String? ?? 'Direct Buyer',
          poNumber: meta['poNumber'] as String? ?? 'PO-$artNo',
          targetPcs: effectiveTarget,
          cutPcs: cutPcs,
          printEmbPcs: printEmbPcs,
          stitchedPcs: stitchedPcs,
          washedPcs: washedPcs,
          ironedPcs: ironedPcs,
          qcPassedPcs: qcPassedPcs,
          qcFailedPcs: qcFailedPcs,
          qcRejectRatePct: qcRejectRatePct,
          godownPcs: godownPcs,
          dispatchedPcs: dispatchedPcs,
          progressPct: progressPct,
          stageStatus: stageStatus,
          operations: operations,
        ));
      }

      articlesReport.sort((a, b) => b.targetPcs.compareTo(a.targetPcs));

      // 9. Macro KPIs & 14-Day Production Trend
      final totalProduced = workerLedger.fold<int>(0, (s, w) => s + w.completedPieces);
      final totalPassedQc = articlesReport.fold<int>(0, (s, a) => s + a.qcPassedPcs);
      final totalFailedQc = articlesReport.fold<int>(0, (s, a) => s + a.qcFailedPcs);
      final totalAuditedQc = totalPassedQc + totalFailedQc;
      final qcPassRate = totalAuditedQc > 0
          ? double.parse(((totalPassedQc / totalAuditedQc) * 100).toStringAsFixed(1))
          : 100.0;
      final netWarehouseStock = articlesReport.fold<int>(0, (s, a) => s + a.godownPcs);
      final totalDispatched = rawDispatch.fold<int>(0, (s, d) => s + ((d['total_pieces'] as num?)?.toInt() ?? 0));

      final kpis = ReportKpis(
        totalProduced: totalProduced,
        qcPassRate: qcPassRate,
        netWarehouseStock: netWarehouseStock,
        totalDispatched: totalDispatched,
      );

      final dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
      final prodTrendMap = <String, int>{};
      final qcTrendMap = <String, Map<String, int>>{};

      for (final w in workerLedger) {
        if (w.date.isEmpty) continue;
        prodTrendMap[w.date] = (prodTrendMap[w.date] ?? 0) + w.completedPieces;
      }

      for (final q in rawQc) {
        final dStr = (q['entry_date']?.toString() ?? q['created_at']?.toString() ?? '').split('T').first;
        if (dStr.isEmpty) continue;
        final cur = qcTrendMap[dStr] ?? {'passed': 0, 'rejected': 0};
        cur['passed'] = (cur['passed'] ?? 0) + ((q['qty_passed'] as num?)?.toInt() ?? 0);
        cur['rejected'] = (cur['rejected'] ?? 0) + ((q['qty_rejected'] as num?)?.toInt() ?? 0);
        qcTrendMap[dStr] = cur;
      }

      final productionTrend = <ProductionTrendPoint>[];
      final qcTrend = <QcTrendPoint>[];
      int sumTrendPcs = 0;

      final now = DateTime.now();
      for (int i = 13; i >= 0; i--) {
        final d = now.subtract(Duration(days: i));
        final dStr = '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        final label = '${dayNames[d.weekday % 7]} ${d.day}';

        final pcs = prodTrendMap[dStr] ?? 0;
        sumTrendPcs += pcs;
        productionTrend.add(ProductionTrendPoint(date: dStr, label: label, pieces: pcs));

        final qEntry = qcTrendMap[dStr] ?? {'passed': 0, 'rejected': 0};
        final p = qEntry['passed'] ?? 0;
        final r = qEntry['rejected'] ?? 0;
        final tot = p + r;
        final pr = tot > 0 ? double.parse(((p / tot) * 100).toStringAsFixed(1)) : 100.0;
        qcTrend.add(QcTrendPoint(date: dStr, label: label, passed: p, rejected: r, passRate: pr));
      }

      final dailyAverage = (sumTrendPcs / (productionTrend.isNotEmpty ? productionTrend.length : 1)).round();

      // 10. Division Performance Scorecards
      final defaultDivs = [
        {'name': 'Cutting Floor', 'route': '/cutting'},
        {'name': 'Printing Unit', 'route': '/printing'},
        {'name': 'Embroidery Unit', 'route': '/embroidery'},
        {'name': 'Stitching & Sewing', 'route': '/stitching-sewing'},
        {'name': 'Washing Plant', 'route': '/washing'},
        {'name': 'Ironing & Finishing', 'route': '/iron'},
        {'name': 'QC Audit', 'route': '/modules'},
        {'name': 'Warehouse / Godown', 'route': '/store'},
        {'name': 'Dispatch Bay', 'route': '/dispatch'},
      ];

      final divWorkerMap = <String, Set<String>>{};
      final divOutputMap = <String, int>{};

      for (final d in defaultDivs) {
        final n = d['name']!;
        divWorkerMap[n] = <String>{};
        divOutputMap[n] = 0;
      }

      for (final w in workerLedger) {
        if (divWorkerMap.containsKey(w.division)) {
          divWorkerMap[w.division]!.add(w.workerName);
          divOutputMap[w.division] = (divOutputMap[w.division] ?? 0) + w.completedPieces;
        }
      }

      final divisionComparison = defaultDivs.map((d) {
        final n = d['name']!;
        final route = d['route']!;
        final wCount = divWorkerMap[n]?.length ?? 0;
        final output = divOutputMap[n] ?? 0;
        final score = output > 0 ? ((output / 500) * 100).round().clamp(0, 100) : 0;

        String metricLabel = '$output pcs output';
        if (n == 'QC Audit') {
          metricLabel = '$qcPassRate% pass rate ($totalAuditedQc audited)';
        } else if (n == 'Warehouse / Godown') {
          metricLabel = '$netWarehouseStock in stock';
        } else if (n == 'Dispatch Bay') {
          metricLabel = '$totalDispatched shipped';
        }

        return DivisionScorePoint(
          division: n,
          divisionRoute: route,
          score: score,
          metricLabel: metricLabel,
          workerCount: wCount,
          totalOutput: output,
        );
      }).toList();

      // 11. Buyer PO Fulfillment & Dispatch Audit
      final buyerFulfillments = rawMerch.map((m) {
        final target = (m['total_quantity'] as num?)?.toInt() ?? 0;
        final buyer = getBrandName(m['brands']);
        final buyerName = buyer.isNotEmpty ? buyer : 'Direct Buyer';
        final po = m['order_number']?.toString() ?? 'PO';

        final matchingChallans = rawDispatch.where((d) {
          final b = (d['buyer_name']?.toString() ?? '').toLowerCase();
          return b.contains(buyerName.toLowerCase());
        }).toList();

        final delivered = matchingChallans.fold<int>(0, (s, d) => s + ((d['total_pieces'] as num?)?.toInt() ?? 0));
        final challanNumbers = matchingChallans
            .map((d) => d['challan_no']?.toString())
            .whereType<String>()
            .toList();

        final pct = target > 0 ? ((delivered / target) * 100).round().clamp(0, 100) : 0;

        String status = 'In Production';
        if (pct >= 100) {
          status = 'Fully Shipped';
        } else if (delivered > 0) {
          status = 'Partially Dispatched';
        }

        final delivDateStr = m['delivery_date']?.toString() ?? 'N/A';
        final isOverdue = pct < 100 &&
            delivDateStr != 'N/A' &&
            (DateTime.tryParse(delivDateStr)?.isBefore(DateTime.now()) ?? false);

        return BuyerFulfillmentItem(
          poNumber: po,
          buyerName: buyerName,
          orderDate: m['order_date']?.toString() ?? 'N/A',
          deliveryDate: delivDateStr,
          targetPieces: target,
          deliveredPieces: delivered,
          godownPieces: (target - delivered).clamp(0, target),
          challanNumbers: challanNumbers,
          percent: pct,
          isOverdue: isOverdue,
          status: status,
        );
      }).toList();

      final reportsData = ReportsData(
        companyName: companyName.isNotEmpty ? companyName : 'Apparel Factory',
        allowedDivisions: resolvedTenant?.allowedDivisions ?? const [],
        kpis: kpis,
        productionTrend: productionTrend,
        dailyAverage: dailyAverage,
        qcTrend: qcTrend,
        articlesReport: articlesReport,
        workerLedger: workerLedger,
        divisionComparison: divisionComparison,
        buyerFulfillments: buyerFulfillments,
        generatedAt: '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      );

      state = state.copyWith(
        isLoading: false,
        companyName: companyName.isNotEmpty ? companyName : 'Apparel Factory',
        data: reportsData,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }
}

final reportsProvider = StateNotifierProvider<ReportsNotifier, ReportsState>((ref) {
  return ReportsNotifier(ref);
});

