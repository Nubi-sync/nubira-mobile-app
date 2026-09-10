import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/connectivity_indicator.dart';
import '../../core/utils/parser_utils.dart';
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

  // Lineman Filter
  String? _selectedLinemanId;
  String? _selectedLinemanName;

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
      // 1. Fetch All Active / Recent Allotments with comprehensive stage and custody columns
      final allotmentsRes = await supabase
          .from('allotments')
          .select('''
            id,
            challan_id,
            article_id,
            lineman_id,
            status,
            target_qty,
            mending_status,
            mending_total_counted,
            mending_verified_at,
            handed_to_mending_by,
            handed_to_mending_at,
            qc_status,
            qc_total_passed,
            qc_total_alter,
            qc_received_at,
            qc_supervisor_name,
            handed_to_qc_by,
            handed_to_qc_at,
            store_inward_status,
            created_at,
            article:articles ( id, art_no, description, size_rates ),
            lineman:profiles!allotments_lineman_id_fkey ( id, username ),
            challan:challans ( id, challan_no, brand )
          ''')
          .order('created_at', ascending: false)
          .limit(100);

      // 2. Fetch Allotment Variants safely
      List<dynamic> variantsRes = [];
      try {
        variantsRes = await supabase
            .from('allotment_variants')
            .select('id, allotment_id, color, size, quantity');
      } catch (e) {
        debugPrint('Floor data: allotment_variants fetch warning: $e');
      }

      // 3. Fetch Worker Assignments (Stitching progress) with correct schema columns
      List<dynamic> assignmentsRes = [];
      try {
        assignmentsRes = await supabase
            .from('worker_assignments')
            .select('id, allotment_id, worker_name, assigned_qty, completed_qty, status');
      } catch (e) {
        debugPrint('Floor data: worker_assignments fetch warning: $e');
      }

      // 4. Fetch QC Logs with actual schema columns
      List<dynamic> qcLogsRes = [];
      try {
        qcLogsRes = await supabase
            .from('qc_logs')
            .select('id, allotment_id, article_id, qty_received, qty_passed, qty_rejected, defect_type, created_at')
            .order('created_at', ascending: false)
            .limit(100);
      } catch (e) {
        debugPrint('Floor data: qc_logs fetch warning: $e');
      }

      // --- Calculations & Mapping ---
      final List<Map<String, dynamic>> enrichedAllotments = [];
      final Map<String, Map<String, dynamic>> linemenMap = {};
      final List<Map<String, dynamic>> alertBottlenecks = [];

      int sumTarget = 0;
      int sumStitched = 0;
      int sumPassed = 0;
      int sumMending = 0;

      for (var a in (allotmentsRes as List)) {
        final aId = a['id'];
        final aStatus = (a['status']?.toString() ?? 'PENDING').toUpperCase();
        final mendingStatus = (a['mending_status']?.toString() ?? '').toUpperCase();
        final qcStatus = (a['qc_status']?.toString() ?? '').toUpperCase();
        final storeStatus = (a['store_inward_status']?.toString() ?? '').toUpperCase();

        // 1. Target pieces: prefer variants sum, fallback to allotments.target_qty
        final vars = variantsRes
            .where((v) => v['allotment_id']?.toString() == aId?.toString())
            .toList();
        int targetQty = 0;
        for (var v in vars) {
          targetQty += parseQty(v['quantity']);
        }
        if (targetQty == 0 && a['target_qty'] != null) {
          targetQty = parseQty(a['target_qty']);
        }

        // 2. Stitched pieces: from worker assignments OR mending counted OR completed status
        final assigns = assignmentsRes
            .where((w) => w['allotment_id']?.toString() == aId?.toString())
            .toList();
        int workerStitched = 0;
        for (var w in assigns) {
          final wStatus = (w['status']?.toString() ?? '').toUpperCase();
          if (wStatus == 'DONE' || wStatus == 'COMPLETED') {
            workerStitched += parseQty(w['completed_qty'], parseQty(w['assigned_qty']));
          } else {
            workerStitched += parseQty(w['completed_qty']);
          }
        }

        int mendingCounted = parseQty(a['mending_total_counted']);
        int stitchedQty = workerStitched > 0 ? workerStitched : mendingCounted;
        if (stitchedQty == 0 && (aStatus == 'COMPLETED' || mendingStatus.contains('MENDING') || mendingStatus == 'QC_PENDING' || a['handed_to_mending_at'] != null)) {
          stitchedQty = targetQty;
        }

        // 3. QC Inspection summary: from qc_logs OR allotments aggregate
        final lotQcLogs = qcLogsRes
            .where((q) => q['allotment_id']?.toString() == aId?.toString())
            .toList();
        int logPassed = 0;
        int logRejected = 0;
        for (var q in lotQcLogs) {
          logPassed += parseQty(q['qty_passed'], parseQty(q['passed_qty']));
          logRejected += parseQty(q['qty_rejected'], parseQty(q['rejected_qty']));
        }
        int passedQty = logPassed > 0 ? logPassed : parseQty(a['qc_total_passed']);
        int rejectedQty = logRejected > 0 ? logRejected : parseQty(a['qc_total_alter']);

        sumTarget += targetQty;
        sumStitched += stitchedQty;
        sumPassed += passedQty;
        sumMending += rejectedQty;

        // 4. Live stage classification based on actual floor progression
        String currentStage = 'SEWING_LINES';
        if (storeStatus == 'RECEIVED' || aStatus == 'DISPATCHED' || (passedQty >= targetQty && targetQty > 0)) {
          currentStage = 'READY_TO_DISPATCH';
        } else if (qcStatus == 'QC_PENDING' || qcStatus == 'IN_PROGRESS' || qcStatus == 'RECEIVED' || passedQty > 0 || rejectedQty > 0 || a['handed_to_qc_at'] != null) {
          currentStage = 'QC_INSPECTION';
        } else if (mendingStatus.contains('MENDING') || mendingStatus == 'QC_PENDING' || a['handed_to_mending_at'] != null || (stitchedQty >= targetQty && targetQty > 0)) {
          currentStage = 'MENDING_COUNTING';
        } else {
          currentStage = 'SEWING_LINES';
        }

        // Extract real colors and size range from allotment variants
        final Set<String> colorSet = {};
        final List<String> sizeList = [];
        for (var v in vars) {
          final c = v['color']?.toString().trim();
          if (c != null && c.isNotEmpty && c.toUpperCase() != 'STANDARD') {
            colorSet.add(c);
          }
          final s = v['size']?.toString().trim();
          if (s != null && s.isNotEmpty && !sizeList.contains(s)) {
            sizeList.add(s);
          }
        }
        final desc = a['article']?['description']?.toString().trim() ?? '';
        final colorStr = colorSet.isNotEmpty
            ? colorSet.join(', ')
            : (desc.isNotEmpty ? desc : 'All Sizes');
        final sizeStr = sizeList.isNotEmpty
            ? (sizeList.length > 3 ? '${sizeList.first}-${sizeList.last}' : sizeList.join('/'))
            : '';

        final enriched = {
          'id': aId,
          'challan_id': a['challan_id'],
          'challan': a['challan'] ?? {},
          'article': a['article'] ?? {},
          'lineman': a['lineman'] ?? {},
          'color': colorStr,
          'size_range': sizeStr,
          'status': aStatus,
          'stage': currentStage,
          'target_qty': targetQty,
          'stitched_qty': stitchedQty,
          'passed_qty': passedQty,
          'rejected_qty': rejectedQty,
          'variants': vars,
          'created_at': a['created_at'],
          'mending_status': mendingStatus,
          'mending_total_counted': mendingCounted,
          'handed_to_mending_by': a['handed_to_mending_by'],
          'handed_to_mending_at': a['handed_to_mending_at'],
          'qc_status': qcStatus,
          'qc_total_passed': passedQty,
          'qc_total_alter': rejectedQty,
          'handed_to_qc_by': a['handed_to_qc_by'],
          'handed_to_qc_at': a['handed_to_qc_at'],
          'store_inward_status': storeStatus,
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
          linemenMap[linemanId]!['active_lots'] = parseQty(linemenMap[linemanId]!['active_lots']) + 1;
          linemenMap[linemanId]!['target_pcs'] = parseQty(linemenMap[linemanId]!['target_pcs']) + targetQty;
          linemenMap[linemanId]!['stitched_pcs'] = parseQty(linemenMap[linemanId]!['stitched_pcs']) + stitchedQty;
          linemenMap[linemanId]!['passed_pcs'] = parseQty(linemenMap[linemanId]!['passed_pcs']) + passedQty;
          linemenMap[linemanId]!['mending_pcs'] = parseQty(linemenMap[linemanId]!['mending_pcs']) + rejectedQty;
          if (a['article'] != null && a['article']['art_no'] != null) {
            (linemenMap[linemanId]!['articles'] as Set<String>).add(a['article']['art_no'].toString());
          }
        }

        // Bottleneck Detection (High alteration rate)
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
          _totalActiveLots = enrichedAllotments.where((a) => a['status'] != 'DISPATCHED' && a['store_inward_status'] != 'RECEIVED').length;
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                  'Tap any line for complete history & floor filter',
                  style: GoogleFonts.publicSans(
                    fontSize: 10.5,
                    color: AppTheme.inkSoft,
                  ),
                ),
              ],
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
              final lmId = line['id']?.toString();
              final isSelected = _selectedLinemanId == lmId;
              final target = parseQty(line['target_pcs']);
              final stitched = parseQty(line['stitched_pcs']);
              final mending = parseQty(line['mending_pcs']);
              final double progress = target > 0 ? (stitched / target).clamp(0.0, 1.0) : 0.0;
              final articles = ((line['articles'] as Set?)?.map((e) => e.toString()) ?? []).join(', ');

              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _showLinemanHistoryModal(line),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.steelMist.withValues(alpha: 0.4) : AppTheme.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppTheme.steel : AppTheme.border,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isSelected ? AppTheme.steel : AppTheme.steelMist,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.person_outline_rounded,
                              size: 16,
                              color: isSelected ? Colors.white : AppTheme.steel,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      line['name'].toString().toUpperCase(),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.ink,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                    if (isSelected) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: AppTheme.steel,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'FILTER ACTIVE',
                                          style: GoogleFonts.publicSans(
                                            fontSize: 8,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (articles.isNotEmpty)
                                  Text(
                                    'Art: $articles',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 10.5,
                                      color: AppTheme.inkSoft,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
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
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildActiveAllotmentsSection() {
    final filteredLots = _selectedLinemanId == null
        ? _allotments
        : _allotments.where((a) => a['lineman']?['id']?.toString() == _selectedLinemanId).toList();

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
              _selectedLinemanId != null
                  ? '${filteredLots.length} of ${_allotments.length} Lots'
                  : '${_allotments.length} Total Lots',
              style: GoogleFonts.publicSans(
                fontSize: 11,
                color: AppTheme.inkSoft,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Lineman Quick Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildFilterChip(
                label: 'All Lines',
                count: _allotments.length,
                isSelected: _selectedLinemanId == null,
                onTap: () {
                  setState(() {
                    _selectedLinemanId = null;
                    _selectedLinemanName = null;
                  });
                },
              ),
              const SizedBox(width: 8),
              ..._linemenSummary.map((line) {
                final lmId = line['id']?.toString();
                final isSel = _selectedLinemanId == lmId;
                final activeLots = parseQty(line['active_lots']);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildFilterChip(
                    label: line['name']?.toString().toUpperCase() ?? 'LINE',
                    count: activeLots,
                    isSelected: isSel,
                    onTap: () {
                      setState(() {
                        if (isSel) {
                          _selectedLinemanId = null;
                          _selectedLinemanName = null;
                        } else {
                          _selectedLinemanId = lmId;
                          _selectedLinemanName = line['name']?.toString();
                        }
                      });
                    },
                  ),
                );
              }),
            ],
          ),
        ),
        if (_selectedLinemanId != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.steelMist.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.steel.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.filter_alt_rounded, size: 16, color: AppTheme.steel),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Filtered by: ${_selectedLinemanName?.toUpperCase() ?? "Lineman"} (${filteredLots.length} lots)',
                    style: GoogleFonts.publicSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.steelDark,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                InkWell(
                  onTap: () {
                    setState(() {
                      _selectedLinemanId = null;
                      _selectedLinemanName = null;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.close, size: 12, color: AppTheme.inkSoft),
                        const SizedBox(width: 4),
                        Text(
                          'Clear',
                          style: GoogleFonts.publicSans(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.ink,
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
        const SizedBox(height: 10),
        if (filteredLots.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              children: [
                const Icon(Icons.assignment_late_outlined, size: 36, color: AppTheme.inkFaint),
                const SizedBox(height: 8),
                Text(
                  'No allotments found',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.inkSoft,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _selectedLinemanName != null
                      ? 'No active lots assigned to $_selectedLinemanName.'
                      : 'Floor allotments list is empty.',
                  style: GoogleFonts.publicSans(fontSize: 11, color: AppTheme.inkFaint),
                ),
                if (_selectedLinemanId != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _selectedLinemanId = null;
                        _selectedLinemanName = null;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.steel),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(
                      'Clear Filter',
                      style: GoogleFonts.publicSans(fontSize: 12, color: AppTheme.steel, fontWeight: FontWeight.w700),
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
            itemCount: filteredLots.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final lot = filteredLots[i];
            final article = parseMap(lot['article']);
            final artNo = article['art_no'] ?? 'N/A';
            final color = (lot['color']?.toString().trim().isNotEmpty == true) ? lot['color'].toString().trim() : (article['description']?.toString() ?? 'All Sizes');
            final sizeRange = lot['size_range']?.toString().trim() ?? '';
            final challan = parseMap(lot['challan']);
            final challanNo = challan['challan_no']?.toString();
            final target = parseQty(lot['target_qty']);
            final stitched = parseQty(lot['stitched_qty']);
            final passed = parseQty(lot['passed_qty']);
            final stage = lot['stage']?.toString() ?? 'SEWING_LINES';

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
                              Expanded(
                                child: Text(
                                  color,
                                  style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.ink),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              if (sizeRange.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: AppTheme.bg,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: AppTheme.border),
                                  ),
                                  child: Text(
                                    sizeRange,
                                    style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppTheme.inkSoft, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                              if (challanNo != null && challanNo.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: AppTheme.steelMist,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'DC #$challanNo',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 9.5,
                                      color: AppTheme.steel,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Lineman: ${lot['lineman']?['username'] ?? 'Unassigned'} • Stitched: $stitched / $target pcs (Passed: $passed)',
                            style: GoogleFonts.publicSans(fontSize: 11, color: AppTheme.inkSoft),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                lot['handed_to_mending_at'] != null ? Icons.check_circle_outline : Icons.schedule_rounded,
                                size: 12,
                                color: lot['handed_to_mending_at'] != null ? AppTheme.green : AppTheme.steel,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  lot['handed_to_mending_at'] != null
                                      ? 'Handed to Mending: ${lot['handed_to_mending_by'] ?? 'Done'}${parseQty(lot['mending_total_counted']) > 0 ? " • Counted: ${lot['mending_total_counted']} pcs" : ""}'
                                      : 'On Stitching Line',
                                  style: GoogleFonts.publicSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: lot['handed_to_mending_at'] != null ? AppTheme.steelDark : AppTheme.inkFaint,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
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
    final article = parseMap(lot['article']);
    final variants = parseList(lot['variants']);
    final artNo = article['art_no'] ?? 'N/A';
    final color = (lot['color']?.toString().trim().isNotEmpty == true) ? lot['color'].toString().trim() : (article['description']?.toString() ?? 'All Sizes');
    final sizeRange = lot['size_range']?.toString().trim() ?? '';
    final challan = parseMap(lot['challan']);
    final challanNo = challan['challan_no']?.toString();
    final target = parseQty(lot['target_qty']);
    final stitched = parseQty(lot['stitched_qty']);
    final passed = parseQty(lot['passed_qty']);

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
                          'Art: $artNo • $color${sizeRange.isNotEmpty ? " ($sizeRange)" : ""}${challanNo != null && challanNo.isNotEmpty ? " • DC #$challanNo" : ""}',
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
                                  child: Text(color.isNotEmpty ? color : 'All Colors', style: GoogleFonts.publicSans(fontSize: 11.5)),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text(sizeRange.isNotEmpty ? sizeRange : 'All Sizes', style: GoogleFonts.jetBrainsMono(fontSize: 11.5), textAlign: TextAlign.center),
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
                    const SizedBox(height: 18),
                    Text(
                      'FLOOR HANDOVER & CUSTODY',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.bg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Column(
                        children: [
                          _buildHandoverRow(
                            step: '1',
                            title: 'Sewing Floor (Lineman)',
                            detail: 'Assigned to: ${lot['lineman']?['username'] ?? 'Unassigned'}',
                            badge: '$target pcs Allotted',
                            isDone: true,
                            badgeColor: AppTheme.steel,
                          ),
                          const Divider(height: 16, color: AppTheme.border),
                          _buildHandoverRow(
                            step: '2',
                            title: 'Mending / Counting Handover',
                            detail: lot['handed_to_mending_at'] != null
                                ? 'Handed by: ${lot['handed_to_mending_by'] ?? 'Lineman'}'
                                : 'In Stitching (Pending Handover)',
                            badge: parseQty(lot['mending_total_counted']) > 0
                                ? '${lot['mending_total_counted']} pcs Counted'
                                : (lot['handed_to_mending_at'] != null ? 'Handed Over' : 'Pending'),
                            isDone: lot['handed_to_mending_at'] != null || parseQty(lot['mending_total_counted']) > 0,
                            badgeColor: AppTheme.amber,
                          ),
                          const Divider(height: 16, color: AppTheme.border),
                          _buildHandoverRow(
                            step: '3',
                            title: 'QC Inspection Handover',
                            detail: lot['handed_to_qc_at'] != null
                                ? 'Supervisor: ${lot['qc_supervisor_name'] ?? lot['handed_to_qc_by'] ?? 'QC'}'
                                : 'Pending Counting Verification',
                            badge: passed > 0
                                ? '$passed Passed / ${lot['rejected_qty'] ?? 0} Alter'
                                : (lot['handed_to_qc_at'] != null ? 'In QC' : 'Pending'),
                            isDone: lot['handed_to_qc_at'] != null || passed > 0,
                            badgeColor: AppTheme.green,
                          ),
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

  Widget _buildHandoverRow({
    required String step,
    required String title,
    required String detail,
    required String badge,
    required bool isDone,
    required Color badgeColor,
  }) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDone ? badgeColor.withValues(alpha: 0.15) : AppTheme.border,
            border: Border.all(color: isDone ? badgeColor : AppTheme.inkFaint, width: 1.5),
          ),
          alignment: Alignment.center,
          child: Text(
            step,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: isDone ? badgeColor : AppTheme.inkFaint,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.ink,
                ),
              ),
              Text(
                detail,
                style: GoogleFonts.publicSans(
                  fontSize: 10.5,
                  color: AppTheme.inkSoft,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: (isDone ? badgeColor : AppTheme.inkFaint).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            badge,
            style: GoogleFonts.publicSans(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: isDone ? badgeColor : AppTheme.inkFaint,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.steel : AppTheme.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.steel : AppTheme.border,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.steel.withValues(alpha: 0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? Colors.white : AppTheme.ink,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withValues(alpha: 0.25) : AppTheme.steelMist,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : AppTheme.steel,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Lineman Performance & Lifetime Article History Modal
  void _showLinemanHistoryModal(Map<String, dynamic> line) {
    final lmId = line['id']?.toString();
    final lmName = line['name']?.toString().toUpperCase() ?? 'LINEMAN';
    final target = parseQty(line['target_pcs']);
    final stitched = parseQty(line['stitched_pcs']);
    final passed = parseQty(line['passed_pcs']);
    final mending = parseQty(line['mending_pcs']);
    final activeLotsCount = parseQty(line['active_lots']);
    final double passRate = stitched > 0 ? ((passed / stitched) * 100).clamp(0.0, 100.0) : 100.0;
    final double efficiency = target > 0 ? ((stitched / target) * 100).clamp(0.0, 100.0) : 0.0;

    // Filter allotments for this lineman
    final linemanLots = _allotments.where((a) => a['lineman']?['id']?.toString() == lmId).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isCurrentlySelected = _selectedLinemanId == lmId;

        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
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
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.steelMist,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.person_rounded, size: 20, color: AppTheme.steel),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lmName,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.ink,
                                  ),
                                ),
                                Text(
                                  'SEWING FLOOR LINE OPERATOR',
                                  style: GoogleFonts.publicSans(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.steel,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20, color: AppTheme.inkSoft),
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
                        // KPI Performance Cards
                        Text(
                          'FLOOR PERFORMANCE & STATS',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.ink,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _buildMetricTile(
                                label: 'ACTIVE LOTS',
                                value: '$activeLotsCount',
                                subtext: 'Floor batches',
                                color: AppTheme.steel,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildMetricTile(
                                label: 'TARGET PCS',
                                value: '$target',
                                subtext: 'Total assigned',
                                color: AppTheme.ink,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildMetricTile(
                                label: 'SEWN PCS',
                                value: '$stitched',
                                subtext: '${efficiency.toStringAsFixed(0)}% output',
                                color: AppTheme.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildMetricTile(
                                label: 'QC PASSED',
                                value: '$passed',
                                subtext: '${passRate.toStringAsFixed(0)}% pass rate',
                                color: AppTheme.green,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildMetricTile(
                                label: 'ALTERATIONS',
                                value: '$mending',
                                subtext: 'In mending/rework',
                                color: mending > 0 ? AppTheme.amber : AppTheme.inkFaint,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Articles / Lots History
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'ASSIGNED ARTICLES & LOTS (${linemanLots.length})',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.ink,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              'Realtime Synced',
                              style: GoogleFonts.publicSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (linemanLots.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppTheme.bg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.border),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'No active lots found for this lineman.',
                              style: GoogleFonts.publicSans(fontSize: 12, color: AppTheme.inkSoft),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: linemanLots.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, idx) {
                              final lot = linemanLots[idx];
                              final article = parseMap(lot['article']);
                              final artNo = article['art_no'] ?? 'N/A';
                              final color = (lot['color']?.toString().trim().isNotEmpty == true)
                                  ? lot['color'].toString().trim()
                                  : (article['description']?.toString() ?? 'All Sizes');
                              final sizeRange = lot['size_range']?.toString().trim() ?? '';
                              final challan = parseMap(lot['challan']);
                              final challanNo = challan['challan_no']?.toString();
                              final lotTarget = parseQty(lot['target_qty']);
                              final lotStitched = parseQty(lot['stitched_qty']);
                              final stage = lot['stage']?.toString() ?? 'SEWING_LINES';

                              Color stageColor = AppTheme.steel;
                              String stageText = 'Sewing';
                              if (stage == 'READY_TO_DISPATCH') {
                                stageColor = AppTheme.green;
                                stageText = 'Ready';
                              } else if (stage == 'QC_INSPECTION') {
                                stageColor = AppTheme.steelDark;
                                stageText = 'QC Floor';
                              } else if (stage == 'MENDING_COUNTING') {
                                stageColor = AppTheme.amber;
                                stageText = 'In Mending';
                              }

                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.bg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppTheme.border),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: AppTheme.steelMist,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'ART $artNo',
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.steel,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  color,
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppTheme.ink,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (sizeRange.isNotEmpty) ...[
                                                const SizedBox(width: 4),
                                                Text(
                                                  '($sizeRange)',
                                                  style: GoogleFonts.jetBrainsMono(fontSize: 10.5, color: AppTheme.inkSoft),
                                                ),
                                              ],
                                              if (challanNo != null) ...[
                                                const SizedBox(width: 4),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.card,
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: AppTheme.border),
                                                  ),
                                                  child: Text(
                                                    'DC #$challanNo',
                                                    style: GoogleFonts.jetBrainsMono(fontSize: 9, color: AppTheme.inkSoft),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            'Stitched: $lotStitched / $lotTarget pcs • Passed: ${lot['passed_qty'] ?? 0} pcs',
                                            style: GoogleFonts.publicSans(fontSize: 10.5, color: AppTheme.inkSoft),
                                          ),
                                          if (lot['handed_to_mending_at'] != null)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 2),
                                              child: Text(
                                                'Handed to Mending by ${lot['handed_to_mending_by'] ?? lmName}',
                                                style: GoogleFonts.publicSans(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppTheme.green,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: stageColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        stageText,
                                        style: GoogleFonts.publicSans(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                          color: stageColor,
                                        ),
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
                  const Divider(height: 1, color: AppTheme.border),
                  // Bottom Filter Action Buttons
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        if (isCurrentlySelected) ...[
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx);
                                setState(() {
                                  _selectedLinemanId = null;
                                  _selectedLinemanName = null;
                                });
                              },
                              icon: const Icon(Icons.close, size: 16),
                              label: const Text('Clear Filter'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                side: const BorderSide(color: AppTheme.border),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ] else ...[
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx);
                                setState(() {
                                  _selectedLinemanId = lmId;
                                  _selectedLinemanName = line['name']?.toString();
                                });
                              },
                              icon: const Icon(Icons.filter_alt_rounded, size: 16, color: Colors.white),
                              label: Text('Filter Floor to $lmName'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.steel,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
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

  Widget _buildMetricTile({
    required String label,
    required String value,
    required String subtext,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.publicSans(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: AppTheme.inkFaint,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtext,
            style: GoogleFonts.publicSans(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}
