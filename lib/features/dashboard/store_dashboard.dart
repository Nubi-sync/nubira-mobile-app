import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/providers/auth_provider.dart';
import '../auth/screens/login_screen.dart';
import '../../core/theme/app_theme.dart';
import '../../../main.dart'; // supabase client

class StoreDashboard extends ConsumerStatefulWidget {
  const StoreDashboard({super.key});

  @override
  ConsumerState<StoreDashboard> createState() => _StoreDashboardState();
}

class _StoreDashboardState extends ConsumerState<StoreDashboard> {
  bool _isLoading = true;
  List<dynamic> _pendingStoreInward = [];

  @override
  void initState() {
    super.initState();
    _fetchPendingInward();
  }

  Future<void> _fetchPendingInward() async {
    setState(() => _isLoading = true);
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];

      // 1. Fetch total passed from QC today
      final qcRes = await supabase
          .from('qc_logs')
          .select('''
            article_id,
            qty_passed,
            articles ( art_no, description )
          ''')
          .eq('stage', 'CHECKING')
          .eq('entry_date', today);

      // 2. Fetch total inwarded to store today
      final storeRes = await supabase
          .from('store_transactions')
          .select('article_id, quantity')
          .eq('type', 'INWARD')
          .eq('entry_date', today);

      // Aggregate QC passed
      final Map<String, dynamic> aggregated = {};
      for (var row in qcRes) {
        final articleId = row['article_id'];
        if (!aggregated.containsKey(articleId)) {
          aggregated[articleId] = {
            'article_id': articleId,
            'art_no': row['articles']['art_no'],
            'description': row['articles']['description'],
            'total_passed': 0,
            'total_inwarded': 0,
          };
        }
        aggregated[articleId]['total_passed'] += (row['qty_passed'] as int);
      }

      // Aggregate Store inwarded
      for (var row in storeRes) {
        final articleId = row['article_id'];
        if (aggregated.containsKey(articleId)) {
          aggregated[articleId]['total_inwarded'] += (row['quantity'] as int);
        }
      }

      // Filter only those with pending items to inward
      final pendingList = aggregated.values
          .where((item) => (item['total_passed'] - item['total_inwarded']) > 0)
          .toList();

      setState(() {
        _pendingStoreInward = pendingList;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showInwardDialog(dynamic item) {
    final pendingQty = item['total_passed'] - item['total_inwarded'];
    final qtyController = TextEditingController(text: pendingQty.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Inward to Store - ${item['art_no']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pending to Inward: $pendingQty pieces'),
            const SizedBox(height: 16),
            TextField(
              controller: qtyController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Received Quantity',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final qty = int.tryParse(qtyController.text) ?? 0;

              if (qty <= 0 || qty > pendingQty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('Quantity must be between 1 and $pendingQty')),
                );
                return;
              }
              Navigator.pop(ctx);
              await _submitStoreInward(item, qty);
            },
            child: const Text('Save Inward'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitStoreInward(dynamic item, int qty) async {
    try {
      await supabase.from('store_transactions').insert({
        'article_id': item['article_id'],
        'type': 'INWARD',
        'quantity': qty,
        'entry_date': DateTime.now().toIso8601String().split('T')[0],
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Store Inward saved successfully!'), backgroundColor: Colors.green),
        );
        _fetchPendingInward(); // Refresh the list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Store Receiving'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchPendingInward,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pendingStoreInward.isEmpty
              ? const Center(child: Text('No pending items from QC today.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _pendingStoreInward.length,
                  itemBuilder: (context, index) {
                    final item = _pendingStoreInward[index];
                    final pendingQty = item['total_passed'] - item['total_inwarded'];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Art No: ${item['art_no']}',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'Pending: $pendingQty',
                                    style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.w600),
                                  ),
                                )
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('${item['description'] ?? ''}', style: TextStyle(color: Colors.grey.shade700)),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () => _showInwardDialog(item),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryBlue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: const Text('Receive to Store'),
                              ),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
