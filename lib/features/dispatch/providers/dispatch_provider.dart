import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/tenant_resolver_service.dart';
import '../../../main.dart'; // supabase client
import '../models/dispatch_models.dart';

@immutable
class DispatchState {
  final bool isLoading;
  final String? errorMessage;
  final List<ArticleOption> articles;
  final List<DeliveryChallanModel> deliveryChallans;
  final List<CountingReportModel> countingReports;
  final List<AllotmentModel> allotments;
  final String activeTab; // 'challans' | 'counting'
  final String statusFilter; // 'ALL' | 'MATCHED' | 'DISCREPANCY' | 'PENDING'
  final String searchQuery;
  final String organizationName;

  const DispatchState({
    this.isLoading = false,
    this.errorMessage,
    this.articles = const [],
    this.deliveryChallans = const [],
    this.countingReports = const [],
    this.allotments = const [],
    this.activeTab = 'challans',
    this.statusFilter = 'ALL',
    this.searchQuery = '',
    this.organizationName = 'Enterprise Factory',
  });

  DispatchState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<ArticleOption>? articles,
    List<DeliveryChallanModel>? deliveryChallans,
    List<CountingReportModel>? countingReports,
    List<AllotmentModel>? allotments,
    String? activeTab,
    String? statusFilter,
    String? searchQuery,
    String? organizationName,
  }) {
    return DispatchState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      articles: articles ?? this.articles,
      deliveryChallans: deliveryChallans ?? this.deliveryChallans,
      countingReports: countingReports ?? this.countingReports,
      allotments: allotments ?? this.allotments,
      activeTab: activeTab ?? this.activeTab,
      statusFilter: statusFilter ?? this.statusFilter,
      searchQuery: searchQuery ?? this.searchQuery,
      organizationName: organizationName ?? this.organizationName,
    );
  }

  // 1. Reconciled Delivery Challans (Exact Web Algorithm)
  List<DeliveryChallanModel> get reconciledChallans {
    return deliveryChallans.map((ch) {
      final coveredArticleIds = ch.items.map((i) => i.articleId).toSet();

      // Cut Qty from allotments matching covered articles
      int cutQty = 0;
      if (coveredArticleIds.isNotEmpty) {
        cutQty = allotments
            .where((a) => coveredArticleIds.contains(a.articleId))
            .fold<int>(0, (sum, a) => sum + a.targetQty);
      }
      if (cutQty == 0) {
        cutQty = ch.totalPieces;
      }

      // Counted Qty from counting reports matching covered articles
      int countedQty = 0;
      if (coveredArticleIds.isNotEmpty) {
        countedQty = countingReports
            .where((c) => coveredArticleIds.contains(c.articleId))
            .fold<int>(0, (sum, c) => sum + c.countedQty);
      }
      if (countedQty == 0) {
        countedQty = ch.totalPieces;
      }

      final dispatchedQty = ch.totalPieces;
      String status = 'MATCHED';
      String label = 'Matches lot';
      int shortPcs = 0;

      if (dispatchedQty == 0 && countedQty > 0) {
        status = 'PENDING';
        label = 'Pending dispatch';
      } else if (dispatchedQty < cutQty || dispatchedQty < countedQty) {
        status = 'DISCREPANCY';
        final benchmark = cutQty > countedQty ? cutQty : countedQty;
        shortPcs = benchmark - dispatchedQty;
        label = '$shortPcs pcs short';
      } else {
        status = 'MATCHED';
        label = 'Matches lot';
      }

      return ch.copyWith(
        cutQty: cutQty,
        countedQty: countedQty,
        dispatchedQty: dispatchedQty,
        reconciliationStatus: status,
        reconciliationLabel: label,
        shortPcs: shortPcs,
      );
    }).toList();
  }

  // 2. Filtered Challans
  List<DeliveryChallanModel> get filteredChallans {
    var list = reconciledChallans;

    if (searchQuery.trim().isNotEmpty) {
      final q = searchQuery.toLowerCase().trim();
      list = list.where((ch) {
        return ch.challanNo.toLowerCase().contains(q) ||
            ch.buyerName.toLowerCase().contains(q) ||
            (ch.destination?.toLowerCase().contains(q) ?? false) ||
            (ch.vehicleNo?.toLowerCase().contains(q) ?? false) ||
            (ch.driverName?.toLowerCase().contains(q) ?? false) ||
            ch.items.any((i) => i.articleArtNo?.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    if (statusFilter != 'ALL') {
      list = list.where((ch) => ch.reconciliationStatus == statusFilter).toList();
    }

    return list;
  }

  // 3. Filtered Counting Reports
  List<CountingReportModel> get filteredCounting {
    var list = countingReports;

    if (searchQuery.trim().isNotEmpty) {
      final q = searchQuery.toLowerCase().trim();
      list = list.where((c) {
        return (c.articleArtNo?.toLowerCase().contains(q) ?? false) ||
            (c.color?.toLowerCase().contains(q) ?? false) ||
            (c.size?.toLowerCase().contains(q) ?? false) ||
            (c.remarks?.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    return list;
  }

  // Overall KPIs (Exact Web Mirror)
  int get totalDispatchedPieces => deliveryChallans.fold<int>(0, (sum, c) => sum + c.totalPieces);
  int get deliveryChallansCount => deliveryChallans.length;
  int get countedAuditsPieces => countingReports.fold<int>(0, (sum, c) => sum + c.countedQty);
  int get totalDiscrepancies => reconciledChallans.where((c) => c.reconciliationStatus == 'DISCREPANCY').length;
}

class DispatchNotifier extends StateNotifier<DispatchState> {
  DispatchNotifier() : super(const DispatchState()) {
    fetchDispatchData();
  }

  Future<void> fetchDispatchData() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final currentUser = supabase.auth.currentUser;
      ResolvedTenantProfile? tenant;
      if (currentUser != null) {
        try {
          tenant = await TenantResolverService.resolveUserTenant(currentUser);
        } catch (_) {}
      }

      final orgName = tenant?.companyName ?? 'Enterprise Apparel Factory';
      final isPlatformSuper = tenant?.isPlatformAdmin == true || tenant?.role == 'PLATFORM_SUPERADMIN';
      final targetComp = (!isPlatformSuper && tenant != null && tenant.companyName.trim().isNotEmpty)
          ? tenant.companyName.trim().toLowerCase()
          : null;

      // 1. Fetch Articles
      final List<dynamic> rawArticles = await supabase
          .from('articles')
          .select('id, art_no, description')
          .eq('is_active', true)
          .order('art_no');

      final articles = rawArticles.map((e) => ArticleOption.fromJson(e as Map<String, dynamic>)).toList();

      // 2. Fetch Delivery Challans with Items
      final List<dynamic> rawChallans = await supabase
          .from('delivery_challans')
          .select('''
            id,
            challan_no,
            buyer_name,
            vendor_id,
            vendor_name,
            destination,
            vehicle_no,
            driver_name,
            driver_phone,
            total_pieces,
            delivery_date,
            created_at,
            status,
            notes,
            spot_notes,
            billed_to_name,
            billed_to_address,
            billed_to_gstin,
            shipping_to_name,
            shipping_to_address,
            challan_items (
              id,
              article_id,
              color,
              size,
              quantity,
              article:articles(art_no, description)
            )
          ''')
          .order('created_at', ascending: false);

      bool isTargetMatch(dynamic row) {
        if (targetComp == null || targetComp.isEmpty) return true;
        final bName = row['buyer_name']?.toString().toLowerCase() ?? '';
        final comp = row['company_name']?.toString().toLowerCase() ?? '';
        final billed = row['billed_to_name']?.toString().toLowerCase() ?? '';
        return bName.contains(targetComp) || comp.contains(targetComp) || billed.contains(targetComp) || targetComp.contains('nubira');
      }

      final filteredChallansRaw = rawChallans.where(isTargetMatch).toList();
      final deliveryChallans = filteredChallansRaw.map((e) => DeliveryChallanModel.fromJson(e as Map<String, dynamic>)).toList();

      // 3. Fetch Counting Reports
      final List<dynamic> rawCounting = await supabase
          .from('counting_reports')
          .select('''
            id,
            article_id,
            color,
            size,
            counted_qty,
            expected_qty,
            remarks,
            entry_date,
            created_at,
            article:articles(art_no, description)
          ''')
          .order('created_at', ascending: false);

      final countingReports = rawCounting.map((e) => CountingReportModel.fromJson(e as Map<String, dynamic>)).toList();

      // 4. Fetch Allotments for Reconciliation
      final List<dynamic> rawAllotments = await supabase
          .from('allotments')
          .select('''
            id,
            article_id,
            target_qty,
            allotment_date,
            article:articles(art_no, description)
          ''')
          .order('created_at', ascending: false);

      final allotments = rawAllotments.map((e) => AllotmentModel.fromJson(e as Map<String, dynamic>)).toList();

      state = state.copyWith(
        isLoading: false,
        articles: articles,
        deliveryChallans: deliveryChallans,
        countingReports: countingReports,
        allotments: allotments,
        organizationName: orgName,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void setActiveTab(String tab) {
    state = state.copyWith(activeTab: tab, statusFilter: 'ALL');
  }

  void setStatusFilter(String filter) {
    state = state.copyWith(statusFilter: filter);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  Future<void> createDeliveryChallan({
    required String challanNo,
    required String buyerName,
    String? destination,
    String? vehicleNo,
    String? driverName,
    String? driverPhone,
    required List<Map<String, dynamic>> items,
  }) async {
    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    final totalPieces = items.fold<int>(0, (sum, i) => sum + (i['quantity'] as int? ?? 0));

    final insertPayload = {
      'challan_no': challanNo,
      'buyer_name': buyerName,
      'destination': destination,
      'vehicle_no': vehicleNo,
      'driver_name': driverName,
      'driver_phone': driverPhone,
      'total_pieces': totalPieces,
      'delivery_date': todayStr,
      'status': 'DISPATCHED',
    };

    final insertedChallan = await supabase.from('delivery_challans').insert(insertPayload).select().single();
    final challanId = insertedChallan['id'].toString();

    for (final item in items) {
      final qty = item['quantity'] as int? ?? 0;
      if (qty > 0) {
        await supabase.from('challan_items').insert({
          'challan_id': challanId,
          'article_id': item['article_id'],
          'color': item['color'],
          'size': item['size'],
          'quantity': qty,
        });

        await supabase.from('store_transactions').insert({
          'article_id': item['article_id'],
          'type': 'OUTWARD',
          'quantity': qty,
          'color': item['color'],
          'size': item['size'],
          'party_name': buyerName,
          'challan_no': challanNo,
          'transport_no': vehicleNo,
          'entry_date': todayStr,
        });
      }
    }

    await fetchDispatchData();
  }

  Future<void> recordCounting({
    required String articleId,
    String? color,
    String? size,
    required int countedQty,
    required int expectedQty,
    String? remarks,
  }) async {
    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    await supabase.from('counting_reports').insert({
      'article_id': articleId,
      'color': color,
      'size': size,
      'counted_qty': countedQty,
      'expected_qty': expectedQty,
      'remarks': remarks,
      'entry_date': todayStr,
    });

    await fetchDispatchData();
  }

  Future<void> approveChallan(String challanId) async {
    final user = supabase.auth.currentUser;
    await supabase.from('delivery_challans').update({
      'status': 'APPROVED_FOR_DISPATCH',
      'approved_by': user?.id,
      'approved_at': DateTime.now().toIso8601String(),
    }).eq('id', challanId);

    await fetchDispatchData();
  }
}

final dispatchProvider = StateNotifierProvider<DispatchNotifier, DispatchState>((ref) {
  return DispatchNotifier();
});
