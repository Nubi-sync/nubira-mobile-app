import '../../core/widgets/connectivity_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/providers/auth_provider.dart';
import '../auth/screens/login_screen.dart';
import '../../core/theme/app_theme.dart';
import '../../../main.dart';

class QcDashboard extends ConsumerStatefulWidget {
  const QcDashboard({super.key});

  @override
  ConsumerState<QcDashboard> createState() => _QcDashboardState();
}

class _QcDashboardState extends ConsumerState<QcDashboard> {
  bool _isLoading = true;

  int _totalReceivedToday = 0;
  int _totalCheckedToday = 0;
  int _totalPassedToday = 0;
  int _totalInMendingToday = 0;
  int _totalPackedToday = 0;
  double _passRate = 100.0;

  List<dynamic> _linemen = [];
  List<dynamic> _articles = [];
  List<dynamic> _activeMendingList = [];
  List<dynamic> _recentQcLogs = [];

  final List<Map<String, String>> _defectTypes = [
    {'key': 'NONE', 'label': 'No Defect (Clean)'},
    {'key': 'STITCHING_ERROR', 'label': 'Stitching / Skip Seam'},
    {'key': 'FABRIC_STAIN', 'label': 'Fabric Stain / Oil'},
    {'key': 'SIZING_ISSUE', 'label': 'Sizing / Fit Issue'},
    {'key': 'MEASUREMENT_OFF', 'label': 'Measurement Off'},
    {'key': 'FABRIC_CUT', 'label': 'Fabric Cut / Hole'},
    {'key': 'COLOR_SHADING', 'label': 'Color Shading'},
    {'key': 'OTHER', 'label': 'Other Minor Issue'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchQcData();
  }

  Future<void> _fetchQcData() async {
    setState(() => _isLoading = true);
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];

      final linemenRes = await supabase
          .from('profiles')
          .select('id, username')
          .eq('role', 'LINEMAN')
          .eq('is_active', true)
          .order('username');

      final articlesRes = await supabase
          .from('articles')
          .select('id, art_no, description')
          .eq('is_active', true)
          .order('art_no');

      final logsRes = await supabase
          .from('qc_logs')
          .select('''
            id,
            article_id,
            stage,
            from_lineman_id,
            qty_received,
            qty_passed,
            qty_rejected,
            defect_type,
            remarks,
            color,
            size,
            mending_returned_qty,
            mending_scrap_qty,
            mending_status,
            bundle_size,
            total_bundles,
            sent_to_store,
            entry_date,
            created_at,
            lineman:profiles!qc_logs_from_lineman_id_fkey ( username ),
            article:articles ( art_no, description )
          ''')
          .eq('entry_date', today)
          .order('created_at', ascending: false);

      int rec = 0;
      int checked = 0;
      int passed = 0;
      int inMending = 0;
      int packed = 0;

      final List<dynamic> activeMending = [];

      for (var log in logsRes) {
        final stage = log['stage'] as String? ?? '';
        final qRec = (log['qty_received'] as int?) ?? 0;
        final qPass = (log['qty_passed'] as int?) ?? 0;
        final qRej = (log['qty_rejected'] as int?) ?? 0;
        final mendRet = (log['mending_returned_qty'] as int?) ?? 0;
        final mendStatus = log['mending_status'] as String? ?? 'NONE';
        final bSize = (log['bundle_size'] as int?) ?? 0;
        final tBundles = (log['total_bundles'] as int?) ?? 0;

        if (stage == 'RECEIVING') {
          rec += qRec;
        } else if (stage == 'CHECKING') {
          checked += (qPass + qRej);
          passed += qPass;
        } else if (stage == 'MENDING') {
          if (mendStatus == 'WITH_LINEMAN_FOR_REPAIR') {
            inMending += qRej;
            activeMending.add(log);
          } else if (mendStatus == 'REPAIR_COMPLETED') {
            passed += mendRet;
          }
        } else if (stage == 'BULKING') {
          packed += (bSize * tBundles);
        }
      }

      double pRate = checked > 0 ? ((passed / checked) * 100).clamp(0.0, 100.0) : 100.0;

      if (mounted) {
        setState(() {
          _linemen = linemenRes;
          _articles = articlesRes;
          _recentQcLogs = logsRes;
          _activeMendingList = activeMending;
          _totalReceivedToday = rec;
          _totalCheckedToday = checked;
          _totalPassedToday = passed;
          _totalInMendingToday = inMending;
          _totalPackedToday = packed;
          _passRate = pRate;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading QC data: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showDailyReceivingModal() {
    String? selectedLinemanId = _linemen.isNotEmpty ? _linemen.first['id'] : null;
    String? selectedArticleId = _articles.isNotEmpty ? _articles.first['id'] : null;
    final colorController = TextEditingController(text: 'Navy Blue');
    final sizeController = TextEditingController(text: 'L');
    final qtyController = TextEditingController();
    final remarksController = TextEditingController();

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
                      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.move_to_inbox_rounded, color: AppTheme.primaryBlue, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Daily Receiving (Line Handover)', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                          Text('Receive stitched bundles from sewing line', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                const Text('From Lineman (Sewing Line)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFCBD5E1))),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedLinemanId,
                      isExpanded: true,
                      items: _linemen.map((lm) => DropdownMenuItem<String>(value: lm['id'], child: Text(lm['username'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)))).toList(),
                      onChanged: (v) => setModalState(() => selectedLinemanId = v),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

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

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Color / Shade', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                          const SizedBox(height: 4),
                          TextField(
                            controller: colorController,
                            decoration: InputDecoration(hintText: 'e.g. Navy Blue', contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                          ),
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
                          TextField(
                            controller: sizeController,
                            decoration: InputDecoration(hintText: 'e.g. L, 32', contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                const Text('Quantity Received (Pieces)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                const SizedBox(height: 6),
                TextField(
                  controller: qtyController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(hintText: 'e.g. 150', prefixIcon: const Icon(Icons.pin_rounded, size: 20), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
                ),

                const SizedBox(height: 14),

                const Text('Remarks / Bundle Note', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                const SizedBox(height: 6),
                TextField(
                  controller: remarksController,
                  decoration: InputDecoration(hintText: 'e.g. Front body bundle', prefixIcon: const Icon(Icons.notes_rounded, size: 20), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final qty = int.tryParse(qtyController.text);
                      if (selectedLinemanId == null || selectedArticleId == null || qty == null || qty <= 0) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please fill all required fields.')));
                        return;
                      }

                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                      Navigator.pop(ctx);
                      try {
                        await supabase.from('qc_logs').insert({
                          'stage': 'RECEIVING',
                          'from_lineman_id': selectedLinemanId,
                          'article_id': selectedArticleId,
                          'color': colorController.text.trim(),
                          'size': sizeController.text.trim(),
                          'qty_received': qty,
                          'remarks': remarksController.text.trim().isEmpty ? null : remarksController.text.trim(),
                          'entry_date': DateTime.now().toIso8601String().split('T')[0],
                        });

                        scaffoldMessenger.showSnackBar(
                          SnackBar(content: Text('Received $qty pcs into QC Queue! ðŸ“¥'), backgroundColor: AppTheme.successGreen),
                        );
                        _fetchQcData();
                      } catch (e) {
                        scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
                      }
                    },
                    icon: const Icon(Icons.move_to_inbox_rounded, size: 20),
                    label: const Text('Receive Pieces & Add to QC Queue'),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCheckingModal() {
    String? selectedArticleId = _articles.isNotEmpty ? _articles.first['id'] : null;
    String? selectedLinemanId = _linemen.isNotEmpty ? _linemen.first['id'] : null;
    final colorController = TextEditingController(text: 'Navy Blue');
    final sizeController = TextEditingController(text: 'L');
    final passedController = TextEditingController();
    final rejectedController = TextEditingController(text: '0');
    final remarksController = TextEditingController();
    String selectedDefect = 'NONE';

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
                      child: const Icon(Icons.fact_check_rounded, color: Color(0xFF047857), size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Quality Checking & Inspection', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                          Text('Inspect garments for pass / defect categorization', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

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

                const Text('Inspected From Lineman', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFCBD5E1))),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedLinemanId,
                      isExpanded: true,
                      items: _linemen.map((lm) => DropdownMenuItem<String>(value: lm['id'], child: Text(lm['username'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)))).toList(),
                      onChanged: (v) => setModalState(() => selectedLinemanId = v),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Color', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                          const SizedBox(height: 4),
                          TextField(
                            controller: colorController,
                            decoration: InputDecoration(hintText: 'e.g. Navy Blue', contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                          ),
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
                          TextField(
                            controller: sizeController,
                            decoration: InputDecoration(hintText: 'e.g. L, 32', contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFA7F3D0))),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.check_circle_rounded, color: Color(0xFF047857), size: 16),
                                SizedBox(width: 4),
                                Text('Passed Qty (OK)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF047857))),
                              ],
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: passedController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF047857)),
                              decoration: const InputDecoration(hintText: '0', border: InputBorder.none, isDense: true),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFFFFF1F2), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFFECDD3))),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.cancel_rounded, color: Color(0xFFBE123C), size: 16),
                                SizedBox(width: 4),
                                Text('Defect Qty', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFBE123C))),
                              ],
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: rejectedController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFFBE123C)),
                              decoration: const InputDecoration(hintText: '0', border: InputBorder.none, isDense: true),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                const Text('Defect Category (If rejected > 0)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _defectTypes.map((dt) {
                    final isSel = selectedDefect == dt['key'];
                    return ChoiceChip(
                      label: Text(dt['label']!, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSel ? Colors.white : AppTheme.textDark)),
                      selected: isSel,
                      selectedColor: isSel ? const Color(0xFFE11D48) : Colors.grey.shade200,
                      onSelected: (selected) {
                        if (selected) setModalState(() => selectedDefect = dt['key']!);
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 14),

                const Text('Inspector Remarks', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                const SizedBox(height: 6),
                TextField(
                  controller: remarksController,
                  decoration: InputDecoration(hintText: 'e.g. Left sleeve skip stitch', prefixIcon: const Icon(Icons.notes_rounded, size: 20), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final pQty = int.tryParse(passedController.text) ?? 0;
                      final rQty = int.tryParse(rejectedController.text) ?? 0;

                      if (selectedArticleId == null || (pQty + rQty) <= 0) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please enter valid inspection quantities.')));
                        return;
                      }

                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                      Navigator.pop(ctx);
                      try {
                        await supabase.from('qc_logs').insert({
                          'stage': 'CHECKING',
                          'article_id': selectedArticleId,
                          'from_lineman_id': selectedLinemanId,
                          'color': colorController.text.trim(),
                          'size': sizeController.text.trim(),
                          'qty_passed': pQty,
                          'qty_rejected': rQty,
                          'defect_type': rQty > 0 ? selectedDefect : 'NONE',
                          'remarks': remarksController.text.trim().isEmpty ? null : remarksController.text.trim(),
                          'entry_date': DateTime.now().toIso8601String().split('T')[0],
                        });

                        scaffoldMessenger.showSnackBar(
                          SnackBar(content: Text('Saved QC Check: $pQty Passed, $rQty Defects âœ…'), backgroundColor: AppTheme.successGreen),
                        );
                        _fetchQcData();
                      } catch (e) {
                        scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
                      }
                    },
                    icon: const Icon(Icons.check_circle_rounded, size: 20),
                    label: const Text('Submit Quality Check Result'),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showMendingModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => DefaultTabController(
          length: 2,
          child: Padding(
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
                        child: const Icon(Icons.build_rounded, color: Colors.orange, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Mending & Alteration (Line Handover)', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                            Text('Return defective pieces to Lineman for repair', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Container(
                    decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(14)),
                    child: const TabBar(
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.all(Radius.circular(12)), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
                      labelColor: Color(0xFF1E293B),
                      labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      unselectedLabelColor: Color(0xFF64748B),
                      tabs: [
                        Tab(text: 'Return to Lineman'),
                        Tab(text: 'Receive Repaired'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  SizedBox(
                    height: 380,
                    child: TabBarView(
                      children: [
                        _buildReturnToLinemanTab(ctx),
                        _buildReceiveRepairedTab(ctx),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReturnToLinemanTab(BuildContext ctx) {
    String? selectedLinemanId = _linemen.isNotEmpty ? _linemen.first['id'] : null;
    String? selectedArticleId = _articles.isNotEmpty ? _articles.first['id'] : null;
    final qtyController = TextEditingController();
    final issueController = TextEditingController();

    return StatefulBuilder(
      builder: (context, setTabState) => SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Return to Lineman (Supervisor)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFCBD5E1))),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedLinemanId,
                  isExpanded: true,
                  items: _linemen.map((lm) => DropdownMenuItem<String>(value: lm['id'], child: Text(lm['username'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)))).toList(),
                  onChanged: (v) => setTabState(() => selectedLinemanId = v),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Article', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFCBD5E1))),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedArticleId,
                  isExpanded: true,
                  items: _articles.map((art) => DropdownMenuItem<String>(value: art['id'], child: Text(art['art_no'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)))).toList(),
                  onChanged: (v) => setTabState(() => selectedArticleId = v),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Defect Quantity to Send for Repair', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
            const SizedBox(height: 6),
            TextField(
              controller: qtyController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(hintText: 'e.g. 20 pcs', prefixIcon: const Icon(Icons.pin_rounded, size: 20), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
            ),
            const SizedBox(height: 12),
            const Text('Issue / Alteration Note', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
            const SizedBox(height: 6),
            TextField(
              controller: issueController,
              decoration: InputDecoration(hintText: 'e.g. Collar skip stitch / Pocket loose', prefixIcon: const Icon(Icons.build_rounded, size: 20), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final qty = int.tryParse(qtyController.text);
                  if (selectedLinemanId == null || selectedArticleId == null || qty == null || qty <= 0) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
                    return;
                  }
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  Navigator.pop(ctx);
                  try {
                    await supabase.from('qc_logs').insert({
                      'stage': 'MENDING',
                      'from_lineman_id': selectedLinemanId,
                      'article_id': selectedArticleId,
                      'qty_rejected': qty,
                      'mending_status': 'WITH_LINEMAN_FOR_REPAIR',
                      'remarks': issueController.text.trim().isEmpty ? 'Alteration rework' : issueController.text.trim(),
                      'entry_date': DateTime.now().toIso8601String().split('T')[0],
                    });
                    scaffoldMessenger.showSnackBar(SnackBar(content: Text('Returned $qty pcs to Lineman for repair 🔧'), backgroundColor: Colors.orange));
                    _fetchQcData();
                  } catch (e) {
                    scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
                  }
                },
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('Return Pieces to Lineman'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiveRepairedTab(BuildContext ctx) {
    if (_activeMendingList.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Text('No active batches currently in mending.\nAll pieces are clear!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, height: 1.5)),
        ),
      );
    }

    return ListView.separated(
      itemCount: _activeMendingList.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, idx) {
        final item = _activeMendingList[idx];
        final lmName = item['lineman']?['username'] ?? 'Lineman';
        final artNo = item['article']?['art_no'] ?? 'Art';
        final rejQty = item['qty_rejected'] ?? 0;
        final remarks = item['remarks'] ?? 'Mending';

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFFED7AA))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('$artNo • With $lmName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF9A3412))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Text('$rejQty pcs in repair', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('Issue: $remarks', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _promptReceiveRepaired(ctx, item),
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text('Receive Repaired Pieces'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _promptReceiveRepaired(BuildContext ctx, dynamic item) {
    final fixedController = TextEditingController(text: item['qty_rejected'].toString());
    final scrapController = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Receive Repaired Batch'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Article: ${item['article']?['art_no']} • ${item['qty_rejected']} pcs sent', style: const TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 14),
            const Text('Fixed & OK Quantity (Adds to Passed)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF047857))),
            const SizedBox(height: 4),
            TextField(controller: fixedController, keyboardType: TextInputType.number, decoration: const InputDecoration(border: OutlineInputBorder())),
            const SizedBox(height: 12),
            const Text('Scrap / Damaged Quantity ❌', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFBE123C))),
            const SizedBox(height: 4),
            TextField(controller: scrapController, keyboardType: TextInputType.number, decoration: const InputDecoration(border: OutlineInputBorder())),
          ],
        ),
        actions: [
          const ConnectivityIndicator(),
          const SizedBox(width: 4),
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final fixed = int.tryParse(fixedController.text) ?? 0;
              final scrap = int.tryParse(scrapController.text) ?? 0;
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              Navigator.pop(dCtx);
              Navigator.pop(ctx);

              try {
                await supabase.from('qc_logs').update({
                  'mending_returned_qty': fixed,
                  'mending_scrap_qty': scrap,
                  'mending_status': 'REPAIR_COMPLETED',
                }).eq('id', item['id']);

                scaffoldMessenger.showSnackBar(
                  SnackBar(content: Text('Received: $fixed Fixed (Passed), $scrap Scrap âœ…'), backgroundColor: AppTheme.successGreen),
                );
                _fetchQcData();
              } catch (e) {
                scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
              }
            },
            child: const Text('Confirm Repaired'),
          ),
        ],
      ),
    );
  }

  void _showBulkingModal() {
    String? selectedArticleId = _articles.isNotEmpty ? _articles.first['id'] : null;
    final colorController = TextEditingController(text: 'Navy Blue');
    final sizeController = TextEditingController(text: 'L');
    final bundleSizeController = TextEditingController(text: '50');
    final totalBundlesController = TextEditingController(text: '2');
    bool verifyPackaging = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final bSize = int.tryParse(bundleSizeController.text) ?? 0;
          final tBundles = int.tryParse(totalBundlesController.text) ?? 0;
          final totalPacked = bSize * tBundles;

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
                        decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(14)),
                        child: const Icon(Icons.inventory_rounded, color: Colors.purple, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Bulking & Store Transfer', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                            Text('Pack passed garments & auto-transfer to Godown', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

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

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Bundle Size (pcs/pack)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                            const SizedBox(height: 4),
                            TextField(
                              controller: bundleSizeController,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setModalState(() {}),
                              decoration: InputDecoration(hintText: '50', contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total Bundles Created', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                            const SizedBox(height: 4),
                            TextField(
                              controller: totalBundlesController,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setModalState(() {}),
                              decoration: InputDecoration(hintText: '2', contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.purple.shade200)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Packed Quantity:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple)),
                        Text('$totalPacked pcs', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.purple)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Checkbox(
                        value: verifyPackaging,
                        activeColor: Colors.purple,
                        onChanged: (v) => setModalState(() => verifyPackaging = v ?? true),
                      ),
                      const Expanded(
                        child: Text('Polybags, barcode labels & master cartons checked', style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        if (selectedArticleId == null || totalPacked <= 0) {
                          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please enter valid bundle counts.')));
                          return;
                        }

                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        Navigator.pop(ctx);
                        try {
                          final todayStr = DateTime.now().toIso8601String().split('T')[0];

                          await supabase.from('qc_logs').insert({
                            'stage': 'BULKING',
                            'article_id': selectedArticleId,
                            'color': colorController.text.trim(),
                            'size': sizeController.text.trim(),
                            'bundle_size': bSize,
                            'total_bundles': tBundles,
                            'qty_passed': totalPacked,
                            'sent_to_store': true,
                            'entry_date': todayStr,
                          });

                          await supabase.from('store_transactions').insert({
                            'type': 'INWARD',
                            'article_id': selectedArticleId,
                            'quantity': totalPacked,
                            'party_name': 'QC Finishing Handover',
                            'entry_date': todayStr,
                          });

                          scaffoldMessenger.showSnackBar(
                            SnackBar(
                              content: Text('Transferred $totalPacked pcs ($tBundles bundles) to Store Godown!'),
                              backgroundColor: AppTheme.successGreen,
                            ),
                          );
                          _fetchQcData();
                        } catch (e) {
                          scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
                        }
                      },
                      icon: const Icon(Icons.rocket_launch_rounded, size: 20),
                      label: Text('Transfer $totalPacked pcs to Store Godown'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
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
        title: const Text('Production QC'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), tooltip: 'Refresh', onPressed: _fetchQcData),
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
              onRefresh: _fetchQcData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Today's QC Summary", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                  Text('Finishing & Inspection Floor', style: TextStyle(color: Colors.white60, fontSize: 12)),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF10B981))),
                                child: Text('Pass: ${_passRate.toStringAsFixed(1)}%', style: const TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.w900, fontSize: 13)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              _buildSummaryStat('Received', '$_totalReceivedToday', Icons.move_to_inbox_rounded, Colors.blue),
                              _buildSummaryStat('Checked', '$_totalCheckedToday', Icons.fact_check_rounded, Colors.indigo),
                              _buildSummaryStat('Passed', '$_totalPassedToday', Icons.check_circle_rounded, const Color(0xFF10B981)),
                              _buildSummaryStat('Mending', '$_totalInMendingToday', Icons.build_rounded, Colors.orange),
                              _buildSummaryStat('Packed', '$_totalPackedToday', Icons.inventory_rounded, Colors.purple),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    const Text('Quick Action Modules', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                    const SizedBox(height: 12),

                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 1.2,
                      children: [
                        _buildActionCard(
                          title: 'Daily Receiving',
                          subtitle: 'Receive from Lineman',
                          icon: Icons.move_to_inbox_rounded,
                          color: const Color(0xFF2563EB),
                          bgColor: const Color(0xFFEFF6FF),
                          onTap: _showDailyReceivingModal,
                        ),
                        _buildActionCard(
                          title: 'Checking (QC)',
                          subtitle: 'Inspect & Pass/Reject',
                          icon: Icons.fact_check_rounded,
                          color: const Color(0xFF059669),
                          bgColor: const Color(0xFFECFDF5),
                          onTap: _showCheckingModal,
                        ),
                        _buildActionCard(
                          title: 'Mending & Repair',
                          subtitle: 'Return to Lineman',
                          icon: Icons.build_rounded,
                          color: const Color(0xFFD97706),
                          bgColor: const Color(0xFFFFFBEB),
                          badge: _totalInMendingToday > 0 ? '$_totalInMendingToday pcs' : null,
                          onTap: _showMendingModal,
                        ),
                        _buildActionCard(
                          title: 'Bulking & Packing',
                          subtitle: 'Pack & Send to Store',
                          icon: Icons.inventory_rounded,
                          color: const Color(0xFF7C3AED),
                          bgColor: const Color(0xFFF5F3FF),
                          onTap: _showBulkingModal,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Recent QC Activity Feed', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                        Text('${_recentQcLogs.length} logs', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (_recentQcLogs.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE2E8F0))),
                        child: const Center(
                          child: Text('No QC inspections logged yet today.\nTap one of the action cards above to begin.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, height: 1.5)),
                        ),
                      )
                    else
                      ..._recentQcLogs.map((log) => _buildLogCard(log)),

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
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
    String? badge,
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
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(14)),
                  child: Icon(icon, color: color, size: 22),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(8)),
                    child: Text(badge, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange.shade900)),
                  ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textDark)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogCard(dynamic log) {
    final stage = log['stage'] as String? ?? 'QC';
    final artNo = log['article']?['art_no'] ?? '-';
    final lmName = log['lineman']?['username'] ?? '';
    final color = log['color'] as String? ?? '';
    final size = log['size'] as String? ?? '';
    final hasVariant = color.isNotEmpty || size.isNotEmpty;
    final variantStr = hasVariant ? ' â€¢ $color ($size)' : '';
    final timeStr = log['created_at'] != null ? DateTime.parse(log['created_at']).toLocal().toString().substring(11, 16) : '-';

    Color badgeColor = Colors.blue;
    String badgeText = stage;
    String mainDetails = '';

    if (stage == 'RECEIVING') {
      badgeColor = const Color(0xFF2563EB);
      badgeText = 'ðŸ“¥ Received';
      mainDetails = 'Received ${log['qty_received']} pcs from $lmName';
    } else if (stage == 'CHECKING') {
      badgeColor = const Color(0xFF059669);
      badgeText = 'Checked';
      final p = log['qty_passed'] ?? 0;
      final r = log['qty_rejected'] ?? 0;
      mainDetails = '$p Passed • $r Defect (${log['defect_type'] ?? 'NONE'})';
    } else if (stage == 'MENDING') {
      badgeColor = Colors.orange;
      badgeText = 'Mending';
      final status = log['mending_status'] ?? '';
      if (status == 'REPAIR_COMPLETED') {
        mainDetails = 'Repaired: ${log['mending_returned_qty']} fixed & added to passed';
      } else {
        mainDetails = 'Sent ${log['qty_rejected']} pcs to $lmName for repair';
      }
    } else if (stage == 'BULKING') {
      badgeColor = Colors.purple;
      badgeText = 'Packed to Store';
      final bSize = log['bundle_size'] ?? 0;
      final tBundles = log['total_bundles'] ?? 0;
      mainDetails = 'Packed ${bSize * tBundles} pcs ($tBundles bundles x $bSize pcs) to Godown';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2))],
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
                      decoration: BoxDecoration(color: badgeColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text(badgeText, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: badgeColor)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('$artNo$variantStr', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.textDark), overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(mainDetails, style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
                if (log['remarks'] != null && (log['remarks'] as String).isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text('Note: ${log['remarks']}', style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontStyle: FontStyle.italic)),
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