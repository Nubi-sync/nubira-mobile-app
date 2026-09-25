import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/tenant_resolver_service.dart';
import '../../merchandising/models/merchandising_models.dart';
import '../models/cutting_models.dart';

class CuttingState {
  final bool isLoading;
  final bool isSyncing;
  final String? error;
  final List<CuttingWorker> workers;
  final List<CuttingTaskAllocation> allocations;
  final List<ActiveBuyer> buyers;
  final List<MerchandisingOrder> orders;
  final String selectedBuyerId;
  final String statusFilter;
  final String searchQuery;
  final String? companyName;
  final Map<String, String> buyerRoutes; // buyerId -> route

  const CuttingState({
    this.isLoading = false,
    this.isSyncing = false,
    this.error,
    this.workers = const [],
    this.allocations = const [],
    this.buyers = const [],
    this.orders = const [],
    this.selectedBuyerId = '',
    this.statusFilter = 'ALL',
    this.searchQuery = '',
    this.companyName,
    this.buyerRoutes = const {},
  });

  CuttingState copyWith({
    bool? isLoading,
    bool? isSyncing,
    String? error,
    List<CuttingWorker>? workers,
    List<CuttingTaskAllocation>? allocations,
    List<ActiveBuyer>? buyers,
    List<MerchandisingOrder>? orders,
    String? selectedBuyerId,
    String? statusFilter,
    String? searchQuery,
    String? companyName,
    Map<String, String>? buyerRoutes,
  }) {
    return CuttingState(
      isLoading: isLoading ?? this.isLoading,
      isSyncing: isSyncing ?? this.isSyncing,
      error: error,
      workers: workers ?? this.workers,
      allocations: allocations ?? this.allocations,
      buyers: buyers ?? this.buyers,
      orders: orders ?? this.orders,
      selectedBuyerId: selectedBuyerId ?? this.selectedBuyerId,
      statusFilter: statusFilter ?? this.statusFilter,
      searchQuery: searchQuery ?? this.searchQuery,
      companyName: companyName ?? this.companyName,
      buyerRoutes: buyerRoutes ?? this.buyerRoutes,
    );
  }

  ActiveBuyer? get selectedBuyer {
    if (selectedBuyerId == 'ALL' || buyers.isEmpty) return null;
    if (selectedBuyerId.isNotEmpty) {
      final found = buyers.where((b) => b.id == selectedBuyerId).toList();
      if (found.isNotEmpty) return found.first;
    }
    return buyers.first;
  }

  String get activeRoute {
    final buyer = selectedBuyer;
    if (buyer == null) return 'PRINT_FIRST_THEN_EMBROIDERY';
    if (buyerRoutes.containsKey(buyer.id)) return buyerRoutes[buyer.id]!;
    
    // Check linked orders
    final matchingOrd = orders.where((o) =>
        (o.buyerId != null && o.buyerId == buyer.id) ||
        o.brandName.toLowerCase() == buyer.buyerName.toLowerCase() ||
        (buyer.linkedArticleNumber != null && o.styleRef == buyer.linkedArticleNumber)).firstOrNull;

    if (matchingOrd != null && matchingOrd.embellishmentSequence.isNotEmpty && matchingOrd.embellishmentSequence != 'NONE') {
      return matchingOrd.embellishmentSequence;
    }
    return 'PRINT_FIRST_THEN_EMBROIDERY';
  }

  int get totalContractedPieces {
    final buyer = selectedBuyer;
    if (buyer != null) {
      final matchingOrders = orders.where((o) =>
          (o.buyerId != null && o.buyerId == buyer.id) ||
          o.brandName.toLowerCase() == buyer.buyerName.toLowerCase() ||
          (buyer.linkedArticleNumber != null && o.styleRef == buyer.linkedArticleNumber)).toList();
      final ordSum = matchingOrders.fold<int>(0, (sum, o) => sum + o.totalQuantity);
      return ordSum > 0 ? ordSum : (buyer.contractedVolume > 0 ? buyer.contractedVolume : 0);
    }
    return buyers.fold<int>(0, (sum, b) => sum + b.contractedVolume);
  }

  List<CuttingTaskAllocation> get matchingAllocations {
    final buyer = selectedBuyer;
    if (buyer == null) return allocations;
    final bName = buyer.buyerName.trim().toLowerCase();
    final bArt = (buyer.linkedArticleNumber ?? '').trim().toUpperCase();

    return allocations.where((t) {
      final tBuyer = t.buyerName.trim().toLowerCase();
      final tBuyerId = t.buyerId ?? '';
      final tArt = t.articleNumber.trim().toUpperCase();
      return (tBuyerId.isNotEmpty && tBuyerId == buyer.id) ||
          (bName.isNotEmpty && tBuyer == bName) ||
          (bArt.isNotEmpty && tArt == bArt);
    }).toList();
  }

  int get completedCuttingPieces {
    return matchingAllocations
        .where((t) => t.isCompleted)
        .fold<int>(0, (sum, t) => sum + (t.completedPieces > 0 ? t.completedPieces : t.piecesToCut));
  }

  int get pendingCuttingPieces {
    return matchingAllocations
        .where((t) => !t.isCompleted)
        .fold<int>(0, (sum, t) => sum + t.piecesToCut);
  }

  int get inHandPieces {
    final rem = totalContractedPieces - pendingCuttingPieces - completedCuttingPieces;
    return rem > 0 ? rem : 0;
  }

  List<CuttingTaskAllocation> get filteredTasks {
    final baseList = selectedBuyerId == 'ALL' ? allocations : matchingAllocations;
    return baseList.where((task) {
      // 1. Search Query
      final q = searchQuery.trim().toLowerCase();
      final matchesSearch = q.isEmpty ||
          task.taskRef.toLowerCase().contains(q) ||
          task.workerName.toLowerCase().contains(q) ||
          task.articleNumber.toLowerCase().contains(q) ||
          task.buyerName.toLowerCase().contains(q) ||
          task.tableNumber.toLowerCase().contains(q);

      // 2. Status Filter
      bool matchesStatus = true;
      if (statusFilter == 'ACTIVE') {
        matchesStatus = !task.isCompleted;
      } else if (statusFilter == 'NEEDS_VERIFY') {
        matchesStatus = task.isWorkerCompleted;
      } else if (statusFilter == 'COMPLETED') {
        matchesStatus = task.isCompleted;
      }

      return matchesSearch && matchesStatus;
    }).toList();
  }
}

class CuttingNotifier extends StateNotifier<CuttingState> {
  CuttingNotifier() : super(const CuttingState()) {
    fetchCuttingData();
  }

  void setSelectedBuyerId(String id) {
    state = state.copyWith(selectedBuyerId: id);
  }

  void setStatusFilter(String filter) {
    state = state.copyWith(statusFilter: filter);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setArticleRoute(String buyerId, String route) {
    final updated = Map<String, String>.from(state.buyerRoutes);
    updated[buyerId] = route;
    state = state.copyWith(buyerRoutes: updated);
  }

  Future<void> syncData() async {
    state = state.copyWith(isSyncing: true);
    await fetchCuttingData(isBackgroundSync: true);
    state = state.copyWith(isSyncing: false);
  }

  Future<void> fetchCuttingData({bool isBackgroundSync = false}) async {
    if (!isBackgroundSync) {
      state = state.copyWith(isLoading: true, error: null);
    }

    try {
      final client = Supabase.instance.client;

      // Centrally resolve tenant identity
      final currentUser = client.auth.currentUser;
      String? companyFilter;
      if (currentUser != null) {
        try {
          final tenant = await TenantResolverService.resolveUserTenant(currentUser);
          if (!tenant.isLegacyNubira && tenant.companyName != 'Zigza MES Platform Operations') {
            companyFilter = tenant.companyName.trim();
          }
        } catch (_) {}
      }

      // 1. Fetch Cutting Workers
      List<CuttingWorker> workersList = [];
      try {
        final wRes = await client.from('cutting_workers').select('*').order('created_at', ascending: false);
        final rawW = (wRes as List<dynamic>?) ?? [];
        var mappedW = rawW.map((w) => CuttingWorker.fromJson(w as Map<String, dynamic>)).toList();
        if (companyFilter != null && companyFilter.isNotEmpty) {
          final target = companyFilter.toLowerCase();
          mappedW = mappedW.where((w) {
            final c = (w.companyName ?? '').toLowerCase();
            return c == target || c.contains(target);
          }).toList();
        }
        workersList = mappedW;
      } catch (e) {
        debugPrint('[CuttingNotifier] Error fetching workers: $e');
      }

      // 2. Fetch Cutting Task Allocations
      List<CuttingTaskAllocation> taskList = [];
      try {
        final tRes = await client.from('cutting_task_allocations').select('*').order('created_at', ascending: false);
        final rawT = (tRes as List<dynamic>?) ?? [];
        var mappedT = rawT.map((t) => CuttingTaskAllocation.fromJson(t as Map<String, dynamic>)).toList();
        if (companyFilter != null && companyFilter.isNotEmpty) {
          final target = companyFilter.toLowerCase();
          mappedT = mappedT.where((t) {
            final c = (t.companyName ?? '').toLowerCase();
            return c == target || c.contains(target);
          }).toList();
        }
        taskList = mappedT;
      } catch (e) {
        debugPrint('[CuttingNotifier] Error fetching task allocations: $e');
      }

      // 3. Fetch Active Buyers & Orders from Database
      List<ActiveBuyer> buyersList = [];
      try {
        final bRes = await client.from('merchandising_active_buyers').select('*').order('created_at', ascending: false);
        final rawB = (bRes as List<dynamic>?) ?? [];
        if (rawB.isNotEmpty) {
          var mappedB = rawB.map((b) => ActiveBuyer.fromJson(b as Map<String, dynamic>)).toList();
          if (companyFilter != null && companyFilter.isNotEmpty) {
            final target = companyFilter.toLowerCase();
            mappedB = mappedB.where((b) {
              final comp = (b.companyName ?? '').toLowerCase();
              final name = b.buyerName.toLowerCase();
              return comp == target || comp.contains(target) || name == target || name.contains(target);
            }).toList();
          }
          buyersList = mappedB;
        }
      } catch (_) {}

      // 4. Fetch Master Merchandising Orders to ensure live contract volumes
      List<MerchandisingOrder> ordersList = [];
      try {
        final oRes = await client
            .from('merchandising_orders')
            .select('''
              *,
              brands ( id, brand_name, brand_code, company_name ),
              design_tech_packs ( id, style_number, category, embellishment_sequence, company_name )
            ''')
            .order('created_at', ascending: false);
        final rawO = (oRes as List<dynamic>?) ?? [];
        var mappedO = rawO.map((row) {
          final tp = row['design_tech_packs'] as Map<String, dynamic>?;
          final brand = row['brands'] as Map<String, dynamic>?;
          final company = row['company_name']?.toString() ?? brand?['company_name']?.toString() ?? tp?['company_name']?.toString();
          final totalQty = (row['total_quantity'] as num?)?.toInt() ?? 0;
          final fobPrice = (row['fob_price_per_piece'] as num?)?.toDouble() ?? 0.0;

          return MerchandisingOrder(
            id: row['id']?.toString() ?? '',
            poNumber: row['order_number']?.toString() ?? 'PO',
            brandName: brand?['brand_name']?.toString() ?? 'Direct Buyer',
            styleRef: tp?['style_number']?.toString() ?? 'Standard Style',
            styleName: '${tp?['category'] ?? 'Garment'} ${row['order_number'] ?? ''}',
            techPackId: row['tech_pack_id']?.toString(),
            totalQuantity: totalQty,
            unitFobPrice: fobPrice,
            totalContractValue: (totalQty * fobPrice),
            exFactoryDate: row['ex_factory_date']?.toString() ?? '',
            status: row['status']?.toString() ?? 'IN_CUTTING',
            embellishmentSequence: tp?['embellishment_sequence']?.toString() ?? 'NONE',
            buyerId: row['buyer_id']?.toString(),
            buyerCode: brand?['brand_code']?.toString(),
            companyName: company,
            createdAt: row['created_at']?.toString() ?? DateTime.now().toIso8601String(),
          );
        }).toList();

        if (companyFilter != null && companyFilter.isNotEmpty) {
          final target = companyFilter.toLowerCase();
          mappedO = mappedO.where((ord) {
            final oc = (ord.companyName ?? '').toLowerCase();
            final bn = ord.brandName.toLowerCase();
            return oc == target || oc.contains(target) || bn == target || bn.contains(target);
          }).toList();
        }
        ordersList = mappedO;

        // If buyers list was empty, merge order-derived buyers
        if (buyersList.isEmpty && ordersList.isNotEmpty) {
          final bMap = <String, ActiveBuyer>{};
          for (final ord in ordersList) {
            final bName = ord.brandName.trim();
            final key = bName.toUpperCase();
            if (!bMap.containsKey(key)) {
              bMap[key] = ActiveBuyer(
                id: ord.buyerId ?? ord.id,
                buyerName: bName,
                buyerCode: ord.buyerCode ?? (bName.length >= 4 ? bName.substring(0, 4).toUpperCase() : 'BUYER'),
                contractedVolume: ord.totalQuantity,
                linkedArticleNumber: ord.styleRef,
                linkedArticleName: ord.styleName,
                companyName: ord.companyName,
              );
            } else {
              final prev = bMap[key]!;
              bMap[key] = prev.copyWith(
                contractedVolume: prev.contractedVolume + ord.totalQuantity,
              );
            }
          }
          buyersList = bMap.values.toList();
        }
      } catch (e) {
        debugPrint('[CuttingNotifier] Error fetching orders: $e');
      }

      // Default selected buyer
      String activeBuyerId = state.selectedBuyerId;
      if (activeBuyerId.isEmpty || (activeBuyerId != 'ALL' && !buyersList.any((b) => b.id == activeBuyerId))) {
        activeBuyerId = buyersList.isNotEmpty ? buyersList.first.id : '';
      }

      state = state.copyWith(
        isLoading: false,
        isSyncing: false,
        workers: workersList,
        allocations: taskList,
        buyers: buyersList,
        orders: ordersList,
        selectedBuyerId: activeBuyerId,
        companyName: companyFilter,
      );
    } catch (e) {
      debugPrint('[CuttingNotifier] Error fetching cutting data: $e');
      state = state.copyWith(
        isLoading: false,
        isSyncing: false,
        error: e.toString(),
      );
    }
  }

  Future<bool> registerWorker({
    required String workerName,
    required String phoneNumber,
    required String password,
    required List<String> roles,
  }) async {
    try {
      final client = Supabase.instance.client;
      final rawDigits = phoneNumber.replaceAll(RegExp(r'\D'), '');
      final phone10 = rawDigits.length >= 10 ? rawDigits.substring(rawDigits.length - 10) : rawDigits;
      final nameClean = workerName.trim();
      final internalEmail = '$phone10@cutting.nubira.local';
      final primaryRoleLabel = roles.map((r) => r.replaceAll('_', ' ')).join(', ');

      final newWorker = CuttingWorker(
        id: 'cw-${DateTime.now().millisecondsSinceEpoch}',
        workerName: nameClean,
        phoneNumber: phone10,
        workerEmail: internalEmail,
        roles: roles,
        role: primaryRoleLabel,
        status: 'ACTIVE',
        assignedPieces: 0,
        completedPieces: 0,
        companyName: state.companyName,
        createdAt: DateTime.now().toIso8601String(),
      );

      // Optimistic update
      state = state.copyWith(
        workers: [newWorker, ...state.workers.where((w) => w.phoneNumber != phone10)],
      );

      // Persist to Supabase
      try {
        await client.from('cutting_workers').upsert({
          'worker_name': nameClean,
          'phone_number': phone10,
          'worker_email': internalEmail,
          'roles': roles,
          'role': primaryRoleLabel,
          'company_name': state.companyName,
          'status': 'ACTIVE',
        }, onConflict: 'phone_number');
      } catch (dbErr) {
        debugPrint('[CuttingNotifier] Database notice on worker upsert: $dbErr');
      }

      return true;
    } catch (e) {
      debugPrint('[CuttingNotifier] Error registering worker: $e');
      return false;
    }
  }

  Future<bool> deleteWorker(String workerId, String? phone) async {
    try {
      final client = Supabase.instance.client;
      state = state.copyWith(
        workers: state.workers.where((w) => w.id != workerId && (phone == null || w.phoneNumber != phone)).toList(),
      );

      try {
        if (workerId.contains('-') && workerId.length > 30) {
          await client.from('cutting_workers').delete().eq('id', workerId);
        } else if (phone != null && phone.isNotEmpty) {
          await client.from('cutting_workers').delete().eq('phone_number', phone);
        }
      } catch (_) {}

      return true;
    } catch (e) {
      debugPrint('[CuttingNotifier] Error deleting worker: $e');
      return false;
    }
  }

  Future<bool> createTaskAllocation({
    required String buyerId,
    required String buyerName,
    required String articleNumber,
    required String articleName,
    required String workerId,
    required String workerName,
    String? workerPhone,
    required String tableNumber,
    required int piecesToCut,
    double allotedHours = 4.0,
    String? dueTime,
    String? notes,
  }) async {
    try {
      final client = Supabase.instance.client;
      final taskRef = 'TSK-${(DateTime.now().millisecondsSinceEpoch % 9000 + 1000)}';

      final newTask = CuttingTaskAllocation(
        id: 'task-${DateTime.now().millisecondsSinceEpoch}',
        taskRef: taskRef,
        buyerId: buyerId.isNotEmpty ? buyerId : null,
        buyerName: buyerName,
        articleNumber: articleNumber,
        articleName: articleName,
        workerId: workerId,
        workerName: workerName,
        workerPhone: workerPhone,
        tableNumber: tableNumber,
        piecesToCut: piecesToCut,
        completedPieces: 0,
        allotedHours: allotedHours,
        dueTime: dueTime ?? DateTime.now().add(Duration(hours: allotedHours.toInt())).toIso8601String(),
        notes: notes,
        status: 'ASSIGNED',
        companyName: state.companyName,
        createdAt: DateTime.now().toIso8601String(),
      );

      // Optimistic update
      state = state.copyWith(
        allocations: [newTask, ...state.allocations],
      );

      // Persist to Supabase
      try {
        final insertRes = await client.from('cutting_task_allocations').insert({
          'task_ref': taskRef,
          'buyer_id': buyerId.isNotEmpty && buyerId.length > 30 ? buyerId : null,
          'buyer_name': buyerName,
          'article_number': articleNumber,
          'article_name': articleName,
          'worker_name': workerName,
          'worker_phone': workerPhone,
          'table_number': tableNumber,
          'pieces_to_cut': piecesToCut,
          'completed_pieces': 0,
          'alloted_hours': allotedHours,
          'due_time': newTask.dueTime,
          'notes': notes,
          'company_name': state.companyName,
          'status': 'ASSIGNED',
        }).select().maybeSingle();

        if (insertRes != null && insertRes['id'] != null) {
          final realId = insertRes['id'].toString();
          state = state.copyWith(
            allocations: state.allocations.map((t) => t.id == newTask.id ? t.copyWith(id: realId) : t).toList(),
          );
        }
      } catch (dbErr) {
        debugPrint('[CuttingNotifier] DB notice on task insert: $dbErr');
      }

      return true;
    } catch (e) {
      debugPrint('[CuttingNotifier] Error creating task allocation: $e');
      return false;
    }
  }

  Future<bool> verifyAndDoneTask(String taskId, int pieces) async {
    try {
      final client = Supabase.instance.client;
      final target = state.allocations.where((t) => t.id == taskId || t.taskRef == taskId).firstOrNull;
      if (target == null) return false;

      final updated = target.copyWith(
        status: 'VERIFIED_COMPLETED',
        completedPieces: pieces > 0 ? pieces : target.piecesToCut,
        completedAt: DateTime.now().toIso8601String(),
      );

      // Optimistic update
      state = state.copyWith(
        allocations: state.allocations.map((t) => (t.id == taskId || t.taskRef == taskId) ? updated : t).toList(),
      );

      // Persist to Supabase
      try {
        if (target.id.contains('-') && target.id.length > 30) {
          await client.from('cutting_task_allocations').update({
            'status': 'VERIFIED_COMPLETED',
            'completed_pieces': updated.completedPieces,
            'completed_at': updated.completedAt,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', target.id);
        } else {
          await client.from('cutting_task_allocations').update({
            'status': 'VERIFIED_COMPLETED',
            'completed_pieces': updated.completedPieces,
            'completed_at': updated.completedAt,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('task_ref', target.taskRef);
        }
      } catch (dbErr) {
        debugPrint('[CuttingNotifier] DB notice on verify: $dbErr');
      }

      return true;
    } catch (e) {
      debugPrint('[CuttingNotifier] Error verifying task: $e');
      return false;
    }
  }

  Future<bool> deleteTaskAllocation(String taskId) async {
    try {
      final client = Supabase.instance.client;
      final target = state.allocations.where((t) => t.id == taskId || t.taskRef == taskId).firstOrNull;

      state = state.copyWith(
        allocations: state.allocations.where((t) => t.id != taskId && t.taskRef != taskId).toList(),
      );

      try {
        if (target != null && target.id.contains('-') && target.id.length > 30) {
          await client.from('cutting_task_allocations').delete().eq('id', target.id);
        } else if (target != null) {
          await client.from('cutting_task_allocations').delete().eq('task_ref', target.taskRef);
        }
      } catch (_) {}

      return true;
    } catch (e) {
      debugPrint('[CuttingNotifier] Error deleting task allocation: $e');
      return false;
    }
  }
}

final cuttingProvider = StateNotifierProvider<CuttingNotifier, CuttingState>((ref) {
  return CuttingNotifier();
});
