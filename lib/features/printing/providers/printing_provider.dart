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

    // 1. Load from local cache, filtering out legacy dummy seed data
    try {
      final cachedWorkers = prefs.getString('cached_printing_workers');
      final cachedTasks = prefs.getString('cached_printing_tasks');
      final cachedBuyers = prefs.getString('cached_printing_buyers');
      final cachedRoutes = prefs.getString('cached_printing_routes');
      final cachedStrikeOff = prefs.getString('cached_printing_strike_off');

      List<PrintingWorker> workers = [];
      List<PrintingTaskAllocation> tasks = [];
      List<PrintingBuyerContract> buyers = [];
      Map<String, String> routes = {};
      StrikeOffApproval strikeOff = const StrikeOffApproval(
        status: 'APPROVED',
        labRemarks: 'Lab color fastness & swatch shade sign-off',
      );

      if (cachedWorkers != null) {
        final decoded = jsonDecode(cachedWorkers) as List;
        workers = decoded
            .map((e) => PrintingWorker.fromJson(e))
            .where((w) => w.id != 'pw-101' && w.id != 'pw-102' && w.id != 'pw-103')
            .toList();
      }
      if (cachedTasks != null) {
        final decoded = jsonDecode(cachedTasks) as List;
        tasks = decoded
            .map((e) => PrintingTaskAllocation.fromJson(e))
            .where((t) => t.id != 'task-prn-01' && t.id != 'task-prn-02')
            .toList();
      }
      if (cachedBuyers != null) {
        final decoded = jsonDecode(cachedBuyers) as List;
        buyers = decoded
            .map((e) => PrintingBuyerContract.fromJson(e))
            .where((b) => b.id != 'byr-01' && b.id != 'byr-02' && b.id != 'byr-03')
            .toList();
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

    // 2. Fetch live data from Supabase backend (exact mirror of Web)
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

      final freshWorkers = results[0] as List<PrintingWorker>;
      final freshTasks = results[1] as List<PrintingTaskAllocation>;
      final freshBuyers = results[2] as List<PrintingBuyerContract>;
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
        upstreamCutPieces: upstreamCut,
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
      return mapped;
    } catch (e) {
      debugPrint('[PrintingNotifier] _fetchWorkersFromSupabase error: $e');
      return [];
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
      return mapped;
    } catch (e) {
      debugPrint('[PrintingNotifier] _fetchTasksFromSupabase error: $e');
      return [];
    }
  }

  Future<List<PrintingBuyerContract>> _fetchBuyersFromSupabase(String? company) async {
    List<PrintingBuyerContract> buyersList = [];

    // 1. Fetch from merchandising_active_buyers
    try {
      final res = await supabase
          .from('merchandising_active_buyers')
          .select('*')
          .order('created_at', ascending: false);
      final raw = (res as List<dynamic>?) ?? [];
      if (raw.isNotEmpty) {
        var mapped = raw.map((e) => PrintingBuyerContract.fromJson(e as Map<String, dynamic>)).toList();
        if (company != null && company.isNotEmpty) {
          final target = company.toLowerCase();
          mapped = mapped.where((b) {
            final c = (b.buyerName).toLowerCase();
            return c == target || c.contains(target);
          }).toList();
        }
        buyersList = mapped;
      }
    } catch (_) {}

    // 2. Fetch master merchandising orders (same as Web fetchActiveBuyersAction)
    try {
      final oRes = await supabase
          .from('merchandising_orders')
          .select('''
            id,
            order_number,
            total_quantity,
            fob_price_per_piece,
            status,
            company_name,
            created_at,
            brands ( id, brand_name, brand_code, company_name ),
            design_tech_packs ( id, style_number, category, embellishment_sequence, company_name )
          ''')
          .order('created_at', ascending: false);

      final rawOrders = (oRes as List<dynamic>?) ?? [];
      if (rawOrders.isNotEmpty) {
        var filteredOrders = rawOrders;
        if (company != null && company.isNotEmpty) {
          final target = company.toLowerCase();
          filteredOrders = rawOrders.where((ord) {
            final oc = (ord['company_name']?.toString() ?? '').toLowerCase();
            final brand = ord['brands'] as Map<String, dynamic>?;
            final bc = (brand?['company_name']?.toString() ?? '').toLowerCase();
            final bn = (brand?['brand_name']?.toString() ?? '').toLowerCase();
            final tp = ord['design_tech_packs'] as Map<String, dynamic>?;
            final tc = (tp?['company_name']?.toString() ?? '').toLowerCase();
            return oc == target || oc.contains(target) ||
                   bc == target || bc.contains(target) ||
                   tc == target || tc.contains(target) ||
                   bn == target || bn.contains(target);
          }).toList();
        }

        final orderBuyersMap = <String, PrintingBuyerContract>{};
        for (final ord in filteredOrders) {
          final brand = ord['brands'] as Map<String, dynamic>?;
          final tp = ord['design_tech_packs'] as Map<String, dynamic>?;
          final buyerName = brand?['brand_name']?.toString() ?? 'Commercial Buyer';
          final buyerKey = buyerName.trim().toUpperCase();
          final qty = ((ord['total_quantity'] as num?) ?? 0).toInt();
          final price = ((ord['fob_price_per_piece'] as num?) ?? 12.5).toDouble();

          if (!orderBuyersMap.containsKey(buyerKey)) {
            orderBuyersMap[buyerKey] = PrintingBuyerContract(
              id: brand?['id']?.toString() ?? 'buyer-${ord['id']}',
              buyerName: buyerName,
              buyerCode: brand?['brand_code']?.toString() ?? (buyerName.length >= 4 ? buyerName.substring(0, 4).toUpperCase() : 'BUYER'),
              contractedVolume: qty,
              pricePerPiece: price,
              totalContractValue: (qty * price),
              linkedArticleNumber: tp?['style_number']?.toString() ?? ord['order_number']?.toString() ?? 'DEMO-102',
              linkedArticleName: tp?['category']?.toString() ?? 'Garment Contract',
              embellishmentSequence: tp?['embellishment_sequence']?.toString() ?? 'PRINT_FIRST_THEN_EMBROIDERY',
              status: 'LINKED',
            );
          } else {
            final prev = orderBuyersMap[buyerKey]!;
            final updatedVol = prev.contractedVolume + qty;
            final updatedVal = prev.totalContractValue + (qty * price);
            orderBuyersMap[buyerKey] = prev.copyWith(
              contractedVolume: updatedVol,
              totalContractValue: updatedVal,
              linkedArticleNumber: prev.linkedArticleNumber ?? tp?['style_number']?.toString(),
              linkedArticleName: prev.linkedArticleName ?? tp?['category']?.toString(),
            );
          }
        }

        // Merge order-derived buyers into buyersList
        orderBuyersMap.forEach((key, ordBuyer) {
          final idx = buyersList.indexWhere((b) => b.buyerName.trim().toUpperCase() == key);
          if (idx >= 0) {
            final existing = buyersList[idx];
            buyersList[idx] = existing.copyWith(
              contractedVolume: ordBuyer.contractedVolume > existing.contractedVolume ? ordBuyer.contractedVolume : existing.contractedVolume,
              linkedArticleNumber: existing.linkedArticleNumber ?? ordBuyer.linkedArticleNumber,
              linkedArticleName: existing.linkedArticleName ?? ordBuyer.linkedArticleName,
              embellishmentSequence: existing.embellishmentSequence.isNotEmpty ? existing.embellishmentSequence : ordBuyer.embellishmentSequence,
            );
          } else {
            buyersList.add(ordBuyer);
          }
        });
      }
    } catch (e) {
      debugPrint('[PrintingNotifier] _fetchBuyersFromSupabase orders error: $e');
    }

    return buyersList;
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
    String shift = 'MORNING',
  }) async {
    final company = await _getResolvedCompanyFilter() ?? 'Nubira Creation';
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final phone10 = cleanPhone.length >= 10 ? cleanPhone.substring(cleanPhone.length - 10) : cleanPhone;
    final internalEmail = '$phone10@printing.nubira.local';
    final primaryRole = roles.isNotEmpty ? roles.first.replaceAll('_', ' ') : 'Screen Printer';

    final newWorker = PrintingWorker(
      id: 'pw-${DateTime.now().millisecondsSinceEpoch}',
      workerName: name.trim(),
      phoneNumber: phone10,
      workerEmail: internalEmail,
      roles: roles,
      role: primaryRole,
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
