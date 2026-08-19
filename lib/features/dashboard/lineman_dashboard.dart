import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/providers/auth_provider.dart';
import '../auth/screens/login_screen.dart';
import '../../core/theme/app_theme.dart';
import '../../../main.dart'; // supabase client

class LinemanDashboard extends ConsumerStatefulWidget {
  const LinemanDashboard({super.key});

  @override
  ConsumerState<LinemanDashboard> createState() => _LinemanDashboardState();
}

class _LinemanDashboardState extends ConsumerState<LinemanDashboard> {
  bool _isLoading = true;
  List<dynamic> _allotments = [];

  @override
  void initState() {
    super.initState();
    _fetchMyAllotments();
  }

  Future<void> _fetchMyAllotments() async {
    setState(() => _isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        final res = await supabase
            .from('allotments')
            .select('''
              id,
              target_qty,
              status,
              article_id,
              articles ( art_no, description, stitching_rate )
            ''')
            .eq('lineman_id', user.id)
            .eq('status', 'IN_PROGRESS');
        
        setState(() {
          _allotments = res;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading targets: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showProductionDialog(dynamic allotment) {
    final qtyController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Enter Production - ${allotment['articles']['art_no']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Target: ${allotment['target_qty']} pieces'),
            const SizedBox(height: 16),
            TextField(
              controller: qtyController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Pieces Completed Today',
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
              final qty = int.tryParse(qtyController.text);
              if (qty == null || qty <= 0) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Enter valid quantity')),
                );
                return;
              }
              Navigator.pop(ctx);
              await _submitProduction(allotment, qty);
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitProduction(dynamic allotment, int qty) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      await supabase.from('daily_product').insert({
        'lineman_id': user.id,
        'employee_id': user.id, // Lineman themselves
        'article_id': allotment['article_id'],
        'quantity': qty,
        'entry_date': DateTime.now().toIso8601String().split('T')[0],
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Production saved!'), backgroundColor: Colors.green),
        );
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
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('My Work (Lineman)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchMyAllotments,
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
        : _allotments.isEmpty 
          ? const Center(child: Text('No targets assigned to you today.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _allotments.length,
              itemBuilder: (context, index) {
                final a = _allotments[index];
                final art = a['articles'];
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
                              'Art No: ${art['art_no']}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Target: ${a['target_qty']}',
                                style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.w600),
                              ),
                            )
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Description: ${art['description'] ?? '-'}', style: TextStyle(color: Colors.grey.shade700)),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => _showProductionDialog(a),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Enter Production'),
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
