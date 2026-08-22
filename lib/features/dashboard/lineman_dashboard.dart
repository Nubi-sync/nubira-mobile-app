import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/providers/auth_provider.dart';
import '../auth/screens/login_screen.dart';
import '../../core/theme/app_theme.dart';
import '../../../main.dart';

class LinemanDashboard extends ConsumerStatefulWidget {
  const LinemanDashboard({super.key});

  @override
  ConsumerState<LinemanDashboard> createState() => _LinemanDashboardState();
}

class _LinemanDashboardState extends ConsumerState<LinemanDashboard> {
  bool _isLoading = true;
  List<dynamic> _allotments = [];
  List<dynamic> _assignments = [];
  List<String> _recentWorkerNames = [];
  int _totalAssigned = 0;
  int _totalDone = 0;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        final today = DateTime.now().toIso8601String().split('T')[0];

        // 1. Fetch In-Progress Allotments for this lineman
        final allotmentsRes = await supabase
            .from('allotments')
            .select('''
              id,
              target_qty,
              allotment_date,
              status,
              article_id,
              articles ( id, art_no, description, stitching_rate )
            ''')
            .eq('lineman_id', user.id)
            .eq('status', 'IN_PROGRESS');

        final allotmentIds = allotmentsRes.map((a) => a['id'] as String).toList();

        // 2. Fetch variants (Size-Color Matrix) for these allotments
        List<dynamic> variantsRes = [];
        if (allotmentIds.isNotEmpty) {
          try {
            variantsRes = await supabase
                .from('allotment_variants')
                .select('id, allotment_id, color, size, quantity, completed_qty')
                .inFilter('allotment_id', allotmentIds);
          } catch (e) {
            debugPrint('Variants table not yet created or empty: $e');
          }
        }

        // 3. Fetch materials checklist for these allotments
        List<dynamic> materialsRes = [];
        if (allotmentIds.isNotEmpty) {
          try {
            materialsRes = await supabase
                .from('allotment_materials')
                .select('id, allotment_id, item_name, required_qty, admin_issued, lineman_received, lineman_received_at')
                .inFilter('allotment_id', allotmentIds);
          } catch (e) {
            debugPrint('Materials table not yet created or empty: $e');
          }
        }

        // 4. Fetch today's worker assignments by this lineman
        final assignmentsRes = await supabase
            .from('worker_assignments')
            .select('''
              id,
              allotment_id,
              worker_name,
              color,
              size,
              article_id,
              assigned_qty,
              completed_qty,
              status,
              notes,
              assigned_at,
              completed_at,
              entry_date,
              articles ( art_no, description )
            ''')
            .eq('lineman_id', user.id)
            .eq('entry_date', today)
            .order('assigned_at', ascending: false);

        // 5. Fetch past distinct worker names for quick auto-suggestions
        final pastRes = await supabase
            .from('worker_assignments')
            .select('worker_name')
            .eq('lineman_id', user.id)
            .limit(100);

        final Set<String> distinctNames = {};
        for (var p in pastRes) {
          final name = p['worker_name'] as String?;
          if (name != null && name.trim().isNotEmpty) {
            distinctNames.add(name.trim());
          }
        }

        // Calculate totals
        int assigned = 0;
        int done = 0;
        final Map<String, int> assignedPerAllotment = {};
        final Map<String, int> donePerAllotment = {};

        for (var a in assignmentsRes) {
          final qty = (a['assigned_qty'] as int?) ?? 0;
          assigned += qty;
          final allotId = a['allotment_id'] as String? ?? '';
          assignedPerAllotment[allotId] = (assignedPerAllotment[allotId] ?? 0) + qty;

          if (a['status'] == 'DONE') {
            final cQty = (a['completed_qty'] as int?) ?? qty;
            done += cQty;
            donePerAllotment[allotId] = (donePerAllotment[allotId] ?? 0) + cQty;
          }
        }

        // Enrich allotments with variants, materials & assignment stats
        final enriched = allotmentsRes.map((a) {
          final aId = a['id'] as String;
          final alVariants = variantsRes.where((v) => v['allotment_id'] == aId).toList();
          final alMaterials = materialsRes.where((m) => m['allotment_id'] == aId).toList();

          return {
            ...a,
            'total_assigned': assignedPerAllotment[aId] ?? 0,
            'total_done': donePerAllotment[aId] ?? 0,
            'variants': alVariants,
            'materials': alMaterials,
          };
        }).toList();

        setState(() {
          _allotments = enriched;
          _assignments = assignmentsRes;
          _recentWorkerNames = distinctNames.toList();
          _totalAssigned = assigned;
          _totalDone = done;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ======= MATERIAL HANDOVER VERIFICATION =======
  Future<void> _confirmMaterialReceipt(dynamic allotment) async {
    final materials = (allotment['materials'] as List<dynamic>?) ?? [];
    if (materials.isEmpty) return;

    final confirm = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.inventory_2_rounded, color: Color(0xFF047857), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Material Handover Verification',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                      ),
                      Text(
                        'Article: ${allotment['articles']?['art_no'] ?? ''}',
                        style: const TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Admin has issued the following materials for this allotment. Please verify physical count on the floor:',
              style: TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
            ),
            const SizedBox(height: 14),

            // Materials List
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: materials.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
                itemBuilder: (_, idx) {
                  final mat = materials[idx];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            mat['item_name'] ?? 'Item',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.textDark),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            mat['required_qty'] ?? '',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.blue.shade800),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(ctx, true),
                icon: const Icon(Icons.verified_rounded, size: 20),
                label: const Text('Confirm Material Received & Verified âœ…'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      try {
        final nowIso = DateTime.now().toUtc().toIso8601String();
        await supabase
            .from('allotment_materials')
            .update({
              'lineman_received': true,
              'lineman_received_at': nowIso,
            })
            .eq('allotment_id', allotment['id']);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Raw materials verified & acknowledged! âœ…'),
              backgroundColor: AppTheme.successGreen,
              behavior: SnackBarBehavior.floating,
            ),
          );
          _fetchDashboardData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  // ======= ASSIGN WORKER DIALOG (WITH SIZE & COLOR) =======
  void _showAssignWorkerDialog(dynamic allotment) {
    final workerNameController = TextEditingController();
    final qtyController = TextEditingController();
    final notesController = TextEditingController();

    final target = (allotment['target_qty'] as int?) ?? 0;
    final alreadyAssigned = (allotment['total_assigned'] as int?) ?? 0;
    final remaining = target - alreadyAssigned;

    final variants = (allotment['variants'] as List<dynamic>?) ?? [];
    
    // Extract unique colors and sizes from variants
    final Set<String> colorSet = {};
    final Set<String> sizeSet = {};
    for (var v in variants) {
      if (v['color'] != null && (v['color'] as String).isNotEmpty) {
        colorSet.add(v['color']);
      }
      if (v['size'] != null && (v['size'] as String).isNotEmpty) {
        sizeSet.add(v['size']);
      }
    }

    final colorsList = colorSet.toList();
    final sizesList = sizeSet.toList();

    String selectedColor = colorsList.isNotEmpty ? colorsList.first : 'Default';
    String selectedSize = sizesList.isNotEmpty ? sizesList.first : 'Standard';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person_add_alt_1_rounded, color: AppTheme.primaryBlue, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Assign Worker - ${allotment['articles']?['art_no'] ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Target: $target pcs',
                              style: TextStyle(color: Colors.blue.shade900, fontWeight: FontWeight.w700, fontSize: 12),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Remaining: $remaining pcs',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: remaining > 0 ? const Color(0xFF047857) : Colors.red.shade700,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            'Assigned so far: $alreadyAssigned pcs',
                            style: TextStyle(color: Colors.blue.shade700, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Worker Name Input with suggestions
                const Text('Worker / Tailor Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                const SizedBox(height: 6),
                Autocomplete<String>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return _recentWorkerNames;
                    }
                    return _recentWorkerNames.where((String option) {
                      return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                    });
                  },
                  onSelected: (String selection) {
                    workerNameController.text = selection;
                  },
                  fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                    controller.addListener(() {
                      workerNameController.text = controller.text;
                    });
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        hintText: 'e.g. Ramesh, Suresh, Mukesh...',
                        prefixIcon: const Icon(Icons.badge_rounded, size: 20),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 14),

                // Color & Size Selectors (if defined on allotment)
                if (colorsList.isNotEmpty || sizesList.isNotEmpty) ...[
                  Row(
                    children: [
                      if (colorsList.isNotEmpty)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Color', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: selectedColor,
                                    isExpanded: true,
                                    items: colorsList.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)))).toList(),
                                    onChanged: (v) {
                                      if (v != null) setDialogState(() => selectedColor = v);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (colorsList.isNotEmpty && sizesList.isNotEmpty) const SizedBox(width: 10),
                      if (sizesList.isNotEmpty)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Size', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: selectedSize,
                                    isExpanded: true,
                                    items: sizesList.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)))).toList(),
                                    onChanged: (v) {
                                      if (v != null) setDialogState(() => selectedSize = v);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],

                // Quantity Input
                const Text('Quantity to Assign (pcs)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                const SizedBox(height: 6),
                TextField(
                  controller: qtyController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Max $remaining pcs',
                    prefixIcon: const Icon(Icons.pin_rounded, size: 20),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),

                const SizedBox(height: 14),

                // Notes Input
                const Text('Remarks / Notes (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                const SizedBox(height: 6),
                TextField(
                  controller: notesController,
                  decoration: InputDecoration(
                    hintText: 'e.g. Front stitching bundle',
                    prefixIcon: const Icon(Icons.notes_rounded, size: 20),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final workerName = workerNameController.text.trim();
                final qty = int.tryParse(qtyController.text);

                if (workerName.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please enter worker name')));
                  return;
                }
                if (qty == null || qty <= 0) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Enter valid quantity')));
                  return;
                }
                if (qty > remaining) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Cannot assign more than $remaining pcs')));
                  return;
                }

                Navigator.pop(ctx);
                await _createAssignment(
                  allotment, 
                  workerName, 
                  selectedColor, 
                  selectedSize, 
                  qty, 
                  notesController.text
                );
              },
              child: const Text('Assign Work'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createAssignment(
    dynamic allotment, 
    String workerName, 
    String color, 
    String size, 
    int qty, 
    String notes
  ) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      await supabase.from('worker_assignments').insert({
        'allotment_id': allotment['id'],
        'lineman_id': user.id,
        'worker_name': workerName,
        'color': color,
        'size': size,
        'article_id': allotment['article_id'],
        'assigned_qty': qty,
        'status': 'PENDING',
        'notes': notes.trim().isEmpty ? null : notes.trim(),
        'entry_date': DateTime.now().toIso8601String().split('T')[0],
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Assigned $qty pcs ($color / $size) to $workerName!'),
            backgroundColor: AppTheme.successGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _fetchDashboardData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  // ======= MARK AS DONE =======
  Future<void> _markAsDone(dynamic assignment) async {
    final workerName = assignment['worker_name'] ?? 'Worker';
    final qty = assignment['assigned_qty'];
    final color = assignment['color'] ?? '';
    final size = assignment['size'] ?? '';
    final tag = (color.isNotEmpty || size.isNotEmpty) ? ' ($color / $size)' : '';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Mark as Done?'),
        content: Text(
          'Worker: $workerName\n'
          'Batch: $qty pcs$tag\n\n'
          'Kya $workerName ka kaam complete ho gaya hai?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successGreen),
            child: const Text('Done âœ…'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await supabase.from('worker_assignments').update({
          'status': 'DONE',
          'completed_qty': qty,
          'completed_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', assignment['id']);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$workerName ka kaam Done mark ho gaya! âœ…'),
              backgroundColor: AppTheme.successGreen,
              behavior: SnackBarBehavior.floating,
            ),
          );
          _fetchDashboardData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  // ======= EDIT ASSIGNMENT =======
  void _editAssignment(dynamic assignment) {
    if (assignment['status'] == 'DONE') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Done entries cannot be edited'), backgroundColor: Colors.orange),
      );
      return;
    }

    final nameController = TextEditingController(text: assignment['worker_name'] ?? '');
    final qtyController = TextEditingController(text: assignment['assigned_qty'].toString());
    final notesController = TextEditingController(text: assignment['notes'] ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.edit_rounded, color: AppTheme.primaryBlue, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Edit - ${assignment['worker_name'] ?? 'Worker'}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Worker Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(hintText: 'Worker Name', prefixIcon: Icon(Icons.person, size: 20)),
              ),
              const SizedBox(height: 14),
              const Text('Quantity (pcs)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: 'e.g. 100', prefixIcon: Icon(Icons.pin_rounded, size: 20)),
              ),
              const SizedBox(height: 14),
              const Text('Notes (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(hintText: 'Remarks', prefixIcon: Icon(Icons.notes_rounded, size: 20)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              final wName = nameController.text.trim();
              final qty = int.tryParse(qtyController.text);
              if (wName.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Enter worker name')));
                return;
              }
              if (qty == null || qty <= 0) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Enter valid quantity')));
                return;
              }
              Navigator.pop(ctx);
              try {
                await supabase.from('worker_assignments').update({
                  'worker_name': wName,
                  'assigned_qty': qty,
                  'notes': notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                }).eq('id', assignment['id']);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Assignment updated!'), backgroundColor: AppTheme.successGreen, behavior: SnackBarBehavior.floating),
                  );
                  _fetchDashboardData();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ======= DELETE ASSIGNMENT =======
  Future<void> _deleteAssignment(dynamic assignment) async {
    if (assignment['status'] == 'DONE') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Done entries cannot be deleted'), backgroundColor: Colors.orange),
      );
      return;
    }

    final workerName = assignment['worker_name'] ?? 'Worker';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Assignment?'),
        content: Text('Remove ${assignment['assigned_qty']} pcs assigned to $workerName?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await supabase.from('worker_assignments').delete().eq('id', assignment['id']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Assignment deleted!'), backgroundColor: Colors.orange),
          );
          _fetchDashboardData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
        }
      }
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'DONE':
        return const Color(0xFF10B981);
      case 'IN_PROGRESS':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF94A3B8);
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'DONE':
        return Icons.check_circle_rounded;
      case 'IN_PROGRESS':
        return Icons.timelapse_rounded;
      default:
        return Icons.pending_rounded;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'DONE':
        return 'Done';
      case 'IN_PROGRESS':
        return 'In Progress';
      default:
        return 'Pending';
    }
  }

  String _formatTime(String? isoTime) {
    if (isoTime == null) return '-';
    try {
      final dt = DateTime.parse(isoTime).toLocal();
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final amPm = dt.hour >= 12 ? 'PM' : 'AM';
      return '${hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $amPm';
    } catch (_) {
      return '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    final userName = user?.email?.split('@')[0] ?? 'Lineman';

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Lineman Area'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), tooltip: 'Refresh', onPressed: _fetchDashboardData),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // GREETING HEADER
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF2563EB).withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 8)),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Welcome, $userName!', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                const Text('Line Supervisor â€¢ Cut-to-Sew Floor', style: TextStyle(color: Colors.white70, fontSize: 13)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(16)),
                            child: const Icon(Icons.supervisor_account_rounded, color: Colors.white, size: 32),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // SUMMARY STATS
                    Row(
                      children: [
                        _buildStatCard('Total Assigned', '$_totalAssigned pcs', Icons.assignment_rounded, const Color(0xFF3B82F6)),
                        const SizedBox(width: 12),
                        _buildStatCard('Work Done', '$_totalDone pcs', Icons.check_circle_rounded, const Color(0xFF10B981)),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ALLOTMENTS SECTION
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Today's Allotment", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: Row(
                            children: [
                              Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                              const SizedBox(width: 6),
                              const Text('Live', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF047857))),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    if (_allotments.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Center(
                          child: Text('No allotment assigned.\nContact Admin to assign style target.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, height: 1.5)),
                        ),
                      )
                    else
                      ..._allotments.map((a) => _buildAllotmentCard(a)),

                    const SizedBox(height: 24),

                    // WORKER ASSIGNMENTS LIST
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Worker Assignments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                        Text('${_assignments.length} entries', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                      ],
                    ),

                    const SizedBox(height: 12),

                    if (_assignments.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Center(
                          child: Text('No workers assigned yet.\nTap "Assign Worker" on an allotment above.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, height: 1.5)),
                        ),
                      )
                    else
                      ..._assignments.map((a) => _buildAssignmentCard(a)),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: color)),
                  Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllotmentCard(dynamic a) {
    final art = a['articles'];
    final target = (a['target_qty'] as int?) ?? 1;
    final assigned = (a['total_assigned'] as int?) ?? 0;
    final done = (a['total_done'] as int?) ?? 0;
    final remaining = target - assigned;
    final progress = target > 0 ? (done / target).clamp(0.0, 1.0) : 0.0;
    final percent = (progress * 100).toInt();

    final variants = (a['variants'] as List<dynamic>?) ?? [];
    final materials = (a['materials'] as List<dynamic>?) ?? [];
    final hasMaterials = materials.isNotEmpty;
    final materialsConfirmed = hasMaterials && materials.every((m) => m['lineman_received'] == true);

    // Group variants by color
    final Map<String, List<dynamic>> colorGroups = {};
    for (var v in variants) {
      final c = (v['color'] as String?) ?? 'Default';
      colorGroups.putIfAbsent(c, () => []).add(v);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Material Handover Alert Banner (If materials issued by admin but not verified)
          if (hasMaterials)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: materialsConfirmed ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(bottom: BorderSide(color: materialsConfirmed ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A))),
              ),
              child: Row(
                children: [
                  Icon(
                    materialsConfirmed ? Icons.verified_rounded : Icons.pending_actions_rounded,
                    color: materialsConfirmed ? const Color(0xFF047857) : const Color(0xFFD97706),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      materialsConfirmed 
                        ? 'Raw Materials Verified & Received (${materials.length} items)'
                        : 'Raw Materials Issued (${materials.length} items) â€¢ Verification Pending',
                      style: TextStyle(
                        fontSize: 12, 
                        fontWeight: FontWeight.bold,
                        color: materialsConfirmed ? const Color(0xFF047857) : const Color(0xFF92400E),
                      ),
                    ),
                  ),
                  if (!materialsConfirmed)
                    TextButton(
                      onPressed: () => _confirmMaterialReceipt(a),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        backgroundColor: const Color(0xFFD97706),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Verify âœ…', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(20),
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
                          Text('Art No: ${art?['art_no'] ?? '-'}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppTheme.primaryBlueDark)),
                          const SizedBox(height: 4),
                          Text(art?['description'] ?? 'Garment Style', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: percent >= 100 ? const Color(0xFFECFDF5) : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: percent >= 100 ? const Color(0xFFA7F3D0) : Colors.blue.shade200),
                      ),
                      child: Text('$percent%', style: TextStyle(color: percent >= 100 ? const Color(0xFF047857) : AppTheme.primaryBlue, fontWeight: FontWeight.w900, fontSize: 14)),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Size & Color Matrix Chips
                if (colorGroups.isNotEmpty) ...[
                  const Text('Size & Color Ratios:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: colorGroups.entries.map((cg) {
                      final sizeStr = cg.value.map((v) => '${v['size']}:${v['quantity']}').join(', ');
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          '${cg.key} ($sizeStr)',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                ],

                // Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: const Color(0xFFF1F5F9),
                    valueColor: AlwaysStoppedAnimation<Color>(percent >= 100 ? AppTheme.successGreen : AppTheme.primaryBlue),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _miniLabel('Target', '$target pcs', Colors.grey.shade700),
                    const SizedBox(width: 8),
                    _miniLabel('Assigned', '$assigned pcs', const Color(0xFF3B82F6)),
                    const SizedBox(width: 8),
                    _miniLabel('Done', '$done pcs', const Color(0xFF10B981)),
                    const SizedBox(width: 8),
                    _miniLabel('Left', '$remaining pcs', remaining > 0 ? Colors.orange : Colors.grey),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: remaining > 0 ? () => _showAssignWorkerDialog(a) : null,
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
                    label: Text(remaining > 0 ? 'Assign Worker ($remaining left)' : 'Fully Assigned âœ…'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniLabel(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildAssignmentCard(dynamic a) {
    final workerName = a['worker_name'] ?? 'Worker';
    final artNo = a['articles']?['art_no'] ?? '-';
    final qty = (a['assigned_qty'] as int?) ?? 0;
    final status = a['status'] ?? 'PENDING';
    final assignedTime = _formatTime(a['assigned_at']);
    final doneTime = _formatTime(a['completed_at']);

    final color = a['color'] as String? ?? '';
    final size = a['size'] as String? ?? '';
    final hasVariant = (color.isNotEmpty && color != 'Default') || (size.isNotEmpty && size != 'Standard');
    final variantTag = hasVariant ? '$color â€¢ Size $size' : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: status == 'DONE' ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0),
          width: status == 'DONE' ? 1.5 : 1,
        ),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: _statusColor(status).withValues(alpha: 0.15),
                  child: Icon(_statusIcon(status), color: _statusColor(status), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(workerName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.textDark)),
                      const SizedBox(height: 3),
                      Text(
                        hasVariant ? 'Art: $artNo â€¢ $variantTag â€¢ $qty pcs' : 'Art: $artNo â€¢ $qty pcs',
                        style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(_statusLabel(status), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: _statusColor(status))),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.access_time_rounded, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text('Given: $assignedTime', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                if (status == 'DONE') ...[
                  const SizedBox(width: 10),
                  const Icon(Icons.check_circle_outline, size: 14, color: Color(0xFF10B981)),
                  const SizedBox(width: 4),
                  Text('Done: $doneTime', style: const TextStyle(fontSize: 11, color: Color(0xFF10B981))),
                ],
                const Spacer(),
                if (status != 'DONE') ...[
                  InkWell(
                    onTap: () => _markAsDone(a),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_rounded, size: 16, color: Color(0xFF10B981)),
                          SizedBox(width: 4),
                          Text('Done', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF10B981))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
                    onSelected: (val) {
                      if (val == 'edit') {
                        _editAssignment(a);
                      } else if (val == 'delete') {
                        _deleteAssignment(a);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 16), SizedBox(width: 8), Text('Edit')])),
                      const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 16, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))])),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}