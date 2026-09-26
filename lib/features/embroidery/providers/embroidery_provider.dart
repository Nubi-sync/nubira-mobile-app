import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../main.dart';
import '../../../core/services/tenant_resolver_service.dart';
import '../models/embroidery_models.dart';

class EmbroideryState {
  final bool isLoading;
  final bool isSyncing;
  final String? error;
  final List<EmbroideryWorker> workers;
  final List<EmbroideryTaskAllocation> taskAllocations;
  final List<EmbroideryBuyerContract> buyers;
  final String selectedBuyerId;
  final Map<String, String> articleRoutes; // buyerId -> routeKey
  final String statusFilter; // ALL, ACTIVE, NEEDS_VERIFY, COMPLETED
  final String searchQuery;
  final int upstreamCutPieces;
  final int upstreamPrintingPieces;
  final List<String> availableMachines;

  const EmbroideryState({
    this.isLoading = false,
    this.isSyncing = false,
    this.error,
    this.workers = const [],
    this.taskAllocations = const [],
    this.buyers = const [],
    this.selectedBuyerId = '',
    this.articleRoutes = const {},
    this.statusFilter = 'ALL',
    this.searchQuery = '',
    this.upstreamCutPieces = 0,
    this.upstreamPrintingPieces = 0,
    this.availableMachines = const [
      'Machine 01 (Tajima 20-Head)',
      'Machine 02 (Tajima 12-Head)',
      'Machine 03 (Barudan 15-Head)',
      'Machine 04 (SWF Multi-Head)',
    ],
  });

  EmbroideryState copyWith({
    bool? isLoading,
    bool? isSyncing,
    String? error,
    List<EmbroideryWorker>? workers,
    List<EmbroideryTaskAllocation>? taskAllocations,
    List<EmbroideryBuyerContract>? buyers,
    String? selectedBuyerId,
    Map<String, String>? articleRoutes,
    String? statusFilter,
    String? searchQuery,
    int? upstreamCutPieces,
    int? upstreamPrintingPieces,
    List<String>? availableMachines,
  }) {
    return EmbroideryState(
      isLoading: isLoading ?? this.isLoading,
      isSyncing: isSyncing ?? this.isSyncing,
      error: error,
      workers: workers ?? this.workers,
      taskAllocations: taskAllocations ?? this.taskAllocations,
      buyers: buyers ?? this.buyers,
      selectedBuyerId: selectedBuyerId ?? this.selectedBuyerId,
      articleRoutes: articleRoutes ?? this.articleRoutes,
      statusFilter: statusFilter ?? this.statusFilter,
      searchQuery: searchQuery ?? this.searchQuery,
      upstreamCutPieces: upstreamCutPieces ?? this.upstreamCutPieces,
      upstreamPrintingPieces: upstreamPrintingPieces ?? this.upstreamPrintingPieces,
      availableMachines: availableMachines ?? this.availableMachines,
    );
  }
}

const List<EmbroideryBuyerContract> kInitialEmbroideryBuyers = [
  EmbroideryBuyerContract(
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
    completedPrintingPieces: 2800,
  ),
  EmbroideryBuyerContract(
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
    completedPrintingPieces: 0,
  ),
];

const List<EmbroideryTaskAllocation> kInitialEmbroideryTasks = [
  EmbroideryTaskAllocation(
    id: 'task-emb-01',
    taskRef: 'EMB-2026-9901',
    workerId: 'ew-101',
    workerName: 'Suresh Kumar',
    workerPhone: '9876543210',
    buyerName: 'Hollypop',
    articleNumber: 'DEMO-101-03',
    articleName: 'Premium Graphic Tee',
    tableNumber: 'Machine 01 (Tajima 20-Head)',
    piecesToEmbroider: 800,
    completedPieces: 0,
    status: 'ASSIGNED',
    allotedHours: 4.0,
    createdAt: '2026-09-24T00:00:00.000Z',
  ),
  EmbroideryTaskAllocation(
    id: 'task-emb-02',
    taskRef: 'EMB-2026-9902',
    workerId: 'ew-102',
    workerName: 'Mohan Lal',
    workerPhone: '9812345678',
    buyerName: 'Hollypop',
    articleNumber: 'DEMO-101-03',
    articleName: 'Premium Graphic Tee',
    tableNumber: 'Machine 02 (Tajima 12-Head)',
    piecesToEmbroider: 500,
    completedPieces: 500,
    status: 'VERIFIED_COMPLETED',
    allotedHours: 4.0,
    createdAt: '2026-09-24T00:00:00.000Z',
    completedAt: '2026-09-24T12:00:00.000Z',
  ),
];

const List<EmbroideryWorker> kInitialEmbroideryWorkers = [
  EmbroideryWorker(
    id: 'ew-101',
    workerName: 'Suresh Kumar',
    phoneNumber: '9876543210',
    role: 'Multi-Head Machine Operator',
    roles: ['EMBROIDERY_OPERATOR'],
    shift: 'MORNING',
    status: 'ACTIVE',
    assignedPieces: 800,
    completedPieces: 0,
    createdAt: '2026-09-24T00:00:00.000Z',
  ),
  EmbroideryWorker(
    id: 'ew-102',
    workerName: 'Mohan Lal',
    phoneNumber: '9812345678',
    role: 'Hooping & Framing Specialist',
    roles: ['HOOPING_SPECIALIST'],
    shift: 'MORNING',
    status: 'ACTIVE',
    assignedPieces: 500,
    completedPieces: 500,
    createdAt: '2026-09-24T00:00:00.000Z',
  ),
  EmbroideryWorker(
    id: 'ew-103',
    workerName: 'Vikram Singh',
    phoneNumber: '9899887766',
    role: 'Punch Digitizer / Quality Inspector',
    roles: ['PUNCH_DIGITIZER'],
    shift: 'GENERAL',
    status: 'ACTIVE',
    assignedPieces: 0,
    completedPieces: 0,
    createdAt: '2026-09-24T00:00:00.000Z',
  ),
];

class EmbroideryNotifier extends StateNotifier<EmbroideryState> {
  EmbroideryNotifier() : super(const EmbroideryState()) {
    loadInitialData();
  }

  static const String _prefWorkersKey = 'nubira_embroidery_workers_cache';
  static const String _prefTasksKey = 'nubira_embroidery_tasks_cache';
  static const String _prefRoutesKey = 'nubira_embroidery_routes_cache';
  static const String _prefMachinesKey = 'nubira_embroidery_machines_cache';

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

  Future<void> loadInitialData({bool isRefresh = false}) async {
    if (isRefresh) {
      state = state.copyWith(isSyncing: true);
    } else {
      state = state.copyWith(isLoading: true);
    }

    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Load cached workers
      List<EmbroideryWorker> loadedWorkers = [...kInitialEmbroideryWorkers];
      final cachedWorkersStr = prefs.getString(_prefWorkersKey);
      if (cachedWorkersStr != null && cachedWorkersStr.isNotEmpty) {
        try {
          final List decoded = jsonDecode(cachedWorkersStr);
          final parsed = decoded.map((e) => EmbroideryWorker.fromJson(e)).toList();
          if (parsed.isNotEmpty) {
            final map = {for (var w in loadedWorkers) w.phoneNumber.isNotEmpty ? w.phoneNumber : w.id: w};
            for (var w in parsed) {
              map[w.phoneNumber.isNotEmpty ? w.phoneNumber : w.id] = w;
            }
            loadedWorkers = map.values.toList();
          }
        } catch (_) {}
      }

      // 2. Load cached task allocations
      List<EmbroideryTaskAllocation> loadedTasks = [...kInitialEmbroideryTasks];
      final cachedTasksStr = prefs.getString(_prefTasksKey);
      if (cachedTasksStr != null && cachedTasksStr.isNotEmpty) {
        try {
          final List decoded = jsonDecode(cachedTasksStr);
          final parsed = decoded.map((e) => EmbroideryTaskAllocation.fromJson(e)).toList();
          if (parsed.isNotEmpty) {
            final map = {for (var t in loadedTasks) t.taskRef: t};
            for (var t in parsed) {
              map[t.taskRef] = t;
            }
            loadedTasks = map.values.toList();
          }
        } catch (_) {}
      }

      // 3. Load cached routes & machines
      Map<String, String> loadedRoutes = {
        'byr-hollypop': 'PRINT_FIRST_THEN_EMBROIDERY',
        'byr-ollywood': 'PRINT_FIRST_THEN_EMBROIDERY',
      };
      final cachedRoutesStr = prefs.getString(_prefRoutesKey);
      if (cachedRoutesStr != null && cachedRoutesStr.isNotEmpty) {
        try {
          final Map<String, dynamic> decoded = jsonDecode(cachedRoutesStr);
          decoded.forEach((key, val) {
            loadedRoutes[key] = val.toString();
          });
        } catch (_) {}
      }

      List<String> loadedMachines = [
        'Machine 01 (Tajima 20-Head)',
        'Machine 02 (Tajima 12-Head)',
        'Machine 03 (Barudan 15-Head)',
        'Machine 04 (SWF Multi-Head)',
      ];
      final cachedMachinesStr = prefs.getString(_prefMachinesKey);
      if (cachedMachinesStr != null && cachedMachinesStr.isNotEmpty) {
        try {
          final List decoded = jsonDecode(cachedMachinesStr);
          final parsed = decoded.map((e) => e.toString()).toList();
          if (parsed.isNotEmpty) loadedMachines = parsed;
        } catch (_) {}
      }

      // 4. Resolve Tenant Company Name
      final companyName = await _getResolvedCompanyFilter();

      // 5. Query Supabase for Live Server Workers
      try {
        var workerQuery = supabase.from('embroidery_workers').select('*');
        if (companyName != null && companyName.trim().isNotEmpty) {
          workerQuery = workerQuery.eq('company_name', companyName.trim());
        }
        final dynamic serverWorkerRows = await workerQuery.order('created_at', ascending: false);
        if (serverWorkerRows is List && serverWorkerRows.isNotEmpty) {
          final serverWorkers = serverWorkerRows.map((e) => EmbroideryWorker.fromJson(e as Map<String, dynamic>)).toList();
          final map = {for (var w in loadedWorkers) w.phoneNumber.isNotEmpty ? w.phoneNumber : w.id: w};
          for (var w in serverWorkers) {
            map[w.phoneNumber.isNotEmpty ? w.phoneNumber : w.id] = w;
          }
          loadedWorkers = map.values.toList();
        }
      } catch (e) {
        debugPrint('[EmbroideryProvider] Server worker fetch warning: $e');
      }

      // 6. Query Supabase for Live Server Task Allocations
      try {
        var taskQuery = supabase.from('embroidery_task_allocations').select('*');
        if (companyName != null && companyName.trim().isNotEmpty) {
          taskQuery = taskQuery.eq('company_name', companyName.trim());
        }
        final dynamic serverTaskRows = await taskQuery.order('created_at', ascending: false);
        if (serverTaskRows is List && serverTaskRows.isNotEmpty) {
          final serverTasks = serverTaskRows.map((e) => EmbroideryTaskAllocation.fromJson(e as Map<String, dynamic>)).toList();
          final map = {for (var t in loadedTasks) t.taskRef: t};
          for (var t in serverTasks) {
            map[t.taskRef] = t;
          }
          loadedTasks = map.values.toList();
        }
      } catch (e) {
        debugPrint('[EmbroideryProvider] Server task fetch warning: $e');
      }

      // 7. Query Upstream Cutting & Printing Allocations for piece counting
      int totalCutPieces = 2800;
      int totalPrintedPieces = 2800;

      try {
        var cutQuery = supabase.from('cutting_task_allocations').select('*');
        if (companyName != null && companyName.trim().isNotEmpty) {
          cutQuery = cutQuery.eq('company_name', companyName.trim());
        }
        final dynamic cutRows = await cutQuery;
        if (cutRows is List && cutRows.isNotEmpty) {
          final completedCuts = cutRows.where((r) =>
              r['status'] == 'VERIFIED_COMPLETED' || r['status'] == 'COMPLETED');
          final sumCut = completedCuts.fold<int>(
            0,
            (acc, curr) =>
                acc + ((curr['completed_pieces'] as num?)?.toInt() ?? (curr['pieces_to_cut'] as num?)?.toInt() ?? 0),
          );
          if (sumCut > 0) totalCutPieces = sumCut;
        }
      } catch (_) {}

      try {
        var printQuery = supabase.from('printing_task_allocations').select('*');
        if (companyName != null && companyName.trim().isNotEmpty) {
          printQuery = printQuery.eq('company_name', companyName.trim());
        }
        final dynamic printRows = await printQuery;
        if (printRows is List && printRows.isNotEmpty) {
          final completedPrints = printRows.where((r) =>
              r['status'] == 'VERIFIED_COMPLETED' || r['status'] == 'COMPLETED');
          final sumPrint = completedPrints.fold<int>(
            0,
            (acc, curr) =>
                acc + ((curr['completed_pieces'] as num?)?.toInt() ?? (curr['pieces_to_print'] as num?)?.toInt() ?? 0),
          );
          if (sumPrint > 0) totalPrintedPieces = sumPrint;
        }
      } catch (_) {}

      // 8. Fetch Active Buyers from Merchandising / Orders
      List<EmbroideryBuyerContract> loadedBuyers = [...kInitialEmbroideryBuyers];
      try {
        final dynamic buyerRows = await supabase.from('brands').select('*').limit(20);
        if (buyerRows is List && buyerRows.isNotEmpty) {
          final parsedBuyers = buyerRows.map((b) {
            return EmbroideryBuyerContract(
              id: b['id']?.toString() ?? '',
              buyerName: b['brand_name']?.toString() ?? 'Buyer',
              buyerCode: b['brand_code']?.toString(),
              contractedVolume: (b['contracted_volume'] as num?)?.toInt() ?? 6000,
              pricePerPiece: (b['price_per_piece'] as num?)?.toDouble() ?? 18.5,
              totalContractValue: (b['total_contract_value'] as num?)?.toDouble() ?? 111000.0,
              linkedArticleNumber: b['linked_article_number']?.toString() ?? 'DEMO-101-03',
              linkedArticleName: b['linked_article_name']?.toString() ?? 'Premium Graphic Tee',
              embellishmentSequence: b['embellishment_sequence']?.toString() ?? 'PRINT_FIRST_THEN_EMBROIDERY',
              completedCutPieces: totalCutPieces,
              completedPrintingPieces: totalPrintedPieces,
            );
          }).toList();

          if (parsedBuyers.isNotEmpty) {
            final buyerMap = {for (var b in loadedBuyers) b.buyerName.toLowerCase(): b};
            for (var b in parsedBuyers) {
              buyerMap[b.buyerName.toLowerCase()] = b;
            }
            loadedBuyers = buyerMap.values.toList();
          }
        }
      } catch (_) {}

      // Match buyer completed cuts & prints
      loadedBuyers = loadedBuyers.map((b) {
        return b.copyWith(
          completedCutPieces: totalCutPieces,
          completedPrintingPieces: totalPrintedPieces,
        );
      }).toList();

      final selectedId = state.selectedBuyerId.isNotEmpty
          ? state.selectedBuyerId
          : (loadedBuyers.isNotEmpty ? loadedBuyers.first.id : 'byr-hollypop');

      state = state.copyWith(
        isLoading: false,
        isSyncing: false,
        workers: loadedWorkers,
        taskAllocations: loadedTasks,
        buyers: loadedBuyers,
        selectedBuyerId: selectedId,
        articleRoutes: loadedRoutes,
        upstreamCutPieces: totalCutPieces,
        upstreamPrintingPieces: totalPrintedPieces,
        availableMachines: loadedMachines,
      );

      // Save merged to cache
      _saveToCache();
    } catch (e) {
      debugPrint('[EmbroideryProvider] loadInitialData error: $e');
      state = state.copyWith(
        isLoading: false,
        isSyncing: false,
        error: e.toString(),
        workers: state.workers.isNotEmpty ? state.workers : kInitialEmbroideryWorkers,
        taskAllocations: state.taskAllocations.isNotEmpty ? state.taskAllocations : kInitialEmbroideryTasks,
        buyers: state.buyers.isNotEmpty ? state.buyers : kInitialEmbroideryBuyers,
        selectedBuyerId: state.selectedBuyerId.isNotEmpty ? state.selectedBuyerId : 'byr-hollypop',
      );
    }
  }

  void selectBuyer(String buyerId) {
    state = state.copyWith(selectedBuyerId: buyerId);
  }

  void setStatusFilter(String filter) {
    state = state.copyWith(statusFilter: filter);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  Future<void> setArticleRoute(String buyerId, String routeKey) async {
    final updatedRoutes = Map<String, String>.from(state.articleRoutes);
    updatedRoutes[buyerId] = routeKey;

    final updatedBuyers = state.buyers.map((b) {
      if (b.id == buyerId) {
        return b.copyWith(embellishmentSequence: routeKey);
      }
      return b;
    }).toList();

    state = state.copyWith(
      articleRoutes: updatedRoutes,
      buyers: updatedBuyers,
    );

    _saveToCache();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefRoutesKey, jsonEncode(updatedRoutes));
    } catch (_) {}
  }

  Future<void> addCustomMachine(String machineName) async {
    final nameClean = machineName.trim();
    if (nameClean.isEmpty || state.availableMachines.contains(nameClean)) return;

    final updated = [...state.availableMachines, nameClean];
    state = state.copyWith(availableMachines: updated);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefMachinesKey, jsonEncode(updated));
    } catch (_) {}
  }

  Future<bool> addWorker({
    required String name,
    required String phone,
    required String password,
    required List<String> roles,
    String shift = 'MORNING',
  }) async {
    final phoneClean = phone.replaceAll(RegExp(r'\D'), '').trim();
    final nameClean = name.trim();

    final roleLabel = roles.map((r) => r.replaceAll('_', ' ')).join(', ');

    final newWorker = EmbroideryWorker(
      id: 'ew-${DateTime.now().millisecondsSinceEpoch}',
      workerName: nameClean,
      phoneNumber: phoneClean,
      workerEmail: phoneClean.length >= 10 ? '${phoneClean.substring(phoneClean.length - 10)}@embroidery.nubira.local' : null,
      roles: roles,
      role: roleLabel,
      shift: shift,
      status: 'ACTIVE',
      assignedPieces: 0,
      completedPieces: 0,
      createdAt: DateTime.now().toIso8601String(),
    );

    // Update local state immediately
    final updatedWorkers = [newWorker, ...state.workers.where((w) => w.phoneNumber != phoneClean)];
    state = state.copyWith(workers: updatedWorkers);
    _saveToCache();

    // Async sync to Supabase
    try {
      final companyName = await _getResolvedCompanyFilter();

      await supabase.from('embroidery_workers').upsert({
        'worker_name': nameClean,
        'phone_number': phoneClean,
        'worker_email': newWorker.workerEmail,
        'roles': roles,
        'role': roleLabel,
        'shift': shift,
        'status': 'ACTIVE',
        if (companyName != null) 'company_name': companyName,
      }, onConflict: 'phone_number');
    } catch (e) {
      debugPrint('[EmbroideryProvider] Add worker Supabase notice: $e');
    }

    return true;
  }

  Future<void> deleteWorker(String workerId, String? phone) async {
    final phoneClean = (phone ?? '').replaceAll(RegExp(r'\D'), '');

    final updatedWorkers = state.workers.where((w) {
      if (w.id == workerId) return false;
      if (phoneClean.isNotEmpty && w.phoneNumber == phoneClean) return false;
      return true;
    }).toList();

    state = state.copyWith(workers: updatedWorkers);
    _saveToCache();

    try {
      if (phoneClean.isNotEmpty) {
        await supabase.from('embroidery_workers').delete().eq('phone_number', phoneClean);
      } else {
        await supabase.from('embroidery_workers').delete().eq('id', workerId);
      }
    } catch (e) {
      debugPrint('[EmbroideryProvider] Delete worker Supabase notice: $e');
    }
  }

  Future<bool> addTaskAllocation({
    required String buyerId,
    required String buyerName,
    required String articleNumber,
    required String? articleName,
    required String workerId,
    required String workerName,
    required String? workerPhone,
    required String tableNumber,
    required int piecesToEmbroider,
    required double allotedHours,
    String? notes,
  }) async {
    final taskRef = 'EMB-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final dueTimestamp = DateTime.now().add(Duration(minutes: (allotedHours * 60).round())).toIso8601String();

    final newTask = EmbroideryTaskAllocation(
      id: 'task-${DateTime.now().millisecondsSinceEpoch}',
      taskRef: taskRef,
      buyerId: buyerId,
      buyerName: buyerName,
      articleNumber: articleNumber,
      articleName: articleName ?? '$articleNumber Garment Embroidery Job',
      workerId: workerId,
      workerName: workerName,
      workerPhone: workerPhone,
      tableNumber: tableNumber,
      piecesToEmbroider: piecesToEmbroider,
      completedPieces: 0,
      allotedHours: allotedHours,
      dueTime: dueTimestamp,
      notes: notes,
      status: 'ASSIGNED',
      createdAt: DateTime.now().toIso8601String(),
    );

    // Update state immediately
    final updatedTasks = [newTask, ...state.taskAllocations];

    // Update worker assigned piece count
    final updatedWorkers = state.workers.map((w) {
      if (w.id == workerId || (workerPhone != null && w.phoneNumber == workerPhone)) {
        return w.copyWith(assignedPieces: w.assignedPieces + piecesToEmbroider);
      }
      return w;
    }).toList();

    state = state.copyWith(
      taskAllocations: updatedTasks,
      workers: updatedWorkers,
    );

    _saveToCache();

    // Async sync to Supabase
    try {
      final companyName = await _getResolvedCompanyFilter();

      await supabase.from('embroidery_task_allocations').insert({
        'task_ref': newTask.taskRef,
        if (buyerId.isNotEmpty) 'buyer_id': buyerId,
        'buyer_name': buyerName,
        'article_number': articleNumber,
        'article_name': newTask.articleName,
        if (workerId.isNotEmpty) 'worker_id': workerId,
        'worker_name': workerName,
        if (workerPhone != null) 'worker_phone': workerPhone,
        'table_number': tableNumber,
        'pieces_to_embroider': piecesToEmbroider,
        'completed_pieces': 0,
        'alloted_hours': allotedHours,
        'due_time': dueTimestamp,
        if (notes != null) 'notes': notes,
        'status': 'ASSIGNED',
        if (companyName != null) 'company_name': companyName,
      });
    } catch (e) {
      debugPrint('[EmbroideryProvider] Add task allocation Supabase notice: $e');
    }

    return true;
  }

  Future<void> deleteTaskAllocation(String taskId) async {
    final taskToDelete = state.taskAllocations.firstWhere(
      (t) => t.id == taskId || t.taskRef == taskId,
      orElse: () => const EmbroideryTaskAllocation(
        id: '',
        taskRef: '',
        buyerName: '',
        articleNumber: '',
        workerName: '',
        piecesToEmbroider: 0,
        createdAt: '',
      ),
    );

    final updatedTasks = state.taskAllocations.where((t) => t.id != taskId && t.taskRef != taskId).toList();

    // Revert worker assigned piece count
    final updatedWorkers = state.workers.map((w) {
      if (taskToDelete.workerId != null && w.id == taskToDelete.workerId) {
        final newAssigned = (w.assignedPieces - taskToDelete.piecesToEmbroider).clamp(0, 999999);
        return w.copyWith(assignedPieces: newAssigned);
      }
      return w;
    }).toList();

    state = state.copyWith(
      taskAllocations: updatedTasks,
      workers: updatedWorkers,
    );

    _saveToCache();

    try {
      await supabase.from('embroidery_task_allocations').delete().or('id.eq.$taskId,task_ref.eq.$taskId');
    } catch (e) {
      debugPrint('[EmbroideryProvider] Delete task Supabase notice: $e');
    }
  }

  Future<void> verifyAndDoneTask(String taskId, int completedPieces) async {
    final updatedTasks = state.taskAllocations.map((t) {
      if (t.id == taskId || t.taskRef == taskId) {
        return t.copyWith(
          status: 'VERIFIED_COMPLETED',
          completedPieces: completedPieces > 0 ? completedPieces : t.piecesToEmbroider,
          completedAt: DateTime.now().toIso8601String(),
        );
      }
      return t;
    }).toList();

    state = state.copyWith(taskAllocations: updatedTasks);
    _saveToCache();

    try {
      await supabase.from('embroidery_task_allocations').update({
        'status': 'VERIFIED_COMPLETED',
        'completed_pieces': completedPieces,
        'completed_at': DateTime.now().toIso8601String(),
      }).or('id.eq.$taskId,task_ref.eq.$taskId');
    } catch (e) {
      debugPrint('[EmbroideryProvider] Verify task Supabase notice: $e');
    }
  }

  EmbroideryRouteDetails getRouteDetails(String buyerId) {
    final selectedBuyer = state.buyers.firstWhere(
      (b) => b.id == buyerId,
      orElse: () => state.buyers.isNotEmpty
          ? state.buyers.first
          : const EmbroideryBuyerContract(
              id: 'byr-hollypop',
              buyerName: 'Hollypop',
              linkedArticleNumber: 'DEMO-101-03',
              completedCutPieces: 2800,
              completedPrintingPieces: 2800,
            ),
    );

    final route = state.articleRoutes[buyerId] ?? selectedBuyer.embellishmentSequence;

    final matchingTasks = state.taskAllocations.where((t) {
      if (selectedBuyer.buyerName.isNotEmpty &&
          t.buyerName.toLowerCase() == selectedBuyer.buyerName.toLowerCase()) {
        return true;
      }
      if (selectedBuyer.linkedArticleNumber != null &&
          t.articleNumber.toUpperCase() == selectedBuyer.linkedArticleNumber!.toUpperCase()) {
        return true;
      }
      return false;
    }).toList();

    final pendingPieces = matchingTasks
        .where((t) => t.status != 'VERIFIED_COMPLETED' && t.status != 'COMPLETED')
        .fold<int>(0, (acc, t) => acc + t.piecesToEmbroider);

    final completedPieces = matchingTasks
        .where((t) => t.status == 'VERIFIED_COMPLETED' || t.status == 'COMPLETED')
        .fold<int>(0, (acc, t) => acc + (t.completedPieces > 0 ? t.completedPieces : t.piecesToEmbroider));

    int sourcePieces = 0;
    String sourceDept = 'Printing Studio';
    String targetDept = 'Stitching & Sewing';
    String badge = 'Step 2: Printing -> Embroidery';
    String stepText = 'Route: Print first -> Embroidery';
    String shortLabel = 'Print first -> Embroidery';
    bool isActive = true;

    switch (route) {
      case 'PRINT_FIRST_THEN_EMBROIDERY':
        sourcePieces = selectedBuyer.completedPrintingPieces > 0
            ? selectedBuyer.completedPrintingPieces
            : state.upstreamPrintingPieces;
        sourceDept = 'Printing Studio';
        targetDept = 'Stitching & Sewing Floor';
        badge = 'Step 2: Printing -> Embroidery';
        stepText = 'Route: Print first -> Embroidery';
        shortLabel = 'Print first -> Embroidery';
        isActive = true;
        break;
      case 'EMBROIDERY_FIRST_THEN_PRINT':
        sourcePieces = selectedBuyer.completedCutPieces > 0
            ? selectedBuyer.completedCutPieces
            : state.upstreamCutPieces;
        sourceDept = 'Cutting Lay Floor';
        targetDept = 'Printing Studio';
        badge = 'Step 1: Cutting -> Embroidery';
        stepText = 'Route: Embroidery first -> Printing';
        shortLabel = 'Embroidery first -> Print';
        isActive = true;
        break;
      case 'EMBROIDERY_ONLY':
        sourcePieces = selectedBuyer.completedCutPieces > 0
            ? selectedBuyer.completedCutPieces
            : state.upstreamCutPieces;
        sourceDept = 'Cutting Lay Floor';
        targetDept = 'Stitching & Sewing Floor';
        badge = 'Direct: Cutting -> Embroidery';
        stepText = 'Route: Direct Embroidery Only';
        shortLabel = 'Embroidery Only';
        isActive = true;
        break;
      case 'PRINT_ONLY':
        sourcePieces = 0;
        sourceDept = 'Bypassed';
        targetDept = 'Stitching & Sewing Floor';
        badge = 'Bypassed in Routing';
        stepText = 'Route: Print Only (Embroidery Skipped)';
        shortLabel = 'Print Only';
        isActive = false;
        break;
      default:
        sourcePieces = selectedBuyer.completedPrintingPieces > 0
            ? selectedBuyer.completedPrintingPieces
            : state.upstreamPrintingPieces;
        sourceDept = 'Printing Studio';
        targetDept = 'Stitching & Sewing Floor';
        badge = 'Step 2: Printing -> Embroidery';
        stepText = 'Route: Print first -> Embroidery';
        shortLabel = 'Print first -> Embroidery';
        isActive = true;
    }

    final inHand = isActive ? (sourcePieces - pendingPieces - completedPieces).clamp(0, 999999) : 0;

    return EmbroideryRouteDetails(
      route: route,
      shortLabel: shortLabel,
      sourceDepartment: sourceDept,
      targetDepartment: targetDept,
      sourceCompletedPieces: sourcePieces,
      inHandPieces: inHand,
      badgeLabel: badge,
      stepText: stepText,
      isActive: isActive,
    );
  }

  Future<void> _saveToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefWorkersKey, jsonEncode(state.workers.map((w) => w.toJson()).toList()));
      await prefs.setString(_prefTasksKey, jsonEncode(state.taskAllocations.map((t) => t.toJson()).toList()));
    } catch (_) {}
  }
}

final embroideryProvider = StateNotifierProvider<EmbroideryNotifier, EmbroideryState>((ref) {
  return EmbroideryNotifier();
});
