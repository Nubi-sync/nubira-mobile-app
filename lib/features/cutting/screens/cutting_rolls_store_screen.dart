import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/widgets/zigza_app_bar.dart';
import '../../modules/screens/enterprise_workspace_hub_screen.dart';
import '../../modules/widgets/workspace_hub_drawer.dart';
import '../models/cutting_models.dart';
import '../providers/cutting_provider.dart';

class CuttingRollsStoreScreen extends ConsumerStatefulWidget {
  const CuttingRollsStoreScreen({super.key});

  @override
  ConsumerState<CuttingRollsStoreScreen> createState() => _CuttingRollsStoreScreenState();
}

class _CuttingRollsStoreScreenState extends ConsumerState<CuttingRollsStoreScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String _activeTab = 'RECEIPTS'; // 'RECEIPTS', 'ISSUES', 'PENDING'
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openCreateIssueModal() {
    final buyerCtrl = TextEditingController(text: 'ZARA INTERNATIONAL');
    final articleCtrl = TextEditingController(text: 'TP-2026-8801');
    final fabricCtrl = TextEditingController(text: '100% Combed Cotton French Terry');
    final colorCtrl = TextEditingController(text: 'Orange');
    final qtyCtrl = TextEditingController(text: '150');
    final rollsCtrl = TextEditingController(text: '1');
    String destination = '06_SEWING';

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Issue Fabric / Remnant Challan',
                    style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF3A3564)),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: destination,
                decoration: InputDecoration(
                  labelText: 'Target Division / Line',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: const [
                  DropdownMenuItem(value: '04_PRINTING', child: Text('04 - Printing Division')),
                  DropdownMenuItem(value: '05_EMBROIDERY', child: Text('05 - Embroidery Division')),
                  DropdownMenuItem(value: '06_SEWING', child: Text('06 - Sewing Line (Cut Panels)')),
                  DropdownMenuItem(value: 'CENTRAL_STORE', child: Text('Central Store (Remnants Return)')),
                ],
                onChanged: (v) => setMState(() => destination = v ?? '06_SEWING'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: articleCtrl,
                decoration: InputDecoration(
                  labelText: 'Article Number',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: fabricCtrl,
                decoration: InputDecoration(
                  labelText: 'Fabric Description',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: qtyCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Quantity (Meters)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: rollsCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Rolls / Bundles',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
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
                    final qty = double.tryParse(qtyCtrl.text.trim()) ?? 0;
                    final rCount = int.tryParse(rollsCtrl.text.trim()) ?? 1;
                    if (qty <= 0) return;
                    ref.read(cuttingProvider.notifier).createStoreIssueChallan(
                          targetDivision: destination,
                          articleNumber: articleCtrl.text.trim(),
                          buyerName: buyerCtrl.text.trim(),
                          fabricType: fabricCtrl.text.trim(),
                          color: colorCtrl.text.trim(),
                          quantity: qty,
                          unit: 'meters',
                          rollsCount: rCount,
                        );
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Fabric issue challan generated successfully.')),
                    );
                  },
                  child: Text('Create Issue Challan', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openAcknowledgeModal(StoreChallanRecord challan) {
    final qtyCtrl = TextEditingController(text: challan.quantity.toStringAsFixed(0));
    final shortageCtrl = TextEditingController(text: '0');
    final receiverCtrl = TextEditingController(text: 'Cutting Master');
    final rackCtrl = TextEditingController(text: 'RACK-CUT-01');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Acknowledge Material Receipt',
                  style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF3A3564)),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'Challan ${challan.challanNumber} • ${challan.fabricType} (${challan.color})',
              style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: qtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Received Qty (Meters)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: shortageCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Shortage (Meters)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: rackCtrl,
              decoration: InputDecoration(
                labelText: 'Floor Storage Rack / Bin',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  final recv = double.tryParse(qtyCtrl.text.trim()) ?? challan.quantity;
                  final short = double.tryParse(shortageCtrl.text.trim()) ?? 0;
                  ref.read(cuttingProvider.notifier).acknowledgeStoreReceipt(
                        challanId: challan.id,
                        receivedQty: recv,
                        shortageQty: short,
                        receiverName: receiverCtrl.text.trim(),
                        rackLocation: rackCtrl.text.trim(),
                      );
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Challan acknowledged and added to floor stock.')),
                  );
                },
                child: Text('Confirm Receipt', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cuttingState = ref.watch(cuttingProvider);
    final challans = cuttingState.storeChallans;

    final receipts = challans.where((c) => c.status == 'RECEIVED').toList();
    final issues = challans.where((c) => c.status == 'ISSUED').toList();
    final pending = challans.where((c) => c.status == 'PENDING').toList();

    final totalReceived = receipts.fold<double>(0, (s, c) => s + c.quantity);
    final totalIssued = issues.fold<double>(0, (s, c) => s + c.quantity);

    List<StoreChallanRecord> displayList;
    if (_activeTab == 'RECEIPTS') {
      displayList = receipts;
    } else if (_activeTab == 'ISSUES') {
      displayList = issues;
    } else {
      displayList = pending;
    }

    final query = _searchCtrl.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      displayList = displayList.where((c) =>
          c.challanNumber.toLowerCase().contains(query) ||
          c.articleNumber.toLowerCase().contains(query) ||
          c.buyerName.toLowerCase().contains(query) ||
          c.fabricType.toLowerCase().contains(query)).toList();
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFFAF7F0),
      drawer: const WorkspaceHubDrawer(activeRoute: '/cutting/store'),
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
                            child: const Icon(Icons.storefront_outlined, color: Color(0xFF3A3564), size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Floor Store (Fabric Rolls)',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF3A3564),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Material receipts from Central Store, roll barcode tracking, line issues, and remnant inventory',
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
                      const SizedBox(height: 16),

                      // KPI Cards Row
                      Row(
                        children: [
                          Expanded(
                            child: _buildKpiTile('Total Received', '${totalReceived.toInt()} m', const Color(0xFF059669)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildKpiTile('Issued to Line', '${totalIssued.toInt()} m', const Color(0xFF0284C7)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildKpiTile('Pending Challans', '${pending.length}', const Color(0xFFD97706)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Action Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _openCreateIssueModal,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3A3564),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: Text(
                            'Issue Fabric / Remnant Challan',
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
                    hintText: 'Search challan, article, buyer, fabric...',
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

                // Tab Bar
                Row(
                  children: [
                    Expanded(
                      child: _buildFilterTab('RECEIPTS', 'Receipts (${receipts.length})'),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildFilterTab('ISSUES', 'Issues (${issues.length})'),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildFilterTab('PENDING', 'Pending (${pending.length})'),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Challans List
                if (displayList.isEmpty)
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
                          Icon(Icons.inventory_2_outlined, size: 40, color: Colors.grey.shade400),
                          const SizedBox(height: 10),
                          Text(
                            'No material challans found',
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
                    itemCount: displayList.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, index) {
                      final c = displayList[index];
                      return _buildChallanCard(c);
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

  Widget _buildKpiTile(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.publicSans(fontSize: 11, color: const Color(0xFF64748B)),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String id, String label) {
    final isSelected = _activeTab == id;
    return InkWell(
      onTap: () => setState(() => _activeTab = id),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3A3564) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF3A3564) : Colors.black.withValues(alpha: 0.08),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.publicSans(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected ? Colors.white : const Color(0xFF475569),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChallanCard(StoreChallanRecord c) {
    final isPending = c.status == 'PENDING';
    final isReceived = c.status == 'RECEIVED';

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
                  c.challanNumber,
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
                  color: isReceived
                      ? const Color(0xFFECFDF5)
                      : (isPending ? const Color(0xFFFFFBEB) : const Color(0xFFF0F9FF)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isReceived
                        ? const Color(0xFFA7F3D0)
                        : (isPending ? const Color(0xFFFDE68A) : const Color(0xFFBAE6FD)),
                  ),
                ),
                child: Text(
                  c.status,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isReceived
                        ? const Color(0xFF047857)
                        : (isPending ? const Color(0xFFB45309) : const Color(0xFF0369A1)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${c.articleNumber} • ${c.buyerName}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${c.fabricType} • Color: ${c.color}',
            style: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF475569)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${c.quantity.toInt()} ${c.unit} (${c.rollsCount} rolls)',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF3A3564),
                ),
              ),
              const Spacer(),
              Text(
                c.rackLocation.isNotEmpty ? 'Location: ${c.rackLocation}' : 'From: ${c.fromDivision}',
                style: GoogleFonts.publicSans(fontSize: 11, color: const Color(0xFF64748B)),
              ),
            ],
          ),
          if (isPending) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openAcknowledgeModal(c),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                icon: const Icon(Icons.check_circle_outline, size: 16),
                label: Text(
                  'Acknowledge & Receive',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
