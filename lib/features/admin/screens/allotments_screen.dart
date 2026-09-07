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
  final List<String> _statuses = ['ALL', 'PENDING', 'IN_PROGRESS', 'COMPLETED'];

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
            icon: const Icon(Icons.add_task_rounded, color: AppTheme.steel),
            tooltip: 'New Allotment',
            onPressed: _showNewAllotmentDialog,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppTheme.card,
              border: Border(bottom: BorderSide(color: AppTheme.border, width: 1)),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  onChanged: (val) {
                    ref.read(allotmentFilterProvider.notifier).state = filter.copyWith(searchQuery: val);
                  },
                  decoration: InputDecoration(
                    hintText: 'Search by Lineman, Art #, Challan...',
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
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _statuses.map((st) {
                      final isSelected = filter.selectedStatus == st;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(st),
                          selected: isSelected,
                          selectedColor: AppTheme.steelMist,
                          checkmarkColor: AppTheme.steel,
                          labelStyle: GoogleFonts.publicSans(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? AppTheme.steel : AppTheme.inkSoft,
                          ),
                          onSelected: (selected) {
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

          // List
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
                  child: Text('Error: ${err.toString()}'),
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
    );
  }
}
