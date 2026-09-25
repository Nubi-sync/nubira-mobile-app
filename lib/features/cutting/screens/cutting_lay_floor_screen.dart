import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/widgets/zigza_app_bar.dart';
import '../../modules/screens/enterprise_workspace_hub_screen.dart';
import '../../modules/widgets/workspace_hub_drawer.dart';
import '../models/cutting_models.dart';
import '../providers/cutting_provider.dart';
import '../widgets/add_cutting_task_modal.dart';
import '../widgets/add_cutting_worker_modal.dart';
import '../widgets/cutting_worker_list_modal.dart';
import '../widgets/select_route_modal.dart';
import 'cutting_lay_sheets_screen.dart';
import 'cutting_cad_markers_screen.dart';
import 'cutting_bundle_tickets_screen.dart';
import 'cutting_zigza_ai_screen.dart';

class CuttingLayFloorScreen extends ConsumerStatefulWidget {
  const CuttingLayFloorScreen({super.key});

  @override
  ConsumerState<CuttingLayFloorScreen> createState() => _CuttingLayFloorScreenState();
}

class _CuttingLayFloorScreenState extends ConsumerState<CuttingLayFloorScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(cuttingProvider.notifier).fetchCuttingData();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openAddWorkerModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddCuttingWorkerModal(),
    );
  }

  void _openWorkerListModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CuttingWorkerListModal(),
    );
  }

  void _openAddTaskModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddCuttingTaskModal(),
    );
  }

  void _openRouteModal(String currentRoute, String buyerName, String buyerId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SelectRouteModal(
        currentRoute: currentRoute,
        buyerName: buyerName,
        onRouteSelected: (newRoute) {
          ref.read(cuttingProvider.notifier).setArticleRoute(buyerId, newRoute);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Manufacturing route updated to: ${allManufacturingRoutes.firstWhere((r) => r.value == newRoute, orElse: () => allManufacturingRoutes.first).shortLabel}',
                style: GoogleFonts.publicSans(fontSize: 13, color: Colors.white),
              ),
              backgroundColor: const Color(0xFF0F172A),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmVerifyTask(CuttingTaskAllocation task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Verify & Complete Cut Panels',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
        content: Text(
          'Verify ${task.piecesToCut} cut pieces for ${task.workerName} (${task.articleNumber}) on ${task.tableNumber}? This will mark panels bundled and move quota to Completed Cutting.',
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
              backgroundColor: const Color(0xFF047857),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Confirm Verified',
              style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await ref.read(cuttingProvider.notifier).verifyAndDoneTask(task.id, task.piecesToCut);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? 'Task ${task.taskRef} verified & marked completed' : 'Failed to update task',
              style: GoogleFonts.publicSans(fontSize: 13, color: Colors.white),
            ),
            backgroundColor: success ? const Color(0xFF0F172A) : const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteTask(CuttingTaskAllocation task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Task Allocation',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
        content: Text(
          'Are you sure you want to remove task allocation ${task.taskRef} (${task.piecesToCut} pcs)? Pieces will return to In Hand queue.',
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
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete',
              style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(cuttingProvider.notifier).deleteTaskAllocation(task.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cuttingProvider);
    final buyer = state.selectedBuyer;
    final buyerName = buyer?.buyerName ?? (state.buyers.isNotEmpty ? state.buyers.first.buyerName : 'Direct Buyer Contract');
    final articleCode = buyer?.linkedArticleNumber ?? (state.orders.isNotEmpty ? state.orders.first.styleRef : 'ART-01');
    final activeRoute = state.activeRoute;
    final routeObj = allManufacturingRoutes.firstWhere(
      (r) => r.value == activeRoute,
      orElse: () => allManufacturingRoutes.first,
    );

    final filteredTasks = state.filteredTasks;
    final inHand = state.inHandPieces;
    final pendingCutting = state.pendingCuttingPieces;
    final completedCutting = state.completedCuttingPieces;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFFAF7F0),
      drawer: const WorkspaceHubDrawer(activeRoute: '/cutting'),
      appBar: ZigzaAppBar(
        onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      body: RefreshIndicator(
        color: const Color(0xFF3A3564),
        backgroundColor: Colors.white,
        onRefresh: () => ref.read(cuttingProvider.notifier).fetchCuttingData(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ==========================================
              // BREADCRUMB & SYNC STATUS ROW
              // ==========================================
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  InkWell(
                    onTap: () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      } else {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const EnterpriseWorkspaceHubScreen()),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.arrow_back, size: 14, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Text(
                            'Workspace hub / Division 03 • Cutting floor',
                            style: GoogleFonts.publicSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Soft-success sync pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF047857),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'VACUUM & WORKER PORTAL SYNC ACTIVE',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF047857),
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ==========================================
              // 1. HEADER CARD (White, bordered)
              // ==========================================
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                  boxShadow: [
                    BoxKeyValues.cardShadow,
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Icon Tile
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAF7F0),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                          ),
                          child: const Icon(Icons.content_cut, color: Color(0xFF3A3564), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  Text(
                                    'Cutting & lay floor',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFAF7F0),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Text(
                                      '${state.workers.length} workers registered',
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF3A3564),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Automated spreading plies, worker task matrix, pieces per shift tracking, and vacuum knife execution',
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

                    // 2x2 Action Button Grid
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionOutlineButton(
                            icon: Icons.layers_outlined,
                            label: 'Lay sheets',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const CuttingLaySheetsScreen()),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildActionOutlineButton(
                            icon: Icons.open_in_full_rounded,
                            label: 'CAD markers',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const CuttingCadMarkersScreen()),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionOutlineButton(
                            icon: Icons.qr_code_2_rounded,
                            label: 'Bundle QR',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const CuttingBundleTicketsScreen()),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildActionOutlineButton(
                            icon: Icons.smart_toy_outlined,
                            label: 'Zigza AI',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const CuttingZigzaAiScreen()),
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
              // 2. SELECTED BUYER CONTRACT CARD
              // ==========================================
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                  boxShadow: [
                    BoxKeyValues.cardShadow,
                  ],
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
                                'SELECTED BUYER CONTRACT',
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
                                    buyerName,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
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
                      onTap: () => _openRouteModal(activeRoute, buyerName, buyer?.id ?? ''),
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
                              child: Text(
                                'Route: ${routeObj.shortLabel}',
                                style: GoogleFonts.publicSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            const Icon(Icons.expand_more, size: 16, color: Color(0xFF64748B)),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Buyer Dropdown Switcher
                    if (state.buyers.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: state.selectedBuyerId.isNotEmpty && state.buyers.any((b) => b.id == state.selectedBuyerId)
                                ? state.selectedBuyerId
                                : (state.buyers.isNotEmpty ? state.buyers.first.id : null),
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B)),
                            items: state.buyers.map((b) {
                              return DropdownMenuItem<String>(
                                value: b.id,
                                child: Text(
                                  '${b.buyerName} (${b.contractedVolume} pcs total)',
                                  style: GoogleFonts.publicSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                ref.read(cuttingProvider.notifier).setSelectedBuyerId(val);
                              }
                            },
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
                            onPressed: () => ref.read(cuttingProvider.notifier).syncData(),
                            tooltip: 'Re-sync contract data',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ==========================================
              // 3. THREE STACKED STAT CARDS
              // ==========================================
              _buildStatCard(
                label: 'In hand',
                value: '$inHand',
                description: '$inHand unassigned pcs in queue',
                icon: Icons.pending_actions_outlined,
              ),
              const SizedBox(height: 10),
              _buildStatCard(
                label: 'Pending cutting',
                value: '$pendingCutting',
                description: '$pendingCutting pcs assigned to table',
                icon: Icons.table_restaurant_outlined,
              ),
              const SizedBox(height: 10),
              _buildStatCard(
                label: 'Completed cutting',
                value: '$completedCutting',
                description: '$completedCutting cut panels bundled',
                icon: Icons.inventory_2_outlined,
              ),

              const SizedBox(height: 14),

              // ==========================================
              // 4. TASK ALLOCATION MATRIX CARD
              // ==========================================
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                  boxShadow: [
                    BoxKeyValues.cardShadow,
                  ],
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
                                  'Cutting floor task allocation matrix',
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
                            'Distribute article piece quotas, assign tables, and set shift deadline targets',
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
                              onChanged: (val) => ref.read(cuttingProvider.notifier).setSearchQuery(val),
                              style: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF0F172A)),
                              decoration: InputDecoration(
                                hintText: 'Search worker, article, task...',
                                hintStyle: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF94A3B8)),
                                prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                                suffixIcon: _searchCtrl.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 16, color: Color(0xFF94A3B8)),
                                        onPressed: () {
                                          _searchCtrl.clear();
                                          ref.read(cuttingProvider.notifier).setSearchQuery('');
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
                                _buildFilterTab('Verified', 'COMPLETED', state.statusFilter),
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
                              onPressed: _openAddTaskModal,
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

                    const Divider(height: 1, color: Color(0xFFF1F5F9)),

                    // Task List or Empty State
                    if (filteredTasks.isEmpty)
                      _buildEmptyState()
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredTasks.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final task = filteredTasks[index];
                          return _buildTaskRow(task);
                        },
                      ),

                    // Cream-tinted Footer Summary Band
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFAF7F0),
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Showing ${filteredTasks.length} task allocations across ${state.workers.length} registered workers',
                            style: GoogleFonts.publicSans(
                              fontSize: 11,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                'In hand: ',
                                style: GoogleFonts.publicSans(fontSize: 11, color: const Color(0xFF64748B)),
                              ),
                              Text(
                                '$inHand',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                ' • Pending: ',
                                style: GoogleFonts.publicSans(fontSize: 11, color: const Color(0xFF64748B)),
                              ),
                              Text(
                                '$pendingCutting',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                ' • Completed: ',
                                style: GoogleFonts.publicSans(fontSize: 11, color: const Color(0xFF64748B)),
                              ),
                              Text(
                                '$completedCutting',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF047857),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // HELPER WIDGETS
  // ==========================================

  Widget _buildActionOutlineButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: const Color(0xFF3A3564)),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0F172A),
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
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
        boxShadow: [
          BoxKeyValues.cardShadow,
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: GoogleFonts.publicSans(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFFAF7F0),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
            ),
            child: Icon(icon, color: const Color(0xFF3A3564), size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String label, String value, String current) {
    final isSelected = current == value;
    return InkWell(
      onTap: () => ref.read(cuttingProvider.notifier).setStatusFilter(value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3A3564) : const Color(0xFFFAF7F0),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF3A3564) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.publicSans(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFFAF7F0),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
              ),
              child: const Icon(Icons.table_restaurant_outlined, size: 28, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 12),
            Text(
              'No matching cutting tasks',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Allocate article piece quotas to registered workers. When assigned, pieces move from In Hand to Pending Cutting.',
              textAlign: TextAlign.center,
              style: GoogleFonts.publicSans(
                fontSize: 12,
                color: const Color(0xFF64748B),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskRow(CuttingTaskAllocation task) {
    Color statusBg = const Color(0xFFF1F5F9);
    Color statusBorder = const Color(0xFFCBD5E1);
    Color statusText = const Color(0xFF475569);
    String statusLabel = task.status;

    if (task.isCompleted) {
      statusBg = const Color(0xFFECFDF5);
      statusBorder = const Color(0xFFA7F3D0);
      statusText = const Color(0xFF047857);
      statusLabel = 'VERIFIED';
    } else if (task.isWorkerCompleted) {
      statusBg = const Color(0xFFFEF3C7);
      statusBorder = const Color(0xFFFDE68A);
      statusText = const Color(0xFFD97706);
      statusLabel = 'NEEDS VERIFICATION';
    } else if (task.isInProgress) {
      statusBg = const Color(0xFFEFF6FF);
      statusBorder = const Color(0xFFBFDBFE);
      statusText = const Color(0xFF2563EB);
      statusLabel = 'IN PROGRESS';
    } else {
      statusBg = const Color(0xFFFAF7F0);
      statusBorder = const Color(0xFFE2E8F0);
      statusText = const Color(0xFF3A3564);
      statusLabel = 'ASSIGNED';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Worker Name, Task Ref & Status
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    Text(
                      task.workerName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      task.taskRef,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
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
                child: Text(
                  statusLabel,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: statusText,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Article, Table, Quota Details
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.checkroom_outlined, size: 12, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Text(
                        task.articleNumber,
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
                      const Icon(Icons.table_restaurant_outlined, size: 12, color: Color(0xFF64748B)),
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
                        '${task.allotedHours.toInt()}h shift',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Text(
                '${task.piecesToCut} pcs',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 14,
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

          // Action row: Verify & Done button (if not verified) + Delete icon
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!task.isCompleted) ...[
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
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class BoxKeyValues {
  static final BoxShadow cardShadow = BoxShadow(
    color: Colors.black.withValues(alpha: 0.03),
    blurRadius: 2,
    offset: const Offset(0, 1),
  );
}
