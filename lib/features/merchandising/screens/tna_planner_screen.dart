import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/widgets/zigza_app_bar.dart';
import '../../modules/widgets/workspace_hub_drawer.dart';
import '../models/merchandising_models.dart';
import '../providers/merchandising_provider.dart';
import '../widgets/update_tna_milestone_modal.dart';
import 'buyer_purchase_orders_screen.dart';

class TnaPlannerScreen extends ConsumerStatefulWidget {
  final String? initialPoNumber;

  const TnaPlannerScreen({
    super.key,
    this.initialPoNumber,
  });

  @override
  ConsumerState<TnaPlannerScreen> createState() => _TnaPlannerScreenState();
}

class _TnaPlannerScreenState extends ConsumerState<TnaPlannerScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String? _selectedPo;

  @override
  void initState() {
    super.initState();
    _selectedPo = widget.initialPoNumber;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(merchandisingProvider.notifier).fetchMerchandisingData();
    });
  }

  void _openUpdateMilestoneModal(TnaMilestone milestone) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UpdateTnaMilestoneModal(milestone: milestone),
    );
  }

  Future<void> _quickMarkCleared(TnaMilestone milestone) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Mark Gate Cleared',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
        content: Text(
          'Are you sure you want to sign off and mark "${milestone.milestoneName}" as COMPLETED for ${milestone.poNumber}?',
          style: GoogleFonts.publicSans(
            fontSize: 13,
            color: const Color(0xFF475569),
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.publicSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3A3564),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Confirm Sign-Off',
              style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(merchandisingProvider.notifier).updateTnaMilestone(
            id: milestone.id,
            status: 'COMPLETED',
            actualDate: DateTime.now().toIso8601String().split('T')[0],
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gate "${milestone.milestoneName}" marked as Cleared.'),
            backgroundColor: const Color(0xFF15803D),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(merchandisingProvider);
    final allMilestones = state.milestones;
    // Available PO list from milestones (matching web exactly)
    final availablePos = allMilestones
        .map((m) => m.poNumber)
        .where((po) => po.isNotEmpty && po != 'N/A')
        .toSet()
        .toList()
      ..sort();

    // Default to first PO if not selected, or null if no milestones exist
    if (_selectedPo != null && !availablePos.contains(_selectedPo)) {
      _selectedPo = null;
    }
    if (_selectedPo == null && availablePos.isNotEmpty) {
      _selectedPo = availablePos.first;
    }

    final activeMilestones = _selectedPo != null
        ? allMilestones.where((m) => m.poNumber == _selectedPo).toList()
        : <TnaMilestone>[];

    activeMilestones.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final totalGates = activeMilestones.length;
    final completedCount = activeMilestones.where((m) => m.isCompleted).length;
    final delayedCount = activeMilestones.where((m) => m.isDelayed || m.isEscalated).length;
    final inProgressCount = totalGates - completedCount - delayedCount > 0
        ? totalGates - completedCount - delayedCount
        : 0;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFFAF7F0), // Canvas
      drawer: const WorkspaceHubDrawer(activeRoute: '/merchandising/tna-calendar'),
      appBar: ZigzaAppBar(
        onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
        trailing: IconButton(
          icon: state.isSyncing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF3A3564)),
                )
              : const Icon(Icons.refresh_rounded, color: Color(0xFF3A3564)),
          tooltip: 'Sync T&A Data',
          onPressed: () => ref.read(merchandisingProvider.notifier).syncData(),
        ),
      ),
      body: RefreshIndicator(
        color: const Color(0xFF3A3564),
        onRefresh: () => ref.read(merchandisingProvider.notifier).fetchMerchandisingData(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Breadcrumb Hierarchy
              _buildBreadcrumb(context),
              const SizedBox(height: 12),

              // 2. Encapsulated Top Header Card
              _buildHeaderCard(totalGates, completedCount, delayedCount),
              const SizedBox(height: 14),

              // 3. 2x2 Executive KPI Grid
              _buildKpiGrid(
                trackedPosCount: availablePos.length,
                completedGates: completedCount,
                pendingGates: inProgressCount,
                delayedGates: delayedCount,
              ),
              const SizedBox(height: 14),

              // 4. Select Order PO Selector Bar
              _buildPoSelector(availablePos),
              const SizedBox(height: 14),

              // 5. Critical Path Timeline & Milestone Stages Card
              _buildTimelineCard(context, activeMilestones, availablePos),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBreadcrumb(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: () => Navigator.pop(context),
          child: Text(
            'Merchandising & sourcing',
            style: GoogleFonts.publicSans(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
            ),
          ),
        ),
        const SizedBox(width: 4),
        const Text('/', style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8))),
        const SizedBox(width: 4),
        Text(
          'Commercial ops',
          style: GoogleFonts.publicSans(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(width: 4),
        const Text('/', style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8))),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            'Time & action (T&A) planner',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.publicSans(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderCard(int totalGates, int completedGates, int delayedGates) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1A000000)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon Badge Tile
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF7F0),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x1A000000)),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: Color(0xFF3A3564),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Time & Action (T&A) Planner',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF7F0),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0x26000000)),
                      ),
                      child: Text(
                        '8 MILESTONE GATES',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF3A3564),
                          letterSpacing: 0.5,
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
            'Critical path schedule, lead-time control, PPM meeting milestones, and AQL inspection cut-offs',
            style: GoogleFonts.publicSans(
              fontSize: 12,
              color: const Color(0xFF475569),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              // Summary Pill: N of N gates cleared
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF7F0),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0x1A000000)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF3A3564)),
                    const SizedBox(width: 6),
                    Text(
                      '$completedGates of $totalGates Gates Cleared',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF3A3564),
                      ),
                    ),
                  ],
                ),
              ),
              if (delayedGates > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFECDD3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFE11D48)),
                      const SizedBox(width: 6),
                      Text(
                        '$delayedGates Delayed',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF9F1239),
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

  Widget _buildKpiGrid({
    required int trackedPosCount,
    required int completedGates,
    required int pendingGates,
    required int delayedGates,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                icon: Icons.layers_outlined,
                title: 'Tracked POs',
                subtitle: 'Orders under T&A SLA',
                value: '$trackedPosCount',
                tag: 'Contracts',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildKpiCard(
                icon: Icons.check_circle_outline_rounded,
                title: 'Completed gates',
                subtitle: 'Successfully signed-off',
                value: '$completedGates',
                tag: 'Cleared',
                isSuccess: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                icon: Icons.schedule_rounded,
                title: 'Pending gates',
                subtitle: 'On-schedule in progress',
                value: '$pendingGates',
                tag: 'In flow',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildKpiCard(
                icon: Icons.error_outline_rounded,
                title: 'Critical alerts',
                subtitle: 'Delayed & escalated steps',
                value: '$delayedGates',
                tag: delayedGates > 0 ? 'Action Required' : 'Zero delay',
                isAlert: delayedGates > 0,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    required String tag,
    bool isSuccess = false,
    bool isAlert = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1A000000)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isAlert
                      ? const Color(0xFFFFF1F2)
                      : (isSuccess ? const Color(0xFFDCFCE7) : const Color(0xFFFAF7F0)),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isAlert
                        ? const Color(0xFFFECDD3)
                        : (isSuccess ? const Color(0xFFBBF7D0) : const Color(0x1A000000)),
                  ),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: isAlert
                      ? const Color(0xFFE11D48)
                      : (isSuccess ? const Color(0xFF15803D) : const Color(0xFF3A3564)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isAlert
                      ? const Color(0xFFFFF1F2)
                      : const Color(0xFFFAF7F0),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isAlert ? const Color(0xFFFECDD3) : const Color(0x1A000000),
                  ),
                ),
                child: Text(
                  tag,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: isAlert ? const Color(0xFFE11D48) : const Color(0xFF3A3564),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.publicSans(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
            ),
          ),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.publicSans(
              fontSize: 10,
              color: const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPoSelector(List<String> availablePos) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1A000000)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Text(
              'SELECT ORDER PO:',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF94A3B8),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 12),
            ...availablePos.map((po) {
              final isSelected = _selectedPo == po;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedPo = po;
                    });
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF3A3564) : const Color(0xFFFAF7F0),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF3A3564) : const Color(0x1A000000),
                      ),
                    ),
                    child: Text(
                      po,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : const Color(0xFF334155),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineCard(
    BuildContext context,
    List<TnaMilestone> activeMilestones,
    List<String> availablePos,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1A000000)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF7F0),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0x1A000000)),
                ),
                child: const Icon(Icons.schedule_rounded, color: Color(0xFF3A3564), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Critical Path Timeline & Milestone Stages (${_selectedPo ?? ''})',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'ISO 9001 Standard Lead-Time Schedule',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10.5,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF7F0),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0x1A000000)),
                ),
                child: Text(
                  '${activeMilestones.length} Serial Gates',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 16),

          // Content: Empty State vs Milestone Timeline
          if (activeMilestones.isEmpty)
            _buildEmptyState(context, availablePos)
          else
            _buildMilestonesList(activeMilestones),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, List<String> availablePos) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFFAF7F0),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x1A000000)),
            ),
            child: const Icon(Icons.calendar_month_outlined, size: 28, color: Color(0xFF3A3564)),
          ),
          const SizedBox(height: 12),
          Text(
            availablePos.isEmpty ? 'No T&A schedules' : 'No milestones for selected PO',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            availablePos.isEmpty
                ? 'Book a buyer PO to generate T&A milestone gates.'
                : 'Select another purchase order from the selector above.',
            textAlign: TextAlign.center,
            style: GoogleFonts.publicSans(
              fontSize: 12.5,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BuyerPurchaseOrdersScreen()),
              );
            },
            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
            label: Text(
              'Go to buyer POs',
              style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3A3564),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMilestonesList(List<TnaMilestone> activeMilestones) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: activeMilestones.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, idx) {
        final m = activeMilestones[idx];
        final isCompleted = m.isCompleted;
        final isDelayed = m.isDelayed || m.isEscalated;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDelayed ? const Color(0xFFFECDD3) : const Color(0x1A000000),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x04000000),
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Gate Number, Title & Status Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'GATE ${(idx + 1).toString().padLeft(2, '0')}',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      m.milestoneName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  _buildStatusBadge(m.status),
                ],
              ),
              const SizedBox(height: 8),

              // Planned Target & Actual Dates
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 12, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 4),
                  Text(
                    'Planned: ',
                    style: GoogleFonts.publicSans(fontSize: 11, color: const Color(0xFF64748B)),
                  ),
                  Text(
                    m.targetDate.isNotEmpty ? m.targetDate : 'N/A',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  if (m.actualDate != null && m.actualDate!.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    const Icon(Icons.check_circle_outline_rounded, size: 12, color: Color(0xFF15803D)),
                    const SizedBox(width: 4),
                    Text(
                      'Actual: ',
                      style: GoogleFonts.publicSans(fontSize: 11, color: const Color(0xFF15803D)),
                    ),
                    Text(
                      m.actualDate!,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF15803D),
                      ),
                    ),
                  ],
                ],
              ),

              // Delay Reason if any
              if (m.delayReason != null && m.delayReason!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFECDD3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 12, color: Color(0xFFE11D48)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Delay: ${m.delayReason}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.publicSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF9F1239),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Mitigation Plan if any
              if (m.mitigationNotes != null && m.mitigationNotes!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Mitigation: "${m.mitigationNotes}"',
                  style: GoogleFonts.publicSans(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
              const SizedBox(height: 10),

              // Action Buttons Row
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!isCompleted) ...[
                    OutlinedButton.icon(
                      onPressed: () => _quickMarkCleared(m),
                      icon: const Icon(Icons.check_rounded, size: 14),
                      label: Text(
                        'Mark gate cleared',
                        style: GoogleFonts.publicSans(fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF15803D),
                        side: const BorderSide(color: Color(0xFFBBF7D0)),
                        backgroundColor: const Color(0xFFDCFCE7),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  ElevatedButton.icon(
                    onPressed: () => _openUpdateMilestoneModal(m),
                    icon: const Icon(Icons.edit_outlined, size: 14),
                    label: Text(
                      'Update gate',
                      style: GoogleFonts.publicSans(fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFAF7F0),
                      foregroundColor: const Color(0xFF3A3564),
                      elevation: 0,
                      side: const BorderSide(color: Color(0x1A000000)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String rawStatus) {
    final status = rawStatus.toUpperCase().trim();
    Color bg;
    Color border;
    Color text;
    String label;

    switch (status) {
      case 'COMPLETED':
      case 'CLEARED':
        bg = const Color(0xFFDCFCE7);
        border = const Color(0xFFBBF7D0);
        text = const Color(0xFF15803D);
        label = 'COMPLETED';
        break;
      case 'DELAYED':
        bg = const Color(0xFFFFF1F2);
        border = const Color(0xFFFECDD3);
        text = const Color(0xFFE11D48);
        label = 'DELAYED';
        break;
      case 'ESCALATED':
        bg = const Color(0xFFFFF1F2);
        border = const Color(0xFFFECDD3);
        text = const Color(0xFFE11D48);
        label = 'ESCALATED';
        break;
      default:
        bg = const Color(0xFFFAF7F0);
        border = const Color(0x1A000000);
        text = const Color(0xFF3A3564);
        label = 'ON SCHEDULE';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
          color: text,
        ),
      ),
    );
  }
}
