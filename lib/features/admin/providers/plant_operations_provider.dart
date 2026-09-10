import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../main.dart';

enum PlantDateFilter { today, week, month, all }

enum PlantStageType {
  totalStocks,
  goodsInLine,
  mendingChecking,
  readyGoods,
  rto,
  readyDelivery,
}

/// Helper function to format relative timestamps (e.g. "Just now", "18 min ago", "2 hr ago")
String formatRelativeTime(DateTime? date) {
  if (date == null) return 'Just now';
  final now = DateTime.now();
  final diff = now.difference(date);
  final mins = diff.inMinutes;
  if (mins < 1) return 'Just now';
  if (mins < 60) return '$mins min ago';
  final hours = diff.inHours;
  if (hours < 24) return '$hours hr${hours > 1 ? 's' : ''} ago';
  final days = diff.inDays;
  return '$days day${days > 1 ? 's' : ''} ago';
}

/// Filter state for Plant Operations Control Center
class PlantOperationsFilterState {
  final String selectedBrand;
  final String selectedArticleId;
  final PlantDateFilter dateFilter;

  const PlantOperationsFilterState({
    this.selectedBrand = 'ALL',
    this.selectedArticleId = 'ALL',
    this.dateFilter = PlantDateFilter.all,
  });

  PlantOperationsFilterState copyWith({
    String? selectedBrand,
    String? selectedArticleId,
    PlantDateFilter? dateFilter,
  }) {
    return PlantOperationsFilterState(
      selectedBrand: selectedBrand ?? this.selectedBrand,
      selectedArticleId: selectedArticleId ?? this.selectedArticleId,
      dateFilter: dateFilter ?? this.dateFilter,
    );
  }
}

final plantOperationsFilterProvider =
    StateProvider.autoDispose<PlantOperationsFilterState>((ref) {
  return const PlantOperationsFilterState();
});

/// Raw models for Plant Operations
class PlantArticleItem {
  final String id;
  final String artNo;
  final String? description;
  final double stitchingRate;
  final Map<String, dynamic>? sizeRates;

  PlantArticleItem({
    required this.id,
    required this.artNo,
    this.description,
    this.stitchingRate = 20.0,
    this.sizeRates,
  });

  factory PlantArticleItem.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? rates;
    if (json['size_rates'] is Map) {
      rates = Map<String, dynamic>.from(json['size_rates']);
    }
    return PlantArticleItem(
      id: json['id']?.toString() ?? '',
      artNo: json['art_no']?.toString().trim().toUpperCase() ?? 'STYLE',
      description: json['description']?.toString(),
      stitchingRate: (json['stitching_rate'] as num?)?.toDouble() ?? 20.0,
      sizeRates: rates,
    );
  }
}

class PlantAllotmentItem {
  final String id;
  final String? challanId;
  final String? linemanId;
  final String linemanName;
  final String? articleId;
  final String articleNo;
  final String? articleDescription;
  final String? challanNo;
  final String? brand;
  final String? fabricType;
  final int targetQty;
  final String status;
  final String? allotmentDate;
  final String? mendingStatus;
  final int? mendingTotalCounted;
  final String? mendingSupervisorName;
  final String? handedToMendingBy;
  final DateTime? handedToMendingAt;
  final String? qcStatus;
  final int? qcTotalPassed;
  final int? qcTotalAlter;
  final DateTime createdAt;
  final List<Map<String, dynamic>> variants;

  PlantAllotmentItem({
    required this.id,
    this.challanId,
    this.linemanId,
    this.linemanName = 'Unassigned (Floor Order)',
    this.articleId,
    this.articleNo = 'Style',
    this.articleDescription,
    this.challanNo,
    this.brand,
    this.fabricType,
    this.targetQty = 0,
    this.status = 'IN_PROGRESS',
    this.allotmentDate,
    this.mendingStatus,
    this.mendingTotalCounted,
    this.mendingSupervisorName,
    this.handedToMendingBy,
    this.handedToMendingAt,
    this.qcStatus,
    this.qcTotalPassed,
    this.qcTotalAlter,
    required this.createdAt,
    this.variants = const [],
  });

  factory PlantAllotmentItem.fromJson(Map<String, dynamic> json) {
    String lmName = 'Unassigned (Floor Order)';
    if (json['profiles'] != null) {
      if (json['profiles'] is Map && json['profiles']['username'] != null) {
        lmName = json['profiles']['username'].toString();
      } else if (json['profiles'] is List && (json['profiles'] as List).isNotEmpty) {
        lmName = (json['profiles'] as List).first['username']?.toString() ?? lmName;
      }
    }

    String aNo = 'Style';
    String? aDesc;
    if (json['articles'] != null && json['articles'] is Map) {
      aNo = json['articles']['art_no']?.toString().trim().toUpperCase() ?? 'Style';
      aDesc = json['articles']['description']?.toString();
    }

    String? cNo;
    String? bName;
    String? fType;
    if (json['challans'] != null && json['challans'] is Map) {
      cNo = json['challans']['challan_no']?.toString();
      bName = json['challans']['brand']?.toString();
      fType = json['challans']['fabric_type']?.toString();
    }

    DateTime created = DateTime.now();
    if (json['created_at'] != null) {
      created = DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now();
    }

    DateTime? handedAt;
    if (json['handed_to_mending_at'] != null) {
      handedAt = DateTime.tryParse(json['handed_to_mending_at'].toString());
    }

    return PlantAllotmentItem(
      id: json['id']?.toString() ?? '',
      challanId: json['challan_id']?.toString(),
      linemanId: json['lineman_id']?.toString(),
      linemanName: lmName,
      articleId: json['article_id']?.toString(),
      articleNo: aNo,
      articleDescription: aDesc,
      challanNo: cNo,
      brand: bName,
      fabricType: fType,
      targetQty: (json['target_qty'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString().toUpperCase() ?? 'IN_PROGRESS',
      allotmentDate: json['allotment_date']?.toString(),
      mendingStatus: json['mending_status']?.toString(),
      mendingTotalCounted: (json['mending_total_counted'] as num?)?.toInt(),
      mendingSupervisorName: json['mending_supervisor_name']?.toString(),
      handedToMendingBy: json['handed_to_mending_by']?.toString(),
      handedToMendingAt: handedAt,
      qcStatus: json['qc_status']?.toString(),
      qcTotalPassed: (json['qc_total_passed'] as num?)?.toInt(),
      qcTotalAlter: (json['qc_total_alter'] as num?)?.toInt(),
      createdAt: created,
    );
  }
}

class PlantChallanItem {
  final String id;
  final String challanNo;
  final String brand;
  final String? fabricType;
  final int totalPcs;
  final int totalSets;
  final String? notes;
  final DateTime createdAt;

  PlantChallanItem({
    required this.id,
    required this.challanNo,
    required this.brand,
    this.fabricType,
    this.totalPcs = 0,
    this.totalSets = 0,
    this.notes,
    required this.createdAt,
  });

  factory PlantChallanItem.fromJson(Map<String, dynamic> json) {
    return PlantChallanItem(
      id: json['id']?.toString() ?? '',
      challanNo: json['challan_no']?.toString().trim().toUpperCase() ?? 'N/A',
      brand: json['brand']?.toString().trim().toUpperCase() ?? 'OLLYPOP',
      fabricType: json['fabric_type']?.toString(),
      totalPcs: (json['total_pcs'] as num?)?.toInt() ?? (json['total_qty'] as num?)?.toInt() ?? 0,
      totalSets: (json['total_sets'] as num?)?.toInt() ?? 0,
      notes: json['notes']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class PlantActivityItem {
  final String id;
  final String type; // 'PRODUCTION' | 'QC' | 'STORE' | 'ALLOTMENT' | 'DISPATCH'
  final String title;
  final String details;
  final String location;
  final DateTime timestamp;

  PlantActivityItem({
    required this.id,
    required this.type,
    required this.title,
    required this.details,
    required this.location,
    required this.timestamp,
  });

  String get relativeTime => formatRelativeTime(timestamp);
}

class PlantQCItem {
  final String id;
  final int qtyPassed;
  final int qtyRejected;
  final String stage;
  final String? defectType;
  final String? entryDate;
  final DateTime createdAt;
  final String? articleId;
  final String articleNo;
  final String? articleDescription;

  PlantQCItem({
    required this.id,
    this.qtyPassed = 0,
    this.qtyRejected = 0,
    this.stage = 'CHECKING',
    this.defectType,
    this.entryDate,
    required this.createdAt,
    this.articleId,
    this.articleNo = 'Style',
    this.articleDescription,
  });

  factory PlantQCItem.fromJson(Map<String, dynamic> json) {
    String aNo = 'Style';
    String? aDesc;
    if (json['article'] != null && json['article'] is Map) {
      aNo = json['article']['art_no']?.toString().trim().toUpperCase() ?? 'Style';
      aDesc = json['article']['description']?.toString();
    }
    return PlantQCItem(
      id: json['id']?.toString() ?? '',
      qtyPassed: (json['qty_passed'] as num?)?.toInt() ?? 0,
      qtyRejected: (json['qty_rejected'] as num?)?.toInt() ?? 0,
      stage: json['stage']?.toString().toUpperCase() ?? 'CHECKING',
      defectType: json['defect_type']?.toString(),
      entryDate: json['entry_date']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      articleId: json['article_id']?.toString(),
      articleNo: aNo,
      articleDescription: aDesc,
    );
  }
}

class PlantStoreItem {
  final String id;
  final String type; // 'INWARD' | 'RTO' | 'REJECT' | 'RETURN'
  final int quantity;
  final String? color;
  final String? size;
  final String? partyName;
  final String? challanNo;
  final String? entryDate;
  final DateTime createdAt;
  final String articleNo;
  final String? articleDescription;

  PlantStoreItem({
    required this.id,
    this.type = 'INWARD',
    this.quantity = 0,
    this.color,
    this.size,
    this.partyName,
    this.challanNo,
    this.entryDate,
    required this.createdAt,
    this.articleNo = 'Style',
    this.articleDescription,
  });

  factory PlantStoreItem.fromJson(Map<String, dynamic> json) {
    String aNo = 'Style';
    String? aDesc;
    if (json['article'] != null && json['article'] is Map) {
      aNo = json['article']['art_no']?.toString().trim().toUpperCase() ?? 'Style';
      aDesc = json['article']['description']?.toString();
    }
    return PlantStoreItem(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString().toUpperCase() ?? 'INWARD',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      color: json['color']?.toString(),
      size: json['size']?.toString(),
      partyName: json['party_name']?.toString(),
      challanNo: json['challan_no']?.toString(),
      entryDate: json['entry_date']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      articleNo: aNo,
      articleDescription: aDesc,
    );
  }
}

class PlantDispatchItem {
  final String id;
  final String challanNo;
  final String? buyerName;
  final int totalPieces;
  final String status;
  final DateTime createdAt;

  PlantDispatchItem({
    required this.id,
    required this.challanNo,
    this.buyerName,
    this.totalPieces = 0,
    this.status = 'DELIVERED',
    required this.createdAt,
  });

  factory PlantDispatchItem.fromJson(Map<String, dynamic> json) {
    return PlantDispatchItem(
      id: json['id']?.toString() ?? '',
      challanNo: json['challan_no']?.toString().trim().toUpperCase() ?? 'N/A',
      buyerName: json['buyer_name']?.toString(),
      totalPieces: (json['total_pieces'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString().toUpperCase() ?? 'DELIVERED',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class PlantLinemanGroup {
  final String key;
  final String name;
  final List<PlantAllotmentItem> allotments;
  final int totalPcs;
  final double totalWage;
  final List<String> articleNumbers;

  PlantLinemanGroup({
    required this.key,
    required this.name,
    required this.allotments,
    required this.totalPcs,
    required this.totalWage,
    required this.articleNumbers,
  });
}

/// Aggregated metrics computed exactly identical to web dashboard
class PlantOperationsMetrics {
  final int totalStocks;
  final int goodsInLine;
  final int mendingChecking;
  final int mendingFloorPcs;
  final int mendingFloorCount;
  final int mendingAlterationQty;
  final double alterationRate;
  final int readyGoods;
  final int rto;
  final int readyDelivery;
  final int inLinePct;
  final int mendingPct;
  final int readyPct;
  final int deliveryPct;

  PlantOperationsMetrics({
    this.totalStocks = 0,
    this.goodsInLine = 0,
    this.mendingChecking = 0,
    this.mendingFloorPcs = 0,
    this.mendingFloorCount = 0,
    this.mendingAlterationQty = 0,
    this.alterationRate = 0.0,
    this.readyGoods = 0,
    this.rto = 0,
    this.readyDelivery = 0,
    this.inLinePct = 0,
    this.mendingPct = 0,
    this.readyPct = 0,
    this.deliveryPct = 0,
  });
}

/// Complete raw bundle & computed state
class PlantOperationsData {
  final List<PlantArticleItem> articles;
  final List<PlantAllotmentItem> allAllotments;
  final List<PlantAllotmentItem> filteredAllotments;
  final List<PlantChallanItem> challans;
  final List<String> brandTabs;
  final PlantOperationsMetrics metrics;
  final List<PlantActivityItem> activities;
  final List<Map<String, dynamic>> variants;
  final List<PlantQCItem> qcLogs;
  final List<PlantStoreItem> storeTransactions;
  final List<PlantDispatchItem> dispatches;
  final List<PlantLinemanGroup> linemanGroups;

  PlantOperationsData({
    this.articles = const [],
    this.allAllotments = const [],
    this.filteredAllotments = const [],
    this.challans = const [],
    this.brandTabs = const [],
    PlantOperationsMetrics? metrics,
    this.activities = const [],
    this.variants = const [],
    this.qcLogs = const [],
    this.storeTransactions = const [],
    this.dispatches = const [],
    this.linemanGroups = const [],
  }) : metrics = metrics ?? PlantOperationsMetrics();
}

/// Primary Riverpod Provider for Plant Operations Control Center
final plantOperationsProvider =
    FutureProvider.autoDispose<PlantOperationsData>((ref) async {
  final filter = ref.watch(plantOperationsFilterProvider);

  // Fetch all factory datasets concurrently in parallel matching Web Admin
  final results = await Future.wait([
    // 0: Articles
    supabase
        .from('articles')
        .select('id, art_no, description, stitching_rate, size_rates')
        .eq('is_active', true)
        .order('art_no'),

    // 1: Allotments with joins
    supabase.from('allotments').select('''
      id, challan_id, lineman_id, article_id, target_qty, status, allotment_date,
      mending_status, mending_total_counted, mending_supervisor_name, mending_supervisor_id,
      handed_to_mending_by, handed_to_mending_at, mending_handover_notes,
      qc_status, qc_total_passed, qc_total_alter, qc_supervisor_name,
      handed_to_qc_by, handed_to_qc_at, created_at,
      profiles:lineman_id ( id, username ),
      articles:article_id ( id, art_no, description, size_rates, stitching_rate ),
      challans:challan_id ( id, challan_no, brand, fabric_type )
    ''').order('created_at', ascending: false).limit(200),

    // 2: Challans
    supabase.from('challans').select('*').order('created_at', ascending: false).limit(100),

    // 3: Variants
    supabase.from('allotment_variants').select('*').limit(500),

    // 4: Daily Product (Production WIP)
    supabase.from('daily_product').select('''
      id, quantity, entry_date, created_at, article_id, lineman_id,
      article:article_id ( id, art_no, description )
    ''').order('created_at', ascending: false).limit(200),

    // 5: QC Logs
    supabase.from('qc_logs').select('''
      id, qty_passed, qty_rejected, stage, defect_type, entry_date, created_at, article_id,
      article:article_id ( id, art_no, description )
    ''').order('created_at', ascending: false).limit(200),

    // 6: Store Transactions
    supabase.from('store_transactions').select('''
      id, type, quantity, party_name, created_at,
      article:article_id ( art_no, description )
    ''').order('created_at', ascending: false).limit(200),

    // 7: Delivery Challans (Dispatches)
    supabase.from('delivery_challans').select('*').order('created_at', ascending: false).limit(100),
  ]);

  final articlesRaw = (results[0] as List?) ?? [];
  final allotmentsRaw = (results[1] as List?) ?? [];
  final challansRaw = (results[2] as List?) ?? [];
  final variantsRaw = (results[3] as List?) ?? [];
  final prodRaw = (results[4] as List?) ?? [];
  final qcRaw = (results[5] as List?) ?? [];
  final storeRaw = (results[6] as List?) ?? [];
  final dispatchRaw = (results[7] as List?) ?? [];

  final articles = articlesRaw.map((e) => PlantArticleItem.fromJson(e)).toList();
  final allotments = allotmentsRaw.map((e) => PlantAllotmentItem.fromJson(e)).toList();
  final challans = challansRaw.map((e) => PlantChallanItem.fromJson(e)).toList();
  final variants = variantsRaw.map((e) => Map<String, dynamic>.from(e)).toList();

  // 1. Extract Unique Brands for Tabs (ALL, OLLYPOP, ..., DIRECT)
  final Set<String> brandsSet = {};
  for (var c in challans) {
    if (c.brand.isNotEmpty) brandsSet.add(c.brand.toUpperCase());
  }
  for (var al in allotments) {
    if (al.brand != null && al.brand!.isNotEmpty) {
      brandsSet.add(al.brand!.toUpperCase());
    }
  }
  final brandTabs = ['ALL', ...brandsSet, 'DIRECT'];

  // 2. Date Filtering Helper
  final now = DateTime.now();
  final startOfToday = DateTime(now.year, now.month, now.day);

  bool matchesDate(DateTime? d) {
    if (d == null || filter.dateFilter == PlantDateFilter.all) return true;
    switch (filter.dateFilter) {
      case PlantDateFilter.today:
        return d.isAfter(startOfToday) || d.isAtSameMomentAs(startOfToday);
      case PlantDateFilter.week:
        final startOfWeek = startOfToday.subtract(const Duration(days: 7));
        return d.isAfter(startOfWeek);
      case PlantDateFilter.month:
        final startOfMonth = startOfToday.subtract(const Duration(days: 30));
        return d.isAfter(startOfMonth);
      case PlantDateFilter.all:
        return true;
    }
  }

  bool matchesArticle(String? artId) {
    if (filter.selectedArticleId == 'ALL') return true;
    return artId == filter.selectedArticleId;
  }

  bool matchesBrand(String? chId, String? chBrand) {
    if (filter.selectedBrand == 'ALL') return true;
    if (filter.selectedBrand == 'DIRECT') return (chId == null || chId.isEmpty) && (chBrand == null || chBrand.isEmpty);
    final ch = challans.where((c) => c.id == chId).firstOrNull;
    final brand = (ch?.brand ?? chBrand ?? '').trim().toUpperCase();
    return brand == filter.selectedBrand.toUpperCase();
  }

  // 3. Filtered Allotments
  final filteredAllotments = allotments.where((a) {
    return matchesArticle(a.articleId) &&
        matchesBrand(a.challanId, a.brand) &&
        matchesDate(a.allotmentDate != null ? DateTime.tryParse(a.allotmentDate!) : a.createdAt);
  }).toList();

  // Filtered Production
  final filteredProd = prodRaw.where((p) {
    final artId = p['article_id']?.toString();
    final d = p['entry_date'] != null ? DateTime.tryParse(p['entry_date'].toString()) : DateTime.tryParse(p['created_at'].toString());
    return matchesArticle(artId) && matchesDate(d);
  }).toList();

  // Filtered QC
  final filteredQC = qcRaw.where((q) {
    final artId = q['article_id']?.toString();
    final d = q['entry_date'] != null ? DateTime.tryParse(q['entry_date'].toString()) : DateTime.tryParse(q['created_at'].toString());
    return matchesArticle(artId) && matchesDate(d);
  }).toList();

  // Filtered Store
  final filteredStore = storeRaw.where((s) {
    final d = s['entry_date'] != null ? DateTime.tryParse(s['entry_date'].toString()) : DateTime.tryParse(s['created_at'].toString());
    return matchesDate(d);
  }).toList();

  // Filtered Dispatch
  final filteredDispatch = dispatchRaw.where((d) {
    final dt = DateTime.tryParse(d['created_at']?.toString() ?? '');
    return matchesDate(dt);
  }).toList();

  // 4. Compute the 6 Core Factory Lifecycle Numbers
  final relevantChallans = challans.where((c) {
    if (filter.selectedBrand == 'ALL') return true;
    if (filter.selectedBrand == 'DIRECT') return false;
    return c.brand.trim().toUpperCase() == filter.selectedBrand.toUpperCase();
  }).toList();

  final challanTotalPcs = relevantChallans.fold<int>(0, (sum, c) => sum + c.totalPcs);
  final totalAllotmentPcs = filteredAllotments
      .where((al) => al.status != 'CANCELLED')
      .fold<int>(0, (sum, al) => sum + al.targetQty);

  final totalStocksBase = challanTotalPcs > totalAllotmentPcs ? challanTotalPcs : totalAllotmentPcs;

  int totalProduced = 0;
  for (var p in filteredProd) {
    totalProduced += (p['quantity'] as num?)?.toInt() ?? 0;
  }

  int totalQCPassed = 0;
  int totalQCRejected = 0;
  for (var q in filteredQC) {
    final stage = q['stage']?.toString().toUpperCase() ?? 'CHECKING';
    if (stage == 'CHECKING' || stage == 'BULKING' || stage == 'FINAL') {
      totalQCPassed += (q['qty_passed'] as num?)?.toInt() ?? 0;
      totalQCRejected += (q['qty_rejected'] as num?)?.toInt() ?? 0;
    }
  }

  int storeInward = 0;
  int storeRTO = 0;
  for (var s in filteredStore) {
    final t = s['type']?.toString().toUpperCase() ?? 'INWARD';
    final qty = (s['quantity'] as num?)?.toInt() ?? 0;
    if (t == 'INWARD') storeInward += qty;
    if (t == 'RTO' || t == 'REJECT' || t == 'RETURN') storeRTO += qty;
  }

  int totalDispatched = 0;
  for (var d in filteredDispatch) {
    totalDispatched += (d['total_pieces'] as num?)?.toInt() ?? 0;
  }

  // 6-Stage Specific Allocations
  final stage1TotalStocks = totalStocksBase > (totalProduced + totalDispatched)
      ? totalStocksBase
      : (totalProduced + totalDispatched);

  // Stage 2: Goods In Line
  final floorSewingAllotments = filteredAllotments.where((al) =>
      al.status != 'CANCELLED' &&
      (al.mendingStatus == null || al.mendingStatus == 'PENDING_STITCHING') &&
      al.status != 'COMPLETED').toList();

  final activeLinemanAllotmentPcs =
      floorSewingAllotments.fold<int>(0, (sum, al) => sum + al.targetQty);

  final stage2GoodsInLine = activeLinemanAllotmentPcs > 0
      ? (activeLinemanAllotmentPcs - totalQCPassed - totalDispatched - totalQCRejected > 0
          ? activeLinemanAllotmentPcs - totalQCPassed - totalDispatched - totalQCRejected
          : 0)
      : 0;

  // Stage 3: Goods in Mending & Checking
  final mendingFloorAllotments = filteredAllotments.where((al) =>
      al.status != 'CANCELLED' &&
      (al.mendingStatus == 'PENDING_MENDING' ||
          al.mendingStatus == 'IN_MENDING' ||
          (al.status == 'COMPLETED' && (al.qcStatus == null || al.qcStatus == 'PENDING_STITCHING')))).toList();

  final mendingFloorPcs =
      mendingFloorAllotments.fold<int>(0, (sum, al) => sum + al.targetQty);

  final remainingProd = totalProduced - totalQCPassed - totalDispatched;
  final stage3MendingChecking = mendingFloorPcs + totalQCRejected + (remainingProd > 0 ? remainingProd : 0);

  // Stage 4: Ready Goods
  final passedMinusDispatch = totalQCPassed - totalDispatched;
  final stage4ReadyGoods = (passedMinusDispatch > 0 ? passedMinusDispatch : 0) + storeInward;

  // Stage 5: RTO
  final stage5Rto = storeRTO;

  // Stage 6: Ready Delivery
  final stage6ReadyDelivery = totalDispatched;

  // Smart Alteration Rate for Mending & Checking
  final totalChecked = totalQCPassed + totalQCRejected;
  final alterationRate = totalChecked > 0 ? ((totalQCRejected / totalChecked) * 100) : 0.0;

  // Conversion percentages
  final base = stage1TotalStocks > 0 ? stage1TotalStocks : 1;
  final inLinePct = ((stage2GoodsInLine / base) * 100).round().clamp(0, 100);
  final mendingPct = ((stage3MendingChecking / base) * 100).round().clamp(0, 100);
  final readyPct = ((stage4ReadyGoods / base) * 100).round().clamp(0, 100);
  final deliveryPct = ((stage6ReadyDelivery / base) * 100).round().clamp(0, 100);

  final metrics = PlantOperationsMetrics(
    totalStocks: stage1TotalStocks,
    goodsInLine: stage2GoodsInLine,
    mendingChecking: stage3MendingChecking,
    mendingFloorPcs: mendingFloorPcs,
    mendingFloorCount: mendingFloorAllotments.length,
    mendingAlterationQty: totalQCRejected,
    alterationRate: alterationRate,
    readyGoods: stage4ReadyGoods,
    rto: stage5Rto,
    readyDelivery: stage6ReadyDelivery,
    inLinePct: inLinePct,
    mendingPct: mendingPct,
    readyPct: readyPct,
    deliveryPct: deliveryPct,
  );

  // 5. Synthesize Multi-Stage Activity Stream
  final List<PlantActivityItem> activitiesList = [];

  for (var p in prodRaw) {
    final art = p['article'] as Map?;
    final dt = DateTime.tryParse(p['created_at']?.toString() ?? '') ?? DateTime.now();
    activitiesList.add(
      PlantActivityItem(
        id: 'prod-${p['id']}',
        type: 'PRODUCTION',
        title: 'Stitching Completed',
        details: '${p['quantity']} pcs • ${art?['art_no'] ?? 'Article'}',
        location: 'Floor Line',
        timestamp: dt,
      ),
    );
  }

  for (var q in qcRaw) {
    final art = q['article'] as Map?;
    final dt = DateTime.tryParse(q['created_at']?.toString() ?? '') ?? DateTime.now();
    activitiesList.add(
      PlantActivityItem(
        id: 'qc-${q['id']}',
        type: 'QC',
        title: 'QC ${(q['stage']?.toString() ?? 'Final').toUpperCase()}',
        details: '${q['qty_passed']} passed, ${q['qty_rejected']} rejected (${art?['art_no'] ?? 'Article'})',
        location: 'QC Station',
        timestamp: dt,
      ),
    );
  }

  for (var s in storeRaw) {
    final dt = DateTime.tryParse(s['created_at']?.toString() ?? '') ?? DateTime.now();
    activitiesList.add(
      PlantActivityItem(
        id: 'store-${s['id']}',
        type: 'STORE',
        title: (s['type']?.toString().toUpperCase() == 'INWARD' ? 'Godown Stock Received' : 'Store Outward'),
        details: '${s['quantity']} pcs${s['party_name'] != null ? ' • ${s['party_name']}' : ''}',
        location: 'Godown Store',
        timestamp: dt,
      ),
    );
  }

  for (var al in allotments) {
    if (al.handedToMendingAt != null || al.mendingStatus == 'PENDING_MENDING' || al.mendingStatus == 'IN_MENDING') {
      activitiesList.add(
        PlantActivityItem(
          id: 'mending-${al.id}',
          type: 'ALLOTMENT',
          title: 'Handover to Mending Floor',
          details: '${al.targetQty} pcs • Art ${al.articleNo} (${al.handedToMendingBy ?? 'Lineman'} → ${al.mendingSupervisorName ?? 'Mending Floor'})',
          location: 'Mending Dept',
          timestamp: al.handedToMendingAt ?? al.createdAt,
        ),
      );
    } else {
      activitiesList.add(
        PlantActivityItem(
          id: 'allot-${al.id}',
          type: 'ALLOTMENT',
          title: 'Target Allotted',
          details: '${al.targetQty} pcs of ${al.articleNo} to ${al.linemanName}',
          location: 'Floor Line',
          timestamp: al.createdAt,
        ),
      );
    }
  }

  for (var d in dispatchRaw) {
    final dt = DateTime.tryParse(d['created_at']?.toString() ?? '') ?? DateTime.now();
    activitiesList.add(
      PlantActivityItem(
        id: 'dispatch-${d['id']}',
        type: 'DISPATCH',
        title: 'Challan #${d['challan_no']}',
        details: '${d['buyer_name'] ?? 'Buyer'} • ${d['total_pieces']} pcs dispatched',
        location: 'Dispatch Bay',
        timestamp: dt,
      ),
    );
  }

  // Sort activities reverse-chronological and filter by date if needed
  activitiesList.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  final filteredActivities = activitiesList.where((a) => matchesDate(a.timestamp)).take(12).toList();

  // 6. Build Typed QC, Store, Dispatch lists matching filter
  final qcLogs = filteredQC.map((q) => PlantQCItem.fromJson(q)).toList();
  final storeTransactions = filteredStore.map((s) => PlantStoreItem.fromJson(s)).toList();
  final dispatches = filteredDispatch.map((d) => PlantDispatchItem.fromJson(d)).toList();

  // 7. Group Goods In Line by Lineman (matching web)
  final Map<String, List<PlantAllotmentItem>> linemanMap = {};
  for (var al in floorSewingAllotments) {
    final key = (al.linemanId != null && al.linemanId!.isNotEmpty) ? al.linemanId! : al.linemanName;
    linemanMap.putIfAbsent(key, () => []).add(al);
  }

  final List<PlantLinemanGroup> linemanGroups = [];
  linemanMap.forEach((key, list) {
    int pcs = 0;
    double wage = 0.0;
    final Set<String> arts = {};
    String lmName = list.first.linemanName;

    for (var item in list) {
      pcs += item.targetQty;
      final art = articles.where((a) => a.id == item.articleId).firstOrNull;
      final rate = art?.stitchingRate ?? 20.0;
      wage += (item.targetQty * rate);
      if (item.articleNo.isNotEmpty && item.articleNo != 'Style') {
        arts.add(item.articleNo);
      }
    }

    linemanGroups.add(
      PlantLinemanGroup(
        key: key,
        name: lmName,
        allotments: list,
        totalPcs: pcs,
        totalWage: wage,
        articleNumbers: arts.toList(),
      ),
    );
  });

  // Sort lineman groups by total pieces descending
  linemanGroups.sort((a, b) => b.totalPcs.compareTo(a.totalPcs));

  return PlantOperationsData(
    articles: articles,
    allAllotments: allotments,
    filteredAllotments: filteredAllotments,
    challans: challans,
    brandTabs: brandTabs,
    metrics: metrics,
    activities: filteredActivities,
    variants: variants,
    qcLogs: qcLogs,
    storeTransactions: storeTransactions,
    dispatches: dispatches,
    linemanGroups: linemanGroups,
  );
});

