import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../providers/plant_operations_provider.dart';

class PlantStageDrilldownSheet extends ConsumerStatefulWidget {
  final PlantStageType stageType;
  final VoidCallback? onClose;

  const PlantStageDrilldownSheet({
    super.key,
    required this.stageType,
    this.onClose,
  });

  static Future<void> show(BuildContext context, PlantStageType stageType) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PlantStageDrilldownSheet(stageType: stageType),
    );
  }

  @override
  ConsumerState<PlantStageDrilldownSheet> createState() => _PlantStageDrilldownSheetState();
}

class _PlantStageDrilldownSheetState extends ConsumerState<PlantStageDrilldownSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Set<String> _expandedKeys = {};
  bool _allExpanded = false;

  @override
  void initState() {
    super.initState();
    // Expand first few items by default
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleExpanded(String key) {
    setState(() {
      if (_expandedKeys.contains(key)) {
        _expandedKeys.remove(key);
      } else {
        _expandedKeys.add(key);
      }
    });
  }

  void _setAllExpanded(bool expand, List<String> allKeys) {
    setState(() {
      _allExpanded = expand;
      if (expand) {
        _expandedKeys.addAll(allKeys);
      } else {
        _expandedKeys.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final plantDataAsync = ref.watch(plantOperationsProvider);
    final filterState = ref.watch(plantOperationsFilterProvider);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Material(
        color: const Color(0xFFFFFFFF),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.90,
          width: double.infinity,
          child: plantDataAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(color: Color(0xFF332B6B)),
              ),
            ),
            error: (err, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Color(0xFFBE123C), size: 36),
                    const SizedBox(height: 12),
                    Text('Failed to load stage breakdown: $err', textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(plantOperationsProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
            data: (data) => _buildSheetBody(context, ref, data, filterState),
          ),
        ),
      ),
    );
  }

  Widget _buildSheetBody(
    BuildContext context,
    WidgetRef ref,
    PlantOperationsData data,
    PlantOperationsFilterState filterState,
  ) {
    final stageConfig = _getStageConfig(widget.stageType, data);

    return Column(
      children: [
        // Drag Handle
        Container(
          margin: const EdgeInsets.only(top: 10, bottom: 6),
          width: 44,
          height: 4.5,
          decoration: BoxDecoration(
            color: const Color(0xFFDAD9D3),
            borderRadius: BorderRadius.circular(3),
          ),
        ),

        // Header
        _buildHeader(context, stageConfig),

        // Mini-stats row (3 equal columns)
        _buildMiniStatsRow(context, ref, data, filterState, stageConfig),

        // Search Filter Bar
        _buildSearchBar(),

        const Divider(height: 1, color: Color(0xFFECECE8)),

        // Scrollable List Content
        Expanded(
          child: RefreshIndicator(
            color: const Color(0xFF332B6B),
            onRefresh: () async {
              ref.invalidate(plantOperationsProvider);
            },
            child: _buildStageContent(context, data, stageConfig),
          ),
        ),

        // Sticky Footer
        _buildStickyFooter(context),
      ],
    );
  }

  // =========================================================
  // HEADER
  // =========================================================
  Widget _buildHeader(BuildContext context, _StageConfig cfg) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stage Icon Tile
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: cfg.accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cfg.accentColor.withValues(alpha: 0.25)),
            ),
            child: Icon(cfg.icon, color: cfg.accentColor, size: 22),
          ),
          const SizedBox(width: 12),

          // Title & Badge
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: cfg.accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cfg.accentColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        cfg.stageTag,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: cfg.accentColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        cfg.title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1C1C1A),
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  cfg.description,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    color: const Color(0xFF6B6A65),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Close (X) Icon
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 22, color: Color(0xFF6B6A65)),
            onPressed: () {
              if (widget.onClose != null) {
                widget.onClose!();
              } else {
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
    );
  }

  // =========================================================
  // MINI-STATS ROW (3 EQUAL COLUMNS)
  // =========================================================
  Widget _buildMiniStatsRow(
    BuildContext context,
    WidgetRef ref,
    PlantOperationsData data,
    PlantOperationsFilterState filterState,
    _StageConfig cfg,
  ) {
    final brandLabel = filterState.selectedBrand == 'ALL'
        ? 'All Brands'
        : (filterState.selectedBrand == 'DIRECT' ? 'Direct Floor' : filterState.selectedBrand);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAF8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFECECE8)),
      ),
      child: Row(
        children: [
          // 1. Stage Volume
          Expanded(
            child: Column(
              children: [
                Text(
                  'STAGE VOLUME',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF9B9A94),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${NumberFormat('#,##,###').format(cfg.volume)} pcs',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1C1C1A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          Container(width: 1, height: 28, color: const Color(0xFFECECE8)),

          // 2. Filter Brand (Tappable)
          Expanded(
            child: InkWell(
              onTap: () => _openBrandPickerModal(context, ref, data, filterState),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'FILTER BRAND',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF9B9A94),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(Icons.keyboard_arrow_down_rounded, size: 12, color: Color(0xFF9B9A94)),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      brandLabel,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF332B6B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),

          Container(width: 1, height: 28, color: const Color(0xFFECECE8)),

          // 3. Active Records Count
          Expanded(
            child: Column(
              children: [
                Text(
                  'ACTIVE RECORDS',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF9B9A94),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  cfg.recordsLabel,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1C1C1A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openBrandPickerModal(
    BuildContext context,
    WidgetRef ref,
    PlantOperationsData data,
    PlantOperationsFilterState filterState,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Filter by Brand',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1C1C1A),
                  ),
                ),
                const SizedBox(height: 12),
                ...data.brandTabs.map((brand) {
                  final isSel = filterState.selectedBrand.toUpperCase() == brand.toUpperCase();
                  final title = brand == 'ALL' ? 'All Brands' : (brand == 'DIRECT' ? 'Direct Floor Lots' : brand);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                        color: isSel ? const Color(0xFF332B6B) : const Color(0xFF1C1C1A),
                      ),
                    ),
                    trailing: isSel ? const Icon(Icons.check_rounded, color: Color(0xFF332B6B), size: 20) : null,
                    onTap: () {
                      ref.read(plantOperationsFilterProvider.notifier).state =
                          filterState.copyWith(selectedBrand: brand);
                      Navigator.pop(ctx);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  // =========================================================
  // SEARCH FILTER BAR
  // =========================================================
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAF8),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFDAD9D3)),
        ),
        child: Row(
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 10, right: 6),
              child: Icon(Icons.search_rounded, size: 18, color: Color(0xFF9B9A94)),
            ),
            Expanded(
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF1C1C1A)),
                decoration: const InputDecoration(
                  hintText: 'Filter by art no, lineman, challan, batch...',
                  hintStyle: TextStyle(fontSize: 12, color: Color(0xFF9B9A94)),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            if (_searchQuery.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF9B9A94)),
                onPressed: () {
                  _searchController.clear();
                },
              ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // STAGE CONTENT SWITCHER
  // =========================================================
  Widget _buildStageContent(
    BuildContext context,
    PlantOperationsData data,
    _StageConfig cfg,
  ) {
    switch (widget.stageType) {
      case PlantStageType.goodsInLine:
        return _buildGoodsInLineContent(context, data, cfg);
      case PlantStageType.totalStocks:
        return _buildTotalStocksContent(context, data, cfg);
      case PlantStageType.mendingChecking:
        return _buildMendingCheckingContent(context, data, cfg);
      case PlantStageType.readyGoods:
        return _buildReadyGoodsContent(context, data, cfg);
      case PlantStageType.rto:
        return _buildRtoContent(context, data, cfg);
      case PlantStageType.readyDelivery:
        return _buildReadyDeliveryContent(context, data, cfg);
    }
  }

  // =========================================================
  // 1. GOODS IN LINE: LINEMAN GROUP CARDS (MAIN DRILLDOWN)
  // =========================================================
  Widget _buildGoodsInLineContent(
    BuildContext context,
    PlantOperationsData data,
    _StageConfig cfg,
  ) {
    // Filter lineman groups by search query
    final filteredGroups = data.linemanGroups.where((g) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery;
      final matchName = g.name.toLowerCase().contains(q);
      final matchArt = g.articleNumbers.any((a) => a.toLowerCase().contains(q));
      final matchLot = g.allotments.any((al) =>
          (al.challanNo?.toLowerCase().contains(q) ?? false) ||
          (al.brand?.toLowerCase().contains(q) ?? false));
      return matchName || matchArt || matchLot;
    }).toList();

    if (filteredGroups.isEmpty) {
      return _buildEmptyState(
        icon: Icons.tune_rounded,
        title: 'No Active Sewing Lots on Floor',
        subtitle: 'No linemen currently have active sewing allotments running on the factory floor.',
      );
    }

    final allKeys = filteredGroups.map((g) => g.key).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // List Header Toolbar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.people_alt_outlined, size: 16, color: Color(0xFF332B6B)),
                const SizedBox(width: 6),
                Text(
                  '${filteredGroups.length} ${filteredGroups.length == 1 ? "lineman active" : "linemen active"}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1C1C1A),
                  ),
                ),
              ],
            ),
            InkWell(
              onTap: () => _setAllExpanded(!_allExpanded, allKeys),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  _allExpanded ? 'Collapse all' : 'Expand all',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF332B6B),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Lineman Cards List
        ...filteredGroups.map((group) {
          final isExpanded = _allExpanded || _expandedKeys.contains(group.key);
          return _buildLinemanGroupCard(context, group, data, isExpanded, cfg);
        }),
      ],
    );
  }

  Widget _buildLinemanGroupCard(
    BuildContext context,
    PlantLinemanGroup group,
    PlantOperationsData data,
    bool isExpanded,
    _StageConfig cfg,
  ) {
    final initials = group.name.isNotEmpty
        ? group.name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
        : 'LM';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAF8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDAD9D3), width: 0.9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main Lineman Header Row (Tappable)
          InkWell(
            onTap: () => _toggleExpanded(group.key),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar circle
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDEAF6),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF332B6B).withValues(alpha: 0.2)),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          initials,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF332B6B),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Name + Lot count badge
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    group.name,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF1C1C1A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEDEAF6),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFF332B6B).withValues(alpha: 0.2)),
                                  ),
                                  child: Text(
                                    '${group.allotments.length} lots',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF332B6B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),

                            // Wrapped Row of Article Chips (collapsible)
                            _buildArticleChipsRow(group.articleNumbers, isExpanded),
                          ],
                        ),
                      ),

                      // Right-Aligned Total Pcs + Stage Status Tag
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${NumberFormat('#,##,###').format(group.totalPcs)} pcs',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF1C1C1A),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE9F7EE),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: const Color(0xFF2FAE66).withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              'IN SEWING',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1B7A43),
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Bottom Caption Line with Estimated Wage
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Active on sewing machines • Est. wage: ₹${NumberFormat('#,##,###').format(group.totalWage.toInt())}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1B7A43),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: const Color(0xFF6B6A65),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Expanded Per-Lot Cards
          if (isExpanded)
            Container(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Column(
                children: [
                  const Divider(height: 1, color: Color(0xFFECECE8)),
                  const SizedBox(height: 8),
                  ...group.allotments.map((al) => _buildIndividualLotCard(context, al, data)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildArticleChipsRow(List<String> articleNumbers, bool isExpanded) {
    if (articleNumbers.isEmpty) return const SizedBox.shrink();

    final showCount = isExpanded ? articleNumbers.length : 3;
    final displayed = articleNumbers.take(showCount).toList();
    final remaining = articleNumbers.length - showCount;

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        ...displayed.map((artNo) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFDAD9D3)),
              ),
              child: Text(
                'Art $artNo',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1C1C1A),
                ),
              ),
            )),
        if (remaining > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: const Color(0xFFECECE8),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '+$remaining more',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF6B6A65),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildIndividualLotCard(BuildContext context, PlantAllotmentItem al, PlantOperationsData data) {
    final lotVariants = data.variants.where((v) => v['allotment_id']?.toString() == al.id).toList();
    final art = data.articles.where((a) => a.id == al.articleId).firstOrNull;

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFECECE8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'Art ${al.articleNo}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1C1C1A),
                    ),
                  ),
                  if (al.challanNo != null && al.challanNo!.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFAF8),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFDAD9D3)),
                      ),
                      child: Text(
                        al.challanNo!.startsWith('JOB-') ? al.challanNo! : 'JOB-${al.challanNo}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF6B6A65),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                '${NumberFormat('#,##,###').format(al.targetQty)} pcs',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF1C1C1A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Date & Stitching Rate
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Allotted: ${al.allotmentDate ?? al.createdAt.toString().split(' ')[0]}',
                style: const TextStyle(fontSize: 10, color: Color(0xFF9B9A94)),
              ),
              if (art != null)
                Text(
                  'Rate: ₹${art.stitchingRate.toStringAsFixed(0)}/pc',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF6B6A65)),
                ),
            ],
          ),

          // Variant Color x Size Table (if variants present)
          if (lotVariants.isNotEmpty) ...[
            const SizedBox(height: 6),
            _buildVariantMatrix(lotVariants),
          ],
        ],
      ),
    );
  }

  // =========================================================
  // COLOR X SIZE VARIANT MATRIX COMPONENT
  // =========================================================
  Widget _buildVariantMatrix(List<Map<String, dynamic>> variants) {
    final Set<String> sizesSet = {};
    final Map<String, Map<String, int>> matrix = {};

    for (var v in variants) {
      final color = (v['color']?.toString() ?? 'Standard').trim().toUpperCase();
      final size = (v['size']?.toString() ?? 'STD').trim().toUpperCase();
      final qty = (v['quantity'] as num?)?.toInt() ?? 0;
      sizesSet.add(size);
      matrix.putIfAbsent(color, () => {})[size] = (matrix[color]?[size] ?? 0) + qty;
    }

    final sortedSizes = sizesSet.toList();

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAF8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFECECE8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.layers_outlined, size: 13, color: Color(0xFF332B6B)),
              const SizedBox(width: 4),
              Text(
                'Color × Size Breakdown',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF332B6B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDEAF6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 80,
                        alignment: Alignment.centerLeft,
                        child: const Text('COLOR', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF332B6B))),
                      ),
                      ...sortedSizes.map((s) => Container(
                            width: 44,
                            alignment: Alignment.center,
                            child: Text(s, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF332B6B))),
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                // Data Rows
                ...matrix.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 80,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            entry.key,
                            style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF1C1C1A)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        ...sortedSizes.map((s) {
                          final qty = entry.value[s] ?? 0;
                          return Container(
                            width: 44,
                            alignment: Alignment.center,
                            child: Text(
                              qty > 0 ? '$qty' : '-',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: qty > 0 ? FontWeight.w800 : FontWeight.normal,
                                color: qty > 0 ? const Color(0xFF1C1C1A) : const Color(0xFFDAD9D3),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // 2. TOTAL STOCKS DRILLDOWN CONTENT
  // =========================================================
  Widget _buildTotalStocksContent(BuildContext context, PlantOperationsData data, _StageConfig cfg) {
    final list = data.filteredAllotments.where((al) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery;
      return al.articleNo.toLowerCase().contains(q) ||
          (al.challanNo?.toLowerCase().contains(q) ?? false) ||
          (al.brand?.toLowerCase().contains(q) ?? false) ||
          al.linemanName.toLowerCase().contains(q);
    }).toList();

    if (list.isEmpty) {
      return _buildEmptyState(
        icon: Icons.warehouse_rounded,
        title: 'No Orders in Active Pipeline',
        subtitle: 'There are no production orders or buyer challans matching current filters.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, idx) {
        final al = list[idx];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAF8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFDAD9D3), width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'Art ${al.articleNo}',
                        style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800),
                      ),
                      if (al.challanNo != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFDAD9D3)),
                          ),
                          child: Text('JOB-${al.challanNo}', style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    '${NumberFormat('#,##,###').format(al.targetQty)} pcs',
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Lineman: ${al.linemanName}', style: const TextStyle(fontSize: 11, color: Color(0xFF6B6A65))),
                  Text(al.status, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF332B6B))),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // =========================================================
  // 3. MENDING & CHECKING DRILLDOWN CONTENT
  // =========================================================
  Widget _buildMendingCheckingContent(BuildContext context, PlantOperationsData data, _StageConfig cfg) {
    final mendingLots = data.filteredAllotments.where((al) =>
        al.status != 'CANCELLED' &&
        (al.mendingStatus == 'PENDING_MENDING' ||
            al.mendingStatus == 'IN_MENDING' ||
            (al.status == 'COMPLETED' && (al.qcStatus == null || al.qcStatus == 'PENDING_STITCHING')))).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // Section: Mending Department Floor Lots
        Row(
          children: [
            const Icon(Icons.check_box_outlined, size: 16, color: Color(0xFFEF9F27)),
            const SizedBox(width: 6),
            Text(
              'Mending Floor Lots (${mendingLots.length})',
              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 8),

        ...mendingLots.map((al) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAF8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFDAD9D3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Art ${al.articleNo}', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800)),
                      Text('${NumberFormat('#,##,###').format(al.targetQty)} pcs', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w900)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'From: ${al.handedToMendingBy ?? al.linemanName} ➔ To: ${al.mendingSupervisorName ?? "Mending Floor"}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF6B6A65)),
                  ),
                ],
              ),
            )),

        const SizedBox(height: 16),

        // Section: QC Defects Table
        if (data.qcLogs.isNotEmpty) ...[
          Row(
            children: [
              const Icon(Icons.shield_outlined, size: 16, color: Color(0xFFBE123C)),
              const SizedBox(width: 6),
              Text(
                'QC Alteration & Defect Logs (${data.qcLogs.length})',
                style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...data.qcLogs.map((q) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBE123C).withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Art ${q.articleNo}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                        Text(q.defectType ?? 'Alteration required', style: const TextStyle(fontSize: 11, color: Color(0xFFBE123C))),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${q.qtyRejected} pcs Defect', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFFBE123C))),
                        Text('${q.qtyPassed} pcs Passed', style: const TextStyle(fontSize: 10, color: Color(0xFF1B7A43))),
                      ],
                    ),
                  ],
                ),
              )),
        ],
      ],
    );
  }

  // =========================================================
  // 4. READY GOODS DRILLDOWN CONTENT
  // =========================================================
  Widget _buildReadyGoodsContent(BuildContext context, PlantOperationsData data, _StageConfig cfg) {
    final inwardStore = data.storeTransactions.where((s) => s.type == 'INWARD').toList();

    if (inwardStore.isEmpty) {
      return _buildEmptyState(
        icon: Icons.inventory_2_rounded,
        title: 'No Godown Receipts Logged',
        subtitle: 'Finished garments will appear here once QC checking inwards them to godown.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: inwardStore.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, idx) {
        final s = inwardStore[idx];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAF8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFDAD9D3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Art ${s.articleNo}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  Text('${s.partyName ?? "Godown Inward"} • ${s.entryDate ?? s.createdAt.toString().split(' ')[0]}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF6B6A65))),
                ],
              ),
              Text(
                '+${NumberFormat('#,##,###').format(s.quantity)} pcs',
                style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w900, color: const Color(0xFF1B7A43)),
              ),
            ],
          ),
        );
      },
    );
  }

  // =========================================================
  // 5. RTO DRILLDOWN CONTENT
  // =========================================================
  Widget _buildRtoContent(BuildContext context, PlantOperationsData data, _StageConfig cfg) {
    final rtoStore = data.storeTransactions.where((s) => s.type == 'RTO' || s.type == 'REJECT' || s.type == 'RETURN').toList();

    if (rtoStore.isEmpty) {
      return _buildEmptyState(
        icon: Icons.check_circle_outline,
        title: 'Zero RTO Rejections!',
        subtitle: 'No lots have been returned to origin. All manufactured consignments accepted.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: rtoStore.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, idx) {
        final r = rtoStore[idx];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1F2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFBE123C).withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Art ${r.articleNo}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  Text(r.partyName ?? 'Defective Consignment', style: const TextStyle(fontSize: 11, color: Color(0xFF6B6A65))),
                ],
              ),
              Text(
                '${r.quantity} pcs',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFBE123C)),
              ),
            ],
          ),
        );
      },
    );
  }

  // =========================================================
  // 6. READY DELIVERY DRILLDOWN CONTENT
  // =========================================================
  Widget _buildReadyDeliveryContent(BuildContext context, PlantOperationsData data, _StageConfig cfg) {
    if (data.dispatches.isEmpty) {
      return _buildEmptyState(
        icon: Icons.local_shipping_rounded,
        title: 'No Dispatches Logged',
        subtitle: 'Gate pass delivery challans generated in Dispatch will appear here.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: data.dispatches.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, idx) {
        final d = data.dispatches[idx];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAF8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFDAD9D3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Challan #${d.challanNo}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  Text('${d.buyerName ?? "Buyer"} • ${d.status}', style: const TextStyle(fontSize: 11, color: Color(0xFF6B6A65))),
                ],
              ),
              Text(
                '${NumberFormat('#,##,###').format(d.totalPieces)} pcs',
                style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w900, color: const Color(0xFF332B6B)),
              ),
            ],
          ),
        );
      },
    );
  }

  // =========================================================
  // EMPTY STATE COMPONENT
  // =========================================================
  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFAF8),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFECECE8)),
                      ),
                      child: Icon(icon, size: 24, color: const Color(0xFF9B9A94)),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1C1C1A),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF6B6A65)),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // =========================================================
  // STICKY FOOTER
  // =========================================================
  Widget _buildStickyFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFFFFFFF),
        border: Border(top: BorderSide(color: Color(0xFFECECE8), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              'Stage breakdown synchronized with live MES database',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF9B9A94),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF332B6B),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () {
              if (widget.onClose != null) {
                widget.onClose!();
              } else {
                Navigator.pop(context);
              }
            },
            child: Text(
              'Close',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // HELPER: STAGE CONFIGURATION
  // =========================================================
  _StageConfig _getStageConfig(PlantStageType type, PlantOperationsData data) {
    final m = data.metrics;
    switch (type) {
      case PlantStageType.totalStocks:
        return _StageConfig(
          stageTag: 'STAGE 01',
          title: 'Total stocks (Order pipeline)',
          description: 'Committed production orders, buyer challans & floor targets',
          icon: Icons.warehouse_rounded,
          accentColor: const Color(0xFF332B6B),
          volume: m.totalStocks,
          recordsLabel: '${data.filteredAllotments.length} Orders',
        );
      case PlantStageType.goodsInLine:
        return _StageConfig(
          stageTag: 'STAGE 02',
          title: 'Goods in line (Sewing WIP)',
          description: 'Active sewing machine batches being stitched by lineman',
          icon: Icons.tune_rounded,
          accentColor: const Color(0xFF6E5CD1),
          volume: m.goodsInLine,
          recordsLabel: '${data.linemanGroups.length} Linemen',
        );
      case PlantStageType.mendingChecking:
        return _StageConfig(
          stageTag: 'STAGE 03',
          title: 'Mending & checking (QC Table)',
          description: 'Defect tagged pieces, alteration logs, and finishing table',
          icon: Icons.check_box_outlined,
          accentColor: const Color(0xFFEF9F27),
          volume: m.mendingChecking,
          recordsLabel: '${data.qcLogs.length + m.mendingFloorCount} Records',
        );
      case PlantStageType.readyGoods:
        return _StageConfig(
          stageTag: 'STAGE 04',
          title: 'Ready goods (Godown stock)',
          description: '100% QC passed finished garments packed in godown storage',
          icon: Icons.inventory_2_rounded,
          accentColor: const Color(0xFF2FAE66),
          volume: m.readyGoods,
          recordsLabel: '${data.storeTransactions.where((s) => s.type == "INWARD").length} Receipts',
        );
      case PlantStageType.rto:
        return _StageConfig(
          stageTag: 'STAGE 05',
          title: 'RTO & rejection (Defects)',
          description: 'Defects returned to origin and supplier rejections',
          icon: Icons.assignment_return_rounded,
          accentColor: const Color(0xFFBE123C),
          volume: m.rto,
          recordsLabel: '${data.storeTransactions.where((s) => s.type == "RTO" || s.type == "REJECT").length} Returns',
        );
      case PlantStageType.readyDelivery:
        return _StageConfig(
          stageTag: 'STAGE 06',
          title: 'Ready for delivery (Dispatch bay)',
          description: 'Dispatched consignments, delivery challans & gate passes',
          icon: Icons.local_shipping_rounded,
          accentColor: const Color(0xFF332B6B),
          volume: m.readyDelivery,
          recordsLabel: '${data.dispatches.length} Challans',
        );
    }
  }
}

class _StageConfig {
  final String stageTag;
  final String title;
  final String description;
  final IconData icon;
  final Color accentColor;
  final int volume;
  final String recordsLabel;

  _StageConfig({
    required this.stageTag,
    required this.title,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.volume,
    required this.recordsLabel,
  });
}
