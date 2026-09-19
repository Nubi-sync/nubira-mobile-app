import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/merchandising_models.dart';

class MerchandisingState {
  final bool isLoading;
  final bool isSyncing;
  final String? error;
  final List<MerchandisingOrder> orders;
  final List<ActiveBuyer> buyers;
  final List<TechPackArticleItem> techPackArticles;
  final List<TnaMilestone> milestones;
  final String selectedBuyerId;
  final String statusFilter;
  final bool isSubmitting;

  const MerchandisingState({
    this.isLoading = false,
    this.isSyncing = false,
    this.error,
    this.orders = const [],
    this.buyers = const [],
    this.techPackArticles = const [],
    this.milestones = const [],
    this.selectedBuyerId = '',
    this.statusFilter = 'ALL',
    this.isSubmitting = false,
  });

  MerchandisingState copyWith({
    bool? isLoading,
    bool? isSyncing,
    String? error,
    List<MerchandisingOrder>? orders,
    List<ActiveBuyer>? buyers,
    List<TechPackArticleItem>? techPackArticles,
    List<TnaMilestone>? milestones,
    String? selectedBuyerId,
    String? statusFilter,
    bool? isSubmitting,
  }) {
    return MerchandisingState(
      isLoading: isLoading ?? this.isLoading,
      isSyncing: isSyncing ?? this.isSyncing,
      error: error,
      orders: orders ?? this.orders,
      buyers: buyers ?? this.buyers,
      techPackArticles: techPackArticles ?? this.techPackArticles,
      milestones: milestones ?? this.milestones,
      selectedBuyerId: selectedBuyerId ?? this.selectedBuyerId,
      statusFilter: statusFilter ?? this.statusFilter,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }

  ActiveBuyer? get selectedBuyer {
    if (buyers.isEmpty) return null;
    if (selectedBuyerId.isNotEmpty) {
      final found = buyers.where((b) => b.id == selectedBuyerId).toList();
      if (found.isNotEmpty) return found.first;
    }
    return buyers.first;
  }

  int get totalBookedPcs {
    return orders.fold<int>(0, (sum, ord) => sum + ord.totalQuantity);
  }

  int get activeArticlesCount {
    return techPackArticles.length;
  }

  int get totalInOrderPieces {
    final linked = buyers.where((b) => b.linkedArticleNumber != null && b.linkedArticleNumber!.isNotEmpty);
    return linked.fold<int>(0, (sum, b) => sum + b.contractedVolume);
  }

  String get slaPercentage {
    if (milestones.isEmpty) return '0.0';
    final cleared = milestones.where((m) => m.status == 'COMPLETED').length;
    return ((cleared / milestones.length) * 100).toStringAsFixed(1);
  }

  StageMetrics get stageMetrics {
    final buyer = selectedBuyer;
    if (buyer == null) return const StageMetrics();

    final totalVol = buyer.contractedVolume;
    final articleNum = buyer.linkedArticleNumber?.trim() ?? '';

    // Calculate stage distribution from orders matching buyer or article
    final buyerOrders = orders.where((o) {
      if (articleNum.isNotEmpty && (o.styleRef == articleNum || o.poNumber == articleNum)) {
        return true;
      }
      return o.brandName.toLowerCase() == buyer.buyerName.toLowerCase() ||
          o.buyerId == buyer.id ||
          o.buyerCode == buyer.buyerCode;
    }).toList();

    int cutPcs = 0;
    int printPcs = 0;
    int embPcs = 0;
    int sewPcs = 0;
    int ironPcs = 0;
    int washPcs = 0;
    int alterPcs = 0;

    for (final ord in buyerOrders) {
      final st = ord.normalizedStatus;
      final q = ord.totalQuantity;
      switch (st) {
        case 'IN_CUTTING':
          cutPcs += q;
          break;
        case 'IN_PRINTING':
          printPcs += q;
          break;
        case 'IN_EMBROIDERY':
          embPcs += q;
          break;
        case 'IN_SEWING':
          sewPcs += q;
          break;
        case 'IRON':
          ironPcs += q;
          break;
        case 'WASHING':
          washPcs += q;
          break;
        case 'ALTER':
          alterPcs += q;
          break;
        default:
          cutPcs += q;
          break;
      }
    }

    final floorSum = cutPcs + printPcs + embPcs + sewPcs + ironPcs + washPcs + alterPcs;
    final inPending = (totalVol > floorSum) ? totalVol - floorSum : 0;

    return StageMetrics(
      inPending: inPending,
      inCutting: cutPcs,
      inPrinting: printPcs,
      inEmbroidery: embPcs,
      inSewing: sewPcs,
      iron: ironPcs,
      washing: washPcs,
      alter: alterPcs,
    );
  }

  List<MerchandisingOrder> get filteredOrders {
    if (statusFilter == 'ALL') return orders;
    return orders.where((o) => o.normalizedStatus == statusFilter).toList();
  }

  List<ActivityItem> get activities {
    if (orders.isEmpty) return [];
    return orders.take(6).map((ord) {
      return ActivityItem(
        id: 'act-${ord.id}',
        type: 'PO',
        title: 'PO ${ord.poNumber} Active',
        details: '${ord.totalQuantity} pcs • ${ord.brandName} (${ord.styleRef})',
        location: 'Commercial Desk',
        timestamp: ord.createdAt,
        relativeTime: 'Active',
      );
    }).toList();
  }
}

class MerchandisingNotifier extends StateNotifier<MerchandisingState> {
  MerchandisingNotifier() : super(const MerchandisingState()) {
    fetchMerchandisingData();
  }

  void setSelectedBuyerId(String id) {
    state = state.copyWith(selectedBuyerId: id);
  }

  void setStatusFilter(String filter) {
    state = state.copyWith(statusFilter: filter);
  }

  Future<void> syncData() async {
    state = state.copyWith(isSyncing: true);
    await fetchMerchandisingData(isBackgroundSync: true);
    state = state.copyWith(isSyncing: false);
  }

  Future<void> fetchMerchandisingData({bool isBackgroundSync = false}) async {
    if (!isBackgroundSync) {
      state = state.copyWith(isLoading: true, error: null);
    }

    try {
      final client = Supabase.instance.client;

      // 1. Fetch Orders with brands, tech packs, and ratios
      List<MerchandisingOrder> fetchedOrders = [];
      try {
        final res = await client
            .from('merchandising_orders')
            .select('''
              *,
              brands ( id, brand_name, brand_code ),
              design_tech_packs ( id, style_number, category, embellishment_sequence, fabric_composition, target_gsm, cad_front_url, cad_back_url ),
              merchandising_order_ratios ( id, color_name, color_code, size_label, ratio_units, quantity )
            ''')
            .order('created_at', ascending: false);

        final rawList = res as List<dynamic>;
        fetchedOrders = rawList.map((row) {
          final colorGroups = <String, Map<String, dynamic>>{};
          final ratios = (row['merchandising_order_ratios'] as List?) ?? [];
          for (final r in ratios) {
            final color = r['color_name']?.toString() ?? 'Standard';
            final size = r['size_label']?.toString() ?? 'M';
            final qty = (r['quantity'] as num?)?.toInt() ?? 0;
            if (!colorGroups.containsKey(color)) {
              colorGroups[color] = {'sizes': <String, int>{}, 'total': 0};
            }
            (colorGroups[color]!['sizes'] as Map<String, int>)[size] = qty;
            colorGroups[color]!['total'] = (colorGroups[color]!['total'] as int) + qty;
          }

          final colorMatrix = colorGroups.entries.map((e) {
            return ColorSizeMatrixItem(
              color: e.key,
              sizes: e.value['sizes'] as Map<String, int>,
              total: e.value['total'] as int,
            );
          }).toList();

          final tp = row['design_tech_packs'] as Map<String, dynamic>?;
          final brand = row['brands'] as Map<String, dynamic>?;

          final totalQty = (row['total_quantity'] as num?)?.toInt() ?? 0;
          final fobPrice = (row['fob_price_per_piece'] as num?)?.toDouble() ?? 0.0;

          // Parse metadata out of fabric_composition
          String cleanFabric = tp?['fabric_composition']?.toString() ?? '100% Combed Cotton Single Jersey';
          List<dynamic> parsedMaterials = [];
          final bomMatch = RegExp(r'\[BOM_JSON:\s*(\[[\s\S]*?\])\]', caseSensitive: false).firstMatch(cleanFabric);
          if (bomMatch != null && bomMatch.group(1) != null) {
            try {
              parsedMaterials = (jsonDecode(bomMatch.group(1)!) as List<dynamic>);
            } catch (_) {}
            cleanFabric = cleanFabric.replaceAll(bomMatch.group(0)!, '');
          }
          cleanFabric = cleanFabric.replaceAll(RegExp(r'\[TARGET_CUT_DATE:[^\]]*\]', caseSensitive: false), '');
          cleanFabric = cleanFabric.replaceAll(RegExp(r'\[INSTRUCTIONS:[^\]]*\]', caseSensitive: false), '');
          cleanFabric = cleanFabric.replaceAll(RegExp(r'\[[A-Z_]+:[^\]]*\]', caseSensitive: false), '');
          cleanFabric = cleanFabric.replaceAll(RegExp(r'\s+'), ' ').trim();
          if (cleanFabric.isEmpty) {
            cleanFabric = '100% Combed Cotton Single Jersey';
          }

          return MerchandisingOrder(
            id: row['id']?.toString() ?? '',
            poNumber: row['order_number']?.toString() ?? 'PO',
            brandName: brand?['brand_name']?.toString() ?? 'Direct Buyer',
            styleRef: tp?['style_number']?.toString() ?? 'Standard Style',
            styleName: '${tp?['category'] ?? 'Garment'} ${row['order_number'] ?? ''} Export Edition',
            techPackId: row['tech_pack_id']?.toString(),
            totalQuantity: totalQty,
            currency: row['currency']?.toString() ?? 'INR',
            unitFobPrice: fobPrice,
            totalContractValue: (totalQty * fobPrice),
            exFactoryDate: row['ex_factory_date']?.toString() ?? '',
            status: row['status']?.toString() ?? 'IN_CUTTING',
            embellishmentSequence: tp?['embellishment_sequence']?.toString() ?? 'NONE',
            fabricComposition: cleanFabric,
            bomMaterials: parsedMaterials,
            targetGsm: (tp?['target_gsm'] as num?)?.toInt() ?? 180,
            cadFrontUrl: tp?['cad_front_url']?.toString(),
            cadBackUrl: tp?['cad_back_url']?.toString(),
            buyerId: row['buyer_id']?.toString(),
            buyerCode: brand?['brand_code']?.toString(),
            colorMatrix: colorMatrix.isNotEmpty
                ? colorMatrix
                : [
                    ColorSizeMatrixItem(
                      color: 'Standard Colorway',
                      sizes: {'S': (totalQty * 0.2).round(), 'M': (totalQty * 0.5).round(), 'L': (totalQty * 0.3).round()},
                      total: totalQty,
                    ),
                  ],
            createdAt: row['created_at']?.toString() ?? DateTime.now().toIso8601String(),
          );
        }).toList();
      } catch (e) {
        debugPrint('[MerchandisingNotifier] Error loading orders: $e');
      }

      // 2. Fetch Active Buyers
      List<ActiveBuyer> buyersList = [];
      try {
        final bRes = await client.from('merchandising_active_buyers').select('*').order('created_at', ascending: false);
        final rawBuyers = bRes as List<dynamic>;
        if (rawBuyers.isNotEmpty) {
          buyersList = rawBuyers.map((b) => ActiveBuyer.fromJson(b as Map<String, dynamic>)).toList();
        }
      } catch (_) {}

      // If active buyers table is empty, generate from orders & brands
      if (buyersList.isEmpty) {
        final buyerMap = <String, ActiveBuyer>{};
        for (final ord in fetchedOrders) {
          final bName = ord.brandName.trim();
          final bKey = bName.toUpperCase();
          if (!buyerMap.containsKey(bKey)) {
            buyerMap[bKey] = ActiveBuyer(
              id: ord.buyerId ?? ord.id,
              buyerName: bName,
              buyerCode: ord.buyerCode ?? (bName.length >= 4 ? bName.substring(0, 4).toUpperCase() : 'BUYER'),
              brandName: bName,
              contractedVolume: ord.totalQuantity,
              pricePerPiece: ord.unitFobPrice > 0 ? ord.unitFobPrice : 12.5,
              totalContractValue: ord.totalContractValue,
              linkedArticleNumber: ord.styleRef,
              linkedArticleName: ord.styleName,
              status: 'LINKED',
            );
          } else {
            final prev = buyerMap[bKey]!;
            buyerMap[bKey] = ActiveBuyer(
              id: prev.id,
              buyerName: prev.buyerName,
              buyerCode: prev.buyerCode,
              brandName: prev.brandName,
              contractedVolume: prev.contractedVolume + ord.totalQuantity,
              pricePerPiece: prev.pricePerPiece,
              totalContractValue: prev.totalContractValue + ord.totalContractValue,
              linkedArticleNumber: prev.linkedArticleNumber ?? ord.styleRef,
              linkedArticleName: prev.linkedArticleName ?? ord.styleName,
              status: 'LINKED',
            );
          }
        }
        buyersList = buyerMap.values.toList();
      }

      // Fallback: Query brands table if still empty
      if (buyersList.isEmpty) {
        try {
          final brRes = await client.from('brands').select('*');
          final rawBrands = brRes as List<dynamic>;
          if (rawBrands.isNotEmpty) {
            buyersList = rawBrands.map((b) {
              final name = b['brand_name']?.toString() ?? 'Direct Buyer';
              return ActiveBuyer(
                id: b['id']?.toString() ?? '',
                buyerName: name,
                buyerCode: b['brand_code']?.toString() ?? (name.length >= 4 ? name.substring(0, 4).toUpperCase() : 'BUYER'),
                brandName: name,
                contractedVolume: 5000,
                pricePerPiece: 1450.0,
                totalContractValue: 5000 * 1450.0,
                status: 'ACTIVE',
              );
            }).toList();
          }
        } catch (_) {}
      }

      // 3. Fetch Tech Pack Articles
      List<TechPackArticleItem> techPacksList = [];
      try {
        final tpRes = await client.from('design_tech_packs').select('*, brands(brand_name)').order('created_at', ascending: false);
        final rawTps = tpRes as List<dynamic>;
        techPacksList = rawTps.map((tp) {
          final brand = tp['brands'] as Map<String, dynamic>?;
          return TechPackArticleItem(
            id: tp['id']?.toString() ?? '',
            styleNumber: tp['style_number']?.toString() ?? 'STYLE',
            category: tp['category']?.toString() ?? 'GARMENT',
            brandName: brand?['brand_name']?.toString(),
            brandId: tp['brand_id']?.toString(),
            embellishmentSequence: tp['embellishment_sequence']?.toString() ?? 'NONE',
            fabricComposition: tp['fabric_composition']?.toString() ?? '100% Cotton',
            targetGsm: (tp['target_gsm'] as num?)?.toInt() ?? 180,
            cadFrontUrl: tp['cad_front_url']?.toString(),
            cadBackUrl: tp['cad_back_url']?.toString(),
          );
        }).toList();
      } catch (e) {
        debugPrint('[MerchandisingNotifier] Error loading tech packs: $e');
      }

      // 4. Fetch T&A Milestones
      List<TnaMilestone> milestoneList = [];
      try {
        final mRes = await client.from('merchandising_tna_milestones').select('*').order('target_date', ascending: true);
        final rawMilestones = mRes as List<dynamic>;
        milestoneList = rawMilestones.map((m) {
          return TnaMilestone(
            id: m['id']?.toString() ?? '',
            orderId: m['order_id']?.toString() ?? '',
            gateName: m['gate_name']?.toString() ?? 'GATE',
            targetDate: m['target_date']?.toString() ?? '',
            actualDate: m['actual_date']?.toString(),
            status: m['status']?.toString() ?? 'ON_SCHEDULE',
            delayReason: m['delay_reason']?.toString(),
          );
        }).toList();
      } catch (_) {}

      // Keep selected buyer ID or default to first
      String activeBuyerId = state.selectedBuyerId;
      if (activeBuyerId.isEmpty || !buyersList.any((b) => b.id == activeBuyerId)) {
        activeBuyerId = buyersList.isNotEmpty ? buyersList.first.id : '';
      }

      state = state.copyWith(
        isLoading: false,
        isSyncing: false,
        orders: fetchedOrders,
        buyers: buyersList,
        techPackArticles: techPacksList,
        milestones: milestoneList,
        selectedBuyerId: activeBuyerId,
      );
    } catch (e) {
      debugPrint('[MerchandisingNotifier] Error fetching merchandising data: $e');
      state = state.copyWith(
        isLoading: false,
        isSyncing: false,
        error: e.toString(),
      );
    }
  }

  Future<bool> createBuyerOrder({
    required String poNumber,
    required String brandName,
    required String styleRef,
    required int totalQuantity,
    required double unitFobPrice,
    required String currency,
    required String exFactoryDate,
    required List<ColorSizeMatrixItem> colorMatrix,
    String? techPackId,
  }) async {
    state = state.copyWith(isSubmitting: true);
    try {
      final client = Supabase.instance.client;

      // 1. Resolve Brand
      String? resolvedBrandId;
      try {
        final existingBrand = await client
            .from('brands')
            .select('id')
            .ilike('brand_name', brandName.trim())
            .limit(1)
            .maybeSingle();

        if (existingBrand != null && existingBrand['id'] != null) {
          resolvedBrandId = existingBrand['id'].toString();
        } else {
          final code = brandName.trim().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
          final newBrand = await client
              .from('brands')
              .insert({
                'brand_name': brandName.trim(),
                'brand_code': code.isNotEmpty ? (code.length > 8 ? code.substring(0, 8) : code) : 'BRAND',
              })
              .select('id')
              .maybeSingle();
          resolvedBrandId = newBrand?['id']?.toString();
        }
      } catch (_) {}

      if (resolvedBrandId == null) {
        final anyBrand = await client.from('brands').select('id').limit(1).maybeSingle();
        resolvedBrandId = anyBrand?['id']?.toString();
      }

      // 2. Resolve Tech Pack
      String? resolvedTechPackId = techPackId;
      if (resolvedTechPackId == null || resolvedTechPackId.isEmpty) {
        try {
          final tp = await client
              .from('design_tech_packs')
              .select('id')
              .ilike('style_number', styleRef.trim())
              .limit(1)
              .maybeSingle();
          if (tp != null && tp['id'] != null) {
            resolvedTechPackId = tp['id'].toString();
          } else {
            final newTp = await client
                .from('design_tech_packs')
                .insert({
                  'style_number': styleRef.trim().toUpperCase(),
                  'brand_id': resolvedBrandId,
                  'category': 'GARMENT',
                  'fabric_composition': '100% Cotton',
                  'target_gsm': 180,
                  'status': 'DRAFT',
                })
                .select('id')
                .maybeSingle();
            resolvedTechPackId = newTp?['id']?.toString();
          }
        } catch (_) {}
      }

      if (resolvedTechPackId == null) {
        final anyTp = await client.from('design_tech_packs').select('id').limit(1).maybeSingle();
        resolvedTechPackId = anyTp?['id']?.toString();
      }

      // 3. Insert Master Order
      final orderRes = await client
          .from('merchandising_orders')
          .insert({
            'order_number': poNumber.trim().toUpperCase(),
            'buyer_id': resolvedBrandId,
            'tech_pack_id': resolvedTechPackId,
            'season': 'SS27',
            'total_quantity': totalQuantity,
            'fob_price_per_piece': unitFobPrice,
            'currency': currency,
            'order_date': DateTime.now().toIso8601String().split('T')[0],
            'ex_factory_date': exFactoryDate,
            'incoterm': 'FOB',
            'status': 'IN_CUTTING',
          })
          .select()
          .single();

      final newOrderId = orderRes['id']?.toString();
      if (newOrderId != null) {
        // 4. Insert Ratios
        final ratioInserts = <Map<String, dynamic>>[];
        for (final item in colorMatrix) {
          item.sizes.forEach((size, qty) {
            if (qty > 0) {
              ratioInserts.add({
                'order_id': newOrderId,
                'color_name': item.color,
                'size_label': size,
                'ratio_units': 1,
                'quantity': qty,
              });
            }
          });
        }

        if (ratioInserts.isNotEmpty) {
          try {
            await client.from('merchandising_order_ratios').insert(ratioInserts);
          } catch (e) {
            debugPrint('[MerchandisingNotifier] Error inserting ratios: $e');
          }
        }

        // 5. Generate Forward-Scheduled T&A Critical Path Milestones
        try {
          final now = DateTime.now();
          final exDate = DateTime.tryParse(exFactoryDate) ?? now.add(const Duration(days: 30));
          final totalDays = exDate.difference(now).inDays > 0 ? exDate.difference(now).inDays : 30;

          final standardGates = [
            {'name': 'LAB_DIP_APPROVAL', 'pct': 0.12},
            {'name': 'FABRIC_INWARD', 'pct': 0.28},
            {'name': 'PPS_APPROVAL', 'pct': 0.40},
            {'name': 'CUTTING_START', 'pct': 0.52},
            {'name': 'SEWING_COMPLETE', 'pct': 0.72},
            {'name': 'WASHING_COMPLETE', 'pct': 0.84},
            {'name': 'FINAL_AQL_AUDIT', 'pct': 0.92},
            {'name': 'EX_FACTORY', 'pct': 1.00},
          ];

          final milestoneInserts = standardGates.map((g) {
            final pct = g['pct'] as double;
            final target = pct == 1.0
                ? exFactoryDate
                : now.add(Duration(days: (totalDays * pct).round())).toIso8601String().split('T')[0];
            return {
              'order_id': newOrderId,
              'gate_name': g['name'],
              'target_date': target,
              'status': 'ON_SCHEDULE',
            };
          }).toList();

          await client.from('merchandising_tna_milestones').insert(milestoneInserts);
        } catch (mErr) {
          debugPrint('[MerchandisingNotifier] T&A scheduling note: $mErr');
        }
      }

      await fetchMerchandisingData();
      state = state.copyWith(isSubmitting: false);
      return true;
    } catch (e) {
      debugPrint('[MerchandisingNotifier] Error creating order: $e');
      state = state.copyWith(isSubmitting: false, error: e.toString());
      return false;
    }
  }
}

final merchandisingProvider = StateNotifierProvider<MerchandisingNotifier, MerchandisingState>((ref) {
  return MerchandisingNotifier();
});
