import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../modules/widgets/workspace_hub_drawer.dart';
import '../modules/screens/enterprise_workspace_hub_screen.dart';
import '../modules/screens/company_profile_screen.dart';
import '../cutting/screens/cutting_notifications_screen.dart';
import '../cutting/screens/cutting_lay_floor_screen.dart';
import '../iron/screens/iron_floor_screen.dart';
import '../ready_goods/screens/quality_clinic_floor_screen.dart';
import '../store/screens/central_store_godown_screen.dart';
import '../dispatch/screens/dispatch_logistics_hub_screen.dart';
import '../admin/screens/reports_screen.dart';
import '../merchandising/screens/active_buyers_screen.dart';
import 'services/plant_operations_dashboard_service.dart';

class PlantOperationsDashboardScreen extends ConsumerStatefulWidget {
  const PlantOperationsDashboardScreen({super.key});

  @override
  ConsumerState<PlantOperationsDashboardScreen> createState() => _PlantOperationsDashboardScreenState();
}

class _PlantOperationsDashboardScreenState extends ConsumerState<PlantOperationsDashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final NumberFormat _numFormat = NumberFormat('#,##,###', 'en_IN');
  String? _selectedArticleId;

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
      appBar: _buildTopBar(context),
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

  PreferredSizeWidget _buildTopBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      titleSpacing: 0,
      shape: const Border(
        bottom: BorderSide(color: Color(0xFFE2E8F0), width: 0.8),
      ),
      leading: Center(
        child: InkWell(
          onTap: () => _scaffoldKey.currentState?.openDrawer(),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Icon(Icons.menu_rounded, color: Color(0xFF0B1220), size: 20),
          ),
        ),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/icon.png',
            height: 26,
            width: 26,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
          const SizedBox(width: 8),
          Image.asset(
            'assets/images/z_i_g_z_a.png',
            height: 19,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Text(
              'ZIGZA',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF0B1220),
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
      actions: [
        // Quick Add Button
        Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EnterpriseWorkspaceHubScreen()),
              );
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0B1220),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_rounded, color: Colors.white, size: 14),
                  const SizedBox(width: 2),
                  const Icon(Icons.arrow_drop_down_rounded, color: Colors.white, size: 14),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),

        // Notification Bell
        IconButton(
          icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF0B1220), size: 20),
          tooltip: 'Notifications',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CuttingNotificationsScreen()),
            );
          },
        ),

        // Profile Avatar
        Container(
          margin: const EdgeInsets.only(right: 12),
          child: IconButton(
            icon: const Icon(Icons.person_outline_rounded, color: Color(0xFF0B1220), size: 20),
            tooltip: 'Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CompanyProfileScreen()),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardContent(BuildContext context, PlantOperationsDashboardData data) {
    // Determine selected article
    final selectedArticle = data.articlesCatalog.firstWhere(
      (a) => a.id == (_selectedArticleId ?? (data.articlesCatalog.isNotEmpty ? data.articlesCatalog.first.id : '')),
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
    );

    return RefreshIndicator(
      color: const Color(0xFF0B1220),
      onRefresh: () => ref.read(plantOperationsDashboardProvider.notifier).fetchData(),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        children: [
          // 1. Header Card
          _buildHeaderCard(context, data),
          const SizedBox(height: 14),

          // 2. Stat Grid (2 columns x 3 rows)
          _buildStatGrid(data.pulse),
          const SizedBox(height: 14),

          // 3. Live Production Flow Card
          _buildLiveProductionFlowCard(data.pipeline),
          const SizedBox(height: 14),

          // 4. Daily Sewing Output (7-Day Trend) Card
          _buildDailyOutputTrendCard(data.outputTrend, data.dailyAverage),
          const SizedBox(height: 14),

          // 5. Quality Control Rate Card
          _buildQualityControlCard(data.qc),
          const SizedBox(height: 14),

          // 6. Buyer Orders Fulfillment Card
          _buildBuyerOrdersCard(context, data.buyerOrders),
          const SizedBox(height: 14),

          // 7. Fabric Stock in Godown Card
          _buildFabricStockCard(context, data.fabricStock),
          const SizedBox(height: 14),

          // 8. Article Deep-Dive Journey Card
          _buildArticleJourneyCard(data.articlesCatalog, selectedArticle),
          const SizedBox(height: 14),

          // 9. Division Heartbeat Section
          _buildDivisionHeartbeatSection(context, data.divisionHeartbeat),
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  // 1. Header Card
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
            'Real-time manufacturing throughput, multi-stage floor reconciliation, and executive metrics.',
            style: GoogleFonts.publicSans(
              fontSize: 12,
              color: const Color(0xFF64748B),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
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
                    'Reports & Analytics',
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

  // 2. Stat Grid (2 columns x 3 rows)
  Widget _buildStatGrid(FactoryPulseKPIs pulse) {
    final stats = [
      {'label': 'ACTIVE STYLES', 'value': _format(pulse.activeStyles)},
      {'label': 'RUNNING ORDERS', 'value': _format(pulse.runningOrders)},
      {'label': 'TARGET PIECES', 'value': _format(pulse.targetPieces)},
      {'label': "TODAY'S OUTPUT", 'value': _format(pulse.todayOutput)},
      {'label': 'IN GODOWN', 'value': _format(pulse.godownStock)},
      {'label': 'DISPATCHED', 'value': _format(pulse.dispatchedPieces)},
    ];

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: 6,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.1,
      ),
      itemBuilder: (context, index) {
        final s = stats[index];
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
      },
    );
  }

  // 3. Live Production Flow Card
  Widget _buildLiveProductionFlowCard(List<ProductionPipelineStage> pipeline) {
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  const SizedBox(height: 2),
                  Text(
                    'Current pieces across all manufacturing stages',
                    style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF94A3B8)),
                  ),
                ],
              ),
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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
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
        ],
      ),
    );
  }

  // 4. Daily Output Trend Card
  Widget _buildDailyOutputTrendCard(List<DailyOutputTrendItem> trend, int dailyAvg) {
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
            children: [
              Column(
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
                    'Stitched pieces per day • Avg: ${_format(dailyAvg)} pcs/day',
                    style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF64748B)),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF14C8B4), shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text('Stitched', style: GoogleFonts.publicSans(fontSize: 10.5, color: const Color(0xFF64748B))),
                  const SizedBox(width: 8),
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFF59E0B), shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text('Today', style: GoogleFonts.publicSans(fontSize: 10.5, color: const Color(0xFFB45309))),
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

  // 5. Quality Control Rate Card
  Widget _buildQualityControlCard(QCMetrics qc) {
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
              Column(
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
                    '3-Stage QC inspection pass vs scrap',
                    style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF94A3B8)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  'QC Standard',
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
                        'No quality defects recorded for this tenant.',
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

  // 6. Buyer Orders Fulfillment Card
  Widget _buildBuyerOrdersCard(BuildContext context, List<BuyerOrderStatusItem> buyerOrders) {
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BUYER ORDERS FULFILLMENT',
                    style: GoogleFonts.publicSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF64748B),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Delivered vs target pieces by active contract',
                    style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF94A3B8)),
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ActiveBuyersScreen()),
                  );
                },
                child: Row(
                  children: [
                    Text(
                      'Manage POs',
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
          if (buyerOrders.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  'No active buyer contracts booked for this company yet.',
                  style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF94A3B8)),
                ),
              ),
            )
          else
            ...buyerOrders.map((bo) {
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
        ],
      ),
    );
  }

  // 7. Fabric Stock in Godown Card
  Widget _buildFabricStockCard(BuildContext context, List<FabricStockItem> fabricStock) {
    final maxMeters = fabricStock.fold<int>(1, (max, item) => item.meters > max ? item.meters : max);

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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FABRIC STOCK IN GODOWN',
                    style: GoogleFonts.publicSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF64748B),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Meters on hand by raw material',
                    style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF94A3B8)),
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CentralStoreGodownScreen()),
                  );
                },
                child: Row(
                  children: [
                    Text(
                      'Store Ledger',
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
          if (fabricStock.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  'No fabric rolls logged in godown for this company.',
                  style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF94A3B8)),
                ),
              ),
            )
          else
            ...fabricStock.map((fab) {
              final pct = maxMeters > 0 ? (fab.meters / maxMeters).clamp(0.05, 1.0) : 0.05;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            fab.fabricType,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0B1220),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Text(
                                '${fab.rolls} Rolls',
                                style: GoogleFonts.jetBrainsMono(fontSize: 9.5, color: const Color(0xFF64748B)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${_format(fab.meters)} m',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0B1220),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        backgroundColor: const Color(0xFFE2E8F0),
                        color: const Color(0xFF14C8B4),
                        minHeight: 5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Color: ${fab.color}',
                      style: GoogleFonts.publicSans(fontSize: 10, color: const Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // 8. Article Deep-Dive Journey Card
  Widget _buildArticleJourneyCard(List<ArticleJourneyItem> catalog, ArticleJourneyItem selectedArticle) {
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
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDFA),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF14C8B4).withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.checkroom_rounded, color: Color(0xFF0B1220), size: 18),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Article Deep-Dive Journey',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0B1220),
                    ),
                  ),
                  Text(
                    'Select garment style to view lifecycle progress',
                    style: GoogleFonts.publicSans(fontSize: 11, color: const Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Dropdown Picker
          if (catalog.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: catalog.any((a) => a.id == selectedArticle.id) ? selectedArticle.id : catalog.first.id,
                  items: catalog.map((art) {
                    return DropdownMenuItem<String>(
                      value: art.id,
                      child: Text(
                        '${art.artNo} — ${art.description}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0B1220),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (newId) {
                    if (newId != null) {
                      setState(() {
                        _selectedArticleId = newId;
                      });
                    }
                  },
                ),
              ),
            ),
          const SizedBox(height: 12),

          // Dark Panel
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0B1220),
              borderRadius: BorderRadius.circular(14),
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
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            selectedArticle.artNo,
                            style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          selectedArticle.description,
                          style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          '${selectedArticle.overallProgressPct}%',
                          style: GoogleFonts.jetBrainsMono(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFF14C8B4)),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Contract Target: ${_format(selectedArticle.buyerPoTarget)} pieces',
                  style: GoogleFonts.jetBrainsMono(fontSize: 11, color: Colors.white70),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (selectedArticle.overallProgressPct / 100).clamp(0.0, 1.0),
                    backgroundColor: Colors.white24,
                    color: const Color(0xFF14C8B4),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 8-Step Grid (2 columns)
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 2.2,
            children: [
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

  // 9. Division Heartbeat Section
  Widget _buildDivisionHeartbeatSection(BuildContext context, List<DivisionHeartbeatItem> heartbeats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
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
                  'Verified active department status and direct navigation',
                  style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF94A3B8)),
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
        GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: heartbeats.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.9,
          ),
          itemBuilder: (context, idx) {
            final div = heartbeats[idx];
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
          },
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
