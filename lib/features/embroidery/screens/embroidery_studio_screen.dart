import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/zigza_app_bar.dart';
import '../../modules/widgets/workspace_hub_drawer.dart';
import '../../modules/screens/company_profile_screen.dart';
import '../models/embroidery_models.dart';
import '../providers/embroidery_provider.dart';
import '../widgets/add_embroidery_worker_modal.dart';
import '../widgets/embroidery_worker_list_modal.dart';
import '../widgets/add_embroidery_task_modal.dart';
import '../widgets/select_embroidery_route_modal.dart';
import '../widgets/select_embroidery_buyer_modal.dart';
import 'embroidery_zigza_ai_screen.dart';

class BoxKeyValues {
  static final BoxShadow cardShadow = BoxShadow(
    color: Colors.black.withValues(alpha: 0.04),
    blurRadius: 10,
    offset: const Offset(0, 3),
  );
}

class EmbroideryStudioScreen extends ConsumerStatefulWidget {
  const EmbroideryStudioScreen({super.key});

  @override
  ConsumerState<EmbroideryStudioScreen> createState() => _EmbroideryStudioScreenState();
}

class _EmbroideryStudioScreenState extends ConsumerState<EmbroideryStudioScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openAddWorkerModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddEmbroideryWorkerModal(),
    );
  }

  void _openWorkerListModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const EmbroideryWorkerListModal(),
    );
  }

  void _openBuyerModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SelectEmbroideryBuyerModal(),
    );
  }

  void _openAddTaskModal(int maxPieces) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddEmbroideryTaskModal(maxSuggestedPieces: maxPieces),
    );
  }

  void _openRouteModal(String routeKey, String buyerName, String buyerId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SelectEmbroideryRouteModal(
        activeRouteKey: routeKey,
        buyerName: buyerName,
        buyerId: buyerId,
      ),
    );
  }

  void _confirmVerifyTask(EmbroideryTaskAllocation task) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Verify Task Sign-Off',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Text(
          'Confirm that task #${task.taskRef} (${task.piecesToEmbroider.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} embroidered panels) has completed multi-head run and passed stitch inspection?',
          style: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF047857),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(embroideryProvider.notifier).verifyAndDoneTask(task.id, task.piecesToEmbroider);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Task #${task.taskRef} verified & signed off!'),
                    backgroundColor: const Color(0xFF047857),
                  ),
                );
              }
            },
            child: Text('Verify & Done', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteTask(EmbroideryTaskAllocation task) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Remove Task Allocation',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Text(
          'Are you sure you want to delete task #${task.taskRef}? The unembroidered pieces will revert to In Hand.',
          style: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(embroideryProvider.notifier).deleteTaskAllocation(task.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Task #${task.taskRef} removed.')),
                );
              }
            },
            child: Text('Remove', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _formatDueTimeline(String? isoDue, double allotedHours) {
    if (isoDue == null || isoDue.isEmpty) return '${allotedHours.toStringAsFixed(1)} hrs alloted';
    try {
      final dt = DateTime.parse(isoDue).toLocal();
      return DateFormat('hh:mm a, MMM dd').format(dt);
    } catch (_) {
      return '${allotedHours.toStringAsFixed(1)} hrs alloted';
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(embroideryProvider);

    final activeSelectedBuyerId = state.selectedBuyerId == 'ALL'
        ? 'ALL'
        : (state.selectedBuyerId.isNotEmpty && state.buyers.any((b) => b.id == state.selectedBuyerId)
            ? state.selectedBuyerId
            : (state.buyers.isNotEmpty ? state.buyers.first.id : 'ALL'));

    final EmbroideryBuyerContract? selectedBuyer = activeSelectedBuyerId == 'ALL'
        ? null
        : (state.buyers.where((b) => b.id == activeSelectedBuyerId).firstOrNull ??
            (state.buyers.isNotEmpty ? state.buyers.first : null));

    final buyerTitle = selectedBuyer != null ? selectedBuyer.buyerName : 'No Active Buyers';
    final articleCode = selectedBuyer?.linkedArticleNumber;

    // Upstream data
    final upstreamCut = state.upstreamCutPieces;
    final buyerCutPieces = selectedBuyer != null ? selectedBuyer.completedCutPieces : upstreamCut;

    final selectedBuyerDisplayText = selectedBuyer != null
        ? '${selectedBuyer.buyerName} ($buyerCutPieces Cut / ${selectedBuyer.contractedVolume.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} BPO)'
        : (activeSelectedBuyerId == 'ALL'
            ? 'All Buyers (${state.taskAllocations.length} Active Lots)'
            : (state.buyers.isEmpty ? 'All Buyers (${state.taskAllocations.length} Active Lots)' : 'Select Buyer Contract'));

    // Route calculation
    final routeDetails = ref.read(embroideryProvider.notifier).getRouteDetails(selectedBuyer?.id ?? 'byr-hollypop');
    final inHand = routeDetails.inHandPieces;

    // Filter tasks for selected buyer
    final buyerTasks = state.taskAllocations.where((t) {
      if (selectedBuyer == null) return true;
      final bMatch = (t.buyerId != null && t.buyerId == selectedBuyer.id) ||
          t.buyerName.toLowerCase() == selectedBuyer.buyerName.toLowerCase();
      final aMatch = articleCode != null && articleCode.isNotEmpty
          ? t.articleNumber.trim().toUpperCase() == articleCode.trim().toUpperCase()
          : false;
      return bMatch || aMatch;
    }).toList();

    final completedEmbroidery = buyerTasks
        .where((t) => t.status == 'VERIFIED_COMPLETED' || t.status == 'COMPLETED')
        .fold<int>(0, (sum, t) => sum + (t.completedPieces > 0 ? t.completedPieces : t.piecesToEmbroider));

    final pendingEmbroidery = buyerTasks
        .where((t) => t.status != 'VERIFIED_COMPLETED' && t.status != 'COMPLETED')
        .fold<int>(0, (sum, t) => sum + t.piecesToEmbroider);

    // Filter tasks by matrix search and tab filter
    final displayedTasks = buyerTasks.where((task) {
      final q = state.searchQuery.toLowerCase();
      final matchesSearch = q.isEmpty ||
          task.workerName.toLowerCase().contains(q) ||
          task.articleNumber.toLowerCase().contains(q) ||
          task.taskRef.toLowerCase().contains(q) ||
          task.tableNumber.toLowerCase().contains(q);

      bool matchesFilter = true;
      if (state.statusFilter == 'ACTIVE') {
        matchesFilter = task.status != 'VERIFIED_COMPLETED' && task.status != 'COMPLETED';
      } else if (state.statusFilter == 'NEEDS_VERIFY') {
        matchesFilter = task.status == 'WORKER_COMPLETED';
      } else if (state.statusFilter == 'COMPLETED') {
        matchesFilter = task.status == 'VERIFIED_COMPLETED' || task.status == 'COMPLETED';
      }

      return matchesSearch && matchesFilter;
    }).toList();

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFFAF7F0),
      drawer: const WorkspaceHubDrawer(activeRoute: '/embroidery'),
      appBar: ZigzaAppBar(
        onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      body: state.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF3A3564)),
            )
          : RefreshIndicator(
              onRefresh: () => ref.read(embroideryProvider.notifier).loadInitialData(isRefresh: true),
              color: const Color(0xFF3A3564),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ==========================================
                    // HEADER ROW: BREADCRUMB + SYNC STATUS PILL
                    // ==========================================
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.arrow_back, size: 13, color: Color(0xFF3A3564)),
                                const SizedBox(width: 4),
                                Text(
                                  'Workspace hub / Division 05 - Embroidery studio',
                                  style: GoogleFonts.publicSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF3A3564),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAF7F0),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'MULTI-HEAD & PUNCH SYNC ACTIVE',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF3A3564),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // ==========================================
                    // 1. MULTI-HEAD EMBROIDERY STUDIO HEADER CARD
                    // ==========================================
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                        boxShadow: [BoxKeyValues.cardShadow],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFAF7F0),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                                ),
                                child: const Center(
                                  child: Icon(Icons.auto_awesome, color: Color(0xFF3A3564), size: 24),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          'Multi-head embroidery studio',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF0F172A),
                                            letterSpacing: -0.3,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFAF7F0),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                                          ),
                                          child: Text(
                                            '${state.workers.length} WORKERS REGISTERED',
                                            style: GoogleFonts.jetBrainsMono(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFF3A3564),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Multi-head computerized machines, hooping stations, shift matrix tracking, and stitch sign-offs',
                                      style: GoogleFonts.publicSans(
                                        fontSize: 12,
                                        color: const Color(0xFF64748B),
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // 2-BUTTON ROW (Zigza AI & Division Profile)
                          Row(
                            children: [
                              Expanded(
                                child: _buildActionOutlineButton(
                                  icon: Icons.smart_toy_outlined,
                                  label: 'Zigza AI',
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const EmbroideryZigzaAiScreen()),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildActionOutlineButton(
                                  icon: Icons.business_outlined,
                                  label: 'Division profile',
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const CompanyProfileScreen()),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ==========================================
                    // 2. SELECTED BUYER CONTRACT & ROUTE CARD
                    // ==========================================
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                        boxShadow: [BoxKeyValues.cardShadow],
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
                                  color: const Color(0xFFFAF7F0),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                                ),
                                child: const Icon(Icons.business_outlined, color: Color(0xFF3A3564), size: 18),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'SELECTED BUYER CONTRACT & ROUTE',
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF64748B),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          buyerTitle,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF0F172A),
                                          ),
                                        ),
                                        if (articleCode != null && articleCode.isNotEmpty)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFAF7F0),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: const Color(0xFFE2E8F0)),
                                            ),
                                            child: Text(
                                              'Article: $articleCode',
                                              style: GoogleFonts.jetBrainsMono(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: const Color(0xFF3A3564),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Route Info Row (Clickable)
                          InkWell(
                            onTap: () => _openRouteModal(routeDetails.route, buyerTitle, selectedBuyer?.id ?? 'byr-hollypop'),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFAF7F0),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.alt_route_rounded, size: 16, color: Color(0xFF3A3564)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Wrap(
                                      spacing: 6,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          routeDetails.stepText,
                                          style: GoogleFonts.publicSans(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF0F172A),
                                          ),
                                        ),
                                        Text(
                                          '(${routeDetails.badgeLabel})',
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 10,
                                            color: const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.expand_more, size: 16, color: Color(0xFF64748B)),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Buyer Selector Button (Opens Searchable Bottom Sheet matching Web)
                          InkWell(
                            onTap: _openBuyerModal,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFAF7F0),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    activeSelectedBuyerId == 'ALL' ? Icons.people_outline : Icons.business_outlined,
                                    size: 17,
                                    color: const Color(0xFF3A3564),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      selectedBuyerDisplayText,
                                      style: GoogleFonts.publicSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF0F172A),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const Icon(Icons.keyboard_arrow_down, size: 18, color: Color(0xFF64748B)),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // "View worker list (N)" button (Outline)
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF0F172A),
                                side: BorderSide(color: Colors.black.withValues(alpha: 0.12)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              onPressed: _openWorkerListModal,
                              icon: const Icon(Icons.people_outline, size: 16, color: Color(0xFF3A3564)),
                              label: Text(
                                'View worker list (${state.workers.length})',
                                style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Two-button row: "+ Add worker" (Primary #3A3564) + Refresh icon button
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF3A3564),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(vertical: 11),
                                  ),
                                  onPressed: _openAddWorkerModal,
                                  icon: const Icon(Icons.person_add_alt_1, size: 16),
                                  label: Text(
                                    '+ Add worker',
                                    style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.black.withValues(alpha: 0.12)),
                                ),
                                child: IconButton(
                                  icon: state.isSyncing
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF3A3564)),
                                        )
                                      : const Icon(Icons.refresh, color: Color(0xFF3A3564), size: 20),
                                  onPressed: () => ref.read(embroideryProvider.notifier).loadInitialData(isRefresh: true),
                                  tooltip: 'Re-sync embroidery floor data',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ==========================================
                    // 3. THREE STACKED STAT CARDS (NO Strike Off card)
                    // ==========================================
                    _buildStatCard(
                      label: 'In hand',
                      value: inHand.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},'),
                      description: '$inHand pcs received from ${routeDetails.sourceDepartment} (Awaiting sign-off)',
                      icon: Icons.pending_actions_outlined,
                      isNumber: true,
                    ),
                    const SizedBox(height: 10),
                    _buildStatCard(
                      label: 'Pending embroidery',
                      value: pendingEmbroidery.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},'),
                      description: '$pendingEmbroidery pcs assigned to machine',
                      icon: Icons.precision_manufacturing_outlined,
                      isNumber: true,
                    ),
                    const SizedBox(height: 10),
                    _buildStatCard(
                      label: 'Completed embroidery',
                      value: completedEmbroidery.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},'),
                      description: '$completedEmbroidery embroidered panels verified',
                      icon: Icons.auto_awesome,
                      isNumber: true,
                    ),

                    const SizedBox(height: 14),

                    // ==========================================
                    // 4. EMBROIDERY FLOOR TASK ALLOCATION MATRIX CARD
                    // ==========================================
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                        boxShadow: [BoxKeyValues.cardShadow],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Card Top Title & Desc
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFAF7F0),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                                      ),
                                      child: const Icon(Icons.table_chart_outlined, color: Color(0xFF3A3564), size: 18),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Embroidery floor task allocation matrix',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF0F172A),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Distribute article embroidery quotas, assign multi-head machines, and set shift deadline targets',
                                  style: GoogleFonts.publicSans(
                                    fontSize: 12,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Search Field
                                Container(
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFAF7F0),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                                  ),
                                  child: TextField(
                                    controller: _searchCtrl,
                                    onChanged: (val) => ref.read(embroideryProvider.notifier).setSearchQuery(val),
                                    style: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF0F172A)),
                                    decoration: InputDecoration(
                                      hintText: 'Search worker, article, machine...',
                                      hintStyle: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF94A3B8)),
                                      prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                                      suffixIcon: _searchCtrl.text.isNotEmpty
                                          ? IconButton(
                                              icon: const Icon(Icons.clear, size: 16, color: Color(0xFF94A3B8)),
                                              onPressed: () {
                                                _searchCtrl.clear();
                                                ref.read(embroideryProvider.notifier).setSearchQuery('');
                                              },
                                            )
                                          : null,
                                      border: InputBorder.none,
                                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 10),

                                // Horizontal Filter Tabs
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      _buildFilterTab('All', 'ALL', state.statusFilter),
                                      const SizedBox(width: 6),
                                      _buildFilterTab('Active queue', 'ACTIVE', state.statusFilter),
                                      const SizedBox(width: 6),
                                      _buildFilterTab('Needs verification', 'NEEDS_VERIFY', state.statusFilter),
                                      const SizedBox(width: 6),
                                      _buildFilterTab('Verified & done', 'COMPLETED', state.statusFilter),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 12),

                                // Full-width "+ Add task row" button
                                SizedBox(
                                  width: double.infinity,
                                  height: 44,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF3A3564),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    onPressed: () => _openAddTaskModal(inHand),
                                    icon: const Icon(Icons.add, size: 18),
                                    label: Text(
                                      '+ Add task row',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const Divider(height: 1, color: Color(0x14000000)),

                          // Task Items List or Empty State
                          if (displayedTasks.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFAF7F0),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                                      ),
                                      child: const Icon(Icons.table_chart_outlined, color: Color(0xFF3A3564), size: 24),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No matching embroidery tasks',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Allocate article embroidery piece quotas to registered workers. When assigned, pieces move from In Hand to Pending Embroidery.',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.publicSans(
                                        fontSize: 12,
                                        color: const Color(0xFF64748B),
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF3A3564),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      ),
                                      onPressed: () => _openAddTaskModal(inHand),
                                      icon: const Icon(Icons.add, size: 16),
                                      label: Text(
                                        '+ Assign task row',
                                        style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(14),
                              itemCount: displayedTasks.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (ctx, idx) {
                                final task = displayedTasks[idx];
                                return _buildTaskRow(task);
                              },
                            ),

                          // Footer Summary Band (Cream-Tinted)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFAF7F0),
                              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                            ),
                            child: Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Text(
                                  'Showing ${displayedTasks.length} task allocations across ${state.workers.length} registered workers',
                                  style: GoogleFonts.publicSans(
                                    fontSize: 11,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                                Text(
                                  'In hand: $inHand • Pending: $pendingEmbroidery • Completed: $completedEmbroidery',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF3A3564),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildActionOutlineButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFAF7F0),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: const Color(0xFF3A3564)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF3A3564),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required String description,
    required IconData icon,
    bool isNumber = true,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
        boxShadow: [BoxKeyValues.cardShadow],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: isNumber
                      ? GoogleFonts.jetBrainsMono(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                          letterSpacing: -0.5,
                        )
                      : GoogleFonts.plusJakartaSans(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.publicSans(
                    fontSize: 11.5,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF7F0),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
            ),
            child: Icon(icon, color: const Color(0xFF3A3564), size: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String label, String value, String activeValue) {
    final isActive = value == activeValue;
    return InkWell(
      onTap: () => ref.read(embroideryProvider.notifier).setStatusFilter(value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF3A3564) : const Color(0xFFFAF7F0),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? const Color(0xFF3A3564) : Colors.black.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
            color: isActive ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildTaskRow(EmbroideryTaskAllocation task) {
    final isDone = task.status == 'VERIFIED_COMPLETED' || task.status == 'COMPLETED';
    final isWorkerDone = task.status == 'WORKER_COMPLETED';
    final dueTimeline = _formatDueTimeline(task.dueTime, task.allotedHours);

    Color statusBg = const Color(0xFFFAF7F0);
    Color statusText = const Color(0xFF3A3564);
    Color statusBorder = Colors.black.withValues(alpha: 0.1);
    String statusLabel = 'IN PROGRESS';

    if (isDone) {
      statusBg = const Color(0xFFECFDF5);
      statusText = const Color(0xFF047857);
      statusBorder = const Color(0xFFA7F3D0);
      statusLabel = 'VERIFIED';
    } else if (isWorkerDone) {
      statusBg = const Color(0xFFFFFBEB);
      statusText = const Color(0xFFD97706);
      statusBorder = const Color(0xFFFDE68A);
      statusLabel = 'NEEDS VERIFY';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDone ? const Color(0xFFF8FAFC) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDone ? const Color(0xFFE2E8F0) : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. TOP ROW: Task Ref + Worker Name & Phone on Left, Status Pill on Right
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF7F0),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                ),
                child: Text(
                  '#${task.taskRef}',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF3A3564),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.workerName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (task.workerPhone != null && task.workerPhone!.isNotEmpty)
                      Text(
                        '+91 ${task.workerPhone}',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isDone) ...[
                      const Icon(Icons.check_circle, size: 10, color: Color(0xFF047857)),
                      const SizedBox(width: 3),
                    ] else if (isWorkerDone) ...[
                      const Icon(Icons.access_time, size: 10, color: Color(0xFFD97706)),
                      const SizedBox(width: 3),
                    ],
                    Text(
                      statusLabel,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: statusText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // 2. MIDDLE DETAILS: Article Style, Machine Station, Target Due, and Pieces Quota
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.style_outlined, size: 12, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Text(
                        '${task.buyerName} • ${task.articleNumber}',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF3A3564),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.precision_manufacturing_outlined, size: 12, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Text(
                        task.tableNumber,
                        style: GoogleFonts.publicSans(
                          fontSize: 11,
                          color: const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.schedule_outlined, size: 12, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Text(
                        dueTimeline,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10.5,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Text(
                '${task.piecesToEmbroider.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} pcs',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),

          if (task.notes != null && task.notes!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              task.notes!,
              style: GoogleFonts.publicSans(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: const Color(0xFF64748B),
              ),
            ),
          ],

          const SizedBox(height: 8),

          // 3. BOTTOM ACTION ROW: Verify & Done Button (if not completed) + Delete Icon Button
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!isDone) ...[
                InkWell(
                  onTap: () => _confirmVerifyTask(task),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check, size: 13, color: Color(0xFF047857)),
                        const SizedBox(width: 4),
                        Text(
                          'Verify & Done',
                          style: GoogleFonts.publicSans(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF047857),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              IconButton(
                onPressed: () => _confirmDeleteTask(task),
                icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFF94A3B8)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                tooltip: 'Remove task allocation',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
