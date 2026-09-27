import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/widgets/zigza_app_bar.dart';
import '../../modules/widgets/workspace_hub_drawer.dart';
import '../models/ready_goods_models.dart';
import '../providers/ready_goods_provider.dart';
import '../widgets/ready_goods_worker_list_modal.dart';
import '../widgets/inward_inspection_lot_modal.dart';
import '../widgets/record_inspection_modal.dart';
import '../widgets/carton_packing_modal.dart';
import '../widgets/aql_audit_modal.dart';

class QualityClinicFloorScreen extends ConsumerStatefulWidget {
  const QualityClinicFloorScreen({super.key});

  @override
  ConsumerState<QualityClinicFloorScreen> createState() => _QualityClinicFloorScreenState();
}

class _QualityClinicFloorScreenState extends ConsumerState<QualityClinicFloorScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showBuyerSelectionSheet(BuildContext context, ReadyGoodsState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final filtered = state.buyers.where((b) {
              if (query.isEmpty) return true;
              return b.buyerName.toLowerCase().contains(query.toLowerCase()) ||
                  b.linkedArticleNumber.toLowerCase().contains(query.toLowerCase());
            }).toList();

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.75,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF7F0),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                    ),
                    child: TextField(
                      onChanged: (v) => setSheetState(() => query = v.trim()),
                      style: GoogleFonts.publicSans(fontSize: 12.5),
                      decoration: const InputDecoration(
                        hintText: 'Search buyers or PO numbers...',
                        hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        prefixIcon: Icon(Icons.search, size: 17, color: Color(0xFF94A3B8)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildBuyerOption(
                            isSelected: state.selectedBuyerId == 'ALL',
                            title: 'All Buyers & Export Orders',
                            subtitle: 'Show all ${state.tasks.length} inspection lots across factory',
                            onTap: () {
                              ref.read(readyGoodsProvider.notifier).selectBuyer('ALL');
                              Navigator.pop(ctx);
                            },
                          ),
                          ...filtered.map((b) {
                            final isSelected = state.selectedBuyerId == b.buyerName;
                            return _buildBuyerOption(
                              isSelected: isSelected,
                              title: b.buyerName,
                              subtitle: '${b.linkedArticleNumber} • ${b.linkedArticleName} (${b.contractedVolume} pcs)',
                              onTap: () {
                                ref.read(readyGoodsProvider.notifier).selectBuyer(b.buyerName);
                                Navigator.pop(ctx);
                              },
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBuyerOption({
    required bool isSelected,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3A3564).withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: const Color(0xFF3A3564).withValues(alpha: 0.25)) : null,
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF3A3564) : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.business_rounded,
                size: 16,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? const Color(0xFF3A3564) : const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.publicSans(fontSize: 11, color: const Color(0xFF64748B)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF3A3564)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(readyGoodsProvider);
    final filteredTasks = state.filteredTasks;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFFAF7F0), // Warm cream canvas
      drawer: const WorkspaceHubDrawer(),
      appBar: ZigzaAppBar(
        onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 2. Encapsulated Floor Header Card
            _buildFloorHeaderCard(state),

            // 3. Main Content
            Expanded(
              child: RefreshIndicator(
                color: const Color(0xFF3A3564),
                onRefresh: () => ref.read(readyGoodsProvider.notifier).fetchData(),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 4. Hero KPI Summary Strip
                      _buildHeroKpiStrip(state),
                      const SizedBox(height: 14),

                      // 5. Filter Pill Tabs
                      _buildFilterTabs(state),
                      const SizedBox(height: 12),

                      // 6. Search Bar
                      Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                        ),
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (v) => ref.read(readyGoodsProvider.notifier).setSearchQuery(v.trim()),
                          style: GoogleFonts.publicSans(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Search lots, styles, orders or buyers...',
                            hintStyle: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF94A3B8)),
                            prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                            suffixIcon: _searchCtrl.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      ref.read(readyGoodsProvider.notifier).setSearchQuery('');
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 11),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 7. Cartons View or Tasks View
                      if (state.statusFilter == 'CARTONS')
                        _buildCartonsSection(state)
                      else if (filteredTasks.isEmpty)
                        _buildEmptyState()
                      else
                        ...filteredTasks.map((t) => _buildInspectionTaskCard(t)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ENCAPSULATED FLOOR HEADER CARD
  Widget _buildFloorHeaderCard(ReadyGoodsState state) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0x1A000000)),
                ),
                child: const Icon(Icons.all_inbox_rounded, color: Color(0xFF3A3564), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quality Clinic & Export Packing',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Post-wash/iron inspection, alteration clinic & carton packing',
                      style: GoogleFonts.publicSans(fontSize: 11, color: const Color(0xFF64748B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF047857), shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text('Live Floor', style: GoogleFonts.publicSans(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF047857))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Buyer Dropdown Pill + Action Buttons
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Buyer Dropdown Pill
                InkWell(
                  onTap: () => _showBuyerSelectionSheet(context, state),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF7F0),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.black.withValues(alpha: 0.12)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.business_rounded, size: 14, color: Color(0xFF3A3564)),
                        const SizedBox(width: 6),
                        Text(
                          state.selectedBuyerId == 'ALL' ? 'All Buyers' : state.selectedBuyerId,
                          style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down, size: 15, color: Color(0xFF64748B)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Inward Lot Button
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('Inward Lot', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3A3564),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const InwardInspectionLotModal(),
                    );
                  },
                ),
                const SizedBox(width: 6),

                // Workers Button
                OutlinedButton.icon(
                  icon: const Icon(Icons.people_outline, size: 14),
                  label: Text('Workers (${state.workers.length})', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF3A3564),
                    side: BorderSide(color: const Color(0xFF3A3564).withValues(alpha: 0.3)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const ReadyGoodsWorkerListModal(),
                    );
                  },
                ),
                const SizedBox(width: 6),

                // Pack Carton Button
                OutlinedButton.icon(
                  icon: const Icon(Icons.inventory_2_outlined, size: 14),
                  label: const Text('Pack Carton', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF047857),
                    side: const BorderSide(color: Color(0xFFA7F3D0)),
                    backgroundColor: const Color(0xFFECFDF5),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const CartonPackingModal(),
                    );
                  },
                ),
                const SizedBox(width: 6),

                // AQL Audit Button
                OutlinedButton.icon(
                  icon: const Icon(Icons.verified_outlined, size: 14),
                  label: const Text('AQL Audit', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFD97706),
                    side: const BorderSide(color: Color(0xFFFDE68A)),
                    backgroundColor: const Color(0xFFFFFBEB),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const AqlAuditModal(),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // HERO KPI SUMMARY STRIP
  Widget _buildHeroKpiStrip(ReadyGoodsState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF3A3564),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: const Color(0xFF3A3564).withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quality & Packing Shift Pulse',
                    style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${state.totalPieces} total pcs in flow • Alteration clinic active',
                    style: GoogleFonts.publicSans(fontSize: 11, color: Colors.white.withValues(alpha: 0.7)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'AQL PASS: ${state.clearanceRate.toStringAsFixed(0)}%',
                  style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF86EFAC)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildKpiItem('TOTAL LOTS', state.tasks.length.toString(), Icons.layers_outlined, Colors.white),
              _buildKpiDivider(),
              _buildKpiItem('IN CHECK', state.inCheckingCount.toString(), Icons.search_rounded, const Color(0xFF93C5FD)),
              _buildKpiDivider(),
              _buildKpiItem('ALTERATION', state.alterationCount.toString(), Icons.build_rounded, const Color(0xFFFCD34D)),
              _buildKpiDivider(),
              _buildKpiItem('CARTONS', state.packedCount.toString(), Icons.inventory_2_outlined, const Color(0xFF86EFAC)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 16, color: color.withValues(alpha: 0.8)),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.jetBrainsMono(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.publicSans(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.6))),
      ],
    );
  }

  Widget _buildKpiDivider() {
    return Container(width: 1, height: 28, color: Colors.white.withValues(alpha: 0.15));
  }

  // FILTER PILL TABS
  Widget _buildFilterTabs(ReadyGoodsState state) {
    final tabs = [
      {'key': 'ALL', 'label': 'All Lots', 'count': state.tasks.length},
      {'key': 'PENDING', 'label': 'Pending', 'count': state.tasks.where((t) => t.status == 'PENDING_CHECK').length},
      {'key': 'ALTERATION', 'label': 'Alteration Clinic', 'count': state.alterationCount},
      {'key': 'PASSED', 'label': 'Passed & Ready', 'count': state.passedCount},
      {'key': 'CARTONS', 'label': 'Cartons & Pallets', 'count': state.cartons.length},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs.map((tab) {
          final isSelected = state.statusFilter == tab['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => ref.read(readyGoodsProvider.notifier).setStatusFilter(tab['key'] as String),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF3A3564) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isSelected ? const Color(0xFF3A3564) : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Text(
                      tab['label'] as String,
                      style: GoogleFonts.publicSans(
                        fontSize: 11.5,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected ? Colors.white : const Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${tab['count']}',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // INSPECTION TASK CARD
  Widget _buildInspectionTaskCard(FinishingInspectionTask task) {
    Color badgeBg;
    Color badgeText;
    String statusLabel;
    IconData statusIcon;

    switch (task.status) {
      case 'PENDING_CHECK':
        badgeBg = const Color(0xFFF1F5F9);
        badgeText = const Color(0xFF475569);
        statusLabel = 'Pending Check';
        statusIcon = Icons.hourglass_top_rounded;
        break;
      case 'IN_CHECKING':
        badgeBg = const Color(0xFFEFF6FF);
        badgeText = const Color(0xFF1D4ED8);
        statusLabel = 'In Checking';
        statusIcon = Icons.search_rounded;
        break;
      case 'REJECTED_TO_ALTERATION':
        badgeBg = const Color(0xFFFFFBEB);
        badgeText = const Color(0xFFB45309);
        statusLabel = 'Alteration Clinic';
        statusIcon = Icons.build_rounded;
        break;
      case 'PASSED_TO_PACKING':
        badgeBg = const Color(0xFFF0FDF4);
        badgeText = const Color(0xFF15803D);
        statusLabel = 'Passed to Packing';
        statusIcon = Icons.check_circle_rounded;
        break;
      default:
        badgeBg = const Color(0xFFF1F5F9);
        badgeText = const Color(0xFF475569);
        statusLabel = task.status;
        statusIcon = Icons.info_outline;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Lot #, Stage badge, and Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF7F0),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                    ),
                    child: Text(
                      task.lotNumber,
                      style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF3A3564)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      task.stage.replaceAll('_', ' '),
                      style: GoogleFonts.publicSans(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: badgeText.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(statusIcon, size: 12, color: badgeText),
                    const SizedBox(width: 4),
                    Text(statusLabel, style: GoogleFonts.publicSans(fontSize: 10.5, fontWeight: FontWeight.bold, color: badgeText)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Row 2: Style & Buyer
          Text(
            '${task.styleName} • ${task.buyer}',
            style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
          ),
          const SizedBox(height: 2),
          Text(
            'Order: ${task.orderNumber} • Color: ${task.color} • Priority: ${task.priority}',
            style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF64748B)),
          ),
          const SizedBox(height: 10),

          // Row 3: Metrics strip (Total vs Passed vs Alteration)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TOTAL PCS', style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8))),
                      Text('${task.piecesCount}', style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                    ],
                  ),
                ),
                Container(width: 1, height: 22, color: const Color(0xFFE2E8F0)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PASSED', style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8))),
                      Text('${task.passedPieces}', style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A))),
                    ],
                  ),
                ),
                Container(width: 1, height: 22, color: const Color(0xFFE2E8F0)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ALTERATION', style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8))),
                      Text('${task.alterationPieces}', style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFFD97706))),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Defect callout if in alteration
          if (task.alterationPieces > 0 && task.defectCategory != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFD97706)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${task.defectCategory}: ${task.defectRemarks ?? "Floor repair required"}',
                      style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF92400E)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.fact_check_outlined, size: 15),
                  label: const Text('Inspect & Triage Alteration', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3A3564),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => RecordInspectionModal(task: task),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFF94A3B8)),
                onPressed: () => ref.read(readyGoodsProvider.notifier).deleteTask(task.id),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // CARTONS & PALLETS SECTION
  Widget _buildCartonsSection(ReadyGoodsState state) {
    if (state.cartons.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        child: Column(
          children: [
            const Icon(Icons.inventory_2_outlined, size: 48, color: Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            Text('No export cartons packed yet', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
            const SizedBox(height: 4),
            Text('Tap "Pack Carton" above to seal master cartons and verify gross weight.', style: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF94A3B8)), textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return Column(
      children: state.cartons.map((c) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
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
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                    ),
                    child: Text(c.cartonNumber, style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF3A3564))),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: c.status == 'AQL_PASSED' ? const Color(0xFFF0FDF4) : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: c.status == 'AQL_PASSED' ? const Color(0xFFBBF7D0) : const Color(0xFFBFDBFE)),
                    ),
                    child: Text(
                      c.status.replaceAll('_', ' '),
                      style: GoogleFonts.publicSans(fontSize: 10.5, fontWeight: FontWeight.bold, color: c.status == 'AQL_PASSED' ? const Color(0xFF15803D) : const Color(0xFF1D4ED8)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('${c.styleName} • ${c.buyer}', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
              const SizedBox(height: 2),
              Text('Order: ${c.orderNumber} • Sealed by: ${c.sealedBy} • Storage: ${c.godownBay}', style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF64748B))),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${c.totalPieces} Pieces Packed', style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                    Text('Gross: ${c.measuredWeightKg} Kg', style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF047857))),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // EMPTY STATE
  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      child: Column(
        children: [
          const Icon(Icons.fact_check_outlined, size: 48, color: Color(0xFF94A3B8)),
          const SizedBox(height: 12),
          Text('No inspection lots in queue', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
          const SizedBox(height: 4),
          Text('Tap "Inward Lot" above to register post-wash/iron inspection batches.', style: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF94A3B8)), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
