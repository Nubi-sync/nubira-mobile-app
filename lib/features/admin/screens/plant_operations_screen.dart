import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../providers/plant_operations_provider.dart';
import '../challans/challans_dashboard_screen.dart';
import '../widgets/plant_stage_drilldown_sheet.dart';
import 'admin_shell.dart';
import 'reports_screen.dart';

class PlantOperationsScreen extends ConsumerStatefulWidget {
  const PlantOperationsScreen({super.key});

  @override
  ConsumerState<PlantOperationsScreen> createState() => _PlantOperationsScreenState();
}

class _PlantOperationsScreenState extends ConsumerState<PlantOperationsScreen> {
  bool _isManualSyncing = false;

  void _triggerManualSync() async {
    setState(() => _isManualSyncing = true);
    ref.invalidate(plantOperationsProvider);
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      setState(() => _isManualSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plantDataAsync = ref.watch(plantOperationsProvider);
    final filterState = ref.watch(plantOperationsFilterProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFFFF),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: Color(0xFF1C1C1A), size: 24),
          tooltip: 'Menu',
          onPressed: () => adminScaffoldKey.currentState?.openDrawer(),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Text(
              'Zigza.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF1C1C1A),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFEDEAF6),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: const Color(0xFF332B6B).withValues(alpha: 0.2)),
              ),
              child: Text(
                'ERP MES',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF332B6B),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        actions: [
          // Live Floor Sync Pill Button
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              onTap: _triggerManualSync,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFE9F7EE),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF2FAE66).withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: _isManualSyncing ? const Color(0xFFEF9F27) : const Color(0xFF1B7A43),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _isManualSyncing ? 'Syncing...' : 'Live sync',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1B7A43),
                      ),
                    ),
                    const SizedBox(width: 4),
                    RotationTransition(
                      turns: _isManualSyncing ? const AlwaysStoppedAnimation(0.5) : const AlwaysStoppedAnimation(0),
                      child: Icon(
                        Icons.refresh_rounded,
                        size: 13,
                        color: const Color(0xFF1B7A43).withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: const Color(0xFF332B6B),
        backgroundColor: Colors.white,
        onRefresh: () async {
          ref.invalidate(plantOperationsProvider);
        },
        child: plantDataAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: Color(0xFF332B6B)),
          ),
          error: (err, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_off_rounded, color: Color(0xFFBE123C), size: 48),
                  const SizedBox(height: 14),
                  Text(
                    'Failed to sync floor operations',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1C1C1A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    err.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B6A65)),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF332B6B),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => ref.invalidate(plantOperationsProvider),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Retry Connection'),
                  ),
                ],
              ),
            ),
          ),
          data: (data) => _buildDashboardContent(context, ref, data, filterState),
        ),
      ),
    );
  }

  Widget _buildDashboardContent(
    BuildContext context,
    WidgetRef ref,
    PlantOperationsData data,
    PlantOperationsFilterState filterState,
  ) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Title Header Card
          _buildHeaderCard(),
          const SizedBox(height: 16),

          // 2. Filter Controls (Brand segmented + Article dropdown + Time chips)
          _buildFiltersSection(context, ref, data, filterState),
          const SizedBox(height: 20),

          // 3. Six-Stage Stats Grid (2 columns x 3 rows)
          _buildSixStageGrid(context, data),
          const SizedBox(height: 24),

          // 4. Live Factory Conversion Flow (2x2 Grid)
          _buildConversionFlowSection(data),
          const SizedBox(height: 24),

          // 5. Active Orders & Floor Allotments Section
          _buildActiveOrdersSection(context, ref, data),
          const SizedBox(height: 24),

          // 6. Floor Activity Stream Section
          _buildActivityStreamSection(data),
          const SizedBox(height: 24),

          // 7. Footer Audit Reports Button
          _buildFooterReportsButton(context),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ==========================================
  // 1. TITLE HEADER CARD
  // ==========================================
  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAF8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFECECE8)),
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
                  color: const Color(0xFFEDEAF6),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF332B6B).withValues(alpha: 0.15)),
                ),
                child: const Icon(
                  Icons.dashboard_rounded,
                  color: Color(0xFF332B6B),
                  size: 20,
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
                            'Plant operations control center',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1C1C1A),
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFEF9F27).withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            'MES LIVE',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF92400E),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Real-time 6-stage garment manufacturing floor throughput and inventory lifecycle',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: const Color(0xFF6B6A65),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 2. FILTERS SECTION
  // ==========================================
  Widget _buildFiltersSection(
    BuildContext context,
    WidgetRef ref,
    PlantOperationsData data,
    PlantOperationsFilterState filterState,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAF8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFECECE8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row A: "BRAND" Label + Segmented Control
          Row(
            children: [
              Text(
                'BRAND',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF9B9A94),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _buildBrandChip(
                        label: 'All orders',
                        value: 'ALL',
                        isSelected: filterState.selectedBrand == 'ALL',
                        onTap: () {
                          ref.read(plantOperationsFilterProvider.notifier).state =
                              filterState.copyWith(selectedBrand: 'ALL');
                        },
                      ),
                      _buildBrandChip(
                        label: 'Ollypop',
                        value: 'OLLYPOP',
                        isSelected: filterState.selectedBrand.toUpperCase() == 'OLLYPOP',
                        onTap: () {
                          ref.read(plantOperationsFilterProvider.notifier).state =
                              filterState.copyWith(selectedBrand: 'OLLYPOP');
                        },
                      ),
                      _buildBrandChip(
                        label: 'Direct floor lots',
                        value: 'DIRECT',
                        isSelected: filterState.selectedBrand == 'DIRECT',
                        onTap: () {
                          ref.read(plantOperationsFilterProvider.notifier).state =
                              filterState.copyWith(selectedBrand: 'DIRECT');
                        },
                      ),
                      // Any other brand tab dynamically from data
                      ...data.brandTabs
                          .where((b) => b != 'ALL' && b != 'OLLYPOP' && b != 'DIRECT')
                          .map((b) => _buildBrandChip(
                                label: b,
                                value: b,
                                isSelected: filterState.selectedBrand == b,
                                onTap: () {
                                  ref.read(plantOperationsFilterProvider.notifier).state =
                                      filterState.copyWith(selectedBrand: b);
                                },
                              )),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Row B: Article Style Dropdown Selector
          _buildArticleDropdown(context, ref, data, filterState),
          const SizedBox(height: 12),

          // Row C: Time-Range Chips Horizontal Scroll + Live sync pill
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildTimeChip(
                  label: 'Today',
                  filter: PlantDateFilter.today,
                  selectedFilter: filterState.dateFilter,
                  onTap: () => ref.read(plantOperationsFilterProvider.notifier).state =
                      filterState.copyWith(dateFilter: PlantDateFilter.today),
                ),
                _buildTimeChip(
                  label: 'This week',
                  filter: PlantDateFilter.week,
                  selectedFilter: filterState.dateFilter,
                  onTap: () => ref.read(plantOperationsFilterProvider.notifier).state =
                      filterState.copyWith(dateFilter: PlantDateFilter.week),
                ),
                _buildTimeChip(
                  label: 'This month',
                  filter: PlantDateFilter.month,
                  selectedFilter: filterState.dateFilter,
                  onTap: () => ref.read(plantOperationsFilterProvider.notifier).state =
                      filterState.copyWith(dateFilter: PlantDateFilter.month),
                ),
                _buildTimeChip(
                  label: 'All time',
                  filter: PlantDateFilter.all,
                  selectedFilter: filterState.dateFilter,
                  onTap: () => ref.read(plantOperationsFilterProvider.notifier).state =
                      filterState.copyWith(dateFilter: PlantDateFilter.all),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandChip({
    required String label,
    required String value,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF332B6B) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? const Color(0xFF332B6B) : const Color(0xFFDAD9D3),
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected ? Colors.white : const Color(0xFF6B6A65),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildArticleDropdown(
    BuildContext context,
    WidgetRef ref,
    PlantOperationsData data,
    PlantOperationsFilterState filterState,
  ) {
    String currentLabel = 'All article styles (${data.articles.length} styles)';
    if (filterState.selectedArticleId != 'ALL') {
      final found = data.articles.where((a) => a.id == filterState.selectedArticleId).firstOrNull;
      if (found != null) {
        final desc = found.description?.isNotEmpty == true ? ' • ${found.description}' : '';
        currentLabel = '${found.artNo}$desc';
      }
    }

    return InkWell(
      onTap: () => _openArticlePickerModal(context, ref, data, filterState),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFDAD9D3), width: 1),
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, size: 16, color: Color(0xFF9B9A94)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                currentLabel,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1C1C1A),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF6B6A65)),
          ],
        ),
      ),
    );
  }

  void _openArticlePickerModal(
    BuildContext context,
    WidgetRef ref,
    PlantOperationsData data,
    PlantOperationsFilterState filterState,
  ) {
    String searchQuery = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredList = data.articles.where((a) {
              if (searchQuery.isEmpty) return true;
              final q = searchQuery.toLowerCase();
              return a.artNo.toLowerCase().contains(q) || (a.description?.toLowerCase().contains(q) ?? false);
            }).toList();

            return Container(
              padding: EdgeInsets.only(
                top: 16,
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFECECE8),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select Article Style',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1C1C1A),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Search Field
                  TextField(
                    autofocus: false,
                    onChanged: (val) => setModalState(() => searchQuery = val.trim()),
                    decoration: InputDecoration(
                      hintText: 'Search by article number or style...',
                      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9B9A94)),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF9B9A94)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      filled: true,
                      fillColor: const Color(0xFFFAFAF8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFDAD9D3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFDAD9D3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF332B6B)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // List
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        // Option: All Articles
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                          dense: true,
                          title: Text(
                            'All article styles (${data.articles.length} styles)',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: filterState.selectedArticleId == 'ALL' ? FontWeight.w800 : FontWeight.w600,
                              color: filterState.selectedArticleId == 'ALL'
                                  ? const Color(0xFF332B6B)
                                  : const Color(0xFF1C1C1A),
                            ),
                          ),
                          trailing: filterState.selectedArticleId == 'ALL'
                              ? const Icon(Icons.check_rounded, color: Color(0xFF332B6B), size: 18)
                              : null,
                          onTap: () {
                            ref.read(plantOperationsFilterProvider.notifier).state =
                                filterState.copyWith(selectedArticleId: 'ALL');
                            Navigator.pop(ctx);
                          },
                        ),
                        const Divider(height: 1, color: Color(0xFFECECE8)),
                        ...filteredList.map((art) {
                          final isSel = filterState.selectedArticleId == art.id;
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                            dense: true,
                            title: Text(
                              art.artNo,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                                color: isSel ? const Color(0xFF332B6B) : const Color(0xFF1C1C1A),
                              ),
                            ),
                            subtitle: art.description?.isNotEmpty == true
                                ? Text(
                                    art.description!,
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF6B6A65)),
                                  )
                                : null,
                            trailing: isSel
                                ? const Icon(Icons.check_rounded, color: Color(0xFF332B6B), size: 18)
                                : null,
                            onTap: () {
                              ref.read(plantOperationsFilterProvider.notifier).state =
                                  filterState.copyWith(selectedArticleId: art.id);
                              Navigator.pop(ctx);
                            },
                          );
                        }),
                      ],
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

  Widget _buildTimeChip({
    required String label,
    required PlantDateFilter filter,
    required PlantDateFilter selectedFilter,
    required VoidCallback onTap,
  }) {
    final isSelected = filter == selectedFilter;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF332B6B) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? const Color(0xFF332B6B) : const Color(0xFFDAD9D3),
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected ? Colors.white : const Color(0xFF6B6A65),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 3. SIX-STAGE STATS GRID (2 Cols x 3 Rows)
  // ==========================================
  Widget _buildSixStageGrid(BuildContext context, PlantOperationsData data) {
    final m = data.metrics;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStageCard(
                context: context,
                data: data,
                stageType: PlantStageType.totalStocks,
                stageTag: 'STAGE 01',
                title: '1. Total stocks',
                subtitle: 'Order pipeline target',
                value: m.totalStocks,
                badgeLabel: 'Total pieces',
                icon: Icons.warehouse_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStageCard(
                context: context,
                data: data,
                stageType: PlantStageType.goodsInLine,
                stageTag: 'STAGE 02',
                title: '2. Goods in line',
                subtitle: 'Sewing machines WIP',
                value: m.goodsInLine,
                badgeLabel: 'On floor',
                icon: Icons.tune_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStageCard(
                context: context,
                data: data,
                stageType: PlantStageType.mendingChecking,
                stageTag: 'STAGE 03',
                title: '3. Mending & checking',
                subtitle: 'Finishing table',
                value: m.mendingChecking,
                badgeLabel: m.mendingAlterationQty > 0 ? '${m.mendingAlterationQty} Alter' : 'QC Table',
                icon: Icons.check_box_outlined,
                alterationRate: m.alterationRate,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStageCard(
                context: context,
                data: data,
                stageType: PlantStageType.readyGoods,
                stageTag: 'STAGE 04',
                title: '4. Ready goods',
                subtitle: 'QC passed & packed',
                value: m.readyGoods,
                badgeLabel: 'In godown',
                icon: Icons.inventory_2_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStageCard(
                context: context,
                data: data,
                stageType: PlantStageType.rto,
                stageTag: 'STAGE 05',
                title: '5. RTO & rejection',
                subtitle: 'Defect / reject',
                value: m.rto,
                badgeLabel: 'Defect / Reject',
                icon: Icons.assignment_return_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStageCard(
                context: context,
                data: data,
                stageType: PlantStageType.readyDelivery,
                stageTag: 'STAGE 06',
                title: '6. Ready for delivery',
                subtitle: 'Dispatched pcs',
                value: m.readyDelivery,
                badgeLabel: 'Gate pass',
                icon: Icons.local_shipping_rounded,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStageCard({
    required BuildContext context,
    required PlantOperationsData data,
    required PlantStageType stageType,
    required String stageTag,
    required String title,
    required String subtitle,
    required int value,
    required String badgeLabel,
    required IconData icon,
    double? alterationRate,
  }) {
    return InkWell(
      onTap: () => _openStageDrilldown(context, data, stageType),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAF8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFDAD9D3), width: 0.9),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Row: Icon + Stage Tag + Arrow
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDEAF6),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF332B6B).withValues(alpha: 0.15)),
                  ),
                  child: Icon(icon, color: const Color(0xFF332B6B), size: 18),
                ),
                Row(
                  children: [
                    Text(
                      stageTag,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF9B9A94),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.arrow_outward_rounded, size: 12, color: Color(0xFF9B9A94)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Title + Subtitle
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1C1C1A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (alterationRate != null && alterationRate > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFBE123C).withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      '${alterationRate.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFBE123C),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                color: const Color(0xFF6B6A65),
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),

            // Big Number + Bottom Pill
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  NumberFormat('#,##,###').format(value),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1C1C1A),
                    letterSpacing: -0.5,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFDAD9D3)),
                  ),
                  child: Text(
                    badgeLabel.toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF6B6A65),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 4. LIVE FACTORY CONVERSION FLOW (2x2 Grid)
  // ==========================================
  Widget _buildConversionFlowSection(PlantOperationsData data) {
    final m = data.metrics;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAF8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFECECE8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Live factory conversion flow',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1C1C1A),
                      ),
                    ),
                    Text(
                      'Order to gate delivery progression',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: const Color(0xFF6B6A65),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              RichText(
                text: TextSpan(
                  text: 'Target: ',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF6B6A65)),
                  children: [
                    TextSpan(
                      text: '${NumberFormat('#,##,###').format(m.totalStocks)} pcs',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1C1C1A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 2x2 Grid of Progress Cards
          Row(
            children: [
              Expanded(
                child: _buildConversionCard(
                  label: '1. Sewing in-line',
                  pct: m.inLinePct,
                  pcs: m.goodsInLine,
                  sublabel: 'On machines',
                  accentColor: const Color(0xFF6E5CD1), // Purple
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildConversionCard(
                  label: '2. Mending & check',
                  pct: m.mendingPct,
                  pcs: m.mendingChecking,
                  sublabel: 'QC table',
                  accentColor: const Color(0xFFEF9F27), // Amber
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildConversionCard(
                  label: '3. Ready godown',
                  pct: m.readyPct,
                  pcs: m.readyGoods,
                  sublabel: '100% packed',
                  accentColor: const Color(0xFF2FAE66), // Green
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildConversionCard(
                  label: '4. Dispatched out',
                  pct: m.deliveryPct,
                  pcs: m.readyDelivery,
                  sublabel: 'Gate pass',
                  accentColor: const Color(0xFF332B6B), // Indigo
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConversionCard({
    required String label,
    required int pct,
    required int pcs,
    required String sublabel,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDAD9D3), width: 0.8),
      ),
      child: Stack(
        children: [
          // Left Border Strip
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 3.5,
            child: Container(
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF6B6A65),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$pct%',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      NumberFormat('#,##,###').format(pcs),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1C1C1A),
                      ),
                    ),
                    Text(
                      sublabel,
                      style: const TextStyle(fontSize: 8.5, color: Color(0xFF9B9A94)),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                // Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: pct / 100.0,
                    minHeight: 3.5,
                    backgroundColor: const Color(0xFFECECE8),
                    valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 5. ACTIVE ORDERS & FLOOR ALLOTMENTS SECTION
  // ==========================================
  Widget _buildActiveOrdersSection(
    BuildContext context,
    WidgetRef ref,
    PlantOperationsData data,
  ) {
    final activeOrders = data.filteredAllotments.take(6).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Active orders & floor allotments',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1C1C1A),
                    ),
                  ),
                  Text(
                    'Live status of multi-article challans and assigned linemen',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: const Color(0xFF6B6A65),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChallansDashboardScreen()),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  children: [
                    Text(
                      'View all',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF332B6B),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF332B6B)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (activeOrders.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAF8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFECECE8)),
            ),
            child: Center(
              child: Text(
                'No active allotments match the selected filters.',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF9B9A94)),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: activeOrders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final al = activeOrders[index];
              return _buildOrderCard(context, al);
            },
          ),
      ],
    );
  }

  Widget _buildOrderCard(BuildContext context, PlantAllotmentItem al) {
    final statusColor = al.status == 'COMPLETED' || al.status == 'QC_PASSED'
        ? const Color(0xFF2FAE66)
        : (al.status == 'PENDING' ? const Color(0xFFEF9F27) : const Color(0xFF332B6B));

    final statusBg = al.status == 'COMPLETED' || al.status == 'QC_PASSED'
        ? const Color(0xFFE9F7EE)
        : (al.status == 'PENDING' ? const Color(0xFFFEF3C7) : const Color(0xFFEDEAF6));

    final challanRef = al.challanNo != null && al.challanNo!.isNotEmpty
        ? (al.challanNo!.startsWith('JOB-') ? al.challanNo! : 'JOB-${al.challanNo}')
        : 'Direct floor';

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
          // Row 1: Article + Category & Challan Reference + Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${al.articleNo}${al.articleDescription?.isNotEmpty == true ? " - ${al.articleDescription}" : ""}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1C1C1A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: const Color(0xFFDAD9D3)),
                      ),
                      child: Text(
                        challanRef,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF6B6A65),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  al.status,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Row 2: Assigned Lineman (left) & Target Pcs (right, bold)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.person_outline_rounded, size: 14, color: Color(0xFF6B6A65)),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        al.linemanName,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF6B6A65),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              RichText(
                text: TextSpan(
                  text: 'Target: ',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF9B9A94)),
                  children: [
                    TextSpan(
                      text: '${NumberFormat('#,##,###').format(al.targetQty)} pcs',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF1C1C1A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 6. FLOOR ACTIVITY STREAM SECTION
  // ==========================================
  Widget _buildActivityStreamSection(PlantOperationsData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.history_rounded, size: 18, color: Color(0xFF1C1C1A)),
            const SizedBox(width: 6),
            Text(
              'Floor activity stream',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1C1C1A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (data.activities.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAF8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFECECE8)),
            ),
            child: const Center(
              child: Text(
                'No recent floor activity recorded.',
                style: TextStyle(fontSize: 12, color: Color(0xFF9B9A94)),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: data.activities.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final act = data.activities[index];
              return _buildActivityTile(act);
            },
          ),
      ],
    );
  }

  Widget _buildActivityTile(PlantActivityItem act) {
    IconData iconData;
    Color iconColor;
    Color iconBg;

    switch (act.type) {
      case 'PRODUCTION':
        iconData = Icons.content_cut_rounded;
        iconColor = const Color(0xFF332B6B);
        iconBg = const Color(0xFFEDEAF6);
        break;
      case 'QC':
        iconData = Icons.verified_outlined;
        iconColor = const Color(0xFF2FAE66);
        iconBg = const Color(0xFFE9F7EE);
        break;
      case 'STORE':
        iconData = Icons.inventory_2_outlined;
        iconColor = const Color(0xFF0C447C);
        iconBg = const Color(0xFFE6F1FB);
        break;
      case 'ALLOTMENT':
        iconData = Icons.assignment_turned_in_outlined;
        iconColor = const Color(0xFF6E5CD1);
        iconBg = const Color(0xFFFAF5FF);
        break;
      case 'DISPATCH':
      default:
        iconData = Icons.local_shipping_outlined;
        iconColor = const Color(0xFF1C1C1A);
        iconBg = const Color(0xFFF4F4F2);
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAF8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFECECE8), width: 0.8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: iconColor.withValues(alpha: 0.2)),
            ),
            child: Icon(iconData, size: 16, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        act.title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1C1C1A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      act.relativeTime,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        color: const Color(0xFF9B9A94),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  act.details,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    color: const Color(0xFF6B6A65),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 7. FOOTER AUDIT REPORTS BUTTON
  // ==========================================
  Widget _buildFooterReportsButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF1C1C1A),
          backgroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFFDAD9D3), width: 1.2),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ReportsScreen()),
          );
        },
        icon: const Icon(Icons.assessment_outlined, size: 18, color: Color(0xFF332B6B)),
        label: Text(
          'Full factory audit reports',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1C1C1A),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 8. 1-CLICK DEEP STAGE DRILLDOWN MODAL
  // ==========================================
  void _openStageDrilldown(
    BuildContext context,
    PlantOperationsData data,
    PlantStageType stageType,
  ) {
    PlantStageDrilldownSheet.show(context, stageType);
  }
}

