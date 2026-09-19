import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/zigza_app_bar.dart';
import '../../modules/widgets/workspace_hub_drawer.dart';
import '../models/merchandising_models.dart';
import '../providers/merchandising_provider.dart';

class ActiveBuyersScreen extends ConsumerStatefulWidget {
  const ActiveBuyersScreen({super.key});

  @override
  ConsumerState<ActiveBuyersScreen> createState() => _ActiveBuyersScreenState();
}

class _ActiveBuyersScreenState extends ConsumerState<ActiveBuyersScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'ALL'; // 'ALL', 'LINKED', 'PENDING_LINK'

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openCreateBuyerModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _CreateBuyerBottomSheet(),
    );
  }

  void _openLinkArticleModal(ActiveBuyer buyer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _LinkArticleBottomSheet(buyer: buyer),
    );
  }

  void _openViewContractModal(ActiveBuyer buyer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ViewContractBottomSheet(
        buyer: buyer,
        onOpenLinkModal: (b) {
          Navigator.pop(ctx);
          _openLinkArticleModal(b);
        },
      ),
    );
  }

  void _confirmDeleteBuyer(ActiveBuyer buyer) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Remove Buyer Contract?',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Text(
          'Are you sure you want to remove buyer contract "${buyer.buyerName}" (${buyer.buyerCode})? This cannot be undone.',
          style: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF6B6A65)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.publicSans(color: const Color(0xFF6B6A65), fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(merchandisingProvider.notifier).deleteActiveBuyer(buyer.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Buyer contract "${buyer.buyerName}" removed')),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(merchandisingProvider);
    final buyers = state.buyers;
    final selectedBuyerId = state.selectedBuyerId;

    // Filter buyers
    final filteredBuyers = buyers.filterBuyers(_searchQuery, _statusFilter);

    // Executive Metrics
    final totalBuyersCount = buyers.length;
    final totalContractedPcs = buyers.fold<int>(0, (sum, b) => sum + b.contractedVolume);
    final linkedBuyers = buyers.where((b) => b.linkedArticleNumber != null && b.linkedArticleNumber!.isNotEmpty);
    final linkedPcs = linkedBuyers.fold<int>(0, (sum, b) => sum + b.contractedVolume);
    final totalContractValue = buyers.fold<double>(0, (sum, b) => sum + b.totalContractValue);

    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // =========================================================
              // 1. BREADCRUMB HIERARCHY TRAIL
              // =========================================================
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Text(
                      'Merchandising & Sourcing',
                      style: GoogleFonts.publicSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF9B9A94),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      '/',
                      style: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF9B9A94)),
                    ),
                  ),
                  Text(
                    'Active Buyers',
                    style: GoogleFonts.publicSans(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1C1C1A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // =========================================================
              // 2. TOP HERO HEADER CARD
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAF7F0),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0x1A000000)),
                          ),
                          child: const Icon(
                            Icons.people_outline_rounded,
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
                                'Active buyers & accounts',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF1C1C1A),
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Contracted buyer order volumes, piece-rate pricing, and tech pack article allocations',
                                style: GoogleFonts.publicSans(
                                  fontSize: 12,
                                  color: const Color(0xFF6B6A65),
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Controls Row: Refresh Button + Filled "+ Contract new buyer" Button
                    Row(
                      children: [
                        // Square Refresh Button
                        InkWell(
                          onTap: () => ref.read(merchandisingProvider.notifier).fetchMerchandisingData(),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAF7F0),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0x1A000000)),
                            ),
                            child: const Icon(
                              Icons.refresh_rounded,
                              color: Color(0xFF332B6B),
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Filled "+ Contract new buyer" Button
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF241D52),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: 0,
                            ),
                            onPressed: _openCreateBuyerModal,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.add_rounded, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  '+ Contract new buyer',
                                  style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.bold),
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
              // 3. EXECUTIVE KPI METRIC CARDS (2x2 Grid)
              // =========================================================
              Row(
                children: [
                  // KPI 1: Active Buyers
                  Expanded(
                    child: _buildKpiCard(
                      icon: Icons.apartment_rounded,
                      label: 'ACTIVE BUYERS',
                      value: totalBuyersCount.toString(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // KPI 2: Contracted Volume
                  Expanded(
                    child: _buildKpiCard(
                      icon: Icons.layers_outlined,
                      label: 'CONTRACTED VOLUME',
                      value: NumberFormat.decimalPattern('en_IN').format(totalContractedPcs),
                      unit: 'Pcs',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  // KPI 3: In Order
                  Expanded(
                    child: _buildKpiCard(
                      icon: Icons.inventory_2_outlined,
                      label: 'IN ORDER',
                      value: NumberFormat.decimalPattern('en_IN').format(linkedPcs),
                      unit: 'Pcs',
                    ),
                  ),
                  const SizedBox(width: 10),
                  // KPI 4: Total Contract Value
                  Expanded(
                    child: _buildKpiCard(
                      icon: Icons.currency_rupee_rounded,
                      label: 'TOTAL CONTRACT VALUE',
                      value: currencyFormatter.format(totalContractValue),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // =========================================================
              // 4. SEARCH BAR & FILTER TABS
              // =========================================================
              TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF6B6A65)),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF6B6A65)),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  hintText: 'Search buyers by name, code, brand, or link',
                  hintStyle: GoogleFonts.publicSans(fontSize: 12.5, color: const Color(0xFFB6B4AC)),
                  filled: true,
                  fillColor: const Color(0xFFFAFAF8),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0x1A000000)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0x1A000000)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF332B6B), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Horizontally Scrollable Filter Tabs
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterPill(
                      label: 'All buyers (${buyers.length})',
                      isSelected: _statusFilter == 'ALL',
                      onTap: () => setState(() => _statusFilter = 'ALL'),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterPill(
                      label: 'Article linked (${linkedBuyers.length})',
                      isSelected: _statusFilter == 'LINKED',
                      onTap: () => setState(() => _statusFilter = 'LINKED'),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterPill(
                      label: 'Pending link (${buyers.length - linkedBuyers.length})',
                      isSelected: _statusFilter == 'PENDING_LINK',
                      onTap: () => setState(() => _statusFilter = 'PENDING_LINK'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // =========================================================
              // 5. BUYERS LIST / EMPTY STATE
              // =========================================================
              if (filteredBuyers.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0x1A000000)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAF7F0),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0x1A000000)),
                        ),
                        child: const Icon(Icons.people_outline_rounded, color: Color(0xFF332B6B), size: 28),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'No active buyers found',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1C1C1A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        buyers.isEmpty
                            ? 'Get started by contracting your first buyer account and assigning contracted order volumes.'
                            : 'No buyers match the current search filter.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.publicSans(fontSize: 12.5, color: const Color(0xFF6B6A65), height: 1.3),
                      ),
                      if (buyers.isEmpty) ...[
                        const SizedBox(height: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF241D52),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            elevation: 0,
                          ),
                          onPressed: _openCreateBuyerModal,
                          child: Text(
                            'Contract first buyer',
                            style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredBuyers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, idx) {
                    final buyer = filteredBuyers[idx];
                    final isSelected = buyer.id == selectedBuyerId;
                    final isLinked = buyer.linkedArticleNumber != null && buyer.linkedArticleNumber!.isNotEmpty;
                    final curSym = buyer.currency == 'INR' ? '₹' : buyer.currency == 'USD' ? '\$' : buyer.currency == 'EUR' ? '€' : '£';

                    return InkWell(
                      onTap: () {
                        ref.read(merchandisingProvider.notifier).setSelectedBuyerId(buyer.id);
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          // Highlight selection with single 1.5px navy border, keep card light
                          border: Border.all(
                            color: isSelected ? const Color(0xFF241D52) : const Color(0x1A000000),
                            width: isSelected ? 1.5 : 1.0,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF241D52).withValues(alpha: 0.08),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Row 1: Avatar + Name + Style Badge + Selection Checkmark
                            Row(
                              children: [
                                // 2-letter Avatar
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFAF7F0),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0x1A000000)),
                                  ),
                                  child: Center(
                                    child: Text(
                                      buyer.buyerName.isNotEmpty
                                          ? buyer.buyerName.substring(0, buyer.buyerName.length >= 2 ? 2 : 1).toUpperCase()
                                          : 'BY',
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF332B6B),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // Buyer Name & Code
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              buyer.buyerName,
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: const Color(0xFF1C1C1A),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (buyer.brandName != null && buyer.brandName != buyer.buyerName) ...[
                                            const SizedBox(width: 6),
                                            Text(
                                              '• ${buyer.brandName}',
                                              style: GoogleFonts.publicSans(fontSize: 11, color: const Color(0xFF6B6A65)),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        buyer.buyerCode,
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF9B9A94),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Style/Article Badge
                                if (isLinked)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEDEBF9),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      buyer.linkedArticleNumber!,
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF332B6B),
                                      ),
                                    ),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFFDE68A)),
                                    ),
                                    child: Text(
                                      'Pending Link',
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF92400E),
                                      ),
                                    ),
                                  ),

                                const SizedBox(width: 8),

                                // Selection Circular Checkmark
                                if (isSelected)
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF241D52),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
                                  )
                                else
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: const Color(0x33000000)),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Row 2: Contracted Volume + Rate / pc
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFAFAF8),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${NumberFormat.decimalPattern('en_IN').format(buyer.contractedVolume)} Pcs · $curSym${buyer.pricePerPiece.toStringAsFixed(2)} / pc',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF6B6A65),
                                    ),
                                  ),
                                  Text(
                                    'Total: $curSym${NumberFormat.decimalPattern('en_IN').format(buyer.totalContractValue.round())}',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF1C1C1A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Row 3: Actions Strip
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                // Link / Change Article button
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF332B6B),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  icon: Icon(isLinked ? Icons.change_circle_outlined : Icons.link_rounded, size: 14),
                                  label: Text(
                                    isLinked ? 'Change Article' : 'Link Article',
                                    style: GoogleFonts.publicSans(fontSize: 11.5, fontWeight: FontWeight.bold),
                                  ),
                                  onPressed: () => _openLinkArticleModal(buyer),
                                ),
                                const SizedBox(width: 6),

                                // View Contract button
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF332B6B),
                                    backgroundColor: const Color(0xFFFAF7F0),
                                    side: const BorderSide(color: Color(0x1A000000)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  icon: const Icon(Icons.description_outlined, size: 13),
                                  label: Text(
                                    'View Contract',
                                    style: GoogleFonts.publicSans(fontSize: 11.5, fontWeight: FontWeight.bold),
                                  ),
                                  onPressed: () => _openViewContractModal(buyer),
                                ),
                                const SizedBox(width: 6),

                                // Delete button
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFF9B9A94)),
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                  onPressed: () => _confirmDeleteBuyer(buyer),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required IconData icon,
    required String label,
    required String value,
    String? unit,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x1A000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFFAF7F0),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0x1A000000)),
            ),
            child: Icon(icon, color: const Color(0xFF332B6B), size: 16),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF9B9A94),
              letterSpacing: 0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          RichText(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              text: value,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1C1C1A),
              ),
              children: unit != null
                  ? [
                      TextSpan(
                        text: ' $unit',
                        style: GoogleFonts.publicSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF6B6A65),
                        ),
                      ),
                    ]
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF241D52) : const Color(0xFFFAF7F0),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF241D52) : const Color(0x1A000000),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : const Color(0xFF6B6A65),
          ),
        ),
      ),
    );
  }
}

extension _BuyerFilterExt on List<ActiveBuyer> {
  List<ActiveBuyer> filterBuyers(String query, String status) {
    return where((b) {
      final q = query.trim().toLowerCase();
      final matchesSearch = q.isEmpty ||
          b.buyerName.toLowerCase().contains(q) ||
          b.buyerCode.toLowerCase().contains(q) ||
          (b.brandName != null && b.brandName!.toLowerCase().contains(q)) ||
          (b.linkedArticleNumber != null && b.linkedArticleNumber!.toLowerCase().contains(q));

      final isLinked = b.linkedArticleNumber != null && b.linkedArticleNumber!.isNotEmpty;
      final matchesStatus = status == 'ALL' ||
          (status == 'LINKED' && isLinked) ||
          (status == 'PENDING_LINK' && !isLinked);

      return matchesSearch && matchesStatus;
    }).toList();
  }
}

// ============================================================================
// MODAL 1: CONTRACT NEW BUYER BOTTOM SHEET
// ============================================================================
class _CreateBuyerBottomSheet extends ConsumerStatefulWidget {
  const _CreateBuyerBottomSheet();

  @override
  ConsumerState<_CreateBuyerBottomSheet> createState() => _CreateBuyerBottomSheetState();
}

class _CreateBuyerBottomSheetState extends ConsumerState<_CreateBuyerBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _brandController = TextEditingController();
  final _volumeController = TextEditingController(text: '5000');
  final _priceController = TextEditingController(text: '450');
  final _contactPersonController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _seasonController = TextEditingController(text: 'AW26');
  final _notesController = TextEditingController();

  String _currency = 'INR';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _brandController.dispose();
    _volumeController.dispose();
    _priceController.dispose();
    _contactPersonController.dispose();
    _contactEmailController.dispose();
    _seasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onNameChanged(String val) {
    if (_codeController.text.isEmpty || _codeController.text.startsWith('BYR-')) {
      final sanitized = val.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
      final snippet = sanitized.length >= 6 ? sanitized.substring(0, 6) : sanitized;
      _codeController.text = 'BYR-$snippet';
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    final volume = int.tryParse(_volumeController.text.trim()) ?? 0;
    final price = double.tryParse(_priceController.text.trim()) ?? 0.0;
    final total = volume * price;

    final newBuyer = ActiveBuyer(
      id: 'BYR-${DateTime.now().millisecondsSinceEpoch}',
      buyerName: _nameController.text.trim(),
      buyerCode: _codeController.text.trim().isNotEmpty
          ? _codeController.text.trim().toUpperCase()
          : 'BYR-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
      brandName: _brandController.text.trim().isNotEmpty ? _brandController.text.trim() : _nameController.text.trim(),
      contractedVolume: volume,
      pricePerPiece: price,
      totalContractValue: total,
      currency: _currency,
      contactPerson: _contactPersonController.text.trim().isNotEmpty ? _contactPersonController.text.trim() : null,
      contactEmail: _contactEmailController.text.trim().isNotEmpty ? _contactEmailController.text.trim() : null,
      targetSeason: _seasonController.text.trim().isNotEmpty ? _seasonController.text.trim() : 'AW26',
      notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      status: 'PENDING_LINK',
      createdAt: DateTime.now().toIso8601String(),
    );

    final success = await ref.read(merchandisingProvider.notifier).createActiveBuyer(newBuyer);
    setState(() => _isSubmitting = false);

    if (mounted) {
      Navigator.pop(context);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Buyer "${newBuyer.buyerName}" contracted successfully!')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vol = int.tryParse(_volumeController.text) ?? 0;
    final pr = double.tryParse(_priceController.text) ?? 0.0;
    final calcTotal = vol * pr;
    final curSym = _currency == 'INR' ? '₹' : _currency == 'USD' ? '\$' : _currency == 'EUR' ? '€' : '£';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF7F0),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0x1A000000)),
                      ),
                      child: const Icon(Icons.apartment_rounded, color: Color(0xFF332B6B), size: 20),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Contract New Active Buyer',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1C1C1A),
                          ),
                        ),
                        Text(
                          'Record volume, unit rate, and contract terms',
                          style: GoogleFonts.publicSans(fontSize: 11, color: const Color(0xFF6B6A65)),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF6B6A65)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 20, color: Color(0xFFF1F5F9)),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Field 1: Buyer Name
                    _buildLabel('BUYER / COMPANY NAME *'),
                    TextFormField(
                      controller: _nameController,
                      onChanged: _onNameChanged,
                      validator: (v) => v == null || v.trim().isEmpty ? 'Buyer name is required' : null,
                      decoration: _inputDecoration('e.g. Zara International'),
                    ),
                    const SizedBox(height: 12),

                    // Field 2: Buyer Reference Code
                    _buildLabel('BUYER REFERENCE CODE'),
                    TextFormField(
                      controller: _codeController,
                      decoration: _inputDecoration('BYR-ZARA'),
                    ),
                    const SizedBox(height: 12),

                    // Field 3: Brand / Label Name & Season
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('BRAND / LABEL NAME'),
                              TextFormField(
                                controller: _brandController,
                                decoration: _inputDecoration('e.g. Zara Man'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('TARGET SEASON'),
                              TextFormField(
                                controller: _seasonController,
                                decoration: _inputDecoration('SS27 / AW26'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Field 4: Volume, Price, Currency
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('CONTRACTED PCS *'),
                              TextFormField(
                                controller: _volumeController,
                                keyboardType: TextInputType.number,
                                onChanged: (_) => setState(() {}),
                                validator: (v) => (int.tryParse(v ?? '') ?? 0) <= 0 ? 'Enter valid volume' : null,
                                decoration: _inputDecoration('5000'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('PRICE / PC *'),
                              TextFormField(
                                controller: _priceController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                onChanged: (_) => setState(() {}),
                                validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Enter rate' : null,
                                decoration: _inputDecoration('450.00'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('CURRENCY'),
                              DropdownButtonFormField<String>(
                                value: _currency,
                                decoration: _inputDecoration(''),
                                items: const [
                                  DropdownMenuItem(value: 'INR', child: Text('INR (₹)')),
                                  DropdownMenuItem(value: 'USD', child: Text('USD (\$)')),
                                  DropdownMenuItem(value: 'EUR', child: Text('EUR (€)')),
                                  DropdownMenuItem(value: 'GBP', child: Text('GBP (£)')),
                                ],
                                onChanged: (v) => setState(() => _currency = v ?? 'INR'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Calculated Total Value Box
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF7F0),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0x1A000000)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'ESTIMATED TOTAL CONTRACT VALUE',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF6B6A65),
                            ),
                          ),
                          Text(
                            '$curSym${NumberFormat.decimalPattern('en_IN').format(calcTotal.round())}',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF332B6B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Contact Person & Email
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('CONTACT PERSON'),
                              TextFormField(
                                controller: _contactPersonController,
                                decoration: _inputDecoration('Buyer Merchandiser'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('CONTACT EMAIL'),
                              TextFormField(
                                controller: _contactEmailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: _inputDecoration('merch@buyer.com'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    _buildLabel('COMMERCIAL NOTES & TERMS'),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 2,
                      decoration: _inputDecoration('Payment terms, LC conditions, packaging instructions...'),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // Submit Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF241D52),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
              ),
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      'Save & Contract Buyer',
                      style: GoogleFonts.publicSans(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF6B6A65),
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFFB6B4AC)),
      filled: true,
      fillColor: const Color(0xFFFAFAF8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0x1A000000)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0x1A000000)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF332B6B), width: 1.5),
      ),
    );
  }
}

// ============================================================================
// MODAL 2: LINK ARTICLE BOTTOM SHEET
// ============================================================================
class _LinkArticleBottomSheet extends ConsumerStatefulWidget {
  final ActiveBuyer buyer;
  const _LinkArticleBottomSheet({required this.buyer});

  @override
  ConsumerState<_LinkArticleBottomSheet> createState() => _LinkArticleBottomSheetState();
}

class _LinkArticleBottomSheetState extends ConsumerState<_LinkArticleBottomSheet> {
  String? _selectedArticleId;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedArticleId = widget.buyer.linkedArticleId;
  }

  Future<void> _link() async {
    final state = ref.read(merchandisingProvider);
    final articles = state.techPackArticles;
    final selected = articles.where((a) => a.id == _selectedArticleId).firstOrNull;
    if (selected == null) return;

    setState(() => _isSubmitting = true);
    final success = await ref.read(merchandisingProvider.notifier).linkArticleToBuyer(
          buyerId: widget.buyer.id,
          articleNumber: selected.styleNumber,
          techPackId: selected.id,
          articleName: '${selected.category} ${selected.styleNumber}',
        );
    setState(() => _isSubmitting = false);

    if (mounted) {
      Navigator.pop(context);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Article "${selected.styleNumber}" linked to ${widget.buyer.buyerName}!')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(merchandisingProvider);
    final articles = state.techPackArticles;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF7F0),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0x1A000000)),
                    ),
                    child: const Icon(Icons.layers_outlined, color: Color(0xFF332B6B), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Link Tech Pack Article',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1C1C1A),
                        ),
                      ),
                      Text(
                        'Allocate article to ${widget.buyer.buyerName}',
                        style: GoogleFonts.publicSans(fontSize: 11, color: const Color(0xFF6B6A65)),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Color(0xFF6B6A65)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),

          Expanded(
            child: articles.isEmpty
                ? Center(
                    child: Text(
                      'No Tech Pack articles available. Create articles in Design Studio first.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF9B9A94)),
                    ),
                  )
                : ListView.separated(
                    itemCount: articles.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, idx) {
                      final art = articles[idx];
                      final isSelected = art.id == _selectedArticleId;

                      return InkWell(
                        onTap: () => setState(() => _selectedArticleId = art.id),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFEDEBF9) : const Color(0xFFFAFAF8),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF332B6B) : const Color(0x1A000000),
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0x1A000000)),
                                ),
                                child: const Icon(Icons.checkroom_outlined, size: 18, color: Color(0xFF332B6B)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      art.styleNumber,
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF1C1C1A),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${art.category} • ${art.fabricComposition}',
                                      style: GoogleFonts.publicSans(fontSize: 11, color: const Color(0xFF6B6A65)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(Icons.check_circle_rounded, color: Color(0xFF332B6B), size: 20),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF241D52),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: 0,
            ),
            onPressed: _selectedArticleId == null || _isSubmitting ? null : _link,
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Text(
                    'Confirm & Link Article',
                    style: GoogleFonts.publicSans(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// MODAL 3: VIEW CONTRACT DETAILS BOTTOM SHEET
// ============================================================================
class _ViewContractBottomSheet extends ConsumerWidget {
  final ActiveBuyer buyer;
  final Function(ActiveBuyer) onOpenLinkModal;

  const _ViewContractBottomSheet({
    required this.buyer,
    required this.onOpenLinkModal,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final curSym = buyer.currency == 'INR' ? '₹' : buyer.currency == 'USD' ? '\$' : buyer.currency == 'EUR' ? '€' : '£';
    final isLinked = buyer.linkedArticleNumber != null && buyer.linkedArticleNumber!.isNotEmpty;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF7F0),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0x1A000000)),
                    ),
                    child: const Icon(Icons.description_outlined, color: Color(0xFF332B6B), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        buyer.buyerName,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1C1C1A),
                        ),
                      ),
                      Text(
                        'Ref: ${buyer.buyerCode} • ${buyer.brandName ?? "Direct Buyer"}',
                        style: GoogleFonts.jetBrainsMono(fontSize: 10.5, color: const Color(0xFF6B6A65)),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Color(0xFF6B6A65)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Volume, Rate, Contract Value 3-up Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildTermCard(
                          'ORDERED VOLUME',
                          '${NumberFormat.decimalPattern('en_IN').format(buyer.contractedVolume)} Pcs',
                          isPrimary: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildTermCard(
                          'PRICE / PIECE',
                          '$curSym${buyer.pricePerPiece.toStringAsFixed(2)}',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildTermCard(
                          'TOTAL VALUE',
                          '$curSym${NumberFormat.decimalPattern('en_IN').format(buyer.totalContractValue.round())}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Linked Article Summary Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFAF8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x1A000000)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'ALLOCATED TECH PACK ARTICLE',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF6B6A65),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isLinked ? const Color(0xFFE9F7EE) : const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isLinked ? 'Active' : 'Action Required',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: isLinked ? const Color(0xFF1B7A43) : const Color(0xFF92400E),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (isLinked) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    buyer.linkedArticleNumber!,
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF332B6B),
                                    ),
                                  ),
                                  if (buyer.linkedArticleName != null)
                                    Text(
                                      buyer.linkedArticleName!,
                                      style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF6B6A65)),
                                    ),
                                ],
                              ),
                              TextButton(
                                onPressed: () => onOpenLinkModal(buyer),
                                child: Text(
                                  'Change',
                                  style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF332B6B)),
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          Text(
                            'No tech pack article linked yet.',
                            style: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF9B9A94)),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF332B6B),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              elevation: 0,
                            ),
                            onPressed: () => onOpenLinkModal(buyer),
                            child: const Text('Link Article Now'),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Commercial Details
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x1A000000)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'COMMERCIAL & CONTACT TERMS',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF6B6A65),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow('Buyer Code', buyer.buyerCode),
                        _buildDetailRow('Brand Label', buyer.brandName ?? '-'),
                        _buildDetailRow('Contact Person', buyer.contactPerson ?? '-'),
                        _buildDetailRow('Contact Email', buyer.contactEmail ?? '-'),
                        _buildDetailRow('Target Season', buyer.targetSeason ?? 'AW26'),
                        _buildDetailRow('Contract Status', buyer.status),
                        if (buyer.notes != null) _buildDetailRow('Notes', buyer.notes!),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Close button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF241D52),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Close Contract View'),
          ),
        ],
      ),
    );
  }

  Widget _buildTermCard(String title, String val, {bool isPrimary = false}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F0),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x1A000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 8.5,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF9B9A94),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            val,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: isPrimary ? const Color(0xFF332B6B) : const Color(0xFF1C1C1A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF6B6A65)),
          ),
          Flexible(
            child: Text(
              value,
              style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF1C1C1A)),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
