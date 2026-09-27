import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../main.dart';
import '../../../core/services/tenant_resolver_service.dart';
import '../models/washing_models.dart';

class WashingState {
  final bool isLoading;
  final bool isSyncing;
  final String? error;
  final List<WashingWorker> workers;
  final List<WashingTaskAllocation> taskAllocations;
  final List<WashingBuyerContract> buyers;
  final String selectedBuyerId;
  final String statusFilter; // ALL, ACTIVE, NEEDS_VERIFY, COMPLETED
  final String searchQuery;
  final List<String> availableMachines;
  final List<String> availableRecipes;

  const WashingState({
    this.isLoading = false,
    this.isSyncing = false,
    this.error,
    this.workers = const [],
    this.taskAllocations = const [],
    this.buyers = const [],
    this.selectedBuyerId = 'byr-ollywood',
    this.statusFilter = 'ALL',
    this.searchQuery = '',
    this.availableMachines = const [
      'Washer 01 (Industrial Tumbler)',
      'Washer 02 (Hydro Extractor)',
      'Washer 03 (Front Load 120kg)',
      'Washer 04 (Bio-Polisher)',
      'Washer 05 (Silicon Bath)',
      'Washer 06 (Steam Tumbler)',
    ],
    this.availableRecipes = const [
      'Bio-Enzyme Wash 55°C',
      'Silicon Softening 40°C',
      'Stone Enzyme Wash',
      'Acid Wash & Neutralize',
      'Garment Tint & Dye 60°C',
      'Vintage Fade & Whiskering',
    ],
  });

  WashingState copyWith({
    bool? isLoading,
    bool? isSyncing,
    String? error,
    List<WashingWorker>? workers,
    List<WashingTaskAllocation>? taskAllocations,
    List<WashingBuyerContract>? buyers,
    String? selectedBuyerId,
    String? statusFilter,
    String? searchQuery,
    List<String>? availableMachines,
    List<String>? availableRecipes,
  }) {
    return WashingState(
      isLoading: isLoading ?? this.isLoading,
      isSyncing: isSyncing ?? this.isSyncing,
      error: error,
      workers: workers ?? this.workers,
      taskAllocations: taskAllocations ?? this.taskAllocations,
      buyers: buyers ?? this.buyers,
      selectedBuyerId: selectedBuyerId ?? this.selectedBuyerId,
      statusFilter: statusFilter ?? this.statusFilter,
      searchQuery: searchQuery ?? this.searchQuery,
      availableMachines: availableMachines ?? this.availableMachines,
      availableRecipes: availableRecipes ?? this.availableRecipes,
    );
  }
}

const List<WashingBuyerContract> kInitialWashingBuyers = [];

class WashingNotifier extends StateNotifier<WashingState> {
  WashingNotifier() : super(const WashingState()) {
    loadInitialData();
  }

  static const _workersPrefKey = 'zigza_washing_workers_v1';
  static const _tasksPrefKey = 'zigza_washing_task_allocations_v1';

  Future<void> loadInitialData({bool isRefresh = false}) async {
    if (isRefresh) {
      state = state.copyWith(isSyncing: true, error: null);
    } else {
      state = state.copyWith(isLoading: true, error: null);
    }

    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Load Workers
      List<WashingWorker> loadedWorkers = [];
      final workersRaw = prefs.getString(_workersPrefKey);
      if (workersRaw != null && workersRaw.isNotEmpty) {
        try {
          final decoded = jsonDecode(workersRaw) as List;
          loadedWorkers = decoded.map((e) => WashingWorker.fromJson(e as Map<String, dynamic>)).toList();
        } catch (_) {}
      }

      // 2. Load Task Allocations
      List<WashingTaskAllocation> loadedTasks = [];
      final tasksRaw = prefs.getString(_tasksPrefKey);
      if (tasksRaw != null && tasksRaw.isNotEmpty) {
        try {
          final decoded = jsonDecode(tasksRaw) as List;
          loadedTasks = decoded.map((e) => WashingTaskAllocation.fromJson(e as Map<String, dynamic>)).toList();
        } catch (_) {}
      }

      // Filter out legacy mock data if any
      loadedTasks = loadedTasks.where((t) {
        final ref = t.taskRef.toUpperCase();
        return !ref.startsWith('BA-') && !ref.startsWith('WSH-TSK-MOCK');
      }).toList();

      List<WashingBuyerContract> loadedBuyers = [];

      // 3. Cloud Sync with Supabase
      try {
        final currentUser = supabase.auth.currentUser;
        String? companyName;
        if (currentUser != null) {
          final tenant = await TenantResolverService.resolveUserTenant(currentUser);
          companyName = tenant.companyName;
        }

        var query = supabase.from('washing_workers').select();
        if (companyName != null && companyName.isNotEmpty) {
          query = query.eq('company_name', companyName);
        }
        final res = await query;
        if (res.isNotEmpty) {
          final cloudWorkers = (res as List).map((e) => WashingWorker.fromJson(e)).toList();
          loadedWorkers = cloudWorkers;
          await prefs.setString(_workersPrefKey, jsonEncode(loadedWorkers.map((w) => w.toJson()).toList()));
        }

        var buyerQuery = supabase.from('merchandising_active_buyers').select();
        if (companyName != null && companyName.isNotEmpty) {
          buyerQuery = buyerQuery.eq('company_name', companyName);
        }
        final buyerRes = await buyerQuery;
        if (buyerRes.isNotEmpty) {
          loadedBuyers = (buyerRes as List).map((b) {
            final bName = (b['buyer_name']?.toString() ?? b['brand_name']?.toString() ?? 'Buyer').trim();
            final qty = ((b['contracted_volume'] as num?) ?? 0).toInt();
            return WashingBuyerContract(
              id: b['id']?.toString() ?? 'byr-${bName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '-')}',
              buyerName: bName,
              buyerCode: b['buyer_code']?.toString() ?? (bName.length >= 4 ? bName.substring(0, 4).toUpperCase() : 'BUYER'),
              contractedVolume: qty,
              pricePerPiece: (b['price_per_piece'] as num?)?.toDouble() ?? 0.0,
              totalContractValue: (b['total_contract_value'] as num?)?.toDouble() ?? 0.0,
              linkedArticleNumber: b['linked_article_number']?.toString() ?? '',
              linkedArticleName: b['linked_article_name']?.toString() ?? '',
              status: 'LINKED',
            );
          }).toList();
        }
      } catch (err) {
        debugPrint('Supabase washing sync notice: $err');
      }

      state = state.copyWith(
        isLoading: false,
        isSyncing: false,
        buyers: loadedBuyers,
        selectedBuyerId: state.selectedBuyerId.isEmpty && loadedBuyers.isNotEmpty ? loadedBuyers.first.id : state.selectedBuyerId,
        workers: loadedWorkers,
        taskAllocations: loadedTasks,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isSyncing: false,
        error: e.toString(),
        buyers: state.buyers,
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
    String machineNumber = 'Washer 01',
    String specialization = 'Bio-Enzyme & Softening',
    String shift = 'Morning (08:00 - 16:30)',
  }) async {
    final newWorker = WashingWorker(
      id: 'wsh-wrk-${DateTime.now().millisecondsSinceEpoch}',
      workerName: name,
      phoneNumber: phone,
      machineNumber: machineNumber,
      specialization: specialization,
      shift: shift,
      status: 'AVAILABLE',
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

      await supabase.from('washing_workers').insert({
        'id': newWorker.id,
        'worker_name': newWorker.workerName,
        'phone_number': newWorker.phoneNumber,
        'machine_number': newWorker.machineNumber,
        'specialization': newWorker.specialization,
        'shift': newWorker.shift,
        'status': newWorker.status,
        'company_name': companyName,
      });
    } catch (e) {
      debugPrint('Cloud insert error: $e');
    }
  }

  Future<void> deleteWorker(String id) async {
    final updated = state.workers.where((w) => w.id != id).toList();
    state = state.copyWith(workers: updated);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_workersPrefKey, jsonEncode(updated.map((w) => w.toJson()).toList()));

    try {
      await supabase.from('washing_workers').delete().eq('id', id);
    } catch (e) {
      debugPrint('Cloud delete error: $e');
    }
  }

  Future<void> addTaskAllocation({
    required WashingBuyerContract buyer,
    required WashingWorker worker,
    required int pieces,
    required String machine,
    required String washRecipe,
    String shift = 'Shift A (08:00 - 16:30)',
    String notes = '',
  }) async {
    final taskRef = (state.taskAllocations.length + 1).toString().padLeft(3, '0');
    final newTask = WashingTaskAllocation(
      id: 'wsh-tsk-${DateTime.now().millisecondsSinceEpoch}',
      taskRef: taskRef,
      buyerId: buyer.id,
      buyerName: buyer.buyerName,
      articleNumber: buyer.linkedArticleNumber,
      workerId: worker.id,
      workerName: worker.workerName,
      workerPhone: worker.phoneNumber,
      machineNumber: machine,
      piecesToWash: pieces,
      completedPieces: 0,
      washRecipe: washRecipe,
      status: 'ASSIGNED',
      targetShift: shift,
      notes: notes,
      createdAt: DateTime.now(),
    );

    final updated = [newTask, ...state.taskAllocations];
    state = state.copyWith(taskAllocations: updated);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tasksPrefKey, jsonEncode(updated.map((t) => t.toJson()).toList()));
  }

  Future<void> verifyAndDone(String taskId, int pieces) async {
    final updated = state.taskAllocations.map((t) {
      if (t.id == taskId || t.taskRef == taskId) {
        return t.copyWith(
          status: 'VERIFIED_COMPLETED',
          completedPieces: pieces,
          completedAt: DateTime.now(),
        );
      }
      return t;
    }).toList();

    state = state.copyWith(taskAllocations: updated);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tasksPrefKey, jsonEncode(updated.map((t) => t.toJson()).toList()));
  }

  Future<void> deleteTaskAllocation(String taskId) async {
    final updated = state.taskAllocations.where((t) => t.id != taskId && t.taskRef != taskId).toList();
    state = state.copyWith(taskAllocations: updated);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tasksPrefKey, jsonEncode(updated.map((t) => t.toJson()).toList()));
  }
}

final washingProvider = StateNotifierProvider<WashingNotifier, WashingState>((ref) {
  return WashingNotifier();
});
