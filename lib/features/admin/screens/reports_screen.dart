import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/zigza_app_bar.dart';
import '../../../core/widgets/zigza_section_header.dart';
import '../../modules/widgets/workspace_hub_drawer.dart';
import '../../reports/models/reports_models.dart';
import '../../reports/providers/reports_provider.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  final String activeRoute;

  const ReportsScreen({
    super.key,
    this.activeRoute = '/reports',
  });

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _articleSearchController = TextEditingController();
  final TextEditingController _workerSearchController = TextEditingController();

  @override
  void dispose() {
    _articleSearchController.dispose();
    _workerSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reportsProvider);
    final notifier = ref.read(reportsProvider.notifier);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppTheme.bgCanvas,
      appBar: ZigzaAppBar(
        onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      drawer: WorkspaceHubDrawer(activeRoute: widget.activeRoute),
      body: RefreshIndicator(
        color: AppTheme.brandRoyalBlue,
        backgroundColor: Colors.white,
        onRefresh: () => notifier.fetchReports(),
        child: state.isLoading && state.data.articlesReport.isEmpty
            ? const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppTheme.brandRoyalBlue,
                ),
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                children: [
                  // 1. Header Card (Title, Company Mint Pill, Date Presets)
                  _buildHeaderCard(context, state, notifier),
                  const SizedBox(height: 12),

                  // 2. Macro Overview KPIs (4 Inset Tiles)
                  _buildPulseKpisCard(context, state),
                  const SizedBox(height: 12),

                  // 3. Segmented 3-Tab Switcher
                  _buildTabSwitcher(context, state, notifier),
                  const SizedBox(height: 12),

                  // 4. Tab Body (Articles | Workers | PO Audit)
                  if (state.activeTab == 'articles')
                    _buildArticlesTab(context, state, notifier)
                  else if (state.activeTab == 'workers')
                    _buildWorkersTab(context, state, notifier)
                  else
                    _buildAuditTab(context, state),

                  const SizedBox(height: 28),
                ],
              ),
      ),
    );
  }

  // ===========================================================================
  // 1. HEADER CARD WITH DATE PRESETS
  // ===========================================================================
  Widget _buildHeaderCard(BuildContext context, ReportsState state, ReportsNotifier notifier) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.mintSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0x4D14C8B4)),
                ),
                child: const Icon(
                  Icons.assessment_outlined,
                  size: 20,
                  color: AppTheme.headingObsidian,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'Plant ',
                            style: zigzaHeadingStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.headingObsidian,
                            ),
                          ),
                          TextSpan(
                            text: 'Reports & Analytics',
                            style: zigzaHeadingStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.brandRoyalBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.mintSurface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0x4D14C8B4)),
                      ),
                      child: Text(
                        state.companyName.toUpperCase(),
                        style: zigzaHeadingStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.headingObsidian,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Date Presets Row (Today | 7 Days | 30 Days | All Time)
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppTheme.bgCanvas,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: Row(
              children: [
                _buildDateChip('today', 'Today', state, notifier),
                _buildDateChip('7days', '7 Days', state, notifier),
                _buildDateChip('30days', '30 Days', state, notifier),
                _buildDateChip('all', 'All Time', state, notifier),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateChip(
    String key,
    String label,
    ReportsState state,
    ReportsNotifier notifier,
  ) {
    final isSelected = state.dateFilter == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => notifier.setDateFilter(key),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.mintSurface : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? Border.all(color: const Color(0x6614C8B4))
                : Border.all(color: Colors.transparent),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: zigzaHeadingStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected ? AppTheme.headingObsidian : AppTheme.bodyInk,
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 2. MACRO EXECUTIVE PULSE KPIS (4 INSET TILES)
  // ===========================================================================
  Widget _buildPulseKpisCard(BuildContext context, ReportsState state) {
    final kpis = state.data.kpis;
    final dateLabel = state.dateFilter == 'today'
        ? 'Today'
        : state.dateFilter == '7days'
            ? '7 Days'
            : state.dateFilter == '30days'
                ? '30 Days'
                : 'All Time';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ZigzaSectionHeader(
            icon: Icons.bar_chart_rounded,
            title: 'Plant',
            accent: 'Overview',
            badge: dateLabel,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildKpiTile(
                  title: 'TOTAL OUTPUT',
                  value: kpis.totalProduced.toString(),
                  sub: 'Avg ${state.data.dailyAverage} / day',
                  icon: Icons.inventory_2_outlined,
                  valueColor: AppTheme.headingObsidian,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildKpiTile(
                  title: 'QC PASS RATE',
                  value: '${kpis.qcPassRate}%',
                  sub: 'Quality standard',
                  icon: Icons.verified_user_outlined,
                  valueColor: const Color(0xFF047857),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildKpiTile(
                  title: 'GODOWN READY',
                  value: kpis.netWarehouseStock.toString(),
                  sub: 'In finished store',
                  icon: Icons.warehouse_outlined,
                  valueColor: const Color(0xFFB45309),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildKpiTile(
                  title: 'DISPATCHED',
                  value: kpis.totalDispatched.toString(),
                  sub: 'Via delivery challan',
                  icon: Icons.local_shipping_outlined,
                  valueColor: AppTheme.brandRoyalBlue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiTile({
    required String title,
    required String value,
    required String sub,
    required IconData icon,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppTheme.bgCanvas,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: zigzaBodyStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.faintInk,
                  letterSpacing: 0.3,
                ),
              ),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppTheme.mintSurface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0x3314C8B4)),
                ),
                child: Icon(icon, size: 13, color: AppTheme.headingObsidian),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: zigzaHeadingStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: zigzaBodyStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppTheme.bodyInk,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 3. SEGMENTED TAB SWITCHER
  // ===========================================================================
  Widget _buildTabSwitcher(BuildContext context, ReportsState state, ReportsNotifier notifier) {
    final active = state.activeTab;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildTabButton(
            id: 'articles',
            label: 'Articles',
            count: state.data.articlesReport.length,
            icon: Icons.layers_outlined,
            isActive: active == 'articles',
            onTap: () => notifier.setActiveTab('articles'),
          ),
          _buildTabButton(
            id: 'workers',
            label: 'Workers',
            count: state.data.workerLedger.length,
            icon: Icons.people_outline_rounded,
            isActive: active == 'workers',
            onTap: () => notifier.setActiveTab('workers'),
          ),
          _buildTabButton(
            id: 'audit',
            label: 'PO Audit',
            count: state.data.buyerFulfillments.length,
            icon: Icons.business_center_outlined,
            isActive: active == 'audit',
            onTap: () => notifier.setActiveTab('audit'),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String id,
    required String label,
    required int count,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? AppTheme.mintSurface : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isActive
                ? Border.all(color: const Color(0x8014C8B4))
                : Border.all(color: Colors.transparent),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isActive ? AppTheme.headingObsidian : AppTheme.faintInk,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: zigzaHeadingStyle(
                  fontSize: 11.5,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                  color: isActive ? AppTheme.headingObsidian : AppTheme.bodyInk,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isActive ? AppTheme.headingObsidian : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: zigzaHeadingStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: isActive ? Colors.white : AppTheme.headingObsidian,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 4. TAB 1: ARTICLE LIFECYCLE & TRACEABILITY
  // ===========================================================================
  Widget _buildArticlesTab(BuildContext context, ReportsState state, ReportsNotifier notifier) {
    final filtered = state.filteredArticles;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ZigzaSectionHeader(
            icon: Icons.layers_outlined,
            title: 'Article',
            accent: 'Lifecycle',
            badge: '${filtered.length} styles',
            action: GestureDetector(
              onTap: () => notifier.toggleExpandAll(),
              child: Text(
                state.isAllArticlesExpanded ? 'Collapse All' : 'Expand All',
                style: zigzaHeadingStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.brandRoyalBlue,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Search Field
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.bgCanvas,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: TextField(
              controller: _articleSearchController,
              onChanged: (val) => notifier.setArticleSearch(val),
              style: zigzaBodyStyle(fontSize: 12),
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                border: InputBorder.none,
                prefixIcon: Icon(Icons.search, size: 16, color: AppTheme.faintInk),
                hintText: 'Search article, buyer, PO...',
                hintStyle: TextStyle(fontSize: 11.5, color: AppTheme.faintInk),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Stage Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStageChip('ALL', 'All Stages', state.stageFilter, notifier),
                _buildStageChip('In Cutting', 'Cutting', state.stageFilter, notifier),
                _buildStageChip('In Embellishment', 'Embellish', state.stageFilter, notifier),
                _buildStageChip('In Stitching', 'Stitching', state.stageFilter, notifier),
                _buildStageChip('In Washing', 'Washing', state.stageFilter, notifier),
                _buildStageChip('In Ironing', 'Ironing', state.stageFilter, notifier),
                _buildStageChip('QC Passed', 'QC Passed', state.stageFilter, notifier),
                _buildStageChip('In Godown', 'Godown', state.stageFilter, notifier),
                _buildStageChip('Dispatched', 'Dispatched', state.stageFilter, notifier),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Article Cards List
          if (filtered.isEmpty)
            _buildEmptyState('No articles matched your filters')
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final article = filtered[index];
                final isExpanded = state.expandedArticleIds.contains(article.id);
                return _buildArticleItemCard(article, isExpanded, notifier);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildStageChip(String key, String label, String active, ReportsNotifier notifier) {
    final isSelected = active.toLowerCase() == key.toLowerCase();
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () => notifier.setStageFilter(key),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.mintSurface : AppTheme.bgCanvas,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? const Color(0xFF14C8B4) : AppTheme.borderLight,
            ),
          ),
          child: Text(
            label,
            style: zigzaHeadingStyle(
              fontSize: 10.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected ? AppTheme.headingObsidian : AppTheme.bodyInk,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildArticleItemCard(
    ArticleReportRow article,
    bool isExpanded,
    ReportsNotifier notifier,
  ) {
    Color badgeBg;
    Color badgeText;
    Color badgeBorder;

    if (article.stageStatus == 'Dispatched') {
      badgeBg = const Color(0xFFF3E8FF);
      badgeText = const Color(0xFF6B21A8);
      badgeBorder = const Color(0xFFD8B4FE);
    } else if (article.stageStatus == 'In Godown') {
      badgeBg = AppTheme.badgeAmberBg;
      badgeText = AppTheme.badgeAmberText;
      badgeBorder = AppTheme.badgeAmberBorder;
    } else if (article.stageStatus == 'QC Passed') {
      badgeBg = AppTheme.badgeEmeraldBg;
      badgeText = AppTheme.badgeEmeraldText;
      badgeBorder = AppTheme.badgeEmeraldBorder;
    } else {
      badgeBg = AppTheme.mintSurface;
      badgeText = AppTheme.headingObsidian;
      badgeBorder = const Color(0x6614C8B4);
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCanvas,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Expand trigger, Art No, Description, Stage Badge
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => notifier.toggleArticleExpand(article.id),
                      child: Container(
                        width: 28,
                        height: 28,
                        margin: const EdgeInsets.only(top: 1, right: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.mintSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0x6614C8B4)),
                        ),
                        child: Icon(
                          isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                          size: 18,
                          color: AppTheme.headingObsidian,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  article.artNo,
                                  style: zigzaHeadingStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.headingObsidian,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: AppTheme.mintSurface,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0x3314C8B4)),
                                  ),
                                  child: Text(
                                    article.description,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: zigzaHeadingStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.headingObsidian,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Buyer: ${article.buyerName} • PO: ${article.poNumber} • Target: ${article.targetPcs} pcs',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: zigzaBodyStyle(
                              fontSize: 10.5,
                              color: AppTheme.bodyInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: badgeBorder),
                      ),
                      child: Text(
                        article.stageStatus,
                        style: zigzaHeadingStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: badgeText,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Pipeline Progress Bar & Inset Metric Strip
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.borderLight),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Pipeline Progress',
                            style: zigzaBodyStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.faintInk,
                            ),
                          ),
                          Text(
                            '${article.progressPct}%',
                            style: zigzaHeadingStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.brandRoyalBlue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          height: 5,
                          child: LinearProgressIndicator(
                            value: (article.progressPct / 100).clamp(0.0, 1.0),
                            backgroundColor: const Color(0xFFF1F5F9),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppTheme.brandRoyalBlue,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildMiniStageMetric('Cut', article.cutPcs.toString(), AppTheme.headingObsidian),
                          _buildMiniStageMetric('Stitch', article.stitchedPcs.toString(), AppTheme.brandRoyalBlue),
                          _buildMiniStageMetric('QC', article.qcPassedPcs.toString(), const Color(0xFF047857)),
                          _buildMiniStageMetric('Godown', article.godownPcs.toString(), const Color(0xFFB45309)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),

                // Expand / Collapse Action trigger
                GestureDetector(
                  onTap: () => notifier.toggleArticleExpand(article.id),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        isExpanded ? 'Hide Traceability' : 'View Operations (${article.operations.length})',
                        style: zigzaHeadingStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.brandRoyalBlue,
                        ),
                      ),
                      Icon(
                        isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        size: 14,
                        color: AppTheme.brandRoyalBlue,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Expanded Operations Accordion Body
          if (isExpanded)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                border: Border(top: BorderSide(color: AppTheme.borderLight)),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(14),
                  bottomRight: Radius.circular(14),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'FLOOR ALLOCATIONS',
                        style: zigzaHeadingStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.headingObsidian,
                          letterSpacing: 0.3,
                        ),
                      ),
                      Text(
                        '${article.operations.length} logs',
                        style: zigzaBodyStyle(
                          fontSize: 10,
                          color: AppTheme.faintInk,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (article.operations.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.borderLight),
                      ),
                      child: Center(
                        child: Text(
                          'No floor allocations logged for this style yet',
                          style: zigzaBodyStyle(fontSize: 11, color: AppTheme.bodyInk),
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: article.operations.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, opIdx) {
                        final op = article.operations[opIdx];
                        return _buildOperationTile(op);
                      },
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMiniStageMetric(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: zigzaBodyStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.faintInk,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            style: zigzaHeadingStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOperationTile(ArticleWorkerOperation op) {
    final isDone = op.status == 'COMPLETED' || op.status == 'DONE';
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  op.workerName,
                  style: zigzaHeadingStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.headingObsidian,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isDone ? AppTheme.badgeEmeraldBg : AppTheme.badgeAmberBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isDone ? AppTheme.badgeEmeraldBorder : AppTheme.badgeAmberBorder,
                  ),
                ),
                child: Text(
                  op.status,
                  style: zigzaHeadingStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: isDone ? AppTheme.badgeEmeraldText : AppTheme.badgeAmberText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${op.division} • ${op.operation}',
            style: zigzaBodyStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.bodyInk,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Target: ${op.targetPcs}',
                  style: zigzaBodyStyle(fontSize: 10, color: AppTheme.bodyInk),
                ),
              ),
              Expanded(
                child: Text(
                  'Done: ${op.completedPcs}',
                  style: zigzaHeadingStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF047857),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'Defects: ${op.rejectedPcs > 0 ? op.rejectedPcs : '-'}',
                  style: zigzaHeadingStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: op.rejectedPcs > 0 ? const Color(0xFFBE123C) : AppTheme.faintInk,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 5. TAB 2: WORKER PIECE-RATE LEDGER & SUMMARY STRIP
  // ===========================================================================
  Widget _buildWorkersTab(BuildContext context, ReportsState state, ReportsNotifier notifier) {
    final filtered = state.filteredWorkerLedger;
    final stats = state.workerStats;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ZigzaSectionHeader(
            icon: Icons.people_outline_rounded,
            title: 'Worker',
            accent: 'Piece Ledger',
            badge: '${filtered.length} logs',
          ),
          const SizedBox(height: 10),

          // 2x2 Worker Summary Strip
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  'OPERATORS',
                  stats.activeWorkers.toString(),
                  'Floor pieces',
                  AppTheme.headingObsidian,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSummaryItem(
                  'PIECES DONE',
                  stats.totalCompleted.toString(),
                  'Completed ops',
                  const Color(0xFF047857),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  'DEFECT RATE',
                  '${stats.defectRatePct}%',
                  '${stats.totalRejected} rejected',
                  const Color(0xFFBE123C),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSummaryItem(
                  'TOP OPERATOR',
                  stats.topWorkerName,
                  '${stats.topWorkerPieces} pcs done',
                  AppTheme.brandRoyalBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Search Worker
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.bgCanvas,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: TextField(
              controller: _workerSearchController,
              onChanged: (val) => notifier.setWorkerSearch(val),
              style: zigzaBodyStyle(fontSize: 12),
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                border: InputBorder.none,
                prefixIcon: Icon(Icons.search, size: 16, color: AppTheme.faintInk),
                hintText: 'Search worker, article, op...',
                hintStyle: TextStyle(fontSize: 11.5, color: AppTheme.faintInk),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Division Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: state.uniqueDivisions.map((div) {
                final isSelected = state.divisionFilter.toLowerCase() == div.toLowerCase();
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => notifier.setDivisionFilter(div),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.mintSurface : AppTheme.bgCanvas,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF14C8B4) : AppTheme.borderLight,
                        ),
                      ),
                      child: Text(
                        div == 'ALL' ? 'All Divisions' : div,
                        style: zigzaHeadingStyle(
                          fontSize: 10.5,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                          color: isSelected ? AppTheme.headingObsidian : AppTheme.bodyInk,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),

          // Status Filter Chips
          Row(
            children: [
              _buildStatusChip('ALL', 'All Statuses', state.workerStatusFilter, notifier),
              const SizedBox(width: 6),
              _buildStatusChip('COMPLETED', 'Completed', state.workerStatusFilter, notifier),
              const SizedBox(width: 6),
              _buildStatusChip('IN_PROGRESS', 'In Progress', state.workerStatusFilter, notifier),
              const SizedBox(width: 6),
              _buildStatusChip('ASSIGNED', 'Assigned', state.workerStatusFilter, notifier),
            ],
          ),
          const SizedBox(height: 12),

          // Worker Ledger Item Cards
          if (filtered.isEmpty)
            _buildEmptyState('No worker piece records found')
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = filtered[index];
                return _buildWorkerItemCard(item);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, String sub, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.bgCanvas,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: zigzaBodyStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: AppTheme.faintInk,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: zigzaHeadingStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: zigzaBodyStyle(fontSize: 9.5, color: AppTheme.bodyInk),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String key, String label, String active, ReportsNotifier notifier) {
    final isSelected = active.toLowerCase() == key.toLowerCase();
    return Expanded(
      child: GestureDetector(
        onTap: () => notifier.setWorkerStatusFilter(key),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.mintSurface : AppTheme.bgCanvas,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? const Color(0xFF14C8B4) : AppTheme.borderLight,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: zigzaHeadingStyle(
              fontSize: 9.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected ? AppTheme.headingObsidian : AppTheme.bodyInk,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWorkerItemCard(WorkerPieceLedgerItem item) {
    final isDone = item.status == 'COMPLETED' || item.status == 'DONE';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bgCanvas,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.mintSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0x6614C8B4)),
                ),
                child: const Icon(
                  Icons.person_outline,
                  size: 16,
                  color: AppTheme.headingObsidian,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.workerName,
                      style: zigzaHeadingStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.headingObsidian,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${item.division} • ${item.role}',
                      style: zigzaBodyStyle(
                        fontSize: 10.5,
                        color: AppTheme.bodyInk,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isDone ? AppTheme.badgeEmeraldBg : AppTheme.badgeAmberBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDone ? AppTheme.badgeEmeraldBorder : AppTheme.badgeAmberBorder,
                  ),
                ),
                child: Text(
                  item.status,
                  style: zigzaHeadingStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: isDone ? AppTheme.badgeEmeraldText : AppTheme.badgeAmberText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Nested White Metric Box
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item.articleNo,
                      style: zigzaHeadingStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.headingObsidian,
                      ),
                    ),
                    Text(
                      item.operationName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: zigzaBodyStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.bodyInk,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildMiniStageMetric('Target', item.targetPieces.toString(), AppTheme.headingObsidian),
                    _buildMiniStageMetric('Completed', item.completedPieces.toString(), const Color(0xFF047857)),
                    _buildMiniStageMetric(
                      'Defects',
                      item.rejectedPieces > 0 ? item.rejectedPieces.toString() : '-',
                      item.rejectedPieces > 0 ? const Color(0xFFBE123C) : AppTheme.faintInk,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Station: ${item.workstationRef}',
                style: zigzaBodyStyle(fontSize: 10, color: AppTheme.bodyInk),
              ),
              Text(
                item.date,
                style: zigzaHeadingStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.faintInk,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 6. TAB 3: PLANT OPERATIONS & BUYER PO FULFILLMENT AUDIT
  // ===========================================================================
  Widget _buildAuditTab(BuildContext context, ReportsState state) {
    final recentProd = state.data.productionTrend.length > 7
        ? state.data.productionTrend.sublist(state.data.productionTrend.length - 7)
        : state.data.productionTrend;

    int maxProd = 1;
    for (final p in recentProd) {
      if (p.pieces > maxProd) maxProd = p.pieces;
    }

    int totalQcPass = 0;
    int totalQcReject = 0;
    for (final q in state.data.qcTrend) {
      totalQcPass += q.passed;
      totalQcReject += q.rejected;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Output & QC Trend Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.cardSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderLight),
            boxShadow: const [
              BoxShadow(
                color: Color(0x05000000),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ZigzaSectionHeader(
                icon: Icons.show_chart_rounded,
                title: 'Output &',
                accent: 'QC Trend',
                badge: 'Avg ${state.data.dailyAverage}/d',
              ),
              const SizedBox(height: 10),

              // 7-Day Output Visualization
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.bgCanvas,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '7-Day Floor Output',
                          style: zigzaHeadingStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.headingObsidian,
                          ),
                        ),
                        Text(
                          '${recentProd.fold<int>(0, (s, p) => s + p.pieces)} pcs',
                          style: zigzaHeadingStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.brandRoyalBlue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 70,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: recentProd.map((pt) {
                          final heightFactor = (pt.pieces / maxProd).clamp(0.08, 1.0);
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2.5),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Flexible(
                                    child: FractionallySizedBox(
                                      heightFactor: heightFactor,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: pt.pieces > 0
                                              ? AppTheme.brandRoyalBlue
                                              : const Color(0xFFCBD5E1),
                                          borderRadius: const BorderRadius.vertical(
                                            top: Radius.circular(4),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    pt.label.split(' ').first,
                                    maxLines: 1,
                                    overflow: TextOverflow.clip,
                                    style: zigzaHeadingStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.faintInk,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // 3-Column QC Audit Strip
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryItem(
                      'QC PASS RATE',
                      '${state.data.kpis.qcPassRate}%',
                      'Audit pass',
                      const Color(0xFF047857),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSummaryItem(
                      'PASSED PCS',
                      totalQcPass.toString(),
                      'Approved',
                      AppTheme.brandRoyalBlue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSummaryItem(
                      'REJECTED',
                      totalQcReject.toString(),
                      'Alterations',
                      const Color(0xFFBE123C),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 2. Division Scorecards Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.cardSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderLight),
            boxShadow: const [
              BoxShadow(
                color: Color(0x05000000),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ZigzaSectionHeader(
                icon: Icons.view_quilt_outlined,
                title: 'Division',
                accent: 'Scorecards',
                badge: '${state.data.divisionComparison.length} units',
              ),
              const SizedBox(height: 10),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: state.data.divisionComparison.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final div = state.data.divisionComparison[index];
                  return Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: AppTheme.bgCanvas,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderLight),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppTheme.mintSurface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0x6614C8B4)),
                          ),
                          child: const Icon(
                            Icons.factory_outlined,
                            size: 16,
                            color: AppTheme.headingObsidian,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                div.division,
                                style: zigzaHeadingStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.headingObsidian,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                '${div.workerCount} active operators • ${div.metricLabel}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: zigzaBodyStyle(
                                  fontSize: 10,
                                  color: AppTheme.bodyInk,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${div.totalOutput} pcs',
                          style: zigzaHeadingStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.brandRoyalBlue,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 3. Buyer Purchase Order Fulfillment Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.cardSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderLight),
            boxShadow: const [
              BoxShadow(
                color: Color(0x05000000),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ZigzaSectionHeader(
                icon: Icons.business_center_outlined,
                title: 'Buyer PO',
                accent: 'Delivery Ledger',
                badge: '${state.data.buyerFulfillments.length} contracts',
              ),
              const SizedBox(height: 10),
              if (state.data.buyerFulfillments.isEmpty)
                _buildEmptyState('No purchase orders recorded')
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: state.data.buyerFulfillments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final b = state.data.buyerFulfillments[index];
                    return _buildBuyerFulfillmentCard(b);
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBuyerFulfillmentCard(BuyerFulfillmentItem b) {
    Color badgeBg;
    Color badgeText;
    Color badgeBorder;

    if (b.status == 'Fully Shipped') {
      badgeBg = AppTheme.badgeEmeraldBg;
      badgeText = AppTheme.badgeEmeraldText;
      badgeBorder = AppTheme.badgeEmeraldBorder;
    } else if (b.status == 'Partially Dispatched') {
      badgeBg = AppTheme.badgeAmberBg;
      badgeText = AppTheme.badgeAmberText;
      badgeBorder = AppTheme.badgeAmberBorder;
    } else {
      badgeBg = AppTheme.badgeBlueBg;
      badgeText = AppTheme.badgeBlueText;
      badgeBorder = AppTheme.badgeBlueBorder;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bgCanvas,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            b.poNumber,
                            style: zigzaHeadingStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.headingObsidian,
                            ),
                          ),
                        ),
                        if (b.isOverdue) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppTheme.badgeRoseBg,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppTheme.badgeRoseBorder),
                            ),
                            child: Text(
                              'Overdue',
                              style: zigzaHeadingStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.badgeRoseText,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      b.buyerName,
                      style: zigzaHeadingStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.bodyInk,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: badgeBorder),
                ),
                child: Text(
                  b.status,
                  style: zigzaHeadingStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: badgeText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Inset Progress & Metrics Box
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    _buildMiniStageMetric('Target', '${b.targetPieces} pcs', AppTheme.headingObsidian),
                    _buildMiniStageMetric('Dispatched', '${b.deliveredPieces} pcs', const Color(0xFF6B21A8)),
                    _buildMiniStageMetric('Godown', '${b.godownPieces} pcs', const Color(0xFFB45309)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Fulfillment',
                      style: zigzaBodyStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.faintInk,
                      ),
                    ),
                    Text(
                      '${b.percent}%',
                      style: zigzaHeadingStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: b.percent >= 100 ? const Color(0xFF047857) : AppTheme.brandRoyalBlue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 5,
                    child: LinearProgressIndicator(
                      value: (b.percent / 100).clamp(0.0, 1.0),
                      backgroundColor: const Color(0xFFF1F5F9),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        b.percent >= 100 ? const Color(0xFF047857) : AppTheme.brandRoyalBlue,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Due: ${b.deliveryDate}',
                style: zigzaBodyStyle(fontSize: 10, color: AppTheme.bodyInk),
              ),
              Flexible(
                child: Text(
                  b.challanNumbers.isNotEmpty ? b.challanNumbers.join(', ') : 'Pending Challan',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: zigzaHeadingStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.faintInk,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // EMPTY STATE HELPER
  // ===========================================================================
  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.bgCanvas,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.mintSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0x6614C8B4)),
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 18,
                color: AppTheme.headingObsidian,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: zigzaBodyStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.bodyInk,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
