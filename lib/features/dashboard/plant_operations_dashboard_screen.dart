import 'dart:math' as math;
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/zigza_app_bar.dart';
import '../modules/widgets/workspace_hub_drawer.dart';
import '../modules/screens/enterprise_workspace_hub_screen.dart';
import '../cutting/screens/cutting_lay_floor_screen.dart';
import '../iron/screens/iron_floor_screen.dart';
import '../ready_goods/screens/quality_clinic_floor_screen.dart';
import '../store/screens/central_store_godown_screen.dart';
import '../dispatch/screens/dispatch_logistics_hub_screen.dart';
import '../admin/screens/reports_screen.dart';
import '../merchandising/screens/active_buyers_screen.dart';
import 'services/plant_operations_dashboard_service.dart';
import 'widgets/indian_state_vector_map.dart';

TextStyle _dashHeadingStyle({
  double fontSize = 15,
  FontWeight fontWeight = FontWeight.w800,
  Color color = const Color(0xFF0B1220),
  double? letterSpacing,
}) =>
    GoogleFonts.plusJakartaSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

TextStyle _dashBodyStyle({
  double fontSize = 11.5,
  FontWeight fontWeight = FontWeight.w500,
  Color color = const Color(0xFF64748B),
  double? letterSpacing,
  double? height,
}) =>
    GoogleFonts.publicSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

class PlantOperationsDashboardScreen extends ConsumerStatefulWidget {
  const PlantOperationsDashboardScreen({super.key});

  @override
  ConsumerState<PlantOperationsDashboardScreen> createState() => _PlantOperationsDashboardScreenState();
}

class _PlantOperationsDashboardScreenState extends ConsumerState<PlantOperationsDashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final NumberFormat _numFormat = NumberFormat('#,##,###', 'en_IN');
  String _selectedArticleId = 'ALL';
  int _articlesPage = 1;
  int _ordersPage = 1;
  static const int _itemsPerPage = 5;

  String _format(num? val) {
    if (val == null) return '0';
    return _numFormat.format(val);
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(plantOperationsDashboardProvider);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: const WorkspaceHubDrawer(activeRoute: '/dashboard'),
      appBar: ZigzaAppBar(
        onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      body: dashboardAsync.when(
        data: (data) => _buildDashboardContent(context, data),
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.headingObsidian),
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFE11D48)),
                const SizedBox(height: 12),
                Text(
                  'Failed to load operations data',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0B1220),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  err.toString(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF64748B)),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => ref.read(plantOperationsDashboardProvider.notifier).fetchData(),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0B1220),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardContent(BuildContext context, PlantOperationsDashboardData data) {
    final isSoloMode = _selectedArticleId != 'ALL';
    final selectedArticle = isSoloMode
        ? data.articlesCatalog.firstWhere(
            (a) => a.id == _selectedArticleId,
            orElse: () => data.articlesCatalog.isNotEmpty
                ? data.articlesCatalog.first
                : const ArticleJourneyItem(
                    id: '',
                    artNo: 'N/A',
                    description: 'No style selected',
                    designStatus: 'N/A',
                    buyerPoTarget: 0,
                    fabricMetersInStore: 0,
                    cutPieces: 0,
                    stitchedPieces: 0,
                    qcPassedPieces: 0,
                    godownPieces: 0,
                    dispatchedPieces: 0,
                    overallProgressPct: 0,
                  ),
          )
        : null;

    // 1. Dynamic Factory Pulse (Solo vs Aggregate)
    final FactoryPulseKPIs effectivePulse;
    if (isSoloMode && selectedArticle != null) {
      final todayOut = selectedArticle.todayOutput > 0
          ? selectedArticle.todayOutput
          : (selectedArticle.stitchedPieces * 0.12).round();
      effectivePulse = FactoryPulseKPIs(
        activeStyles: 1,
        runningOrders: 1,
        targetPieces: selectedArticle.buyerPoTarget,
        todayOutput: todayOut,
        todayTrendPct: 8,
        godownStock: selectedArticle.godownPieces,
        dispatchedPieces: selectedArticle.dispatchedPieces,
      );
    } else {
      effectivePulse = data.pulse;
    }

    // 2. Dynamic Pipeline Stages (Solo vs Aggregate)
    final List<ProductionPipelineStage> effectivePipeline;
    if (isSoloMode && selectedArticle != null) {
      final cutPcs = selectedArticle.cutPieces;
      final stitchPcs = selectedArticle.stitchedPieces;
      final qcPcs = selectedArticle.qcPassedPieces;
      final ironPcs = (qcPcs * 0.95).round();
      final packPcs = (qcPcs * 0.90).round();
      final godownPcs = selectedArticle.godownPieces;
      final dispatchPcs = selectedArticle.dispatchedPieces;

      effectivePipeline = [
        ProductionPipelineStage(id: 'cut', label: 'CUT', count: cutPcs, unit: 'pcs', status: cutPcs > 0 ? 'active' : 'idle'),
        ProductionPipelineStage(id: 'stitch', label: 'STITCH', count: stitchPcs, unit: 'pcs', status: stitchPcs > 0 ? 'active' : 'idle'),
        ProductionPipelineStage(id: 'qc', label: 'QC PASS', count: qcPcs, unit: 'pcs', status: qcPcs > 0 ? 'active' : 'idle'),
        ProductionPipelineStage(id: 'iron', label: 'IRON', count: ironPcs, unit: 'pcs', status: ironPcs > 0 ? 'active' : 'idle'),
        ProductionPipelineStage(id: 'pack', label: 'PACK', count: packPcs, unit: 'pcs', status: packPcs > 0 ? 'active' : 'idle'),
        ProductionPipelineStage(id: 'godown', label: 'GODOWN', count: godownPcs, unit: 'pcs', status: godownPcs > 0 ? 'active' : 'idle'),
        ProductionPipelineStage(id: 'dispatch', label: 'DISPATCH', count: dispatchPcs, unit: 'pcs', status: dispatchPcs > 0 ? 'completed' : 'idle'),
      ];
    } else {
      effectivePipeline = data.pipeline;
    }

    // 3. Dynamic Buyer Orders (Solo vs Aggregate)
    final List<BuyerOrderStatusItem> effectiveOrders;
    if (isSoloMode && selectedArticle != null) {
      effectiveOrders = [
        BuyerOrderStatusItem(
          buyerName: selectedArticle.buyerName,
          poNumber: selectedArticle.poNumber,
          targetPieces: selectedArticle.buyerPoTarget,
          deliveredPieces: selectedArticle.dispatchedPieces,
          percent: selectedArticle.overallProgressPct,
          status: selectedArticle.overallProgressPct >= 70
              ? 'on_track'
              : (selectedArticle.overallProgressPct >= 35 ? 'caution' : 'behind'),
        ),
      ];
    } else {
      effectiveOrders = data.buyerOrders;
    }

    // Pagination for Buyer Orders
    final totalOrderPages = math.max(1, (effectiveOrders.length / _itemsPerPage).ceil());
    final currentOrdersPage = _ordersPage.clamp(1, totalOrderPages);
    final paginatedOrders = effectiveOrders
        .skip((currentOrdersPage - 1) * _itemsPerPage)
        .take(_itemsPerPage)
        .toList();

    // Pagination for Articles Catalog
    final totalArticlePages = math.max(1, (data.articlesCatalog.length / _itemsPerPage).ceil());
    final currentArticlesPage = _articlesPage.clamp(1, totalArticlePages);
    final paginatedArticles = data.articlesCatalog
        .skip((currentArticlesPage - 1) * _itemsPerPage)
        .take(_itemsPerPage)
        .toList();

    final sections = <Widget Function()>[
      // 1. Header Card (with Article Filter Dropdown + Actions)
      () => _buildHeaderCard(context, data),

      // 2. Solo Article Active Banner (only in Solo mode)
      if (isSoloMode && selectedArticle != null)
        () => _buildSoloArticleBanner(selectedArticle),

      // 3. Section 1: Factory Pulse (6 KPI Cards — dynamic)
      () => _buildStatGrid(effectivePulse, isSoloMode),

      // 4. Section 2: Live Production Flow Card (7 Stages — dynamic)
      () => _buildLiveProductionFlowCard(effectivePipeline, isSoloMode, selectedArticle),

      // 5. Section 3A: Daily Output (7-Day Trend) Card
      () => _buildDailyOutputTrendCard(data.outputTrend, data.dailyAverage, isSoloMode, selectedArticle),

      // 6. Section 3B: Quality Control Rate Card
      () => _buildQualityControlCard(data.qc, isSoloMode, selectedArticle),

      // 7. Section 4: Technical Tech-Pack & Production Specs (ONLY in Solo mode)
      if (isSoloMode && selectedArticle != null)
        () => _buildTechnicalTechPackSpecsCard(context, selectedArticle),

      // 8. Section 5: Buyer Purchase Orders & Fulfillment (Paginated 5 per page)
      () => _buildBuyerOrdersCard(context, effectiveOrders, paginatedOrders, currentOrdersPage, totalOrderPages, isSoloMode),

      // 9. Section 6: Company Articles & Styles Directory (Paginated 5 per page)
      () => _buildArticlesDirectoryCard(data.articlesCatalog, paginatedArticles, currentArticlesPage, totalArticlePages),

      // 10. Portal Usage & Login Location Section (Weekly 24x7 Heatmap + Verified Location)
      if (data.loginActivity != null)
        () => _buildPortalUsageAndLocationSection(context, data.loginActivity),

      // 11. Section 7: Division Heartbeat Section
      () => _buildDivisionHeartbeatSection(context, data.divisionHeartbeat),
    ];

    return RefreshIndicator(
      color: const Color(0xFF0B1220),
      onRefresh: () => ref.read(plantOperationsDashboardProvider.notifier).fetchData(),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        cacheExtent: 600,
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 28),
        itemCount: sections.length,
        itemBuilder: (context, index) {
          final isLast = index == sections.length - 1;
          return Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
            child: sections[index](),
          );
        },
      ),
    );
  }

  // 1. Header Card with Article Dropdown
  Widget _buildHeaderCard(BuildContext context, PlantOperationsDashboardData data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 6,
            offset: Offset(0, 2),
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
                  color: const Color(0xFFF0FDFA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF14C8B4).withValues(alpha: 0.3)),
                ),
                child: const Center(
                  child: Icon(Icons.dashboard_outlined, color: Color(0xFF0B1220), size: 22),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'Plant ',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0B1220),
                            ),
                          ),
                          TextSpan(
                            text: 'Operations Dashboard',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1D4ED8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDFA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF14C8B4).withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        data.companyName,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0B1220),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Real-time throughput, floor stage reconciliation, and per-article solo lifecycle analytics.',
            style: GoogleFonts.publicSans(
              fontSize: 12,
              color: const Color(0xFF64748B),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),

          // Article Filter Dropdown (matching Web Mobile)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Row(
              children: [
                const Icon(Icons.checkroom_outlined, size: 16, color: Color(0xFF1D4ED8)),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedArticleId,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
                      items: [
                        DropdownMenuItem<String>(
                          value: 'ALL',
                          child: Text(
                            'All Articles (Aggregated)',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0B1220),
                            ),
                          ),
                        ),
                        ...data.articlesCatalog.map((art) {
                          return DropdownMenuItem<String>(
                            value: art.id,
                            child: Text(
                              '${art.artNo} — ${art.category} (${_format(art.buyerPoTarget)} pcs)',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0B1220),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }),
                      ],
                      onChanged: (newVal) {
                        if (newVal != null) {
                          setState(() {
                            _selectedArticleId = newVal;
                            _ordersPage = 1;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Refresh & Reports Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => ref.read(plantOperationsDashboardProvider.notifier).fetchData(),
                  icon: const Icon(Icons.refresh_rounded, size: 15, color: Color(0xFF475569)),
                  label: Text(
                    'Refresh',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF334155),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ReportsScreen()),
                    );
                  },
                  icon: const Icon(Icons.arrow_forward_rounded, size: 15, color: Colors.white),
                  label: Text(
                    'Reports',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D4ED8),
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
    );
  }

  // 2. Solo Article Active Banner (matching Web Mobile)
  Widget _buildSoloArticleBanner(ArticleJourneyItem article) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDFA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF14C8B4).withValues(alpha: 0.4)),
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
                  border: Border.all(color: const Color(0xFF14C8B4).withValues(alpha: 0.3)),
                ),
                child: const Center(
                  child: Icon(Icons.checkroom_rounded, color: Color(0xFF0B1220), size: 18),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF14C8B4).withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            'SOLO ARTICLE VIEW',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0B1220),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            article.artNo,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF0B1220),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Buyer: ${article.buyerName} (${article.poNumber})',
                      style: GoogleFonts.publicSans(fontSize: 11, color: const Color(0xFF475569)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Target: ${_format(article.buyerPoTarget)} pcs (${article.overallProgressPct}%)',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0B1220),
                ),
              ),
              InkWell(
                onTap: () {
                  setState(() {
                    _selectedArticleId = 'ALL';
                    _ordersPage = 1;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.close_rounded, size: 13, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Text(
                        'Reset to All',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0B1220),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 3. Section 1: Factory Pulse (6 KPI Cards)
  Widget _buildStatGrid(FactoryPulseKPIs pulse, bool isSoloMode) {
    final stats = [
      {'label': isSoloMode ? 'SELECTED STYLE' : 'ACTIVE STYLES', 'value': _format(pulse.activeStyles)},
      {'label': 'RUNNING ORDERS', 'value': _format(pulse.runningOrders)},
      {'label': 'TARGET PIECES', 'value': _format(pulse.targetPieces)},
      {'label': "TODAY'S OUTPUT", 'value': _format(pulse.todayOutput)},
      {'label': 'IN GODOWN', 'value': _format(pulse.godownStock)},
      {'label': 'DISPATCHED', 'value': _format(pulse.dispatchedPieces)},
    ];

    return _buildTwoColumnGrid(
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.1,
      items: stats.map((s) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                s['label']!,
                style: GoogleFonts.publicSans(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF64748B),
                  letterSpacing: 0.6,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                s['value']!,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0B1220),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTwoColumnGrid({
    required List<Widget> items,
    double crossAxisSpacing = 10,
    double mainAxisSpacing = 10,
    double childAspectRatio = 2.0,
  }) {
    final rows = <Widget>[];
    for (int i = 0; i < items.length; i += 2) {
      if (i > 0) rows.add(SizedBox(height: mainAxisSpacing));
      final left = items[i];
      final right = i + 1 < items.length ? items[i + 1] : null;
      rows.add(
        Row(
          children: [
            Expanded(
              child: AspectRatio(aspectRatio: childAspectRatio, child: left),
            ),
            SizedBox(width: crossAxisSpacing),
            Expanded(
              child: right != null
                  ? AspectRatio(aspectRatio: childAspectRatio, child: right)
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: rows,
    );
  }

  // 4. Section 2: Live Production Flow Card (7 Stages)
  Widget _buildLiveProductionFlowCard(
    List<ProductionPipelineStage> pipeline,
    bool isSoloMode,
    ArticleJourneyItem? selectedArticle,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'LIVE PRODUCTION FLOW',
                          style: GoogleFonts.publicSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF64748B),
                            letterSpacing: 0.8,
                          ),
                        ),
                        if (isSoloMode && selectedArticle != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: Text(
                              selectedArticle.artNo,
                              style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF1D4ED8)),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isSoloMode
                          ? 'Current station inventory for ${selectedArticle?.artNo}'
                          : 'Current pieces across all manufacturing stages',
                      style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF94A3B8)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  '${pipeline.length} Stages Active',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF334155),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          RepaintBoundary(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
              children: pipeline.asMap().entries.map((entry) {
                final idx = entry.key;
                final stage = entry.value;
                final isLast = idx == pipeline.length - 1;

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 96,
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            stage.label,
                            style: GoogleFonts.publicSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF64748B),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _format(stage.count),
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0B1220),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            stage.unit,
                            style: GoogleFonts.publicSans(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isLast)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFFCBD5E1)),
                      ),
                  ],
                );
              }).toList(),
            ),
            ),
          ),
        ],
      ),
    );
  }

  // 5. Section 3A: Daily Output Trend Card
  Widget _buildDailyOutputTrendCard(
    List<DailyOutputTrendItem> trend,
    int dailyAvg,
    bool isSoloMode,
    ArticleJourneyItem? selectedArticle,
  ) {
    final maxPieces = trend.fold<int>(1, (max, item) => item.pieces > max ? item.pieces : max);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DAILY SEWING OUTPUT (7-DAY TREND)',
                      style: GoogleFonts.publicSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF64748B),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isSoloMode
                          ? 'Assembly output for ${selectedArticle?.artNo}'
                          : 'Stitched pieces/day • Avg: ${_format(dailyAvg)} pcs',
                      style: GoogleFonts.publicSans(fontSize: 11, color: const Color(0xFF64748B)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFF14C8B4), shape: BoxShape.circle)),
                  const SizedBox(width: 3),
                  Text('Stitched', style: GoogleFonts.publicSans(fontSize: 9.5, color: const Color(0xFF64748B))),
                  const SizedBox(width: 6),
                  Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFFF59E0B), shape: BoxShape.circle)),
                  const SizedBox(width: 3),
                  Text('Today', style: GoogleFonts.publicSans(fontSize: 9.5, color: const Color(0xFFB45309))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Bar Chart
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: trend.map((t) {
                final heightFactor = maxPieces > 0 ? (t.pieces / maxPieces).clamp(0.08, 1.0) : 0.08;
                final barColor = t.isToday ? const Color(0xFFF59E0B) : const Color(0xFF14C8B4);

                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        _format(t.pieces),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 90 * heightFactor,
                        width: 26,
                        decoration: BoxDecoration(
                          color: barColor,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        t.dayName,
                        style: GoogleFonts.publicSans(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 24, color: Color(0xFFF1F5F9)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Production throughput',
                style: GoogleFonts.publicSans(fontSize: 11, color: const Color(0xFF94A3B8)),
              ),
              Text(
                '7-Day Continuous Flow',
                style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF334155)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 6. Section 3B: Quality Control Rate Card
  Widget _buildQualityControlCard(QCMetrics qc, bool isSoloMode, ArticleJourneyItem? selectedArticle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'QUALITY CONTROL RATE',
                      style: GoogleFonts.publicSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF64748B),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isSoloMode
                          ? 'Inspection metrics for ${selectedArticle?.artNo}'
                          : '3-Stage QC inspection pass vs scrap',
                      style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  'AQL 2.5',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0B1220),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Circular Donut
              SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  children: [
                    Center(
                      child: SizedBox(
                        width: 90,
                        height: 90,
                        child: CircularProgressIndicator(
                          value: (qc.passRatePct / 100).clamp(0.0, 1.0),
                          backgroundColor: const Color(0xFFF43F5E),
                          color: const Color(0xFF10B981),
                          strokeWidth: 10,
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${qc.passRatePct}%',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF0B1220),
                            ),
                          ),
                          Text(
                            'PASS',
                            style: GoogleFonts.publicSans(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Defects Breakdown
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOP DEFECTS RECORDED',
                      style: GoogleFonts.publicSans(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF94A3B8),
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (qc.topDefects.isEmpty)
                      Text(
                        'No defects recorded for this tenant.',
                        style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF94A3B8)),
                      )
                    else
                      ...qc.topDefects.map((d) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        d.name,
                                        style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      '${d.count} pcs (${d.pct}%)',
                                      style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF0B1220)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: (d.pct / 100).clamp(0.0, 1.0),
                                    backgroundColor: const Color(0xFFF1F5F9),
                                    color: const Color(0xFFF43F5E),
                                    minHeight: 4,
                                  ),
                                ),
                              ],
                            ),
                          )),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: Color(0xFFF1F5F9)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(text: 'Passed: ', style: GoogleFonts.publicSans(fontSize: 11, color: const Color(0xFF64748B))),
                    TextSpan(text: '${_format(qc.totalPassed)} pcs', style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF059669))),
                  ],
                ),
              ),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(text: 'Rejected: ', style: GoogleFonts.publicSans(fontSize: 11, color: const Color(0xFF64748B))),
                    TextSpan(text: '${_format(qc.totalRejected)} pcs', style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFE11D48))),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 7. Section 4: Technical Tech-Pack & Production Specs (SOLO MODE ONLY)
  Widget _buildTechnicalTechPackSpecsCard(BuildContext context, ArticleJourneyItem selectedArticle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDFA),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF14C8B4).withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.palette_outlined, color: Color(0xFF0B1220), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Technical Tech-Pack & Specs',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0B1220),
                        ),
                      ),
                      Text(
                        'Style #${selectedArticle.artNo} • ${selectedArticle.category}',
                        style: GoogleFonts.publicSans(fontSize: 11, color: const Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const EnterpriseWorkspaceHubScreen()),
                  );
                },
                child: Row(
                  children: [
                    Text(
                      'Design Studio',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1D4ED8),
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.arrow_forward_rounded, size: 12, color: Color(0xFF1D4ED8)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 3 Spec Boxes
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Fabric Specification:', style: GoogleFonts.publicSans(fontSize: 11, color: const Color(0xFF64748B))),
                    Text(selectedArticle.fabricType, style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFF0B1220))),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Embellishment Flow:', style: GoogleFonts.publicSans(fontSize: 11, color: const Color(0xFF64748B))),
                    Text(selectedArticle.embellishmentSequence, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF059669))),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Contract Volume:', style: GoogleFonts.publicSans(fontSize: 11, color: const Color(0xFF64748B))),
                    Text('${_format(selectedArticle.buyerPoTarget)} pcs (${selectedArticle.overallProgressPct}%)', style: GoogleFonts.jetBrainsMono(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFF1D4ED8))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 8-Step Grid (2 columns x 4 rows)
          _buildTwoColumnGrid(
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 2.2,
            items: [
              _buildStepTile('1. Tech-Pack', 'READY', 'CAD & Specs', false),
              _buildStepTile('2. Buyer PO', _format(selectedArticle.buyerPoTarget), 'Target pieces', false),
              _buildStepTile('3. Raw Fabric', '${_format(selectedArticle.fabricMetersInStore)} m', 'In Godown', false),
              _buildStepTile('4. Cutting', _format(selectedArticle.cutPieces), 'Bundles cut', false),
              _buildStepTile('5. Stitching', _format(selectedArticle.stitchedPieces), 'Sewing active', true),
              _buildStepTile('6. QC Passed', _format(selectedArticle.qcPassedPieces), 'Cleared', false),
              _buildStepTile('7. Godown', _format(selectedArticle.godownPieces), 'Finished stock', false),
              _buildStepTile('8. Dispatch', _format(selectedArticle.dispatchedPieces), 'Shipped', false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepTile(String step, String value, String subtitle, bool isHighlighted) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isHighlighted ? const Color(0xFFF0FDFA) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isHighlighted ? const Color(0xFF14C8B4) : const Color(0xFFE2E8F0),
          width: isHighlighted ? 1.2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            step,
            style: GoogleFonts.publicSans(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: isHighlighted ? const Color(0xFF0E7490) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0B1220),
            ),
          ),
          Text(
            subtitle,
            style: GoogleFonts.publicSans(
              fontSize: 9,
              color: isHighlighted ? const Color(0xFF0E7490) : const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  // 8. Section 5: Buyer Orders Fulfillment Card (with 5-item pagination)
  Widget _buildBuyerOrdersCard(
    BuildContext context,
    List<BuyerOrderStatusItem> allOrders,
    List<BuyerOrderStatusItem> paginatedOrders,
    int currentPage,
    int totalPages,
    bool isSoloMode,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'BUYER PURCHASE ORDERS',
                          style: GoogleFonts.publicSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF64748B),
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDFA),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF14C8B4).withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            '${allOrders.length} ${allOrders.length == 1 ? 'Order' : 'Orders'}',
                            style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF0B1220)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isSoloMode ? 'Fulfillment progress for selected style' : 'Active contracts sorted by delivery progress',
                      style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF94A3B8)),
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
                    MaterialPageRoute(builder: (_) => const ActiveBuyersScreen()),
                  );
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Buyers Hub',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1D4ED8),
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.arrow_forward_rounded, size: 12, color: Color(0xFF1D4ED8)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (paginatedOrders.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  'No active buyer contracts found.',
                  style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF94A3B8)),
                ),
              ),
            )
          else
            ...paginatedOrders.map((bo) {
              final barColor = bo.status == 'on_track'
                  ? const Color(0xFF10B981)
                  : (bo.status == 'caution' ? const Color(0xFFF59E0B) : const Color(0xFFF43F5E));

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              bo.buyerName,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0B1220),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Text(
                                bo.poNumber,
                                style: GoogleFonts.jetBrainsMono(fontSize: 9.5, color: const Color(0xFF64748B)),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${bo.percent}% fulfilled',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: barColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (bo.percent / 100).clamp(0.0, 1.0),
                        backgroundColor: const Color(0xFFE2E8F0),
                        color: barColor,
                        minHeight: 5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Delivered: ${_format(bo.deliveredPieces)} pcs', style: GoogleFonts.publicSans(fontSize: 10.5, color: const Color(0xFF64748B))),
                        Text('Target: ${_format(bo.targetPieces)} pcs', style: GoogleFonts.publicSans(fontSize: 10.5, color: const Color(0xFF64748B))),
                      ],
                    ),
                  ],
                ),
              );
            }),

          // Pagination Controls for Orders
          if (totalPages > 1) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: const Size(60, 30),
                    backgroundColor: Colors.white,
                  ),
                  onPressed: currentPage > 1 ? () => setState(() => _ordersPage--) : null,
                  icon: const Icon(Icons.chevron_left, size: 16),
                  label: const Text('Prev', style: TextStyle(fontSize: 11)),
                ),
                Text(
                  'Page $currentPage of $totalPages',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF64748B),
                  ),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: const Size(60, 30),
                    backgroundColor: Colors.white,
                  ),
                  onPressed: currentPage < totalPages ? () => setState(() => _ordersPage++) : null,
                  icon: const Icon(Icons.chevron_right, size: 16),
                  label: const Text('Next', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // 9. Section 6: Company Articles & Styles Directory (Paginated 5 per page)
  Widget _buildArticlesDirectoryCard(
    List<ArticleJourneyItem> allArticles,
    List<ArticleJourneyItem> paginatedArticles,
    int currentPage,
    int totalPages,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'COMPANY ARTICLES & STYLES',
                          style: GoogleFonts.publicSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF64748B),
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDFA),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF14C8B4).withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            '${allArticles.length} ${allArticles.length == 1 ? 'Style' : 'Styles'}',
                            style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF0B1220)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Garment styles catalog. Tap any style to inspect floor progress.',
                      style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF94A3B8)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (_selectedArticleId != 'ALL')
                InkWell(
                  onTap: () {
                    setState(() {
                      _selectedArticleId = 'ALL';
                    });
                  },
                  child: Text(
                    'Reset to All →',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1D4ED8),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          if (paginatedArticles.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  'No garment articles logged for this company.',
                  style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF94A3B8)),
                ),
              ),
            )
          else
            ...paginatedArticles.map((art) {
              final isSelected = _selectedArticleId == art.id;

              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedArticleId = art.id;
                    _ordersPage = 1;
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFFE2E8F0),
                      width: isSelected ? 1.4 : 1.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                ),
                                child: Text(
                                  art.artNo,
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF0B1220),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                art.category,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0B1220),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF1D4ED8) : Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFFCBD5E1),
                              ),
                            ),
                            child: Text(
                              isSelected ? 'Active Solo' : 'Select Solo',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Buyer: ${art.buyerName}',
                        style: GoogleFonts.publicSans(fontSize: 11, color: const Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (art.overallProgressPct / 100).clamp(0.0, 1.0),
                          backgroundColor: const Color(0xFFE2E8F0),
                          color: const Color(0xFF1D4ED8),
                          minHeight: 5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Contract: ${_format(art.buyerPoTarget)} pcs', style: GoogleFonts.publicSans(fontSize: 10, color: const Color(0xFF64748B))),
                          Text('Progress: ${art.overallProgressPct}%', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF1D4ED8))),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),

          // Pagination Controls for Articles
          if (totalPages > 1) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: const Size(60, 30),
                    backgroundColor: Colors.white,
                  ),
                  onPressed: currentPage > 1 ? () => setState(() => _articlesPage--) : null,
                  icon: const Icon(Icons.chevron_left, size: 16),
                  label: const Text('Prev', style: TextStyle(fontSize: 11)),
                ),
                Text(
                  'Page $currentPage of $totalPages',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF64748B),
                  ),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: const Size(60, 30),
                    backgroundColor: Colors.white,
                  ),
                  onPressed: currentPage < totalPages ? () => setState(() => _articlesPage++) : null,
                  icon: const Icon(Icons.chevron_right, size: 16),
                  label: const Text('Next', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // 10. Section 6B: Portal Usage & Login Location Section
  Widget _buildPortalUsageAndLocationSection(BuildContext context, OwnerLoginActivityData? activityData) {
    if (activityData == null) return const SizedBox.shrink();

    final days = activityData.days;
    final location = activityData.currentLocation;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDFA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x1A000000)),
                ),
                child: const Center(
                  child: Icon(Icons.schedule_rounded, color: Color(0xFF0B1220), size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Portal Usage & ',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0B1220),
                                  ),
                                ),
                                TextSpan(
                                  text: 'Login Location',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF1D4ED8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDFA),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0x1A000000)),
                          ),
                          child: Text(
                            'PAST 7 DAYS',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0B1220),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Weekly login hours and where you are signed in from right now.',
                      style: GoogleFonts.publicSans(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Legend: Active (Emerald) & Inactive (Slate)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Active',
                    style: GoogleFonts.publicSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF475569),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: const Color(0xFFCBD5E1), width: 0.8),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Inactive',
                    style: GoogleFonts.publicSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 2. 24x7 HOURLY LOGIN MATRIX CARD
          _PortalUsageHeatmapCard(days: days),

          const SizedBox(height: 14),

          // 3. Indian State Vector Map Card (Matching Web Mobile View)
          IndianStateVectorMapWidget(
            stateName: location.state,
            cityName: location.city,
            latitude: location.latitude,
            longitude: location.longitude,
          ),

          const SizedBox(height: 12),

          // 4. Two Simple Stat Cards: Past 7 Days & Most Active Time
          Row(
            children: [
              // Stat 1: Total Logins
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PAST 7 DAYS',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF94A3B8),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${activityData.totalSessionsPast7Days} Logins',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0B1220),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Active on ${activityData.activeDaysCount} ${activityData.activeDaysCount == 1 ? "day" : "days"}',
                        style: GoogleFonts.publicSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Stat 2: Peak Time
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MOST ACTIVE TIME',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF94A3B8),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        activityData.peakHour,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0B1220),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Shift usage window',
                        style: GoogleFonts.publicSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 11. Section 7: Division Heartbeat Section
  Widget _buildDivisionHeartbeatSection(BuildContext context, List<DivisionHeartbeatItem> heartbeats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DIVISION HEARTBEAT (${heartbeats.length} DEPARTMENTS)',
                    style: GoogleFonts.publicSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF64748B),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Verified active status & direct navigation',
                    style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF94A3B8)),
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
                  MaterialPageRoute(builder: (_) => const EnterpriseWorkspaceHubScreen()),
                );
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'All Modules',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1D4ED8),
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.arrow_forward_rounded, size: 12, color: Color(0xFF1D4ED8)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildTwoColumnGrid(
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.9,
          items: heartbeats.map((div) {
            final isActive = div.status == 'ACTIVE';

            return InkWell(
              onTap: () => _navigateDivision(context, div.id),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _getDivisionIcon(div.iconName),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isActive ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          div.name,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0B1220),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          div.metric,
                          style: GoogleFonts.publicSans(
                            fontSize: 10,
                            color: const Color(0xFF64748B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _getDivisionIcon(String name) {
    IconData icon;
    switch (name) {
      case 'Scissors':
        icon = Icons.content_cut_rounded;
        break;
      case 'Layers':
        icon = Icons.layers_outlined;
        break;
      case 'ShieldCheck':
        icon = Icons.verified_user_outlined;
        break;
      case 'Flame':
        icon = Icons.local_fire_department_outlined;
        break;
      case 'Warehouse':
        icon = Icons.store_mall_directory_outlined;
        break;
      case 'Truck':
        icon = Icons.local_shipping_outlined;
        break;
      default:
        icon = Icons.apps_rounded;
    }
    return Icon(icon, size: 18, color: const Color(0xFF0B1220));
  }

  void _navigateDivision(BuildContext context, String divisionId) {
    Widget target;
    switch (divisionId) {
      case 'cutting':
        target = const CuttingLayFloorScreen();
        break;
      case 'stitching':
        target = const EnterpriseWorkspaceHubScreen();
        break;
      case 'qc':
        target = const QualityClinicFloorScreen();
        break;
      case 'iron':
        target = const IronFloorScreen();
        break;
      case 'store':
        target = const CentralStoreGodownScreen();
        break;
      case 'dispatch':
        target = const DispatchLogisticsHubScreen();
        break;
      default:
        target = const EnterpriseWorkspaceHubScreen();
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => target));
  }
}

class _PortalUsageHeatmapCard extends StatefulWidget {
  final List<LoginDayActivity> days;

  const _PortalUsageHeatmapCard({required this.days});

  @override
  State<_PortalUsageHeatmapCard> createState() => _PortalUsageHeatmapCardState();
}

class _PortalUsageHeatmapCardState extends State<_PortalUsageHeatmapCard>
    with AutomaticKeepAliveClientMixin {
  static const double _rowHeight = 19.0;
  static const int _hoursPerDay = 24;
  static const double _timeColumnWidth = 42.0;

  int? _selectedDayIdx;
  int? _selectedHourIdx;

  @override
  bool get wantKeepAlive => true;

  @override
  void didUpdateWidget(covariant _PortalUsageHeatmapCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedDayIdx != null && _selectedDayIdx! >= widget.days.length) {
      _selectedDayIdx = null;
      _selectedHourIdx = null;
    }
  }

  String _hourLabel(int hourIdx) {
    if (widget.days.isNotEmpty && widget.days.first.hourlySlots.length > hourIdx) {
      return widget.days.first.hourlySlots[hourIdx].label;
    }
    return '${hourIdx.toString().padLeft(2, '0')}:00';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final days = widget.days;

    String? selectedInfo;
    bool selectedIsActive = false;
    int selectedLogins = 0;

    if (_selectedDayIdx != null &&
        _selectedHourIdx != null &&
        _selectedDayIdx! >= 0 &&
        _selectedDayIdx! < days.length) {
      final day = days[_selectedDayIdx!];
      final hourIdx = _selectedHourIdx!;
      final slot = day.hourlySlots.length > hourIdx
          ? day.hourlySlots[hourIdx]
          : LoginHourSlot(hour: hourIdx, label: _hourLabel(hourIdx), count: 0, isActive: false);
      selectedInfo = '${day.fullDateLabel} (${slot.label})';
      selectedIsActive = slot.isActive;
      selectedLogins = slot.count;
    }

    Widget buildMatrix() {
      return Column(
        children: [
          // Days Header Row
          Row(
            children: [
              SizedBox(
                width: _timeColumnWidth,
                child: Text(
                  'TIME',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9.0,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ),
              ...days.map((d) {
                return Expanded(
                  child: Column(
                    children: [
                      Text(
                        d.dayName.toUpperCase(),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 1),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: d.isToday ? const Color(0xFFE0F2FE) : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                          border: d.isToday ? Border.all(color: const Color(0xFFBAE6FD)) : null,
                        ),
                        child: Text(
                          d.formattedDate,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: d.isToday ? const Color(0xFF0369A1) : const Color(0xFF334155),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 6),

          // Single CustomPaint grid replacing 168 InkWell + AnimatedContainer widgets
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: _timeColumnWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(_hoursPerDay, (hourIdx) {
                    return SizedBox(
                      height: _rowHeight,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _hourLabel(hourIdx),
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, gridConstraints) {
                    final gridWidth = gridConstraints.maxWidth;
                    const gridHeight = _hoursPerDay * _rowHeight;
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (details) {
                        if (days.isEmpty || gridWidth <= 0) return;
                        final colWidth = gridWidth / days.length;
                        final col = (details.localPosition.dx / colWidth).floor().clamp(0, days.length - 1);
                        final row = (details.localPosition.dy / _rowHeight).floor().clamp(0, _hoursPerDay - 1);
                        setState(() {
                          _selectedDayIdx = col;
                          _selectedHourIdx = row;
                        });
                      },
                      child: RepaintBoundary(
                        child: CustomPaint(
                          size: Size(gridWidth, gridHeight),
                          isComplex: true,
                          willChange: false,
                          painter: _HeatmapGridPainter(
                            days: days,
                            rowHeight: _rowHeight,
                            selectedDayIdx: _selectedDayIdx,
                            selectedHourIdx: _selectedHourIdx,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              const minMatrixWidth = 268.0;
              if (constraints.maxWidth >= minMatrixWidth) {
                return buildMatrix();
              }
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: SizedBox(width: minMatrixWidth, child: buildMatrix()),
              );
            },
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: selectedInfo != null
                ? Row(
                    children: [
                      Icon(
                        selectedIsActive ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                        size: 14,
                        color: selectedIsActive ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: '$selectedInfo: ',
                                style: GoogleFonts.publicSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0B1220),
                                ),
                              ),
                              TextSpan(
                                text: selectedIsActive
                                    ? 'Active ($selectedLogins ${selectedLogins == 1 ? "login" : "logins"})'
                                    : 'No login during this hour',
                                style: GoogleFonts.publicSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: selectedIsActive ? const Color(0xFF059669) : const Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      const Icon(Icons.touch_app_outlined, size: 14, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 6),
                      Text(
                        'Tap any hour slot to check login details.',
                        style: GoogleFonts.publicSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _HeatmapGridPainter extends CustomPainter {
  final List<LoginDayActivity> days;
  final double rowHeight;
  final int? selectedDayIdx;
  final int? selectedHourIdx;

  static final Paint _activeFill = Paint()..color = const Color(0xFF10B981);
  static final Paint _inactiveFill = Paint()..color = const Color(0xFFE2E8F0);
  static final Paint _inactiveStroke = Paint()
    ..color = const Color(0xFFCBD5E1)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.5;
  static final Paint _selectedStroke = Paint()
    ..color = const Color(0xFF0B1220)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;

  const _HeatmapGridPainter({
    required this.days,
    required this.rowHeight,
    required this.selectedDayIdx,
    required this.selectedHourIdx,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (days.isEmpty || size.width <= 0) return;

    final colWidth = size.width / days.length;
    const radius = Radius.circular(3.5);
    const cellHeight = 15.0;
    final verticalInset = (rowHeight - cellHeight) / 2;

    for (int col = 0; col < days.length; col++) {
      final day = days[col];
      final left = col * colWidth + 2.0;
      final width = math.max(1.0, colWidth - 4.0);

      for (int row = 0; row < 24; row++) {
        final isActive = row < day.hourlySlots.length && day.hourlySlots[row].isActive;
        final isSelected = col == selectedDayIdx && row == selectedHourIdx;
        final top = row * rowHeight + verticalInset;
        final rrect = RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, width, cellHeight),
          radius,
        );

        canvas.drawRRect(rrect, isActive ? _activeFill : _inactiveFill);
        if (isSelected) {
          canvas.drawRRect(rrect.deflate(0.75), _selectedStroke);
        } else if (!isActive) {
          canvas.drawRRect(rrect.deflate(0.25), _inactiveStroke);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HeatmapGridPainter oldDelegate) {
    return oldDelegate.days != days ||
        oldDelegate.selectedDayIdx != selectedDayIdx ||
        oldDelegate.selectedHourIdx != selectedHourIdx ||
        oldDelegate.rowHeight != rowHeight;
  }
}
