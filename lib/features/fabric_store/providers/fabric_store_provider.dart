import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/tenant_resolver_service.dart';
import '../../../main.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/fabric_store_models.dart';

class FabricStoreActionResult {
  final bool success;
  final String? error;
  final FabricAllocationItem? createdFabric;

  const FabricStoreActionResult({
    required this.success,
    this.error,
    this.createdFabric,
  });
}

class FabricStoreState {
  final bool isLoading;
  final bool isSubmitting;
  final String? error;
  final String companyName;
  final List<FabricAllocationItem> fabrics;
  final List<TrimAllocationItem> trims;
  final List<ActiveArticleOption> activeArticles;
  final String searchQuery;
  final String fabricFilter; // 'ALL' | 'ASSIGNED' | 'UNASSIGNED'
  final String trimCategoryFilter;

  const FabricStoreState({
    this.isLoading = false,
    this.isSubmitting = false,
    this.error,
    this.companyName = 'Apparel Factory',
    this.fabrics = const [],
    this.trims = const [],
    this.activeArticles = const [],
    this.searchQuery = '',
    this.fabricFilter = 'ALL',
    this.trimCategoryFilter = 'ALL',
  });

  double get totalClothMeters => fabrics.fold(0.0, (s, f) => s + f.totalMeters);
  int get totalClothRolls => fabrics.fold(0, (s, f) => s + f.totalRolls);
  double get totalClothAssignedMeters => fabrics.fold(0.0, (s, f) => s + f.bookedMeters);
  int get clothAllocationRate =>
      totalClothMeters > 0 ? ((totalClothAssignedMeters / totalClothMeters) * 100).round() : 0;

  int get totalTrimUnitsInStore => trims.fold(0, (s, t) => s + t.totalInStore);
  int get totalTrimAssignedUnits => trims.fold(0, (s, t) => s + t.assignedQuantity);
  int get trimAllocationRate =>
      totalTrimUnitsInStore > 0 ? ((totalTrimAssignedUnits / totalTrimUnitsInStore) * 100).round() : 0;

  List<String> get trimCategories {
    final cats = <String>{};
    for (final t in trims) {
      if (t.category.isNotEmpty) cats.add(t.category);
    }
    return ['ALL', ...cats];
  }

  List<FabricAllocationItem> get filteredFabrics {
    final q = searchQuery.toLowerCase().trim();
    var list = fabrics;

    if (q.isNotEmpty) {
      list = list.where((f) {
        return f.fabricType.toLowerCase().contains(q) ||
            f.color.toLowerCase().contains(q) ||
            f.supplierName.toLowerCase().contains(q) ||
            (f.bookedForArticle ?? '').toLowerCase().contains(q) ||
            (f.articlePo ?? '').toLowerCase().contains(q) ||
            (f.buyerName ?? '').toLowerCase().contains(q) ||
            f.rackLocation.toLowerCase().contains(q);
      }).toList();
    }

    if (fabricFilter == 'ASSIGNED') {
      list = list.where((f) => (f.bookedForArticle ?? '').isNotEmpty && f.bookedMeters > 0).toList();
    } else if (fabricFilter == 'UNASSIGNED') {
      list = list
          .where((f) => (f.bookedForArticle ?? '').isEmpty || f.bookedMeters == 0 || f.availableMeters > 0)
          .toList();
    }

    return list;
  }

  List<TrimAllocationItem> get filteredTrims {
    final q = searchQuery.toLowerCase().trim();
    var list = trims;

    if (q.isNotEmpty) {
      list = list.where((t) {
        return t.itemName.toLowerCase().contains(q) ||
            t.category.toLowerCase().contains(q) ||
            (t.assignedArticle ?? '').toLowerCase().contains(q) ||
            (t.partyOrSupplier ?? '').toLowerCase().contains(q) ||
            (t.notes ?? '').toLowerCase().contains(q);
      }).toList();
    }

    if (trimCategoryFilter != 'ALL') {
      final target = trimCategoryFilter.toLowerCase();
      list = list.where((t) => t.category.toLowerCase() == target).toList();
    }

    return list;
  }

  FabricStoreState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    String? error,
    bool clearError = false,
    String? companyName,
    List<FabricAllocationItem>? fabrics,
    List<TrimAllocationItem>? trims,
    List<ActiveArticleOption>? activeArticles,
    String? searchQuery,
    String? fabricFilter,
    String? trimCategoryFilter,
  }) {
    return FabricStoreState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
      companyName: companyName ?? this.companyName,
      fabrics: fabrics ?? this.fabrics,
      trims: trims ?? this.trims,
      activeArticles: activeArticles ?? this.activeArticles,
      searchQuery: searchQuery ?? this.searchQuery,
      fabricFilter: fabricFilter ?? this.fabricFilter,
      trimCategoryFilter: trimCategoryFilter ?? this.trimCategoryFilter,
    );
  }
}

class FabricStoreNotifier extends StateNotifier<FabricStoreState> {
  final Ref _ref;

  FabricStoreNotifier(this._ref) : super(const FabricStoreState()) {
    fetchHubData();
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setFabricFilter(String filter) {
    state = state.copyWith(fabricFilter: filter);
  }

  void setTrimCategoryFilter(String category) {
    state = state.copyWith(trimCategoryFilter: category);
  }

  Future<String> _resolveTargetCompany() async {
    final authState = _ref.read(authProvider);
    final currentUser = supabase.auth.currentUser;
    final resolvedTenant = authState.tenantProfile ??
        (currentUser != null
            ? await TenantResolverService.resolveUserTenant(currentUser)
            : null);
    return (resolvedTenant?.companyName ?? '').trim();
  }

  Future<void> fetchHubData() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final targetCompany = await _resolveTargetCompany();
      if (targetCompany.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          companyName: '',
          fabrics: const [],
          trims: const [],
          activeArticles: const [],
        );
        return;
      }

      final normCompany = targetCompany.toLowerCase();
      bool matchesCompany(Map<String, dynamic> row) {
        final comp = (row['company_name']?.toString() ?? '').toLowerCase().trim();
        return comp.isEmpty || comp == normCompany;
      }

      // 1. Central fabric inventory (strictly for this company)
      Future<List<Map<String, dynamic>>> fetchFabrics() async {
        try {
          final resp = await supabase
              .from('central_fabric_inventory')
              .select('*')
              .ilike('company_name', targetCompany)
              .order('created_at', ascending: false);
          return (resp as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .where(matchesCompany)
              .toList();
        } catch (err) {
          debugPrint('FabricStore fabric fetch error: $err');
          return const [];
        }
      }

      // 2. Merchandising orders (strictly for this company)
      Future<List<Map<String, dynamic>>> fetchOrders() async {
        try {
          final resp = await supabase
              .from('merchandising_orders')
              .select('id, order_number, buyer_name, total_quantity, tech_pack_id, brand_id, company_name, brands(brand_name)')
              .ilike('company_name', targetCompany)
              .order('created_at', ascending: false);
          return (resp as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .where(matchesCompany)
              .toList();
        } catch (_) {
          try {
            final resp = await supabase
                .from('merchandising_orders')
                .select('id, order_number, buyer_name, total_quantity, tech_pack_id, brand_id, company_name')
                .ilike('company_name', targetCompany)
                .order('created_at', ascending: false);
            return (resp as List)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .where(matchesCompany)
                .toList();
          } catch (err) {
            debugPrint('FabricStore orders fetch error: $err');
            return const [];
          }
        }
      }

      // 3. Design tech packs (strictly for this company)
      Future<List<Map<String, dynamic>>> fetchTechPacks() async {
        try {
          final resp = await supabase
              .from('design_tech_packs')
              .select('*')
              .ilike('company_name', targetCompany)
              .order('created_at', ascending: false);
          return (resp as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .where(matchesCompany)
              .toList();
        } catch (err) {
          debugPrint('FabricStore tech packs fetch error: $err');
          return const [];
        }
      }

      // 4. Truck inward items (matches Web limit(200) + inward join)
      Future<List<Map<String, dynamic>>> fetchTruckItems() async {
        try {
          final resp = await supabase
              .from('truck_inward_items')
              .select('*, inward:truck_inwards(article_no, party_name, notes)')
              .limit(200);
          return (resp as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        } catch (err) {
          debugPrint('FabricStore truck inward fetch error: $err');
          return const [];
        }
      }

      final results = await Future.wait([
        fetchFabrics(),
        fetchOrders(),
        fetchTechPacks(),
        fetchTruckItems(),
      ]);

      final rawFabrics = results[0];
      final rawOrders = results[1];
      final rawTechPacks = results[2];
      final rawTruckItems = results[3];

      // Build active articles selector list (matches Web)
      final articleSet = <String>{};
      final activeArticles = <ActiveArticleOption>[];

      for (final tp in rawTechPacks) {
        final styleNo = tp['style_number']?.toString().trim() ?? '';
        if (styleNo.isNotEmpty && !articleSet.contains(styleNo)) {
          articleSet.add(styleNo);
          final cat = tp['category']?.toString().trim();
          activeArticles.add(ActiveArticleOption(
            artNo: styleNo,
            label: '$styleNo (${(cat != null && cat.isNotEmpty) ? cat : 'Apparel'})',
          ));
        }
      }

      for (final f in rawFabrics) {
        final bookedArt = f['booked_for_article']?.toString().trim() ?? '';
        if (bookedArt.isNotEmpty && !articleSet.contains(bookedArt)) {
          articleSet.add(bookedArt);
          activeArticles.add(ActiveArticleOption(
            artNo: bookedArt,
            label: 'Article $bookedArt',
          ));
        }
      }

      // Section 1: Process cloth / fabric inventory & article allocations
      final fabrics = rawFabrics.map((row) {
        final totalM = (row['total_meters'] as num?)?.toDouble() ?? 0.0;
        final bookedM = (row['booked_meters'] as num?)?.toDouble() ?? 0.0;
        final freeM = (totalM - bookedM) > 0 ? (totalM - bookedM) : 0.0;
        final pct = totalM > 0 ? ((bookedM / totalM) * 100).round().clamp(0, 100) : 0;

        final matchedArticle = row['booked_for_article']?.toString().trim() ?? '';
        Map<String, dynamic>? matchingOrder;
        if (matchedArticle.isNotEmpty) {
          final mArtUpper = matchedArticle.toUpperCase();
          for (final o in rawOrders) {
            final ordNo = (o['order_number']?.toString() ?? '').toUpperCase();
            final tpMatch = rawTechPacks.any((tp) =>
                tp['id'] == o['tech_pack_id'] &&
                (tp['style_number']?.toString() ?? '').toUpperCase().contains(mArtUpper));
            if (ordNo.contains(mArtUpper) || tpMatch) {
              matchingOrder = o;
              break;
            }
          }
        }

        Map<String, dynamic>? matchingTechPack;
        if (matchedArticle.isNotEmpty) {
          final mArtUpper = matchedArticle.toUpperCase();
          for (final tp in rawTechPacks) {
            if ((tp['style_number']?.toString() ?? '').toUpperCase() == mArtUpper) {
              matchingTechPack = tp;
              break;
            }
          }
        }

        String? buyer;
        if (matchingOrder != null) {
          final directBuyer = matchingOrder['buyer_name']?.toString().trim();
          final brandMap = matchingOrder['brands'] is Map
              ? Map<String, dynamic>.from(matchingOrder['brands'] as Map)
              : null;
          final brandBuyer = brandMap?['brand_name']?.toString().trim();
          buyer = (directBuyer != null && directBuyer.isNotEmpty)
              ? directBuyer
              : (brandBuyer != null && brandBuyer.isNotEmpty ? brandBuyer : null);
        }

        final poNumber = matchingOrder?['order_number']?.toString();
        final resolvedBookedArt = (row['booked_for_article']?.toString().trim().isNotEmpty == true)
            ? row['booked_for_article'].toString().trim()
            : matchingTechPack?['style_number']?.toString();

        return FabricAllocationItem(
          id: row['id']?.toString() ?? '',
          fabricType: (row['fabric_type']?.toString().trim().isNotEmpty == true)
              ? row['fabric_type'].toString().trim()
              : 'Standard Fabric',
          color: (row['color']?.toString().trim().isNotEmpty == true)
              ? row['color'].toString().trim()
              : 'Standard',
          supplierName: (row['supplier_name']?.toString().trim().isNotEmpty == true)
              ? row['supplier_name'].toString().trim()
              : 'Mill Sourcing',
          totalMeters: totalM,
          totalRolls: (row['total_rolls'] as num?)?.toInt() ?? 0,
          totalWeightKg: (row['total_weight_kg'] as num?)?.toDouble() ?? 0.0,
          rackLocation: (row['rack_location']?.toString().trim().isNotEmpty == true)
              ? row['rack_location'].toString().trim()
              : 'STORE-GODOWN',
          bookedForArticle: resolvedBookedArt,
          bookedMeters: bookedM,
          availableMeters: freeM,
          allocationPercentage: pct,
          articlePo: poNumber,
          buyerName: buyer,
          notes: row['notes']?.toString(),
        );
      }).toList();

      // Section 2: Required trims & accessories (Tech Pack BOM + Truck Inward Items)
      final trimsMap = <String, TrimAllocationItem>{};

      for (final tp in rawTechPacks) {
        final parsed = parseBOMFromFabric(tp['fabric_composition']?.toString() ?? '');
        Map<String, dynamic>? matchingOrder;
        for (final o in rawOrders) {
          if (o['tech_pack_id'] == tp['id']) {
            matchingOrder = o;
            break;
          }
        }
        final rawQty = (matchingOrder?['total_quantity'] as num?)?.toInt();
        final orderQty = (rawQty != null && rawQty > 0) ? rawQty : 3000;
        final styleNo = tp['style_number']?.toString() ?? '';

        for (final mat in parsed.materials) {
          final consumption = double.tryParse(mat.consumption) ?? 1.0;
          final requiredUnits = (consumption * orderQty).round();
          final normItem = mat.item.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
          final key = 'tp-$styleNo-$normItem';

          final displayName = formatTrimDisplayName(mat.item, mat.component);
          final cat = categorizeTrim(mat.item, mat.component);
          final unit = cat == 'Sewing Threads'
              ? 'cones'
              : (cat == 'Tapes & Elastics' ? 'meters' : 'pcs');

          trimsMap[key] = TrimAllocationItem(
            id: key,
            itemName: displayName,
            category: cat,
            unit: unit,
            totalInStore: requiredUnits,
            assignedArticle: styleNo.isNotEmpty ? styleNo : null,
            assignedQuantity: requiredUnits,
            freeQuantity: 0,
            allocationPercentage: 100,
            partyOrSupplier: 'Central Store',
            notes: 'Required for Style $styleNo',
          );
        }
      }

      for (final it in rawTruckItems) {
        final inward = it['inward'] is Map
            ? Map<String, dynamic>.from(it['inward'] as Map)
            : const <String, dynamic>{};
        final artNo = inward['article_no']?.toString().trim() ?? '';
        final party = (inward['party_name']?.toString() ?? '').toLowerCase();
        final notes = (inward['notes']?.toString() ?? '').toLowerCase();

        final belongsToCompany = party.contains(normCompany) || notes.contains(normCompany);
        if (!belongsToCompany) continue;

        final rawItemName = (it['item_name']?.toString().trim().isNotEmpty == true)
            ? it['item_name'].toString().trim()
            : 'Trim Item';
        final normItem = rawItemName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
        final key = 'inw-${artNo.isNotEmpty ? artNo : 'gen'}-$normItem';

        if (!trimsMap.containsKey(key)) {
          final qty = (it['quantity'] as num?)?.round() ?? 0;
          final unit = (it['unit']?.toString().trim().isNotEmpty == true)
              ? it['unit'].toString().trim()
              : 'pcs';
          final cat = categorizeTrim(rawItemName);
          final hasArticle = artNo.isNotEmpty;

          trimsMap[key] = TrimAllocationItem(
            id: key,
            itemName: rawItemName,
            category: cat,
            unit: unit,
            totalInStore: qty,
            assignedArticle: hasArticle ? artNo : null,
            assignedQuantity: hasArticle ? qty : 0,
            freeQuantity: hasArticle ? 0 : qty,
            allocationPercentage: hasArticle ? 100 : 0,
            partyOrSupplier: inward['party_name']?.toString() ?? 'Store Inward',
            notes: inward['notes']?.toString() ??
                (hasArticle ? 'Inwarded for Article $artNo' : null),
          );
        }
      }

      state = state.copyWith(
        isLoading: false,
        companyName: targetCompany,
        fabrics: fabrics,
        trims: trimsMap.values.toList(),
        activeArticles: activeArticles,
      );
    } catch (err) {
      debugPrint('FabricStore fetchHubData error: $err');
      state = state.copyWith(
        isLoading: false,
        error: 'Unable to load Fabric & Store records',
      );
    }
  }

  Future<FabricStoreActionResult> updateFabricArticleAllocation({
    required String inventoryId,
    required String articleNo,
    required double bookedMeters,
  }) async {
    if (inventoryId.isEmpty) {
      return const FabricStoreActionResult(success: false, error: 'Invalid fabric inventory ID');
    }

    state = state.copyWith(isSubmitting: true);
    try {
      final current = await supabase
          .from('central_fabric_inventory')
          .select('total_meters')
          .eq('id', inventoryId)
          .single();

      final totalM = (current['total_meters'] as num?)?.toDouble() ?? 0.0;
      final requestedBooked = bookedMeters < 0 ? 0.0 : bookedMeters;

      if (requestedBooked > totalM) {
        state = state.copyWith(isSubmitting: false);
        return FabricStoreActionResult(
          success: false,
          error: 'Cannot allocate ${requestedBooked.toStringAsFixed(0)}m. Total cloth in store is ${totalM.toStringAsFixed(0)}m.',
        );
      }

      final cleanArticle = articleNo.trim().isEmpty ? null : articleNo.trim();

      await supabase.from('central_fabric_inventory').update({
        'booked_for_article': cleanArticle,
        'booked_meters': requestedBooked,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', inventoryId);

      final updatedList = state.fabrics.map((f) {
        if (f.id != inventoryId) return f;
        final free = (f.totalMeters - requestedBooked) > 0 ? (f.totalMeters - requestedBooked) : 0.0;
        final pct = f.totalMeters > 0
            ? ((requestedBooked / f.totalMeters) * 100).round().clamp(0, 100)
            : 0;
        return f.copyWith(
          bookedForArticle: cleanArticle,
          clearBookedArticle: cleanArticle == null,
          bookedMeters: requestedBooked,
          availableMeters: free,
          allocationPercentage: pct,
        );
      }).toList();

      state = state.copyWith(isSubmitting: false, fabrics: updatedList);
      return const FabricStoreActionResult(success: true);
    } catch (err) {
      state = state.copyWith(isSubmitting: false);
      return FabricStoreActionResult(
        success: false,
        error: 'Failed to update allocation: $err',
      );
    }
  }

  Future<FabricStoreActionResult> addFabricCloth({
    required String fabricType,
    required String color,
    String? supplierName,
    required double totalMeters,
    int totalRolls = 1,
    String rackLocation = 'RACK-01',
    String? bookedForArticle,
    double bookedMeters = 0,
    String? notes,
  }) async {
    var comp = state.companyName.trim();
    if (comp.isEmpty) {
      comp = await _resolveTargetCompany();
    }
    if (comp.isEmpty) {
      return const FabricStoreActionResult(
        success: false,
        error: 'Company tenant profile is required to register fabric inventory.',
      );
    }
    if (fabricType.trim().isEmpty || color.trim().isEmpty || totalMeters <= 0) {
      return const FabricStoreActionResult(
        success: false,
        error: 'Fabric type, color, and positive total meters are required.',
      );
    }

    state = state.copyWith(isSubmitting: true);
    try {
      final cleanBooked = bookedMeters.clamp(0.0, totalMeters).toDouble();
      final cleanArticle =
          (bookedForArticle != null && bookedForArticle.trim().isNotEmpty) ? bookedForArticle.trim() : null;
      final cleanRack = rackLocation.trim().isNotEmpty ? rackLocation.trim() : 'RACK-01';
      final cleanSupplier =
          (supplierName != null && supplierName.trim().isNotEmpty) ? supplierName.trim() : 'Mill Sourcing';
      final nowIso = DateTime.now().toIso8601String();

      final inserted = await supabase
          .from('central_fabric_inventory')
          .insert({
            'company_name': comp,
            'fabric_type': fabricType.trim(),
            'color': color.trim(),
            'supplier_name': cleanSupplier,
            'total_meters': totalMeters,
            'total_rolls': totalRolls > 0 ? totalRolls : 1,
            'total_weight_kg': 0,
            'rack_location': cleanRack,
            'booked_for_article': cleanArticle,
            'booked_meters': cleanBooked,
            'notes': (notes != null && notes.trim().isNotEmpty) ? notes.trim() : null,
            'created_at': nowIso,
            'updated_at': nowIso,
          })
          .select()
          .maybeSingle();

      final free = (totalMeters - cleanBooked) > 0 ? (totalMeters - cleanBooked) : 0.0;
      final pct = totalMeters > 0 ? ((cleanBooked / totalMeters) * 100).round().clamp(0, 100) : 0;

      final newItem = FabricAllocationItem(
        id: inserted?['id']?.toString() ?? 'new-${DateTime.now().millisecondsSinceEpoch}',
        fabricType: fabricType.trim(),
        color: color.trim(),
        supplierName: cleanSupplier,
        totalMeters: totalMeters,
        totalRolls: totalRolls > 0 ? totalRolls : 1,
        totalWeightKg: 0,
        rackLocation: cleanRack,
        bookedForArticle: cleanArticle,
        bookedMeters: cleanBooked,
        availableMeters: free,
        allocationPercentage: pct,
        notes: (notes != null && notes.trim().isNotEmpty) ? notes.trim() : null,
      );

      final updatedArticles = List<ActiveArticleOption>.from(state.activeArticles);
      if (cleanArticle != null && !updatedArticles.any((a) => a.artNo == cleanArticle)) {
        updatedArticles.add(ActiveArticleOption(artNo: cleanArticle, label: 'Article $cleanArticle'));
      }

      state = state.copyWith(
        isSubmitting: false,
        fabrics: [newItem, ...state.fabrics],
        activeArticles: updatedArticles,
      );

      return FabricStoreActionResult(success: true, createdFabric: newItem);
    } catch (err) {
      state = state.copyWith(isSubmitting: false);
      return FabricStoreActionResult(
        success: false,
        error: 'Failed to add cloth stock: $err',
      );
    }
  }
}

final fabricStoreProvider =
    StateNotifierProvider<FabricStoreNotifier, FabricStoreState>((ref) {
  return FabricStoreNotifier(ref);
});
