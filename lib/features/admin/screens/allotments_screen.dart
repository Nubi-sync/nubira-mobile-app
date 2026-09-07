import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../main.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_allotment_card.dart';
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

  void _showNewAllotmentDialog() async {
    // Fetch active challans, linemen, and articles
    final challansRes = await supabase.from('challans').select('id, challan_no, brand').limit(50);
    final linemenRes = await supabase.from('profiles').select('id, username').eq('is_active', true);
    final articlesRes = await supabase.from('articles').select('id, art_no, description').eq('is_active', true);

    final challans = (challansRes as List?) ?? [];
    final linemen = (linemenRes as List?) ?? [];
    final articles = (articlesRes as List?) ?? [];

    if (challans.isEmpty || linemen.isEmpty || articles.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please ensure Challans, Linemen, and Articles are created first.')),
        );
      }
      return;
    }

    String selectedChallanId = challans.first['id'].toString();
    String selectedLinemanId = linemen.first['id'].toString();
    String selectedArticleId = articles.first['id'].toString();
    final targetQtyCtrl = TextEditingController(text: '100');

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'New Target Allotment',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: AppTheme.ink),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedChallanId,
                  decoration: const InputDecoration(labelText: 'Select Challan'),
                  items: challans
                      .map((c) => DropdownMenuItem(
                            value: c['id'].toString(),
                            child: Text('${c['challan_no']} (${c['brand']})'),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedChallanId = val);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedLinemanId,
                  decoration: const InputDecoration(labelText: 'Assign Lineman'),
                  items: linemen
                      .map((l) => DropdownMenuItem(
                            value: l['id'].toString(),
                            child: Text(l['username'].toString()),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedLinemanId = val);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedArticleId,
                  decoration: const InputDecoration(labelText: 'Select Article'),
                  items: articles
                      .map((a) => DropdownMenuItem(
                            value: a['id'].toString(),
                            child: Text('${a['art_no']} - ${a['description'] ?? ''}'),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedArticleId = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: targetQtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Target Quantity (Pcs) *'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.steel,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final qty = int.tryParse(targetQtyCtrl.text.trim()) ?? 0;
                if (qty <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please provide a valid Target Quantity.')),
                  );
                  return;
                }

                try {
                  await supabase.from('allotments').insert({
                    'challan_id': selectedChallanId,
                    'lineman_id': selectedLinemanId,
                    'article_id': selectedArticleId,
                    'target_qty': qty,
                    'status': 'PENDING',
                    'allotment_date': DateTime.now().toIso8601String().substring(0, 10),
                  });

                  if (mounted) {
                    Navigator.pop(ctx);
                    ref.invalidate(adminAllotmentsListProvider);
                    ref.invalidate(adminDashboardProvider);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: AppTheme.green,
                        content: Text('Allotment assigned successfully!'),
                      ),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${e.toString()}')),
                  );
                }
              },
              child: const Text('Assign Allotment'),
            ),
          ],
        ),
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
