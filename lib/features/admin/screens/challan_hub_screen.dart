import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../main.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_challan_card.dart';
import '../widgets/admin_excel_import_modal.dart';
import 'admin_shell.dart';

class ChallanHubScreen extends ConsumerStatefulWidget {
  const ChallanHubScreen({super.key});

  @override
  ConsumerState<ChallanHubScreen> createState() => _ChallanHubScreenState();
}

class _ChallanHubScreenState extends ConsumerState<ChallanHubScreen> {
  final TextEditingController _searchController = TextEditingController();

  final List<String> _brands = ['ALL', 'OLLYPOP', 'FIRST SMILE', 'GALAXY'];
  final List<String> _statuses = ['ALL', 'PENDING', 'IN_PROGRESS', 'COMPLETED'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showNewChallanDialog() {
    final challanNoCtrl = TextEditingController();
    final fabricCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String selectedBrand = 'OLLYPOP';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'New Delivery Challan',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: AppTheme.ink),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: challanNoCtrl,
                  decoration: const InputDecoration(labelText: 'Challan Number *', hintText: 'e.g. 9437'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedBrand,
                  decoration: const InputDecoration(labelText: 'Brand / Buyer'),
                  items: ['OLLYPOP', 'FIRST SMILE', 'GALAXY']
                      .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedBrand = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: fabricCtrl,
                  decoration: const InputDecoration(labelText: 'Fabric Type', hintText: 'e.g. Cotton Sinker'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: qtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Total Quantity (Pcs) *', hintText: 'e.g. 1200'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Description / Remarks', hintText: 'e.g. Art 9437 Lot 12'),
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
                final chNo = challanNoCtrl.text.trim();
                final qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
                if (chNo.isEmpty || qty <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please provide valid Challan No and Quantity')),
                  );
                  return;
                }

                try {
                  await supabase.from('challans').insert({
                    'challan_no': chNo,
                    'brand': selectedBrand,
                    'fabric_type': fabricCtrl.text.trim().isEmpty ? null : fabricCtrl.text.trim(),
                    'total_qty': qty,
                    'description': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                    'status': 'PENDING',
                  });

                  if (mounted) {
                    Navigator.pop(ctx);
                    ref.invalidate(adminChallansListProvider);
                    ref.invalidate(adminDashboardProvider);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: AppTheme.green,
                        content: Text('Challan created successfully!'),
                      ),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${e.toString()}')),
                  );
                }
              },
              child: const Text('Create Challan'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final challansAsync = ref.watch(adminChallansListProvider);
    final filter = ref.watch(challanFilterProvider);

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
          'Challan Hub',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.ink,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file_rounded, color: AppTheme.steel),
            tooltip: 'Bulk Excel Import',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => AdminExcelImportModal(
                  onImportSuccess: () {
                    ref.invalidate(adminChallansListProvider);
                    ref.invalidate(adminDashboardProvider);
                  },
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.steel),
            tooltip: 'New Challan',
            onPressed: _showNewChallanDialog,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Search & Filters Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppTheme.card,
              border: Border(bottom: BorderSide(color: AppTheme.border, width: 1)),
            ),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    ref.read(challanFilterProvider.notifier).state = filter.copyWith(searchQuery: val);
                  },
                  decoration: InputDecoration(
                    hintText: 'Search by Challan #, Art, Fabric...',
                    prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.inkFaint),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              ref.read(challanFilterProvider.notifier).state = filter.copyWith(searchQuery: '');
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),

                const SizedBox(height: 10),

                // Brand Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _brands.map((brand) {
                      final isSelected = filter.selectedBrand == brand;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(brand),
                          selected: isSelected,
                          selectedColor: AppTheme.steelMist,
                          checkmarkColor: AppTheme.steel,
                          labelStyle: GoogleFonts.publicSans(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? AppTheme.steel : AppTheme.inkSoft,
                          ),
                          onSelected: (selected) {
                            ref.read(challanFilterProvider.notifier).state = filter.copyWith(selectedBrand: brand);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Challan List
          Expanded(
            child: RefreshIndicator(
              color: AppTheme.steel,
              onRefresh: () async {
                ref.invalidate(adminChallansListProvider);
              },
              child: challansAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppTheme.steel),
                ),
                error: (err, stack) => Center(
                  child: Text('Error: ${err.toString()}'),
                ),
                data: (challans) {
                  if (challans.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.layers_clear_outlined, size: 48, color: AppTheme.inkFaint),
                            const SizedBox(height: 12),
                            Text(
                              'No Challans Found',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.ink,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Upload Excel sheets or click + to add manually.',
                              style: GoogleFonts.publicSans(fontSize: 12, color: AppTheme.inkSoft),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: challans.length,
                    itemBuilder: (ctx, index) {
                      final challan = challans[index];
                      return AdminChallanCard(
                        challan: challan,
                        onTap: () {},
                      );
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
