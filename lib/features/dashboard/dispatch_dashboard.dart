import '../../core/widgets/connectivity_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/providers/auth_provider.dart';
import '../auth/screens/login_screen.dart';
import '../../core/theme/app_theme.dart';
import '../../../main.dart'; // supabase client

class DispatchDashboard extends ConsumerStatefulWidget {
  const DispatchDashboard({super.key});

  @override
  ConsumerState<DispatchDashboard> createState() => _DispatchDashboardState();
}

class _DispatchDashboardState extends ConsumerState<DispatchDashboard> {
  bool _isLoading = true;
  String _selectedFeedTab = 'challans'; // 'challans' | 'counting'

  // Aggregate Stats
  int _todayCountedQty = 0;
  int _todayDeliveredQty = 0;
  int _activeChallansCount = 0;
  int _discrepanciesCount = 0;

  List<dynamic> _articles = [];
  List<dynamic> _recentChallans = [];
  List<dynamic> _recentCountings = [];
  Map<String, int> _expectedQtyMap = {};

  @override
  void initState() {
    super.initState();
    _fetchDispatchData();
  }

  Future<void> _fetchDispatchData() async {
    setState(() => _isLoading = true);
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];

      // 1. Fetch Articles
      final articlesRes = await supabase
          .from('articles')
          .select('id, art_no, description')
          .eq('is_active', true)
          .order('art_no');

      // 2. Fetch Store Outward entries (for Expected Qty auto-fill)
      final storeOutwardRes = await supabase
          .from('store_transactions')
          .select('article_id, quantity')
          .eq('type', 'OUTWARD')
          .eq('entry_date', today);

      final Map<String, int> expMap = {};
      for (var row in storeOutwardRes) {
        final artId = row['article_id'] as String;
        final q = (row['quantity'] as int?) ?? 0;
        expMap[artId] = (expMap[artId] ?? 0) + q;
      }

      // 3. Fetch Delivery Challans with items
      final challansRes = await supabase
          .from('delivery_challans')
          .select('''
            id,
            challan_no,
            buyer_name,
            destination,
            vehicle_no,
            driver_name,
            driver_phone,
            total_pieces,
            delivery_date,
            created_at,
            status,
            challan_items (
              id,
              article_id,
              size,
              color,
              quantity,
              article:articles ( art_no, description )
            )
          ''')
          .order('created_at', ascending: false)
          .limit(50);

      // 4. Fetch Counting Reports
      final countingRes = await supabase
          .from('counting_reports')
          .select('''
            id,
            article_id,
            size,
            color,
            counted_qty,
            expected_qty,
            remarks,
            entry_date,
            created_at,
            article:articles ( art_no, description )
          ''')
          .order('created_at', ascending: false)
          .limit(50);

      // 5. Aggregate KPIs
      int totalCounted = 0;
      int discCount = 0;
      for (var c in countingRes) {
        if (c['entry_date'] == today) {
          totalCounted += (c['counted_qty'] as int?) ?? 0;
          final exp = (c['expected_qty'] as int?) ?? 0;
          final cnt = (c['counted_qty'] as int?) ?? 0;
          if (exp > 0 && exp != cnt) {
            discCount++;
          }
        }
      }

      int totalDelivered = 0;
      int activeChallans = 0;
      for (var ch in challansRes) {
        if (ch['delivery_date'] == today) {
          totalDelivered += (ch['total_pieces'] as int?) ?? 0;
          activeChallans++;
        }
      }

      if (mounted) {
        setState(() {
          _articles = articlesRes;
          _expectedQtyMap = expMap;
          _recentChallans = challansRes;
          _recentCountings = countingRes;
          _todayCountedQty = totalCounted;
          _todayDeliveredQty = totalDelivered;
          _activeChallansCount = activeChallans;
          _discrepanciesCount = discCount;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading dispatch data: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ==========================================
  // MODULE 1: COUNTING REPORT (PRE-LOAD TALLY)
  // ==========================================
  void _showCountingModal() {
    String? selectedArticleId = _articles.isNotEmpty ? _articles.first['id'] : null;
    final colorController = TextEditingController(text: 'Navy Blue');
    final sizeController = TextEditingController(text: 'L');
    final expectedController = TextEditingController(
      text: selectedArticleId != null ? (_expectedQtyMap[selectedArticleId] ?? 200).toString() : '200',
    );
    final countedController = TextEditingController();
    final remarksController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final counted = int.tryParse(countedController.text) ?? 0;
          final expected = int.tryParse(expectedController.text) ?? 0;
          final diff = counted - expected;
          final isMismatch = expected > 0 && counted > 0 && diff != 0;

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
                        child: const Icon(Icons.pin_outlined, color: Color(0xFF2563EB), size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('COUNTING REPORT: Pre-Loading Tally', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                            Text('Verify carton & bundle count before loading into truck', style: TextStyle(fontSize: 12, color: Colors.grey)),
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
                        items: _articles.map((art) => DropdownMenuItem<String>(
                          value: art['id'],
                          child: Text('${art['art_no']} (${art['description'] ?? ''})', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        )).toList(),
                        onChanged: (v) {
                          setModalState(() {
                            selectedArticleId = v;
                            if (v != null && _expectedQtyMap.containsKey(v) && (_expectedQtyMap[v] ?? 0) > 0) {
                              expectedController.text = _expectedQtyMap[v].toString();
                            }
                          });
                        },
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
                            TextField(controller: sizeController, decoration: InputDecoration(hintText: 'e.g. L', contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Expected vs Counted
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Expected System Qty', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                            const SizedBox(height: 4),
                            TextField(
                              controller: expectedController,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setModalState(() {}),
                              decoration: InputDecoration(hintText: 'e.g. 500', prefixIcon: const Icon(Icons.info_outline, size: 18), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Physical Counted Qty', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                            const SizedBox(height: 4),
                            TextField(
                              controller: countedController,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setModalState(() {}),
                              decoration: InputDecoration(hintText: 'e.g. 480', prefixIcon: const Icon(Icons.pin_rounded, size: 18), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Live Difference & Alert Chip
                  if (countedController.text.isNotEmpty && expectedController.text.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: diff == 0 ? const Color(0xFFECFDF5) : (diff < 0 ? const Color(0xFFFFF1F2) : const Color(0xFFFFFBEB)),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: diff == 0 ? const Color(0xFFA7F3D0) : (diff < 0 ? const Color(0xFFFECDD3) : const Color(0xFFFDE68A))),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            diff == 0 ? Icons.check_circle_rounded : (diff < 0 ? Icons.error_rounded : Icons.add_circle_rounded),
                            color: diff == 0 ? const Color(0xFF047857) : (diff < 0 ? const Color(0xFFE11D48) : const Color(0xFFD97706)),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              diff == 0
                                  ? 'Exact Match! Counted $counted pcs tally perfectly âœ…'
                                  : (diff < 0
                                      ? 'âš ï¸ SHORTAGE ALERT: $diff pcs missing! (Counted: $counted vs Expected: $expected)'
                                      : 'ðŸ“¦ SURPLUS ALERT: +$diff pcs extra! (Counted: $counted vs Expected: $expected)'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: diff == 0 ? const Color(0xFF047857) : (diff < 0 ? const Color(0xFFBE123C) : const Color(0xFFB45309)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 14),

                  // Remarks
                  const Text('Counting Remarks / Notes (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: remarksController,
                    decoration: InputDecoration(hintText: isMismatch ? 'Reason for difference (e.g. 1 bundle short in carton #4)' : 'e.g. Checked & loaded onto truck', prefixIcon: const Icon(Icons.notes_rounded, size: 20), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final cnt = int.tryParse(countedController.text);
                        final exp = int.tryParse(expectedController.text) ?? 0;
                        if (selectedArticleId == null || cnt == null || cnt <= 0) {
                          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please enter a valid physical counted quantity.')));
                          return;
                        }

                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        Navigator.pop(ctx);
                        try {
                          final todayStr = DateTime.now().toIso8601String().split('T')[0];
                          await supabase.from('counting_reports').insert({
                            'article_id': selectedArticleId,
                            'color': colorController.text.trim(),
                            'size': sizeController.text.trim(),
                            'counted_qty': cnt,
                            'expected_qty': exp,
                            'remarks': remarksController.text.trim().isEmpty ? null : remarksController.text.trim(),
                            'entry_date': todayStr,
                          });

                          scaffoldMessenger.showSnackBar(
                            SnackBar(
                              content: Text('Recorded counting of $cnt pcs ${diff != 0 ? "(Mismatch $diff pcs)" : "âœ…"}'),
                              backgroundColor: diff == 0 ? AppTheme.successGreen : Colors.orange.shade800,
                            ),
                          );
                          _fetchDispatchData();
                        } catch (e) {
                          scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
                        }
                      },
                      icon: const Icon(Icons.check_rounded, size: 20),
                      label: const Text('Save & Verify Counting Report'),
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
  // MODULE 2: DELIVERY REPORT (CHALLAN BUILDER)
  // ==========================================
  void _showDeliveryChallanModal() {
    final challanNo = 'CH-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    final buyerController = TextEditingController(text: 'Reliance Retail Pvt Ltd');
    final destinationController = TextEditingController(text: 'Mumbai Central Hub');
    final vehicleController = TextEditingController(text: 'Truck MH-04-AB-1234');
    final driverController = TextEditingController(text: 'Ramesh Kumar');
    final driverPhoneController = TextEditingController(text: '+91 98765 43210');

    // Multi-row items
    List<Map<String, dynamic>> challanItems = [
      {
        'article_id': _articles.isNotEmpty ? _articles.first['id'] : '',
        'color': 'Navy Blue',
        'size': 'L',
        'qty_controller': TextEditingController(text: '200'),
      }
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          int calcTotal() {
            int t = 0;
            for (var it in challanItems) {
              t += int.tryParse((it['qty_controller'] as TextEditingController).text) ?? 0;
            }
            return t;
          }

          final totalPcs = calcTotal();

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
                        child: const Icon(Icons.local_shipping_rounded, color: Color(0xFF2563EB), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('GENERATE DELIVERY CHALLAN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                            Text('Official Gate Pass & Consignment Document (#$challanNo)', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Buyer & Destination
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Buyer / Consignee Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                            const SizedBox(height: 4),
                            TextField(controller: buyerController, decoration: InputDecoration(hintText: 'e.g. Reliance Retail', contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Destination City / Hub', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                            const SizedBox(height: 4),
                            TextField(controller: destinationController, decoration: InputDecoration(hintText: 'e.g. Mumbai Hub', contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Articles / Line Items
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Challan Items (Articles & Sizes)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                      TextButton.icon(
                        onPressed: () {
                          setModalState(() {
                            challanItems.add({
                              'article_id': _articles.isNotEmpty ? _articles.first['id'] : '',
                              'color': 'Black',
                              'size': 'M',
                              'qty_controller': TextEditingController(text: '100'),
                            });
                          });
                        },
                        icon: const Icon(Icons.add_circle_outline, size: 16),
                        label: const Text('+ Add Item', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  ...challanItems.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Text('#${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: item['article_id'],
                                    isExpanded: true,
                                    items: _articles.map((art) => DropdownMenuItem<String>(
                                      value: art['id'],
                                      child: Text('${art['art_no']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    )).toList(),
                                    onChanged: (v) => setModalState(() => item['article_id'] = v ?? ''),
                                  ),
                                ),
                              ),
                              if (challanItems.length > 1)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                                  onPressed: () => setModalState(() => challanItems.removeAt(index)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  decoration: const InputDecoration(labelText: 'Color', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8), border: OutlineInputBorder()),
                                  onChanged: (v) => item['color'] = v,
                                  controller: TextEditingController(text: item['color']),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  decoration: const InputDecoration(labelText: 'Size', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8), border: OutlineInputBorder()),
                                  onChanged: (v) => item['size'] = v,
                                  controller: TextEditingController(text: item['size']),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: item['qty_controller'],
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) => setModalState(() {}),
                                  decoration: const InputDecoration(labelText: 'Qty (Pcs)', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8), border: OutlineInputBorder()),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),

                  // Total Pieces Box
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Consignment Quantity:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E40AF))),
                        Text('$totalPcs Pieces', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF1D4ED8))),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Transporter / Vehicle Details
                  const Text('Transporter & Driver Details', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: vehicleController,
                          decoration: InputDecoration(hintText: 'e.g. MH-04-1234', prefixIcon: const Icon(Icons.local_shipping_rounded, size: 18), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: driverController,
                          decoration: InputDecoration(hintText: 'e.g. Ramesh Kumar', prefixIcon: const Icon(Icons.person_rounded, size: 18), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: driverPhoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(hintText: 'Driver Phone: +91 98765 43210', prefixIcon: const Icon(Icons.phone_rounded, size: 18), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        if (buyerController.text.trim().isEmpty || totalPcs <= 0) {
                          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please enter buyer name and at least one item quantity.')));
                          return;
                        }

                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        Navigator.pop(ctx);
                        try {
                          final todayStr = DateTime.now().toIso8601String().split('T')[0];

                          // 1. Create Delivery Challan
                          final challanInsert = await supabase
                              .from('delivery_challans')
                              .insert({
                                'challan_no': challanNo,
                                'buyer_name': buyerController.text.trim(),
                                'destination': destinationController.text.trim(),
                                'vehicle_no': vehicleController.text.trim(),
                                'driver_name': driverController.text.trim(),
                                'driver_phone': driverPhoneController.text.trim(),
                                'total_pieces': totalPcs,
                                'delivery_date': todayStr,
                                'status': 'DISPATCHED',
                              })
                              .select()
                              .single();

                          final challanId = challanInsert['id'];

                          // 2. Insert Challan Items & Store Outward entries
                          for (var item in challanItems) {
                            final q = int.tryParse((item['qty_controller'] as TextEditingController).text) ?? 0;
                            if (q > 0) {
                              await supabase.from('challan_items').insert({
                                'challan_id': challanId,
                                'article_id': item['article_id'],
                                'color': item['color'],
                                'size': item['size'],
                                'quantity': q,
                              });

                              // Also link to store_transactions as OUTWARD
                              await supabase.from('store_transactions').insert({
                                'article_id': item['article_id'],
                                'type': 'OUTWARD',
                                'quantity': q,
                                'color': item['color'],
                                'size': item['size'],
                                'party_name': buyerController.text.trim(),
                                'challan_no': challanNo,
                                'transport_no': vehicleController.text.trim(),
                                'entry_date': todayStr,
                              });
                            }
                          }

                          scaffoldMessenger.showSnackBar(
                            SnackBar(
                              content: Text('Created Challan #$challanNo for $totalPcs pcs! ðŸšš'),
                              backgroundColor: const Color(0xFF047857),
                            ),
                          );
                          _fetchDispatchData();
                        } catch (e) {
                          scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
                        }
                      },
                      icon: const Icon(Icons.print_rounded, size: 20),
                      label: const Text('Generate Official Challan & Dispatch'),
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
  // VIEW & PRINTABLE CHALLAN MODAL
  // ==========================================
  void _showChallanSlipModal(dynamic challan) {
    final items = (challan['challan_items'] as List<dynamic>?) ?? [];
    final challanNo = challan['challan_no'] ?? '-';
    final buyer = challan['buyer_name'] ?? '-';
    final dest = challan['destination'] ?? '-';
    final vehicle = challan['vehicle_no'] ?? '-';
    final driver = challan['driver_name'] ?? '-';
    final driverPhone = challan['driver_phone'] ?? '';
    final date = challan['delivery_date'] ?? '-';
    final total = challan['total_pieces'] ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
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

              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(20)),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('ðŸ­ NUBIRA CREATION', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5)),
                        Text('DELIVERY CHALLAN', style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Challan #: $challanNo', style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                        Text('Date: $date', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Consignee & Vehicle Info
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Consignee: $buyer', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppTheme.textDark)),
                    const SizedBox(height: 2),
                    Text('Destination: $dest', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                    const Divider(height: 16),
                    Row(
                      children: [
                        Expanded(child: Text('Vehicle: $vehicle', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                        Expanded(child: Text('Driver: $driver ${driverPhone.isNotEmpty ? "($driverPhone)" : ""}', style: const TextStyle(fontSize: 12))),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Line items table
              const Text('Itemized Consignment Breakdown:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
              const SizedBox(height: 6),

              Container(
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: const BoxDecoration(color: Color(0xFFF1F5F9), borderRadius: BorderRadius.vertical(top: Radius.circular(15))),
                      child: const Row(
                        children: [
                          Expanded(flex: 3, child: Text('Article', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey))),
                          Expanded(flex: 3, child: Text('Color / Size', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey))),
                          Expanded(flex: 2, child: Text('Qty (Pcs)', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey))),
                        ],
                      ),
                    ),
                    ...items.map((it) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          Expanded(flex: 3, child: Text('${it['article']?['art_no'] ?? '-'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                          Expanded(flex: 3, child: Text('${it['color'] ?? ''} (${it['size'] ?? ''})', style: const TextStyle(fontSize: 12, color: Colors.grey))),
                          Expanded(flex: 2, child: Text('${it['quantity']} pcs', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF2563EB)))),
                        ],
                      ),
                    )),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(color: Color(0xFFEFF6FF), borderRadius: BorderRadius.vertical(bottom: Radius.circular(15))),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('TOTAL DISPATCH:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E40AF))),
                          Text('$total Pieces', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF1D4ED8))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Action Buttons: WhatsApp Share & Copy Text
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final slipText = '''
ðŸ“¦ NUBIRA CREATION - DELIVERY CHALLAN #$challanNo
ðŸ“… Date: $date
ðŸ¢ Buyer: $buyer
ðŸ“ Destination: $dest
ðŸšš Vehicle: $vehicle | Driver: $driver ($driverPhone)
â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
TOTAL QUANTITY: $total Pieces
â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
âœ… Verified & Dispatched from Factory
''';
                        Clipboard.setData(ClipboardData(text: slipText));
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Challan text copied! Ready to paste in WhatsApp ðŸ“²')),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Copy WhatsApp Text'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Close'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
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
        title: const Text('Dispatch Area'),
        actions: [
          const ConnectivityIndicator(),
          const SizedBox(width: 4),
          IconButton(icon: const Icon(Icons.refresh_rounded), tooltip: 'Refresh', onPressed: _fetchDispatchData),
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
              onRefresh: _fetchDispatchData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ====== TOP SUMMARY CARD ======
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
                                  Text('Dispatch Logistics Hub', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                  Text('Final Counting, Loading & Delivery Challans', style: TextStyle(color: Colors.white60, fontSize: 12)),
                                ],
                              ),
                              Icon(Icons.local_shipping_rounded, color: Colors.white70, size: 28),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              _buildSummaryStat('Counted Today', '$_todayCountedQty pcs', Icons.pin_rounded, const Color(0xFF38BDF8)),
                              _buildSummaryStat('Delivered Today', '$_todayDeliveredQty pcs', Icons.check_circle_rounded, const Color(0xFF34D399)),
                              _buildSummaryStat('Active Challans', '$_activeChallansCount', Icons.receipt_long_rounded, Colors.orangeAccent),
                              _buildSummaryStat('Discrepancies', '$_discrepanciesCount', Icons.warning_amber_rounded, _discrepanciesCount > 0 ? const Color(0xFFF43F5E) : Colors.white60),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ====== DISPATCH QUICK ACTIONS ======
                    const Text('Dispatch Operations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                    const SizedBox(height: 12),

                    _buildActionTile(
                      title: 'COUNTING REPORT',
                      subtitle: 'Tally & verify pieces before loading to truck',
                      icon: Icons.pin_outlined,
                      color: const Color(0xFF2563EB),
                      bgColor: const Color(0xFFEFF6FF),
                      onTap: _showCountingModal,
                    ),
                    const SizedBox(height: 10),

                    _buildActionTile(
                      title: 'DELIVERY REPORT (CHALLAN)',
                      subtitle: 'Generate official delivery challan document',
                      icon: Icons.local_shipping_rounded,
                      color: const Color(0xFF047857),
                      bgColor: const Color(0xFFECFDF5),
                      onTap: _showDeliveryChallanModal,
                    ),

                    const SizedBox(height: 24),

                    // ====== RECENT FEED WITH SEGMENTED TABS ======
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _selectedFeedTab = 'challans'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: _selectedFeedTab == 'challans' ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: _selectedFeedTab == 'challans' ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)] : null,
                                ),
                                child: Center(
                                  child: Text('Recent Challans (${_recentChallans.length})', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _selectedFeedTab == 'challans' ? AppTheme.textDark : Colors.grey)),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _selectedFeedTab = 'counting'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: _selectedFeedTab == 'counting' ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: _selectedFeedTab == 'counting' ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)] : null,
                                ),
                                child: Center(
                                  child: Text('Counting Audits (${_recentCountings.length})', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _selectedFeedTab == 'counting' ? AppTheme.textDark : Colors.grey)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // FEED LIST
                    if (_selectedFeedTab == 'challans') ...[
                      if (_recentChallans.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE2E8F0))),
                          child: const Center(
                            child: Text('No delivery challans generated yet.\nTap DELIVERY REPORT above to create your first dispatch challan.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, height: 1.5)),
                          ),
                        )
                      else
                        ..._recentChallans.map((ch) => _buildChallanCard(ch)),
                    ] else ...[
                      if (_recentCountings.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE2E8F0))),
                          child: const Center(
                            child: Text('No pre-loading counting audits logged yet.\nTap COUNTING REPORT above to tally goods before loading.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, height: 1.5)),
                          ),
                        )
                      else
                        ..._recentCountings.map((c) => _buildCountingCard(c)),
                    ],

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

  Widget _buildChallanCard(dynamic ch) {
    final challanNo = ch['challan_no'] ?? '-';
    final buyer = ch['buyer_name'] ?? '-';
    final total = ch['total_pieces'] ?? 0;
    final vehicle = ch['vehicle_no'] ?? '-';
    final timeStr = ch['created_at'] != null ? DateTime.parse(ch['created_at']).toLocal().toString().substring(11, 16) : '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF2563EB), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('#$challanNo', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppTheme.textDark)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(6)),
                      child: Text('$total pcs', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF047857))),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Buyer: $buyer â€¢ $vehicle', style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(timeStr, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              InkWell(
                onTap: () => _showChallanSlipModal(ch),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                  child: const Text('View Slip âž”', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCountingCard(dynamic c) {
    final artNo = c['article']?['art_no'] ?? '-';
    final color = c['color'] ?? '';
    final size = c['size'] ?? '';
    final counted = (c['counted_qty'] as int?) ?? 0;
    final expected = (c['expected_qty'] as int?) ?? 0;
    final diff = counted - expected;
    final remarks = c['remarks'] ?? '';
    final timeStr = c['created_at'] != null ? DateTime.parse(c['created_at']).toLocal().toString().substring(11, 16) : '-';

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
                    Text('$artNo', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppTheme.textDark)),
                    if (color.isNotEmpty || size.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text('â€¢ $color ($size)', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: diff == 0 ? const Color(0xFFECFDF5) : const Color(0xFFFFF1F2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        diff == 0 ? 'Match âœ…' : '$diff pcs âš ï¸',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: diff == 0 ? const Color(0xFF047857) : const Color(0xFFE11D48)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Counted: $counted pcs (Expected: $expected pcs)', style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
                if (remarks.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text('Note: $remarks', style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontStyle: FontStyle.italic)),
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