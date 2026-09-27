import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ready_goods_models.dart';

@immutable
class ReadyGoodsState {
  final bool isLoading;
  final List<ReadyGoodsWorker> workers;
  final List<FinishingInspectionTask> tasks;
  final List<ReadyGoodsBuyer> buyers;
  final String selectedBuyerId; // 'ALL' or specific buyer name
  final String statusFilter; // 'ALL', 'PENDING', 'ALTERATION', 'PASSED'
  final String searchQuery;

  const ReadyGoodsState({
    this.isLoading = false,
    this.workers = const [],
    this.tasks = const [],
    this.buyers = const [],
    this.selectedBuyerId = 'ALL',
    this.statusFilter = 'ALL',
    this.searchQuery = '',
  });

  ReadyGoodsState copyWith({
    bool? isLoading,
    List<ReadyGoodsWorker>? workers,
    List<FinishingInspectionTask>? tasks,
    List<ReadyGoodsBuyer>? buyers,
    String? selectedBuyerId,
    String? statusFilter,
    String? searchQuery,
  }) {
    return ReadyGoodsState(
      isLoading: isLoading ?? this.isLoading,
      workers: workers ?? this.workers,
      tasks: tasks ?? this.tasks,
      buyers: buyers ?? this.buyers,
      selectedBuyerId: selectedBuyerId ?? this.selectedBuyerId,
      statusFilter: statusFilter ?? this.statusFilter,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  // Scoped tasks for selected buyer
  List<FinishingInspectionTask> get buyerTasks {
    if (selectedBuyerId == 'ALL') return tasks;
    return tasks.where((t) => t.buyer.trim().toLowerCase() == selectedBuyerId.trim().toLowerCase()).toList();
  }

  // Filtered tasks by search & status tab
  List<FinishingInspectionTask> get filteredTasks {
    return buyerTasks.where((task) {
      final q = searchQuery.toLowerCase().trim();
      final matchesSearch = q.isEmpty ||
          task.taskCode.toLowerCase().contains(q) ||
          task.orderNumber.toLowerCase().contains(q) ||
          task.buyer.toLowerCase().contains(q) ||
          task.styleName.toLowerCase().contains(q) ||
          task.color.toLowerCase().contains(q) ||
          task.washBatchRef.toLowerCase().contains(q) ||
          task.ironStationRef.toLowerCase().contains(q);

      if (!matchesSearch) return false;

      if (statusFilter == 'PENDING') {
        return task.status == 'PENDING_CHECK' || task.status == 'IN_CHECKING';
      } else if (statusFilter == 'ALTERATION') {
        return task.status == 'REJECTED_TO_ALTERATION';
      } else if (statusFilter == 'PASSED') {
        return task.status == 'PASSED_TO_PACKING' || task.status == 'PACKED_IN_CARTON';
      }
      return true;
    }).toList();
  }

  // Pure 3 Stat Card Counts matching Web exactly
  int get inspectionQueueCount => buyerTasks.where((t) => t.status == 'PENDING_CHECK' || t.status == 'IN_CHECKING').length;
  int get alterationCount => buyerTasks.where((t) => t.status == 'REJECTED_TO_ALTERATION').length;
  int get passedCount => buyerTasks.where((t) => t.status == 'PASSED_TO_PACKING' || t.status == 'PACKED_IN_CARTON').length;
  int get totalPieces => buyerTasks.fold(0, (sum, t) => sum + t.piecesCount);
}

class ReadyGoodsNotifier extends StateNotifier<ReadyGoodsState> {
  static const String _workersPrefKey = 'zigza_ready_goods_workers_v1';
  static const String _tasksPrefKey = 'zigza_ready_goods_inspection_tasks_v1';

  ReadyGoodsNotifier() : super(const ReadyGoodsState()) {
    fetchData();
  }

  Future<void> fetchData() async {
    state = state.copyWith(isLoading: true);
    final prefs = await SharedPreferences.getInstance();

    // Default Preset Buyers matching Web
    final List<ReadyGoodsBuyer> presetBuyers = [
      const ReadyGoodsBuyer(id: 'Zara International', buyerName: 'Zara International', buyerCode: 'ZARA-INT', contractedVolume: 12500, linkedArticleNumber: 'PO-7715', linkedArticleName: 'Heavyweight Boxy Drop-Shoulder Tee'),
      const ReadyGoodsBuyer(id: 'Urban Outfitters', buyerName: 'Urban Outfitters', buyerCode: 'UO-GLOBAL', contractedVolume: 8400, linkedArticleNumber: 'PO-7714', linkedArticleName: 'French Terry Relaxed Hoodie'),
      const ReadyGoodsBuyer(id: 'Tommy Hilfiger', buyerName: 'Tommy Hilfiger', buyerCode: 'TH-USA', contractedVolume: 9200, linkedArticleNumber: 'PO-7717', linkedArticleName: 'Pique Heritage Polo'),
      const ReadyGoodsBuyer(id: 'Levi Strauss Co', buyerName: 'Levi Strauss Co', buyerCode: 'LEVI-IND', contractedVolume: 15000, linkedArticleNumber: 'PO-7716', linkedArticleName: 'Raw Denim Workwear Overshirt'),
    ];

    List<ReadyGoodsWorker> workers = [];
    final workersRaw = prefs.getString(_workersPrefKey);
    if (workersRaw != null && workersRaw.isNotEmpty) {
      try {
        final List list = jsonDecode(workersRaw);
        workers = list.map((e) => ReadyGoodsWorker.fromJson(e)).toList();
      } catch (_) {}
    }

    List<FinishingInspectionTask> tasks = [];
    final tasksRaw = prefs.getString(_tasksPrefKey);
    if (tasksRaw != null && tasksRaw.isNotEmpty) {
      try {
        final List list = jsonDecode(tasksRaw);
        tasks = list.map((e) => FinishingInspectionTask.fromJson(e)).toList();
      } catch (_) {}
    }

    state = state.copyWith(
      isLoading: false,
      workers: workers,
      tasks: tasks,
      buyers: presetBuyers,
    );
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
    required String workerName,
    required String phoneNumber,
    required String role,
    required String skillLevel,
    required String shift,
  }) async {
    final newWorker = ReadyGoodsWorker(
      id: 'rgw-${DateTime.now().millisecondsSinceEpoch}',
      workerName: workerName,
      phoneNumber: phoneNumber,
      role: role,
      skillLevel: skillLevel,
      shift: shift,
      createdAt: DateTime.now(),
    );

    final updated = [newWorker, ...state.workers];
    state = state.copyWith(workers: updated);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_workersPrefKey, jsonEncode(updated.map((e) => e.toJson()).toList()));
  }

  Future<void> deleteWorker(String id) async {
    final updated = state.workers.where((w) => w.id != id).toList();
    state = state.copyWith(workers: updated);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_workersPrefKey, jsonEncode(updated.map((e) => e.toJson()).toList()));
  }

  Future<void> inwardLot({
    required String lotCode,
    required String orderNumber,
    required String buyer,
    required String styleName,
    required String color,
    required String size,
    required int piecesCount,
    required String washBatchRef,
    required String ironStationRef,
    required bool hasPrinting,
    required bool hasEmbroidery,
    required String printEmbSummary,
    required String priority,
    String? assignedWorkerId,
    String? assignedWorkerName,
  }) async {
    final newTask = FinishingInspectionTask(
      id: 'fit-${DateTime.now().millisecondsSinceEpoch}',
      taskCode: lotCode,
      orderNumber: orderNumber,
      buyer: buyer,
      styleName: styleName,
      color: color,
      size: size,
      piecesCount: piecesCount,
      washBatchRef: washBatchRef,
      ironStationRef: ironStationRef,
      hasPrinting: hasPrinting,
      hasEmbroidery: hasEmbroidery,
      printEmbSummary: printEmbSummary,
      status: assignedWorkerId != null && assignedWorkerId.isNotEmpty ? 'IN_CHECKING' : 'PENDING_CHECK',
      checkedByWorkerId: assignedWorkerId,
      checkedByWorkerName: assignedWorkerName,
      priority: priority,
      createdAt: DateTime.now(),
    );

    final updated = [newTask, ...state.tasks];
    state = state.copyWith(tasks: updated);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tasksPrefKey, jsonEncode(updated.map((e) => e.toJson()).toList()));
  }

  Future<void> submitInspectionResult({
    required String taskId,
    required String workerName,
    required String workerId,
    required InspectionChecklist checklist,
    required bool isDefectMode,
    String? defectReason,
    String? defectNotes,
    String? defectStation,
  }) async {
    final updated = state.tasks.map((t) {
      if (t.id != taskId) return t;
      if (isDefectMode) {
        return t.copyWith(
          checkedByWorkerName: workerName,
          checkedByWorkerId: workerId,
          checklist: checklist,
          status: 'REJECTED_TO_ALTERATION',
          defectReason: defectReason ?? 'OPEN_SEAM',
          defectNotes: defectNotes ?? 'Defect flagged during inspection',
          defectStation: defectStation ?? 'Mending Station 01',
        );
      } else {
        return t.copyWith(
          checkedByWorkerName: workerName,
          checkedByWorkerId: workerId,
          checklist: checklist,
          status: 'PASSED_TO_PACKING',
          defectReason: null,
          defectNotes: null,
        );
      }
    }).toList();

    state = state.copyWith(tasks: updated);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tasksPrefKey, jsonEncode(updated.map((e) => e.toJson()).toList()));
  }

  Future<void> markRepaired(String taskId) async {
    final updated = state.tasks.map((t) {
      if (t.id != taskId) return t;
      return t.copyWith(
        status: 'IN_CHECKING',
        defectNotes: 'Repaired by Alteration Master Desk - Ready for re-check',
      );
    }).toList();

    state = state.copyWith(tasks: updated);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tasksPrefKey, jsonEncode(updated.map((e) => e.toJson()).toList()));
  }

  Future<void> deleteTask(String taskId) async {
    final updated = state.tasks.where((t) => t.id != taskId).toList();
    state = state.copyWith(tasks: updated);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tasksPrefKey, jsonEncode(updated.map((e) => e.toJson()).toList()));
  }

  Future<void> resetAllData() async {
    state = state.copyWith(tasks: [], workers: []);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tasksPrefKey);
    await prefs.remove(_workersPrefKey);
  }
}

final readyGoodsProvider = StateNotifierProvider<ReadyGoodsNotifier, ReadyGoodsState>((ref) {
  return ReadyGoodsNotifier();
});
