import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/widgets/zigza_app_bar.dart';
import '../../modules/widgets/workspace_hub_drawer.dart';
import '../../modules/screens/company_profile_screen.dart';
import '../models/iron_models.dart';
import '../providers/iron_provider.dart';
import '../widgets/add_iron_worker_modal.dart';
import '../widgets/iron_worker_list_modal.dart';
import '../widgets/add_iron_task_modal.dart';
import 'iron_zigza_ai_screen.dart';

class IronFloorScreen extends ConsumerStatefulWidget {
  const IronFloorScreen({super.key});

  @override
  ConsumerState<IronFloorScreen> createState() => _IronFloorScreenState();
}

class _IronFloorScreenState extends ConsumerState<IronFloorScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _taskSearchCtrl = TextEditingController();

  @override
  void dispose() {
    _taskSearchCtrl.dispose();
    super.dispose();
  }

  void _confirmDeleteTask(IronTaskAllocation task) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Remove Task Allocation?',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF232028),
          ),
        ),
        content: Text(
          'Are you sure you want to remove task #${task.taskRef} (${task.piecesToPress} pcs of ${task.articleNumber} assigned to ${task.workerName})?',
          style: GoogleFonts.publicSans(
            fontSize: 13,
            color: const Color(0xFF7A7488),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.publicSans(color: const Color(0xFF7A7488)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(ironProvider.notifier).deleteTaskAllocation(task.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Task #${task.taskRef} removed from allocations.')),
                );
              }
            },
            child: Text(
              'Remove Task',
              style: GoogleFonts.publicSans(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _handleVerifyAndDone(IronTaskAllocation task) async {
    await ref.read(ironProvider.notifier).verifyAndDone(task.id, task.piecesToPress);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1F8A5A),
          content: Text(
            'Task #${task.taskRef} verified! ${task.piecesToPress} pcs steam pressed & finish QC passed.',
            style: GoogleFonts.publicSans(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ironState = ref.watch(ironProvider);
    final workers = ironState.workers;
    final allocations = ironState.taskAllocations;
    final buyers = ironState.buyers;

    // Active Selected Buyer Resolution
    final selectedBuyer = ironState.selectedBuyerId == 'ALL'
        ? null
        : buyers.firstWhere(
            (b) => b.id == ironState.selectedBuyerId,
            orElse: () => buyers.isNotEmpty
                ? buyers.first
                : const IronBuyerContract(
                    id: 'byr-ollywood',
                    buyerName: 'ollywood',
                    buyerCode: 'OLLY',
                    contractedVolume: 5000,
                    pricePerPiece: 2.20,
                    totalContractValue: 11000,
                    linkedArticleNumber: 'DEMO-102',
                    linkedArticleName: 'Heavyweight Loopback Hoodie',
                  ),
          );

    final int upstreamPieces = selectedBuyer?.contractedVolume ??
        buyers.fold<int>(0, (sum, b) => sum + b.contractedVolume);

    // Matching Allocations
    final matchingAllocations = allocations.where((t) {
      if (selectedBuyer == null) return true;
      return t.buyerName.toLowerCase() == selectedBuyer.buyerName.toLowerCase() ||
          t.articleNumber.toUpperCase() == selectedBuyer.linkedArticleNumber.toUpperCase();
    }).toList();

    // Metric Calculations
    final completedIronPieces = matchingAllocations
        .where((t) => t.status == 'VERIFIED_COMPLETED' || t.status == 'COMPLETED')
        .fold<int>(0, (sum, curr) => sum + (curr.completedPieces > 0 ? curr.completedPieces : curr.piecesToPress));

    final pendingIronPieces = matchingAllocations
        .where((t) => t.status != 'VERIFIED_COMPLETED' && t.status != 'COMPLETED')
        .fold<int>(0, (sum, curr) => sum + curr.piecesToPress);

    final assignedOrCompletedIron = matchingAllocations.fold<int>(0, (sum, curr) => sum + curr.piecesToPress);
    final inHandPieces = (upstreamPieces - assignedOrCompletedIron).clamp(0, 999999);

    // Filtered Tasks for Matrix Table
    final filteredTasks = allocations.where((task) {
      if (selectedBuyer != null) {
        final matchesBuyer = task.buyerName.toLowerCase() == selectedBuyer.buyerName.toLowerCase() ||
            task.articleNumber.toUpperCase() == selectedBuyer.linkedArticleNumber.toUpperCase();
        if (!matchesBuyer) return false;
      }

      final query = _taskSearchCtrl.text.toLowerCase().trim();
      final matchesSearch = query.isEmpty ||
          task.taskRef.toLowerCase().contains(query) ||
          task.workerName.toLowerCase().contains(query) ||
          task.articleNumber.toLowerCase().contains(query) ||
          task.buyerName.toLowerCase().contains(query) ||
          task.machineTable.toLowerCase().contains(query);

      bool matchesStatus = true;
      if (ironState.statusFilter == 'ACTIVE') {
        matchesStatus = task.status != 'VERIFIED_COMPLETED';
      } else if (ironState.statusFilter == 'NEEDS_VERIFY') {
        matchesStatus = task.status == 'COMPLETED';
      } else if (ironState.statusFilter == 'COMPLETED') {
        matchesStatus = task.status == 'VERIFIED_COMPLETED';
      }

      return matchesSearch && matchesStatus;
    }).toList();

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFFAF7F0), // Canvas warm cream
      drawer: const WorkspaceHubDrawer(activeRoute: '/iron'),
      appBar: ZigzaAppBar(
        onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      body: RefreshIndicator(
        color: const Color(0xFF3A3564),
        onRefresh: () async {
          await ref.read(ironProvider.notifier).loadInitialData(isRefresh: true);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // a. Breadcrumb block
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
                                color: const Color(0xFF7A7488),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text('/', style: TextStyle(color: Color(0xFFE7E1D6), fontSize: 12)),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE5EDF9),
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(color: const Color(0xFF2E5AA8).withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              'Division 08 · Steam Finishing & Ironing',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF2E5AA8),
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
                'Ironing & Steam Pressing',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF232028),
                ),
              ),
              const SizedBox(height: 10),

              // b. Sync status pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F3EA),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: const Color(0xFF1F8A5A).withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6.5,
                      height: 6.5,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1F8A5A),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Boiler & Vacuum Sync Active',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1F8A5A),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // c. Module card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0x1A000000)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x08000000),
                      blurRadius: 4,
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
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAF7F0),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0x1A000000)),
                          ),
                          child: const Icon(
                            Icons.air_rounded,
                            color: Color(0xFF3A3564),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Steam Ironing Floor',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF232028),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFAF7F0),
                                      borderRadius: BorderRadius.circular(100),
                                      border: Border.all(color: const Color(0x1A000000)),
                                    ),
                                    child: Text(
                                      '${workers.length} Pressers Registered',
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF3A3564),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Industrial boiler telemetry (4.5 Bar steam), vacuum buck table allocation, thermal shine QC, and finished garment sign-offs.',
                                style: GoogleFonts.publicSans(
                                  fontSize: 12,
                                  color: const Color(0xFF7A7488),
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF3A3564),
                            side: const BorderSide(color: Color(0x1A000000)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.smart_toy_outlined, size: 15),
                          label: Text(
                            'Zigza AI',
                            style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const IronZigzaAiScreen()),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF3A3564),
                            side: const BorderSide(color: Color(0x1A000000)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.people_outline, size: 15),
                          label: Text(
                            'Division Profile',
                            style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const CompanyProfileScreen()),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // d. Selected Buyer Contract card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0x1A000000)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x08000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Row with Refresh Icon
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'SELECTED BUYER CONTRACT',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF7A7488),
                            letterSpacing: 0.5,
                          ),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            Icons.refresh_rounded,
                            color: const Color(0xFF3A3564),
                            size: 18,
                          ),
                          tooltip: 'Refresh cloud data',
                          onPressed: () {
                            ref.read(ironProvider.notifier).loadInitialData(isRefresh: true);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Buyer Name + Article Pill
                    Row(
                      children: [
                        Text(
                          selectedBuyer?.buyerName ?? 'No Active Buyer',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF232028),
                          ),
                        ),
                        if (selectedBuyer != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAF7F0),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0x1A000000)),
                            ),
                            child: Text(
                              'Article: ${selectedBuyer.linkedArticleNumber}',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF3A3564),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Buyer Dropdown Selector
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF7F0),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0x1A000000)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: ironState.selectedBuyerId,
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF7A7488)),
                          style: GoogleFonts.publicSans(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF232028),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'ALL',
                              child: Text('All Buyers (${allocations.length} Active Lots)'),
                            ),
                            ...buyers.map((b) {
                              return DropdownMenuItem(
                                value: b.id,
                                child: Text('${b.buyerName} (${b.contractedVolume} Pcs Contracted)'),
                              );
                            }),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              ref.read(ironProvider.notifier).selectBuyer(val);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Two buttons: View Worker List / + Add Worker
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF232028),
                              side: const BorderSide(color: Color(0x1A000000)),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.people_alt_outlined, size: 16, color: Color(0xFF3A3564)),
                            label: Text(
                              'View Worker List (${workers.length})',
                              style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (_) => const IronWorkerListModal(),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3A3564),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.person_add_alt_1_outlined, size: 16),
                            label: Text(
                              '+ Add Worker',
                              style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (_) => const AddIronWorkerModal(),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // e. Three stacked stat cards, full width, in this order
              // 1. IN HAND
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0x1A000000)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x08000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF7F0),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0x1A000000)),
                      ),
                      child: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF3A3564), size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'IN HAND',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF7A7488),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            inHandPieces.toString(),
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF232028),
                            ),
                          ),
                          Text(
                            inHandPieces > 0
                                ? '$inHandPieces pcs ready for vacuum pressing tables'
                                : '0 pcs in hand (All garments allocated to pressers)',
                            style: GoogleFonts.publicSans(
                              fontSize: 11.5,
                              color: const Color(0xFF7A7488),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // 2. PROCESSING / IN PROGRESS
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0x1A000000)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x08000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF7F0),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0x1A000000)),
                      ),
                      child: const Icon(Icons.access_time_rounded, color: Color(0xFF3A3564), size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PROCESSING / IN PROGRESS',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF7A7488),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            pendingIronPieces.toString(),
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF232028),
                            ),
                          ),
                          Text(
                            pendingIronPieces > 0
                                ? '$pendingIronPieces pcs running on vacuum buck tables'
                                : '0 pcs in active steam pressing',
                            style: GoogleFonts.publicSans(
                              fontSize: 11.5,
                              color: const Color(0xFF7A7488),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // 3. COMPLETE / VERIFIED
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0x1A000000)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x08000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF7F0),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0x1A000000)),
                      ),
                      child: const Icon(Icons.check_circle_outline, color: Color(0xFF3A3564), size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'COMPLETE / VERIFIED',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF7A7488),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            completedIronPieces.toString(),
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF232028),
                            ),
                          ),
                          Text(
                            completedIronPieces > 0
                                ? '$completedIronPieces pressed garments verified & transferred to packing'
                                : '0 pressed garments verified',
                            style: GoogleFonts.publicSans(
                              fontSize: 11.5,
                              color: const Color(0xFF7A7488),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // f. Steam Ironing Floor Task Allocation Matrix card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0x1A000000)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x08000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon + Title + Subtitle
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAF7F0),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0x1A000000)),
                          ),
                          child: const Icon(Icons.table_chart_outlined, color: Color(0xFF3A3564), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Steam Ironing Floor Task Allocation Matrix',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF232028),
                                ),
                              ),
                              Text(
                                'Distribute garment pressing quotas, assign vacuum buck tables, and set shift completion targets.',
                                style: GoogleFonts.publicSans(
                                  fontSize: 11.5,
                                  color: const Color(0xFF7A7488),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Search Input
                    TextField(
                      controller: _taskSearchCtrl,
                      onChanged: (_) => setState(() {}),
                      style: GoogleFonts.publicSans(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search presser, article, table…',
                        hintStyle: GoogleFonts.publicSans(color: const Color(0xFFA09BAA), fontSize: 12.5),
                        prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF7A7488)),
                        filled: true,
                        fillColor: const Color(0xFFFAF7F0).withValues(alpha: 0.5),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0x1A000000)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0x1A000000)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF3A3564), width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Segmented Filter Tabs
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAF7F0),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0x1A000000)),
                        ),
                        child: Row(
                          children: [
                            _buildFilterTab('ALL', 'All'),
                            const SizedBox(width: 4),
                            _buildFilterTab('ACTIVE', 'Active Queue'),
                            const SizedBox(width: 4),
                            _buildFilterTab('NEEDS_VERIFY', 'Needs Verification'),
                            const SizedBox(width: 4),
                            _buildFilterTab('COMPLETED', 'Verified & Done'),
                          ],
                        ),
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
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text(
                          '+ Add Task Row',
                          style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => AddIronTaskModal(
                              selectedBuyer: selectedBuyer,
                              inHandPieces: inHandPieces,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Table Container (with Horizontal Scroll)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0x1A000000)),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: filteredTasks.isEmpty
                            ? Container(
                                width: 700,
                                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                                child: Center(
                                  child: Column(
                                    children: [
                                      const Icon(Icons.air_rounded, size: 40, color: Color(0xFFA09BAA)),
                                      const SizedBox(height: 10),
                                      Text(
                                        'No tasks yet. Click \'+ Add Task Row\' to begin.',
                                        style: GoogleFonts.publicSans(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF7A7488),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : DataTable(
                                headingRowColor: WidgetStateProperty.all(const Color(0xFFFAF7F0)),
                                headingTextStyle: GoogleFonts.jetBrainsMono(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF7A7488),
                                ),
                                dataTextStyle: GoogleFonts.publicSans(
                                  fontSize: 12,
                                  color: const Color(0xFF232028),
                                ),
                                columns: const [
                                  DataColumn(label: Text('Task Ref')),
                                  DataColumn(label: Text('Buyer / Brand')),
                                  DataColumn(label: Text('Article No')),
                                  DataColumn(label: Text('Finishing Presser')),
                                  DataColumn(label: Text('Vacuum Table')),
                                  DataColumn(label: Text('Target Pcs'), numeric: true),
                                  DataColumn(label: Text('Completed Pcs'), numeric: true),
                                  DataColumn(label: Text('Soleplate Temp')),
                                  DataColumn(label: Text('Status')),
                                  DataColumn(label: Text('Actions')),
                                ],
                                rows: filteredTasks.map((task) {
                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        Text(
                                          '#${task.taskRef}',
                                          style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold),
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
                                            if (task.workerPhone != null && task.workerPhone!.isNotEmpty)
                                              Text(
                                                '+91 ${task.workerPhone}',
                                                style: GoogleFonts.jetBrainsMono(fontSize: 10, color: const Color(0xFF7A7488)),
                                              ),
                                          ],
                                        ),
                                      ),
                                      DataCell(Text(task.machineTable)),
                                      DataCell(
                                        Text(
                                          task.piecesToPress.toString(),
                                          style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          task.completedPieces.toString(),
                                          style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, color: const Color(0xFF1F8A5A)),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          '${task.ironTempC}°C',
                                          style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                      DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                          decoration: BoxDecoration(
                                            color: task.status == 'VERIFIED_COMPLETED'
                                                ? const Color(0xFFE3F3EA)
                                                : task.status == 'COMPLETED'
                                                    ? const Color(0xFFE5EDF9)
                                                    : const Color(0xFFFEF3C7),
                                            borderRadius: BorderRadius.circular(100),
                                          ),
                                          child: Text(
                                            task.status.replaceAll('_', ' '),
                                            style: GoogleFonts.jetBrainsMono(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.bold,
                                              color: task.status == 'VERIFIED_COMPLETED'
                                                  ? const Color(0xFF1F8A5A)
                                                  : task.status == 'COMPLETED'
                                                      ? const Color(0xFF2E5AA8)
                                                      : const Color(0xFFB45309),
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (task.status == 'COMPLETED')
                                              IconButton(
                                                icon: const Icon(Icons.check_circle, color: Color(0xFF1F8A5A), size: 20),
                                                tooltip: 'Verify & Done',
                                                onPressed: () => _handleVerifyAndDone(task),
                                              ),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, color: Color(0xFFE11D48), size: 18),
                                              tooltip: 'Delete Task',
                                              onPressed: () => _confirmDeleteTask(task),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterTab(String filterKey, String label) {
    final ironState = ref.watch(ironProvider);
    final isSelected = ironState.statusFilter == filterKey;

    return InkWell(
      onTap: () {
        ref.read(ironProvider.notifier).setStatusFilter(filterKey);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3A3564) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : const Color(0xFF7A7488),
          ),
        ),
      ),
    );
  }
}
