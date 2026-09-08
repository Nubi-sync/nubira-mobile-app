import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../models/admin_models.dart';
import '../providers/admin_providers.dart';
import 'allotment_form_state.dart';
import 'allotment_step1_screen.dart';
import 'widgets/allotment_card_widget.dart';

class AllotmentsListScreen extends ConsumerStatefulWidget {
  const AllotmentsListScreen({super.key});

  @override
  ConsumerState<AllotmentsListScreen> createState() => _AllotmentsListScreenState();
}

class _AllotmentsListScreenState extends ConsumerState<AllotmentsListScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAllotmentDetails(AdminAllotment allotment) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title & Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Art #${allotment.articleNo ?? "N/A"}',
                        style: const TextStyle(
                          color: AppTheme.ink,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (allotment.articleDescription != null && allotment.articleDescription!.isNotEmpty)
                        Text(
                          allotment.articleDescription!,
                          style: const TextStyle(color: AppTheme.inkSoft, fontSize: 13),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: allotment.status == 'COMPLETED'
                        ? AppTheme.greenMist
                        : (allotment.status == 'CANCELLED' ? AppTheme.redMist : AppTheme.amberMist),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    allotment.status,
                    style: TextStyle(
                      color: allotment.status == 'COMPLETED'
                          ? AppTheme.green
                          : (allotment.status == 'CANCELLED' ? AppTheme.red : AppTheme.amber),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Metadata Grid
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                children: [
                  _buildDetailRow('Lineman', allotment.linemanName ?? 'N/A'),
                  const Divider(height: 14, color: AppTheme.border),
                  _buildDetailRow('Allotment Date', allotment.allotmentDate ?? 'N/A'),
                  const Divider(height: 14, color: AppTheme.border),
                  _buildDetailRow('Target Pieces', '${allotment.targetQty} pcs'),
                  const Divider(height: 14, color: AppTheme.border),
                  _buildDetailRow('Completed Pieces', '${allotment.achievedQty} pcs'),
                  if (allotment.brand != null) ...[
                    const Divider(height: 14, color: AppTheme.border),
                    _buildDetailRow('Brand', allotment.brand!),
                  ],
                  if (allotment.challanNo != null) ...[
                    const Divider(height: 14, color: AppTheme.border),
                    _buildDetailRow('Challan Ref', allotment.challanNo!),
                  ],
                  if (allotment.priority.isNotEmpty) ...[
                    const Divider(height: 14, color: AppTheme.border),
                    _buildDetailRow('Priority', allotment.priority),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Variants Breakdown
            if (allotment.variants.isNotEmpty) ...[
              const Text(
                'Size & Color Variants Matrix',
                style: TextStyle(color: AppTheme.ink, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  children: allotment.variants.map((v) {
                    return ListTile(
                      dense: true,
                      title: Text(
                        '${v.color} • Size ${v.size}',
                        style: const TextStyle(color: AppTheme.ink, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      trailing: Text(
                        '${v.completedQty} / ${v.quantity} pcs',
                        style: const TextStyle(color: AppTheme.steel, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Materials Checklist
            if (allotment.materials.isNotEmpty) ...[
              const Text(
                'Raw Materials Issue Checklist (BOM)',
                style: TextStyle(color: AppTheme.ink, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  children: allotment.materials.map((m) {
                    final isIssued = m['admin_issued'] == true;
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        isIssued ? Icons.check_circle : Icons.circle_outlined,
                        color: isIssued ? AppTheme.green : AppTheme.inkFaint,
                        size: 18,
                      ),
                      title: Text(
                        m['item_name']?.toString() ?? 'Item',
                        style: const TextStyle(color: AppTheme.ink, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        'Required: ${m['required_qty'] ?? "As required"}',
                        style: const TextStyle(color: AppTheme.inkSoft, fontSize: 11),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Close button
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.steel,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.inkSoft, fontSize: 12)),
        Text(value, style: const TextStyle(color: AppTheme.ink, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  void _confirmDelete(AdminAllotment allotment) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Allotment', style: TextStyle(color: AppTheme.ink, fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to delete the allotment for Art #${allotment.articleNo ?? ""} assigned to ${allotment.linemanName ?? "Lineman"}? This action cannot be undone.',
          style: const TextStyle(color: AppTheme.inkSoft),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.inkSoft)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await deleteAllotmentInSupabase(allotment.id);
              if (success) {
                ref.invalidate(adminAllotmentsListProvider);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Allotment deleted successfully.')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(allotmentFilterProvider);
    final allotmentsAsync = ref.watch(adminAllotmentsListProvider);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Target Allotments'),
        backgroundColor: AppTheme.card,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.ink),
            onPressed: () => ref.invalidate(adminAllotmentsListProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by article, lineman, challan, brand...',
                prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.inkSoft),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18, color: AppTheme.inkSoft),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(allotmentFilterProvider.notifier).state =
                              filter.copyWith(searchQuery: '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.card,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              onChanged: (val) {
                ref.read(allotmentFilterProvider.notifier).state =
                    filter.copyWith(searchQuery: val.trim());
              },
            ),
          ),

          // 2. Status Filter Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                _buildStatusFilterChip('ALL', 'All Allotments', filter.selectedStatus == 'ALL'),
                const SizedBox(width: 8),
                _buildStatusFilterChip('IN_PROGRESS', 'In Progress', filter.selectedStatus == 'IN_PROGRESS'),
                const SizedBox(width: 8),
                _buildStatusFilterChip('COMPLETED', 'Completed', filter.selectedStatus == 'COMPLETED'),
                const SizedBox(width: 8),
                _buildStatusFilterChip('CANCELLED', 'Cancelled', filter.selectedStatus == 'CANCELLED'),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // 3. Allotment List
          Expanded(
            child: allotmentsAsync.when(
              data: (allotments) {
                if (allotments.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: AppTheme.steelMist,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.assignment_outlined, size: 32, color: AppTheme.steel),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No allotments found',
                            style: TextStyle(color: AppTheme.ink, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Create a new target allotment to assign cut-to-sew pieces to floor linemen.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.inkSoft, fontSize: 13),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: () {
                              ref.read(allotmentFormProvider.notifier).reset();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AllotmentStep1Screen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.add, color: Colors.white, size: 18),
                            label: const Text('Create First Allotment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.steel),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  color: AppTheme.steel,
                  onRefresh: () async {
                    ref.invalidate(adminAllotmentsListProvider);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 6, bottom: 80),
                    itemCount: allotments.length,
                    itemBuilder: (context, index) {
                      final item = allotments[index];
                      return AllotmentCardWidget(
                        allotment: item,
                        onTap: () => _showAllotmentDetails(item),
                        onStatusChange: (newStatus) async {
                          final ok = await updateAllotmentStatusInSupabase(item.id, newStatus);
                          if (ok) {
                            ref.invalidate(adminAllotmentsListProvider);
                          }
                        },
                        onDelete: () => _confirmDelete(item),
                      );
                    },
                  ),
                );
              },
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
                      const SizedBox(height: 12),
                      Text(
                        'Failed to load allotments\n$err',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.ink, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(adminAllotmentsListProvider),
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.steel),
                        child: const Text('Retry', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.steel,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Allotment', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () {
          ref.read(allotmentFormProvider.notifier).reset();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AllotmentStep1Screen(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusFilterChip(String key, String label, bool isSelected) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppTheme.steel,
      backgroundColor: AppTheme.card,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppTheme.inkSoft,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      side: BorderSide(color: isSelected ? AppTheme.steel : AppTheme.border),
      onSelected: (selected) {
        if (selected) {
          ref.read(allotmentFilterProvider.notifier).state =
              ref.read(allotmentFilterProvider).copyWith(selectedStatus: key);
        }
      },
    );
  }
}
