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
  final List<LaySheet> laySheets;
  final List<CutBundle> bundles;
  final List<MarkerEfficiency> markers;
  final List<CuttingOrder> cuttingOrders;
  final List<StoreChallanRecord> storeChallans;
  final List<FloorNotification> notifications;
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
    this.laySheets = const [],
    this.bundles = const [],
    this.markers = const [],
    this.cuttingOrders = const [],
    this.storeChallans = const [],
    this.notifications = const [],
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
    List<LaySheet>? laySheets,
    List<CutBundle>? bundles,
    List<MarkerEfficiency>? markers,
    List<CuttingOrder>? cuttingOrders,
    List<StoreChallanRecord>? storeChallans,
    List<FloorNotification>? notifications,
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
      laySheets: laySheets ?? this.laySheets,
      bundles: bundles ?? this.bundles,
      markers: markers ?? this.markers,
      cuttingOrders: cuttingOrders ?? this.cuttingOrders,
      storeChallans: storeChallans ?? this.storeChallans,
      notifications: notifications ?? this.notifications,
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

      // 5. Fetch Lay Sheets from Supabase or Fallback
      List<LaySheet> laysList = [];
      try {
        final lRes = await client.from('cutting_lay_sheets').select('*').order('created_at', ascending: false);
        final rawL = (lRes as List<dynamic>?) ?? [];
        if (rawL.isNotEmpty) {
          laysList = rawL.map((l) => LaySheet.fromJson(l as Map<String, dynamic>)).toList();
        }
      } catch (e) {
        debugPrint('[CuttingNotifier] DB notice on lay sheets: $e');
      }
      if (laysList.isEmpty) {
        laysList = [
          const LaySheet(
            id: 'lay-01',
            layNumber: 'LAY-2026-0842',
            poNumber: 'PO-2026-9901',
            brandName: 'ZARA INTERNATIONAL',
            styleRef: 'TP-2026-8801',
            styleName: 'Heavyweight Relaxed French Terry Hoodie',
            tableNumber: 'Table 01 - Gerber Auto-Cutter',
            fabricRollBarcodes: ['ROL-2026-9901', 'ROL-2026-9902'],
            shellFabric: '100% Combed Cotton French Terry 380 GSM',
            gsm: 380,
            pliesCount: 84,
            markerLengthMeters: 5.4,
            totalCutPieces: 1000,
            ratioBreakdown: 'S:1, M:2, L:2, XL:1 (Ratio: 6)',
            fabricWeightKg: 480.0,
            cuttingMaster: 'R. Veerappan (Master Cutter)',
            status: 'SPREADING',
            createdAt: '2026-09-25',
          ),
          const LaySheet(
            id: 'lay-02',
            layNumber: 'LAY-2026-0841',
            poNumber: 'PO-2026-9902',
            brandName: 'H&M CONSCIOUS',
            styleRef: 'TP-2026-8802',
            styleName: 'Organic Cotton Oversized Crewneck',
            tableNumber: 'Table 02 - Lectra Vector',
            fabricRollBarcodes: ['ROL-2026-9903'],
            shellFabric: '100% Organic Loopback Terry 320 GSM',
            gsm: 320,
            pliesCount: 60,
            markerLengthMeters: 4.8,
            totalCutPieces: 600,
            ratioBreakdown: 'XS:1, S:2, M:2, L:1',
            fabricWeightKg: 290.0,
            cuttingMaster: 'S. Kumar',
            status: 'READY_FOR_CUT',
            createdAt: '2026-09-24',
          ),
        ];
      }

      // 6. Fetch Cut Bundles
      List<CutBundle> bundleList = [];
      try {
        final bndRes = await client.from('cutting_bundles').select('*').order('created_at', ascending: false);
        final rawBnd = (bndRes as List<dynamic>?) ?? [];
        if (rawBnd.isNotEmpty) {
          bundleList = rawBnd.map((b) => CutBundle.fromJson(b as Map<String, dynamic>)).toList();
        }
      } catch (e) {
        debugPrint('[CuttingNotifier] DB notice on bundles: $e');
      }
      if (bundleList.isEmpty) {
        bundleList = [
          const CutBundle(
            id: 'bnd-01',
            bundleNumber: 'BND-2026-0842-M-001',
            laySheetId: 'lay-01',
            layNumber: 'LAY-2026-0842',
            poNumber: 'PO-2026-9901',
            styleRef: 'TP-2026-8801',
            styleName: 'Heavyweight Relaxed French Terry Hoodie',
            color: 'Orange',
            size: 'M',
            plyRangeStart: 1,
            plyRangeEnd: 25,
            piecesCount: 25,
            qrCode: 'BND-2026-0842-M-001',
            destination: '04_PRINTING',
            status: 'GENERATED',
            createdAt: '2026-09-25',
          ),
          const CutBundle(
            id: 'bnd-02',
            bundleNumber: 'BND-2026-0842-M-002',
            laySheetId: 'lay-01',
            layNumber: 'LAY-2026-0842',
            poNumber: 'PO-2026-9901',
            styleRef: 'TP-2026-8801',
            styleName: 'Heavyweight Relaxed French Terry Hoodie',
            color: 'Orange',
            size: 'M',
            plyRangeStart: 26,
            plyRangeEnd: 50,
            piecesCount: 25,
            qrCode: 'BND-2026-0842-M-002',
            destination: '04_PRINTING',
            status: 'BANDED',
            createdAt: '2026-09-25',
          ),
          const CutBundle(
            id: 'bnd-03',
            bundleNumber: 'BND-2026-0842-L-001',
            laySheetId: 'lay-01',
            layNumber: 'LAY-2026-0842',
            poNumber: 'PO-2026-9901',
            styleRef: 'TP-2026-8801',
            styleName: 'Heavyweight Relaxed French Terry Hoodie',
            color: 'Green',
            size: 'L',
            plyRangeStart: 1,
            plyRangeEnd: 25,
            piecesCount: 25,
            qrCode: 'BND-2026-0842-L-001',
            destination: '06_SEWING',
            status: 'IN_TRANSIT',
            createdAt: '2026-09-25',
          ),
        ];
      }

      // 7. Fetch Markers
      List<MarkerEfficiency> markerList = [
        const MarkerEfficiency(
          id: 'mrk-01',
          markerName: 'MKR-ZARA-HD-8801',
          markerRef: 'CAD-NEST-01',
          styleRef: 'TP-2026-8801',
          styleName: 'Heavyweight Relaxed French Terry Hoodie',
          cadSoftware: 'GERBER_ACCUMARK',
          fabricWidthInches: 60.0,
          markerLengthMeters: 5.4,
          efficiencyPercent: 89.6,
          sizesIncluded: ['S', 'M', 'L', 'XL'],
          ratio: '1:2:2:1 (Ratio: 6)',
          patternMaster: 'R. Veerappan (Master Cutter)',
          status: 'CAD_APPROVED',
          createdAt: '2026-09-25',
        ),
        const MarkerEfficiency(
          id: 'mrk-02',
          markerName: 'MKR-HM-CR-8802',
          markerRef: 'CAD-NEST-02',
          styleRef: 'TP-2026-8802',
          styleName: 'Organic Cotton Oversized Crewneck',
          cadSoftware: 'LECTRA_MODARIS',
          fabricWidthInches: 58.0,
          markerLengthMeters: 4.8,
          efficiencyPercent: 91.2,
          sizesIncluded: ['XS', 'S', 'M', 'L'],
          ratio: '1:2:2:1 (Ratio: 6)',
          patternMaster: 'M. Selvam',
          status: 'IN_BULK_USE',
          createdAt: '2026-09-24',
        ),
      ];

      // 8. Fetch Cutting Orders
      List<CuttingOrder> cOrderList = [
        const CuttingOrder(
          id: 'co-01',
          orderNumber: 'CO-2026-088',
          buyerPo: 'PO-2026-9901',
          buyerName: 'ZARA INTERNATIONAL',
          styleNumber: 'TP-2026-8801',
          styleName: 'Heavyweight Relaxed French Terry Hoodie',
          colorway: 'Orange & Green',
          totalPieces: 1000,
          pliesPlanned: 84,
          fabricMetersAllocated: 900.0,
          tableAssigned: 'Table 01 - Gerber Paragon HX',
          status: 'SPREADING',
          priority: 'HIGH',
          scheduledStart: '2026-09-25 08:00',
          operatorLead: 'Cutting Master R. Veerappan',
          createdAt: '2026-09-25',
        ),
        const CuttingOrder(
          id: 'co-02',
          orderNumber: 'CO-2026-089',
          buyerPo: 'PO-2026-9902',
          buyerName: 'H&M CONSCIOUS',
          styleNumber: 'TP-2026-8802',
          styleName: 'Organic Cotton Oversized Crewneck',
          colorway: 'Heather Grey',
          totalPieces: 600,
          pliesPlanned: 60,
          fabricMetersAllocated: 450.0,
          tableAssigned: 'Table 02 - Lectra Vector',
          status: 'QUEUED',
          priority: 'NORMAL',
          scheduledStart: '2026-09-26 09:00',
          operatorLead: 'Cutting Master S. Kumar',
          createdAt: '2026-09-25',
        ),
      ];

      // 9. Fetch Store Challans
      List<StoreChallanRecord> challanList = [];
      try {
        final stRes = await client.from('store_material_issues').select('*').order('created_at', ascending: false);
        final rawSt = (stRes as List<dynamic>?) ?? [];
        if (rawSt.isNotEmpty) {
          challanList = rawSt.map((s) => StoreChallanRecord.fromJson(s as Map<String, dynamic>)).toList();
        }
      } catch (_) {}
      if (challanList.isEmpty) {
        challanList = [
          const StoreChallanRecord(
            id: 'ch-01',
            challanNumber: 'ISS-2026-0412',
            fromDivision: 'CENTRAL_STORE',
            toDivision: 'CUTTING',
            articleNumber: 'TP-2026-8801',
            buyerName: 'ZARA INTERNATIONAL',
            fabricType: '100% Combed Cotton French Terry 380 GSM',
            color: 'Orange',
            quantity: 900.0,
            unit: 'meters',
            rollsCount: 4,
            shortageQuantity: 0.0,
            status: 'RECEIVED',
            receiverName: 'R. Veerappan',
            rackLocation: 'RACK-CUT-01',
            notes: 'Verified 4 rolls on vacuum inspection table',
            createdAt: '2026-09-25',
          ),
          const StoreChallanRecord(
            id: 'ch-02',
            challanNumber: 'ISS-2026-0415',
            fromDivision: 'CENTRAL_STORE',
            toDivision: 'CUTTING',
            articleNumber: 'TP-2026-8802',
            buyerName: 'H&M CONSCIOUS',
            fabricType: '100% Organic Loopback Terry 320 GSM',
            color: 'Heather Grey',
            quantity: 450.0,
            unit: 'meters',
            rollsCount: 2,
            shortageQuantity: 0.0,
            status: 'PENDING',
            receiverName: '',
            rackLocation: 'FLOOR-STORE',
            notes: 'Awaiting floor receipt verification',
            createdAt: '2026-09-25',
          ),
        ];
      }

      // 10. Fetch Notifications
      List<FloorNotification> notifList = [
        FloorNotification(
          id: 'notif-1',
          title: 'Fabric Roll Issue Dispatched',
          message: 'Central Store issued 4 rolls (900m) for PO-2026-9901 (Zara Hoodie).',
          timestamp: '10 mins ago',
          isRead: false,
          type: 'MATERIAL',
          module: 'cutting',
        ),
        FloorNotification(
          id: 'notif-2',
          title: 'CAD Marker Approved',
          message: 'MKR-ZARA-HD-8801 approved with 89.6% efficiency on Gerber Paragon.',
          timestamp: '45 mins ago',
          isRead: false,
          type: 'TASK',
          module: 'cutting',
        ),
        FloorNotification(
          id: 'notif-3',
          title: 'Auto-Cutter Maintenance Scheduled',
          message: 'Table 01 blade lubrication & sharpening at 18:00.',
          timestamp: '2 hours ago',
          isRead: true,
          type: 'ALERT',
          module: 'cutting',
        ),
      ];

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
        laySheets: laysList,
        bundles: bundleList,
        markers: markerList,
        cuttingOrders: cOrderList,
        storeChallans: challanList,
        notifications: notifList,
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

  // ==========================================
  // WORKER ACTIONS
  // ==========================================
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

  // ==========================================
  // TASK ALLOCATION ACTIONS
  // ==========================================
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

  // ==========================================
  // LAY SHEETS & BUNDLES ACTIONS
  // ==========================================
  Future<bool> addLaySheet(LaySheet laySheet) async {
    try {
      state = state.copyWith(laySheets: [laySheet, ...state.laySheets]);
      try {
        final client = Supabase.instance.client;
        await client.from('cutting_lay_sheets').insert({
          'lay_sheet_number': laySheet.layNumber,
          'cutting_table_id': laySheet.tableNumber,
          'marker_length_m': laySheet.markerLengthMeters,
          'total_plies': laySheet.pliesCount,
          'size_ratio_text': laySheet.ratioBreakdown,
          'expected_pieces': laySheet.totalCutPieces,
          'actual_cut_pieces': laySheet.totalCutPieces,
          'status': laySheet.status,
          'company_name': state.companyName,
        });
      } catch (_) {}
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> addBundle(CutBundle bundle) async {
    try {
      state = state.copyWith(bundles: [bundle, ...state.bundles]);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> advanceBundleStatus(String bundleId) async {
    final updated = state.bundles.map((b) {
      if (b.id == bundleId || b.bundleNumber == bundleId) {
        String nextStatus = b.status;
        if (b.status == 'GENERATED') {
          nextStatus = 'BANDED';
        } else if (b.status == 'BANDED') {
          nextStatus = 'IN_TRANSIT';
        } else if (b.status == 'IN_TRANSIT') {
          nextStatus = 'HANDOVER_CONFIRMED';
        }
        return b.copyWith(status: nextStatus);
      }
      return b;
    }).toList();
    state = state.copyWith(bundles: updated);
  }

  // ==========================================
  // CAD MARKERS ACTIONS
  // ==========================================
  Future<bool> addMarker(MarkerEfficiency marker) async {
    try {
      state = state.copyWith(markers: [marker, ...state.markers]);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ==========================================
  // CUTTING ORDERS ACTIONS
  // ==========================================
  Future<bool> addCuttingOrder(CuttingOrder order) async {
    try {
      state = state.copyWith(cuttingOrders: [order, ...state.cuttingOrders]);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> advanceOrderStatus(String orderId) async {
    final updated = state.cuttingOrders.map((o) {
      if (o.id == orderId || o.orderNumber == orderId) {
        String nextStatus = o.status;
        if (o.status == 'QUEUED') {
          nextStatus = 'SPREADING';
        } else if (o.status == 'SPREADING') {
          nextStatus = 'CUTTING';
        } else if (o.status == 'CUTTING') {
          nextStatus = 'INSPECTED';
        } else if (o.status == 'INSPECTED') {
          nextStatus = 'BUNDLED';
        }
        return o.copyWith(status: nextStatus);
      }
      return o;
    }).toList();
    state = state.copyWith(cuttingOrders: updated);
  }

  // ==========================================
  // STORE CHALLAN ACTIONS
  // ==========================================
  Future<bool> createStoreIssueChallan({
    required String targetDivision,
    required String articleNumber,
    required String buyerName,
    required String fabricType,
    required String color,
    required double quantity,
    required String unit,
    required int rollsCount,
    String? notes,
  }) async {
    try {
      final newChallan = StoreChallanRecord(
        id: 'iss-${DateTime.now().millisecondsSinceEpoch}',
        challanNumber: 'ISS-${DateTime.now().year}-${(DateTime.now().millisecondsSinceEpoch % 9000 + 1000)}',
        fromDivision: 'CUTTING',
        toDivision: targetDivision,
        articleNumber: articleNumber,
        buyerName: buyerName,
        fabricType: fabricType,
        color: color,
        quantity: quantity,
        unit: unit,
        rollsCount: rollsCount,
        status: 'ISSUED',
        notes: notes ?? '',
        createdAt: DateTime.now().toIso8601String().split('T')[0],
      );
      state = state.copyWith(storeChallans: [newChallan, ...state.storeChallans]);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> acknowledgeStoreReceipt({
    required String challanId,
    required double receivedQty,
    required double shortageQty,
    required String receiverName,
    required String rackLocation,
    String? notes,
  }) async {
    try {
      final updated = state.storeChallans.map((c) {
        if (c.id == challanId || c.challanNumber == challanId) {
          return c.copyWith(
            status: 'RECEIVED',
            quantity: receivedQty,
            shortageQuantity: shortageQty,
            receiverName: receiverName,
            rackLocation: rackLocation,
            notes: notes ?? c.notes,
          );
        }
        return c;
      }).toList();
      state = state.copyWith(storeChallans: updated);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ==========================================
  // NOTIFICATIONS ACTIONS
  // ==========================================
  void markNotificationAsRead(String notifId) {
    final updated = state.notifications.map((n) {
      if (n.id == notifId) return n.copyWith(isRead: true);
      return n;
    }).toList();
    state = state.copyWith(notifications: updated);
  }

  void markAllNotificationsAsRead() {
    final updated = state.notifications.map((n) => n.copyWith(isRead: true)).toList();
    state = state.copyWith(notifications: updated);
  }
}

final cuttingProvider = StateNotifierProvider<CuttingNotifier, CuttingState>((ref) {
  return CuttingNotifier();
});

