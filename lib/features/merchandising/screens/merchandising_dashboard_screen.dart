import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/widgets/zigza_app_bar.dart';
import '../../modules/widgets/workspace_hub_drawer.dart';
import '../../design/screens/tech_pack_catalog_screen.dart';
import '../models/merchandising_models.dart';
import '../providers/merchandising_provider.dart';
import '../widgets/create_order_modal.dart';
import '../widgets/view_order_modal.dart';
import '../widgets/active_buyers_modal.dart';

class MerchandisingDashboardScreen extends ConsumerStatefulWidget {
  const MerchandisingDashboardScreen({super.key});

  @override
  ConsumerState<MerchandisingDashboardScreen> createState() => _MerchandisingDashboardScreenState();
}

class _MerchandisingDashboardScreenState extends ConsumerState<MerchandisingDashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(merchandisingProvider.notifier).fetchMerchandisingData();
    });
  }

  void _openCreateOrderModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CreateOrderModal(),
    );
  }

  void _openActiveBuyersModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ActiveBuyersModal(),
    );
  }

  void _openViewOrderModal(MerchandisingOrder order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ViewOrderModal(order: order),
    );
  }

  void _showBuyerSelectionDialog(List<ActiveBuyer> buyers, String currentBuyerId) {
    String searchQuery = '';
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filtered = buyers.where((b) {
              final q = searchQuery.toLowerCase();
              return b.buyerName.toLowerCase().contains(q) ||
                  b.buyerCode.toLowerCase().contains(q) ||
                  (b.linkedArticleNumber != null && b.linkedArticleNumber!.toLowerCase().contains(q));
            }).toList();

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select Buyer Contract',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1C1C1A),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF6B6A65)),
                    onPressed: () => Navigator.pop(ctx),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF6B6A65)),
                        hintText: 'Search buyers...',
                        hintStyle: GoogleFonts.publicSans(fontSize: 12.5, color: const Color(0xFFB6B4AC)),
                        filled: true,
                        fillColor: const Color(0xFFFAFAF8),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0x1A000000)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0x1A000000)),
                        ),
                      ),
                      onChanged: (v) {
                        setDialogState(() => searchQuery = v);
                      },
                    ),
                    const SizedBox(height: 10),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 260),
                      child: filtered.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text(
                                'No buyers match search.',
                                style: GoogleFonts.publicSans(fontSize: 12.5, color: const Color(0xFF9B9A94)),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                              itemBuilder: (_, idx) {
                                final b = filtered[idx];
                                final isSelected = b.id == currentBuyerId;
                                return ListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  title: Text(
                                    b.buyerName,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? const Color(0xFF332B6B) : const Color(0xFF1C1C1A),
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${b.contractedVolume} Pcs ${b.linkedArticleNumber != null ? '• ${b.linkedArticleNumber}' : '• Pending Link'}',
                                    style: GoogleFonts.jetBrainsMono(fontSize: 11, color: const Color(0xFF6B6A65)),
                                  ),
                                  trailing: isSelected
                                      ? const Icon(Icons.check_circle_rounded, color: Color(0xFF332B6B), size: 18)
                                      : null,
                                  onTap: () {
                                    ref.read(merchandisingProvider.notifier).setSelectedBuyerId(b.id);
                                    Navigator.pop(ctx);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF6B6A65)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(merchandisingProvider);
    final selectedBuyer = state.selectedBuyer;
    final stageMetrics = state.stageMetrics;
    final filteredOrders = state.filteredOrders;
    final activities = state.activities;

    final selectedBuyerDisplayText = selectedBuyer != null
        ? '${selectedBuyer.buyerName} (${selectedBuyer.contractedVolume.toString()} Pcs)'
        : (state.buyers.isEmpty ? 'No active buyers contracted' : 'Select buyer contract');

    final buyerVolume = selectedBuyer?.contractedVolume ?? 0;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFFFFFFF),
      drawer: const WorkspaceHubDrawer(activeRoute: '/merchandising'),
      appBar: ZigzaAppBar(
        onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      body: RefreshIndicator(
        color: const Color(0xFF332B6B),
        backgroundColor: Colors.white,
        onRefresh: () => ref.read(merchandisingProvider.notifier).fetchMerchandisingData(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // =========================================================
              // 1. PAGE HEADER CARD (#FAFAF8)
              // =========================================================
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAF8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0x1A000000)),
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
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0x1A000000)),
                          ),
                          child: const Icon(
                            Icons.work_outline,
                            color: Color(0xFF332B6B),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Merchandising & sourcing desk',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF1C1C1A),
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Real-time buyer PO contracts and critical path T&A tracking',
                                style: GoogleFonts.publicSans(
                                  fontSize: 12.5,
                                  color: const Color(0xFF6B6A65),
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Quick Action Buttons
                    Row(
                      children: [
                        // "Active buyers" outline button
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF1C1C1A),
                              side: const BorderSide(color: Color(0x26000000)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                            ),
                            onPressed: _openActiveBuyersModal,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.people_outline_rounded, size: 16, color: Color(0xFF332B6B)),
                                const SizedBox(width: 6),
                                Text(
                                  'Active buyers',
                                  style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // "+ Book new PO" filled indigo button
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF332B6B),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              elevation: 0,
                            ),
                            onPressed: _openCreateOrderModal,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.add_rounded, size: 18),
                                const SizedBox(width: 4),
                                Text(
                                  '+ Book new PO',
                                  style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // =========================================================
              // 2. SELECTED BUYER CONTRACT CARD (#FAFAF8)
              // =========================================================
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAF8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0x1A000000)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0x1A000000)),
                          ),
                          child: const Icon(
                            Icons.business_outlined,
                            color: Color(0xFF332B6B),
                            size: 19,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SELECTED BUYER CONTRACT',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF9B9A94),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      selectedBuyer != null ? selectedBuyer.buyerName : 'No active buyers',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF1C1C1A),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (selectedBuyer?.linkedArticleNumber != null &&
                                      selectedBuyer!.linkedArticleNumber!.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: const Color(0x1A000000)),
                                      ),
                                      child: Text(
                                        selectedBuyer.linkedArticleNumber!,
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF332B6B),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Selector row with Refresh sync button
                    Row(
                      children: [
                        // Searchable Dropdown Button
                        Expanded(
                          child: InkWell(
                            onTap: () => _showBuyerSelectionDialog(state.buyers, state.selectedBuyerId),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0x1A000000)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.people_alt_outlined, size: 15, color: Color(0xFF332B6B)),
                                      const SizedBox(width: 8),
                                      ConstrainedBox(
                                        constraints: BoxConstraints(
                                          maxWidth: MediaQuery.of(context).size.width * 0.52,
                                        ),
                                        child: Text(
                                          selectedBuyerDisplayText,
                                          style: GoogleFonts.publicSans(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF1C1C1A),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF6B6A65)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Refresh sync button
                        InkWell(
                          onTap: () => ref.read(merchandisingProvider.notifier).syncData(),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0x1A000000)),
                            ),
                            child: state.isSyncing
                                ? const Center(
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFF332B6B),
                                      ),
                                    ),
                                  )
                                : const Icon(Icons.sync_rounded, color: Color(0xFF332B6B), size: 18),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // =========================================================
              // 3. STATS GRID (2x2)
              // =========================================================
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.5,
                children: [
                  // Stat 1: Active Articles
                  _buildStatCard(
                    title: 'Active articles',
                    value: state.activeArticlesCount.toString(),
                    icon: Icons.layers_outlined,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TechPackCatalogScreen()),
                      );
                    },
                  ),

                  // Stat 2: Active buyer POs
                  _buildStatCard(
                    title: 'Active buyer POs',
                    value: state.totalBookedPcs.toString(),
                    icon: Icons.work_outline,
                    onTap: () {
                      ref.read(merchandisingProvider.notifier).setStatusFilter('ALL');
                    },
                  ),

                  // Stat 3: In order
                  _buildStatCard(
                    title: 'In order',
                    value: state.totalInOrderPieces.toString(),
                    icon: Icons.inventory_2_outlined,
                    onTap: _openActiveBuyersModal,
                  ),

                  // Stat 4: Critical path SLA
                  _buildStatCard(
                    title: 'Critical path SLA',
                    value: '${state.slaPercentage}%',
                    icon: Icons.calendar_today_outlined,
                    onTap: () {},
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // =========================================================
              // 4. LIVE REVIEW SECTION (#FAFAF8)
              // =========================================================
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAF8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0x1A000000)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0x1A000000)),
                              ),
                              child: const Icon(
                                Icons.trending_up_rounded,
                                color: Color(0xFF332B6B),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Live review',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF1C1C1A),
                                  ),
                                ),
                                Text(
                                  'Commercial lead-time and factory floor conversion',
                                  style: GoogleFonts.publicSans(
                                    fontSize: 11,
                                    color: const Color(0xFF6B6A65),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Summary row: Total Booked & Full T&A Calendar link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total booked: ${buyerVolume > 0 ? buyerVolume : state.totalBookedPcs} pcs',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1C1C1A),
                          ),
                        ),
                        InkWell(
                          onTap: () {},
                          child: Row(
                            children: [
                              Text(
                                'Full T&A calendar',
                                style: GoogleFonts.publicSans(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF332B6B),
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(Icons.arrow_forward_rounded, size: 13, color: Color(0xFF332B6B)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // =========================================================
                    // 5. EIGHT PIPELINE-STAGE CARDS
                    // =========================================================
                    _buildPipelineGrid(stageMetrics, buyerVolume),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // =========================================================
              // 6. ACTIVE COMMERCIAL ORDERS PIPELINE CARD (#FAFAF8)
              // =========================================================
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAF8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0x1A000000)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Active commercial orders pipeline',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1C1C1A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Live buyer contracts with BOM variance and production floor handshake status',
                                style: GoogleFonts.publicSans(
                                  fontSize: 11,
                                  color: const Color(0xFF6B6A65),
                                ),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            ref.read(merchandisingProvider.notifier).setStatusFilter('ALL');
                          },
                          child: Row(
                            children: [
                              Text(
                                'View all orders',
                                style: GoogleFonts.publicSans(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF332B6B),
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(Icons.arrow_forward_rounded, size: 13, color: Color(0xFF332B6B)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Horizontal Filter Tabs matching 8 stages
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterTab('All', 'ALL', state.statusFilter),
                          _buildFilterTab('In cutting', 'IN_CUTTING', state.statusFilter),
                          _buildFilterTab('In printing', 'IN_PRINTING', state.statusFilter),
                          _buildFilterTab('In embroidery', 'IN_EMBROIDERY', state.statusFilter),
                          _buildFilterTab('In sewing', 'IN_SEWING', state.statusFilter),
                          _buildFilterTab('Iron', 'IRON', state.statusFilter),
                          _buildFilterTab('Washing', 'WASHING', state.statusFilter),
                          _buildFilterTab('Alter', 'ALTER', state.statusFilter),
                          _buildFilterTab('Dispatched', 'DISPATCHED', state.statusFilter),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Orders List (Stacked Cards for Mobile)
                    if (filteredOrders.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0x1A000000)),
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              const Icon(Icons.work_outline, size: 36, color: Color(0xFFB6B4AC)),
                              const SizedBox(height: 8),
                              Text(
                                state.statusFilter != 'ALL' ? 'No orders in this stage' : 'No active commercial orders',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1C1C1A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                state.statusFilter != 'ALL'
                                    ? 'Try switching tabs or resetting the filter.'
                                    : 'Book a buyer purchase order to begin tracking.',
                                style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF6B6A65)),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF332B6B),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  elevation: 0,
                                ),
                                onPressed: _openCreateOrderModal,
                                child: Text('+ Book New PO', style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.bold)),
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
                        itemBuilder: (ctx, idx) {
                          final ord = filteredOrders[idx];
                          return _buildOrderCard(ord);
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // =========================================================
              // 7. COMMERCIAL ACTIVITY STREAM CARD (#FAFAF8)
              // =========================================================
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAF8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0x1A000000)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Commercial activity stream',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1C1C1A),
                          ),
                        ),
                        const Icon(Icons.access_time_rounded, size: 18, color: Color(0xFF332B6B)),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Activities List
                    if (activities.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Text(
                            'No recent activity. Activity logs appear automatically as purchase orders progress.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF9B9A94)),
                          ),
                        ),
                      )
                    else
                      ...activities.map((act) => _buildActivityItem(act)),

                    const SizedBox(height: 12),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 12),

                    // Footer Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Real-time ERP synchronization',
                          style: GoogleFonts.publicSans(
                            fontSize: 11.5,
                            color: const Color(0xFF6B6A65),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE9F7EE),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF1B7A43),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Connected',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1B7A43),
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
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAF8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x1A000000)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0x1A000000)),
                  ),
                  child: Icon(icon, color: const Color(0xFF332B6B), size: 17),
                ),
                const Icon(Icons.arrow_outward_rounded, size: 14, color: Color(0xFF9B9A94)),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF6B6A65),
                    letterSpacing: 0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1C1C1A),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPipelineGrid(StageMetrics metrics, int totalVolume) {
    final stages = [
      {'name': '1. In pending', 'pcs': metrics.inPending},
      {'name': '2. In cutting', 'pcs': metrics.inCutting},
      {'name': '3. In printing', 'pcs': metrics.inPrinting},
      {'name': '4. In embroidery', 'pcs': metrics.inEmbroidery},
      {'name': '5. In sewing', 'pcs': metrics.inSewing},
      {'name': '6. Iron', 'pcs': metrics.iron},
      {'name': '7. Washing', 'pcs': metrics.washing},
      {'name': '8. Alter', 'pcs': metrics.alter},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 2.1,
      ),
      itemCount: stages.length,
      itemBuilder: (ctx, idx) {
        final st = stages[idx];
        final pcs = st['pcs'] as int;
        final pct = totalVolume > 0 ? ((pcs / totalVolume) * 100).round() : 0;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0x1A000000)),
          ),
          child: Stack(
            children: [
              // Left indigo accent indicator
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 3.5,
                  decoration: BoxDecoration(
                    color: const Color(0xFF332B6B),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            (st['name'] as String).toUpperCase(),
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF6B6A65),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAFAF8),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0x1A000000)),
                          ),
                          child: Text(
                            '$pct%',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF332B6B),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      pcs.toString(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1C1C1A),
                      ),
                    ),
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: (pct / 100.0).clamp(0.0, 1.0),
                        backgroundColor: const Color(0xFFF1F5F9),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF332B6B)),
                        minHeight: 3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterTab(String label, String value, String activeValue) {
    final isSelected = activeValue == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () {
          ref.read(merchandisingProvider.notifier).setStatusFilter(value);
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF332B6B) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? const Color(0xFF332B6B) : const Color(0x1A000000),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.publicSans(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : const Color(0xFF6B6A65),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(MerchandisingOrder ord) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x1A000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // PO Number + Buyer on Left, Article + Category on Right
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left: PO & Buyer
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ord.poNumber,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF332B6B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ord.brandName,
                      style: GoogleFonts.publicSans(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1C1C1A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Right: Style Ref & Style Name
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      ord.styleRef,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1C1C1A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ord.styleName,
                      style: GoogleFonts.publicSans(
                        fontSize: 10.5,
                        color: const Color(0xFF6B6A65),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),

          // Volume, FOB & Contract Value, Route, Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Volume & FOB / Value
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${ord.totalQuantity} Pcs',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1C1C1A),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${ord.currency == 'INR' ? '₹' : '\$'}${ord.unitFobPrice.toStringAsFixed(0)} • ${ord.currency == 'INR' ? '₹' : '\$'}${(ord.totalContractValue >= 100000 ? '${(ord.totalContractValue / 100000).toStringAsFixed(1)}L' : '${(ord.totalContractValue / 1000).toStringAsFixed(0)}k')}',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10.5,
                        color: const Color(0xFF6B6A65),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // Route & Status Pills
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFAF8),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0x1A000000)),
                    ),
                    child: Text(
                      ord.routeLabel,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF332B6B),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE9F7EE),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0x331B7A43)),
                    ),
                    child: Text(
                      ord.statusLabel,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1B7A43),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Actions: View More & T&A buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  backgroundColor: const Color(0xFFFAFAF8),
                  foregroundColor: const Color(0xFF332B6B),
                  side: const BorderSide(color: Color(0x1A000000)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: const Size(0, 0),
                ),
                onPressed: () => _openViewOrderModal(ord),
                child: Text('View More', style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF332B6B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: const Size(0, 0),
                  elevation: 0,
                ),
                onPressed: () => _openViewOrderModal(ord),
                child: Text('T&A', style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(ActivityItem act) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x1A000000)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAF8),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0x1A000000)),
            ),
            child: const Icon(Icons.work_outline, color: Color(0xFF332B6B), size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  act.title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1C1C1A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  act.details,
                  style: GoogleFonts.publicSans(
                    fontSize: 11,
                    color: const Color(0xFF6B6A65),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      act.location,
                      style: GoogleFonts.jetBrainsMono(fontSize: 9.5, color: const Color(0xFF9B9A94)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE9F7EE),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        act.relativeTime,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1B7A43),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
