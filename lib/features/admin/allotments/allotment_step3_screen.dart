import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final form = ref.read(allotmentFormProvider);
      if (form.materials.isEmpty) {
        ref.read(allotmentFormProvider.notifier).autoGenerateBom();
      }
    });
  }

  void _showAddOrEditCustomItemModal([BomItem? existingItem]) {
    final nameController = TextEditingController(text: existingItem?.itemName ?? '');
    final qtyController = TextEditingController(text: existingItem?.requiredQty ?? '');
    String selectedSource = existingItem?.source ?? 'CLIENT';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    existingItem == null ? 'Add Custom Material / Trim' : 'Edit Material Item',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1C1C1A),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF6B6A65), size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Item Name Input
              const Text(
                'Material / Item Name *',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1C1C1A)),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: nameController,
                autofocus: existingItem == null,
                decoration: InputDecoration(
                  hintText: 'e.g. 24L Metal Snap Buttons, 12" Zipper, Hangtags',
                  hintStyle: const TextStyle(color: Color(0xFF9B9A94), fontSize: 13),
                  filled: true,
                  fillColor: const Color(0xFFFAFAF8),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFDAD9D3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFDAD9D3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF1C1C1A), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Quantity Input
              const Text(
                'Required Quantity *',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1C1C1A)),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: qtyController,
                decoration: InputDecoration(
                  hintText: 'e.g. 500 pcs, 25 meters, 12 cones, As per roll marker',
                  hintStyle: const TextStyle(color: Color(0xFF9B9A94), fontSize: 13),
                  filled: true,
                  fillColor: const Color(0xFFFAFAF8),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFDAD9D3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFDAD9D3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF1C1C1A), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Source Selector
              const Text(
                'Supplied By / Source *',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1C1C1A)),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setModalState(() => selectedSource = 'CLIENT'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selectedSource == 'CLIENT' ? const Color(0xFF1C1C1A) : const Color(0xFFF1F1EE),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Client supplied',
                          style: TextStyle(
                            color: selectedSource == 'CLIENT' ? Colors.white : const Color(0xFF6B6A65),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setModalState(() => selectedSource = 'FACTORY_STORE'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selectedSource == 'FACTORY_STORE' ? const Color(0xFF1C1C1A) : const Color(0xFFF1F1EE),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Factory sourced',
                          style: TextStyle(
                            color: selectedSource == 'FACTORY_STORE' ? Colors.white : const Color(0xFF6B6A65),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Color(0xFFDAD9D3)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B6A65))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        final name = nameController.text.trim();
                        final qty = qtyController.text.trim();
                        if (name.isNotEmpty) {
                          if (existingItem != null) {
                            // Update existing
                            ref.read(allotmentFormProvider.notifier).updateMaterialItem(
                              existingItem.id,
                              name: name,
                              qty: qty.isNotEmpty ? qty : 'As required',
                              source: selectedSource,
                            );
                          } else {
                            // Add new
                            final now = DateTime.now().millisecondsSinceEpoch;
                            ref.read(allotmentFormProvider.notifier).addMaterialItem(
                              BomItem(
                                id: 'custom_${now}_${name.hashCode}',
                                itemName: name,
                                requiredQty: qty.isNotEmpty ? qty : 'As required',
                                adminIssued: false,
                                source: selectedSource,
                              ),
                            );
                          }
                          Navigator.pop(ctx);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1C1C1A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        existingItem == null ? 'Add to BOM' : 'Save Changes',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
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
      ref.invalidate(adminAllotmentsListProvider);
      ref.read(allotmentFormProvider.notifier).reset();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Allotment of ${form.totalPieces} pcs assigned to ${form.linemanName ?? "Lineman"} successfully!'),
          backgroundColor: const Color(0xFF047857),
        ),
      );

      // Return to Allotments List / Challan Hub
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed: $error'),
          backgroundColor: Colors.red.shade800,
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'New allotment',
          style: TextStyle(
            color: Color(0xFF1C1C1A),
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1C1C1A)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // 3-Bar Step Indicator
          const AllotmentStepIndicator(
            currentStep: 3,
            subtitle: 'Step 3 of 3 - BOM raw materials and trims',
          ),

          // Scrollable Body Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // 1. Segmented Filter Tabs (Client supplied vs Factory sourced)
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _activeFilter = _activeFilter == 'CLIENT' ? 'ALL' : 'CLIENT';
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _activeFilter == 'CLIENT'
                                ? const Color(0xFF1C1C1A)
                                : const Color(0xFFF1F1EE),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Client supplied - $clientCount',
                            style: TextStyle(
                              color: _activeFilter == 'CLIENT'
                                  ? Colors.white
                                  : const Color(0xFF6B6A65),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _activeFilter = _activeFilter == 'FACTORY_STORE' ? 'ALL' : 'FACTORY_STORE';
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _activeFilter == 'FACTORY_STORE'
                                ? const Color(0xFF1C1C1A)
                                : const Color(0xFFF1F1EE),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Factory sourced - $storeCount',
                            style: TextStyle(
                              color: _activeFilter == 'FACTORY_STORE'
                                  ? Colors.white
                                  : const Color(0xFF6B6A65),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 2. Action Row: Auto-calculate BOM + Add Custom Item
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          ref.read(allotmentFormProvider.notifier).autoGenerateBom();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('BOM auto-calculated from size matrix & garment specs!'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F1EE),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFECECE8)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.auto_awesome, size: 14, color: Color(0xFF1C1C1A)),
                              SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Auto-calculate BOM',
                                  style: TextStyle(
                                    color: Color(0xFF1C1C1A),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _showAddOrEditCustomItemModal(),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1C1A),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add, size: 15, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'Add Custom',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 3. Materials List Cards
                if (filteredMaterials.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(28),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFAF8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFDAD9D3)),
                    ),
                    child: const Text(
                      'No items in this filter.\nTap Auto-calculate or add a custom item.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF6B6A65), fontSize: 13),
                    ),
                  )
                else
                  ...filteredMaterials.map((m) => _buildMaterialCard(m)),

                const SizedBox(height: 16),

                // 4. Quick presets Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Quick presets',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1C1C1A),
                      ),
                    ),
                    InkWell(
                      onTap: () => _showAddOrEditCustomItemModal(),
                      child: const Text(
                        '+ Custom item',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF332B6B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildPresetChip(
                      '+ Elastic waistband',
                      () => _addPresetItem(
                        'Elastic waistband',
                        '${form.totalPieces > 0 ? (form.totalPieces * 1.2).ceil() : 600} meters',
                        'CLIENT',
                      ),
                    ),
                    _buildPresetChip(
                      '+ Drawcord',
                      () => _addPresetItem(
                        'Drawcord',
                        '${form.totalPieces > 0 ? form.totalPieces : 500} meters',
                        'CLIENT',
                      ),
                    ),
                    _buildPresetChip(
                      '+ Metal eyelets',
                      () => _addPresetItem(
                        'Metal eyelets',
                        '${form.totalPieces > 0 ? form.totalPieces * 2 : 1000} pcs',
                        'CLIENT',
                      ),
                    ),
                    _buildPresetChip(
                      '+ Care labels',
                      () => _addPresetItem(
                        'Care labels',
                        '${form.totalPieces > 0 ? form.totalPieces : 500} pcs',
                        'CLIENT',
                      ),
                    ),
                    _buildPresetChip(
                      '+ 18L 4-hole buttons',
                      () => _addPresetItem(
                        '18L 4-hole buttons',
                        '${form.totalPieces > 0 ? form.totalPieces * 3 : 1500} pcs',
                        'CLIENT',
                      ),
                    ),
                    _buildPresetChip(
                      '+ Master polybags',
                      () => _addPresetItem(
                        'Master polybags',
                        '${form.totalPieces > 0 ? form.totalPieces : 500} pcs',
                        'CLIENT',
                      ),
                    ),
                    _buildPresetChip(
                      '+ Custom item...',
                      () => _showAddOrEditCustomItemModal(),
                      isHighlighted: true,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),

          // Sticky Bottom Actions Bar (Back + Submit allotment)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFECECE8), width: 1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFFDAD9D3)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Back',
                      style: TextStyle(
                        color: Color(0xFF1C1C1A),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitAllotment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1C1C1A),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF9B9A94),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'Submit allotment',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
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

  Widget _buildMaterialCard(BomItem m) {
    final sourceLabel = m.source == 'CLIENT' ? 'Client supplied' : 'Factory sourced';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFECECE8)),
      ),
      child: Row(
        children: [
          // Item Name & Subtitle (Tappable to edit)
          Expanded(
            child: InkWell(
              onTap: () => _showAddOrEditCustomItemModal(m),
              borderRadius: BorderRadius.circular(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          m.itemName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1C1C1A),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.edit_outlined, size: 13, color: Color(0xFF9B9A94)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${m.requiredQty} - $sourceLabel',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B6A65),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Square Checkbox
          Transform.scale(
            scale: 0.95,
            child: Checkbox(
              value: m.adminIssued,
              activeColor: const Color(0xFF1C1C1A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              side: const BorderSide(color: Color(0xFFDAD9D3), width: 1.2),
              onChanged: (_) => ref.read(allotmentFormProvider.notifier).toggleMaterialIssued(m.id),
            ),
          ),

          // Delete icon button
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20, color: Color(0xFF9B9A94)),
            splashRadius: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () => ref.read(allotmentFormProvider.notifier).removeMaterialItem(m.id),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String label, VoidCallback onAdd, {bool isHighlighted = false}) {
    return InkWell(
      onTap: onAdd,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isHighlighted ? const Color(0xFFEDEAF6) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isHighlighted ? const Color(0xFF332B6B) : const Color(0xFFDAD9D3),
            width: isHighlighted ? 1.2 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w500,
            color: isHighlighted ? const Color(0xFF332B6B) : const Color(0xFF1C1C1A),
          ),
        ),
      ),
    );
  }
}
