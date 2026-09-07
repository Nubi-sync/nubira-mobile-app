import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../main.dart';
import '../providers/admin_providers.dart';
import 'admin_shell.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  void _showNewGrnDialog() async {
    final partyCtrl = TextEditingController();
    final challanCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final colorCtrl = TextEditingController();
    final sizeCtrl = TextEditingController();
    String type = 'INWARD';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'New Truck Inward (GRN)',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: AppTheme.ink),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Entry Type'),
                  items: const [
                    DropdownMenuItem(value: 'INWARD', child: Text('Truck Inward (GRN)')),
                    DropdownMenuItem(value: 'OUTWARD', child: Text('Material Outward')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => type = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: challanCtrl,
                  decoration: const InputDecoration(labelText: 'Challan Number / Lot #', hintText: 'e.g. 9437'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: partyCtrl,
                  decoration: const InputDecoration(labelText: 'Party / Mill Name', hintText: 'e.g. Vardhman Mills'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: qtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Quantity (Meters / Pcs) *'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: colorCtrl,
                        decoration: const InputDecoration(labelText: 'Color / Shade'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: sizeCtrl,
                        decoration: const InputDecoration(labelText: 'Size / Width'),
                      ),
                    ),
                  ],
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
                final qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
                if (qty <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid quantity.')),
                  );
                  return;
                }

                try {
                  await supabase.from('store_transactions').insert({
                    'type': type,
                    'quantity': qty,
                    'party_name': partyCtrl.text.trim().isEmpty ? null : partyCtrl.text.trim(),
                    'challan_no': challanCtrl.text.trim().isEmpty ? null : challanCtrl.text.trim(),
                    'color': colorCtrl.text.trim().isEmpty ? null : colorCtrl.text.trim(),
                    'size': sizeCtrl.text.trim().isEmpty ? null : sizeCtrl.text.trim(),
                    'entry_date': DateTime.now().toIso8601String().substring(0, 10),
                  });

                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  ref.invalidate(adminInventoryListProvider);
                  ref.invalidate(adminDashboardProvider);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: AppTheme.green,
                      content: Text('Inventory entry saved successfully!'),
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${e.toString()}')),
                  );
                }
              },
              child: const Text('Save Entry'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inventoryAsync = ref.watch(adminInventoryListProvider);

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
          'Godown & Inventory',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.ink,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_shopping_cart, color: AppTheme.steel),
            tooltip: 'Truck Inward',
            onPressed: _showNewGrnDialog,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.steel,
        onRefresh: () async {
          ref.invalidate(adminInventoryListProvider);
        },
        child: inventoryAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.steel),
          ),
          error: (err, stack) => Center(
            child: Text('Error: ${err.toString()}'),
          ),
          data: (entries) {
            if (entries.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.warehouse_outlined, size: 48, color: AppTheme.inkFaint),
                      const SizedBox(height: 12),
                      Text(
                        'No Inventory Entries',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tap + to log truck inwards (GRN) or material outward.',
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
              itemCount: entries.length,
              itemBuilder: (ctx, index) {
                final entry = entries[index];
                final isInward = entry.type == 'INWARD';

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isInward ? AppTheme.greenMist : AppTheme.amberMist,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isInward ? Icons.arrow_downward : Icons.arrow_upward,
                              color: isInward ? AppTheme.green : AppTheme.amber,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.partyName ?? (entry.challanNo != null ? 'Challan #${entry.challanNo}' : 'Store Entry'),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${entry.type} ${entry.color != null ? '• ${entry.color}' : ''}',
                                style: GoogleFonts.publicSans(fontSize: 12, color: AppTheme.inkSoft),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${isInward ? '+' : '-'}${entry.quantity}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: isInward ? AppTheme.green : AppTheme.amber,
                            ),
                          ),
                          Text(
                            entry.entryDate ?? '',
                            style: GoogleFonts.publicSans(fontSize: 11, color: AppTheme.inkFaint),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
