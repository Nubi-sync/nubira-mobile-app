import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/widgets/zigza_app_bar.dart';
import '../../modules/screens/enterprise_workspace_hub_screen.dart';
import '../../modules/widgets/workspace_hub_drawer.dart';
import '../models/cutting_models.dart';
import '../providers/cutting_provider.dart';

class CuttingOrdersQueueScreen extends ConsumerStatefulWidget {
  const CuttingOrdersQueueScreen({super.key});

  @override
  ConsumerState<CuttingOrdersQueueScreen> createState() => _CuttingOrdersQueueScreenState();
}

class _CuttingOrdersQueueScreenState extends ConsumerState<CuttingOrdersQueueScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String _statusFilter = 'ALL';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openCreateOrderModal() {
    final orderNumCtrl = TextEditingController(text: 'CO-${DateTime.now().year}-${(DateTime.now().millisecondsSinceEpoch % 9000 + 1000)}');
    final buyerCtrl = TextEditingController(text: 'ZARA INTERNATIONAL');
    final poCtrl = TextEditingController(text: 'PO-2026-9901');
    final styleCtrl = TextEditingController(text: 'TP-2026-8801');
    final colorwayCtrl = TextEditingController(text: 'Orange & Green');
    final piecesCtrl = TextEditingController(text: '1000');
    final pliesCtrl = TextEditingController(text: '84');
    final metersCtrl = TextEditingController(text: '900');
    final tableCtrl = TextEditingController(text: 'Table 01 - Gerber Paragon HX');
    String priority = 'HIGH';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Queue New Cutting Order',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF3A3564),
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 8),
                TextField(
                  controller: orderNumCtrl,
                  decoration: InputDecoration(
                    labelText: 'Cutting Order Number',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: buyerCtrl,
                        decoration: InputDecoration(
                          labelText: 'Buyer Name',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: poCtrl,
                        decoration: InputDecoration(
                          labelText: 'Buyer PO',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: styleCtrl,
                        decoration: InputDecoration(
                          labelText: 'Style Ref',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: colorwayCtrl,
                        decoration: InputDecoration(
                          labelText: 'Colorway',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: piecesCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Total Pieces',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: pliesCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Plies Planned',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: tableCtrl,
                  decoration: InputDecoration(
                    labelText: 'Table Assigned',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: priority,
                  decoration: InputDecoration(
                    labelText: 'Priority Level',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'NORMAL', child: Text('Normal Priority')),
                    DropdownMenuItem(value: 'HIGH', child: Text('High Priority')),
                    DropdownMenuItem(value: 'URGENT', child: Text('Urgent Ex-Factory')),
                  ],
                  onChanged: (v) => setMState(() => priority = v ?? 'HIGH'),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3A3564),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      final pcs = int.tryParse(piecesCtrl.text.trim()) ?? 1000;
                      final plies = int.tryParse(pliesCtrl.text.trim()) ?? 80;
                      final meters = double.tryParse(metersCtrl.text.trim()) ?? 900.0;

                      final newOrder = CuttingOrder(
                        id: 'co-${DateTime.now().millisecondsSinceEpoch}',
                        orderNumber: orderNumCtrl.text.trim(),
                        buyerPo: poCtrl.text.trim(),
                        buyerName: buyerCtrl.text.trim(),
                        styleNumber: styleCtrl.text.trim(),
                        styleName: 'Production Lot',
                        colorway: colorwayCtrl.text.trim(),
                        totalPieces: pcs,
                        pliesPlanned: plies,
                        fabricMetersAllocated: meters,
                        tableAssigned: tableCtrl.text.trim(),
                        status: 'QUEUED',
                        priority: priority,
                        scheduledStart: '${DateTime.now().toIso8601String().split('T')[0]} 08:00',
                        operatorLead: 'Cutting Master',
                        createdAt: DateTime.now().toIso8601String().split('T')[0],
                      );

                      ref.read(cuttingProvider.notifier).addCuttingOrder(newOrder);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Cutting order added to queue.')),
                      );
                    },
                    child: Text(
                      'Confirm & Push to Floor Queue',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
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
    final cuttingState = ref.watch(cuttingProvider);
    final orders = cuttingState.cuttingOrders;

    final query = _searchCtrl.text.trim().toLowerCase();
    final filteredOrders = orders.where((o) {
      final matchesSearch = query.isEmpty ||
          o.orderNumber.toLowerCase().contains(query) ||
          o.buyerPo.toLowerCase().contains(query) ||
          o.buyerName.toLowerCase().contains(query) ||
          o.styleNumber.toLowerCase().contains(query);
      final matchesStatus = _statusFilter == 'ALL' || o.status == _statusFilter;
      return matchesSearch && matchesStatus;
    }).toList();

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFFAF7F0),
      drawer: const WorkspaceHubDrawer(activeRoute: '/cutting/orders'),
      appBar: ZigzaAppBar(
        onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
        trailing: IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Color(0xFF3A3564)),
          onPressed: () => ref.read(cuttingProvider.notifier).fetchCuttingData(),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF3A3564),
          onRefresh: () => ref.read(cuttingProvider.notifier).fetchCuttingData(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Navigation Back Row
                InkWell(
                  onTap: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const EnterpriseWorkspaceHubScreen()),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_back_rounded, size: 14, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Text(
                        'Workspace hub / 03 - Cutting floor',
                        style: GoogleFonts.publicSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Header Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
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
                              color: const Color(0xFFFAF7F0),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                            ),
                            child: const Icon(Icons.memory_rounded, color: Color(0xFF3A3564), size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Cutting Orders & Queue',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF3A3564),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Master cutter job queue, automated blade dispatch, table prioritization, and ex-factory milestones',
                                  style: GoogleFonts.publicSans(
                                    fontSize: 12,
                                    color: const Color(0xFF64748B),
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Action Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _openCreateOrderModal,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3A3564),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: Text(
                            'Queue Cutting Order',
                            style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Search Bar
                TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search order number, PO, buyer...',
                    hintStyle: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Status Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildChip('ALL', 'All (${orders.length})'),
                      const SizedBox(width: 8),
                      _buildChip('QUEUED', 'Queued'),
                      const SizedBox(width: 8),
                      _buildChip('SPREADING', 'Spreading'),
                      const SizedBox(width: 8),
                      _buildChip('CUTTING', 'Cutting'),
                      const SizedBox(width: 8),
                      _buildChip('BUNDLED', 'Bundled'),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Orders List
                if (filteredOrders.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.assignment_late_outlined, size: 40, color: Colors.grey.shade400),
                          const SizedBox(height: 10),
                          Text(
                            'No cutting orders found',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredOrders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, index) {
                      final o = filteredOrders[index];
                      return _buildOrderCard(o);
                    },
                  ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChip(String id, String label) {
    final isSelected = _statusFilter == id;
    return InkWell(
      onTap: () => setState(() => _statusFilter = id),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3A3564) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF3A3564) : Colors.black.withValues(alpha: 0.1),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.publicSans(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(CuttingOrder o) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF7F0),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                ),
                child: Text(
                  o.orderNumber,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF3A3564),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: o.priority == 'URGENT' ? const Color(0xFFFFE4E6) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: o.priority == 'URGENT' ? const Color(0xFFFDA4AF) : const Color(0xFFBFDBFE),
                  ),
                ),
                child: Text(
                  '${o.priority} PRIORITY',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: o.priority == 'URGENT' ? const Color(0xFFE11D48) : const Color(0xFF1D4ED8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${o.buyerPo} • ${o.buyerName}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${o.styleNumber} • Color: ${o.colorway}',
            style: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF64748B)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${o.totalPieces} pcs • ${o.pliesPlanned} plies',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF3A3564),
                ),
              ),
              const Spacer(),
              Text(
                o.tableAssigned,
                style: GoogleFonts.publicSans(fontSize: 11, color: const Color(0xFF475569)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'STATUS: ${o.status}',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF334155),
                  ),
                ),
              ),
              OutlinedButton(
                onPressed: () => ref.read(cuttingProvider.notifier).advanceOrderStatus(o.id),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF3A3564),
                  side: BorderSide(color: Colors.black.withValues(alpha: 0.15)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                  'Advance Status ->',
                  style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
