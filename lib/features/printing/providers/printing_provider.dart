import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../main.dart';
import '../../auth/providers/auth_provider.dart';
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
    this.strikeOffApproval = const StrikeOffApproval(),
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

  String _getCompanyFilter() {
    final authState = ref.read(authProvider);
    final tenant = authState.tenantProfile;
    return (tenant?.companyName ?? 'Nubira Creation').trim();
  }

  Future<void> loadInitialData() async {
    state = state.copyWith(isLoading: true, error: null);
    final prefs = await SharedPreferences.getInstance();

    // 1. Load from local cache first
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
      StrikeOffApproval strikeOff = const StrikeOffApproval();

      if (cachedWorkers != null) {
        final decoded = jsonDecode(cachedWorkers) as List;
        workers = decoded.map((e) => PrintingWorker.fromJson(e)).toList();
      }
      if (cachedTasks != null) {
        final decoded = jsonDecode(cachedTasks) as List;
        tasks = decoded.map((e) => PrintingTaskAllocation.fromJson(e)).toList();
      }
      if (cachedBuyers != null) {
        final decoded = jsonDecode(cachedBuyers) as List;
        buyers = decoded.map((e) => PrintingBuyerContract.fromJson(e)).toList();
      }
      if (cachedRoutes != null) {
        final decoded = jsonDecode(cachedRoutes) as Map<String, dynamic>;
        routes = decoded.map((k, v) => MapEntry(k, v.toString()));
      }
      if (cachedStrikeOff != null) {
        strikeOff = StrikeOffApproval.fromJson(jsonDecode(cachedStrikeOff));
      }

      if (workers.isNotEmpty || tasks.isNotEmpty || buyers.isNotEmpty) {
        state = state.copyWith(
          isLoading: false,
          workers: workers,
          taskAllocations: tasks,
          buyers: buyers,
          articleRoutes: routes,
          strikeOffApproval: strikeOff,
          selectedBuyerId: state.selectedBuyerId.isNotEmpty
              ? state.selectedBuyerId
              : (buyers.isNotEmpty ? buyers.first.id : ''),
        );
      }
    } catch (_) {}

    // 2. Fetch live data from Supabase backend
    await syncData();
  }

  Future<void> syncData() async {
    state = state.copyWith(isSyncing: true, error: null);
    final company = _getCompanyFilter();

    try {
      // Parallel fetch from Supabase
      final results = await Future.wait([
        _fetchWorkersFromSupabase(company),
        _fetchTasksFromSupabase(company),
        _fetchBuyersFromSupabase(company),
        _fetchUpstreamCuttingPieces(company),
        _fetchUpstreamEmbroideryPieces(company),
      ]);

      final freshWorkers = results[0] as List<PrintingWorker>;
      final freshTasks = results[1] as List<PrintingTaskAllocation>;
      final freshBuyers = results[2] as List<PrintingBuyerContract>;
      final upstreamCut = results[3] as int;
      final upstreamEmbroidery = results[4] as int;

      // Seed fallback demo data if server tables are empty
      final finalWorkers = freshWorkers.isNotEmpty ? freshWorkers : _getFallbackWorkers();
      final finalBuyers = freshBuyers.isNotEmpty ? freshBuyers : _getFallbackBuyers();
      final finalTasks = freshTasks.isNotEmpty ? freshTasks : _getFallbackTasks();

      final activeBuyerId = state.selectedBuyerId.isNotEmpty &&
              finalBuyers.any((b) => b.id == state.selectedBuyerId)
          ? state.selectedBuyerId
          : (finalBuyers.isNotEmpty ? finalBuyers.first.id : '');

      state = state.copyWith(
        isLoading: false,
        isSyncing: false,
        workers: finalWorkers,
        taskAllocations: finalTasks,
        buyers: finalBuyers,
        selectedBuyerId: activeBuyerId,
        upstreamCutPieces: upstreamCut > 0 ? upstreamCut : 1420,
        upstreamEmbroideryPieces: upstreamEmbroidery > 0 ? upstreamEmbroidery : 850,
      );

      // Save to SharedPreferences cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_printing_workers', jsonEncode(finalWorkers.map((e) => e.toJson()).toList()));
      await prefs.setString('cached_printing_tasks', jsonEncode(finalTasks.map((e) => e.toJson()).toList()));
      await prefs.setString('cached_printing_buyers', jsonEncode(finalBuyers.map((e) => {
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
      state = state.copyWith(
        isLoading: false,
        isSyncing: false,
        error: 'Network sync notice: ${e.toString()}',
      );
    }
  }

  Future<List<PrintingWorker>> _fetchWorkersFromSupabase(String company) async {
    try {
      final res = await supabase
          .from('printing_workers')
          .select('*')
          .eq('company_name', company)
          .order('created_at', ascending: false);
      return (res as List).map((e) => PrintingWorker.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<PrintingTaskAllocation>> _fetchTasksFromSupabase(String company) async {
    try {
      final res = await supabase
          .from('printing_task_allocations')
          .select('*')
          .eq('company_name', company)
          .order('created_at', ascending: false);
      return (res as List).map((e) => PrintingTaskAllocation.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<PrintingBuyerContract>> _fetchBuyersFromSupabase(String company) async {
    try {
      final res = await supabase
          .from('merchandising_active_buyers')
          .select('*')
          .eq('company_name', company)
          .order('created_at', ascending: false);
      return (res as List).map((e) => PrintingBuyerContract.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<int> _fetchUpstreamCuttingPieces(String company) async {
    try {
      final res = await supabase
          .from('cutting_task_allocations')
          .select('completed_pieces, pieces_to_cut, status')
          .eq('company_name', company);
      int sum = 0;
      for (final r in (res as List)) {
        final status = r['status']?.toString();
        if (status == 'VERIFIED_COMPLETED' || status == 'COMPLETED') {
          sum += ((r['completed_pieces'] ?? r['pieces_to_cut']) as num?)?.toInt() ?? 0;
        }
      }
      return sum;
    } catch (_) {
      return 0;
    }
  }

  Future<int> _fetchUpstreamEmbroideryPieces(String company) async {
    try {
      final res = await supabase
          .from('embroidery_task_allocations')
          .select('completed_pieces, pieces_to_embroider, status')
          .eq('company_name', company);
      int sum = 0;
      for (final r in (res as List)) {
        final status = r['status']?.toString();
        if (status == 'VERIFIED_COMPLETED' || status == 'COMPLETED') {
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
    final company = _getCompanyFilter();
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
    final company = _getCompanyFilter();
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

  // Fallback seed data
  List<PrintingWorker> _getFallbackWorkers() {
    return [
      PrintingWorker(
        id: 'pw-101',
        workerName: 'Rajesh Sharma',
        phoneNumber: '9876543211',
        workerEmail: '9876543211@printing.nubira.local',
        roles: const ['SCREEN_PRINTER', 'CAROUSEL_MASTER'],
        role: 'Screen Printer, Carousel Master',
        shift: 'MORNING',
        status: 'ACTIVE',
        assignedPieces: 450,
        completedPieces: 450,
        createdAt: '2026-09-18T00:00:00.000Z',
      ),
      PrintingWorker(
        id: 'pw-102',
        workerName: 'Amit Mondal',
        phoneNumber: '9876543212',
        workerEmail: '9876543212@printing.nubira.local',
        roles: const ['DTG_SPECIALIST'],
        role: 'DTG Specialist',
        shift: 'EVENING',
        status: 'ACTIVE',
        assignedPieces: 300,
        completedPieces: 150,
        createdAt: '2026-09-19T00:00:00.000Z',
      ),
      PrintingWorker(
        id: 'pw-103',
        workerName: 'Sunil Das',
        phoneNumber: '9876543213',
        workerEmail: '9876543213@printing.nubira.local',
        roles: const ['CURING_OVEN_OPERATOR'],
        role: 'Curing Oven Operator',
        shift: 'NIGHT',
        status: 'ACTIVE',
        assignedPieces: 600,
        completedPieces: 600,
        createdAt: '2026-09-20T00:00:00.000Z',
      ),
    ];
  }

  List<PrintingBuyerContract> _getFallbackBuyers() {
    return [
      const PrintingBuyerContract(
        id: 'byr-01',
        buyerName: 'Ollywood Brand Global',
        buyerCode: 'OLLY',
        contractedVolume: 3500,
        pricePerPiece: 14.50,
        totalContractValue: 50750,
        linkedArticleNumber: 'ART-TEE-882',
        linkedArticleName: 'Premium Graphic Cotton Tee',
        embellishmentSequence: 'PRINT_FIRST_THEN_EMBROIDERY',
      ),
      const PrintingBuyerContract(
        id: 'byr-02',
        buyerName: 'Urban Heritage Lifestyle',
        buyerCode: 'URBN',
        contractedVolume: 2200,
        pricePerPiece: 18.00,
        totalContractValue: 39600,
        linkedArticleNumber: 'ART-HOODIE-104',
        linkedArticleName: 'Front Chest Plastisol Hoodie',
        embellishmentSequence: 'PRINTING_ONLY',
      ),
      const PrintingBuyerContract(
        id: 'byr-03',
        buyerName: 'Nordic Trend Exports',
        buyerCode: 'NORD',
        contractedVolume: 1800,
        pricePerPiece: 12.00,
        totalContractValue: 21600,
        linkedArticleNumber: 'ART-JOGGER-301',
        linkedArticleName: 'Waterbase Side-Print Joggers',
        embellishmentSequence: 'EMBROIDERY_FIRST_THEN_PRINT',
      ),
    ];
  }

  List<PrintingTaskAllocation> _getFallbackTasks() {
    return [
      PrintingTaskAllocation(
        id: 'task-prn-01',
        taskRef: 'PRN-101',
        buyerId: 'byr-01',
        buyerName: 'Ollywood Brand Global',
        articleNumber: 'ART-TEE-882',
        articleName: 'Premium Graphic Cotton Tee',
        workerId: 'pw-101',
        workerName: 'Rajesh Sharma',
        workerPhone: '9876543211',
        tableNumber: 'Print Table 01 (Screen 4-Color)',
        piecesToPrint: 450,
        completedPieces: 450,
        allotedHours: 6.0,
        status: 'VERIFIED_COMPLETED',
        createdAt: '2026-09-24T09:00:00.000Z',
        completedAt: '2026-09-24T15:00:00.000Z',
      ),
      PrintingTaskAllocation(
        id: 'task-prn-02',
        taskRef: 'PRN-102',
        buyerId: 'byr-01',
        buyerName: 'Ollywood Brand Global',
        articleNumber: 'ART-TEE-882',
        articleName: 'Premium Graphic Cotton Tee',
        workerId: 'pw-102',
        workerName: 'Amit Mondal',
        workerPhone: '9876543212',
        tableNumber: 'Automatic Carousel A (6-Head)',
        piecesToPrint: 350,
        completedPieces: 200,
        allotedHours: 8.0,
        status: 'IN_PROGRESS',
        notes: 'Plastisol curing at 165°C, 2.5 min conveyor dwell time',
        createdAt: '2026-09-25T08:30:00.000Z',
      ),
    ];
  }
}

final printingProvider = StateNotifierProvider<PrintingNotifier, PrintingState>((ref) {
  return PrintingNotifier(ref);
});
