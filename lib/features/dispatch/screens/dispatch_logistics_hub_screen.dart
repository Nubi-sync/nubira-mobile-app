import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/widgets/zigza_app_bar.dart';
import '../../modules/widgets/workspace_hub_drawer.dart';
import '../models/dispatch_models.dart';
import '../providers/dispatch_provider.dart';
import '../widgets/create_delivery_challan_modal.dart';
import '../widgets/record_counting_modal.dart';
import '../widgets/challan_details_modal.dart';

class DispatchLogisticsHubScreen extends ConsumerStatefulWidget {
  const DispatchLogisticsHubScreen({super.key});

  @override
  ConsumerState<DispatchLogisticsHubScreen> createState() => _DispatchLogisticsHubScreenState();
}

class _DispatchLogisticsHubScreenState extends ConsumerState<DispatchLogisticsHubScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchCtrl = TextEditingController();

  // Design Tokens (Industrial Luxury Aesthetic - Fixed Palette)
  static const Color kCanvasColor = Color(0xFFFAF7F0); // Warm cream canvas
  static const Color kCardBg = Color(0xFFFFFFFF);
  static const Color kPrimaryBrand = Color(0xFF3A3564); // Primary brand plum
  static const Color kBorderColor = Color(0xFFE7E1D6); // Hairline border
  static const Color kMutedText = Color(0xFF7A7488); // Muted text
  static const Color kInkText = Color(0xFF232028); // Primary ink text
  static const Color kBluePastelBg = Color(0xFFE5EDF9); // Blue pastel bg
  static const Color kBluePastelText = Color(0xFF2E5AA8); // Blue pastel text
  static const Color kFilterChipInactiveBg = Color(0xFFEEF1F8); // Inactive filter chip
  static const Color kSearchInputBg = Color(0xFFF6F8FC); // Search input bg

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openCreateChallanModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const CreateDeliveryChallanModal(),
    );
  }

  void _openRecordCountingModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const RecordCountingModal(),
    );
  }

  void _openChallanDetailsModal(DeliveryChallanModel challan) {
    showDialog(
      context: context,
      builder: (ctx) => ChallanDetailsModal(challan: challan),
    );
  }

  void _exportCSV(DispatchState state) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Exporting ${state.activeTab == 'challans' ? 'Delivery Challans (${state.filteredChallans.length})' : 'Counting Audits (${state.filteredCounting.length})'} as CSV...',
        ),
        backgroundColor: kPrimaryBrand,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dispatchProvider);
    final filteredChallans = state.filteredChallans;
    final filteredCounting = state.filteredCounting;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: kCanvasColor,
      drawer: const WorkspaceHubDrawer(activeRoute: '/dispatch'),
      appBar: ZigzaAppBar(
        onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      body: RefreshIndicator(
        color: kPrimaryBrand,
        backgroundColor: kCardBg,
        onRefresh: () async {
          await ref.read(dispatchProvider.notifier).fetchDispatchData();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ==========================================
              // a. Breadcrumb Row
              // ==========================================
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
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
                        const SizedBox(width: 6),
                        const Text('/', style: TextStyle(color: kBorderColor, fontSize: 12)),
                        const SizedBox(width: 6),
                        Text(
                          '12. Dispatch & Logistics Hub',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: kInkText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: kBluePastelBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: kBluePastelText.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      state.organizationName,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: kBluePastelText,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ==========================================
              // b. Module Card
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
                      blurRadius: 8,
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
                          child: const Icon(Icons.local_shipping_outlined, size: 22, color: kPrimaryBrand),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Dispatch & Logistics Hub',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: kInkText,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Pre-loading physical counting, delivery challans, and transport tracking.',
                                style: GoogleFonts.publicSans(
                                  fontSize: 12,
                                  color: kMutedText,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Button Row: "Record Counting" & "+ New Delivery Challan"
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _openRecordCountingModal,
                            icon: const Icon(Icons.assignment_turned_in_outlined, size: 15, color: kPrimaryBrand),
                            label: Text(
                              'Record Counting',
                              style: GoogleFonts.publicSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: kPrimaryBrand,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: kBorderColor),
                              backgroundColor: kCanvasColor,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _openCreateChallanModal,
                            icon: const Icon(Icons.add, size: 16),
                            label: Text(
                              '+ New Delivery Challan',
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
                              padding: const EdgeInsets.symmetric(vertical: 11),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Export CSV Button (on its own row, fit-to-content)
                    OutlinedButton.icon(
                      onPressed: () => _exportCSV(state),
                      icon: const Icon(Icons.download_outlined, size: 14, color: kInkText),
                      label: Text(
                        'Export CSV',
                        style: GoogleFonts.publicSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: kInkText,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: kBorderColor),
                        backgroundColor: kCardBg,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ==========================================
              // c. Stats: 2x2 Grid (Exact Web Labels & Icons)
              // ==========================================
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      label: 'TOTAL DISPATCHED',
                      value: '${state.totalDispatchedPieces}',
                      unit: 'pcs',
                      icon: Icons.local_shipping_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildStatCard(
                      label: 'DELIVERY CHALLANS',
                      value: '${state.deliveryChallansCount}',
                      unit: 'issued',
                      icon: Icons.description_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      label: 'COUNTED AUDITS',
                      value: '${state.countedAuditsPieces}',
                      unit: 'pcs',
                      icon: Icons.assignment_turned_in_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildStatCard(
                      label: 'DISCREPANCIES',
                      value: '${state.totalDiscrepancies}',
                      unit: 'mismatches',
                      icon: Icons.warning_amber_rounded,
                      isAlert: state.totalDiscrepancies > 0,
                      onTap: state.totalDiscrepancies > 0
                          ? () {
                              ref.read(dispatchProvider.notifier).setActiveTab('challans');
                              ref.read(dispatchProvider.notifier).setStatusFilter('DISCREPANCY');
                            }
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ==========================================
              // d. Tabs + Filters Card (One White Card)
              // ==========================================
              Container(
                decoration: BoxDecoration(
                  color: kCardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kBorderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Main Tabs (Horizontal Pill Row + Bottom Hairline)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildMainTab(
                              icon: Icons.description_outlined,
                              label: 'Delivery Challans Master (${state.deliveryChallans.length})',
                              isActive: state.activeTab == 'challans',
                              onTap: () {
                                ref.read(dispatchProvider.notifier).setActiveTab('challans');
                              },
                            ),
                            const SizedBox(width: 8),
                            _buildMainTab(
                              icon: Icons.assignment_turned_in_outlined,
                              label: 'Pre-Loading Counting (${state.countingReports.length})',
                              isActive: state.activeTab == 'counting',
                              onTap: () {
                                ref.read(dispatchProvider.notifier).setActiveTab('counting');
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: kBorderColor),

                    // Filter Chips (For Challans Tab) + Search Bar
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (state.activeTab == 'challans') ...[
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildFilterChip('All (${state.reconciledChallans.length})', 'ALL', state.statusFilter),
                                  const SizedBox(width: 6),
                                  _buildFilterChip(
                                    'Matched (${state.reconciledChallans.where((c) => c.reconciliationStatus == 'MATCHED').length})',
                                    'MATCHED',
                                    state.statusFilter,
                                  ),
                                  const SizedBox(width: 6),
                                  _buildFilterChip(
                                    'Discrepancy (${state.reconciledChallans.where((c) => c.reconciliationStatus == 'DISCREPANCY').length})',
                                    'DISCREPANCY',
                                    state.statusFilter,
                                    isWarning: true,
                                  ),
                                  const SizedBox(width: 6),
                                  _buildFilterChip(
                                    'Pending dispatch (${state.reconciledChallans.where((c) => c.reconciliationStatus == 'PENDING').length})',
                                    'PENDING',
                                    state.statusFilter,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],

                          // Search Bar
                          Container(
                            decoration: BoxDecoration(
                              color: kSearchInputBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: kBorderColor),
                            ),
                            child: TextField(
                              controller: _searchCtrl,
                              onChanged: (val) {
                                ref.read(dispatchProvider.notifier).setSearchQuery(val);
                              },
                              style: GoogleFonts.publicSans(fontSize: 12.5, color: kInkText),
                              decoration: InputDecoration(
                                hintText: state.activeTab == 'challans'
                                    ? 'Search challan, buyer, vehicle…'
                                    : 'Search article, color, size, remarks…',
                                hintStyle: GoogleFonts.publicSans(fontSize: 12, color: kMutedText),
                                prefixIcon: const Icon(Icons.search, size: 16, color: kMutedText),
                                suffixIcon: _searchCtrl.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.close, size: 14, color: kMutedText),
                                        onPressed: () {
                                          _searchCtrl.clear();
                                          ref.read(dispatchProvider.notifier).setSearchQuery('');
                                        },
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ==========================================
              // e. Main Content Table / Empty State Card
              // ==========================================
              if (state.activeTab == 'challans') ...[
                if (filteredChallans.isEmpty)
                  _buildEmptyStateCard(
                    icon: Icons.description_outlined,
                    title: 'No delivery challans found',
                    body: 'Created delivery challans will show up here, with automatic reconciliation against cutting and counted quantities.',
                    buttonLabel: '+ Create First Challan',
                    onButtonPressed: _openCreateChallanModal,
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredChallans.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final ch = filteredChallans[i];
                      return _buildChallanCard(ch);
                    },
                  ),
              ] else ...[
                if (filteredCounting.isEmpty)
                  _buildEmptyStateCard(
                    icon: Icons.assignment_turned_in_outlined,
                    title: 'No counting audits found',
                    body: 'Pre-loading piece and carton physical counting audits will show up here for live reconciliation.',
                    buttonLabel: 'Record Counting Audit',
                    onButtonPressed: _openRecordCountingModal,
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredCounting.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final c = filteredCounting[i];
                      return _buildCountingCard(c);
                    },
                  ),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // Pure 2x2 Stat Card Widget
  Widget _buildStatCard({
    required String label,
    required String value,
    required String unit,
    required IconData icon,
    bool isAlert = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isAlert ? const Color(0xFFFFF1F2) : kCardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isAlert ? const Color(0xFFFECDD3) : kBorderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: isAlert ? const Color(0xFFBE123C) : kMutedText,
                    letterSpacing: 0.5,
                  ),
                ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isAlert ? const Color(0xFFFFE4E6) : kCanvasColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isAlert ? const Color(0xFFFDA4AF) : kBorderColor),
                  ),
                  child: Icon(icon, size: 16, color: isAlert ? const Color(0xFFBE123C) : kPrimaryBrand),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isAlert ? const Color(0xFFBE123C) : kInkText,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: GoogleFonts.publicSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isAlert ? const Color(0xFFBE123C) : kMutedText,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Main Tab Button
  Widget _buildMainTab({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? kPrimaryBrand : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isActive ? Colors.white : kPrimaryBrand),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.publicSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isActive ? Colors.white : kInkText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Filter Chip Button
  Widget _buildFilterChip(String label, String filterKey, String currentFilter, {bool isWarning = false}) {
    final isSelected = currentFilter == filterKey;
    return InkWell(
      onTap: () {
        ref.read(dispatchProvider.notifier).setStatusFilter(filterKey);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? (isWarning ? const Color(0xFFE11D48) : kPrimaryBrand)
              : kFilterChipInactiveBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? (isWarning ? const Color(0xFFE11D48) : kPrimaryBrand) : kBorderColor,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.publicSans(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : kInkText,
          ),
        ),
      ),
    );
  }

  // Empty State Card
  Widget _buildEmptyStateCard({
    required IconData icon,
    required String title,
    required String body,
    required String buttonLabel,
    required VoidCallback onButtonPressed,
  }) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderColor),
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: kCanvasColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kBorderColor),
            ),
            child: Icon(icon, size: 24, color: kPrimaryBrand),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: kInkText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            textAlign: TextAlign.center,
            style: GoogleFonts.publicSans(
              fontSize: 12,
              color: kMutedText,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onButtonPressed,
            icon: const Icon(Icons.add, size: 16),
            label: Text(
              buttonLabel,
              style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryBrand,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            ),
          ),
        ],
      ),
    );
  }

  // Challan Card Tile
  Widget _buildChallanCard(DeliveryChallanModel ch) {
    Color reconBg;
    Color reconText;
    if (ch.reconciliationStatus == 'DISCREPANCY') {
      reconBg = const Color(0xFFFFE4E6);
      reconText = const Color(0xFFBE123C);
    } else if (ch.reconciliationStatus == 'PENDING') {
      reconBg = const Color(0xFFFEF3C7);
      reconText = const Color(0xFFB45309);
    } else {
      reconBg = const Color(0xFFD1FAE5);
      reconText = const Color(0xFF047857);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(14),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Challan No + Date + Reconciliation Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: kPrimaryBrand,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      ch.challanNo,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    ch.deliveryDate,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      color: kMutedText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: reconBg,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  ch.reconciliationLabel,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: reconText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Buyer & Destination
          Text(
            ch.buyerName,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: kInkText,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Destination: ${ch.destination ?? 'Factory Dispatch Gate'} • Truck: ${ch.vehicleNo ?? 'Direct Transport'}',
            style: GoogleFonts.publicSans(
              fontSize: 11.5,
              color: kMutedText,
            ),
          ),
          const SizedBox(height: 10),

          // Quantities Row: Cut Qty | Counted Qty | Dispatched Qty
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kBorderColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Cut: ${ch.cutQty} pcs',
                  style: GoogleFonts.jetBrainsMono(fontSize: 11, color: kMutedText),
                ),
                Text(
                  'Counted: ${ch.countedQty} pcs',
                  style: GoogleFonts.jetBrainsMono(fontSize: 11, color: kMutedText),
                ),
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.jetBrainsMono(fontSize: 11, color: kPrimaryBrand),
                    children: [
                      const TextSpan(text: 'Dispatched: '),
                      TextSpan(
                        text: '${ch.totalPieces} pcs',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Action Row
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () => _openChallanDetailsModal(ch),
                icon: const Icon(Icons.remove_red_eye_outlined, size: 14, color: kPrimaryBrand),
                label: Text(
                  'View & Gate Out',
                  style: GoogleFonts.publicSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: kPrimaryBrand,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: kBorderColor),
                  backgroundColor: kCardBg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Counting Card Tile
  Widget _buildCountingCard(CountingReportModel c) {
    final diff = c.countedQty - c.expectedQty;
    final isMatch = diff == 0;
    final isShort = diff < 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(14),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                c.articleArtNo ?? 'Art #${c.articleId.substring(0, 6)}',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: kPrimaryBrand,
                ),
              ),
              Text(
                c.entryDate,
                style: GoogleFonts.jetBrainsMono(fontSize: 11, color: kMutedText),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${c.color ?? 'Standard Color'} • Size ${c.size ?? 'Free'}',
            style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w500, color: kInkText),
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kBorderColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Counted: ${c.countedQty} pcs', style: GoogleFonts.jetBrainsMono(fontSize: 11.5, fontWeight: FontWeight.w700, color: kInkText)),
                Text('Expected: ${c.expectedQty} pcs', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: kMutedText)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isMatch
                        ? const Color(0xFFD1FAE5)
                        : isShort
                            ? const Color(0xFFFFE4E6)
                            : const Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isMatch
                        ? 'Matched'
                        : isShort
                            ? '$diff pcs short'
                            : '+$diff pcs excess',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: isMatch
                          ? const Color(0xFF047857)
                          : isShort
                              ? const Color(0xFFBE123C)
                              : const Color(0xFF1D4ED8),
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (c.remarks != null && c.remarks!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Remarks: ${c.remarks}',
              style: GoogleFonts.publicSans(fontSize: 11, color: kMutedText, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }
}
