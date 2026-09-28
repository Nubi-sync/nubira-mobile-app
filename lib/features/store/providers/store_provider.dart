import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/tenant_resolver_service.dart';
import '../../../main.dart'; // Supabase client
import '../models/store_models.dart';

@immutable
class StoreState {
  final bool isLoading;
  final String? errorMessage;
  final List<CentralFabricInventoryModel> fabrics;
  final List<CentralMaterialIssueModel> issues;
  final List<CentralMaterialReceiptModel> receipts;
  final List<TruckInwardModel> truckInwards;
  final List<dynamic> rawArticles;
  final String activeTab; // 'OVERVIEW' | 'FABRICS' | 'ISSUES' | 'RECEIPTS' | 'TRUCKS'
  final String statusFilter; // 'ALL' | 'AVAILABLE' | 'BOOKED' | 'LOW_STOCK'
  final String searchQuery;
  final String organizationName;

  const StoreState({
    this.isLoading = false,
    this.errorMessage,
    this.fabrics = const [],
    this.issues = const [],
    this.receipts = const [],
    this.truckInwards = const [],
    this.rawArticles = const [],
    this.activeTab = 'OVERVIEW',
    this.statusFilter = 'ALL',
    this.searchQuery = '',
    this.organizationName = 'DIV 11',
  });

  // KPIs
  double get totalFabricMeters => fabrics.fold(0.0, (sum, f) => sum + f.totalMeters);
  int get totalFabricRolls => fabrics.fold(0, (sum, f) => sum + f.totalRolls);
  double get totalWeightKg => fabrics.fold(0.0, (sum, f) => sum + f.totalWeightKg);
  double get totalBookedMeters => fabrics.fold(0.0, (sum, f) => sum + f.bookedMeters);
  double get totalAvailableMeters => fabrics.fold(0.0, (sum, f) => sum + f.availableMeters);
  int get activeIssuesCount => issues.where((i) => i.status == 'ISSUED' || i.status == 'IN_TRANSIT').length;
  int get totalTrucksCount => truckInwards.length;

  List<CentralFabricInventoryModel> get filteredFabrics {
    return fabrics.where((f) {
      if (statusFilter == 'AVAILABLE' && f.availableMeters <= 0) return false;
      if (statusFilter == 'BOOKED' && f.bookedMeters <= 0) return false;
      if (statusFilter == 'LOW_STOCK' && f.availableMeters > 200) return false;

      if (searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase();
        final matchType = f.fabricType.toLowerCase().contains(q);
        final matchColor = f.color.toLowerCase().contains(q);
        final matchSupplier = f.supplierName?.toLowerCase().contains(q) ?? false;
        final matchRack = f.rackLocation.toLowerCase().contains(q);
        final matchArticle = f.bookedForArticle?.toLowerCase().contains(q) ?? false;
        return matchType || matchColor || matchSupplier || matchRack || matchArticle;
      }
      return true;
    }).toList();
  }

  List<CentralMaterialIssueModel> get filteredIssues {
    return issues.where((i) {
      if (searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase();
        final matchChallan = i.issueChallanNo.toLowerCase().contains(q);
        final matchTo = i.toDivision.toLowerCase().contains(q);
        final matchArticle = i.articleNo?.toLowerCase().contains(q) ?? false;
        final matchBuyer = i.buyerName?.toLowerCase().contains(q) ?? false;
        final matchType = i.fabricType?.toLowerCase().contains(q) ?? false;
        return matchChallan || matchTo || matchArticle || matchBuyer || matchType;
      }
      return true;
    }).toList();
  }

  List<TruckInwardModel> get filteredTrucks {
    return truckInwards.where((t) {
      if (searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase();
        final matchParty = t.partyName.toLowerCase().contains(q);
        final matchGrn = t.grnNo.toLowerCase().contains(q);
        final matchTruck = t.truckNo?.toLowerCase().contains(q) ?? false;
        final matchChallan = t.challanNo?.toLowerCase().contains(q) ?? false;
        return matchParty || matchGrn || matchTruck || matchChallan;
      }
      return true;
    }).toList();
  }

  StoreState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<CentralFabricInventoryModel>? fabrics,
    List<CentralMaterialIssueModel>? issues,
    List<CentralMaterialReceiptModel>? receipts,
    List<TruckInwardModel>? truckInwards,
    List<dynamic>? rawArticles,
    String? activeTab,
    String? statusFilter,
    String? searchQuery,
    String? organizationName,
  }) {
    return StoreState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      fabrics: fabrics ?? this.fabrics,
      issues: issues ?? this.issues,
      receipts: receipts ?? this.receipts,
      truckInwards: truckInwards ?? this.truckInwards,
      rawArticles: rawArticles ?? this.rawArticles,
      activeTab: activeTab ?? this.activeTab,
      statusFilter: statusFilter ?? this.statusFilter,
      searchQuery: searchQuery ?? this.searchQuery,
      organizationName: organizationName ?? this.organizationName,
    );
  }
}

class StoreNotifier extends StateNotifier<StoreState> {
  StoreNotifier() : super(const StoreState()) {
    fetchStoreData();
  }

  void setActiveTab(String tab) {
    state = state.copyWith(activeTab: tab);
  }

  void setStatusFilter(String filter) {
    state = state.copyWith(statusFilter: filter);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  Future<void> fetchStoreData() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final currentUser = supabase.auth.currentUser;
      String orgName = 'DIV 11';
      String? targetComp;
      bool isPlatformSuper = false;

      if (currentUser != null) {
        try {
          final tenant = await TenantResolverService.resolveUserTenant(currentUser);
          if (tenant.companyName.isNotEmpty) {
            orgName = tenant.companyName;
            isPlatformSuper = tenant.isPlatformAdmin || tenant.role == 'PLATFORM_SUPERADMIN';
            if (!isPlatformSuper) {
              targetComp = tenant.companyName.trim();
            }
          }
        } catch (_) {}
      }

      // 1. Fetch Central Fabric Inventory (TENANT-SCOPED)
      List<CentralFabricInventoryModel> fabrics = [];
      try {
        var fabricQuery = supabase
            .from('central_fabric_inventory')
            .select('*');
        if (targetComp != null && targetComp.isNotEmpty) {
          fabricQuery = fabricQuery.ilike('company_name', targetComp);
        }
        final List<dynamic> rawFabrics = await fabricQuery
            .order('created_at', ascending: false);
        fabrics = rawFabrics.map((e) => CentralFabricInventoryModel.fromJson(e as Map<String, dynamic>)).toList();
      } catch (err) {
        debugPrint('Error fetching fabric inventory: $err');
      }

      // 2. Fetch Central Material Issues (TENANT-SCOPED)
      List<CentralMaterialIssueModel> issues = [];
      try {
        var issueQuery = supabase
            .from('central_material_issues')
            .select('*');
        if (targetComp != null && targetComp.isNotEmpty) {
          issueQuery = issueQuery.ilike('company_name', targetComp);
        }
        final List<dynamic> rawIssues = await issueQuery
            .order('created_at', ascending: false)
            .limit(100);
        issues = rawIssues.map((e) => CentralMaterialIssueModel.fromJson(e as Map<String, dynamic>)).toList();
      } catch (err) {
        debugPrint('Error fetching material issues: $err');
      }

      // 3. Fetch Central Material Receipts (TENANT-SCOPED)
      List<CentralMaterialReceiptModel> receipts = [];
      try {
        var receiptQuery = supabase
            .from('central_material_receipts')
            .select('*');
        if (targetComp != null && targetComp.isNotEmpty) {
          receiptQuery = receiptQuery.ilike('company_name', targetComp);
        }
        final List<dynamic> rawReceipts = await receiptQuery
            .order('created_at', ascending: false)
            .limit(60);
        receipts = rawReceipts.map((e) => CentralMaterialReceiptModel.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {
        try {
          var fallbackQuery = supabase
              .from('central_material_receipts')
              .select('*');
          if (targetComp != null && targetComp.isNotEmpty) {
            fallbackQuery = fallbackQuery.ilike('company_name', targetComp);
          }
          final List<dynamic> rawReceipts = await fallbackQuery
              .limit(60);
          receipts = rawReceipts.map((e) => CentralMaterialReceiptModel.fromJson(e as Map<String, dynamic>)).toList();
        } catch (err) {
          debugPrint('Error fetching material receipts: $err');
        }
      }

      // 4. Fetch Truck Inwards (TENANT-SCOPED — server-side filter)
      List<TruckInwardModel> truckInwards = [];
      try {
        var truckQuery = supabase
            .from('truck_inwards')
            .select('*');
        if (targetComp != null && targetComp.isNotEmpty) {
          truckQuery = truckQuery.or('company_name.ilike.%$targetComp%,party_name.ilike.%$targetComp%,notes.ilike.%$targetComp%');
        }
        final List<dynamic> rawTrucks = await truckQuery
            .order('inward_date', ascending: false)
            .limit(60);
        truckInwards = rawTrucks.map((e) => TruckInwardModel.fromJson(e as Map<String, dynamic>)).toList();
      } catch (err) {
        debugPrint('Error fetching truck inwards: $err');
      }

      // 5. Fetch Articles for selectors
      List<dynamic> articles = [];
      try {
        articles = await supabase.from('articles').select('id, art_no, description').order('art_no', ascending: true);
      } catch (_) {}

      state = state.copyWith(
        isLoading: false,
        fabrics: fabrics,
        issues: issues,
        receipts: receipts,
        truckInwards: truckInwards,
        rawArticles: articles,
        organizationName: orgName,
      );
    } catch (e) {
      debugPrint('Store fetch error: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> addFabricInventory({
    required String fabricType,
    required String color,
    String? supplierName,
    required double totalMeters,
    double totalWeightKg = 0.0,
    int totalRolls = 0,
    String rackLocation = 'BAY_1_RACK_01',
    String? notes,
  }) async {
    final company = state.organizationName;
    final rowData = {
      'company_name': company,
      'fabric_type': fabricType.trim(),
      'color': color.trim(),
      'supplier_name': supplierName?.trim() ?? '',
      'total_meters': totalMeters,
      'total_weight_kg': totalWeightKg,
      'total_rolls': totalRolls,
      'rack_location': rackLocation.trim(),
      'notes': notes?.trim(),
      'created_at': DateTime.now().toIso8601String(),
    };

    await supabase.from('central_fabric_inventory').insert(rowData);
    await fetchStoreData();
  }

  Future<void> bookFabricForArticle({
    required String inventoryId,
    required String articleNo,
    required double meters,
  }) async {
    final fabric = state.fabrics.firstWhere((f) => f.id == inventoryId);
    final newBooked = fabric.bookedMeters + meters;

    await supabase.from('central_fabric_inventory').update({
      'booked_for_article': articleNo.trim(),
      'booked_meters': newBooked,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', inventoryId);

    await fetchStoreData();
  }

  Future<void> createMaterialIssue({
    required String fromDivision,
    required String toDivision,
    String? articleNo,
    String? buyerName,
    String? fabricType,
    String? color,
    required double quantity,
    String unit = 'meters',
    int rollsCount = 0,
    String? notes,
  }) async {
    final challanNo = 'ISS-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final todayStr = DateTime.now().toIso8601String().split('T')[0];

    await supabase.from('central_material_issues').insert({
      'company_name': state.organizationName,
      'issue_challan_no': challanNo,
      'from_division': fromDivision.toUpperCase(),
      'to_division': toDivision.toUpperCase(),
      'article_no': articleNo?.trim(),
      'buyer_name': buyerName?.trim(),
      'fabric_type': fabricType?.trim(),
      'color': color?.trim(),
      'quantity': quantity,
      'unit': unit.toLowerCase(),
      'rolls_count': rollsCount,
      'issued_by': 'Central Store Godown',
      'status': 'ISSUED',
      'issue_date': todayStr,
      'notes': notes?.trim(),
      'created_at': DateTime.now().toIso8601String(),
    });

    await fetchStoreData();
  }
}

final storeProvider = StateNotifierProvider<StoreNotifier, StoreState>((ref) {
  return StoreNotifier();
});
