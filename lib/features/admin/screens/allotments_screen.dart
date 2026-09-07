import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_allotment_card.dart';
import '../widgets/admin_create_allotment_modal.dart';
import 'admin_shell.dart';

class AllotmentsScreen extends ConsumerStatefulWidget {
  const AllotmentsScreen({super.key});

  @override
  ConsumerState<AllotmentsScreen> createState() => _AllotmentsScreenState();
}

class _AllotmentsScreenState extends ConsumerState<AllotmentsScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final List<String> _statuses = ['ALL', 'IN_PROGRESS', 'COMPLETED', 'PENDING'];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showNewAllotmentDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AdminCreateAllotmentModal(
        onSuccess: () {
          ref.invalidate(adminAllotmentsListProvider);
          ref.invalidate(adminDashboardProvider);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allotmentsAsync = ref.watch(adminAllotmentsListProvider);
    final filter = ref.watch(allotmentFilterProvider);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.card,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: AppTheme.ink),
          tooltip: 'Menu',
          onPressed: () => adminScaffoldKey.currentState?.openDrawer(),
        ),
        title: Text(
          'Target Allotments',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.ink,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.steel),
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(adminAllotmentsListProvider);
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // 1. TOP HEADER BANNER (Matching Web Admin Image 2)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: const BoxDecoration(
              color: AppTheme.card,
              border: Border(bottom: BorderSide(color: AppTheme.border, width: 1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Active Allotments & Handover',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tracking size ratios & raw materials issued to lines',
                            style: GoogleFonts.publicSans(
                              fontSize: 11,
                              color: AppTheme.inkSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Assign Target Button
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E234D), // Web Admin dark purple CTA
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      onPressed: _showNewAllotmentDialog,
                      icon: const Icon(Icons.check, size: 16),
                      label: Text(
                        'Assign Target',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Live Sync & Allotment Count Badges
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8FDF2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFA6F4C5)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF12B76A),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Live Sync',
                            style: GoogleFonts.publicSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF027A48),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    allotmentsAsync.maybeWhen(
                      data: (list) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.bg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Text(
                          '${list.length} Allotments',
                          style: GoogleFonts.publicSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.inkSoft,
                          ),
                        ),
                      ),
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Search Bar
                TextField(
                  controller: _searchCtrl,
                  onChanged: (val) {
                    ref.read(allotmentFilterProvider.notifier).state = filter.copyWith(searchQuery: val);
                  },
                  decoration: InputDecoration(
                    hintText: 'Search by article, lineman, or date...',
                    prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.inkFaint),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              ref.read(allotmentFilterProvider.notifier).state = filter.copyWith(searchQuery: '');
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
                const SizedBox(height: 10),

                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _statuses.map((st) {
                      final isSelected = filter.selectedStatus == st;
                      final label = st == 'ALL'
                          ? 'All'
                          : (st == 'IN_PROGRESS'
                              ? 'In Progress'
                              : (st == 'COMPLETED' ? 'Completed' : 'Pending'));

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(label),
                          selected: isSelected,
                          selectedColor: const Color(0xFF2E234D),
                          backgroundColor: AppTheme.bg,
                          labelStyle: GoogleFonts.publicSans(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? Colors.white : AppTheme.inkSoft,
                          ),
                          onSelected: (_) {
                            ref.read(allotmentFilterProvider.notifier).state = filter.copyWith(selectedStatus: st);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // 2. ALLOTMENTS LIST
          Expanded(
            child: RefreshIndicator(
              color: AppTheme.steel,
              onRefresh: () async {
                ref.invalidate(adminAllotmentsListProvider);
              },
              child: allotmentsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppTheme.steel),
                ),
                error: (err, stack) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 40, color: AppTheme.red),
                        const SizedBox(height: 10),
                        Text('Error loading allotments: ${err.toString()}', textAlign: TextAlign.center, style: GoogleFonts.publicSans(color: AppTheme.inkSoft)),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () => ref.invalidate(adminAllotmentsListProvider),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (allotments) {
                  if (allotments.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.assignment_late_outlined, size: 48, color: AppTheme.inkFaint),
                            const SizedBox(height: 12),
                            Text(
                              'No Allotments Found',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tap "Assign Target" to create a new allotment.',
                              style: GoogleFonts.publicSans(fontSize: 12, color: AppTheme.inkSoft),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: allotments.length,
                    itemBuilder: (ctx, index) {
                      final allotment = allotments[index];
                      return AdminAllotmentCard(allotment: allotment);
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF2E234D),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_task_rounded),
        label: Text('New Allotment', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
        onPressed: _showNewAllotmentDialog,
      ),
    );
  }
}
