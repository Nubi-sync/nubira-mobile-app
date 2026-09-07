import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../main.dart';
import '../providers/admin_providers.dart';
import 'admin_shell.dart';

class DispatchScreen extends ConsumerStatefulWidget {
  const DispatchScreen({super.key});

  @override
  ConsumerState<DispatchScreen> createState() => _DispatchScreenState();
}

class _DispatchScreenState extends ConsumerState<DispatchScreen> {
  void _showNewDispatchDialog() {
    final challanNoCtrl = TextEditingController();
    final buyerCtrl = TextEditingController();
    final totalPcsCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Create Delivery Challan',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: AppTheme.ink),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: challanNoCtrl,
              decoration: const InputDecoration(labelText: 'Delivery Challan # *', hintText: 'e.g. DC-8801'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: buyerCtrl,
              decoration: const InputDecoration(labelText: 'Buyer / Consignee Name *', hintText: 'e.g. Ollypop Retail Hub'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: totalPcsCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Total Pieces *', hintText: 'e.g. 500'),
            ),
          ],
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
              final buyer = buyerCtrl.text.trim();
              final pcs = int.tryParse(totalPcsCtrl.text.trim()) ?? 0;

              if (chNo.isEmpty || buyer.isEmpty || pcs <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill all fields with valid numbers.')),
                );
                return;
              }

              try {
                await supabase.from('delivery_challans').insert({
                  'challan_no': chNo,
                  'buyer_name': buyer,
                  'total_pieces': pcs,
                  'status': 'PENDING',
                });

                if (mounted) {
                  Navigator.pop(ctx);
                  ref.invalidate(adminDispatchListProvider);
                  ref.invalidate(adminDashboardProvider);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: AppTheme.green,
                      content: Text('Delivery Challan created successfully!'),
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: ${e.toString()}')),
                );
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dispatchAsync = ref.watch(adminDispatchListProvider);

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
          'Dispatch & Delivery',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.ink,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box_outlined, color: AppTheme.steel),
            tooltip: 'New Delivery Challan',
            onPressed: _showNewDispatchDialog,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.steel,
        onRefresh: () async {
          ref.invalidate(adminDispatchListProvider);
        },
        child: dispatchAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.steel),
          ),
          error: (err, stack) => Center(
            child: Text('Error: ${err.toString()}'),
          ),
          data: (dispatches) {
            if (dispatches.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.local_shipping_outlined, size: 48, color: AppTheme.inkFaint),
                      const SizedBox(height: 12),
                      Text(
                        'No Delivery Challans Found',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Create outbound delivery challans to track dispatch cartons.',
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
              itemCount: dispatches.length,
              itemBuilder: (ctx, index) {
                final d = dispatches[index];
                final isDispatched = d.status == 'DISPATCHED';

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            d.challanNo,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.ink,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDispatched ? AppTheme.greenMist : AppTheme.amberMist,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              d.status,
                              style: GoogleFonts.publicSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDispatched ? AppTheme.green : AppTheme.amber,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            d.buyerName ?? 'Direct Consignee',
                            style: GoogleFonts.publicSans(fontSize: 13, color: AppTheme.inkSoft),
                          ),
                          Text(
                            '${d.totalPieces} Pcs',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.steel,
                            ),
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
