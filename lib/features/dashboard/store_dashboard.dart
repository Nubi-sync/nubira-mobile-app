import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  int _totalAccessoriesTracked = 0;
  int _todayInward = 0;
  int _todayOutward = 0;

  List<dynamic> _articles = [];
  List<dynamic> _storeLogs = [];
  final List<String> _commonAccessories = [
    'Sewing Thread (Navy Blue)',
    'Sewing Thread (Black)',
    'Sewing Thread (White)',
    'Buttons (18L 4-Hole)',
    'Buttons (24L 4-Hole)',
    'Nylon Zipper 7 inch',
    'Main Brand Label',
    'Care & Size Label',
    'Polybag (10x14)',
    'Elastic (1 inch roll)',
    'Fusing / Interlining (Meters)',
    'Hang Tag & Tag Pin'
  ];

  Map<String, int> _articleStockMap = {};

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

      for (var tx in txRes) {
        final qty = (tx['quantity'] as int?) ?? 0;
        final type = tx['type'] as String? ?? 'INWARD';
        final artId = tx['article']?['id'] as String? ?? 'UNKNOWN';
        final entryDate = (tx['entry_date'] as String?) ?? (tx['created_at'] != null ? tx['created_at'].toString().split('T')[0] : '');

        if (type == 'INWARD') {
          totalIn += qty;
          stockMap[artId] = (stockMap[artId] ?? 0) + qty;
          if (entryDate == today) tInward += qty;
        } else if (type == 'OUTWARD') {
          totalOut += qty;
          stockMap[artId] = (stockMap[artId] ?? 0) - qty;
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
          _totalAccessoriesTracked = distinctAcc.length;
          _todayInward = tInward;
          _todayOutward = tOutward;
          _articleStockMap = stockMap;
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
  // MODULE 1: INWARD (RECEIVE FINISHED GOODS)
  // ==========================================
  void _showInwardModal() {
    String? selectedArticleId = _articles.isNotEmpty ? _articles.first['id'] : null;
    final colorController = TextEditingController(text: 'Navy Blue');
    final sizeController = TextEditingController(text: 'L');
    final qtyController = TextEditingController();
    final fromController = TextEditingController(text: 'QC Finishing Floor');
    final notesController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
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
                          Text('INWARD: Receive Finished Goods', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                          Text('Add passed garments from QC / Finishing into Godown', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Article Dropdown
                const Text('Article (Style #)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFCBD5E1))),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedArticleId,
                      isExpanded: true,
                      items: _articles.map((art) => DropdownMenuItem<String>(value: art['id'], child: Text('${art['art_no']} (${art['description'] ?? ''})', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)))).toList(),
                      onChanged: (v) => setModalState(() => selectedArticleId = v),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Color & Size
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Color', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                          const SizedBox(height: 4),
                          TextField(controller: colorController, decoration: InputDecoration(hintText: 'e.g. Navy Blue', contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Size', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                          const SizedBox(height: 4),
                          TextField(controller: sizeController, decoration: InputDecoration(hintText: 'e.g. L, 32', contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Quantity
                const Text('Quantity Received (Pieces)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                const SizedBox(height: 6),
                TextField(
                  controller: qtyController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(hintText: 'e.g. 150', prefixIcon: const Icon(Icons.pin_rounded, size: 20), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
                ),

                const SizedBox(height: 14),

                // From
                const Text('Received From', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                const SizedBox(height: 6),
                TextField(
                  controller: fromController,
                  decoration: InputDecoration(hintText: 'e.g. QC Finishing Table', prefixIcon: const Icon(Icons.factory_rounded, size: 20), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
                ),

                const SizedBox(height: 14),

                // Notes
                const Text('Carton / Bundle Notes (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                const SizedBox(height: 6),
                TextField(
                  controller: notesController,
                  decoration: InputDecoration(hintText: 'e.g. Master Carton #3 (3x50 bundles)', prefixIcon: const Icon(Icons.notes_rounded, size: 20), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final qty = int.tryParse(qtyController.text);
                      if (selectedArticleId == null || qty == null || qty <= 0) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please enter a valid quantity.')));
                        return;
                      }

                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                      Navigator.pop(ctx);
                      try {
                        final todayStr = DateTime.now().toIso8601String().split('T')[0];
                        await supabase.from('store_transactions').insert({
                          'article_id': selectedArticleId,
                          'type': 'INWARD',
                          'quantity': qty,
                          'color': colorController.text.trim(),
                          'size': sizeController.text.trim(),
                          'party_name': fromController.text.trim(),
                          'notes': notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                          'entry_date': todayStr,
                        });

                        scaffoldMessenger.showSnackBar(
                          SnackBar(content: Text('Inwarded $qty pcs to Store Godown! ðŸ“¥'), backgroundColor: AppTheme.successGreen),
                        );
                        _fetchStoreData();
                      } catch (e) {
                        scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
                      }
                    },
                    icon: const Icon(Icons.download_rounded, size: 20),
                    label: const Text('Save Inward & Add to Stock'),
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
        ),
      ),
    );
  }

  // ==========================================
  // MODULE 2: OUTWARD (DISPATCH GOODS)
  // ==========================================
  void _showOutwardModal() {
    String? selectedArticleId = _articles.isNotEmpty ? _articles.first['id'] : null;
    final colorController = TextEditingController(text: 'Navy Blue');
    final sizeController = TextEditingController(text: 'L');
    final qtyController = TextEditingController();
    final buyerController = TextEditingController();
    final challanController = TextEditingController();
    final notesController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final availStock = selectedArticleId != null ? (_articleStockMap[selectedArticleId] ?? 0) : 0;

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
                            Text('OUTWARD: Dispatch Finished Goods', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                            Text('Issue garments for customer delivery or retail branch', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Article Dropdown
                  const Text('Article (Style #)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFCBD5E1))),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedArticleId,
                        isExpanded: true,
                        items: _articles.map((art) => DropdownMenuItem<String>(value: art['id'], child: Text('${art['art_no']} (${art['description'] ?? ''})', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)))).toList(),
                        onChanged: (v) => setModalState(() => selectedArticleId = v),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Available stock chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: availStock > 0 ? const Color(0xFFEFF6FF) : const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: availStock > 0 ? const Color(0xFFBFDBFE) : const Color(0xFFFECDD3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(availStock > 0 ? Icons.check_circle_outline : Icons.warning_amber_rounded, size: 16, color: availStock > 0 ? const Color(0xFF2563EB) : const Color(0xFFE11D48)),
                        const SizedBox(width: 6),
                        Text('Available in Godown: $availStock pcs', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: availStock > 0 ? const Color(0xFF1E40AF) : const Color(0xFFBE123C))),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Color & Size
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Color', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                            const SizedBox(height: 4),
                            TextField(controller: colorController, decoration: InputDecoration(hintText: 'e.g. Navy Blue', contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Size', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                            const SizedBox(height: 4),
                            TextField(controller: sizeController, decoration: InputDecoration(hintText: 'e.g. L', contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Dispatch Quantity
                  const Text('Dispatch Quantity (Pieces)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: qtyController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(hintText: 'e.g. 100', prefixIcon: const Icon(Icons.pin_rounded, size: 20), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
                  ),

                  const SizedBox(height: 14),

                  // Buyer Name
                  const Text('Buyer Name / Customer / PO #', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: buyerController,
                    decoration: InputDecoration(hintText: 'e.g. Reliance Retail / Order #PO-882', prefixIcon: const Icon(Icons.business_rounded, size: 20), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
                  ),

                  const SizedBox(height: 14),

                  // Delivery Challan / Vehicle No
                  const Text('Challan No / Vehicle No (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: challanController,
                    decoration: InputDecoration(hintText: 'e.g. Challan #DC-402 • Truck MH-04-1234', prefixIcon: const Icon(Icons.local_shipping_rounded, size: 20), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final qty = int.tryParse(qtyController.text);
                        if (selectedArticleId == null || qty == null || qty <= 0) {
                          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please enter a valid quantity.')));
                          return;
                        }

                        if (qty > availStock && availStock > 0) {
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Cannot dispatch $qty pcs. Only $availStock pcs available!')));
                          return;
                        }

                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        Navigator.pop(ctx);
                        try {
                          final todayStr = DateTime.now().toIso8601String().split('T')[0];
                          await supabase.from('store_transactions').insert({
                            'article_id': selectedArticleId,
                            'type': 'OUTWARD',
                            'quantity': qty,
                            'color': colorController.text.trim(),
                            'size': sizeController.text.trim(),
                            'party_name': buyerController.text.trim().isEmpty ? 'General Dispatch' : buyerController.text.trim(),
                            'challan_no': challanController.text.trim().isEmpty ? null : challanController.text.trim(),
                            'notes': notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                            'entry_date': todayStr,
                          });

                          scaffoldMessenger.showSnackBar(
                            SnackBar(content: Text('Dispatched $qty pcs from Store Godown!'), backgroundColor: const Color(0xFF2563EB)),
                          );
                          _fetchStoreData();
                        } catch (e) {
                          scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
                        }
                      },
                      icon: const Icon(Icons.upload_rounded, size: 20),
                      label: const Text('Dispatch Goods & Deduct Stock'),
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
  void _showAccessoriesModal() {
    String selectedAction = 'IN';
    final itemController = TextEditingController(text: 'Sewing Thread (Navy Blue)');
    final qtyController = TextEditingController();
    String selectedUnit = 'cones';
    final partyController = TextEditingController(text: 'Supplier: Vardhman Threads');
    final notesController = TextEditingController();

    final List<String> units = ['cones', 'pcs', 'gross', 'meters', 'packets', 'rolls', 'boxes'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
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
                      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.category_rounded, color: Colors.orange, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ACCESSORIES: Raw Materials Ledger', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                          Text('Track Thread, Buttons, Zippers, Labels, Polybags', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Action Toggle (IN vs OUT)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(14)),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            setModalState(() {
                              selectedAction = 'IN';
                              partyController.text = 'Supplier: Vardhman Threads';
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: selectedAction == 'IN' ? const Color(0xFF047857) : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.arrow_downward_rounded, size: 14, color: selectedAction == 'IN' ? Colors.white : const Color(0xFF64748B)),
                                  const SizedBox(width: 4),
                                  Text('IN (Stock Received)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: selectedAction == 'IN' ? Colors.white : const Color(0xFF64748B))),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            setModalState(() {
                              selectedAction = 'OUT';
                              partyController.text = 'Issued to: Line 1 (Lineman Raju)';
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: selectedAction == 'OUT' ? const Color(0xFFD97706) : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.arrow_upward_rounded, size: 14, color: selectedAction == 'OUT' ? Colors.white : const Color(0xFF64748B)),
                                  const SizedBox(width: 4),
                                  Text('OUT (Issued to Line)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: selectedAction == 'OUT' ? Colors.white : const Color(0xFF64748B))),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Item Name Autocomplete/Dropdown
                const Text('Item Name / Description', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                const SizedBox(height: 6),
                TextField(
                  controller: itemController,
                  decoration: InputDecoration(
                    hintText: 'e.g. Sewing Thread, Button 18L',
                    prefixIcon: const Icon(Icons.label_rounded, size: 20),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),

                const SizedBox(height: 8),

                // Quick item chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _commonAccessories.take(5).map((item) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        label: Text(item, style: const TextStyle(fontSize: 11)),
                        onPressed: () => setModalState(() => itemController.text = item),
                      ),
                    )).toList(),
                  ),
                ),

                const SizedBox(height: 14),

                // Quantity & Unit
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Quantity', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                          const SizedBox(height: 4),
                          TextField(
                            controller: qtyController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(hintText: 'e.g. 24', prefixIcon: const Icon(Icons.pin_rounded, size: 20), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Unit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFCBD5E1))),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedUnit,
                                isExpanded: true,
                                items: units.map((u) => DropdownMenuItem<String>(value: u, child: Text(u, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)))).toList(),
                                onChanged: (v) => setModalState(() => selectedUnit = v ?? 'cones'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Supplier / Line Reference
                Text(selectedAction == 'IN' ? 'Received From (Supplier Name)' : 'Issued To (Line # / Lineman)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                const SizedBox(height: 6),
                TextField(
                  controller: partyController,
                  decoration: InputDecoration(hintText: 'e.g. Vardhman Threads / Line 1 Raju', prefixIcon: const Icon(Icons.person_pin_rounded, size: 20), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
                ),

                const SizedBox(height: 14),

                // Notes
                const Text('Notes / Bill Reference (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                const SizedBox(height: 6),
                TextField(
                  controller: notesController,
                  decoration: InputDecoration(hintText: 'e.g. Invoice #INV-9912', prefixIcon: const Icon(Icons.notes_rounded, size: 20), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final qty = int.tryParse(qtyController.text);
                      if (itemController.text.trim().isEmpty || qty == null || qty <= 0) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please enter item name and valid quantity.')));
                        return;
                      }

                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                      Navigator.pop(ctx);
                      try {
                        final todayStr = DateTime.now().toIso8601String().split('T')[0];
                        await supabase.from('accessories').insert({
                          'item_name': itemController.text.trim(),
                          'action': selectedAction,
                          'quantity': qty,
                          'unit': selectedUnit,
                          'party_name': partyController.text.trim().isEmpty ? null : partyController.text.trim(),
                          'notes': notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                          'entry_date': todayStr,
                        });

                        scaffoldMessenger.showSnackBar(
                          SnackBar(
                            content: Text('${selectedAction == "IN" ? "Added" : "Issued"} $qty $selectedUnit of ${itemController.text.trim()}'),
                            backgroundColor: selectedAction == 'IN' ? const Color(0xFF047857) : Colors.orange,
                          ),
                        );
                        _fetchStoreData();
                      } catch (e) {
                        scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
                      }
                    },
                    icon: const Icon(Icons.category_rounded, size: 20),
                    label: Text('Save ${selectedAction == "IN" ? "Inward Stock" : "Issue to Line"}'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selectedAction == 'IN' ? const Color(0xFF047857) : Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
                              _buildSummaryStat('Accessories', '$_totalAccessoriesTracked items', Icons.category_rounded, Colors.orangeAccent),
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
                    const SizedBox(height: 10),

                    _buildActionTile(
                      title: 'ACCESSORIES',
                      subtitle: 'Thread, buttons, zips, labels raw materials',
                      icon: Icons.category_rounded,
                      color: Colors.orange.shade800,
                      bgColor: Colors.orange.shade50,
                      onTap: _showAccessoriesModal,
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