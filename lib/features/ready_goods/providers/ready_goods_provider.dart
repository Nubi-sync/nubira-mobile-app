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
  final List<ReadyGoodsCarton> cartons;
  final List<AqlAuditRecord> aqlAudits;
  final List<ReadyGoodsBuyer> buyers;
  final String selectedBuyerId; // 'ALL' or specific buyer ID
  final String statusFilter; // 'ALL', 'PENDING', 'IN_CHECKING', 'ALTERATION', 'PASSED', 'CARTONS'
  final String searchQuery;

  const ReadyGoodsState({
    this.isLoading = false,
    this.workers = const [],
    this.tasks = const [],
    this.cartons = const [],
    this.aqlAudits = const [],
    this.buyers = const [],
    this.selectedBuyerId = 'ALL',
    this.statusFilter = 'ALL',
    this.searchQuery = '',
  });

  ReadyGoodsState copyWith({
    bool? isLoading,
    List<ReadyGoodsWorker>? workers,
    List<FinishingInspectionTask>? tasks,
    List<ReadyGoodsCarton>? cartons,
    List<AqlAuditRecord>? aqlAudits,
    List<ReadyGoodsBuyer>? buyers,
    String? selectedBuyerId,
    String? statusFilter,
    String? searchQuery,
  }) {
    return ReadyGoodsState(
      isLoading: isLoading ?? this.isLoading,
      workers: workers ?? this.workers,
      tasks: tasks ?? this.tasks,
      cartons: cartons ?? this.cartons,
      aqlAudits: aqlAudits ?? this.aqlAudits,
      buyers: buyers ?? this.buyers,
      selectedBuyerId: selectedBuyerId ?? this.selectedBuyerId,
      statusFilter: statusFilter ?? this.statusFilter,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  // Active filtered tasks
  List<FinishingInspectionTask> get filteredTasks {
    return tasks.where((t) {
      // 1. Buyer filter
      if (selectedBuyerId != 'ALL') {
        final buyerMatch = t.buyer.toLowerCase() == selectedBuyerId.toLowerCase();
        if (!buyerMatch) return false;
      }

      // 2. Status filter
      if (statusFilter == 'PENDING' && t.status != 'PENDING_CHECK') return false;
      if (statusFilter == 'IN_CHECKING' && t.status != 'IN_CHECKING') return false;
      if (statusFilter == 'ALTERATION' && t.status != 'REJECTED_TO_ALTERATION') return false;
      if (statusFilter == 'PASSED' && t.status != 'PASSED_TO_PACKING') return false;
      if (statusFilter == 'CARTONS' && t.status != 'PACKED_IN_CARTON') return false;

      // 3. Search query
      if (searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase();
        return t.lotNumber.toLowerCase().contains(q) ||
            t.orderNumber.toLowerCase().contains(q) ||
            t.styleName.toLowerCase().contains(q) ||
            t.buyer.toLowerCase().contains(q) ||
            t.taskRef.toLowerCase().contains(q);
      }

      return true;
    }).toList();
  }

  // Clearance rate & KPI statistics
  int get totalPieces => tasks.fold(0, (sum, t) => sum + t.piecesCount);
  int get passedPieces => tasks.fold(0, (sum, t) => sum + t.passedPieces);
  int get alterationPieces => tasks.fold(0, (sum, t) => sum + t.alterationPieces);
  int get inCheckingCount => tasks.where((t) => t.status == 'IN_CHECKING').length;
  int get alterationCount => tasks.where((t) => t.status == 'REJECTED_TO_ALTERATION').length;
  int get passedCount => tasks.where((t) => t.status == 'PASSED_TO_PACKING').length;
  int get packedCount => cartons.length;

  double get clearanceRate {
    if (totalPieces == 0) return 100.0;
    return ((passedPieces / totalPieces) * 100).clamp(0.0, 100.0);
  }
}

class ReadyGoodsNotifier extends StateNotifier<ReadyGoodsState> {
  static const String _workersPrefKey = 'zigza_ready_goods_workers_v1';
  static const String _tasksPrefKey = 'zigza_ready_goods_tasks_v1';
  static const String _cartonsPrefKey = 'zigza_ready_goods_cartons_v1';

  ReadyGoodsNotifier() : super(const ReadyGoodsState()) {
    fetchData();
  }

  Future<void> fetchData() async {
    state = state.copyWith(isLoading: true);
    final prefs = await SharedPreferences.getInstance();

    // Default Preset Buyers matching Web
    final List<ReadyGoodsBuyer> presetBuyers = [
      const ReadyGoodsBuyer(id: 'Zara International', buyerName: 'Zara International', buyerCode: 'ZARA-INT', contractedVolume: 12500, linkedArticleNumber: 'PO-7715', linkedArticleName: 'Heavyweight Boxy Tee'),
      const ReadyGoodsBuyer(id: 'Urban Outfitters', buyerName: 'Urban Outfitters', buyerCode: 'UO-GLOBAL', contractedVolume: 8400, linkedArticleNumber: 'PO-7714', linkedArticleName: 'French Terry Hoodie'),
      const ReadyGoodsBuyer(id: 'Tommy Hilfiger', buyerName: 'Tommy Hilfiger', buyerCode: 'TH-USA', contractedVolume: 9200, linkedArticleNumber: 'PO-7717', linkedArticleName: 'Pique Heritage Polo'),
      const ReadyGoodsBuyer(id: 'Levi Strauss Co', buyerName: 'Levi Strauss Co', buyerCode: 'LEVI-IND', contractedVolume: 15000, linkedArticleNumber: 'PO-7716', linkedArticleName: 'Denim Overshirt'),
    ];

    // Load local cache or presets
    List<ReadyGoodsWorker> workers = [];
    final workersRaw = prefs.getString(_workersPrefKey);
    if (workersRaw != null && workersRaw.isNotEmpty) {
      try {
        final List list = jsonDecode(workersRaw);
        workers = list.map((e) => ReadyGoodsWorker.fromJson(e)).toList();
      } catch (_) {}
    }
    if (workers.isEmpty) {
      workers = [
        ReadyGoodsWorker(id: 'rgw-1', workerName: 'Sunil Verma', phoneNumber: '9876543210', role: 'Chief Quality Auditor (AQL Master)', skillLevel: 'Master', completedPieces: 1420, createdAt: DateTime.now().subtract(const Duration(days: 10))),
        ReadyGoodsWorker(id: 'rgw-2', workerName: 'Ramesh Tailor', phoneNumber: '9876543211', role: 'Alteration Specialist (Seam Repair)', skillLevel: 'Senior', completedPieces: 680, createdAt: DateTime.now().subtract(const Duration(days: 8))),
        ReadyGoodsWorker(id: 'rgw-3', workerName: 'Pooja Sharma', phoneNumber: '9876543212', role: 'Polybag & Barcode Tagging Incharge', skillLevel: 'Certified', completedPieces: 2150, createdAt: DateTime.now().subtract(const Duration(days: 5))),
        ReadyGoodsWorker(id: 'rgw-4', workerName: 'Vikram Singh', phoneNumber: '9876543213', role: 'Master Carton Weighbridge Packer', skillLevel: 'Certified', completedPieces: 1800, createdAt: DateTime.now().subtract(const Duration(days: 3))),
      ];
      await prefs.setString(_workersPrefKey, jsonEncode(workers.map((e) => e.toJson()).toList()));
    }

    List<FinishingInspectionTask> tasks = [];
    final tasksRaw = prefs.getString(_tasksPrefKey);
    if (tasksRaw != null && tasksRaw.isNotEmpty) {
      try {
        final List list = jsonDecode(tasksRaw);
        tasks = list.map((e) => FinishingInspectionTask.fromJson(e)).toList();
      } catch (_) {}
    }
    if (tasks.isEmpty) {
      tasks = [
        FinishingInspectionTask(
          id: 'fit-1',
          taskRef: 'QC-7714-A',
          lotNumber: 'LOT-IRON-9401',
          orderNumber: 'PO-7714',
          styleName: 'French Terry Hoodie',
          color: 'Heather Grey',
          buyer: 'Urban Outfitters',
          stage: 'POST_IRON',
          piecesCount: 450,
          passedPieces: 435,
          alterationPieces: 15,
          checkerName: 'Sunil Verma',
          status: 'REJECTED_TO_ALTERATION',
          priority: 'RUSH',
          defectCategory: 'Seam Open / Uneven Hem',
          defectRemarks: '15 pcs have broken stitch at bottom ribbing. Sent to Alteration Clinic.',
          createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        ),
        FinishingInspectionTask(
          id: 'fit-2',
          taskRef: 'QC-7715-B',
          lotNumber: 'LOT-WASH-9484',
          orderNumber: 'PO-7715',
          styleName: 'Heavyweight Boxy Tee',
          color: 'Vintage Black',
          buyer: 'Zara International',
          stage: 'POST_WASH',
          piecesCount: 600,
          passedPieces: 600,
          alterationPieces: 0,
          checkerName: 'Sunil Verma',
          status: 'PASSED_TO_PACKING',
          priority: 'NORMAL',
          createdAt: DateTime.now().subtract(const Duration(hours: 5)),
        ),
        FinishingInspectionTask(
          id: 'fit-3',
          taskRef: 'QC-7717-C',
          lotNumber: 'LOT-PRINT-5246',
          orderNumber: 'PO-7717',
          styleName: 'Pique Heritage Polo',
          color: 'Navy Blue',
          buyer: 'Tommy Hilfiger',
          stage: 'POST_PRINT',
          piecesCount: 350,
          passedPieces: 0,
          alterationPieces: 0,
          status: 'PENDING_CHECK',
          priority: 'NORMAL',
          createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        ),
      ];
      await prefs.setString(_tasksPrefKey, jsonEncode(tasks.map((e) => e.toJson()).toList()));
    }

    List<ReadyGoodsCarton> cartons = [];
    final cartonsRaw = prefs.getString(_cartonsPrefKey);
    if (cartonsRaw != null && cartonsRaw.isNotEmpty) {
      try {
        final List list = jsonDecode(cartonsRaw);
        cartons = list.map((e) => ReadyGoodsCarton.fromJson(e)).toList();
      } catch (_) {}
    }
    if (cartons.isEmpty) {
      cartons = [
        ReadyGoodsCarton(
          id: 'ctn-1',
          cartonNumber: 'CTN-7715-01',
          orderNumber: 'PO-7715',
          buyer: 'Zara International',
          styleName: 'Heavyweight Boxy Tee',
          color: 'Vintage Black',
          totalPieces: 50,
          measuredWeightKg: 14.8,
          expectedWeightKg: 15.0,
          status: 'AQL_PASSED',
          godownBay: 'BAY_3',
          sealedBy: 'Vikram Singh',
          createdAt: DateTime.now().subtract(const Duration(hours: 4)),
        ),
        ReadyGoodsCarton(
          id: 'ctn-2',
          cartonNumber: 'CTN-7715-02',
          orderNumber: 'PO-7715',
          buyer: 'Zara International',
          styleName: 'Heavyweight Boxy Tee',
          color: 'Vintage Black',
          totalPieces: 50,
          measuredWeightKg: 14.9,
          expectedWeightKg: 15.0,
          status: 'PACKED',
          godownBay: 'BAY_3',
          sealedBy: 'Vikram Singh',
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
      ];
      await prefs.setString(_cartonsPrefKey, jsonEncode(cartons.map((e) => e.toJson()).toList()));
    }

    state = state.copyWith(
      isLoading: false,
      workers: workers,
      tasks: tasks,
      cartons: cartons,
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
    required String lotNumber,
    required String orderNumber,
    required String styleName,
    required String color,
    required String buyer,
    required String stage,
    required int piecesCount,
    required String priority,
  }) async {
    final newTask = FinishingInspectionTask(
      id: 'fit-${DateTime.now().millisecondsSinceEpoch}',
      taskRef: 'QC-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
      lotNumber: lotNumber,
      orderNumber: orderNumber,
      styleName: styleName,
      color: color,
      buyer: buyer,
      stage: stage,
      piecesCount: piecesCount,
      priority: priority,
      status: 'PENDING_CHECK',
      createdAt: DateTime.now(),
    );

    final updated = [newTask, ...state.tasks];
    state = state.copyWith(tasks: updated);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tasksPrefKey, jsonEncode(updated.map((e) => e.toJson()).toList()));
  }

  Future<void> recordInspectionResult({
    required String taskId,
    required int passedPieces,
    required int alterationPieces,
    required String checkerName,
    String? defectCategory,
    String? remarks,
  }) async {
    final updated = state.tasks.map((t) {
      if (t.id != taskId) return t;
      final String nextStatus = alterationPieces > 0 ? 'REJECTED_TO_ALTERATION' : 'PASSED_TO_PACKING';
      return t.copyWith(
        passedPieces: passedPieces,
        alterationPieces: alterationPieces,
        checkerName: checkerName,
        status: nextStatus,
        defectCategory: defectCategory,
        defectRemarks: remarks,
      );
    }).toList();

    state = state.copyWith(tasks: updated);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tasksPrefKey, jsonEncode(updated.map((e) => e.toJson()).toList()));
  }

  Future<void> packCarton({
    required String cartonNumber,
    required String orderNumber,
    required String buyer,
    required String styleName,
    required String color,
    required int totalPieces,
    required double measuredWeightKg,
    required String godownBay,
    required String sealedBy,
  }) async {
    final newCarton = ReadyGoodsCarton(
      id: 'ctn-${DateTime.now().millisecondsSinceEpoch}',
      cartonNumber: cartonNumber,
      orderNumber: orderNumber,
      buyer: buyer,
      styleName: styleName,
      color: color,
      totalPieces: totalPieces,
      measuredWeightKg: measuredWeightKg,
      godownBay: godownBay,
      sealedBy: sealedBy,
      status: 'PACKED',
      createdAt: DateTime.now(),
    );

    final updated = [newCarton, ...state.cartons];
    state = state.copyWith(cartons: updated);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cartonsPrefKey, jsonEncode(updated.map((e) => e.toJson()).toList()));
  }

  Future<void> recordAqlAudit({
    required String cartonNumber,
    required String orderNumber,
    required int sampleSize,
    required int criticalDefects,
    required int majorDefects,
    required int minorDefects,
    required String decision,
    required String inspectorName,
    required String remarks,
  }) async {
    final newAudit = AqlAuditRecord(
      id: 'aql-${DateTime.now().millisecondsSinceEpoch}',
      auditNumber: 'AQL-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      orderNumber: orderNumber,
      cartonNumber: cartonNumber,
      sampleSize: sampleSize,
      criticalDefects: criticalDefects,
      majorDefects: majorDefects,
      minorDefects: minorDefects,
      decision: decision,
      inspectorName: inspectorName,
      remarks: remarks,
      auditDate: DateTime.now(),
    );

    // Also update matching carton status
    final updatedCartons = state.cartons.map((c) {
      if (c.cartonNumber == cartonNumber) {
        return c.copyWith(status: decision == 'PASS' ? 'AQL_PASSED' : 'QUARANTINED');
      }
      return c;
    }).toList();

    state = state.copyWith(
      aqlAudits: [newAudit, ...state.aqlAudits],
      cartons: updatedCartons,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cartonsPrefKey, jsonEncode(updatedCartons.map((e) => e.toJson()).toList()));
  }

  Future<void> deleteTask(String taskId) async {
    final updated = state.tasks.where((t) => t.id != taskId).toList();
    state = state.copyWith(tasks: updated);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tasksPrefKey, jsonEncode(updated.map((e) => e.toJson()).toList()));
  }
}

final readyGoodsProvider = StateNotifierProvider<ReadyGoodsNotifier, ReadyGoodsState>((ref) {
  return ReadyGoodsNotifier();
});
