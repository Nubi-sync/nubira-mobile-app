import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/tenant_resolver_service.dart';
import '../../modules/services/supervisor_workers_service.dart';
import '../models/buyers_vendors_models.dart';

class ActionResult {
  final bool success;
  final String? error;
  final ModuleVendorItem? moduleItem;

  const ActionResult({
    required this.success,
    this.error,
    this.moduleItem,
  });
}

class BuyersVendorsState {
  final bool isLoading;
  final bool isSyncing;
  final bool isSubmitting;
  final String? error;
  final String companyName;
  final String userRole;
  final List<BuyerItem> buyers;
  final List<ModuleVendorItem> moduleVendors;
  final BuyersVendorsSummary summary;
  final String searchQuery;

  const BuyersVendorsState({
    this.isLoading = false,
    this.isSyncing = false,
    this.isSubmitting = false,
    this.error,
    this.companyName = 'Factory',
    this.userRole = 'SUPERADMIN',
    this.buyers = const [],
    this.moduleVendors = const [],
    this.summary = const BuyersVendorsSummary(),
    this.searchQuery = '',
  });

  BuyersVendorsState copyWith({
    bool? isLoading,
    bool? isSyncing,
    bool? isSubmitting,
    String? error,
    bool clearError = false,
    String? companyName,
    String? userRole,
    List<BuyerItem>? buyers,
    List<ModuleVendorItem>? moduleVendors,
    BuyersVendorsSummary? summary,
    String? searchQuery,
  }) {
    return BuyersVendorsState(
      isLoading: isLoading ?? this.isLoading,
      isSyncing: isSyncing ?? this.isSyncing,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
      companyName: companyName ?? this.companyName,
      userRole: userRole ?? this.userRole,
      buyers: buyers ?? this.buyers,
      moduleVendors: moduleVendors ?? this.moduleVendors,
      summary: summary ?? this.summary,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  List<BuyerItem> get filteredBuyers {
    final q = searchQuery.toLowerCase().trim();
    if (q.isEmpty) return buyers;

    return buyers.where((b) {
      if (b.brandName.toLowerCase().contains(q)) return true;
      if (b.contactPerson.toLowerCase().contains(q)) return true;
      if (b.phone.contains(q)) return true;
      if (b.city.toLowerCase().contains(q)) return true;
      if (b.gstin.toLowerCase().contains(q)) return true;
      return b.articles.any(
        (a) =>
            a.artNo.toLowerCase().contains(q) ||
            a.challanNo.toLowerCase().contains(q) ||
            a.description.toLowerCase().contains(q) ||
            a.colorPattern.toLowerCase().contains(q),
      );
    }).toList();
  }

  List<ModuleVendorItem> get filteredModules {
    final q = searchQuery.toLowerCase().trim();
    if (q.isEmpty) return moduleVendors;

    return moduleVendors.where((m) {
      if (m.moduleName.toLowerCase().contains(q)) return true;
      if (m.description.toLowerCase().contains(q)) return true;
      final v = m.assignedVendor;
      if (v != null) {
        if (v.companyName.toLowerCase().contains(q)) return true;
        if (v.contactPerson.toLowerCase().contains(q)) return true;
        if (v.phone.contains(q)) return true;
      }
      return false;
    }).toList();
  }

  int get totalBuyers => buyers.length;
  int get totalArticles => buyers.fold<int>(0, (sum, b) => sum + b.totalArticlesCount);
  int get totalAssignedPieces => buyers.fold<int>(0, (sum, b) => sum + b.totalAssignedPieces);
  int get totalDeliveredPieces => buyers.fold<int>(0, (sum, b) => sum + b.totalDeliveredPieces);
  int get assignedModulesCount => moduleVendors.where((m) => m.assignedVendor != null).length;
}

class BuyersVendorsNotifier extends StateNotifier<BuyersVendorsState> {
  BuyersVendorsNotifier() : super(const BuyersVendorsState()) {
    fetchHubData();
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  Future<({String companyName, String userRole, List<String> allowedDivisions, String filterCompany})>
      _resolveTenantContext() async {
    final client = Supabase.instance.client;
    final currentUser = client.auth.currentUser;

    String companyName = 'Factory';
    String userRole = 'SUPERADMIN';
    String filterCompany = '';
    List<String> allowedDivisions = [];

    if (currentUser != null) {
      try {
        final tenant = await TenantResolverService.resolveUserTenant(currentUser);
        companyName = tenant.companyName.trim().isNotEmpty ? tenant.companyName.trim() : 'Factory';
        userRole = tenant.role.toUpperCase();
        allowedDivisions = List<String>.from(tenant.allowedDivisions);

        if (!tenant.isPlatformAdmin && companyName != 'Zigza MES Platform Operations') {
          filterCompany = companyName;
        }
      } catch (_) {}
    }

    if (filterCompany.isNotEmpty) {
      try {
        final tenantFactory = await client
            .from('platform_tenant_factories')
            .select('allowed_divisions')
            .ilike('company_name', filterCompany)
            .maybeSingle();
        if (tenantFactory != null &&
            tenantFactory['allowed_divisions'] is List &&
            (tenantFactory['allowed_divisions'] as List).isNotEmpty) {
          allowedDivisions =
              (tenantFactory['allowed_divisions'] as List).map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }

    return (
      companyName: companyName,
      userRole: userRole,
      allowedDivisions: allowedDivisions,
      filterCompany: filterCompany,
    );
  }

  Future<void> fetchHubData({bool isBackgroundSync = false}) async {
    if (!isBackgroundSync) {
      state = state.copyWith(isLoading: true, clearError: true);
    } else {
      state = state.copyWith(isSyncing: true, clearError: true);
    }

    try {
      final client = Supabase.instance.client;
      final ctx = await _resolveTenantContext();
      final targetCompany = ctx.filterCompany;

      Future<List<dynamic>> safeBrands() async {
        try {
          var q = client.from('brands').select('*');
          if (targetCompany.isNotEmpty) {
            q = q.ilike('company_name', targetCompany);
          }
          return await q.order('brand_name', ascending: true);
        } catch (_) {
          return [];
        }
      }

      Future<List<dynamic>> safeMerchBuyers() async {
        try {
          var q = client.from('merchandising_active_buyers').select('*');
          if (targetCompany.isNotEmpty) {
            q = q.ilike('company_name', targetCompany);
          }
          return await q;
        } catch (_) {
          return [];
        }
      }

      Future<List<dynamic>> safeMerchOrders() async {
        try {
          var q = client.from('merchandising_orders').select('''
            *,
            brands ( id, brand_name, brand_code, company_name ),
            design_tech_packs ( id, style_number, category, embellishment_sequence, fabric_composition, target_gsm, cad_front_url, cad_back_url, company_name ),
            merchandising_order_ratios ( id, color_name, color_code, size_label, quantity )
          ''');
          if (targetCompany.isNotEmpty) {
            q = q.ilike('company_name', targetCompany);
          }
          return await q.order('created_at', ascending: false);
        } catch (_) {
          return [];
        }
      }

      Future<List<dynamic>> safeChallans() async {
        try {
          return await client.from('challans').select('*').order('created_at', ascending: false);
        } catch (_) {
          return [];
        }
      }

      Future<List<dynamic>> safeAllotments() async {
        try {
          return await client.from('allotments').select('''
            id,
            challan_id,
            target_qty,
            allotment_date,
            status,
            created_at,
            lineman_id,
            profiles:lineman_id ( id, username ),
            articles:article_id ( id, art_no, description, size_rates, stitching_rate )
          ''').order('created_at', ascending: false);
        } catch (_) {
          try {
            return await client.from('allotments').select('*').order('created_at', ascending: false);
          } catch (_) {
            return [];
          }
        }
      }

      Future<List<dynamic>> safeVariants() async {
        try {
          return await client.from('allotment_variants').select('*');
        } catch (_) {
          return [];
        }
      }

      Future<List<dynamic>> safeVendors() async {
        try {
          var q = client.from('vendors').select('*');
          if (targetCompany.isNotEmpty) {
            final safeComp = targetCompany.replaceAll(',', '');
            q = q.or('tenant_company.ilike.$safeComp,brand_name.ilike.$safeComp');
          }
          return await q;
        } catch (_) {
          return [];
        }
      }

      Future<List<dynamic>> safeModuleVendors() async {
        try {
          var q = client.from('module_vendors').select('*');
          if (targetCompany.isNotEmpty) {
            q = q.ilike('tenant_company', targetCompany);
          }
          return await q;
        } catch (_) {
          return [];
        }
      }

      final results = await Future.wait<List<dynamic>>([
        safeBrands(),
        safeMerchBuyers(),
        safeMerchOrders(),
        safeChallans(),
        safeAllotments(),
        safeVariants(),
        safeVendors(),
        safeModuleVendors(),
      ]);

      final rawBrands = results[0].whereType<Map<String, dynamic>>().toList();
      final rawMerchBuyers = results[1].whereType<Map<String, dynamic>>().toList();
      final rawMerchOrders = results[2].whereType<Map<String, dynamic>>().toList();
      final rawChallans = results[3].whereType<Map<String, dynamic>>().toList();
      final rawAllotments = results[4].whereType<Map<String, dynamic>>().toList();
      final rawVariants = results[5].whereType<Map<String, dynamic>>().toList();
      final rawVendors = results[6].whereType<Map<String, dynamic>>().toList();
      final rawModuleVendors = results[7].whereType<Map<String, dynamic>>().toList();

      final buyerArticlesMap = <String, List<BuyerArticleHistory>>{};

      // A. Ingest Merchandising Orders as Contracted Articles
      for (final mOrder in rawMerchOrders) {
        final brandObj = mOrder['brands'] is Map ? mOrder['brands'] as Map<String, dynamic> : null;
        final tpObj =
            mOrder['design_tech_packs'] is Map ? mOrder['design_tech_packs'] as Map<String, dynamic> : null;
        final ratios = (mOrder['merchandising_order_ratios'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .toList() ??
            const [];

        final rawBuyerName =
            (brandObj?['brand_name'] ?? mOrder['brand_name'] ?? 'Direct Buyer').toString().trim();
        final buyerKey = rawBuyerName.toUpperCase();
        final styleRef = (tpObj?['style_number'] ?? mOrder['style_ref'] ?? 'STYLE-PO').toString();
        final category = (tpObj?['category'] ?? 'Garment Collection').toString();
        final totalQty = (mOrder['total_quantity'] as num?)?.toInt() ?? 0;

        final colorMap = <String, ({Map<String, int> sizes, int total})>{};
        final colorSet = <String>{};
        final sizeSet = <String>{};

        for (final r in ratios) {
          final cName = (r['color_name'] ?? 'Standard').toString();
          final sLabel = (r['size_label'] ?? 'Free').toString();
          final qty = (r['quantity'] as num?)?.toInt() ?? 0;

          if ((r['color_name']?.toString().trim() ?? '').isNotEmpty) {
            colorSet.add(r['color_name'].toString().trim());
          }
          if ((r['size_label']?.toString().trim() ?? '').isNotEmpty) {
            sizeSet.add(r['size_label'].toString().trim());
          }

          final prev = colorMap[cName] ?? (sizes: <String, int>{}, total: 0);
          prev.sizes[sLabel] = (prev.sizes[sLabel] ?? 0) + qty;
          colorMap[cName] = (sizes: prev.sizes, total: prev.total + qty);
        }

        final colorMatrix = colorMap.entries
            .map((e) => ColorMatrixRow(color: e.key, sizes: e.value.sizes, total: e.value.total))
            .toList();

        final uniqueColors = colorSet.isNotEmpty ? colorSet.join(', ') : 'Standard';
        final uniqueSizes = sizeSet.isNotEmpty ? sizeSet.join('/') : 'Free Size';

        final orderStatus = (mOrder['status']?.toString() ?? '').toUpperCase();
        String status = 'IN_PRODUCTION';
        int deliveredQty = 0;
        if (orderStatus == 'SHIPPED' || orderStatus == 'COMPLETED' || orderStatus == 'DISPATCHED') {
          status = 'DELIVERED';
          deliveredQty = totalQty;
        } else if (orderStatus == 'PENDING_COSTING' || orderStatus == 'DRAFT') {
          status = 'PENDING';
          deliveredQty = 0;
        }

        final inCutting = (totalQty * 0.17).round();
        final inPrinting = (totalQty * 0.25).round();
        final inEmbroidery = (totalQty * 0.22).round();
        final inPending = max(0, totalQty - (inCutting + inPrinting + inEmbroidery));

        final unitFobPrice = (mOrder['fob_price_per_piece'] as num?)?.toDouble() ?? 450.0;
        final totalVal = (mOrder['total_contract_value'] as num?)?.toDouble() ?? (totalQty * unitFobPrice);

        final rawFabricStr =
            (tpObj?['fabric_composition'] ?? mOrder['fabric_composition'] ?? '').toString();
        final parsedFabric = parseFabricAndBom(rawFabricStr);
        final targetGsm = (tpObj?['target_gsm'] as num?)?.toInt() ?? 180;
        final embSeq = (tpObj?['embellishment_sequence'] ?? 'Only Embroidery').toString();

        final orderId = mOrder['id']?.toString() ?? '';
        final shortId = orderId.length >= 6 ? orderId.substring(0, 6).toUpperCase() : orderId.toUpperCase();
        final poNo = (mOrder['order_number']?.toString() ?? '').trim().isNotEmpty
            ? mOrder['order_number'].toString().trim()
            : 'PO-$shortId';
        final createdIso = mOrder['created_at']?.toString() ?? DateTime.now().toIso8601String();
        final contractDate = createdIso.split('T').first;

        final techPack = TechPackSpec(
          styleNumber: styleRef,
          category: category,
          cadFrontUrl: tpObj?['cad_front_url']?.toString() ?? '',
          cadBackUrl: tpObj?['cad_back_url']?.toString() ?? '',
          fabricComposition: parsedFabric.cleanFabric,
          targetGsm: targetGsm,
          embellishmentSequence: embSeq,
          bomMaterials: parsedFabric.materials,
          constructionNotes: 'Single Needle Lockstitch seams with 4-thread overlock safety.',
        );

        final contract = BuyerContractSpec(
          poNumber: poNo,
          buyerName: rawBuyerName.isNotEmpty ? rawBuyerName : buyerKey,
          fobPrice: unitFobPrice,
          currency: (mOrder['currency'] ?? 'INR').toString(),
          totalContractValue: totalVal,
          season: (mOrder['season'] ?? 'Autumn / Winter').toString(),
          orderDate: contractDate,
          deliveryDate: (mOrder['ex_factory_date'] ?? '').toString(),
          commercialStatus: (mOrder['status'] ?? 'CONFIRMED').toString(),
          colorMatrix: colorMatrix.isNotEmpty
              ? colorMatrix
              : [
                  ColorMatrixRow(
                    color: 'Standard Colorway',
                    sizes: const {'XS': 500, 'S': 1000, 'M': 1000, 'L': 500},
                    total: totalQty,
                  ),
                ],
        );

        final floorReview = LiveFloorReviewSpec(
          inPending: inPending,
          inCutting: inCutting,
          inPrinting: inPrinting,
          inEmbroidery: inEmbroidery,
        );

        final article = BuyerArticleHistory(
          id: 'merch-$orderId',
          challanId: orderId,
          challanNo: poNo,
          contractDate: contractDate,
          deliveryDate: (mOrder['ex_factory_date'] ?? '').toString(),
          fabricType: parsedFabric.cleanFabric,
          sampleGiven: true,
          challanNotes: 'Season: ${mOrder['season'] ?? 'Current'} • FOB: ₹${unitFobPrice.toStringAsFixed(0)}/pc',
          artNo: styleRef,
          patternNo: tpObj?['embellishment_sequence']?.toString() ?? '',
          category: category,
          product: category,
          description: '$category (PO #$poNo)',
          colorPattern: uniqueColors,
          sizeRange: uniqueSizes,
          assignedQty: totalQty,
          deliveredQty: deliveredQty,
          sets: 1,
          pcsPerSet: totalQty,
          stitchingRate: unitFobPrice,
          assignedLinemanName: 'Merchandising & Assembly Desk',
          status: status,
          sourceType: 'MERCHANDISING_PO',
          pictureUrl: tpObj?['cad_front_url']?.toString() ?? '',
          createdAt: createdIso,
          techPack: techPack,
          contract: contract,
          floorReview: floorReview,
        );

        buyerArticlesMap.putIfAbsent(buyerKey, () => []).add(article);
      }

      // Company brand filter set
      final companyBrandNames = <String>{
        ...rawBrands.map((b) => (b['brand_name'] ?? '').toString().trim().toUpperCase()),
        ...rawMerchBuyers.map((b) => (b['buyer_name'] ?? b['brand_name'] ?? '').toString().trim().toUpperCase()),
        ...rawMerchOrders.map((o) {
          final br = o['brands'] is Map ? (o['brands'] as Map)['brand_name'] : null;
          return (br ?? o['brand_name'] ?? '').toString().trim().toUpperCase();
        }),
      }..removeWhere((s) => s.isEmpty);

      // B. Ingest Floor Production Allotments & Challans for this company's brands
      final challanById = <String, Map<String, dynamic>>{};
      for (final ch in rawChallans) {
        final id = ch['id']?.toString();
        if (id != null && id.isNotEmpty) challanById[id] = ch;
      }

      for (final al in rawAllotments) {
        final challanId = al['challan_id']?.toString() ?? '';
        final matchingChallan = challanById[challanId];
        final buyerKey = (matchingChallan?['brand'] ?? '').toString().trim().toUpperCase();
        if (buyerKey.isEmpty) continue;
        if (!companyBrandNames.contains(buyerKey) && !buyerArticlesMap.containsKey(buyerKey)) continue;

        final alId = al['id']?.toString() ?? '';
        final alVars = rawVariants.where((v) => v['allotment_id']?.toString() == alId).toList();
        final rawArt = al['articles'];
        final Map<String, dynamic> artObj = rawArt is List
            ? (rawArt.isNotEmpty && rawArt.first is Map ? rawArt.first as Map<String, dynamic> : {})
            : (rawArt is Map ? rawArt as Map<String, dynamic> : {});
        final sizeRates = artObj['size_rates'] is Map ? artObj['size_rates'] as Map : null;
        final artMeta = sizeRates?['_meta'] is Map ? sizeRates!['_meta'] as Map : const {};

        final firstVar = alVars.isNotEmpty ? alVars.first : null;
        final colorPattern = (firstVar?['color'] ?? 'Standard Color').toString();
        final sizeRange = (firstVar?['size'] ?? 'Standard Size').toString();
        final varSum = alVars.fold<int>(0, (s, v) => s + ((v['quantity'] as num?)?.toInt() ?? 0));
        final totalPcs = ((al['target_qty'] as num?)?.toInt() ?? 0) > 0
            ? (al['target_qty'] as num).toInt()
            : varSum;

        int completedQty = 0;
        String status = 'PENDING';
        final alStatus = (al['status']?.toString() ?? '').toUpperCase();
        if (alStatus == 'DISPATCHED' || alStatus == 'DELIVERED') {
          status = 'DELIVERED';
          completedQty = totalPcs;
        } else if (alStatus == 'QC_PASSED') {
          status = 'QC_PASSED';
        } else if ((al['lineman_id']?.toString() ?? '').isNotEmpty) {
          status = 'IN_PRODUCTION';
        }

        final shortAl4 = alId.length >= 4 ? alId.substring(0, 4).toUpperCase() : alId.toUpperCase();
        final shortAl6 = alId.length >= 6 ? alId.substring(0, 6).toUpperCase() : alId.toUpperCase();
        final artNo = (artObj['art_no']?.toString() ?? '').trim().isNotEmpty
            ? artObj['art_no'].toString().trim()
            : 'ART-$shortAl4';
        final parsedFabric =
            parseFabricAndBom((matchingChallan?['fabric_type'] ?? 'Cotton / Lycra Blend').toString());
        final challanNo = (matchingChallan?['challan_no']?.toString() ?? '').trim().isNotEmpty
            ? matchingChallan!['challan_no'].toString().trim()
            : 'CH-$shortAl6';
        final createdIso = al['created_at']?.toString() ?? DateTime.now().toIso8601String();
        final contractDate = (matchingChallan?['challan_date'] ??
                al['allotment_date'] ??
                createdIso.split('T').first)
            .toString();
        final deliveryDate = (matchingChallan?['delivery_date'] ?? '').toString();
        final stitchRate = (artObj['stitching_rate'] as num?)?.toDouble();

        final profRaw = al['profiles'];
        final Map<String, dynamic>? profMap = profRaw is List
            ? (profRaw.isNotEmpty && profRaw.first is Map ? profRaw.first as Map<String, dynamic> : null)
            : (profRaw is Map ? profRaw as Map<String, dynamic> : null);
        final linemanName = (profMap?['full_name'] ?? profMap?['username'] ?? 'Floor Line').toString();

        final techPack = TechPackSpec(
          styleNumber: artNo,
          category: (artObj['description'] ?? 'Floor Article').toString(),
          fabricComposition: parsedFabric.cleanFabric,
          targetGsm: 240,
          embellishmentSequence: 'Cutting → Stitching Assembly → Iron Pressing',
          bomMaterials: parsedFabric.materials,
          constructionNotes: 'Factory floor production order.',
        );

        final effectiveRate = stitchRate ?? 25.0;
        final contract = BuyerContractSpec(
          poNumber: challanNo,
          buyerName: buyerKey,
          fobPrice: effectiveRate,
          currency: 'INR',
          totalContractValue: totalPcs * effectiveRate,
          season: 'General Production',
          orderDate: contractDate,
          deliveryDate: deliveryDate,
          commercialStatus: status,
          colorMatrix: [
            ColorMatrixRow(color: colorPattern, sizes: {sizeRange: totalPcs}, total: totalPcs),
          ],
        );

        final floorReview = LiveFloorReviewSpec(
          inPending: status == 'PENDING' ? totalPcs : 0,
          inSewing: status == 'IN_PRODUCTION' ? totalPcs : 0,
        );

        final item = BuyerArticleHistory(
          id: alId,
          challanId: challanId,
          challanNo: challanNo,
          contractDate: contractDate,
          deliveryDate: deliveryDate,
          fabricType: parsedFabric.cleanFabric,
          sampleGiven: matchingChallan?['sample_given'] == true,
          challanNotes: (matchingChallan?['notes'] ?? '').toString(),
          artNo: artNo,
          patternNo: (artMeta['pattern'] ?? '').toString(),
          category: 'Apparel Production',
          product: (artObj['description'] ?? 'Garment Article').toString(),
          description: (artObj['description'] ?? 'Factory Article').toString(),
          colorPattern: colorPattern,
          sizeRange: sizeRange,
          assignedQty: totalPcs,
          deliveredQty: completedQty,
          sets: 1,
          pcsPerSet: totalPcs,
          stitchingRate: stitchRate,
          assignedLinemanName: linemanName,
          status: status,
          sourceType: 'PRODUCTION_CHALLAN',
          createdAt: createdIso,
          techPack: techPack,
          contract: contract,
          floorReview: floorReview,
        );

        buyerArticlesMap.putIfAbsent(buyerKey, () => []).add(item);
      }

      // 2. Build Strictly Isolated Buyers List
      final List<BuyerItem> buyers = [];
      final brandByUpper = <String, Map<String, dynamic>>{};
      for (final br in rawBrands) {
        final key = (br['brand_name'] ?? '').toString().trim().toUpperCase();
        if (key.isNotEmpty) brandByUpper[key] = br;
      }

      for (final mb in rawMerchBuyers) {
        final bName = (mb['buyer_name'] ?? mb['brand_name'] ?? '').toString().trim();
        if (bName.isEmpty) continue;
        final bKey = bName.toUpperCase();
        final matchingBrand = brandByUpper[bKey];

        final buyerArticles = buyerArticlesMap[bKey] ?? const <BuyerArticleHistory>[];
        final uniqueContracts = buyerArticles.map((a) => a.challanId).where((c) => c.isNotEmpty).toSet();
        final artSum = buyerArticles.fold<int>(0, (s, a) => s + a.assignedQty);
        final totalAssignedPieces =
            artSum > 0 ? artSum : ((mb['contracted_volume'] as num?)?.toInt() ?? 0);
        final totalDeliveredPieces = buyerArticles.fold<int>(0, (s, a) => s + a.deliveredQty);
        final deliveryPercentage = totalAssignedPieces > 0
            ? ((totalDeliveredPieces / totalAssignedPieces) * 100).round()
            : 0;

        String cleanField(dynamic primary, dynamic secondary, bool Function(String) reject) {
          final v = (primary ?? secondary ?? '').toString().trim();
          if (v.isEmpty || reject(v)) return '';
          return v;
        }

        final cleanPerson = cleanField(
            mb['contact_person'], matchingBrand?['contact_person'], (v) => v == 'Procurement Lead');
        final cleanPhone = cleanField(
            matchingBrand?['phone'], mb['contact_phone'], (v) => v == '9876543210');
        final cleanEmail = cleanField(
            mb['contact_email'], matchingBrand?['email'], (v) => v.startsWith('buyer@'));
        final cleanCity = cleanField(
            matchingBrand?['city'], mb['city'], (v) => v == 'Kolkata, WB');

        buyers.add(
          BuyerItem(
            id: matchingBrand?['id']?.toString() ??
                mb['id']?.toString() ??
                'merch-buyer-${bKey.replaceAll(RegExp(r'[^A-Z0-9]'), '_')}',
            brandCode: getBuyerAvatarInitials(bName),
            brandName: bName,
            contactPerson: cleanPerson,
            phone: cleanPhone,
            email: cleanEmail,
            city: cleanCity,
            address: (matchingBrand?['address'] ?? '').toString().trim(),
            gstin: (matchingBrand?['gstin'] ?? '').toString().trim(),
            companyName: (mb['company_name'] ?? ctx.companyName).toString(),
            isActive: true,
            createdAt: (mb['created_at'] ?? '').toString(),
            totalContractsCount:
                uniqueContracts.isNotEmpty ? uniqueContracts.length : (buyerArticles.isNotEmpty ? 1 : 0),
            totalArticlesCount: buyerArticles.length,
            totalAssignedPieces: totalAssignedPieces,
            totalDeliveredPieces: totalDeliveredPieces,
            deliveryPercentage: deliveryPercentage,
            articles: buyerArticles,
          ),
        );
      }

      for (final entry in buyerArticlesMap.entries) {
        final buyerKey = entry.key;
        final articles = entry.value;
        if (buyers.any((b) => b.brandName.toUpperCase() == buyerKey)) continue;

        final matchingBrand = brandByUpper[buyerKey];
        final rawBrandName = (matchingBrand?['brand_name']?.toString().trim().isNotEmpty == true)
            ? matchingBrand!['brand_name'].toString().trim()
            : (buyerKey.length > 1
                ? '${buyerKey[0]}${buyerKey.substring(1).toLowerCase()}'
                : buyerKey);

        final totalAssignedPieces = articles.fold<int>(0, (s, a) => s + a.assignedQty);
        final totalDeliveredPieces = articles.fold<int>(0, (s, a) => s + a.deliveredQty);
        final deliveryPercentage = totalAssignedPieces > 0
            ? ((totalDeliveredPieces / totalAssignedPieces) * 100).round()
            : 0;
        final uniqueContracts = articles.map((a) => a.challanId).where((c) => c.isNotEmpty).toSet();

        final rawPerson = (matchingBrand?['contact_person'] ?? '').toString().trim();
        final rawPhone = (matchingBrand?['phone'] ?? '').toString().trim();
        final rawEmail = (matchingBrand?['email'] ?? '').toString().trim();
        final rawCity = (matchingBrand?['city'] ?? '').toString().trim();

        buyers.add(
          BuyerItem(
            id: matchingBrand?['id']?.toString() ??
                'buyer-${buyerKey.replaceAll(RegExp(r'[^A-Z0-9]'), '_')}',
            brandCode: getBuyerAvatarInitials(rawBrandName),
            brandName: rawBrandName,
            contactPerson: rawPerson == 'Procurement Lead' ? '' : rawPerson,
            phone: rawPhone == '9876543210' ? '' : rawPhone,
            email: rawEmail.startsWith('buyer@') ? '' : rawEmail,
            city: rawCity == 'Kolkata, WB' ? '' : rawCity,
            address: (matchingBrand?['address'] ?? '').toString().trim(),
            gstin: (matchingBrand?['gstin'] ?? '').toString().trim(),
            companyName: ctx.companyName,
            isActive: true,
            createdAt: (matchingBrand?['created_at'] ?? '').toString(),
            totalContractsCount:
                uniqueContracts.isNotEmpty ? uniqueContracts.length : (articles.isNotEmpty ? 1 : 0),
            totalArticlesCount: articles.length,
            totalAssignedPieces: totalAssignedPieces,
            totalDeliveredPieces: totalDeliveredPieces,
            deliveryPercentage: deliveryPercentage,
            articles: articles,
          ),
        );
      }

      // Also include any explicitly registered company brands not yet in merchBuyers/orders
      for (final br in rawBrands) {
        final bName = (br['brand_name'] ?? '').toString().trim();
        if (bName.isEmpty) continue;
        final bKey = bName.toUpperCase();
        if (buyers.any((b) => b.brandName.toUpperCase() == bKey)) continue;

        final rawPerson = (br['contact_person'] ?? '').toString().trim();
        final rawPhone = (br['phone'] ?? '').toString().trim();
        final rawEmail = (br['email'] ?? '').toString().trim();
        final rawCity = (br['city'] ?? '').toString().trim();

        buyers.add(
          BuyerItem(
            id: br['id']?.toString() ?? 'brand-$bKey',
            brandCode: getBuyerAvatarInitials(bName),
            brandName: bName,
            contactPerson: rawPerson == 'Procurement Lead' ? '' : rawPerson,
            phone: rawPhone == '9876543210' ? '' : rawPhone,
            email: rawEmail.startsWith('buyer@') ? '' : rawEmail,
            city: rawCity == 'Kolkata, WB' ? '' : rawCity,
            address: (br['address'] ?? '').toString().trim(),
            gstin: (br['gstin'] ?? '').toString().trim(),
            companyName: (br['company_name'] ?? ctx.companyName).toString(),
            isActive: br['is_active'] != false,
            createdAt: (br['created_at'] ?? '').toString(),
            totalContractsCount: 0,
            totalArticlesCount: 0,
            totalAssignedPieces: 0,
            totalDeliveredPieces: 0,
            deliveryPercentage: 0,
            articles: const [],
          ),
        );
      }

      // 3. Build Subscribed Modules & Custom Factory Modules Vendor Roster
      final effectiveAllowed = ctx.allowedDivisions;
      bool isRouteAllowed(String route) {
        if (effectiveAllowed.isEmpty) return true;
        if (effectiveAllowed.contains('/platform-admin') || effectiveAllowed.contains('*')) return true;
        if (effectiveAllowed.contains(route)) return true;
        if ((route == '/store' || route == '/fabric-store') &&
            (effectiveAllowed.contains('/store') || effectiveAllowed.contains('/fabric-store'))) {
          return true;
        }
        if ((route == '/stitching-sewing' || route == '/stitching') &&
            (effectiveAllowed.contains('/stitching-sewing') ||
                effectiveAllowed.contains('/stitching'))) {
          return true;
        }
        return false;
      }

      final subscribedCatalog = kAllDefaultDivisions.where((cat) => isRouteAllowed(cat.route)).toList();

      final List<Map<String, dynamic>> customModuleRows = [];
      final List<Map<String, dynamic>> standardModuleRows = [];

      for (final mv in rawModuleVendors) {
        final route = (mv['module_route'] ?? '').toString();
        bool isCustom = mv['is_custom'] == true || route.startsWith('/custom');
        if (!isCustom) {
          final notesStr = (mv['notes'] ?? '').toString().trim();
          if (notesStr.startsWith('{')) {
            try {
              final decoded = jsonDecode(notesStr);
              if (decoded is Map && decoded['isCustom'] == true) {
                isCustom = true;
              }
            } catch (_) {}
          }
        }
        if (isCustom) {
          customModuleRows.add(mv);
        } else {
          standardModuleRows.add(mv);
        }
      }

      final List<ModuleVendorItem> catalogModuleVendors = subscribedCatalog.map((cat) {
        final dbModVendor = standardModuleRows.cast<Map<String, dynamic>?>().firstWhere(
              (mv) =>
                  mv!['module_route']?.toString() == cat.route ||
                  (mv['module_name']?.toString().toLowerCase() ?? '') == cat.name.toLowerCase(),
              orElse: () => null,
            );

        final fallbackVendor = rawVendors.cast<Map<String, dynamic>?>().firstWhere(
              (v) {
                if (v!['module_route']?.toString() == cat.route) return true;
                final vType = (v['vendor_type'] ?? '').toString().toLowerCase();
                if (vType.length >= 4 && cat.route.contains(vType.substring(0, 4))) return true;
                return false;
              },
              orElse: () => null,
            );

        AssignedVendorInfo? assignedVendor;
        final dbComp = (dbModVendor?['company_name'] ?? '').toString().trim();
        if (dbModVendor != null &&
            dbComp.isNotEmpty &&
            dbComp != 'Unassigned' &&
            dbComp != 'Not Assigned') {
          assignedVendor = AssignedVendorInfo(
            id: dbModVendor['id']?.toString() ?? '',
            companyName: dbComp,
            contactPerson: (dbModVendor['contact_person'] ?? '').toString(),
            phone: (dbModVendor['phone'] ?? '').toString(),
            notes: (dbModVendor['notes'] ?? '').toString(),
            isActive: dbModVendor['is_active'] ?? true,
            createdAt: dbModVendor['created_at']?.toString(),
          );
        } else if (fallbackVendor != null &&
            (fallbackVendor['vendor_name'] ?? '').toString().trim().isNotEmpty) {
          assignedVendor = AssignedVendorInfo(
            id: fallbackVendor['id']?.toString() ?? '',
            companyName: fallbackVendor['vendor_name'].toString().trim(),
            contactPerson: (fallbackVendor['contact_person'] ?? '').toString(),
            phone: (fallbackVendor['phone'] ?? '').toString(),
            notes: (fallbackVendor['address'] ?? '').toString(),
            isActive: fallbackVendor['is_active'] ?? true,
            createdAt: fallbackVendor['created_at']?.toString(),
          );
        }

        return ModuleVendorItem(
          id: cat.id,
          moduleRoute: cat.route,
          moduleCode: cat.code,
          moduleName: cat.name,
          defaultDesignation: cat.defaultDesignation,
          iconName: cat.iconName,
          description: cat.description,
          isCustom: false,
          assignedVendor: assignedVendor,
        );
      }).toList();

      final List<ModuleVendorItem> customModuleVendors = customModuleRows.map((mv) {
        Map<String, dynamic> meta = {};
        final notesStr = (mv['notes'] ?? '').toString().trim();
        if (notesStr.startsWith('{') || notesStr.startsWith('[')) {
          try {
            final decoded = jsonDecode(notesStr);
            if (decoded is Map<String, dynamic>) meta = decoded;
          } catch (_) {}
        }

        final mvComp = (mv['company_name'] ?? '').toString().trim();
        final hasRealVendor =
            mvComp.isNotEmpty && mvComp != 'Unassigned' && mvComp != 'Not Assigned';

        AssignedVendorInfo? assignedVendor;
        if (hasRealVendor) {
          final vendorNotes = (meta['vendorNotes']?.toString().isNotEmpty == true)
              ? meta['vendorNotes'].toString()
              : (!notesStr.startsWith('{') ? notesStr : '');
          assignedVendor = AssignedVendorInfo(
            id: mv['id']?.toString() ?? '',
            companyName: mvComp,
            contactPerson: (mv['contact_person'] ?? '').toString(),
            phone: (mv['phone'] ?? '').toString(),
            notes: vendorNotes,
            isActive: mv['is_active'] ?? true,
            createdAt: mv['created_at']?.toString(),
          );
        }

        return ModuleVendorItem(
          id: mv['id']?.toString() ?? '',
          moduleRoute: (mv['module_route'] ?? '').toString(),
          moduleCode: (mv['module_code'] ?? meta['moduleCode'] ?? 'CUST').toString(),
          moduleName: (mv['module_name'] ?? 'Custom Module').toString(),
          defaultDesignation:
              (meta['defaultDesignation'] ?? 'Station Head / Unit In-Charge').toString(),
          iconName: (mv['icon_name'] ?? meta['iconName'] ?? 'Layers').toString(),
          description: (meta['description'] ??
                  (!notesStr.startsWith('{') && notesStr.isNotEmpty
                      ? notesStr
                      : 'Custom factory floor module'))
              .toString(),
          isCustom: true,
          assignedVendor: assignedVendor,
        );
      }).toList();

      final moduleVendors = [...catalogModuleVendors, ...customModuleVendors];

      final totalContracts = buyers.fold<int>(0, (s, b) => s + b.totalContractsCount);
      final totalArticlesContracted = buyers.fold<int>(0, (s, b) => s + b.totalArticlesCount);
      final totalAssignedPieces = buyers.fold<int>(0, (s, b) => s + b.totalAssignedPieces);
      final totalDeliveredPieces = buyers.fold<int>(0, (s, b) => s + b.totalDeliveredPieces);
      final overallPct = totalAssignedPieces > 0
          ? ((totalDeliveredPieces / totalAssignedPieces) * 100).round()
          : 0;
      final assignedModsCount = moduleVendors.where((m) => m.assignedVendor != null).length;

      state = state.copyWith(
        isLoading: false,
        isSyncing: false,
        companyName: ctx.companyName,
        userRole: ctx.userRole,
        buyers: buyers,
        moduleVendors: moduleVendors,
        summary: BuyersVendorsSummary(
          totalBuyers: buyers.length,
          activeBuyers: buyers.where((b) => b.isActive).length,
          totalContracts: totalContracts,
          totalArticlesContracted: totalArticlesContracted,
          totalAssignedPieces: totalAssignedPieces,
          totalDeliveredPieces: totalDeliveredPieces,
          overallDeliveryPercentage: overallPct,
          assignedModulesCount: assignedModsCount,
          totalModulesCount: moduleVendors.length,
        ),
      );
    } catch (e) {
      debugPrint('[BuyersVendorsNotifier] fetchHubData error: $e');
      state = state.copyWith(
        isLoading: false,
        isSyncing: false,
        error: 'Unable to load Buyers & Vendors data. Pull down to retry.',
      );
    }
  }

  Future<ActionResult> createOrUpdateBuyer({
    String? existingId,
    required String brandName,
    String? brandCode,
    required String contactPerson,
    required String phone,
    String? email,
    String? city,
    String? address,
    String? gstin,
  }) async {
    state = state.copyWith(isSubmitting: true);
    try {
      final client = Supabase.instance.client;
      final tenantCompany = state.companyName.trim().isNotEmpty ? state.companyName.trim() : 'Factory';

      final cleanName = brandName.trim().toUpperCase();
      final fallbackCode = cleanName.length >= 3 ? cleanName.substring(0, 3) : cleanName;
      final cleanCode = (brandCode ?? '').trim().isNotEmpty
          ? brandCode!.trim().toUpperCase()
          : fallbackCode;
      final cleanPerson = contactPerson.trim();
      final digits = phone.replaceAll(RegExp(r'\D'), '');
      final cleanPhone = digits.length > 10 ? digits.substring(digits.length - 10) : digits;

      if (cleanName.isEmpty) {
        return const ActionResult(success: false, error: 'Please enter Buyer / Company Name.');
      }

      // Resolve if a matching brand row exists for this buyer
      String? targetBrandId;
      if (existingId != null &&
          existingId.isNotEmpty &&
          !existingId.startsWith('virtual-') &&
          !existingId.startsWith('merch-buyer-') &&
          !existingId.startsWith('buyer-')) {
        try {
          final existingById =
              await client.from('brands').select('id').eq('id', existingId).maybeSingle();
          if (existingById != null && existingById['id'] != null) {
            targetBrandId = existingById['id'].toString();
          }
        } catch (_) {}
      }

      if (targetBrandId == null) {
        try {
          final existingByName = await client
              .from('brands')
              .select('id')
              .ilike('brand_name', cleanName)
              .limit(1)
              .maybeSingle();
          if (existingByName != null && existingByName['id'] != null) {
            targetBrandId = existingByName['id'].toString();
          }
        } catch (_) {}
      }

      final brandPayload = {
        'brand_name': cleanName,
        'brand_code': cleanCode,
        'contact_person': cleanPerson.isNotEmpty ? cleanPerson : null,
        'phone': cleanPhone.isNotEmpty ? cleanPhone : null,
        'email': (email ?? '').trim().isNotEmpty ? email!.trim() : null,
        'city': (city ?? '').trim().isNotEmpty ? city!.trim() : null,
        'address': (address ?? '').trim().isNotEmpty ? address!.trim() : null,
        'gstin': (gstin ?? '').trim().isNotEmpty ? gstin!.trim().toUpperCase() : null,
        'company_name': tenantCompany,
      };

      if (targetBrandId != null) {
        await client.from('brands').update({
          ...brandPayload,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', targetBrandId);
      } else {
        await client.from('brands').insert({
          ...brandPayload,
          'is_active': true,
        });
      }

      // Best-effort sync to merchandising_active_buyers
      try {
        final existingMb = await client
            .from('merchandising_active_buyers')
            .select('id')
            .ilike('buyer_name', cleanName)
            .ilike('company_name', tenantCompany)
            .limit(1)
            .maybeSingle();
        final mbPayload = {
          'buyer_name': cleanName,
          'buyer_code': cleanCode,
          'brand_name': cleanName,
          'contact_person': cleanPerson.isNotEmpty ? cleanPerson : null,
          'contact_email': (email ?? '').trim().isNotEmpty ? email!.trim() : null,
          'company_name': tenantCompany,
          'status': 'ACTIVE',
        };
        if (existingMb != null && existingMb['id'] != null) {
          await client
              .from('merchandising_active_buyers')
              .update(mbPayload)
              .eq('id', existingMb['id'].toString());
        } else {
          await client.from('merchandising_active_buyers').insert(mbPayload);
        }
      } catch (_) {}

      await fetchHubData(isBackgroundSync: true);
      return const ActionResult(success: true);
    } catch (e) {
      debugPrint('[BuyersVendorsNotifier] createOrUpdateBuyer error: $e');
      return ActionResult(success: false, error: 'Failed to save buyer: $e');
    } finally {
      state = state.copyWith(isSubmitting: false);
    }
  }

  Future<ActionResult> assignModuleVendor({
    required ModuleVendorItem moduleItem,
    required String companyName,
    required String contactPerson,
    required String phone,
    String? notes,
  }) async {
    state = state.copyWith(isSubmitting: true);
    try {
      final client = Supabase.instance.client;
      final tenantCompany = state.companyName.trim().isNotEmpty ? state.companyName.trim() : 'Factory';

      final cleanCompany = companyName.trim();
      final cleanPerson = contactPerson.trim();
      final digits = phone.replaceAll(RegExp(r'\D'), '');
      final cleanPhone = digits.length > 10 ? digits.substring(digits.length - 10) : digits;

      if (cleanCompany.isEmpty) {
        return const ActionResult(success: false, error: 'Please enter Company / Vendor Name.');
      }
      if (cleanPerson.isEmpty) {
        return const ActionResult(success: false, error: 'Please enter Contact Person Name.');
      }
      if (cleanPhone.length < 10) {
        return const ActionResult(success: false, error: 'Please enter a valid 10-digit mobile number.');
      }

      String? recordId;
      final existing = await client
          .from('module_vendors')
          .select('id, notes')
          .eq('module_route', moduleItem.moduleRoute)
          .ilike('tenant_company', tenantCompany)
          .maybeSingle();

      // For custom modules, preserve JSON module metadata and store vendorNotes inside it
      String? effectiveNotes = (notes ?? '').trim().isNotEmpty ? notes!.trim() : null;
      if (moduleItem.isCustom) {
        Map<String, dynamic> meta = {};
        final oldNotes = (existing?['notes'] ?? '').toString().trim();
        if (oldNotes.startsWith('{')) {
          try {
            final decoded = jsonDecode(oldNotes);
            if (decoded is Map<String, dynamic>) meta = decoded;
          } catch (_) {}
        }
        meta['isCustom'] = true;
        meta['moduleCode'] = moduleItem.moduleCode;
        meta['defaultDesignation'] = moduleItem.defaultDesignation;
        meta['iconName'] = moduleItem.iconName;
        meta['description'] = moduleItem.description;
        meta['vendorNotes'] = effectiveNotes ?? '';
        effectiveNotes = jsonEncode(meta);
      }

      if (existing != null && existing['id'] != null) {
        final updated = await client
            .from('module_vendors')
            .update({
              'module_name': moduleItem.moduleName,
              'company_name': cleanCompany,
              'contact_person': cleanPerson,
              'phone': cleanPhone,
              'notes': effectiveNotes,
              'tenant_company': tenantCompany,
              'is_active': true,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', existing['id'].toString())
            .select()
            .maybeSingle();
        recordId = updated?['id']?.toString() ?? existing['id'].toString();
      } else {
        final inserted = await client
            .from('module_vendors')
            .insert({
              'module_route': moduleItem.moduleRoute,
              'module_name': moduleItem.moduleName,
              'company_name': cleanCompany,
              'contact_person': cleanPerson,
              'phone': cleanPhone,
              'notes': effectiveNotes,
              'tenant_company': tenantCompany,
              'is_active': true,
            })
            .select()
            .maybeSingle();
        recordId = inserted?['id']?.toString();
      }

      // Best-effort sync to vendors directory
      try {
        final prefix = cleanCompany.length >= 3
            ? cleanCompany.substring(0, 3).toUpperCase()
            : cleanCompany.toUpperCase();
        final suffix = 100 + Random().nextInt(900);
        await client.from('vendors').upsert({
          'vendor_code': 'VND-$prefix-$suffix',
          'vendor_name': cleanCompany,
          'brand_name': tenantCompany,
          'contact_person': cleanPerson,
          'phone': cleanPhone,
          'module_route': moduleItem.moduleRoute,
          'tenant_company': tenantCompany,
          'vendor_type': 'STITCHING_JOB_WORK',
          'city': 'Kolkata',
          'stitching_rate': 20,
          'is_active': true,
        }, onConflict: 'vendor_name');
      } catch (_) {}

      final updatedModule = moduleItem.copyWith(
        assignedVendor: AssignedVendorInfo(
          id: recordId ?? 'vnd-${DateTime.now().millisecondsSinceEpoch}',
          companyName: cleanCompany,
          contactPerson: cleanPerson,
          phone: cleanPhone,
          notes: (notes ?? '').trim(),
          isActive: true,
        ),
      );

      final updatedList = state.moduleVendors
          .map((m) => m.moduleRoute == updatedModule.moduleRoute ? updatedModule : m)
          .toList();
      state = state.copyWith(moduleVendors: updatedList);
      await fetchHubData(isBackgroundSync: true);
      return ActionResult(success: true, moduleItem: updatedModule);
    } catch (e) {
      debugPrint('[BuyersVendorsNotifier] assignModuleVendor error: $e');
      return ActionResult(success: false, error: 'Failed to assign vendor: $e');
    } finally {
      state = state.copyWith(isSubmitting: false);
    }
  }

  Future<ActionResult> removeModuleVendor(String moduleRoute) async {
    state = state.copyWith(isSubmitting: true);
    try {
      final client = Supabase.instance.client;
      final tenantCompany = state.companyName.trim().isNotEmpty ? state.companyName.trim() : 'Factory';

      if (moduleRoute.startsWith('/custom')) {
        await client
            .from('module_vendors')
            .update({
              'company_name': 'Unassigned',
              'contact_person': 'Not Assigned',
              'phone': '0000000000',
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('module_route', moduleRoute)
            .ilike('tenant_company', tenantCompany);
      } else {
        await client
            .from('module_vendors')
            .delete()
            .eq('module_route', moduleRoute)
            .ilike('tenant_company', tenantCompany);
      }

      final updatedList = state.moduleVendors
          .map((m) => m.moduleRoute == moduleRoute ? m.copyWith(clearVendor: true) : m)
          .toList();
      state = state.copyWith(moduleVendors: updatedList);
      await fetchHubData(isBackgroundSync: true);
      return const ActionResult(success: true);
    } catch (e) {
      debugPrint('[BuyersVendorsNotifier] removeModuleVendor error: $e');
      return ActionResult(success: false, error: 'Failed to remove vendor: $e');
    } finally {
      state = state.copyWith(isSubmitting: false);
    }
  }

  Future<ActionResult> createCustomModule({
    required String moduleName,
    String? moduleCode,
    String? defaultDesignation,
    String? description,
    String iconName = 'Layers',
    String? vendorCompanyName,
    String? contactPerson,
    String? phone,
    String? vendorNotes,
  }) async {
    state = state.copyWith(isSubmitting: true);
    try {
      final client = Supabase.instance.client;
      final tenantCompany = state.companyName.trim().isNotEmpty ? state.companyName.trim() : 'Factory';

      final cleanName = moduleName.trim();
      if (cleanName.isEmpty) {
        return const ActionResult(success: false, error: 'Please enter a valid Module Name.');
      }

      final slugRaw = cleanName
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]'), '-')
          .replaceAll(RegExp(r'-+'), '-');
      final slug = slugRaw.length > 24 ? slugRaw.substring(0, 24) : slugRaw;
      final moduleRoute = '/custom/$slug-${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';

      final fallbackCode = (cleanName.length >= 4 ? cleanName.substring(0, 4) : cleanName).toUpperCase();
      final cleanCode = (moduleCode ?? '').trim().isNotEmpty
          ? moduleCode!.trim().toUpperCase()
          : fallbackCode;
      final cleanDesig = (defaultDesignation ?? '').trim().isNotEmpty
          ? defaultDesignation!.trim()
          : 'Unit In-Charge';
      final cleanDesc = (description ?? '').trim().isNotEmpty
          ? description!.trim()
          : '$cleanName operational station';

      final hasVendor = (vendorCompanyName ?? '').trim().isNotEmpty;
      final digits = (phone ?? '').replaceAll(RegExp(r'\D'), '');
      final cleanPhone = hasVendor
          ? (digits.length > 10 ? digits.substring(digits.length - 10) : (digits.isNotEmpty ? digits : '0000000000'))
          : '0000000000';
      final companyVal = hasVendor ? vendorCompanyName!.trim() : 'Unassigned';
      final personVal = hasVendor
          ? ((contactPerson ?? '').trim().isNotEmpty ? contactPerson!.trim() : 'Unit Representative')
          : 'Not Assigned';

      final metaNotes = jsonEncode({
        'isCustom': true,
        'moduleCode': cleanCode,
        'defaultDesignation': cleanDesig,
        'iconName': iconName,
        'description': cleanDesc,
        'vendorNotes': vendorNotes?.trim() ?? '',
      });

      Map<String, dynamic>? inserted;
      try {
        inserted = await client
            .from('module_vendors')
            .insert({
              'module_route': moduleRoute,
              'module_name': cleanName,
              'module_code': cleanCode,
              'icon_name': iconName,
              'is_custom': true,
              'company_name': companyVal,
              'contact_person': personVal,
              'phone': cleanPhone,
              'notes': metaNotes,
              'tenant_company': tenantCompany,
              'is_active': true,
            })
            .select()
            .maybeSingle();
      } catch (_) {
        inserted = await client
            .from('module_vendors')
            .insert({
              'module_route': moduleRoute,
              'module_name': cleanName,
              'company_name': companyVal,
              'contact_person': personVal,
              'phone': cleanPhone,
              'notes': metaNotes,
              'tenant_company': tenantCompany,
              'is_active': true,
            })
            .select()
            .maybeSingle();
      }

      final createdItem = ModuleVendorItem(
        id: inserted?['id']?.toString() ?? 'mod-${DateTime.now().millisecondsSinceEpoch}',
        moduleRoute: moduleRoute,
        moduleCode: cleanCode,
        moduleName: cleanName,
        defaultDesignation: cleanDesig,
        iconName: iconName,
        description: cleanDesc,
        isCustom: true,
        assignedVendor: hasVendor
            ? AssignedVendorInfo(
                id: inserted?['id']?.toString() ?? 'vnd-${DateTime.now().millisecondsSinceEpoch}',
                companyName: companyVal,
                contactPerson: personVal,
                phone: cleanPhone,
                notes: vendorNotes?.trim() ?? '',
                isActive: true,
              )
            : null,
      );

      state = state.copyWith(moduleVendors: [...state.moduleVendors, createdItem]);
      await fetchHubData(isBackgroundSync: true);
      return ActionResult(success: true, moduleItem: createdItem);
    } catch (e) {
      debugPrint('[BuyersVendorsNotifier] createCustomModule error: $e');
      return ActionResult(success: false, error: 'Failed to create custom module: $e');
    } finally {
      state = state.copyWith(isSubmitting: false);
    }
  }

  Future<ActionResult> deleteCustomModule(String moduleRoute) async {
    state = state.copyWith(isSubmitting: true);
    try {
      final client = Supabase.instance.client;
      final tenantCompany = state.companyName.trim().isNotEmpty ? state.companyName.trim() : 'Factory';

      await client
          .from('module_vendors')
          .delete()
          .eq('module_route', moduleRoute)
          .ilike('tenant_company', tenantCompany);

      state = state.copyWith(
        moduleVendors: state.moduleVendors.where((m) => m.moduleRoute != moduleRoute).toList(),
      );
      await fetchHubData(isBackgroundSync: true);
      return const ActionResult(success: true);
    } catch (e) {
      debugPrint('[BuyersVendorsNotifier] deleteCustomModule error: $e');
      return ActionResult(success: false, error: 'Failed to delete custom module: $e');
    } finally {
      state = state.copyWith(isSubmitting: false);
    }
  }
}

final buyersVendorsProvider =
    StateNotifierProvider.autoDispose<BuyersVendorsNotifier, BuyersVendorsState>((ref) {
  return BuyersVendorsNotifier();
});

