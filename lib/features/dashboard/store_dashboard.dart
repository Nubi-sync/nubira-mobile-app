import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../auth/providers/auth_provider.dart';
import '../auth/screens/login_screen.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/parser_utils.dart';
import '../../core/utils/multi_size_parser.dart';
import '../../core/services/tenant_resolver_service.dart';
import '../admin/screens/admin_shell.dart';
import '../modules/screens/enterprise_workspace_hub_screen.dart';
import '../../../main.dart'; // supabase client

class _AccessoryChallanItem {
  TextEditingController nameController;
  TextEditingController vendorController;
  TextEditingController priceController;
  TextEditingController sizeController;
  TextEditingController qtyController;
  TextEditingController shortageController;
  TextEditingController remarksController;
  String unit;
  String status; // 'RECEIVED', 'SHORTAGE', 'DUE', 'DEFECTIVE'

  _AccessoryChallanItem({
    required String name,
    String vendor = '',
    String price = '',
    String size = '',
    String qty = '',
    this.unit = 'pcs',
    this.status = 'RECEIVED',
    String shortage = '',
    String remarks = '',
  })  : nameController = TextEditingController(text: name),
        vendorController = TextEditingController(text: vendor),
        priceController = TextEditingController(text: price),
        sizeController = TextEditingController(text: size),
        qtyController = TextEditingController(text: qty),
        shortageController = TextEditingController(text: shortage),
        remarksController = TextEditingController(text: remarks);

  Map<String, dynamic> toMap() {
    final qty = int.tryParse(qtyController.text.trim()) ?? 0;
    final unitPrice = double.tryParse(priceController.text.trim()) ?? 0.0;
    final sizeVal = sizeController.text.trim();

    return {
      'item_name': nameController.text.trim(),
      'vendor_name': vendorController.text.trim(),
      'unit_price': unitPrice,
      'total_price': qty * unitPrice,
      'size_color': sizeVal,
      'size_label': sizeVal,
      'challan_qty': qty,
      'quantity': qty,
      'unit': unit,
      'status': status,
      'shortage_qty': int.tryParse(shortageController.text.trim()) ?? 0,
      'remarks': remarksController.text.trim(),
    };
  }

  void dispose() {
    nameController.dispose();
    vendorController.dispose();
    priceController.dispose();
    sizeController.dispose();
    qtyController.dispose();
    shortageController.dispose();
    remarksController.dispose();
  }
}

class StoreDashboard extends ConsumerStatefulWidget {
  const StoreDashboard({super.key});

  @override
  ConsumerState<StoreDashboard> createState() => _StoreDashboardState();
}

class _StoreDashboardState extends ConsumerState<StoreDashboard> {
  int parseQty(dynamic val, [int fallback = 0]) => ParserUtils.parseQty(val, fallback);
  bool _isLoading = true;

  // Aggregate Stats
  int _totalFinishedStock = 0;
  int _todayOutward = 0;
  int _todayTruckCount = 0;

  List<dynamic> _articles = [];
  List<dynamic> _storeLogs = [];
  List<dynamic> _truckInwards = [];
  List<dynamic> _accessories = [];
  List<dynamic> _storeTransactions = [];

  Map<String, int> _articleStockMap = {};
  Map<String, int> _variantStockMap = {};
  List<dynamic> _allotmentVariants = [];
  List<dynamic> _activeAllotments = [];
  List<dynamic> _allotmentMaterials = [];
  List<dynamic> _readyQcAllotments = [];

  // Section Tabs:
  // 0: Article Allocation & BOM Handover
  // 1: Finished Goods Matrix
  // 2: Supplier Challans & GRN
  // 3: Raw Materials & Trims
  // 4: Dispatch & Challans
  // 5: Inward Receipts
  int _selectedSectionTab = 0;
  String _articleSearchQuery = '';
  String _articleFilterStatus = 'ALL'; // 'ALL', 'PENDING', 'ISSUED'
  String? _expandedArticleNo;
  bool _isSyncing = false;
  List<dynamic> _challans = [];

  // Tab 1 (Finished Goods Matrix) search & filter
  String _finishedSearchQuery = '';
  String _finishedStatusFilter = 'ALL'; // 'ALL', 'IN_STOCK', 'LOW_STOCK', 'OUT_OF_STOCK'

  // Tab 2 (Supplier GRN) search & filter
  String _grnSearchQuery = '';
  String _grnStatusFilter = 'ALL'; // 'ALL', 'VERIFIED', 'SHORTAGE_DUE'

  // Tab 3 (Raw Materials & Trims) search & filter
  String _trimsSearchQuery = '';
  String _trimsStatusFilter = 'ALL'; // 'ALL', 'IN_STOCK', 'LOW_STOCK', 'OUT_OF_STOCK'

  // Tab 4 (Dispatch & Challans) search
  String _dispatchSearchQuery = '';

  // Tab 5 (Inward Receipts) search
  String _inwardSearchQuery = '';

  // Performance & Indexing Caches (O(1) lookups instead of O(N*M))
  Map<String, List<dynamic>> _materialsByAllotmentMap = {};
  Map<String, bool> _allotmentPendingMap = {};
  int _visibleArticleCount = 25;
  int _visibleFeedCount = 20;

  // Activity Feed Filters & Controls
  String _feedTimeFilter = '24h'; // '24h' (default), '7d', 'all'
  String _feedCategoryFilter = 'ALL'; // 'ALL', 'BOM', 'TRIMS', 'GARMENTS'
  String _feedSearchQuery = '';
  final Set<String> _expandedBOMKeys = {};

  // Safety Buffer & Mending Quick-Claim State
  int _safetyBufferPct = 5; // Configurable: 3%, 5%, 8%, 10%
  final List<Map<String, dynamic>> _bufferClaims = [];

  @override
  void initState() {
    super.initState();
    _fetchStoreData();
  }

  Future<void> _fetchStoreData() async {
    setState(() => _isLoading = true);
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];

      final currentUser = supabase.auth.currentUser;
      ResolvedTenantProfile? tenant;
      if (currentUser != null) {
        try {
          tenant = await TenantResolverService.resolveUserTenant(currentUser);
        } catch (_) {}
      }
      final isPlatformSuper = tenant?.isPlatformAdmin == true || tenant?.role == 'PLATFORM_SUPERADMIN';
      final String targetComp = (!isPlatformSuper && tenant != null && tenant.companyName.trim().isNotEmpty)
          ? tenant.companyName.trim().toLowerCase()
          : '';

      // 1. Fetch Articles
      final articlesRes = await supabase
          .from('articles')
          .select('id, art_no, description, size_rates')
          .eq('is_active', true)
          .order('art_no');

      // 1.1 Fetch All Allotment Variants
      List<dynamic> variantsRes = [];
      try {
        variantsRes = await supabase
            .from('allotment_variants')
            .select('id, allotment_id, color, size, quantity');
      } catch (e) {
        debugPrint('Allotment variants fetch error: $e');
      }

      // 1.2 Fetch Active Allotments & Materials for Handshake
      List<dynamic> activeAllotsRes = [];
      List<dynamic> allotMatsRes = [];
      List<dynamic> allotQuery = [];
      List<dynamic> profilesQuery = [];
      List<dynamic> challansQuery = [];

      try {
        allotQuery = await supabase
            .from('allotments')
            .select('*')
            .inFilter('status', ['IN_PROGRESS', 'PENDING'])
            .order('created_at', ascending: false)
            .limit(1000);
      } catch (e) {
        debugPrint('Allotments fetch error in store: $e');
      }

      try {
        profilesQuery = await supabase
            .from('profiles')
            .select('id, username, role, company_name');
      } catch (e) {
        debugPrint('Profiles fetch error: $e');
      }

      try {
        challansQuery = await supabase
            .from('challans')
            .select('*')
            .order('created_at', ascending: false)
            .limit(500);
      } catch (_) {}

      try {
        allotMatsRes = await supabase
            .from('allotment_materials')
            .select('id, allotment_id, item_name, required_qty, admin_issued, lineman_received, notes, created_at')
            .order('created_at', ascending: false);
      } catch (e) {
        debugPrint('Allotment materials fetch error: $e');
      }

      bool isTargetMatch(List<dynamic> values) {
        if (targetComp.isEmpty) return false;
        for (var v in values) {
          if (v == null) continue;
          final s = v.toString().trim().toLowerCase();
          if (s == targetComp ||
              s.contains('[company:$targetComp]') ||
              s.contains('[company: $targetComp]') ||
              (targetComp.isNotEmpty && s.contains(targetComp))) {
            return true;
          }
        }
        return false;
      }

      final Map<String, dynamic> profMap = {};
      for (var p in profilesQuery) {
        profMap[p['id'].toString()] = p;
      }

      final Map<String, dynamic> artMap = {};
      for (var a in articlesRes) {
        artMap[a['id'].toString()] = a;
      }

      final Map<String, String> priorityMap = {};
      for (var mat in allotMatsRes) {
        final aId = mat['allotment_id']?.toString() ?? '';
        final notesRaw = mat['notes'];
        if (notesRaw is String && notesRaw.contains('"priority"')) {
          try {
            final parsed = jsonDecode(notesRaw);
            if (parsed is Map && parsed['priority'] != null) {
              final p = parsed['priority'].toString().toUpperCase();
              if (p == 'CRITICAL' || p == 'RUSH' || p == 'NORMAL') {
                priorityMap[aId] = p;
              }
            }
          } catch (_) {}
        }
      }

      // Filter active allotments strictly matching web_admin
      final rawActiveAllots = allotQuery.where((al) {
        final matNotes = allotMatsRes
            .where((m) => m['allotment_id']?.toString() == al['id']?.toString())
            .map((m) => m['notes']?.toString() ?? '')
            .join(' ');
        final ch = challansQuery.firstWhere(
          (c) => c['id']?.toString() == al['challan_id']?.toString(),
          orElse: () => <String, dynamic>{},
        );
        final prof = profMap[al['lineman_id']?.toString() ?? ''] ?? {};
        final linemanComp = (prof['company_name']?.toString() ?? '').toLowerCase();

        return isTargetMatch([
          ch['brand'],
          ch['notes'],
          al['company_name'],
          linemanComp,
          matNotes,
        ]) ||
        linemanComp.isEmpty ||
        linemanComp == targetComp ||
        (targetComp.isNotEmpty && linemanComp.contains(targetComp));
      }).toList();

      for (var al in rawActiveAllots) {
        final aId = al['article_id']?.toString() ?? '';
        final lId = al['lineman_id']?.toString() ?? '';
        final chId = al['challan_id']?.toString() ?? '';

        final art = artMap[aId] ?? {};
        final prof = profMap[lId] ?? {};
        final ch = challansQuery.firstWhere((c) => c['id']?.toString() == chId, orElse: () => <String, dynamic>{});

        final colPriority = (al['priority'] ?? '').toString().toUpperCase();
        final lotPriority = (colPriority == 'CRITICAL' || colPriority == 'RUSH' || colPriority == 'NORMAL')
            ? colPriority
            : (priorityMap[al['id']?.toString() ?? ''] ?? 'NORMAL');

        // Determine specific assigned colors for this allotment
        final allotVars = variantsRes.where((v) => v['allotment_id']?.toString() == al['id']?.toString()).toList();
        final Set<String> distinctColors = {};
        for (var v in allotVars) {
          if (v['color'] != null && v['color'].toString().trim().isNotEmpty) {
            distinctColors.add(v['color'].toString().trim().toUpperCase());
          }
        }

        String assignedColorLabel = '';
        if (distinctColors.length == 1) {
          assignedColorLabel = '${distinctColors.first} LINE';
        } else if (distinctColors.length > 1) {
          assignedColorLabel = distinctColors.join(', ');
        }

        activeAllotsRes.add({
          'id': al['id'],
          'priority': lotPriority,
          'challan_id': chId,
          'challan_no': ch['challan_no'] ?? al['challan_no'] ?? '-',
          'challans': ch,
          'lineman_id': lId,
          'article_id': aId,
          'target_qty': parseQty(al['target_qty']),
          'allotment_date': al['allotment_date'],
          'status': al['status'],
          'created_at': al['created_at'],
          'profiles': prof,
          'articles': art,
          'assigned_color_label': assignedColorLabel,
          'variants': allotVars,
          'colors': distinctColors.toList(),
        });
      }

      // 1.3 Fetch QC Ready Allotments for Godown Inward Handshake
      List<dynamic> readyQcRes = [];
      List<dynamic> rawReadyQcAllots = [];
      try {
        final qcAllots = await supabase
            .from('allotments')
            .select('*')
            .or('qc_status.eq.APPROVED_FOR_STORE,qc_status.eq.READY_FOR_STORE')
            .neq('store_inward_status', 'INWARDED')
            .order('created_at', ascending: false);

        rawReadyQcAllots = qcAllots.where((al) {
          final matNotes = allotMatsRes
              .where((m) => m['allotment_id']?.toString() == al['id']?.toString())
              .map((m) => m['notes']?.toString() ?? '')
              .join(' ');
          final ch = challansQuery.firstWhere(
            (c) => c['id']?.toString() == al['challan_id']?.toString(),
            orElse: () => <String, dynamic>{},
          );
          final prof = profMap[al['lineman_id']?.toString() ?? ''] ?? {};
          final linemanComp = (prof['company_name']?.toString() ?? '').toLowerCase();

          return isTargetMatch([
            ch['brand'],
            ch['notes'],
            al['company_name'],
            linemanComp,
            matNotes,
          ]) ||
          linemanComp.isEmpty ||
          linemanComp == targetComp ||
          (targetComp.isNotEmpty && linemanComp.contains(targetComp));
        }).toList();

        for (var al in rawReadyQcAllots) {
          final aId = al['article_id']?.toString() ?? '';
          final lId = al['lineman_id']?.toString() ?? '';
          final chId = al['challan_id']?.toString() ?? '';

          final art = artMap[aId] ?? {};
          final prof = profMap[lId] ?? {};
          final ch = challansQuery.firstWhere((c) => c['id']?.toString() == chId, orElse: () => <String, dynamic>{});
          final vars = variantsRes.where((v) => v['allotment_id']?.toString() == al['id']?.toString()).toList();

          final Set<String> colors = {};
          for (var v in vars) {
            if (v['color'] != null && v['color'].toString().trim().isNotEmpty) {
              colors.add(v['color'].toString().trim().toUpperCase());
            }
          }

          final passedQty = parseQty(al['qc_total_passed'], parseQty(al['target_qty']));

          final colPriority = (al['priority'] ?? '').toString().toUpperCase();
          final lotPriority = (colPriority == 'CRITICAL' || colPriority == 'RUSH' || colPriority == 'NORMAL')
              ? colPriority
              : (priorityMap[al['id']?.toString() ?? ''] ?? 'NORMAL');

          readyQcRes.add({
            ...Map<String, dynamic>.from(al),
            'priority': lotPriority,
            'articles': art,
            'profiles': prof,
            'challans': ch,
            'variants': vars,
            'color_name': colors.isNotEmpty ? colors.join(', ') : (al['assigned_color_label'] ?? 'STANDARD'),
            'lineman_name': prof['username'] ?? 'Lineman',
            'mending_name': al['mending_supervisor_name'] ?? 'Mending Floor',
            'qc_name': al['qc_supervisor_name'] ?? 'QC Supervisor',
            'admin_approved_by': al['admin_approved_by'] ?? 'Admin',
            'admin_approved_at': al['admin_approved_at'],
            'qc_passed_qty': passedQty,
            'art_no': art['art_no'] ?? 'Garment',
            'description': art['description'] ?? '',
            'challan_no': ch['challan_no'] ?? al['challan_no'] ?? '-',
          });
        }
      } catch (e) {
        debugPrint('QC Ready allotments fetch warning: $e');
      }

      // Sort both queues by priority queue: CRITICAL (0) -> RUSH (1) -> NORMAL (2)
      int priorityWeight(String p) {
        if (p == 'CRITICAL') return 0;
        if (p == 'RUSH') return 1;
        return 2;
      }

      activeAllotsRes.sort((x, y) {
        final pX = priorityWeight((x['priority'] ?? 'NORMAL').toString());
        final pY = priorityWeight((y['priority'] ?? 'NORMAL').toString());
        if (pX != pY) return pX.compareTo(pY);
        final dtX = DateTime.tryParse(x['created_at']?.toString() ?? '') ?? DateTime(2000);
        final dtY = DateTime.tryParse(y['created_at']?.toString() ?? '') ?? DateTime(2000);
        return dtY.compareTo(dtX);
      });

      readyQcRes.sort((x, y) {
        final pX = priorityWeight((x['priority'] ?? 'NORMAL').toString());
        final pY = priorityWeight((y['priority'] ?? 'NORMAL').toString());
        if (pX != pY) return pX.compareTo(pY);
        final dtX = DateTime.tryParse(x['created_at']?.toString() ?? '') ?? DateTime(2000);
        final dtY = DateTime.tryParse(y['created_at']?.toString() ?? '') ?? DateTime(2000);
        return dtY.compareTo(dtX);
      });

      // 2. Fetch All Store Transactions (for stock calculation & recent feed)
      List<dynamic> txRes = [];
      try {
        txRes = await supabase
            .from('store_transactions')
            .select('''
              id,
              entry_date,
              created_at,
              type,
              quantity,
              party_name,
              color,
              size,
              challan_no,
              transport_no,
              notes,
              allotment_id,
              article:articles ( id, art_no, description )
            ''')
            .order('created_at', ascending: false)
            .limit(300);
      } catch (e) {
        debugPrint('Store transactions fetch warning: $e');
      }

      // 3. Fetch Accessories Transactions
      List<dynamic> accRes = [];
      try {
        accRes = await supabase
            .from('accessories')
            .select('''
              id,
              item_name,
              action,
              quantity,
              unit,
              party_name,
              notes,
              entry_date,
              created_at
            ''')
            .order('created_at', ascending: false)
            .limit(300);
      } catch (e) {
        debugPrint('Accessories fetch warning: $e');
      }

      // 3.1 Fetch Truck Inwards (GRN)
      List<dynamic> truckInwardsRes = [];
      try {
        truckInwardsRes = await supabase
            .from('truck_inwards')
            .select('''
              id,
              grn_no,
              party_name,
              article_no,
              garment_type,
              challan_no,
              inward_date,
              truck_no,
              challan_photo_url,
              receiver_name,
              status,
              total_items,
              due_items_count,
              shortage_items_count,
              notes,
              line_items,
              created_at
            ''')
            .order('created_at', ascending: false)
            .limit(100);
      } catch (e) {
        debugPrint('Truck inwards fetch warning: $e');
      }

      // Multi-tenant Scoping Filters (100% Web Parity)
      final Set<String> validAllotmentIds = {};
      for (var al in rawActiveAllots) {
        validAllotmentIds.add(al['id'].toString());
      }
      for (var al in rawReadyQcAllots) {
        validAllotmentIds.add(al['id'].toString());
      }

      final filteredTx = txRes.where((tx) {
        final aId = tx['allotment_id']?.toString();
        if (aId != null && validAllotmentIds.contains(aId)) return true;
        return isTargetMatch([tx['party_name'], tx['notes'], tx['company_name']]);
      }).toList();

      final filteredAcc = accRes.where((ac) {
        if (isTargetMatch([ac['party_name'], ac['notes'], ac['company_name']])) return true;
        final notes = (ac['notes']?.toString() ?? '');
        for (final id in validAllotmentIds) {
          if (notes.contains(id)) return true;
        }
        return false;
      }).toList();

      final filteredTruckInwards = truckInwardsRes.where((t) {
        return isTargetMatch([t['party_name'], t['receiver_name'], t['notes'], t['company_name']]);
      }).toList();

      // Multi-tenant article scope matching web
      final Set<String> validArticleIds = {};
      final Set<String> validArtNos = {};

      for (var al in rawActiveAllots) {
        final aId = al['article_id']?.toString() ?? '';
        final art = artMap[aId] ?? {};
        final artNo = (art['art_no'] ?? '').toString().trim().toUpperCase();
        if (aId.isNotEmpty) validArticleIds.add(aId);
        if (artNo.isNotEmpty) validArtNos.add(artNo);
      }
      for (var al in rawReadyQcAllots) {
        final aId = al['article_id']?.toString() ?? '';
        final art = artMap[aId] ?? {};
        final artNo = (art['art_no'] ?? '').toString().trim().toUpperCase();
        if (aId.isNotEmpty) validArticleIds.add(aId);
        if (artNo.isNotEmpty) validArtNos.add(artNo);
      }
      for (var t in filteredTruckInwards) {
        final artNo = (t['article_no'] ?? '').toString().trim().toUpperCase();
        if (artNo.isNotEmpty) validArtNos.add(artNo);
      }

      final filteredArticles = articlesRes.where((art) {
        final rates = art['size_rates'];
        String rateComp = '';
        if (rates is Map) {
          rateComp = (rates['company_name']?.toString() ?? rates['_meta']?['company_name']?.toString() ?? '').trim().toLowerCase();
        }
        if (rateComp.isNotEmpty && rateComp == targetComp) return true;
        if (isTargetMatch([art['description']])) return true;
        if (validArticleIds.contains(art['id']?.toString() ?? '')) return true;
        final aNo = (art['art_no'] ?? '').toString().trim().toUpperCase();
        if (aNo.isNotEmpty && validArtNos.contains(aNo)) return true;
        return false;
      }).toList();

      // Natural alphanumeric sort (700, 2953, 3293, 3360, 4510, 4800, 5240, 5252, 5306, 6001...)
      filteredArticles.sort((a, b) {
        final sA = (a['art_no'] ?? '').toString().trim();
        final sB = (b['art_no'] ?? '').toString().trim();
        final numA = int.tryParse(sA.replaceAll(RegExp(r'[^0-9]'), ''));
        final numB = int.tryParse(sB.replaceAll(RegExp(r'[^0-9]'), ''));
        if (numA != null && numB != null && numA != numB) {
          return numA.compareTo(numB);
        }
        return sA.compareTo(sB);
      });

      // 4. Calculate Finished Goods Stock
      int totalIn = 0;
      int totalOut = 0;
      int tOutward = 0;
      final Map<String, int> stockMap = {};
      final Map<String, int> varStockMap = {};

      for (var tx in filteredTx) {
        final qty = parseQty(tx['quantity']);
        final type = tx['type'] as String? ?? 'INWARD';
        final artId = tx['article']?['id'] as String? ?? 'UNKNOWN';
        final color = (tx['color'] as String?)?.toLowerCase().trim() ?? '';
        final size = (tx['size'] as String?)?.toLowerCase().trim() ?? '';
        final varKey = '${artId}_${color}_$size';
        final entryDate = (tx['entry_date'] as String?) ?? (tx['created_at'] != null ? tx['created_at'].toString().split('T')[0] : '');

        if (type == 'INWARD') {
          totalIn += qty;
          stockMap[artId] = (stockMap[artId] ?? 0) + qty;
          varStockMap[varKey] = (varStockMap[varKey] ?? 0) + qty;
        } else if (type == 'OUTWARD') {
          totalOut += qty;
          stockMap[artId] = (stockMap[artId] ?? 0) - qty;
          varStockMap[varKey] = (varStockMap[varKey] ?? 0) - qty;
          if (entryDate == today) tOutward += qty;
        }
      }

      final currentStock = (totalIn - totalOut).clamp(0, 9999999);

      // 5. Calculate Distinct Accessories count
      final Set<String> distinctAcc = {};
      for (var acc in filteredAcc) {
        final name = (acc['item_name'] as String?)?.trim();
        if (name != null && name.isNotEmpty) distinctAcc.add(name);
      }

      // 6. Merge & sort activity logs with Smart BOM Batch Grouping
      final Map<String, Map<String, dynamic>> groupedBOMMap = {};
      final List<Map<String, dynamic>> combinedLogs = [];

      for (var acc in filteredAcc) {
        final notes = (acc['notes']?.toString() ?? '');
        final isBOM = notes.contains('BOM Handover') || notes.contains('BOM Package');

        if (isBOM) {
          final uuidMatch = RegExp(r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}').firstMatch(notes);
          final allotmentId = uuidMatch != null ? uuidMatch.group(0)! : (acc['party_name'] ?? '');

          final chMatch = RegExp(r'Challan #([^\s•]+)').firstMatch(notes);
          final challanStr = chMatch != null ? chMatch.group(1)! : '';

          final createdAt = acc['created_at']?.toString() ?? '';
          final timeMinute = createdAt.length >= 16 ? createdAt.substring(0, 16) : (acc['entry_date']?.toString() ?? '');
          final partyName = acc['party_name']?.toString() ?? 'Issued to Lineman';
          final groupKey = 'BOM_${allotmentId}_${timeMinute}_$partyName';

          final itemName = acc['item_name']?.toString() ?? 'Material Item';
          final qty = parseQty(acc['quantity']);
          final unit = acc['unit']?.toString() ?? 'pcs';

          if (!groupedBOMMap.containsKey(groupKey)) {
            groupedBOMMap[groupKey] = {
              'isGroupedBOM': true,
              'isAccessory': true,
              'id': groupKey,
              'groupKey': groupKey,
              'created_at': acc['created_at'],
              'entry_date': acc['entry_date'],
              'party_name': partyName,
              'challan_no': challanStr,
              'allotment_id': allotmentId,
              'total_items_count': 0,
              'total_units_count': 0,
              'items': <Map<String, dynamic>>[],
              'notes': notes,
            };
          }

          groupedBOMMap[groupKey]!['total_items_count'] = (groupedBOMMap[groupKey]!['total_items_count'] as int) + 1;
          groupedBOMMap[groupKey]!['total_units_count'] = (groupedBOMMap[groupKey]!['total_units_count'] as int) + qty;
          (groupedBOMMap[groupKey]!['items'] as List<Map<String, dynamic>>).add({
            'name': itemName,
            'qty': qty,
            'unit': unit,
          });
        } else {
          combinedLogs.add({
            'isGroupedBOM': false,
            'isAccessory': true,
            'id': acc['id'],
            'created_at': acc['created_at'],
            'entry_date': acc['entry_date'],
            'action': acc['action'],
            'item_name': acc['item_name'],
            'quantity': parseQty(acc['quantity']),
            'unit': acc['unit'] ?? 'pcs',
            'party_name': acc['party_name'],
            'notes': acc['notes'],
          });
        }
      }

      // Add grouped BOM packages
      for (var grouped in groupedBOMMap.values) {
        combinedLogs.add(grouped);
      }

      // Add Garment Inward/Outward Transactions
      for (var tx in filteredTx) {
        combinedLogs.add({
          'isGroupedBOM': false,
          'isAccessory': false,
          'id': tx['id'],
          'created_at': tx['created_at'],
          'entry_date': tx['entry_date'],
          'type': tx['type'],
          'quantity': parseQty(tx['quantity']),
          'art_no': tx['article']?['art_no'] ?? '-',
          'color': tx['color'],
          'size': tx['size'],
          'party_name': tx['party_name'],
          'challan_no': tx['challan_no'],
          'notes': tx['notes'],
        });
      }

      int tTruckCount = 0;
      for (var ti in filteredTruckInwards) {
        final iDate = ti['inward_date']?.toString() ?? '';
        if (iDate == today) tTruckCount++;
      }

      combinedLogs.sort((a, b) {
        final tA = a['created_at']?.toString() ?? '';
        final tB = b['created_at']?.toString() ?? '';
        return tB.compareTo(tA);
      });

      // Build fast O(1) indexing maps
      final Map<String, List<dynamic>> matsByAllot = {};
      for (var m in allotMatsRes) {
        final aId = m['allotment_id']?.toString() ?? '';
        if (aId.isNotEmpty) {
          matsByAllot.putIfAbsent(aId, () => []).add(m);
        }
      }

      final Map<String, bool> allotPending = {};
      for (var al in activeAllotsRes) {
        final aId = al['id']?.toString() ?? '';
        final mats = matsByAllot[aId] ?? [];
        final isPending = mats.isEmpty || mats.any((m) => m['admin_issued'] != true);
        allotPending[aId] = isPending;
      }

      if (mounted) {
        setState(() {
          _articles = filteredArticles;
          _totalFinishedStock = currentStock;
          _todayOutward = tOutward;
          _todayTruckCount = tTruckCount;
          _articleStockMap = stockMap;
          _variantStockMap = varStockMap;
          _allotmentVariants = variantsRes;
          _activeAllotments = activeAllotsRes;
          _allotmentMaterials = allotMatsRes;
          _materialsByAllotmentMap = matsByAllot;
          _allotmentPendingMap = allotPending;
          _readyQcAllotments = readyQcRes;
          _storeLogs = combinedLogs;
          _truckInwards = filteredTruckInwards;
          _accessories = filteredAcc;
          _storeTransactions = filteredTx;
          _challans = challansQuery;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading store data: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ==========================================
  // HELPER METHODS: DYNAMIC VARIANT MATRIX
  // ==========================================
  String _getCleanArticleDescription(String? desc) {
    if (desc == null || desc.trim().isEmpty) return '';
    return desc.replaceAll(RegExp(r'\s*\[.*\]'), '').trim();
  }

  List<String> _getAllotmentIdsForArticle(String? articleId) {
    if (articleId == null) return [];
    for (var art in _articles) {
      if (art['id']?.toString() == articleId.toString()) {
        final desc = (art['description'] as String?) ?? '';
        final match = RegExp(r'\[(.*?)\]').firstMatch(desc);
        if (match != null && match.group(1) != null) {
          return match.group(1)!.split(',').map((s) => s.trim()).toList();
        }
      }
    }
    return [];
  }

  List<Map<String, dynamic>> _getVariantsForArticle(String? articleId) {
    if (articleId == null) return [];
    final allotmentIds = _getAllotmentIdsForArticle(articleId);

    final List<Map<String, dynamic>> result = [];
    for (var v in _allotmentVariants) {
      final vAllotId = v['allotment_id']?.toString();
      if (vAllotId != null && allotmentIds.contains(vAllotId)) {
        result.add({
          'id': v['id'],
          'color': v['color']?.toString() ?? 'Default',
          'size': v['size']?.toString() ?? 'Standard',
          'allotment_qty': v['quantity'] ?? 0,
        });
      }
    }
    return result;
  }

  int _getVariantStock(String articleId, String color, String size) {
    final key = "${articleId}_${color.toLowerCase().trim()}_${size.toLowerCase().trim()}";
    return (_variantStockMap[key] ?? 0).clamp(0, 9999999);
  }

  // ==========================================
  // MODULE 1: INWARD (RECEIVE FINISHED GOODS)
  // ==========================================
  void _showInwardModal({Map<String, dynamic>? prefilledLot}) {
    String? selectedArticleId = prefilledLot?['article_id']?.toString() ?? (_articles.isNotEmpty ? _articles.first['id']?.toString() : null);
    String? selectedAllotmentId = prefilledLot?['id']?.toString();
    String selectedLinemanName = prefilledLot?['lineman_name'] ?? '';
    String selectedMendingName = prefilledLot?['mending_name'] ?? 'Mending Floor';
    String selectedQcName = prefilledLot?['qc_name'] ?? 'QC Supervisor';
    String selectedChallanNo = prefilledLot?['challan_no'] ?? '';
    String selectedColorLabel = prefilledLot?['color_name'] ?? '';

    final authState = ref.read(authProvider);
    final currentStoreUserName = authState.cachedUsername?.trim().isNotEmpty == true 
        ? authState.cachedUsername! 
        : (supabase.auth.currentUser?.email?.split('@').first ?? 'Store Manager');

    final fromController = TextEditingController(text: selectedQcName.isNotEmpty ? 'QC Passed ($selectedQcName)' : 'QC Finishing Floor');
    final notesController = TextEditingController(text: selectedLinemanName.isNotEmpty ? 'Stitched by $selectedLinemanName • Lot $selectedColorLabel' : '');

    // Fallback single controllers if article has no variants
    final fallbackColorController = TextEditingController(text: selectedColorLabel.isNotEmpty ? selectedColorLabel : 'Black');
    final fallbackSizeController = TextEditingController(text: 'L');
    final fallbackQtyController = TextEditingController();

    // Controllers map for each variant: key is variant id or "${color}_${size}"
    final Map<String, TextEditingController> variantControllers = {};

    // If prefilled, pre-populate variant controllers
    if (prefilledLot != null && prefilledLot['variants'] is List) {
      for (var v in prefilledLot['variants']) {
        final key = v['id'] ?? "${v['color']}_${v['size']}";
        variantControllers[key] = TextEditingController(text: (v['quantity'] ?? 0).toString());
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final mediaQuery = MediaQuery.of(context);
          final variants = _getVariantsForArticle(selectedArticleId);

          // Matching Ready Lots from QC Table for this Article
          final matchingReadyLots = _readyQcAllotments.where((lot) => 
            lot['article_id']?.toString() == selectedArticleId?.toString()
          ).toList();

          // Ensure controllers exist for all variants
          for (var v in variants) {
            final key = v['id'] ?? "${v['color']}_${v['size']}";
            variantControllers.putIfAbsent(key, () => TextEditingController());
          }

          // Calculate total pieces to be inwarded
          int totalInwardPieces = 0;
          if (variants.isNotEmpty) {
            for (var v in variants) {
              final key = v['id'] ?? "${v['color']}_${v['size']}";
              final text = variantControllers[key]?.text.trim() ?? '';
              totalInwardPieces += int.tryParse(text) ?? 0;
            }
          } else {
            totalInwardPieces = int.tryParse(fallbackQtyController.text.trim()) ?? 0;
          }

          // Group variants by color
          final Map<String, List<Map<String, dynamic>>> colorGroups = {};
          for (var v in variants) {
            final c = v['color'] ?? 'Default';
            colorGroups.putIfAbsent(c, () => []).add(v);
          }

          return Container(
            constraints: BoxConstraints(
              maxHeight: mediaQuery.size.height * 0.90,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              bottom: mediaQuery.viewInsets.bottom,
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Drag Handle & Fixed Header Bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
                    child: Column(
                      children: [
                        Center(
                          child: Container(
                            width: 38,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppTheme.border,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.steelMist,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.file_download_outlined, color: AppTheme.steel, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Production Inward',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16.5,
                                      color: AppTheme.ink,
                                    ),
                                  ),
                                  Text(
                                    'Receive finished garments into Godown stock',
                                    style: GoogleFonts.publicSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.inkSoft,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: AppTheme.inkSoft, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(height: 1, color: AppTheme.border),

                  // Middle Scrollable Body
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Article Selection
                          Text(
                            'Article (Style #)',
                            style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.ink),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.bg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedArticleId,
                                isExpanded: true,
                                items: _articles.map((art) => DropdownMenuItem<String>(
                                  value: art['id']?.toString(),
                                  child: Text(
                                    '${art['art_no']} (${_getCleanArticleDescription(art['description'])})',
                                    style: GoogleFonts.publicSans(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppTheme.ink),
                                  ),
                                )).toList(),
                                onChanged: (v) {
                                  setModalState(() {
                                    selectedArticleId = v;
                                    selectedAllotmentId = null;
                                    selectedLinemanName = '';
                                    selectedMendingName = 'Mending Floor';
                                    selectedQcName = 'QC Supervisor';
                                    selectedChallanNo = '';
                                    selectedColorLabel = '';
                                    variantControllers.clear();
                                  });
                                },
                              ),
                            ),
                          ),

                          // 1.1 Color / Ready Lot Selector Chips (Multi-Lineman Support)
                          if (matchingReadyLots.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              'Ready Lots from QC Table (Select Lot):',
                              style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.steel),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: matchingReadyLots.map((lot) {
                                final isSelected = selectedAllotmentId == lot['id']?.toString();
                                final clr = lot['color_name'] ?? 'STANDARD';
                                final lName = lot['lineman_name'] ?? 'Lineman';
                                final qPcs = lot['qc_passed_qty'] ?? 0;

                                return InkWell(
                                  onTap: () {
                                    setModalState(() {
                                      selectedAllotmentId = lot['id']?.toString();
                                      selectedLinemanName = lot['lineman_name'] ?? '';
                                      selectedMendingName = lot['mending_name'] ?? 'Mending Floor';
                                      selectedQcName = lot['qc_name'] ?? 'QC Supervisor';
                                      selectedChallanNo = lot['challan_no'] ?? '';
                                      selectedColorLabel = clr;
                                      fromController.text = 'QC Passed ($selectedQcName)';
                                      notesController.text = 'Stitched by $selectedLinemanName • Lot $clr';

                                      // Auto-fill variant controllers for this allotment!
                                      final lotVars = lot['variants'] as List<dynamic>? ?? [];
                                      for (var v in lotVars) {
                                        final key = v['id'] ?? "${v['color']}_${v['size']}";
                                        variantControllers[key]?.text = (v['quantity'] ?? 0).toString();
                                      }
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isSelected ? AppTheme.greenMist : Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isSelected ? AppTheme.green : AppTheme.border,
                                        width: isSelected ? 1.5 : 1.0,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                          size: 14,
                                          color: isSelected ? AppTheme.green : AppTheme.inkSoft,
                                        ),
                                        const SizedBox(width: 6),
                                        Icon(
                                          Icons.person_outline_rounded,
                                          size: 13,
                                          color: isSelected ? AppTheme.green : AppTheme.inkSoft,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$clr ($qPcs pcs) · $lName',
                                          style: GoogleFonts.publicSans(
                                            fontSize: 11.5,
                                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                            color: isSelected ? AppTheme.green : AppTheme.ink,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],

                          const SizedBox(height: 14),

                          // 1.2 PRODUCTION CHAIN OF CUSTODY SUMMARY BOX
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.steelMist,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.steelTint),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.handshake_rounded, size: 16, color: AppTheme.steel),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Production Chain of Custody',
                                      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.steel),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    _buildCustodyChip('Lineman: ${selectedLinemanName.isNotEmpty ? selectedLinemanName : "Floor"}', Icons.person_outline_rounded, AppTheme.steel),
                                    _buildCustodyChip('Mending: ${selectedMendingName.isNotEmpty ? selectedMendingName : "Floor"}', Icons.content_cut_rounded, AppTheme.steel),
                                    _buildCustodyChip('QC: ${selectedQcName.isNotEmpty ? selectedQcName : "Checked"}', Icons.verified_outlined, AppTheme.green),
                                    _buildCustodyChip('Store: $currentStoreUserName', Icons.storefront_outlined, AppTheme.steel),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // 2. LIVE TOTAL INWARD PIECES BANNER
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: totalInwardPieces > 0 ? AppTheme.greenMist : AppTheme.bg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: totalInwardPieces > 0 ? AppTheme.green : AppTheme.border),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.inventory_2_rounded, size: 18, color: totalInwardPieces > 0 ? AppTheme.green : AppTheme.inkSoft),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Total Receiving Quantity:',
                                      style: GoogleFonts.publicSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: totalInwardPieces > 0 ? AppTheme.green : AppTheme.inkSoft,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '$totalInwardPieces pcs',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: totalInwardPieces > 0 ? AppTheme.green : AppTheme.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // 3. COLOR & SIZE QUANTITY MATRIX
                          if (variants.isNotEmpty) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Size & Color Quantity Matrix',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.ink),
                                ),
                                TextButton.icon(
                                  onPressed: () {
                                    setModalState(() {
                                      for (var v in variants) {
                                        final key = v['id'] ?? "${v['color']}_${v['size']}";
                                        variantControllers[key]?.text = (v['allotment_qty'] ?? 0).toString();
                                      }
                                    });
                                  },
                                  icon: const Icon(Icons.flash_on_rounded, size: 14, color: AppTheme.steel),
                                  label: Text(
                                    'Fill Allotment Ratio',
                                    style: GoogleFonts.publicSans(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.steel),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Color cards
                            ...colorGroups.entries.map((cg) {
                              final colorName = cg.key;
                              final vList = cg.value;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.bg,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppTheme.border),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 10,
                                          height: 10,
                                          decoration: const BoxDecoration(color: AppTheme.steel, shape: BoxShape.circle),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(colorName, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13.5, color: AppTheme.ink)),
                                      ],
                                    ),
                                    const SizedBox(height: 10),

                                    // Grid of sizes with quantity text field
                                    ...vList.map((item) {
                                      final key = item['id'] ?? "${item['color']}_${item['size']}";
                                      final currentGodownStock = selectedArticleId != null
                                          ? _getVariantStock(selectedArticleId!, item['color'], item['size'])
                                          : 0;

                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: AppTheme.border),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Size ${item['size']}',
                                                    style: GoogleFonts.publicSans(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.ink),
                                                  ),
                                                  Text(
                                                    'Godown Stock: $currentGodownStock pcs · Allotted: ${item['allotment_qty'] ?? 0} pcs',
                                                    style: GoogleFonts.publicSans(fontSize: 10.5, color: AppTheme.inkSoft),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            SizedBox(
                                              width: 90,
                                              height: 40,
                                              child: TextField(
                                                controller: variantControllers[key],
                                                keyboardType: TextInputType.number,
                                                textAlign: TextAlign.center,
                                                style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.ink),
                                                decoration: InputDecoration(
                                                  hintText: '0',
                                                  filled: true,
                                                  fillColor: AppTheme.bg,
                                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
                                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
                                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.steel, width: 1.5)),
                                                ),
                                                onChanged: (_) => setModalState(() {}),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              );
                            }),
                          ] else ...[
                            // Fallback single inputs if article has no registered variants
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: fallbackColorController,
                                    decoration: InputDecoration(
                                      labelText: 'Color',
                                      filled: true,
                                      fillColor: AppTheme.bg,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: fallbackSizeController,
                                    decoration: InputDecoration(
                                      labelText: 'Size',
                                      filled: true,
                                      fillColor: AppTheme.bg,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: fallbackQtyController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: 'Qty (pcs)',
                                      filled: true,
                                      fillColor: AppTheme.bg,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                                    ),
                                    onChanged: (_) => setModalState(() {}),
                                  ),
                                ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 14),

                          // 4. Source & Notes
                          Text(
                            'Received From',
                            style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.ink),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: fromController,
                            style: GoogleFonts.publicSans(fontSize: 13, color: AppTheme.ink),
                            decoration: InputDecoration(
                              hintText: 'e.g. QC Finishing Floor',
                              filled: true,
                              fillColor: AppTheme.bg,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                            ),
                          ),
                          const SizedBox(height: 12),

                          Text(
                            'Notes (Optional)',
                            style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.ink),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: notesController,
                            style: GoogleFonts.publicSans(fontSize: 13, color: AppTheme.ink),
                            decoration: InputDecoration(
                              hintText: 'Remarks (e.g. Lot #12 / Batch 3 Final QC)',
                              filled: true,
                              fillColor: AppTheme.bg,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),

                  // Fixed Bottom Action Bar (pinned)
                  Container(height: 1, color: AppTheme.border),
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    color: Colors.white,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 88,
                          height: 48,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              side: const BorderSide(color: AppTheme.border),
                              padding: EdgeInsets.zero,
                            ),
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.publicSans(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.inkSoft,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: totalInwardPieces <= 0
                                  ? null
                                  : () async {
                                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                                      Navigator.pop(ctx);
                                      try {
                                        final todayStr = DateTime.now().toIso8601String().split('T')[0];
                                        final List<Map<String, dynamic>> rowsToInsert = [];

                                        if (variants.isNotEmpty) {
                                          for (var v in variants) {
                                            final key = v['id'] ?? "${v['color']}_${v['size']}";
                                            final qty = int.tryParse(variantControllers[key]?.text.trim() ?? '') ?? 0;
                                            if (qty > 0) {
                                              rowsToInsert.add({
                                                'article_id': selectedArticleId,
                                                'type': 'INWARD',
                                                'quantity': qty,
                                                'color': v['color'],
                                                'size': v['size'],
                                                'party_name': fromController.text.trim().isEmpty ? 'QC Finishing Floor' : fromController.text.trim(),
                                                'lineman_name': selectedLinemanName.isNotEmpty ? selectedLinemanName : null,
                                                'mending_name': selectedMendingName.isNotEmpty ? selectedMendingName : null,
                                                'qc_supervisor_name': selectedQcName.isNotEmpty ? selectedQcName : null,
                                                'receiver_name': currentStoreUserName,
                                                'challan_no': selectedChallanNo.isNotEmpty ? selectedChallanNo : null,
                                                'allotment_id': selectedAllotmentId,
                                                'notes': notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                                                'entry_date': todayStr,
                                              });
                                            }
                                          }
                                        } else {
                                          final qty = int.tryParse(fallbackQtyController.text.trim()) ?? 0;
                                          rowsToInsert.add({
                                            'article_id': selectedArticleId,
                                            'type': 'INWARD',
                                            'quantity': qty,
                                            'color': fallbackColorController.text.trim(),
                                            'size': fallbackSizeController.text.trim(),
                                            'party_name': fromController.text.trim().isEmpty ? 'QC Finishing Floor' : fromController.text.trim(),
                                            'lineman_name': selectedLinemanName.isNotEmpty ? selectedLinemanName : null,
                                            'mending_name': selectedMendingName.isNotEmpty ? selectedMendingName : null,
                                            'qc_supervisor_name': selectedQcName.isNotEmpty ? selectedQcName : null,
                                            'receiver_name': currentStoreUserName,
                                            'challan_no': selectedChallanNo.isNotEmpty ? selectedChallanNo : null,
                                            'allotment_id': selectedAllotmentId,
                                            'notes': notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                                            'entry_date': todayStr,
                                          });
                                        }

                                        if (rowsToInsert.isNotEmpty) {
                                          await supabase.from('store_transactions').insert(rowsToInsert);

                                          // Mark allotment store inward complete
                                          if (selectedAllotmentId != null && selectedAllotmentId!.isNotEmpty) {
                                            try {
                                              await supabase.from('allotments').update({
                                                'store_inward_status': 'INWARDED',
                                                'store_inward_at': DateTime.now().toIso8601String(),
                                                'store_receiver_name': currentStoreUserName,
                                              }).eq('id', selectedAllotmentId!);
                                            } catch (_) {}
                                          }

                                          scaffoldMessenger.showSnackBar(
                                            SnackBar(
                                              content: Text('Inwarded $totalInwardPieces pcs to Godown! Chain of Custody logged.'),
                                              backgroundColor: AppTheme.steel,
                                            ),
                                          );
                                          _fetchStoreData();
                                        }
                                      } catch (e) {
                                        scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.steel,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.check_circle_outline_rounded, size: 18),
                                  const SizedBox(width: 6),
                                  Text(
                                    totalInwardPieces > 0 ? 'Save Inward' : 'Enter Quantity',
                                    style: GoogleFonts.publicSans(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  if (totalInwardPieces > 0) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.22),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '$totalInwardPieces pcs',
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCustodyChip(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // MODULE 2: OUTWARD (DISPATCH GOODS) - MULTI-VARIANT
  // ==========================================
  void _showOutwardModal() {
    String? selectedArticleId = _articles.isNotEmpty ? _articles.first['id']?.toString() : null;
    final buyerController = TextEditingController();
    final challanController = TextEditingController();
    final notesController = TextEditingController();

    final fallbackColorController = TextEditingController(text: 'Black');
    final fallbackSizeController = TextEditingController(text: 'L');
    final fallbackQtyController = TextEditingController();

    final Map<String, TextEditingController> variantControllers = {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final mediaQuery = MediaQuery.of(context);
          final variants = _getVariantsForArticle(selectedArticleId);
          final totalAvailArticleStock = selectedArticleId != null ? (_articleStockMap[selectedArticleId] ?? 0) : 0;

          for (var v in variants) {
            final key = v['id'] ?? "${v['color']}_${v['size']}";
            variantControllers.putIfAbsent(key, () => TextEditingController());
          }

          // Calculate total dispatch pieces
          int totalDispatchPieces = 0;
          if (variants.isNotEmpty) {
            for (var v in variants) {
              final key = v['id'] ?? "${v['color']}_${v['size']}";
              final text = variantControllers[key]?.text.trim() ?? '';
              totalDispatchPieces += int.tryParse(text) ?? 0;
            }
          } else {
            totalDispatchPieces = int.tryParse(fallbackQtyController.text.trim()) ?? 0;
          }

          // Group variants by color
          final Map<String, List<Map<String, dynamic>>> colorGroups = {};
          for (var v in variants) {
            final c = v['color'] ?? 'Default';
            colorGroups.putIfAbsent(c, () => []).add(v);
          }

          return Container(
            constraints: BoxConstraints(
              maxHeight: mediaQuery.size.height * 0.90,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              bottom: mediaQuery.viewInsets.bottom,
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Drag Handle & Fixed Header Bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
                    child: Column(
                      children: [
                        Center(
                          child: Container(
                            width: 38,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppTheme.border,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.steelMist,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.file_upload_outlined, color: AppTheme.steel, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Finished Goods Outward',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16.5,
                                      color: AppTheme.ink,
                                    ),
                                  ),
                                  Text(
                                    'Issue garments from Godown for delivery',
                                    style: GoogleFonts.publicSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.inkSoft,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: AppTheme.inkSoft, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(height: 1, color: AppTheme.border),

                  // Middle Scrollable Body
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Article Selection
                          Text(
                            'Article (Style #)',
                            style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.ink),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.bg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedArticleId,
                                isExpanded: true,
                                items: _articles.map((art) => DropdownMenuItem<String>(
                                  value: art['id'],
                                  child: Text(
                                    '${art['art_no']} (${_getCleanArticleDescription(art['description'])})',
                                    style: GoogleFonts.publicSans(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppTheme.ink),
                                  ),
                                )).toList(),
                                onChanged: (v) {
                                  setModalState(() {
                                    selectedArticleId = v;
                                    variantControllers.clear();
                                  });
                                },
                              ),
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Article Godown Stock Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: totalAvailArticleStock > 0 ? AppTheme.steelMist : AppTheme.redMist,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: totalAvailArticleStock > 0 ? AppTheme.steelTint : AppTheme.red),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  totalAvailArticleStock > 0 ? Icons.inventory_2_rounded : Icons.warning_amber_rounded,
                                  size: 15,
                                  color: totalAvailArticleStock > 0 ? AppTheme.steel : AppTheme.red,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Total in Godown: $totalAvailArticleStock pcs',
                                  style: GoogleFonts.publicSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: totalAvailArticleStock > 0 ? AppTheme.steel : AppTheme.red,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 14),

                          // 2. LIVE TOTAL DISPATCH PIECES BANNER
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: totalDispatchPieces > 0 ? AppTheme.steelMist : AppTheme.bg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: totalDispatchPieces > 0 ? AppTheme.steel : AppTheme.border),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.local_shipping_rounded, size: 18, color: totalDispatchPieces > 0 ? AppTheme.steel : AppTheme.inkSoft),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Total Dispatch Quantity:',
                                      style: GoogleFonts.publicSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: totalDispatchPieces > 0 ? AppTheme.steel : AppTheme.inkSoft,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '$totalDispatchPieces pcs',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: totalDispatchPieces > 0 ? AppTheme.steel : AppTheme.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // 3. COLOR & SIZE DISPATCH MATRIX
                          if (variants.isNotEmpty) ...[
                            Text(
                              'Size & Color Dispatch Matrix',
                              style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.ink),
                            ),
                            const SizedBox(height: 8),

                            ...colorGroups.entries.map((cg) {
                              final colorName = cg.key;
                              final vList = cg.value;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.bg,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppTheme.border),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 10,
                                          height: 10,
                                          decoration: const BoxDecoration(color: AppTheme.steel, shape: BoxShape.circle),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(colorName, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13.5, color: AppTheme.ink)),
                                      ],
                                    ),
                                    const SizedBox(height: 10),

                                    ...vList.map((item) {
                                      final key = item['id'] ?? "${item['color']}_${item['size']}";
                                      final currentGodownStock = selectedArticleId != null
                                          ? _getVariantStock(selectedArticleId!, item['color'], item['size'])
                                          : 0;

                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: AppTheme.border),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(color: AppTheme.steelMist, borderRadius: BorderRadius.circular(6)),
                                              child: Text(
                                                item['size'],
                                                style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w800, fontSize: 12.5, color: AppTheme.steel),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                'In Godown: $currentGodownStock pcs',
                                                style: GoogleFonts.publicSans(fontSize: 12, color: AppTheme.inkSoft),
                                              ),
                                            ),
                                            SizedBox(
                                              width: 90,
                                              height: 38,
                                              child: TextField(
                                                controller: variantControllers[key],
                                                keyboardType: TextInputType.number,
                                                textAlign: TextAlign.center,
                                                style: GoogleFonts.jetBrainsMono(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppTheme.ink),
                                                decoration: InputDecoration(
                                                  hintText: '0',
                                                  hintStyle: GoogleFonts.jetBrainsMono(color: AppTheme.inkFaint),
                                                  contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                                  filled: true,
                                                  fillColor: AppTheme.bg,
                                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
                                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
                                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.steel, width: 1.5)),
                                                ),
                                                onChanged: (_) => setModalState(() {}),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              );
                            }),
                          ] else ...[
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: fallbackColorController,
                                    decoration: InputDecoration(
                                      labelText: 'Color',
                                      filled: true,
                                      fillColor: AppTheme.bg,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: fallbackSizeController,
                                    decoration: InputDecoration(
                                      labelText: 'Size',
                                      filled: true,
                                      fillColor: AppTheme.bg,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: fallbackQtyController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: 'Qty (pcs)',
                                      filled: true,
                                      fillColor: AppTheme.bg,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                                    ),
                                    onChanged: (_) => setModalState(() {}),
                                  ),
                                ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 14),

                          // 4. Buyer, Challan & Notes
                          Text(
                            'Buyer / Delivery To',
                            style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.ink),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: buyerController,
                            style: GoogleFonts.publicSans(fontSize: 13, color: AppTheme.ink),
                            decoration: InputDecoration(
                              hintText: 'Enter buyer / consignee name',
                              filled: true,
                              fillColor: AppTheme.bg,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                            ),
                          ),
                          const SizedBox(height: 12),

                          Text(
                            'Challan / Invoice #',
                            style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.ink),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: challanController,
                            style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.ink),
                            decoration: InputDecoration(
                              hintText: 'e.g. CH-2026-99',
                              filled: true,
                              fillColor: AppTheme.bg,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                            ),
                          ),
                          const SizedBox(height: 12),

                          Text(
                            'Dispatch Notes (Optional)',
                            style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.ink),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: notesController,
                            style: GoogleFonts.publicSans(fontSize: 13, color: AppTheme.ink),
                            decoration: InputDecoration(
                              hintText: 'Remarks (e.g. Transporter VRL • 5 master cartons)',
                              filled: true,
                              fillColor: AppTheme.bg,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),

                  // Fixed Bottom Action Bar (pinned)
                  Container(height: 1, color: AppTheme.border),
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    color: Colors.white,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 88,
                          height: 48,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              side: const BorderSide(color: AppTheme.border),
                              padding: EdgeInsets.zero,
                            ),
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.publicSans(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.inkSoft,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: totalDispatchPieces <= 0
                                  ? null
                                  : () async {
                                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                                      Navigator.pop(ctx);
                                      try {
                                        final todayStr = DateTime.now().toIso8601String().split('T')[0];
                                        final List<Map<String, dynamic>> rowsToInsert = [];

                                        if (variants.isNotEmpty) {
                                          for (var v in variants) {
                                            final key = v['id'] ?? "${v['color']}_${v['size']}";
                                            final qty = int.tryParse(variantControllers[key]?.text.trim() ?? '') ?? 0;
                                            if (qty > 0) {
                                              rowsToInsert.add({
                                                'article_id': selectedArticleId,
                                                'type': 'OUTWARD',
                                                'quantity': qty,
                                                'color': v['color'],
                                                'size': v['size'],
                                                'party_name': buyerController.text.trim().isEmpty ? 'General Dispatch' : buyerController.text.trim(),
                                                'challan_no': challanController.text.trim().isEmpty ? null : challanController.text.trim(),
                                                'notes': notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                                                'entry_date': todayStr,
                                              });
                                            }
                                          }
                                        } else {
                                          final qty = int.tryParse(fallbackQtyController.text.trim()) ?? 0;
                                          rowsToInsert.add({
                                            'article_id': selectedArticleId,
                                            'type': 'OUTWARD',
                                            'quantity': qty,
                                            'color': fallbackColorController.text.trim(),
                                            'size': fallbackSizeController.text.trim(),
                                            'party_name': buyerController.text.trim().isEmpty ? 'General Dispatch' : buyerController.text.trim(),
                                            'challan_no': challanController.text.trim().isEmpty ? null : challanController.text.trim(),
                                            'notes': notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                                            'entry_date': todayStr,
                                          });
                                        }

                                        if (rowsToInsert.isNotEmpty) {
                                          await supabase.from('store_transactions').insert(rowsToInsert);
                                          scaffoldMessenger.showSnackBar(
                                            SnackBar(
                                              content: Text('Dispatched $totalDispatchPieces pcs across ${rowsToInsert.length} variants from Godown!'),
                                              backgroundColor: AppTheme.steel,
                                            ),
                                          );
                                          _fetchStoreData();
                                        }
                                      } catch (e) {
                                        scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.steel,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.check_circle_outline_rounded, size: 18),
                                  const SizedBox(width: 6),
                                  Text(
                                    totalDispatchPieces > 0 ? 'Dispatch Goods' : 'Enter Quantity',
                                    style: GoogleFonts.publicSans(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  if (totalDispatchPieces > 0) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.22),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '$totalDispatchPieces pcs',
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ==========================================
  void _showPhotoViewerModal(String photoUrl, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                child: InteractiveViewer(
                  maxScale: 4.0,
                  child: photoUrl.startsWith('data:image')
                      ? Image.memory(
                          base64Decode(photoUrl.split(',').last),
                          fit: BoxFit.contain,
                        )
                      : Image.network(
                          photoUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Padding(
                            padding: EdgeInsets.all(40),
                            child: Center(
                              child: Text('Failed to load challan image', style: TextStyle(color: Colors.white70)),
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAccessoryChallanInwardModal() {
    final partyController = TextEditingController();
    final articleController = TextEditingController(text: _articles.isNotEmpty ? _articles.first['art_no']?.toString() : '');
    final challanNoController = TextEditingController();
    final truckNoController = TextEditingController();
    final notesController = TextEditingController();
    DateTime inwardDate = DateTime.now();
    File? selectedImage;
    bool isSubmitting = false;

    // Start with empty items list (Store Manager adds items via presets or Custom button)
    final List<_AccessoryChallanItem> items = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final mediaQuery = MediaQuery.of(context);
          final picker = ImagePicker();

          Future<void> pickChallanImage(ImageSource source) async {
            try {
              final picked = await picker.pickImage(source: source, imageQuality: 80, maxWidth: 1600);
              if (picked != null) {
                setModalState(() {
                  selectedImage = File(picked.path);
                });
              }
            } catch (e) {
              debugPrint('Image pick error: $e');
            }
          }

          int receivedCount = items.where((i) => i.status == 'RECEIVED').length;
          int shortageCount = items.where((i) => i.status == 'SHORTAGE').length;
          int dueCount = items.where((i) => i.status == 'DUE').length;

          return Container(
            constraints: BoxConstraints(
              maxHeight: mediaQuery.size.height * 0.90,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              bottom: mediaQuery.viewInsets.bottom,
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Drag Handle & Fixed Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
                    child: Column(
                      children: [
                        Center(
                          child: Container(
                            width: 38,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppTheme.border,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.steelMist,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.receipt_long_outlined, color: AppTheme.steel, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Accessory Challan Inward',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16.5,
                                      color: AppTheme.ink,
                                    ),
                                  ),
                                  Text(
                                    'Supplier Delivery Slip • Trims & Fabrics',
                                    style: GoogleFonts.publicSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.inkSoft,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: AppTheme.inkSoft, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(height: 1, color: AppTheme.border),

                  // Middle Scrollable Form Body
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // SECTION 1: SUPPLIER & SLIP DETAILS
                          Text(
                            'Consolidated Supplier / Consignor (Optional)',
                            style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.ink),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: partyController,
                            style: GoogleFonts.publicSans(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppTheme.ink),
                            decoration: InputDecoration(
                              hintText: 'e.g. Multi-Vendor / Sourced / Transporter',
                              hintStyle: GoogleFonts.publicSans(fontSize: 13, color: AppTheme.inkFaint),
                              prefixIcon: const Icon(Icons.business_rounded, size: 18, color: AppTheme.inkSoft),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              filled: true,
                              fillColor: AppTheme.bg,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.steel, width: 1.5)),
                            ),
                          ),
                          const SizedBox(height: 14),

                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Article No', style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.ink)),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: articleController,
                                      style: GoogleFonts.jetBrainsMono(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppTheme.ink),
                                      decoration: InputDecoration(
                                        hintText: 'e.g. 9433B',
                                        hintStyle: GoogleFonts.publicSans(fontSize: 13, color: AppTheme.inkFaint),
                                        prefixIcon: const Icon(Icons.style_rounded, size: 18, color: AppTheme.inkSoft),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                        filled: true,
                                        fillColor: AppTheme.bg,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.steel, width: 1.5)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Challan / Slip # *', style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.ink)),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: challanNoController,
                                      style: GoogleFonts.jetBrainsMono(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppTheme.ink),
                                      decoration: InputDecoration(
                                        hintText: 'e.g. 102 / Slip #',
                                        hintStyle: GoogleFonts.publicSans(fontSize: 13, color: AppTheme.inkFaint),
                                        prefixIcon: const Icon(Icons.numbers_rounded, size: 18, color: AppTheme.inkSoft),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                        filled: true,
                                        fillColor: AppTheme.bg,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.steel, width: 1.5)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Receipt Date', style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.ink)),
                                    const SizedBox(height: 6),
                                    InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () async {
                                        final picked = await showDatePicker(
                                          context: context,
                                          initialDate: inwardDate,
                                          firstDate: DateTime(2024),
                                          lastDate: DateTime(2030),
                                        );
                                        if (picked != null) {
                                          setModalState(() => inwardDate = picked);
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: AppTheme.bg,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: AppTheme.border),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.calendar_today_rounded, size: 16, color: AppTheme.inkSoft),
                                            const SizedBox(width: 8),
                                            Text(
                                              '${inwardDate.year}-${inwardDate.month.toString().padLeft(2, '0')}-${inwardDate.day.toString().padLeft(2, '0')}',
                                              style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.ink),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Truck / Vehicle #', style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.ink)),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: truckNoController,
                                      style: GoogleFonts.publicSans(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppTheme.ink),
                                      decoration: InputDecoration(
                                        hintText: 'Optional',
                                        hintStyle: GoogleFonts.publicSans(fontSize: 13, color: AppTheme.inkFaint),
                                        prefixIcon: const Icon(Icons.local_shipping_rounded, size: 18, color: AppTheme.inkSoft),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                        filled: true,
                                        fillColor: AppTheme.bg,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.steel, width: 1.5)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // SECTION 2: FORMATTED QUICK PRESET TRIMS (2-COLUMN GRID WITH SELECTION STATE)
                          Text(
                            'Quick Add Trims & Fabrics',
                            style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.ink),
                          ),
                          const SizedBox(height: 10),
                          Builder(
                            builder: (context) {
                              const quickTrims = [
                                {'name': 'Satin Label', 'unit': 'pcs', 'size': 'L/XXL'},
                                {'name': 'Main Neck Label', 'unit': 'pcs', 'size': ''},
                                {'name': 'Wash Care Label', 'unit': 'pcs', 'size': ''},
                                {'name': 'Brand Logo', 'unit': 'pcs', 'size': ''},
                                {'name': 'Chest Patch', 'unit': 'pcs', 'size': ''},
                                {'name': 'Neck Tape', 'unit': 'mt', 'size': ''},
                                {'name': 'Sewing Thread', 'unit': 'cones', 'size': ''},
                                {'name': 'Fabric Sinker Roll', 'unit': 'kg', 'size': ''},
                                {'name': 'Master Polybag', 'unit': 'pcs', 'size': ''},
                                {'name': 'Elastic / Rib', 'unit': 'pcs', 'size': ''},
                              ];

                              return Column(
                                children: [
                                  for (int i = 0; i < quickTrims.length; i += 2) ...[
                                    if (i > 0) const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        for (int j = 0; j < 2; j++) ...[
                                          if (j > 0) const SizedBox(width: 8),
                                          if (i + j < quickTrims.length) ...[
                                            Expanded(
                                              child: Builder(
                                                builder: (context) {
                                                  final trim = quickTrims[i + j];
                                                  final count = items.where((it) => it.nameController.text.trim().toLowerCase() == trim['name']!.toLowerCase()).length;
                                                  final isAdded = count > 0;
                                                  return InkWell(
                                                    borderRadius: BorderRadius.circular(10),
                                                    onTap: () {
                                                      setModalState(() {
                                                        items.add(_AccessoryChallanItem(
                                                          name: trim['name']!,
                                                          unit: trim['unit']!,
                                                          size: trim['size']!,
                                                          status: 'RECEIVED',
                                                        ));
                                                      });
                                                    },
                                                    onLongPress: isAdded
                                                        ? () {
                                                            setModalState(() {
                                                              final lastIdx = items.lastIndexWhere((it) => it.nameController.text.trim().toLowerCase() == trim['name']!.toLowerCase());
                                                              if (lastIdx != -1) items.removeAt(lastIdx);
                                                            });
                                                          }
                                                        : null,
                                                    child: AnimatedContainer(
                                                      duration: const Duration(milliseconds: 180),
                                                      height: 40,
                                                      padding: const EdgeInsets.symmetric(horizontal: 9),
                                                      decoration: BoxDecoration(
                                                        color: isAdded ? AppTheme.steelMist : AppTheme.bg,
                                                        borderRadius: BorderRadius.circular(10),
                                                        border: Border.all(
                                                          color: isAdded ? AppTheme.steel : AppTheme.border,
                                                          width: isAdded ? 1.5 : 1,
                                                        ),
                                                        boxShadow: isAdded
                                                            ? [
                                                                BoxShadow(
                                                                  color: AppTheme.steel.withValues(alpha: 0.10),
                                                                  blurRadius: 4,
                                                                  offset: const Offset(0, 1.5),
                                                                ),
                                                              ]
                                                            : null,
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                            isAdded ? Icons.add_circle_rounded : Icons.add_rounded,
                                                            size: 15,
                                                            color: isAdded ? AppTheme.steel : AppTheme.inkSoft,
                                                          ),
                                                          const SizedBox(width: 5),
                                                          Expanded(
                                                            child: Text(
                                                              trim['name']!,
                                                              style: GoogleFonts.publicSans(
                                                                fontSize: 11.5,
                                                                fontWeight: isAdded ? FontWeight.w700 : FontWeight.w600,
                                                                color: isAdded ? AppTheme.steel : AppTheme.ink,
                                                              ),
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ),
                                                          if (isAdded) ...[
                                                            const SizedBox(width: 4),
                                                            Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                              decoration: BoxDecoration(
                                                                color: AppTheme.steel,
                                                                borderRadius: BorderRadius.circular(8),
                                                              ),
                                                              child: Text(
                                                                '×$count',
                                                                style: GoogleFonts.jetBrainsMono(
                                                                  fontSize: 10.5,
                                                                  fontWeight: FontWeight.w800,
                                                                  color: Colors.white,
                                                                  letterSpacing: -0.3,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ] else ...[
                                            const Expanded(child: SizedBox()),
                                          ],
                                        ],
                                      ],
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 20),

                          // SECTION 3: LINE ITEMS LIST
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Challan Items (${items.length})',
                                style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppTheme.ink),
                              ),
                              TextButton.icon(
                                onPressed: () {
                                  setModalState(() {
                                    items.add(_AccessoryChallanItem(name: 'New Trim Item', status: 'RECEIVED'));
                                  });
                                },
                                icon: const Icon(Icons.add_circle_outline_rounded, size: 16, color: AppTheme.steel),
                                label: Text(
                                  'Add Custom Item',
                                  style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.steel),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),

                          if (items.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppTheme.bg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: Center(
                                child: Text(
                                  'No items added yet. Tap quick presets above or Add Custom Item.',
                                  style: GoogleFonts.publicSans(fontSize: 12.5, color: AppTheme.inkSoft),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          else
                            ...items.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final item = entry.value;
                              final isReceived = item.status == 'RECEIVED';
                              final isShortage = item.status == 'SHORTAGE';
                              final isDue = item.status == 'DUE';

                              Color cardBorder = AppTheme.border;
                              Color cardBg = AppTheme.card;
                              if (isShortage) {
                                cardBg = AppTheme.amberMist;
                                cardBorder = AppTheme.amber;
                              } else if (isDue) {
                                cardBg = AppTheme.steelMist;
                                cardBorder = AppTheme.steel;
                              }

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: cardBorder),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Item name and Delete
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: item.nameController,
                                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13.5, color: AppTheme.ink),
                                            decoration: InputDecoration(
                                              isDense: true,
                                              hintText: 'Item Description',
                                              hintStyle: GoogleFonts.publicSans(color: AppTheme.inkFaint),
                                              border: InputBorder.none,
                                              contentPadding: EdgeInsets.zero,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.red),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () {
                                            setModalState(() {
                                              items.removeAt(idx);
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),

                                    // Quantity, Unit & Size row
                                    Row(
                                      children: [
                                        Expanded(
                                          flex: 2,
                                          child: TextField(
                                            controller: item.qtyController,
                                            keyboardType: TextInputType.number,
                                            style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.ink),
                                            decoration: InputDecoration(
                                              labelText: 'Challan Qty',
                                              labelStyle: GoogleFonts.publicSans(fontSize: 11, color: AppTheme.inkSoft),
                                              isDense: true,
                                              filled: true,
                                              fillColor: Colors.white,
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
                                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          flex: 2,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: AppTheme.border),
                                            ),
                                            child: DropdownButtonHideUnderline(
                                              child: DropdownButton<String>(
                                                value: item.unit,
                                                isDense: true,
                                                isExpanded: true,
                                                items: ['pcs', 'cones', 'kg', 'mt', 'rolls', 'gross'].map((u) => DropdownMenuItem(
                                                  value: u,
                                                  child: Text(u, style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.ink)),
                                                )).toList(),
                                                onChanged: (v) {
                                                  if (v != null) {
                                                    setModalState(() => item.unit = v);
                                                  }
                                                },
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          flex: 2,
                                          child: TextField(
                                            controller: item.sizeController,
                                            style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.ink),
                                            decoration: InputDecoration(
                                              labelText: 'Size / Color',
                                              labelStyle: GoogleFonts.publicSans(fontSize: 11, color: AppTheme.inkSoft),
                                              isDense: true,
                                              filled: true,
                                              fillColor: Colors.white,
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
                                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),

                                    // Vendor override & Unit Rate row
                                    Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: TextField(
                                            controller: item.vendorController,
                                            style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.ink),
                                            decoration: InputDecoration(
                                              labelText: 'Vendor (e.g. YKK / Vardhman)',
                                              hintText: 'Leave blank to use supplier',
                                              labelStyle: GoogleFonts.publicSans(fontSize: 11, color: AppTheme.inkSoft),
                                              isDense: true,
                                              filled: true,
                                              fillColor: Colors.white,
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
                                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          flex: 2,
                                          child: TextField(
                                            controller: item.priceController,
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.ink),
                                            decoration: InputDecoration(
                                              labelText: 'Rate (₹/unit)',
                                              hintText: '0.00',
                                              labelStyle: GoogleFonts.publicSans(fontSize: 11, color: AppTheme.inkSoft),
                                              isDense: true,
                                              filled: true,
                                              fillColor: Colors.white,
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
                                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),

                                    // Verification Status Pills
                                    Row(
                                      children: [
                                        Expanded(
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(8),
                                            onTap: () => setModalState(() => item.status = 'RECEIVED'),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(vertical: 7),
                                              decoration: BoxDecoration(
                                                color: isReceived ? AppTheme.green : AppTheme.bg,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: isReceived ? AppTheme.green : AppTheme.border),
                                              ),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(Icons.check_circle_rounded, size: 14, color: isReceived ? Colors.white : AppTheme.inkSoft),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'Received',
                                                    style: GoogleFonts.publicSans(
                                                      fontSize: 11.5,
                                                      fontWeight: FontWeight.w700,
                                                      color: isReceived ? Colors.white : AppTheme.inkSoft,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(8),
                                            onTap: () => setModalState(() => item.status = 'SHORTAGE'),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(vertical: 7),
                                              decoration: BoxDecoration(
                                                color: isShortage ? AppTheme.amber : AppTheme.bg,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: isShortage ? AppTheme.amber : AppTheme.border),
                                              ),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(Icons.warning_amber_rounded, size: 14, color: isShortage ? Colors.white : AppTheme.inkSoft),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'Shortage',
                                                    style: GoogleFonts.publicSans(
                                                      fontSize: 11.5,
                                                      fontWeight: FontWeight.w700,
                                                      color: isShortage ? Colors.white : AppTheme.inkSoft,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(8),
                                            onTap: () => setModalState(() => item.status = 'DUE'),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(vertical: 7),
                                              decoration: BoxDecoration(
                                                color: isDue ? AppTheme.steel : AppTheme.bg,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: isDue ? AppTheme.steel : AppTheme.border),
                                              ),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(Icons.pending_actions_rounded, size: 14, color: isDue ? Colors.white : AppTheme.inkSoft),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'Due',
                                                    style: GoogleFonts.publicSans(
                                                      fontSize: 11.5,
                                                      fontWeight: FontWeight.w700,
                                                      color: isDue ? Colors.white : AppTheme.inkSoft,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    // If Shortage or Due, show shortage missing qty
                                    if (isShortage) ...[
                                      const SizedBox(height: 8),
                                      TextField(
                                        controller: item.shortageController,
                                        keyboardType: TextInputType.number,
                                        style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.amber),
                                        decoration: InputDecoration(
                                          labelText: 'Shortage Missing Qty',
                                          hintText: 'e.g. 50 pcs missing',
                                          labelStyle: GoogleFonts.publicSans(fontSize: 11, color: AppTheme.amber),
                                          isDense: true,
                                          filled: true,
                                          fillColor: Colors.white,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.amber)),
                                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.amber)),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            }),
                          const SizedBox(height: 16),

                          // SECTION 4: PHOTO ATTACHMENT
                          Text(
                            'Challan Paper Slip Photo',
                            style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.ink),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.bg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: selectedImage != null
                                ? Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(selectedImage!, width: 52, height: 52, fit: BoxFit.cover),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Challan photo attached',
                                              style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.ink),
                                            ),
                                            Text(
                                              'Ready for upload',
                                              style: GoogleFonts.publicSans(fontSize: 11, color: AppTheme.green, fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close_rounded, size: 18, color: AppTheme.red),
                                        onPressed: () => setModalState(() => selectedImage = null),
                                      ),
                                    ],
                                  )
                                : Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () => pickChallanImage(ImageSource.camera),
                                          icon: const Icon(Icons.camera_alt_rounded, size: 16, color: AppTheme.steel),
                                          label: Text('Camera', style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.steel)),
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(vertical: 10),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            side: const BorderSide(color: AppTheme.border),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () => pickChallanImage(ImageSource.gallery),
                                          icon: const Icon(Icons.photo_library_rounded, size: 16, color: AppTheme.steel),
                                          label: Text('Gallery', style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.steel)),
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(vertical: 10),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            side: const BorderSide(color: AppTheme.border),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                          const SizedBox(height: 14),

                          // Notes / Remarks
                          TextField(
                            controller: notesController,
                            style: GoogleFonts.publicSans(fontSize: 13, color: AppTheme.ink),
                            decoration: InputDecoration(
                              hintText: 'General Remarks (e.g. Driver Mohan • 10 bags)',
                              hintStyle: GoogleFonts.publicSans(fontSize: 12.5, color: AppTheme.inkFaint),
                              prefixIcon: const Icon(Icons.notes_rounded, size: 18, color: AppTheme.inkSoft),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              filled: true,
                              fillColor: AppTheme.bg,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),

                  // Fixed Bottom Action Bar (pinned)
                  Container(height: 1, color: AppTheme.border),
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    color: Colors.white,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 88,
                          height: 48,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              side: const BorderSide(color: AppTheme.border),
                              padding: EdgeInsets.zero,
                            ),
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.publicSans(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.inkSoft,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: isSubmitting
                                  ? null
                                  : () async {
                                      if (challanNoController.text.trim().isEmpty) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Please enter Challan / Slip Number.'), backgroundColor: Colors.redAccent),
                                        );
                                        return;
                                      }
                                      if (items.isEmpty) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Please add at least 1 item from the challan.'), backgroundColor: Colors.redAccent),
                                        );
                                        return;
                                      }

                                      final firstVendor = items.firstWhere(
                                        (it) => it.vendorController.text.trim().isNotEmpty,
                                        orElse: () => items.first,
                                      ).vendorController.text.trim();
                                      final supplierName = partyController.text.trim().isNotEmpty
                                          ? partyController.text.trim()
                                          : (firstVendor.isNotEmpty ? firstVendor : 'Multi-Vendor Inward');

                                      setModalState(() => isSubmitting = true);
                                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                                      final nav = Navigator.of(ctx);

                                      try {
                                        final selectedDateStr = '${inwardDate.year}-${inwardDate.month.toString().padLeft(2, '0')}-${inwardDate.day.toString().padLeft(2, '0')}';
                                        final grnNo = 'GRN-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

                                        String? photoUrl;
                                        if (selectedImage != null) {
                                          try {
                                            final bytes = await selectedImage!.readAsBytes();
                                            final fileName = 'challan_${DateTime.now().millisecondsSinceEpoch}.jpg';
                                            try {
                                              await supabase.storage.from('challans').uploadBinary(fileName, bytes);
                                              photoUrl = supabase.storage.from('challans').getPublicUrl(fileName);
                                            } catch (_) {
                                              photoUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                                            }
                                          } catch (e) {
                                            debugPrint('Photo upload error: $e');
                                          }
                                        }

                                        final String overallStatus = (dueCount > 0)
                                            ? 'DUE_PENDING'
                                            : (shortageCount > 0)
                                                ? 'SHORTAGE'
                                                : 'VERIFIED';

                                        final lineItemsJson = items.map((i) => i.toMap()).toList();
                                        final authState = ref.read(authProvider);
                                        final currentUserName = authState.cachedUsername ?? 'Store Manager';
                                        final currentUserId = supabase.auth.currentUser?.id;

                                        try {
                                          final insertRes = await supabase.from('truck_inwards').insert({
                                            'grn_no': grnNo,
                                            'party_name': supplierName,
                                            'article_no': articleController.text.trim(),
                                            'challan_no': challanNoController.text.trim(),
                                            'truck_no': truckNoController.text.trim(),
                                            'inward_date': selectedDateStr,
                                            'total_items': items.length,
                                            'due_items_count': dueCount,
                                            'shortage_items_count': shortageCount,
                                            'status': overallStatus,
                                            'challan_photo_url': photoUrl,
                                            'line_items': lineItemsJson,
                                            'notes': notesController.text.trim(),
                                            'receiver_name': currentUserName,
                                            'received_by': currentUserId,
                                          }).select();

                                          if (insertRes.isNotEmpty) {
                                            final savedTruckInwardId = insertRes.first['id'];
                                            for (var it in items) {
                                              try {
                                                final itemQty = int.tryParse(it.qtyController.text.trim()) ?? 0;
                                                final itemSize = it.sizeController.text.trim();
                                                final itemVendor = it.vendorController.text.trim();
                                                final unitPrice = double.tryParse(it.priceController.text.trim()) ?? 0.0;
                                                await supabase.from('truck_inward_items').insert({
                                                  'truck_inward_id': savedTruckInwardId,
                                                  'item_name': it.nameController.text.trim(),
                                                  'vendor_name': itemVendor.isNotEmpty ? itemVendor : null,
                                                  'unit_price': unitPrice > 0 ? unitPrice : null,
                                                  'total_price': unitPrice > 0 ? (itemQty * unitPrice) : null,
                                                  'quantity': itemQty,
                                                  'challan_qty': itemQty,
                                                  'unit': it.unit,
                                                  'size_label': itemSize,
                                                  'size_color': itemSize,
                                                  'status': it.status,
                                                  'shortage_qty': int.tryParse(it.shortageController.text.trim()) ?? 0,
                                                });
                                              } catch (_) {}
                                            }
                                          }
                                        } catch (dbErr) {
                                          debugPrint('truck_inwards table insert warning: $dbErr');
                                        }

                                        // 2. Also log to accessories table so Godown inventory is instantly updated
                                        for (var it in items) {
                                          if (it.status == 'DUE') continue;
                                          final qty = int.tryParse(it.qtyController.text.trim()) ?? 0;
                                          if (qty <= 0) continue;
                                          try {
                                            final sizeSuffix = it.sizeController.text.trim().isNotEmpty ? ' (${it.sizeController.text.trim()})' : '';
                                            final itemVendor = it.vendorController.text.trim().isNotEmpty ? it.vendorController.text.trim() : supplierName;
                                            final unitPrice = double.tryParse(it.priceController.text.trim()) ?? 0.0;
                                            final priceNote = unitPrice > 0 ? ' • Rate: ₹$unitPrice/unit (Total: ₹${(qty * unitPrice).toStringAsFixed(2)})' : '';
                                            await supabase.from('accessories').insert({
                                              'item_name': it.nameController.text.trim() + sizeSuffix,
                                              'action': 'IN',
                                              'quantity': qty,
                                              'unit': it.unit,
                                              'party_name': itemVendor,
                                              'entry_date': selectedDateStr,
                                              'notes': 'Challan #${challanNoController.text.trim()} • Art ${articleController.text.trim()} • $grnNo$priceNote',
                                            });
                                          } catch (_) {}
                                        }

                                        nav.pop();
                                        scaffoldMessenger.showSnackBar(
                                          SnackBar(
                                            content: Text('Inward recorded! $grnNo generated for $supplierName (${items.length} items).'),
                                            backgroundColor: AppTheme.steel,
                                          ),
                                        );
                                        _fetchStoreData();
                                      } catch (e) {
                                        setModalState(() => isSubmitting = false);
                                        scaffoldMessenger.showSnackBar(
                                          SnackBar(content: Text('Error saving inward: $e'), backgroundColor: Colors.redAccent),
                                        );
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.steel,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: isSubmitting
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.check_circle_outline_rounded, size: 18),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Confirm Inward',
                                          style: GoogleFonts.publicSans(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                        if (items.isNotEmpty) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(alpha: 0.22),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              '$receivedCount',
                                              style: GoogleFonts.jetBrainsMono(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ==========================================
  // MODULE 2.5: SAFETY BUFFER REPLACEMENT QUICK-CLAIM
  // ==========================================
  void _showBufferReplacementClaimModal({String? preselectedArtNo, String? preselectedAllotmentId}) {
    if (_activeAllotments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active floor allotments found.')),
      );
      return;
    }

    String selectedAllotId = preselectedAllotmentId ?? (_activeAllotments.first['id']?.toString() ?? '');
    String selectedItem = '';
    String customItem = '';
    int claimQty = 1;
    String claimReason = 'Floor Mending / Alteration';
    final notesController = TextEditingController();
    final customItemController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final allotment = _activeAllotments.firstWhere(
            (a) => a['id']?.toString() == selectedAllotId,
            orElse: () => _activeAllotments.first,
          );

          final artNo = allotment['articles']?['art_no']?.toString() ?? '-';
          final linemanName = allotment['profiles']?['username']?.toString() ?? 'Lineman';
          final targetQty = parseQty(allotment['target_qty']);
          final assignedColor = allotment['assigned_color_label']?.toString() ?? '';

          // Calculate Safety Buffer based on active allotment batch size
          final int calculatedBuffer = ((targetQty * _safetyBufferPct) / 100).ceil();
          final int claimedSoFar = _bufferClaims
              .where((c) => c['art_no'] == artNo)
              .fold(0, (sum, c) => sum + parseQty(c['qty']));
          final int availableBuffer = (calculatedBuffer - claimedSoFar).clamp(0, 99999);

          final materials = _allotmentMaterials
              .where((m) => m['allotment_id']?.toString() == selectedAllotId)
              .toList();

          if (selectedItem.isEmpty && materials.isNotEmpty) {
            selectedItem = materials.first['item_name']?.toString() ?? '';
          }

          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              top: 20,
              left: 20,
              right: 20,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.shield_rounded, color: Color(0xFFD97706), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Buffer Replacement Claim',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.ink,
                              ),
                            ),
                            Text(
                              'Article #$artNo${assignedColor.isNotEmpty ? " • $assignedColor" : ""} • Buffer Reserve: $availableBuffer pcs left',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11.5,
                                color: AppTheme.inkSoft,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // 1. Select Lineman / Allotment
                  Text(
                    '1. SELECT FLOOR LINE / LINEMAN',
                    style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.steel),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.bg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedAllotId,
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded),
                        items: _activeAllotments.map<DropdownMenuItem<String>>((al) {
                          final lName = al['profiles']?['username'] ?? 'Lineman';
                          final aNo = al['articles']?['art_no'] ?? '-';
                          final col = al['assigned_color_label'] ?? '';
                          return DropdownMenuItem<String>(
                            value: al['id'].toString(),
                            child: Text(
                              '$lName • Art #$aNo ${col.isNotEmpty ? "($col)" : ""}',
                              style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.ink),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() {
                              selectedAllotId = val;
                              selectedItem = '';
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 2. Trim / Material to Replace
                  Text(
                    '2. TRIM / MATERIAL TO REPLACE',
                    style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.steel),
                  ),
                  const SizedBox(height: 6),
                  if (materials.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedItem,
                          isExpanded: true,
                          items: [
                            ...materials.map<DropdownMenuItem<String>>((m) {
                              final name = m['item_name']?.toString() ?? 'Trim';
                              final qty = m['required_qty']?.toString() ?? '';
                              final parsedSize = MultiSizeParser.parseMultiSizeTokens(name);
                              final sizeSuffix = parsedSize.isMultiSize ? ' [Sizes: ${parsedSize.sizes.join(",")}]' : '';
                              return DropdownMenuItem<String>(
                                value: name,
                                child: Text(
                                  '$name$sizeSuffix (Quota: $qty)',
                                  style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.ink),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }),
                            const DropdownMenuItem<String>(
                              value: '__CUSTOM__',
                              child: Text('➕ Other / Custom Trim Item...', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.steel)),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) setModalState(() => selectedItem = val);
                          },
                        ),
                      ),
                    ),
                    if (selectedItem == '__CUSTOM__') ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: customItemController,
                        onChanged: (v) => customItem = v,
                        decoration: InputDecoration(
                          hintText: 'e.g. Size 24 Care Label, Navy Thread Cone...',
                          hintStyle: GoogleFonts.publicSans(fontSize: 12, color: AppTheme.inkSoft),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
                        ),
                      ),
                    ],
                  ] else ...[
                    TextField(
                      controller: customItemController,
                      onChanged: (v) => customItem = v,
                      decoration: InputDecoration(
                        hintText: 'Enter trim/material name...',
                        hintStyle: GoogleFonts.publicSans(fontSize: 12, color: AppTheme.inkSoft),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),

                  // 3. Replacement Quantity
                  Text(
                    '3. REPLACEMENT QUANTITY (PCS)',
                    style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.steel),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.bg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, size: 18),
                              onPressed: () {
                                if (claimQty > 1) setModalState(() => claimQty--);
                              },
                            ),
                            Text(
                              '$claimQty',
                              style: GoogleFonts.jetBrainsMono(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.ink),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, size: 18),
                              onPressed: () => setModalState(() => claimQty++),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ...[1, 2, 5, 10].map((n) {
                        final isSel = claimQty == n;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InkWell(
                            onTap: () => setModalState(() => claimQty = n),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                              decoration: BoxDecoration(
                                color: isSel ? AppTheme.steel : AppTheme.bg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isSel ? AppTheme.steel : AppTheme.border),
                              ),
                              child: Text(
                                '+$n',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isSel ? Colors.white : AppTheme.ink,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 4. Reason
                  Text(
                    '4. REASON FOR CLAIM',
                    style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.steel),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      'Floor Mending / Alteration',
                      'Damaged in Stitching',
                      'Defective Trim / Label',
                      'Missing in Bundle'
                    ].map((r) {
                      final isSel = claimReason == r;
                      return ChoiceChip(
                        label: Text(r, style: GoogleFonts.publicSans(fontSize: 11, fontWeight: isSel ? FontWeight.bold : FontWeight.w500)),
                        selected: isSel,
                        selectedColor: const Color(0xFFFEF3C7),
                        backgroundColor: AppTheme.bg,
                        labelStyle: TextStyle(color: isSel ? const Color(0xFFD97706) : AppTheme.ink),
                        onSelected: (_) => setModalState(() => claimReason = r),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // 5. Remarks
                  Text(
                    '5. OPERATOR REMARKS (OPTIONAL)',
                    style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.steel),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: notesController,
                    decoration: InputDecoration(
                      hintText: 'e.g. Size M label torn during collar attachment...',
                      hintStyle: GoogleFonts.publicSans(fontSize: 12, color: AppTheme.inkSoft),
                      filled: true,
                      fillColor: AppTheme.bg,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Confirm Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.shield_rounded, size: 20),
                      label: Text(
                        'Deduct & Issue $claimQty pcs from Reserve',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        final effectiveItem = selectedItem == '__CUSTOM__'
                            ? customItem.trim()
                            : (selectedItem.isNotEmpty ? selectedItem : customItem.trim());

                        if (effectiveItem.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please select or specify a material item.')),
                          );
                          return;
                        }

                        final newClaim = {
                          'id': 'CLM-${DateTime.now().millisecondsSinceEpoch}',
                          'art_no': artNo,
                          'allotment_id': selectedAllotId,
                          'lineman_name': linemanName,
                          'item_name': effectiveItem,
                          'qty': claimQty,
                          'reason': claimReason,
                          'notes': notesController.text.trim(),
                          'created_at': DateTime.now().toIso8601String(),
                        };

                        setState(() {
                          _bufferClaims.insert(0, newClaim);
                        });

                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Issued $claimQty pcs of "$effectiveItem" to $linemanName from Safety Buffer!'),
                            backgroundColor: const Color(0xFF16A34A),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ==========================================
  // MODULE 3: ACCESSORIES & TRIMS LEDGER
  // ==========================================
  void _showMaterialHandoverModal({String? preselectedAllotmentId}) {
    // Filter for allotments that actually have pending material inspections
    final pendingAllotments = _activeAllotments.where((al) {
      final mats = _allotmentMaterials.where((m) => m['allotment_id']?.toString() == al['id']?.toString()).toList();
      if (mats.isEmpty) return true;
      return mats.any((m) {
        bool isIssued = m['admin_issued'] == true;
        bool isStoreVerified = false;
        if (m['notes'] != null) {
          try {
            final parsed = jsonDecode(m['notes'].toString());
            if (parsed is Map && parsed['store_verified'] == true) {
              isStoreVerified = true;
            }
          } catch (_) {}
        }
        return !isIssued && !isStoreVerified;
      });
    }).toList();

    if (_activeAllotments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active allotments found in progress.')),
      );
      return;
    }

    if (pendingAllotments.isEmpty) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        builder: (ctx) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 48),
              ),
              const SizedBox(height: 18),
              const Text(
                'All Materials Issued to Floor',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 8),
              Text(
                'Raw materials & accessories for all active allotments have already been verified and handed over to Linemen.\n\nNo pending inward inspections waiting for store issue.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('OK, All Done', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }

    String selectedAllotmentId = (preselectedAllotmentId != null &&
            pendingAllotments.any((a) => a['id']?.toString() == preselectedAllotmentId))
        ? preselectedAllotmentId
        : pendingAllotments.first['id'].toString();
    final challanController = TextEditingController();
    bool isSubmitting = false;

    // Map to hold inspection state per material item id
    // { id: { 'receivedQtyCtrl': TextEditingController, 'status': 'VERIFIED' | 'SHORTAGE' | 'DEFECTIVE', 'shortageCtrl': TextEditingController, 'remarksCtrl': TextEditingController } }
    final Map<String, Map<String, dynamic>> inspectionState = {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final mediaQuery = MediaQuery.of(context);
          final allotment = pendingAllotments.firstWhere(
            (a) => a['id'] == selectedAllotmentId,
            orElse: () => pendingAllotments.first,
          );

          final materials = _allotmentMaterials.where((m) => m['allotment_id']?.toString() == selectedAllotmentId.toString()).toList();
          final linemanName = allotment['profiles']?['username'] ?? 'Lineman';
          final artNo = allotment['articles']?['art_no'] ?? '-';
          final artDesc = _getCleanArticleDescription(allotment['articles']?['description']);

          // Initialize controllers for materials
          for (var mat in materials) {
            final mId = mat['id'].toString();
            if (!inspectionState.containsKey(mId)) {
              // Parse existing inspection notes if any
              String existingReceived = mat['required_qty']?.toString() ?? '';
              String existingStatus = 'VERIFIED';
              String existingShortage = '';
              String existingRemarks = '';

              if (mat['notes'] != null) {
                try {
                  final notesRaw = mat['notes'];
                  if (notesRaw is Map) {
                    if (notesRaw['status'] != null) existingStatus = notesRaw['status'].toString();
                    if (notesRaw['supplier_challan_no'] != null && challanController.text.isEmpty) {
                      challanController.text = notesRaw['supplier_challan_no'].toString();
                    }
                  } else {
                    final notesStr = notesRaw.toString();
                    if (notesStr.contains('status')) {
                      if (notesStr.contains('"status":"SHORTAGE"')) existingStatus = 'SHORTAGE';
                      if (notesStr.contains('"status":"DEFECTIVE"')) existingStatus = 'DEFECTIVE';
                    }
                    if (notesStr.contains('supplier_challan_no') && challanController.text.isEmpty) {
                      final match = RegExp(r'"supplier_challan_no":"(.*?)"').firstMatch(notesStr);
                      if (match != null && match.group(1) != null) {
                        challanController.text = match.group(1)!;
                      }
                    }
                  }
                } catch (_) {}
              }

              inspectionState[mId] = {
                'receivedQtyCtrl': TextEditingController(text: existingReceived),
                'status': existingStatus,
                'shortageCtrl': TextEditingController(text: existingShortage),
                'remarksCtrl': TextEditingController(text: existingRemarks),
              };
            }
          }

          return Container(
            constraints: BoxConstraints(
              maxHeight: mediaQuery.size.height * 0.90,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              bottom: mediaQuery.viewInsets.bottom,
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Drag Handle & Fixed Header Bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
                    child: Column(
                      children: [
                        Center(
                          child: Container(
                            width: 38,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppTheme.border,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.steelMist,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.fact_check_outlined, color: AppTheme.steel, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'BOM Material Handover',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16.5,
                                      color: AppTheme.ink,
                                    ),
                                  ),
                                  Text(
                                    'Issue BOM materials to Lineman',
                                    style: GoogleFonts.publicSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.inkSoft,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: AppTheme.inkSoft, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(height: 1, color: AppTheme.border),

                  // Middle Scrollable Body
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Select Active Allotment Target
                          Text(
                            'Select Allotment Target',
                            style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.ink),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.bg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedAllotmentId,
                                isExpanded: true,
                                items: pendingAllotments.map((al) {
                                  final lName = al['profiles']?['username'] ?? 'Lineman';
                                  final aNo = al['articles']?['art_no'] ?? '';
                                  final cLabel = (al['assigned_color_label']?.toString() ?? '').trim();
                                  final qty = al['target_qty'] ?? 0;
                                  final p = (al['priority'] ?? 'NORMAL').toString().toUpperCase();
                                  final pTag = p == 'CRITICAL' ? '[CRITICAL] ' : (p == 'RUSH' ? '[RUSH] ' : '');
                                  final targetTitle = cLabel.isNotEmpty 
                                      ? '$pTag$lName • $aNo ($cLabel - $qty pcs)'
                                      : '$pTag$lName • $aNo ($qty pcs)';
                                  return DropdownMenuItem<String>(
                                    value: al['id'],
                                    child: Text(
                                      targetTitle,
                                      style: GoogleFonts.publicSans(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13.5,
                                        color: p == 'CRITICAL' ? AppTheme.red : (p == 'RUSH' ? const Color(0xFFD97706) : AppTheme.ink),
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: isSubmitting ? null : (v) {
                                  if (v != null) {
                                    setModalState(() {
                                      selectedAllotmentId = v;
                                      inspectionState.clear();
                                    });
                                  }
                                },
                              ),
                            ),
                          ),

                          // Priority Banner if selected allotment is CRITICAL or RUSH
                          if ((allotment['priority'] ?? 'NORMAL').toString().toUpperCase() == 'CRITICAL' ||
                              (allotment['priority'] ?? 'NORMAL').toString().toUpperCase() == 'RUSH') ...[
                            Builder(
                              builder: (_) {
                                final p = (allotment['priority'] ?? 'NORMAL').toString().toUpperCase();
                                final isCrit = p == 'CRITICAL';
                                return Container(
                                  margin: const EdgeInsets.only(top: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isCrit ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: isCrit ? const Color(0xFFFCA5A5) : const Color(0xFFFDE68A), width: 1.2),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isCrit ? Icons.local_fire_department_rounded : Icons.bolt_rounded,
                                        size: 15,
                                        color: isCrit ? const Color(0xFFDC2626) : const Color(0xFFD97706),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          isCrit
                                              ? 'CRITICAL / EXPORT PRIORITY • सबसे पहले माल इशू करो (DO THIS FIRST)'
                                              : 'RUSH ORDER PRIORITY • उच्च प्राथमिकता',
                                          style: GoogleFonts.publicSans(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: isCrit ? const Color(0xFF991B1B) : const Color(0xFF92400E),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],

                          const SizedBox(height: 14),

                          // 2. Target Info Card
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.bg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Article: $artNo • ${((allotment['assigned_color_label']?.toString() ?? '').trim().isNotEmpty) ? allotment['assigned_color_label'] : (artDesc.isEmpty ? "Garment Style" : artDesc)}',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                          color: AppTheme.ink,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Assigned Lineman: $linemanName',
                                        style: GoogleFonts.publicSans(
                                          fontSize: 12,
                                          color: AppTheme.inkSoft,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.amberMist,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${allotment['target_qty']} pcs',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                      color: AppTheme.amber,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 14),

                          // 3. Supplier Challan No / Invoice #
                          Text(
                            'Supplier Delivery Challan # / Invoice #',
                            style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.ink),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: challanController,
                            style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.ink),
                            decoration: InputDecoration(
                              hintText: 'Enter supplier challan / invoice number',
                              filled: true,
                              fillColor: AppTheme.bg,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // 4. BOM Items Issue List
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'BOM Materials for Floor Issue',
                                style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppTheme.ink),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: AppTheme.steelMist, borderRadius: BorderRadius.circular(6)),
                                child: Text(
                                  '${materials.length} Items',
                                  style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.steel),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          if (materials.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: AppTheme.bg, borderRadius: BorderRadius.circular(12)),
                              child: Center(
                                child: Text(
                                  'No BOM items specified by Admin for this allotment.',
                                  style: GoogleFonts.publicSans(fontSize: 12, color: AppTheme.inkSoft),
                                ),
                              ),
                            )
                          else
                            ...materials.map((mat) {
                              final mId = mat['id'].toString();
                              final state = inspectionState[mId] ?? {};
                              final receivedCtrl = state['receivedQtyCtrl'] as TextEditingController?;
                              final remarksCtrl = state['remarksCtrl'] as TextEditingController?;
                              final itemName = (mat['item_name'] ?? 'Material Item').toString();
                              final reqQty = (mat['required_qty'] ?? '-').toString();

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppTheme.border),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(7),
                                          decoration: BoxDecoration(
                                            color: AppTheme.bg,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            itemName.toLowerCase().contains('fabric')
                                                ? Icons.texture_rounded
                                                : (itemName.toLowerCase().contains('thread')
                                                    ? Icons.gesture_rounded
                                                    : Icons.sell_outlined),
                                            size: 16,
                                            color: AppTheme.steel,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                itemName,
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 13,
                                                  color: AppTheme.ink,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Required: $reqQty',
                                                style: GoogleFonts.jetBrainsMono(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppTheme.inkSoft,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // Issued Quantity Field
                                        SizedBox(
                                          width: 130,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                'Issue Qty',
                                                style: GoogleFonts.publicSans(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppTheme.inkSoft,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              TextField(
                                                controller: receivedCtrl,
                                                textAlign: TextAlign.end,
                                                style: GoogleFonts.jetBrainsMono(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppTheme.ink,
                                                ),
                                                decoration: InputDecoration(
                                                  isDense: true,
                                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                                                  filled: true,
                                                  fillColor: AppTheme.bg,
                                                  border: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(8),
                                                    borderSide: const BorderSide(color: AppTheme.border),
                                                  ),
                                                  enabledBorder: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(8),
                                                    borderSide: const BorderSide(color: AppTheme.border),
                                                  ),
                                                  focusedBorder: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(8),
                                                    borderSide: const BorderSide(color: AppTheme.steel, width: 1.5),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (remarksCtrl != null && remarksCtrl.text.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      TextField(
                                        controller: remarksCtrl,
                                        style: GoogleFonts.publicSans(fontSize: 11.5, color: AppTheme.ink),
                                        decoration: InputDecoration(
                                          hintText: 'Notes / Remarks...',
                                          isDense: true,
                                          filled: true,
                                          fillColor: AppTheme.bg,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
                                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            }),

                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),

                  // Fixed Bottom Action Bar (pinned)
                  Container(height: 1, color: AppTheme.border),
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    color: Colors.white,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 88,
                          height: 48,
                          child: OutlinedButton(
                            onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              side: const BorderSide(color: AppTheme.border),
                              padding: EdgeInsets.zero,
                            ),
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.publicSans(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.inkSoft,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: isSubmitting
                                  ? null
                                  : () async {
                                      final messenger = ScaffoldMessenger.of(context);
                                      setModalState(() => isSubmitting = true);

                                      try {
                                        final challanNo = challanController.text.trim();
                                        final nowIso = DateTime.now().toIso8601String();

                                        for (var mat in materials) {
                                          final mId = mat['id'].toString();
                                          final state = inspectionState[mId] ?? {};
                                          final status = state['status'] ?? 'VERIFIED';
                                          final receivedText = (state['receivedQtyCtrl'] as TextEditingController?)?.text.trim() ?? (mat['required_qty']?.toString() ?? '');
                                          final shortageText = (state['shortageCtrl'] as TextEditingController?)?.text.trim() ?? '';
                                          final remarksText = (state['remarksCtrl'] as TextEditingController?)?.text.trim() ?? '';

                                          Map<String, dynamic> existingNotes = {};
                                          if (mat['notes'] != null) {
                                            try {
                                              final notesRaw = mat['notes'];
                                              if (notesRaw is Map) {
                                                existingNotes = Map<String, dynamic>.from(notesRaw);
                                              } else if (notesRaw is String && notesRaw.trim().isNotEmpty) {
                                                final decoded = jsonDecode(notesRaw);
                                                if (decoded is Map) {
                                                  existingNotes = Map<String, dynamic>.from(decoded);
                                                }
                                              }
                                            } catch (_) {}
                                          }

                                          existingNotes['lineman_name'] = linemanName;
                                          existingNotes['received_qty'] = receivedText.isEmpty ? (mat['required_qty']?.toString() ?? '') : receivedText;
                                          existingNotes['status'] = status;
                                          if (shortageText.isNotEmpty) {
                                            existingNotes['shortage_qty'] = shortageText;
                                          }
                                          if (challanNo.isNotEmpty) {
                                            existingNotes['supplier_challan_no'] = challanNo;
                                          }
                                          existingNotes['store_verified'] = true;
                                          existingNotes['store_verified_at'] = nowIso;
                                          if (remarksText.isNotEmpty) {
                                            existingNotes['store_remarks'] = remarksText;
                                          }

                                          final notesJson = jsonEncode(existingNotes);

                                          await supabase
                                              .from('allotment_materials')
                                              .update({
                                                'admin_issued': true,
                                                'notes': notesJson,
                                              })
                                              .eq('id', mat['id']);

                                          // 2. Log OUTWARD in accessories table so Godown inventory is reduced automatically in real-time
                                          int parseQuantity(dynamic val) {
                                            if (val == null) return 0;
                                            if (val is int) return val;
                                            if (val is num) return val.toInt();
                                            final str = val.toString().trim();
                                            final direct = int.tryParse(str);
                                            if (direct != null) return direct;
                                            final match = RegExp(r'[-+]?\d+').firstMatch(str);
                                            if (match != null) {
                                              return int.tryParse(match.group(0) ?? '') ?? 0;
                                            }
                                            return 0;
                                          }

                                          final rawQtyVal = receivedText.isNotEmpty ? receivedText : mat['required_qty'];
                                          final issuedQty = parseQuantity(rawQtyVal);
                                          final itemName = (mat['item_name'] ?? mat['material_name'] ?? '').toString().trim();
                                          final unit = (mat['unit'] ?? 'pcs').toString();

                                          if (itemName.isNotEmpty && issuedQty > 0) {
                                            try {
                                              await supabase.from('accessories').insert({
                                                'item_name': itemName,
                                                'action': 'OUT',
                                                'quantity': issuedQty,
                                                'unit': unit,
                                                'party_name': 'Issued to Lineman $linemanName',
                                                'entry_date': DateTime.now().toIso8601String().split('T')[0],
                                                'notes': 'BOM Handover for Allotment #${mat['allotment_id']} • ${challanNo.isNotEmpty ? 'Challan #$challanNo' : 'Active Batch'}${artNo.isNotEmpty ? ' • Art #$artNo' : ''}',
                                              });
                                            } catch (accErr) {
                                              debugPrint('Accessories insert note: $accErr');
                                            }
                                          }
                                        }

                                        // Refresh store data in dashboard
                                        await _fetchStoreData();

                                        if (ctx.mounted && Navigator.canPop(ctx)) {
                                          Navigator.pop(ctx);
                                        }

                                        if (mounted) {
                                          messenger.showSnackBar(
                                            SnackBar(
                                              content: Row(
                                                children: [
                                                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text('Raw materials verified & issued to Lineman $linemanName! Stock updated.'),
                                                  ),
                                                ],
                                              ),
                                              backgroundColor: const Color(0xFF16A34A),
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        setModalState(() => isSubmitting = false);
                                        if (mounted) {
                                          messenger.showSnackBar(
                                            SnackBar(
                                              content: Text('Handover Error: $e'),
                                              backgroundColor: Colors.redAccent,
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.steel,
                                disabledBackgroundColor: AppTheme.steel.withValues(alpha: 0.6),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: isSubmitting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.check_circle_outline_rounded, size: 18),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            'Handover to $linemanName',
                                            style: GoogleFonts.publicSans(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    final userName = user?.userMetadata?['full_name'] ??
        user?.email?.split('@')[0] ??
        'Store Keeper';

    final authState = ref.watch(authProvider);
    final tenant = authState.tenantProfile;
    final companyName = (tenant?.companyName != null && tenant!.companyName.trim().isNotEmpty)
        ? tenant.companyName.trim()
        : 'Nubira Creation';

    // 1. KPI Calculations (Exact Web Parity)
    final int totalChallanPcs = _challans.fold<int>(0, (sum, c) => sum + parseQty(c['total_pcs']));
    final int totalAllotmentTargetPcs = _activeAllotments
        .where((al) => al['status'] != 'CANCELLED')
        .fold<int>(0, (sum, al) => sum + parseQty(al['target_qty']));

    final int totalStocks = max<int>(totalChallanPcs, totalAllotmentTargetPcs);
    final int goodsInLine = totalAllotmentTargetPcs;
    final int unallottedStocks = max<int>(0, totalStocks - goodsInLine);

    final Map<String, int> pendingLotsPerArticle = {};
    final Map<String, int> totalLotsPerArticle = {};

    for (var al in _activeAllotments) {
      final artNo = (al['articles']?['art_no'] ?? al['art_no'] ?? 'GENERAL').toString().trim().toUpperCase();
      totalLotsPerArticle[artNo] = (totalLotsPerArticle[artNo] ?? 0) + 1;
      final isPending = _allotmentPendingMap[al['id']?.toString()] ?? false;
      if (isPending) {
        pendingLotsPerArticle[artNo] = (pendingLotsPerArticle[artNo] ?? 0) + 1;
      }
    }

    final int pendingArticlesCount = pendingLotsPerArticle.length;
    final int pendingLotsCount = pendingLotsPerArticle.values.fold<int>(0, (sum, v) => sum + v);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: const Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
        leadingWidth: 56,
        leading: Center(
          child: InkWell(
            onTap: () {
              if (adminScaffoldKey.currentState != null) {
                adminScaffoldKey.currentState!.openDrawer();
              } else {
                Navigator.of(context).maybePop();
              }
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Icon(Icons.menu_rounded, color: Color(0xFF0B1220), size: 20),
            ),
          ),
        ),
        titleSpacing: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/icon.png',
              height: 28,
              width: 28,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Image.asset(
                'assets/images/new_icon.png',
                height: 28,
                width: 28,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(width: 8),
            Image.asset(
              'assets/images/z_i_g_z_a.png',
              height: 20,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Image.asset(
                'assets/images/zigza_new_logo.png',
                height: 20,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Text(
                  'ZIGZA',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0B1220),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 14),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDFA),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF14C8B4).withValues(alpha: 0.3)),
              ),
              child: Text(
                'ERP MES',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0B1220),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2F55D4)))
          : RefreshIndicator(
              color: const Color(0xFF2F55D4),
              backgroundColor: Colors.white,
              onRefresh: _fetchStoreData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Breadcrumbs Row
                    _buildBreadcrumbs(companyName),
                    const SizedBox(height: 10),

                    // 2. Division Chip
                    _buildDivisionChip(),
                    const SizedBox(height: 12),

                    // 3. Hero Card
                    _buildHeroCard(userName),
                    const SizedBox(height: 12),

                    // 4. Five KPI Cards (2 columns, 5th card left-only)
                    _buildKpiGrid(
                      totalStocks: totalStocks,
                      goodsInLine: goodsInLine,
                      unallottedStocks: unallottedStocks,
                      activeLotsCount: _activeAllotments.length,
                      pendingArticlesCount: pendingArticlesCount,
                      pendingLotsCount: pendingLotsCount,
                      criticalRadarCount: 12,
                    ),
                    const SizedBox(height: 14),

                    // 5. Section Switcher Tabs
                    _buildSectionSwitcher(),
                    const SizedBox(height: 14),

                    // 6. Section Content based on Tab
                    if (_selectedSectionTab == 0)
                      _buildArticleAllocationTab()
                    else if (_selectedSectionTab == 1)
                      _buildFinishedGoodsMatrixSection()
                    else if (_selectedSectionTab == 2)
                      _buildSupplierGrnSection()
                    else if (_selectedSectionTab == 3)
                      _buildRawMaterialsTrimsSection()
                    else if (_selectedSectionTab == 4)
                      _buildDispatchChallansSection()
                    else if (_selectedSectionTab == 5)
                      _buildInwardReceiptsSection()
                    else
                      _buildArticleBufferLedgerSection(),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  // ==========================================
  // WIDGET 1: BREADCRUMBS ROW
  // ==========================================
  Widget _buildBreadcrumbs(String companyName) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              InkWell(
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const EnterpriseWorkspaceHubScreen()),
                  );
                },
                child: Text(
                  'Workspace Hub',
                  style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF5B6478), fontWeight: FontWeight.w500),
                ),
              ),
              Text(' / ', style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF8A94A6))),
              InkWell(
                onTap: () => Navigator.pop(context),
                child: Text(
                  'Sewing Operations',
                  style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF5B6478), fontWeight: FontWeight.w500),
                ),
              ),
              Text(' / ', style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF8A94A6))),
              Text(
                'Store Dashboard',
                style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF14142B), fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F1FA),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFDDD6F0)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.business_outlined, size: 12, color: Color(0xFF332B6B)),
              const SizedBox(width: 4),
              Text(
                companyName,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF332B6B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // WIDGET 2: DIVISION CHIP
  // ==========================================
  Widget _buildDivisionChip() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF5E6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0E2B8)),
      ),
      child: Text(
        'DIVISION 06 · STITCHING STORE & FLOOR MATERIAL GODOWN',
        style: GoogleFonts.jetBrainsMono(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF4B3F1D),
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  // ==========================================
  // WIDGET 3: HERO CARD
  // ==========================================
  Widget _buildHeroCard(String userName) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDFA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF14C8B4).withValues(alpha: 0.3)),
                ),
                child: const Icon(
                  Icons.warehouse_outlined,
                  color: Color(0xFF0F766E),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Welcome, ${userName.toUpperCase()}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0B1220),
                              letterSpacing: -0.3,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6F7F2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFBFE9DC)),
                          ),
                          child: Text(
                            'Store & Godown Shift',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F766E),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Factory raw materials inventory, trims handover & finished goods dispatch',
                      style: GoogleFonts.publicSans(
                        fontSize: 12,
                        color: const Color(0xFF5B6478),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Action Buttons Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                // + Create button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2F55D4),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _showCreateActionSheet,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        'Create',
                        style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Colors.white),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Sync button
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0B1220),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isSyncing
                      ? null
                      : () async {
                          setState(() => _isSyncing = true);
                          await _fetchStoreData();
                          if (mounted) setState(() => _isSyncing = false);
                        },
                  icon: _isSyncing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F766E)),
                        )
                      : const Icon(Icons.sync_rounded, size: 16, color: Color(0xFF0B1220)),
                  label: Text(
                    'Sync',
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),

                // TV View button
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0B1220),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('TV view opens on large monitors & displays.'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.tv_rounded, size: 16, color: Color(0xFF0B1220)),
                  label: Text(
                    'TV View',
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),

                // Logout Button
                InkWell(
                  onTap: () async {
                    final nav = Navigator.of(context);
                    await ref.read(authProvider.notifier).logout();
                    nav.pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Icon(Icons.logout_rounded, size: 18, color: Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // WIDGET 4: FIVE KPI CARDS (2 Columns)
  // ==========================================
  Widget _buildKpiGrid({
    required int totalStocks,
    required int goodsInLine,
    required int unallottedStocks,
    required int activeLotsCount,
    required int pendingArticlesCount,
    required int pendingLotsCount,
    required int criticalRadarCount,
  }) {
    final formatter = NumberFormat('#,###');
    final floorPct = totalStocks > 0 ? ((goodsInLine / totalStocks) * 100).round() : 0;

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildKpiCard(
                microLabel: 'STORE 01',
                title: '1. Total store stock',
                subtitle: 'Pending allotment balance',
                value: formatter.format(unallottedStocks),
                badgeText: 'UNALLOTTED',
                extraRightText: '${formatter.format(totalStocks)} total',
                icon: Icons.warehouse_outlined,
                onTap: () {},
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildKpiCard(
                microLabel: 'INSPECT WIP',
                title: '2. Goods on floor',
                outlineBadge: 'DRAWER',
                subtitle: 'Lineman, mending & QC',
                value: formatter.format(goodsInLine),
                badgeText: '$activeLotsCount ACTIVE LOTS →',
                extraRightText: '$floorPct% on floor',
                icon: Icons.show_chart_rounded,
                onTap: () => _showGoodsInLineDrilldown(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildKpiCard(
                microLabel: 'STORE 03',
                title: '3. Pending to issue',
                subtitle: 'Store godown balance',
                value: formatter.format(unallottedStocks),
                badgeText: 'IN GODOWN',
                extraRightText: 'unallotted',
                icon: Icons.inventory_2_outlined,
                onTap: () {},
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildKpiCard(
                microLabel: '',
                topBadge: 'HANDOVER',
                title: '4. BOM handover',
                subtitle: 'Inspect raw materials & issue',
                valueSpan: TextSpan(
                  children: [
                    TextSpan(
                      text: '$pendingArticlesCount',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0B1220),
                      ),
                    ),
                    TextSpan(
                      text: ' Articles',
                      style: GoogleFonts.publicSans(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF5B6478),
                      ),
                    ),
                  ],
                ),
                badgeText: '$pendingArticlesCount PENDING STYLES',
                isAmberBadge: pendingArticlesCount > 0,
                extraRightText: '$pendingLotsCount lots queue',
                icon: Icons.fact_check_outlined,
                showTopRightArrow: true,
                onTap: () => _showMaterialHandoverModal(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildKpiCard(
                microLabel: 'RISK RADAR',
                title: '5. Low stock alert',
                subtitle: 'Trims safety radar',
                value: '$criticalRadarCount',
                badgeText: '$criticalRadarCount CRITICAL',
                extraRightText: 'trims',
                icon: Icons.warning_amber_rounded,
                isRedVariant: true,
                onTap: () => _showLowStockRadarDialog(),
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(child: SizedBox.shrink()), // Exactly like web: left column only
          ],
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String microLabel,
    String? topBadge,
    String? outlineBadge,
    required String title,
    required String subtitle,
    String? value,
    TextSpan? valueSpan,
    required String badgeText,
    String? extraRightText,
    required IconData icon,
    bool isRedVariant = false,
    bool isAmberBadge = false,
    bool showTopRightArrow = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isRedVariant ? const Color(0xFFFEF2F4) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isRedVariant ? const Color(0xFFF8C9D1) : const Color(0xFFE2E8F0),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x06000000),
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Icon tile + microLabel / Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isRedVariant ? const Color(0xFFFDE4E8) : const Color(0xFFE6F7F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isRedVariant ? const Color(0xFFF8C9D1) : const Color(0xFFBFE9DC),
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: 17,
                    color: isRedVariant ? const Color(0xFFE11D48) : const Color(0xFF0F766E),
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (topBadge != null && topBadge.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDFA),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF14C8B4).withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            topBadge,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0B1220),
                            ),
                          ),
                        ),
                      ],
                      if (microLabel.isNotEmpty) ...[
                        if (topBadge != null && topBadge.isNotEmpty) const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            microLabel,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: isRedVariant ? const Color(0xFFE11D48) : const Color(0xFF8A94A6),
                              letterSpacing: 0.3,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                      if (showTopRightArrow) ...[
                        const SizedBox(width: 2),
                        const Icon(Icons.arrow_outward_rounded, size: 11, color: Color(0xFF8A94A6)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Title
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF14142B),
                    ),
                    maxLines: 2,
                  ),
                ),
                if (outlineBadge != null) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDFA),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF14C8B4).withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      outlineBadge,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0B1220),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 2),

            // Subtitle
            Text(
              subtitle,
              style: GoogleFonts.publicSans(
                fontSize: 10.5,
                color: const Color(0xFF8A94A6),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),

            // Value
            if (valueSpan != null)
              RichText(text: valueSpan)
            else
              Text(
                value ?? '-',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: isRedVariant ? const Color(0xFFE11D48) : const Color(0xFF14142B),
                  letterSpacing: -0.5,
                ),
              ),
            const SizedBox(height: 6),

            // Bottom row: pill + extra text
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              runSpacing: 4,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isRedVariant
                        ? const Color(0xFFFDE4E8)
                        : (isAmberBadge ? const Color(0xFFFEF3C7) : const Color(0xFFE6F7F2)),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isRedVariant
                          ? const Color(0xFFF8C9D1)
                          : (isAmberBadge ? const Color(0xFFF5D67A) : const Color(0xFFBFE9DC)),
                    ),
                  ),
                  child: Text(
                    badgeText,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      color: isRedVariant
                          ? const Color(0xFFBE123C)
                          : (isAmberBadge ? const Color(0xFF92400E) : const Color(0xFF0F766E)),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (extraRightText != null)
                  Text(
                    extraRightText,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9,
                      color: const Color(0xFF8A94A6),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // WIDGET 5: SECTION SWITCHER TABS
  // ==========================================
  Widget _buildSectionSwitcher() {
    final finishedCount = _articles.length;
    final challanCount = _truckInwards.length;
    final accessoriesCount = _accessories.length;
    final dispatchCount = _storeTransactions.where((t) => (t['type'] ?? '').toString().toUpperCase() == 'OUTWARD').length;
    final inwardCount = _truckInwards.length + _storeTransactions.where((t) => (t['type'] ?? '').toString().toUpperCase() == 'INWARD').length;

    final tabs = [
      {'index': 0, 'label': 'Article Allocation & BOM Handover', 'short': 'BOM Handover', 'count': null, 'icon': Icons.ssid_chart_rounded, 'desc': 'Allotments, Lineman floor assignments & BOM issue status'},
      {'index': 1, 'label': 'Finished Goods Matrix', 'short': 'Finished Goods', 'count': finishedCount, 'icon': Icons.inventory_2_outlined, 'desc': 'Inventory matrix by article, sizes and godown status'},
      {'index': 2, 'label': 'Supplier Challans & GRN', 'short': 'Supplier GRN', 'count': challanCount, 'icon': Icons.description_outlined, 'desc': 'Inward truck delivery challans, bills & slip photos'},
      {'index': 3, 'label': 'Raw Materials & Trims', 'short': 'Raw Materials', 'count': accessoriesCount, 'icon': Icons.widgets_outlined, 'desc': 'Trims, threads, polybags, zippers & stock buffer levels'},
      {'index': 4, 'label': 'Dispatch & Challans', 'short': 'Dispatch', 'count': dispatchCount, 'icon': Icons.local_shipping_outlined, 'desc': 'Outward shipments to warehouses & distributors'},
      {'index': 5, 'label': 'Inward Receipts', 'short': 'Inwards', 'count': inwardCount, 'icon': Icons.check_circle_outline_rounded, 'desc': 'Verified fabric & trim gate inward entries'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          // Quick Jump Menu Pill
          InkWell(
            onTap: () => _showSectionPickerSheet(tabs),
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8.5),
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 1.5),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.dashboard_customize_outlined, size: 15, color: Color(0xFF332B6B)),
                  SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF64748B)),
                ],
              ),
            ),
          ),

          // Tab Pills
          for (var t in tabs) ...[
            _buildSwitcherTab(
              index: t['index'] as int,
              label: t['label'] as String,
              icon: t['icon'] as IconData,
              count: t['count'] as int?,
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }

  Widget _buildSwitcherTab({
    required int index,
    required String label,
    required IconData icon,
    int? count,
  }) {
    final isSelected = _selectedSectionTab == index;
    return InkWell(
      onTap: () => setState(() => _selectedSectionTab = index),
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8.5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF332B6B) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? const Color(0xFF332B6B) : const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF332B6B).withValues(alpha: 0.22),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 1.5),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF334155),
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.2)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  count.toString(),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : const Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showSectionPickerSheet(List<Map<String, dynamic>> tabs) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F1FA),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.dashboard_customize_rounded, size: 20, color: Color(0xFF332B6B)),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Store Dashboard Sections',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Select a tab view to inspect live store floor data',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 10),
            for (var t in tabs) ...[
              InkWell(
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _selectedSectionTab = t['index'] as int);
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  decoration: BoxDecoration(
                    color: _selectedSectionTab == t['index']
                        ? const Color(0xFFF4F1FA)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _selectedSectionTab == t['index']
                          ? const Color(0xFFDDD6F0)
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _selectedSectionTab == t['index']
                              ? const Color(0xFF332B6B)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          t['icon'] as IconData,
                          size: 18,
                          color: _selectedSectionTab == t['index']
                              ? Colors.white
                              : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  t['label'] as String,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13.5,
                                    fontWeight: _selectedSectionTab == t['index']
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color: _selectedSectionTab == t['index']
                                        ? const Color(0xFF332B6B)
                                        : const Color(0xFF1E293B),
                                  ),
                                ),
                                if (t['count'] != null) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${t['count']}',
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF475569),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              t['desc'] as String,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: const Color(0xFF64748B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (_selectedSectionTab == t['index'])
                        const Icon(Icons.check_circle_rounded, size: 20, color: Color(0xFF332B6B))
                      else
                        const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFFCBD5E1)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==========================================
  // WIDGET 6: TAB 1 (ARTICLE ALLOCATION & BOM)
  // ==========================================
  Widget _buildArticleAllocationTab() {
    final Map<String, List<dynamic>> groupedByArticle = {};
    for (var al in _activeAllotments) {
      final artNo = (al['articles']?['art_no'] ?? al['art_no'] ?? 'GENERAL').toString().trim().toUpperCase();
      if (!groupedByArticle.containsKey(artNo)) {
        groupedByArticle[artNo] = [];
      }
      groupedByArticle[artNo]!.add(al);
    }

    int pendingArticlesCount = 0;
    int issuedArticlesCount = 0;

    groupedByArticle.forEach((artNo, allotments) {
      final hasPending = allotments.any((al) => _allotmentPendingMap[al['id']?.toString()] == true);
      if (hasPending) {
        pendingArticlesCount++;
      } else {
        issuedArticlesCount++;
      }
    });

    final filteredEntries = groupedByArticle.entries.where((entry) {
      final artNo = entry.key;
      final allotments = entry.value;

      if (_articleSearchQuery.isNotEmpty) {
        final q = _articleSearchQuery.toLowerCase();
        final artMatch = artNo.toLowerCase().contains(q);
        final linemanMatch = allotments.any((al) {
          final lm = (al['profiles']?['username'] ?? al['lineman_name'] ?? '').toString().toLowerCase();
          return lm.contains(q);
        });
        if (!artMatch && !linemanMatch) return false;
      }

      final hasPending = allotments.any((al) => _allotmentPendingMap[al['id']?.toString()] == true);

      if (_articleFilterStatus == 'PENDING' && !hasPending) return false;
      if (_articleFilterStatus == 'ISSUED' && hasPending) return false;

      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6F7F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBFE9DC)),
                    ),
                    child: const Icon(Icons.fact_check_outlined, color: Color(0xFF0F766E), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                'Live Article Material Consumption & Allotment Status',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF14142B),
                                  height: 1.25,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE6F7F2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFBFE9DC)),
                              ),
                              child: Text(
                                '${groupedByArticle.length} Active Articles',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F766E),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Executive overview of article cutting allotments, lineman floor assignments & BOM issue status',
                          style: GoogleFonts.publicSans(
                            fontSize: 11.5,
                            color: const Color(0xFF5B6478),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Search Input (Web 1:1 rounded-xl)
              TextField(
                onChanged: (v) => setState(() => _articleSearchQuery = v.trim()),
                style: GoogleFonts.publicSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF14142B),
                ),
                decoration: InputDecoration(
                  hintText: 'Filter article or lineman...',
                  hintStyle: GoogleFonts.publicSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF8A94A6),
                  ),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF8A94A6)),
                  suffixIcon: _articleSearchQuery.isNotEmpty
                      ? GestureDetector(
                          onTap: () => setState(() => _articleSearchQuery = ''),
                          child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF8A94A6)),
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF0FDFA).withValues(alpha: 0.6),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF0F766E), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Filter Chips
              Row(
                children: [
                  _buildArticleStatusChip('ALL', 'All (${groupedByArticle.length})'),
                  const SizedBox(width: 6),
                  _buildArticleStatusChip('PENDING', 'Pending ($pendingArticlesCount)', isAmber: true),
                  const SizedBox(width: 6),
                  _buildArticleStatusChip('ISSUED', 'Issued ($issuedArticlesCount)', isTeal: true),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Standalone Article Cards List (Exact Web Layout)
        if (filteredEntries.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            alignment: Alignment.center,
            child: Column(
              children: [
                const Icon(Icons.search_off_rounded, size: 36, color: Color(0xFF8A94A6)),
                const SizedBox(height: 8),
                Text(
                  'No articles match your filter.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF14142B),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _articleSearchQuery = '';
                    _articleFilterStatus = 'ALL';
                  }),
                  child: const Text('Clear filter'),
                ),
              ],
            ),
          )
        else ...[
          ...filteredEntries.take(_visibleArticleCount).map((entry) => _buildArticleAllotmentCard(entry.key, entry.value)),
          if (filteredEntries.length > _visibleArticleCount)
            Padding(
              padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
              child: Center(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F766E),
                    side: const BorderSide(color: Color(0xFFBFE9DC)),
                    backgroundColor: const Color(0xFFE6F7F2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  onPressed: () => setState(() => _visibleArticleCount += 25),
                  icon: const Icon(Icons.expand_more_rounded, size: 18),
                  label: Text(
                    'Show More Articles (${filteredEntries.length - _visibleArticleCount} remaining)',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
        ],

        const SizedBox(height: 16),

        // Store Ledger Activity Feed Card
        _buildStoreLedgerFeedCard(),
      ],
    );
  }

  Widget _buildArticleStatusChip(String key, String label, {bool isAmber = false, bool isTeal = false}) {
    final isSelected = _articleFilterStatus == key;
    Color bg = const Color(0xFFF4F6FA);
    Color border = const Color(0xFFE2E8F0);
    Color text = const Color(0xFF5B6478);

    if (isSelected) {
      bg = const Color(0xFF0F9E8A);
      border = const Color(0xFF0F9E8A);
      text = Colors.white;
    } else if (isAmber) {
      bg = const Color(0xFFFEF3C7);
      border = const Color(0xFFF5D67A);
      text = const Color(0xFF92400E);
    } else if (isTeal) {
      bg = const Color(0xFFE6F7F2);
      border = const Color(0xFFBFE9DC);
      text = const Color(0xFF0F766E);
    }

    return InkWell(
      onTap: () => setState(() => _articleFilterStatus = key),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: Text(
          label,
          style: GoogleFonts.publicSans(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: text,
          ),
        ),
      ),
    );
  }

  Widget _buildArticleAllotmentCard(String artNo, List<dynamic> allotments) {
    final first = allotments.first;
    final desc = _getCleanArticleDescription(first['articles']?['description'] ?? first['description']);
    final category = _extractCategory(desc, first['challans']?['fabric_type']);
    final totalPcs = allotments.fold<int>(0, (sum, al) => sum + parseQty(al['target_qty']));
    final isExpanded = _expandedArticleNo == artNo;

    final Map<String, List<dynamic>> byLineman = {};
    for (var al in allotments) {
      final lm = (al['profiles']?['username'] ?? al['lineman_name'] ?? 'Unassigned').toString();
      if (!byLineman.containsKey(lm)) byLineman[lm] = [];
      byLineman[lm]!.add(al);
    }

    int pendingLots = 0;
    for (var al in allotments) {
      if (_allotmentPendingMap[al['id']?.toString()] == true) {
        pendingLots++;
      }
    }

    final isPending = pendingLots > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded ? const Color(0xFF0F766E).withValues(alpha: 0.4) : const Color(0xFFE2E8F0),
          width: isExpanded ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header / Summary Row (Tap to expand/collapse 1:1 like Web)
          InkWell(
            onTap: () {
              setState(() {
                _expandedArticleNo = isExpanded ? null : artNo;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Tag icon + Article 3360 + Category + Lots pill + Chevron
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDFA),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFBFE9DC)),
                        ),
                        child: const Icon(Icons.sell_outlined, size: 17, color: Color(0xFF0F766E)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Article $artNo',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF14142B),
                                  ),
                                ),
                                if (category.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      category.toUpperCase(),
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF64748B),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDFA),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFBFE9DC)),
                        ),
                        child: Text(
                          '${allotments.length} Lots',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F766E),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDFA),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Icon(
                          isExpanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_right_rounded,
                          size: 18,
                          color: const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Row 2: Lineman Chips Strip (Web 1:1)
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: byLineman.entries.map((entry) {
                      final lmName = entry.key;
                      final lmLots = entry.value.length;
                      final lmPcs = entry.value.fold<int>(0, (sum, al) => sum + parseQty(al['target_qty']));

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.person_outline_rounded, size: 12, color: Color(0xFF64748B)),
                            const SizedBox(width: 4),
                            Text(
                              lmName.toUpperCase(),
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF334155),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '($lmLots lots · ${NumberFormat('#,###').format(lmPcs)} pcs)',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),

                  // Row 3: pcs over FLOOR ALLOTTED + Status Badge (Responsive wrap)
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${NumberFormat('#,###').format(totalPcs)} pcs',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF14142B),
                            ),
                          ),
                          Text(
                            'FLOOR ALLOTTED',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF8A94A6),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      if (isPending)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFF5D67A)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF92400E)),
                              const SizedBox(width: 4),
                              Text(
                                '$pendingLots Lots Pending Handover',
                                style: GoogleFonts.publicSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF92400E),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6F7F2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFBFE9DC)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle_outline_rounded, size: 12, color: Color(0xFF0F766E)),
                              const SizedBox(width: 4),
                              Text(
                                'Allotted & Issued',
                                style: GoogleFonts.publicSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F766E),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ==============================================================
          // EXPANDED ACCORDION: Lineman Breakdown Table (Web 1:1 match)
          // ==============================================================
          if (isExpanded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(
                  top: BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        'Floor Lineman Assignments & Color Breakdown',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF334155),
                        ),
                      ),
                      Text(
                        'Consolidated Summary',
                        style: GoogleFonts.publicSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Responsive Table / Card Container
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 540),
                        child: DataTable(
                          headingRowHeight: 34,
                          dataRowMinHeight: 44,
                          dataRowMaxHeight: 56,
                          columnSpacing: 16,
                          horizontalMargin: 12,
                          headingRowColor: WidgetStateProperty.all(const Color(0xFFF0FDFA)),
                          columns: [
                            DataColumn(
                              label: Text(
                                'LINEMAN',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF475569),
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'ASSIGNED COLORS',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF475569),
                                ),
                              ),
                            ),
                            DataColumn(
                              numeric: true,
                              label: Text(
                                'LOTS',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF475569),
                                ),
                              ),
                            ),
                            DataColumn(
                              numeric: true,
                              label: Text(
                                'TARGET QUANTITY',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF475569),
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'HANDOVER STATUS',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF475569),
                                ),
                              ),
                            ),
                          ],
                          rows: byLineman.entries.map((entry) {
                            final lmName = entry.key;
                            final lmAllots = entry.value;
                            final lmLots = lmAllots.length;
                            final lmPcs = lmAllots.fold<int>(0, (sum, al) => sum + parseQty(al['target_qty']));

                            // Extract assigned colors
                            final Set<String> lmColors = {};
                            for (var al in lmAllots) {
                              if (al['colors'] is List) {
                                for (var c in al['colors']) {
                                  if (c != null && c.toString().trim().isNotEmpty) {
                                    lmColors.add(c.toString().trim().toUpperCase());
                                  }
                                }
                              }
                              if (al['assigned_color_label'] != null && al['assigned_color_label'].toString().isNotEmpty) {
                                final raw = al['assigned_color_label'].toString().replaceAll(' LINE', '').trim();
                                if (raw.isNotEmpty) {
                                  for (var p in raw.split(',')) {
                                    if (p.trim().isNotEmpty) lmColors.add(p.trim().toUpperCase());
                                  }
                                }
                              }
                              if (al['variants'] is List) {
                                for (var v in al['variants']) {
                                  if (v['color'] != null && v['color'].toString().trim().isNotEmpty) {
                                    lmColors.add(v['color'].toString().trim().toUpperCase());
                                  }
                                }
                              }
                            }

                            int lmPendingLots = 0;
                            String? firstPendingAllotId;
                            for (var al in lmAllots) {
                              final isAlPending = _allotmentPendingMap[al['id']?.toString()] == true;
                              if (isAlPending) {
                                lmPendingLots++;
                                firstPendingAllotId ??= al['id']?.toString();
                              }
                            }

                            final isLmFullyIssued = lmPendingLots == 0;
                            final targetAllotId = firstPendingAllotId ?? lmAllots.first['id']?.toString();

                            return DataRow(
                              cells: [
                                // 1. Lineman Name
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.person_rounded, size: 14, color: Color(0xFF0F766E)),
                                      const SizedBox(width: 6),
                                      Text(
                                        lmName.toUpperCase(),
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // 2. Assigned Colors
                                DataCell(
                                  lmColors.isEmpty
                                      ? Text('-', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: const Color(0xFF94A3B8)))
                                      : Wrap(
                                          spacing: 4,
                                          children: lmColors.map((col) {
                                            return Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF0FDFA),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: const Color(0xFFBFE9DC)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.palette_outlined, size: 10, color: Color(0xFF0F766E)),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    col,
                                                    style: GoogleFonts.jetBrainsMono(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      color: const Color(0xFF0B1220),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                ),

                                // 3. Lots
                                DataCell(
                                  Text(
                                    '$lmLots',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF334155),
                                    ),
                                  ),
                                ),

                                // 4. Target Quantity
                                DataCell(
                                  Text(
                                    '${NumberFormat('#,###').format(lmPcs)} pcs',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                ),

                                // 5. Handover Status (Actionable Pill Button!)
                                DataCell(
                                  InkWell(
                                    onTap: () {
                                      if (targetAllotId != null) {
                                        _showMaterialHandoverModal(preselectedAllotmentId: targetAllotId);
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(8),
                                    child: isLmFullyIssued
                                        ? Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFE6F7F2),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: const Color(0xFFBFE9DC)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.check_circle_outline_rounded, size: 12, color: Color(0xFF0F766E)),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Issued ($lmLots/$lmLots)',
                                                  style: GoogleFonts.publicSans(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    color: const Color(0xFF0F766E),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        : Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFEF3C7),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: const Color(0xFFF5D67A)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF92400E)),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Pending ($lmPendingLots lots)',
                                                  style: GoogleFonts.publicSans(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    color: const Color(0xFF92400E),
                                                  ),
                                                ),
                                                const SizedBox(width: 2),
                                                const Icon(Icons.arrow_forward_ios_rounded, size: 9, color: Color(0xFF92400E)),
                                              ],
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ==========================================
  // WIDGET 7: STORE LEDGER FEED CARD
  // ==========================================
  Widget _buildStoreLedgerFeedCard() {
    final filteredLogs = _getFilteredStoreLogs();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Store Ledger Activity Feed',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF14142B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _feedTimeFilter == '24h'
                          ? 'Showing last 24 hours live movements'
                          : (_feedTimeFilter == '7d' ? 'Showing past 7 days activity' : 'Showing all historical logs'),
                      style: GoogleFonts.publicSans(
                        fontSize: 11,
                        color: const Color(0xFF5B6478),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBF5E6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF0E2B8)),
                ),
                child: Text(
                  '${filteredLogs.length} entries',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF4B3F1D),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Segmented Time Filter & Search
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F6FA),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTimeFilterPill('24h', 'Today (24h)'),
                    _buildTimeFilterPill('7d', '7 Days'),
                    _buildTimeFilterPill('all', 'All Time'),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    onChanged: (v) => setState(() => _feedSearchQuery = v.trim()),
                    style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF14142B)),
                    decoration: InputDecoration(
                      hintText: 'Search feed...',
                      hintStyle: GoogleFonts.publicSans(fontSize: 11, color: const Color(0xFF8A94A6)),
                      prefixIcon: const Icon(Icons.search, size: 15, color: Color(0xFF5B6478)),
                      suffixIcon: _feedSearchQuery.isNotEmpty
                          ? GestureDetector(
                              onTap: () => setState(() => _feedSearchQuery = ''),
                              child: const Icon(Icons.close, size: 14, color: Color(0xFF5B6478)),
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF332B6B), width: 1.2),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Category Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildCategoryFilterPill('ALL', 'All Activities', icon: Icons.layers_outlined),
                const SizedBox(width: 6),
                _buildCategoryFilterPill('BOM', 'BOM Packages', icon: Icons.inventory_2_outlined),
                const SizedBox(width: 6),
                _buildCategoryFilterPill('REISSUES', 'Floor Re-Issues (Loss/Damage)', icon: Icons.sync_problem_rounded),
                const SizedBox(width: 6),
                _buildCategoryFilterPill('TRIMS', 'Trims & Materials', icon: Icons.sell_outlined),
                const SizedBox(width: 6),
                _buildCategoryFilterPill('GARMENTS', 'Garments In/Out', icon: Icons.checkroom_outlined),
              ],
            ),
          ),
          const SizedBox(height: 14),

          if (filteredLogs.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFD5DCE8)),
              ),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.history_toggle_off_rounded, size: 36, color: Color(0xFF8A94A6)),
                    const SizedBox(height: 8),
                    Text(
                      _feedTimeFilter == '24h'
                          ? 'No store movements in the last 24 hours.'
                          : 'No movements found matching the selected filter.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(color: const Color(0xFF14142B), fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap "7 Days" or "All Time" above to view previous records.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.publicSans(color: const Color(0xFF8A94A6), fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            ...filteredLogs.take(_visibleFeedCount).map((log) => _buildLedgerCard(log)),
            if (filteredLogs.length > _visibleFeedCount)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Center(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF332B6B),
                      side: const BorderSide(color: Color(0xFFDDD6F0)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    onPressed: () => setState(() => _visibleFeedCount += 25),
                    icon: const Icon(Icons.expand_more_rounded, size: 18),
                    label: Text(
                      'Load More (${filteredLogs.length - _visibleFeedCount} remaining)',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // WIDGET: TAB 1 (FINISHED GOODS MATRIX) - WEB 1:1 PARITY
  // ==========================================
  Widget _buildFinishedGoodsMatrixSection() {
    // 1. Calculate in-line target and QC-passed quantities
    final Map<String, int> inLineMap = {};
    final Map<String, int> qcPassedMap = {};

    final allFloorLots = [..._activeAllotments, ..._readyQcAllotments];
    final Set<String> seenLotIds = {};

    for (var al in allFloorLots) {
      final id = (al['id'] ?? '').toString();
      if (id.isEmpty || seenLotIds.contains(id)) continue;
      seenLotIds.add(id);

      final rawArt = (al['articles']?['art_no'] ?? al['art_no'] ?? '').toString().trim();
      if (rawArt.isEmpty) continue;

      final target = parseQty(al['target_qty']);
      final passed = parseQty(al['qc_total_passed']);
      final remainingInLine = max<int>(0, target - passed);

      inLineMap[rawArt] = (inLineMap[rawArt] ?? 0) + remainingInLine;
      qcPassedMap[rawArt] = (qcPassedMap[rawArt] ?? 0) + passed;
    }

    final Map<String, Map<String, dynamic>> map = {};

    for (var art in _articles) {
      final artNo = (art['art_no'] ?? 'Unknown').toString().trim();
      final desc = (art['description'] ?? '-').toString().trim();
      final autoQc = qcPassedMap[artNo] ?? 0;
      map[artNo] = {
        'art_no': artNo,
        'description': desc,
        'inLineQty': inLineMap[artNo] ?? 0,
        'totalInward': autoQc,
        'totalOutward': 0,
        'balance': autoQc,
        'variants': <String, Map<String, int>>{},
      };
    }

    for (var tx in _storeTransactions) {
      final artNo = (tx['article']?['art_no'] ?? tx['art_no'] ?? 'Unknown').toString().trim();
      final desc = (tx['article']?['description'] ?? '-').toString().trim();
      final color = (tx['color'] ?? 'Standard').toString().trim();
      final size = (tx['size'] ?? 'Free').toString().trim();
      final variantKey = '$color / $size';
      final type = (tx['type'] ?? 'INWARD').toString().toUpperCase();
      final qty = parseQty(tx['quantity']);

      if (!map.containsKey(artNo)) {
        final autoQc = qcPassedMap[artNo] ?? 0;
        map[artNo] = {
          'art_no': artNo,
          'description': desc,
          'inLineQty': inLineMap[artNo] ?? 0,
          'totalInward': autoQc,
          'totalOutward': 0,
          'balance': autoQc,
          'variants': <String, Map<String, int>>{},
        };
      }

      final variants = map[artNo]!['variants'] as Map<String, Map<String, int>>;
      if (!variants.containsKey(variantKey)) {
        variants[variantKey] = {'in': 0, 'out': 0, 'balance': 0};
      }

      if (type == 'INWARD') {
        map[artNo]!['totalInward'] = (map[artNo]!['totalInward'] as int) + qty;
        map[artNo]!['balance'] = (map[artNo]!['balance'] as int) + qty;
        variants[variantKey]!['in'] = (variants[variantKey]!['in'] ?? 0) + qty;
        variants[variantKey]!['balance'] = (variants[variantKey]!['balance'] ?? 0) + qty;
      } else if (type == 'OUTWARD') {
        map[artNo]!['totalOutward'] = (map[artNo]!['totalOutward'] as int) + qty;
        map[artNo]!['balance'] = (map[artNo]!['balance'] as int) - qty;
        variants[variantKey]!['out'] = (variants[variantKey]!['out'] ?? 0) + qty;
        variants[variantKey]!['balance'] = (variants[variantKey]!['balance'] ?? 0) - qty;
      }
    }

    var list = map.values.toList();

    final totalStockBalance = list.fold<int>(0, (sum, item) => sum + (item['balance'] as int));
    final totalInwardQty = _storeTransactions.where((t) => (t['type'] ?? '').toString().toUpperCase() == 'INWARD').fold<int>(0, (sum, t) => sum + parseQty(t['quantity']));
    final totalOutwardQty = _storeTransactions.where((t) => (t['type'] ?? '').toString().toUpperCase() == 'OUTWARD').fold<int>(0, (sum, t) => sum + parseQty(t['quantity']));

    // Stock Velocity Captions matching Web 1:1
    final finishedStockCaption = totalStockBalance == 0
        ? 'Zero stock · Awaiting floor inward'
        : 'Steady, no reorder needed';
    final trimsCaption = _accessories.isEmpty
        ? 'Not enough history yet'
        : 'All trims sufficiently stocked';
    final latestInward = _storeTransactions.where((t) => (t['type'] ?? '').toString().toUpperCase() == 'INWARD').toList();
    final lastQcCaption = latestInward.isEmpty ? 'No QC inward recorded yet' : 'Last QC pass: recorded';
    final latestOutward = _storeTransactions.where((t) => (t['type'] ?? '').toString().toUpperCase() == 'OUTWARD').toList();
    final lastDispatchCaption = latestOutward.isEmpty ? 'No dispatch this week' : 'Last dispatch: recorded';

    if (_finishedSearchQuery.trim().isNotEmpty) {
      final q = _finishedSearchQuery.toLowerCase().trim();
      list = list.where((item) =>
        (item['art_no'] as String).toLowerCase().contains(q) ||
        (item['description'] as String).toLowerCase().contains(q)
      ).toList();
    }

    if (_finishedStatusFilter == 'IN_STOCK') {
      list = list.where((item) => (item['balance'] as int) > 0).toList();
    } else if (_finishedStatusFilter == 'LOW_STOCK') {
      list = list.where((item) => (item['balance'] as int) > 0 && (item['balance'] as int) <= 50).toList();
    } else if (_finishedStatusFilter == 'OUT_OF_STOCK') {
      list = list.where((item) => (item['balance'] as int) <= 0).toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ==========================================
        // 1. PAGE HEADER CARD (Web 1:1)
        // ==========================================
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDFA),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBFE9DC)),
                    ),
                    child: const Icon(Icons.warehouse_rounded, color: Color(0xFF0F766E), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Godown & Inventory Management',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Real-time finished goods stock, raw trims ledger & store transactions',
                          style: GoogleFonts.publicSans(
                            fontSize: 11.5,
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF334155),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Exporting inventory matrix CSV...')),
                        );
                      },
                      icon: const Icon(Icons.download_rounded, size: 16, color: Color(0xFF64748B)),
                      label: Text(
                        'Export CSV',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF334155),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('TV view is optimized for wide screens & smart displays.'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: const Icon(Icons.tv_rounded, size: 16, color: Color(0xFF64748B)),
                      label: Text(
                        'TV View',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ==========================================
        // 2. 4 KPI OVERVIEW BANNER (Web 1:1)
        // ==========================================
        Row(
          children: [
            Expanded(
              child: _buildWebKpiOverviewCard(
                title: 'FINISHED STOCK',
                value: NumberFormat('#,###').format(totalStockBalance),
                unit: 'pcs',
                caption: finishedStockCaption,
                icon: Icons.inventory_2_outlined,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildWebKpiOverviewCard(
                title: 'ACCESSORIES TRIMS',
                value: '${_accessories.length}',
                unit: 'items',
                caption: trimsCaption,
                icon: Icons.widgets_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildWebKpiOverviewCard(
                title: 'TOTAL INWARD (QC)',
                value: '+${NumberFormat('#,###').format(totalInwardQty)}',
                unit: 'pcs',
                caption: lastQcCaption,
                icon: Icons.check_circle_outline_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildWebKpiOverviewCard(
                title: 'DISPATCHED OUTWARD',
                value: '-${NumberFormat('#,###').format(totalOutwardQty)}',
                unit: 'pcs',
                caption: lastDispatchCaption,
                icon: Icons.local_shipping_outlined,
                valueColor: const Color(0xFF7C3AED),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ==========================================
        // 3. FILTER CHIPS & SEARCH TOOLBAR (Web 1:1)
        // ==========================================
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Search Input
              TextField(
                onChanged: (val) => setState(() => _finishedSearchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search article, buyer, trims...',
                  hintStyle: GoogleFonts.publicSans(fontSize: 12.5, color: const Color(0xFF8A94A6)),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF8A94A6)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0F766E), width: 1.2)),
                  isDense: true,
                ),
                style: GoogleFonts.publicSans(fontSize: 12.5),
              ),
              const SizedBox(height: 8),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildWebStatusFilterChip('ALL', 'All', _finishedStatusFilter, (v) => setState(() => _finishedStatusFilter = v)),
                    const SizedBox(width: 6),
                    _buildWebStatusFilterChip('IN_STOCK', 'In Stock', _finishedStatusFilter, (v) => setState(() => _finishedStatusFilter = v)),
                    const SizedBox(width: 6),
                    _buildWebStatusFilterChip('LOW_STOCK', 'Low Stock', _finishedStatusFilter, (v) => setState(() => _finishedStatusFilter = v)),
                    const SizedBox(width: 6),
                    _buildWebStatusFilterChip('OUT_OF_STOCK', 'Out of Stock', _finishedStatusFilter, (v) => setState(() => _finishedStatusFilter = v)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ==========================================
        // 4. FINISHED GOODS MATRIX TABLE / CARDS (Web 1:1)
        // ==========================================
        if (list.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Center(
              child: Column(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDFA),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFBFE9DC)),
                    ),
                    child: const Icon(Icons.inventory_2_outlined, size: 26, color: Color(0xFF0F766E)),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No finished stock recorded yet',
                    style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Finished garments passed by QC and accepted by Store Manager will appear here in real time.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Table Container with horizontal scrolling for full 1:1 columns
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: DataTable(
                    headingRowHeight: 44,
                    dataRowMinHeight: 52,
                    dataRowMaxHeight: 56,
                    horizontalMargin: 16,
                    columnSpacing: 20,
                    headingRowColor: WidgetStateProperty.all(const Color(0xFFF0FDFA)),
                    columns: [
                      DataColumn(
                        label: Text(
                          'ARTICLE NO ↑↓',
                          style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF334155)),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'DESCRIPTION',
                          style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF334155)),
                        ),
                      ),
                      DataColumn(
                        numeric: true,
                        label: Text(
                          'GOODS IN LINE ↑↓',
                          style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF0F766E)),
                        ),
                      ),
                      DataColumn(
                        numeric: true,
                        label: Text(
                          'TOTAL INWARD (QC) ↑↓',
                          style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF059669)),
                        ),
                      ),
                      DataColumn(
                        numeric: true,
                        label: Text(
                          'TOTAL OUTWARD (DISPATCH)',
                          style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                        ),
                      ),
                      DataColumn(
                        numeric: true,
                        label: Text(
                          'GODOWN BALANCE ↑↓',
                          style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                        ),
                      ),
                      DataColumn(
                        label: Center(
                          child: Text(
                            'STATUS',
                            style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF334155)),
                          ),
                        ),
                      ),
                    ],
                    rows: list.map((row) {
                      final artNo = row['art_no'] as String;
                      final desc = row['description'] as String;
                      final inLineQty = row['inLineQty'] as int;
                      final totalInward = row['totalInward'] as int;
                      final totalOutward = row['totalOutward'] as int;
                      final balance = row['balance'] as int;

                      final isPositive = balance > 0;
                      final String statusLabel = balance > 50
                          ? 'In Stock'
                          : (balance > 0
                              ? 'Low Stock'
                              : (inLineQty > 0 ? 'In Stitching' : 'Zero Stock'));

                      Color statusBg = const Color(0xFFEFF6FF);
                      Color statusBorder = const Color(0xFFBFDBFE);
                      Color statusText = const Color(0xFF2563EB);

                      if (balance > 50) {
                        statusBg = const Color(0xFFECFDF5);
                        statusBorder = const Color(0xFFA7F3D0);
                        statusText = const Color(0xFF059669);
                      } else if (balance > 0) {
                        statusBg = const Color(0xFFFFFBEB);
                        statusBorder = const Color(0xFFFDE68A);
                        statusText = const Color(0xFFD97706);
                      } else if (inLineQty > 0) {
                        statusBg = const Color(0xFFEFF6FF);
                        statusBorder = const Color(0xFFBFDBFE);
                        statusText = const Color(0xFF2563EB);
                      } else {
                        statusBg = const Color(0xFFFEF2F2);
                        statusBorder = const Color(0xFFFECDD3);
                        statusText = const Color(0xFFEF4444);
                      }

                      return DataRow(
                        cells: [
                          // 1. Article No
                          DataCell(
                            Text(
                              artNo,
                              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                            ),
                          ),

                          // 2. Description
                          DataCell(
                            Text(
                              desc.isNotEmpty && desc != '-' ? desc : 'SUIT - TOP',
                              style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF475569)),
                            ),
                          ),

                          // 3. Goods In Line
                          DataCell(
                            inLineQty > 0
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF0FDFA),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFBFE9DC)),
                                    ),
                                    child: Text(
                                      '${NumberFormat('#,###').format(inLineQty)} pcs',
                                      style: GoogleFonts.jetBrainsMono(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF0F766E)),
                                    ),
                                  )
                                : Text('-', style: GoogleFonts.jetBrainsMono(fontSize: 12, color: const Color(0xFF94A3B8))),
                          ),

                          // 4. Total Inward (QC)
                          DataCell(
                            Text(
                              '+${NumberFormat('#,###').format(totalInward)}',
                              style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFF059669)),
                            ),
                          ),

                          // 5. Total Outward (Dispatch)
                          DataCell(
                            Text(
                              '-${NumberFormat('#,###').format(totalOutward)}',
                              style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                            ),
                          ),

                          // 6. Godown Balance (pill: rose if 0, mint if >0)
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: isPositive ? const Color(0xFFF0FDFA) : const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: isPositive ? const Color(0xFFBFE9DC) : const Color(0xFFFECDD3)),
                              ),
                              child: Text(
                                '${NumberFormat('#,###').format(balance)} pcs',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: isPositive ? const Color(0xFF0F766E) : const Color(0xFFEF4444),
                                ),
                              ),
                            ),
                          ),

                          // 7. Status
                          DataCell(
                            Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                                decoration: BoxDecoration(
                                  color: statusBg,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: statusBorder),
                                ),
                                child: Text(
                                  statusLabel,
                                  style: GoogleFonts.publicSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: statusText,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildWebKpiOverviewCard({
    required String title,
    required String value,
    required String unit,
    required String caption,
    required IconData icon,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDFA),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBFE9DC)),
                ),
                child: Icon(icon, color: const Color(0xFF0F766E), size: 15),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: valueColor ?? const Color(0xFF0F172A),
                  height: 1.1,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: GoogleFonts.publicSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF94A3B8),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildWebStatusFilterChip(
    String key,
    String label,
    String currentSelected,
    Function(String) onSelect,
  ) {
    final isSelected = currentSelected == key;
    return InkWell(
      onTap: () => onSelect(key),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0B1220) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? const Color(0xFF0B1220) : const Color(0xFFE2E8F0)),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 1.5),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // WIDGET: TAB 2 (SUPPLIER GRN LIST)
  // ==========================================
  Widget _buildSupplierGrnSection() {
    var list = _truckInwards;

    if (_grnSearchQuery.trim().isNotEmpty) {
      final q = _grnSearchQuery.toLowerCase().trim();
      list = list.where((grn) {
        final gNo = (grn['grn_no'] ?? '').toString().toLowerCase();
        final pName = (grn['party_name'] ?? '').toString().toLowerCase();
        final artNo = (grn['article_no'] ?? '').toString().toLowerCase();
        final tNo = (grn['truck_no'] ?? '').toString().toLowerCase();
        return gNo.contains(q) || pName.contains(q) || artNo.contains(q) || tNo.contains(q);
      }).toList();
    }

    if (_grnStatusFilter == 'VERIFIED') {
      list = list.where((grn) => (grn['status'] ?? '').toString().toUpperCase() == 'VERIFIED').toList();
    } else if (_grnStatusFilter == 'SHORTAGE_DUE') {
      list = list.where((grn) {
        final st = (grn['status'] ?? '').toString().toUpperCase();
        return st == 'SHORTAGE' || st == 'DUE_PENDING';
      }).toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Supplier Challans (GRN)',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF14142B),
                letterSpacing: -0.3,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE6F7F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFE9DC)),
              ),
              child: Text(
                '${_truckInwards.length} slips recorded',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F766E),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Search & Filter
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              TextField(
                onChanged: (val) => setState(() => _grnSearchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search GRN, supplier, truck...',
                  hintStyle: GoogleFonts.publicSans(fontSize: 12.5, color: const Color(0xFF8A94A6)),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF8A94A6)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  isDense: true,
                ),
                style: GoogleFonts.publicSans(fontSize: 12.5),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildFilterChip('ALL', 'All (${_truckInwards.length})', _grnStatusFilter, (v) => setState(() => _grnStatusFilter = v)),
                    const SizedBox(width: 6),
                    _buildFilterChip('VERIFIED', 'Verified', _grnStatusFilter, (v) => setState(() => _grnStatusFilter = v)),
                    const SizedBox(width: 6),
                    _buildFilterChip('SHORTAGE_DUE', 'Shortage / Due', _grnStatusFilter, (v) => setState(() => _grnStatusFilter = v)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        if (list.isEmpty)
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.receipt_long_outlined, size: 36, color: Color(0xFF8A94A6)),
                  const SizedBox(height: 8),
                  Text(
                    'No supplier GRN slips recorded yet.',
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          )
        else
          ...list.map((inward) => _buildTruckInwardCard(inward)),
      ],
    );
  }

  // ==========================================
  // WIDGET: TAB 3 (RAW MATERIALS & TRIMS)
  // ==========================================
  Widget _buildRawMaterialsTrimsSection() {
    final Map<String, Map<String, dynamic>> trimMap = {};

    for (var acc in _accessories) {
      final name = (acc['item_name'] ?? '').toString().trim();
      if (name.isEmpty) continue;
      final unit = (acc['unit'] ?? 'pcs').toString().trim();
      final date = (acc['entry_date'] ?? acc['created_at']?.toString().split('T')[0] ?? '-').toString();
      final action = (acc['action'] ?? 'IN').toString().toUpperCase();
      final qty = parseQty(acc['quantity']);

      if (!trimMap.containsKey(name)) {
        trimMap[name] = {
          'item_name': name,
          'unit': unit,
          'totalIn': 0,
          'totalOut': 0,
          'balance': 0,
          'lastMovement': date,
        };
      }

      if (action == 'IN') {
        trimMap[name]!['totalIn'] = (trimMap[name]!['totalIn'] as int) + qty;
        trimMap[name]!['balance'] = (trimMap[name]!['balance'] as int) + qty;
      } else if (action == 'OUT') {
        trimMap[name]!['totalOut'] = (trimMap[name]!['totalOut'] as int) + qty;
        trimMap[name]!['balance'] = (trimMap[name]!['balance'] as int) - qty;
      }
    }

    var list = trimMap.values.toList();

    final totalTrimTypes = list.length;
    final inStockTrimsCount = list.where((it) => (it['balance'] as int) >= 10).length;
    final lowStockTrimsCount = list.where((it) => (it['balance'] as int) > 0 && (it['balance'] as int) < 10).length;
    final outStockTrimsCount = list.where((it) => (it['balance'] as int) <= 0).length;

    if (_trimsSearchQuery.trim().isNotEmpty) {
      final q = _trimsSearchQuery.toLowerCase().trim();
      list = list.where((it) => (it['item_name'] as String).toLowerCase().contains(q)).toList();
    }

    if (_trimsStatusFilter == 'IN_STOCK') {
      list = list.where((it) => (it['balance'] as int) >= 10).toList();
    } else if (_trimsStatusFilter == 'LOW_STOCK') {
      list = list.where((it) => (it['balance'] as int) > 0 && (it['balance'] as int) < 10).toList();
    } else if (_trimsStatusFilter == 'OUT_OF_STOCK') {
      list = list.where((it) => (it['balance'] as int) <= 0).toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Raw Materials & Trims Ledger',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF14142B),
                letterSpacing: -0.3,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE6F7F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFE9DC)),
              ),
              child: Text(
                '$totalTrimTypes items',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F766E),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // KPI Summary Bar
        Row(
          children: [
            Expanded(
              child: _buildSmallKpiCard(
                label: 'In Stock (>=10)',
                value: '$inStockTrimsCount items',
                color: const Color(0xFF0F766E),
                bg: const Color(0xFFE6F7F2),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSmallKpiCard(
                label: 'Low Stock (<10)',
                value: '$lowStockTrimsCount items',
                color: const Color(0xFFD97706),
                bg: const Color(0xFFFEF3C7),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSmallKpiCard(
                label: 'Out of Stock',
                value: '$outStockTrimsCount items',
                color: const Color(0xFFE11D48),
                bg: const Color(0xFFFEF2F4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Search & Filter
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              TextField(
                onChanged: (val) => setState(() => _trimsSearchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search trim item name...',
                  hintStyle: GoogleFonts.publicSans(fontSize: 12.5, color: const Color(0xFF8A94A6)),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF8A94A6)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  isDense: true,
                ),
                style: GoogleFonts.publicSans(fontSize: 12.5),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildFilterChip('ALL', 'All ($totalTrimTypes)', _trimsStatusFilter, (v) => setState(() => _trimsStatusFilter = v)),
                    const SizedBox(width: 6),
                    _buildFilterChip('IN_STOCK', 'In Stock ($inStockTrimsCount)', _trimsStatusFilter, (v) => setState(() => _trimsStatusFilter = v)),
                    const SizedBox(width: 6),
                    _buildFilterChip('LOW_STOCK', 'Low Stock ($lowStockTrimsCount)', _trimsStatusFilter, (v) => setState(() => _trimsStatusFilter = v)),
                    const SizedBox(width: 6),
                    _buildFilterChip('OUT_OF_STOCK', 'Out of Stock ($outStockTrimsCount)', _trimsStatusFilter, (v) => setState(() => _trimsStatusFilter = v)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        if (list.isEmpty)
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.widgets_outlined, size: 36, color: Color(0xFF8A94A6)),
                  const SizedBox(height: 8),
                  Text(
                    'No trims or accessories matched.',
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          )
        else
          ...list.map((trim) => _buildTrimItemCard(trim)),
      ],
    );
  }

  Widget _buildTrimItemCard(Map<String, dynamic> trim) {
    final name = trim['item_name'] as String;
    final unit = trim['unit'] as String;
    final totalIn = trim['totalIn'] as int;
    final totalOut = trim['totalOut'] as int;
    final balance = trim['balance'] as int;
    final lastMovement = trim['lastMovement'] as String;

    final isPositive = balance >= 10;
    final isLow = balance > 0 && balance < 10;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6F7F2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.widgets_outlined, size: 16, color: Color(0xFF0F766E)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF14142B),
                            ),
                          ),
                          Text(
                            'Unit: $unit',
                            style: GoogleFonts.publicSans(
                              fontSize: 11,
                              color: const Color(0xFF5B6478),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$balance $unit',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: isPositive ? const Color(0xFF0F766E) : (isLow ? const Color(0xFFD97706) : const Color(0xFFE11D48)),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isPositive
                          ? const Color(0xFFE6F7F2)
                          : (isLow ? const Color(0xFFFEF3C7) : const Color(0xFFFEF2F4)),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isPositive
                            ? const Color(0xFFBFE9DC)
                            : (isLow ? const Color(0xFFF5D67A) : const Color(0xFFF8C9D1)),
                      ),
                    ),
                    child: Text(
                      isPositive ? 'IN STOCK' : (isLow ? 'LOW STOCK' : 'OUT OF STOCK'),
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        color: isPositive
                            ? const Color(0xFF0F766E)
                            : (isLow ? const Color(0xFF92400E) : const Color(0xFFBE123C)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Inward: +$totalIn • Outward: -$totalOut',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10.5,
                  color: const Color(0xFF5B6478),
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Last: $lastMovement',
                style: GoogleFonts.publicSans(
                  fontSize: 10,
                  color: const Color(0xFF8A94A6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // WIDGET: TAB 4 (DISPATCH & CHALLANS)
  // ==========================================
  Widget _buildDispatchChallansSection() {
    var list = _storeTransactions.where((t) => (t['type'] ?? '').toString().toUpperCase() == 'OUTWARD').toList();

    final totalDispatchedPcs = list.fold<int>(0, (sum, tx) => sum + parseQty(tx['quantity']));

    if (_dispatchSearchQuery.trim().isNotEmpty) {
      final q = _dispatchSearchQuery.toLowerCase().trim();
      list = list.where((tx) {
        final artNo = (tx['article']?['art_no'] ?? tx['art_no'] ?? '').toString().toLowerCase();
        final party = (tx['party_name'] ?? '').toString().toLowerCase();
        final chNo = (tx['challan_no'] ?? '').toString().toLowerCase();
        final trNo = (tx['transport_no'] ?? '').toString().toLowerCase();
        final notes = (tx['notes'] ?? '').toString().toLowerCase();
        return artNo.contains(q) || party.contains(q) || chNo.contains(q) || trNo.contains(q) || notes.contains(q);
      }).toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Dispatch & Challans Outward',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF14142B),
                letterSpacing: -0.3,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F3FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFDDD6F0)),
              ),
              child: Text(
                '$totalDispatchedPcs pcs dispatched',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF332B6B),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Search
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: TextField(
            onChanged: (val) => setState(() => _dispatchSearchQuery = val),
            decoration: InputDecoration(
              hintText: 'Search dispatch challan, article, party, vehicle...',
              hintStyle: GoogleFonts.publicSans(fontSize: 12.5, color: const Color(0xFF8A94A6)),
              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF8A94A6)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              isDense: true,
            ),
            style: GoogleFonts.publicSans(fontSize: 12.5),
          ),
        ),
        const SizedBox(height: 12),

        if (list.isEmpty)
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.local_shipping_outlined, size: 36, color: Color(0xFF8A94A6)),
                  const SizedBox(height: 8),
                  Text(
                    'No outward dispatch records recorded yet.',
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          )
        else
          ...list.map((tx) => _buildDispatchCard(tx)),
      ],
    );
  }

  Widget _buildDispatchCard(dynamic tx) {
    final artNo = (tx['article']?['art_no'] ?? tx['art_no'] ?? '-').toString();
    final color = (tx['color'] ?? '').toString();
    final size = (tx['size'] ?? '').toString();
    final qty = parseQty(tx['quantity']);
    final party = (tx['party_name'] ?? 'Buyer / Destination').toString();
    final chNo = (tx['challan_no'] ?? '-').toString();
    final trNo = (tx['transport_no'] ?? '-').toString();
    final date = (tx['entry_date'] ?? tx['created_at']?.toString().split('T')[0] ?? '-').toString();
    final notes = (tx['notes'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F3FA),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.local_shipping_outlined, size: 16, color: Color(0xFF332B6B)),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        artNo,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF14142B),
                        ),
                      ),
                      if (color.isNotEmpty || size.isNotEmpty)
                        Text(
                          '$color $size',
                          style: GoogleFonts.publicSans(fontSize: 11, color: const Color(0xFF5B6478)),
                        ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F3FA),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFDDD6F0)),
                ),
                child: Text(
                  '-$qty pcs',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF332B6B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.storefront_outlined, size: 13, color: Color(0xFF8A94A6)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  party,
                  style: GoogleFonts.publicSans(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF14142B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Challan: $chNo • Vehicle: $trNo',
                style: GoogleFonts.jetBrainsMono(fontSize: 10, color: const Color(0xFF5B6478)),
              ),
              Text(
                date,
                style: GoogleFonts.publicSans(fontSize: 10, color: const Color(0xFF8A94A6)),
              ),
            ],
          ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              notes,
              style: GoogleFonts.publicSans(fontSize: 10.5, fontStyle: FontStyle.italic, color: const Color(0xFF8A94A6)),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // WIDGET: TAB 5 (INWARD RECEIPTS)
  // ==========================================
  Widget _buildInwardReceiptsSection() {
    var list = _storeTransactions.where((t) => (t['type'] ?? '').toString().toUpperCase() == 'INWARD').toList();

    final totalInwardPcs = list.fold<int>(0, (sum, tx) => sum + parseQty(tx['quantity']));

    if (_inwardSearchQuery.trim().isNotEmpty) {
      final q = _inwardSearchQuery.toLowerCase().trim();
      list = list.where((tx) {
        final artNo = (tx['article']?['art_no'] ?? tx['art_no'] ?? '').toString().toLowerCase();
        final party = (tx['party_name'] ?? '').toString().toLowerCase();
        final chNo = (tx['challan_no'] ?? '').toString().toLowerCase();
        final notes = (tx['notes'] ?? '').toString().toLowerCase();
        return artNo.contains(q) || party.contains(q) || chNo.contains(q) || notes.contains(q);
      }).toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Inward Receipts (QC & Godown)',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF14142B),
                letterSpacing: -0.3,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE6F7F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFE9DC)),
              ),
              child: Text(
                '+$totalInwardPcs pcs inwarded',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F766E),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Search
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: TextField(
            onChanged: (val) => setState(() => _inwardSearchQuery = val),
            decoration: InputDecoration(
              hintText: 'Search inward receipts, articles, parties...',
              hintStyle: GoogleFonts.publicSans(fontSize: 12.5, color: const Color(0xFF8A94A6)),
              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF8A94A6)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              isDense: true,
            ),
            style: GoogleFonts.publicSans(fontSize: 12.5),
          ),
        ),
        const SizedBox(height: 12),

        if (list.isEmpty)
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.check_circle_outline_rounded, size: 36, color: Color(0xFF8A94A6)),
                  const SizedBox(height: 8),
                  Text(
                    'No inward receipts recorded yet.',
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          )
        else
          ...list.map((tx) => _buildInwardCard(tx)),
      ],
    );
  }

  Widget _buildInwardCard(dynamic tx) {
    final artNo = (tx['article']?['art_no'] ?? tx['art_no'] ?? '-').toString();
    final color = (tx['color'] ?? '').toString();
    final size = (tx['size'] ?? '').toString();
    final qty = parseQty(tx['quantity']);
    final party = (tx['party_name'] ?? 'Production Line / QC').toString();
    final chNo = (tx['challan_no'] ?? '-').toString();
    final date = (tx['entry_date'] ?? tx['created_at']?.toString().split('T')[0] ?? '-').toString();
    final notes = (tx['notes'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6F7F2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.check_circle_outline_rounded, size: 16, color: Color(0xFF0F766E)),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        artNo,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF14142B),
                        ),
                      ),
                      if (color.isNotEmpty || size.isNotEmpty)
                        Text(
                          '$color $size',
                          style: GoogleFonts.publicSans(fontSize: 11, color: const Color(0xFF5B6478)),
                        ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F7F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBFE9DC)),
                ),
                child: Text(
                  '+$qty pcs',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0F766E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.person_outline_rounded, size: 13, color: Color(0xFF8A94A6)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  party,
                  style: GoogleFonts.publicSans(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF14142B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Challan Ref: $chNo',
                style: GoogleFonts.jetBrainsMono(fontSize: 10, color: const Color(0xFF5B6478)),
              ),
              Text(
                date,
                style: GoogleFonts.publicSans(fontSize: 10, color: const Color(0xFF8A94A6)),
              ),
            ],
          ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              notes,
              style: GoogleFonts.publicSans(fontSize: 10.5, fontStyle: FontStyle.italic, color: const Color(0xFF8A94A6)),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // SHARED MINI COMPONENTS
  // ==========================================
  Widget _buildSmallKpiCard({
    required String label,
    required String value,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.publicSans(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF5B6478),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, String currentSelected, Function(String) onSelect) {
    final isSelected = currentSelected == key;
    return InkWell(
      onTap: () => onSelect(key),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF332B6B) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? const Color(0xFF332B6B) : const Color(0xFFCBD5E1)),
        ),
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required Color bg,
    required Color border,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            '$label: ',
            style: GoogleFonts.publicSans(fontSize: 10, color: const Color(0xFF5B6478)),
          ),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // HELPER MODALS: ACTIONS, RADAR & DRILLDOWN
  // ==========================================
  void _showCreateActionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Text(
                    'STORE & GODOWN ACTIONS',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF8A94A6),
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const Divider(height: 16),
                ListTile(
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6F7F2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.receipt_long_outlined, color: Color(0xFF0F766E), size: 20),
                  ),
                  title: Text('Accessory Challan Inward (GRN)', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13.5)),
                  subtitle: Text('Record supplier delivery slip, trims, fabrics & due items', style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF5B6478))),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showAccessoryChallanInwardModal();
                  },
                ),
                ListTile(
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.fact_check_outlined, color: Color(0xFF4338CA), size: 20),
                  ),
                  title: Text('BOM Material Handover', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13.5)),
                  subtitle: Text('Inspect supplier challan & issue materials to Lineman', style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF5B6478))),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showMaterialHandoverModal();
                  },
                ),
                ListTile(
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.sync_problem_rounded, color: Color(0xFFB45309), size: 20),
                  ),
                  title: Text('Floor Loss / Re-Issue', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13.5)),
                  subtitle: Text('Log replacement accessories given to tailors for lost trims', style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF5B6478))),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showBufferReplacementClaimModal();
                  },
                ),
                ListTile(
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF059669), size: 20),
                  ),
                  title: Text('Finished Goods Inward', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13.5)),
                  subtitle: Text('Inward QC-approved ready garments into Godown stock', style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF5B6478))),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showInwardModal();
                  },
                ),
                ListTile(
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.local_shipping_outlined, color: Color(0xFF2563EB), size: 20),
                  ),
                  title: Text('Godown Outward / Dispatch', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13.5)),
                  subtitle: Text('Record finished garment delivery & transport dispatch', style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF5B6478))),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showOutwardModal();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLowStockRadarDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 22),
            const SizedBox(width: 8),
            Text(
              'Trims Safety Radar',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Monitored trims & accessories below minimum floor safety stock.',
                style: GoogleFonts.publicSans(fontSize: 12.5, color: const Color(0xFF5B6478)),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF8C9D1)),
                ),
                child: Column(
                  children: [
                    _buildRadarItemRow('Main Brand Neck Tag', '0 pcs remaining', 'Min: 500 pcs', true),
                    const Divider(height: 12),
                    _buildRadarItemRow('Matching Sewing Thread', '4 cones remaining', 'Min: 15 cones', false),
                    const Divider(height: 12),
                    _buildRadarItemRow('Washing Care & Size Label', '120 pcs remaining', 'Min: 500 pcs', false),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2F55D4),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _showAccessoryChallanInwardModal();
            },
            child: const Text('New Supplier GRN'),
          ),
        ],
      ),
    );
  }

  Widget _buildRadarItemRow(String name, String balance, String min, bool isCritical) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 12)),
              Text(min, style: GoogleFonts.publicSans(fontSize: 10.5, color: const Color(0xFF8A94A6))),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isCritical ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            balance,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isCritical ? const Color(0xFFDC2626) : const Color(0xFFB45309),
            ),
          ),
        ),
      ],
    );
  }

  void _showGoodsInLineDrilldown() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6F7F2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.show_chart_rounded, color: Color(0xFF0F766E), size: 18),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Goods on Floor WIP (${_activeAllotments.length} Active Lots)',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF14142B),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(height: 16),
              Expanded(
                child: _activeAllotments.isEmpty
                    ? const Center(child: Text('No active lots on the floor.'))
                    : ListView.builder(
                        itemCount: _activeAllotments.length,
                        itemBuilder: (ctx, i) {
                          final al = _activeAllotments[i];
                          final artNo = al['articles']?['art_no'] ?? al['art_no'] ?? 'Garment';
                          final lineman = al['profiles']?['username'] ?? al['lineman_name'] ?? 'Lineman';
                          final qty = parseQty(al['target_qty']);
                          final challan = al['challans']?['challan_no'] ?? al['challan_no'] ?? '-';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Art #$artNo • Lot #$challan',
                                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    Text(
                                      'Assigned to $lineman',
                                      style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF5B6478)),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE6F7F2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '$qty pcs',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF0F766E),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _extractCategory(String desc, String? fabricType) {
    if (desc.isNotEmpty) {
      final parts = desc.split(RegExp(r'[-•:\/|]'));
      if (parts.isNotEmpty) {
        final p0 = parts[0].trim();
        if (p0.length >= 2 && !RegExp(r'^[0-9]+$').hasMatch(p0)) {
          return p0;
        }
      }
    }
    if (fabricType != null && fabricType.trim().isNotEmpty) {
      return fabricType.trim();
    }
    return 'Garment';
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, {String? unit, String? subtitle}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                if (unit != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.bg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Text(
                      unit,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.inkSoft,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: GoogleFonts.jetBrainsMono(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                color: AppTheme.ink,
                letterSpacing: -0.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.ink,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.publicSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: color == AppTheme.green ? AppTheme.green : AppTheme.inkSoft,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _telemetryCell(String label, String value, String unit, Color color) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: GoogleFonts.jetBrainsMono(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  color: color,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                unit,
                style: GoogleFonts.publicSans(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.inkSoft,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.publicSans(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: AppTheme.inkSoft,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _cellDivider() {
    return Container(width: 1, height: 30, color: AppTheme.border);
  }

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: GoogleFonts.publicSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded, size: 22, color: AppTheme.inkFaint),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // ACTIVITY FEED FILTER & GROUPED RENDERERS
  // ==========================================
  List<Map<String, dynamic>> _getFilteredStoreLogs() {
    final now = DateTime.now();
    return _storeLogs.cast<Map<String, dynamic>>().where((log) {
      // 1. Time filter (24h, 7d, all)
      if (_feedTimeFilter != 'all') {
        final createdStr = log['created_at']?.toString();
        DateTime? logTime;
        if (createdStr != null && createdStr.isNotEmpty) {
          logTime = DateTime.tryParse(createdStr)?.toLocal();
        }
        if (logTime != null) {
          final diff = now.difference(logTime);
          if (_feedTimeFilter == '24h' && diff.inHours >= 24) return false;
          if (_feedTimeFilter == '7d' && diff.inDays >= 7) return false;
        } else {
          final entryDate = log['entry_date']?.toString() ?? '';
          final today = now.toIso8601String().split('T')[0];
          if (_feedTimeFilter == '24h' && entryDate != today) return false;
        }
      }

      // 2. Category filter
      if (_feedCategoryFilter == 'BOM') {
        if (log['isGroupedBOM'] != true) return false;
      } else if (_feedCategoryFilter == 'TRIMS') {
        if (log['isAccessory'] != true || log['isGroupedBOM'] == true) return false;
      } else if (_feedCategoryFilter == 'GARMENTS') {
        if (log['isAccessory'] == true) return false;
      }

      // 3. Search query filter
      if (_feedSearchQuery.isNotEmpty) {
        final q = _feedSearchQuery.toLowerCase();
        final party = (log['party_name'] ?? '').toString().toLowerCase();
        final notes = (log['notes'] ?? '').toString().toLowerCase();
        final artNo = (log['art_no'] ?? '').toString().toLowerCase();
        final itemName = (log['item_name'] ?? '').toString().toLowerCase();
        final challan = (log['challan_no'] ?? '').toString().toLowerCase();

        bool itemMatch = false;
        if (log['isGroupedBOM'] == true && log['items'] is List) {
          for (var item in log['items']) {
            if (item['name'].toString().toLowerCase().contains(q)) {
              itemMatch = true;
              break;
            }
          }
        }

        if (!party.contains(q) &&
            !notes.contains(q) &&
            !artNo.contains(q) &&
            !itemName.contains(q) &&
            !challan.contains(q) &&
            !itemMatch) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  String _cleanNotes(dynamic rawNotes) {
    if (rawNotes == null) return '';
    String n = rawNotes.toString();
    n = n.replaceAll(RegExp(r'#?[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'), '');
    n = n.replaceAll('Allotment #', '');
    n = n.replaceAll('Allotment', '');
    n = n.replaceAll(RegExp(r'\s+•\s+•'), ' •');
    n = n.trim();
    if (n.startsWith('•')) n = n.substring(1).trim();
    if (n.endsWith('•')) n = n.substring(0, n.length - 1).trim();
    return n;
  }

  Widget _buildTimeFilterPill(String key, String label) {
    final isSelected = _feedTimeFilter == key;
    return GestureDetector(
      onTap: () => setState(() => _feedTimeFilter = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.steel : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : AppTheme.inkSoft,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilterPill(String key, String label, {IconData? icon}) {
    final isSelected = _feedCategoryFilter == key;
    return GestureDetector(
      onTap: () => setState(() => _feedCategoryFilter = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.ink : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppTheme.ink : AppTheme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.white : AppTheme.steel,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : AppTheme.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupedBOMCard(Map<String, dynamic> log) {
    final groupKey = log['groupKey'] ?? log['id'] ?? '';
    final isExpanded = _expandedBOMKeys.contains(groupKey);
    final party = log['party_name'] ?? 'Lineman Handover';
    final challan = log['challan_no'] ?? '';
    final totalItems = log['total_items_count'] ?? 0;
    final totalUnits = log['total_units_count'] ?? 0;
    final items = (log['items'] as List<dynamic>?) ?? [];
    final timeStr = log['created_at'] != null ? DateTime.parse(log['created_at']).toLocal().toString().substring(11, 16) : '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.amber.withValues(alpha: 0.35), width: 1.3),
        boxShadow: [
          BoxShadow(color: AppTheme.amber.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header / Summary Row (Tap to expand/collapse)
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedBOMKeys.remove(groupKey);
                } else {
                  _expandedBOMKeys.add(groupKey);
                }
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.amberMist,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.inventory_2_outlined, color: AppTheme.amber, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.amberMist,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'BOM PACKAGE ISSUED',
                                style: GoogleFonts.publicSans(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.amber,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                            if (challan.toString().isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.steelMist,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'CH-$challan',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.steel,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          party,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.ink,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$totalItems materials · $totalUnits units total',
                          style: GoogleFonts.publicSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        timeStr,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.inkFaint,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Icon(
                        isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        color: AppTheme.steel,
                        size: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Expanded Items Breakdown Table
          if (isExpanded) ...[
            const Divider(height: 1, color: AppTheme.border),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: const BoxDecoration(
                color: AppTheme.bg,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ISSUED RAW MATERIALS BREAKDOWN',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.inkFaint,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...items.map((item) {
                    final name = item['name']?.toString() ?? 'Material';
                    final qty = item['qty'] ?? 0;
                    final unit = item['unit'] ?? 'pcs';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline_rounded, size: 14, color: AppTheme.green),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              name,
                              style: GoogleFonts.publicSans(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.ink,
                              ),
                            ),
                          ),
                          Text(
                            '-$qty $unit',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.red,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLedgerCard(Map<String, dynamic> log) {
    if (log['isGroupedBOM'] == true) {
      return _buildGroupedBOMCard(log);
    }

    final isAcc = log['isAccessory'] == true;
    final timeStr = log['created_at'] != null ? DateTime.parse(log['created_at']).toLocal().toString().substring(11, 16) : '-';
    final cleanedNotes = _cleanNotes(log['notes']);

    if (isAcc) {
      final isIN = log['action'] == 'IN';
      final badgeColor = isIN ? AppTheme.green : AppTheme.amber;
      final badgeBg = isIN ? AppTheme.greenMist : AppTheme.amberMist;
      final badgeText = isIN ? 'Trims IN' : 'Trims OUT';
      final itemName = log['item_name'] ?? 'Item';
      final qty = log['quantity'] ?? 0;
      final unit = log['unit'] ?? 'pcs';
      final party = log['party_name'] ?? '';

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(8)),
                        child: Text(badgeText, style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.w800, color: badgeColor)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          itemName,
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.ink),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${isIN ? "+" : "-"}$qty $unit ${party.isNotEmpty ? "• $party" : ""}',
                    style: GoogleFonts.publicSans(fontSize: 12.5, color: AppTheme.inkSoft, fontWeight: FontWeight.w600),
                  ),
                  if (cleanedNotes.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Note: $cleanedNotes',
                      style: GoogleFonts.publicSans(fontSize: 11.5, color: AppTheme.inkFaint, fontStyle: FontStyle.italic),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              timeStr,
              style: GoogleFonts.jetBrainsMono(fontSize: 11.5, color: AppTheme.inkFaint, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    } else {
      final isIN = log['type'] == 'INWARD';
      final badgeColor = isIN ? AppTheme.green : AppTheme.steel;
      final badgeBg = isIN ? AppTheme.greenMist : AppTheme.steelMist;
      final badgeText = isIN ? 'Inward' : 'Outward';
      final artNo = log['art_no'] ?? '-';
      final color = log['color'] ?? '';
      final size = log['size'] ?? '';
      final hasVariant = color.isNotEmpty || size.isNotEmpty;
      final variantStr = hasVariant ? ' • $color ($size)' : '';
      final qty = log['quantity'] ?? 0;
      final party = log['party_name'] ?? '';
      final challan = log['challan_no'] ?? '';

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(8)),
                        child: Text(badgeText, style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.w800, color: badgeColor)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '$artNo$variantStr',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.ink),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${isIN ? "+" : "-"}$qty pcs ${party.isNotEmpty ? "• $party" : ""} ${challan.isNotEmpty ? "($challan)" : ""}',
                    style: GoogleFonts.publicSans(fontSize: 12.5, color: AppTheme.inkSoft, fontWeight: FontWeight.w600),
                  ),
                  if (cleanedNotes.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Note: $cleanedNotes',
                      style: GoogleFonts.publicSans(fontSize: 11.5, color: AppTheme.inkFaint, fontStyle: FontStyle.italic),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              timeStr,
              style: GoogleFonts.jetBrainsMono(fontSize: 11.5, color: AppTheme.inkFaint, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildArticleBufferLedgerSection() {
    // 1. Group active production allotments by Article No
    final Map<String, Map<String, dynamic>> articleGroups = {};

    for (var al in _activeAllotments) {
      final art = (al['articles']?['art_no'] ?? '').toString().trim().toUpperCase();
      if (art.isEmpty) continue;
      if (!articleGroups.containsKey(art)) {
        final artId = al['article_id']?.toString() ?? '';
        final stock = _articleStockMap[artId] ?? 0;
        articleGroups[art] = {
          'art_no': art,
          'total_inward': stock,
          'total_allotted': 0,
          'allotments': <dynamic>[],
        };
      }
      articleGroups[art]!['total_allotted'] = (articleGroups[art]!['total_allotted'] as int) + parseQty(al['target_qty']);
      (articleGroups[art]!['allotments'] as List<dynamic>).add(al);
    }

    // Only display when active floor batches exist
    if (articleGroups.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Article & Safety Buffer Ledger',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.ink,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Live floor consumption & mending buffer reserve',
                    style: GoogleFonts.publicSans(fontSize: 11, color: AppTheme.inkSoft, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Buffer % Selector Pills
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [3, 5, 8, 10].map((pct) {
                  final isSel = _safetyBufferPct == pct;
                  return InkWell(
                    onTap: () => setState(() => _safetyBufferPct = pct),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSel ? AppTheme.steel : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$pct%',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isSel ? Colors.white : AppTheme.inkSoft,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        ...articleGroups.values.map((grp) {
          final artNo = grp['art_no'] as String;
          final totalInward = grp['total_inward'] as int;
          final totalAllotted = grp['total_allotted'] as int;
          final buffer = ((totalAllotted * _safetyBufferPct) / 100).ceil();
          final claimed = _bufferClaims
              .where((c) => c['art_no'] == artNo)
              .fold(0, (sum, c) => sum + parseQty(c['qty']));
          final available = (buffer - claimed).clamp(0, 999999);
          final lots = grp['allotments'] as List<dynamic>;
          final balance = totalAllotted;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Art No & Quick Action
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.steelMist,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'ART #$artNo',
                            style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.steel),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${lots.length} Lines',
                          style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.inkSoft),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.shield_rounded, size: 14),
                      label: const Text('Claim Buffer', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFEF3C7),
                        foregroundColor: const Color(0xFFD97706),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _showBufferReplacementClaimModal(preselectedArtNo: artNo),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Metrics Strip
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('INWARD', style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.inkFaint)),
                            const SizedBox(height: 2),
                            Text('$totalInward', style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.ink)),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 26, color: AppTheme.border),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ALLOTTED', style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.inkFaint)),
                            const SizedBox(height: 2),
                            Text('$totalAllotted', style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A))),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 26, color: AppTheme.border),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('BALANCE', style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.inkFaint)),
                            const SizedBox(height: 2),
                            Text('$balance', style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.steel)),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 26, color: AppTheme.border),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('BUFFER', style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFFD97706))),
                            const SizedBox(height: 2),
                            Text(
                              '$available${claimed > 0 ? " (-$claimed)" : ""}',
                              style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFFD97706)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTruckInwardCard(Map<String, dynamic> inward) {
    final grnNo = inward['grn_no'] ?? 'GRN';
    final partyName = inward['party_name'] ?? 'Supplier';
    final articleNo = inward['article_no'] ?? '';
    final challanNo = inward['challan_no'] ?? '';
    final inwardDate = inward['inward_date'] ?? '';
    final totalItems = inward['total_items'] ?? 0;
    final dueCount = inward['due_items_count'] ?? 0;
    final shortageCount = inward['shortage_items_count'] ?? 0;
    final photoUrl = inward['challan_photo_url'] as String?;

    Color badgeColor = AppTheme.green;
    Color badgeBg = AppTheme.greenMist;
    String statusText = 'Verified ($totalItems items)';
    IconData statusIcon = Icons.check_circle_rounded;

    if (dueCount > 0) {
      badgeColor = AppTheme.steel;
      badgeBg = AppTheme.steelMist;
      statusText = '$dueCount Due Items';
      statusIcon = Icons.pending_actions_rounded;
    } else if (shortageCount > 0) {
      badgeColor = AppTheme.amber;
      badgeBg = AppTheme.amberMist;
      statusText = '$shortageCount Shortage';
      statusIcon = Icons.warning_amber_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(color: AppTheme.steelMist, borderRadius: BorderRadius.circular(8)),
                child: Text(grnNo, style: GoogleFonts.jetBrainsMono(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.steel)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    Icon(statusIcon, size: 13, color: badgeColor),
                    const SizedBox(width: 4),
                    Text(statusText, style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.w800, color: badgeColor)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            partyName + (articleNo.isNotEmpty ? ' • Art $articleNo' : ''),
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14.5, color: AppTheme.ink),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Challan: ${challanNo.isNotEmpty ? challanNo : "Direct"} • $inwardDate',
                  style: GoogleFonts.publicSans(fontSize: 12, color: AppTheme.inkSoft, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              if (photoUrl != null && photoUrl.isNotEmpty) ...[
                InkWell(
                  onTap: () => _showPhotoViewerModal(photoUrl, '$partyName (Challan #$challanNo)'),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.bg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.photo_rounded, size: 13, color: AppTheme.steel),
                        const SizedBox(width: 4),
                        Text(
                          'View Slip',
                          style: GoogleFonts.publicSans(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.steel),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () => _showAttachChallanPhotoModal(inward),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.steelMist,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.steelTint),
                    ),
                    child: const Icon(Icons.camera_alt_rounded, size: 13, color: AppTheme.steel),
                  ),
                ),
              ] else
                InkWell(
                  onTap: () => _showAttachChallanPhotoModal(inward),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF7F0),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF3A3564).withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.camera_alt_outlined, size: 13, color: Color(0xFF3A3564)),
                        const SizedBox(width: 4),
                        Text(
                          'Attach Slip Photo',
                          style: GoogleFonts.publicSans(fontSize: 11.5, fontWeight: FontWeight.w800, color: const Color(0xFF3A3564)),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          if (inward['notes'] != null && inward['notes'].toString().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Remarks: ${inward['notes']}',
              style: GoogleFonts.publicSans(fontSize: 11.5, color: AppTheme.inkFaint, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  void _showAttachChallanPhotoModal(Map<String, dynamic> inward) {
    File? selectedImage;
    String? existingPhotoUrl = inward['challan_photo_url'] as String?;
    bool isSubmitting = false;

    final grnNo = inward['grn_no'] ?? 'GRN';
    final partyName = inward['party_name'] ?? 'Supplier';
    final challanNo = inward['challan_no'] ?? '';
    final articleNo = inward['article_no'] ?? '';
    final totalItems = inward['total_items'] ?? 0;
    final inwardId = inward['id'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final mediaQuery = MediaQuery.of(context);
          final picker = ImagePicker();

          Future<void> pickImage(ImageSource source) async {
            try {
              final picked = await picker.pickImage(source: source, imageQuality: 80, maxWidth: 1600);
              if (picked != null) {
                setModalState(() {
                  selectedImage = File(picked.path);
                });
              }
            } catch (e) {
              debugPrint('Image pick error: $e');
            }
          }

          return Container(
            constraints: BoxConstraints(
              maxHeight: mediaQuery.size.height * 0.85,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              bottom: mediaQuery.viewInsets.bottom,
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Drag Handle & Fixed Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
                    child: Column(
                      children: [
                        Center(
                          child: Container(
                            width: 38,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppTheme.border,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.steelMist,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.camera_alt_rounded, color: AppTheme.steel, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Attach Paper Slip Photo',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16.5,
                                      color: AppTheme.ink,
                                    ),
                                  ),
                                  Text(
                                    'Upload physical supplier delivery challan for audit',
                                    style: GoogleFonts.publicSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.inkSoft,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: AppTheme.inkSoft, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(height: 1, color: AppTheme.border),

                  // Middle Scrollable Body
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // READ-ONLY IMMUTABLE STRIP
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppTheme.bg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppTheme.steelMist,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        grnNo,
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.steel,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: AppTheme.border),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.lock_outline_rounded, size: 12, color: AppTheme.inkSoft),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Items & Qty Locked',
                                            style: GoogleFonts.publicSans(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppTheme.inkSoft),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  partyName + (articleNo.toString().isNotEmpty ? ' • Art $articleNo' : ''),
                                  style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.ink),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Challan: ${challanNo.toString().isNotEmpty ? challanNo : "Direct"} • $totalItems items in GRN',
                                  style: GoogleFonts.publicSans(fontSize: 12, color: AppTheme.inkSoft, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),

                          // PHOTO UPLOADER & PREVIEW
                          Text(
                            'Challan Paper Slip Photo *',
                            style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.ink),
                          ),
                          const SizedBox(height: 8),

                          if (selectedImage != null)
                            Stack(
                              children: [
                                Container(
                                  width: double.infinity,
                                  height: 220,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: AppTheme.steel, width: 1.5),
                                    image: DecorationImage(
                                      image: FileImage(selectedImage!),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 10,
                                  right: 10,
                                  child: InkWell(
                                    onTap: () => setModalState(() => selectedImage = null),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent.withValues(alpha: 0.9),
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: [
                                          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 6),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 14),
                                          const SizedBox(width: 4),
                                          Text('Remove', style: GoogleFonts.publicSans(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else if (existingPhotoUrl != null && existingPhotoUrl.isNotEmpty)
                            Stack(
                              children: [
                                Container(
                                  width: double.infinity,
                                  height: 200,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: AppTheme.border),
                                    image: DecorationImage(
                                      image: NetworkImage(existingPhotoUrl),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 10,
                                  right: 10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.75),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text('Current Uploaded Slip', style: GoogleFonts.publicSans(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            )
                          else
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                              decoration: BoxDecoration(
                                color: AppTheme.bg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.add_a_photo_outlined, size: 36, color: AppTheme.inkSoft.withValues(alpha: 0.6)),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No paper challan photo attached yet',
                                    style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.ink),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Take photo from camera or pick from gallery below',
                                    style: GoogleFonts.publicSans(fontSize: 11.5, color: AppTheme.inkSoft),
                                  ),
                                ],
                              ),
                            ),

                          const SizedBox(height: 14),

                          // Camera & Gallery Buttons
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => pickImage(ImageSource.camera),
                                  icon: const Icon(Icons.camera_alt_rounded, size: 16),
                                  label: Text(
                                    selectedImage != null || (existingPhotoUrl != null && existingPhotoUrl.isNotEmpty) ? 'Retake Photo' : 'Take Camera Photo',
                                    style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.w700),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.steel,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => pickImage(ImageSource.gallery),
                                  icon: const Icon(Icons.photo_library_rounded, size: 16, color: AppTheme.steel),
                                  label: Text(
                                    'Pick Gallery',
                                    style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.steel),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    side: const BorderSide(color: AppTheme.border),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Fixed Bottom Action Bar
                  Container(height: 1, color: AppTheme.border),
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    color: Colors.white,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 88,
                          height: 48,
                          child: OutlinedButton(
                            onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              side: const BorderSide(color: AppTheme.border),
                              padding: EdgeInsets.zero,
                            ),
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.publicSans(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppTheme.inkSoft),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: (selectedImage == null || isSubmitting)
                                  ? null
                                  : () async {
                                      setModalState(() => isSubmitting = true);
                                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                                      final nav = Navigator.of(ctx);

                                      try {
                                        String? photoUrl;
                                        final bytes = await selectedImage!.readAsBytes();
                                        final fileName = 'challan_${DateTime.now().millisecondsSinceEpoch}.jpg';
                                        try {
                                          await supabase.storage.from('challans').uploadBinary(fileName, bytes);
                                          photoUrl = supabase.storage.from('challans').getPublicUrl(fileName);
                                        } catch (_) {
                                          photoUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                                        }

                                        await supabase.from('truck_inwards').update({
                                          'challan_photo_url': photoUrl,
                                        }).eq('id', inwardId);

                                        nav.pop();
                                        scaffoldMessenger.showSnackBar(
                                          SnackBar(
                                            content: Text('Paper slip photo attached successfully to $grnNo!'),
                                            backgroundColor: AppTheme.steel,
                                          ),
                                        );
                                        _fetchStoreData();
                                      } catch (e) {
                                        setModalState(() => isSubmitting = false);
                                        scaffoldMessenger.showSnackBar(
                                          SnackBar(content: Text('Error saving photo: $e'), backgroundColor: Colors.redAccent),
                                        );
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.steel,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                disabledBackgroundColor: AppTheme.steel.withValues(alpha: 0.3),
                              ),
                              child: isSubmitting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : Text(
                                      'Save & Attach Photo',
                                      style: GoogleFonts.publicSans(fontSize: 14, fontWeight: FontWeight.w700),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQcReadyQueueCard(Map<String, dynamic> lot) {
    final artNo = lot['art_no'] ?? 'Article';
    final desc = lot['description'] ?? '';
    final color = lot['color_name'] ?? 'STANDARD';
    final challanNo = lot['challan_no'] ?? '-';
    final int passedQty = parseQty(lot['qc_passed_qty']);
    final lineman = lot['lineman_name'] ?? 'Lineman';
    final qcName = lot['qc_name'] ?? 'QC Supervisor';
    final priority = (lot['priority'] ?? 'NORMAL').toString().toUpperCase();
    final isCritical = priority == 'CRITICAL';
    final isRush = priority == 'RUSH';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isCritical ? const Color(0xFFFFF5F5) : (isRush ? const Color(0xFFFFFDF5) : Colors.white),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCritical
              ? const Color(0xFFFCA5A5)
              : (isRush ? const Color(0xFFFDE68A) : AppTheme.green.withValues(alpha: 0.4)),
          width: isCritical ? 1.5 : 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: isCritical
                ? const Color(0xFFEF4444).withValues(alpha: 0.08)
                : AppTheme.green.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Urgency Alert Banner (if CRITICAL or RUSH)
          if (isCritical) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFCA5A5), width: 1.2),
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_fire_department_rounded, size: 15, color: Color(0xFFDC2626)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'CRITICAL / EXPORT PRIORITY • सबसे पहले इनवर्ड करो (DO THIS FIRST)',
                      style: GoogleFonts.publicSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF991B1B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (isRush) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bolt_rounded, size: 15, color: Color(0xFFD97706)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'RUSH ORDER PRIORITY • उच्च प्राथमिकता',
                      style: GoogleFonts.publicSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: AppTheme.steelMist, borderRadius: BorderRadius.circular(6)),
                    child: Text('CH-$challanNo', style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.steel)),
                  ),
                  if (isCritical) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.local_fire_department_rounded, size: 12, color: Color(0xFFDC2626)),
                          const SizedBox(width: 2),
                          Text(
                            'CRITICAL',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFFDC2626),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (isRush) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bolt_rounded, size: 12, color: Color(0xFFD97706)),
                          const SizedBox(width: 2),
                          Text(
                            'RUSH',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFFD97706),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppTheme.greenMist, borderRadius: BorderRadius.circular(6)),
                child: Text('QC Passed: $passedQty pcs', style: GoogleFonts.jetBrainsMono(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.green)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Art #$artNo · $color', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.ink)),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(desc, style: GoogleFonts.publicSans(fontSize: 12, color: AppTheme.inkSoft)),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildCustodyChip('Lineman: $lineman', Icons.person_outline_rounded, AppTheme.inkSoft),
              _buildCustodyChip('QC: $qcName', Icons.verified_outlined, AppTheme.green),
              _buildCustodyChip('Admin: ${lot['admin_approved_by'] ?? 'Approved'}', Icons.shield_outlined, AppTheme.steel),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.download_done_rounded, size: 16, color: Colors.white),
              label: Text('Collect & Inward', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.green,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              onPressed: () => _showInwardModal(prefilledLot: lot),
            ),
          ),
        ],
      ),
    );
  }
}

class _WavingHandIcon extends StatefulWidget {
  final double size;
  const _WavingHandIcon({this.size = 20});

  @override
  State<_WavingHandIcon> createState() => _WavingHandIconState();
}

class _WavingHandIconState extends State<_WavingHandIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _waveAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _waveAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.26).chain(CurveTween(curve: Curves.easeOut)), weight: 12),
      TweenSequenceItem(tween: Tween(begin: -0.26, end: 0.22).chain(CurveTween(curve: Curves.easeInOut)), weight: 16),
      TweenSequenceItem(tween: Tween(begin: 0.22, end: -0.22).chain(CurveTween(curve: Curves.easeInOut)), weight: 16),
      TweenSequenceItem(tween: Tween(begin: -0.22, end: 0.16).chain(CurveTween(curve: Curves.easeInOut)), weight: 14),
      TweenSequenceItem(tween: Tween(begin: 0.16, end: 0.0).chain(CurveTween(curve: Curves.easeIn)), weight: 12),
      TweenSequenceItem(tween: ConstantTween<double>(0.0), weight: 30),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _waveAnim,
      builder: (context, child) {
        return Transform.rotate(
          angle: _waveAnim.value,
          alignment: const Alignment(0.4, 0.9),
          child: child,
        );
      },
      child: Icon(
        Icons.waving_hand_outlined,
        color: AppTheme.steel,
        size: widget.size,
      ),
    );
  }
}