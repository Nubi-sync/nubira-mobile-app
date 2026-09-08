import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/admin_providers.dart';
import 'allotment_form_state.dart';
import 'widgets/allotment_step_indicator.dart';

class AllotmentStep3Screen extends ConsumerStatefulWidget {
  const AllotmentStep3Screen({super.key});

  @override
  ConsumerState<AllotmentStep3Screen> createState() => _AllotmentStep3ScreenState();
}

class _AllotmentStep3ScreenState extends ConsumerState<AllotmentStep3Screen> {
  String _activeFilter = 'ALL'; // 'ALL' | 'CLIENT' | 'FACTORY_STORE'
  bool _isSubmitting = false;

  final TextEditingController _customNameController = TextEditingController();
  final TextEditingController _customQtyController = TextEditingController();
  String _customSource = 'CLIENT';

  @override
  void dispose() {
    _customNameController.dispose();
    _customQtyController.dispose();
    super.dispose();
  }

  void _showAddCustomItemDialog() {
    _customNameController.clear();
    _customQtyController.clear();
    _customSource = 'CLIENT';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add Material / Accessory', style: TextStyle(color: AppTheme.ink, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _customNameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Item Name *',
                  hintText: 'e.g. Drawcord, Elastic, Zipper',
                  filled: true,
                  fillColor: AppTheme.bg,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _customQtyController,
                decoration: const InputDecoration(
                  labelText: 'Required Quantity',
                  hintText: 'e.g. 500 pcs, 25 meters, As required',
                  filled: true,
                  fillColor: AppTheme.bg,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Text('Supplied By:', style: TextStyle(color: AppTheme.inkSoft, fontSize: 13)),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Client'),
                    selected: _customSource == 'CLIENT',
                    selectedColor: AppTheme.steel,
                    labelStyle: TextStyle(color: _customSource == 'CLIENT' ? Colors.white : AppTheme.inkSoft),
                    onSelected: (val) => setDialogState(() => _customSource = 'CLIENT'),
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: const Text('Factory Store'),
                    selected: _customSource == 'FACTORY_STORE',
                    selectedColor: AppTheme.steel,
                    labelStyle: TextStyle(color: _customSource == 'FACTORY_STORE' ? Colors.white : AppTheme.inkSoft),
                    onSelected: (val) => setDialogState(() => _customSource = 'FACTORY_STORE'),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.inkSoft)),
            ),
            ElevatedButton(
              onPressed: () {
                final name = _customNameController.text.trim();
                final qty = _customQtyController.text.trim();
                if (name.isNotEmpty) {
                  ref.read(allotmentFormProvider.notifier).addMaterialItem(
                        BomItem(
                          id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                          itemName: name,
                          requiredQty: qty.isNotEmpty ? qty : 'As required',
                          source: _customSource,
                        ),
                      );
                  Navigator.pop(ctx);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.steel),
              child: const Text('Add Item', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _addPresetItem(String name, String qty, String source) {
    final now = DateTime.now().millisecondsSinceEpoch;
    ref.read(allotmentFormProvider.notifier).addMaterialItem(
          BomItem(
            id: 'preset_${now}_${name.hashCode}',
            itemName: name,
            requiredQty: qty,
            source: source,
          ),
        );
  }

  Future<void> _submitAllotment() async {
    final form = ref.read(allotmentFormProvider);

    if (!form.isStep1Valid || !form.isStep2Valid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete Lineman and Size Matrix requirements first.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final variantsList = <Map<String, dynamic>>[];
    for (var r in form.colorRows) {
      final color = r.color.trim().isEmpty ? 'Default Color' : r.color.trim();
      for (var size in form.selectedSizes) {
        final qty = r.quantities[size] ?? 0;
        if (qty > 0) {
          variantsList.add({
            'color': color,
            'size': size,
            'quantity': qty,
          });
        }
      }
    }

    final materialsList = form.materials.map((m) {
      return {
        'item_name': m.itemName,
        'required_qty': m.requiredQty,
        'admin_issued': m.adminIssued,
        'source': m.source,
      };
    }).toList();

    final error = await createDetailedAllotmentInSupabase(
      linemanId: form.linemanId!,
      linemanName: form.linemanName,
      articleId: form.articleId!,
      articleNo: form.articleNo,
      articleDesc: form.articleDesc,
      targetQty: form.totalPieces,
      managerName: form.managerName,
      challanId: form.challanId,
      challanNo: form.challanNo,
      brand: form.brand,
      fabricType: form.fabricType,
      priority: form.priority,
      dueDate: form.dueDate,
      targetHours: form.targetHours,
      clientChallanNo: form.clientChallanNo,
      samplePhotos: form.samplePhotos,
      variants: variantsList,
      materials: materialsList,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (error == null) {
      // Refresh list provider
      ref.invalidate(adminAllotmentsListProvider);
      ref.read(allotmentFormProvider.notifier).reset();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Allotment of ${form.totalPieces} pcs assigned to ${form.linemanName ?? "Lineman"} successfully!'),
          backgroundColor: AppTheme.green,
        ),
      );

      // Pop back to Allotments List Screen (pop Step 3, Step 2, Step 1)
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed: $error'),
          backgroundColor: AppTheme.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(allotmentFormProvider);

    final clientCount = form.materials.where((m) => m.source == 'CLIENT').length;
    final storeCount = form.materials.where((m) => m.source == 'FACTORY_STORE').length;

    final filteredMaterials = form.materials.where((m) {
      if (_activeFilter == 'CLIENT') return m.source == 'CLIENT';
      if (_activeFilter == 'FACTORY_STORE') return m.source == 'FACTORY_STORE';
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('BOM & Raw Materials'),
        backgroundColor: AppTheme.card,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.ink),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Step Progress
          const AllotmentStepIndicator(currentStep: 3),

          // Scrollable Body
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 1. Target Summary Header Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: AppTheme.steelMist,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.person, color: AppTheme.steel, size: 18),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    form.linemanName ?? 'Lineman',
                                    style: const TextStyle(color: AppTheme.ink, fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'Art #${form.articleNo ?? 'N/A'}${form.brand != null ? ' (${form.brand})' : ''}',
                                    style: const TextStyle(color: AppTheme.inkSoft, fontSize: 11),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.steelMist,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${form.totalPieces} pcs Target',
                              style: const TextStyle(color: AppTheme.steel, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20, color: AppTheme.border),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'PPC Speed: ${form.pcsPerHour.toStringAsFixed(1)} pcs/hr (${form.targetHours}h)',
                            style: const TextStyle(color: AppTheme.inkSoft, fontSize: 11),
                          ),
                          Text(
                            'Priority: ${form.priority}',
                            style: TextStyle(
                              color: form.priority == 'CRITICAL' ? AppTheme.red : (form.priority == 'RUSH' ? AppTheme.amber : AppTheme.steel),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // 2. Auto-Generate Button & Filter Tabs
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => ref.read(allotmentFormProvider.notifier).autoGenerateBom(),
                        icon: const Icon(Icons.auto_awesome, size: 16, color: AppTheme.steel),
                        label: const Text('Auto-BOM from Matrix', style: TextStyle(color: AppTheme.steel, fontSize: 12, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.steel),
                          backgroundColor: AppTheme.card,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _showAddCustomItemDialog,
                      icon: const Icon(Icons.add, size: 16, color: Colors.white),
                      label: const Text('Custom', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.steel,
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 3. Segmented Filter Tabs
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterTab('ALL', 'All Items (${form.materials.length})'),
                      const SizedBox(width: 6),
                      _buildFilterTab('CLIENT', 'Client Supplied ($clientCount)'),
                      const SizedBox(width: 6),
                      _buildFilterTab('FACTORY_STORE', 'Factory Store ($storeCount)'),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 4. Quick Preset Chips Row
                _buildSectionHeader('Quick Add Accessories'),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildPresetChip('+ Elastic Waistband (1.2m/pc)', () => _addPresetItem('Elastic Waistband', '${(form.totalPieces * 1.2).ceil()} Meters', 'CLIENT')),
                    _buildPresetChip('+ Drawcord String (1m/pc)', () => _addPresetItem('Drawcord String', '${form.totalPieces} Meters', 'CLIENT')),
                    _buildPresetChip('+ Metal Eyelets (2 pcs/pc)', () => _addPresetItem('Metal Eyelets', '${form.totalPieces * 2} Pcs', 'CLIENT')),
                    _buildPresetChip('+ Care / Wash Labels', () => _addPresetItem('Care / Wash Labels', '${form.totalPieces} Pcs', 'CLIENT')),
                    _buildPresetChip('+ Hangtags & Strings', () => _addPresetItem('Hangtags & Strings', '${form.totalPieces} Sets', 'CLIENT')),
                  ],
                ),
                const SizedBox(height: 18),

                // 5. Materials Checklist
                _buildSectionHeader('Issued Materials Checklist (${filteredMaterials.length})'),
                if (filteredMaterials.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: const Text(
                      'No materials in this category.\nTap Auto-BOM or add custom items.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.inkFaint, fontSize: 13),
                    ),
                  )
                else
                  ...filteredMaterials.map((m) => _buildMaterialItemCard(m)),
                const SizedBox(height: 24),
              ],
            ),
          ),

          // Sticky Bottom Submit Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.card,
              border: const Border(top: BorderSide(color: AppTheme.border)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  offset: const Offset(0, -2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppTheme.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Back', style: TextStyle(color: AppTheme.inkSoft)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitAllotment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.steel,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_outline, size: 18),
                              SizedBox(width: 8),
                              Text('Create Allotment', style: TextStyle(fontWeight: FontWeight.bold)),
                            ],
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: AppTheme.ink,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildFilterTab(String key, String label) {
    final isSelected = _activeFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppTheme.steel,
      backgroundColor: AppTheme.card,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppTheme.inkSoft,
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(color: isSelected ? AppTheme.steel : AppTheme.border),
      onSelected: (val) {
        if (val) setState(() => _activeFilter = key);
      },
    );
  }

  Widget _buildPresetChip(String label, VoidCallback onAdd) {
    return ActionChip(
      label: Text(label),
      backgroundColor: AppTheme.card,
      side: const BorderSide(color: AppTheme.border),
      labelStyle: const TextStyle(color: AppTheme.steel, fontSize: 11, fontWeight: FontWeight.w600),
      onPressed: onAdd,
    );
  }

  Widget _buildMaterialItemCard(BomItem m) {
    final isClient = m.source == 'CLIENT';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          // Source Tag Chip (Tap to toggle)
          InkWell(
            onTap: () => ref.read(allotmentFormProvider.notifier).toggleMaterialSource(m.id),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isClient ? AppTheme.amberMist : AppTheme.steelMist,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isClient ? AppTheme.amber.withValues(alpha: 0.4) : AppTheme.steel.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                isClient ? 'CLIENT' : 'FACTORY',
                style: TextStyle(
                  color: isClient ? AppTheme.amber : AppTheme.steel,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Item Name & Required Quantity
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.itemName,
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Qty: ${m.requiredQty}',
                  style: const TextStyle(color: AppTheme.inkSoft, fontSize: 11),
                ),
              ],
            ),
          ),

          // Delete button
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppTheme.red, size: 18),
            onPressed: () => ref.read(allotmentFormProvider.notifier).removeMaterialItem(m.id),
          ),
        ],
      ),
    );
  }
}
