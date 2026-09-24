import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/zigza_app_bar.dart';
import '../../modules/widgets/workspace_hub_drawer.dart';
import '../models/merchandising_models.dart';
import '../providers/merchandising_provider.dart';
import '../widgets/create_order_modal.dart';
import 'buyer_po_specification_screen.dart';

class BuyerPurchaseOrdersScreen extends ConsumerStatefulWidget {
  const BuyerPurchaseOrdersScreen({super.key});

  @override
  ConsumerState<BuyerPurchaseOrdersScreen> createState() => _BuyerPurchaseOrdersScreenState();
}

class _BuyerPurchaseOrdersScreenState extends ConsumerState<BuyerPurchaseOrdersScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();

  String _activeFilter = 'ALL';
  String _searchQuery = '';

  static const List<String> _statusFilters = [
    'ALL',
    'IN_CUTTING',
    'IN_PRINTING',
    'IN_EMBROIDERY',
    'IN_SEWING',
    'IRON',
    'WASHING',
    'ALTER',
    'DISPATCHED',
    'COMPLETED',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(merchandisingProvider.notifier).fetchMerchandisingData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openCreateOrderModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CreateOrderModal(),
    );
  }

  void _openViewOrderModal(MerchandisingOrder order) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BuyerPOSpecificationScreen(order: order)),
    );
  }

  String _normalizeStatus(String? status) {
    if (status == null || status.isEmpty || status == 'BOOKED') {
      return 'IN_CUTTING';
    }
    return status;
  }

  String _getStatusLabel(String status) {
    final s = _normalizeStatus(status);
    switch (s) {
      case 'IN_CUTTING':
        return 'In Cutting';
      case 'IN_PRINTING':
        return 'In Printing';
      case 'IN_EMBROIDERY':
        return 'In Embroidery';
      case 'IN_SEWING':
        return 'In Sewing';
      case 'IRON':
        return 'Iron';
      case 'WASHING':
        return 'Washing';
      case 'ALTER':
        return 'Alter';
      case 'DISPATCHED':
        return 'Dispatched';
      case 'COMPLETED':
        return 'Completed';
      default:
        return s.replaceAll('_', ' ');
    }
  }

  String _formatRoute(String? seq) {
    if (seq == null || seq.isEmpty || seq == 'NONE') return 'Cut & Sew';
    if (seq == 'ONLY_PRINTING') return 'Printing';
    if (seq == 'ONLY_EMBROIDERY') return 'Embroidery';
    if (seq == 'EMBROIDERY_FIRST_THEN_PRINT') return 'Emb → Print';
    if (seq == 'PRINT_FIRST_THEN_EMBROIDERY') return 'Print → Emb';
    return seq.replaceAll('_', ' ');
  }

  String _formatCurrencyValue(double val, String curr) {
    final sym = curr == 'USD' ? '\$' : curr == 'EUR' ? '€' : '₹';
    if (val >= 10000000) {
      return '$sym${(val / 10000000).toStringAsFixed(2)} Cr';
    } else if (val >= 100000) {
      return '$sym${(val / 100000).toStringAsFixed(2)} Lakh';
    } else if (val >= 1000) {
      return '$sym${(val / 1000).toStringAsFixed(1)}k';
    } else {
      return '$sym${val.toStringAsFixed(0)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(merchandisingProvider);
    final allOrders = state.orders;

    // Filter and search
    final filteredOrders = allOrders.where((ord) {
      final normStatus = _normalizeStatus(ord.status);
      final matchesFilter = _activeFilter == 'ALL' || normStatus == _activeFilter;

      final q = _searchQuery.trim().toLowerCase();
      final matchesSearch = q.isEmpty ||
          ord.poNumber.toLowerCase().contains(q) ||
          ord.brandName.toLowerCase().contains(q) ||
          ord.styleRef.toLowerCase().contains(q) ||
          ord.styleName.toLowerCase().contains(q);

      return matchesFilter && matchesSearch;
    }).toList();

    // Summary calculations matching Web Admin OrdersCatalogClient.tsx
    final totalPieces = allOrders.fold<int>(0, (sum, o) => sum + o.totalQuantity);
    final activeWip = allOrders.where((o) {
      final s = _normalizeStatus(o.status);
      return s == 'IN_CUTTING' ||
          s == 'IN_PRINTING' ||
          s == 'IN_EMBROIDERY' ||
          s == 'IN_SEWING' ||
          s == 'IRON' ||
          s == 'WASHING' ||
          s == 'ALTER';
    }).length;
    final totalValue = allOrders.fold<double>(0, (sum, o) => sum + o.totalContractValue);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFFAF7F0), // Warm cream canvas matching design.md
      drawer: const WorkspaceHubDrawer(activeRoute: '/merchandising/orders'),
      appBar: ZigzaAppBar(
        trailing: IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Color(0xFF3A3564), size: 20),
          tooltip: 'Refresh Ledger',
          onPressed: () {
            ref.read(merchandisingProvider.notifier).fetchMerchandisingData();
          },
        ),
      ),
      body: RefreshIndicator(
        color: const Color(0xFF3A3564),
        backgroundColor: Colors.white,
        onRefresh: () async {
          await ref.read(merchandisingProvider.notifier).fetchMerchandisingData();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // -------------------------------------------------------------
              // LAYER 1: BREADCRUMB
              // -------------------------------------------------------------
              _buildBreadcrumbTrail(),

              const SizedBox(height: 12),

              // -------------------------------------------------------------
              // LAYER 2: TOP HERO HEADER CARD (Encapsulated Luxury White Card)
              // -------------------------------------------------------------
              _buildTopHeaderCard(allOrders.length),

              const SizedBox(height: 14),

              // -------------------------------------------------------------
              // LAYER 3: 4 EXECUTIVE KPI METRIC CARDS (2x2 Grid)
              // -------------------------------------------------------------
              _buildKpiMetricsGrid(
                contractedCount: allOrders.length,
                totalVolume: totalPieces,
                activeWipCount: activeWip,
                totalContractValue: totalValue,
              ),

              const SizedBox(height: 16),

              // -------------------------------------------------------------
              // LAYER 4: TOOLBAR (Status Tabs + Search Box)
              // -------------------------------------------------------------
              _buildFilterToolbar(filteredOrders.length),

              const SizedBox(height: 12),

              // -------------------------------------------------------------
              // LAYER 5: ORDER CARDS LEDGER / EMPTY STATE
              // -------------------------------------------------------------
              if (state.isLoading && allOrders.isEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF3A3564), strokeWidth: 2.5),
                  ),
                ),
              ] else if (filteredOrders.isEmpty) ...[
                _buildEmptyStateCard(),
              ] else ...[
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredOrders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final order = filteredOrders[index];
                    return _buildOrderCard(order);
                  },
                ),
              ],

              const SizedBox(height: 70),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateOrderModal,
        backgroundColor: const Color(0xFF3A3564),
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: Text(
          'Book New PO',
          style: GoogleFonts.publicSans(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // BREADCRUMB TRAIL
  // =========================================================================
  Widget _buildBreadcrumbTrail() {
    return Row(
      children: [
        Text(
          'Merchandising',
          style: GoogleFonts.publicSans(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(width: 5),
        const Text('/', style: TextStyle(fontSize: 11, color: Color(0xFFCBD5E1))),
        const SizedBox(width: 5),
        Text(
          'Commercial Ops',
          style: GoogleFonts.publicSans(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(width: 5),
        const Text('/', style: TextStyle(fontSize: 11, color: Color(0xFFCBD5E1))),
        const SizedBox(width: 5),
        Text(
          'Buyer Purchase Orders',
          style: GoogleFonts.publicSans(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // TOP HERO HEADER CARD
  // =========================================================================
  Widget _buildTopHeaderCard(int count) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1A000000), width: 0.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 44x44 Icon Container
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF7F0),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x1A000000), width: 0.5),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: Color(0xFF3A3564),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Buyer Purchase Orders',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAF7F0),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0x1F000000), width: 0.5),
                          ),
                          child: Text(
                            '$count Active',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF3A3564),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Master buyer contract ledger, color & size matrix, and line handover',
                      style: GoogleFonts.publicSans(
                        fontSize: 12,
                        color: const Color(0xFF475569),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _openCreateOrderModal,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3A3564),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(
                'Book New Buyer PO (2-Step)',
                style: GoogleFonts.publicSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 4 EXECUTIVE KPI METRICS (2x2 Grid)
  // =========================================================================
  Widget _buildKpiMetricsGrid({
    required int contractedCount,
    required int totalVolume,
    required int activeWipCount,
    required double totalContractValue,
  }) {
    final currencyText = _formatCurrencyValue(totalContractValue, 'INR');

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                icon: Icons.assignment_turned_in_outlined,
                stage: 'STAGE 01',
                title: 'Contracted POs',
                subtitle: 'Commercial POs',
                value: '$contractedCount',
                pillLabel: 'Global Buyers',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricCard(
                icon: Icons.layers_outlined,
                stage: 'VOLUME',
                title: 'Total Pieces',
                subtitle: 'Aggregated pcs',
                value: NumberFormat.compact().format(totalVolume),
                pillLabel: 'Total Pcs',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                icon: Icons.trending_up_rounded,
                stage: 'WIP',
                title: 'Floor Handover',
                subtitle: 'Lines in progress',
                value: '$activeWipCount',
                pillLabel: 'Active WIP Lines',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricCard(
                icon: Icons.currency_rupee_rounded,
                stage: 'REVENUE',
                title: 'Contract Value',
                subtitle: 'Commercial revenue',
                value: currencyText,
                pillLabel: 'Booked Value',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String stage,
    required String title,
    required String subtitle,
    required String value,
    required String pillLabel,
  }) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x1A000000), width: 0.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 2,
            offset: Offset(0, 1),
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
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF7F0),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: const Color(0x14000000), width: 0.5),
                ),
                child: Icon(icon, color: const Color(0xFF3A3564), size: 17),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 0.5),
                ),
                child: Text(
                  stage,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: GoogleFonts.publicSans(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E293B),
            ),
          ),
          Text(
            subtitle,
            style: GoogleFonts.publicSans(
              fontSize: 10,
              color: const Color(0xFF94A3B8),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.only(top: 8),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFF1F5F9), width: 0.8)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF7F0),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0x14000000), width: 0.5),
                  ),
                  child: Text(
                    pillLabel,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF3A3564),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TOOLBAR (SEARCH & HORIZONTAL STATUS FILTER CHIPS)
  // =========================================================================
  Widget _buildFilterToolbar(int matchCount) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x1A000000), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search Input
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 0.5),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() => _searchQuery = val);
              },
              style: GoogleFonts.publicSans(fontSize: 12.5, color: const Color(0xFF0F172A)),
              decoration: InputDecoration(
                hintText: 'Search PO, Buyer, Style Ref...',
                hintStyle: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16, color: Color(0xFF64748B)),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                border: InputBorder.none,
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Horizontal Status Filter Scroll
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _statusFilters.map((tab) {
                final isSelected = _activeFilter == tab;
                final label = tab == 'ALL' ? 'All Contracts' : _getStatusLabel(tab);

                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: () => setState(() => _activeFilter = tab),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF3A3564) : const Color(0xFFFAF7F0),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF3A3564) : const Color(0x14000000),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        label,
                        style: GoogleFonts.publicSans(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                          color: isSelected ? Colors.white : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // SINGLE BUYER PO CARD (Industrial Luxury Styling)
  // =========================================================================
  Widget _buildOrderCard(MerchandisingOrder order) {
    final statusText = _getStatusLabel(order.status);
    final routeText = _formatRoute(order.embellishmentSequence);
    final currencySym = order.currency == 'USD' ? '\$' : order.currency == 'EUR' ? '€' : '₹';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x1A000000), width: 0.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Header Row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF7F0),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0x1A000000), width: 0.5),
                      ),
                      child: Text(
                        order.poNumber,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF3A3564),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      order.brandName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF7F0),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0x1A000000), width: 0.5),
                  ),
                  child: Text(
                    statusText.toUpperCase(),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF3A3564),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Body Content: Style + Specs + Metrics
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Style ref and name
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        order.styleRef,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF334155),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        order.styleName.isNotEmpty ? order.styleName : 'Standard Garment Article',
                        style: GoogleFonts.publicSans(
                          fontSize: 12,
                          color: const Color(0xFF475569),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Specs 3-Column Box
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF7F0),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0x10000000), width: 0.5),
                  ),
                  child: Row(
                    children: [
                      // Volume
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CONTRACT PCS',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${order.totalQuantity.toLocaleString()} Pcs',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 0.8, height: 26, color: const Color(0xFFE2E8F0)),
                      const SizedBox(width: 10),

                      // FOB & Value
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'UNIT FOB / VALUE',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$currencySym${order.unitFobPrice.toStringAsFixed(2)} • ${_formatCurrencyValue(order.totalContractValue, order.currency)}',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Ex-Factory & Embellishment Routing Tags
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.event_outlined, size: 14, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Text(
                          order.exFactoryDate.isNotEmpty ? order.exFactoryDate : 'TBD',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0x1A000000), width: 0.5),
                      ),
                      child: Text(
                        routeText,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF3A3564),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Bottom Action Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                InkWell(
                  onTap: () => _openViewOrderModal(order),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF7F0),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0x1A000000), width: 0.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.visibility_outlined, size: 14, color: Color(0xFF3A3564)),
                        const SizedBox(width: 5),
                        Text(
                          'View Specification & Matrix',
                          style: GoogleFonts.publicSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF3A3564),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // EMPTY STATE CARD
  // =========================================================================
  Widget _buildEmptyStateCard() {
    final isFiltered = _searchQuery.isNotEmpty || _activeFilter != 'ALL';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1A000000), width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFFFAF7F0),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x14000000), width: 0.5),
            ),
            child: const Icon(Icons.receipt_long_outlined, size: 28, color: Color(0xFF3A3564)),
          ),
          const SizedBox(height: 14),
          Text(
            isFiltered ? 'No matching purchase orders' : 'No Buyer Purchase Orders Yet',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isFiltered
                ? 'Try adjusting your search terms or status filter tab.'
                : 'Book your first master buyer purchase order to begin tracking matrix ratios & production.',
            textAlign: TextAlign.center,
            style: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          if (isFiltered) ...[
            OutlinedButton.icon(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                  _activeFilter = 'ALL';
                });
              },
              icon: const Icon(Icons.restart_alt_rounded, size: 16),
              label: Text(
                'Reset Filters',
                style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF3A3564),
                side: const BorderSide(color: Color(0xFF3A3564)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ] else ...[
            ElevatedButton.icon(
              onPressed: _openCreateOrderModal,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(
                'Book New Buyer PO',
                style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3A3564),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

extension IntFormattingExtension on int {
  String toLocaleString() {
    return NumberFormat('#,##,###').format(this);
  }
}
