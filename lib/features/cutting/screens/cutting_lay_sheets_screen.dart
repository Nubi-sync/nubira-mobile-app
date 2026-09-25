import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/widgets/zigza_app_bar.dart';
import '../../modules/screens/enterprise_workspace_hub_screen.dart';
import '../../modules/widgets/workspace_hub_drawer.dart';
import '../models/cutting_models.dart';
import '../providers/cutting_provider.dart';

class CuttingLaySheetsScreen extends ConsumerStatefulWidget {
  const CuttingLaySheetsScreen({super.key});

  @override
  ConsumerState<CuttingLaySheetsScreen> createState() => _CuttingLaySheetsScreenState();
}

class _CuttingLaySheetsScreenState extends ConsumerState<CuttingLaySheetsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String _statusFilter = 'ALL';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openCreateLaySheetModal() {
    final layNumCtrl = TextEditingController(text: 'LAY-${DateTime.now().year}-${(DateTime.now().millisecondsSinceEpoch % 9000 + 1000)}');
    final buyerCtrl = TextEditingController(text: 'ZARA INTERNATIONAL');
    final poCtrl = TextEditingController(text: 'PO-2026-9901');
    final styleCtrl = TextEditingController(text: 'TP-2026-8801');
    final tableCtrl = TextEditingController(text: 'Table 01 - Gerber Auto-Cutter');
    final pliesCtrl = TextEditingController(text: '84');
    final lengthCtrl = TextEditingController(text: '5.4');
    final ratioCtrl = TextEditingController(text: 'S:1, M:2, L:2, XL:1 (Ratio: 6)');
    final totalPiecesCtrl = TextEditingController(text: '1000');

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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Create New Spreading Lay Sheet',
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
                controller: layNumCtrl,
                decoration: InputDecoration(
                  labelText: 'Lay Sheet Number',
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
                        labelText: 'Buyer / Brand',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: poCtrl,
                      decoration: InputDecoration(
                        labelText: 'PO Number',
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
                  labelText: 'Cutting Table & Vacuum Setup',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: pliesCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Total Plies Count',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: lengthCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Marker Length (Meters)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: ratioCtrl,
                decoration: InputDecoration(
                  labelText: 'Size Ratio Breakdown',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: totalPiecesCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Total Cut Pieces Expected',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
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
                    final plies = int.tryParse(pliesCtrl.text.trim()) ?? 80;
                    final len = double.tryParse(lengthCtrl.text.trim()) ?? 5.4;
                    final totalPcs = int.tryParse(totalPiecesCtrl.text.trim()) ?? 1000;

                    final newLay = LaySheet(
                      id: 'lay-${DateTime.now().millisecondsSinceEpoch}',
                      layNumber: layNumCtrl.text.trim(),
                      poNumber: poCtrl.text.trim(),
                      brandName: buyerCtrl.text.trim(),
                      styleRef: styleCtrl.text.trim(),
                      styleName: 'Garment Style Lot',
                      tableNumber: tableCtrl.text.trim(),
                      fabricRollBarcodes: ['ROL-2026-9901'],
                      shellFabric: '100% Combed Cotton French Terry 380 GSM',
                      gsm: 380,
                      pliesCount: plies,
                      markerLengthMeters: len,
                      totalCutPieces: totalPcs,
                      ratioBreakdown: ratioCtrl.text.trim(),
                      fabricWeightKg: 450.0,
                      cuttingMaster: 'Cutting Master',
                      status: 'SPREADING',
                      createdAt: DateTime.now().toIso8601String().split('T')[0],
                    );

                    ref.read(cuttingProvider.notifier).addLaySheet(newLay);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Lay sheet generated and queued for spreading.')),
                    );
                  },
                  child: Text(
                    'Confirm & Queue Lay Sheet',
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
    );
  }

  void _showLayDetailSheet(LaySheet lay) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lay.layNumber,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF3A3564),
                      ),
                    ),
                    Text(
                      '${lay.poNumber} • ${lay.brandName}',
                      style: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            _buildDetailRow('Assigned Table', lay.tableNumber),
            _buildDetailRow('Plies Count', '${lay.pliesCount} Plies'),
            _buildDetailRow('Marker Length', '${lay.markerLengthMeters} meters'),
            _buildDetailRow('Size Ratio', lay.ratioBreakdown),
            _buildDetailRow('Total Pieces', '${lay.totalCutPieces} pcs'),
            _buildDetailRow('Shell Fabric', lay.shellFabric),
            _buildDetailRow('Roll Barcodes', lay.fabricRollBarcodes.join(', ')),
            _buildDetailRow('Cutting Master', lay.cuttingMaster),
            _buildDetailRow('Status', lay.status),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Bundles generated for ${lay.layNumber}')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3A3564),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                label: Text(
                  'Generate Serialized Bundle QR Tickets',
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.publicSans(fontSize: 12.5, color: const Color(0xFF64748B))),
          Text(value, style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cuttingState = ref.watch(cuttingProvider);
    final lays = cuttingState.laySheets;

    final query = _searchCtrl.text.trim().toLowerCase();
    final filteredLays = lays.where((l) {
      final matchesSearch = query.isEmpty ||
          l.layNumber.toLowerCase().contains(query) ||
          l.poNumber.toLowerCase().contains(query) ||
          l.brandName.toLowerCase().contains(query) ||
          l.styleRef.toLowerCase().contains(query);
      final matchesStatus = _statusFilter == 'ALL' || l.status == _statusFilter;
      return matchesSearch && matchesStatus;
    }).toList();

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFFAF7F0),
      drawer: const WorkspaceHubDrawer(activeRoute: '/cutting/lay-sheets'),
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
                            child: const Icon(Icons.layers_outlined, color: Color(0xFF3A3564), size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Spreading & Lay Plans',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF3A3564),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Multi-ply fabric spreading sheets, CAD ratios, table allocations, and component lot serialization',
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
                          onPressed: _openCreateLaySheetModal,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3A3564),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: Text(
                            'Create Lay Sheet',
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
                    hintText: 'Search lay number, PO, brand...',
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

                // Status Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildChip('ALL', 'All (${lays.length})'),
                      const SizedBox(width: 8),
                      _buildChip('SPREADING', 'Spreading'),
                      const SizedBox(width: 8),
                      _buildChip('READY_FOR_CUT', 'Ready For Cut'),
                      const SizedBox(width: 8),
                      _buildChip('CUT_COMPLETED', 'Cut Completed'),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Lay Sheets List
                if (filteredLays.isEmpty)
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
                          Icon(Icons.layers_clear_outlined, size: 40, color: Colors.grey.shade400),
                          const SizedBox(height: 10),
                          Text(
                            'No lay sheets found',
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
                    itemCount: filteredLays.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, index) {
                      final lay = filteredLays[index];
                      return _buildLayCard(lay);
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

  Widget _buildLayCard(LaySheet lay) {
    return InkWell(
      onTap: () => _showLayDetailSheet(lay),
      borderRadius: BorderRadius.circular(16),
      child: Container(
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
                    lay.layNumber,
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
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Text(
                    lay.status,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF16A34A),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${lay.poNumber} • ${lay.brandName}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              lay.styleName,
              style: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '${lay.pliesCount} plies • ${lay.markerLengthMeters}m',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF3A3564),
                  ),
                ),
                const Spacer(),
                Text(
                  '${lay.totalCutPieces} pcs cut',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF059669),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Ratio: ${lay.ratioBreakdown}',
              style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF475569)),
            ),
          ],
        ),
      ),
    );
  }
}
