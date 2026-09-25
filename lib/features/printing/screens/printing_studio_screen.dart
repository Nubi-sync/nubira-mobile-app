import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/widgets/zigza_app_bar.dart';
import '../../modules/widgets/workspace_hub_drawer.dart';
import '../../modules/screens/company_profile_screen.dart';
import '../models/printing_models.dart';
import '../providers/printing_provider.dart';
import '../widgets/add_printing_worker_modal.dart';
import '../widgets/printing_worker_list_modal.dart';
import '../widgets/add_printing_task_modal.dart';
import '../widgets/select_printing_route_modal.dart';
import 'printing_zigza_ai_screen.dart';

class PrintingStudioScreen extends ConsumerStatefulWidget {
  const PrintingStudioScreen({super.key});

  @override
  ConsumerState<PrintingStudioScreen> createState() => _PrintingStudioScreenState();
}

class _PrintingStudioScreenState extends ConsumerState<PrintingStudioScreen> {
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
      backgroundColor: Colors.transparent,
      builder: (_) => const AddPrintingWorkerModal(),
    );
  }

  void _openWorkerListModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PrintingWorkerListModal(),
    );
  }

  void _openAddTaskModal(int maxPieces) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddPrintingTaskModal(maxSuggestedPieces: maxPieces),
    );
  }

  void _openRouteModal(String routeKey, String buyerName, String buyerId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SelectPrintingRouteModal(
        activeRouteKey: routeKey,
        buyerName: buyerName,
        buyerId: buyerId,
      ),
    );
  }

  void _confirmVerifyTask(PrintingTaskAllocation task) {
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
          'Confirm that task #${task.taskRef} (${task.piecesToPrint} printed panels) has passed curing inspection and is ready for downstream transfer?',
          style: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.publicSans(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF047857),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(printingProvider.notifier).verifyAndDoneTask(task);
            },
            child: Text('Verify & Done', style: GoogleFonts.publicSans(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteTask(PrintingTaskAllocation task) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Task Allocation',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Text(
          'Are you sure you want to remove Task #${task.taskRef} (${task.piecesToPrint} pcs) from the printing floor schedule?',
          style: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.publicSans(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(printingProvider.notifier).deleteTaskAllocation(task.id, task.taskRef);
            },
            child: Text('Delete', style: GoogleFonts.publicSans(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _toggleStrikeOffDialog(StrikeOffApproval strikeOff) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.verified_outlined, color: Color(0xFF047857), size: 20),
            const SizedBox(width: 8),
            Text(
              'Strike-Off Lab Approval',
              style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Status: ${strikeOff.status}',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: strikeOff.isApproved ? const Color(0xFF047857) : const Color(0xFFD97706),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Remarks: ${strikeOff.labRemarks}',
              style: GoogleFonts.publicSans(fontSize: 12.5, color: const Color(0xFF475569)),
            ),
            const SizedBox(height: 4),
            Text(
              'Spectro Delta E: ${strikeOff.deltaE} • Fastness: ${strikeOff.washFastnessRating} / 5.0',
              style: GoogleFonts.jetBrainsMono(fontSize: 11, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 4),
            Text(
              'Auditor: ${strikeOff.auditorName}',
              style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close', style: GoogleFonts.publicSans(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: strikeOff.isApproved ? const Color(0xFFD97706) : const Color(0xFF047857),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              final newStatus = strikeOff.isApproved ? 'IN_LAB_TESTING' : 'APPROVED';
              ref.read(printingProvider.notifier).updateStrikeOffStatus(newStatus);
            },
            child: Text(
              strikeOff.isApproved ? 'Set In Testing' : 'Approve Swatch',
              style: GoogleFonts.publicSans(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(printingProvider);

    final activeSelectedBuyerId = state.selectedBuyerId == 'ALL'
        ? 'ALL'
        : (state.selectedBuyerId.isNotEmpty && state.buyers.any((b) => b.id == state.selectedBuyerId)
            ? state.selectedBuyerId
            : (state.buyers.isNotEmpty ? state.buyers.first.id : 'ALL'));

    final PrintingBuyerContract? selectedBuyer = activeSelectedBuyerId == 'ALL'
        ? null
        : (state.buyers.where((b) => b.id == activeSelectedBuyerId).firstOrNull ??
            (state.buyers.isNotEmpty ? state.buyers.first : null));

    final buyerTitle = selectedBuyer != null ? selectedBuyer.buyerName : 'No Active Buyers';
    final articleCode = selectedBuyer?.linkedArticleNumber;

    // Route resolution
    final activeRouteKey = selectedBuyer != null
        ? (state.articleRoutes[selectedBuyer.id] ?? selectedBuyer.embellishmentSequence)
        : (state.articleRoutes['ALL'] ?? 'PRINT_FIRST_THEN_EMBROIDERY');

    final routeOption = kPrintingRouteOptions.firstWhere(
      (r) => r.key == activeRouteKey,
      orElse: () => kPrintingRouteOptions.first,
    );

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

    final completedPrinting = buyerTasks
        .where((t) => t.isCompleted)
        .fold<int>(0, (sum, t) => sum + (t.completedPieces > 0 ? t.completedPieces : t.piecesToPrint));

    final pendingPrinting = buyerTasks
        .where((t) => !t.isCompleted)
        .fold<int>(0, (sum, t) => sum + t.piecesToPrint);

    // In Hand resolution based on upstream Cutting Floor pieces
    final upstreamCut = state.upstreamCutPieces;
    final upstreamEmb = state.upstreamEmbroideryPieces;

    int sourcePieces = upstreamCut;
    if (activeRouteKey == 'EMBROIDERY_FIRST_THEN_PRINT') {
      sourcePieces = upstreamEmb;
    }

    final totalAllocated = pendingPrinting + completedPrinting;
    final inHand = (sourcePieces - totalAllocated) > 0 ? (sourcePieces - totalAllocated) : 0;

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
        matchesFilter = !task.isCompleted;
      } else if (state.statusFilter == 'NEEDS_VERIFY') {
        matchesFilter = task.isWorkerCompleted;
      } else if (state.statusFilter == 'COMPLETED') {
        matchesFilter = task.isCompleted;
      }

      return matchesSearch && matchesFilter;
    }).toList();

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFFAF7F0),
      drawer: const WorkspaceHubDrawer(activeRoute: '/printing'),
      appBar: ZigzaAppBar(
        onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      body: state.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF3A3564)),
            )
          : RefreshIndicator(
              onRefresh: () => ref.read(printingProvider.notifier).syncData(),
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
                                  'Workspace hub / Division 04 - Printing studio',
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
                                'SCREEN & DIGITAL PRINT SYNC ACTIVE',
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
                    // 1. SCREEN & DIGITAL PRINTING STUDIO HEADER CARD
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
                                  child: Icon(Icons.print_outlined, color: Color(0xFF3A3564), size: 24),
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
                                          'Screen & digital printing studio',
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
                                      'Screen tables, automatic carousels, DTG stations, shift matrix tracking, and curing sign-offs',
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
                                    MaterialPageRoute(builder: (_) => const PrintingZigzaAiScreen()),
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
                            onTap: () => _openRouteModal(activeRouteKey, buyerTitle, selectedBuyer?.id ?? 'ALL'),
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
                                          'Route: ${routeOption.shortLabel}',
                                          style: GoogleFonts.publicSans(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF0F172A),
                                          ),
                                        ),
                                        Text(
                                          '(${routeOption.stepIndicator})',
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

                          // Buyer Dropdown Switcher (Always available with 'All Buyers' option)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAF7F0),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: activeSelectedBuyerId,
                                isExpanded: true,
                                icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B)),
                                items: [
                                  DropdownMenuItem<String>(
                                    value: 'ALL',
                                    child: Row(
                                      children: [
                                        const Icon(Icons.people_outline, size: 16, color: Color(0xFF3A3564)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'All Buyers (${state.taskAllocations.length} Active Lots)',
                                            style: GoogleFonts.publicSans(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFF0F172A),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ...state.buyers.map((b) {
                                    return DropdownMenuItem<String>(
                                      value: b.id,
                                      child: Row(
                                        children: [
                                          const Icon(Icons.business_outlined, size: 16, color: Color(0xFF3A3564)),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              '${b.buyerName} ($upstreamCut Cut / ${b.contractedVolume} BPO)',
                                              style: GoogleFonts.publicSans(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFF0F172A),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    ref.read(printingProvider.notifier).setSelectedBuyerId(val);
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
                                  onPressed: () => ref.read(printingProvider.notifier).syncData(),
                                  tooltip: 'Re-sync printing floor data',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ==========================================
                    // 3. FOUR STACKED STAT CARDS
                    // ==========================================
                    _buildStatCard(
                      label: 'In hand',
                      value: '$inHand',
                      description: '$inHand pcs received from ${routeOption.sourceDepartment} (Awaiting sign-off)',
                      icon: Icons.pending_actions_outlined,
                      isNumber: true,
                    ),
                    const SizedBox(height: 10),
                    _buildStatCard(
                      label: 'Pending printing',
                      value: '$pendingPrinting',
                      description: '$pendingPrinting pcs assigned to table',
                      icon: Icons.table_restaurant_outlined,
                      isNumber: true,
                    ),
                    const SizedBox(height: 10),
                    _buildStatCard(
                      label: 'Completed printing',
                      value: '$completedPrinting',
                      description: '$completedPrinting printed panels cured',
                      icon: Icons.inventory_2_outlined,
                      isNumber: true,
                    ),
                    const SizedBox(height: 10),
                    _buildStatCard(
                      label: 'Strike off',
                      value: state.strikeOffApproval.isApproved ? 'Approved' : state.strikeOffApproval.status,
                      description: state.strikeOffApproval.labRemarks,
                      icon: Icons.file_download_done_outlined,
                      isNumber: false,
                      valueColor: state.strikeOffApproval.isApproved ? const Color(0xFF047857) : const Color(0xFFD97706),
                      onTap: () => _toggleStrikeOffDialog(state.strikeOffApproval),
                    ),

                    const SizedBox(height: 14),

                    // ==========================================
                    // 4. PRINTING TASK ALLOCATION MATRIX CARD
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
                                        'Printing floor task allocation matrix',
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
                                  'Distribute article print quotas, assign tables/carousels, and set shift deadline targets',
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
                                    onChanged: (val) => ref.read(printingProvider.notifier).setSearchQuery(val),
                                    style: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF0F172A)),
                                    decoration: InputDecoration(
                                      hintText: 'Search worker, article, table...',
                                      hintStyle: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF94A3B8)),
                                      prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                                      suffixIcon: _searchCtrl.text.isNotEmpty
                                          ? IconButton(
                                              icon: const Icon(Icons.clear, size: 16, color: Color(0xFF94A3B8)),
                                              onPressed: () {
                                                _searchCtrl.clear();
                                                ref.read(printingProvider.notifier).setSearchQuery('');
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
                                      'No matching printing tasks',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Allocate article print piece quotas to registered workers. When assigned, pieces move from In Hand to Pending Printing.',
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
                                  'In hand: $inHand • Pending: $pendingPrinting • Completed: $completedPrinting',
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
    Color? valueColor,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
          boxShadow: [BoxKeyValues.cardShadow],
        ),
        child: Row(
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
                    style: isNumber
                        ? GoogleFonts.jetBrainsMono(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: valueColor ?? const Color(0xFF0F172A),
                          )
                        : GoogleFonts.plusJakartaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: valueColor ?? const Color(0xFF047857),
                          ),
                  ),
                  const SizedBox(height: 2),
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
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFFAF7F0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
              ),
              child: Icon(icon, color: const Color(0xFF3A3564), size: 22),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTab(String label, String value, String currentVal) {
    final isSelected = value == currentVal;
    return InkWell(
      onTap: () => ref.read(printingProvider.notifier).setStatusFilter(value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3A3564) : const Color(0xFFFAF7F0),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF3A3564) : Colors.black.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildTaskRow(PrintingTaskAllocation task) {
    Color statusBg;
    Color statusBorder;
    Color statusText;
    String statusLabel;

    if (task.isCompleted) {
      statusBg = const Color(0xFFECFDF5);
      statusBorder = const Color(0xFFA7F3D0);
      statusText = const Color(0xFF047857);
      statusLabel = 'VERIFIED';
    } else if (task.isWorkerCompleted) {
      statusBg = const Color(0xFFFEF3C7);
      statusBorder = const Color(0xFFFDE68A);
      statusText = const Color(0xFFB45309);
      statusLabel = 'NEEDS VERIFY';
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
                '${task.piecesToPrint} pcs',
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
