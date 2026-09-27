import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/widgets/zigza_app_bar.dart';
import '../../modules/widgets/workspace_hub_drawer.dart';
import '../../dashboard/dispatch_dashboard.dart';
import '../models/ready_goods_models.dart';
import '../providers/ready_goods_provider.dart';
import '../widgets/ready_goods_worker_list_modal.dart';
import '../widgets/add_ready_goods_worker_modal.dart';
import '../widgets/inward_inspection_lot_modal.dart';
import '../widgets/inspect_lot_modal.dart';

class QualityClinicFloorScreen extends ConsumerStatefulWidget {
  const QualityClinicFloorScreen({super.key});

  @override
  ConsumerState<QualityClinicFloorScreen> createState() => _QualityClinicFloorScreenState();
}

class _QualityClinicFloorScreenState extends ConsumerState<QualityClinicFloorScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchCtrl = TextEditingController();

  // Design Tokens (Industrial Luxury Aesthetic - Light Theme Fixed Palette)
  static const Color kCanvasColor = Color(0xFFFAF7F0); // Warm cream canvas
  static const Color kCardBg = Color(0xFFFFFFFF);
  static const Color kPrimaryBrand = Color(0xFF3A3564); // Primary brand plum
  static const Color kBorderColor = Color(0xFFE7E1D6); // Hairline border
  static const Color kMutedText = Color(0xFF7A7488); // Muted text
  static const Color kInkText = Color(0xFF232028); // Primary ink text
  static const Color kBluePastelBg = Color(0xFFE5EDF9); // Blue pastel bg
  static const Color kBluePastelText = Color(0xFF2E5AA8); // Blue pastel text

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openInwardModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const InwardInspectionLotModal(),
    );
  }

  void _openWorkerListModal() {
    showDialog(
      context: context,
      builder: (ctx) => const ReadyGoodsWorkerListModal(),
    );
  }

  void _openAddWorkerModal() {
    showDialog(
      context: context,
      builder: (ctx) => const AddReadyGoodsWorkerModal(),
    );
  }

  void _openInspectModal(FinishingInspectionTask task) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => InspectLotModal(task: task),
    );
  }

  void _confirmDeleteTask(FinishingInspectionTask task) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: kBorderColor),
        ),
        title: Text(
          'Remove Quality Lot?',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: kInkText,
          ),
        ),
        content: Text(
          'Are you sure you want to remove Lot #${task.taskCode} (${task.piecesCount} pcs • ${task.styleName}) from the quality inspection queue?',
          style: GoogleFonts.publicSans(
            fontSize: 13,
            color: kMutedText,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.publicSans(color: kMutedText, fontWeight: FontWeight.w600),
            ),
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
              await ref.read(readyGoodsProvider.notifier).deleteTask(task.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Lot #${task.taskCode} removed.'),
                    backgroundColor: const Color(0xFFE11D48),
                  ),
                );
              }
            },
            child: Text(
              'Remove Lot',
              style: GoogleFonts.publicSans(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmResetData() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: kBorderColor),
        ),
        title: Text(
          'Reset Quality Clinic Data?',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: kInkText,
          ),
        ),
        content: Text(
          'This will clear all registered floor workers and inspection tasks back to a clean 0-state matching web admin.',
          style: GoogleFonts.publicSans(
            fontSize: 13,
            color: kMutedText,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.publicSans(color: kMutedText)),
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
              await ref.read(readyGoodsProvider.notifier).resetAllData();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Quality Clinic data reset to clean 0-state.')),
                );
              }
            },
            child: Text('Reset Data', style: GoogleFonts.publicSans(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(readyGoodsProvider);
    final tasks = state.tasks;
    final workers = state.workers;
    final buyers = state.buyers;
    final filteredTasks = state.filteredTasks;

    // Stat counts across current buyer scope
    final buyerScopedTasks = state.buyerTasks;
    final pendingCount = buyerScopedTasks.where((t) => t.status == 'PENDING_CHECK' || t.status == 'IN_CHECKING').length;
    final alterationCount = buyerScopedTasks.where((t) => t.status == 'REJECTED_TO_ALTERATION').length;
    final passedCount = buyerScopedTasks.where((t) => t.status == 'PASSED_TO_PACKING' || t.status == 'PACKED_IN_CARTON').length;
    final totalLotsCount = buyerScopedTasks.length;
    final totalPiecesCount = buyerScopedTasks.fold<int>(0, (sum, t) => sum + t.piecesCount);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: kCanvasColor,
      drawer: const WorkspaceHubDrawer(activeRoute: '/ready-goods'),
      appBar: ZigzaAppBar(
        onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      body: RefreshIndicator(
        color: kPrimaryBrand,
        backgroundColor: kCardBg,
        onRefresh: () async {
          await ref.read(readyGoodsProvider.notifier).fetchData();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ==========================================
              // a. Breadcrumb block
              // ==========================================
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: () => Navigator.pop(context),
                            child: Text(
                              'Workspace Hub',
                              style: GoogleFonts.publicSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: kMutedText,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text('/', style: TextStyle(color: kBorderColor, fontSize: 12)),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: kBluePastelBg,
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(color: kBluePastelText.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              'Division 09 · Ready Goods Clinic',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: kBluePastelText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Page title header
              Text(
                'Quality Clinic & Export Packing',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: kInkText,
                ),
              ),
              const SizedBox(height: 12),

              // ==========================================
              // b. Cross-division nav link
              // ==========================================
              InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DispatchDashboard()),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: kCardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kBorderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: kCanvasColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: kBorderColor),
                        ),
                        child: const Icon(Icons.inventory_2_outlined, size: 16, color: kPrimaryBrand),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Go to Packing Goods',
                        style: GoogleFonts.publicSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: kInkText,
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.arrow_forward_rounded, size: 16, color: kMutedText),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // ==========================================
              // c. Module card
              // ==========================================
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: kCardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kBorderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
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
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: kCanvasColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: kBorderColor),
                          ),
                          child: const Icon(Icons.build_outlined, size: 20, color: kPrimaryBrand),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Alteration & Quality Clinic',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: kInkText,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Post-wash QC inspection, defect clinic & packing clearance.',
                                style: GoogleFonts.publicSans(
                                  fontSize: 12,
                                  color: kMutedText,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Two outline buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Opening Ready Goods Worker Terminal...')),
                              );
                            },
                            icon: const Icon(Icons.arrow_outward, size: 14, color: kPrimaryBrand),
                            label: Text(
                              'Worker Terminal',
                              style: GoogleFonts.publicSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: kPrimaryBrand,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: kBorderColor),
                              backgroundColor: kCardBg,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Zigza AI Quality Diagnostics Active.')),
                              );
                            },
                            icon: const Icon(Icons.build_outlined, size: 14, color: kPrimaryBrand),
                            label: Text(
                              'Zigza AI',
                              style: GoogleFonts.publicSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: kPrimaryBrand,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: kBorderColor),
                              backgroundColor: kCardBg,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),
                    // Small refresh icon button, bottom-right of the card, on its own row
                    Align(
                      alignment: Alignment.centerRight,
                      child: InkWell(
                        onTap: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          await ref.read(readyGoodsProvider.notifier).fetchData();
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Quality Clinic module refreshed.')),
                          );
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: kCanvasColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: kBorderColor),
                          ),
                          child: const Icon(Icons.refresh, size: 14, color: kMutedText),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ==========================================
              // d. Selected Buyer Contract card
              // ==========================================
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: kCardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kBorderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SELECTED BUYER CONTRACT',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: kMutedText,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'All Buyers & Contracts',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: kInkText,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Custom styled dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      decoration: BoxDecoration(
                        color: kCardBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: kBorderColor),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: state.selectedBuyerId,
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down, size: 16, color: kPrimaryBrand),
                          items: [
                            DropdownMenuItem<String>(
                              value: 'ALL',
                              child: Text(
                                'All Buyers ($totalLotsCount Lots · $totalPiecesCount Pcs)',
                                style: GoogleFonts.publicSans(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: kInkText,
                                ),
                              ),
                            ),
                            ...buyers.map((b) {
                              final buyerLots = tasks.where((t) => t.buyer.toLowerCase() == b.buyerName.toLowerCase()).length;
                              final buyerPcs = tasks
                                  .where((t) => t.buyer.toLowerCase() == b.buyerName.toLowerCase())
                                  .fold<int>(0, (sum, t) => sum + t.piecesCount);
                              return DropdownMenuItem<String>(
                                value: b.buyerName,
                                child: Text(
                                  '${b.buyerName} ($buyerLots Lots · $buyerPcs Pcs)',
                                  style: GoogleFonts.publicSans(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: kInkText,
                                  ),
                                ),
                              );
                            }),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              ref.read(readyGoodsProvider.notifier).selectBuyer(val);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Buttons row: "Workers (N)" / "+ Worker" (both outline)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _openWorkerListModal,
                            icon: const Icon(Icons.people_outline, size: 14, color: kInkText),
                            label: Text(
                              'Workers (${workers.length})',
                              style: GoogleFonts.publicSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: kInkText,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: kBorderColor),
                              backgroundColor: kCardBg,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _openAddWorkerModal,
                            icon: const Icon(Icons.person_add_alt_1_outlined, size: 14, color: kInkText),
                            label: Text(
                              '+ Worker',
                              style: GoogleFonts.publicSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: kInkText,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: kBorderColor),
                              backgroundColor: kCardBg,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Bottom row: "📦 + Inward Lot" (filled plum, wide) + small refresh icon button beside it
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _openInwardModal,
                            icon: const Text('📦', style: TextStyle(fontSize: 14)),
                            label: Text(
                              '+ Inward Lot',
                              style: GoogleFonts.publicSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kPrimaryBrand,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: _confirmResetData,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: kCanvasColor,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: kBorderColor),
                            ),
                            child: const Icon(Icons.refresh, size: 15, color: kMutedText),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ==========================================
              // e. Three stacked stat cards (numbers stand alone, no subtext)
              // ==========================================
              _buildStatCard(
                title: 'INSPECTION QUEUE',
                value: '$pendingCount',
                icon: Icons.content_cut,
              ),
              const SizedBox(height: 8),
              _buildStatCard(
                title: 'ALTERATION REWORK',
                value: '$alterationCount',
                icon: Icons.build_outlined,
              ),
              const SizedBox(height: 8),
              _buildStatCard(
                title: 'PASSED FOR PACKING',
                value: '$passedCount',
                icon: Icons.check,
              ),
              const SizedBox(height: 16),

              // ==========================================
              // f. Search bar
              // ==========================================
              Container(
                decoration: BoxDecoration(
                  color: kCardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kBorderColor),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (val) {
                    ref.read(readyGoodsProvider.notifier).setSearchQuery(val);
                  },
                  style: GoogleFonts.publicSans(fontSize: 13, color: kInkText),
                  decoration: InputDecoration(
                    hintText: 'Search lot #, buyer, style, wash batch…',
                    hintStyle: GoogleFonts.publicSans(fontSize: 12.5, color: kMutedText),
                    prefixIcon: const Icon(Icons.search, size: 16, color: kMutedText),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 14, color: kMutedText),
                            onPressed: () {
                              _searchCtrl.clear();
                              ref.read(readyGoodsProvider.notifier).setSearchQuery('');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // ==========================================
              // g. Filter tabs with count badges
              // ==========================================
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterTab(
                      label: 'All Lots',
                      count: totalLotsCount,
                      filterKey: 'ALL',
                      currentFilter: state.statusFilter,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterTab(
                      label: 'Pending Check',
                      count: pendingCount,
                      filterKey: 'PENDING',
                      currentFilter: state.statusFilter,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterTab(
                      label: 'In Alteration',
                      count: alterationCount,
                      filterKey: 'ALTERATION',
                      currentFilter: state.statusFilter,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterTab(
                      label: 'Ready to Pack',
                      count: passedCount,
                      filterKey: 'PASSED',
                      currentFilter: state.statusFilter,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ==========================================
              // h. Quality Inspection Lots card
              // ==========================================
              Container(
                decoration: BoxDecoration(
                  color: kCardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kBorderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Title and badge header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Quality Inspection Lots',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: kInkText,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: kCanvasColor,
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(color: kBorderColor),
                            ),
                            child: Text(
                              '${filteredTasks.length} lots',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: kInkText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Table header row
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: const BoxDecoration(
                        color: kCanvasColor,
                        border: Border.symmetric(horizontal: BorderSide(color: kBorderColor)),
                      ),
                      child: Text(
                        'Lot # / Order • Buyer & Style • Pieces & Size • Wash & Iron Origin',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: kMutedText,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),

                    // Content: Clean Empty State OR Lot List
                    if (filteredTasks.isEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: kCanvasColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: kBorderColor),
                              ),
                              child: const Icon(Icons.inventory_2_outlined, size: 24, color: kMutedText),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Quality Clinic is empty. Inward incoming garment lots to begin inspection.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.publicSans(
                                fontSize: 12.5,
                                color: kMutedText,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _openInwardModal,
                                icon: const Text('📦', style: TextStyle(fontSize: 14)),
                                label: Text(
                                  '+ Inward Lot',
                                  style: GoogleFonts.publicSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: kPrimaryBrand,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredTasks.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: kBorderColor),
                        itemBuilder: (context, index) {
                          final task = filteredTasks[index];
                          return _buildTaskCard(task);
                        },
                      ),
                    ],
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

  // Pure Stat Card Widget (numbers stand alone, no subtext captions)
  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: kMutedText,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: kInkText,
                ),
              ),
            ],
          ),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: kCanvasColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kBorderColor),
            ),
            child: Icon(icon, size: 18, color: kPrimaryBrand),
          ),
        ],
      ),
    );
  }

  // Filter Tab Widget with count badge
  Widget _buildFilterTab({
    required String label,
    required int count,
    required String filterKey,
    required String currentFilter,
  }) {
    final isActive = currentFilter == filterKey;
    return InkWell(
      onTap: () {
        ref.read(readyGoodsProvider.notifier).setStatusFilter(filterKey);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? kPrimaryBrand : kCardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isActive ? kPrimaryBrand : kBorderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.publicSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isActive ? Colors.white : kInkText,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isActive ? Colors.white.withValues(alpha: 0.2) : kCanvasColor,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: isActive ? Colors.white.withValues(alpha: 0.3) : kBorderColor,
                ),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isActive ? Colors.white : kInkText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Quality Inspection Lot Item Tile
  Widget _buildTaskCard(FinishingInspectionTask task) {
    Color statusBg;
    Color statusColor;
    String statusLabel;

    if (task.status == 'PASSED_TO_PACKING' || task.status == 'PACKED_IN_CARTON') {
      statusBg = const Color(0xFFD1FAE5);
      statusColor = const Color(0xFF047857);
      statusLabel = 'READY TO PACK';
    } else if (task.status == 'REJECTED_TO_ALTERATION') {
      statusBg = const Color(0xFFFFE4E6);
      statusColor = const Color(0xFFBE123C);
      statusLabel = 'IN ALTERATION';
    } else {
      statusBg = const Color(0xFFFEF3C7);
      statusColor = const Color(0xFFB45309);
      statusLabel = 'PENDING CHECK';
    }

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Lot # + Order + Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: kPrimaryBrand,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '#${task.taskCode}',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    task.orderNumber,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: kMutedText,
                    ),
                  ),
                  if (task.priority != 'NORMAL') ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE4E6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        task.priority,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFBE123C),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  statusLabel,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Style & Buyer Info
          Text(
            '${task.buyer} • ${task.styleName}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: kInkText,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${task.color} • ${task.piecesCount} pcs • Size ${task.size}',
            style: GoogleFonts.publicSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: kMutedText,
            ),
          ),
          const SizedBox(height: 6),

          // Origin details
          Row(
            children: [
              Expanded(
                child: Text(
                  'Wash: ${task.washBatchRef}',
                  style: GoogleFonts.publicSans(fontSize: 11, color: kMutedText),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                child: Text(
                  'Iron: ${task.ironStationRef}',
                  style: GoogleFonts.publicSans(fontSize: 11, color: kMutedText),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Criteria chips row
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _buildCriteriaChip('Cutting', task.checklist.cuttingDoneRight),
              if (task.hasPrinting) _buildCriteriaChip('Printing', task.checklist.printingDoneRight),
              if (task.hasEmbroidery) _buildCriteriaChip('Embroidery', task.checklist.embroideryDoneRight),
              _buildCriteriaChip('Washing', task.checklist.washingDoneRight),
              _buildCriteriaChip('Ironing', task.checklist.ironDoneRight),
            ],
          ),

          // Defect note if in alteration
          if (task.status == 'REJECTED_TO_ALTERATION' && task.defectNotes != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFECDD3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFBE123C)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${task.defectReason ?? 'DEFECT'}: ${task.defectNotes}',
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

          const SizedBox(height: 10),

          // Action row
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (task.status == 'PENDING_CHECK' || task.status == 'IN_CHECKING') ...[
                ElevatedButton.icon(
                  onPressed: () => _openInspectModal(task),
                  icon: const Icon(Icons.verified_outlined, size: 14),
                  label: Text(
                    'Inspect / Check',
                    style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryBrand,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                ),
              ] else if (task.status == 'REJECTED_TO_ALTERATION') ...[
                OutlinedButton.icon(
                  onPressed: () async {
                    await ref.read(readyGoodsProvider.notifier).markRepaired(task.id);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Lot #${task.taskCode} marked repaired & returned to checking queue.'),
                          backgroundColor: const Color(0xFF10B981),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.build_outlined, size: 14, color: Color(0xFF047857)),
                  label: Text(
                    'Mark Repaired',
                    style: GoogleFonts.publicSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF047857),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF6EE7B7)),
                    backgroundColor: const Color(0xFFECFDF5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _openInspectModal(task),
                  icon: const Icon(Icons.verified_outlined, size: 14),
                  label: Text(
                    'Re-Inspect',
                    style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryBrand,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, size: 14, color: Color(0xFF047857)),
                      const SizedBox(width: 6),
                      Text(
                        'Verified by ${task.checkedByWorkerName ?? 'Inspector'}',
                        style: GoogleFonts.publicSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF047857),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _confirmDeleteTask(task),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: kCanvasColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kBorderColor),
                  ),
                  child: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFE11D48)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCriteriaChip(String label, bool isDone) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isDone ? const Color(0xFFECFDF5) : kCanvasColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: isDone ? const Color(0xFF6EE7B7) : kBorderColor),
      ),
      child: Text(
        '$label: ${isDone ? '✓' : '—'}',
        style: GoogleFonts.jetBrainsMono(
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
          color: isDone ? const Color(0xFF047857) : kMutedText,
        ),
      ),
    );
  }
}
