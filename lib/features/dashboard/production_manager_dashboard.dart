import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/connectivity_indicator.dart';
import '../auth/providers/auth_provider.dart';
import '../auth/screens/login_screen.dart';
import 'qc_dashboard.dart';
import 'mending_dashboard.dart';
import '../../../main.dart';

class ProductionManagerDashboard extends ConsumerStatefulWidget {
  const ProductionManagerDashboard({super.key});

  @override
  ConsumerState<ProductionManagerDashboard> createState() => _ProductionManagerDashboardState();
}

class _ProductionManagerDashboardState extends ConsumerState<ProductionManagerDashboard> {
  bool _isLoading = true;

  // Floor KPI Metrics
  int _totalActiveLots = 0;
  int _totalTargetPieces = 0;
  int _totalStitchedPieces = 0;
  int _totalQcPassedPieces = 0;
  int _totalMendingPieces = 0;
  double _floorEfficiency = 0.0;

  // Data collections
  List<Map<String, dynamic>> _allotments = [];
  List<Map<String, dynamic>> _linemenSummary = [];
  List<Map<String, dynamic>> _bottlenecks = [];

  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchFloorData();
    // Auto-refresh floor data every 45 seconds
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (mounted) _fetchFloorData(isSilent: true);
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  String _getShiftName() {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 14) {
      return 'Morning Shift';
    } else if (hour >= 14 && hour < 22) {
      return 'Evening Shift';
    } else {
      return 'Night Shift';
    }
  }

  Future<void> _fetchFloorData({bool isSilent = false}) async {
    if (!isSilent) {
      setState(() => _isLoading = true);
    }

    try {
      // 1. Fetch All Active / Recent Allotments
      final allotmentsRes = await supabase
          .from('allotments')
          .select('''
            id,
            challan_id,
            article_id,
            lineman_id,
            status,
            created_at,
            article:articles ( id, art_no, description, color_pattern, size_range, pattern_no ),
            lineman:profiles!allotments_lineman_id_fkey ( id, username )
          ''')
          .order('created_at', ascending: false)
          .limit(100);

      // 2. Fetch Allotment Variants
      final variantsRes = await supabase
          .from('allotment_variants')
          .select('id, allotment_id, color, size, quantity');

      // 3. Fetch Worker Assignments (Stitching progress)
      final assignmentsRes = await supabase
          .from('worker_assignments')
          .select('id, allotment_id, total_pieces, worker_name, status');

      // 4. Fetch QC Logs
      final qcLogsRes = await supabase
          .from('qc_logs')
          .select('''
            id,
            allotment_id,
            article_id,
            qty_checked,
            qty_passed,
            qty_rejected,
            defect_type,
            mending_status,
            from_lineman_id,
            created_at
          ''')
          .order('created_at', ascending: false)
          .limit(100);

      // --- Calculations & Mapping ---
      final List<Map<String, dynamic>> enrichedAllotments = [];
      final Map<String, Map<String, dynamic>> linemenMap = {};
      final List<Map<String, dynamic>> alertBottlenecks = [];

      int sumTarget = 0;
      int sumStitched = 0;
      int sumPassed = 0;
      int sumMending = 0;

      for (var a in allotmentsRes) {
        final aId = a['id'];
        final aStatus = (a['status'] as String? ?? 'PENDING').toUpperCase();

        // Target pieces from variants
        final vars = (variantsRes as List)
            .where((v) => v['allotment_id'] == aId)
            .toList();
        int targetQty = 0;
        for (var v in vars) {
          targetQty += (v['quantity'] as int? ?? 0);
        }

        // Stitched pieces from worker assignments
        final assigns = (assignmentsRes as List)
            .where((w) => w['allotment_id'] == aId)
            .toList();
        int stitchedQty = 0;
        for (var w in assigns) {
          stitchedQty += (w['total_pieces'] as int? ?? 0);
        }

        // QC Inspection summary
        final lotQcLogs = (qcLogsRes as List)
            .where((q) => q['allotment_id'] == aId)
            .toList();
        int passedQty = 0;
        int rejectedQty = 0;
        for (var q in lotQcLogs) {
          passedQty += (q['qty_passed'] as int? ?? 0);
          rejectedQty += (q['qty_rejected'] as int? ?? 0);
        }

        sumTarget += targetQty;
        sumStitched += stitchedQty;
        sumPassed += passedQty;
        sumMending += rejectedQty;

        // Stage classification
        String currentStage = 'STITCHING';
        if (passedQty >= targetQty && targetQty > 0) {
          currentStage = 'READY_TO_DISPATCH';
        } else if (passedQty > 0 || rejectedQty > 0) {
          currentStage = 'QC_INSPECTION';
        } else if (stitchedQty >= targetQty && targetQty > 0) {
          currentStage = 'MENDING_COUNTING';
        } else {
          currentStage = 'SEWING_LINES';
        }

        final enriched = {
          'id': aId,
          'challan_id': a['challan_id'],
          'article': a['article'] ?? {},
          'lineman': a['lineman'] ?? {},
          'status': aStatus,
          'stage': currentStage,
          'target_qty': targetQty,
          'stitched_qty': stitchedQty,
          'passed_qty': passedQty,
          'rejected_qty': rejectedQty,
          'variants': vars,
          'created_at': a['created_at'],
        };

        enrichedAllotments.add(enriched);

        // Group by Lineman
        final linemanObj = a['lineman'];
        final linemanId = linemanObj != null ? linemanObj['id'] : null;
        final linemanName = linemanObj != null ? linemanObj['username'] ?? 'Unassigned' : 'Unassigned';

        if (linemanId != null) {
          if (!linemenMap.containsKey(linemanId)) {
            linemenMap[linemanId] = {
              'id': linemanId,
              'name': linemanName,
              'active_lots': 0,
              'target_pcs': 0,
              'stitched_pcs': 0,
              'passed_pcs': 0,
              'mending_pcs': 0,
              'articles': <String>{},
            };
          }
          linemenMap[linemanId]!['active_lots'] = (linemenMap[linemanId]!['active_lots'] as int) + 1;
          linemenMap[linemanId]!['target_pcs'] = (linemenMap[linemanId]!['target_pcs'] as int) + targetQty;
          linemenMap[linemanId]!['stitched_pcs'] = (linemenMap[linemanId]!['stitched_pcs'] as int) + stitchedQty;
          linemenMap[linemanId]!['passed_pcs'] = (linemenMap[linemanId]!['passed_pcs'] as int) + passedQty;
          linemenMap[linemanId]!['mending_pcs'] = (linemenMap[linemanId]!['mending_pcs'] as int) + rejectedQty;
          if (a['article'] != null && a['article']['art_no'] != null) {
            (linemenMap[linemanId]!['articles'] as Set<String>).add(a['article']['art_no'].toString());
          }
        }

        // Bottleneck Detection (Stitched but not inspected, or high defect rate)
        if (rejectedQty > 0 && (rejectedQty / (targetQty > 0 ? targetQty : 1)) > 0.05) {
          alertBottlenecks.add({
            'type': 'HIGH_DEFECT_RATE',
            'severity': 'HIGH',
            'title': 'High Alteration Rate in Art ${a['article']?['art_no'] ?? ''}',
            'detail': '$rejectedQty pcs defective on Line $linemanName',
            'allotment': enriched,
          });
        }
      }

      final efficiency = sumTarget > 0 ? ((sumStitched / sumTarget) * 100).clamp(0.0, 100.0) : 0.0;

      if (mounted) {
        setState(() {
          _allotments = enrichedAllotments;
          _linemenSummary = linemenMap.values.toList();
          _bottlenecks = alertBottlenecks;
          _totalActiveLots = enrichedAllotments.where((a) => a['status'] != 'COMPLETED' && a['status'] != 'DISPATCHED').length;
          _totalTargetPieces = sumTarget;
          _totalStitchedPieces = sumStitched;
          _totalQcPassedPieces = sumPassed;
          _totalMendingPieces = sumMending;
          _floorEfficiency = efficiency;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Floor data fetch error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: _buildTopBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.steel))
          : RefreshIndicator(
              onRefresh: () => _fetchFloorData(),
              color: AppTheme.steel,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ConnectivityIndicator(),
                    const SizedBox(height: 8),

                    // Floor Header & Shift Info
                    _buildShiftBanner(),
                    const SizedBox(height: 14),

                    // Industrial KPI Metrics Grid
                    _buildKpiMetrics(),
                    const SizedBox(height: 18),

                    // Production Pipeline Stage Tracker
                    _buildPipelineStageTracker(),
                    const SizedBox(height: 18),

                    // Bottleneck & Critical Floor Alerts
                    if (_bottlenecks.isNotEmpty) ...[
                      _buildBottlenecksSection(),
                      const SizedBox(height: 18),
                    ],

                    // Line-by-Line Lineman Live Tracking
                    _buildLinemenFloorSection(),
                    const SizedBox(height: 18),

                    // Active Allotments & Lot Breakdown Table
                    _buildActiveAllotmentsSection(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  PreferredSizeWidget _buildTopBar() {
    return AppBar(
      backgroundColor: AppTheme.card,
      elevation: 0,
      titleSpacing: 16,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppTheme.steelMist,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.precision_manufacturing_rounded, size: 20, color: AppTheme.steel),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PRODUCTION MANAGER',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                'Floor Overview • Nubira Creation',
                style: GoogleFonts.publicSans(
                  fontSize: 11,
                  color: AppTheme.inkSoft,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Floor Refresh',
          icon: const Icon(Icons.sync_rounded, color: AppTheme.inkSoft),
          onPressed: () => _fetchFloorData(),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, color: AppTheme.inkSoft),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onSelected: (val) async {
            if (val == 'QC_VIEW') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const QcDashboard()),
              );
            } else if (val == 'MENDING_VIEW') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MendingDashboard()),
              );
            } else if (val == 'LOGOUT') {
              final nav = Navigator.of(context);
              await ref.read(authProvider.notifier).logout();
              if (mounted) {
                nav.pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            }
          },
          itemBuilder: (ctx) => [
            PopupMenuItem(
              value: 'QC_VIEW',
              child: Row(
                children: [
                  const Icon(Icons.verified_rounded, size: 18, color: AppTheme.steel),
                  const SizedBox(width: 10),
                  Text('Open QC Floor', style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'MENDING_VIEW',
              child: Row(
                children: [
                  const Icon(Icons.table_view_rounded, size: 18, color: AppTheme.steel),
                  const SizedBox(width: 10),
                  Text('Open Mending Counting', style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'LOGOUT',
              child: Row(
                children: [
                  const Icon(Icons.logout_rounded, size: 18, color: AppTheme.red),
                  const SizedBox(width: 10),
                  Text('Logout', style: GoogleFonts.publicSans(fontSize: 13, color: AppTheme.red, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildShiftBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.steelMist,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                const Icon(Icons.schedule_rounded, size: 13, color: AppTheme.steel),
                const SizedBox(width: 5),
                Text(
                  _getShiftName(),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.steel,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Text(
            '$_totalActiveLots Active Floor Lots',
            style: GoogleFonts.publicSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.ink,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppTheme.green,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiMetrics() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.55,
      children: [
        _buildMetricCard(
          title: 'TARGET VOLUME',
          value: '$_totalTargetPieces',
          unit: 'pcs',
          subtitle: 'Active floor work',
          icon: Icons.flag_rounded,
          color: AppTheme.steel,
          bgColor: AppTheme.steelMist,
        ),
        _buildMetricCard(
          title: 'SEWN OUTPUT',
          value: '$_totalStitchedPieces',
          unit: 'pcs',
          subtitle: '${_floorEfficiency.toStringAsFixed(1)}% Floor Progress',
          icon: Icons.check_circle_outline_rounded,
          color: AppTheme.green,
          bgColor: AppTheme.greenMist,
        ),
        _buildMetricCard(
          title: 'QC PASSED',
          value: '$_totalQcPassedPieces',
          unit: 'pcs',
          subtitle: 'Ready for gate pass',
          icon: Icons.verified_rounded,
          color: AppTheme.steelDark,
          bgColor: AppTheme.steelMist,
        ),
        _buildMetricCard(
          title: 'MENDING / DEFECTS',
          value: '$_totalMendingPieces',
          unit: 'pcs',
          subtitle: _totalMendingPieces > 0 ? 'Pending line repairs' : 'Zero alterations',
          icon: Icons.handyman_rounded,
          color: _totalMendingPieces > 0 ? AppTheme.amber : AppTheme.inkFaint,
          bgColor: _totalMendingPieces > 0 ? AppTheme.amberMist : AppTheme.bg,
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String unit,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.publicSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.inkSoft,
                  letterSpacing: 0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6)),
                child: Icon(icon, size: 14, color: color),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: GoogleFonts.publicSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.inkFaint,
                ),
              ),
            ],
          ),
          Text(
            subtitle,
            style: GoogleFonts.publicSans(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPipelineStageTracker() {
    int sewingCount = _allotments.where((a) => a['stage'] == 'SEWING_LINES').length;
    int mendingCount = _allotments.where((a) => a['stage'] == 'MENDING_COUNTING').length;
    int qcCount = _allotments.where((a) => a['stage'] == 'QC_INSPECTION').length;
    int readyCount = _allotments.where((a) => a['stage'] == 'READY_TO_DISPATCH').length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'LIVE FLOOR PIPELINE',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                'Real-time Progression',
                style: GoogleFonts.publicSans(
                  fontSize: 11,
                  color: AppTheme.inkFaint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildPipelineNode('1. Sewing', '$sewingCount Lots', AppTheme.steel),
              _buildPipelineConnector(),
              _buildPipelineNode('2. Counting', '$mendingCount Lots', AppTheme.amber),
              _buildPipelineConnector(),
              _buildPipelineNode('3. QC Floor', '$qcCount Lots', AppTheme.steelDark),
              _buildPipelineConnector(),
              _buildPipelineNode('4. Dispatch', '$readyCount Lots', AppTheme.green),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPipelineNode(String title, String count, Color accent) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: accent.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: GoogleFonts.publicSans(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              count,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppTheme.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPipelineConnector() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 3),
      child: Icon(Icons.arrow_forward_ios_rounded, size: 10, color: AppTheme.inkFaint),
    );
  }

  Widget _buildBottlenecksSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.redMist,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.red.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, size: 16, color: AppTheme.red),
              const SizedBox(width: 8),
              Text(
                'BOTTLENECK ALERTS',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.red,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._bottlenecks.map((b) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Container(width: 5, height: 5, decoration: const BoxDecoration(color: AppTheme.red, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${b['title']} • ${b['detail']}',
                      style: GoogleFonts.publicSans(fontSize: 11.5, color: AppTheme.ink, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildLinemenFloorSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'LINEMEN & LINE PERFORMANCE',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppTheme.ink,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              '${_linemenSummary.length} Active Lines',
              style: GoogleFonts.publicSans(
                fontSize: 11,
                color: AppTheme.inkSoft,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_linemenSummary.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Text(
              'No active lines assigned at the moment.',
              style: GoogleFonts.publicSans(fontSize: 12, color: AppTheme.inkSoft),
              textAlign: TextAlign.center,
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _linemenSummary.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final line = _linemenSummary[i];
              final target = line['target_pcs'] as int? ?? 0;
              final stitched = line['stitched_pcs'] as int? ?? 0;
              final mending = line['mending_pcs'] as int? ?? 0;
              final double progress = target > 0 ? (stitched / target).clamp(0.0, 1.0) : 0.0;
              final articles = (line['articles'] as Set<String>).join(', ');

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
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
                                color: AppTheme.steelMist,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.person_outline_rounded, size: 16, color: AppTheme.steel),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  line['name'].toString().toUpperCase(),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.ink,
                                  ),
                                ),
                                if (articles.isNotEmpty)
                                  Text(
                                    'Art: $articles',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 10.5,
                                      color: AppTheme.inkSoft,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$stitched / $target pcs',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.steel,
                              ),
                            ),
                            if (mending > 0)
                              Text(
                                '$mending pcs in alteration',
                                style: GoogleFonts.publicSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.amber,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: AppTheme.bg,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          progress >= 1.0 ? AppTheme.green : AppTheme.steel,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildActiveAllotmentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ACTIVE FLOOR ALLOTMENTS',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppTheme.ink,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              '${_allotments.length} Total Lots',
              style: GoogleFonts.publicSans(
                fontSize: 11,
                color: AppTheme.inkSoft,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _allotments.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (ctx, i) {
            final lot = _allotments[i];
            final article = lot['article'] as Map<String, dynamic>? ?? {};
            final artNo = article['art_no'] ?? 'N/A';
            final color = article['color_pattern'] ?? 'Standard';
            final sizeRange = article['size_range'] ?? 'STD';
            final target = lot['target_qty'] as int? ?? 0;
            final stitched = lot['stitched_qty'] as int? ?? 0;
            final passed = lot['passed_qty'] as int? ?? 0;
            final stage = lot['stage'] as String? ?? 'SEWING_LINES';

            Color stageColor = AppTheme.steel;
            String stageLabel = 'Sewing';
            if (stage == 'READY_TO_DISPATCH') {
              stageColor = AppTheme.green;
              stageLabel = 'Ready to Dispatch';
            } else if (stage == 'QC_INSPECTION') {
              stageColor = AppTheme.steelDark;
              stageLabel = 'QC Floor';
            } else if (stage == 'MENDING_COUNTING') {
              stageColor = AppTheme.amber;
              stageLabel = 'In Counting';
            }

            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _showChallanBreakdownModal(lot),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.steelMist,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'ART',
                            style: GoogleFonts.publicSans(fontSize: 8.5, fontWeight: FontWeight.w700, color: AppTheme.inkFaint),
                          ),
                          Text(
                            '$artNo',
                            style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.steel),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '$color',
                                style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.ink),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: AppTheme.bg,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppTheme.border),
                                ),
                                child: Text(
                                  '$sizeRange',
                                  style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppTheme.inkSoft, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Lineman: ${lot['lineman']?['username'] ?? 'Unassigned'} • Stitched: $stitched / $target pcs (Passed: $passed)',
                            style: GoogleFonts.publicSans(fontSize: 11, color: AppTheme.inkSoft),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: stageColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: stageColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        stageLabel,
                        style: GoogleFonts.publicSans(fontSize: 10, fontWeight: FontWeight.w700, color: stageColor),
                      ),
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

  // Exact Challan Article Reference Sheet Modal
  void _showChallanBreakdownModal(Map<String, dynamic> lot) {
    final article = lot['article'] as Map<String, dynamic>? ?? {};
    final variants = lot['variants'] as List<dynamic>? ?? [];
    final artNo = article['art_no'] ?? 'N/A';
    final color = article['color_pattern'] ?? 'Standard';
    final sizeRange = article['size_range'] ?? 'STD';
    final target = lot['target_qty'] as int? ?? 0;
    final stitched = lot['stitched_qty'] as int? ?? 0;
    final passed = lot['passed_qty'] as int? ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CHALLAN ARTICLE SHEET',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.ink,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          'Art: $artNo • $color ($sizeRange)',
                          style: GoogleFonts.publicSans(fontSize: 11.5, color: AppTheme.inkSoft, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: AppTheme.inkSoft),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppTheme.border),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    // Summary cards
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: AppTheme.bg, borderRadius: BorderRadius.circular(10)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('TARGET PCS', style: GoogleFonts.publicSans(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppTheme.inkFaint)),
                                Text('$target', style: GoogleFonts.jetBrainsMono(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.ink)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: AppTheme.bg, borderRadius: BorderRadius.circular(10)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('STITCHED PCS', style: GoogleFonts.publicSans(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppTheme.inkFaint)),
                                Text('$stitched', style: GoogleFonts.jetBrainsMono(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.steel)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: AppTheme.bg, borderRadius: BorderRadius.circular(10)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('QC PASSED', style: GoogleFonts.publicSans(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppTheme.inkFaint)),
                                Text('$passed', style: GoogleFonts.jetBrainsMono(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.green)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    Text(
                      'COLOUR × SIZE BREAKDOWN',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.ink, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.border),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Table(
                        border: TableBorder.symmetric(inside: const BorderSide(color: AppTheme.border)),
                        children: [
                          TableRow(
                            decoration: const BoxDecoration(color: AppTheme.bg),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text('COLOUR', style: GoogleFonts.publicSans(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.inkSoft)),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text('SIZE', style: GoogleFonts.publicSans(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.inkSoft), textAlign: TextAlign.center),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text('TARGET PCS', style: GoogleFonts.publicSans(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.inkSoft), textAlign: TextAlign.right),
                              ),
                            ],
                          ),
                          if (variants.isEmpty)
                            TableRow(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text('Standard', style: GoogleFonts.publicSans(fontSize: 11.5)),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text(sizeRange, style: GoogleFonts.jetBrainsMono(fontSize: 11.5), textAlign: TextAlign.center),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text('$target', style: GoogleFonts.jetBrainsMono(fontSize: 11.5, fontWeight: FontWeight.w700), textAlign: TextAlign.right),
                                ),
                              ],
                            )
                          else
                            ...variants.map((v) {
                              return TableRow(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Text('${v['color'] ?? 'Standard'}', style: GoogleFonts.publicSans(fontSize: 11.5, fontWeight: FontWeight.w600)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Text('${v['size'] ?? 'STD'}', style: GoogleFonts.jetBrainsMono(fontSize: 11.5), textAlign: TextAlign.center),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Text('${v['quantity'] ?? 0}', style: GoogleFonts.jetBrainsMono(fontSize: 11.5, fontWeight: FontWeight.w700), textAlign: TextAlign.right),
                                  ),
                                ],
                              );
                            }),
                        ],
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
}
