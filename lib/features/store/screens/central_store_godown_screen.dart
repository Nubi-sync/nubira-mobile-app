import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/widgets/zigza_app_bar.dart';
import '../../modules/widgets/workspace_hub_drawer.dart';
import '../models/store_models.dart';
import '../providers/store_provider.dart';
import '../widgets/add_fabric_modal.dart';
import '../widgets/create_material_issue_modal.dart';
import '../widgets/book_fabric_modal.dart';

class CentralStoreGodownScreen extends ConsumerStatefulWidget {
  const CentralStoreGodownScreen({super.key});

  @override
  ConsumerState<CentralStoreGodownScreen> createState() => _CentralStoreGodownScreenState();
}

class _CentralStoreGodownScreenState extends ConsumerState<CentralStoreGodownScreen> {
  // Zigza Industrial Luxury Design Tokens
  static const Color kCanvasColor = Color(0xFFFAF7F0);
  static const Color kCardBg = Color(0xFFFFFFFF);
  static const Color kPrimaryBrand = Color(0xFF3A3564);
  static const Color kBorderColor = Color(0xFFE7E1D6);
  static const Color kMutedText = Color(0xFF7A7488);
  static const Color kInkText = Color(0xFF232028);
  static const Color kBluePastelBg = Color(0xFFE5EDF9);
  static const Color kBluePastelText = Color(0xFF2E5AA8);
  static const Color kSearchInputBg = Color(0xFFF6F8FC);
  static const Color kFilterChipInactive = Color(0xFFEEF1F8);

  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openAddFabricModal() {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => const AddFabricModal(),
    );
  }

  void _openIssueModal({
    String? fabricType,
    String? color,
    String? articleNo,
    double? quantity,
    int? rolls,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => CreateMaterialIssueModal(
        initialFabricType: fabricType,
        initialColor: color,
        initialArticleNo: articleNo,
        initialQuantity: quantity,
        initialRolls: rolls,
      ),
    );
  }

  void _openBookFabricModal(CentralFabricInventoryModel fabric) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => BookFabricModal(fabric: fabric),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(storeProvider);

    return Scaffold(
      backgroundColor: kCanvasColor,
      appBar: const ZigzaAppBar(),
      drawer: const WorkspaceHubDrawer(activeRoute: '/store'),
      body: RefreshIndicator(
        color: kPrimaryBrand,
        backgroundColor: kCardBg,
        onRefresh: () async {
          await ref.read(storeProvider.notifier).fetchStoreData();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ==========================================
              // a. Breadcrumb Row (Responsive & Safe)
              // ==========================================
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 5,
                      runSpacing: 2,
                      children: [
                        InkWell(
                          onTap: () => Navigator.pop(context),
                          child: Text(
                            'Workspace Hub',
                            style: GoogleFonts.publicSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: kMutedText,
                            ),
                          ),
                        ),
                        const Text('/', style: TextStyle(color: kBorderColor, fontSize: 12)),
                        Text(
                          '11. Central Store & Godown',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: kInkText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: kCanvasColor,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: kBorderColor),
                    ),
                    child: Text(
                      state.organizationName,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: kPrimaryBrand,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ==========================================
              // b. Module Card (Matching Web Admin Central Store Hub)
              // ==========================================
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: kCardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kBorderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
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
                            color: kCanvasColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: kBorderColor),
                          ),
                          child: const Icon(Icons.store_mall_directory_outlined, color: kPrimaryBrand, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Central Store Hub',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: kInkText,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: kCanvasColor,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: kBorderColor),
                                    ),
                                    child: Text(
                                      'DIV 11',
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: kPrimaryBrand,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Central fabric stock, merchandise booking, and inter-module production flow',
                                style: GoogleFonts.publicSans(
                                  fontSize: 12,
                                  color: kMutedText,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Actions Row
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _openAddFabricModal,
                            icon: const Icon(Icons.add, size: 14, color: kPrimaryBrand),
                            label: Text(
                              'Add Cloth Stock',
                              style: GoogleFonts.publicSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: kPrimaryBrand,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: kCanvasColor,
                              side: const BorderSide(color: kBorderColor),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _openIssueModal(),
                            icon: const Icon(Icons.outbound_outlined, size: 14),
                            label: Text(
                              'Issue Challan',
                              style: GoogleFonts.publicSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kPrimaryBrand,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ==========================================
              // c. 2x2 Stats Grid with Web Badges
              // ==========================================
              Row(
                children: [
                  Expanded(
                    child: _buildWebKpiCard(
                      label: 'TOTAL CLOTH STOCK',
                      sublabel: '${state.totalFabricRolls} Rolls on hand',
                      value: state.totalFabricMeters >= 1000
                          ? '${(state.totalFabricMeters / 1000).toStringAsFixed(1)}k'
                          : state.totalFabricMeters.toStringAsFixed(0),
                      unit: 'METERS',
                      badge: 'IN GODOWN',
                      badgeColor: const Color(0xFFE2E8F0),
                      badgeTextColor: const Color(0xFF475569),
                      icon: Icons.layers_outlined,
                      onTap: () => ref.read(storeProvider.notifier).setActiveTab('FABRICS'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildWebKpiCard(
                      label: 'UNRESERVED FABRIC',
                      sublabel: '${state.totalBookedMeters.toStringAsFixed(0)}m Booked',
                      value: state.totalAvailableMeters >= 1000
                          ? '${(state.totalAvailableMeters / 1000).toStringAsFixed(1)}k'
                          : state.totalAvailableMeters.toStringAsFixed(0),
                      unit: 'METERS',
                      badge: 'AVAILABLE',
                      badgeColor: const Color(0xFFECFDF5),
                      badgeTextColor: const Color(0xFF047857),
                      icon: Icons.inventory_2_outlined,
                      onTap: () => ref.read(storeProvider.notifier).setActiveTab('FABRICS'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildWebKpiCard(
                      label: 'ACTIVE ISSUES',
                      sublabel: 'Inter-module transfers',
                      value: '${state.activeIssuesCount}',
                      unit: 'IN TRANSIT',
                      badge: 'PIPELINE',
                      badgeColor: const Color(0xFFFEF3C7),
                      badgeTextColor: const Color(0xFFB45309),
                      icon: Icons.sync_alt_rounded,
                      onTap: () => ref.read(storeProvider.notifier).setActiveTab('ISSUES'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildWebKpiCard(
                      label: 'TOTAL WEIGHT',
                      sublabel: 'Stock mass',
                      value: state.totalWeightKg >= 1000
                          ? '${(state.totalWeightKg / 1000).toStringAsFixed(1)}k'
                          : state.totalWeightKg.toStringAsFixed(0),
                      unit: 'KG',
                      badge: 'WEIGHT',
                      badgeColor: const Color(0xFFEFF6FF),
                      badgeTextColor: const Color(0xFF2563EB),
                      icon: Icons.scale_outlined,
                      onTap: () {},
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ==========================================
              // c.5 PRODUCTION CHAIN & MODULE FLOOR STORES
              // ==========================================
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: kCardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kBorderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PRODUCTION CHAIN & MODULE FLOOR STORES',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: kInkText,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildChainTile('01', 'Merchandise', 'Stock & Sourcing'),
                          const SizedBox(width: 8),
                          _buildChainTile('03', 'Cutting Floor', 'Holds & Spreading'),
                          const SizedBox(width: 8),
                          _buildChainTile('04', 'Printing Div', 'Screen & Digital'),
                          const SizedBox(width: 8),
                          _buildChainTile('05', 'Embroidery', 'Satin & Multi-head'),
                          const SizedBox(width: 8),
                          _buildChainTile('06', 'Washing Ops', 'Enzyme & Hydro'),
                          const SizedBox(width: 8),
                          _buildChainTile('08', 'Ironing Ops', 'Steam & Press'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ==========================================
              // d. Tabs + Filter Card (Single White Card)
              // ==========================================
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: kCardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kBorderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Tabs Scrollable Bar (Exact match with Web)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildTabButton(
                            title: 'Overview',
                            icon: Icons.dashboard_outlined,
                            isActive: state.activeTab == 'OVERVIEW',
                            onTap: () => ref.read(storeProvider.notifier).setActiveTab('OVERVIEW'),
                          ),
                          const SizedBox(width: 6),
                          _buildTabButton(
                            title: 'Fabric Inventory (${state.fabrics.length})',
                            icon: Icons.layers_outlined,
                            isActive: state.activeTab == 'FABRICS',
                            onTap: () => ref.read(storeProvider.notifier).setActiveTab('FABRICS'),
                          ),
                          const SizedBox(width: 6),
                          _buildTabButton(
                            title: 'Merchandise Store',
                            icon: Icons.business_center_outlined,
                            isActive: state.activeTab == 'MERCHANDISE',
                            onTap: () => ref.read(storeProvider.notifier).setActiveTab('MERCHANDISE'),
                          ),
                          const SizedBox(width: 6),
                          _buildTabButton(
                            title: 'Material Issues (${state.issues.length})',
                            icon: Icons.outbound_outlined,
                            isActive: state.activeTab == 'ISSUES',
                            onTap: () => ref.read(storeProvider.notifier).setActiveTab('ISSUES'),
                          ),
                          const SizedBox(width: 6),
                          _buildTabButton(
                            title: 'Module Receipts (${state.receipts.length})',
                            icon: Icons.move_to_inbox_outlined,
                            isActive: state.activeTab == 'RECEIPTS',
                            onTap: () => ref.read(storeProvider.notifier).setActiveTab('RECEIPTS'),
                          ),
                          const SizedBox(width: 6),
                          _buildTabButton(
                            title: 'Truck GRN (${state.truckInwards.length})',
                            icon: Icons.local_shipping_outlined,
                            isActive: state.activeTab == 'TRUCKS',
                            onTap: () => ref.read(storeProvider.notifier).setActiveTab('TRUCKS'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Filter Chips (when on FABRICS tab)
                    if (state.activeTab == 'FABRICS') ...[
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip('ALL', 'All Fabrics (${state.fabrics.length})', state.statusFilter),
                            const SizedBox(width: 6),
                            _buildFilterChip('AVAILABLE', 'Available Stock', state.statusFilter),
                            const SizedBox(width: 6),
                            _buildFilterChip('BOOKED', 'Booked for Articles', state.statusFilter),
                            const SizedBox(width: 6),
                            _buildFilterChip('LOW_STOCK', 'Low Stock (< 200m)', state.statusFilter),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Search Input
                    Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: kSearchInputBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: kBorderColor),
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (v) => ref.read(storeProvider.notifier).setSearchQuery(v),
                        style: GoogleFonts.publicSans(fontSize: 12.5, color: kInkText),
                        decoration: InputDecoration(
                          hintText: 'Search fabric type, color, supplier, rack, challan…',
                          hintStyle: GoogleFonts.publicSans(fontSize: 12, color: kMutedText),
                          prefixIcon: const Icon(Icons.search, size: 18, color: kMutedText),
                          suffixIcon: _searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16, color: kMutedText),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    ref.read(storeProvider.notifier).setSearchQuery('');
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ==========================================
              // e. Main Content Lists
              // ==========================================
              if (state.isLoading) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator(color: kPrimaryBrand)),
                ),
              ] else if (state.activeTab == 'OVERVIEW') ...[
                _buildOverviewTab(state),
              ] else if (state.activeTab == 'FABRICS' || state.activeTab == 'MERCHANDISE') ...[
                _buildFabricsList(state),
              ] else if (state.activeTab == 'ISSUES') ...[
                _buildIssuesList(state),
              ] else if (state.activeTab == 'RECEIPTS') ...[
                _buildReceiptsList(state),
              ] else if (state.activeTab == 'TRUCKS') ...[
                _buildTrucksList(state),
              ],
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------
  // OVERVIEW TAB
  // ----------------------------------------------------
  Widget _buildOverviewTab(StoreState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Quick Navigation Grid
        Text(
          'STORE WAREHOUSE SECTIONS',
          style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w800, color: kInkText, letterSpacing: 0.5),
        ),
        const SizedBox(height: 8),

        Row(
          children: [
            Expanded(
              child: _buildSectionCard(
                title: 'Fabric Godown',
                subtitle: 'Bay 1 & 2 Storage',
                count: '${state.totalFabricRolls} Rolls',
                icon: Icons.layers_outlined,
                onTap: () => ref.read(storeProvider.notifier).setActiveTab('FABRICS'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSectionCard(
                title: 'Floor Issues',
                subtitle: 'Production Challans',
                count: '${state.issues.length} Issues',
                icon: Icons.outbound_outlined,
                onTap: () => ref.read(storeProvider.notifier).setActiveTab('ISSUES'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildSectionCard(
                title: 'Truck Inward Gate',
                subtitle: 'Lorry GRN Receiving',
                count: '${state.truckInwards.length} Inwards',
                icon: Icons.local_shipping_outlined,
                onTap: () => ref.read(storeProvider.notifier).setActiveTab('TRUCKS'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSectionCard(
                title: 'Export Bays 3–5',
                subtitle: 'Finished Garment Vault',
                count: 'Live Stage',
                icon: Icons.inventory_2_outlined,
                onTap: () {},
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Recent Fabrics Stream
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('FABRIC STOCK SUMMARY',
                style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w800, color: kInkText, letterSpacing: 0.5)),
            InkWell(
              onTap: () => ref.read(storeProvider.notifier).setActiveTab('FABRICS'),
              child: Text('View All →',
                  style: GoogleFonts.publicSans(fontSize: 11.5, fontWeight: FontWeight.w700, color: kPrimaryBrand)),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (state.fabrics.isEmpty)
          _buildEmptyCard('No Fabric Inventory Recorded', 'Tap "+ Add Cloth Stock" to register raw fabric rolls.')
        else
          ...state.fabrics.take(4).map((f) => _buildFabricCard(f)),

        const SizedBox(height: 16),

        // Recent Issues Stream
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('RECENT MATERIAL DISPATCHES',
                style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w800, color: kInkText, letterSpacing: 0.5)),
            InkWell(
              onTap: () => ref.read(storeProvider.notifier).setActiveTab('ISSUES'),
              child: Text('View All →',
                  style: GoogleFonts.publicSans(fontSize: 11.5, fontWeight: FontWeight.w700, color: kPrimaryBrand)),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (state.issues.isEmpty)
          _buildEmptyCard('No Material Issues Logged', 'Tap "+ Issue Challan" to send fabrics or trims to production lines.')
        else
          ...state.issues.take(4).map((i) => _buildIssueCard(i)),
      ],
    );
  }

  // ----------------------------------------------------
  // FABRICS LIST TAB
  // ----------------------------------------------------
  Widget _buildFabricsList(StoreState state) {
    final list = state.filteredFabrics;
    if (list.isEmpty) {
      return _buildEmptyCard('No Matching Fabrics Found', 'Try adjusting your search query or filter chips.');
    }

    return Column(
      children: list.map((f) => _buildFabricCard(f)).toList(),
    );
  }

  // ----------------------------------------------------
  // ISSUES LIST TAB
  // ----------------------------------------------------
  Widget _buildIssuesList(StoreState state) {
    final list = state.filteredIssues;
    if (list.isEmpty) {
      return _buildEmptyCard('No Material Issues Found', 'No issue challans match your search query.');
    }

    return Column(
      children: list.map((i) => _buildIssueCard(i)).toList(),
    );
  }

  // ----------------------------------------------------
  // RECEIPTS LIST TAB
  // ----------------------------------------------------
  Widget _buildReceiptsList(StoreState state) {
    final list = state.receipts;
    if (list.isEmpty) {
      return _buildEmptyCard('No Module Receipts Found', 'Materials acknowledged across factory floors will appear here.');
    }

    return Column(
      children: list.map((r) => _buildReceiptCard(r)).toList(),
    );
  }

  // ----------------------------------------------------
  // TRUCKS LIST TAB
  // ----------------------------------------------------
  Widget _buildTrucksList(StoreState state) {
    final list = state.filteredTrucks;
    if (list.isEmpty) {
      return _buildEmptyCard('No Truck Inwards Logged', 'Lorry delivery slips and GRN receipts will appear here.');
    }

    return Column(
      children: list.map((t) => _buildTruckCard(t)).toList(),
    );
  }

  Widget _buildReceiptCard(CentralMaterialReceiptModel r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorderColor),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                r.divisionCode,
                style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800, color: kInkText),
              ),
              const SizedBox(height: 2),
              Text(
                'Received: ${r.receiptDate}',
                style: GoogleFonts.publicSans(fontSize: 11, color: kMutedText),
              ),
            ],
          ),
          Text(
            '${r.receivedQuantity.toStringAsFixed(0)} ${r.unit}',
            style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFF047857)),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // ITEM CARD BUILDERS
  // ----------------------------------------------------
  Widget _buildFabricCard(CentralFabricInventoryModel fabric) {
    final ratio = fabric.totalMeters > 0 ? (fabric.availableMeters / fabric.totalMeters).clamp(0.0, 1.0) : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorderColor),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  fabric.fabricType,
                  style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w800, color: kInkText),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: kCanvasColor,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: kBorderColor),
                ),
                child: Text(
                  fabric.rackLocation,
                  style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: kPrimaryBrand),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Color: ${fabric.color}${fabric.supplierName != null && fabric.supplierName!.isNotEmpty ? ' • Mill: ${fabric.supplierName}' : ''}',
            style: GoogleFonts.publicSans(fontSize: 12, color: kMutedText),
          ),
          const SizedBox(height: 8),

          // Stock Metrics Responsive Row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AVAILABLE',
                      style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.w800, color: const Color(0xFF047857), letterSpacing: 0.3),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${fabric.availableMeters.toStringAsFixed(0)}m free',
                      style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFF047857)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BOOKED',
                      style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.w800, color: const Color(0xFF2563EB), letterSpacing: 0.3),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${fabric.bookedMeters.toStringAsFixed(0)}m',
                      style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFF2563EB)),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'TOTAL STOCK',
                    style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.w800, color: kMutedText, letterSpacing: 0.3),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${fabric.totalMeters.toStringAsFixed(0)}m (${fabric.totalRolls}r)',
                    style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w800, color: kInkText),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 5,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(
                ratio > 0.3 ? const Color(0xFF047857) : const Color(0xFFBE123C),
              ),
            ),
          ),

          if (fabric.bookedForArticle != null && fabric.bookedForArticle!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: kBluePastelBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Allocated to Art #${fabric.bookedForArticle}',
                style: GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.bold, color: kBluePastelText),
              ),
            ),
          ],
          const SizedBox(height: 10),

          // Actions Row
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openBookFabricModal(fabric),
                  icon: const Icon(Icons.bookmark_border_rounded, size: 13, color: kPrimaryBrand),
                  label: Text('Book for Article', style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.w700, color: kPrimaryBrand)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: kBorderColor),
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _openIssueModal(
                    fabricType: fabric.fabricType,
                    color: fabric.color,
                    articleNo: fabric.bookedForArticle,
                    quantity: fabric.availableMeters > 0 ? fabric.availableMeters : fabric.totalMeters,
                    rolls: fabric.totalRolls,
                  ),
                  icon: const Icon(Icons.outbound_outlined, size: 13),
                  label: Text('Quick Issue to Floor', style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryBrand,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIssueCard(CentralMaterialIssueModel issue) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorderColor),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                issue.issueChallanNo,
                style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.w800, color: kInkText),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: issue.status == 'ACCEPTED' ? const Color(0xFFECFDF5) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: issue.status == 'ACCEPTED' ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A),
                  ),
                ),
                child: Text(
                  issue.status,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: issue.status == 'ACCEPTED' ? const Color(0xFF047857) : const Color(0xFFB45309),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Source -> Destination Flow
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                child: Text(issue.fromDivision, style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF475569))),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.arrow_forward_rounded, size: 12, color: kMutedText),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: kBluePastelBg, borderRadius: BorderRadius.circular(4)),
                child: Text(issue.toDivision, style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: kBluePastelText)),
              ),
              const Spacer(),
              Text(
                '${issue.quantity.toStringAsFixed(0)} ${issue.unit}',
                style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w800, color: kPrimaryBrand),
              ),
            ],
          ),
          const SizedBox(height: 6),

          Text(
            '${issue.fabricType ?? 'Material'} • ${issue.color ?? 'Natural'}${issue.articleNo != null ? ' • Art #${issue.articleNo}' : ''}',
            style: GoogleFonts.publicSans(fontSize: 12, color: kMutedText),
          ),
        ],
      ),
    );
  }

  Widget _buildTruckCard(TruckInwardModel truck) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorderColor),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                truck.grnNo,
                style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.w800, color: kInkText),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Text(
                  truck.status,
                  style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF047857)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            truck.partyName,
            style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: kInkText),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Lorry: ${truck.truckNo ?? 'N/A'} • Slip #${truck.challanNo ?? 'N/A'}',
                style: GoogleFonts.publicSans(fontSize: 11.5, color: kMutedText),
              ),
              Text(
                truck.inwardDate,
                style: GoogleFonts.jetBrainsMono(fontSize: 11, color: kMutedText),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required String count,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, size: 20, color: kPrimaryBrand),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: kCanvasColor, borderRadius: BorderRadius.circular(6), border: Border.all(color: kBorderColor)),
                  child: Text(count, style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.bold, color: kPrimaryBrand)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w800, color: kInkText)),
            Text(subtitle, style: GoogleFonts.publicSans(fontSize: 11, color: kMutedText)),
          ],
        ),
      ),
    );
  }


  Widget _buildWebKpiCard({
    required String label,
    required String sublabel,
    required String value,
    required String unit,
    required String badge,
    required Color badgeColor,
    required Color badgeTextColor,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kBorderColor),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 1)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: kCanvasColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kBorderColor),
                  ),
                  child: Icon(icon, size: 15, color: kPrimaryBrand),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badge,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      color: badgeTextColor,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.w800, color: kInkText, letterSpacing: 0.3),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              sublabel,
              style: GoogleFonts.publicSans(fontSize: 10.5, color: kMutedText),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: GoogleFonts.jetBrainsMono(fontSize: 19, fontWeight: FontWeight.w800, color: kInkText),
                ),
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.bold, color: kMutedText),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChainTile(String num, String title, String desc) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: kCanvasColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: kBorderColor),
            ),
            child: Text(
              num,
              style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.w800, color: kPrimaryBrand),
            ),
          ),
          const SizedBox(width: 7),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: kInkText)),
              Text(desc, style: GoogleFonts.publicSans(fontSize: 9.5, color: kMutedText)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String title,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? kPrimaryBrand : kCanvasColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isActive ? kPrimaryBrand : kBorderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isActive ? Colors.white : kMutedText),
            const SizedBox(width: 5),
            Text(
              title,
              style: GoogleFonts.publicSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: isActive ? Colors.white : kInkText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String code, String label, String currentFilter) {
    final isSelected = currentFilter == code;
    return InkWell(
      onTap: () => ref.read(storeProvider.notifier).setStatusFilter(code),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? kPrimaryBrand : kFilterChipInactive,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: GoogleFonts.publicSans(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : kMutedText,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyCard(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorderColor),
      ),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: kCanvasColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kBorderColor),
              ),
              child: const Icon(Icons.inbox_outlined, color: kMutedText, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: kInkText),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.publicSans(fontSize: 12, color: kMutedText),
            ),
          ],
        ),
      ),
    );
  }
}
