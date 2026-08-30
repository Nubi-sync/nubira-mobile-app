import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/connectivity_indicator.dart';
import '../auth/providers/auth_provider.dart';
import '../auth/screens/login_screen.dart';
import '../../core/theme/app_theme.dart';
import '../../../main.dart'; // supabase client

class StoreDashboard extends ConsumerStatefulWidget {
  const StoreDashboard({super.key});

  @override
  ConsumerState<StoreDashboard> createState() => _StoreDashboardState();
}

class _StoreDashboardState extends ConsumerState<StoreDashboard> {
  bool _isLoading = true;

  // Aggregate Stats
  int _totalFinishedStock = 0;
  int _todayInward = 0;
  int _todayOutward = 0;

  List<dynamic> _articles = [];
  List<dynamic> _storeLogs = [];

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
      try {
        final allotQuery = await supabase
            .from('allotments')
            .select('id, challan_id, lineman_id, article_id, target_qty, allotment_date, status, created_at')
            .eq('status', 'IN_PROGRESS')
            .order('created_at', ascending: false);

        final profilesQuery = await supabase
            .from('profiles')
            .select('id, username, role');

        final articlesQuery = await supabase
            .from('articles')
            .select('id, art_no, description, stitching_rate, size_rates');

        List<dynamic> challansQuery = [];
        try {
          challansQuery = await supabase
              .from('challans')
              .select('id, challan_no, brand, fabric_type');
        } catch (_) {}

        allotMatsRes = await supabase
            .from('allotment_materials')
            .select('id, allotment_id, item_name, required_qty, admin_issued, lineman_received, notes, created_at')
            .order('created_at', ascending: false);

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

          activeAllotsRes.add({
            'id': al['id'],
            'challan_id': cId,
            'challan_no': ch['challan_no'] ?? 'DIRECT',
            'challans': ch,
            'lineman_id': lId,
            'article_id': aId,
            'target_qty': al['target_qty'] ?? 0,
            'allotment_date': al['allotment_date'],
            'status': al['status'],
            'created_at': al['created_at'],
            'profiles': prof,
            'articles': art,
          });
        }
      } catch (e) {
        debugPrint('Active allotments fetch error in store: $e');
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
      int tInward = 0;
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
          if (entryDate == today) tInward += qty;
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

      combinedLogs.sort((a, b) {
        final tA = a['created_at']?.toString() ?? '';
        final tB = b['created_at']?.toString() ?? '';
        return tB.compareTo(tA);
      });

      if (mounted) {
        setState(() {
          _articles = articlesRes;
          _totalFinishedStock = currentStock;
          _todayInward = tInward;
          _todayOutward = tOutward;
          _articleStockMap = stockMap;
          _variantStockMap = varStockMap;
          _allotmentVariants = variantsRes;
          _activeAllotments = activeAllotsRes;
          _allotmentMaterials = allotMatsRes;
          _storeLogs = combinedLogs;
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
  // MODULE 3: ACCESSORIES & TRIMS LEDGER
  // ==========================================
  void _showMaterialHandoverModal() {
    if (_activeAllotments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active allotments found in progress.')),
      );
      return;
    }

    String selectedAllotmentId = _activeAllotments.first['id'];
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
          final allotment = _activeAllotments.firstWhere(
            (a) => a['id'] == selectedAllotmentId,
            orElse: () => _activeAllotments.first,
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
                        items: _activeAllotments.map((al) {
                          final lName = al['profiles']?['username'] ?? 'Lineman';
                          final aNo = al['articles']?['art_no'] ?? '';
                          final qty = al['target_qty'] ?? 0;
                          return DropdownMenuItem<String>(
                            value: al['id'],
                            child: Text('$lName • $aNo ($qty pcs)', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
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
                                'Article: $artNo (${artDesc.isEmpty ? "Garment" : artDesc})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
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

                            final notesPayload = {
                              'received_qty': receivedText.isEmpty ? mat['required_qty'] : receivedText,
                              'status': status,
                              'shortage_qty': shortageText.isEmpty ? null : shortageText,
                              'supplier_challan_no': challanNo.isEmpty ? null : challanNo,
                              'store_verified': true,
                              'store_verified_at': nowIso,
                              'store_remarks': remarksText.isEmpty ? null : remarksText,
                            };

                            // Encode into valid JSON string
                            final notesJson = '{"lineman_name":"$linemanName","received_qty":"${notesPayload['received_qty']}","status":"$status","shortage_qty":"${notesPayload['shortage_qty'] ?? ''}","supplier_challan_no":"${notesPayload['supplier_challan_no'] ?? ''}","store_verified":true,"store_verified_at":"$nowIso","store_remarks":"${notesPayload['store_remarks'] ?? ''}"}';

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
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Store Ledger'),
        actions: [
          const ConnectivityIndicator(),
          const SizedBox(width: 4),
          IconButton(icon: const Icon(Icons.refresh_rounded), tooltip: 'Refresh', onPressed: _fetchStoreData),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchStoreData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ====== STORE INVENTORY SUMMARY CARD ======
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 16, offset: const Offset(0, 8)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Store & Godown Ledger', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                  Text('Finished Goods & Raw Materials Inventory', style: TextStyle(color: Colors.white60, fontSize: 12)),
                                ],
                              ),
                              Icon(Icons.warehouse_rounded, color: Colors.white70, size: 28),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              _buildSummaryStat('Finished Stock', '$_totalFinishedStock pcs', Icons.inventory_2_rounded, const Color(0xFF38BDF8)),
                              _buildSummaryStat('Active Lots', '${_activeAllotments.length} lots', Icons.fact_check_rounded, const Color(0xFF818CF8)),
                              _buildSummaryStat('Today Inward', '+$_todayInward', Icons.download_rounded, const Color(0xFF34D399)),
                              _buildSummaryStat('Today Outward', '-$_todayOutward', Icons.upload_rounded, const Color(0xFFF43F5E)),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ====== STORE QUICK ACTIONS ======
                    const Text('Store Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                    const SizedBox(height: 12),

                    _buildActionTile(
                      title: 'BOM MATERIAL HANDOVER',
                      subtitle: 'Inspect supplier challan & issue materials to Lineman',
                      icon: Icons.fact_check_rounded,
                      color: const Color(0xFF4F46E5),
                      bgColor: const Color(0xFFEEF2FF),
                      onTap: _showMaterialHandoverModal,
                    ),
                    const SizedBox(height: 10),

                    _buildActionTile(
                      title: 'INWARD',
                      subtitle: 'Receive finished goods from QC / Production',
                      icon: Icons.download_rounded,
                      color: const Color(0xFF047857),
                      bgColor: const Color(0xFFECFDF5),
                      onTap: _showInwardModal,
                    ),
                    const SizedBox(height: 10),

                    _buildActionTile(
                      title: 'OUTWARD',
                      subtitle: 'Issue goods for dispatch & delivery',
                      icon: Icons.upload_rounded,
                      color: const Color(0xFF2563EB),
                      bgColor: const Color(0xFFEFF6FF),
                      onTap: _showOutwardModal,
                    ),

                    const SizedBox(height: 24),

                    // ====== STORE LEDGER ACTIVITY FEED ======
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Recent Store Ledger Feed', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                        Text('${_storeLogs.length} entries', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (_storeLogs.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE2E8F0))),
                        child: const Center(
                          child: Text('No store transactions logged yet.\nTap INWARD, OUTWARD, or ACCESSORIES above to record movements.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, height: 1.5)),
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

  Widget _buildSummaryStat(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10), textAlign: TextAlign.center),
        ],
      ),
    );
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
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
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
      final badgeColor = isIN ? const Color(0xFF047857) : Colors.orange.shade800;
      final badgeBg = isIN ? const Color(0xFFECFDF5) : Colors.orange.shade50;
      final badgeText = isIN ? 'Trims IN' : 'Trims OUT';
      final itemName = log['item_name'] ?? 'Item';
      final qty = log['quantity'] ?? 0;
      final unit = log['unit'] ?? 'pcs';
      final party = log['party_name'] ?? '';

      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
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
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(8)),
                        child: Text(badgeText, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: badgeColor)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(itemName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.textDark), overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('${isIN ? "+" : "-"}$qty $unit ${party.isNotEmpty ? "• $party" : ""}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
                  if (log['notes'] != null && (log['notes'] as String).isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text('Note: ${log['notes']}', style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontStyle: FontStyle.italic)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(timeStr, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    } else {
      final isIN = log['type'] == 'INWARD';
      final badgeColor = isIN ? const Color(0xFF047857) : const Color(0xFF2563EB);
      final badgeBg = isIN ? const Color(0xFFECFDF5) : const Color(0xFFEFF6FF);
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
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
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
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(8)),
                        child: Text(badgeText, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: badgeColor)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('$artNo$variantStr', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.textDark), overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('${isIN ? "+" : "-"}$qty pcs ${party.isNotEmpty ? "• $party" : ""} ${challan.isNotEmpty ? "($challan)" : ""}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
                  if (log['notes'] != null && (log['notes'] as String).isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text('Note: ${log['notes']}', style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontStyle: FontStyle.italic)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(timeStr, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }
  }
}