import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/providers/auth_provider.dart';
import '../auth/screens/login_screen.dart';
import '../../core/theme/app_theme.dart';
import '../../../main.dart'; // supabase client

class QcDashboard extends ConsumerStatefulWidget {
  const QcDashboard({super.key});

  @override
  ConsumerState<QcDashboard> createState() => _QcDashboardState();
}

class _QcDashboardState extends ConsumerState<QcDashboard> {
  bool _isLoading = true;
  List<dynamic> _pendingProduction = [];

  @override
  void initState() {
    super.initState();
    _fetchPendingProduction();
  }

  Future<void> _fetchPendingProduction() async {
    setState(() => _isLoading = true);
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];

      // 1. Fetch total produced by each lineman for each article today
      final producedRes = await supabase
          .from('daily_product')
          .select('''
            lineman_id,
            article_id,
            quantity,
            profiles!daily_product_lineman_id_fkey ( username ),
            articles ( art_no, description )
          ''')
          .eq('entry_date', today);

      // 2. Fetch total already checked in qc_logs for today
      final checkedRes = await supabase
          .from('qc_logs')
          .select('from_lineman_id, article_id, qty_passed, qty_rejected')
          .eq('stage', 'CHECKING')
          .eq('entry_date', today);

      // Aggregate produced
      final Map<String, dynamic> aggregated = {};
      for (var row in producedRes) {
        final key = '${row['lineman_id']}_${row['article_id']}';
        if (!aggregated.containsKey(key)) {
          aggregated[key] = {
            'lineman_id': row['lineman_id'],
            'article_id': row['article_id'],
            'username': row['profiles']['username'],
            'art_no': row['articles']['art_no'],
            'description': row['articles']['description'],
            'total_produced': 0,
            'total_checked': 0,
          };
        }
        aggregated[key]['total_produced'] += (row['quantity'] as int);
      }

      // Aggregate checked
      for (var row in checkedRes) {
        final key = '${row['from_lineman_id']}_${row['article_id']}';
        if (aggregated.containsKey(key)) {
          final passed = row['qty_passed'] ?? 0;
          final rejected = row['qty_rejected'] ?? 0;
          aggregated[key]['total_checked'] += (passed + rejected) as int;
        }
      }

      // Filter only those with pending items to check
      final pendingList = aggregated.values
          .where((item) => (item['total_produced'] - item['total_checked']) > 0)
          .toList();

      setState(() {
        _pendingProduction = pendingList;
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

  void _showQcDialog(dynamic item) {
    final pendingQty = item['total_produced'] - item['total_checked'];
    final passedController = TextEditingController(text: pendingQty.toString());
    final rejectedController = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('QC Check - ${item['art_no']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Lineman: ${item['username']}'),
            Text('Pending to check: $pendingQty pieces'),
            const SizedBox(height: 16),
            TextField(
              controller: passedController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Passed Quantity (OK)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: rejectedController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Rejected Quantity (Defect)',
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
              final passed = int.tryParse(passedController.text) ?? 0;
              final rejected = int.tryParse(rejectedController.text) ?? 0;
              final totalInput = passed + rejected;

              if (totalInput <= 0 || totalInput > pendingQty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('Total must be between 1 and $pendingQty')),
                );
                return;
              }
              Navigator.pop(ctx);
              await _submitQcCheck(item, passed, rejected);
            },
            child: const Text('Submit QC'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitQcCheck(dynamic item, int passed, int rejected) async {
    try {
      await supabase.from('qc_logs').insert({
        'article_id': item['article_id'],
        'stage': 'CHECKING',
        'from_lineman_id': item['lineman_id'],
        'qty_passed': passed,
        'qty_rejected': rejected,
        'entry_date': DateTime.now().toIso8601String().split('T')[0],
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QC Check saved successfully!'), backgroundColor: Colors.green),
        );
        _fetchPendingProduction(); // Refresh the list
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
        title: const Text('Production QC'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchPendingProduction,
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
          : _pendingProduction.isEmpty
              ? const Center(child: Text('No pending production to check today.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _pendingProduction.length,
                  itemBuilder: (context, index) {
                    final item = _pendingProduction[index];
                    final pendingQty = item['total_produced'] - item['total_checked'];
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
                                  'Lineman: ${item['username']}',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'Pending: $pendingQty',
                                    style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.w600),
                                  ),
                                )
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('Art No: ${item['art_no']} - ${item['description'] ?? ''}', style: TextStyle(color: Colors.grey.shade700)),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () => _showQcDialog(item),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryBlue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: const Text('Perform QC Check'),
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
