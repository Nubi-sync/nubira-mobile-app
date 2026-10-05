import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../main.dart';
import '../../../core/services/tenant_resolver_service.dart';

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

class TrendBarItem {
  final String label;
  final int planned;
  final int production;
  final int delivered;
  final int dateVal;

  TrendBarItem({
    required this.label,
    required this.planned,
    required this.production,
    required this.delivered,
    required this.dateVal,
  });
}

class OrderStatusSegment {
  final String key;
  final String label;
  final int count;
  final int colorHex;
  final int pct;

  OrderStatusSegment({
    required this.key,
    required this.label,
    required this.count,
    required this.colorHex,
    required this.pct,
  });
}

class CategoryVolumeItem {
  final String label;
  final int count;
  final int colorHex;

  CategoryVolumeItem({
    required this.label,
    required this.count,
    required this.colorHex,
  });
}

class TopRunningStyleItem {
  final String artNo;
  final String description;
  final int orderQty;
  final int producedQty;

  TopRunningStyleItem({
    required this.artNo,
    required this.description,
    required this.orderQty,
    required this.producedQty,
  });
}

/// Aggregated metrics computed exactly identical to web dashboard
class PlantOperationsMetrics {
  final int totalStocks;
  final int unallottedStocks;
  final int totalOrderPipeline;
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
  final int totalProduced;
  final int totalQCPassed;
  final int totalDispatched;

  PlantOperationsMetrics({
    this.totalStocks = 0,
    this.unallottedStocks = 0,
    this.totalOrderPipeline = 0,
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
    this.totalProduced = 0,
    this.totalQCPassed = 0,
    this.totalDispatched = 0,
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
  final List<TrendBarItem> monthlyTrend;
  final List<TrendBarItem> weeklyTrend;
  final List<OrderStatusSegment> orderStatusSegments;
  final List<CategoryVolumeItem> categoryProduction;
  final String primarySegmentText;
  final List<TopRunningStyleItem> topRunningStyles;

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
    this.monthlyTrend = const [],
    this.weeklyTrend = const [],
    this.orderStatusSegments = const [],
    this.categoryProduction = const [],
    this.primarySegmentText = '',
    this.topRunningStyles = const [],
  }) : metrics = metrics ?? PlantOperationsMetrics();
}

/// Helper to clean description
String cleanDesc(String? d) {
  if (d == null) return '';
  return d.replaceAll(RegExp(r'\s*\[.*\]'), '').trim();
}

/// Helper to extract dynamic category from article & challan
String extractCategory(PlantArticleItem? art, PlantChallanItem? ch) {
  if (art?.sizeRates != null && art!.sizeRates!['category'] is String && (art.sizeRates!['category'] as String).trim().isNotEmpty) {
    return (art.sizeRates!['category'] as String).trim();
  }
  final d = cleanDesc(art?.description);
  if (d.isNotEmpty) {
    final parts = d.split(RegExp(r'[-•:\/|]'));
    final first = parts[0].trim();
    if (first.isNotEmpty && !RegExp(r'^[0-9]+$').hasMatch(first) && first.length >= 2) {
      final cleaned = first.replaceAll(RegExp(r'^(art|article|style|no|#)?\s*[0-9A-Z_-]+\s*[-•:]*\s*', caseSensitive: false), '').trim();
      if (cleaned.length >= 2 && int.tryParse(cleaned) == null) {
        return cleaned;
      }
      if (int.tryParse(first) == null) {
        return first;
      }
    }
  }
  if (ch?.fabricType != null && ch!.fabricType!.trim().isNotEmpty) {
    return ch.fabricType!.trim();
  }
  return 'General';
}

/// Primary Riverpod Provider for Plant Operations Control Center
final plantOperationsProvider =
    FutureProvider.autoDispose<PlantOperationsData>((ref) async {
  final filter = ref.watch(plantOperationsFilterProvider);

  final currentUser = supabase.auth.currentUser;
  ResolvedTenantProfile? tenant;
  if (currentUser != null) {
    try {
      tenant = await TenantResolverService.resolveUserTenant(currentUser);
    } catch (_) {}
  }
  final isPlatformSuper = tenant?.isPlatformAdmin == true || tenant?.role == 'PLATFORM_SUPERADMIN';
  final email = (currentUser?.email ?? '').toLowerCase();
  final compName = (tenant?.companyName ?? '').toLowerCase();
  final isCustomPlant = isPlatformSuper ||
      compName.contains('nubira') ||
      email.contains('nubira') ||
      email == 'aj@nubiracreation.com' ||
      email == 'team.anga9@gmail.com' ||
      email == 'admin@zigza.in';

  final targetComp = (!isPlatformSuper && !isCustomPlant && tenant != null && tenant.companyName.trim().isNotEmpty)
      ? tenant.companyName.trim().toLowerCase()
      : null;

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
    ''').order('created_at', ascending: false).limit(300),

    // 2: Challans
    supabase.from('challans').select('*').order('created_at', ascending: false).limit(200),

    // 3: Variants
    supabase.from('allotment_variants').select('*').limit(1000),

    // 4: Daily Product (Production WIP)
    supabase.from('daily_product').select('''
      id, quantity, entry_date, created_at, article_id, lineman_id,
      article:article_id ( id, art_no, description )
    ''').order('created_at', ascending: false).limit(300),

    // 5: QC Logs
    supabase.from('qc_logs').select('''
      id, qty_passed, qty_rejected, stage, defect_type, entry_date, created_at, article_id,
      article:article_id ( id, art_no, description )
    ''').order('created_at', ascending: false).limit(300),

    // 6: Store Transactions
    supabase.from('store_transactions').select('''
      id, type, quantity, party_name, created_at,
      article:article_id ( art_no, description )
    ''').order('created_at', ascending: false).limit(300),

    // 7: Delivery Challans (Dispatches)
    supabase.from('delivery_challans').select('*').order('created_at', ascending: false).limit(200),
  ]);

  var articlesRaw = (results[0] as List?) ?? [];
  var allotmentsRaw = (results[1] as List?) ?? [];
  var challansRaw = (results[2] as List?) ?? [];
  final variantsRaw = (results[3] as List?) ?? [];
  final prodRaw = (results[4] as List?) ?? [];
  final qcRaw = (results[5] as List?) ?? [];
  var storeRaw = (results[6] as List?) ?? [];
  var dispatchRaw = (results[7] as List?) ?? [];

  if (targetComp != null && targetComp.isNotEmpty) {
    challansRaw = challansRaw.where((ch) {
      final comp = (ch['company_name']?.toString() ?? '').toLowerCase();
      return comp == targetComp || comp.contains(targetComp);
    }).toList();

    final scopedChallanIds = challansRaw.map((c) => c['id']?.toString()).toSet();

    allotmentsRaw = allotmentsRaw.where((al) {
      final chId = al['challan_id']?.toString();
      if (chId != null && scopedChallanIds.contains(chId)) return true;
      final comp = (al['company_name']?.toString() ?? '').toLowerCase();
      return comp == targetComp || comp.contains(targetComp);
    }).toList();

    articlesRaw = articlesRaw.where((art) {
      final rates = art['size_rates'];
      String rateComp = '';
      if (rates is Map) {
        rateComp = (rates['company_name']?.toString() ?? rates['_meta']?['company_name']?.toString() ?? '').toLowerCase();
      }
      return rateComp == targetComp || rateComp.contains(targetComp);
    }).toList();

    storeRaw = storeRaw.where((s) {
      final comp = (s['company_name']?.toString() ?? '').toLowerCase();
      return comp == targetComp || comp.contains(targetComp);
    }).toList();

    dispatchRaw = dispatchRaw.where((d) {
      final comp = (d['company_name']?.toString() ?? '').toLowerCase();
      return comp == targetComp || comp.contains(targetComp);
    }).toList();
  }

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

  final totalOrderPipeline = challanTotalPcs > totalAllotmentPcs ? challanTotalPcs : totalAllotmentPcs;

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

  // Stage 1: Unallotted Stocks (Pending Allotment Balance)
  final stage1UnallottedStocks = (totalOrderPipeline - activeLinemanAllotmentPcs) > 0
      ? (totalOrderPipeline - activeLinemanAllotmentPcs)
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
  final base = totalOrderPipeline > 0 ? totalOrderPipeline : 1;
  final inLinePct = ((stage2GoodsInLine / base) * 100).round().clamp(0, 100);
  final mendingPct = ((stage3MendingChecking / base) * 100).round().clamp(0, 100);
  final readyPct = ((stage4ReadyGoods / base) * 100).round().clamp(0, 100);
  final deliveryPct = ((stage6ReadyDelivery / base) * 100).round().clamp(0, 100);

  final metrics = PlantOperationsMetrics(
    totalStocks: totalOrderPipeline,
    unallottedStocks: stage1UnallottedStocks,
    totalOrderPipeline: totalOrderPipeline,
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
    totalProduced: totalProduced,
    totalQCPassed: totalQCPassed,
    totalDispatched: totalDispatched,
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
        details: '${p['quantity']} pcs produced • Art: ${art?['art_no'] ?? 'Article'}',
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
        details: '${q['qty_passed']} passed, ${q['qty_rejected']} rejected • Art: ${art?['art_no'] ?? 'Article'}',
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
          details: '${al.targetQty} pcs • Art: ${al.articleNo} (${al.handedToMendingBy ?? 'Lineman'} → ${al.mendingSupervisorName ?? 'Mending Floor'})',
          location: 'Mending Dept',
          timestamp: al.handedToMendingAt ?? al.createdAt,
        ),
      );
    } else {
      activitiesList.add(
        PlantActivityItem(
          id: 'allot-${al.id}',
          type: 'ALLOTMENT',
          title: 'Allotted to ${al.linemanName}',
          details: '${al.targetQty} pcs of Art: ${al.articleNo}${al.challanNo != null ? ' • Challan ${al.challanNo}' : ''}',
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
        title: 'Challan ${d['challan_no']} Dispatched',
        details: '${d['buyer_name'] ?? 'Buyer'} • ${d['total_pieces']} pcs dispatched via Gate Pass',
        location: 'Dispatch Bay',
        timestamp: dt,
      ),
    );
  }

  // Sort activities reverse-chronological
  activitiesList.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  final filteredActivities = activitiesList.where((a) => matchesDate(a.timestamp)).take(20).toList();

  // 6. Production Trend Data (Monthly & Weekly)
  final Map<String, TrendBarItem> monthlyMap = {};
  for (var c in challans) {
    final dt = DateTime.tryParse(c.createdAt.toString());
    if (dt != null) {
      final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
      final label = DateFormat('MMM yyyy').format(dt);
      monthlyMap.putIfAbsent(key, () => TrendBarItem(label: label, planned: 0, production: 0, delivered: 0, dateVal: DateTime(dt.year, dt.month).millisecondsSinceEpoch));
      monthlyMap[key] = TrendBarItem(label: label, planned: monthlyMap[key]!.planned + c.totalPcs, production: monthlyMap[key]!.production, delivered: monthlyMap[key]!.delivered, dateVal: monthlyMap[key]!.dateVal);
    }
  }
  for (var p in prodRaw) {
    final dt = DateTime.tryParse(p['entry_date']?.toString() ?? p['created_at']?.toString() ?? '');
    if (dt != null) {
      final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
      final label = DateFormat('MMM yyyy').format(dt);
      final qty = (p['quantity'] as num?)?.toInt() ?? 0;
      monthlyMap.putIfAbsent(key, () => TrendBarItem(label: label, planned: 0, production: 0, delivered: 0, dateVal: DateTime(dt.year, dt.month).millisecondsSinceEpoch));
      monthlyMap[key] = TrendBarItem(label: label, planned: monthlyMap[key]!.planned, production: monthlyMap[key]!.production + qty, delivered: monthlyMap[key]!.delivered, dateVal: monthlyMap[key]!.dateVal);
    }
  }
  for (var d in dispatchRaw) {
    final dt = DateTime.tryParse(d['created_at']?.toString() ?? '');
    if (dt != null) {
      final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
      final label = DateFormat('MMM yyyy').format(dt);
      final qty = (d['total_pieces'] as num?)?.toInt() ?? 0;
      monthlyMap.putIfAbsent(key, () => TrendBarItem(label: label, planned: 0, production: 0, delivered: 0, dateVal: DateTime(dt.year, dt.month).millisecondsSinceEpoch));
      monthlyMap[key] = TrendBarItem(label: label, planned: monthlyMap[key]!.planned, production: monthlyMap[key]!.production, delivered: monthlyMap[key]!.delivered + qty, dateVal: monthlyMap[key]!.dateVal);
    }
  }

  if (monthlyMap.isEmpty) {
    final now = DateTime.now();
    final key = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final label = DateFormat('MMM yyyy').format(now);
    monthlyMap[key] = TrendBarItem(
      label: label,
      planned: totalOrderPipeline,
      production: totalProduced,
      delivered: stage6ReadyDelivery,
      dateVal: now.millisecondsSinceEpoch,
    );
  }

  final monthlyTrend = monthlyMap.values.toList()..sort((a, b) => a.dateVal.compareTo(b.dateVal));

  // 7. Order Status Donut Breakdown
  final inProd = stage2GoodsInLine;
  final deliv = stage6ReadyDelivery;
  final mend = metrics.mendingAlterationQty + mendingFloorPcs;
  final chk = stage3MendingChecking;
  final rawPend = totalOrderPipeline - (inProd + deliv + mend + chk);
  final pend = rawPend > 0 ? rawPend : 0;
  final totalStat = (inProd + deliv + mend + chk + pend) > 0 ? (inProd + deliv + mend + chk + pend) : 1;

  final orderStatusSegments = [
    OrderStatusSegment(key: 'IN_PROD', label: 'In Production', count: inProd, colorHex: 0xFF0B1220, pct: ((inProd / totalStat) * 100).round()),
    OrderStatusSegment(key: 'DELIVERED', label: 'Delivered', count: deliv, colorHex: 0xFF14C8B4, pct: ((deliv / totalStat) * 100).round()),
    OrderStatusSegment(key: 'MENDING', label: 'Mending', count: mend, colorHex: 0xFFE11D48, pct: ((mend / totalStat) * 100).round()),
    OrderStatusSegment(key: 'CHECKING', label: 'Checking', count: chk, colorHex: 0xFFD97706, pct: ((chk / totalStat) * 100).round()),
    OrderStatusSegment(key: 'PENDING', label: 'Pending Allotment', count: pend, colorHex: 0xFF94A3B8, pct: ((pend / totalStat) * 100).round()),
  ];

  // 8. Category Production Breakdown
  final categoryPalette = [
    0xFF0B1220, // Obsidian
    0xFF14C8B4, // Mint
    0xFF1D4ED8, // Royal Blue
    0xFFF59E0B, // Amber
    0xFFEC4899, // Pink
    0xFF0284C7, // Cyan
  ];

  final Map<String, int> catCountMap = {};
  for (var al in filteredAllotments) {
    if (al.status == 'CANCELLED') continue;
    final art = articles.where((a) => a.id == al.articleId).firstOrNull;
    final ch = challans.where((c) => c.id == al.challanId).firstOrNull;
    final cat = extractCategory(art, ch);
    catCountMap[cat] = (catCountMap[cat] ?? 0) + al.targetQty;
  }

  for (var ch in challans) {
    final cat = extractCategory(null, ch);
    if (cat != 'General') {
      catCountMap.putIfAbsent(cat, () => 0);
      if (catCountMap[cat] == 0 && ch.totalPcs > 0) {
        catCountMap[cat] = ch.totalPcs;
      }
    }
  }

  if (catCountMap.isEmpty) {
    for (var art in articles) {
      final cat = extractCategory(art, null);
      catCountMap.putIfAbsent(cat, () => 0);
    }
  }

  final sortedCats = catCountMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  final categoryProduction = <CategoryVolumeItem>[];
  for (int i = 0; i < sortedCats.length && i < 6; i++) {
    categoryProduction.add(CategoryVolumeItem(
      label: sortedCats[i].key,
      count: sortedCats[i].value,
      colorHex: categoryPalette[i % categoryPalette.length],
    ));
  }

  final catTotal = categoryProduction.fold<int>(0, (s, c) => s + c.count);
  final topCat = categoryProduction.isNotEmpty ? categoryProduction.first : null;
  final topPct = (topCat != null && catTotal > 0) ? ((topCat.count / catTotal) * 100).round() : 0;
  final primarySegmentText = topCat != null ? '${topCat.label} ($topPct%)' : 'All Items';

  // 9. Top Running Styles
  final Map<String, TopRunningStyleItem> styleMap = {};
  for (var art in articles) {
    final aNo = art.artNo.trim();
    if (aNo.isNotEmpty && !styleMap.containsKey(aNo)) {
      styleMap[aNo] = TopRunningStyleItem(
        artNo: aNo,
        description: cleanDesc(art.description),
        orderQty: 0,
        producedQty: 0,
      );
    }
  }

  for (var al in filteredAllotments) {
    if (al.status == 'CANCELLED') continue;
    final aNo = al.articleNo.trim();
    if (styleMap.containsKey(aNo)) {
      final cur = styleMap[aNo]!;
      styleMap[aNo] = TopRunningStyleItem(
        artNo: aNo,
        description: cur.description.isNotEmpty ? cur.description : cleanDesc(al.articleDescription),
        orderQty: cur.orderQty + al.targetQty,
        producedQty: cur.producedQty,
      );
    } else {
      styleMap[aNo] = TopRunningStyleItem(
        artNo: aNo,
        description: cleanDesc(al.articleDescription),
        orderQty: al.targetQty,
        producedQty: 0,
      );
    }
  }

  final topRunningStyles = styleMap.values.where((s) => s.orderQty > 0 || s.producedQty > 0).toList()
    ..sort((a, b) => b.orderQty.compareTo(a.orderQty));

  // 10. Typed QC, Store, Dispatch
  final qcLogs = filteredQC.map((q) => PlantQCItem.fromJson(q)).toList();
  final storeTransactions = filteredStore.map((s) => PlantStoreItem.fromJson(s)).toList();
  final dispatches = filteredDispatch.map((d) => PlantDispatchItem.fromJson(d)).toList();

  // 11. Group Goods In Line by Lineman
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
    monthlyTrend: monthlyTrend,
    weeklyTrend: const [],
    orderStatusSegments: orderStatusSegments,
    categoryProduction: categoryProduction,
    primarySegmentText: primarySegmentText,
    topRunningStyles: topRunningStyles.take(5).toList(),
  );
});

