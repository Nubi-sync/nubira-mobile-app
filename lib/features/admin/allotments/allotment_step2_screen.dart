import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import 'allotment_form_state.dart';
import 'allotment_step3_screen.dart';
import 'widgets/allotment_step_indicator.dart';

class AllotmentStep2Screen extends ConsumerStatefulWidget {
  const AllotmentStep2Screen({super.key});

  @override
  ConsumerState<AllotmentStep2Screen> createState() => _AllotmentStep2ScreenState();
}

class _AllotmentStep2ScreenState extends ConsumerState<AllotmentStep2Screen> {
  final TextEditingController _customSizeController = TextEditingController();

  @override
  void dispose() {
    _customSizeController.dispose();
    super.dispose();
  }

  void _showAddSizeDialog() {
    _customSizeController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Custom Size', style: TextStyle(color: AppTheme.ink, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: _customSizeController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. 5XL, 38, Free Size',
            filled: true,
            fillColor: AppTheme.bg,
          ),
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.inkSoft)),
          ),
          ElevatedButton(
            onPressed: () {
              final size = _customSizeController.text.trim();
              if (size.isNotEmpty) {
                ref.read(allotmentFormProvider.notifier).addCustomSize(size);
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.steel),
            child: const Text('Add Size', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(allotmentFormProvider);

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
          // Step Progress
          const AllotmentStepIndicator(
            currentStep: 2,
            subtitle: 'Step 2 of 3 - Size & color ratio matrix',
          ),

          // Scrollable Matrix Body
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Info Box
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.steelMist,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppTheme.steel,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.grid_view_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Step 2: Cut-to-Sew Ratio Matrix',
                              style: TextStyle(
                                color: AppTheme.ink,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Target Style: Art #${form.articleNo ?? 'N/A'}${form.brand != null ? ' (${form.brand})' : ''}',
                              style: const TextStyle(
                                color: AppTheme.steel,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // 1. Size Preset Selector
                _buildSectionHeader('Size Presets'),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: SizePreset.presets.map((preset) {
                      final isSelected = form.activePreset == preset.key;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(preset.label),
                          selected: isSelected,
                          selectedColor: AppTheme.steel,
                          backgroundColor: AppTheme.card,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : AppTheme.inkSoft,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                          side: BorderSide(
                            color: isSelected ? AppTheme.steel : AppTheme.border,
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              ref.read(allotmentFormProvider.notifier).setPreset(preset.key);
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 18),

                // 2. Active Sizes Row (with Add/Remove)
                _buildSectionHeader('Active Sizes (${form.selectedSizes.length})'),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ...form.selectedSizes.map((size) {
                      return Chip(
                        label: Text(size, style: const TextStyle(color: AppTheme.ink, fontWeight: FontWeight.bold, fontSize: 12)),
                        backgroundColor: AppTheme.card,
                        side: const BorderSide(color: AppTheme.border),
                        deleteIcon: const Icon(Icons.close, size: 14, color: AppTheme.inkFaint),
                        onDeleted: form.selectedSizes.length > 1
                            ? () => ref.read(allotmentFormProvider.notifier).removeSize(size)
                            : null,
                      );
                    }),
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 16, color: AppTheme.steel),
                      label: const Text('Add Size', style: TextStyle(color: AppTheme.steel, fontWeight: FontWeight.bold, fontSize: 12)),
                      backgroundColor: AppTheme.steelMist,
                      side: const BorderSide(color: AppTheme.steel),
                      onPressed: _showAddSizeDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                // 3. Color Rows Matrix
                _buildSectionHeader('Color Rows & Piece Quantities'),
                ...form.colorRows.map((row) => _buildColorCard(row, form.selectedSizes)),
                const SizedBox(height: 8),

                // Add Color Row Button
                OutlinedButton.icon(
                  onPressed: () => ref.read(allotmentFormProvider.notifier).addColorRow(),
                  icon: const Icon(Icons.add, size: 18, color: AppTheme.steel),
                  label: const Text('Add Color Line', style: TextStyle(color: AppTheme.steel, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppTheme.card,
                    side: const BorderSide(color: AppTheme.steel, style: BorderStyle.solid),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),

          // Sticky Bottom Summary Bar
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Grand Target Summary
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Grand Target Pieces:',
                      style: TextStyle(color: AppTheme.inkSoft, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${form.totalPieces} pcs',
                      style: const TextStyle(
                        color: AppTheme.steel,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
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
                        onPressed: form.isStep2Valid
                            ? () {
                                // Auto generate standard BOM
                                ref.read(allotmentFormProvider.notifier).autoGenerateBom();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AllotmentStep3Screen(),
                                  ),
                                );
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.steel,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppTheme.border,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Continue to BOM', style: TextStyle(fontWeight: FontWeight.bold)),
                            SizedBox(width: 6),
                            Icon(Icons.arrow_forward, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
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

  Widget _buildColorCard(ColorMatrixRow row, List<String> sizes) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Color Name Field + Row Total + Delete
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: row.color,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    labelText: 'Color / Shade Name',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) {
                    ref.read(allotmentFormProvider.notifier).updateColorName(row.id, val.trim());
                  },
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.steelMist,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${row.rowTotal} pcs',
                  style: const TextStyle(
                    color: AppTheme.steel,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppTheme.red, size: 20),
                onPressed: () => ref.read(allotmentFormProvider.notifier).removeColorRow(row.id),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Size Input Grid (Horizontal scrollable or wrap)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: sizes.map((size) {
                final qty = row.quantities[size] ?? 0;
                return Container(
                  width: 72,
                  margin: const EdgeInsets.only(right: 8),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppTheme.bg,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                          border: Border.all(color: AppTheme.border),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          size,
                          style: const TextStyle(
                            color: AppTheme.ink,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      TextFormField(
                        key: ValueKey('${row.id}_$size'),
                        initialValue: qty > 0 ? qty.toString() : '',
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: '0',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(6)),
                            borderSide: const BorderSide(color: AppTheme.border),
                          ),
                          filled: true,
                          fillColor: AppTheme.card,
                        ),
                        onChanged: (val) {
                          final parsed = int.tryParse(val) ?? 0;
                          ref.read(allotmentFormProvider.notifier).updateQuantity(row.id, size, parsed);
                        },
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
