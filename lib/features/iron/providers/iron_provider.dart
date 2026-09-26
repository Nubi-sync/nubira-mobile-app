import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../main.dart';
import '../../../core/services/tenant_resolver_service.dart';
import '../models/iron_models.dart';

class IronState {
  final bool isLoading;
  final bool isSyncing;
  final String? error;
  final List<IronWorker> workers;
  final List<IronTaskAllocation> taskAllocations;
  final List<IronBuyerContract> buyers;
  final String selectedBuyerId;
  final String statusFilter; // ALL, ACTIVE, NEEDS_VERIFY, COMPLETED
  final String searchQuery;
  final List<String> availableTables;

  const IronState({
    this.isLoading = false,
    this.isSyncing = false,
    this.error,
    this.workers = const [],
    this.taskAllocations = const [],
    this.buyers = const [],
    this.selectedBuyerId = 'byr-ollywood',
    this.statusFilter = 'ALL',
    this.searchQuery = '',
    this.availableTables = const [
      'Table 01 (Vacuum Buck)',
      'Table 02 (Heated Utility)',
      'Table 03 (Collar/Cuff Press)',
      'Table 04 (Form Finisher)',
      'Table 05 (Steam Tunnel)',
    ],
  });

  IronState copyWith({
    bool? isLoading,
    bool? isSyncing,
    String? error,
    List<IronWorker>? workers,
    List<IronTaskAllocation>? taskAllocations,
    List<IronBuyerContract>? buyers,
    String? selectedBuyerId,
    String? statusFilter,
    String? searchQuery,
    List<String>? availableTables,
  }) {
    return IronState(
      isLoading: isLoading ?? this.isLoading,
      isSyncing: isSyncing ?? this.isSyncing,
      error: error,
      workers: workers ?? this.workers,
      taskAllocations: taskAllocations ?? this.taskAllocations,
      buyers: buyers ?? this.buyers,
      selectedBuyerId: selectedBuyerId ?? this.selectedBuyerId,
      statusFilter: statusFilter ?? this.statusFilter,
      searchQuery: searchQuery ?? this.searchQuery,
      availableTables: availableTables ?? this.availableTables,
    );
  }
}

const List<IronBuyerContract> kInitialIronBuyers = [
  IronBuyerContract(
    id: 'byr-ollywood',
    buyerName: 'ollywood',
    buyerCode: 'OLLY',
    contractedVolume: 5000,
    pricePerPiece: 2.20,
    totalContractValue: 11000,
    linkedArticleNumber: 'DEMO-102',
    linkedArticleName: 'Heavyweight Loopback Hoodie',
    status: 'LINKED',
  ),
  IronBuyerContract(
    id: 'byr-hollypop',
    buyerName: 'Hollypop',
    buyerCode: 'HOLL',
    contractedVolume: 6000,
    pricePerPiece: 2.50,
    totalContractValue: 15000,
    linkedArticleNumber: 'DEMO-101-03',
    linkedArticleName: 'Premium Graphic Tee',
    status: 'LINKED',
  ),
];

class IronNotifier extends StateNotifier<IronState> {
  IronNotifier() : super(const IronState()) {
    loadInitialData();
  }

  static const _workersPrefKey = 'zigza_iron_workers_v1';
  static const _tasksPrefKey = 'zigza_iron_task_allocations_v1';

  Future<void> loadInitialData({bool isRefresh = false}) async {
    if (isRefresh) {
      state = state.copyWith(isSyncing: true, error: null);
    } else {
      state = state.copyWith(isLoading: true, error: null);
    }

    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Load Workers from local cache
      List<IronWorker> loadedWorkers = [];
      final workersRaw = prefs.getString(_workersPrefKey);
      if (workersRaw != null && workersRaw.isNotEmpty) {
        try {
          final decoded = jsonDecode(workersRaw) as List;
          loadedWorkers = decoded.map((e) => IronWorker.fromJson(e as Map<String, dynamic>)).toList();
        } catch (_) {}
      }

      // 2. Load Task Allocations from local cache
      List<IronTaskAllocation> loadedTasks = [];
      final tasksRaw = prefs.getString(_tasksPrefKey);
      if (tasksRaw != null && tasksRaw.isNotEmpty) {
        try {
          final decoded = jsonDecode(tasksRaw) as List;
          loadedTasks = decoded.map((e) => IronTaskAllocation.fromJson(e as Map<String, dynamic>)).toList();
        } catch (_) {}
      }

      // 3. Cloud Sync with Supabase
      try {
        final currentUser = supabase.auth.currentUser;
        String? companyName;
        if (currentUser != null) {
          final tenant = await TenantResolverService.resolveUserTenant(currentUser);
          companyName = tenant.companyName;
        }

        // Fetch Cloud Workers
        var workerQuery = supabase.from('iron_workers').select();
        if (companyName != null && companyName.isNotEmpty) {
          workerQuery = workerQuery.eq('company_name', companyName);
        }
        final workerRes = await workerQuery;
        if (workerRes.isNotEmpty) {
          final cloudWorkers = (workerRes as List).map((e) => IronWorker.fromJson(e)).toList();
          loadedWorkers = cloudWorkers;
          await prefs.setString(_workersPrefKey, jsonEncode(loadedWorkers.map((w) => w.toJson()).toList()));
        }

        // Fetch Cloud Task Allocations
        var taskQuery = supabase.from('iron_task_allocations').select();
        if (companyName != null && companyName.isNotEmpty) {
          taskQuery = taskQuery.eq('company_name', companyName);
        }
        final taskRes = await taskQuery;
        if (taskRes.isNotEmpty) {
          final cloudTasks = (taskRes as List).map((e) => IronTaskAllocation.fromJson(e)).toList();
          loadedTasks = cloudTasks;
          await prefs.setString(_tasksPrefKey, jsonEncode(loadedTasks.map((t) => t.toJson()).toList()));
        }
      } catch (err) {
        debugPrint('Supabase iron sync notice: $err');
      }

      state = state.copyWith(
        isLoading: false,
        isSyncing: false,
        buyers: kInitialIronBuyers,
        selectedBuyerId: state.selectedBuyerId.isEmpty ? 'byr-ollywood' : state.selectedBuyerId,
        workers: loadedWorkers,
        taskAllocations: loadedTasks,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isSyncing: false,
        error: e.toString(),
        buyers: kInitialIronBuyers,
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

  Future<void> addWorker({
    required String name,
    required String phone,
    required String password,
    required List<String> roles,
    String assignedTable = 'Table 01 (Vacuum Buck)',
    String shift = 'SHIFT_1',
  }) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final phone10 = cleanPhone.length >= 10 ? cleanPhone.substring(cleanPhone.length - 10) : cleanPhone;
    final primaryRole = roles.isNotEmpty ? roles.first.replaceAll('_', ' ') : 'Finishing Presser';

    final newWorker = IronWorker(
      id: 'iw-${DateTime.now().millisecondsSinceEpoch}',
      workerName: name.trim(),
      phoneNumber: phone10,
      roles: roles,
      role: primaryRole,
      assignedTable: assignedTable,
      shift: shift,
      isActive: true,
      completedPieces: 0,
      createdAt: DateTime.now(),
    );

    final updated = [newWorker, ...state.workers];
    state = state.copyWith(workers: updated);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_workersPrefKey, jsonEncode(updated.map((w) => w.toJson()).toList()));

    try {
      final currentUser = supabase.auth.currentUser;
      String? companyName;
      if (currentUser != null) {
        final tenant = await TenantResolverService.resolveUserTenant(currentUser);
        companyName = tenant.companyName;
      }

      await supabase.from('iron_workers').upsert({
        'worker_name': newWorker.workerName,
        'phone_number': phone10,
        'worker_email': '$phone10@iron.nubira.local',
        'roles': roles,
        'role': primaryRole,
        'assigned_table': assignedTable,
        'shift': shift,
        'status': 'ACTIVE',
        'company_name': companyName,
      }, onConflict: 'phone_number');
    } catch (e) {
      debugPrint('Cloud insert error for iron worker: $e');
    }
  }

  Future<void> toggleWorkerStatus(IronWorker worker) async {
    final updated = state.workers.map((w) {
      if (w.id == worker.id || w.phoneNumber == worker.phoneNumber) {
        return w.copyWith(isActive: !w.isActive);
      }
      return w;
    }).toList();

    state = state.copyWith(workers: updated);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_workersPrefKey, jsonEncode(updated.map((w) => w.toJson()).toList()));

    try {
      await supabase.from('iron_workers').update({
        'status': !worker.isActive ? 'ACTIVE' : 'INACTIVE',
      }).eq('phone_number', worker.phoneNumber);
    } catch (e) {
      debugPrint('Cloud update worker status error: $e');
    }
  }

  Future<void> deleteWorker(String id) async {
    final worker = state.workers.firstWhere((w) => w.id == id, orElse: () => IronWorker(id: '', workerName: '', phoneNumber: ''));
    final updated = state.workers.where((w) => w.id != id).toList();
    state = state.copyWith(workers: updated);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_workersPrefKey, jsonEncode(updated.map((w) => w.toJson()).toList()));

    try {
      if (worker.phoneNumber.isNotEmpty) {
        await supabase.from('iron_workers').delete().eq('phone_number', worker.phoneNumber);
      } else {
        await supabase.from('iron_workers').delete().eq('id', id);
      }
    } catch (e) {
      debugPrint('Cloud delete error: $e');
    }
  }

  Future<void> addTaskAllocation({
    required IronBuyerContract buyer,
    required IronWorker worker,
    required int pieces,
    required String articleNumber,
    required String table,
    required double allotedHours,
    int ironTempC = 150,
    String shift = 'SHIFT_1',
  }) async {
    final taskRef = 'IRN-${DateTime.now().millisecondsSinceEpoch.toString().substring(DateTime.now().millisecondsSinceEpoch.toString().length - 6)}';
    
    final newTask = IronTaskAllocation(
      id: 'itask-${DateTime.now().millisecondsSinceEpoch}',
      taskRef: taskRef,
      buyerId: buyer.id,
      buyerName: buyer.buyerName,
      articleNumber: articleNumber.toUpperCase().trim(),
      articleName: buyer.linkedArticleName,
      workerId: worker.id,
      workerName: worker.workerName,
      workerPhone: worker.phoneNumber,
      machineTable: table,
      piecesToPress: pieces,
      completedPieces: 0,
      allotedHours: allotedHours,
      shift: shift,
      ironTempC: ironTempC,
      status: 'PENDING',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final updated = [newTask, ...state.taskAllocations];
    state = state.copyWith(taskAllocations: updated);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tasksPrefKey, jsonEncode(updated.map((t) => t.toJson()).toList()));

    try {
      final currentUser = supabase.auth.currentUser;
      String? companyName;
      if (currentUser != null) {
        final tenant = await TenantResolverService.resolveUserTenant(currentUser);
        companyName = tenant.companyName;
      }

      await supabase.from('iron_task_allocations').insert({
        'task_ref': newTask.taskRef,
        'buyer_id': newTask.buyerId,
        'buyer_name': newTask.buyerName,
        'article_number': newTask.articleNumber,
        'article_name': newTask.articleName,
        'worker_id': newTask.workerId,
        'worker_name': newTask.workerName,
        'worker_phone': newTask.workerPhone,
        'machine_table': newTask.machineTable,
        'pieces_to_press': newTask.piecesToPress,
        'completed_pieces': 0,
        'alloted_hours': newTask.allotedHours,
        'shift': newTask.shift,
        'iron_temp_c': newTask.ironTempC,
        'status': newTask.status,
        'company_name': companyName,
      });
    } catch (e) {
      debugPrint('Cloud insert task error: $e');
    }
  }

  Future<void> verifyAndDone(String taskId, int pieces) async {
    final updated = state.taskAllocations.map((t) {
      if (t.id == taskId || t.taskRef == taskId) {
        return t.copyWith(
          status: 'VERIFIED_COMPLETED',
          completedPieces: pieces,
          completedAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }
      return t;
    }).toList();

    state = state.copyWith(taskAllocations: updated);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tasksPrefKey, jsonEncode(updated.map((t) => t.toJson()).toList()));

    try {
      await supabase.from('iron_task_allocations').update({
        'status': 'VERIFIED_COMPLETED',
        'completed_pieces': pieces,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('task_ref', taskId);
    } catch (e) {
      debugPrint('Cloud verify task error: $e');
    }
  }

  Future<void> deleteTaskAllocation(String taskId) async {
    final updated = state.taskAllocations.where((t) => t.id != taskId && t.taskRef != taskId).toList();
    state = state.copyWith(taskAllocations: updated);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tasksPrefKey, jsonEncode(updated.map((t) => t.toJson()).toList()));

    try {
      await supabase.from('iron_task_allocations').delete().or('id.eq.$taskId,task_ref.eq.$taskId');
    } catch (e) {
      debugPrint('Cloud delete task error: $e');
    }
  }
}

final ironProvider = StateNotifierProvider<IronNotifier, IronState>((ref) {
  return IronNotifier();
});
