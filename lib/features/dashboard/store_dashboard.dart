import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../auth/providers/auth_provider.dart';
import '../auth/screens/login_screen.dart';
import '../../core/theme/app_theme.dart';
import '../../../main.dart'; // supabase client

class _AccessoryChallanItem {
  TextEditingController nameController;
  TextEditingController sizeController;
  TextEditingController qtyController;
  TextEditingController shortageController;
  TextEditingController remarksController;
  String unit;
  String status; // 'RECEIVED', 'SHORTAGE', 'DUE', 'DEFECTIVE'

  _AccessoryChallanItem({
    required String name,
    String size = '',
    String qty = '',
    this.unit = 'pcs',
    this.status = 'RECEIVED',
    String shortage = '',
    String remarks = '',
  })  : nameController = TextEditingController(text: name),
        sizeController = TextEditingController(text: size),
        qtyController = TextEditingController(text: qty),
        shortageController = TextEditingController(text: shortage),
        remarksController = TextEditingController(text: remarks);

  void dispose() {
    nameController.dispose();
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
  bool _isLoading = true;

  // Aggregate Stats
  int _totalFinishedStock = 0;
  int _todayOutward = 0;
  int _todayTruckCount = 0;

  List<dynamic> _articles = [];
  List<dynamic> _storeLogs = [];
  List<dynamic> _truckInwards = [];

  Map<String, int> _articleStockMap = {};
  Map<String, int> _variantStockMap = {};
  List<dynamic> _allotmentVariants = [];
  List<dynamic> _activeAllotments = [];
  List<dynamic> _allotmentMaterials = [];

  @override
  void initState() {
    super.initState();
    _fetchStoreData();
  }

  Future<void> _fetchStoreData() async {
    setState(() => _isLoading = true);
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];

            // 1. Fetch Articles
      final articlesRes = await supabase
          .from('articles')
          .select('id, art_no, description')
          .eq('is_active', true)
          .order('art_no');

      // 1.1 Fetch Allotment Variants
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
      List<dynamic> articlesQuery = [];
      List<dynamic> challansQuery = [];

      try {
        allotQuery = await supabase
            .from('allotments')
            .select('*')
            .eq('status', 'IN_PROGRESS')
            .order('created_at', ascending: false);
      } catch (e) {
        debugPrint('Allotments fetch error in store: $e');
      }

      try {
        profilesQuery = await supabase
            .from('profiles')
            .select('id, username, role');
      } catch (e) {
        debugPrint('Profiles fetch error: $e');
      }

      try {
        articlesQuery = await supabase
            .from('articles')
            .select('id, art_no, description, stitching_rate, size_rates');
      } catch (e) {
        debugPrint('Articles fetch error: $e');
      }

      try {
        challansQuery = await supabase
            .from('challans')
            .select('id, challan_no, brand, fabric_type');
      } catch (_) {}

      try {
        allotMatsRes = await supabase
            .from('allotment_materials')
            .select('id, allotment_id, item_name, required_qty, admin_issued, lineman_received, notes, created_at')
            .order('created_at', ascending: false);
      } catch (e) {
        debugPrint('Allotment materials fetch error: $e');
      }

      final Map<String, dynamic> profMap = {};
      for (var p in profilesQuery) {
        profMap[p['id'].toString()] = p;
      }

      final Map<String, dynamic> artMap = {};
      for (var a in articlesQuery) {
        artMap[a['id'].toString()] = a;
      }

      final Map<String, dynamic> chMap = {};
      for (var c in challansQuery) {
        chMap[c['id'].toString()] = c;
      }

      for (var al in allotQuery) {
        final lId = al['lineman_id']?.toString() ?? '';
        final aId = al['article_id']?.toString() ?? '';
        final cId = al['challan_id']?.toString() ?? '';
        final prof = profMap[lId] ?? {'username': 'Lineman', 'role': 'LINEMAN'};
        final art = artMap[aId] ?? {'art_no': 'Garment', 'description': ''};
        final ch = chMap[cId] ?? {'challan_no': 'DIRECT', 'brand': 'INTERNAL'};

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
        } else if (al['production_order_no'] != null && al['production_order_no'].toString().trim().isNotEmpty) {
          assignedColorLabel = al['production_order_no'].toString();
        }

        activeAllotsRes.add({
          'id': al['id'],
          'challan_id': cId,
          'challan_no': ch['challan_no'] ?? 'DIRECT',
          'challans': ch,
          'lineman_id': lId,
          'article_id': aId,
          'target_qty': (al['target_qty'] as num?)?.toInt() ?? 0,
          'allotment_date': al['allotment_date'],
          'status': al['status'],
          'created_at': al['created_at'],
          'profiles': prof,
          'articles': art,
          'assigned_color_label': assignedColorLabel,
        });
      }

      // If allotments query returned empty (due to RLS policy on allotments),
      // reconstruct active allotment entries from allotment_materials notes
      final Set<String> seenAllotIds = activeAllotsRes.map((a) => a['id'].toString()).toSet();
      for (var mat in allotMatsRes) {
        final aId = mat['allotment_id']?.toString() ?? '';
        if (aId.isEmpty || seenAllotIds.contains(aId)) continue;
        seenAllotIds.add(aId);

        Map<String, dynamic> meta = {};
        if (mat['notes'] != null) {
          try {
            meta = jsonDecode(mat['notes']);
          } catch (_) {}
        }

        final articleId = meta['article_id']?.toString() ?? '';
        final linemanId = meta['lineman_id']?.toString() ?? '';
        final linemanName = meta['lineman_name'] ?? (profMap[linemanId]?['username'] ?? 'Lineman');
        final artNo = meta['art_no'] ?? (artMap[articleId]?['art_no'] ?? 'Garment');
        final artDesc = meta['article_description'] ?? (artMap[articleId]?['description'] ?? '');
        final challanNo = meta['client_challan_no'] ?? 'DIRECT';

        // Calculate total target pcs from variants or meta
        int targetPcs = 0;
        final allotVars = variantsRes.where((v) => v['allotment_id']?.toString() == aId).toList();
        final Set<String> distinctColors = {};
        for (var v in allotVars) {
          targetPcs += (v['quantity'] as num?)?.toInt() ?? 0;
          if (v['color'] != null && v['color'].toString().trim().isNotEmpty) {
            distinctColors.add(v['color'].toString().trim().toUpperCase());
          }
        }
        if (targetPcs == 0) {
          targetPcs = int.tryParse(meta['total_pcs']?.toString() ?? '') ?? 
                      int.tryParse(meta['target_qty']?.toString() ?? '') ?? 0;
        }

        String assignedColorLabel = '';
        if (distinctColors.length == 1) {
          assignedColorLabel = '${distinctColors.first} LINE';
        } else if (distinctColors.length > 1) {
          assignedColorLabel = distinctColors.join(', ');
        } else if (meta['color'] != null && meta['color'].toString().trim().isNotEmpty) {
          assignedColorLabel = '${meta['color'].toString().trim().toUpperCase()} LINE';
        }

        activeAllotsRes.add({
          'id': aId,
          'challan_id': '',
          'challan_no': challanNo,
          'challans': {'challan_no': challanNo, 'brand': meta['brand'] ?? 'INTERNAL'},
          'lineman_id': linemanId,
          'article_id': articleId,
          'target_qty': targetPcs,
          'allotment_date': mat['created_at']?.toString().split('T')[0] ?? '',
          'status': meta['status'] ?? 'IN_PROGRESS',
          'created_at': mat['created_at'],
          'profiles': {'username': linemanName, 'role': 'LINEMAN'},
          'articles': {'art_no': artNo, 'description': artDesc},
          'assigned_color_label': assignedColorLabel,
        });
      }

      // 2. Fetch All Store Transactions (for stock calculation & recent feed)
      final txRes = await supabase
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
            article:articles ( id, art_no, description )
          ''')
          .order('created_at', ascending: false)
          .limit(100);

      // 3. Fetch Accessories Transactions
      final accRes = await supabase
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
          .limit(100);

      // 4. Calculate Finished Goods Stock
      int totalIn = 0;
      int totalOut = 0;
      int tOutward = 0;
      final Map<String, int> stockMap = {};

      final Map<String, int> varStockMap = {};

      for (var tx in txRes) {
        final qty = (tx['quantity'] as int?) ?? 0;
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
      for (var acc in accRes) {
        final name = (acc['item_name'] as String?)?.trim();
        if (name != null && name.isNotEmpty) distinctAcc.add(name);
      }

      // 6. Merge & sort activity logs
      final List<Map<String, dynamic>> combinedLogs = [];

      for (var tx in txRes) {
        combinedLogs.add({
          'isAccessory': false,
          'id': tx['id'],
          'created_at': tx['created_at'],
          'entry_date': tx['entry_date'],
          'type': tx['type'],
          'quantity': tx['quantity'],
          'art_no': tx['article']?['art_no'] ?? '-',
          'color': tx['color'],
          'size': tx['size'],
          'party_name': tx['party_name'],
          'challan_no': tx['challan_no'],
          'notes': tx['notes'],
        });
      }

      for (var acc in accRes) {
        combinedLogs.add({
          'isAccessory': true,
          'id': acc['id'],
          'created_at': acc['created_at'],
          'entry_date': acc['entry_date'],
          'action': acc['action'],
          'item_name': acc['item_name'],
          'quantity': acc['quantity'],
          'unit': acc['unit'] ?? 'pcs',
          'party_name': acc['party_name'],
          'notes': acc['notes'],
        });
      }

      // 3.1 Fetch Truck Inwards (GRN)
      List<dynamic> truckInwardsRes = [];
      try {
        truckInwardsRes = await supabase
            .from('truck_inwards')
            .select('*')
            .order('created_at', ascending: false)
            .limit(50);
      } catch (e) {
        debugPrint('Truck inwards fetch warning: $e');
      }

      int tTruckCount = 0;
      for (var ti in truckInwardsRes) {
        final iDate = ti['inward_date']?.toString() ?? '';
        if (iDate == today) tTruckCount++;
      }

      combinedLogs.sort((a, b) {
        final tA = a['created_at']?.toString() ?? '';
        final tB = b['created_at']?.toString() ?? '';
        return tB.compareTo(tA);
      });

      if (mounted) {
        setState(() {
          _articles = articlesRes;
          _totalFinishedStock = currentStock;
          _todayOutward = tOutward;
          _todayTruckCount = tTruckCount;
          _articleStockMap = stockMap;
          _variantStockMap = varStockMap;
          _allotmentVariants = variantsRes;
          _activeAllotments = activeAllotsRes;
          _allotmentMaterials = allotMatsRes;
          _storeLogs = combinedLogs;
          _truckInwards = truckInwardsRes;
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
  void _showInwardModal() {
    String? selectedArticleId = _articles.isNotEmpty ? _articles.first['id'] : null;
    final fromController = TextEditingController(text: 'QC Finishing Floor');
    final notesController = TextEditingController();

    // Fallback single controllers if article has no variants
    final fallbackColorController = TextEditingController(text: 'Black');
    final fallbackSizeController = TextEditingController(text: 'L');
    final fallbackQtyController = TextEditingController();

    // Controllers map for each variant: key is variant id or "${color}_${size}"
    final Map<String, TextEditingController> variantControllers = {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final variants = _getVariantsForArticle(selectedArticleId);

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

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(width: 44, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(3))),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(14)),
                        child: const Icon(Icons.download_rounded, color: Color(0xFF047857), size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('INWARD: Multi-Variant Receiving', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                            Text('Receive ready sizes & colors into Godown stock', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // 1. Article Selection
                  const Text('Article (Style #)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFCBD5E1))),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedArticleId,
                        isExpanded: true,
                        items: _articles.map((art) => DropdownMenuItem<String>(
                          value: art['id'],
                          child: Text('${art['art_no']} (${_getCleanArticleDescription(art['description'])})', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
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

                  const SizedBox(height: 16),

                  // 2. LIVE TOTAL INWARD PIECES BANNER
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: totalInwardPieces > 0 ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: totalInwardPieces > 0 ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.inventory_2_rounded, size: 18, color: totalInwardPieces > 0 ? const Color(0xFF047857) : Colors.grey),
                            const SizedBox(width: 8),
                            Text(
                              'Total Receiving Quantity:',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: totalInwardPieces > 0 ? const Color(0xFF065F46) : Colors.grey.shade700),
                            ),
                          ],
                        ),
                        Text(
                          '$totalInwardPieces pcs',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'monospace',
                            color: totalInwardPieces > 0 ? const Color(0xFF047857) : Colors.grey.shade600,
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
                        const Text('Size & Color Quantity Matrix', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                        TextButton.icon(
                          onPressed: () {
                            setModalState(() {
                              for (var v in variants) {
                                final key = v['id'] ?? "${v['color']}_${v['size']}";
                                variantControllers[key]?.text = (v['allotment_qty'] ?? 0).toString();
                              }
                            });
                          },
                          icon: const Icon(Icons.flash_on_rounded, size: 14, color: Color(0xFF047857)),
                          label: const Text('Fill Allotment Ratio', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF047857))),
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
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(color: Color(0xFF0F172A), shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 6),
                                Text(colorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
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
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                                      child: Text(item['size'], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF0F172A))),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'In Godown: $currentGodownStock pcs',
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 90,
                                      height: 38,
                                      child: TextField(
                                        controller: variantControllers[key],
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                                        decoration: InputDecoration(
                                          hintText: '0',
                                          hintStyle: TextStyle(color: Colors.grey.shade400),
                                          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF047857), width: 1.5)),
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
                            decoration: InputDecoration(labelText: 'Color', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: fallbackSizeController,
                            decoration: InputDecoration(labelText: 'Size', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: fallbackQtyController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(labelText: 'Qty', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                            onChanged: (_) => setModalState(() {}),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 14),

                  // 4. From
                  const Text('Received From', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: fromController,
                    decoration: InputDecoration(hintText: 'e.g. QC Finishing Table', prefixIcon: const Icon(Icons.factory_rounded, size: 20), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
                  ),

                  const SizedBox(height: 14),

                  // 5. Notes
                  const Text('Carton / Bundle Batch Notes (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: notesController,
                    decoration: InputDecoration(hintText: 'e.g. Master Carton #3 (Full Lot Ready)', prefixIcon: const Icon(Icons.notes_rounded, size: 20), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
                  ),

                  const SizedBox(height: 22),

                  // SUBMIT BUTTON
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        if (selectedArticleId == null || totalInwardPieces <= 0) {
                          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please enter quantity for at least one size/color.')));
                          return;
                        }

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
                                  'notes': notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                                  'entry_date': todayStr,
                                });
                              }
                            }
                          } else {
                            final qty = int.parse(fallbackQtyController.text.trim());
                            rowsToInsert.add({
                              'article_id': selectedArticleId,
                              'type': 'INWARD',
                              'quantity': qty,
                              'color': fallbackColorController.text.trim(),
                              'size': fallbackSizeController.text.trim(),
                              'party_name': fromController.text.trim().isEmpty ? 'QC Finishing Floor' : fromController.text.trim(),
                              'notes': notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                              'entry_date': todayStr,
                            });
                          }

                          if (rowsToInsert.isNotEmpty) {
                            await supabase.from('store_transactions').insert(rowsToInsert);
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text('Inwarded $totalInwardPieces pcs across ${rowsToInsert.length} variants to Godown!'),
                                backgroundColor: const Color(0xFF047857),
                              ),
                            );
                            _fetchStoreData();
                          }
                        } catch (e) {
                          scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
                        }
                      },
                      icon: const Icon(Icons.download_rounded, size: 20),
                      label: Text('Save Inward ($totalInwardPieces pcs) to Godown'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF047857),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
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
  // MODULE 2: OUTWARD (DISPATCH GOODS) - MULTI-VARIANT
  // ==========================================
  void _showOutwardModal() {
    String? selectedArticleId = _articles.isNotEmpty ? _articles.first['id'] : null;
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
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

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(width: 44, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(3))),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(14)),
                        child: const Icon(Icons.upload_rounded, color: Color(0xFF2563EB), size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('OUTWARD: Multi-Variant Dispatch', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                            Text('Issue garments from Godown for delivery', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // 1. Article Selection
                  const Text('Article (Style #)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFCBD5E1))),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedArticleId,
                        isExpanded: true,
                        items: _articles.map((art) => DropdownMenuItem<String>(
                          value: art['id'],
                          child: Text('${art['art_no']} (${_getCleanArticleDescription(art['description'])})', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
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
                      color: totalAvailArticleStock > 0 ? const Color(0xFFEFF6FF) : const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: totalAvailArticleStock > 0 ? const Color(0xFFBFDBFE) : const Color(0xFFFECDD3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(totalAvailArticleStock > 0 ? Icons.check_circle_outline : Icons.warning_amber_rounded, size: 16, color: totalAvailArticleStock > 0 ? const Color(0xFF2563EB) : const Color(0xFFE11D48)),
                        const SizedBox(width: 6),
                        Text('Total in Godown: $totalAvailArticleStock pcs', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: totalAvailArticleStock > 0 ? const Color(0xFF1E40AF) : const Color(0xFFBE123C))),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 2. LIVE TOTAL DISPATCH PIECES BANNER
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: totalDispatchPieces > 0 ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: totalDispatchPieces > 0 ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.local_shipping_rounded, size: 18, color: totalDispatchPieces > 0 ? const Color(0xFF2563EB) : Colors.grey),
                            const SizedBox(width: 8),
                            Text(
                              'Total Dispatch Quantity:',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: totalDispatchPieces > 0 ? const Color(0xFF1E40AF) : Colors.grey.shade700),
                            ),
                          ],
                        ),
                        Text(
                          '$totalDispatchPieces pcs',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'monospace',
                            color: totalDispatchPieces > 0 ? const Color(0xFF2563EB) : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 3. COLOR & SIZE DISPATCH MATRIX
                  if (variants.isNotEmpty) ...[
                    const Text('Size & Color Dispatch Matrix', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                    const SizedBox(height: 8),

                    ...colorGroups.entries.map((cg) {
                      final colorName = cg.key;
                      final vList = cg.value;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(color: Color(0xFF2563EB), shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 6),
                                Text(colorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                              ],
                            ),
                            const SizedBox(height: 10),

                            ...vList.map((item) {
                              final key = item['id'] ?? "${item['color']}_${item['size']}";
                              final currentGodownStock = selectedArticleId != null
                                  ? _getVariantStock(selectedArticleId!, item['color'], item['size'])
                                  : 0;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                                      child: Text(item['size'], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF0F172A))),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Stock: $currentGodownStock pcs',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: currentGodownStock > 0 ? const Color(0xFF047857) : Colors.redAccent,
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 90,
                                      height: 38,
                                      child: TextField(
                                        controller: variantControllers[key],
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                                        decoration: InputDecoration(
                                          hintText: '0',
                                          hintStyle: TextStyle(color: Colors.grey.shade400),
                                          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
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
                            decoration: InputDecoration(labelText: 'Color', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: fallbackSizeController,
                            decoration: InputDecoration(labelText: 'Size', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: fallbackQtyController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(labelText: 'Qty', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                            onChanged: (_) => setModalState(() {}),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 14),

                  // 4. Buyer Name
                  const Text('Buyer Name / Customer / PO #', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: buyerController,
                    decoration: InputDecoration(hintText: 'e.g. Reliance Retail / Order #PO-882', prefixIcon: const Icon(Icons.business_rounded, size: 20), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
                  ),

                  const SizedBox(height: 14),

                  // 5. Challan No / Vehicle No
                  const Text('Challan No / Vehicle No (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: challanController,
                    decoration: InputDecoration(hintText: 'e.g. Challan #DC-402 • Truck MH-04-1234', prefixIcon: const Icon(Icons.local_shipping_rounded, size: 20), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
                  ),

                  const SizedBox(height: 22),

                  // SUBMIT BUTTON
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        if (selectedArticleId == null || totalDispatchPieces <= 0) {
                          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please enter quantity for at least one size/color.')));
                          return;
                        }

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
                            final qty = int.parse(fallbackQtyController.text.trim());
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
                                backgroundColor: const Color(0xFF2563EB),
                              ),
                            );
                            _fetchStoreData();
                          }
                        } catch (e) {
                          scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
                        }
                      },
                      icon: const Icon(Icons.upload_rounded, size: 20),
                      label: Text('Dispatch ($totalDispatchPieces pcs) & Deduct Stock'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
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
  // MODULE: ACCESSORY & TRUCK CHALLAN INWARD (GRN)
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
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

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 44,
                      height: 4.5,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(3)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Accessory Challan Inward', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                            Text('Record supplier delivery slip, trims & due items', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: const Color(0xFFE0F2FE), borderRadius: BorderRadius.circular(10)),
                        child: const Row(
                          children: [
                            Icon(Icons.receipt_long_rounded, color: Color(0xFF0284C7), size: 16),
                            SizedBox(width: 4),
                            Text('GRN Entry', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0369A1))),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // SECTION 1: CHALLAN & PARTY DETAILS
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Supplier / Brand Name *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: partyController,
                          decoration: InputDecoration(
                            hintText: 'e.g. Ollypop Industries Pvt. Ltd. / Reena',
                            prefixIcon: const Icon(Icons.business_rounded, size: 18, color: Color(0xFF64748B)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Article No', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: articleController,
                                    decoration: InputDecoration(
                                      hintText: 'e.g. 9433',
                                      prefixIcon: const Icon(Icons.style_rounded, size: 18, color: Color(0xFF64748B)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                      filled: true,
                                      fillColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 1,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Challan / Slip #', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: challanNoController,
                                    decoration: InputDecoration(
                                      hintText: 'e.g. 102 / Slip #',
                                      prefixIcon: const Icon(Icons.numbers_rounded, size: 18, color: Color(0xFF64748B)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                      filled: true,
                                      fillColor: Colors.white,
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Receipt Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                                  const SizedBox(height: 6),
                                  InkWell(
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
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFFCBD5E1)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF64748B)),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${inwardDate.year}-${inwardDate.month.toString().padLeft(2, '0')}-${inwardDate.day.toString().padLeft(2, '0')}',
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Truck / Vehicle #', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: truckNoController,
                                    decoration: InputDecoration(
                                      hintText: 'Optional',
                                      prefixIcon: const Icon(Icons.local_shipping_rounded, size: 18, color: Color(0xFF64748B)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                      filled: true,
                                      fillColor: Colors.white,
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
                  const SizedBox(height: 18),

                  // SECTION 2: QUICK PRESET CHIPS
                  const Text('Quick Add Trims & Fabrics', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
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
                    ].map((trim) {
                      return ActionChip(
                        avatar: const Icon(Icons.add_rounded, size: 14, color: Color(0xFF0284C7)),
                        label: Text(trim['name']!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0369A1))),
                        backgroundColor: const Color(0xFFF0F9FF),
                        side: const BorderSide(color: Color(0xFFBAE6FD)),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        onPressed: () {
                          setModalState(() {
                            items.add(_AccessoryChallanItem(
                              name: trim['name']!,
                              unit: trim['unit']!,
                              size: trim['size']!,
                              status: 'RECEIVED',
                            ));
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),

                  // SECTION 3: LINE ITEMS LIST
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Challan Items (${items.length})', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                      TextButton.icon(
                        onPressed: () {
                          setModalState(() {
                            items.add(_AccessoryChallanItem(name: 'New Trim Item', status: 'RECEIVED'));
                          });
                        },
                        icon: const Icon(Icons.add_circle_outline_rounded, size: 16, color: Color(0xFF0284C7)),
                        label: const Text('Add Custom Item', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  if (items.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12)),
                      child: const Center(
                        child: Text('No items added. Tap quick presets above or Add Custom Item.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ),
                    )
                  else
                    ...items.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final item = entry.value;
                      final isReceived = item.status == 'RECEIVED';
                      final isShortage = item.status == 'SHORTAGE';
                      final isDue = item.status == 'DUE';

                      Color cardBg = Colors.white;
                      Color cardBorder = const Color(0xFFE2E8F0);
                      if (isShortage) {
                        cardBg = const Color(0xFFFFFBEB);
                        cardBorder = const Color(0xFFFDE68A);
                      } else if (isDue) {
                        cardBg = const Color(0xFFFAF5FF);
                        cardBorder = const Color(0xFFE9D5FF);
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
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
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      hintText: 'Item Description',
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: () {
                                    setModalState(() {
                                      items.removeAt(idx);
                                    });
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.all(4.0),
                                    child: Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 14, color: Color(0xFFF1F5F9)),

                            // Size / Quantity / Unit Row
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: TextField(
                                    controller: item.sizeController,
                                    decoration: InputDecoration(
                                      labelText: 'Size / Ratio',
                                      hintText: 'e.g. L/XXL, 22x26',
                                      labelStyle: const TextStyle(fontSize: 11),
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: TextField(
                                    controller: item.qtyController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: 'Quantity',
                                      hintText: 'e.g. 659',
                                      labelStyle: const TextStyle(fontSize: 11),
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade400),
                                    color: Colors.white,
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: item.unit,
                                      isDense: true,
                                      items: ['pcs', 'mt', 'cones', 'kg', 'rolls', 'sets']
                                          .map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 12))))
                                          .toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setModalState(() => item.unit = val);
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Status chips
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () => setModalState(() => item.status = 'RECEIVED'),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isReceived ? const Color(0xFF047857) : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.check_circle_rounded, size: 14, color: isReceived ? Colors.white : const Color(0xFF475569)),
                                          const SizedBox(width: 4),
                                          Text('Received', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isReceived ? Colors.white : const Color(0xFF475569))),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: InkWell(
                                    onTap: () => setModalState(() => item.status = 'SHORTAGE'),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isShortage ? const Color(0xFFD97706) : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.warning_amber_rounded, size: 14, color: isShortage ? Colors.white : const Color(0xFF475569)),
                                          const SizedBox(width: 4),
                                          Text('Shortage', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isShortage ? Colors.white : const Color(0xFF475569))),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: InkWell(
                                    onTap: () => setModalState(() => item.status = 'DUE'),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isDue ? const Color(0xFF7C3AED) : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.pending_actions_rounded, size: 14, color: isDue ? Colors.white : const Color(0xFF475569)),
                                          const SizedBox(width: 4),
                                          Text('Due / Pending', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDue ? Colors.white : const Color(0xFF475569))),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // If Shortage or Due, show shortage details
                            if (isShortage) ...[
                              const SizedBox(height: 8),
                              TextField(
                                controller: item.shortageController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Shortage Missing Qty',
                                  hintText: 'e.g. 50 pcs missing',
                                  labelStyle: const TextStyle(fontSize: 11, color: Color(0xFFD97706)),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 16),

                  // SECTION 4: PHOTO ATTACHMENT
                  const Text('Challan Paper Slip Photo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: selectedImage != null
                        ? Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(selectedImage!, width: 64, height: 64, fit: BoxFit.cover),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Paper Challan Attached', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                                    Text('Ready for cloud verification', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, color: Colors.redAccent),
                                onPressed: () => setModalState(() => selectedImage = null),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => pickChallanImage(ImageSource.camera),
                                  icon: const Icon(Icons.photo_camera_rounded, size: 18, color: Color(0xFF0284C7)),
                                  label: const Text('Camera', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    side: const BorderSide(color: Color(0xFFBAE6FD)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => pickChallanImage(ImageSource.gallery),
                                  icon: const Icon(Icons.photo_library_rounded, size: 18, color: Color(0xFF475569)),
                                  label: const Text('Gallery', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    side: const BorderSide(color: Color(0xFFCBD5E1)),
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
                    decoration: InputDecoration(
                      hintText: 'General Remarks (e.g. Driver Mohan • 10 bags)',
                      prefixIcon: const Icon(Icons.notes_rounded, size: 18, color: Color(0xFF64748B)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // SUBMIT BUTTON
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final supplierName = partyController.text.trim();
                              if (supplierName.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please enter Supplier / Brand Name.'), backgroundColor: Colors.redAccent),
                                );
                                return;
                              }
                              if (items.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please add at least 1 item from the challan.'), backgroundColor: Colors.redAccent),
                                );
                                return;
                              }

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
                                    : (shortageCount > 0 ? 'SHORTAGE' : 'VERIFIED');

                                // 1. Insert into truck_inwards
                                Map<String, dynamic> inwardRecord = {
                                  'grn_no': grnNo,
                                  'party_name': supplierName,
                                  'article_no': articleController.text.trim().isNotEmpty ? articleController.text.trim() : null,
                                  'challan_no': challanNoController.text.trim().isNotEmpty ? challanNoController.text.trim() : null,
                                  'inward_date': selectedDateStr,
                                  'truck_no': truckNoController.text.trim().isNotEmpty ? truckNoController.text.trim() : null,
                                  'challan_photo_url': photoUrl,
                                  'received_by': supabase.auth.currentUser?.id,
                                  'receiver_name': 'Store Incharge',
                                  'status': overallStatus,
                                  'total_items': items.length,
                                  'due_items_count': dueCount,
                                  'shortage_items_count': shortageCount,
                                  'notes': notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
                                };

                                try {
                                  final inserted = await supabase.from('truck_inwards').insert(inwardRecord).select().single();
                                  final inwardId = inserted['id'];

                                  List<Map<String, dynamic>> itemRows = [];
                                  for (var it in items) {
                                    itemRows.add({
                                      'truck_inward_id': inwardId,
                                      'item_name': it.nameController.text.trim(),
                                      'size_label': it.sizeController.text.trim().isNotEmpty ? it.sizeController.text.trim() : null,
                                      'quantity': double.tryParse(it.qtyController.text.trim()) ?? 0,
                                      'unit': it.unit,
                                      'status': it.status,
                                      'shortage_qty': double.tryParse(it.shortageController.text.trim()) ?? 0,
                                      'remarks': it.remarksController.text.trim().isNotEmpty ? it.remarksController.text.trim() : null,
                                    });
                                  }
                                  if (itemRows.isNotEmpty) {
                                    await supabase.from('truck_inward_items').insert(itemRows);
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
                                    await supabase.from('accessories').insert({
                                      'item_name': it.nameController.text.trim() + sizeSuffix,
                                      'action': 'IN',
                                      'quantity': qty,
                                      'unit': it.unit,
                                      'party_name': supplierName,
                                      'entry_date': selectedDateStr,
                                      'notes': 'Challan #${challanNoController.text.trim()} • Art ${articleController.text.trim()} • $grnNo',
                                    });
                                  } catch (_) {}
                                }

                                nav.pop();
                                scaffoldMessenger.showSnackBar(
                                  SnackBar(
                                    content: Text('Inward recorded! $grnNo generated for $supplierName (${items.length} items).'),
                                    backgroundColor: const Color(0xFF0284C7),
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
                      icon: isSubmitting
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_circle_rounded, size: 20),
                      label: Text(
                        isSubmitting
                            ? 'Saving Inward...'
                            : 'Confirm Inward ($receivedCount Received${dueCount > 0 ? ", $dueCount Due" : ""})',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
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
  void _showMaterialHandoverModal() {
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

    String selectedAllotmentId = pendingAllotments.first['id'];
    final challanController = TextEditingController();

    // Map to hold inspection state per material item id
    // { id: { 'receivedQtyCtrl': TextEditingController, 'status': 'VERIFIED' | 'SHORTAGE' | 'DEFECTIVE', 'shortageCtrl': TextEditingController, 'remarksCtrl': TextEditingController } }
    final Map<String, Map<String, dynamic>> inspectionState = {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final allotment = pendingAllotments.firstWhere(
            (a) => a['id'] == selectedAllotmentId,
            orElse: () => pendingAllotments.first,
          );

          final materials = _allotmentMaterials.where((m) => m['allotment_id'] == selectedAllotmentId).toList();
          final linemanName = allotment['profiles']?['username'] ?? 'Lineman';
          final artNo = allotment['articles']?['art_no'] ?? '-';
          final artDesc = _getCleanArticleDescription(allotment['articles']?['description']);

          // Initialize controllers for materials
          for (var mat in materials) {
            final mId = mat['id'].toString();
            if (!inspectionState.containsKey(mId)) {
              // Parse existing inspection notes if any
              String existingReceived = mat['required_qty'] ?? '';
              String existingStatus = 'VERIFIED';
              String existingShortage = '';
              String existingRemarks = '';

              if (mat['notes'] != null) {
                try {
                  // Simple manual JSON parse
                  final notesStr = mat['notes'].toString();
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

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(width: 44, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(3))),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(14)),
                        child: const Icon(Icons.fact_check_rounded, color: Color(0xFF4F46E5), size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('BOM Material Inward Inspection', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                            Text('Recheck raw materials against supplier challan & issue to line', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // 1. Select Active Allotment Target
                  const Text('Select Allotment Target', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFCBD5E1))),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedAllotmentId,
                        isExpanded: true,
                        items: pendingAllotments.map((al) {
                          final lName = al['profiles']?['username'] ?? 'Lineman';
                          final aNo = al['articles']?['art_no'] ?? '';
                          final cLabel = (al['assigned_color_label']?.toString() ?? '').trim();
                          final qty = al['target_qty'] ?? 0;
                          final targetTitle = cLabel.isNotEmpty 
                              ? '$lName • $aNo ($cLabel - $qty pcs)'
                              : '$lName • $aNo ($qty pcs)';
                          return DropdownMenuItem<String>(
                            value: al['id'],
                            child: Text(targetTitle, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          );
                        }).toList(),
                        onChanged: (v) {
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

                  const SizedBox(height: 14),

                  // 2. Target Info Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
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
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Color(0xFF0F172A),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Assigned Lineman: $linemanName',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.grey.shade600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${allotment['target_qty']} pcs',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Color(0xFF4F46E5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 3. Supplier Challan No / Invoice #
                  const Text('Supplier Delivery Challan # / Invoice #', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: challanController,
                    decoration: InputDecoration(
                      hintText: 'e.g. Vardhman Inv #9921 • Delivery CH-402',
                      prefixIcon: const Icon(Icons.receipt_long_rounded, size: 20),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 4. Checklist of Items
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('BOM Physical Inspection Checklist', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                      Text('${materials.length} Items', style: const TextStyle(fontSize: 11.5, color: Colors.grey, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (materials.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12)),
                      child: const Center(child: Text('No BOM items specified by Admin for this allotment.', style: TextStyle(fontSize: 12, color: Colors.grey))),
                    )
                  else
                    ...materials.map((mat) {
                      final mId = mat['id'].toString();
                      final state = inspectionState[mId] ?? {};
                      final status = state['status'] ?? 'VERIFIED';
                      final receivedCtrl = state['receivedQtyCtrl'] as TextEditingController?;
                      final shortageCtrl = state['shortageCtrl'] as TextEditingController?;
                      final remarksCtrl = state['remarksCtrl'] as TextEditingController?;

                      final isShortage = status == 'SHORTAGE';
                      final isDefective = status == 'DEFECTIVE';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isShortage ? const Color(0xFFFFF7ED) : (isDefective ? const Color(0xFFFEF2F2) : Colors.white),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isShortage ? const Color(0xFFFED7AA) : (isDefective ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0)),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    mat['item_name'] ?? 'Material Item',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                                  child: Text('Required: ${mat['required_qty']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF334155))),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Inspection Status Selector Chips
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () => setModalState(() => inspectionState[mId]?['status'] = 'VERIFIED'),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 6),
                                      decoration: BoxDecoration(
                                        color: status == 'VERIFIED' ? const Color(0xFF047857) : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Center(
                                        child: Text(
                                          ' Full Verified',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: status == 'VERIFIED' ? Colors.white : const Color(0xFF475569)),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: InkWell(
                                    onTap: () => setModalState(() => inspectionState[mId]?['status'] = 'SHORTAGE'),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isShortage ? const Color(0xFFD97706) : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '️ Shortage',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isShortage ? Colors.white : const Color(0xFF475569)),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: InkWell(
                                    onTap: () => setModalState(() => inspectionState[mId]?['status'] = 'DEFECTIVE'),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isDefective ? const Color(0xFFDC2626) : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Center(
                                        child: Text(
                                          ' Defective',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDefective ? Colors.white : const Color(0xFF475569)),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 10),

                            // Physical Received Qty Input & Shortage details
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Physical Received Count', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                                      const SizedBox(height: 4),
                                      TextField(
                                        controller: receivedCtrl,
                                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                                        decoration: InputDecoration(
                                          hintText: 'e.g. 12 Cones / 500 Meters',
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isShortage) ...[
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Shortage Diff', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                                        const SizedBox(height: 4),
                                        TextField(
                                          controller: shortageCtrl,
                                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                                          decoration: InputDecoration(
                                            hintText: 'e.g. -4 Cones',
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFFED7AA))),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),

                            // Remarks input for Shortage or Defective
                            if (isShortage || isDefective) ...[
                              const SizedBox(height: 8),
                              TextField(
                                controller: remarksCtrl,
                                style: const TextStyle(fontSize: 11.5),
                                decoration: InputDecoration(
                                  hintText: isShortage ? 'Reason for shortage / supplier follow-up note...' : 'Defect details (wrong shade, damaged packaging)...',
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),

                  const SizedBox(height: 20),

                  // 5. Submit Button: Verify & Issue to Lineman
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        Navigator.pop(ctx);

                        try {
                          final challanNo = challanController.text.trim();
                          final nowIso = DateTime.now().toIso8601String();

                          for (var mat in materials) {
                            final mId = mat['id'].toString();
                            final state = inspectionState[mId] ?? {};
                            final status = state['status'] ?? 'VERIFIED';
                            final receivedText = (state['receivedQtyCtrl'] as TextEditingController?)?.text.trim() ?? (mat['required_qty'] ?? '');
                            final shortageText = (state['shortageCtrl'] as TextEditingController?)?.text.trim() ?? '';
                            final remarksText = (state['remarksCtrl'] as TextEditingController?)?.text.trim() ?? '';

                            Map<String, dynamic> existingNotes = {};
                            if (mat['notes'] != null) {
                              try {
                                existingNotes = jsonDecode(mat['notes']);
                              } catch (_) {}
                            }

                            existingNotes['lineman_name'] = linemanName;
                            existingNotes['received_qty'] = receivedText.isEmpty ? mat['required_qty'] : receivedText;
                            existingNotes['status'] = status;
                            existingNotes['shortage_qty'] = shortageText.isEmpty ? null : shortageText;
                            existingNotes['supplier_challan_no'] = challanNo.isEmpty ? null : challanNo;
                            existingNotes['store_verified'] = true;
                            existingNotes['store_verified_at'] = nowIso;
                            existingNotes['store_remarks'] = remarksText.isEmpty ? null : remarksText;

                            final notesJson = jsonEncode(existingNotes);

                            await supabase
                                .from('allotment_materials')
                                .update({
                                  'admin_issued': true,
                                  'notes': notesJson,
                                })
                                .eq('id', mat['id']);
                          }

                          scaffoldMessenger.showSnackBar(
                            SnackBar(
                              content: Text('Raw materials verified & issued to Lineman $linemanName!'),
                              backgroundColor: const Color(0xFF4F46E5),
                            ),
                          );
                          _fetchStoreData();
                        } catch (e) {
                          scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
                        }
                      },
                      icon: const Icon(Icons.verified_rounded, size: 20),
                      label: Text('Verify & Issue Materials to $linemanName'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
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

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        toolbarHeight: 68,
        titleSpacing: 18,
        backgroundColor: AppTheme.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    'Welcome, $userName',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.ink,
                      letterSpacing: -0.4,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                const _WavingHandIcon(size: 20),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              'Store & Godown Shift',
              style: GoogleFonts.publicSans(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.inkSoft,
              ),
            ),
          ],
        ),
        actions: [
          // Live Sync / Refresh button
          Tooltip(
            message: 'Resync Store Data',
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _fetchStoreData,
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.sync_rounded, size: 16, color: AppTheme.steel),
                    const SizedBox(width: 5),
                    Text(
                      'Sync',
                      style: GoogleFonts.publicSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.steel,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Clean Logout button
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
            ),
            child: IconButton(
              icon: const Icon(Icons.logout_rounded, color: AppTheme.inkSoft, size: 18),
              tooltip: 'Logout',
              padding: EdgeInsets.zero,
              onPressed: () async {
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
                }
              },
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchStoreData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ====== STORE INVENTORY SUMMARY STATS ======
                    Builder(
                      builder: (context) {
                        final int pendingHandoverCount = _activeAllotments.where((al) {
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
                        }).length;

                        return Column(
                          children: [
                            // Two Hero Stat Cards (Vertical layout prevents any text truncation)
                            Row(
                              children: [
                                _buildStatCard(
                                  'Finished Stock',
                                  '$_totalFinishedStock',
                                  Icons.inventory_2_rounded,
                                  AppTheme.steel,
                                  unit: 'pcs',
                                  subtitle: 'Ready in Store',
                                ),
                                const SizedBox(width: 12),
                                _buildStatCard(
                                  'Floor Handover',
                                  '$pendingHandoverCount',
                                  Icons.fact_check_rounded,
                                  pendingHandoverCount > 0 ? AppTheme.amber : AppTheme.green,
                                  unit: 'lots',
                                  subtitle: pendingHandoverCount > 0 ? 'Pending Issue' : 'All lots cleared',
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Unified 4-Column Telemetry Strip with Short Punchy Labels
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                              decoration: BoxDecoration(
                                color: AppTheme.card,
                                borderRadius: BorderRadius.circular(14),
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
                                  _telemetryCell('STOCK', '$_totalFinishedStock', 'pcs', AppTheme.ink),
                                  _cellDivider(),
                                  _telemetryCell('PENDING', '$pendingHandoverCount', 'lots', pendingHandoverCount > 0 ? AppTheme.amber : AppTheme.green),
                                  _cellDivider(),
                                  _telemetryCell('INWARD', '+$_todayTruckCount', 'slips', AppTheme.steel),
                                  _cellDivider(),
                                  _telemetryCell('OUTWARD', '-$_todayOutward', 'pcs', _todayOutward > 0 ? AppTheme.red : AppTheme.inkSoft),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // ====== STORE QUICK ACTIONS ======
                    Text(
                      'Store Quick Actions',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildActionTile(
                      title: 'Accessory Challan Inward (GRN)',
                      subtitle: 'Record supplier delivery slip, trims, fabrics & due items',
                      icon: Icons.receipt_long_rounded,
                      color: AppTheme.steel,
                      bgColor: AppTheme.steelMist,
                      onTap: _showAccessoryChallanInwardModal,
                    ),
                    const SizedBox(height: 10),

                    _buildActionTile(
                      title: 'BOM Material Handover',
                      subtitle: 'Inspect supplier challan & issue materials to Lineman',
                      icon: Icons.fact_check_rounded,
                      color: AppTheme.amber,
                      bgColor: AppTheme.amberMist,
                      onTap: _showMaterialHandoverModal,
                    ),
                    const SizedBox(height: 10),

                    _buildActionTile(
                      title: 'Production Inward',
                      subtitle: 'Receive finished goods from QC / Production',
                      icon: Icons.download_rounded,
                      color: AppTheme.green,
                      bgColor: AppTheme.greenMist,
                      onTap: _showInwardModal,
                    ),
                    const SizedBox(height: 10),

                    _buildActionTile(
                      title: 'Finished Goods Outward',
                      subtitle: 'Issue goods for dispatch & delivery',
                      icon: Icons.upload_rounded,
                      color: AppTheme.steel,
                      bgColor: AppTheme.steelMist,
                      onTap: _showOutwardModal,
                    ),

                    const SizedBox(height: 26),

                    // ====== RECENT ACCESSORY CHALLANS (GRN) FEED ======
                    if (_truckInwards.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Recent Supplier Challans (GRN)',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.ink,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.steelMist,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.steelTint),
                            ),
                            child: Text(
                              '${_truckInwards.length} slips',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.steel,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ..._truckInwards.map((inward) => _buildTruckInwardCard(inward)),
                      const SizedBox(height: 24),
                    ],

                    // ====== STORE LEDGER ACTIVITY FEED ======
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recent Store Ledger Feed',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.ink,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.steelMist,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.steelTint),
                          ),
                          child: Text(
                            '${_storeLogs.length} entries',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.steel,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (_storeLogs.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: AppTheme.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Center(
                          child: Text(
                            'No store transactions logged yet.\nTap Inward, Outward, or Accessory Challan above to record movements.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.publicSans(color: AppTheme.inkSoft, fontSize: 13, height: 1.5),
                          ),
                        ),
                      )
                    else
                      ..._storeLogs.map((log) => _buildLedgerCard(log)),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
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

  Widget _buildLedgerCard(Map<String, dynamic> log) {
    final isAcc = log['isAccessory'] == true;
    final timeStr = log['created_at'] != null ? DateTime.parse(log['created_at']).toLocal().toString().substring(11, 16) : '-';

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
                  if (log['notes'] != null && (log['notes'] as String).isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Note: ${log['notes']}',
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
                  if (log['notes'] != null && (log['notes'] as String).isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Note: ${log['notes']}',
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
              Text(
                'Challan: ${challanNo.isNotEmpty ? challanNo : "Direct"} • $inwardDate',
                style: GoogleFonts.publicSans(fontSize: 12, color: AppTheme.inkSoft, fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              if (photoUrl != null && photoUrl.isNotEmpty)
                InkWell(
                  onTap: () => _showPhotoViewerModal(photoUrl, '$partyName (Challan #$challanNo)'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.bg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
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