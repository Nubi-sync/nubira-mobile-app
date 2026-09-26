import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/widgets/zigza_app_bar.dart';
import '../../modules/widgets/workspace_hub_drawer.dart';
import '../../modules/screens/enterprise_workspace_hub_screen.dart';
import '../../modules/screens/company_profile_screen.dart';
import '../models/washing_models.dart';
import '../providers/washing_provider.dart';
import '../widgets/add_washing_worker_modal.dart';
import '../widgets/washing_worker_list_modal.dart';
import '../widgets/add_washing_task_modal.dart';

class WashingFloorScreen extends ConsumerStatefulWidget {
  const WashingFloorScreen({super.key});

  @override
  ConsumerState<WashingFloorScreen> createState() => _WashingFloorScreenState();
}

class _WashingFloorScreenState extends ConsumerState<WashingFloorScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showBuyerSelectionSheet(BuildContext context, WashingState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final filteredBuyers = state.buyers.where((b) {
              if (searchQuery.isEmpty) return true;
              final q = searchQuery.toLowerCase();
              return b.buyerName.toLowerCase().contains(q) ||
                  b.linkedArticleNumber.toLowerCase().contains(q) ||
                  b.buyerCode.toLowerCase().contains(q);
            }).toList();

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.75,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Search Bar matching Web
                  Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF7F0),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                    ),
                    child: TextField(
                      autofocus: false,
                      onChanged: (v) => setSheetState(() => searchQuery = v.trim()),
                      style: GoogleFonts.publicSans(fontSize: 12.5),
                      decoration: const InputDecoration(
                        hintText: 'Search buyers...',
                        hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        prefixIcon: Icon(Icons.search, size: 17, color: Color(0xFF94A3B8)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 1. All Buyers & Contracts Option
                          if (searchQuery.isEmpty || 'all buyers & contracts'.contains(searchQuery.toLowerCase()))
                            _buildBuyerOption(
                              isSelected: state.selectedBuyerId == 'ALL',
                              title: 'All Buyers & Contracts',
                              subtitle: 'Show all ${state.taskAllocations.length} floor task allocations',
                              onTap: () {
                                ref.read(washingProvider.notifier).selectBuyer('ALL');
                                Navigator.pop(ctx);
                              },
                            ),

                          // 2. Individual Buyers
                          ...filteredBuyers.map((b) {
                            final isSelected = state.selectedBuyerId == b.id;
                            final formattedVol = b.contractedVolume.toString().replaceAllMapped(
                                  RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                                  (Match m) => '${m[1]},',
                                );
                            return _buildBuyerOption(
                              isSelected: isSelected,
                              title: b.buyerName,
                              subtitle: '$formattedVol BPO Pcs • ${b.linkedArticleNumber}',
                              onTap: () {
                                ref.read(washingProvider.notifier).selectBuyer(b.id);
                                Navigator.pop(ctx);
                              },
                            );
                          }),
                        ],
                      ),
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

  Widget _buildBuyerOption({
    required bool isSelected,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF3A3564) : const Color(0xFFFAF7F0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? const Color(0xFF3A3564) : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? const Color(0xFFC7D2FE) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_rounded, color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteTask(BuildContext context, WashingTaskAllocation task) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Remove Task Allocation?',
          style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
        ),
        content: Text(
          'Are you sure you want to remove task #${task.taskRef} (${task.piecesToWash} pcs of ${task.articleNumber} assigned to ${task.workerName})?',
          style: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(washingProvider.notifier).deleteTaskAllocation(task.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Task #${task.taskRef} removed from allocations.')),
              );
            },
            child: const Text('Remove Task'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(washingProvider);

    // Selected Buyer resolution
    WashingBuyerContract? selectedBuyer;
    if (state.selectedBuyerId != 'ALL') {
      selectedBuyer = state.buyers.firstWhere(
        (b) => b.id == state.selectedBuyerId,
        orElse: () => state.buyers.isNotEmpty ? state.buyers.first : const WashingBuyerContract(
          id: 'byr-ollywood',
          buyerName: 'ollywood',
          buyerCode: 'OLLY',
          contractedVolume: 5000,
          pricePerPiece: 15.0,
          totalContractValue: 75000,
          linkedArticleNumber: 'DEMO-102',
          linkedArticleName: 'Washed Oversized Heavyweight Tee',
        ),
      );
    }

    // Dynamic metrics calculation
    final totalContracted = selectedBuyer != null
        ? selectedBuyer.contractedVolume
        : state.buyers.fold<int>(0, (sum, b) => sum + b.contractedVolume);

    final matchingAllocations = state.taskAllocations.where((t) {
      if (selectedBuyer == null) return true;
      return t.buyerId == selectedBuyer.id || t.buyerName.toLowerCase() == selectedBuyer.buyerName.toLowerCase();
    }).toList();

    final completedPieces = matchingAllocations
        .where((t) => t.status == 'VERIFIED_COMPLETED')
        .fold<int>(0, (sum, t) => sum + (t.completedPieces > 0 ? t.completedPieces : t.piecesToWash));

    final pendingPieces = matchingAllocations
        .where((t) => t.status != 'VERIFIED_COMPLETED')
        .fold<int>(0, (sum, t) => sum + t.piecesToWash);

    final assignedTotal = matchingAllocations.fold<int>(0, (sum, t) => sum + t.piecesToWash);
    final inHandPieces = (totalContracted - assignedTotal).clamp(0, totalContracted);

    // Task table filtering
    final filteredTasks = matchingAllocations.where((task) {
      if (state.searchQuery.isNotEmpty) {
        final q = state.searchQuery.toLowerCase();
        final matches = task.taskRef.toLowerCase().contains(q) ||
            task.workerName.toLowerCase().contains(q) ||
            task.articleNumber.toLowerCase().contains(q) ||
            task.buyerName.toLowerCase().contains(q) ||
            task.machineNumber.toLowerCase().contains(q);
        if (!matches) return false;
      }

      if (state.statusFilter == 'ACTIVE') {
        return task.status != 'VERIFIED_COMPLETED';
      } else if (state.statusFilter == 'NEEDS_VERIFY') {
        return task.status == 'WORKER_COMPLETED' || task.status == 'ASSIGNED';
      } else if (state.statusFilter == 'COMPLETED') {
        return task.status == 'VERIFIED_COMPLETED';
      }
      return true;
    }).toList();

    final selectedBuyerDisplayText = selectedBuyer != null
        ? '${selectedBuyer.buyerName} (${selectedBuyer.contractedVolume.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} Pcs Contracted)'
        : (state.selectedBuyerId == 'ALL' ? 'All Buyers & Contracts' : 'Select Buyer Contract');

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFFAF7F0),
      drawer: const WorkspaceHubDrawer(activeRoute: '/washing'),
      appBar: ZigzaAppBar(
        onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      body: RefreshIndicator(
        color: const Color(0xFF3A3564),
        onRefresh: () => ref.read(washingProvider.notifier).loadInitialData(isRefresh: true),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ===============================================================
              // a. BREADCRUMB BLOCK & b. SYNC STATUS PILL
              // ===============================================================
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    InkWell(
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const EnterpriseWorkspaceHubScreen()),
                        );
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.arrow_back_ios_new_rounded, size: 11, color: Color(0xFF3A3564)),
                            const SizedBox(width: 4),
                            Text(
                              'Workspace Hub',
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
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5EDF9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF2E5AA8).withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        'Division 07 • Wet Processing & Laundry',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2E5AA8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Sync status pill (Emerald pastel with pulsing dot)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F3EA),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF1F8A5A).withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF1F8A5A),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Tumbler & Hydro Sync Active',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1F8A5A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ===============================================================
              // c. MODULE CARD
              // ===============================================================
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
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
                            color: const Color(0xFFFAF7F0),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                          ),
                          child: const Icon(Icons.waves_rounded, color: Color(0xFF3A3564), size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Text(
                                      'Industrial Washing Floor',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF0F172A),
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFAF7F0),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                                    ),
                                    child: Text(
                                      '${state.workers.length} Washers Registered',
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF3A3564),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Enzyme bio-polishing, silicon softening, 1:5.0 liquor ratio management, and hydro-dryer piece allocations.',
                                style: GoogleFonts.publicSans(
                                  fontSize: 11.5,
                                  color: const Color(0xFF64748B),
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Quick Action Buttons (Zigza AI / Division Profile)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF3A3564),
                              backgroundColor: const Color(0xFFFAF7F0),
                              side: BorderSide(color: Colors.black.withValues(alpha: 0.1)),
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Zigza AI Washing Assistant active on floor.')),
                              );
                            },
                            icon: const Icon(Icons.smart_toy_outlined, size: 15),
                            label: Text('Zigza AI', style: GoogleFonts.publicSans(fontSize: 11.5, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF3A3564),
                              backgroundColor: const Color(0xFFFAF7F0),
                              side: BorderSide(color: Colors.black.withValues(alpha: 0.1)),
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const CompanyProfileScreen()),
                              );
                            },
                            icon: const Icon(Icons.people_outline_rounded, size: 15),
                            label: Text('Division Profile', style: GoogleFonts.publicSans(fontSize: 11.5, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ===============================================================
              // d. SELECTED BUYER CONTRACT CARD
              // ===============================================================
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAF7F0),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                          ),
                          child: const Icon(Icons.apartment_rounded, color: Color(0xFF3A3564), size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SELECTED BUYER CONTRACT',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF64748B),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(
                                    selectedBuyer != null ? selectedBuyer.buyerName : 'All Buyers & Contracts',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                  if (selectedBuyer != null && selectedBuyer.linkedArticleNumber.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFAF7F0),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                                      ),
                                      child: Text(
                                        'Article: ${selectedBuyer.linkedArticleNumber}',
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF3A3564),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => ref.read(washingProvider.notifier).loadInitialData(isRefresh: true),
                          icon: const Icon(Icons.refresh_rounded, size: 18, color: Color(0xFF3A3564)),
                          tooltip: 'Refresh floor state',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Dropdown button for Buyer Selection
                    InkWell(
                      onTap: () => _showBuyerSelectionSheet(context, state),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAF7F0),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.people_outline_rounded, size: 16, color: Color(0xFF3A3564)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                selectedBuyerDisplayText,
                                style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Buttons: View Worker List & + Add Worker
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF0F172A),
                              backgroundColor: Colors.white,
                              side: BorderSide(color: Colors.black.withValues(alpha: 0.12)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => WashingWorkerListModal.show(context),
                            icon: const Icon(Icons.people_outline_rounded, size: 15, color: Color(0xFF3A3564)),
                            label: Text(
                              'View Worker List (${state.workers.length})',
                              style: GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3A3564),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => AddWashingWorkerModal.show(context),
                            icon: const Icon(Icons.person_add_outlined, size: 15),
                            label: Text(
                              '+ Add Worker',
                              style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ===============================================================
              // e. THREE STACKED STAT CARDS (IN HAND, PROCESSING, COMPLETE)
              // ===============================================================
              _buildStatCard(
                title: 'IN HAND',
                value: inHandPieces.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},'),
                subtext: inHandPieces > 0
                    ? '${inHandPieces.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} pcs ready for wash recipe loading'
                    : '0 pcs in hand (All garments allocated)',
                icon: Icons.shopping_bag_outlined,
              ),
              const SizedBox(height: 10),
              _buildStatCard(
                title: 'PROCESSING / IN PROGRESS',
                value: pendingPieces.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},'),
                subtext: pendingPieces > 0
                    ? '$pendingPieces pcs running in wash tumblers & hydro dryers'
                    : '0 pcs in active washing cycles',
                icon: Icons.access_time_rounded,
              ),
              const SizedBox(height: 10),
              _buildStatCard(
                title: 'COMPLETE / VERIFIED',
                value: completedPieces.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},'),
                subtext: completedPieces > 0
                    ? '$completedPieces washed panels verified & moisture tested'
                    : '0 washed panels verified',
                icon: Icons.waves_rounded,
              ),

              const SizedBox(height: 14),

              // ===============================================================
              // f. SPREADSHEET MATRIX CARD
              // ===============================================================
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Bar
                    Padding(
                      padding: const EdgeInsets.all(16),
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
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Washing Floor Task Allocation Matrix',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                    Text(
                                      'Distribute garment washing batches, assign hydro-dryers, and set shift completion targets.',
                                      style: GoogleFonts.publicSans(fontSize: 11, color: const Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Search Bar
                          Container(
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAF7F0),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                            ),
                            child: TextField(
                              controller: _searchCtrl,
                              onChanged: (v) => ref.read(washingProvider.notifier).setSearchQuery(v.trim()),
                              style: GoogleFonts.publicSans(fontSize: 12),
                              decoration: const InputDecoration(
                                hintText: 'Search worker, article, machine...',
                                hintStyle: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                                prefixIcon: Icon(Icons.search, size: 16, color: Color(0xFF94A3B8)),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(vertical: 9),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Filter Tabs Row
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildTabPill('ALL', 'All'),
                                const SizedBox(width: 6),
                                _buildTabPill('ACTIVE', 'Active Queue'),
                                const SizedBox(width: 6),
                                _buildTabPill('NEEDS_VERIFY', 'Needs Verification'),
                                const SizedBox(width: 6),
                                _buildTabPill('COMPLETED', 'Verified & Done'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // + Add Task Row Full-Width Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3A3564),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () => AddWashingTaskModal.show(context),
                              icon: const Icon(Icons.add, size: 16),
                              label: Text(
                                '+ Add Task Row',
                                style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Divider(height: 1, color: Color(0x14000000)),

                    // Table / List Content
                    if (filteredTasks.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                        child: Center(
                          child: Column(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFAF7F0),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                                ),
                                child: const Icon(Icons.waves_rounded, color: Color(0xFF3A3564), size: 24),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No tasks yet. Click "+ Add Task Row" to begin.',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Allocate garment batches to washing operators.',
                                style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(const Color(0xFFFAF7F0)),
                          headingTextStyle: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF64748B),
                          ),
                          dataTextStyle: GoogleFonts.publicSans(
                            fontSize: 11.5,
                            color: const Color(0xFF0F172A),
                          ),
                          columns: const [
                            DataColumn(label: Text('TASK REF')),
                            DataColumn(label: Text('BUYER / BRAND')),
                            DataColumn(label: Text('ARTICLE NO')),
                            DataColumn(label: Text('WASHER OPERATOR')),
                            DataColumn(label: Text('MACHINE / TUMBLER')),
                            DataColumn(label: Text('TARGET PCS'), numeric: true),
                            DataColumn(label: Text('COMPLETED PCS'), numeric: true),
                            DataColumn(label: Text('WASH RECIPE')),
                            DataColumn(label: Text('STATUS')),
                            DataColumn(label: Text('ACTIONS')),
                          ],
                          rows: filteredTasks.map((task) {
                            final isCompleted = task.status == 'VERIFIED_COMPLETED';
                            return DataRow(
                              cells: [
                                DataCell(
                                  Text(
                                    '#${task.taskRef}',
                                    style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, color: const Color(0xFF3A3564)),
                                  ),
                                ),
                                DataCell(Text(task.buyerName, style: const TextStyle(fontWeight: FontWeight.w600))),
                                DataCell(
                                  Text(
                                    task.articleNumber,
                                    style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, color: const Color(0xFF3A3564)),
                                  ),
                                ),
                                DataCell(
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(task.workerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      if (task.workerPhone.isNotEmpty)
                                        Text('+91 ${task.workerPhone}', style: GoogleFonts.jetBrainsMono(fontSize: 9.5, color: const Color(0xFF94A3B8))),
                                    ],
                                  ),
                                ),
                                DataCell(Text(task.machineNumber)),
                                DataCell(
                                  Text(
                                    task.piecesToWash.toString(),
                                    style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    task.completedPieces.toString(),
                                    style: GoogleFonts.jetBrainsMono(
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF047857),
                                    ),
                                  ),
                                ),
                                DataCell(Text(task.washRecipe)),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                    decoration: BoxDecoration(
                                      color: isCompleted ? const Color(0xFFECFDF5) : const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: isCompleted ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A),
                                      ),
                                    ),
                                    child: Text(
                                      isCompleted ? 'VERIFIED COMPLETED' : task.status.replaceAll('_', ' '),
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: isCompleted ? const Color(0xFF047857) : const Color(0xFFB45309),
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (!isCompleted)
                                        IconButton(
                                          icon: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF047857), size: 18),
                                          tooltip: 'Verify & Done',
                                          onPressed: () {
                                            ref.read(washingProvider.notifier).verifyAndDone(task.id, task.piecesToWash);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Task #${task.taskRef} verified & completed!'),
                                                backgroundColor: const Color(0xFF047857),
                                              ),
                                            );
                                          },
                                        ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18),
                                        tooltip: 'Remove Task',
                                        onPressed: () => _confirmDeleteTask(context, task),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
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

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtext,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF64748B),
                  letterSpacing: 0.5,
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF7F0),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                ),
                child: Icon(icon, color: const Color(0xFF3A3564), size: 18),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtext,
            style: GoogleFonts.publicSans(fontSize: 11, color: const Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildTabPill(String filterKey, String label) {
    final currentFilter = ref.watch(washingProvider).statusFilter;
    final isSelected = currentFilter == filterKey;

    return InkWell(
      onTap: () => ref.read(washingProvider.notifier).setStatusFilter(filterKey),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3A3564) : const Color(0xFFFAF7F0),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF3A3564) : Colors.black.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}
