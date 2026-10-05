import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/providers/auth_provider.dart';

class FactoryPulseKPIs {
  final int activeStyles;
  final int runningOrders;
  final int targetPieces;
  final int todayOutput;
  final int todayTrendPct;
  final int godownStock;
  final int dispatchedPieces;

  const FactoryPulseKPIs({
    required this.activeStyles,
    required this.runningOrders,
    required this.targetPieces,
    required this.todayOutput,
    required this.todayTrendPct,
    required this.godownStock,
    required this.dispatchedPieces,
  });

  factory FactoryPulseKPIs.empty() => const FactoryPulseKPIs(
        activeStyles: 0,
        runningOrders: 0,
        targetPieces: 0,
        todayOutput: 0,
        todayTrendPct: 0,
        godownStock: 0,
        dispatchedPieces: 0,
      );
}

class ProductionPipelineStage {
  final String id;
  final String label;
  final int count;
  final String unit;
  final String status; // 'active', 'caution', 'completed', 'idle'

  const ProductionPipelineStage({
    required this.id,
    required this.label,
    required this.count,
    required this.unit,
    required this.status,
  });
}

class DailyOutputTrendItem {
  final String date;
  final String dayName;
  final int pieces;
  final bool isToday;

  const DailyOutputTrendItem({
    required this.date,
    required this.dayName,
    required this.pieces,
    required this.isToday,
  });
}

class DefectItem {
  final String name;
  final int count;
  final double pct;

  const DefectItem({
    required this.name,
    required this.count,
    required this.pct,
  });
}

class QCMetrics {
  final int totalPassed;
  final int totalRejected;
  final double passRatePct;
  final List<DefectItem> topDefects;

  const QCMetrics({
    required this.totalPassed,
    required this.totalRejected,
    required this.passRatePct,
    required this.topDefects,
  });

  factory QCMetrics.empty() => const QCMetrics(
        totalPassed: 0,
        totalRejected: 0,
        passRatePct: 100.0,
        topDefects: [],
      );
}

class BuyerOrderStatusItem {
  final String buyerName;
  final String poNumber;
  final int targetPieces;
  final int deliveredPieces;
  final int percent;
  final String status; // 'on_track', 'caution', 'behind'

  const BuyerOrderStatusItem({
    required this.buyerName,
    required this.poNumber,
    required this.targetPieces,
    required this.deliveredPieces,
    required this.percent,
    required this.status,
  });
}

class FabricStockItem {
  final String fabricType;
  final int meters;
  final int rolls;
  final String color;

  const FabricStockItem({
    required this.fabricType,
    required this.meters,
    required this.rolls,
    required this.color,
  });
}

class ArticleJourneyItem {
  final String id;
  final String artNo;
  final String description;
  final String designStatus;
  final int buyerPoTarget;
  final int fabricMetersInStore;
  final int cutPieces;
  final int stitchedPieces;
  final int qcPassedPieces;
  final int godownPieces;
  final int dispatchedPieces;
  final int overallProgressPct;

  const ArticleJourneyItem({
    required this.id,
    required this.artNo,
    required this.description,
    required this.designStatus,
    required this.buyerPoTarget,
    required this.fabricMetersInStore,
    required this.cutPieces,
    required this.stitchedPieces,
    required this.qcPassedPieces,
    required this.godownPieces,
    required this.dispatchedPieces,
    required this.overallProgressPct,
  });
}

class DivisionHeartbeatItem {
  final String id;
  final String name;
  final String route;
  final String status; // 'ACTIVE', 'LOW', 'IDLE'
  final String metric;
  final String iconName;

  const DivisionHeartbeatItem({
    required this.id,
    required this.name,
    required this.route,
    required this.status,
    required this.metric,
    required this.iconName,
  });
}

class PlantOperationsDashboardData {
  final String companyName;
  final FactoryPulseKPIs pulse;
  final List<ProductionPipelineStage> pipeline;
  final List<DailyOutputTrendItem> outputTrend;
  final int dailyAverage;
  final QCMetrics qc;
  final List<BuyerOrderStatusItem> buyerOrders;
  final List<FabricStockItem> fabricStock;
  final List<ArticleJourneyItem> articlesCatalog;
  final List<DivisionHeartbeatItem> divisionHeartbeat;
  final String lastUpdated;

  const PlantOperationsDashboardData({
    required this.companyName,
    required this.pulse,
    required this.pipeline,
    required this.outputTrend,
    required this.dailyAverage,
    required this.qc,
    required this.buyerOrders,
    required this.fabricStock,
    required this.articlesCatalog,
    required this.divisionHeartbeat,
    required this.lastUpdated,
  });

  factory PlantOperationsDashboardData.initial([String company = 'Nubira Creation']) => PlantOperationsDashboardData(
        companyName: company,
        pulse: FactoryPulseKPIs.empty(),
        pipeline: const [],
        outputTrend: const [],
        dailyAverage: 0,
        qc: QCMetrics.empty(),
        buyerOrders: const [],
        fabricStock: const [],
        articlesCatalog: const [],
        divisionHeartbeat: const [],
        lastUpdated: 'Just now',
      );
}

class PlantOperationsDashboardNotifier extends StateNotifier<AsyncValue<PlantOperationsDashboardData>> {
  final Ref ref;

  PlantOperationsDashboardNotifier(this.ref) : super(const AsyncValue.loading()) {
    fetchData();
  }

  Future<void> fetchData() async {
    state = const AsyncValue.loading();
    try {
      final authState = ref.read(authProvider);
      final tenant = authState.tenantProfile;
      final companyName = tenant?.companyName ?? 'Nubira Creation';

      final client = Supabase.instance.client;
      final now = DateTime.now();
      final todayStr = "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      final yesterday = now.subtract(const Duration(days: 1));
      final yesterdayStr = "${yesterday.year.toString().padLeft(4, '0')}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}";

      // 1. Articles Query
      var articlesQuery = client.from('articles').select('id, art_no, description, is_active, size_rates');
      final articlesRes = await articlesQuery.order('art_no', ascending: true);
      final rawArticles = (articlesRes as List<dynamic>?) ?? [];

      // 2. Challans Query
      var challansQuery = client.from('challans').select('id, challan_no, brand, total_pcs, status, notes');
      final challansRes = await challansQuery.order('created_at', ascending: false).limit(200);
      final rawChallans = (challansRes as List<dynamic>?) ?? [];

      // 3. Merchandising Orders Query
      List<dynamic> rawMerchOrders = [];
      try {
        final merchRes = await client.from('merchandising_orders').select('id, order_number, buyer_name, total_quantity, status, company_name').limit(100);
        rawMerchOrders = (merchRes as List<dynamic>?) ?? [];
      } catch (_) {}

      // 4. Fabric Inventory Query
      List<dynamic> rawFabric = [];
      try {
        final fabRes = await client.from('central_fabric_inventory').select('id, fabric_type, total_meters, total_rolls, color, company_name').limit(100);
        rawFabric = (fabRes as List<dynamic>?) ?? [];
      } catch (_) {}

      // 5. Daily Production, QC, Store Transactions, Allotments, Delivery Challans, Cutting Lay Sheets
      List<dynamic> rawDailyProd = [];
      try {
        final dailyRes = await client.from('daily_product').select('id, quantity, entry_date, article_id').order('entry_date', ascending: false).limit(600);
        rawDailyProd = (dailyRes as List<dynamic>?) ?? [];
      } catch (_) {}

      List<dynamic> rawQc = [];
      try {
        final qcRes = await client.from('qc_logs').select('id, qty_passed, qty_rejected, defect_type, entry_date, article_id').order('entry_date', ascending: false).limit(600);
        rawQc = (qcRes as List<dynamic>?) ?? [];
      } catch (_) {}

      List<dynamic> rawStore = [];
      try {
        final storeRes = await client.from('store_transactions').select('id, type, quantity, article_id, entry_date').limit(800);
        rawStore = (storeRes as List<dynamic>?) ?? [];
      } catch (_) {}

      List<dynamic> rawDispatch = [];
      try {
        final dispatchRes = await client.from('delivery_challans').select('id, challan_no, buyer_name, total_pieces, status, created_at').order('created_at', ascending: false).limit(200);
        rawDispatch = (dispatchRes as List<dynamic>?) ?? [];
      } catch (_) {}

      List<dynamic> rawCutting = [];
      try {
        final cuttingRes = await client.from('cutting_lay_sheets').select('id, actual_cut_pieces, total_plies, status, created_at').limit(300);
        rawCutting = (cuttingRes as List<dynamic>?) ?? [];
      } catch (_) {}

      List<dynamic> rawReadyGoods = [];
      try {
        final readyRes = await client.from('ready_goods_cartons').select('id, total_pieces, status, created_at').limit(300);
        rawReadyGoods = (readyRes as List<dynamic>?) ?? [];
      } catch (_) {}

      List<dynamic> rawAllotments = [];
      try {
        final allotRes = await client.from('allotments').select('id, target_qty, article_id').limit(300);
        rawAllotments = (allotRes as List<dynamic>?) ?? [];
      } catch (_) {}

      // Calculate Pulse KPIs
      final activeStyles = rawArticles.where((a) => a['is_active'] != false).length;
      final runningOrders = rawChallans.where((c) => (c['status']?.toString().toUpperCase() ?? '') != 'COMPLETED').length;
      final targetPieces = rawChallans.fold<int>(0, (sum, c) => sum + (int.tryParse(c['total_pcs']?.toString() ?? '0') ?? 0));

      final todayOutput = rawDailyProd
          .where((p) => p['entry_date'] == todayStr)
          .fold<int>(0, (sum, p) => sum + (int.tryParse(p['quantity']?.toString() ?? '0') ?? 0));

      final yesterdayOutput = rawDailyProd
          .where((p) => p['entry_date'] == yesterdayStr)
          .fold<int>(0, (sum, p) => sum + (int.tryParse(p['quantity']?.toString() ?? '0') ?? 0));

      final todayTrendPct = yesterdayOutput > 0 ? (((todayOutput - yesterdayOutput) / yesterdayOutput) * 100).round() : 0;

      int netGodownStock = 0;
      for (final tx in rawStore) {
        final q = int.tryParse(tx['quantity']?.toString() ?? '0') ?? 0;
        final type = tx['type']?.toString().toUpperCase() ?? '';
        if (type == 'INWARD') {
          netGodownStock += q;
        } else if (type == 'OUTWARD') {
          netGodownStock -= q;
        }
      }
      final godownStock = netGodownStock > 0 ? netGodownStock : 0;
      final dispatchedPieces = rawDispatch.fold<int>(0, (sum, d) => sum + (int.tryParse(d['total_pieces']?.toString() ?? '0') ?? 0));

      final pulse = FactoryPulseKPIs(
        activeStyles: activeStyles,
        runningOrders: runningOrders,
        targetPieces: targetPieces,
        todayOutput: todayOutput,
        todayTrendPct: todayTrendPct,
        godownStock: godownStock,
        dispatchedPieces: dispatchedPieces,
      );

      // Pipeline Stages
      final cutPcs = rawCutting.fold<int>(0, (sum, c) => sum + (int.tryParse(c['actual_cut_pieces']?.toString() ?? '0') ?? 0));
      final stitchPcs = rawDailyProd.fold<int>(0, (sum, p) => sum + (int.tryParse(p['quantity']?.toString() ?? '0') ?? 0));
      final qcPcs = rawQc.fold<int>(0, (sum, q) => sum + (int.tryParse(q['qty_passed']?.toString() ?? '0') ?? 0));
      final ironPcs = (qcPcs * 0.95).round();
      final packPcs = rawReadyGoods.fold<int>(0, (sum, r) => sum + (int.tryParse(r['total_pieces']?.toString() ?? '0') ?? 0));

      final pipeline = [
        ProductionPipelineStage(id: 'cut', label: 'CUT', count: cutPcs, unit: 'pcs', status: cutPcs > 0 ? 'active' : 'idle'),
        ProductionPipelineStage(id: 'stitch', label: 'STITCH', count: stitchPcs, unit: 'pcs', status: stitchPcs > 0 ? 'active' : 'idle'),
        ProductionPipelineStage(id: 'qc', label: 'QC PASS', count: qcPcs, unit: 'pcs', status: qcPcs > 0 ? 'active' : 'idle'),
        ProductionPipelineStage(id: 'iron', label: 'IRON', count: ironPcs, unit: 'pcs', status: ironPcs > 0 ? 'active' : 'idle'),
        ProductionPipelineStage(id: 'pack', label: 'PACK', count: packPcs, unit: 'pcs', status: packPcs > 0 ? 'active' : 'idle'),
        ProductionPipelineStage(id: 'godown', label: 'GODOWN', count: godownStock, unit: 'pcs', status: godownStock > 0 ? 'active' : 'idle'),
        ProductionPipelineStage(id: 'dispatch', label: 'DISPATCH', count: dispatchedPieces, unit: 'pcs', status: dispatchedPieces > 0 ? 'completed' : 'idle'),
      ];

      // 7-Day Output Trend
      final dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
      final List<DailyOutputTrendItem> outputTrend = [];
      int total7DayPieces = 0;

      for (int i = 6; i >= 0; i--) {
        final d = now.subtract(Duration(days: i));
        final dStr = "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
        final dayLabel = "${dayNames[d.weekday % 7]} ${d.day}";

        final dayPcs = rawDailyProd
            .where((p) => p['entry_date'] == dStr)
            .fold<int>(0, (sum, p) => sum + (int.tryParse(p['quantity']?.toString() ?? '0') ?? 0));

        total7DayPieces += dayPcs;
        outputTrend.add(DailyOutputTrendItem(
          date: dStr,
          dayName: dayLabel,
          pieces: dayPcs,
          isToday: i == 0,
        ));
      }
      final dailyAverage = (total7DayPieces / 7).round();

      // QC Metrics
      final totalPassed = rawQc.fold<int>(0, (sum, q) => sum + (int.tryParse(q['qty_passed']?.toString() ?? '0') ?? 0));
      final totalRejected = rawQc.fold<int>(0, (sum, q) => sum + (int.tryParse(q['qty_rejected']?.toString() ?? '0') ?? 0));
      final totalInspected = totalPassed + totalRejected;
      final passRatePct = totalInspected > 0 ? double.parse(((totalPassed / totalInspected) * 100).toStringAsFixed(1)) : 100.0;

      final Map<String, int> defectCounts = {};
      for (final q in rawQc) {
        final rej = int.tryParse(q['qty_rejected']?.toString() ?? '0') ?? 0;
        final type = q['defect_type']?.toString().trim() ?? '';
        if (rej > 0 && type.isNotEmpty && type != 'NONE') {
          defectCounts[type] = (defectCounts[type] ?? 0) + rej;
        }
      }

      final topDefects = defectCounts.entries
          .map((e) => DefectItem(
                name: e.key,
                count: e.value,
                pct: totalRejected > 0 ? double.parse(((e.value / totalRejected) * 100).toStringAsFixed(1)) : 0.0,
              ))
          .toList()
        ..sort((a, b) => b.count.compareTo(a.count));

      final qc = QCMetrics(
        totalPassed: totalPassed,
        totalRejected: totalRejected,
        passRatePct: passRatePct,
        topDefects: topDefects.take(3).toList(),
      );

      // Buyer Orders
      final Map<String, _BuyerAccumulator> buyerMap = {};
      for (final o in rawMerchOrders) {
        final buyer = o['buyer_name']?.toString() ?? 'Direct Buyer';
        final po = o['order_number']?.toString() ?? 'PO';
        final qty = int.tryParse(o['total_quantity']?.toString() ?? '0') ?? 0;
        final acc = buyerMap[buyer] ?? _BuyerAccumulator(po: po, target: 0, delivered: 0);
        acc.target += qty;
        buyerMap[buyer] = acc;
      }

      for (final d in rawDispatch) {
        final buyer = d['buyer_name']?.toString() ?? 'Direct Buyer';
        if (buyerMap.containsKey(buyer)) {
          final pieces = int.tryParse(d['total_pieces']?.toString() ?? '0') ?? 0;
          buyerMap[buyer]!.delivered += pieces;
        }
      }

      final buyerOrders = buyerMap.entries.map((e) {
        final target = e.value.target > 0 ? e.value.target : 1;
        final pct = ((e.value.delivered / target) * 100).round().clamp(0, 100);
        return BuyerOrderStatusItem(
          buyerName: e.key,
          poNumber: e.value.po,
          targetPieces: e.value.target,
          deliveredPieces: e.value.delivered,
          percent: pct,
          status: pct >= 70 ? 'on_track' : (pct >= 35 ? 'caution' : 'behind'),
        );
      }).toList();

      // Fabric Stock
      final Map<String, _FabricAccumulator> fabricMap = {};
      for (final f in rawFabric) {
        final type = f['fabric_type']?.toString() ?? 'General Fabric';
        final meters = int.tryParse(f['total_meters']?.toString() ?? '0') ?? 0;
        final rolls = int.tryParse(f['total_rolls']?.toString() ?? '0') ?? 1;
        final color = f['color']?.toString() ?? 'Standard';

        final acc = fabricMap[type] ?? _FabricAccumulator(meters: 0, rolls: 0, color: color);
        acc.meters += meters;
        acc.rolls += rolls;
        fabricMap[type] = acc;
      }

      final fabricStock = fabricMap.entries
          .map((e) => FabricStockItem(
                fabricType: e.key,
                meters: e.value.meters,
                rolls: e.value.rolls,
                color: e.value.color,
              ))
          .toList()
        ..sort((a, b) => b.meters.compareTo(a.meters));

      // Article Deep Dive Catalog
      final articlesCatalog = rawArticles.map((art) {
        final artId = art['id']?.toString() ?? '';
        final artAllotmentTarget = rawAllotments
            .where((a) => a['article_id']?.toString() == artId)
            .fold<int>(0, (sum, a) => sum + (int.tryParse(a['target_qty']?.toString() ?? '0') ?? 0));

        final artStitched = rawDailyProd
            .where((p) => p['article_id']?.toString() == artId)
            .fold<int>(0, (sum, p) => sum + (int.tryParse(p['quantity']?.toString() ?? '0') ?? 0));

        final artPassed = rawQc
            .where((q) => q['article_id']?.toString() == artId)
            .fold<int>(0, (sum, q) => sum + (int.tryParse(q['qty_passed']?.toString() ?? '0') ?? 0));

        int artStock = 0;
        for (final tx in rawStore.where((s) => s['article_id']?.toString() == artId)) {
          final q = int.tryParse(tx['quantity']?.toString() ?? '0') ?? 0;
          final type = tx['type']?.toString().toUpperCase() ?? '';
          if (type == 'INWARD') artStock += q;
          if (type == 'OUTWARD') artStock -= q;
        }

        final target = artAllotmentTarget > 0 ? artAllotmentTarget : 0;
        final progress = target > 0
            ? ((artStitched / target) * 100).round().clamp(0, 100)
            : (artStitched > 0 ? 100 : 0);

        return ArticleJourneyItem(
          id: artId,
          artNo: art['art_no']?.toString() ?? 'Art',
          description: art['description']?.toString() ?? 'Garment Style',
          designStatus: 'APPROVED',
          buyerPoTarget: target,
          fabricMetersInStore: 0,
          cutPieces: 0,
          stitchedPieces: artStitched,
          qcPassedPieces: artPassed,
          godownPieces: artStock > 0 ? artStock : 0,
          dispatchedPieces: 0,
          overallProgressPct: progress,
        );
      }).toList();

      // Division Heartbeat
      final divisionHeartbeat = [
        DivisionHeartbeatItem(
          id: 'cutting',
          name: 'Cutting Floor',
          route: '/cutting',
          status: rawCutting.isNotEmpty ? 'ACTIVE' : 'IDLE',
          metric: '${rawCutting.length} lay sheets cut',
          iconName: 'Scissors',
        ),
        DivisionHeartbeatItem(
          id: 'stitching',
          name: 'Stitching Lines',
          route: '/stitching-sewing/dashboard',
          status: todayOutput > 0 ? 'ACTIVE' : (rawDailyProd.isNotEmpty ? 'LOW' : 'IDLE'),
          metric: '$todayOutput pcs stitched',
          iconName: 'Layers',
        ),
        DivisionHeartbeatItem(
          id: 'qc',
          name: '3-Stage QC',
          route: '/stitching-sewing/qc',
          status: rawQc.isNotEmpty ? 'ACTIVE' : 'IDLE',
          metric: rawQc.isNotEmpty ? '$passRatePct% pass rate' : '0 audits',
          iconName: 'ShieldCheck',
        ),
        DivisionHeartbeatItem(
          id: 'iron',
          name: 'Iron & Finishing',
          route: '/iron',
          status: ironPcs > 0 ? 'ACTIVE' : 'IDLE',
          metric: '$ironPcs pcs pressed',
          iconName: 'Flame',
        ),
        DivisionHeartbeatItem(
          id: 'store',
          name: 'Store & Godown',
          route: '/store',
          status: godownStock > 0 ? 'ACTIVE' : 'IDLE',
          metric: '$godownStock pcs in stock',
          iconName: 'Warehouse',
        ),
        DivisionHeartbeatItem(
          id: 'dispatch',
          name: 'Dispatch Gates',
          route: '/dispatch',
          status: dispatchedPieces > 0 ? 'ACTIVE' : 'IDLE',
          metric: '$dispatchedPieces pcs shipped',
          iconName: 'Truck',
        ),
      ];

      final dashboardData = PlantOperationsDashboardData(
        companyName: companyName,
        pulse: pulse,
        pipeline: pipeline,
        outputTrend: outputTrend,
        dailyAverage: dailyAverage,
        qc: qc,
        buyerOrders: buyerOrders,
        fabricStock: fabricStock,
        articlesCatalog: articlesCatalog,
        divisionHeartbeat: divisionHeartbeat,
        lastUpdated: "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}",
      );

      state = AsyncValue.data(dashboardData);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

class _BuyerAccumulator {
  String po;
  int target;
  int delivered;
  _BuyerAccumulator({required this.po, required this.target, required this.delivered});
}

class _FabricAccumulator {
  int meters;
  int rolls;
  String color;
  _FabricAccumulator({required this.meters, required this.rolls, required this.color});
}

final plantOperationsDashboardProvider = StateNotifierProvider<PlantOperationsDashboardNotifier, AsyncValue<PlantOperationsDashboardData>>(
  (ref) => PlantOperationsDashboardNotifier(ref),
);
